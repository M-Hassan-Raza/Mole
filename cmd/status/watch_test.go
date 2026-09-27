package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"os"
	"os/exec"
	"sync/atomic"
	"testing"
	"time"

	"github.com/shirou/gopsutil/v4/disk"
)

// Exercise the actual streaming loop in a child so its stdout and collector
// probes stay isolated from other tests. All external commands are disabled.
func TestStatusWatchProcess(t *testing.T) {
	mode := os.Getenv("MOLE_STATUS_WATCH_TEST_MODE")
	if mode == "" {
		t.Skip("watch subprocess helper")
	}
	runCmd = func(context.Context, string, ...string) (string, error) {
		return "", errors.New("optional metric unavailable")
	}
	commandExists = func(string) bool { return false }
	var calls atomic.Int32
	diskPartitionsFunc = func(bool) ([]disk.PartitionStat, error) {
		attempt := calls.Add(1)
		if mode == "failed" || (mode == "recover" && attempt <= 2) {
			return nil, errors.New("partition probe failed")
		}
		return []disk.PartitionStat{{Device: "/dev/disk3s1", Mountpoint: "/", Fstype: "apfs"}}, nil
	}
	diskUsageFunc = func(string) (*disk.UsageStat, error) {
		return &disk.UsageStat{Total: 2 << 30, Used: 1 << 30, Free: 1 << 30, UsedPercent: 50}, nil
	}
	collectProcessesFunc = func() (processSample, error) {
		return processSample{parentsAvailable: true}, nil
	}
	runWatchStdout(time.Second)
}

func TestWatchHonorsIntervalAfterInitialSnapshot(t *testing.T) {
	for _, mode := range []string{"healthy", "failed", "recover"} {
		t.Run(mode, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			cmd := exec.CommandContext(ctx, os.Args[0], "-test.run=^TestStatusWatchProcess$")
			cmd.Env = append(os.Environ(), "MOLE_STATUS_WATCH_TEST_MODE="+mode, "HOME="+t.TempDir(), "MOLE_TEST_NO_AUTH=1")
			var stderr bytes.Buffer
			cmd.Stderr = &stderr
			stdout, err := cmd.StdoutPipe()
			if err != nil {
				t.Fatal(err)
			}
			defer stdout.Close()
			if err := cmd.Start(); err != nil {
				t.Fatal(err)
			}
			defer func() {
				cancel()
				_ = cmd.Wait()
				if t.Failed() {
					t.Logf("watch stderr: %s", &stderr)
				}
			}()
			var snapshots [3]MetricsSnapshot
			decoder := json.NewDecoder(stdout)
			for i := range snapshots {
				if err := decoder.Decode(&snapshots[i]); err != nil {
					t.Fatalf("snapshot %d: %v", i, err)
				}
			}
			// Startup may enrich the first snapshot immediately. Every later
			// collection must wait, including repeated failures and recovery.
			if elapsed := snapshots[2].CollectedAt.Sub(snapshots[1].CollectedAt); elapsed < time.Second {
				t.Fatalf("next collection started after %v, want at least 1s", elapsed)
			}
			if mode == "failed" && len(snapshots[2].Disks) != 0 {
				t.Fatal("failed disk probe unexpectedly produced a disk")
			}
			if mode != "failed" && (len(snapshots[2].Disks) != 1 || snapshots[2].Disks[0].Total != 2<<30) {
				t.Fatalf("healthy or recovered disk missing: %+v", snapshots[2].Disks)
			}
		})
	}
}
