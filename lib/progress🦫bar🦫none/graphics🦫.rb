# frozen_string_literal: true

require "base64"

module ProgressBarNone
  # Kitty Graphics Protocol support for inline images in terminal
  # Works with Ghostty, Kitty, WezTerm, and other compatible terminals
  module Graphics
    # Kitty Graphics Protocol APC escape sequences
    # Format: ESC _ G <control-data> ; <payload> ESC \
    KITTY_START = "\e_G"
    KITTY_END   = "\e\\"

    # iTerm2 inline image protocol
    ITERM_START = "\e]1337;File="
    ITERM_END   = "\a"

    # Max bytes per Kitty chunk (base64-encoded)
    KITTY_CHUNK_SIZE = 4096

    class << self
      # Check if terminal supports Kitty graphics protocol.
      # Ghostty sets TERM=xterm-ghostty and GHOSTTY_RESOURCES_DIR.
      def kitty_supported?
        term         = ENV.fetch("TERM", "")
        term_program = ENV.fetch("TERM_PROGRAM", "")

        term.include?("kitty")    ||
          term.include?("ghostty") ||
          term_program.downcase.include?("kitty")    ||
          term_program.downcase.include?("ghostty")  ||
          term_program.downcase.include?("wezterm")  ||
          ENV.key?("GHOSTTY_RESOURCES_DIR")
      end

      # Check if terminal supports iTerm2 inline image protocol
      def iterm_supported?
        term_program = ENV.fetch("TERM_PROGRAM", "")
        lc_terminal  = ENV.fetch("LC_TERMINAL", "")

        term_program.include?("iTerm")               ||
          lc_terminal.include?("iTerm")              ||
          term_program.downcase.include?("wezterm")
      end

      # Display an image file using the best available protocol.
      # @param path [String]          Path to image file (PNG, JPEG, GIF, …)
      # @param cols [Integer, nil]    Width in terminal columns (nil = auto)
      # @param rows [Integer, nil]    Height in terminal rows (nil = auto)
      # @param image_id [Integer, nil] Kitty image ID for later deletion
      # @return [String]              Escape sequence, ready to print
      def display_image(path, cols: nil, rows: nil, image_id: nil, preserve_aspect: true)
        return "" unless File.exist?(path)

        if kitty_supported?
          kitty_display_image(path, cols: cols, rows: rows, image_id: image_id)
        elsif iterm_supported?
          iterm_display_image(path, cols: cols, rows: rows, preserve_aspect: preserve_aspect)
        else
          ascii_placeholder(cols || 20, rows || 4)
        end
      end

      # Transmit and display a PNG/JPEG/GIF from a file path via the Kitty
      # Graphics Protocol (f=100 = PNG/auto-detect).
      def kitty_display_image(path, cols: nil, rows: nil, image_id: nil)
        data = File.binread(path)
        kitty_encode(data, format: 100, cols: cols, rows: rows, image_id: image_id)
      end

      # Transmit and display raw RGBA pixel data via the Kitty Graphics Protocol.
      # @param rgba_data    [String]  Binary string of R,G,B,A bytes
      # @param pixel_width  [Integer] Image width in pixels
      # @param pixel_height [Integer] Image height in pixels
      # @param cols  [Integer, nil]   Display width in terminal columns
      # @param rows  [Integer, nil]   Display height in terminal rows
      # @param image_id [Integer, nil] Optional ID for later deletion
      def kitty_display_pixels(rgba_data, pixel_width:, pixel_height:,
                                cols: nil, rows: nil, image_id: nil)
        kitty_encode(rgba_data, format: 32,
                     pixel_width: pixel_width, pixel_height: pixel_height,
                     cols: cols, rows: rows, image_id: image_id)
      end

      # Render a gradient progress bar as inline pixels via Kitty protocol.
      # @param progress   [Float]   0.0..1.0
      # @param width_px   [Integer] Bar width in pixels
      # @param height_px  [Integer] Bar height in pixels
      # @param palette    [Symbol]  CRYSTAL_PALETTE key
      # @param cols       [Integer, nil] Terminal column width override
      # @param rows       [Integer, nil] Terminal row height override
      # @param image_id   [Integer, nil]
      def kitty_progress_bar(progress, width_px: 400, height_px: 20,
                              palette: :crystal, cols: nil, rows: nil, image_id: nil)
        progress = progress.clamp(0.0, 1.0)
        filled_px = (progress * width_px).round

        pal = ANSI::CRYSTAL_PALETTE[palette] || ANSI::CRYSTAL_PALETTE[:crystal]

        # Build raw RGBA pixel data row-by-row
        pixels = "".b
        height_px.times do
          width_px.times do |x|
            if x < filled_px
              pos = filled_px > 1 ? x.to_f / (filled_px - 1) : 0.0
              r, g, b = interpolate_palette(pal, pos)
              pixels << [r, g, b, 255].pack("C4")
            else
              # Unfilled: very dark
              pixels << [15, 15, 25, 255].pack("C4")
            end
          end
        end

        kitty_display_pixels(pixels, pixel_width: width_px, pixel_height: height_px,
                              cols: cols, rows: rows, image_id: image_id)
      end

      # Delete a previously displayed Kitty image by ID.
      # @param image_id [Integer]
      # @param what [String] Kitty delete action ('i' = by ID, 'A' = all)
      def kitty_delete_image(image_id, what: "i")
        "#{KITTY_START}a=d,d=#{what},i=#{image_id};#{KITTY_END}"
      end

      # Display image using iTerm2 inline image protocol
      def iterm_display_image(path, cols: nil, rows: nil, preserve_aspect: true)
        data    = File.binread(path)
        encoded = Base64.strict_encode64(data)

        args = ["inline=1", "size=#{data.bytesize}",
                "preserveAspectRatio=#{preserve_aspect ? 1 : 0}"]
        args << "width=#{cols}"   if cols
        args << "height=#{rows}"  if rows

        "#{ITERM_START}#{args.join(";")}:#{encoded}#{ITERM_END}"
      end

      # ASCII box placeholder when no graphics protocol is available
      def ascii_placeholder(cols, rows)
        inner_w = [cols - 2, 1].max
        top     = "┌" + "─" * inner_w + "┐\n"
        middle  = ("│" + " " * inner_w + "│\n") * [rows - 2, 1].max
        bottom  = "└" + "─" * inner_w + "┘"
        top + middle + bottom
      end

      # Inline ASCII art animations — work in every terminal
      def ascii_art(name, frame = 0)
        case name
        when :fire        then fire_art(frame)
        when :nyan        then nyan_art(frame)
        when :rocket      then rocket_art(frame)
        when :celebration then celebration_art(frame)
        when :skull       then skull_art(frame)
        when :matrix      then matrix_art(frame)
        when :loading     then loading_art(frame)
        else ""
        end
      end

      private

      # Core Kitty encoder.  Produces correctly chunked APC sequences:
      #   - first chunk carries all control keys
      #   - subsequent chunks carry only m= (per the protocol spec)
      # q=1: suppress OK responses, still surface errors.
      def kitty_encode(data, format:, cols: nil, rows: nil,
                        pixel_width: nil, pixel_height: nil, image_id: nil)
        encoded = Base64.strict_encode64(data)
        chunks  = encoded.scan(/.{1,#{KITTY_CHUNK_SIZE}}/)

        result = "".b

        chunks.each_with_index do |chunk, i|
          is_last = (i == chunks.length - 1)

          ctrl = if i == 0
                   # First chunk: full control data
                   parts = ["a=T", "f=#{format}", "t=d", "q=1"]
                   parts << "s=#{pixel_width}"  if pixel_width
                   parts << "v=#{pixel_height}" if pixel_height
                   parts << "c=#{cols}"         if cols
                   parts << "r=#{rows}"         if rows
                   parts << "i=#{image_id}"     if image_id
                   parts << "m=#{is_last ? 0 : 1}"
                   parts.join(",")
                 else
                   # Subsequent chunks: only m= (and i= if needed for reassembly)
                   parts = []
                   parts << "i=#{image_id}" if image_id
                   parts << "m=#{is_last ? 0 : 1}"
                   parts.join(",")
                 end

          result << "#{KITTY_START}#{ctrl};#{chunk}#{KITTY_END}"
        end

        result.force_encoding(Encoding::BINARY)
      end

      # Linearly interpolate a palette array at position 0.0..1.0
      def interpolate_palette(pal, pos)
        return pal.first if pos <= 0.0
        return pal.last  if pos >= 1.0

        scaled = pos * (pal.length - 1)
        idx    = scaled.floor
        frac   = scaled - idx
        c1     = pal[idx]
        c2     = pal[[idx + 1, pal.length - 1].min]

        [
          (c1[0] + (c2[0] - c1[0]) * frac).round,
          (c1[1] + (c2[1] - c1[1]) * frac).round,
          (c1[2] + (c2[2] - c1[2]) * frac).round,
        ]
      end

      def fire_art(frame)
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
        colors = [
          "\e[38;2;255;0;0m",
          "\e[38;2;255;100;0m",
          "\e[38;2;255;200;0m",
          "\e[38;2;255;255;100m",
        ]
        result = ""
        flames.each_with_index do |line, i|
          result += "#{colors[(frame + i) % colors.length]}#{line}\e[0m\n"
        end
        result
      end

      def nyan_art(frame)
        cat_frames = [
          ["   ╭━━━━━━━╮  ", "  ╭┃ ▀ ω ▀ ┃╮ ", "━━╯┃       ┃╰━",
           "   ╰━━━╮╭━━╯  ", "     ╰╯╰╯     "],
          ["   ╭━━━━━━━╮  ", "  ╭┃ ▀ ω ▀ ┃╮ ", "━━╯┃       ┃╰━",
           "   ╰━━╮━╮━━╯  ", "     ╯  ╰     "],
        ]
        rainbow = "\e[38;2;255;0;0m━\e[38;2;255;127;0m━\e[38;2;255;255;0m━" \
                  "\e[38;2;0;255;0m━\e[38;2;0;0;255m━\e[38;2;139;0;255m━\e[0m"
        result = ""
        cat_frames[frame % 2].each { |line| result += "#{rainbow}#{line}\n" }
        result
      end

      def rocket_art(frame)
        body = ["    /\\    ", "   /  \\   ", "  |    |  ", "  |    |  ",
                " /|    |\\ ", "/ |    | \\"]
        exhaust = [["  \\    /  ", "   \\  /   ", "    \\/    ", "    ||    ",
                    "   /||\\   ", "  / || \\  "],
                   ["  \\    /  ", "   \\  /   ", "    \\/    ", "   *||*   ",
                    "  */||\\*  ", " */ || \\* "]]
        colors = ["\e[38;2;255;100;0m", "\e[38;2;255;200;0m", "\e[38;2;255;255;255m"]
        result = ""
        body.each { |l| result += "\e[38;2;200;200;200m#{l}\e[0m\n" }
        exhaust[frame % 2].each_with_index do |l, i|
          result += "#{colors[(frame + i) % colors.length]}#{l}\e[0m\n"
        end
        result
      end

      def celebration_art(frame)
        patterns = ["  * . * . *  ", " .  *   *  . ", "*  .  *  .  *",
                    " . * . * . * ", "  *   *   *  "]
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
        skull = ["     ___     ", "    /   \\    ", "   | x x |   ",
                 "   |  _  |   ", "   | \\_/ |   ", "    \\___/    "]
        eye = ["x", "o", "O", "*"][frame % 4]
        result = ""
        skull.each { |l| result += "\e[38;2;255;255;255m#{l.gsub("x", eye)}\e[0m\n" }
        result
      end

      def matrix_art(frame) # rubocop:disable Lint/UnusedMethodArgument
        chars = "ﾊﾐﾋｰｳｼﾅﾓﾆｻﾜﾂｵﾘｱﾎﾃﾏｹﾒｴｶｷﾑﾕﾗｾﾈｽﾀﾇﾍ0123456789".chars
        result = ""
        5.times do
          line = ""
          20.times do
            if rand < 0.3
              brightness = rand(100..255)
              line += "\e[38;2;0;#{brightness};0m#{chars.sample}\e[0m"
            else
              line += " "
            end
          end
          result += line + "\n"
        end
        result
      end

      def loading_art(frame)
        frames = ["[ ●    ]", "[  ●   ]", "[   ●  ]", "[    ● ]",
                  "[   ●  ]", "[  ●   ]"]
        "\e[38;2;0;255;255m#{frames[frame % frames.length]}\e[0m"
      end
    end
  end
end
