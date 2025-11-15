# minarch-cores - Build libretro cores using Knulli definitions
# CPU family-based builds for optimal performance

.PHONY: help list-cores recipes-% recipes-all build-% build-all core-% package-% package-all clean-% clean docker-build shell

# Docker configuration
DOCKER_IMAGE := minarch-cores-builder
# Use native architecture (ARM64 on Apple Silicon, x86_64 elsewhere)
DOCKER_RUN := docker run --rm -v $(PWD):/workspace -w /workspace $(DOCKER_IMAGE)

# CPU families to build (MinUI-focused, space-optimized)
# Building only 2 families to save SD card space:
#   - cortex-a7:  ARM32 devices (Miyoo Mini family)
#   - cortex-a53: ARM64 universal (works on A35, A53, A55 devices)
#
# Disabled to save space:
#   - cortex-a35: No MinUI support (RG-351 runs Knulli/JelOS)
#   - cortex-a55: Works fine with A53 binaries (<1% perf difference)
#   - cortex-a76: No MinUI support (RG-406/556 run Android/Knulli)
#
# To build disabled families: Add to CPU_FAMILIES list
CPU_FAMILIES := cortex-a7 cortex-a53

# All available CPU families (including disabled)
ALL_CPU_FAMILIES := cortex-a7 cortex-a35 cortex-a53 cortex-a55 cortex-a76

# Build parallelism (default to number of CPU cores)
JOBS ?= $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

help:
	@echo "minarch-cores - ARM libretro core builder (MinUI-focused)"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. Generate recipes: make recipes-cortex-a53"
	@echo "  2. Build cores:      make build-cortex-a53"
	@echo "  3. Build all:        make build-all"
	@echo ""
	@echo "Active CPU Families (MinUI-supported, space-optimized):"
	@echo "  make build-cortex-a7        ARM32: Miyoo Mini family (3 devices)"
	@echo "  make build-cortex-a53       ARM64: Universal 64-bit (15 devices)"
	@echo "  make build-all              Build both families (~11 min)"
	@echo ""
	@echo "Device Compatibility Guide:"
	@echo "  Miyoo Mini/Plus/A30         → cortex-a7"
	@echo "  RG28xx/35xx/40xx/CubeXX     → cortex-a53 (H700/A133 native)"
	@echo "  Miyoo Flip, RGB30, RG353    → cortex-a53 (A55 compatible)"
	@echo "  Trimui Brick/Smart Pro      → cortex-a53 (A133 native)"
	@echo ""
	@echo "Optional Builds (disabled to save SD space):"
	@echo "  make build-cortex-a35       RG351 series (no MinUI)"
	@echo "  make build-cortex-a55       RK3566 optimized (minor gains)"
	@echo "  make build-cortex-a76       RG406/556 (no MinUI)"
	@echo ""
	@echo "Single Core Build (for testing/debugging):"
	@echo "  make core-cortex-a53-gambatte  Build just gambatte for cortex-a53"
	@echo "  make core-cortex-a53-flycast   Build just flycast for cortex-a53"
	@echo ""
	@echo "Recipe Generation:"
	@echo "  make recipes-cortex-a53     Generate recipes for cortex-a53"
	@echo "  make recipes-all            Generate all CPU family recipes"
	@echo ""
	@echo "Packaging:"
	@echo "  make package-cortex-a53     Create cortex-a53.zip"
	@echo "  make package-all            Create all packages"
	@echo ""
	@echo "Utilities:"
	@echo "  make list-cores             List available cores (131 from Knulli)"
	@echo "  make clean-cores            Clean .o/.a/.so artifacts (run between CPU builds!)"
	@echo "  make clean-cortex-a53       Clean specific build"
	@echo "  make clean                  Clean everything"
	@echo "  make shell                  Open shell in build container"
	@echo ""
	@echo "Device Guide:"
	@echo "  Anbernic RG28xx/35xx/40xx, Trimui → cortex-a53"
	@echo "  Miyoo Flip, RGB30, RG353          → cortex-a55"
	@echo "  Miyoo Mini series                 → cortex-a7"
	@echo "  RG351 series                      → cortex-a35"
	@echo "  Retroid Pocket 5                  → cortex-a76"

# Build Docker image
docker-build:
	@echo "=== Building Docker image ==="
	docker build -t $(DOCKER_IMAGE) .
	@echo "✓ Docker image ready"

# Generate recipes for a CPU family
.PHONY: recipes-%
recipes-%: docker-build
	@echo "=== Generating recipes for $* ==="
	@if [ ! -f config/$*.config ]; then \
		echo "ERROR: Config not found: config/$*.config"; \
		echo "Available configs: $(CPU_FAMILIES)"; \
		exit 1; \
	fi
	$(DOCKER_RUN) ruby scripts/generate-recipes $*
	@echo "✓ Recipes generated: recipes/linux/$*.json"

# Generate all recipes
.PHONY: recipes-all
recipes-all: $(addprefix recipes-,$(CPU_FAMILIES))

# Generic build target for any CPU family
.PHONY: build-%
build-%: docker-build
	@echo "=== Building cores for $* ==="
	@if [ ! -f config/$*.config ]; then \
		echo "ERROR: Config not found: config/$*.config"; \
		echo "Available configs: $(CPU_FAMILIES)"; \
		exit 1; \
	fi
	@if [ ! -f recipes/linux/$*.json ]; then \
		echo "ERROR: Recipe not found. Generate it first:"; \
		echo "  make recipes-$*"; \
		exit 1; \
	fi
	@CORE_COUNT=$$(jq 'length' recipes/linux/$*.json); \
	echo "Building $$CORE_COUNT cores for $*"
	@echo "This will take 1-3 hours..."
	@mkdir -p build/$* cores logs
	$(DOCKER_RUN) ruby scripts/build-all $* -j $(JOBS) -l logs/$*-build.log
	@echo ""
	@echo "✓ Build complete for $*"
	@echo "  Cores built: $$(ls build/$*/*.so 2>/dev/null | wc -l)"
	@du -sh build/$* 2>/dev/null || true

# Build all CPU families
.PHONY: build-all
build-all: $(addprefix build-,$(CPU_FAMILIES))
	@echo ""
	@echo "=== Build Summary ==="
	@for family in $(CPU_FAMILIES); do \
		echo "  $$family: $$(ls build/$$family/*.so 2>/dev/null | wc -l) cores"; \
	done
	@echo ""
	@echo "Total size:"
	@du -sh build/* 2>/dev/null || true

# Build a single core (for testing/debugging)
# Usage: make core-cortex-a53-gambatte
.PHONY: core-%
core-%: docker-build
	@# Parse pattern: core-<family>-<corename>
	@FAMILY=$$(echo "$*" | cut -d- -f1,2); \
	CORE=$$(echo "$*" | cut -d- -f3-); \
	echo "=== Building single core: $$CORE for $$FAMILY ==="; \
	if [ ! -f config/$$FAMILY.config ]; then \
		echo "ERROR: Config not found: config/$$FAMILY.config"; \
		echo "Available configs: $(CPU_FAMILIES)"; \
		exit 1; \
	fi; \
	if [ ! -f recipes/linux/$$FAMILY.json ]; then \
		echo "ERROR: Recipe not found. Generate it first:"; \
		echo "  make recipes-$$FAMILY"; \
		exit 1; \
	fi; \
	mkdir -p build/$$FAMILY cores logs; \
	$(DOCKER_RUN) ruby scripts/build-one $$FAMILY $$CORE -j $(JOBS); \
	if [ -f build/$$FAMILY/$${CORE}_libretro.so ]; then \
		echo ""; \
		echo "✓ Built successfully: build/$$FAMILY/$${CORE}_libretro.so"; \
		ls -lh build/$$FAMILY/$${CORE}_libretro.so | awk '{print "  Size: " $$5}'; \
	else \
		echo ""; \
		echo "✗ Build failed"; \
		exit 1; \
	fi

# Generic package target
.PHONY: package-%
package-%:
	@if [ ! -d build/$* ] || [ -z "$$(ls build/$*/*.so 2>/dev/null)" ]; then \
		echo "ERROR: No cores built for $*. Run: make build-$*"; \
		exit 1; \
	fi
	@echo "=== Packaging $* cores ==="
	@mkdir -p dist
	@cd build/$* && zip -q ../../dist/linux-$*.zip *.so
	@echo "✓ Created dist/linux-$*.zip ($$(ls -lh dist/linux-$*.zip | awk '{print $$5}'))"

# Package all families
.PHONY: package-all
package-all: $(addprefix package-,$(CPU_FAMILIES))
	@echo ""
	@echo "=== Packaging Summary ==="
	@ls -lh dist/*.zip 2>/dev/null | awk '{print "  " $$9 " - " $$5}'

# List available cores
list-cores:
	@echo "Available cores from Knulli (131 cores):"
	@find -L package/batocera/emulators/retroarch/libretro -name 'libretro-*.mk' 2>/dev/null | \
		sed 's|.*/libretro-||' | sed 's|/.*||' | sort | uniq | \
		awk '{printf "  - %s\n", $$0}' | head -20
	@echo "  ... (and 111 more)"
	@echo ""
	@echo "Total: $$(find -L package/batocera/emulators/retroarch/libretro -name 'libretro-*.mk' 2>/dev/null | wc -l | xargs) cores"

# Clean specific CPU family
.PHONY: clean-%
clean-%:
	@echo "=== Cleaning $* ==="
	rm -rf build/$*
	rm -rf output/$*
	rm -f dist/linux-$*.zip
	@echo "✓ Cleaned $*"

# Clean build artifacts from cores (IMPORTANT: Run between CPU family builds!)
.PHONY: clean-cores
clean-cores:
	@echo "=== Cleaning build artifacts from cores directories ==="
	@echo "Removing .o files..."
	find cores -name "*.o" -type f -delete 2>/dev/null || true
	@echo "Removing .a files..."
	find cores -name "*.a" -type f -delete 2>/dev/null || true
	@echo "Removing .so files..."
	find cores -name "*.so" -type f -delete 2>/dev/null || true
	@echo "Removing .dylib files..."
	find cores -name "*.dylib" -type f -delete 2>/dev/null || true
	@echo "Removing build directories..."
	find cores -type d -name "build" -exec rm -rf {} + 2>/dev/null || true
	find cores -type d -name "obj" -exec rm -rf {} + 2>/dev/null || true
	@echo "✓ Cleaned $(shell find cores -name '*.o' -o -name '*.a' -o -name '*.so' 2>/dev/null | wc -l) artifact files"

# Clean everything
clean:
	@echo "=== Cleaning all ==="
	-rm -rf build output dl dist cores
	@echo "✓ Cleaned"

# Open interactive shell in build container
shell: docker-build
	@echo "=== Opening shell in build container ==="
	@echo "Debian Buster (GCC 8.3.0, glibc 2.28)"
	@echo "Type 'exit' to return"
	@echo ""
	docker run --rm -it -v $(PWD):/workspace -w /workspace $(DOCKER_IMAGE) /bin/bash
