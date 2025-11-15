# Documentation Index

Quick guide to which file has what information.

---

## 📖 User Documentation (Root)

**Start here if you're installing cores on your device:**

| File | Purpose | Who Needs This |
|------|---------|----------------|
| **../README.md** | Project overview, quick start | Everyone |
| **../TODO.md** | Build status, what's complete | Status check |
| **make help** | Build commands reference | Builders |

---

## 📚 Reference Documentation (docs/)

**Detailed guides and analysis:**

| File | Purpose | Who Needs This |
|------|---------|----------------|
| **MINUI-DEVICES.md** | Device compatibility guide | MinUI users |
| **CORE_SELECTION.md** | Why we picked these cores | Curious users |
| **CPU-COMPARISON.md** | Architecture analysis | Optimization nerds |
| **HANDHELD-DATABASE.md** | 70+ devices by CPU | Researchers |

---

## 🎯 Quick Reference

### "Which cores do I install?"
→ **docs/MINUI-DEVICES.md**

### "Why only 2 CPU families?"
→ **docs/CPU-COMPARISON.md**

### "Why these specific cores?"
→ **docs/CORE_SELECTION.md**

### "What bugs were fixed?"
→ **TODO.md** (Section: "Fixed Issues")

### "Which devices use which CPU?"
→ **docs/HANDHELD-DATABASE.md**

### "How do I build?"
→ **README.md** or `make help`

### "Can I enable cortex-a55/a35/a76?"
→ **Makefile** line 22 (add to CPU_FAMILIES)

---

## 📊 At a Glance

**Active Build:**
- 2 families: cortex-a7, cortex-a53
- 51 cores total
- 479 MB
- 18 MinUI devices (100%)

**Optional Build:**
- +3 families: cortex-a35, cortex-a55, cortex-a76
- +79 cores
- +920 MB
- Non-MinUI devices (Knulli, Android)

**To enable optional:** Edit `Makefile` line 22
