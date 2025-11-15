# CPU Family Specifications

Technical specifications for each ARM CPU family.

## Cortex-A7 (ARM32)

**Architecture:** ARMv7-A (32-bit)
**Year:** 2011
**Instruction Set:** ARM, Thumb-2
**SIMD:** NEON
**Features:** VFPv4, Hardware virtualization

**Compiler Flags:**
```
-march=armv7ve -mcpu=cortex-a7 -mtune=cortex-a7
-mfpu=neon-vfpv4 -mfloat-abi=hard
```

**Devices:**
- Allwinner R16 (Miyoo Mini)
- Allwinner A33 (Miyoo A30)

---

## Cortex-A35 (ARM64 Entry)

**Architecture:** ARMv8-A (64-bit)
**Year:** 2015
**Instruction Set:** AArch64, AArch32
**SIMD:** NEON (Advanced SIMD)
**Features:** CRC32, Crypto extensions

**Compiler Flags:**
```
-march=armv8-a+crc+fp+simd -mcpu=cortex-a35 -mtune=cortex-a35
```

**Devices:**
- Rockchip RK3326 (RG-351 series)

---

## Cortex-A53 (ARM64 Universal)

**Architecture:** ARMv8-A (64-bit)
**Year:** 2012
**Instruction Set:** AArch64, AArch32
**SIMD:** NEON (Advanced SIMD)
**Features:** CRC32

**Compiler Flags:**
```
-march=armv8-a+crc -mcpu=cortex-a53 -mtune=cortex-a53
```

**Devices:**
- Allwinner H700 (RG28xx, RG35xx, RG40xx)
- Allwinner A133 Plus (Trimui Brick, Smart Pro)

**Notes:** Most widely deployed ARM64 CPU. Used as universal baseline.

---

## Cortex-A55 (ARM64 Modern)

**Architecture:** ARMv8.2-A (64-bit)
**Year:** 2017
**Instruction Set:** AArch64, AArch32
**SIMD:** NEON (Advanced SIMD)
**Features:** CRC32, Crypto, Dot Product (ML/AI)

**Compiler Flags:**
```
-march=armv8.2-a+crc+crypto+dotprod -mcpu=cortex-a55 -mtune=cortex-a55
```

**Devices:**
- Rockchip RK3566 (Miyoo Flip, RGB30, RG353)

**Notes:** ARMv8.2 adds crypto and dot product instructions. Backward compatible with ARMv8.0 (A53) binaries.

---

## Cortex-A76 (ARM64 High-Performance)

**Architecture:** ARMv8.2-A (64-bit)
**Year:** 2018
**Instruction Set:** AArch64, AArch32
**SIMD:** NEON (Advanced SIMD)
**Features:** CRC32, Crypto, Dot Product, Release Consistent PC

**Compiler Flags:**
```
-march=armv8.2-a+crc+crypto+rcpc+dotprod -mtune=cortex-a76.cortex-a55
```

**Devices:**
- Rockchip RK3588 (RG406 series)
- Snapdragon (Retroid Pocket 5)

**Notes:** Used in big.LITTLE configurations (A76 performance cores + A55 efficiency cores). Tune flag optimizes for both.

---

## Compatibility Matrix

| Source CPU | Can Run On |
|------------|-----------|
| Cortex-A7 | A7 only (ARMv7 is 32-bit) |
| Cortex-A35 | A35, A53, A55, A76 |
| Cortex-A53 | A53, A55, A76 |
| Cortex-A55 | A55, A76 |
| Cortex-A76 | A76 |

**Example:** Cortex-A53 binaries work on A53, A55, and A76 devices because they all support ARMv8.0 baseline instructions.
