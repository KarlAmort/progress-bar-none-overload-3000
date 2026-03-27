# frozen_string_literal: true

module ProgressBarNone
  class Gantt
    # Color mode configurations
    MODES = {
      tufte: {
        done:    { palette: :ocean,   char: "█", partial: "▓" },
        wip:     { palette: :sunset,  char: "▓", partial: "▒" },
        pending: { palette: :mono,    char: "░", partial: "░" },
        frame: false,
        animated: false,
      },
      phase: {
        palettes: [:ocean, :forest, :sunset, :crystal, :fire, :ice, :galaxy, :neon],
        char: "█", partial: "▓",
        frame: :rounded,
        animated: false,
      },
      rainbow: {
        char: "█", partial: "▓",
        frame: :neon,
        animated: true,
      },
      fire: {
        done:    { palette: :lava, char: "█", partial: "▓" },
        wip:     { palette: :lava, char: "▓", partial: "▒" },
        pending: { palette: :mono, char: "░", partial: "░" },
        frame: :bold,
        animated: true,
      },
      matrix: {
        done:    { palette: :matrix, char: "█", partial: "▓" },
        wip:     { palette: :matrix, char: "▓", partial: "▒" },
        pending: { palette: :hacker, char: "░", partial: "░" },
        frame: :single,
        animated: true,
      },
      neon: {
        done:    { palette: :synthwave, char: "█", partial: "▓" },
        wip:     { palette: :neon,      char: "▓", partial: "▒" },
        pending: { palette: :mono,      char: "░", partial: "░" },
        frame: :cyber,
        animated: true,
      },
    }.freeze

    STATUS_ICONS = {
      done:    "✓",
      wip:     "◆",
      pending: "○",
    }.freeze

    attr_reader :tasks, :mode, :title, :width, :show_progress, :animated

    def initialize(tasks, title: nil, mode: :tufte, width: 80, show_progress: true,
                   animated: nil, frame_style: nil, custom_palettes: nil)
      @tasks = tasks.map { |t| normalize_task(t) }
      @title = title
      @mode = mode
      @mode_config = MODES[mode] || MODES[:tufte]
      @width = width
      @show_progress = show_progress
      @animated = animated.nil? ? @mode_config[:animated] : animated
      @frame_style = frame_style || @mode_config[:frame]
      @custom_palettes = custom_palettes
      @max_time = @tasks.map { |t| t[:start] + t[:duration] }.max || 1
    end

    def render(frame_num: 0)
      lines = []
      lines.concat(render_title(frame_num))
      lines << render_timeline_header
      lines << render_separator
      @tasks.each_with_index { |t, i| lines << render_task_row(t, i, frame_num) }
      lines << render_separator
      lines.concat(render_footer(frame_num)) if @show_progress
      lines
    end

    def to_s(frame_num: 0)
      render(frame_num: frame_num).join("\n")
    end

    def run(fps: 1)
      print ANSI::HIDE_CURSOR
      frame = 0
      loop do
        print "\e[2J\e[H"
        puts to_s(frame_num: frame)
        frame += 1
        sleep(1.0 / fps)
      end
    rescue Interrupt
      print ANSI::SHOW_CURSOR
    end

    private

    def normalize_task(t)
      {
        name:     t[:name] || "Untitled",
        group:    t[:group] || "",
        start:    t[:start] || 0,
        duration: t[:duration] || 1,
        status:   t[:status] || :pending,
        progress: t[:progress] || 0.0,
      }
    end

    def render_title(frame_num)
      return [] unless @title
      if @mode == :rainbow
        rainbow_title = @title.each_char.with_index.map { |c, i|
          "#{ANSI.rainbow_cycle(i * 0.1, frame_num * 0.1, 1.0)}#{c}"
        }.join + ANSI::RESET
        [rainbow_title, ""]
      elsif @frame_style
        Frames.banner(@title, style: :double, palette: title_palette, animated: @animated, frame_num: frame_num) + [""]
      else
        color = ANSI.palette_color(title_palette, 0.5)
        ["#{ANSI::BOLD}#{color}#{@title}#{ANSI::RESET}", ""]
      end
    end

    def render_timeline_header
      label_width = calc_label_width
      bar_width = @width - label_width
      header = "#{ANSI::DIM}#{"Phase".ljust(6)}#{"Task".ljust(label_width - 6)}#{ANSI::RESET}"

      step = [(@max_time / 10.0).ceil, 1].max
      markers = (0..@max_time).step(step * 2).map { |i| format("%-4s", "T#{i}") }.join
      "  #{header}#{ANSI::DIM}#{markers}#{ANSI::RESET}"
    end

    def render_separator
      "  #{ANSI::DIM}#{"─" * (@width - 4)}#{ANSI::RESET}"
    end

    def render_task_row(task, index, frame_num)
      status = task[:status]
      icon_color = status_color(status, 0.5, index, frame_num)
      icon = "#{icon_color}#{STATUS_ICONS[status]}#{ANSI::RESET}"

      name_style = status == :done ? ANSI::DIM : ""
      group_color = ANSI.palette_color(:crystal, 0.3)

      label = "  #{group_color}#{task[:group].ljust(6)}#{ANSI::RESET}#{icon} #{name_style}#{task[:name].ljust(calc_label_width - 8)}#{ANSI::RESET}"

      bar = render_bar(task, index, frame_num)
      "#{label}#{bar}"
    end

    def render_bar(task, index, frame_num)
      label_width = calc_label_width
      bar_width = @width - label_width - 4
      scale = bar_width.to_f / @max_time

      start_pos = (task[:start] * scale).round
      filled_total = (task[:duration] * scale).round
      filled_done = (filled_total * task[:progress]).round

      # Build bar as array of cells (each cell is a pre-formatted string)
      cells = Array.new(bar_width) { " " }

      filled_total.times do |i|
        pos = start_pos + i
        break if pos >= bar_width

        is_done_portion = i < filled_done
        char_progress = i.to_f / [filled_total, 1].max

        color = if @mode == :rainbow
                  ANSI.rainbow_cycle(char_progress, frame_num * 0.1, 1.0)
                elsif @mode == :fire && @animated
                  palette = ANSI::CRYSTAL_PALETTE[:lava]
                  c = palette[(char_progress * (palette.length - 1)).round]
                  ANSI.fire_flicker(c[0], c[1], c[2], frame_num * 0.1 + i * 0.05)
                else
                  status_color(task[:status], char_progress, index, frame_num)
                end

        ch = if is_done_portion
               bar_char(task[:status], :filled)
             elsif task[:progress] > 0
               bar_char(task[:status], :partial)
             else
               bar_char(task[:status], :filled)
             end

        cells[pos] = "#{color}#{ch}#{ANSI::RESET}"
      end

      # Matrix rain in empty space
      if @mode == :matrix && @animated
        cells.each_with_index do |cell, i|
          if cell == " " && rand < 0.03
            cells[i] = "#{ANSI::DIM}#{ANSI.palette_color(:matrix, rand)}#{["0", "1"].sample}#{ANSI::RESET}"
          end
        end
      end

      cells.join
    end

    def render_footer(frame_num)
      done = @tasks.count { |t| t[:status] == :done }
      total = @tasks.size
      pct = total > 0 ? done.to_f / total : 0

      renderer = Renderer.new(
        style: :crystal,
        width: [30, @width - 30].min,
        palette: footer_palette,
      )

      state = { progress: pct, current: done, total: total }
      lines = [""]
      lines << "  #{renderer.render_progress_bar(state)}"
      lines << "  #{ANSI::DIM}Updated: #{Time.now.strftime("%H:%M:%S")}#{ANSI::RESET}"
      lines << ""
      lines
    end

    def status_color(status, progress, index, frame_num)
      case @mode
      when :phase
        palettes = MODES[:phase][:palettes]
        palette_name = palettes[index % palettes.length]
        ANSI.palette_color(palette_name, progress)
      when :rainbow
        ANSI.rainbow_cycle(progress, frame_num * 0.1, 1.0)
      when :custom
        palette_name = @custom_palettes&.dig(status) || :crystal
        ANSI.palette_color(palette_name, progress)
      else
        config = @mode_config[status]
        if config
          ANSI.palette_color(config[:palette], progress)
        else
          ANSI.palette_color(:mono, progress)
        end
      end
    end

    def bar_char(status, type)
      config = @mode_config[status]
      return "█" unless config.is_a?(Hash)
      type == :filled ? config[:char] : config[:partial]
    end

    def title_palette
      case @mode
      when :fire then :lava
      when :matrix then :matrix
      when :neon then :neon
      when :rainbow then :rainbow
      else :ocean
      end
    end

    def footer_palette
      case @mode
      when :fire then :lava
      when :matrix then :matrix
      when :neon then :synthwave
      when :rainbow then :rainbow
      else :ocean
      end
    end

    def calc_label_width
      max_name = @tasks.map { |t| t[:name].length }.max || 10
      max_group = @tasks.map { |t| t[:group].length }.max || 2
      [max_name + max_group + 10, @width / 2].min
    end

    public

    def render_svg(svg_width: 900, row_height: 25)
      svg_height = 120 + @tasks.size * row_height + 60

      status_palette = { done: :ocean, wip: :sunset, pending: :mono }
      status_opacity = { done: 0.8, wip: 0.6, pending: 0.3 }

      lines = []
      lines << %(<svg xmlns="http://www.w3.org/2000/svg" width="#{svg_width}" height="#{svg_height}" font-family="'SF Mono', 'Menlo', 'Monaco', monospace" font-size="13">)
      lines << %(  <rect width="100%" height="100%" fill="#1a1a2e" rx="12"/>)
      lines << %(  <g fill="#e0e0e0">)

      if @title
        lines << %(    <text x="#{svg_width / 2}" y="50" text-anchor="middle" fill="#{palette_rgb(:ocean, 0.5)}" font-size="18" font-weight="bold">#{escape_svg(@title)}</text>)
        lines << %(    <rect x="20" y="65" width="#{svg_width - 40}" height="1" fill="#333"/>)
      end

      y_start = @title ? 90 : 30
      lines << %(    <text x="30" y="#{y_start}" fill="#666" font-size="11">Phase</text>)
      lines << %(    <text x="90" y="#{y_start}" fill="#666" font-size="11">Task</text>)
      lines << %(    <rect x="20" y="#{y_start + 7}" width="#{svg_width - 40}" height="1" fill="#333"/>)

      bar_left = 350
      bar_right = svg_width - 30
      bar_total = bar_right - bar_left
      scale = bar_total.to_f / @max_time

      @tasks.each_with_index do |task, i|
        y = y_start + 20 + i * row_height
        icon = STATUS_ICONS[task[:status]]
        color = palette_rgb(status_palette[task[:status]], 0.5)
        opacity = status_opacity[task[:status]]
        name_fill = task[:status] == :done ? "#999" : "#ccc"

        lines << %(    <text x="30" y="#{y}" fill="#00bcd4" font-size="11">#{escape_svg(task[:group])}</text>)
        lines << %(    <text x="70" y="#{y}" fill="#{color}" font-size="11">#{icon}</text>)
        lines << %(    <text x="90" y="#{y}" fill="#{name_fill}" font-size="11">#{escape_svg(task[:name])}</text>)

        rx = bar_left + (task[:start] * scale).round
        rw = (task[:duration] * scale).round
        lines << %(    <rect x="#{rx}" y="#{y - 12}" width="#{rw}" height="16" fill="#{color}" opacity="#{opacity}" rx="2"/>)
      end

      done = @tasks.count { |t| t[:status] == :done }
      pct = @tasks.size > 0 ? (done.to_f / @tasks.size * 100).round : 0
      footer_y = y_start + 20 + @tasks.size * row_height + 20
      filled_w = (pct / 100.0 * 300).round
      lines << %(    <rect x="20" y="#{footer_y - 15}" width="#{svg_width - 40}" height="1" fill="#333"/>)
      lines << %(    <text x="30" y="#{footer_y}" fill="#ccc" font-weight="bold" font-size="12">Progress:</text>)
      lines << %(    <rect x="120" y="#{footer_y - 12}" width="300" height="16" fill="#333" rx="4"/>)
      lines << %(    <rect x="120" y="#{footer_y - 12}" width="#{filled_w}" height="16" fill="#{palette_rgb(:ocean, 0.7)}" opacity="0.8" rx="4"/>)
      lines << %(    <text x="430" y="#{footer_y}" fill="#{palette_rgb(:ocean, 0.7)}" font-size="12">#{pct}% (#{done}/#{@tasks.size})</text>)

      lines << %(  </g>)
      lines << %(</svg>)
      lines.join("\n")
    end

    private

    def palette_rgb(palette_name, progress)
      p = ANSI::CRYSTAL_PALETTE[palette_name] || ANSI::CRYSTAL_PALETTE[:crystal]
      scaled = progress * (p.length - 1)
      i = scaled.floor
      frac = scaled - i
      c1 = p[i]
      c2 = p[[i + 1, p.length - 1].min]
      r = (c1[0] + (c2[0] - c1[0]) * frac).round
      g = (c1[1] + (c2[1] - c1[1]) * frac).round
      b = (c1[2] + (c2[2] - c1[2]) * frac).round
      "#%02x%02x%02x" % [r, g, b]
    end

    def escape_svg(text)
      text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
    end
  end
end
