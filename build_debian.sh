#!/bin/bash
# Build the kitty binary packages (.deb), one set for every suite. Nothing is
# compiled (upstream's bundle is repackaged), so the per-suite builds differed
# only in their ~<suite> version suffix. The fixed ~griffo keeps it below the
# distro's own build of the same version.
#
# Produces, in ./out :
#   kitty_<ver>-<build>~griffo_<arch>.deb            (amd64, arm64)
#   kitty-terminfo_<ver>-<build>~griffo_all.deb
#   kitty-shell-integration_<ver>-<build>~griffo_all.deb
#   kitty-doc_<ver>-<build>~griffo_all.deb
#
# The arch:all packages are built once, by the first architecture of the run.
# Set SKIP_ARCH_ALL=1 to never build them (CI does this for the arm64 job,
# whose amd64 sibling already produces them).
#
# Usage: ./build_debian.sh <kitty_version> <build_version> [amd64|arm64|all]
set -euo pipefail

VERSION="${1:-}"
BUILD="${2:-}"
ARCH="${3:-all}"
if [ -z "$VERSION" ] || [ -z "$BUILD" ]; then
    echo "Usage: $0 <kitty_version> <build_version> [amd64|arm64|all]" >&2
    echo "Example: $0 0.49.2 1 all" >&2
    exit 1
fi

FULL_VERSION="${VERSION}-${BUILD}~griffo"

case "$ARCH" in
    all)   ARCHES=("amd64" "arm64") ;;
    amd64|arm64) ARCHES=("$ARCH") ;;
    *) echo "❌ Unsupported architecture: $ARCH (upstream publishes amd64 and arm64 bundles only)" >&2; exit 1 ;;
esac

# Upstream names the bundles by CPU, with mixed spelling: x86_64 but arm64.
bundle_arch() {
    case "$1" in
        amd64) echo "x86_64" ;;
        arm64) echo "arm64" ;;
    esac
}

mkdir -p out

BUILD_TYPE="-b"
[ "${SKIP_ARCH_ALL:-}" = "1" ] && BUILD_TYPE="-B"

for arch in "${ARCHES[@]}"; do
    TARBALL="kitty-${VERSION}-$(bundle_arch "$arch").txz"
    # Download on the host; the Dockerfile COPYs it into the build so
    # debian/rules does not fetch it again.
    if [ ! -f "$TARBALL" ]; then
        echo "==> Downloading $TARBALL"
        wget -q "https://github.com/kovidgoyal/kitty/releases/download/v${VERSION}/${TARBALL}"
    fi

    echo "==> Building kitty ${FULL_VERSION} (${arch}, dpkg-buildpackage ${BUILD_TYPE})"

    # Generate the changelog (overwrites the placeholder).
    cat > debian/changelog << EOC
kitty (${FULL_VERSION}) stable; urgency=medium

  * New upstream release ${VERSION}.

 -- Dario Griffo <dariogriffo@gmail.com>  $(date -R)
EOC

    docker build -t "kitty-${arch}" \
        --build-arg "ARCH=${arch}" \
        --build-arg "BUILD_TYPE=${BUILD_TYPE}" \
        -f Dockerfile .

    cid="$(docker create "kitty-${arch}")"
    docker cp "${cid}:/out/." ./out/
    docker rm "${cid}" > /dev/null

    # Later architectures in this run only need the arch-dependent package
    BUILD_TYPE="-B"
done

echo ""
echo "Built packages:"
ls -la out/kitty*.deb
