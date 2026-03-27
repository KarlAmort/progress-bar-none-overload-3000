# frozen_string_literal: true

module ProgressBarNone
  module ProgressbarCompat
    class Bar
      DEFAULT_TOTAL = 100

      def self.create(**options)
        new(**options)
      end

      def initialize(**options)
        @output = options.fetch(:output, $stderr)
        @title = options[:title]
        @total = normalize_total(options[:total] || options[:length])
        @progress = normalize_progress(options[:starting_at] || options[:progress] || 0)

        @bar = ProgressBarNone::Bar.new(
          total: @total,
          title: @title,
          output: @output,
          width: options[:width] || options[:length] || 40,
          style: options[:style] || :crystal,
          palette: options[:palette] || :crystal,
          spinner: options[:spinner] || :braille,
          rainbow_mode: !!options[:rainbow_mode],
          celebration: options[:celebration] || :confetti,
          glow: !!options[:glow],
          fps: options[:fps] || 15
        )

        @bar.start
        @bar.set(@progress)
      end

      attr_reader :output

      def total
        @total
      end

      def total=(value)
        @total = normalize_total(value)
        @bar.instance_variable_set(:@total, @total)
        @progress = [@progress, @total].min
        @bar.set(@progress)
      end

      def progress
        @progress
      end

      def progress=(value)
        @progress = normalize_progress(value)
        @bar.set(@progress)
      end

      def title
        @title
      end

      def title=(value)
        @title = value.to_s
        @bar.instance_variable_set(:@title, @title)
      end

      def increment
        increment_progress(1)
      end

      def decrement
        increment_progress(-1)
      end

      def log(message)
        output.puts(message)
        output.flush
      end

      def pause; end

      def resume; end

      def stopped?
        false
      end

      def finished?
        @progress >= @total
      end

      def reset
        self.progress = 0
      end

      def finish
        @progress = @total
        @bar.finish
      end

      private

      def normalize_total(value)
        n = value.to_i
        n = DEFAULT_TOTAL if n <= 0
        n
      end

      def normalize_progress(value)
        n = value.to_i
        n = 0 if n.negative?
        [n, @total || DEFAULT_TOTAL].min
      end

      def increment_progress(by)
        next_value = @progress + by.to_i
        self.progress = next_value
      end
    end
  end
end

# Top-level compatibility constants matching the common progressbar API.
unless defined?(::ProgressBar)
  module ProgressBar
    class << self
      def create(**options)
        ProgressBarNone::ProgressbarCompat::Bar.create(**options)
      end
    end
  end
end
