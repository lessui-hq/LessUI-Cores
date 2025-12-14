# Adding New Cores

This guide walks through adding a new libretro core to LessUI-Cores.

## Overview

1. Find the core's GitHub repo and get the latest commit
2. Add an entry to the recipe YAML
3. Test the build
4. Copy to other architectures

## Step 1: Find the Core

Most libretro cores live under the `libretro` GitHub organization.

```bash
# Get the latest commit SHA from master branch
git ls-remote https://github.com/libretro/gambatte-libretro.git refs/heads/master

# Output: 6924c76ba03dadddc6e97fa3660f3d3bc08faa94  refs/heads/master
```

For stable releases, check the repo's tags/releases page on GitHub.

## Step 2: Inspect the Build System

Use the helper script to analyze a core's build configuration:

```bash
./scripts/inspect-core libretro/gambatte-libretro 6924c76ba03dadddc6e97fa3660f3d3bc08faa94
```

This downloads the core, finds makefiles, attempts a test build, and suggests a recipe entry.

**What to look for:**
- Which Makefile to use (`Makefile.libretro` preferred over `Makefile`)
- Where the build directory is (usually `.` but sometimes `platform/libretro`)
- What the output `.so` file is named

## Step 3: Add to Recipe

Edit `recipes/linux/arm64.yml` and add the core under the `cores:` section in alphabetical order.

### Make Build (Most Common)

```yaml
cores:
  gambatte:
    repo: libretro/gambatte-libretro
    target: master                                    # Branch to track for updates
    commit: 6924c76ba03dadddc6e97fa3660f3d3bc08faa94  # Specific SHA to build
    build_type: make
    makefile: Makefile.libretro
    build_dir: "."
    platform: unix
    so_file: gambatte_libretro.so
```

### CMake Build

```yaml
cores:
  flycast:
    repo: flyinghead/flycast
    target: v2.0
    commit: aa97a6d64fb47d3ce0febaa575b26d975dd916e4
    build_type: cmake
    so_file: build/flycast_libretro.so
    submodules: true
    cmake_opts:
      - -DCMAKE_BUILD_TYPE=Release
      - -DLIBRETRO=ON
```

### Required Fields

**All cores:**
| Field | Description |
|-------|-------------|
| `repo` | GitHub path (e.g., `libretro/gambatte-libretro`) |
| `commit` | Full 40-character SHA |
| `build_type` | `make` or `cmake` |
| `so_file` | Path to output `.so` file (relative to core root) |

**Make builds also need:**
| Field | Description |
|-------|-------------|
| `makefile` | Makefile name (e.g., `Makefile.libretro`) |
| `build_dir` | Directory containing the makefile (usually `"."`) |
| `platform` | Usually `unix` |

**CMake builds also need:**
| Field | Description |
|-------|-------------|
| `cmake_opts` | List of CMake options |

### Optional Fields

| Field | When to Use |
|-------|-------------|
| `target` | Branch or tag to track for auto-updates (e.g., `master`, `v1.0`) |
| `submodules: true` | Core has git submodules |
| `extra_args` | Additional make arguments |
| `prebuild_script` | Script to run before build |

## Step 4: Test Build

```bash
# Build just this core
make core-arm64-gambatte
```

If successful, you'll see the `.so` file in `output/arm64/`.

## Step 5: Add to Other Architectures

Copy the same entry to `recipes/linux/arm32.yml` and test:

```bash
make core-arm32-gambatte
```

Most cores work identically on both architectures. Exceptions:
- `platform` might differ (e.g., `arm64` vs `unix` for gpsp)
- Some cmake options are architecture-specific

## Common Patterns

### Standard libretro core
```yaml
corename:
  repo: libretro/libretro-corename
  target: master
  commit: <sha>
  build_type: make
  makefile: Makefile.libretro
  build_dir: "."
  platform: unix
  so_file: corename_libretro.so
```

### Beetle/Mednafen cores
Output uses `mednafen_` prefix:
```yaml
beetle-lynx:
  repo: libretro/beetle-lynx-libretro
  so_file: mednafen_lynx_libretro.so  # Not beetle_lynx!
```

### Non-root build directory
```yaml
fbneo:
  build_dir: src/burner/libretro
  so_file: src/burner/libretro/fbneo_libretro.so
```

### Upstream project (not libretro fork)
```yaml
stella:
  repo: stella-emu/stella          # Upstream repo
  target: 6.7.1                    # Release tag
  build_dir: src/libretro
  so_file: src/libretro/stella_libretro.so
```

### With extra make arguments
```yaml
snes9x2005:
  extra_args:
    - USE_BLARGG_APU=1
```

## Troubleshooting

**Build fails immediately:**
- Check the repo path is correct
- Verify the commit SHA exists
- Make sure build_dir contains the makefile

**Can't find .so file:**
- Check `so_file` path is relative to core root, not build_dir
- Run `find output/cores-arm64/libretro-corename -name "*.so"` to locate it

**Works on one architecture but not the other:**
- Some cores need different `platform` values
- Check if extra_args need architecture-specific flags

## Checklist

Before submitting:
- [ ] Core builds on arm64
- [ ] Core builds on arm32
- [ ] Entry is alphabetically sorted in `cores:` section
- [ ] Uses `Makefile.libretro` if available
- [ ] `so_file` uses actual output name (check with `find`)
- [ ] Added `target` field for auto-updates (recommended)
