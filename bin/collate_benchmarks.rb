#!/usr/bin/env ruby
# frozen_string_literal: true

# Collate benchmark JSON files from the CI matrix into a markdown comparison table.
#
# Usage:
#   ruby bin/collate_benchmarks.rb <input_dir> <output.md>
#   ruby bin/collate_benchmarks.rb docs/benchmarks tmp/benchmark_chart.md
#
# Reads all .json benchmark files, groups by benchmark label, and produces
# a markdown table comparing wall time, CPU time, and memory across environments.
# Also generates historical trend data if multiple timestamped runs exist.

require "json"
require "time"

input_dir = ARGV[0] || "tmp/bench-results"
output_path = ARGV[1] || "tmp/benchmark_chart.md"

files = Dir.glob(File.join(input_dir, "**", "*.json")).sort
if files.empty?
  warn "No benchmark JSON files found in #{input_dir}"
  exit 0
end

# Parse all results
runs = files.filter_map do |path|
  data = JSON.parse(File.read(path), symbolize_names: true)
  next unless data[:environment] && data[:benchmarks]

  data
rescue JSON::ParserError => e
  warn "Skipping #{path}: #{e.message}"
  nil
end

if runs.empty?
  warn "No valid benchmark data found"
  exit 0
end

# Group runs by timestamp (latest per environment config)
latest_runs = runs
  .group_by { |r| "#{r[:environment][:os]}_#{r[:environment][:ruby_engine]}#{r[:environment][:ruby_version]}_#{r[:environment][:shell]}" }
  .transform_values { |group| group.max_by { |r| r[:environment][:timestamp] } }

# Collect all unique benchmark labels
all_labels = latest_runs.values.flat_map { |r| r[:benchmarks].map { |b| b[:label] } }.uniq.sort

# Build environment column headers
env_keys = latest_runs.keys.sort
env_labels = env_keys.map do |key|
  r = latest_runs[key][:environment]
  engine = r[:ruby_engine] == "ruby" ? "CRuby" : r[:ruby_engine].capitalize
  os_short = r[:os].include?("darwin") ? "macOS" : r[:os].include?("linux") ? "Linux" : r[:os]
  shell_short = File.basename(r[:shell].to_s)
  "#{engine} #{r[:ruby_version]} / #{os_short} / #{shell_short}"
end

# Generate markdown
lines = []
lines << "## Benchmark results"
lines << ""
lines << "Latest results from CI matrix (#{Time.now.utc.strftime("%Y-%m-%d")})."
lines << ""

# Wall time comparison table
lines << "### Wall time (seconds)"
lines << ""
header = "| Benchmark | " + env_labels.join(" | ") + " |"
sep = "|---|" + env_keys.map { "---:|" }.join
lines << header
lines << sep

all_labels.each do |label|
  cols = env_keys.map do |key|
    bench = latest_runs[key][:benchmarks].find { |b| b[:label] == label }
    bench ? format("%.4f", bench[:wall_seconds]) : "--"
  end
  lines << "| `#{label}` | #{cols.join(" | ")} |"
end
lines << ""

# Summary row
lines << "### Summary"
lines << ""
sum_header = "| Metric | " + env_labels.join(" | ") + " |"
sum_sep = "|---|" + env_keys.map { "---:|" }.join
lines << sum_header
lines << sum_sep

[:total_wall_seconds, :total_cpu_seconds, :peak_memory_kb, :total_objects_allocated].each do |metric|
  cols = env_keys.map do |key|
    s = latest_runs[key][:summary]
    val = s[metric]
    case metric
    when :peak_memory_kb
      "#{(val.to_f / 1024).round(1)} MB"
    when :total_objects_allocated
      val.to_i > 1_000_000 ? "#{(val.to_f / 1_000_000).round(1)}M" : val.to_s
    else
      format("%.3f", val)
    end
  end
  pretty = metric.to_s.tr("_", " ").capitalize
  lines << "| #{pretty} | #{cols.join(" | ")} |"
end
lines << ""

# Historical trend (if we have multiple runs for the same config)
historical = runs
  .group_by { |r| "#{r[:environment][:os]}_#{r[:environment][:ruby_engine]}#{r[:environment][:ruby_version]}_#{r[:environment][:shell]}" }
  .select { |_, group| group.size > 1 }

unless historical.empty?
  lines << "### Trend (last 5 runs)"
  lines << ""
  lines << "Total wall time per run:"
  lines << ""

  historical.each do |config_key, group|
    env = group.first[:environment]
    engine = env[:ruby_engine] == "ruby" ? "CRuby" : env[:ruby_engine].capitalize
    label = "#{engine} #{env[:ruby_version]} / #{File.basename(env[:shell].to_s)}"

    recent = group.sort_by { |r| r[:environment][:timestamp] }.last(5)
    sparkline_chars = " _.-=^"
    values = recent.map { |r| r[:summary][:total_wall_seconds] }
    min_v, max_v = values.minmax
    range = [max_v - min_v, 0.001].max

    spark = values.map do |v|
      idx = ((v - min_v) / range * (sparkline_chars.length - 1)).round
      sparkline_chars[idx]
    end.join

    dates = recent.map { |r| Time.parse(r[:environment][:timestamp]).strftime("%m/%d") }

    lines << "**#{label}**: `#{spark}` #{values.map { |v| format("%.2f", v) }.join(" -> ")}s (#{dates.first}..#{dates.last})"
  end
  lines << ""
end

# Write output
dir = File.dirname(output_path)
Dir.mkdir(dir) unless File.exist?(dir)
File.write(output_path, lines.join("\n") + "\n")

puts "Benchmark chart written to #{output_path}"
puts "  #{latest_runs.size} environments, #{all_labels.size} benchmarks"
