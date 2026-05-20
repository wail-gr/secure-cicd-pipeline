# =============================================================================
# Multi-Stage Production Dockerfile — Distroless Final Image
# =============================================================================
# Stage 1: Dependency resolution (cached by go.sum hash)
# Stage 2: Static binary compilation (CGO_ENABLED=0)
# Stage 3: Distroless production image (no shell, no pkg mgr)
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Dependencies — cached unless go.mod/go.sum change
# ---------------------------------------------------------------------------
FROM golang:1.23-bookworm AS deps

WORKDIR /app

# Copy only dependency files first (maximizes cache reuse)
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# ---------------------------------------------------------------------------
# Stage 2: Build — static binary with no CGO dependencies
# ---------------------------------------------------------------------------
FROM deps AS builder

WORKDIR /app

# Copy source code
COPY . .

# Build static binary
# CGO_ENABLED=0: pure Go binary, no libc dependency
# -ldflags: strip debug info & set version metadata
# -trimpath: remove local file paths from binary (security)
ARG VERSION=dev
ARG COMMIT_SHA=unknown
ARG BUILD_TIME=unknown

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w \
        -X main.version=${VERSION} \
        -X main.commitSHA=${COMMIT_SHA} \
        -X main.buildTime=${BUILD_TIME}" \
    -trimpath \
    -o /app/server \
    ./cmd/server/

# Verify the binary is statically linked
RUN file /app/server | grep -q "statically linked" && \
    echo "✓ Static binary verified" || \
    echo "⚠ Binary may have dynamic dependencies"

# ---------------------------------------------------------------------------
# Stage 3: Production — Google Distroless (no shell, no OS packages)
# ---------------------------------------------------------------------------
FROM gcr.io/distroless/static-debian12:nonroot AS production

# Labels for container registry metadata
LABEL maintainer="wail-gr"
LABEL org.opencontainers.image.title="secure-cicd-pipeline"
LABEL org.opencontainers.image.description="Hardened API service running on Distroless"
LABEL org.opencontainers.image.source="https://github.com/wail-gr/secure-cicd-pipeline"

# Copy only the compiled binary from builder
COPY --from=builder --chown=nonroot:nonroot /app/server /server

# Expose application port
EXPOSE 8080

# Run as non-root user (UID 65534)
USER nonroot:nonroot

# Health check not available in Distroless (no shell)
# Cloud Run handles health checks via HTTP probe

# Start the application
ENTRYPOINT ["/server"]
