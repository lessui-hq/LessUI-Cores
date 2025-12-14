# frozen_string_literal: true

require 'spec_helper'
require 'source_fetcher'
require 'logger'
require 'tmpdir'

RSpec.describe SourceFetcher do
  let(:cores_dir) { Dir.mktmpdir('cores_spec') }
  let(:cache_dir) { Dir.mktmpdir('cache_spec') }
  let(:logger) { instance_double('BuildLogger', section: nil, info: nil, success: nil, warn: nil, error: nil, step: nil, detail: nil) }
  let(:fetcher) { described_class.new(cores_dir: cores_dir, cache_dir: cache_dir, logger: logger, parallel: 2) }

  after do
    FileUtils.rm_rf(cores_dir)
    FileUtils.rm_rf(cache_dir)
  end

  describe '#fetch_one' do
    context 'when core directory already exists' do
      let(:metadata) do
        {
          'repo' => 'libretro/test-core',
          'commit' => 'abc123'
        }
      end

      before do
        # Create existing directory
        FileUtils.mkdir_p(File.join(cores_dir, 'libretro-test-core'))
      end

      it 'skips fetching and increments skipped counter' do
        allow(fetcher).to receive(:log_thread)

        fetcher.fetch_one('test-core', metadata)

        expect(fetcher.skipped).to eq(1)
        expect(fetcher.fetched).to eq(0)
      end
    end

    context 'with commit SHA (uses tarball)' do
      let(:metadata) do
        {
          'repo' => 'libretro/gambatte-libretro',
          'commit' => '47c5a2feaa9c253efc407283d9247a3c055f9efb'
        }
      end

      it 'uses tarball fetch method' do
        allow(fetcher).to receive(:log_thread)
        expect(fetcher).to receive(:fetch_tarball).with(
          "https://github.com/libretro/gambatte-libretro/archive/47c5a2feaa9c253efc407283d9247a3c055f9efb.tar.gz",
          File.join(cores_dir, 'libretro-gambatte'),
          'libretro-gambatte',
          'libretro/gambatte-libretro',
          '47c5a2feaa9c253efc407283d9247a3c055f9efb'
        )

        fetcher.fetch_one('gambatte', metadata)
      end

      it 'increments fetched counter on success' do
        allow(fetcher).to receive(:log_thread)
        allow(fetcher).to receive(:fetch_tarball)

        fetcher.fetch_one('gambatte', metadata)

        expect(fetcher.fetched).to eq(1)
      end
    end

    context 'with version tag (uses git)' do
      let(:metadata) do
        {
          'repo' => 'libretro/test-core',
          'commit' => 'v1.2.3'
        }
      end

      it 'uses git fetch method for version tags' do
        allow(fetcher).to receive(:log_thread)
        expect(fetcher).to receive(:fetch_git).with(
          'https://github.com/libretro/test-core.git',
          File.join(cores_dir, 'libretro-test-core'),
          'v1.2.3',
          false
        )

        fetcher.fetch_one('test-core', metadata)
      end
    end

    context 'with submodules enabled' do
      let(:metadata) do
        {
          'repo' => 'libretro/test-core',
          'commit' => 'abc123def456',
          'submodules' => true
        }
      end

      it 'uses git fetch method for cores with submodules' do
        allow(fetcher).to receive(:log_thread)
        expect(fetcher).to receive(:fetch_git).with(
          'https://github.com/libretro/test-core.git',
          File.join(cores_dir, 'libretro-test-core'),
          'abc123def456',
          true
        )

        fetcher.fetch_one('test-core', metadata)
      end
    end

    context 'with missing required fields' do
      it 'handles missing repo gracefully' do
        metadata = { 'commit' => 'abc123' }  # Missing repo

        # Should not raise, but should log error and increment failed counter
        fetcher.fetch_one('test', metadata)

        expect(fetcher.failed).to eq(1)
      end

      it 'handles missing commit gracefully' do
        metadata = { 'repo' => 'libretro/test-core' }  # Missing commit

        fetcher.fetch_one('test', metadata)

        expect(fetcher.failed).to eq(1)
      end
    end

    context 'when fetch fails' do
      let(:metadata) do
        {
          'repo' => 'libretro/test-core',
          'commit' => 'abc123'
        }
      end

      it 'increments failed counter and logs error' do
        allow(fetcher).to receive(:fetch_tarball).and_raise(StandardError, 'Network error')
        allow(fetcher).to receive(:log_thread)

        fetcher.fetch_one('test-core', metadata)

        expect(fetcher.failed).to eq(1)
        expect(fetcher.fetched).to eq(0)
      end
    end
  end

  describe '#fetch_all' do
    let(:recipes) do
      {
        'gambatte' => {
          'repo' => 'libretro/gambatte-libretro',
          'commit' => 'abc123'
        },
        'fceumm' => {
          'repo' => 'libretro/libretro-fceumm',
          'commit' => 'def456'
        }
      }
    end

    it 'processes all recipes' do
      allow(fetcher).to receive(:fetch_tarball)
      allow(fetcher).to receive(:log_thread)

      fetcher.fetch_all(recipes)

      expect(fetcher.fetched).to eq(2)
    end

    it 'logs summary with counts' do
      allow(fetcher).to receive(:fetch_tarball)
      allow(fetcher).to receive(:log_thread)

      expect(logger).to receive(:success).with(/Fetched: 2, Skipped: 0, Failed: 0/)

      fetcher.fetch_all(recipes)
    end

    it 'creates cores and cache directories' do
      allow(fetcher).to receive(:fetch_tarball)
      allow(fetcher).to receive(:log_thread)

      fetcher.fetch_all(recipes)

      expect(Dir.exist?(cores_dir)).to be true
      expect(Dir.exist?(cache_dir)).to be true
    end
  end

  describe 'parallel processing' do
    let(:recipes) do
      (1..10).map do |i|
        ["core#{i}", {
          'repo' => "libretro/core#{i}",
          'commit' => "commit#{i}"
        }]
      end.to_h
    end

    it 'processes cores in parallel' do
      allow(fetcher).to receive(:fetch_tarball)
      allow(fetcher).to receive(:log_thread)

      fetcher.fetch_all(recipes)

      # With 10 cores and parallel: 2, should be faster than sequential
      # Just verify it completes successfully
      expect(fetcher.fetched).to eq(10)
    end
  end

  describe 'naming convention' do
    let(:metadata) do
      {
        'repo' => 'libretro/gambatte-libretro',
        'commit' => 'abc123'
      }
    end

    it 'constructs directory name as libretro-{corename}' do
      allow(fetcher).to receive(:log_thread)
      allow(fetcher).to receive(:fetch_tarball) do |_url, target_dir, _repo_name, _repo, _ref|
        expect(target_dir).to eq(File.join(cores_dir, 'libretro-gambatte'))
      end

      fetcher.fetch_one('gambatte', metadata)
    end
  end

  describe 'fetch_tarball' do
    let(:metadata) do
      {
        'repo' => 'libretro/test-core',
        'commit' => 'abc123def456789012345678901234567890abcd'
      }
    end

    it 'creates cache directory and downloads tarball' do
      allow(fetcher).to receive(:log_thread)

      # Mock run_command to simulate successful wget and tar
      expect(fetcher).to receive(:run_command).with('wget', '-q', '-O', anything, anything).ordered
      expect(fetcher).to receive(:run_command).with('tar', '-xzf', anything, '-C', anything, '--strip-components=1').ordered

      fetcher.fetch_one('test-core', metadata)

      # Verify cache directory was created
      expect(Dir.exist?(File.join(cache_dir, 'libretro--test-core'))).to be true
    end

    it 'uses cached tarball if already present' do
      allow(fetcher).to receive(:log_thread)

      # Create fake cached tarball
      repo_cache_dir = File.join(cache_dir, 'libretro--test-core')
      FileUtils.mkdir_p(repo_cache_dir)
      cached_file = File.join(repo_cache_dir, 'abc123def456789012345678901234567890abcd.tar.gz')
      FileUtils.touch(cached_file)

      # Should only call tar (not wget) since file exists
      expect(fetcher).not_to receive(:run_command).with('wget', any_args)
      expect(fetcher).to receive(:run_command).with('tar', '-xzf', anything, '-C', anything, '--strip-components=1')

      fetcher.fetch_one('test-core', metadata)
    end
  end

  describe 'fetch_git' do
    context 'with version tag' do
      let(:metadata) do
        {
          'repo' => 'libretro/test-core',
          'commit' => 'v1.2.3'
        }
      end

      it 'uses shallow clone for version tags' do
        allow(fetcher).to receive(:log_thread)

        expect(fetcher).to receive(:run_command).with(
          'git', 'clone', '--quiet', '--depth', '1',
          '--branch', 'v1.2.3',
          'https://github.com/libretro/test-core.git',
          anything
        )

        fetcher.fetch_one('test-core', metadata)
      end
    end

    context 'with version tag and submodules' do
      let(:metadata) do
        {
          'repo' => 'libretro/test-core',
          'commit' => 'v1.2.3',
          'submodules' => true
        }
      end

      it 'uses shallow clone with --recurse-submodules' do
        allow(fetcher).to receive(:log_thread)

        expect(fetcher).to receive(:run_command).with(
          'git', 'clone', '--quiet', '--depth', '1',
          '--branch', 'v1.2.3',
          '--recurse-submodules',
          'https://github.com/libretro/test-core.git',
          anything
        )

        fetcher.fetch_one('test-core', metadata)
      end
    end

    context 'with full SHA commit' do
      let(:metadata) do
        {
          'repo' => 'libretro/test-core',
          'commit' => 'abc123def456789012345678901234567890abcd',
          'submodules' => true
        }
      end

      it 'uses full clone and checkout for SHA with submodules' do
        allow(fetcher).to receive(:log_thread)
        target_dir = File.join(cores_dir, 'libretro-test-core')

        # Full clone
        expect(fetcher).to receive(:run_command).with(
          'git', 'clone', '--quiet',
          'https://github.com/libretro/test-core.git',
          target_dir
        ).ordered

        # Checkout specific commit
        expect(fetcher).to receive(:run_command).with(
          'git', '-C', target_dir, 'checkout', '--quiet',
          'abc123def456789012345678901234567890abcd'
        ).ordered

        # Initialize submodules
        expect(fetcher).to receive(:run_command).with(
          'git', '-C', target_dir, 'submodule', 'update', '--init', '--recursive', '--quiet'
        ).ordered

        fetcher.fetch_one('test-core', metadata)
      end
    end

  end

  describe 'run_command error handling' do
    let(:metadata) do
      {
        'repo' => 'libretro/test-core',
        'commit' => 'v1.0.0'
      }
    end

    it 'raises error when command fails' do
      allow(fetcher).to receive(:log_thread)

      # Mock Open3 to simulate failure
      allow(Open3).to receive(:capture3).and_return(['', 'error output', double(success?: false)])

      fetcher.fetch_one('test-core', metadata)

      expect(fetcher.failed).to eq(1)
    end
  end

  describe 'log_thread' do
    it 'logs step messages for normal operations' do
      allow(fetcher).to receive(:fetch_tarball)

      expect(logger).to receive(:step).with(/Fetching/)

      fetcher.fetch_one('test', { 'repo' => 'test/test', 'commit' => 'abc123' })
    end

    it 'logs error messages when error: true' do
      expect(logger).to receive(:error).with(/Failed/)

      fetcher.fetch_one('test', { 'commit' => 'abc123' })  # Missing repo
    end
  end
end
