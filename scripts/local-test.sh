#!/bin/bash
# =============================================================================
# local-test.sh — Run all checks locally (mirrors CI pipeline)
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
    local name="$1"
    shift
    echo -e "${YELLOW}→ ${name}${NC}"
    if "$@" 2>&1; then
        echo -e "${GREEN}  ✓ ${name} passed${NC}\n"
        ((PASS++))
    else
        echo -e "${RED}  ✗ ${name} failed${NC}\n"
        ((FAIL++))
    fi
}

echo "============================================"
echo "  Local CI Check Suite"
echo "============================================"
echo ""

# Go checks
check "go vet"        go vet ./...
check "go fmt check"  bash -c 'test -z "$(gofmt -l .)"'
check "go test"       go test -v -race -cover ./...
check "go build"      go build -o /dev/null ./cmd/server/

# Docker checks
if command -v hadolint &> /dev/null; then
    check "hadolint" hadolint Dockerfile
else
    echo -e "${YELLOW}  ⚠ hadolint not installed, skipping${NC}\n"
fi

if command -v docker &> /dev/null; then
    check "docker build" docker build -t secure-api:local-test --target production .
    
    # Check image size
    SIZE=$(docker images secure-api:local-test --format "{{.Size}}")
    echo -e "  📦 Image size: ${SIZE}\n"
else
    echo -e "${YELLOW}  ⚠ docker not installed, skipping build${NC}\n"
fi

# Summary
echo "============================================"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "============================================"

exit $FAIL
