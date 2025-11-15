# Documentation Index

Quick reference for finding information.

## Core Documentation

| File | Purpose |
|------|---------|
| **[../README.md](../README.md)** | Build instructions and project overview |
| **[MINUI-DEVICES.md](MINUI-DEVICES.md)** | MinUI device compatibility |
| **[HANDHELD-DATABASE.md](HANDHELD-DATABASE.md)** | Complete device database |
| **[CPU-COMPARISON.md](CPU-COMPARISON.md)** | CPU family specifications |
| **[CORE_SELECTION.md](CORE_SELECTION.md)** | Core selection methodology |

## Common Questions

**Which cores for my device?** → [MINUI-DEVICES.md](MINUI-DEVICES.md)

**What CPU does my device use?** → [HANDHELD-DATABASE.md](HANDHELD-DATABASE.md)

**How to build cores?** → [../README.md](../README.md)

**How are cores selected?** → [CORE_SELECTION.md](CORE_SELECTION.md)

## Build System

- **systems.yml** - System and core definitions (source of truth)
- **Makefile** - Build commands
- **config/*.config** - CPU compiler flags
- **config/*.list** - Generated core lists per CPU
