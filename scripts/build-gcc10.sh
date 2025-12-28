#!/bin/bash
#
# Build GCC 10 on Debian Buster (ARM64 host)
# Maintains glibc 2.28 compatibility by using Buster's sysroot
#
# Builds:
# - Native GCC 10 (for ARM64 cores - native compilation)
# - arm-linux-gnueabihf-gcc-10 (for ARM32 cores - cross-compilation)
#

set -e

GCC_VERSION="10.5.0"
BINUTILS_VERSION="2.36.1"
INSTALL_PREFIX="/opt/gcc-10"
BUILD_DIR="/tmp/gcc-build"
JOBS="${JOBS:-$(nproc)}"

log() { echo "=== $1 ==="; }

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

log "Installing build dependencies"
apt-get update
apt-get install -y --no-install-recommends \
    wget xz-utils bzip2 \
    make autoconf automake \
    gcc g++ \
    libgmp-dev libmpfr-dev libmpc-dev libisl-dev \
    texinfo flex bison file

# Download sources with checksum verification (using GNU ftpmirror for reliability)
log "Downloading GCC $GCC_VERSION"
if [ ! -f "gcc-$GCC_VERSION.tar.xz" ]; then
    wget -q "https://ftpmirror.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz"
    echo "d86dbc18b978771531f4039465e7eb7c19845bf607dc513c97abf8e45ffe1086a99d98f83dfb7b37204af22431574186de9d5ff80c8c3c3a98dbe3983195bffd  gcc-$GCC_VERSION.tar.xz" | sha512sum -c -
fi
tar xf "gcc-$GCC_VERSION.tar.xz"

log "Downloading binutils $BINUTILS_VERSION"
if [ ! -f "binutils-$BINUTILS_VERSION.tar.xz" ]; then
    wget -q "https://ftpmirror.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.xz"
    echo "cc24590bcead10b90763386b6f96bb027d7594c659c2d95174a6352e8b98465a50ec3e4088d0da038428abe059bbc4ae5f37b269f31a40fc048072c8a234f4e9  binutils-$BINUTILS_VERSION.tar.xz" | sha512sum -c -
fi
tar xf "binutils-$BINUTILS_VERSION.tar.xz"

# Build native GCC 10 (used for ARM64 cores)
log "Building native GCC $GCC_VERSION (for ARM64 cores)"
mkdir -p build-gcc-native && cd build-gcc-native

../gcc-$GCC_VERSION/configure \
    --prefix="$INSTALL_PREFIX" \
    --enable-languages=c,c++ \
    --disable-multilib \
    --disable-bootstrap \
    --disable-nls \
    --with-system-zlib \
    --enable-shared \
    --enable-threads=posix \
    --enable-__cxa_atexit \
    --enable-clocale=gnu

make -j"$JOBS"
make install
cd ..

# Use new GCC for building cross-compiler
export PATH="$INSTALL_PREFIX/bin:$PATH"
export CC="$INSTALL_PREFIX/bin/gcc"
export CXX="$INSTALL_PREFIX/bin/g++"

# Build binutils for ARM32
log "Building binutils for arm-linux-gnueabihf"
mkdir -p build-binutils-arm32 && cd build-binutils-arm32

../binutils-$BINUTILS_VERSION/configure \
    --prefix="$INSTALL_PREFIX" \
    --target=arm-linux-gnueabihf \
    --with-sysroot=/ \
    --disable-nls \
    --disable-werror

make -j"$JOBS"
make install
cd ..

# Build GCC cross-compiler for ARM32
# Use system root (/) as sysroot - Debian multiarch will handle finding armhf headers/libs
log "Building GCC cross-compiler for arm-linux-gnueabihf (for ARM32 cores)"
mkdir -p build-gcc-arm32 && cd build-gcc-arm32

../gcc-$GCC_VERSION/configure \
    --prefix="$INSTALL_PREFIX" \
    --target=arm-linux-gnueabihf \
    --with-sysroot=/ \
    --enable-languages=c,c++ \
    --disable-multilib \
    --disable-nls \
    --disable-libsanitizer \
    --enable-shared \
    --enable-threads=posix \
    --enable-__cxa_atexit \
    --enable-clocale=gnu \
    --with-gnu-as \
    --with-gnu-ld \
    --with-float=hard \
    --with-arch=armv7-a \
    --with-fpu=vfpv4-d16

make -j"$JOBS"
make install
cd ..

# Verify
log "Verifying installation"
echo "Native GCC 10 (for ARM64):"
"$INSTALL_PREFIX/bin/gcc" --version | head -1
echo ""
echo "ARM32 cross-compiler:"
"$INSTALL_PREFIX/bin/arm-linux-gnueabihf-gcc" --version | head -1

# Cleanup
log "Cleaning up"
cd /
rm -rf "$BUILD_DIR"

log "Done! GCC $GCC_VERSION installed to $INSTALL_PREFIX"
echo ""
echo "Compilers:"
echo "  ARM64: $INSTALL_PREFIX/bin/gcc"
echo "  ARM32: $INSTALL_PREFIX/bin/arm-linux-gnueabihf-gcc"
