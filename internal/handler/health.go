package handler

import (
	"net/http"
	"runtime"
	"time"
)

// HealthCheck handles GET /health — used by Cloud Run and Load Balancer probes.
func (h *Handler) HealthCheck(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, Response{
		Status: "healthy",
		Data: map[string]interface{}{
			"uptime":     time.Since(h.startTime).String(),
			"goroutines": runtime.NumGoroutine(),
			"timestamp":  time.Now().UTC().Format(time.RFC3339),
		},
	})
}

// ReadinessCheck handles GET /ready — indicates the service is ready to accept traffic.
func (h *Handler) ReadinessCheck(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, Response{
		Status:  "ready",
		Message: "service is ready to accept traffic",
	})
}

// Version handles GET /version — returns build metadata.
func (h *Handler) Version(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, Response{
		Status: "ok",
		Data: map[string]string{
			"version":    h.version,
			"commit_sha": h.commitSHA,
			"build_time": h.buildTime,
			"go_version": runtime.Version(),
			"os_arch":    runtime.GOOS + "/" + runtime.GOARCH,
		},
	})
}
