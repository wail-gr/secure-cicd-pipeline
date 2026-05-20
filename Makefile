# =============================================================================
# Makefile — Developer Commands
# =============================================================================

.PHONY: all build run test lint docker-build docker-run hadolint clean help

# Default target
all: lint test build

# ---------------------------------------------------------------------------
# Go Commands
# ---------------------------------------------------------------------------

## Build the server binary
build:
	@echo "→ Building server..."
	CGO_ENABLED=0 go build -trimpath -o bin/server ./cmd/server/
	@echo "✓ Binary: bin/server"

## Run the server locally
run:
	@echo "→ Starting server on :8080..."
	go run ./cmd/server/

## Run tests with race detection and coverage
test:
	@echo "→ Running tests..."
	go test -v -race -coverprofile=coverage.out ./...
	go tool cover -func=coverage.out | grep total

## Run linters (go vet + staticcheck)
lint:
	@echo "→ Running go vet..."
	go vet ./...
	@echo "→ Running staticcheck..."
	staticcheck ./... || echo "⚠ Install: go install honnef.co/go/tools/cmd/staticcheck@latest"

## Format all Go files
fmt:
	gofmt -w .

# ---------------------------------------------------------------------------
# Docker Commands
# ---------------------------------------------------------------------------

## Build production Docker image
docker-build:
	@echo "→ Building production image..."
	docker build \
		--build-arg VERSION=local \
		--build-arg COMMIT_SHA=$$(git rev-parse --short HEAD) \
		--build-arg BUILD_TIME=$$(date -u +%Y-%m-%dT%H:%M:%SZ) \
		-t secure-api:latest \
		.
	@echo ""
	@docker images secure-api:latest --format "✓ Image: {{.Repository}}:{{.Tag}} ({{.Size}})"

## Run the container locally
docker-run: docker-build
	@echo "→ Starting container on :8080..."
	docker run --rm -p 8080:8080 \
		-e ENVIRONMENT=development \
		-e LOG_LEVEL=debug \
		secure-api:latest

## Lint Dockerfile with Hadolint
hadolint:
	@echo "→ Linting Dockerfile..."
	hadolint Dockerfile
	@echo "✓ Dockerfile passed"

## Run full local CI (mirrors GitHub Actions)
ci: lint test docker-build hadolint
	@echo ""
	@echo "✓ All CI checks passed"

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

## Remove build artifacts
clean:
	rm -rf bin/ coverage.out
	docker rmi secure-api:latest 2>/dev/null || true

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

## Show this help message
help:
	@echo "Available targets:"
	@echo ""
	@grep -E '^## ' Makefile | sed 's/^## /  /'
	@echo ""
	@grep -E '^[a-zA-Z_-]+:' Makefile | sed 's/:.*//' | sort | sed 's/^/  make /'
