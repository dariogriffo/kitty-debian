#!/bin/bash
# Build the *source* package (.dsc + .orig.tar.gz + .debian.tar.xz), one for
# every suite, for upload to deb.griffo.io. The upstream kitty source
# archive is used as the .orig tarball; the shipped payload is upstream's
# prebuilt bundle, fetched by debian/rules at build time.
#
# Usage: ./build_src.sh <kitty_version> <build_version>
set -euo pipefail

VERSION="${1:-}"
BUILD="${2:-}"
if [ -z "$VERSION" ] || [ -z "$BUILD" ]; then
    echo "Usage: $0 <kitty_version> <build_version>" >&2
    echo "Example: $0 0.49.2 1" >&2
    exit 1
fi

PACKAGE_NAME="kitty"
ORIG_TARBALL="${PACKAGE_NAME}_${VERSION}.orig.tar.gz"
BUILD_DIR="${PACKAGE_NAME}-${VERSION}"

# --- Shared .orig.tar.gz: the upstream source archive for tag v<VERSION> -----
# GitHub's archive of tag "v<VERSION>" extracts to "kitty-<VERSION>/", which is
# exactly the "<source>-<version>/" layout dpkg-source expects.
# A rebuild of an upstream version already released here (a +N build bump)
# must ship the very same orig tarball: the pool holds one per upstream
# version and reprepro refuses a different one, and nothing guarantees the
# archive download is byte-identical next time. Reuse the earlier release's copy.
if [ ! -f "$ORIG_TARBALL" ]; then
    for ((b = BUILD - 1; b >= 1; b--)); do
        if wget -q "https://github.com/dariogriffo/kitty-debian/releases/download/${VERSION}%2B${b}/${ORIG_TARBALL}" -O "$ORIG_TARBALL"; then
            echo "  Reusing $ORIG_TARBALL from release ${VERSION}+${b}"
            break
        fi
        rm -f "$ORIG_TARBALL"
    done
fi

if [ ! -f "$ORIG_TARBALL" ]; then
    echo "Downloading upstream source for v${VERSION}..."
    wget -q "https://github.com/kovidgoyal/kitty/archive/refs/tags/v${VERSION}.tar.gz" \
        -O "$ORIG_TARBALL"
    echo "  Saved as $ORIG_TARBALL"
else
    echo "  Using existing $ORIG_TARBALL"
fi

build_source_package() {
    local FULL_VERSION="${VERSION}-${BUILD}~griffo"
    echo "  Building source package ${FULL_VERSION}..."

    rm -rf "$BUILD_DIR"
    tar -xf "$ORIG_TARBALL"
    cp -r debian "$BUILD_DIR/"

    cat > "$BUILD_DIR/debian/changelog" << EOC
kitty (${FULL_VERSION}) stable; urgency=medium

  * New upstream release ${VERSION}.

 -- Dario Griffo <dariogriffo@gmail.com>  $(date -R)
EOC

    dpkg-source -b "$BUILD_DIR"
    rm -rf "$BUILD_DIR"
}

echo ""
# One source package for every suite, as with the binaries (see build_debian.sh).
build_source_package

echo ""
echo "Source package created:"
ls -la "${PACKAGE_NAME}_"*.dsc "${PACKAGE_NAME}_"*.orig.tar.gz "${PACKAGE_NAME}_"*.debian.tar.xz 2>/dev/null || true
