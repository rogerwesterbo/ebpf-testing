package ebpf

import (
	"fmt"

	"github.com/cilium/ebpf"
	"github.com/cilium/ebpf/link"
)

// Manager manages eBPF programs and maps
type Manager struct {
	collection *ebpf.Collection
	kprobeLink link.Link
	countsMap  *ebpf.Map
}

// Config holds the configuration for the eBPF manager
type Config struct {
	ObjectPath   string
	ProgramName  string
	MapName      string
	KprobeSymbol string
}

// DefaultConfig returns the default configuration
func DefaultConfig() Config {
	return Config{
		ObjectPath:   "/bpf/tcpconnect.bpf.o",
		ProgramName:  "on_tcp_connect",
		MapName:      "counts",
		KprobeSymbol: "tcp_connect",
	}
}

// NewManager creates and initializes a new eBPF manager
func NewManager(cfg Config) (*Manager, error) {
	// Load the BPF object from disk
	spec, err := ebpf.LoadCollectionSpec(cfg.ObjectPath)
	if err != nil {
		return nil, fmt.Errorf("load spec: %w", err)
	}

	coll, err := ebpf.NewCollection(spec)
	if err != nil {
		return nil, fmt.Errorf("new collection: %w", err)
	}

	prog := coll.Programs[cfg.ProgramName]
	if prog == nil {
		coll.Close()
		return nil, fmt.Errorf("program %q not found", cfg.ProgramName)
	}

	// Attach kprobe
	l, err := link.Kprobe(cfg.KprobeSymbol, prog, nil)
	if err != nil {
		coll.Close()
		return nil, fmt.Errorf("link kprobe: %w", err)
	}

	// Get map handle
	counts := coll.Maps[cfg.MapName]
	if counts == nil {
		l.Close()
		coll.Close()
		return nil, fmt.Errorf("map %q not found", cfg.MapName)
	}

	return &Manager{
		collection: coll,
		kprobeLink: l,
		countsMap:  counts,
	}, nil
}

// GetCountsMap returns the counts map
func (m *Manager) GetCountsMap() *ebpf.Map {
	return m.countsMap
}

// Close cleans up resources
func (m *Manager) Close() error {
	var err error
	if m.kprobeLink != nil {
		if e := m.kprobeLink.Close(); e != nil {
			err = e
		}
	}
	if m.collection != nil {
		m.collection.Close()
	}
	return err
}
