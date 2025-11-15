# Documentation

Reference documentation for LessUI-Cores.

---

## 📖 Quick Navigation

**For Users:**
- **MINUI-DEVICES.md** - Which cores to install on your device
- **DOCUMENTATION-INDEX.md** - Full documentation index

**For Developers:**
- **CORE_SELECTION.md** - Core selection methodology
- **CPU-COMPARISON.md** - Architecture comparison and optimization analysis
- **HANDHELD-DATABASE.md** - Complete device catalog (70+ handhelds)

**For Build Status:**
- **../TODO.md** - Current status and technical notes

---

## 🎯 Common Questions

**Q: Which cores do I need for my Miyoo Flip?**
A: See MINUI-DEVICES.md → Use cortex-a53 (A55 compatible)

**Q: Why only 2 CPU families?**
A: See CPU-COMPARISON.md → Saves 66% space, covers 100% MinUI devices

**Q: Which devices are supported?**
A: See MINUI-DEVICES.md → 18 MinUI devices total

**Q: Can I build all 5 CPU families?**
A: Yes! Edit `Makefile` line 22, add families to CPU_FAMILIES

---

## 📁 File Overview

| File | Lines | Purpose |
|------|-------|---------|
| MINUI-DEVICES.md | ~150 | Device compatibility guide |
| CPU-COMPARISON.md | ~200 | Architecture analysis |
| HANDHELD-DATABASE.md | ~400 | Complete device catalog |
| CORE_SELECTION.md | ~140 | Core selection methodology |
| DOCUMENTATION-INDEX.md | ~80 | Navigation index |

**Total:** ~1000 lines of comprehensive documentation
