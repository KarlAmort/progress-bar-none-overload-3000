# frozen_string_literal: true

module ProgressBarNone
  # ANSI escape codes for colors, cursor control, and styling
  module ANSI
    # Escape sequence prefix
    ESC = "\e["

    # Cursor control
    HIDE_CURSOR = "#{ESC}?25l"
    SHOW_CURSOR = "#{ESC}?25h"
    SAVE_CURSOR = "\e7"
    RESTORE_CURSOR = "\e8"
    CLEAR_LINE = "#{ESC}2K"
    CLEAR_TO_END = "#{ESC}0K"

    # Text styles
    RESET = "#{ESC}0m"
    BOLD = "#{ESC}1m"
    DIM = "#{ESC}2m"
    ITALIC = "#{ESC}3m"
    UNDERLINE = "#{ESC}4m"
    BLINK = "#{ESC}5m"
    REVERSE = "#{ESC}7m"

    # Standard colors (foreground)
    BLACK = "#{ESC}30m"
    RED = "#{ESC}31m"
    GREEN = "#{ESC}32m"
    YELLOW = "#{ESC}33m"
    BLUE = "#{ESC}34m"
    MAGENTA = "#{ESC}35m"
    CYAN = "#{ESC}36m"
    WHITE = "#{ESC}37m"

    # Bright colors
    BRIGHT_BLACK = "#{ESC}90m"
    BRIGHT_RED = "#{ESC}91m"
    BRIGHT_GREEN = "#{ESC}92m"
    BRIGHT_YELLOW = "#{ESC}93m"
    BRIGHT_BLUE = "#{ESC}94m"
    BRIGHT_MAGENTA = "#{ESC}95m"
    BRIGHT_CYAN = "#{ESC}96m"
    BRIGHT_WHITE = "#{ESC}97m"

    # Background colors
    BG_BLACK = "#{ESC}40m"
    BG_RED = "#{ESC}41m"
    BG_GREEN = "#{ESC}42m"
    BG_YELLOW = "#{ESC}43m"
    BG_BLUE = "#{ESC}44m"
    BG_MAGENTA = "#{ESC}45m"
    BG_CYAN = "#{ESC}46m"
    BG_WHITE = "#{ESC}47m"

    # Crystal color palette - beautiful gradients (moved to module level)
    CRYSTAL_PALETTE = {
        # Cyan to purple crystal gradient
        crystal: [
          [80, 220, 255],   # Bright cyan
          [100, 200, 255],  # Light blue
          [130, 180, 255],  # Sky blue
          [160, 160, 255],  # Periwinkle
          [190, 140, 255],  # Light purple
          [220, 120, 255],  # Bright purple
          [255, 100, 220],  # Pink
        ],
        # Fire gradient
        fire: [
          [255, 80, 0],     # Orange
          [255, 120, 0],    # Light orange
          [255, 160, 0],    # Yellow-orange
          [255, 200, 0],    # Yellow
          [255, 220, 100],  # Light yellow
        ],
        # Ocean gradient
        ocean: [
          [0, 80, 120],     # Deep blue
          [0, 120, 160],    # Ocean blue
          [0, 160, 200],    # Bright blue
          [0, 200, 220],    # Turquoise
          [100, 220, 220],  # Aqua
        ],
        # Forest gradient
        forest: [
          [0, 80, 40],      # Deep green
          [0, 120, 60],     # Forest
          [40, 160, 80],    # Green
          [80, 200, 100],   # Bright green
          [160, 220, 120],  # Light green
        ],
        # Sunset gradient
        sunset: [
          [100, 0, 120],    # Deep purple
          [160, 0, 100],    # Purple
          [200, 40, 80],    # Magenta
          [255, 80, 60],    # Red-orange
          [255, 140, 40],   # Orange
          [255, 200, 80],   # Yellow
        ],
        # Rainbow
        rainbow: [
          [255, 0, 0],      # Red
          [255, 127, 0],    # Orange
          [255, 255, 0],    # Yellow
          [0, 255, 0],      # Green
          [0, 0, 255],      # Blue
          [75, 0, 130],     # Indigo
          [148, 0, 211],    # Violet
        ],
        # Monochrome
        mono: [
          [60, 60, 60],
          [100, 100, 100],
          [140, 140, 140],
          [180, 180, 180],
          [220, 220, 220],
        ],
        # Extended palettes
        # Neon cyberpunk
        neon: [
          [255, 0, 102],   # Hot pink
          [255, 0, 255],   # Magenta
          [0, 255, 255],   # Cyan
          [0, 255, 128],   # Neon green
          [255, 255, 0],   # Electric yellow
          [255, 0, 102],   # Back to hot pink (loop)
        ],
        # Synthwave/Outrun
        synthwave: [
          [15, 5, 40],     # Deep purple night
          [139, 0, 139],   # Dark magenta
          [255, 0, 100],   # Hot pink
          [255, 110, 199], # Pink
          [0, 255, 255],   # Cyan glow
          [255, 255, 100], # Pale yellow sun
        ],
        # Vaporwave aesthetic
        vaporwave: [
          [255, 113, 206], # Pink
          [185, 103, 255], # Purple
          [1, 205, 254],   # Cyan
          [5, 255, 161],   # Teal
          [255, 251, 150], # Yellow
          [255, 113, 206], # Back to pink
        ],
        # Acid/Psychedelic
        acid: [
          [0, 255, 0],     # Nuclear green
          [255, 255, 0],   # Bright yellow
          [255, 0, 255],   # Magenta
          [0, 255, 255],   # Cyan
          [255, 128, 0],   # Orange
          [128, 255, 0],   # Lime
        ],
        # Plasma/Electric
        plasma: [
          [128, 0, 255],   # Electric purple
          [255, 0, 128],   # Electric pink
          [255, 0, 255],   # Magenta
          [0, 128, 255],   # Electric blue
          [0, 255, 255],   # Cyan
          [128, 0, 255],   # Back to purple
        ],
        # Matrix green
        matrix: [
          [0, 40, 0],      # Dark green
          [0, 80, 0],      # Forest green
          [0, 140, 0],     # Green
          [0, 200, 0],     # Bright green
          [0, 255, 0],     # Neon green
          [180, 255, 180], # White-green glow
        ],
        # Lava/Magma
        lava: [
          [80, 0, 0],      # Dark red
          [180, 0, 0],     # Red
          [255, 60, 0],    # Red-orange
          [255, 120, 0],   # Orange
          [255, 200, 0],   # Yellow-orange
          [255, 255, 100], # Hot yellow
        ],
        # Ice/Frozen
        ice: [
          [200, 240, 255], # Pale blue
          [150, 220, 255], # Light blue
          [100, 200, 255], # Sky blue
          [50, 180, 255],  # Blue
          [0, 160, 255],   # Deep blue
          [255, 255, 255], # White sparkle
        ],
        # Galaxy/Cosmic
        galaxy: [
          [10, 0, 30],     # Deep space
          [60, 0, 100],    # Purple nebula
          [150, 50, 200],  # Violet
          [200, 100, 255], # Light purple
          [255, 200, 255], # Pink star
          [255, 255, 255], # White star
        ],
        # Toxic/Radioactive
        toxic: [
          [0, 0, 0],       # Black
          [0, 80, 0],      # Dark green
          [0, 180, 0],     # Green
          [180, 255, 0],   # Yellow-green
          [255, 255, 0],   # Warning yellow
          [0, 255, 0],     # Neon green glow
        ],
        # Hacker/Terminal
        hacker: [
          [0, 20, 0],      # Almost black
          [0, 60, 0],      # Very dark green
          [0, 100, 0],     # Dark green
          [0, 150, 10],    # Green
          [20, 200, 20],   # Bright green
          [100, 255, 100], # Glow green
        ],
    }.freeze

    class << self
      # Move cursor up n lines
      def up(n = 1)
        "#{ESC}#{n}A"
      end

      # Move cursor down n lines
      def down(n = 1)
        "#{ESC}#{n}B"
      end

      # Move cursor forward n columns
      def forward(n = 1)
        "#{ESC}#{n}C"
      end

      # Move cursor backward n columns
      def backward(n = 1)
        "#{ESC}#{n}D"
      end

      # Move cursor to column n
      def column(n)
        "#{ESC}#{n}G"
      end

      # Move cursor to specific position
      def position(row, col)
        "#{ESC}#{row};#{col}H"
      end

      # 256-color foreground
      def fg256(color)
        "#{ESC}38;5;#{color}m"
      end

      # 256-color background
      def bg256(color)
        "#{ESC}48;5;#{color}m"
      end

      # True color (24-bit) foreground
      def rgb(r, g, b)
        "#{ESC}38;2;#{r};#{g};#{b}m"
      end

      # True color (24-bit) background
      def bg_rgb(r, g, b)
        "#{ESC}48;2;#{r};#{g};#{b}m"
      end

      # Get color from palette based on progress (0.0 to 1.0)
      def palette_color(palette_name, progress)
        palette = CRYSTAL_PALETTE[palette_name] || CRYSTAL_PALETTE[:crystal]
        return rgb(*palette.first) if progress <= 0
        return rgb(*palette.last) if progress >= 1

        # Interpolate between colors
        scaled = progress * (palette.length - 1)
        index = scaled.floor
        fraction = scaled - index

        c1 = palette[index]
        c2 = palette[[index + 1, palette.length - 1].min]

        r = (c1[0] + (c2[0] - c1[0]) * fraction).round
        g = (c1[1] + (c2[1] - c1[1]) * fraction).round
        b = (c1[2] + (c2[2] - c1[2]) * fraction).round

        rgb(r, g, b)
      end

      # Create a shimmer effect (slight brightness variation)
      def shimmer(r, g, b, phase)
        shimmer_amount = (Math.sin(phase) * 30).round
        r = [[r + shimmer_amount, 0].max, 255].min
        g = [[g + shimmer_amount, 0].max, 255].min
        b = [[b + shimmer_amount, 0].max, 255].min
        rgb(r, g, b)
      end

      # Rainbow color from hue (0.0 to 1.0)
      def hue_to_rgb(hue, saturation = 1.0, lightness = 0.5)
        hue = hue % 1.0
        c = (1 - (2 * lightness - 1).abs) * saturation
        x = c * (1 - ((hue * 6) % 2 - 1).abs)
        m = lightness - c / 2

        r, g, b = case (hue * 6).floor
                  when 0 then [c, x, 0]
                  when 1 then [x, c, 0]
                  when 2 then [0, c, x]
                  when 3 then [0, x, c]
                  when 4 then [x, 0, c]
                  else        [c, 0, x]
                  end

        rgb(((r + m) * 255).round, ((g + m) * 255).round, ((b + m) * 255).round)
      end

      # Animated rainbow color based on position and time
      def rainbow_cycle(position, time, speed = 1.0)
        hue = (position + time * speed) % 1.0
        hue_to_rgb(hue, 1.0, 0.5)
      end

      # Neon glow effect - returns [bg_color, fg_color] for glow effect
      def neon_glow(r, g, b, intensity = 1.0)
        # Dim background glow
        glow_r = (r * 0.3 * intensity).round
        glow_g = (g * 0.3 * intensity).round
        glow_b = (b * 0.3 * intensity).round
        # Bright foreground
        fg = rgb([[r + 50, 255].min, 0].max, [[g + 50, 255].min, 0].max, [[b + 50, 255].min, 0].max)
        bg = bg_rgb(glow_r, glow_g, glow_b)
        [bg, fg]
      end

      # Pulsing brightness effect
      def pulse(r, g, b, time, min_brightness = 0.5, max_brightness = 1.0)
        brightness = min_brightness + (max_brightness - min_brightness) * (0.5 + 0.5 * Math.sin(time * Math::PI * 2))
        rgb((r * brightness).round.clamp(0, 255),
            (g * brightness).round.clamp(0, 255),
            (b * brightness).round.clamp(0, 255))
      end

      # Fire flicker effect
      def fire_flicker(base_r, base_g, base_b, time)
        flicker = rand(-20..20) + (Math.sin(time * 10) * 15).round
        rgb((base_r + flicker).clamp(0, 255),
            (base_g + flicker / 2).clamp(0, 255),
            (base_b).clamp(0, 255))
      end

      # Glitch effect - occasionally scramble color
      def glitch(r, g, b, probability = 0.1)
        if rand < probability
          # Random color shift
          shift = rand(-100..100)
          rgb((r + shift).clamp(0, 255), (g + shift).clamp(0, 255), (b + shift).clamp(0, 255))
        else
          rgb(r, g, b)
        end
      end

      # Strip ANSI codes from string
      def strip(str)
        str.gsub(/\e\[[0-9;]*[a-zA-Z]/, "")
      end

      # Visible length of string (excluding ANSI codes)
      def visible_length(str)
        strip(str).length
      end
    end

    # Extended spinner styles for maximum pizzazz
    SPINNERS = {
      braille: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
      dots: ["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"],
      moon: ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"],
      clock: ["🕐", "🕑", "🕒", "🕓", "🕔", "🕕", "🕖", "🕗", "🕘", "🕙", "🕚", "🕛"],
      earth: ["🌍", "🌎", "🌏"],
      bounce: ["⠁", "⠂", "⠄", "⠂"],
      arc: ["◜", "◠", "◝", "◞", "◡", "◟"],
      square: ["◰", "◳", "◲", "◱"],
      arrows: ["←", "↖", "↑", "↗", "→", "↘", "↓", "↙"],
      box: ["▖", "▘", "▝", "▗"],
      triangle: ["◢", "◣", "◤", "◥"],
      binary: ["0", "1"],
      hearts: ["💖", "💗", "💓", "💗"],
      fire: ["🔥", "🔥", "🔥", "🔥", "🔥", "🔥", "🔥", "🔥", "✨", "✨"],
      sparkle: ["✨", "💫", "⭐", "🌟", "💫", "✨"],
      nyan: ["🐱", "🐱", "🐱", "🌈"],
      snake: ["⠁", "⠉", "⠋", "⠛", "⠟", "⠿", "⡿", "⣿", "⣶", "⣤", "⣀"],
      grow: ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█", "▇", "▆", "▅", "▄", "▃", "▂"],
      wave: ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█", "▇", "▆", "▅", "▄", "▃", "▂", "▁"],
      toggle: ["⊶", "⊷"],
      balloon: [".", "o", "O", "@", "*", " "],
      noise: ["▓", "▒", "░", "▒"],
      dna: ["╔", "╗", "╝", "╚"],
      weather: ["🌤️", "⛅", "🌥️", "☁️", "🌧️", "⛈️", "🌩️", "🌨️"],
      rocket: ["🚀", "🚀", "💨", "✨"],
      skull: ["💀", "☠️"],
      eyes: ["👁️", "👀", "👁️", "👀"],
      explosion: ["💥", "✨", "🔥", "💫"],
    }.freeze

    # Celebration effects
    CELEBRATIONS = {
      firework: [".", "*", "✦", "✸", "✹", "✺", "✹", "✸", "✦", "*", "."],
      confetti: ["🎊", "🎉", "✨", "🌟", "💫", "⭐"],
      party: ["🎈", "🎁", "🎂", "🍰", "🎊", "🎉"],
      success: ["✓", "✔", "✔️", "☑️", "✅"],
    }.freeze

    # Box drawing characters for frames
    FRAMES = {
      single: { tl: "┌", tr: "┐", bl: "└", br: "┘", h: "─", v: "│" },
      double: { tl: "╔", tr: "╗", bl: "╚", br: "╝", h: "═", v: "║" },
      rounded: { tl: "╭", tr: "╮", bl: "╰", br: "╯", h: "─", v: "│" },
      bold: { tl: "┏", tr: "┓", bl: "┗", br: "┛", h: "━", v: "┃" },
      ascii: { tl: "+", tr: "+", bl: "+", br: "+", h: "-", v: "|" },
    }.freeze
  end
end
