// Package main is the entrypoint for the secure API server.
// Build metadata (version, commit, build time) is injected at compile-time
// via -ldflags in the Dockerfile and CI/CD pipeline.
package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/wail-gr/secure-cicd-pipeline/internal/handler"
	"github.com/wail-gr/secure-cicd-pipeline/internal/middleware"
	"go.uber.org/zap"
)

// Build metadata — injected via ldflags at compile time
var (
	version   = "dev"
	commitSHA = "unknown"
	buildTime = "unknown"
)

func main() {
	// Initialize structured logger
	logger, err := initLogger()
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to initialize logger: %v\n", err)
		os.Exit(1)
	}
	defer logger.Sync()

	logger.Info("starting server",
		zap.String("version", version),
		zap.String("commit", commitSHA),
		zap.String("build_time", buildTime),
	)

	// Resolve port from environment (Cloud Run sets PORT)
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Initialize handlers
	h := handler.New(logger, version, commitSHA, buildTime)

	// Build router
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", h.HealthCheck)
	mux.HandleFunc("GET /ready", h.ReadinessCheck)
	mux.HandleFunc("GET /version", h.Version)
	mux.HandleFunc("GET /", h.Root)

	// Apply middleware chain
	chain := middleware.Chain(
		mux,
		middleware.RequestID,
		middleware.Logging(logger),
		middleware.Recovery(logger),
		middleware.SecurityHeaders,
	)

	// Configure HTTP server
	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           chain,
		ReadTimeout:       15 * time.Second,
		ReadHeaderTimeout: 5 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    1 << 20, // 1MB
	}

	// Start server in goroutine
	go func() {
		logger.Info("server listening", zap.String("port", port))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("server failed", zap.Error(err))
		}
	}()

	// Graceful shutdown on SIGTERM/SIGINT (Cloud Run sends SIGTERM)
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	sig := <-quit

	logger.Info("shutdown signal received", zap.String("signal", sig.String()))

	// Give in-flight requests 30 seconds to complete
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.Error("server forced shutdown", zap.Error(err))
		os.Exit(1)
	}

	logger.Info("server stopped gracefully")
}

// initLogger creates a production or development logger based on ENVIRONMENT.
func initLogger() (*zap.Logger, error) {
	env := os.Getenv("ENVIRONMENT")
	if env == "production" {
		return zap.NewProduction()
	}
	return zap.NewDevelopment()
}
