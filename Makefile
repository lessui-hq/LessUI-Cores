# minarch-cores Makefile
# Builds libretro cores using official recipes via Docker

.PHONY: all help build-arm7neonhf build-aarch64 build-arm7neonhf-custom build-aarch64-custom build-all build-all-custom apply-build-fixes-docker apply-custom-patches-docker clean-patches-docker package-arm7neonhf package-aarch64 package-arm7neonhf-custom package-aarch64-custom package-all clean shell

# Include configuration
include config.env

# Docker image name
DOCKER_IMAGE := minarch-cores-builder
DOCKER_RUN := docker run --rm -v $(PWD):/workspace $(DOCKER_IMAGE)

# Recipe paths
RECIPE_ARMV7 := recipes/linux/cores-linux-arm7neonhf
RECIPE_AARCH64 := recipes/linux/cores-linux-aarch64
RECIPE_ARMV7_CUSTOM := recipes/linux/cores-linux-arm7neonhf-custom
RECIPE_AARCH64_CUSTOM := recipes/linux/cores-linux-aarch64-custom

# Build options
FORCE := YES  # Always do full rebuilds for reliability and reproducibility
JOBS ?= 8     # Parallel build jobs (override in config.env or via JOBS=N make ...)

help:
	@echo "minarch-cores - Local Build System"
	@echo ""
	@echo "Complete Workflow:"
	@echo "  make all                      Build all cores + create all packages"
	@echo ""
	@echo "Clean Builds (our recipes + fake08/race/supafaust):"
	@echo "  make build-arm7neonhf         Build arm7neonhf cores"
	@echo "  make build-aarch64            Build aarch64 cores"
	@echo "  make build-all                Build both architectures"
	@echo ""
	@echo "Custom Builds (minarch customizations):"
	@echo "  make build-arm7neonhf-custom Build custom arm7neonhf cores"
	@echo "  make build-aarch64-custom    Build custom aarch64 cores"
	@echo "  make build-all-custom        Build all clean + custom"
	@echo ""
	@echo "Packaging (create distribution zips):"
	@echo "  make package-arm7neonhf         Create linux-arm7neonhf.zip"
	@echo "  make package-aarch64            Create linux-aarch64.zip"
	@echo "  make package-arm7neonhf-custom Create linux-arm7neonhf-custom.zip"
	@echo "  make package-aarch64-custom    Create linux-aarch64-custom.zip"
	@echo "  make package-all                Create all 4 zip files"
	@echo ""
	@echo "Build Options:"
	@echo "  JOBS=N make build-*        Parallel jobs (default: 8)"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean                 Remove build artifacts"
	@echo "  make shell                 Open shell in build container"
	@echo ""
	@echo "Note: All builds are full rebuilds for reliability and reproducibility."
	@echo "      Builds take 1-3 hours. GitHub Actions cache speeds up repo clones."

# Complete workflow: build all + package all
all: build-all package-all
	@echo ""
	@echo "✓ Build and packaging complete"
	@echo "  Packages created:"
	@ls -lh dist/*.zip 2>/dev/null || true

# Build Docker image (only needed once)
docker-build:
	@echo "=== Building Docker image (Debian Buster) ==="
	docker build -t $(DOCKER_IMAGE) .
	@echo "✓ Docker image ready"

# Apply build fix patches (runs inside Docker to avoid permission issues)
apply-build-fixes-docker:
	@echo "=== Applying build fix patches (inside Docker) ==="
	$(DOCKER_RUN) bash -c "for core in $(BUILD_FIX_CORES); do \
		echo \"  → Cleaning and patching \$$core\"; \
		cd cores/libretro-\$$core && git checkout . && git clean -fd && cd ../..; \
		patch_file=\$$(ls patches/build/\$$core-*.patch 2>/dev/null | head -1); \
		if [ -n \"\$$patch_file\" ]; then \
			echo \"    Applying \$$patch_file\"; \
			cd cores/libretro-\$$core && patch -p1 < ../../\$$patch_file && cd ../..; \
		fi; \
	done"
	@echo "✓ Build fix patches applied"

# Apply custom behavior patches (runs inside Docker to avoid permission issues)
apply-custom-patches-docker:
	@echo "=== Applying custom behavior patches (inside Docker) ==="
	$(DOCKER_RUN) bash -c "for core in $(CUSTOM_CORES); do \
		echo \"  → Cleaning and patching \$$core\"; \
		cd cores/libretro-\$$core && git checkout . && git clean -fd && cd ../..; \
		patch_file=\$$(ls patches/custom/\$$core-*.patch 2>/dev/null | head -1); \
		if [ -n \"\$$patch_file\" ]; then \
			echo \"    Applying \$$patch_file\"; \
			cd cores/libretro-\$$core && patch -p1 < ../../\$$patch_file && cd ../..; \
		fi; \
	done"
	@echo "✓ Custom patches applied"

# Clean all patches (runs inside Docker to avoid permission issues)
clean-patches-docker:
	@echo "=== Reverting all patches (inside Docker) ==="
	$(DOCKER_RUN) bash -c "for core in $(BUILD_FIX_CORES) $(CUSTOM_CORES); do \
		echo \"  → Reverting \$$core\"; \
		cd cores/libretro-\$$core && git checkout . && git clean -fd && cd ../..; \
	done"
	@echo "✓ Patches reverted"

# Internal build function - use specific targets below
# Usage: $(call build-cores,arch-name,recipe-path,arch-type,extra-patches)
define build-cores
	@echo "=== Building $(1) cores ==="
	@echo "Recipe: $(2)"
	@test -z "$(4)" || echo "Custom cores: $(CUSTOM_CORES)"
	@echo "This will take 1-3 hours depending on your system..."
	@echo "  → Cleaning output directory for fresh build..."
	@rm -rf build/$(1)
	@mkdir -p build/$(1)
	@echo "  → Fetching/updating repositories..."
	$(DOCKER_RUN) bash -c "chmod +x scripts/*.sh && \
		./scripts/fetch-cores.sh $(2) cores"
	$(MAKE) apply-build-fixes-docker
	$(if $(4),$(MAKE) apply-custom-patches-docker)
	@echo "  → Building cores..."
	$(DOCKER_RUN) bash -c "chmod +x scripts/*.sh && \
		JOBS=$(JOBS) ./scripts/build-cores.sh $(2) $(3) cores build/$(1)"
	@echo "✓ $(1) cores built: $$(ls build/$(1)/*.so 2>/dev/null | wc -l | xargs) cores"
	@test "$(1)" = "arm7neonhf" -o "$(1)" = "aarch64" && du -sh build/$(1) 2>/dev/null || true
	$(MAKE) clean-patches-docker
endef

# Build 32-bit ARM cores
build-arm7neonhf: docker-build
	$(call build-cores,arm7neonhf,$(RECIPE_ARMV7),arm7neonhf)

# Build 64-bit ARM cores
build-aarch64: docker-build
	$(call build-cores,aarch64,$(RECIPE_AARCH64),aarch64)

# Build 32-bit ARM custom cores
build-arm7neonhf-custom: docker-build
	$(call build-cores,arm7neonhf-custom,$(RECIPE_ARMV7_CUSTOM),arm7neonhf,yes)

# Build 64-bit ARM custom cores
build-aarch64-custom: docker-build
	$(call build-cores,aarch64-custom,$(RECIPE_AARCH64_CUSTOM),aarch64,yes)

# Build both architectures (clean only)
build-all: build-arm7neonhf build-aarch64
	@echo ""
	@echo "=== Build Summary ==="
	@echo "  arm7neonhf cores: $$(ls build/arm7neonhf/*.so 2>/dev/null | wc -l | xargs)"
	@echo "  aarch64 cores:    $$(ls build/aarch64/*.so 2>/dev/null | wc -l | xargs)"
	@echo ""
	@echo "Total size:"
	@du -sh build/arm7neonhf build/aarch64 2>/dev/null || true

# Build all: clean + custom for both architectures
build-all-custom: build-arm7neonhf build-aarch64 build-arm7neonhf-custom build-aarch64-custom
	@echo ""
	@echo "=== Complete Build Summary ==="
	@echo "Clean builds:"
	@echo "  arm7neonhf cores: $$(ls build/arm7neonhf/*.so 2>/dev/null | wc -l | xargs)"
	@echo "  aarch64 cores:    $$(ls build/aarch64/*.so 2>/dev/null | wc -l | xargs)"
	@echo ""
	@echo "Custom builds:"
	@echo "  arm7neonhf cores: $$(ls build/arm7neonhf-custom/*.so 2>/dev/null | wc -l | xargs)"
	@echo "  aarch64 cores:    $$(ls build/aarch64-custom/*.so 2>/dev/null | wc -l | xargs)"
	@echo ""
	@echo "Total size:"
	@du -sh build/* 2>/dev/null || true

# Internal packaging function
# Usage: $(call package-cores,arch-name)
define package-cores
	@echo "=== Packaging $(1) cores ==="
	@mkdir -p dist
	@cd build/$(1) && zip -q ../../dist/linux-$(1).zip *.so
	@echo "✓ Created dist/linux-$(1).zip ($$(ls -lh dist/linux-$(1).zip | awk '{print $$5}'))"
endef

# Package targets
package-arm7neonhf: build-arm7neonhf
	$(call package-cores,arm7neonhf)

package-aarch64: build-aarch64
	$(call package-cores,aarch64)

package-arm7neonhf-custom: build-arm7neonhf-custom
	$(call package-cores,arm7neonhf-custom)

package-aarch64-custom: build-aarch64-custom
	$(call package-cores,aarch64-custom)

# Package all cores into zip files
package-all: package-arm7neonhf package-aarch64 package-arm7neonhf-custom package-aarch64-custom
	@echo ""
	@echo "=== Packaging Summary ==="
	@ls -lh dist/*.zip 2>/dev/null | awk '{print "  " $$9 " - " $$5}'

# Clean build artifacts
clean:
	@echo "=== Cleaning ==="
	rm -rf build/
	rm -rf dist/
	rm -rf cores/
	@echo "✓ Cleaned"

# Open interactive shell in build container (for debugging)
shell: docker-build
	@echo "=== Opening shell in build container ==="
	@echo "Debian Buster (GCC 8.3.0, glibc 2.28)"
	@echo "Cores directory: /workspace/cores"
	@echo "Type 'exit' to return"
	@echo ""
	docker run --rm -it -v $(PWD):/workspace $(DOCKER_IMAGE) /bin/bash
