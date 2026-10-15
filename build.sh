#!/bin/bash
# Build everything: Debian debs, Ubuntu debs and the source packages.
# Usage: ./build.sh <kitty_version> <build_version> [amd64|arm64|all]
set -euo pipefail
./build_debian.sh "$1" "$2" "${3:-all}"
./build_ubuntu.sh "$1" "$2" "${3:-all}"
./build_src.sh "$1" "$2"
