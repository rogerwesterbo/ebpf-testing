package health

import (
	"encoding/json"
	"net/http"
	"sync/atomic"
	"time"
)

// Checker manages application health state
type Checker struct {
	ready int64 // 0 = not ready, 1 = ready
	alive int64 // 0 = not alive, 1 = alive
}

// Status represents the health status
type Status struct {
	Ready     bool  `json:"ready"`
	Alive     bool  `json:"alive"`
	Timestamp int64 `json:"timestamp"`
}

// NewChecker creates a new health checker
func NewChecker() *Checker {
	return &Checker{
		alive: 1, // Alive from the start
		ready: 0, // Not ready until initialized
	}
}

// SetReady marks the application as ready
func (c *Checker) SetReady(ready bool) {
	if ready {
		atomic.StoreInt64(&c.ready, 1)
	} else {
		atomic.StoreInt64(&c.ready, 0)
	}
}

// SetAlive marks the application as alive
func (c *Checker) SetAlive(alive bool) {
	if alive {
		atomic.StoreInt64(&c.alive, 1)
	} else {
		atomic.StoreInt64(&c.alive, 0)
	}
}

// IsReady returns whether the application is ready
func (c *Checker) IsReady() bool {
	return atomic.LoadInt64(&c.ready) == 1
}

// IsAlive returns whether the application is alive
func (c *Checker) IsAlive() bool {
	return atomic.LoadInt64(&c.alive) == 1
}

// GetStatus returns the current health status
func (c *Checker) GetStatus() Status {
	return Status{
		Ready:     c.IsReady(),
		Alive:     c.IsAlive(),
		Timestamp: time.Now().Unix(),
	}
}

// LivenessHandler handles Kubernetes liveness probes
// This checks if the application is running and not deadlocked
func (c *Checker) LivenessHandler(w http.ResponseWriter, r *http.Request) {
	if c.IsAlive() {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	} else {
		w.WriteHeader(http.StatusServiceUnavailable)
		w.Write([]byte("Not alive"))
	}
}

// ReadinessHandler handles Kubernetes readiness probes
// This checks if the application is ready to serve traffic
func (c *Checker) ReadinessHandler(w http.ResponseWriter, r *http.Request) {
	if c.IsReady() {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Ready"))
	} else {
		w.WriteHeader(http.StatusServiceUnavailable)
		w.Write([]byte("Not ready"))
	}
}

// HealthHandler provides detailed health information in JSON format
func (c *Checker) HealthHandler(w http.ResponseWriter, r *http.Request) {
	status := c.GetStatus()

	if status.Ready && status.Alive {
		w.WriteHeader(http.StatusOK)
	} else {
		w.WriteHeader(http.StatusServiceUnavailable)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(status)
}
