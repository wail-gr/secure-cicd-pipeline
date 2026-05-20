// Package handler provides HTTP route handlers for the API.
package handler

import (
	"encoding/json"
	"net/http"
	"time"

	"go.uber.org/zap"
)

// Handler holds dependencies for HTTP handlers.
type Handler struct {
	logger    *zap.Logger
	version   string
	commitSHA string
	buildTime string
	startTime time.Time
}

// New creates a new Handler with the given dependencies.
func New(logger *zap.Logger, version, commitSHA, buildTime string) *Handler {
	return &Handler{
		logger:    logger,
		version:   version,
		commitSHA: commitSHA,
		buildTime: buildTime,
		startTime: time.Now(),
	}
}

// Response is a generic JSON response envelope.
type Response struct {
	Status  string      `json:"status"`
	Message string      `json:"message,omitempty"`
	Data    interface{} `json:"data,omitempty"`
}

// Root handles GET / requests.
func (h *Handler) Root(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, Response{
		Status:  "ok",
		Message: "Secure CI/CD Pipeline API",
		Data: map[string]string{
			"version":    h.version,
			"docs":       "/health, /ready, /version",
			"repository": "https://github.com/wail-gr/secure-cicd-pipeline",
		},
	})
}

// writeJSON marshals data to JSON and writes it to the response.
func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}
