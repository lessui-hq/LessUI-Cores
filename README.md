# LessUI-Cores

Build libretro emulator cores for ARM-based retro handhelds running MinUI.

**Systems-driven, curated core selection** - 35 retro systems, optimized per CPU!

## Current Status

✅ **35 systems** - Curated from systems.yml (NES, SNES, PSX, GBA, Dreamcast, etc.)
✅ **25-27 cores** - Per CPU family (optimized core selection)
✅ **4 CPU families** - cortex-a7, a53, a55, a76 (all MinUI-compatible devices)
✅ **Easily extensible** - Add systems via systems.yml configuration

## Quick Start

```bash
# 1. Configure systems (edit config/systems.yml to add/remove systems)
# 2. Generate core lists
make recipes-all

# 3. Build cores for all CPU families
make build-all

# Or build individually:
make build-cortex-a7   # ARM32: Miyoo Mini family
make build-cortex-a53  # ARM64: Universal baseline
make build-cortex-a55  # ARM64: RK3566 optimized
make build-cortex-a76  # ARM64: High-performance
```

**Output per CPU family:**
- cortex-a7: 25 cores (30 systems)
- cortex-a53: 26 cores (35 systems)
- cortex-a55: 26 cores (35 systems)
- cortex-a76: 27 cores (35 systems)

## Supported Systems

35 retro gaming systems configured in `config/systems.yml`:

**Classic Consoles:** Atari 2600/5200/7800, NES, Master System, TurboGrafx-16, Genesis, SNES, Sega CD, Neo Geo
**Handhelds:** Game Boy, Game Gear, GBC, Lynx, Virtual Boy, Neo Geo Pocket, Pokémon Mini, GBA
**Modern Eras:** PlayStation, N64, Dreamcast, NDS, PSP
**Computers:** C64, ZX Spectrum
**Fantasy Consoles:** PICO-8, TIC-80
**Others:** ColecoVision, Vectrex, ScummVM, FinalBurn Neo (Arcade)

### Per-CPU Core Optimization

Each CPU family uses the optimal core for each system:
- **cortex-a7** (ARM32): Lightweight cores (pocketsnes, stella2014, gpsp, picodrive)
- **cortex-a53/a55**: Balanced accuracy and performance
- **cortex-a76**: Cycle-accurate cores where beneficial (bsnes, swanstation, beetle-supergrafx)

Heavy systems (N64, NDS, Dreamcast, PSP) are excluded from cortex-a7 builds.

## Supported Devices

| CPU Family | Devices | Architecture |
|------------|---------|--------------|
| **cortex-a7** | Miyoo Mini, Mini Plus, A30 | ARM32 (ARMv7) |
| **cortex-a53** | RG28xx/35xx/40xx, Trimui Brick/Smart Pro | ARM64 baseline |
| **cortex-a55** | Miyoo Flip, RGB30, RG353 (RK3566) | ARM64 w/ crypto+dotprod |
| **cortex-a76** | RG406/556, Retroid Pocket 5 | ARM64 high-performance |

See `config/systems.yml` for complete system definitions and per-CPU core mappings.

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

### Build Flow

1. **Define systems** (`config/systems.yml`)
   - Specify retro systems to support
   - Map each system to the best libretro core per CPU family
   - Example: SNES uses `pocketsnes` on cortex-a7, `snes9x` on a53/a55, `bsnes` on a76

2. **Generate core lists** (`scripts/generate-cores-from-systems`)
   ```bash
   make recipes-cortex-a53  # Generates config/cores-cortex-a53.list
   ```
   - Reads systems.yml
   - Determines unique cores needed for each CPU family
   - Saves to `config/cores-{cpu}.list`

3. **Generate recipes** (`scripts/generate-recipes`)
   - Parses Knulli's `.mk` files to extract:
     - Git repository URLs
     - Tested commit hashes (production-proven on real hardware)
     - Build configurations and dependencies
   - Filters to only cores in the CPU family's list
   - Saves to `recipes/linux/{cpu}.json`

4. **Build cores** (`scripts/build-all`)
   ```bash
   make build-cortex-a53
   ```
   - Fetches source code at tested commits
   - Cross-compiles with CPU-optimized flags
   - Outputs `.so` files to `workspace/{cpu}/`

### Benefits

✅ **Systems-driven** - Curate by use case, not individual cores
✅ **CPU-optimized** - Best core per system per CPU family
✅ **Knulli-tested** - Production commits proven on real hardware
✅ **Easily extensible** - Add systems via YAML config
✅ **No Buildroot** - Simple recipe-based builds
✅ **glibc 2.28** - Maximum device compatibility

## Adding New Systems

1. **Edit `config/systems.yml`**:
   ```yaml
   wonderswan:
     name: Bandai WonderSwan
     cores:
       default: beetle-wswan
       cortex-a7: null  # Too heavy for ARM32
   ```

2. **Regenerate core lists**:
   ```bash
   scripts/generate-cores-from-systems cortex-a53
   # Or for all families:
   make recipes-all
   ```

3. **Build**:
   ```bash
   make build-cortex-a53
   ```

The system will automatically fetch the core from Knulli's definitions and build it with the correct flags.

## Build Commands

```bash
# Generate recipes (run after editing systems.yml)
make recipes-cortex-a53
make recipes-all

# Build specific CPU family
make build-cortex-a7
make build-cortex-a53
make build-cortex-a55
make build-cortex-a76

# Build all families
make build-all

# Package builds
make package-cortex-a53
make package-all

# Clean
make clean-cortex-a53
make clean
```

## Updating Cores from Knulli

When Knulli updates their core definitions or commits:

```bash
# Update Knulli submodule to latest
git submodule update --remote knulli

# Regenerate recipes with latest commits
make recipes-all

# Rebuild cores
make build-all
```

This pulls the latest tested commits from Knulli's production builds.

## Build Environment

- **Docker**: Debian Buster
- **Compiler**: GCC 8.3.0
- **glibc**: 2.28 (for maximum compatibility)
- **Toolchains**: arm-linux-gnueabihf, aarch64-linux-gnu

## Architecture

```
LessUI-Cores/
├── config/
│   ├── systems.yml              # System definitions (source of truth)
│   ├── cortex-a53.config        # Compiler flags per CPU
│   └── cores-cortex-a53.list    # Generated: 26 cores for a53
├── scripts/
│   ├── generate-cores-from-systems  # systems.yml → cores-*.list
│   ├── generate-recipes             # cores list → recipes JSON
│   ├── build-all                    # Build all cores for CPU
│   └── build-one                    # Build single core (testing)
├── lib/                         # Ruby build system
│   ├── cpu_config.rb            # Parse CPU configs
│   ├── mk_parser.rb             # Parse Knulli .mk files
│   ├── recipe_generator.rb      # Extract build info from Knulli
│   ├── core_builder.rb          # Build individual cores
│   └── cores_builder.rb         # Orchestrate builds
├── recipes/linux/
│   └── cortex-a53.json          # Generated: 26 recipes with commits
├── workspace/                   # All build artifacts
│   ├── cores/                   # Fetched source code
│   ├── logs/                    # Build logs
│   ├── dist/                    # Packaged zips
│   ├── cortex-a53/*.so          # Built cores
│   ├── cortex-a55/*.so
│   ├── cortex-a7/*.so
│   └── cortex-a76/*.so
├── knulli/                      # Git submodule (Knulli sources)
├── Dockerfile                   # Debian Buster (GCC 8.3, glibc 2.28)
└── Makefile                     # Build orchestration
```

### Key Files

- **`config/systems.yml`** - Define systems and cores (edit this to add systems!)
- **`config/cores-*.list`** - Generated from systems.yml (don't edit directly)
- **`recipes/linux/*.json`** - Generated from Knulli .mk files (don't edit directly)

## Output

Cores are built as `.so` files:
- `workspace/cortex-a53/*.so` - Individual cores
- `workspace/dist/linux-cortex-a53.zip` - Distribution package
- `workspace/cores/` - Fetched source code
- `workspace/logs/` - Build logs

## Requirements

- Docker
- Git (for cloning submodules)
- ~5GB disk space per CPU family
- 1-3 hours build time per CPU family

## Initial Setup

```bash
# Clone the repository with submodules
git clone --recursive https://github.com/YOUR-USERNAME/LessUI-Cores.git

# Or if already cloned, initialize the submodule:
git submodule update --init --recursive
```

## Examples

**Build only Game Boy cores for testing:**
```bash
# Edit systems.yml to include only gb, gbc, gba
scripts/generate-cores-from-systems cortex-a53
make build-cortex-a53
```

**Add arcade support:**
```yaml
# In config/systems.yml:
mame2003plus:
  name: MAME 2003-Plus
  cores:
    default: mame2003-plus
```
```bash
make recipes-all
make build-all
```

## License

Individual cores have their own licenses (typically GPLv2). See upstream repositories for details.
