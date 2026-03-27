# frozen_string_literal: true

module ProgressBarNone
  # Decorative frames and borders for the progress cockpit
  module Frames
    class << self
      # Draw a decorative frame around content
      # @param content [Array<String>] Lines of content
      # @param style [Symbol] Frame style (:single, :double, :rounded, :bold, :ascii, :cyber, :neon)
      # @param palette [Symbol] Color palette for the frame
      # @param title [String, nil] Optional title for the frame
      # @param animated [Boolean] Enable animated frame
      # @param frame_num [Integer] Animation frame number
      # @return [Array<String>] Framed content lines
      def wrap(content, style: :rounded, palette: :crystal, title: nil, animated: false, frame_num: 0)
        lines = content.is_a?(Array) ? content : content.split("\n")
        return lines if lines.empty?

        # Calculate max width
        max_width = lines.map { |l| ANSI.visible_length(l) }.max

        # Get frame characters
        frame = frame_chars(style)

        # Build framed output
        result = []

        # Top border
        top_border = build_top_border(frame, max_width, title, palette, animated, frame_num)
        result << top_border

        # Content lines
        lines.each_with_index do |line, i|
          padding = max_width - ANSI.visible_length(line)
          left = frame_color(frame[:v], palette, i, animated, frame_num)
          right = frame_color(frame[:v], palette, i, animated, frame_num)
          result << "#{left} #{line}#{" " * padding} #{right}"
        end

        # Bottom border
        bottom_border = build_bottom_border(frame, max_width, palette, animated, frame_num)
        result << bottom_border

        result
      end

      # Create a simple horizontal separator
      def separator(width: 40, style: :single, palette: :crystal, animated: false, frame_num: 0)
        frame = frame_chars(style)
        char = frame[:h]

        if animated
          # Animated separator with traveling highlight
          result = ""
          width.times do |i|
            highlight_pos = (frame_num * 2) % width
            if (i - highlight_pos).abs < 3
              intensity = 1.0 - (i - highlight_pos).abs / 3.0
              result += "#{ANSI::BOLD}#{ANSI.palette_color(palette, intensity)}#{char}#{ANSI::RESET}"
            else
              result += "#{ANSI::DIM}#{char}#{ANSI::RESET}"
            end
          end
          result
        else
          color = ANSI.palette_color(palette, 0.5)
          "#{color}#{char * width}#{ANSI::RESET}"
        end
      end

      # Create a decorative header banner
      def banner(text, style: :double, palette: :neon, animated: false, frame_num: 0)
        width = text.length + 4
        frame = frame_chars(style)

        lines = []

        # Top
        top_color = animated ? ANSI.rainbow_cycle(0, frame_num * 0.1, 1.0) : ANSI.palette_color(palette, 0.0)
        lines << "#{top_color}#{frame[:tl]}#{frame[:h] * width}#{frame[:tr]}#{ANSI::RESET}"

        # Middle with text
        mid_color = animated ? ANSI.rainbow_cycle(0.5, frame_num * 0.1, 1.0) : ANSI.palette_color(palette, 0.5)
        text_color = animated ? rainbow_text(text, frame_num) : "#{ANSI::BOLD}#{mid_color}#{text}#{ANSI::RESET}"
        lines << "#{mid_color}#{frame[:v]}#{ANSI::RESET}  #{text_color}  #{mid_color}#{frame[:v]}#{ANSI::RESET}"

        # Bottom
        bot_color = animated ? ANSI.rainbow_cycle(1.0, frame_num * 0.1, 1.0) : ANSI.palette_color(palette, 1.0)
        lines << "#{bot_color}#{frame[:bl]}#{frame[:h] * width}#{frame[:br]}#{ANSI::RESET}"

        lines
      end

      # ASCII art title banners
      def ascii_title(text, style: :block, palette: :neon)
        case style
        when :block
          block_title(text, palette)
        when :shadow
          shadow_title(text, palette)
        when :outline
          outline_title(text, palette)
        else
          simple_title(text, palette)
        end
      end

      private

      def frame_chars(style)
        case style
        when :single
          { tl: "┌", tr: "┐", bl: "└", br: "┘", h: "─", v: "│" }
        when :double
          { tl: "╔", tr: "╗", bl: "╚", br: "╝", h: "═", v: "║" }
        when :rounded
          { tl: "╭", tr: "╮", bl: "╰", br: "╯", h: "─", v: "│" }
        when :bold
          { tl: "┏", tr: "┓", bl: "┗", br: "┛", h: "━", v: "┃" }
        when :ascii
          { tl: "+", tr: "+", bl: "+", br: "+", h: "-", v: "|" }
        when :cyber
          { tl: "⟦", tr: "⟧", bl: "⟦", br: "⟧", h: "═", v: "▐" }
        when :neon
          { tl: "◤", tr: "◥", bl: "◣", br: "◢", h: "━", v: "┃" }
        when :stars
          { tl: "✦", tr: "✦", bl: "✦", br: "✦", h: "✧", v: "✧" }
        else
          { tl: "╭", tr: "╮", bl: "╰", br: "╯", h: "─", v: "│" }
        end
      end

      def build_top_border(frame, width, title, palette, animated, frame_num)
        h_char = frame[:h]
        total_width = width + 2  # +2 for padding

        if title && !title.empty?
          title_display = " #{title} "
          title_len = ANSI.visible_length(title_display)
          left_width = 2
          right_width = total_width - left_width - title_len

          left = frame_color(frame[:tl], palette, 0, animated, frame_num)
          right = frame_color(frame[:tr], palette, 0, animated, frame_num)
          left_h = frame_color(h_char * left_width, palette, 0, animated, frame_num)
          right_h = frame_color(h_char * [right_width, 0].max, palette, 0, animated, frame_num)

          title_color = animated ? rainbow_text(title_display, frame_num) :
                                  "#{ANSI::BOLD}#{ANSI.palette_color(palette, 0.5)}#{title_display}#{ANSI::RESET}"

          "#{left}#{left_h}#{title_color}#{right_h}#{right}"
        else
          left = frame_color(frame[:tl], palette, 0, animated, frame_num)
          right = frame_color(frame[:tr], palette, 0, animated, frame_num)
          middle = frame_color(h_char * total_width, palette, 0, animated, frame_num)

          "#{left}#{middle}#{right}"
        end
      end

      def build_bottom_border(frame, width, palette, animated, frame_num)
        h_char = frame[:h]
        total_width = width + 2

        left = frame_color(frame[:bl], palette, 1, animated, frame_num)
        right = frame_color(frame[:br], palette, 1, animated, frame_num)
        middle = frame_color(h_char * total_width, palette, 1, animated, frame_num)

        "#{left}#{middle}#{right}"
      end

      def frame_color(char, palette, position, animated, frame_num)
        if animated
          color = ANSI.rainbow_cycle(position * 0.5, frame_num * 0.1, 1.0)
          "#{color}#{char}#{ANSI::RESET}"
        else
          color = ANSI.palette_color(palette, position)
          "#{color}#{char}#{ANSI::RESET}"
        end
      end

      def rainbow_text(text, frame_num)
        result = ""
        text.each_char.with_index do |char, i|
          color = ANSI.rainbow_cycle(i * 0.1, frame_num * 0.1, 1.0)
          result += "#{color}#{char}"
        end
        result + ANSI::RESET
      end

      def block_title(text, palette)
        # Simple block-style title
        color = ANSI.palette_color(palette, 0.5)
        [
          "#{color}#{ANSI::BOLD}█▀▀ #{text.upcase} ▀▀█#{ANSI::RESET}",
        ]
      end

      def shadow_title(text, palette)
        color = ANSI.palette_color(palette, 0.5)
        shadow = ANSI::DIM
        [
          "#{color}#{ANSI::BOLD}#{text}#{ANSI::RESET}",
          "#{shadow}#{text.gsub(/[^ ]/, "░")}#{ANSI::RESET}",
        ]
      end

      def outline_title(text, palette)
        color = ANSI.palette_color(palette, 0.5)
        border = "═" * (text.length + 2)
        [
          "#{color}╔#{border}╗#{ANSI::RESET}",
          "#{color}║ #{ANSI::BOLD}#{text}#{ANSI::RESET}#{color} ║#{ANSI::RESET}",
          "#{color}╚#{border}╝#{ANSI::RESET}",
        ]
      end

      def simple_title(text, palette)
        color = ANSI.palette_color(palette, 0.5)
        ["#{color}#{ANSI::BOLD}▸ #{text}#{ANSI::RESET}"]
      end
    end
  end
end
