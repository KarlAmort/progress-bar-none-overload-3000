# frozen_string_literal: true

module ProgressBarNone
  # A wrapper that provides progress tracking for any enumerable
  class ProgressEnumerator
    include Enumerable

    def initialize(enumerable, bar_options = {})
      @enumerable = enumerable
      @bar_options = bar_options
      @items = nil
    end

    def each(&block)
      return to_enum(:each) unless block_given?

      # Materialize the enumerable to get count
      @items ||= @enumerable.to_a
      total = @items.length

      return if total.zero?

      bar = Bar.new(total: total, **@bar_options)
      bar.start

      begin
        @items.each do |item|
          # Yield to the block
          result = yield(item)

          # Check if result includes metrics
          if result.is_a?(Hash)
            # If it has a :metrics key, use that
            if result.key?(:metrics)
              bar.increment(metrics: result[:metrics])
            else
              # Treat the whole hash as metrics
              bar.increment(metrics: result)
            end
          else
            bar.increment
          end
        end
      ensure
        bar.finish
      end
    end

    # Forward common Enumerable methods
    def size
      @items ||= @enumerable.to_a
      @items.size
    end

    def length
      size
    end
  end
end

# Extend Enumerable with progress bar support
module Enumerable
  # Iterate with a spectacular progress bar
  #
  # @param title [String, nil] Optional title for the progress bar
  # @param style [Symbol] Visual style (:crystal, :blocks, :dots, :arrows, :ascii, :fire, :nyan, :matrix, etc.)
  # @param palette [Symbol] Color palette (:crystal, :fire, :ocean, :neon, :synthwave, :vaporwave, :acid, etc.)
  # @param width [Integer] Width of the progress bar (default: 40)
  # @param output [IO] Output stream (default: $stderr)
  # @param spinner [Symbol] Spinner style (:braille, :moon, :clock, :earth, :fire, :nyan, etc.)
  # @param rainbow_mode [Boolean] Enable rainbow color cycling animation
  # @param celebration [Symbol] Celebration effect on completion (:confetti, :firework, :party, :success)
  # @param glow [Boolean] Enable neon glow effect
  # @param fps [Integer] Frames per second for animation (default: 15)
  # @return [ProgressEnumerator] A progress-tracking enumerator
  #
  # @example Basic usage
  #   (1..100).with_progress.each { |i| sleep(0.01) }
  #
  # @example MAXIMUM PIZZAZZ mode
  #   items.with_progress(
  #     title: "🔥 TURBO MODE 🔥",
  #     style: :fire,
  #     palette: :neon,
  #     rainbow_mode: true,
  #     spinner: :rocket,
  #     celebration: :firework,
  #     glow: true
  #   ).each { |item| process(item) }
  #
  # @example Reporting metrics
  #   files.with_progress(title: "Analyzing").each do |file|
  #     size = File.size(file)
  #     lines = File.readlines(file).count
  #     { bytes: size, lines: lines }  # Return metrics hash
  #   end
  #
  def with_progress(title: nil, style: :crystal, palette: :crystal, width: 40, output: $stderr,
                    spinner: :braille, rainbow_mode: false, celebration: :confetti, glow: false, fps: 15)
    ProgressBarNone::ProgressEnumerator.new(
      self,
      title: title,
      style: style,
      palette: palette,
      width: width,
      output: output,
      spinner: spinner,
      rainbow_mode: rainbow_mode,
      celebration: celebration,
      glow: glow,
      fps: fps
    )
  end
end

