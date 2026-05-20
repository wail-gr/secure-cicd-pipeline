#!/bin/bash
# =============================================================================
# setup-gcp.sh — Bootstrap GCP project for CI/CD pipeline
# =============================================================================
# Creates Artifact Registry repo, enables APIs, and sets up service account.
# Usage: ./scripts/setup-gcp.sh <PROJECT_ID> <REGION>
# =============================================================================

set -euo pipefail

PROJECT_ID="${1:?Usage: $0 <PROJECT_ID> <REGION>}"
REGION="${2:-us-central1}"
REPO_NAME="secure-cicd"
SERVICE_NAME="secure-api"
SA_NAME="github-actions-deployer"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "============================================"
echo "  GCP Project Setup"
echo "============================================"
echo "  Project:  ${PROJECT_ID}"
echo "  Region:   ${REGION}"
echo "  Repo:     ${REPO_NAME}"
echo "============================================"
echo ""

# Set project
gcloud config set project "${PROJECT_ID}"

# ---------------------------------------------------------------------------
# 1. Enable required APIs
# ---------------------------------------------------------------------------
echo "→ Enabling GCP APIs..."
gcloud services enable \
    run.googleapis.com \
    artifactregistry.googleapis.com \
    cloudbuild.googleapis.com \
    compute.googleapis.com \
    iam.googleapis.com \
    --quiet

echo "  ✓ APIs enabled"

# ---------------------------------------------------------------------------
# 2. Create Artifact Registry repository
# ---------------------------------------------------------------------------
echo "→ Creating Artifact Registry repository..."
gcloud artifacts repositories create "${REPO_NAME}" \
    --repository-format=docker \
    --location="${REGION}" \
    --description="Docker images for secure CI/CD pipeline" \
    --quiet 2>/dev/null || echo "  ℹ Repository already exists"

echo "  ✓ Artifact Registry: ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}"

# ---------------------------------------------------------------------------
# 3. Create service account for GitHub Actions
# ---------------------------------------------------------------------------
echo "→ Creating service account for GitHub Actions..."
gcloud iam service-accounts create "${SA_NAME}" \
    --display-name="GitHub Actions Deployer" \
    --description="Service account for CI/CD deployments from GitHub Actions" \
    --quiet 2>/dev/null || echo "  ℹ Service account already exists"

echo "  ✓ Service account: ${SA_EMAIL}"

# ---------------------------------------------------------------------------
# 4. Grant required IAM roles
# ---------------------------------------------------------------------------
echo "→ Granting IAM roles..."

ROLES=(
    "roles/run.admin"
    "roles/artifactregistry.writer"
    "roles/iam.serviceAccountUser"
    "roles/storage.admin"
)

for ROLE in "${ROLES[@]}"; do
    gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:${SA_EMAIL}" \
        --role="${ROLE}" \
        --quiet > /dev/null
    echo "  ✓ Granted: ${ROLE}"
done

# ---------------------------------------------------------------------------
# 5. Generate service account key (for GitHub Secrets)
# ---------------------------------------------------------------------------
KEY_FILE="sa-key-${SA_NAME}.json"
echo "→ Generating service account key..."
gcloud iam service-accounts keys create "${KEY_FILE}" \
    --iam-account="${SA_EMAIL}" \
    --quiet

echo "  ✓ Key saved to: ${KEY_FILE}"
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo ""
echo "  Add these GitHub Secrets to your repository:"
echo ""
echo "    GCP_PROJECT_ID = ${PROJECT_ID}"
echo "    GCP_REGION     = ${REGION}"
echo "    GCP_AR_REPO    = ${REPO_NAME}"
echo "    GCP_SA_KEY     = $(base64 -w0 ${KEY_FILE})"
echo ""
echo "  ⚠  Delete the key file after adding to GitHub:"
echo "    rm ${KEY_FILE}"
echo ""
echo "============================================"
