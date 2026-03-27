# frozen_string_literal: true

# Exhaustive benchmark test for progress_bar_none_overload_3000
#
# Exercises every major feature path while measuring:
#   - Wall-clock time
#   - CPU time (user + system)
#   - Peak RSS memory
#   - GC stats (heap pages, object counts, GC runs)
#
# Usage:
#   ruby test/benchmark🦫_test.rb                    # run all benchmarks
#   ruby test/benchmark🦫_test.rb --json             # emit JSON for CI ingestion
#   ruby test/benchmark🦫_test.rb --compare FILE     # compare against prior JSON
#
# The JSON output includes environment metadata (Ruby version, shell, terminal,
# OS) so results from different matrices can be collated into comparison charts.

require "minitest/autorun"
require "json"
require "stringio"
require_relative "../lib/progress🦫bar🦫none"

module BenchmarkHelpers
  # Collect environment metadata for cross-matrix comparison
  def self.environment
    {
      ruby_version: RUBY_VERSION,
      ruby_engine: RUBY_ENGINE,
      ruby_engine_version: defined?(RUBY_ENGINE_VERSION) ? RUBY_ENGINE_VERSION : RUBY_VERSION,
      ruby_platform: RUBY_PLATFORM,
      ruby_description: RUBY_DESCRIPTION,
      shell: ENV["SHELL"] || "unknown",
      term_program: ENV["TERM_PROGRAM"] || "unknown",
      term: ENV["TERM"] || "unknown",
      colorterm: ENV["COLORTERM"] || "unknown",
      os: RbConfig::CONFIG["host_os"],
      cpu: RbConfig::CONFIG["host_cpu"],
      timestamp: Time.now.utc.iso8601,
    }
  end

  # Measure a block's resource usage
  def self.measure(label, &block)
    GC.start
    gc_before = GC.stat
    mem_before = current_rss_kb

    cpu_before = Process.times
    wall_before = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    result = block.call

    wall_after = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    cpu_after = Process.times

    GC.start
    gc_after = GC.stat
    mem_after = current_rss_kb

    {
      label: label,
      wall_seconds: (wall_after - wall_before).round(6),
      cpu_user_seconds: (cpu_after.utime - cpu_before.utime).round(6),
      cpu_system_seconds: (cpu_after.stime - cpu_before.stime).round(6),
      memory_delta_kb: mem_after - mem_before,
      memory_peak_kb: mem_after,
      gc_count: gc_after[:count] - gc_before[:count],
      gc_major_count: gc_after[:major_gc_count] - gc_before[:major_gc_count],
      heap_pages_delta: gc_after[:heap_available_slots] - gc_before[:heap_available_slots],
      objects_allocated_delta: gc_after[:total_allocated_objects] - gc_before[:total_allocated_objects],
      result: result,
    }
  end

  # Get current RSS in KB (macOS and Linux)
  def self.current_rss_kb
    if RUBY_PLATFORM.include?("darwin")
      # macOS: use ps
      `ps -o rss= -p #{Process.pid}`.strip.to_i
    elsif File.exist?("/proc/#{Process.pid}/status")
      # Linux: read from procfs
      File.read("/proc/#{Process.pid}/status")[/VmRSS:\s+(\d+)/, 1].to_i
    else
      0
    end
  rescue StandardError
    0
  end
end

class BenchmarkTest < Minitest::Test
  DEVNULL = StringIO.new

  # Number of items for each benchmark pass
  N_SMALL = 50
  N_MEDIUM = 500
  N_LARGE = 5_000

  def setup
    @results = []
  end

  def teardown
    return if @results.empty?

    # Accumulate results for the class-level reporter
    @@all_results ||= []
    @@all_results.concat(@results)
  end

  # --- Feature: Basic progress bar rendering ---

  def test_bench_basic_progress_small
    m = BenchmarkHelpers.measure("basic_progress_#{N_SMALL}") do
      (1..N_SMALL).with_progress(output: DEVNULL).each { |_| nil }
    end
    @results << m
    assert m[:wall_seconds] < 30, "basic progress (#{N_SMALL}) took too long: #{m[:wall_seconds]}s"
  end

  def test_bench_basic_progress_large
    m = BenchmarkHelpers.measure("basic_progress_#{N_LARGE}") do
      (1..N_LARGE).with_progress(output: DEVNULL).each { |_| nil }
    end
    @results << m
    assert m[:wall_seconds] < 60, "basic progress (#{N_LARGE}) took too long: #{m[:wall_seconds]}s"
  end

  # --- Feature: All styles ---

  def test_bench_all_styles
    styles = ProgressBarNone::Renderer::STYLES.keys
    m = BenchmarkHelpers.measure("all_#{styles.size}_styles") do
      styles.each do |style|
        (1..N_SMALL).with_progress(output: DEVNULL, style: style).each { |_| nil }
      end
    end
    @results << m
    assert m[:wall_seconds] < 120, "all styles took too long: #{m[:wall_seconds]}s"
  end

  # --- Feature: All palettes ---

  def test_bench_all_palettes
    palettes = ProgressBarNone::ANSI::CRYSTAL_PALETTE.keys
    m = BenchmarkHelpers.measure("all_#{palettes.size}_palettes") do
      palettes.each do |palette|
        (1..N_SMALL).with_progress(output: DEVNULL, palette: palette).each { |_| nil }
      end
    end
    @results << m
    assert m[:wall_seconds] < 120, "all palettes took too long: #{m[:wall_seconds]}s"
  end

  # --- Feature: All spinners ---

  def test_bench_all_spinners
    spinners = ProgressBarNone::ANSI::SPINNERS.keys
    m = BenchmarkHelpers.measure("all_#{spinners.size}_spinners") do
      spinners.each do |spinner|
        (1..N_SMALL).with_progress(output: DEVNULL, spinner: spinner).each { |_| nil }
      end
    end
    @results << m
    assert m[:wall_seconds] < 120, "all spinners took too long: #{m[:wall_seconds]}s"
  end

  # --- Feature: Metrics tracking ---

  def test_bench_metrics_tracking
    m = BenchmarkHelpers.measure("metrics_tracking_#{N_MEDIUM}") do
      (1..N_MEDIUM).with_progress(output: DEVNULL, title: "Metrics bench").each do |i|
        { latency_ms: rand(5..200), throughput: rand(100..5000), error_rate: rand * 0.05 }
      end
    end
    @results << m
    assert m[:wall_seconds] < 60, "metrics tracking took too long: #{m[:wall_seconds]}s"
  end

  # --- Feature: Sparkline generation ---

  def test_bench_sparkline_generation
    values = (1..1000).map { rand(0.0..100.0) }
    m = BenchmarkHelpers.measure("sparkline_1000_values") do
      1000.times do
        ProgressBarNone::Sparkline.generate(values, width: 20)
        ProgressBarNone::Sparkline.generate_colored(values, width: 20, palette: :fire)
      end
    end
    @results << m
    assert m[:wall_seconds] < 30, "sparkline generation took too long: #{m[:wall_seconds]}s"
  end

  # --- Feature: ANSI color generation ---

  def test_bench_ansi_color_generation
    palettes = ProgressBarNone::ANSI::CRYSTAL_PALETTE.keys
    m = BenchmarkHelpers.measure("ansi_color_#{palettes.size}_palettes_x_1000") do
      palettes.each do |palette|
        1000.times do |i|
          ProgressBarNone::ANSI.palette_color(palette, i / 1000.0)
        end
      end
    end
    @results << m
    assert m[:wall_seconds] < 10, "ANSI color generation took too long: #{m[:wall_seconds]}s"
  end

  # --- Feature: Rainbow mode ---

  def test_bench_rainbow_mode
    m = BenchmarkHelpers.measure("rainbow_mode_#{N_MEDIUM}") do
      (1..N_MEDIUM).with_progress(
        output: DEVNULL,
        rainbow_mode: true,
        style: :crystal,
        palette: :rainbow
      ).each { |_| nil }
    end
    @results << m
    assert m[:wall_seconds] < 60, "rainbow mode took too long: #{m[:wall_seconds]}s"
  end

  # --- Feature: Glow effect ---

  def test_bench_glow_effect
    m = BenchmarkHelpers.measure("glow_effect_#{N_MEDIUM}") do
      (1..N_MEDIUM).with_progress(
        output: DEVNULL,
        glow: true,
        style: :cyberpunk,
        palette: :neon
      ).each { |_| nil }
    end
    @results << m
    assert m[:wall_seconds] < 60, "glow effect took too long: #{m[:wall_seconds]}s"
  end

  # --- Feature: Direct Bar API ---

  def test_bench_direct_bar_api
    m = BenchmarkHelpers.measure("direct_bar_api_#{N_LARGE}") do
      bar = ProgressBarNone::Bar.new(total: N_LARGE, output: DEVNULL, title: "Direct API")
      bar.start
      N_LARGE.times { bar.increment }
      bar.finish
    end
    @results << m
    assert m[:wall_seconds] < 60, "direct bar API took too long: #{m[:wall_seconds]}s"
  end

  # --- Feature: Direct Bar API with metrics ---

  def test_bench_direct_bar_api_with_metrics
    m = BenchmarkHelpers.measure("direct_bar_metrics_#{N_MEDIUM}") do
      bar = ProgressBarNone::Bar.new(total: N_MEDIUM, output: DEVNULL, title: "Metrics API")
      bar.start
      N_MEDIUM.times do |i|
        bar.increment(metrics: { value: i, rate: rand(10..1000) })
      end
      bar.finish
    end
    @results << m
    assert m[:wall_seconds] < 60, "direct bar with metrics took too long: #{m[:wall_seconds]}s"
  end

  # --- Feature: Renderer output size ---

  def test_bench_renderer_output_size
    m = BenchmarkHelpers.measure("renderer_all_styles_output_size") do
      sizes = {}
      ProgressBarNone::Renderer::STYLES.each_key do |style|
        renderer = ProgressBarNone::Renderer.new(style: style, width: 40, palette: :crystal)
        output = renderer.render(progress: 0.5, current: 50, total: 100)
        raw_bytes = output.join("\n").bytesize
        visible_chars = output.map { |l| ProgressBarNone::ANSI.visible_length(l) }.sum
        sizes[style] = { raw_bytes: raw_bytes, visible_chars: visible_chars }
      end
      sizes
    end
    @results << m
  end

  # --- Feature: Frames ---

  def test_bench_frames
    m = BenchmarkHelpers.measure("frames_all_styles") do
      [:single, :double, :rounded, :bold, :ascii, :cyber, :neon, :stars].each do |style|
        100.times do
          ProgressBarNone::Frames.wrap("Benchmark content line here", style: style)
        end
      end
    end
    @results << m
    assert m[:wall_seconds] < 10, "frames rendering took too long: #{m[:wall_seconds]}s"
  end

  # --- Feature: Gantt chart ---

  def test_bench_gantt_render
    tasks = 20.times.map do |i|
      { name: "Task #{i}", start: i * 2, duration: 3, group: "Group #{i / 5}" }
    end
    m = BenchmarkHelpers.measure("gantt_20_tasks_render") do
      gantt = ProgressBarNone::Gantt.new(tasks, title: "Benchmark pipeline", width: 80)
      gantt.render
    end
    @results << m
    assert m[:wall_seconds] < 10, "gantt render took too long: #{m[:wall_seconds]}s"
  end

  # --- Feature: Gantt SVG export ---

  def test_bench_gantt_svg
    tasks = 20.times.map do |i|
      { name: "Task #{i}", start: i * 2, duration: 3, group: "Group #{i / 5}" }
    end
    m = BenchmarkHelpers.measure("gantt_20_tasks_svg") do
      gantt = ProgressBarNone::Gantt.new(tasks, title: "SVG bench", width: 80)
      gantt.render_svg
    end
    @results << m
    assert m[:wall_seconds] < 10, "gantt SVG took too long: #{m[:wall_seconds]}s"
  end

  # --- Feature: ANSI strip performance ---

  def test_bench_ansi_strip
    # Build a realistic ANSI-heavy string
    sample = (1..100).map { |i|
      "\e[38;2;#{rand(256)};#{rand(256)};#{rand(256)}m#{"x" * 10}\e[0m"
    }.join
    m = BenchmarkHelpers.measure("ansi_strip_10k_calls") do
      10_000.times { ProgressBarNone::ANSI.strip(sample) }
    end
    @results << m
    assert m[:wall_seconds] < 10, "ANSI strip took too long: #{m[:wall_seconds]}s"
  end

  # --- Feature: ProgressBar compatibility layer ---

  def test_bench_progressbar_compat
    m = BenchmarkHelpers.measure("progressbar_compat_#{N_MEDIUM}") do
      bar = ProgressBarNone::ProgressbarCompat::Bar.new(
        total: N_MEDIUM,
        title: "Compat bench",
        output: DEVNULL
      )
      N_MEDIUM.times { bar.increment }
      bar.finish
    end
    @results << m
    assert m[:wall_seconds] < 60, "progressbar compat took too long: #{m[:wall_seconds]}s"
  end

  # --- Feature: Memory stress (many bars created/destroyed) ---

  def test_bench_memory_stress
    m = BenchmarkHelpers.measure("memory_stress_100_bars") do
      100.times do
        bar = ProgressBarNone::Bar.new(total: 50, output: DEVNULL)
        bar.start
        50.times { bar.increment(metrics: { v: rand(100) }) }
        bar.finish
      end
    end
    @results << m
    assert m[:memory_delta_kb] < 100_000, "memory stress used too much RAM: #{m[:memory_delta_kb]}KB"
  end

  # --- Feature: Combination stress (all features at once) ---

  def test_bench_combination_stress
    m = BenchmarkHelpers.measure("combination_stress_#{N_MEDIUM}") do
      (1..N_MEDIUM).with_progress(
        output: DEVNULL,
        title: "Stress test",
        style: :fire,
        palette: :neon,
        rainbow_mode: true,
        spinner: :rocket,
        celebration: :firework,
        glow: true,
        fps: 30
      ).each do |i|
        { latency: rand(1..100), throughput: rand(500..5000), errors: rand(0..5) }
      end
    end
    @results << m
    assert m[:wall_seconds] < 120, "combination stress took too long: #{m[:wall_seconds]}s"
  end

  # -------------------------------------------------------------------------
  # Report generation (runs after all tests)
  # -------------------------------------------------------------------------

  Minitest.after_run do
    results = (defined?(@@all_results) && @@all_results) || []
    next if results.empty?

    env = BenchmarkHelpers.environment

    report = {
      environment: env,
      benchmarks: results.map { |r| r.except(:result) },
      summary: {
        total_benchmarks: results.size,
        total_wall_seconds: results.sum { |r| r[:wall_seconds] }.round(3),
        total_cpu_seconds: results.sum { |r| r[:cpu_user_seconds] + r[:cpu_system_seconds] }.round(3),
        peak_memory_kb: results.map { |r| r[:memory_peak_kb] }.max,
        total_objects_allocated: results.sum { |r| r[:objects_allocated_delta] },
      },
    }

    # Always print a human-readable summary
    puts "\n#{"=" * 72}"
    puts "BENCHMARK RESULTS -- #{env[:ruby_description]}"
    puts "Shell: #{env[:shell]}  Terminal: #{env[:term_program]}  OS: #{env[:os]}"
    puts "#{"=" * 72}"
    puts
    printf "%-45s %10s %10s %10s %12s\n", "Benchmark", "Wall (s)", "CPU (s)", "Mem (KB)", "Objects"
    puts "-" * 92
    results.sort_by { |r| -r[:wall_seconds] }.each do |r|
      cpu = r[:cpu_user_seconds] + r[:cpu_system_seconds]
      printf "%-45s %10.4f %10.4f %10d %12d\n",
             r[:label], r[:wall_seconds], cpu, r[:memory_delta_kb], r[:objects_allocated_delta]
    end
    puts "-" * 92
    s = report[:summary]
    printf "%-45s %10.4f %10.4f %10s %12d\n",
           "TOTAL", s[:total_wall_seconds], s[:total_cpu_seconds], "peak:#{s[:peak_memory_kb]}", s[:total_objects_allocated]
    puts

    # JSON output for CI
    if ARGV.include?("--json") || ENV["BENCH_JSON"]
      json_path = ENV["BENCH_JSON_PATH"] || "tmp/benchmark_#{env[:ruby_engine]}_#{env[:ruby_version]}_#{Time.now.strftime("%Y%m%d_%H%M%S")}.json"
      dir = File.dirname(json_path)
      Dir.mkdir(dir) unless File.exist?(dir)
      File.write(json_path, JSON.pretty_generate(report))
      puts "JSON results written to #{json_path}"
    end

    # Compare against a prior run
    if (compare_file = ARGV.find { |a| a.start_with?("--compare") })
      compare_path = compare_file.split("=", 2).last
      compare_path = ARGV[ARGV.index(compare_file) + 1] if compare_path == compare_file
      if compare_path && File.exist?(compare_path)
        prior = JSON.parse(File.read(compare_path), symbolize_names: true)
        puts "\nCOMPARISON vs #{compare_path}"
        puts "Prior: #{prior[:environment][:ruby_description]} / #{prior[:environment][:term_program]}"
        puts
        printf "%-45s %10s %10s %10s\n", "Benchmark", "Current", "Prior", "Delta"
        puts "-" * 80
        results.each do |r|
          prior_bench = prior[:benchmarks]&.find { |b| b[:label] == r[:label] }
          next unless prior_bench

          delta = r[:wall_seconds] - prior_bench[:wall_seconds]
          sign = delta > 0 ? "+" : ""
          pct = prior_bench[:wall_seconds] > 0 ? (delta / prior_bench[:wall_seconds] * 100).round(1) : 0
          printf "%-45s %10.4f %10.4f %9s%%\n",
                 r[:label], r[:wall_seconds], prior_bench[:wall_seconds], "#{sign}#{pct}"
        end
        puts
      end
    end
  end
end
