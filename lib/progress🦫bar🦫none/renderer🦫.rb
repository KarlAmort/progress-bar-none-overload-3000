# frozen_string_literal: true

module ProgressBarNone
  # Renders the progress bar and metrics display
  class Renderer
    # Crystal-inspired bar characters
    CRYSTAL_CHARS = {
      filled: "█",
      partial: ["░", "▒", "▓"],
      empty: "░",
      left_cap: "❮",
      right_cap: "❯",
      shimmer: ["✦", "✧", "⬥", "⬦", "◆", "◇"],
    }.freeze

    # Alternative styles
    STYLES = {
      crystal: {
        filled: "█",
        partial: ["░", "▒", "▓"],
        empty: "░",
        left: "⟨",
        right: "⟩",
        pulse: ["◈", "◇", "◆"],
      },
      blocks: {
        filled: "█",
        partial: ["▏", "▎", "▍", "▌", "▋", "▊", "▉"],
        empty: "░",
        left: "[",
        right: "]",
        pulse: ["█", "▓", "▒"],
      },
      dots: {
        filled: "●",
        partial: ["○", "◐", "◑", "●"],
        empty: "○",
        left: "(",
        right: ")",
        pulse: ["●", "◉", "○"],
      },
      arrows: {
        filled: "▶",
        partial: ["▷", "▸", "▹"],
        empty: "▹",
        left: "«",
        right: "»",
        pulse: ["▸", "▹", "▸"],
      },
      ascii: {
        filled: "#",
        partial: ["-", "=", "#"],
        empty: "-",
        left: "[",
        right: "]",
        pulse: ["#", "=", "-"],
      },
      # Animated styles
      fire: {
        filled: "█",
        partial: ["░", "▒", "▓", "█"],
        empty: "░",
        left: "🔥",
        right: "🔥",
        pulse: ["🔥", "💥", "✨"],
        animated: true,
      },
      nyan: {
        filled: "█",
        partial: ["░", "▒", "▓"],
        empty: "░",
        left: "🐱",
        right: "🌈",
        pulse: ["⭐", "✨", "💫"],
        animated: true,
      },
      matrix: {
        filled: "█",
        partial: ["░", "▒", "▓"],
        empty: "░",
        left: "⟨",
        right: "⟩",
        pulse: ["0", "1", "█"],
        animated: true,
      },
      glitch: {
        filled: "█",
        partial: ["▓", "▒", "░"],
        empty: "░",
        left: "⌈",
        right: "⌉",
        pulse: ["▓", "▒", "░", "█"],
        animated: true,
      },
      plasma: {
        filled: "◆",
        partial: ["◇", "◈", "◆"],
        empty: "·",
        left: "《",
        right: "》",
        pulse: ["◆", "◈", "◇"],
        animated: true,
      },
      wave: {
        filled: "█",
        partial: ["▁", "▂", "▃", "▄", "▅", "▆", "▇"],
        empty: "▁",
        left: "〈",
        right: "〉",
        pulse: ["~", "≈", "∿"],
        animated: true,
      },
      electric: {
        filled: "⚡",
        partial: ["·", "∘", "○", "◉"],
        empty: "·",
        left: "⟪",
        right: "⟫",
        pulse: ["⚡", "✧", "★"],
        animated: true,
      },
      skull: {
        filled: "█",
        partial: ["░", "▒", "▓"],
        empty: "░",
        left: "💀",
        right: "☠️",
        pulse: ["💀", "☠️", "🔥"],
        animated: true,
      },
      retro: {
        filled: "■",
        partial: ["□", "▪", "■"],
        empty: "□",
        left: "[",
        right: "]",
        pulse: ["■", "□", "▪"],
      },
      hearts: {
        filled: "♥",
        partial: ["♡", "❤", "♥"],
        empty: "♡",
        left: "💕",
        right: "💕",
        pulse: ["💖", "💗", "💓"],
        animated: true,
      },
      stars: {
        filled: "★",
        partial: ["☆", "✦", "★"],
        empty: "☆",
        left: "⭐",
        right: "🌟",
        pulse: ["✨", "💫", "⭐"],
        animated: true,
      },
      cyberpunk: {
        filled: "▰",
        partial: ["▱", "▰"],
        empty: "▱",
        left: "⟦",
        right: "⟧",
        pulse: ["▰", "▱", "▰"],
        animated: true,
      },
      pixel: {
        filled: "▓",
        partial: ["░", "▒", "▓"],
        empty: "░",
        left: "⌜",
        right: "⌝",
        pulse: ["▓", "▒", "░"],
      },
      snake: {
        filled: "◉",
        partial: ["○", "◎", "◉"],
        empty: "·",
        left: "🐍",
        right: "🍎",
        pulse: ["◉", "◎", "○"],
        animated: true,
      },
      music: {
        filled: "♫",
        partial: ["♪", "♬", "♫"],
        empty: "·",
        left: "🎵",
        right: "🎶",
        pulse: ["🎵", "🎶", "🎼"],
        animated: true,
      },
      rocket: {
        filled: "█",
        partial: ["░", "▒", "▓"],
        empty: "·",
        left: "🚀",
        right: "🌙",
        pulse: ["🚀", "💨", "✨"],
        animated: true,
      },
    }.freeze

    attr_reader :style, :width, :palette, :spinner_style, :rainbow_mode, :celebration_mode

    def initialize(style: :crystal, width: 40, palette: :crystal, spinner: :braille,
                   rainbow_mode: false, celebration_mode: :confetti, glow: false)
      @style = STYLES[style] || STYLES[:crystal]
      @style_name = style
      @width = width
      @palette = palette
      @spinner_style = spinner
      @rainbow_mode = rainbow_mode
      @celebration_mode = celebration_mode
      @glow = glow
      @animation_frame = 0
      @last_render_time = Time.now
      @start_time = Time.now
    end

    # Render the complete progress display
    def render(state)
      @animation_frame += 1
      lines = []

      # Main progress bar line
      lines << render_progress_bar(state)

      # Stats line
      lines << render_stats(state)

      # Metrics lines (if any)
      if state[:metrics]&.any?
        lines << ""  # Spacer
        lines.concat(render_metrics(state[:metrics]))
      end

      lines
    end

    # Render just the progress bar
    def render_progress_bar(state)
      progress = state[:progress] || 0.0
      progress = [[progress, 0.0].max, 1.0].min

      filled_width = (progress * @width).floor
      remaining = @width - filled_width

      # Build the bar with gradient colors
      bar = build_gradient_bar(filled_width, remaining, progress)

      # Percentage with color
      pct = (progress * 100).round(1)
      pct_color = ANSI.palette_color(@palette, progress)
      pct_str = "#{pct_color}#{format("%5.1f", pct)}%#{ANSI::RESET}"

      # Caps
      left = "#{ANSI::DIM}#{@style[:left]}#{ANSI::RESET}"
      right = "#{ANSI::DIM}#{@style[:right]}#{ANSI::RESET}"

      "#{pct_str} #{left}#{bar}#{right}"
    end

    # Render statistics line
    def render_stats(state)
      parts = []

      # Items done / total
      if state[:total]
        done_color = ANSI.palette_color(@palette, 0.5)
        total_color = ANSI::DIM
        parts << "#{done_color}#{state[:current]}#{ANSI::RESET}#{total_color}/#{state[:total]}#{ANSI::RESET}"
      end

      # Rate
      if state[:rate] && state[:rate] > 0
        rate_color = ANSI.palette_color(@palette, 0.3)
        rate_str = format_rate(state[:rate])
        parts << "#{rate_color}#{rate_str}#{ANSI::RESET}"
      end

      # Elapsed time
      if state[:elapsed]
        elapsed_str = format_time(state[:elapsed])
        parts << "#{ANSI::DIM}⏱#{ANSI::RESET} #{elapsed_str}"
      end

      # ETA
      if state[:eta] && state[:eta] > 0 && state[:eta] < Float::INFINITY
        eta_color = ANSI.palette_color(@palette, 0.7)
        eta_str = format_time(state[:eta])
        parts << "#{ANSI::DIM}→#{ANSI::RESET} #{eta_color}#{eta_str}#{ANSI::RESET}"
      elsif state[:progress] && state[:progress] >= 1.0
        # CELEBRATION TIME!
        celebration = render_celebration
        done_color = ANSI.palette_color(@palette, 1.0)
        parts << "#{celebration} #{done_color}✓ Done!#{ANSI::RESET} #{celebration}"
      end

      # Spinner for active work
      if state[:progress] && state[:progress] < 1.0 && state[:progress] > 0
        spinner = render_spinner
        parts.unshift(spinner)
      end

      parts.join("  ")
    end

    # Render metrics section
    def render_metrics(metrics)
      metrics.format_all(palette: @palette)
    end

    private

    def build_gradient_bar(filled, remaining, progress)
      bar = ""
      time = Time.now - @start_time

      # Filled portion with gradient (with optional rainbow cycling and shimmer)
      filled.times do |i|
        char_progress = i.to_f / [@width, 1].max

        # Choose color based on mode
        color = if @rainbow_mode
                  # Rainbow cycling animation
                  ANSI.rainbow_cycle(char_progress, time, 0.5)
                elsif @style[:animated] && @style_name == :fire
                  # Fire flicker effect
                  base_colors = [[255, 80, 0], [255, 160, 0], [255, 200, 0]]
                  c = base_colors[(char_progress * (base_colors.length - 1)).round]
                  ANSI.fire_flicker(c[0], c[1], c[2], time + i * 0.1)
                elsif @style[:animated] && @style_name == :glitch
                  # Glitch effect
                  palette = ANSI::CRYSTAL_PALETTE[@palette] || ANSI::CRYSTAL_PALETTE[:crystal]
                  c = palette[(char_progress * (palette.length - 1)).round]
                  ANSI.glitch(c[0], c[1], c[2], 0.05)
                elsif @style[:animated] && @style_name == :matrix
                  # Matrix rain effect - occasionally show 0 or 1
                  if rand < 0.1
                    ANSI.rgb(0, 255, 0)
                  else
                    ANSI.palette_color(@palette, char_progress)
                  end
                else
                  ANSI.palette_color(@palette, char_progress)
                end

        # Add shimmer wave effect
        shimmer_intensity = calculate_shimmer(i, filled, time)
        if shimmer_intensity > 0
          color = apply_shimmer_to_color(color, shimmer_intensity)
        end

        # Apply glow effect if enabled
        char = @style[:filled]
        if @glow && i == filled - 1
          # Leading edge gets glow
          bar += "#{ANSI::BOLD}#{color}#{char}#{ANSI::RESET}"
        else
          bar += "#{color}#{char}#{ANSI::RESET}"
        end
      end

      # Partial block at the edge with pulsing
      if remaining > 0 && progress > 0
        partial_progress = (progress * @width) - filled
        partial_index = (partial_progress * (@style[:partial].length - 1)).round
        partial_char = @style[:partial][partial_index] || @style[:partial].last

        edge_color = if @rainbow_mode
                       ANSI.rainbow_cycle(progress, time, 0.5)
                     else
                       ANSI.palette_color(@palette, progress)
                     end

        bar += "#{ANSI::BOLD}#{edge_color}#{partial_char}#{ANSI::RESET}"
        remaining -= 1
      end

      # Empty portion with subtle animation
      remaining.times do |i|
        if @style[:animated] && rand < 0.02
          # Occasional sparkle in empty space
          sparkle = ["·", "∙", "•"][rand(3)]
          bar += "#{ANSI::DIM}#{sparkle}#{ANSI::RESET}"
        else
          bar += "#{ANSI::DIM}#{@style[:empty]}#{ANSI::RESET}"
        end
      end

      bar
    end

    def calculate_shimmer(position, total_filled, time)
      return 0 if total_filled < 3

      # Traveling wave shimmer
      wave_speed = 3.0
      wave_width = 5.0
      wave_pos = (time * wave_speed * @width) % (@width * 2)

      distance = (position - wave_pos).abs
      if distance < wave_width
        (1.0 - distance / wave_width) * 0.5
      else
        0
      end
    end

    def apply_shimmer_to_color(color_code, intensity)
      # Extract RGB from color code if possible, boost brightness
      # For simplicity, we'll just add BOLD for shimmer
      "#{ANSI::BOLD}#{color_code}"
    end

    def render_spinner
      spinners = ANSI::SPINNERS[@spinner_style] || ANSI::SPINNERS[:braille]
      time = Time.now - @start_time

      # Animate color
      spinner_color = if @rainbow_mode
                        ANSI.rainbow_cycle(0, time, 2.0)
                      else
                        ANSI.palette_color(@palette, (time * 2) % 1.0)
                      end

      spinner_char = spinners[@animation_frame % spinners.length]
      "#{spinner_color}#{spinner_char}#{ANSI::RESET}"
    end

    # Render celebration effects when complete
    def render_celebration
      time = Time.now - @start_time
      effects = ANSI::CELEBRATIONS[@celebration_mode] || ANSI::CELEBRATIONS[:confetti]

      # Animated celebration
      celebration = ""
      5.times do |i|
        char = effects[((@animation_frame + i * 3) % effects.length)]
        color = ANSI.rainbow_cycle(i / 5.0, time, 3.0)
        celebration += "#{color}#{char}#{ANSI::RESET}"
      end
      celebration
    end

    def format_rate(rate)
      if rate >= 1000
        "#{(rate / 1000.0).round(1)}K/s"
      elsif rate >= 1
        "#{rate.round(1)}/s"
      else
        "#{(rate * 60).round(1)}/min"
      end
    end

    def format_time(seconds)
      return "∞" if seconds == Float::INFINITY
      return "0s" if seconds <= 0

      if seconds < 60
        "#{seconds.round(1)}s"
      elsif seconds < 3600
        mins = (seconds / 60).floor
        secs = (seconds % 60).round
        "#{mins}m#{secs}s"
      else
        hours = (seconds / 3600).floor
        mins = ((seconds % 3600) / 60).round
        "#{hours}h#{mins}m"
      end
    end
  end
end
