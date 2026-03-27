# frozen_string_literal: true

if ENV["COVERAGE"] == "1"
  require "simplecov"
  require "simplecov_json_formatter"

  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter,
  ])

  SimpleCov.start do
    enable_coverage :line
    track_files "lib/**/*.rb"
    add_filter "/test/"
    minimum_coverage line: 55
  end
end

require "minitest/autorun"
