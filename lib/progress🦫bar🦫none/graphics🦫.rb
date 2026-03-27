# frozen_string_literal: true

require "base64"

module ProgressBarNone
  # Kitty Graphics Protocol support for inline images in terminal
  # Works with Ghostty, Kitty, WezTerm, and other compatible terminals
  module Graphics
    # Kitty Graphics Protocol escape sequences
    # Format: <ESC>_G<control data>;<payload><ESC>\
    KITTY_START = "\e_G"
    KITTY_END = "\e\\"

    # iTerm2 protocol (also supported by many terminals)
    ITERM_START = "\e]1337;File="
    ITERM_END = "\a"

    class << self
      # Check if terminal supports Kitty graphics protocol
      def kitty_supported?
        term = ENV["TERM"] || ""
        term_program = ENV["TERM_PROGRAM"] || ""

        # Known supporting terminals
        term.include?("kitty") ||
          term.include?("ghostty") ||
          term_program.downcase.include?("kitty") ||
          term_program.downcase.include?("ghostty") ||
          term_program.downcase.include?("wezterm")
      end

      # Check if terminal supports iTerm2 graphics protocol
      def iterm_supported?
        term_program = ENV["TERM_PROGRAM"] || ""
        lc_terminal = ENV["LC_TERMINAL"] || ""

        term_program.include?("iTerm") ||
          lc_terminal.include?("iTerm") ||
          term_program.downcase.include?("wezterm")
      end

      # Display an image using the best available protocol
      # @param path [String] Path to image file (PNG, GIF, JPEG, etc.)
      # @param width [Integer, nil] Width in cells (nil = auto)
      # @param height [Integer, nil] Height in cells (nil = auto)
      # @param preserve_aspect [Boolean] Preserve aspect ratio
      # @return [String] Escape sequence to display image
      def display_image(path, width: nil, height: nil, preserve_aspect: true)
        return "" unless File.exist?(path)

        if kitty_supported?
          kitty_display_image(path, width: width, height: height)
        elsif iterm_supported?
          iterm_display_image(path, width: width, height: height, preserve_aspect: preserve_aspect)
        else
          # Fallback: return empty or ASCII art placeholder
          ascii_placeholder(width || 10, height || 3)
        end
      end

      # Display image using Kitty graphics protocol
      def kitty_display_image(path, width: nil, height: nil)
        data = File.binread(path)
        encoded = Base64.strict_encode64(data)

        # Build control data
        controls = []
        controls << "a=T"  # Action: transmit and display
        controls << "f=100" # Format: PNG (auto-detect)
        controls << "t=d"  # Transmission: direct
        controls << "c=#{width}" if width
        controls << "r=#{height}" if height

        # Chunk the data (max 4096 bytes per chunk)
        chunks = encoded.scan(/.{1,4096}/)
        result = ""

        chunks.each_with_index do |chunk, i|
          is_last = i == chunks.length - 1
          ctrl = controls.dup
          ctrl << (is_last ? "m=0" : "m=1")

          result += "#{KITTY_START}#{ctrl.join(",")};#{chunk}#{KITTY_END}"
        end

        result
      end

      # Display image using iTerm2 protocol
      def iterm_display_image(path, width: nil, height: nil, preserve_aspect: true)
        data = File.binread(path)
        encoded = Base64.strict_encode64(data)

        # Build arguments
        args = []
        args << "inline=1"
        args << "width=#{width}" if width
        args << "height=#{height}" if height
        args << "preserveAspectRatio=#{preserve_aspect ? 1 : 0}"

        "#{ITERM_START}#{args.join(";")};#{encoded}#{ITERM_END}"
      end

      # ASCII art placeholder when graphics not supported
      def ascii_placeholder(width, height)
        top = "┌" + "─" * width + "┐\n"
        middle = ("│" + " " * width + "│\n") * [height - 2, 1].max
        bottom = "└" + "─" * width + "┘"
        top + middle + bottom
      end

      # Generate inline ASCII art animations
      # These work in ALL terminals!
      def ascii_art(name, frame = 0)
        case name
        when :fire
          fire_art(frame)
        when :nyan
          nyan_art(frame)
        when :rocket
          rocket_art(frame)
        when :celebration
          celebration_art(frame)
        when :skull
          skull_art(frame)
        when :matrix
          matrix_art(frame)
        when :loading
          loading_art(frame)
        else
          ""
        end
      end

      private

      def fire_art(frame)
        # Animated fire ASCII art
        flames = [
          "   (  )   ",
          "  (    )  ",
          " (  ()  ) ",
          "(  (())  )",
          " \\|/||\\|/ ",
          "  \\||||/  ",
          "   \\||/   ",
          "    ||    ",
        ]

        # Animate by shifting colors
        colors = [
          "\e[38;2;255;0;0m",    # Red
          "\e[38;2;255;100;0m",  # Orange
          "\e[38;2;255;200;0m",  # Yellow
          "\e[38;2;255;255;100m", # Light yellow
        ]

        result = ""
        flames.each_with_index do |line, i|
          color_idx = (frame + i) % colors.length
          result += "#{colors[color_idx]}#{line}\e[0m\n"
        end
        result
      end

      def nyan_art(frame)
        # Animated nyan cat
        cat_frames = [
          [
            "   ╭━━━━━━━╮  ",
            "  ╭┃ ▀ ω ▀ ┃╮ ",
            "━━╯┃       ┃╰━",
            "   ╰━━━╮╭━━╯  ",
            "     ╰╯╰╯     ",
          ],
          [
            "   ╭━━━━━━━╮  ",
            "  ╭┃ ▀ ω ▀ ┃╮ ",
            "━━╯┃       ┃╰━",
            "   ╰━━╮━╮━━╯  ",
            "     ╯  ╰     ",
          ],
        ]

        rainbow = "\e[38;2;255;0;0m━\e[38;2;255;127;0m━\e[38;2;255;255;0m━\e[38;2;0;255;0m━\e[38;2;0;0;255m━\e[38;2;139;0;255m━\e[0m"
        cat = cat_frames[frame % 2]

        result = ""
        cat.each { |line| result += "#{rainbow}#{line}\n" }
        result
      end

      def rocket_art(frame)
        rockets = [
          [
            "    /\\    ",
            "   /  \\   ",
            "  |    |  ",
            "  |    |  ",
            " /|    |\\ ",
            "/ |    | \\",
            "  \\    /  ",
            "   \\  /   ",
            "    \\/    ",
            "    ||    ",
            "   /||\\   ",
            "  / || \\  ",
          ],
          [
            "    /\\    ",
            "   /  \\   ",
            "  |    |  ",
            "  |    |  ",
            " /|    |\\ ",
            "/ |    | \\",
            "  \\    /  ",
            "   \\  /   ",
            "    \\/    ",
            "   *||*   ",
            "  */||\\*  ",
            " */ || \\* ",
          ],
        ]

        colors = ["\e[38;2;255;100;0m", "\e[38;2;255;200;0m", "\e[38;2;255;255;255m"]
        rocket = rockets[frame % 2]

        result = ""
        rocket.each_with_index do |line, i|
          color = i < 6 ? "\e[38;2;200;200;200m" : colors[(frame + i) % colors.length]
          result += "#{color}#{line}\e[0m\n"
        end
        result
      end

      def celebration_art(frame)
        # Fireworks/confetti
        patterns = [
          "  * . * . *  ",
          " .  *   *  . ",
          "*  .  *  .  *",
          " . * . * . * ",
          "  *   *   *  ",
        ]

        emojis = ["🎉", "🎊", "✨", "💫", "⭐", "🌟"]

        result = ""
        patterns.each_with_index do |pattern, i|
          colored = pattern.gsub("*") do
            color = ANSI.rainbow_cycle((frame + i) * 0.1, frame * 0.05, 2.0)
            "#{color}#{emojis[(frame + i) % emojis.length]}\e[0m"
          end
          result += colored + "\n"
        end
        result
      end

      def skull_art(frame)
        skull = [
          "     ___     ",
          "    /   \\    ",
          "   | x x |   ",
          "   |  _  |   ",
          "   | \\_/ |   ",
          "    \\___/    ",
        ]

        eye_frames = ["x", "o", "O", "*"]
        eye = eye_frames[frame % eye_frames.length]

        result = ""
        skull.each do |line|
          colored_line = line.gsub("x", eye)
          result += "\e[38;2;255;255;255m#{colored_line}\e[0m\n"
        end
        result
      end

      def matrix_art(frame)
        width = 20
        height = 5
        chars = "ﾊﾐﾋｰｳｼﾅﾓﾆｻﾜﾂｵﾘｱﾎﾃﾏｹﾒｴｶｷﾑﾕﾗｾﾈｽﾀﾇﾍ0123456789".chars

        result = ""
        height.times do |y|
          line = ""
          width.times do |x|
            if rand < 0.3
              brightness = rand(100..255)
              char = chars.sample
              line += "\e[38;2;0;#{brightness};0m#{char}\e[0m"
            else
              line += " "
            end
          end
          result += line + "\n"
        end
        result
      end

      def loading_art(frame)
        frames = [
          "[ ●    ]",
          "[  ●   ]",
          "[   ●  ]",
          "[    ● ]",
          "[   ●  ]",
          "[  ●   ]",
        ]
        "\e[38;2;0;255;255m#{frames[frame % frames.length]}\e[0m"
      end
    end
  end
end
