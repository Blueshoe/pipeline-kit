#!/bin/bash
# =============================================================================
# Registry Login
# =============================================================================
# Authenticates to a container registry so Docker can pull the image.
#
# Supported registry types:
#   quay    - Quay.io (uses REGISTRY_USERNAME + REGISTRY_PASSWORD)
#   ecr     - AWS ECR (uses AWS credentials + region)
#   generic - Any Docker-compatible registry (uses REGISTRY_USERNAME + REGISTRY_PASSWORD)
#
# Required env vars:
#   CONTAINER_IMAGE  - Full image reference (used to derive registry host)
#   REGISTRY_TYPE    - quay, ecr, or generic
#
# Conditional env vars (depending on REGISTRY_TYPE):
#   REGISTRY_USERNAME / REGISTRY_PASSWORD  - for quay and generic
#   AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_REGION - for ecr
# =============================================================================

set -e

echo "::group::Registry login"

# Extract registry host from image reference (everything before the first /)
REGISTRY_HOST="${CONTAINER_IMAGE%%/*}"
echo "Registry host: $REGISTRY_HOST"
echo "Registry type: $REGISTRY_TYPE"

case "$REGISTRY_TYPE" in

  quay)
    if [[ -z "$REGISTRY_USERNAME" || -z "$REGISTRY_PASSWORD" ]]; then
      echo "::error::Quay login requires registry-username and registry-password"
      exit 1
    fi
    echo "$REGISTRY_PASSWORD" | docker login quay.io -u "$REGISTRY_USERNAME" --password-stdin
    echo "Logged in to quay.io"
    ;;

  ecr)
    if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" ]]; then
      echo "::error::ECR login requires aws-access-key-id and aws-secret-access-key"
      exit 1
    fi

    # Extract ECR registry URL from image (e.g. 325385077232.dkr.ecr.eu-central-1.amazonaws.com)
    ECR_REGISTRY="$REGISTRY_HOST"
    echo "ECR registry: $ECR_REGISTRY"

    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_DEFAULT_REGION="${AWS_REGION:-eu-central-1}"

    # Get ECR login password and pipe to docker login
    aws ecr get-login-password --region "$AWS_DEFAULT_REGION" \
      | docker login "$ECR_REGISTRY" -u AWS --password-stdin
    echo "Logged in to ECR ($ECR_REGISTRY)"
    ;;

  generic)
    if [[ -z "$REGISTRY_USERNAME" || -z "$REGISTRY_PASSWORD" ]]; then
      echo "No credentials provided — assuming public image, skipping login"
      echo "::endgroup::"
      exit 0
    fi
    echo "$REGISTRY_PASSWORD" | docker login "$REGISTRY_HOST" -u "$REGISTRY_USERNAME" --password-stdin
    echo "Logged in to $REGISTRY_HOST"
    ;;

  *)
    echo "::error::Unknown registry type: $REGISTRY_TYPE (expected: quay, ecr, generic)"
    exit 1
    ;;
esac

echo "::endgroup::"
