# LessUI-Cores

Build libretro emulator cores for ARM retro handhelds running MinUI/LessUI.

## Quick Start

```bash
# Build cores for ARM64 devices
make build-arm64

# Build cores for ARM32 devices
make build-arm32

# Build both architectures
make build-all

# Package for distribution
make package-all
```

## Supported Devices

| Package | Devices | Architecture |
|---------|---------|--------------|
| **arm32** | Miyoo Mini/Plus/A30, RG35XX, Trimui Smart | ARMv7VE + NEON (Cortex-A7) |
| **arm64** | RG28xx/35xx/40xx, CubeXX, Trimui | ARMv8-A + NEON (Cortex-A53) |

## What's Included

35 cores per architecture covering:

- **Core Systems**: NES, SNES, GB/GBC, GBA, Genesis, PS1, PCE, Neo Geo Pocket, Virtual Boy, Pokemon Mini, PICO-8
- **Additional**: Atari (2600/5200/7800/Lynx), Game Gear, Sega CD, N64, Dreamcast, PSP, DOS, and more

## How It Works

**Recipes** define which cores to build:
```
recipes/linux/arm64.yml  →  Fetch sources  →  Build  →  output/arm64/*.so
recipes/linux/arm32.yml  →  Fetch sources  →  Build  →  output/arm32/*.so
```

Each recipe YAML contains:
1. **CPU config** - Compiler flags and toolchain settings
2. **Core definitions** - Repo, commit, and build instructions for each core

## Build Commands

```bash
# Full builds (1-3 hours each)
make build-arm32          # All ARM32 cores
make build-arm64          # All ARM64 cores
make build-all            # Both architectures

# Single core (for testing)
make core-arm64-gambatte  # Build one core
make core-arm32-flycast

# Packaging
make package-arm64        # Create linux-arm64.zip
make package-all          # Create all zips

# Utilities
make list-cores           # Show available cores
make test                 # Run test suite
make shell                # Open Docker shell
make clean                # Remove all outputs
```

## Adding a Core

1. Find the commit:
   ```bash
   git ls-remote --heads https://github.com/libretro/gambatte-libretro.git | grep master
   ```

2. Add to `recipes/linux/arm64.yml`:
   ```yaml
   cores:
     gambatte:
       repo: libretro/gambatte-libretro
       commit: 6924c76ba03dadddc6e97fa3660f3d3bc08faa94
       build_type: make
       makefile: Makefile.libretro
       build_dir: "."
       platform: unix
       so_file: gambatte_libretro.so
   ```

3. Test build:
   ```bash
   make core-arm64-gambatte
   ```

4. Copy entry to `arm32.yml` and test that architecture

## Updating Cores

Cores with a `target` field can be auto-updated:

```bash
make update-recipes-arm64           # Update all updateable cores
make update-core-arm64-gambatte     # Update specific core
make update-recipes-arm64 DRY=1     # Check what would update
```

For manually pinned cores, edit the `commit` field directly.

## Build Environment

- **Docker**: Debian Buster (glibc 2.28 for device compatibility)
- **Compiler**: GCC 8.3.0
- **Toolchains**: arm-linux-gnueabihf (ARM32), aarch64-linux-gnu (ARM64)

## Project Structure

```
recipes/linux/          # YAML recipes (source of truth)
  arm32.yml             # ARM32 CPU config + cores
  arm64.yml             # ARM64 CPU config + cores
lib/                    # Ruby build system
  cores_builder.rb      # Main orchestrator
  source_fetcher.rb     # Fetch from GitHub
  core_builder.rb       # Compile cores
scripts/
  build-all             # Build all cores
  build-one             # Build single core
  update-recipes        # Update commit hashes
output/                 # Build outputs (gitignored)
  arm64/*.so            # Built cores
  cores-arm64/          # Fetched sources
  dist/                 # Packaged zips
```

## Releases

Releases are triggered by pushing date-based tags:

```bash
make release            # Create and push YYYYMMDD-N tag
make release FORCE=1    # Force recreate today's release
```

GitHub Actions builds both architectures and creates a release with `linux-arm32.zip` and `linux-arm64.zip`.

## Requirements

- Docker
- ~5GB disk space per architecture
- 1-3 hours build time per architecture

## Documentation

- `CLAUDE.md` - Detailed developer guide
- `docs/adding-cores.md` - Step-by-step core addition guide

## License

Individual cores have their own licenses (typically GPLv2). See upstream repositories.
