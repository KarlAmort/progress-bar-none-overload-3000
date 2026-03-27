# frozen_string_literal: true

module ProgressBarNone
  # Sparkline visualization for metrics
  module Sparkline
    # Unicode block characters for vertical bars (8 levels)
    BLOCKS = [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"].freeze

    # Braille patterns for high-resolution sparklines
    BRAILLE_BASE = 0x2800

    class << self
      # Generate a sparkline from an array of values
      # @param values [Array<Numeric>] The values to visualize
      # @param width [Integer] Maximum width of the sparkline
      # @param min [Numeric, nil] Minimum value (auto-detect if nil)
      # @param max [Numeric, nil] Maximum value (auto-detect if nil)
      # @param style [Symbol] :blocks or :braille
      # @return [String] The sparkline string
      def generate(values, width: 20, min: nil, max: nil, style: :blocks)
        return "" if values.empty?

        # Sample values if we have more than width
        sampled = sample_values(values, width)
        return "" if sampled.empty?

        min ||= sampled.min
        max ||= sampled.max
        range = max - min

        case style
        when :braille
          generate_braille(sampled, min, range)
        else
          generate_blocks(sampled, min, range)
        end
      end

      # Generate with color gradient
      def generate_colored(values, width: 20, palette: :crystal, min: nil, max: nil)
        return "" if values.empty?

        sampled = sample_values(values, width)
        return "" if sampled.empty?

        min ||= sampled.min
        max ||= sampled.max
        range = [max - min, 0.001].max

        sampled.each_with_index.map do |val, i|
          normalized = range.zero? ? 0.5 : (val - min) / range
          block_index = (normalized * (BLOCKS.length - 1)).round
          block = BLOCKS[block_index]

          # Color based on position in the sparkline
          progress = i.to_f / [sampled.length - 1, 1].max
          color = ANSI.palette_color(palette, progress)

          "#{color}#{block}#{ANSI::RESET}"
        end.join
      end

      # Mini histogram
      def histogram(values, width: 10, height: 3, palette: :crystal)
        return "" if values.empty?

        # Create buckets
        min = values.min
        max = values.max
        range = [max - min, 0.001].max

        buckets = Array.new(width, 0)
        values.each do |v|
          bucket = ((v - min) / range * (width - 1)).floor
          bucket = [[bucket, 0].max, width - 1].min
          buckets[bucket] += 1
        end

        max_count = buckets.max
        return " " * width if max_count.zero?

        # Generate rows from top to bottom
        rows = (0...height).map do |row|
          threshold = (height - row) / height.to_f * max_count
          buckets.each_with_index.map do |count, i|
            progress = i.to_f / [width - 1, 1].max
            color = ANSI.palette_color(palette, progress)
            char = count >= threshold ? "█" : " "
            "#{color}#{char}#{ANSI::RESET}"
          end.join
        end

        rows.join("\n")
      end

      private

      def sample_values(values, width)
        return values if values.length <= width

        # Downsample by taking averages
        chunk_size = (values.length / width.to_f).ceil
        values.each_slice(chunk_size).map do |chunk|
          chunk.sum / chunk.length.to_f
        end.first(width)
      end

      def generate_blocks(values, min, range)
        values.map do |val|
          normalized = range.zero? ? 0.5 : (val - min) / range
          index = (normalized * (BLOCKS.length - 1)).round
          BLOCKS[index]
        end.join
      end

      def generate_braille(values, min, range)
        # Braille uses 2x4 dot patterns per character
        # Group values in pairs
        values.each_slice(2).map do |pair|
          val1 = pair[0]
          val2 = pair[1] || val1

          n1 = range.zero? ? 0.5 : (val1 - min) / range
          n2 = range.zero? ? 0.5 : (val2 - min) / range

          # Map to 4 vertical dots
          dots1 = (n1 * 4).round
          dots2 = (n2 * 4).round

          braille_char(dots1, dots2)
        end.join
      end

      def braille_char(left_dots, right_dots)
        # Braille dot positions:
        # 1 4
        # 2 5
        # 3 6
        # 7 8
        pattern = 0

        # Left column (dots 1,2,3,7)
        pattern |= 0x01 if left_dots >= 1
        pattern |= 0x02 if left_dots >= 2
        pattern |= 0x04 if left_dots >= 3
        pattern |= 0x40 if left_dots >= 4

        # Right column (dots 4,5,6,8)
        pattern |= 0x08 if right_dots >= 1
        pattern |= 0x10 if right_dots >= 2
        pattern |= 0x20 if right_dots >= 3
        pattern |= 0x80 if right_dots >= 4

        (BRAILLE_BASE + pattern).chr(Encoding::UTF_8)
      end
    end
  end
end
