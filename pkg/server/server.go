package server

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/rogerwesterbo/ebpf-testing/pkg/health"
)

// Config holds the configuration for the server manager
type Config struct {
	MetricsAddr string
	HealthAddr  string
	HealthCheck *health.Checker
}

// Manager manages HTTP servers
type Manager struct {
	metricsServer *http.Server
	healthServer  *http.Server
}

// NewManager creates a new server manager
func NewManager(cfg Config) *Manager {
	// Metrics server
	metricsServer := &http.Server{
		Addr: cfg.MetricsAddr,
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path == "/metrics" {
				promhttp.Handler().ServeHTTP(w, r)
			} else {
				http.NotFound(w, r)
			}
		}),
	}

	// Health check server
	healthMux := http.NewServeMux()
	healthMux.HandleFunc("/readiness", cfg.HealthCheck.ReadinessHandler)
	healthMux.HandleFunc("/liveness", cfg.HealthCheck.LivenessHandler)
	healthMux.HandleFunc("/health", cfg.HealthCheck.HealthHandler)

	healthServer := &http.Server{
		Addr:    cfg.HealthAddr,
		Handler: healthMux,
	}

	return &Manager{
		metricsServer: metricsServer,
		healthServer:  healthServer,
	}
}

// Start starts both HTTP servers
func (m *Manager) Start() error {
	// Start metrics server
	go func() {
		log.Printf("serving metrics on %s/metrics", m.metricsServer.Addr)
		if err := m.metricsServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Printf("metrics server error: %v", err)
		}
	}()

	// Start health check server
	go func() {
		log.Printf("serving health checks on %s (/readiness, /liveness, /health)", m.healthServer.Addr)
		if err := m.healthServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Printf("health server error: %v", err)
		}
	}()

	return nil
}

// Shutdown gracefully shuts down both servers
func (m *Manager) Shutdown(ctx context.Context) error {
	var err error

	// Shutdown both servers concurrently
	done := make(chan error, 2)

	go func() {
		done <- m.metricsServer.Shutdown(ctx)
	}()

	go func() {
		done <- m.healthServer.Shutdown(ctx)
	}()

	// Wait for both to complete
	for i := 0; i < 2; i++ {
		if e := <-done; e != nil {
			err = e
		}
	}

	if err != nil {
		return fmt.Errorf("server shutdown error: %w", err)
	}

	return nil
}

// ShutdownGracefully performs a graceful shutdown with a timeout
func (m *Manager) ShutdownGracefully(timeout time.Duration) error {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	return m.Shutdown(ctx)
}
