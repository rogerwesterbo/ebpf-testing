package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/rogerwesterbo/ebpf-testing/pkg/ebpf"
	"github.com/rogerwesterbo/ebpf-testing/pkg/health"
	"github.com/rogerwesterbo/ebpf-testing/pkg/metrics"
	"github.com/rogerwesterbo/ebpf-testing/pkg/server"
)

func main() {
	// Initialize health checker
	healthChecker := health.NewChecker()

	// Load and attach eBPF program
	log.Println("Loading eBPF program...")
	ebpfMgr, err := ebpf.NewManager(ebpf.DefaultConfig())
	if err != nil {
		log.Fatalf("Failed to load eBPF program: %v", err)
	}
	defer ebpfMgr.Close()

	// Mark as ready once eBPF is successfully loaded and attached
	healthChecker.SetReady(true)
	log.Println("eBPF program loaded and attached successfully - application is ready")

	// Start metrics collector
	log.Println("Starting metrics collector...")
	metricsCollector := metrics.NewCollector(metrics.Config{
		CountsMap: ebpfMgr.GetCountsMap(),
		Interval:  5 * time.Second,
		OnError: func(err error) {
			log.Printf("Metrics collection error: %v", err)
			healthChecker.SetAlive(false)
		},
	})
	metricsCollector.Start()
	defer metricsCollector.Stop()

	// Start HTTP servers
	log.Println("Starting HTTP servers...")
	serverMgr := server.NewManager(server.Config{
		MetricsAddr: ":9090",
		HealthAddr:  ":8080",
		HealthCheck: healthChecker,
	})

	if err := serverMgr.Start(); err != nil {
		log.Fatalf("Failed to start servers: %v", err)
	}

	// Wait for shutdown signal
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	<-sig

	// Graceful shutdown
	log.Println("Shutting down...")
	healthChecker.SetReady(false)

	if err := serverMgr.ShutdownGracefully(10 * time.Second); err != nil {
		log.Printf("Server shutdown error: %v", err)
	}

	log.Println("Shutdown complete")
}
