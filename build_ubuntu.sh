#!/bin/bash
# Build the kitty binary packages (.deb) for each Ubuntu suite, using a
# per-suite Docker image so the packages are assembled with that suite's
# dpkg/debhelper.
#
# Produces, per suite, in ./out :
#   kitty_<ver>-<build>~<dist>_<arch>_ubu.deb        (amd64, arm64)
#   kitty-terminfo_<ver>-<build>~<dist>_all_ubu.deb
#   kitty-shell-integration_<ver>-<build>~<dist>_all_ubu.deb
#   kitty-doc_<ver>-<build>~<dist>_all_ubu.deb
#
# The arch:all packages are built once, by the first architecture of the run.
# Set SKIP_ARCH_ALL=1 to never build them (CI does this for the arm64 job,
# whose amd64 sibling already produces them).
#
# Usage: ./build_ubuntu.sh <kitty_version> <build_version> [amd64|arm64|all]
set -euo pipefail

VERSION="${1:-}"
BUILD="${2:-}"
ARCH="${3:-all}"
if [ -z "$VERSION" ] || [ -z "$BUILD" ]; then
    echo "Usage: $0 <kitty_version> <build_version> [amd64|arm64|all]" >&2
    echo "Example: $0 0.49.2 1 all" >&2
    exit 1
fi

DISTS=("jammy" "noble" "questing" "resolute")

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
    # Download once per architecture; the Dockerfile COPYs it into every
    # suite's build so debian/rules does not fetch it 4 times.
    if [ ! -f "$TARBALL" ]; then
        echo "==> Downloading $TARBALL"
        wget -q "https://github.com/kovidgoyal/kitty/releases/download/v${VERSION}/${TARBALL}"
    fi

    for dist in "${DISTS[@]}"; do
        FULL_VERSION="${VERSION}-${BUILD}~${dist}"
        echo "==> Building kitty ${FULL_VERSION} (${dist}, ${arch}, dpkg-buildpackage ${BUILD_TYPE})"

        # Generate the distribution-specific changelog (overwrites the placeholder).
        cat > debian/changelog << EOC
kitty (${FULL_VERSION}) ${dist}; urgency=medium

  * New upstream release ${VERSION}.

 -- Dario Griffo <dariogriffo@gmail.com>  $(date -R)
EOC

        docker build -t "kitty-ubuntu-${dist}-${arch}" \
            --build-arg "DIST=${dist}" \
            --build-arg "ARCH=${arch}" \
            --build-arg "BUILD_TYPE=${BUILD_TYPE}" \
            -f Dockerfile.ubu .

        cid="$(docker create "kitty-ubuntu-${dist}-${arch}")"
        docker cp "${cid}:/out/." ./out/
        docker rm "${cid}" > /dev/null

        # The mirror's download_ubuntu_file.sh looks for a _ubu.deb suffix,
        # which dpkg-buildpackage doesn't produce. Rename only THIS suite's
        # fresh debs (matched by ~<dist>_), skipping any already renamed.
        for f in out/kitty*~"${dist}"_*.deb; do
            case "$f" in
                *_ubu.deb) ;;
                *) mv "$f" "${f%.deb}_ubu.deb" ;;
            esac
        done
    done

    # Later architectures in this run only need the arch-dependent package
    BUILD_TYPE="-B"
done

echo ""
echo "Built packages:"
ls -la out/kitty*_ubu.deb
