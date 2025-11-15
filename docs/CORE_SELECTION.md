# Core Selection Methodology

How libretro cores are selected for each system and CPU family.

## Source: systems.yml

All cores are defined in `config/systems.yml`. Each system specifies:
- Default core (used by all CPU families)
- CPU-specific overrides (optional)

**Example:**
```yaml
snes:
  name: Super Nintendo
  cores:
    default: snes9x           # Used by cortex-a53, a55, a76
    cortex-a7: pocketsnes     # ARM32 uses lighter core
    cortex-a76: bsnes         # High-end uses cycle-accurate
```

## Core Selection Principles

### Cortex-A7 (ARM32 - Low Power)

**Philosophy:** Lightweight cores optimized for ARM32

**Examples:**
- **SNES:** `pocketsnes` - ARM-optimized
- **Atari 2600:** `stella2014` - Older, lighter version
- **GBA:** `gpsp` - Dynarec for speed
- **Genesis:** `picodrive` - Assembly-optimized
- **PSX:** `pcsx` - Lighter than beetle-psx

Heavy systems (N64, NDS, Dreamcast, PSP) are set to `null` (excluded).

### Cortex-A53/A55 (ARM64 - Universal)

**Philosophy:** Balance accuracy and performance

**Examples:**
- **SNES:** `snes9x` - Balanced emulation
- **Atari 2600:** `stella` - Current version
- **GBA:** `mgba` - More accurate
- **PSX:** `beetle-psx` - Better accuracy
- **Dreamcast:** `flycast-xtreme` - ARM64 optimized

### Cortex-A76 (ARM64 - High Performance)

**Philosophy:** Use cycle-accurate cores where beneficial

**Additional cores:**
- **SNES:** `bsnes` - Cycle-accurate
- **PSX:** `swanstation` - Modern, accurate
- **PC Engine:** `beetle-supergrafx` - Full SuperGrafx

## Core Sources

All cores come from Knulli's tested libretro packages:
- **Repository:** https://github.com/knulli-cfw/distribution
- **Location:** `package/batocera/emulators/retroarch/libretro/`
- **Validation:** Each core verified to exist in Knulli's build system

Build information (URLs, commits, dependencies) is extracted from Knulli's `.mk` files.

## Per-System Optimizations

Different cores per CPU family allow optimal performance:

| System | cortex-a7 | cortex-a53/a55 | cortex-a76 |
|--------|-----------|----------------|------------|
| SNES | pocketsnes | snes9x | bsnes |
| PSX | pcsx | beetle-psx | swanstation |
| GBA | gpsp | mgba | mgba |
| Atari 2600 | stella2014 | stella | stella |

This ensures weak CPUs get playable performance while strong CPUs get better accuracy.

## Adding New Systems

1. Add system to `config/systems.yml`
2. Specify core per CPU family
3. Run `scripts/generate-cores-from-systems <cpu>`
4. Regenerate recipes: `make recipes-all`
5. Build: `make build-all`

The build system automatically fetches core definitions from Knulli.
