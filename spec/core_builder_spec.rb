# frozen_string_literal: true

require 'spec_helper'
require 'core_builder'
require 'cpu_config'
require 'command_builder'
require 'logger'
require 'tmpdir'

RSpec.describe CoreBuilder do
  let(:cores_dir) { Dir.mktmpdir('cores_spec') }
  let(:output_dir) { Dir.mktmpdir('output_spec') }
  let(:logger) { instance_double('BuildLogger', section: nil, info: nil, success: nil, error: nil, step: nil, detail: nil, warn: nil, summary: nil) }

  let(:cpu_config) do
    instance_double('CpuConfig',
      family: 'arm64',
      arch: 'aarch64',
      target_cross: 'aarch64-linux-gnu-',
      target_cpu: 'cortex-a53',
      target_cflags: '-O2 -pipe -march=armv8-a',
      to_env: {
        'ARCH' => 'aarch64',
        'CC' => 'aarch64-linux-gnu-gcc',
        'CXX' => 'aarch64-linux-gnu-g++',
        'AR' => 'aarch64-linux-gnu-ar',
        'STRIP' => 'aarch64-linux-gnu-strip',
        'CFLAGS' => '-O2 -pipe',
        'CXXFLAGS' => '-O2 -pipe',
        'LDFLAGS' => '-Wl,-O1',
        'TERM' => 'xterm'
      }
    )
  end

  let(:builder) do
    described_class.new(
      cores_dir: cores_dir,
      output_dir: output_dir,
      cpu_config: cpu_config,
      logger: logger,
      parallel: 4
    )
  end

  after do
    FileUtils.rm_rf(cores_dir)
    FileUtils.rm_rf(output_dir)
  end

  describe '#build_one' do
    let(:core_dir) { File.join(cores_dir, 'libretro-gambatte') }

    before do
      FileUtils.mkdir_p(core_dir)
    end

    context 'with Make-based core' do
      let(:metadata) do
        {
          'repo' => 'libretro/gambatte-libretro',
          'build_type' => 'make',
          'makefile' => 'Makefile',
          'build_dir' => '.',
          'platform' => 'unix',
          'so_file' => 'gambatte_libretro.so'
        }
      end

      before do
        # Create Makefile in core directory
        FileUtils.touch(File.join(core_dir, 'Makefile'))
      end

      it 'builds successfully and returns .so path' do
        # Stub prebuild and patch methods
        allow(builder).to receive(:run_prebuild_steps)
        allow(builder).to receive(:apply_patches)

        # Mock Dir.chdir to yield
        allow(Dir).to receive(:chdir).and_yield

        # Mock Dir.exist? for work_dir check
        allow(Dir).to receive(:exist?).and_call_original
        allow(Dir).to receive(:exist?).with(core_dir).and_return(true)

        # Expect make build command (no clean anymore based on code comment)
        expect(builder).to receive(:run_command).with(
          hash_including('ARCH' => 'aarch64'),
          'make',
          '-f',
          'Makefile',
          '-j4',
          anything,  # CC=...
          anything,  # CXX=...
          anything,  # AR=...
          'platform=unix'
        )

        # Mock the .so file being created after build
        so_file = File.join(core_dir, 'gambatte_libretro.so')
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(File.join(core_dir, 'Makefile')).and_return(true)
        allow(File).to receive(:exist?).with(so_file).and_return(true)
        allow(FileUtils).to receive(:cp)

        result = builder.build_one('gambatte', metadata)

        expect(result).to eq(File.join(output_dir, 'gambatte_libretro.so'))
      end

      it 'constructs correct Make arguments' do
        captured_args = nil

        # Stub prebuild and patch methods
        allow(builder).to receive(:run_prebuild_steps)
        allow(builder).to receive(:apply_patches)

        allow(Dir).to receive(:chdir).and_yield
        allow(Dir).to receive(:exist?).and_call_original
        allow(Dir).to receive(:exist?).with(core_dir).and_return(true)

        allow(builder).to receive(:run_command) do |env, *args|
          captured_args = args
        end

        # Mock file existence - need Makefile to exist
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(File.join(core_dir, 'Makefile')).and_return(true)
        allow(File).to receive(:exist?).with(File.join(core_dir, 'gambatte_libretro.so')).and_return(true)
        allow(FileUtils).to receive(:cp)

        builder.build_one('gambatte', metadata)

        expect(captured_args).to include('make')
        expect(captured_args).to include('-j4')
        expect(captured_args).to include('-f')
        expect(captured_args).to include('Makefile')
        expect(captured_args).to include('platform=unix')
        expect(captured_args.join(' ')).to match(/CC=aarch64-linux-gnu-gcc/)
      end

      it 'passes extra_args from metadata' do
        metadata['extra_args'] = ['USE_BLARGG_APU=1', 'DEBUG=0']

        captured_args = nil

        # Stub prebuild and patch methods
        allow(builder).to receive(:run_prebuild_steps)
        allow(builder).to receive(:apply_patches)

        allow(Dir).to receive(:chdir).and_yield
        allow(Dir).to receive(:exist?).and_call_original
        allow(Dir).to receive(:exist?).with(core_dir).and_return(true)

        allow(builder).to receive(:run_command) do |env, *args|
          captured_args = args
        end

        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(File.join(core_dir, 'Makefile')).and_return(true)
        allow(File).to receive(:exist?).with(File.join(core_dir, 'gambatte_libretro.so')).and_return(true)
        allow(FileUtils).to receive(:cp)

        builder.build_one('gambatte', metadata)

        expect(captured_args).to include('USE_BLARGG_APU=1')
        expect(captured_args).to include('DEBUG=0')
      end
    end

    context 'with CMake-based core' do
      let(:cmake_core_dir) { File.join(cores_dir, 'libretro-cmake-test') }
      let(:metadata) do
        {
          'repo' => 'libretro/cmake-test',
          'build_type' => 'cmake',
          'cmake_opts' => ['-DBUILD_SHARED_LIBS=ON'],
          'so_file' => 'cmake_test_libretro.so'
        }
      end

      before do
        FileUtils.mkdir_p(cmake_core_dir)
      end

      it 'constructs CMake configure and build commands' do
        captured_commands = []

        # Stub prebuild and patch methods
        allow(builder).to receive(:run_prebuild_steps)
        allow(builder).to receive(:apply_patches)

        # Mock Dir.chdir to yield
        allow(Dir).to receive(:chdir).and_yield

        # Capture all run_command calls
        allow(builder).to receive(:run_command) do |env, *args|
          captured_commands << { env: env, args: args }
        end

        # Mock the .so file being created
        so_file = File.join(cmake_core_dir, 'cmake_test_libretro.so')
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(so_file).and_return(true)
        allow(FileUtils).to receive(:cp)

        result = builder.build_one('cmake-test', metadata)

        # Should have 2 commands: cmake configure + make build
        expect(captured_commands.length).to eq(2)

        # First command: cmake configure
        cmake_cmd = captured_commands[0]
        expect(cmake_cmd[:args].first).to eq('cmake')
        # Second arg is the source directory (full path when no build_dir specified)
        expect(cmake_cmd[:args][1]).to eq(cmake_core_dir)
        expect(cmake_cmd[:args]).to include('-DBUILD_SHARED_LIBS=ON')

        # Verify cross-compile settings are included
        cmd_str = cmake_cmd[:args].join(' ')
        expect(cmd_str).to include('-DCMAKE_C_COMPILER=')
        expect(cmd_str).to include('-DCMAKE_SYSTEM_PROCESSOR=')

        # Second command: make build
        make_cmd = captured_commands[1]
        expect(make_cmd[:args]).to eq(['make', '-j4'])

        # Verify result
        expect(result).to eq(File.join(output_dir, 'cmake_test_libretro.so'))
      end
    end

    context 'with missing .so file after build' do
      let(:metadata) do
        {
          'repo' => 'libretro/test-core',
          'build_type' => 'make',
          'makefile' => 'Makefile',
          'build_dir' => '.',
          'platform' => 'unix',
          'so_file' => 'missing_libretro.so'
        }
      end

      it 'returns nil when .so file not found' do
        allow(builder).to receive(:run_command)
        allow(File).to receive(:exist?).and_return(false)

        result = builder.build_one('test-core', metadata)

        expect(result).to be_nil
      end
    end

    context 'with build failure' do
      let(:metadata) do
        {
          'repo' => 'libretro/test-core',
          'build_type' => 'make',
          'makefile' => 'Makefile',
          'build_dir' => '.',
          'platform' => 'unix',
          'so_file' => 'test_libretro.so'
        }
      end

      it 'catches errors and returns nil' do
        allow(builder).to receive(:run_command).and_raise(StandardError, 'Build failed')

        result = builder.build_one('test-core', metadata)

        expect(result).to be_nil
      end
    end
  end

  describe '#build_all' do
    let(:recipes) do
      {
        'gambatte' => {
          'repo' => 'libretro/gambatte-libretro',
          'build_type' => 'make',
          'makefile' => 'Makefile',
          'build_dir' => '.',
          'platform' => 'unix',
          'so_file' => 'gambatte_libretro.so'
        },
        'fceumm' => {
          'repo' => 'libretro/libretro-fceumm',
          'build_type' => 'make',
          'makefile' => 'Makefile.libretro',
          'build_dir' => '.',
          'platform' => 'unix',
          'so_file' => 'fceumm_libretro.so'
        }
      }
    end

    before do
      FileUtils.mkdir_p(File.join(cores_dir, 'libretro-gambatte'))
      FileUtils.mkdir_p(File.join(cores_dir, 'libretro-fceumm'))
      # Create Makefiles
      FileUtils.touch(File.join(cores_dir, 'libretro-gambatte', 'Makefile'))
      FileUtils.touch(File.join(cores_dir, 'libretro-fceumm', 'Makefile.libretro'))
    end

    it 'builds all cores and returns success exit code' do
      # Stub prebuild and patch methods
      allow(builder).to receive(:run_prebuild_steps)
      allow(builder).to receive(:apply_patches)

      allow(Dir).to receive(:chdir).and_yield
      allow(Dir).to receive(:exist?).and_call_original
      allow(Dir).to receive(:exist?).with(File.join(cores_dir, 'libretro-gambatte')).and_return(true)
      allow(Dir).to receive(:exist?).with(File.join(cores_dir, 'libretro-fceumm')).and_return(true)
      allow(builder).to receive(:run_command)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(cores_dir, 'libretro-gambatte', 'Makefile')).and_return(true)
      allow(File).to receive(:exist?).with(File.join(cores_dir, 'libretro-fceumm', 'Makefile.libretro')).and_return(true)
      allow(File).to receive(:exist?).with(File.join(cores_dir, 'libretro-gambatte', 'gambatte_libretro.so')).and_return(true)
      allow(File).to receive(:exist?).with(File.join(cores_dir, 'libretro-fceumm', 'fceumm_libretro.so')).and_return(true)
      allow(FileUtils).to receive(:cp)

      exit_code = builder.build_all(recipes)

      expect(exit_code).to eq(0)  # Success
    end

    it 'tracks build statistics' do
      # Stub prebuild and patch methods
      allow(builder).to receive(:run_prebuild_steps)
      allow(builder).to receive(:apply_patches)

      allow(Dir).to receive(:chdir).and_yield
      allow(Dir).to receive(:exist?).and_call_original
      allow(Dir).to receive(:exist?).with(File.join(cores_dir, 'libretro-gambatte')).and_return(true)
      allow(Dir).to receive(:exist?).with(File.join(cores_dir, 'libretro-fceumm')).and_return(true)
      allow(builder).to receive(:run_command)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(cores_dir, 'libretro-gambatte', 'Makefile')).and_return(true)
      allow(File).to receive(:exist?).with(File.join(cores_dir, 'libretro-fceumm', 'Makefile.libretro')).and_return(true)
      allow(File).to receive(:exist?).with(File.join(cores_dir, 'libretro-gambatte', 'gambatte_libretro.so')).and_return(true)
      allow(File).to receive(:exist?).with(File.join(cores_dir, 'libretro-fceumm', 'fceumm_libretro.so')).and_return(true)
      allow(FileUtils).to receive(:cp)

      builder.build_all(recipes)

      expect(builder.built).to eq(2)
      expect(builder.failed).to eq(0)
    end

    it 'logs summary with statistics' do
      # Create Makefiles for both cores
      FileUtils.touch(File.join(cores_dir, 'libretro-gambatte', 'Makefile'))
      FileUtils.touch(File.join(cores_dir, 'libretro-fceumm', 'Makefile.libretro'))

      # Stub prebuild and patch methods
      allow(builder).to receive(:run_prebuild_steps)
      allow(builder).to receive(:apply_patches)

      allow(Dir).to receive(:chdir).and_yield
      allow(Dir).to receive(:exist?).and_call_original
      allow(Dir).to receive(:exist?).with(File.join(cores_dir, 'libretro-gambatte')).and_return(true)
      allow(Dir).to receive(:exist?).with(File.join(cores_dir, 'libretro-fceumm')).and_return(true)
      allow(builder).to receive(:run_command)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(cores_dir, 'libretro-gambatte', 'Makefile')).and_return(true)
      allow(File).to receive(:exist?).with(File.join(cores_dir, 'libretro-fceumm', 'Makefile.libretro')).and_return(true)
      allow(File).to receive(:exist?).with(File.join(cores_dir, 'libretro-gambatte', 'gambatte_libretro.so')).and_return(true)
      allow(File).to receive(:exist?).with(File.join(cores_dir, 'libretro-fceumm', 'fceumm_libretro.so')).and_return(true)
      allow(FileUtils).to receive(:cp)

      expect(logger).to receive(:summary).with(built: 2, failed: 0, skipped: 0)

      builder.build_all(recipes)
    end

    context 'with dry_run enabled' do
      let(:dry_run_builder) do
        described_class.new(
          cores_dir: cores_dir,
          output_dir: output_dir,
          cpu_config: cpu_config,
          logger: logger,
          parallel: 4,
          dry_run: true
        )
      end

      it 'logs dry run mode' do
        expect(logger).to receive(:info).with('Dry run: true')

        dry_run_builder.build_all(recipes)
      end
    end
  end

  describe 'build type selection' do
    let(:core_dir) { File.join(cores_dir, 'libretro-test') }

    before do
      FileUtils.mkdir_p(core_dir)
    end

    context 'when build_type is make' do
      let(:metadata) do
        {
          'repo' => 'libretro/test-core',
          'build_type' => 'make',
          'makefile' => 'Makefile',
          'build_dir' => '.',
          'platform' => 'unix',
          'so_file' => 'test_libretro.so'
        }
      end

      it 'uses Make build method' do
        expect(builder).to receive(:build_make).with('test', metadata, core_dir)

        allow(builder).to receive(:copy_so_file).and_return(File.join(output_dir, 'test_libretro.so'))

        builder.build_one('test', metadata)
      end
    end

    context 'when build_type is cmake' do
      let(:metadata) do
        {
          'repo' => 'libretro/test-core',
          'build_type' => 'cmake',
          'cmake_opts' => [],
          'so_file' => 'test_libretro.so'
        }
      end

      it 'uses CMake build method' do
        expect(builder).to receive(:build_cmake).with('test', metadata, core_dir)

        allow(builder).to receive(:copy_so_file).and_return(File.join(output_dir, 'test_libretro.so'))

        builder.build_one('test', metadata)
      end
    end
  end

  describe 'environment variable handling' do
    let(:core_dir) { File.join(cores_dir, 'libretro-test') }
    let(:metadata) do
      {
        'repo' => 'libretro/test-core',
        'build_type' => 'make',
        'makefile' => 'Makefile',
        'build_dir' => '.',
        'platform' => 'unix',
        'so_file' => 'test_libretro.so'
      }
    end

    before do
      FileUtils.mkdir_p(core_dir)
    end

    it 'passes CPU config environment to build commands' do
      captured_env = nil

      allow(builder).to receive(:run_command) do |env, *args|
        captured_env = env if args.first == 'make' && args.include?('-j4')
      end

      allow(File).to receive(:exist?).and_return(true)
      allow(FileUtils).to receive(:cp)

      builder.build_one('test', metadata)

      expect(captured_env).to include('ARCH' => 'aarch64')
      expect(captured_env).to include('CC' => 'aarch64-linux-gnu-gcc')
      expect(captured_env).to include('CXX' => 'aarch64-linux-gnu-g++')
      expect(captured_env).to include('CFLAGS' => '-O2 -pipe')
    end
  end

  describe '#copy_so_file' do
    let(:core_dir) { File.join(cores_dir, 'libretro-test') }
    let(:so_file) { File.join(core_dir, 'test_libretro.so') }
    let(:metadata) { { 'so_file' => 'test_libretro.so' } }

    before do
      FileUtils.mkdir_p(core_dir)
    end

    it 'copies .so file to output directory' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(so_file).and_return(true)
      expect(FileUtils).to receive(:cp).with(so_file, File.join(output_dir, 'test_libretro.so'))

      result = builder.send(:copy_so_file, so_file, 'test', metadata)

      expect(result).to eq(File.join(output_dir, 'test_libretro.so'))
    end

    it 'raises error when .so file does not exist' do
      # copy_so_file doesn't check existence - it will fail on FileUtils.cp
      # The caller (build_make/build_cmake) is responsible for checking existence first
      expect {
        builder.send(:copy_so_file, '/nonexistent/file.so', 'test', metadata)
      }.to raise_error(Errno::ENOENT)
    end
  end

  describe 'dry run mode' do
    let(:dry_run_builder) do
      described_class.new(
        cores_dir: cores_dir,
        output_dir: output_dir,
        cpu_config: cpu_config,
        logger: logger,
        parallel: 4,
        dry_run: true
      )
    end

    let(:core_dir) { File.join(cores_dir, 'libretro-test') }
    let(:metadata) do
      {
        'repo' => 'libretro/test-core',
        'build_type' => 'make',
        'makefile' => 'Makefile',
        'build_dir' => '.',
        'platform' => 'unix',
        'so_file' => 'test_libretro.so'
      }
    end

    before do
      FileUtils.mkdir_p(core_dir)
    end

    it 'does not execute build commands in dry run mode' do
      expect(dry_run_builder).not_to receive(:run_command)

      dry_run_builder.build_one('test', metadata)
    end

    it 'logs what would be done' do
      expect(logger).to receive(:detail).with(/\[DRY RUN\] Would build test/)

      dry_run_builder.build_one('test', metadata)
    end
  end

  describe 'parallel builds' do
    it 'uses correct parallel flag' do
      parallel_builder = described_class.new(
        cores_dir: cores_dir,
        output_dir: output_dir,
        cpu_config: cpu_config,
        logger: logger,
        parallel: 8
      )

      core_dir = File.join(cores_dir, 'libretro-test')
      FileUtils.mkdir_p(core_dir)

      metadata = {
        'repo' => 'libretro/test-core',
        'build_type' => 'make',
        'makefile' => 'Makefile',
        'build_dir' => '.',
        'platform' => 'unix',
        'so_file' => 'test_libretro.so'
      }

      captured_args = nil
      allow(parallel_builder).to receive(:run_command) do |env, *args|
        captured_args = args if args.first == 'make' && args.include?('-j8')
      end

      allow(File).to receive(:exist?).and_return(true)
      allow(FileUtils).to receive(:cp)

      parallel_builder.build_one('test', metadata)

      expect(captured_args).to include('-j8')
    end
  end

  describe 'prebuild scripts' do
    let(:core_dir) { File.join(cores_dir, 'libretro-test') }

    before do
      FileUtils.mkdir_p(core_dir)
    end

    context 'when prebuild_script is specified' do
      let(:metadata) do
        {
          'repo' => 'libretro/test-core',
          'build_type' => 'make',
          'makefile' => 'Makefile',
          'build_dir' => '.',
          'platform' => 'unix',
          'so_file' => 'test_libretro.so',
          'prebuild_script' => 'prebuild-test.sh'
        }
      end

      it 'raises error when prebuild script does not exist' do
        result = builder.build_one('test', metadata)

        expect(result).to be_nil
        expect(builder.failed).to eq(1)
      end

      it 'raises error when prebuild script fails' do
        # Create a real scripts directory relative to lib/
        scripts_dir = File.join(File.dirname(File.dirname(__FILE__)), 'scripts')
        FileUtils.mkdir_p(scripts_dir)
        script_path = File.join(scripts_dir, 'prebuild-test.sh')
        File.write(script_path, "#!/bin/bash\nexit 1")
        File.chmod(0o755, script_path)

        begin
          allow(Open3).to receive(:capture2e).and_return(['error output', double(success?: false)])

          result = builder.build_one('test', metadata)

          expect(result).to be_nil
          expect(builder.failed).to eq(1)
        ensure
          FileUtils.rm_f(script_path)
        end
      end
    end
  end

  describe 'patches' do
    let(:core_dir) { File.join(cores_dir, 'libretro-test') }

    before do
      FileUtils.mkdir_p(core_dir)
      FileUtils.touch(File.join(core_dir, 'Makefile'))
    end

    let(:metadata) do
      {
        'repo' => 'libretro/test-core',
        'build_type' => 'make',
        'makefile' => 'Makefile',
        'build_dir' => '.',
        'platform' => 'unix',
        'so_file' => 'test_libretro.so'
      }
    end

    context 'when no patches directory exists' do
      it 'skips patching and continues build' do
        # Create the .so file that would be produced by build
        so_file = File.join(core_dir, 'test_libretro.so')
        FileUtils.touch(so_file)

        allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

        result = builder.build_one('test', metadata)

        expect(result).to eq(File.join(output_dir, 'test_libretro.so'))
        expect(File.exist?(File.join(output_dir, 'test_libretro.so'))).to be true
      end
    end
  end

  describe '#apply_patches' do
    let(:core_dir) { File.join(cores_dir, 'libretro-patchtest') }
    let(:patches_dir) { File.join(File.dirname(File.dirname(__FILE__)), 'patches', 'patchtest') }
    let(:patch_file) { File.join(patches_dir, '01-test.patch') }

    before do
      FileUtils.mkdir_p(core_dir)
      FileUtils.mkdir_p(patches_dir)
      File.write(patch_file, "--- a/file.c\n+++ b/file.c\n@@ -1 +1 @@\n-old\n+new\n")
    end

    after do
      FileUtils.rm_rf(patches_dir)
    end

    context 'in a git repo when git apply succeeds' do
      it 'applies patch using git apply' do
        Dir.chdir(core_dir) do
          # Simulate being in a git repo
          allow_any_instance_of(Object).to receive(:system).and_call_original
          allow_any_instance_of(Object).to receive(:system).with('git rev-parse --git-dir > /dev/null 2>&1').and_return(true)
          # git apply --check succeeds
          allow_any_instance_of(Object).to receive(:system).with(/git apply --check/).and_return(true)

          expect(builder).to receive(:run_command).with({}, 'git', 'apply', patch_file)

          builder.send(:apply_patches, 'patchtest', core_dir)
        end
      end
    end

    context 'in a git repo when patch is already applied' do
      it 'skips the patch' do
        Dir.chdir(core_dir) do
          allow_any_instance_of(Object).to receive(:system).and_call_original
          allow_any_instance_of(Object).to receive(:system).with('git rev-parse --git-dir > /dev/null 2>&1').and_return(true)
          # git apply --check fails
          allow_any_instance_of(Object).to receive(:system).with(/git apply --check/).and_return(false)
          # git apply --reverse --check succeeds (patch already applied)
          allow_any_instance_of(Object).to receive(:system).with(/git apply --reverse --check/).and_return(true)

          expect(builder).not_to receive(:run_command)

          builder.send(:apply_patches, 'patchtest', core_dir)
        end
      end
    end

    context 'in a git repo when git apply fails but patch command works (submodule files)' do
      it 'falls back to patch command' do
        Dir.chdir(core_dir) do
          allow_any_instance_of(Object).to receive(:system).and_call_original
          allow_any_instance_of(Object).to receive(:system).with('git rev-parse --git-dir > /dev/null 2>&1').and_return(true)
          # git apply --check fails
          allow_any_instance_of(Object).to receive(:system).with(/git apply --check/).and_return(false)
          # git apply --reverse --check fails (not already applied)
          allow_any_instance_of(Object).to receive(:system).with(/git apply --reverse --check/).and_return(false)
          # patch --dry-run succeeds
          allow_any_instance_of(Object).to receive(:system).with(/patch -p1 --dry-run/).and_return(true)

          expect(builder).to receive(:run_command).with({}, 'patch', '-p1', '-i', patch_file)

          builder.send(:apply_patches, 'patchtest', core_dir)
        end
      end
    end

    context 'in a git repo when both git apply and patch command fail' do
      it 'raises an error' do
        Dir.chdir(core_dir) do
          allow_any_instance_of(Object).to receive(:system).and_call_original
          allow_any_instance_of(Object).to receive(:system).with('git rev-parse --git-dir > /dev/null 2>&1').and_return(true)
          # git apply --check fails
          allow_any_instance_of(Object).to receive(:system).with(/git apply --check/).and_return(false)
          # git apply --reverse --check fails
          allow_any_instance_of(Object).to receive(:system).with(/git apply --reverse --check/).and_return(false)
          # patch --dry-run fails
          allow_any_instance_of(Object).to receive(:system).with(/patch -p1 --dry-run/).and_return(false)

          expect {
            builder.send(:apply_patches, 'patchtest', core_dir)
          }.to raise_error(/doesn't apply cleanly/)
        end
      end
    end

    context 'when not in a git repo' do
      it 'uses patch command directly' do
        Dir.chdir(core_dir) do
          allow_any_instance_of(Object).to receive(:system).and_call_original
          allow_any_instance_of(Object).to receive(:system).with('git rev-parse --git-dir > /dev/null 2>&1').and_return(false)

          expect(builder).to receive(:run_command).with({}, 'patch', '-p1', '-i', patch_file)

          builder.send(:apply_patches, 'patchtest', core_dir)
        end
      end
    end
  end

  describe 'VERBOSE mode' do
    let(:core_dir) { File.join(cores_dir, 'libretro-test') }

    before do
      FileUtils.mkdir_p(core_dir)
      FileUtils.touch(File.join(core_dir, 'Makefile'))
    end

    let(:metadata) do
      {
        'repo' => 'libretro/test-core',
        'build_type' => 'make',
        'makefile' => 'Makefile',
        'build_dir' => '.',
        'platform' => 'unix',
        'so_file' => 'test_libretro.so'
      }
    end

    around do |example|
      original = ENV['VERBOSE']
      ENV['VERBOSE'] = '1'
      example.run
      ENV['VERBOSE'] = original
    end

    it 'does not crash in verbose mode' do
      # Create the .so file that would be produced by build
      so_file = File.join(core_dir, 'test_libretro.so')
      FileUtils.touch(so_file)

      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

      result = builder.build_one('test', metadata)

      expect(result).to eq(File.join(output_dir, 'test_libretro.so'))
    end
  end

  describe 'cmake_env overrides' do
    let(:cmake_core_dir) { File.join(cores_dir, 'libretro-cmake-test') }

    before do
      FileUtils.mkdir_p(cmake_core_dir)
    end

    let(:metadata) do
      {
        'repo' => 'libretro/cmake-test',
        'build_type' => 'cmake',
        'cmake_opts' => [],
        'so_file' => 'cmake_test_libretro.so',
        'cmake_env' => {
          'CC' => 'gcc',
          'CXX' => 'g++',
          'CFLAGS' => ''
        }
      }
    end

    it 'applies cmake_env overrides to build environment' do
      captured_env = nil

      allow(builder).to receive(:run_command) do |env, *args|
        captured_env = env if args.first == 'cmake'
      end

      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(cmake_core_dir, 'cmake_test_libretro.so')).and_return(true)
      allow(FileUtils).to receive(:cp)

      builder.build_one('cmake-test', metadata)

      expect(captured_env['CC']).to eq('gcc')
      expect(captured_env['CXX']).to eq('g++')
      expect(captured_env['CFLAGS']).to eq('')
    end
  end

  describe 'extra_cflags/extra_cxxflags' do
    let(:make_core_dir) { File.join(cores_dir, 'libretro-extra-flags-test') }

    before do
      FileUtils.mkdir_p(make_core_dir)
      File.write(File.join(make_core_dir, 'Makefile'), 'all:')
    end

    let(:metadata) do
      {
        'repo' => 'libretro/extra-flags-test',
        'build_type' => 'make',
        'makefile' => 'Makefile',
        'build_dir' => '.',
        'platform' => 'unix',
        'so_file' => 'extra_flags_test_libretro.so',
        'extra_cflags' => '-DHAVE_UNISTD_H -Wno-error',
        'extra_cxxflags' => '-mno-outline-atomics',
        'extra_ldflags' => '-lextra'
      }
    end

    it 'appends extra flags to environment' do
      captured_env = nil

      allow(builder).to receive(:run_command) do |env, *args|
        captured_env = env if args.first == 'make'
      end

      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(make_core_dir, 'extra_flags_test_libretro.so')).and_return(true)
      allow(FileUtils).to receive(:cp)

      builder.build_one('extra-flags-test', metadata)

      expect(captured_env['CFLAGS']).to include('-DHAVE_UNISTD_H')
      expect(captured_env['CFLAGS']).to include('-Wno-error')
      expect(captured_env['CXXFLAGS']).to include('-mno-outline-atomics')
      expect(captured_env['LDFLAGS']).to include('-lextra')
    end

    context 'with cmake build' do
      let(:cmake_core_dir) { File.join(cores_dir, 'libretro-cmake-extra-flags-test') }

      before do
        FileUtils.mkdir_p(cmake_core_dir)
        File.write(File.join(cmake_core_dir, 'CMakeLists.txt'), 'project(test)')
      end

      let(:cmake_metadata) do
        {
          'repo' => 'libretro/cmake-extra-flags-test',
          'build_type' => 'cmake',
          'cmake_opts' => ['-DCMAKE_BUILD_TYPE=Release'],
          'so_file' => 'cmake_extra_flags_test_libretro.so',
          'extra_cflags' => '-Wno-error',
          'extra_cxxflags' => '-mno-outline-atomics'
        }
      end

      it 'appends extra flags to environment for cmake builds' do
        captured_env = nil

        allow(builder).to receive(:run_command) do |env, *args|
          captured_env = env if args.first == 'cmake'
        end

        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(File.join(cmake_core_dir, 'build', 'cmake_extra_flags_test_libretro.so')).and_return(true)
        allow(FileUtils).to receive(:cp)

        builder.build_one('cmake-extra-flags-test', cmake_metadata)

        expect(captured_env['CFLAGS']).to include('-Wno-error')
        expect(captured_env['CXXFLAGS']).to include('-mno-outline-atomics')
      end
    end
  end

  describe 'unknown build type' do
    let(:core_dir) { File.join(cores_dir, 'libretro-test') }

    before do
      FileUtils.mkdir_p(core_dir)
    end

    it 'raises error for unknown build type' do
      metadata = {
        'repo' => 'libretro/test-core',
        'build_type' => 'unknown',
        'so_file' => 'test_libretro.so'
      }

      result = builder.build_one('test', metadata)

      expect(result).to be_nil
      expect(builder.failed).to eq(1)
    end
  end

  describe 'missing build directory' do
    it 'raises error when core directory does not exist' do
      metadata = {
        'repo' => 'libretro/nonexistent',
        'build_type' => 'make',
        'makefile' => 'Makefile',
        'build_dir' => '.',
        'platform' => 'unix',
        'so_file' => 'test_libretro.so'
      }

      result = builder.build_one('nonexistent', metadata)

      expect(result).to be_nil
      expect(builder.failed).to eq(1)
    end

    it 'raises error when build_dir subdirectory does not exist' do
      core_dir = File.join(cores_dir, 'libretro-test')
      FileUtils.mkdir_p(core_dir)
      # Don't create the 'platform/libretro' subdirectory

      metadata = {
        'repo' => 'libretro/test-core',
        'build_type' => 'make',
        'makefile' => 'Makefile',
        'build_dir' => 'platform/libretro',
        'platform' => 'unix',
        'so_file' => 'test_libretro.so'
      }

      result = builder.build_one('test', metadata)

      expect(result).to be_nil
      expect(builder.failed).to eq(1)
    end
  end

  describe 'missing makefile' do
    it 'raises error when makefile does not exist' do
      core_dir = File.join(cores_dir, 'libretro-test')
      FileUtils.mkdir_p(core_dir)
      # Don't create the Makefile

      metadata = {
        'repo' => 'libretro/test-core',
        'build_type' => 'make',
        'makefile' => 'Makefile.libretro',
        'build_dir' => '.',
        'platform' => 'unix',
        'so_file' => 'test_libretro.so'
      }

      result = builder.build_one('test', metadata)

      expect(result).to be_nil
      expect(builder.failed).to eq(1)
    end
  end

  describe 'missing .so file after build' do
    let(:core_dir) { File.join(cores_dir, 'libretro-test') }

    before do
      FileUtils.mkdir_p(core_dir)
      FileUtils.touch(File.join(core_dir, 'Makefile'))
    end

    context 'with make build' do
      it 'raises error when .so file not produced' do
        metadata = {
          'repo' => 'libretro/test-core',
          'build_type' => 'make',
          'makefile' => 'Makefile',
          'build_dir' => '.',
          'platform' => 'unix',
          'so_file' => 'test_libretro.so'
        }

        # Mock successful make but don't create .so file
        allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

        result = builder.build_one('test', metadata)

        expect(result).to be_nil
        expect(builder.failed).to eq(1)
      end
    end

    context 'with cmake build' do
      it 'raises error when .so file not produced' do
        metadata = {
          'repo' => 'libretro/test-core',
          'build_type' => 'cmake',
          'cmake_opts' => [],
          'so_file' => 'build/test_libretro.so'
        }

        # Mock successful cmake and make but don't create .so file
        allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

        result = builder.build_one('test', metadata)

        expect(result).to be_nil
        expect(builder.failed).to eq(1)
      end
    end
  end

  describe 'output_name override' do
    let(:core_dir) { File.join(cores_dir, 'libretro-test') }

    before do
      FileUtils.mkdir_p(core_dir)
      FileUtils.touch(File.join(core_dir, 'Makefile'))
    end

    let(:metadata) do
      {
        'repo' => 'libretro/test-core',
        'build_type' => 'make',
        'makefile' => 'Makefile',
        'build_dir' => '.',
        'platform' => 'unix',
        'so_file' => 'original_libretro.so',
        'output_name' => 'renamed_libretro.so'
      }
    end

    it 'uses output_name for destination file' do
      # Create the .so file that would be produced by build
      so_file = File.join(core_dir, 'original_libretro.so')
      FileUtils.touch(so_file)

      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

      result = builder.build_one('test', metadata)

      expect(result).to eq(File.join(output_dir, 'renamed_libretro.so'))
      expect(File.exist?(File.join(output_dir, 'renamed_libretro.so'))).to be true
    end
  end
end
