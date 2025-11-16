# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LessUI-Cores is a build system for creating CPU-optimized libretro emulator cores for ARM-based retro handhelds running MinUI. It builds 26-31 cores per CPU family, supporting all MinUI required cores plus additional systems.

**Key Architecture:** Manual YAML recipes define which cores to build for each CPU family. Recipes are the single source of truth - edit them directly to add/update/remove cores.

**MinUI Compatibility:** All 13 MinUI required cores are built for all CPU families to ensure upgrade compatibility from MinUI.

## Common Build Commands

```bash
# Build cores for specific CPU family
make build-cortex-a7    # ARM32: Miyoo Mini family
make build-cortex-a53   # ARM64: Universal baseline (RG35xx, RG40xx, Trimui)
make build-cortex-a55   # ARM64: RK3566 optimized (Miyoo Flip, RGB30, RG353)
make build-cortex-a76   # ARM64: High-performance (RG406/556, Retroid Pocket 5)

# Build all families (1-3 hours per family)
make build-all

# Build single core for testing/debugging
make core-cortex-a53-gambatte
make core-cortex-a55-flycast

# Package builds
make package-cortex-a53
make package-all

# Clean
make clean              # Clean all build outputs
make clean-cortex-a53   # Clean specific CPU family
```

## Build System Architecture

### Simple Two-Phase Build Flow

**Phase 1: Recipes → Fetched Sources**
- **Input:** `recipes/linux/{cpu}.yml` (YAML files with core definitions)
- **Script:** `lib/source_fetcher.rb`
- **Output:** `output/cores/{corename}/` (git clones at specific commits)

**Phase 2: Sources → Built Cores**
- **Input:** Fetched sources + `config/{cpu}.config` (compiler flags)
- **Script:** `lib/core_builder.rb`
- **Output:** `output/{cpu}/*.so` files (compiled cores)

### Ruby Library Organization

- **`lib/cores_builder.rb`** - Main orchestrator; coordinates fetching and building
- **`lib/cpu_config.rb`** - Parses `config/{cpu}.config` bash files into Ruby objects
- **`lib/source_fetcher.rb`** - Clones/fetches git repositories at specific commits
- **`lib/core_builder.rb`** - Executes builds for individual cores
- **`lib/logger.rb`** - Centralized logging with sections and timestamps

### Data Flow

```
recipes/linux/{cpu}.yml → source_fetcher → output/cores/
                              ↓
                        core_builder → output/{cpu}/*.so
```

## Key Configuration Files

### `recipes/linux/{cpu}.yml` - Source of Truth

These are **manually maintained YAML files** that define which cores to build for each CPU family. Edit them directly to add/update/remove cores.

**Location:**
- `recipes/linux/cortex-a7.yml` - ARM32 cores (26 cores)
- `recipes/linux/cortex-a53.yml` - ARM64 baseline (30 cores)
- `recipes/linux/cortex-a55.yml` - RK3566 optimized (30 cores)
- `recipes/linux/cortex-a76.yml` - High-performance (31 cores)

**Recipe Entry Format:**
```yaml
core-name:
  version: <git-commit-hash>
  commit: <git-commit-hash>
  url: https://github.com/org/repo/archive/<commit>.tar.gz
  license: GPLv2
  platform: unix
  submodules: true|false
  build_type: make|cmake
  makefile: Makefile.libretro
  name: core-name
  repo: libretro-core-name
  build_dir: .
  extra_args: []              # Optional: additional make args
  cmake_opts: []              # Optional: cmake-specific options
  so_file: core_libretro.so   # Optional: override output path
```

**Important Notes:**
- Each recipe file has a header comment with documentation
- Cores are sorted alphabetically for easy navigation
- Comments can be added anywhere (YAML supports `#` comments)
- The `url` field uses GitHub's archive URL for the specific commit

### `config/{cpu}.config` - CPU-Specific Compiler Flags

Bash-formatted files with CPU-optimized compiler flags. Key variables:
- `ARCH` - Architecture (arm, aarch64)
- `TARGET_CROSS` - Compiler prefix (arm-linux-gnueabihf-, aarch64-linux-gnu-)
- `TARGET_OPTIMIZATION` - CPU-specific march/mcpu/mtune flags
- `TARGET_CFLAGS` / `TARGET_CXXFLAGS` - Compiler optimization flags

**Do not edit these unless you understand ARM CPU architecture specifics.**

## Adding New Cores

To add a new core to the build:

1. **Find the core repository and commit:**
   - Search https://github.com/libretro for the core repository
   - Or reference Knulli's online definitions for tested commits: https://github.com/knulli-cfw/distribution/tree/main/package/batocera/emulators/retroarch/libretro

2. **Add to recipe files:**
   - Edit `recipes/linux/{cpu}.yml` for each CPU family you want to support
   - Copy an existing core entry as a template
   - Update all fields (name, version, url, etc.)

3. **Build and test:**
   ```bash
   make core-cortex-a53-{corename}  # Test single core
   make build-all                    # Build for all families
   ```

**Example - Adding a new core:**
```bash
# 1. Find the core repository and latest commit
# Check https://github.com/libretro for official cores
# Or reference Knulli: https://github.com/knulli-cfw/distribution/tree/main/package/batocera/emulators/retroarch/libretro

# 2. Edit recipes/linux/cortex-a53.yml
vim recipes/linux/cortex-a53.yml

# 4. Add entry (alphabetically):
genesisplusgx:
  version: abc123...
  commit: abc123...
  url: https://github.com/libretro/Genesis-Plus-GX/archive/abc123.tar.gz
  # ... rest of fields

# 5. Test build
make core-cortex-a53-genesisplusgx
```

## Updating Cores

To update a core to a newer version:

1. **Find the latest commit:**
   - Check the libretro core's GitHub releases or commits
   - Or reference Knulli's package definitions: https://github.com/knulli-cfw/distribution/tree/main/package/batocera/emulators/retroarch/libretro

2. **Update recipe files:**
   ```bash
   # Edit the recipe for each CPU family
   vim recipes/linux/cortex-a53.yml

   # Update these fields with the new commit hash:
   # - version: <new-commit-hash>
   # - commit: <new-commit-hash>
   # - url: https://github.com/org/repo/archive/<new-commit-hash>.tar.gz
   ```

3. **Test the update:**
   ```bash
   # Test build single core first
   make core-cortex-a53-{corename}

   # If successful, update other CPU families and rebuild all
   make build-all
   ```

**Tip:** You can reference Knulli's online package definitions to find tested commit hashes, but we maintain our own recipes independently.

## MinUI Required Cores

These 13 cores MUST be present on all CPU families for MinUI compatibility:

1. **fake08** - PICO-8 (fantasy console)
2. **fceumm** - Nintendo Entertainment System
3. **gambatte** - Game Boy / Game Boy Color
4. **gpsp** - Game Boy Advance (ARM32 optimized)
5. **beetle-pce-fast** - PC Engine / TurboGrafx-16 (mednafen_pce_fast)
6. **supafaust** - Super Nintendo (mednafen_supafaust)
7. **beetle-vb** - Virtual Boy (mednafen_vb)
8. **mgba** - Game Boy Advance (ARM64 / general purpose)
9. **pcsx** - PlayStation (pcsx_rearmed)
10. **picodrive** - Sega Genesis / Mega Drive / 32X
11. **pokemini** - Pokemon Mini
12. **race** - Neo Geo Pocket / Neo Geo Pocket Color
13. **snes9x2005** - Super Nintendo (snes9x2005_plus)

**Core Naming:** Some cores have different names in MinUI vs libretro. Our recipes use libretro names (e.g., `beetle-vb` instead of `mednafen_vb`).

## Build Environment

- **Docker:** Debian Buster (for glibc 2.28 compatibility)
- **Compiler:** GCC 8.3.0
- **Toolchains:** arm-linux-gnueabihf (ARM32), aarch64-linux-gnu (ARM64)
- **Parallel builds:** Controlled by `-j` flag or `JOBS` environment variable

## CPU Family Details

| CPU Family | Architecture | Devices | Cores Built |
|------------|--------------|---------|-------------|
| **cortex-a7** | ARM32 (ARMv7) | Miyoo Mini, A30 | 26 cores |
| **cortex-a53** | ARM64 (ARMv8-a) | RG28xx/35xx/40xx, Trimui | 30 cores |
| **cortex-a55** | ARM64 (ARMv8.2-a) | Miyoo Flip, RGB30, RG353 | 30 cores |
| **cortex-a76** | ARM64 (ARMv8.2-a) | RG406/556, Retroid Pocket 5 | 31 cores |

**Core Selection Philosophy:**
- **cortex-a7:** Lightweight cores, exclude heavy systems (N64, PSP, Dreamcast)
- **cortex-a53/a55:** Balanced cores, universal compatibility
- **cortex-a76:** Can handle cycle-accurate/heavy cores (bsnes, swanstation, beetle-psx)

## Troubleshooting

### Build Failures

1. Check build log: `output/logs/{cpu}-build.log`
2. Test single core: `make core-cortex-a53-{corename}`
3. Verify recipe exists: `grep -A 10 "^{corename}:" recipes/linux/{cpu}.yml`

### Missing Cores

1. Check if core is in recipe: `grep "^{corename}:" recipes/linux/{cpu}.yml`
2. Add core to recipe file if missing (see "Adding New Cores" above)
3. Rebuild: `make build-{cpu}`

### Cross-Compilation Issues

- Ensure Docker image is built: `make docker-build`
- Check CPU config file exists: `config/{cpu}.config`
- Verify toolchain is available in Docker container: `make shell`

## Output Structure

```
output/
├── cores/              # Fetched source code (git clones)
├── logs/               # Build logs
├── dist/               # Packaged zips
├── cortex-a7/*.so      # ARM32 cores (26 cores)
├── cortex-a53/*.so     # ARM64 baseline (30 cores)
├── cortex-a55/*.so     # RK3566 optimized (30 cores)
└── cortex-a76/*.so     # High-performance (31 cores)
```

## Development Workflow

### Testing a New Core

```bash
# 1. Add core to recipes/linux/cortex-a53.yml

# 2. Build just that core
make core-cortex-a53-{corename}

# 3. If successful, add to other CPU families
# Edit recipes/linux/cortex-a7.yml, cortex-a55.yml, cortex-a76.yml

# 4. Build for all families
make build-all
```

### Debugging Build Issues

```bash
# Open shell in build container
make shell

# Manually inspect source
cd output/cores/{corename}
ls -la

# Try manual build with verbose output
make -f Makefile.libretro platform=unix CC=gcc V=1
```

## Release and Deployment

### Creating a Release

The project uses git flow with automated releases triggered by UTC date-based tags (YYYYMMDD format):

```bash
# Create a new release (must be on develop branch)
./scripts/release

# Force re-release (overwrites existing tag/release for today)
./scripts/release --force
```

The release script will:
1. Validate you're on the `develop` branch with no uncommitted changes
2. Generate a UTC date-based tag (e.g., `20251115`)
3. If tag exists and `--force` flag used, delete local/remote tag and GitHub release
4. Execute git flow release start/finish
5. Push branches and tag to trigger GitHub Actions

**Force Mode:** Use `--force` to redeploy on the same day (e.g., after fixing a bad build). This deletes the existing tag and GitHub release (requires `gh` CLI for release deletion).

### GitHub Actions Workflow

When a tag matching YYYYMMDD format is pushed to `main`:
1. Builds Docker image
2. Runs `make build-all` for all CPU families
3. Packages builds using `make package-all`
4. Creates GitHub Release with:
   - `cortex-a7.zip` - ARM32 cores (26 cores)
   - `cortex-a53.zip` - ARM64 baseline (30 cores)
   - `cortex-a55.zip` - RK3566 optimized (30 cores)
   - `cortex-a76.zip` - High-performance (31 cores)
5. Updates `latest` tag to point to newest release

### Prerequisites for Deployment

- git-flow must be installed: `brew install git-flow` (macOS) or `apt-get install git-flow` (Linux)
- Repository must be on `develop` branch
- All changes must be committed
- GitHub repository must have Actions enabled

## Important Notes

- **Never commit `output/` directory** - It contains build artifacts and fetched sources
- **Recipes are git-tracked** - Your edits to YAML files are preserved in version control
- **Recipes are manually maintained** - No automatic generation; edit YAML files directly
- **Each CPU family needs ~5GB disk space** - Plan accordingly
- **Build times are 1-3 hours per CPU family** - Use `build-all` overnight
- **One release per day** - UTC date tags prevent multiple releases on the same day
