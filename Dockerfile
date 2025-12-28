# Docker image for building libretro cores
# Uses Debian Buster for glibc 2.28 compatibility
# Builds GCC 10.5.0 for modern C++ support while maintaining ABI compatibility
#
# Host: ARM64 (aarch64)
# Compilation targets: ARM64 (native), ARM32 (cross-compilation)

FROM debian/eol:buster-slim AS gcc-builder

ENV DEBIAN_FRONTEND=noninteractive

# Install GCC build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget xz-utils bzip2 \
    make autoconf automake \
    gcc g++ \
    libgmp-dev libmpfr-dev libmpc-dev libisl-dev \
    zlib1g-dev \
    texinfo flex bison file \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# GCC 10.5.0 build configuration
ENV GCC_VERSION=10.5.0 \
    BINUTILS_VERSION=2.36.1 \
    INSTALL_PREFIX=/opt/gcc-10

WORKDIR /build

# Download sources with checksum verification (using GNU ftpmirror for reliability)
RUN wget -q "https://ftpmirror.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz" && \
    echo "d86dbc18b978771531f4039465e7eb7c19845bf607dc513c97abf8e45ffe1086a99d98f83dfb7b37204af22431574186de9d5ff80c8c3c3a98dbe3983195bffd  gcc-${GCC_VERSION}.tar.xz" | sha512sum -c - && \
    wget -q "https://ftpmirror.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz" && \
    echo "cc24590bcead10b90763386b6f96bb027d7594c659c2d95174a6352e8b98465a50ec3e4088d0da038428abe059bbc4ae5f37b269f31a40fc048072c8a234f4e9  binutils-${BINUTILS_VERSION}.tar.xz" | sha512sum -c - && \
    tar xf gcc-${GCC_VERSION}.tar.xz && \
    tar xf binutils-${BINUTILS_VERSION}.tar.xz

# Build native GCC 10 (for ARM64 cores)
RUN mkdir build-gcc-native && cd build-gcc-native && \
    ../gcc-${GCC_VERSION}/configure \
        --prefix=${INSTALL_PREFIX} \
        --enable-languages=c,c++ \
        --disable-multilib \
        --disable-bootstrap \
        --disable-nls \
        --with-system-zlib \
        --enable-shared \
        --enable-threads=posix \
        --enable-__cxa_atexit \
        --enable-clocale=gnu && \
    make -j$(nproc) && \
    make install

# Create aarch64-linux-gnu-* symlinks for native GCC
# (build system expects these names even for native compilation)
RUN cd ${INSTALL_PREFIX}/bin && \
    for tool in gcc g++ cpp gcov gcc-ar gcc-nm gcc-ranlib; do \
        ln -sf $tool aarch64-linux-gnu-$tool; \
    done && \
    ln -sf ${INSTALL_PREFIX}/bin/ar aarch64-linux-gnu-ar || true && \
    ln -sf ${INSTALL_PREFIX}/bin/as aarch64-linux-gnu-as || true && \
    ln -sf ${INSTALL_PREFIX}/bin/ld aarch64-linux-gnu-ld || true && \
    ln -sf ${INSTALL_PREFIX}/bin/nm aarch64-linux-gnu-nm || true && \
    ln -sf ${INSTALL_PREFIX}/bin/objcopy aarch64-linux-gnu-objcopy || true && \
    ln -sf ${INSTALL_PREFIX}/bin/objdump aarch64-linux-gnu-objdump || true && \
    ln -sf ${INSTALL_PREFIX}/bin/ranlib aarch64-linux-gnu-ranlib || true && \
    ln -sf ${INSTALL_PREFIX}/bin/readelf aarch64-linux-gnu-readelf || true && \
    ln -sf ${INSTALL_PREFIX}/bin/strip aarch64-linux-gnu-strip || true

# Set up environment for building cross-compiler
ENV PATH="${INSTALL_PREFIX}/bin:${PATH}" \
    CC="${INSTALL_PREFIX}/bin/gcc" \
    CXX="${INSTALL_PREFIX}/bin/g++"

# Build binutils for ARM32 cross-compilation
RUN mkdir build-binutils-arm32 && cd build-binutils-arm32 && \
    ../binutils-${BINUTILS_VERSION}/configure \
        --prefix=${INSTALL_PREFIX} \
        --target=arm-linux-gnueabihf \
        --with-sysroot=/usr/arm-linux-gnueabihf \
        --disable-nls \
        --disable-werror && \
    make -j$(nproc) && \
    make install

# Install ARM32 sysroot headers/libs for cross-compiler build
RUN apt-get update && \
    dpkg --add-architecture armhf && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libc6-dev:armhf \
        linux-libc-dev:armhf \
    && rm -rf /var/lib/apt/lists/*

# Build GCC 10 cross-compiler for ARM32
# Use system root (/) as sysroot - Debian multiarch will handle finding armhf headers/libs
RUN mkdir build-gcc-arm32 && cd build-gcc-arm32 && \
    ../gcc-${GCC_VERSION}/configure \
        --prefix=${INSTALL_PREFIX} \
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
        --with-fpu=vfpv4-d16 && \
    make -j$(nproc) && \
    make install

# Verify build
RUN echo "=== GCC 10 Build Complete ===" && \
    ${INSTALL_PREFIX}/bin/gcc --version | head -1 && \
    ${INSTALL_PREFIX}/bin/aarch64-linux-gnu-gcc --version | head -1 && \
    ${INSTALL_PREFIX}/bin/arm-linux-gnueabihf-gcc --version | head -1

# =============================================================================
# Final image
# =============================================================================
FROM debian/eol:buster-slim

ENV DEBIAN_FRONTEND=noninteractive

# Copy GCC 10 from builder
COPY --from=gcc-builder /opt/gcc-10 /opt/gcc-10

# Enable multiarch for ARM libraries
RUN dpkg --add-architecture armhf && \
    dpkg --add-architecture arm64

# Install ARM32 runtime libraries (needed to run 32-bit binaries on ARM64 hosts)
RUN apt-get update && apt-get install -y \
    libc6:armhf \
    libstdc++6:armhf \
    libgcc1:armhf \
    && rm -rf /var/lib/apt/lists/*

# Verify ARM32 runtime is available
RUN echo "=== ARM32 Runtime Check ===" && \
    ls -la /lib/ld-linux-armhf.so.3 && \
    echo "Dynamic linker exists."

# Install build tools and libretro core dependencies
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    build-essential \
    git \
    wget \
    curl \
    unzip \
    zip \
    make \
    cmake \
    ninja-build \
    nasm \
    yasm \
    patch \
    perl \
    pkg-config \
    python \
    python3 \
    python3-pip \
    ruby \
    ruby-dev \
    ccache \
    autoconf \
    automake \
    libtool \
    jq \
    bc \
    zlib1g-dev \
    zlib1g-dev:armhf \
    zlib1g-dev:arm64 \
    libpng-dev \
    liblzma-dev \
    libssl-dev \
    libglib2.0-dev \
    libx11-dev \
    mesa-common-dev \
    libglu1-mesa-dev \
    libgl1-mesa-dev \
    libgles2-mesa-dev \
    libasound2-dev \
    libc6-dev:armhf \
    libc6-dev:arm64 \
    linux-libc-dev:armhf \
    linux-libc-dev:arm64 \
    libgl1-mesa-dev:armhf \
    libgl1-mesa-dev:arm64 \
    libgles2-mesa-dev:armhf \
    libgles2-mesa-dev:arm64 \
    libattr1-dev \
    libattr1-dev:armhf \
    libattr1-dev:arm64 \
    libexpat1-dev \
    libicu-dev \
    libsdl2-dev \
    libsdl2-ttf-dev \
    libavcodec-dev \
    libavdevice-dev \
    libavfilter-dev \
    libavformat-dev \
    libavutil-dev \
    libswresample-dev \
    libswscale-dev \
    libpostproc-dev \
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev \
    && rm -rf /var/lib/apt/lists/*

# Create symlinks for native binutils tools (as, ld, etc) that GCC 10 needs
# These weren't built with GCC but are needed for aarch64-linux-gnu-* naming
RUN cd /opt/gcc-10/bin && \
    for tool in ar as ld nm objcopy objdump ranlib readelf strip; do \
        [ ! -f aarch64-linux-gnu-$tool ] && ln -sf /usr/bin/$tool aarch64-linux-gnu-$tool || true; \
    done

# Build liblcf from source (needed for easyrpg)
RUN cd /tmp && \
    git clone https://github.com/EasyRPG/liblcf.git && \
    cd liblcf && \
    git checkout 0.8 && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr && \
    make -j4 && \
    make install && \
    cd / && rm -rf /tmp/liblcf

# Upgrade CMake to 3.22 (Debian Buster has 3.13.4, but ppsspp needs 3.16+)
RUN wget -q "https://github.com/Kitware/CMake/releases/download/v3.22.1/cmake-3.22.1-linux-aarch64.tar.gz" && \
    echo "601443375aa1a48a1a076bda7e3cca73af88400463e166fffc3e1da3ce03540b  cmake-3.22.1-linux-aarch64.tar.gz" | sha256sum -c - && \
    tar -xzf cmake-3.22.1-linux-aarch64.tar.gz -C /opt && \
    ln -sf /opt/cmake-3.22.1-linux-aarch64/bin/cmake /usr/local/bin/cmake && \
    ln -sf /opt/cmake-3.22.1-linux-aarch64/bin/ctest /usr/local/bin/ctest && \
    ln -sf /opt/cmake-3.22.1-linux-aarch64/bin/cpack /usr/local/bin/cpack && \
    rm cmake-3.22.1-linux-aarch64.tar.gz

# Set GCC 10 as default (before system GCC in PATH)
ENV PATH="/opt/gcc-10/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/gcc-10/lib64:/opt/gcc-10/lib"

# Verify build environment
RUN echo "=== Build Environment ===" && \
    uname -m && \
    echo "" && \
    echo "=== GCC 10 Compilers ===" && \
    gcc --version | head -1 && \
    aarch64-linux-gnu-gcc --version | head -1 && \
    arm-linux-gnueabihf-gcc --version | head -1 && \
    echo "" && \
    echo "=== Other Tools ===" && \
    cmake --version | head -1 && \
    ruby --version

WORKDIR /workspace

# Clear any problematic bash configs
RUN rm -f /etc/bash.bashrc /root/.bashrc /etc/profile.d/* || true

# Configure git to avoid credential issues with public repos
RUN git config --global credential.helper "" && \
    git config --global http.postBuffer 524288000 && \
    git config --global core.compression 0

CMD ["/bin/bash"]
