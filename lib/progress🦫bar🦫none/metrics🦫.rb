# frozen_string_literal: true

module ProgressBarNone
  # Tracks custom metrics reported by work items
  class Metrics
    # Individual metric tracker
    class Metric
      attr_reader :name, :values, :sum, :min, :max, :count

      def initialize(name)
        @name = name
        @values = []
        @sum = 0.0
        @min = Float::INFINITY
        @max = -Float::INFINITY
        @count = 0
      end

      def add(value)
        value = value.to_f
        @values << value
        @sum += value
        @min = value if value < @min
        @max = value if value > @max
        @count += 1

        # Keep only last 100 values for sparklines
        @values.shift if @values.length > 100
      end

      def avg
        return 0.0 if @count.zero?
        @sum / @count
      end

      def last
        @values.last || 0.0
      end

      # Recent values for sparkline (last n)
      def recent(n = 20)
        @values.last(n)
      end

      def to_h
        {
          avg: avg.round(2),
          min: @min == Float::INFINITY ? 0 : @min.round(2),
          max: @max == -Float::INFINITY ? 0 : @max.round(2),
          sum: @sum.round(2),
          count: @count,
          last: last.round(2),
        }
      end
    end

    attr_reader :metrics

    def initialize
      @metrics = {}
      @mutex = Mutex.new
    end

    # Record metrics from a hash
    # @param data [Hash] Key-value pairs of metric names and values
    def record(data)
      return unless data.is_a?(Hash)

      @mutex.synchronize do
        data.each do |key, value|
          next unless value.is_a?(Numeric)

          key_sym = key.to_sym
          @metrics[key_sym] ||= Metric.new(key.to_s)
          @metrics[key_sym].add(value)
        end
      end
    end

    # Get a specific metric
    def [](name)
      @metrics[name.to_sym]
    end

    # Get all metric names
    def names
      @metrics.keys
    end

    # Check if we have any metrics
    def any?
      @metrics.any?
    end

    # Format metrics for display
    # @param width [Integer] Available width for each metric
    # @param palette [Symbol] Color palette to use
    # @return [Array<String>] Formatted metric lines
    def format_all(width: 60, palette: :crystal, sparkline_width: 15)
      @mutex.synchronize do
        @metrics.map do |name, metric|
          format_metric(name, metric, width: width, palette: palette, sparkline_width: sparkline_width)
        end
      end
    end

    # Format a single metric with sparkline
    def format_metric(name, metric, width: 60, palette: :crystal, sparkline_width: 15)
      # Build the metric display
      sparkline = Sparkline.generate_colored(
        metric.recent(sparkline_width),
        width: sparkline_width,
        palette: palette
      )

      # Colorized label
      label_color = ANSI.palette_color(palette, 0.3)
      value_color = ANSI.palette_color(palette, 0.7)
      dim = ANSI::DIM

      # Format numbers nicely
      avg_str = format_number(metric.avg)
      min_str = format_number(metric.min == Float::INFINITY ? 0 : metric.min)
      max_str = format_number(metric.max == -Float::INFINITY ? 0 : metric.max)
      sum_str = format_number(metric.sum)

      # Build the line
      "#{label_color}#{name}#{ANSI::RESET} " \
        "#{sparkline} " \
        "#{dim}avg:#{ANSI::RESET}#{value_color}#{avg_str}#{ANSI::RESET} " \
        "#{dim}min:#{ANSI::RESET}#{value_color}#{min_str}#{ANSI::RESET} " \
        "#{dim}max:#{ANSI::RESET}#{value_color}#{max_str}#{ANSI::RESET} " \
        "#{dim}Σ:#{ANSI::RESET}#{value_color}#{sum_str}#{ANSI::RESET}"
    end

    private

    def format_number(num)
      if num.abs >= 1_000_000
        "#{(num / 1_000_000.0).round(1)}M"
      elsif num.abs >= 1_000
        "#{(num / 1_000.0).round(1)}K"
      elsif num == num.to_i
        num.to_i.to_s
      else
        num.round(2).to_s
      end
    end
  end
end
