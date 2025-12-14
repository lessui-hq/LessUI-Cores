# frozen_string_literal: true

require 'spec_helper'
require 'command_builder'
require 'cpu_config'
require 'tmpdir'

RSpec.describe CommandBuilder do
  # Create a minimal CPU config mock
  let(:cpu_config_data) do
    {
      family: cpu_family,
      arch: arch,
      target_cross: target_cross,
      target_cflags: '-O2 -pipe -march=armv8-a+crc',
      target_cxxflags: '-O2 -pipe -march=armv8-a+crc',
      target_ldflags: '-Wl,-O1',
      platform: 'unix'
    }
  end

  let(:cpu_config) do
    instance_double('CpuConfig',
                    family: cpu_config_data[:family],
                    arch: cpu_config_data[:arch],
                    target_cross: cpu_config_data[:target_cross],
                    platform: cpu_config_data[:platform],
                    to_env: {
                      'ARCH' => cpu_config_data[:arch],
                      'CC' => "#{cpu_config_data[:target_cross]}gcc",
                      'CXX' => "#{cpu_config_data[:target_cross]}g++",
                      'CFLAGS' => cpu_config_data[:target_cflags],
                      'CXXFLAGS' => cpu_config_data[:target_cxxflags],
                      'LDFLAGS' => cpu_config_data[:target_ldflags]
                    })
  end

  let(:parallel) { 4 }
  let(:builder) { described_class.new(cpu_config: cpu_config, parallel: parallel) }

  describe '#make_args' do
    context 'with arm64 architecture' do
      let(:cpu_family) { 'arm64' }
      let(:arch) { 'aarch64' }
      let(:target_cross) { 'aarch64-linux-gnu-' }

      let(:metadata) do
        {
          'name' => 'gambatte',
          'platform' => 'unix',
          'extra_args' => []
        }
      end

      it 'includes toolchain variables' do
        args = builder.make_args(metadata)
        expect(args).to include('CC=aarch64-linux-gnu-gcc')
        expect(args).to include('CXX=aarch64-linux-gnu-g++')
      end

      it 'includes platform from metadata' do
        args = builder.make_args(metadata)
        expect(args).to include('platform=unix')
      end

      it 'includes extra args from metadata' do
        metadata['extra_args'] = ['EXTRA_FLAG=1', 'DEBUG=yes']
        args = builder.make_args(metadata)

        expect(args).to include('EXTRA_FLAG=1')
        expect(args).to include('DEBUG=yes')
      end
    end

    context 'with arm32 architecture' do
      let(:cpu_family) { 'arm32' }
      let(:arch) { 'arm' }
      let(:target_cross) { 'arm-linux-gnueabihf-' }

      let(:metadata) do
        {
          'name' => 'fceumm',
          'platform' => 'classic_armv7_a7'
        }
      end

      it 'uses correct platform from metadata' do
        args = builder.make_args(metadata)
        expect(args).to include('platform=classic_armv7_a7')
      end
    end
  end

  describe '#cmake_args' do
    let(:cpu_family) { 'arm64' }
    let(:arch) { 'aarch64' }
    let(:target_cross) { 'aarch64-linux-gnu-' }

    context 'with basic cmake metadata' do
      let(:metadata) do
        {
          'cmake_opts' => ['-DBUILD_SHARED_LIBS=ON']
        }
      end

      it 'includes recipe cmake options' do
        args = builder.cmake_args(metadata)
        expect(args).to include('-DBUILD_SHARED_LIBS=ON')
      end

      it 'includes compiler flags' do
        args = builder.cmake_args(metadata)
        expect(args.join(' ')).to include('-DCMAKE_C_FLAGS=')
        expect(args.join(' ')).to include('-DCMAKE_CXX_FLAGS=')
      end

      it 'includes pthread flag' do
        args = builder.cmake_args(metadata)
        expect(args).to include('-DTHREADS_PREFER_PTHREAD_FLAG=ON')
      end

      it 'includes Release build type by default' do
        args = builder.cmake_args(metadata)
        expect(args).to include('-DCMAKE_BUILD_TYPE=Release')
      end

      it 'does not override existing CMAKE_BUILD_TYPE' do
        metadata['cmake_opts'] = ['-DCMAKE_BUILD_TYPE=Debug']
        args = builder.cmake_args(metadata)

        # Should only have one BUILD_TYPE (the Debug one from metadata)
        build_types = args.select { |arg| arg.include?('CMAKE_BUILD_TYPE') }
        expect(build_types.length).to eq(1)
        expect(build_types.first).to include('Debug')
      end
    end

    context 'with ARM32 architecture' do
      let(:cpu_family) { 'arm32' }
      let(:arch) { 'arm' }
      let(:target_cross) { 'arm-linux-gnueabihf-' }

      let(:metadata) do
        {
          'cmake_opts' => []
        }
      end

      it 'forces C99 standard for ARM32' do
        args = builder.cmake_args(metadata)
        expect(args).to include('-DCMAKE_C_STANDARD=99')
      end

      it 'forces C++11 standard for ARM32' do
        args = builder.cmake_args(metadata)
        expect(args).to include('-DCMAKE_CXX_STANDARD=11')
      end
    end

    context 'with CMAKE_C_FLAGS in recipe cmake_opts' do
      let(:cpu_family) { 'arm64' }
      let(:arch) { 'aarch64' }
      let(:target_cross) { 'aarch64-linux-gnu-' }

      # Note: cmake_opts are split by whitespace, so each -D flag becomes separate
      # e.g., "-DCMAKE_C_FLAGS=-DFOO=1 -DBAR=2" becomes ["-DCMAKE_C_FLAGS=-DFOO=1", "-DBAR=2"]

      it 'extracts -D define from recipe CMAKE_C_FLAGS and merges with config flags' do
        metadata = {
          # After split: ["-DCMAKE_C_FLAGS=-DFOO=1"]
          'cmake_opts' => ['-DCMAKE_C_FLAGS=-DFOO=1']
        }
        args = builder.cmake_args(metadata)

        c_flags_arg = args.find { |arg| arg.start_with?('-DCMAKE_C_FLAGS=') }
        expect(c_flags_arg).not_to be_nil

        # Should contain config CFLAGS
        expect(c_flags_arg).to include('-O2')
        expect(c_flags_arg).to include('-pipe')

        # Should contain recipe define
        expect(c_flags_arg).to include('-DFOO=1')
      end

      it 'filters out optimization flags from recipe CMAKE_C_FLAGS value' do
        metadata = {
          # Recipe only has optimization flag, no defines to keep
          'cmake_opts' => ['-DCMAKE_C_FLAGS=-O3']
        }
        args = builder.cmake_args(metadata)

        c_flags_arg = args.find { |arg| arg.start_with?('-DCMAKE_C_FLAGS=') }

        # Should contain config CFLAGS (which has -O2)
        expect(c_flags_arg).to include('-O2')
        # The -O3 from recipe should NOT appear as a define (it's an optimization flag)
      end

      it 'removes original CMAKE_C_FLAGS from cmake_opts' do
        metadata = {
          'cmake_opts' => ['-DCMAKE_C_FLAGS=-DFOO=1', '-DBUILD_SHARED_LIBS=ON']
        }
        args = builder.cmake_args(metadata)

        # Should only have one CMAKE_C_FLAGS entry (the merged one)
        c_flags_entries = args.select { |arg| arg.start_with?('-DCMAKE_C_FLAGS=') }
        expect(c_flags_entries.length).to eq(1)

        # Other options should be preserved
        expect(args).to include('-DBUILD_SHARED_LIBS=ON')
      end

      it 'handles CMAKE_CXX_FLAGS the same way' do
        metadata = {
          'cmake_opts' => ['-DCMAKE_CXX_FLAGS=-DCPP_DEFINE=yes']
        }
        args = builder.cmake_args(metadata)

        cxx_flags_arg = args.find { |arg| arg.start_with?('-DCMAKE_CXX_FLAGS=') }
        expect(cxx_flags_arg).to include('-DCPP_DEFINE=yes')
      end

      it 'does not filter out legitimate defines starting with CMAKE' do
        # Edge case: a preprocessor define like -DCMAKE_CUSTOM_THING=1 should be kept
        # (it's a preprocessor define, not a CMake variable)
        metadata = {
          'cmake_opts' => ['-DCMAKE_C_FLAGS=-DCMAKE_CUSTOM_THING=1']
        }
        args = builder.cmake_args(metadata)

        c_flags_arg = args.find { |arg| arg.start_with?('-DCMAKE_C_FLAGS=') }
        # CMAKE_CUSTOM_THING is not in our builtin list, so it should be kept
        expect(c_flags_arg).to include('-DCMAKE_CUSTOM_THING=1')
      end

      it 'filters out known CMake builtin variables used as defines' do
        metadata = {
          'cmake_opts' => ['-DCMAKE_C_FLAGS=-DCMAKE_BUILD_TYPE=Release']
        }
        args = builder.cmake_args(metadata)

        c_flags_arg = args.find { |arg| arg.start_with?('-DCMAKE_C_FLAGS=') }
        # CMAKE_BUILD_TYPE is a builtin and should be filtered
        expect(c_flags_arg).not_to include('-DCMAKE_BUILD_TYPE=Release')
      end
    end
  end

  describe '#cmake_configure_command' do
    let(:cpu_family) { 'arm64' }
    let(:arch) { 'aarch64' }
    let(:target_cross) { 'aarch64-linux-gnu-' }
    let(:build_dir) { Dir.mktmpdir }

    let(:metadata) do
      {
        'cmake_opts' => ['-DFOO=bar']
      }
    end

    after do
      FileUtils.rm_rf(build_dir)
    end

    it 'includes cmake command' do
      cmd = builder.cmake_configure_command(metadata, build_dir: build_dir)
      expect(cmd.first).to eq('cmake')
    end

    it 'targets parent directory' do
      cmd = builder.cmake_configure_command(metadata, build_dir: build_dir)
      expect(cmd).to include('..')
    end

    it 'includes cross-compile settings' do
      cmd = builder.cmake_configure_command(metadata, build_dir: build_dir)
      cmd_str = cmd.join(' ')
      expect(cmd_str).to include('-DCMAKE_C_COMPILER=')
      expect(cmd_str).to include('-DCMAKE_CXX_COMPILER=')
      expect(cmd_str).to include('-DCMAKE_SYSTEM_PROCESSOR=')
    end

    it 'includes cmake args from metadata' do
      cmd = builder.cmake_configure_command(metadata, build_dir: build_dir)
      expect(cmd).to include('-DFOO=bar')
    end
  end

  describe '#cmake_build_command' do
    let(:cpu_family) { 'arm64' }
    let(:arch) { 'aarch64' }
    let(:target_cross) { 'aarch64-linux-gnu-' }

    it 'uses make with parallel jobs' do
      cmd = builder.cmake_build_command
      expect(cmd).to eq(['make', '-j4'])
    end
  end

  describe '#cmake_args with CMAKE_PREFIX_PATH' do
    let(:cpu_family) { 'arm64' }
    let(:arch) { 'aarch64' }
    let(:target_cross) { 'aarch64-linux-gnu-' }

    around do |example|
      original = ENV['CMAKE_PREFIX_PATH']
      ENV['CMAKE_PREFIX_PATH'] = '/custom/prefix/path'
      example.run
      ENV['CMAKE_PREFIX_PATH'] = original
    end

    it 'includes CMAKE_PREFIX_PATH when set' do
      metadata = { 'cmake_opts' => [] }
      args = builder.cmake_args(metadata)
      expect(args).to include('-DCMAKE_PREFIX_PATH=/custom/prefix/path')
    end
  end

  describe '#make_command' do
    let(:cpu_family) { 'arm64' }
    let(:arch) { 'aarch64' }
    let(:target_cross) { 'aarch64-linux-gnu-' }

    let(:metadata) do
      { 'platform' => 'unix', 'extra_args' => [] }
    end

    it 'builds make command with makefile and parallel flag' do
      cmd = builder.make_command(metadata, 'Makefile.libretro')
      expect(cmd).to include('make')
      expect(cmd).to include('-f')
      expect(cmd).to include('Makefile.libretro')
      expect(cmd).to include('-j4')
    end

    it 'builds clean command when clean: true' do
      cmd = builder.make_command(metadata, 'Makefile', clean: true)
      expect(cmd).to eq(['make', '-f', 'Makefile', 'clean'])
      expect(cmd).not_to include('-j4')
    end
  end

  describe 'platform resolution' do
    let(:cpu_family) { 'arm64' }
    let(:arch) { 'aarch64' }
    let(:target_cross) { 'aarch64-linux-gnu-' }

    it 'raises error when platform is nil' do
      metadata = { 'platform' => nil, 'extra_args' => [] }
      expect { builder.make_args(metadata) }.to raise_error(/Missing 'platform'/)
    end

    it 'uses platform from metadata' do
      metadata = { 'platform' => 'unix', 'extra_args' => [] }
      args = builder.make_args(metadata)
      expect(args).to include('platform=unix')
    end
  end

end
