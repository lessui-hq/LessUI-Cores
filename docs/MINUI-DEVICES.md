# MinUI Device Compatibility Guide

Quick reference for which core package to install on your MinUI device.

---

## 🎯 Which Build Do I Need?

### ARM32 Devices → `cortex-a7`

| Device | SoC | Notes |
|--------|-----|-------|
| **Miyoo Mini** | SSD202D | Most popular budget device |
| **Miyoo Mini Plus** | SSD202D | WiFi-enabled version |
| **Miyoo A30** | Allwinner A33 | Budget alternative |

**Installation:**
```bash
# Download and extract cortex-a7 cores to your MinUI installation
# Path: /mnt/SDCARD/.minui/cores/
```

---

### ARM64 Devices → `cortex-a53`

All 64-bit MinUI devices use the **same cortex-a53 build**:

#### H700/A133 Devices (Native Cortex-A53)

| Device | SoC | Notes |
|--------|-----|-------|
| **Anbernic RG28xx** | H700 | Tiny form factor |
| **Anbernic RG34xx** | H700 | Compact |
| **Anbernic RG34xxSP** | H700 | SP form factor |
| **Anbernic RG35xx Plus** | H700 | Clamshell |
| **Anbernic RG35xxH** | H700 | Horizontal |
| **Anbernic RG35xxSP** | H700 | SP style |
| **Anbernic RG40xxH** | H700 | Large horizontal |
| **Anbernic RG40xxV** | H700 | Large vertical |
| **Anbernic RG CubeXX** | H700 | Square screen |
| **Trimui Brick** | A133 Plus | Unique screen |
| **Trimui Smart Pro** | A133 Plus | Large screen |
| **MagicX Mini Zero 28** | A133 Plus | Third party |

**Total:** 12 devices (70% of MinUI market)

#### RK3566 Devices (Cortex-A55 → Use A53 Binaries)

| Device | SoC | Notes |
|--------|-----|-------|
| **Miyoo Flip** | RK3566 | Clamshell flagship |
| **Miyoo Mini Flip** | RK3566 | Mini + flip |
| **Powkiddy RGB30** | RK3566 | Square screen |

**Total:** 3 devices (15% of MinUI market)

**Why use cortex-a53 instead of cortex-a55?**
- Saves ~300MB SD card space (no duplicate cores)
- Performance impact: <1% (emulators don't use crypto/dotprod)
- Binary compatible (ARMv8.2 runs ARMv8.0 code perfectly)

**Installation:**
```bash
# Download and extract cortex-a53 cores to your MinUI installation
# Path: /mnt/SDCARD/.minui/cores/
```

---

## 📊 Summary

### MinUI Device Coverage

| Build | Devices Supported | SD Card Space | Market Share |
|-------|-------------------|---------------|--------------|
| **cortex-a7** | 3 devices | ~177 MB | ~15% |
| **cortex-a53** | 15 devices | ~302 MB | ~85% |
| **Total** | **18 devices** | **~479 MB** | **100%** |

### Space Savings vs. Building All 5 Families

| Strategy | Families | Total Space | Build Time |
|----------|----------|-------------|------------|
| **All families** | 5 | ~1.4 GB | ~30 min |
| **MinUI-focused (2)** | 2 | ~479 MB | ~11 min |
| **Savings** | -3 | **-66%** | **-63%** |

---

## ❌ Devices NOT Supported by MinUI

These devices run other operating systems (Knulli, JelOS, Android):

### Cortex-A35 Devices (RK3326)
- All RG-351 series (P, M, V, MP)
- All RGB10/RGB20 series
- Odroid Go Advance variants
- GameForce Chi

**OS:** Knulli, JelOS, ArkOS (not MinUI)

### Cortex-A76 Devices (Premium)
- Anbernic RG-406H, RG-406V
- Anbernic RG-556, RG-Cube
- GameForce ACE

**OS:** Android, Knulli (not MinUI)

### Other Architectures
- MIPS devices (GKD Pixel, RG-350 series)
- x86 devices (OrangePi Neo)
- Microcontroller devices (ESP32)

---

## 🔧 Advanced: Building Optional Families

If you want optimized builds for non-MinUI devices:

```makefile
# Edit Makefile, line 22:
CPU_FAMILIES := cortex-a7 cortex-a53 cortex-a55 cortex-a35 cortex-a76

# Then build:
make build-all
```

**Why you might want this:**
- Testing other distros (Knulli, JelOS)
- Maximum performance on A55 devices (crypto/dotprod)
- RG-351/RG-406 development

**Cost:**
- +1.0 GB SD card space
- +19 min build time
- More complexity

---

## 📝 Installation Paths

### MinUI Core Installation

```bash
# Standard MinUI path (most devices)
/mnt/SDCARD/.minui/cores/

# Alternative paths (device-specific)
/mnt/SDCARD/MinUI/cores/
/media/SDCARD/.minui/cores/
```

### Per-Device Instructions

**Miyoo Mini/Plus:**
1. Copy `cortex-a7/*.so` to `/mnt/SDCARD/.minui/cores/`
2. Cores appear in MinUI automatically

**RG35xx/40xx series:**
1. Copy `cortex-a53/*.so` to `/mnt/SDCARD/.minui/cores/`
2. Cores appear in MinUI automatically

**Miyoo Flip:**
1. Copy `cortex-a53/*.so` to `/mnt/SDCARD/.minui/cores/`
2. Despite being A55, use A53 binaries (compatible)

**Trimui devices:**
1. Copy `cortex-a53/*.so` to device-specific MinUI path
2. Check Trimui documentation for exact path

---

## 🎉 Recommended Workflow

**For MinUI users:**
1. Build 2 families: `make build-all`
2. Install cortex-a7 on Miyoo Mini
3. Install cortex-a53 on ALL other devices
4. Enjoy ~480MB of cores instead of 1.4GB!

**For developers/testers:**
- Enable optional families in Makefile as needed
- All configs and recipes are ready to use
- Just uncomment in CPU_FAMILIES
