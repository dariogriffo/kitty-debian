#!/bin/bash
# Build everything: the debs and the source package.
# Usage: ./build.sh <kitty_version> <build_version> [amd64|arm64|all]
set -euo pipefail
./build_debian.sh "$1" "$2" "${3:-all}"
./build_src.sh "$1" "$2"
