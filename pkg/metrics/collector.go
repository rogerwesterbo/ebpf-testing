package metrics

import (
	"log"
	"sort"
	"strconv"
	"time"

	"github.com/cilium/ebpf"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/rogerwesterbo/ebpf-testing/internal/procfs"
)

// Collector collects and exports eBPF metrics to Prometheus
type Collector struct {
	countsMap   *ebpf.Map
	countsGauge *prometheus.GaugeVec
	interval    time.Duration
	stopChan    chan struct{}
	onError     func(error)
}

// Config holds the configuration for the metrics collector
type Config struct {
	CountsMap *ebpf.Map
	Interval  time.Duration
	OnError   func(error)
}

// NewCollector creates a new metrics collector
func NewCollector(cfg Config) *Collector {
	countsGauge := prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "tcp_connects_by_pid",
			Help: "Number of tcp_connect() calls observed per PID",
		},
		[]string{"pid", "comm"},
	)

	prometheus.MustRegister(countsGauge)

	if cfg.Interval == 0 {
		cfg.Interval = 5 * time.Second
	}

	return &Collector{
		countsMap:   cfg.CountsMap,
		countsGauge: countsGauge,
		interval:    cfg.Interval,
		stopChan:    make(chan struct{}),
		onError:     cfg.OnError,
	}
}

type pidCount struct {
	pid uint32
	val uint64
}

// Start begins collecting metrics
func (c *Collector) Start() {
	go func() {
		defer func() {
			if r := recover(); r != nil {
				log.Printf("Metrics collection goroutine panicked: %v", r)
				if c.onError != nil {
					if err, ok := r.(error); ok {
						c.onError(err)
					}
				}
			}
		}()

		ticker := time.NewTicker(c.interval)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				c.collect()
			case <-c.stopChan:
				return
			}
		}
	}()
}

// collect reads the eBPF map and updates Prometheus metrics
func (c *Collector) collect() {
	iter := c.countsMap.Iterate()
	counts := make([]pidCount, 0, 256)

	var pid uint32
	var val uint64
	for iter.Next(&pid, &val) {
		counts = append(counts, pidCount{pid, val})
	}

	// Sort by PID for consistent ordering
	sort.Slice(counts, func(i, j int) bool {
		return counts[i].pid < counts[j].pid
	})

	// Update gauges
	for _, pc := range counts {
		labels := prometheus.Labels{
			"pid":  strconv.Itoa(int(pc.pid)),
			"comm": procfs.GetProcessName(int(pc.pid)),
		}
		c.countsGauge.With(labels).Set(float64(pc.val))
	}
}

// Stop stops the metrics collection
func (c *Collector) Stop() {
	close(c.stopChan)
}
