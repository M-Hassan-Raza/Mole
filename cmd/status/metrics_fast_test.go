package main

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"

	"github.com/shirou/gopsutil/v4/disk"
	gopsutilnet "github.com/shirou/gopsutil/v4/net"
)

func TestCollectFastAvoidsExternalCommands(t *testing.T) {
	origRunCmd := runCmd
	origCommandExists := commandExists
	origPartitions := diskPartitionsFunc
	origUsage := diskUsageFunc
	origIOCounters := ioCountersFunc
	t.Cleanup(func() {
		runCmd = origRunCmd
		commandExists = origCommandExists
		diskPartitionsFunc = origPartitions
		diskUsageFunc = origUsage
		ioCountersFunc = origIOCounters
	})

	var externalCalls atomic.Int32
	runCmd = func(ctx context.Context, name string, args ...string) (string, error) {
		externalCalls.Add(1)
		return "", errors.New("unexpected command")
	}
	commandExists = func(name string) bool {
		externalCalls.Add(1)
		return false
	}
	diskPartitionsFunc = func(all bool) ([]disk.PartitionStat, error) {
		return []disk.PartitionStat{
			{Device: "/dev/disk3s1s1", Mountpoint: "/", Fstype: "apfs"},
		}, nil
	}
	diskUsageFunc = func(path string) (*disk.UsageStat, error) {
		return &disk.UsageStat{
			Path:        path,
			Fstype:      "apfs",
			Total:       2 * 1024 * 1024 * 1024,
			Used:        1024 * 1024 * 1024,
			UsedPercent: 50,
		}, nil
	}
	ioCountersFunc = func(bool) ([]gopsutilnet.IOCountersStat, error) {
		return []gopsutilnet.IOCountersStat{
			{Name: "en0", BytesRecv: 1024, BytesSent: 2048},
		}, nil
	}

	collector := NewCollector(ProcessWatchOptions{})
	if _, err := collector.CollectFast(); err != nil {
		t.Fatalf("CollectFast() error = %v", err)
	}
	if externalCalls.Load() != 0 {
		t.Fatalf("CollectFast() made %d external command calls", externalCalls.Load())
	}
}
