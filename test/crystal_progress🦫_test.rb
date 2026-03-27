# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/progress🦫bar🦫none"

class ProgressBarNoneTest < Minitest::Test
  def test_version
    assert_match(/\A\d+\.\d+(?:\.\d+)?(?:-[A-Za-z0-9.]+)?\z/, ProgressBarNone::VERSION)
  end

  def test_ansi_strip
    str = "\e[31mHello\e[0m World"
    assert_equal "Hello World", ProgressBarNone::ANSI.strip(str)
  end

  def test_ansi_visible_length
    str = "\e[31mHello\e[0m"
    assert_equal 5, ProgressBarNone::ANSI.visible_length(str)
  end

  def test_palette_color
    color = ProgressBarNone::ANSI.palette_color(:crystal, 0.5)
    assert_match(/\e\[38;2;\d+;\d+;\d+m/, color)
  end

  def test_sparkline_generate
    values = [1, 2, 3, 4, 5]
    sparkline = ProgressBarNone::Sparkline.generate(values, width: 5)
    assert_equal 5, sparkline.length
    refute_empty sparkline
  end

  def test_sparkline_colored
    values = [1, 2, 3, 4, 5]
    sparkline = ProgressBarNone::Sparkline.generate_colored(values, width: 5)
    assert_match(/\e\[/, sparkline)
  end

  def test_metrics_tracking
    metrics = ProgressBarNone::Metrics.new
    metrics.record({ latency: 10, throughput: 100 })
    metrics.record({ latency: 20, throughput: 200 })

    assert metrics.any?
    assert_equal [:latency, :throughput], metrics.names

    latency = metrics[:latency]
    assert_equal 15.0, latency.avg
    assert_equal 10, latency.min
    assert_equal 20, latency.max
    assert_equal 30.0, latency.sum
    assert_equal 2, latency.count
  end

  def test_bar_initialization
    bar = ProgressBarNone::Bar.new(total: 100)
    assert_equal 100, bar.total
    assert_equal 0, bar.current
    assert_equal 0.0, bar.progress
  end

  def test_bar_increment
    output = StringIO.new
    bar = ProgressBarNone::Bar.new(total: 10, output: output)
    bar.start

    bar.increment
    assert_equal 1, bar.current
    assert_in_delta 0.1, bar.progress, 0.01

    bar.increment(5)
    assert_equal 6, bar.current

    bar.finish
  end

  def test_bar_with_metrics
    output = StringIO.new
    bar = ProgressBarNone::Bar.new(total: 5, output: output)
    bar.start

    5.times do |i|
      bar.increment(metrics: { value: i * 10 })
    end

    assert bar.metrics.any?
    value_metric = bar.metrics[:value]
    assert_equal 20.0, value_metric.avg
    assert_equal 0, value_metric.min
    assert_equal 40, value_metric.max
    assert_equal 100.0, value_metric.sum

    bar.finish
  end

  def test_with_progress_extension
    output = StringIO.new
    results = []

    [1, 2, 3].with_progress(output: output).each do |i|
      results << i
    end

    assert_equal [1, 2, 3], results
  end

  def test_with_progress_metrics
    output = StringIO.new
    collected_values = []

    [10, 20, 30].with_progress(output: output).each do |val|
      collected_values << val
      { recorded: val }
    end

    assert_equal [10, 20, 30], collected_values
  end

  def test_renderer_styles
    ProgressBarNone::Renderer::STYLES.each_key do |style|
      renderer = ProgressBarNone::Renderer.new(style: style)
      state = { progress: 0.5, current: 50, total: 100 }
      output = renderer.render(state)
      refute_empty output
    end
  end

  def test_renderer_palettes
    palettes = [:crystal, :fire, :ocean, :forest, :sunset, :rainbow, :mono]
    palettes.each do |palette|
      renderer = ProgressBarNone::Renderer.new(palette: palette)
      state = { progress: 0.5, current: 50, total: 100 }
      output = renderer.render(state)
      refute_empty output
    end
  end
end
