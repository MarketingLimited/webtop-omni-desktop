#!/bin/bash

# Fast build script with optimizations
set -e

echo "🚀 Starting optimized Docker build..."

# Enable BuildKit for better caching and parallelization
export DOCKER_BUILDKIT=1

# Build arguments
TARGET="${1:-production}"
CACHE_FROM=""

# Check if we have existing images to use as cache
if docker image inspect webtop-kde-base >/dev/null 2>&1; then
    CACHE_FROM="--cache-from webtop-kde-base"
fi

echo "📦 Building target: $TARGET"

# Build with optimizations
docker build \
    --file Dockerfile.optimized \
    --target "$TARGET" \
    --tag "webtop-kde:$TARGET" \
    --tag "webtop-kde:latest" \
    $CACHE_FROM \
    --progress=plain \
    .

echo "✅ Build completed for target: $TARGET"

# Tag the base stage for future cache usage
docker tag webtop-kde:$TARGET webtop-kde-base 2>/dev/null || true

echo "🎉 Build completed! Use 'docker-compose up' to start the container."