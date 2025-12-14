# frozen_string_literal: true

# Code coverage - must be loaded before application code
require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  enable_coverage :branch
  minimum_coverage line: 90, branch: 85
end

require 'rspec'

# Add lib directory to load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed

  # Suppress stdout during tests to reduce noise
  original_stdout = $stdout
  original_stderr = $stderr

  config.before(:suite) do
    $stdout = StringIO.new unless ENV['VERBOSE']
  end

  config.after(:suite) do
    $stdout = original_stdout
  end
end
