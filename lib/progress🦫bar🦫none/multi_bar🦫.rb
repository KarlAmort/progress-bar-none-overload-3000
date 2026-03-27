# frozen_string_literal: true

module ProgressBarNone
  # Multi-bar progress display with nested/hierarchical bars.
  # Sub-bars compose into parent bars. Bars can start indeterminate
  # and become specific once the total is discovered.
  #
  # @example Basic usage
  #   multi = ProgressBarNone::MultiBar.new
  #   multi.add(:total, title: "TOTAL", style: :fire, palette: :neon, rainbow_mode: true)
  #   multi.add(:search, title: "Searching", parent: :total, style: :electric, palette: :ocean)
  #   multi.add(:import, title: "Importing", parent: :total, style: :crystal, palette: :crystal)
  #   multi.start
  #
  #   multi.set_total(:search, 3)
  #   3.times { multi.increment(:search) }
  #
  #   multi.set_total(:import, 57)
  #   57.times { multi.increment(:import) }
  #
  #   multi.finish
  #
  class MultiBar
    PALETTES_CYCLE = %i[neon fire ocean synthwave acid crystal vaporwave matrix lava ice galaxy toxic].freeze
    STYLES_CYCLE = %i[fire electric crystal plasma wave nyan matrix glitch rocket cyberpunk stars skull].freeze

    BarState = Struct.new(
      :name, :title, :parent, :children,
      :total, :current, :started_at, :finished,
      :style, :palette, :spinner, :rainbow_mode, :glow,
      :indeterminate, :weight,
      keyword_init: true
    )

    def initialize(output: $stderr, fps: 12, width: 40)
      @bars = {}
      @bar_order = []
      @output = output
      @fps = fps
      @width = width
      @mutex = Mutex.new
      @lines_rendered = 0
      @render_thread = nil
      @started = false
      @finished = false
      @frame = 0
      @start_time = nil
    end

    # Add a bar to the display.
    # @param name [Symbol] Unique identifier
    # @param title [String] Display title
    # @param total [Integer, nil] Total items (nil = indeterminate)
    # @param parent [Symbol, nil] Parent bar name (for nesting)
    # @param style [Symbol] Bar style
    # @param palette [Symbol] Color palette
    # @param weight [Float] How much this bar contributes to parent (auto-calculated if not set)
    def add(name, title:, total: nil, parent: nil, style: nil, palette: nil,
            spinner: :braille, rainbow_mode: false, glow: false, weight: nil)
      @mutex.synchronize do
        depth = parent ? depth_of(parent) + 1 : 0
        style ||= STYLES_CYCLE[depth % STYLES_CYCLE.size]
        palette ||= PALETTES_CYCLE[depth % PALETTES_CYCLE.size]

        bar = BarState.new(
          name: name, title: title, parent: parent, children: [],
          total: total, current: 0, started_at: nil, finished: false,
          style: style, palette: palette, spinner: spinner,
          rainbow_mode: rainbow_mode, glow: glow,
          indeterminate: total.nil?, weight: weight
        )

        @bars[name] = bar
        @bar_order << name

        # Register as child of parent
        if parent && @bars[parent]
          @bars[parent].children << name
        end
      end
    end

    # Set or update the total for a bar (transitions from indeterminate to determinate)
    def set_total(name, total)
      @mutex.synchronize do
        bar = @bars[name]
        return unless bar
        bar.total = total
        bar.indeterminate = false
      end
      maybe_render
    end

    # Increment a bar's progress. Propagates to parent bars.
    def increment(name, amount = 1, metrics: nil)
      @mutex.synchronize do
        bar = @bars[name]
        return unless bar
        bar.current += amount
        bar.current = [bar.current, bar.total].min if bar.total
        bar.started_at ||= Time.now

        # Propagate to parent
        propagate_to_parent(bar)
      end
      maybe_render
    end

    # Log a status message for a bar (shown as subtitle)
    def log(name, message)
      @mutex.synchronize do
        bar = @bars[name]
        return unless bar
        bar.title = message
      end
      maybe_render
    end

    # Mark a bar as finished
    def finish_bar(name)
      @mutex.synchronize do
        bar = @bars[name]
        return unless bar
        bar.current = bar.total if bar.total
        bar.finished = true
        propagate_to_parent(bar)
      end
      maybe_render
    end

    # Start the multi-bar display with a background render thread
    def start
      @start_time = Time.now
      @started = true
      @output.print ANSI::HIDE_CURSOR
      render(force: true)

      @render_thread = Thread.new do
        loop do
          break if @finished
          sleep(1.0 / @fps)
          render
        end
      end
      self
    end

    # Stop rendering and clean up
    def finish
      @finished = true
      @render_thread&.join
      render(force: true)
      @output.puts
      @output.print ANSI::SHOW_CURSOR
      self
    end

    private

    def depth_of(name)
      bar = @bars[name]
      return 0 unless bar&.parent
      1 + depth_of(bar.parent)
    end

    def propagate_to_parent(bar)
      return unless bar.parent
      parent = @bars[bar.parent]
      return unless parent

      # Recalculate parent progress from children
      children = parent.children.map { |c| @bars[c] }.compact
      return if children.empty?

      # Total = sum of child totals (known ones)
      known_children = children.select { |c| c.total && c.total > 0 }
      if known_children.any?
        parent.total = known_children.sum(&:total)
        parent.current = known_children.sum(&:current)
        parent.indeterminate = children.any?(&:indeterminate)
      else
        parent.indeterminate = true
      end

      propagate_to_parent(parent)
    end

    def maybe_render
      render
    end

    def render(force: false)
      @mutex.synchronize do
        @frame += 1

        clear_rendered_lines

        lines = []
        time = Time.now - (@start_time || Time.now)

        @bar_order.each do |name|
          bar = @bars[name]
          depth = depth_of(name)
          indent = "  " * depth

          # Title line
          title_color = ANSI.palette_color(bar.palette, 0.5)
          spinner_char = spinning_char(bar, time)

          if bar.finished
            status = "#{ANSI::BOLD}#{ANSI::GREEN}✓#{ANSI::RESET}"
          elsif bar.indeterminate
            status = spinner_char
          else
            status = spinner_char
          end

          count_str = if bar.total && bar.total > 0
            count_color = ANSI.palette_color(bar.palette, 0.7)
            "#{count_color}#{bar.current}#{ANSI::RESET}#{ANSI::DIM}/#{bar.total}#{ANSI::RESET}"
          elsif bar.current > 0
            count_color = ANSI.palette_color(bar.palette, 0.7)
            "#{count_color}#{bar.current}#{ANSI::RESET}#{ANSI::DIM}/?#{ANSI::RESET}"
          else
            ""
          end

          title_line = "#{indent}#{status} #{ANSI::BOLD}#{title_color}#{bar.title}#{ANSI::RESET}"
          title_line += "  #{count_str}" unless count_str.empty?

          # ETA/rate
          if bar.started_at && bar.total && bar.total > 0 && bar.current > 0 && !bar.finished
            elapsed = Time.now - bar.started_at
            rate = bar.current / elapsed
            eta = (bar.total - bar.current) / rate
            title_line += "  #{ANSI::DIM}#{format_rate(rate)}  → #{format_time(eta)}#{ANSI::RESET}" if rate > 0
          end

          lines << "#{ANSI::CLEAR_LINE}#{title_line}"

          # Bar line
          bar_line = render_bar_line(bar, depth, time)
          lines << "#{ANSI::CLEAR_LINE}#{bar_line}" if bar_line
        end

        # Output
        lines.each_with_index do |line, i|
          @output.print line
          @output.print "\n" if i < lines.length - 1
        end

        @lines_rendered = lines.length
      end
    end

    def render_bar_line(bar, depth, time)
      indent = "  " * depth
      width = @width - (depth * 2)
      width = [width, 10].max

      if bar.indeterminate
        # Pulsing/bouncing bar for unknown total
        render_indeterminate(bar, indent, width, time)
      elsif bar.total && bar.total > 0
        render_determinate(bar, indent, width, time)
      else
        nil
      end
    end

    def render_indeterminate(bar, indent, width, time)
      # Bouncing highlight
      pos = ((Math.sin(time * 2.5) + 1) / 2 * (width - 4)).round
      chars = ""
      width.times do |i|
        dist = (i - pos).abs
        if dist < 3
          intensity = 1.0 - dist / 3.0
          color = ANSI.palette_color(bar.palette, intensity)
          chars += "#{ANSI::BOLD}#{color}█#{ANSI::RESET}"
        else
          chars += "#{ANSI::DIM}░#{ANSI::RESET}"
        end
      end
      "#{indent}  #{ANSI::DIM}⟨#{ANSI::RESET}#{chars}#{ANSI::DIM}⟩#{ANSI::RESET}"
    end

    def render_determinate(bar, indent, width, time)
      progress = bar.current.to_f / bar.total
      progress = [[progress, 0.0].max, 1.0].min

      filled_count = (progress * width).floor
      remaining = width - filled_count

      # Build gradient bar
      filled = ""
      style_def = Renderer::STYLES[bar.style] || Renderer::STYLES[:crystal]

      filled_count.times do |i|
        char_progress = i.to_f / [width, 1].max
        color = if bar.rainbow_mode
                  ANSI.rainbow_cycle(char_progress, time, 0.5)
                else
                  ANSI.palette_color(bar.palette, char_progress)
                end

        # Shimmer wave
        wave_pos = (time * 3.0 * width) % (width * 2)
        dist = (i - wave_pos).abs
        bold = dist < 5 ? ANSI::BOLD : ""

        filled += "#{bold}#{color}#{style_def[:filled]}#{ANSI::RESET}"
      end

      # Partial block at edge
      if remaining > 0 && progress > 0
        partial_progress = (progress * width) - filled_count
        partial_idx = (partial_progress * (style_def[:partial].length - 1)).round
        partial_char = style_def[:partial][[partial_idx, 0].max] || style_def[:partial].last
        edge_color = ANSI.palette_color(bar.palette, progress)
        filled += "#{ANSI::BOLD}#{edge_color}#{partial_char}#{ANSI::RESET}"
        remaining -= 1
      end

      # Empty portion
      empty = ""
      remaining.times { empty += "#{ANSI::DIM}#{style_def[:empty]}#{ANSI::RESET}" }

      # Percentage
      pct = (progress * 100).round(1)
      pct_color = ANSI.palette_color(bar.palette, progress)
      pct_str = "#{pct_color}#{format("%5.1f", pct)}%#{ANSI::RESET}"

      left = "#{ANSI::DIM}#{style_def[:left]}#{ANSI::RESET}"
      right = "#{ANSI::DIM}#{style_def[:right]}#{ANSI::RESET}"

      "#{indent}  #{pct_str} #{left}#{filled}#{empty}#{right}"
    end

    def spinning_char(bar, time)
      return "" if bar.finished
      spinners = ANSI::SPINNERS[bar.spinner] || ANSI::SPINNERS[:braille]
      idx = (@frame % spinners.length)
      color = ANSI.palette_color(bar.palette, (time * 2) % 1.0)
      "#{color}#{spinners[idx]}#{ANSI::RESET}"
    end

    def clear_rendered_lines
      return if @lines_rendered.zero?
      (@lines_rendered - 1).times do
        @output.print ANSI.up(1)
        @output.print ANSI::CLEAR_LINE
      end
      @output.print "\r#{ANSI::CLEAR_LINE}"
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
      return "∞" if seconds == Float::INFINITY || seconds.nan?
      return "0s" if seconds <= 0
      if seconds < 60
        "#{seconds.round(0)}s"
      elsif seconds < 3600
        "#{(seconds / 60).floor}m#{(seconds % 60).round}s"
      else
        "#{(seconds / 3600).floor}h#{((seconds % 3600) / 60).round}m"
      end
    end
  end
end
