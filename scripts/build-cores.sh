#!/bin/bash
# Build cores from recipe file with cross-compilation
set -e

RECIPE_FILE="$1"
ARCH="$2"
CORES_DIR="${3:-cores}"
OUTPUT_DIR="${4:-dist}"

if [ -z "$RECIPE_FILE" ] || [ -z "$ARCH" ]; then
    echo "Usage: $0 <recipe-file> <arch> [cores-dir] [output-dir]"
    echo "  arch: arm7neonhf or aarch64"
    exit 1
fi

# Convert to absolute paths
SCRIPT_DIR="$(pwd)"
case "$RECIPE_FILE" in
    /*) ;; # already absolute
    *) RECIPE_FILE="$SCRIPT_DIR/$RECIPE_FILE" ;;
esac
case "$CORES_DIR" in
    /*) ;; # already absolute
    *) CORES_DIR="$SCRIPT_DIR/$CORES_DIR" ;;
esac
case "$OUTPUT_DIR" in
    /*) ;; # already absolute
    *) OUTPUT_DIR="$SCRIPT_DIR/$OUTPUT_DIR" ;;
esac

# Set up cross-compilation environment
case "$ARCH" in
    arm7neonhf)
        export CC="arm-linux-gnueabihf-gcc"
        export CXX="arm-linux-gnueabihf-g++"
        export AR="arm-linux-gnueabihf-ar"
        export AS="arm-linux-gnueabihf-as"
        export STRIP="arm-linux-gnueabihf-strip"
        PLATFORM="unix"
        ;;
    aarch64)
        export CC="aarch64-linux-gnu-gcc"
        export CXX="aarch64-linux-gnu-g++"
        export AR="aarch64-linux-gnu-ar"
        export AS="aarch64-linux-gnu-as"
        export STRIP="aarch64-linux-gnu-strip"
        PLATFORM="unix"
        ;;
    *)
        echo "Unknown architecture: $ARCH"
        exit 1
        ;;
esac

mkdir -p "$OUTPUT_DIR"

echo "=== Building cores from $RECIPE_FILE ==="
echo "Architecture: $ARCH"
echo "Toolchain: $CC"
echo ""

BUILD_COUNT=0
FAIL_COUNT=0

while read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue

    # Parse: name dir url branch enabled build_type makefile subdir args...
    read -r name dir url branch enabled build_type makefile subdir args <<< "$line"

    # Skip if not enabled
    [ "$enabled" != "YES" ] && continue

    # Only support GENERIC builds for now
    if [ "$build_type" != "GENERIC" ] && [ "$build_type" != "GENERIC_GL" ]; then
        echo "⊘ $name (unsupported build type: $build_type)"
        continue
    fi

    echo "→ Building $name"

    BUILD_DIR="$CORES_DIR/$dir/$subdir"

    if [ ! -d "$BUILD_DIR" ]; then
        echo "  ✗ Directory not found: $BUILD_DIR"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi

    # Build the core
    cd "$BUILD_DIR"

    # Clean first
    CC="$CC" CXX="$CXX" AR="$AR" AS="$AS" STRIP="$STRIP" make -f "$makefile" clean 2>/dev/null || true

    # Build
    if CC="$CC" CXX="$CXX" AR="$AR" AS="$AS" STRIP="$STRIP" make -f "$makefile" -j${JOBS:-8} platform="$PLATFORM" $args 2>&1 | grep -v "Entering directory" | grep -v "Leaving directory"; then
        # Find and copy the .so file
        SO_FILE=$(find . -maxdepth 1 -name "*_libretro.so" | head -1)
        if [ -n "$SO_FILE" ]; then
            cp "$SO_FILE" "$OUTPUT_DIR/${name}_libretro.so"
            BUILD_COUNT=$((BUILD_COUNT + 1))
            echo "  ✓ ${name}_libretro.so"
        else
            echo "  ✗ No .so file found"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo "  ✗ Build failed"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    cd - > /dev/null

done < "$RECIPE_FILE"

echo ""
echo "=== Build Summary ==="
echo "Built: $BUILD_COUNT cores"
echo "Failed: $FAIL_COUNT cores"

# Exit 0 if at least one core built successfully
[ $BUILD_COUNT -gt 0 ] && exit 0 || exit 1
