# frozen_string_literal: true

require 'spec_helper'
require 'cores_builder'
require 'tmpdir'

RSpec.describe CoresBuilder do
  let(:fixtures_dir) { File.expand_path('fixtures/recipes/linux', __dir__) }
  let(:cores_dir) { Dir.mktmpdir('cores_spec') }
  let(:cache_dir) { Dir.mktmpdir('cache_spec') }
  let(:output_dir) { Dir.mktmpdir('output_spec') }
  let(:recipe_file) { File.join(fixtures_dir, 'arm64.yml') }

  before do
    FileUtils.mkdir_p(fixtures_dir)
    File.write(recipe_file, <<~YAML)
      # Test Recipe
      ---
      config:
        arch: aarch64
        target_cross: aarch64-linux-gnu-
        gnu_target_name: aarch64-buildroot-linux-gnu
        target_cpu: cortex-a53
        target_arch: armv8-a+crc
        target_optimization: "-march=armv8-a+crc -mcpu=cortex-a53"
        target_float: ""
        target_cflags: "-O2 -pipe -fsigned-char"
        target_cxxflags: "-O2 -pipe -fsigned-char"
        target_ldflags: ""

      cores:
        gambatte:
          repo: libretro/gambatte-libretro
          commit: 47c5a2feaa9c253efc407283d9247a3c055f9efb
          build_type: make
          makefile: Makefile
          build_dir: "."
          platform: unix
          so_file: gambatte_libretro.so

        fceumm:
          repo: libretro/libretro-fceumm
          commit: abc123def456
          build_type: make
          makefile: Makefile.libretro
          build_dir: "."
          platform: unix
          so_file: fceumm_libretro.so
    YAML
  end

  after do
    FileUtils.rm_rf(File.expand_path('fixtures', __dir__))
    FileUtils.rm_rf(cores_dir)
    FileUtils.rm_rf(cache_dir)
    FileUtils.rm_rf(output_dir)
  end

  describe '#initialize' do
    it 'sets default paths based on cpu_family' do
      builder = described_class.new(cpu_family: 'arm64', recipe_file: recipe_file)

      expect(builder.cpu_family).to eq('arm64')
      expect(builder.cores_dir).to include('output/cores-arm64')
      expect(builder.output_dir).to include('output/arm64')
    end

    it 'accepts custom paths' do
      builder = described_class.new(
        cpu_family: 'arm64',
        cores_dir: cores_dir,
        cache_dir: cache_dir,
        output_dir: output_dir,
        recipe_file: recipe_file
      )

      expect(builder.cores_dir).to eq(cores_dir)
      expect(builder.cache_dir).to eq(cache_dir)
      expect(builder.output_dir).to eq(output_dir)
    end

    it 'accepts parallel settings' do
      builder = described_class.new(
        cpu_family: 'arm64',
        recipe_file: recipe_file,
        parallel_fetch: 8,
        parallel_build: 2
      )

      expect(builder.parallel_fetch).to eq(8)
      expect(builder.parallel_build).to eq(2)
    end

    it 'accepts dry_run option' do
      builder = described_class.new(
        cpu_family: 'arm64',
        recipe_file: recipe_file,
        dry_run: true
      )

      expect(builder.dry_run).to be true
    end

    it 'accepts skip_fetch and skip_build options' do
      builder = described_class.new(
        cpu_family: 'arm64',
        recipe_file: recipe_file,
        skip_fetch: true,
        skip_build: true
      )

      expect(builder.skip_fetch).to be true
      expect(builder.skip_build).to be true
    end
  end

  describe '#run' do
    let(:builder) do
      described_class.new(
        cpu_family: 'arm64',
        cores_dir: cores_dir,
        cache_dir: cache_dir,
        output_dir: output_dir,
        recipe_file: recipe_file
      )
    end

    context 'with skip_fetch and skip_build' do
      let(:skip_builder) do
        described_class.new(
          cpu_family: 'arm64',
          cores_dir: cores_dir,
          cache_dir: cache_dir,
          output_dir: output_dir,
          recipe_file: recipe_file,
          skip_fetch: true,
          skip_build: true
        )
      end

      it 'returns 0 without doing fetch or build' do
        result = skip_builder.run

        expect(result).to eq(0)
      end
    end

    context 'with skip_build only' do
      let(:fetch_only_builder) do
        described_class.new(
          cpu_family: 'arm64',
          cores_dir: cores_dir,
          cache_dir: cache_dir,
          output_dir: output_dir,
          recipe_file: recipe_file,
          skip_build: true
        )
      end

      it 'runs fetch but skips build' do
        # Mock SourceFetcher
        fetcher = instance_double('SourceFetcher')
        allow(SourceFetcher).to receive(:new).and_return(fetcher)
        allow(fetcher).to receive(:fetch_all)

        result = fetch_only_builder.run

        expect(fetcher).to have_received(:fetch_all)
        expect(result).to eq(0)
      end
    end

    context 'with skip_fetch only' do
      let(:build_only_builder) do
        described_class.new(
          cpu_family: 'arm64',
          cores_dir: cores_dir,
          cache_dir: cache_dir,
          output_dir: output_dir,
          recipe_file: recipe_file,
          skip_fetch: true
        )
      end

      it 'skips fetch but runs build' do
        # Mock CoreBuilder
        core_builder = instance_double('CoreBuilder')
        allow(CoreBuilder).to receive(:new).and_return(core_builder)
        allow(core_builder).to receive(:build_all).and_return(0)

        result = build_only_builder.run

        expect(CoreBuilder).to have_received(:new)
        expect(core_builder).to have_received(:build_all)
        expect(result).to eq(0)
      end
    end

    context 'full run' do
      it 'runs both fetch and build phases' do
        # Mock both components
        fetcher = instance_double('SourceFetcher')
        allow(SourceFetcher).to receive(:new).and_return(fetcher)
        allow(fetcher).to receive(:fetch_all)

        core_builder = instance_double('CoreBuilder')
        allow(CoreBuilder).to receive(:new).and_return(core_builder)
        allow(core_builder).to receive(:build_all).and_return(0)

        result = builder.run

        expect(fetcher).to have_received(:fetch_all)
        expect(core_builder).to have_received(:build_all)
        expect(result).to eq(0)
      end

      it 'passes correct options to SourceFetcher' do
        allow(SourceFetcher).to receive(:new).and_call_original

        fetcher = instance_double('SourceFetcher')
        expect(SourceFetcher).to receive(:new).with(
          cores_dir: cores_dir,
          cache_dir: cache_dir,
          logger: anything,
          parallel: 4  # Default parallel_fetch
        ).and_return(fetcher)
        allow(fetcher).to receive(:fetch_all)

        core_builder = instance_double('CoreBuilder')
        allow(CoreBuilder).to receive(:new).and_return(core_builder)
        allow(core_builder).to receive(:build_all).and_return(0)

        builder.run
      end

      it 'passes correct options to CoreBuilder' do
        fetcher = instance_double('SourceFetcher')
        allow(SourceFetcher).to receive(:new).and_return(fetcher)
        allow(fetcher).to receive(:fetch_all)

        expect(CoreBuilder).to receive(:new).with(
          cores_dir: cores_dir,
          output_dir: output_dir,
          cpu_config: anything,
          logger: anything,
          parallel: 1,  # Default parallel_build
          dry_run: false
        ).and_call_original

        core_builder = instance_double('CoreBuilder')
        allow(CoreBuilder).to receive(:new).and_return(core_builder)
        allow(core_builder).to receive(:build_all).and_return(0)

        builder.run
      end
    end
  end

  describe 'recipe loading' do
    context 'with valid recipe file' do
      let(:builder) do
        described_class.new(
          cpu_family: 'arm64',
          recipe_file: recipe_file,
          skip_fetch: true,
          skip_build: true
        )
      end

      it 'loads cores from YAML' do
        # Access private method for testing
        recipes = builder.send(:load_recipes_from_yaml)

        expect(recipes).to be_a(Hash)
        expect(recipes).to have_key('gambatte')
        expect(recipes).to have_key('fceumm')
        expect(recipes['gambatte']['repo']).to eq('libretro/gambatte-libretro')
      end
    end

    context 'with missing recipe file' do
      it 'raises error during initialization' do
        expect {
          described_class.new(
            cpu_family: 'arm64',
            recipe_file: '/nonexistent/recipe.yml',
            skip_fetch: true,
            skip_build: true
          )
        }.to raise_error(/Recipe file not found/)
      end
    end

    context 'with recipe missing cores section' do
      let(:bad_recipe) { File.join(fixtures_dir, 'bad.yml') }

      before do
        File.write(bad_recipe, <<~YAML)
          ---
          config:
            arch: aarch64
            target_cross: aarch64-linux-gnu-
            target_cflags: "-O2"
            target_cxxflags: "-O2"
            target_ldflags: ""
        YAML
      end

      it 'raises error when cores section is missing' do
        builder = described_class.new(
          cpu_family: 'arm64',
          recipe_file: bad_recipe,
          skip_fetch: true,
          skip_build: true
        )

        expect {
          builder.send(:load_recipes_from_yaml)
        }.to raise_error(/No 'cores' section/)
      end
    end
  end

  describe 'logging' do
    it 'creates logger with log_file when specified' do
      log_file = File.join(output_dir, 'test.log')

      builder = described_class.new(
        cpu_family: 'arm64',
        recipe_file: recipe_file,
        log_file: log_file,
        skip_fetch: true,
        skip_build: true
      )

      builder.run

      expect(File.exist?(log_file)).to be true
    end
  end
end
