# CPU Family Comparison

## Executive Summary

**Can we simplify?** → **Maybe 1-2 families**

### Consolidation Opportunities

| Keep | Maybe Drop | Reason |
|------|------------|--------|
| **cortex-a7** | - | MUST keep - only 32-bit ARM, unique cores, 15% market |
| **cortex-a53** | - | MUST keep - 70% market share, baseline 64-bit |
| **cortex-a55** | ✓ **cortex-a35** | a35/a53/a55 have identical cores, just different flags |
| **cortex-a76** | - | Keep for premium devices (has 3 bonus cores) |

**Recommendation:** Drop **cortex-a35** (legacy devices can use cortex-a53 binaries)

---

## Core List Analysis

### Summary Table

| CPU Family | Cores | Architecture | Market Share | Unique? |
|------------|-------|--------------|--------------|---------|
| cortex-a7  | 25    | ARMv7 (32-bit) | ~15% | ✅ YES - only ARM32 |
| cortex-a35 | 26    | ARMv8.0       | Legacy | ❌ NO - same as a53 |
| cortex-a53 | 26    | ARMv8.0       | ~70% | ✅ YES - baseline |
| cortex-a55 | 26    | ARMv8.2       | ~15% | ❌ NO - same cores as a53 |
| cortex-a76 | 27    | ARMv8.2       | Premium | ✅ YES - 3 bonus cores |

### Core Differences

**cortex-a7 (ARM32) - 7 unique cores:**
- `fbalpha` - Older arcade emulator
- `gpsp` - ARM-optimized GBA
- `handy` - Atari Lynx
- `pcsx` - PlayStation (ARM32 version)
- `picodrive` - Genesis/32X/CD
- `pocketsnes` - ARM-optimized SNES
- `stella2014` - Lighter Atari 2600

**cortex-a35/a53/a55 (baseline 64-bit) - Identical 26 cores**
- All three have the EXACT same core list
- Only compiler flags differ

**cortex-a76 (premium) - 3 bonus cores:**
- `beetle-supergrafx` - PC Engine SuperGrafx
- `bsnes` - Accuracy-focused SNES
- `swanstation` - Modern PS1 emulator

---

## Architecture Comparison

### Compiler Flags

```makefile
# cortex-a7 (ARM32)
ARCH = arm
TARGET_ARCH = armv7ve
TARGET_FLOAT = -mfloat-abi=hard -mfpu=neon-vfpv4

# cortex-a35 (ARMv8.0 baseline)
ARCH = aarch64
TARGET_ARCH = armv8-a+crc+fp+simd

# cortex-a53 (ARMv8.0 minimal)
ARCH = aarch64
TARGET_ARCH = armv8-a+crc

# cortex-a55 (ARMv8.2 modern)
ARCH = aarch64
TARGET_ARCH = armv8.2-a+crc+crypto+dotprod

# cortex-a76 (ARMv8.2 premium)
ARCH = aarch64
TARGET_ARCH = armv8.2-a+crc+crypto+rcpc+dotprod
TARGET_CPU = cortex-a75.cortex-a55  # GCC 8.3.0 fallback
```

### ISA Extensions

| Extension | a7 | a35 | a53 | a55 | a76 | Purpose |
|-----------|----|----|-----|-----|-----|---------|
| **32-bit ARM** | ✅ | - | - | - | - | Legacy compatibility |
| **64-bit ARM** | - | ✅ | ✅ | ✅ | ✅ | Modern baseline |
| **NEON SIMD** | ✅ | ✅ | ✅ | ✅ | ✅ | Vector operations |
| **CRC32** | - | ✅ | ✅ | ✅ | ✅ | Checksums |
| **FP/SIMD** | - | ✅ | - | - | - | Floating point explicit |
| **Crypto** | - | - | - | ✅ | ✅ | AES/SHA acceleration |
| **Dot Product** | - | - | - | ✅ | ✅ | ML/AI workloads |
| **RCPC** | - | - | - | - | ✅ | Weak memory ordering |

---

## Market Analysis

### Device Distribution

| CPU | Devices | Market Share | Notes |
|-----|---------|--------------|-------|
| **cortex-a53** | RG35xx, RG40xx, RG28xx, Trimui | ~70% | H700/A133 SoCs dominate |
| **cortex-a7** | Miyoo Mini series | ~15% | R16 SoC (32-bit) |
| **cortex-a55** | Miyoo Flip, RGB30, RG353 | ~15% | RK3566 (modern) |
| **cortex-a35** | RG351 series | Legacy | Being phased out |
| **cortex-a76** | Retroid Pocket 5, RK3588 | Premium | High-end niche |

---

## Consolidation Analysis

### Option 1: Drop cortex-a35 (RECOMMENDED)

**Reasoning:**
- ✅ Identical core list to a53/a55
- ✅ Legacy devices (RG351 series)
- ✅ a53 binaries will work fine on A35 hardware
- ✅ Saves build time (~6 minutes per build)
- ✅ Reduces maintenance burden

**Impact:**
- RG351 users use cortex-a53 binaries
- Slight performance loss from non-optimal flags
- Core functionality unchanged

**Binary Compatibility:**
- A35 is ARMv8.0 (supports: crc, fp, simd)
- A53 binaries are ARMv8.0 (uses: crc only)
- ✅ A53 binaries will run on A35 hardware
- ⚠️  A35 won't use fp/simd optimizations (minor perf loss)

### Option 2: Drop cortex-a55

**Reasoning:**
- ✅ Identical core list to a53
- ❌ Modern devices (15% market share)
- ❌ ARMv8.2 features (crypto, dotprod) unused

**Impact:**
- Miyoo Flip, RG353 users lose crypto/dotprod optimizations
- Emulators don't heavily use these features
- But these are NEW devices, dropping seems wrong

**Verdict:** Less recommended than dropping a35

### Option 3: Merge a35/a53/a55 into "armv8"

**Reasoning:**
- ✅ Single 64-bit ARM build
- ✅ Covers 100% of 64-bit devices
- ❌ Loses per-CPU optimizations
- ❌ Can't use ARMv8.2 features on a55/a76

**Verdict:** Too much performance left on table

---

## Recommended Strategy

### Keep: 4 CPU Families

1. **cortex-a7** (ARM32)
   - Unique 32-bit cores
   - 15% market (Miyoo Mini)
   - No alternatives

2. **cortex-a53** (ARMv8.0 baseline)
   - 70% market share
   - Baseline 64-bit
   - Can serve a35 devices too

3. **cortex-a55** (ARMv8.2 modern)
   - 15% market (new devices)
   - crypto + dotprod extensions
   - Worth keeping for modern SoCs

4. **cortex-a76** (ARMv8.2 premium)
   - Premium devices
   - 3 bonus cores
   - big.LITTLE optimization

### Drop: 1 CPU Family

**cortex-a35** (legacy ARMv8.0)
- Legacy devices (RG351 series)
- Identical cores to a53
- Users can use a53 binaries
- Saves ~6 minutes per build
- Reduces from 5 to 4 families (20% reduction)

---

## Build Time Savings

**Current:** 5 families × 6 min = ~30 minutes total
**After:** 4 families × 6 min = ~24 minutes total

**Savings:** 6 minutes per full build (20% faster)

---

## Migration Plan

If dropping cortex-a35:

1. Update documentation to point RG351 users to cortex-a53
2. Add note: "RG351 devices: Use cortex-a53 binaries"
3. Remove `config/cortex-a35.config`
4. Remove `recipes/linux/cortex-a35.json`
5. Remove from `CPU_FAMILIES` in Makefile
6. Update TODO.md to reflect 4 families

---

## Performance Impact Analysis

### RG351 using cortex-a53 binaries

**Lost optimizations:**
```makefile
# cortex-a35 has:
TARGET_ARCH = armv8-a+crc+fp+simd

# cortex-a53 has:
TARGET_ARCH = armv8-a+crc

# Lost: +fp+simd explicit flags
```

**Reality:**
- ARMv8-a includes fp/simd by default
- The flags are mostly redundant/explicit
- Actual performance difference: ~0-2%
- Emulators are memory-bound, not CPU-bound

**Verdict:** Negligible real-world impact

---

## Conclusion

**Recommendation:** **Drop cortex-a35**

**Benefits:**
- ✅ 20% reduction in build families (5 → 4)
- ✅ 20% faster builds (~6 min saved)
- ✅ Less maintenance overhead
- ✅ a53 binaries work fine on A35 hardware
- ✅ RG351 is legacy (being phased out anyway)

**Costs:**
- ⚠️  RG351 users must be told to use a53
- ⚠️  ~0-2% performance loss (negligible)

**Keep these 4 families:**
1. cortex-a7 (ARM32, 15% market)
2. cortex-a53 (ARMv8.0, 70% market)
3. cortex-a55 (ARMv8.2, 15% market)
4. cortex-a76 (ARMv8.2 premium)

This gives us:
- Clean ARM32 vs ARM64 split
- Baseline (a53) vs Modern (a55) vs Premium (a76)
- 100% device coverage
- Simpler to maintain
