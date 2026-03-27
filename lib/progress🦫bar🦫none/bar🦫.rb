# frozen_string_literal: true

module ProgressBarNone
  # The main progress bar class
  class Bar
    attr_reader :total, :current, :metrics, :title

    # Initialize a new progress bar
    # @param total [Integer] Total number of items
    # @param title [String, nil] Optional title for the progress bar
    # @param style [Symbol] Visual style (:crystal, :blocks, :dots, :arrows, :ascii, :fire, :nyan, :matrix, etc.)
    # @param palette [Symbol] Color palette (:crystal, :fire, :ocean, :neon, :synthwave, :vaporwave, :acid, etc.)
    # @param width [Integer] Width of the progress bar
    # @param output [IO] Output stream (default: $stderr)
    # @param spinner [Symbol] Spinner style (:braille, :moon, :clock, :earth, :fire, :nyan, etc.)
    # @param rainbow_mode [Boolean] Enable rainbow color cycling animation
    # @param celebration [Symbol] Celebration effect on completion (:confetti, :firework, :party, :success)
    # @param glow [Boolean] Enable neon glow effect on the progress bar edge
    # @param fps [Integer] Frames per second for animation (default: 15)
    def initialize(total:, title: nil, style: :crystal, palette: :crystal, width: 40, output: $stderr,
                   spinner: :braille, rainbow_mode: false, celebration: :confetti, glow: false, fps: 15)
      @total = total
      @current = 0
      @title = title
      @output = output
      @started_at = nil
      @last_render_at = nil
      @render_interval = 1.0 / fps
      @metrics = Metrics.new
      @renderer = Renderer.new(
        style: style,
        width: width,
        palette: palette,
        spinner: spinner,
        rainbow_mode: rainbow_mode,
        celebration_mode: celebration,
        glow: glow
      )
      @lines_rendered = 0
      @mutex = Mutex.new
      @finished = false
      @rate_samples = []
      @last_increment_at = nil
    end

    # Start the progress bar
    def start
      @started_at = Time.now
      @last_render_at = Time.now
      @output.print ANSI::HIDE_CURSOR
      render
      self
    end

    # Increment progress by a given amount
    # @param amount [Integer] Amount to increment by
    # @param metrics [Hash, nil] Optional metrics hash to record
    def increment(amount = 1, metrics: nil)
      @mutex.synchronize do
        @current += amount
        @current = [@current, @total].min

        # Track rate
        now = Time.now
        if @last_increment_at
          interval = now - @last_increment_at
          if interval > 0
            @rate_samples << amount / interval
            @rate_samples.shift if @rate_samples.length > 10
          end
        end
        @last_increment_at = now

        # Record metrics if provided
        @metrics.record(metrics) if metrics
      end

      maybe_render
      self
    end

    # Set progress to a specific value
    # @param value [Integer] The value to set
    # @param metrics [Hash, nil] Optional metrics hash
    def set(value, metrics: nil)
      @mutex.synchronize do
        @current = [[value, 0].max, @total].min
        @metrics.record(metrics) if metrics
      end
      maybe_render
      self
    end

    # Update progress and report metrics
    # @param metrics [Hash] Metrics hash with numeric values
    def report(metrics)
      @metrics.record(metrics)
      maybe_render
      self
    end

    # Mark the progress as finished
    def finish
      @mutex.synchronize do
        @current = @total
        @finished = true
      end
      render(force: true)
      @output.puts
      @output.print ANSI::SHOW_CURSOR
      self
    end

    # Clear the progress bar display
    def clear
      @mutex.synchronize do
        clear_rendered_lines
      end
      @output.print ANSI::SHOW_CURSOR
      self
    end

    # Get current progress as a float (0.0 to 1.0)
    def progress
      return 0.0 if @total.zero?
      @current.to_f / @total
    end

    # Get elapsed time in seconds
    def elapsed
      return 0 unless @started_at
      Time.now - @started_at
    end

    # Get estimated time remaining
    def eta
      return Float::INFINITY if @current.zero?
      return 0 if @current >= @total

      elapsed_time = elapsed
      return Float::INFINITY if elapsed_time.zero?

      rate = @current / elapsed_time
      remaining = @total - @current
      remaining / rate
    end

    # Get current rate (items per second)
    def rate
      return 0.0 if @rate_samples.empty?
      @rate_samples.sum / @rate_samples.length
    end

    # Iterate with progress tracking
    # @param enumerable [Enumerable] The collection to iterate
    # @yield [item] Block to execute for each item
    def self.each(enumerable, **options, &block)
      items = enumerable.to_a
      bar = new(total: items.length, **options)
      bar.start

      begin
        items.each do |item|
          result = yield(item)
          # If block returns a hash with :metrics key, record it
          if result.is_a?(Hash) && result.key?(:metrics)
            bar.increment(metrics: result[:metrics])
          else
            bar.increment
          end
        end
      ensure
        bar.finish
      end
    end

    private

    def maybe_render
      render
    end

    def render(force: false)
      @mutex.synchronize do
        now = Time.now
        return if !force && @last_render_at && (now - @last_render_at) < @render_interval

        clear_rendered_lines

        state = build_state
        lines = @renderer.render(state)

        # Add title if present
        if @title && !@title.empty?
          title_line = "#{ANSI::BOLD}#{ANSI.palette_color(@renderer.palette, 0.5)}#{@title}#{ANSI::RESET}"
          lines.unshift(title_line)
        end

        # Output lines
        lines.each_with_index do |line, i|
          @output.print "#{ANSI::CLEAR_LINE}#{line}"
          @output.print "\n" if i < lines.length - 1
        end

        @lines_rendered = lines.length
        @last_render_at = now
      end
    end

    def clear_rendered_lines
      return if @lines_rendered.zero?

      # Move up and clear each line
      (@lines_rendered - 1).times do
        @output.print ANSI.up(1)
        @output.print ANSI::CLEAR_LINE
      end
      @output.print "\r#{ANSI::CLEAR_LINE}"
    end

    def build_state
      {
        progress: progress,
        current: @current,
        total: @total,
        elapsed: elapsed,
        eta: eta,
        rate: rate,
        metrics: @metrics,
        finished: @finished,
      }
    end
  end
end
