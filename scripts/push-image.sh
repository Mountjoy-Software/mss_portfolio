#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
REPOSITORY="mss-portfolio-backend"
TAG="${1:-$(git rev-parse HEAD)}"

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE="${REGISTRY}/${REPOSITORY}:${TAG}"

aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

docker build --build-arg "APP_VERSION=${TAG}" --tag "$IMAGE" \
  "$(dirname "$0")/../backend"
docker push "$IMAGE"

echo "pushed ${IMAGE}"
echo "deploy it with: npx aws-cdk deploy --all -c image_tag=${TAG}"
