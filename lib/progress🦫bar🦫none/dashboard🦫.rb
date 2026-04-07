# frozen_string_literal: true

module ProgressBarNone
  # Four-pane fixed terminal dashboard: top / center / right / bottom.
  # Each pane updates in-place and independently via absolute ANSI cursor
  # positioning.  Designed for Ghostty and any VT100-compatible terminal.
  #
  # Layout
  # ──────
  #   ╔═════════════════ TOP ════════════════════════════╗
  #   ║  header / overall progress                       ║
  #   ╠════════ CENTER ═══════════════╦═══ RIGHT ════════╣
  #   ║  task list + progress bars    ║  metrics/stats   ║
  #   ╠════════ BOTTOM ═══════════════╩══════════════════╣
  #   ║  scrolling log                                   ║
  #   ╚══════════════════════════════════════════════════╝
  #
  # @example
  #   dash = Dashboard.new(title: "Build Pipeline", width: 100, height: 30)
  #   dash.start
  #   dash.update(:top,    ["Overall: 42%  ⏱ 3s"])
  #   dash.update(:center, ["[✓] compile", "[ ] test"])
  #   dash.update(:right,  ["CPU  12%", "MEM 340 MB"])
  #   dash.log("Compiled main.rb")
  #   dash.finish
  #
  class Dashboard
    # ── box-drawing style ────────────────────────────────────────────────────
    B = {
      tl: "╔", tr: "╗", bl: "╚", br: "╝",
      h:  "═", v:  "║",
      ml: "╠", mr: "╣",         # mid-row left/right wall connectors
      ts: "╦", bs: "╩",         # top/bottom of vertical separator
      xs: "╬",                  # crossing of horizontal rule + vertical sep
    }.freeze

    # Pane descriptor (immutable geometry + mutable content)
    Pane = Struct.new(:name, :top_row, :left_col, :inner_w, :inner_h,
                      :title, :palette, keyword_init: true) do
      def content
        @content ||= []
      end

      def content=(val)
        @content = val
      end
    end

    # ── task tracking ────────────────────────────────────────────────────────
    Task = Struct.new(:name, :status, :progress, :message, keyword_init: true)

    TASK_ICONS = { pending: "○", running: "◉", done: "✓", error: "✗" }.freeze
    TASK_COLORS = {
      pending: ANSI::DIM,
      running: "\e[38;2;0;200;255m",
      done:    "\e[38;2;0;255;100m",
      error:   "\e[38;2;255;60;60m",
    }.freeze

    attr_reader :panes, :tasks

    # @param title      [String]       Dashboard title shown in top border
    # @param width      [Integer]      Total terminal columns (nil = auto-detect)
    # @param height     [Integer]      Total terminal rows (nil = auto-detect)
    # @param top_height [Integer]      Inner rows for top pane
    # @param right_width[Integer]      Inner cols for right pane
    # @param bottom_height[Integer]    Inner rows for bottom pane
    # @param fps        [Integer]      Render frequency
    # @param output     [IO]           Output stream
    def initialize(title: "COCKPIT 3000",
                   width: nil, height: nil,
                   top_height: 3, right_width: 28, bottom_height: 4,
                   fps: 10, output: $stderr)
      @title        = title
      @width        = width  || detect_terminal_width
      @height       = height || detect_terminal_height
      @fps          = fps
      @output       = output
      @mutex        = Mutex.new
      @finished     = false
      @render_thread = nil
      @start_time   = nil
      @log_lines    = []

      # Derived dimensions
      top_h   = top_height
      right_w = right_width
      bot_h   = bottom_height
      ctr_h   = @height - top_h - bot_h - 4   # 4 border rows
      left_w  = @width  - right_w - 3          # left│right│border

      ctr_h = [ctr_h, 1].max
      left_w = [left_w, 10].max

      # Row numbers are 1-indexed terminal rows.
      # Row 1: top outer border
      # Rows 2..top_h+1: top pane content
      # Row top_h+2: horizontal separator (top_h+2)
      # Rows top_h+3..top_h+2+ctr_h: center / right content
      # Row top_h+3+ctr_h: horizontal separator
      # Rows top_h+4+ctr_h..top_h+3+ctr_h+bot_h: bottom content
      # Row top_h+4+ctr_h+bot_h: bottom outer border

      sep1 = top_h + 2         # row of first horizontal separator
      sep2 = sep1 + ctr_h + 1  # row of second horizontal separator

      @panes = {
        top: Pane.new(
          name: :top, top_row: 2, left_col: 2,
          inner_w: @width - 2, inner_h: top_h,
          title: "STATUS", palette: :crystal
        ),
        center: Pane.new(
          name: :center, top_row: sep1 + 1, left_col: 2,
          inner_w: left_w, inner_h: ctr_h,
          title: "TASKS", palette: :matrix
        ),
        right: Pane.new(
          name: :right, top_row: sep1 + 1, left_col: left_w + 3,
          inner_w: right_w, inner_h: ctr_h,
          title: "METRICS", palette: :neon
        ),
        bottom: Pane.new(
          name: :bottom, top_row: sep2 + 1, left_col: 2,
          inner_w: @width - 2, inner_h: bot_h,
          title: "LOG", palette: :ocean
        ),
      }

      @top_h   = top_h
      @ctr_h   = ctr_h
      @left_w  = left_w
      @right_w = right_w
      @bot_h   = bot_h
      @sep1    = sep1
      @sep2    = sep2
      @tasks   = {}
    end

    # ── public API ────────────────────────────────────────────────────────────

    # Start rendering. Draws the frame, then begins the background render loop.
    def start
      @start_time = Time.now
      @output.print ANSI::HIDE_CURSOR
      @output.print "\e[2J\e[H"   # clear screen, home cursor
      draw_frame

      @render_thread = Thread.new do
        loop do
          break if @finished
          refresh_all
          sleep(1.0 / @fps)
        end
      end
      self
    end

    # Finish: final render, restore cursor, move below dashboard.
    def finish
      @finished = true
      @render_thread&.join
      refresh_all
      @output.print ANSI.position(@height + 2, 1)
      @output.print ANSI::SHOW_CURSOR
      self
    end

    # Replace a pane's content lines.
    # @param pane_name [:top, :center, :right, :bottom]
    # @param lines [Array<String>]
    def update(pane_name, lines)
      @mutex.synchronize { @panes[pane_name]&.content = lines }
    end

    # Add (or update) a tracked task.
    def add_task(name, message: "", status: :pending, progress: 0.0)
      @mutex.synchronize do
        @tasks[name] = Task.new(name: name, status: status,
                                progress: progress, message: message)
      end
      rebuild_center
    end

    # Update a tracked task.
    def update_task(name, status: nil, progress: nil, message: nil)
      @mutex.synchronize do
        t = @tasks[name]
        return unless t
        t.status   = status   if status
        t.progress = progress if progress
        t.message  = message  if message
      end
      rebuild_center
    end

    # Append to the scrolling bottom log.
    def log(message)
      @mutex.synchronize do
        timestamp = format_elapsed(Time.now - (@start_time || Time.now))
        @log_lines << "#{ANSI::DIM}#{timestamp}#{ANSI::RESET}  #{message}"
        @log_lines.shift while @log_lines.length > @bot_h
        @panes[:bottom].content = @log_lines.dup
      end
    end

    # ── geometry helpers (exposed for testing) ───────────────────────────────

    def total_rows
      @top_h + @ctr_h + @bot_h + 4
    end

    def frame_string
      build_frame
    end

    private

    # ── rendering ─────────────────────────────────────────────────────────────

    def draw_frame
      @output.print build_frame
    end

    def build_frame
      w = @width
      buf = +""

      # Helper: horizontal rule of width w
      hline = lambda { |len| B[:h] * len }

      # ── Row 1: top border ─────────────────────────────────────────────────
      title_str = " #{@title} "
      pad_total = w - 2 - title_str.length
      pad_l = pad_total / 2
      pad_r = pad_total - pad_l
      buf << pos(1, 1)
      buf << "#{B[:tl]}#{hline.call(pad_l)}#{title_str}#{hline.call(pad_r)}#{B[:tr]}"

      # ── Rows 2..top_h+1: top pane (blank, content filled by refresh) ──────
      (@top_h).times do |i|
        buf << pos(2 + i, 1) << B[:v] << " " * (w - 2) << B[:v]
      end

      # ── Row sep1: separator between top and center/right ─────────────────
      left_label  = " TASKS "
      right_label = " METRICS "
      right_sep_col = @left_w + 2   # 1-indexed column of the vertical separator

      buf << pos(@sep1, 1)
      buf << B[:ml]
      inner = w - 2
      # Draw left section label, then fill to separator, then right section
      left_part  = inner - @right_w - 1   # columns before vertical sep
      right_part = @right_w               # columns after vertical sep

      left_label_line  = center_label(left_label,  left_part)
      right_label_line = center_label(right_label, right_part)
      buf << left_label_line << B[:ts] << right_label_line << B[:mr]

      # ── Rows sep1+1..sep2-1: center/right pane (blank) ───────────────────
      @ctr_h.times do |i|
        row = @sep1 + 1 + i
        buf << pos(row, 1) << B[:v]
        buf << " " * @left_w
        buf << B[:v]
        buf << " " * @right_w
        buf << B[:v]
      end

      # ── Row sep2: separator between center/right and bottom ──────────────
      log_label = " LOG "
      log_line  = center_label(log_label, w - 2)
      buf << pos(@sep2, 1)
      buf << B[:ml] << B[:h] * @left_w << B[:bs] << B[:h] * @right_w << B[:mr]
      # Overwrite with log label centered across the full width
      buf << pos(@sep2, 1)
      buf << B[:ml] << center_label(log_label, w - 2) << B[:mr]

      # ── Rows sep2+1..sep2+bot_h: bottom pane (blank) ─────────────────────
      @bot_h.times do |i|
        buf << pos(@sep2 + 1 + i, 1) << B[:v] << " " * (w - 2) << B[:v]
      end

      # ── Last row: bottom border ───────────────────────────────────────────
      buf << pos(@sep2 + @bot_h + 1, 1)
      buf << "#{B[:bl]}#{hline.call(w - 2)}#{B[:br]}"

      buf
    end

    def refresh_all
      @mutex.synchronize do
        @panes.each_value { |pane| write_pane(pane) }
      end
    end

    def write_pane(pane)
      buf = "".dup
      buf << ANSI::SAVE_CURSOR

      pane.inner_h.times do |i|
        row = pane.top_row + i
        col = pane.left_col

        buf << pos(row, col)

        line = (pane.content[i] || "").dup
        # Clip to pane inner width (visible chars only)
        clipped = clip_visible(line, pane.inner_w)
        # Pad to inner width with spaces to overwrite stale content
        visible_len = ANSI.visible_length(clipped)
        padding = [pane.inner_w - visible_len, 0].max
        buf << clipped << " " * padding
      end

      buf << ANSI::RESTORE_CURSOR
      @output.print buf
    end

    # ── task → center pane content ────────────────────────────────────────────

    def rebuild_center
      lines = []
      elapsed = Time.now - (@start_time || Time.now)

      @tasks.each_value do |task|
        icon  = TASK_ICONS[task.status] || "?"
        color = TASK_COLORS[task.status] || ANSI::RESET
        name_str = "#{color}#{ANSI::BOLD}#{icon} #{task.name}#{ANSI::RESET}"

        # Truncate message to remaining width
        name_vis = ANSI.visible_length(name_str)
        msg_max  = [@left_w - name_vis - 2, 0].max
        msg      = task.message.to_s[0, msg_max]
        msg_str  = msg.empty? ? "" : "  #{ANSI::DIM}#{msg}#{ANSI::RESET}"

        lines << "#{name_str}#{msg_str}"

        # Progress bar for running/done tasks
        if %i[running done].include?(task.status)
          bar_w     = [@left_w - 10, 8].max
          progress  = task.progress.clamp(0.0, 1.0)
          filled    = (progress * bar_w).round
          pct_str   = "#{color}#{format("%3d", (progress * 100).round)}%#{ANSI::RESET}"
          bar_filled = "#{color}#{"█" * filled}#{ANSI::RESET}"
          bar_empty  = "#{ANSI::DIM}#{"░" * (bar_w - filled)}#{ANSI::RESET}"
          lines << "  #{pct_str} #{ANSI::DIM}⟨#{ANSI::RESET}#{bar_filled}#{bar_empty}#{ANSI::DIM}⟩#{ANSI::RESET}"
        end
      end

      @panes[:center].content = lines
    end

    # ── helpers ───────────────────────────────────────────────────────────────

    def pos(row, col)
      ANSI.position(row, col)
    end

    def center_label(label, width)
      pad = [(width - label.length) / 2, 0].max
      (B[:h] * pad + label + B[:h] * width)[0, width]
    end

    # Clip a string (potentially containing ANSI codes) to max_vis visible chars.
    def clip_visible(str, max_vis)
      result = "".dup
      visible = 0
      i = 0
      while i < str.length
        ch = str[i]
        if ch == "\e"
          # Grab the whole escape sequence
          j = i + 1
          j += 1 while j < str.length && !"A-Za-z".include?(str[j]) && str[j] !~ /[A-Za-z]/
          j += 1
          result << str[i...j]
          i = j
        else
          break if visible >= max_vis
          result << ch
          visible += 1
          i += 1
        end
      end
      result << ANSI::RESET
    end

    def format_elapsed(secs)
      return "00:00" if secs <= 0
      m = (secs / 60).floor
      s = (secs % 60).floor
      format("%02d:%02d", m, s)
    end

    def detect_terminal_width
      return IO.console&.winsize&.last || 80
    rescue
      80
    end

    def detect_terminal_height
      return IO.console&.winsize&.first || 24
    rescue
      24
    end
  end
end
