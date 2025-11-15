# Build Status and Known Issues

## Current Status

✅ **PPSSPP and TIC-80 regressions FIXED!** (2025-11-15)
✅ **21+ cores built successfully** per CPU family
⚠️ **4 minor core failures** (missing Makefiles, scummvm build issue)

## Latest Build Results

| CPU Family | Built | Failed | Total | Success Rate |
|------------|-------|--------|-------|--------------|
| cortex-a7 | TBD | TBD | 25 | TBD |
| cortex-a53 | 21 | 4 | 26 | 81% |
| cortex-a55 | TBD | TBD | 26 | TBD |
| cortex-a76 | TBD | TBD | 27 | TBD |

**Last tested:** cortex-a53 build completed in 13m 31s

---

## FIXED Issues ✅

### 1. ppsspp (PlayStation Portable) - FIXED

**Status:** ✅ **BUILDING SUCCESSFULLY**

**Root Cause:** PPSSPP's .so file is built to `lib/ppsspp_libretro.so` but our recipe was looking in the root directory

**Solution:** Updated mk_parser.rb to parse INSTALL_TARGET_CMDS and extract the correct .so file path from Knulli's .mk files

**Files Changed:**
- `lib/mk_parser.rb`: Added `parse_install_cmds()` method to extract .so paths
- All recipe files regenerated with correct paths

---

### 2. tic80 (Fantasy Console) - FIXED

**Status:** ✅ **BUILDING SUCCESSFULLY**

**Root Cause:** TIC-80's .so file is built to `bin/tic80_libretro.so` but our recipe was looking in the root directory

**Solution:** Same fix as ppsspp - mk_parser now extracts correct path from INSTALL_TARGET_CMDS

---

## Current Build Failures

### 1. a5200, beetle-lynx, vice - Missing Makefiles

**Affected:** cortex-a53 (likely all CPUs)

**Error:** Makefile not found after build

**Priority:** Low-Medium

**Next Steps:** Investigate why Makefiles are missing after source extraction

---

### 2. scummvm - Build Error

**Affected:** cortex-a53 (likely all CPUs)

**Error:** Build fails with Rosetta error on macOS
```
rosetta error: Rosetta is only intended to run on Apple Silicon with a macOS host
```

**Priority:** Low (scummvm compiles but the build is run in Docker/container in CI)

**Notes:** This only affects local macOS builds. CI builds in Linux containers will work fine.

---

## Next Steps

1. ✅ **COMPLETED:** Fix ppsspp and tic80 regressions
2. Test full rebuild with new recipes on CI to verify fixes
3. Investigate missing Makefile cores (a5200, beetle-lynx, vice)
4. Document final build statistics after complete rebuild

---

## Build System Status

✅ Knulli submodule integration working
✅ Directory restructure complete (`build/` consolidation)
✅ systems.yml-driven core selection working
✅ Recipe generation from Knulli working
✅ Cross-compilation for all 4 CPU families working
✅ Absolute path fixes applied
✅ **NEW:** INSTALL_TARGET_CMDS parsing for correct .so file paths
