# LessUI-Cores

Build libretro emulator cores for ARM-based retro handhelds running MinUI.

**MinUI-focused, space-optimized** - Just 2 CPU families covering 18 devices!

## Current Status

✅ **51 cores** - Default build (cortex-a7 + cortex-a53)
✅ **130 cores** - Total available (all 5 CPU families, 100% success)
✅ **18 devices** - 100% MinUI device coverage
✅ **66% space savings** - 479 MB vs 1.4 GB building all families

## Quick Start

```bash
# Build both ARM32 and ARM64 cores (11 minutes)
make build-all

# Or build individually:
make build-cortex-a7   # Miyoo Mini family (3 devices)
make build-cortex-a53  # All other MinUI devices (15 devices)
```

**Output:**
- cortex-a7: 25 cores, ~177 MB
- cortex-a53: 26 cores, ~302 MB
- **Total: 51 cores, ~479 MB** (vs 130 cores, 1.4 GB for all families)

**Build time:** ~11 minutes (vs 30 minutes for all families)

## Supported Devices (MinUI)

### Active Builds (Default)

| Build | Devices | Use Case |
|-------|---------|----------|
| **cortex-a7** | Miyoo Mini, Mini Plus, A30 | ARM32 devices |
| **cortex-a53** | RG28xx/35xx/40xx, Trimui, Miyoo Flip, RGB30, RG353 | Universal ARM64 |

### Device → Build Mapping

| Your Device | Use This Build | Why |
|-------------|----------------|-----|
| Miyoo Mini/Plus/A30 | **cortex-a7** | ARM32 (unique cores) |
| RG28xx/34xx/35xx/40xx/CubeXX | **cortex-a53** | H700 native |
| Trimui Brick/Smart Pro | **cortex-a53** | A133 native |
| Miyoo Flip, RGB30, RG353 | **cortex-a53** | A55 compatible |

**Total Coverage:** 18 MinUI devices (100%)

**Documentation:** See `docs/` for detailed guides:
- `docs/MINUI-DEVICES.md` - Which build for your device
- `docs/CPU-COMPARISON.md` - Why we simplified to 2 families
- `docs/HANDHELD-DATABASE.md` - All 70+ devices categorized
- `docs/CORE_SELECTION.md` - How cores were chosen

### CPU Family Details

Each CPU family uses optimized compiler flags for best performance:

**Cortex-A53** (64-bit, ARMv8-a baseline)
- Arch: `aarch64`
- Flags: `-march=armv8-a+crc -mcpu=cortex-a53 -mtune=cortex-a53`
- Features: CRC extensions
- Devices: H700/A133 SoCs (RG35xx, RG40xx, Trimui)

**Cortex-A55** (64-bit, ARMv8.2-a advanced)
- Arch: `aarch64`
- Flags: `-march=armv8.2-a+crc+crypto+dotprod -mcpu=cortex-a55 -mtune=cortex-a55`
- Features: Crypto extensions, dot product (ML/AI)
- Devices: RK3566/RK3568 (RGB30, RG353, Miyoo Flip)

**Cortex-A7** (32-bit, ARMv7)
- Arch: `arm`
- Flags: `-march=armv7ve -mcpu=cortex-a7 -mtune=cortex-a7`
- Features: Virtualization extensions, NEON
- Devices: R16 SoC (Miyoo Mini, A30)

**Cortex-A35** (64-bit, ARMv8-a with SIMD)
- Arch: `aarch64`
- Flags: `-march=armv8-a+crc+fp+simd -mcpu=cortex-a35 -mtune=cortex-a35`
- Features: Floating point, SIMD optimizations
- Devices: RK3326 (RG351 series, GameForce)

**Cortex-A76** (64-bit big.LITTLE, ARMv8.2-a)
- Arch: `aarch64`
- Flags: `-march=armv8.2-a+crc+crypto+rcpc+dotprod -mtune=cortex-a76.cortex-a55`
- Features: Release-consistent, tuned for big.LITTLE (A76+A55)
- Devices: RK3588, Snapdragon (Retroid Pocket 5)

## How It Works

1. **Extract from Knulli**: Uses Make to evaluate Knulli's `.mk` files, extracting tested commit hashes and build configs
2. **Filter cores**: Uses CPU-specific core lists (78 cores for cortex-a53, tested by Knulli on RG35xx)
3. **Build in Docker**: Cross-compiles with CPU-optimized flags in Debian Buster (glibc 2.28) for maximum device compatibility

### Benefits

✅ **Knulli's tested commits** - Production-proven on real hardware
✅ **Auto-updates** - Re-run extraction when Knulli updates
✅ **No Buildroot complexity** - Simple recipe-based builds
✅ **Proven build system** - Uses tested fetch/build scripts
✅ **glibc 2.28 compatibility** - Works on older device firmware

## Build Commands

```bash
# Build specific CPU family
make build-cortex-a53
make build-cortex-a55
make build-cortex-a7

# Build all families
make build-all

# Package builds
make package-cortex-a53
make package-all

# Clean
make clean-cortex-a53
make clean
```

## Updating from Knulli

When Knulli updates their cores:

```bash
cd /Users/nchapman/knulli
git pull

cd /Users/nchapman/Drive/Code/LessUI-Cores
make recipes-cortex-a53
```

This regenerates recipes with updated commits.

## Build Environment

- **Docker**: Debian Buster
- **Compiler**: GCC 8.3.0
- **glibc**: 2.28 (for maximum compatibility)
- **Toolchains**: arm-linux-gnueabihf, aarch64-linux-gnu

## Architecture

```
minarch-cores/
├── config/                      # CPU family configs
│   ├── cortex-a53.config        # Compiler flags
│   ├── cores-cortex-a53.list    # Enabled cores (78 cores)
│   ├── cortex-a55.config
│   ├── cores-cortex-a55.list
│   └── ...
├── recipes/linux/               # Generated recipes (JSON)
│   ├── cortex-a53.json          # 78 cores with commit SHAs
│   └── ...
├── lib/                         # Ruby build system
│   ├── logger.rb                # Colored output
│   ├── cpu_config.rb            # Parse CPU configs
│   ├── mk_parser.rb             # Parse Knulli .mk files
│   ├── recipe_generator.rb      # Generate recipes
│   ├── source_fetcher.rb        # Fetch sources
│   ├── core_builder.rb          # Build individual cores
│   └── cores_builder.rb         # Orchestrate builds
├── scripts/                     # Entry points
│   ├── generate-recipes         # Generate JSON recipes
│   ├── build-all                # Build all cores
│   ├── build-one                # Build single core
│   └── fetch-sources            # Fetch source code
├── Dockerfile                   # Debian Buster build environment
└── Makefile                     # Build orchestration
```

## Output

Cores are built as `.so` files:
- `build/cortex-a53/*.so` - Individual cores
- `dist/linux-cortex-a53.zip` - Distribution package

## Requirements

- Docker
- ~10GB disk space
- 1-3 hours build time

## License

Individual cores have their own licenses (typically GPLv2). See upstream repositories for details.
