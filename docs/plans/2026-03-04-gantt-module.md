# Cockpit3000::Gantt Module Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a generic, reusable Gantt chart renderer to the Cockpit3000 gem with Tufte-inspired defaults and rainbow vomit mode.

**Architecture:** New `Cockpit3000::Gantt` class in `lib/cockpit3000/gantt.rb`. Takes an array of task hashes, renders ANSI terminal output or SVG. Uses existing ANSI, Frames, Renderer, Sparkline modules for all visual output. SONYHATE3000's `sonyctl_gantt.rb` becomes a thin wrapper.

**Tech Stack:** Pure Ruby, no new dependencies. Uses Cockpit3000::ANSI (true-color), Cockpit3000::Frames (borders), Cockpit3000::Renderer (progress bar), Cockpit3000::Sparkline (optional velocity graphs).

---

### Task 1: Gantt class skeleton + Tufte mode rendering

**Files:**
- Create: `lib/cockpit3000/gantt.rb`
- Modify: `lib/cockpit3000.rb` (add require)
- Create: `test/gantt_test.rb`

**Step 1: Write the failing test**

```ruby
# test/gantt_test.rb
require "minitest/autorun"
require_relative "../lib/cockpit3000"

class GanttTest < Minitest::Test
  def setup
    @tasks = [
      { name: "Task A", group: "P1", start: 0, duration: 4, status: :done, progress: 1.0 },
      { name: "Task B", group: "P2", start: 2, duration: 6, status: :wip, progress: 0.5 },
      { name: "Task C", group: "P3", start: 6, duration: 3, status: :pending, progress: 0.0 },
    ]
  end

  def test_render_returns_array_of_strings
    chart = Cockpit3000::Gantt.new(@tasks, title: "Test Chart")
    lines = chart.render
    assert_kind_of Array, lines
    assert lines.all? { |l| l.is_a?(String) }
    assert lines.length > 5 # title + header + 3 tasks + footer
  end

  def test_to_s_returns_joined_string
    chart = Cockpit3000::Gantt.new(@tasks)
    assert_kind_of String, chart.to_s
    assert chart.to_s.include?("Task A")
  end

  def test_tufte_mode_is_default
    chart = Cockpit3000::Gantt.new(@tasks)
    assert_equal :tufte, chart.mode
  end

  def test_task_names_appear_in_output
    chart = Cockpit3000::Gantt.new(@tasks)
    output = chart.to_s
    assert output.include?("Task A")
    assert output.include?("Task B")
    assert output.include?("Task C")
  end

  def test_group_labels_appear_in_output
    chart = Cockpit3000::Gantt.new(@tasks)
    output = chart.to_s
    assert output.include?("P1")
    assert output.include?("P2")
    assert output.include?("P3")
  end

  def test_status_icons_in_output
    chart = Cockpit3000::Gantt.new(@tasks)
    stripped = Cockpit3000::ANSI.strip(chart.to_s)
    assert stripped.include?("✓") # done
    assert stripped.include?("◆") # wip
    assert stripped.include?("○") # pending
  end

  def test_progress_bar_in_footer
    chart = Cockpit3000::Gantt.new(@tasks, show_progress: true)
    stripped = Cockpit3000::ANSI.strip(chart.to_s)
    assert stripped.include?("%")
  end
end
```

**Step 2: Run test to verify it fails**

Run: `cd "/Users/matti/p/🦜 progress bar none overload 3000 🦑" && ruby test/gantt_test.rb`
Expected: FAIL — `Cockpit3000::Gantt` not defined

**Step 3: Write the Gantt class**

```ruby
# lib/cockpit3000/gantt.rb
# frozen_string_literal: true

module Cockpit3000
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
        [Frames.rainbow_text(@title, frame_num).to_s, ""]
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

      result = " " * bar_width

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

        # Build the colored character
        result = result[0...pos] + "#{color}#{ch}#{ANSI::RESET}" + (result[(pos + 1)..] || "")
      end

      # Matrix rain in empty space
      if @mode == :matrix && @animated
        bar_width.times do |i|
          if result[i] == " " && rand < 0.03
            result = result[0...i] + "#{ANSI::DIM}#{ANSI.palette_color(:matrix, rand)}#{["0", "1"].sample}#{ANSI::RESET}" + (result[(i + 1)..] || "")
          end
        end
      end

      result
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
  end
end
```

**Step 4: Add require to cockpit3000.rb**

Add `require_relative "cockpit3000/gantt"` after the existing requires in `lib/cockpit3000.rb`.

**Step 5: Run tests to verify they pass**

Run: `cd "/Users/matti/p/🦜 progress bar none overload 3000 🦑" && ruby test/gantt_test.rb`
Expected: 7 tests, 0 failures

**Step 6: Commit**

```bash
cd "/Users/matti/p/🦜 progress bar none overload 3000 🦑"
git add lib/cockpit3000/gantt.rb lib/cockpit3000.rb test/gantt_test.rb
git commit -m "feat: add Cockpit3000::Gantt module with Tufte-inspired defaults"
```

---

### Task 2: SVG export

**Files:**
- Modify: `lib/cockpit3000/gantt.rb` (add `render_svg` method)
- Modify: `test/gantt_test.rb` (add SVG tests)

**Step 1: Write failing tests**

```ruby
# Add to test/gantt_test.rb
def test_render_svg_returns_string
  chart = Cockpit3000::Gantt.new(@tasks, title: "Test")
  svg = chart.render_svg
  assert_kind_of String, svg
  assert svg.start_with?("<svg")
  assert svg.include?("</svg>")
end

def test_svg_contains_task_names
  chart = Cockpit3000::Gantt.new(@tasks)
  svg = chart.render_svg
  assert svg.include?("Task A")
  assert svg.include?("Task B")
end

def test_svg_has_dark_background
  chart = Cockpit3000::Gantt.new(@tasks)
  svg = chart.render_svg
  assert svg.include?("#1a1a2e")
end
```

**Step 2: Run to verify failure**

Run: `cd "/Users/matti/p/🦜 progress bar none overload 3000 🦑" && ruby test/gantt_test.rb`
Expected: FAIL — `render_svg` not defined

**Step 3: Implement render_svg**

Add this method to the `Gantt` class:

```ruby
def render_svg(svg_width: 900, row_height: 25)
  svg_height = 120 + @tasks.size * row_height + 60
  palette_rgb = ->(palette, progress) {
    p = ANSI::CRYSTAL_PALETTE[palette] || ANSI::CRYSTAL_PALETTE[:crystal]
    scaled = progress * (p.length - 1)
    i = scaled.floor
    frac = scaled - i
    c1 = p[i]
    c2 = p[[i + 1, p.length - 1].min]
    r = (c1[0] + (c2[0] - c1[0]) * frac).round
    g = (c1[1] + (c2[1] - c1[1]) * frac).round
    b = (c1[2] + (c2[2] - c1[2]) * frac).round
    "#%02x%02x%02x" % [r, g, b]
  }

  status_palette = { done: :ocean, wip: :sunset, pending: :mono }
  status_opacity = { done: 0.8, wip: 0.6, pending: 0.3 }

  lines = []
  lines << %(<svg xmlns="http://www.w3.org/2000/svg" width="#{svg_width}" height="#{svg_height}" font-family="'SF Mono', 'Menlo', 'Monaco', monospace" font-size="13">)
  lines << %(  <rect width="100%" height="100%" fill="#1a1a2e" rx="12"/>)
  lines << %(  <g fill="#e0e0e0">)

  # Title
  if @title
    lines << %(    <text x="#{svg_width / 2}" y="50" text-anchor="middle" fill="#{palette_rgb.(:ocean, 0.5)}" font-size="18" font-weight="bold">#{escape_svg(@title)}</text>)
    lines << %(    <rect x="20" y="65" width="#{svg_width - 40}" height="1" fill="#333"/>)
  end

  # Header
  y_start = @title ? 90 : 30
  lines << %(    <text x="30" y="#{y_start}" fill="#666" font-size="11">Phase</text>)
  lines << %(    <text x="90" y="#{y_start}" fill="#666" font-size="11">Task</text>)
  lines << %(    <rect x="20" y="#{y_start + 7}" width="#{svg_width - 40}" height="1" fill="#333"/>)

  # Tasks
  bar_left = 350
  bar_right = svg_width - 30
  bar_total = bar_right - bar_left
  scale = bar_total.to_f / @max_time

  @tasks.each_with_index do |task, i|
    y = y_start + 20 + i * row_height
    icon = STATUS_ICONS[task[:status]]
    color = palette_rgb.(status_palette[task[:status]], 0.5)
    opacity = status_opacity[task[:status]]
    name_fill = task[:status] == :done ? "#999" : "#ccc"

    lines << %(    <text x="30" y="#{y}" fill="#00bcd4" font-size="11">#{escape_svg(task[:group])}</text>)
    lines << %(    <text x="70" y="#{y}" fill="#{color}" font-size="11">#{icon}</text>)
    lines << %(    <text x="90" y="#{y}" fill="#{name_fill}" font-size="11">#{escape_svg(task[:name])}</text>)

    rx = bar_left + (task[:start] * scale).round
    rw = (task[:duration] * scale).round
    lines << %(    <rect x="#{rx}" y="#{y - 12}" width="#{rw}" height="16" fill="#{color}" opacity="#{opacity}" rx="2"/>)
  end

  # Progress footer
  done = @tasks.count { |t| t[:status] == :done }
  pct = @tasks.size > 0 ? (done.to_f / @tasks.size * 100).round : 0
  footer_y = y_start + 20 + @tasks.size * row_height + 20
  lines << %(    <rect x="20" y="#{footer_y - 15}" width="#{svg_width - 40}" height="1" fill="#333"/>)
  lines << %(    <text x="30" y="#{footer_y}" fill="#ccc" font-weight="bold" font-size="12">Progress:</text>)
  bar_w = 300
  filled_w = (pct / 100.0 * bar_w).round
  lines << %(    <rect x="120" y="#{footer_y - 12}" width="#{bar_w}" height="16" fill="#333" rx="4"/>)
  lines << %(    <rect x="120" y="#{footer_y - 12}" width="#{filled_w}" height="16" fill="#{palette_rgb.(:ocean, 0.7)}" opacity="0.8" rx="4"/>)
  lines << %(    <text x="#{130 + bar_w}" y="#{footer_y}" fill="#{palette_rgb.(:ocean, 0.7)}" font-size="12">#{pct}% (#{done}/#{@tasks.size})</text>)

  lines << %(  </g>)
  lines << %(</svg>)
  lines.join("\n")
end

private

def escape_svg(text)
  text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
end
```

**Step 4: Run tests**

Run: `cd "/Users/matti/p/🦜 progress bar none overload 3000 🦑" && ruby test/gantt_test.rb`
Expected: 10 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/cockpit3000/gantt.rb test/gantt_test.rb
git commit -m "feat: add SVG export to Cockpit3000::Gantt"
```

---

### Task 3: Migrate sonyctl_gantt.rb to use Cockpit3000::Gantt

**Files:**
- Modify: `/Users/matti/p/SONYHATE3000/ruby/sonyctl_gantt.rb` (rewrite as thin wrapper)

**Step 1: Rewrite sonyctl_gantt.rb**

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# sonyctl Gantt chart progress dashboard
# Now powered by Cockpit3000::Gantt

require "cockpit3000"

TASKS = [
  { name: "sonyctl.rb v1",         group: "P1",  start: 0,  duration: 8,  status: :done,    progress: 1.0 },
  { name: "AudioRecorder/record",  group: "P1",  start: 8,  duration: 6,  status: :done,    progress: 1.0 },
  { name: "sonyctl-snap.swift",    group: "P2",  start: 8,  duration: 5,  status: :done,    progress: 1.0 },
  { name: "sonyctl-live.swift",    group: "P3",  start: 8,  duration: 12, status: :done,    progress: 1.0 },
  { name: "Shell aliases",         group: "P4",  start: 14, duration: 2,  status: :done,    progress: 1.0 },
  { name: "Test suite v1",         group: "P5",  start: 14, duration: 4,  status: :done,    progress: 1.0 },
  { name: "Nanoleaf API client",   group: "P6",  start: 20, duration: 6,  status: :check },
  { name: "Light cmds in sonyctl", group: "P6",  start: 20, duration: 6,  status: :check },
  { name: "AI+Light in live app",  group: "P7",  start: 22, duration: 8,  status: :check },
  { name: "AI model integration",  group: "P7",  start: 24, duration: 6,  status: :check },
  { name: "Compile & sign",        group: "P8",  start: 30, duration: 3,  status: :check },
  { name: "Full test suite",       group: "P9",  start: 30, duration: 6,  status: :check },
  { name: "Fix all errors",        group: "P9",  start: 33, duration: 5,  status: :check },
  { name: "WLAN/Bluetooth",        group: "P10", start: 36, duration: 4,  status: :check },
]

def check_file_status
  {
    "Nanoleaf API client"   => File.exist?(File.expand_path("~/.config/ruby/nanoleaf.rb")),
    "Light cmds in sonyctl" => (File.read(File.expand_path("~/.config/ruby/sonyctl.rb")).include?("cmd_light") rescue false),
    "AI+Light in live app"  => (File.read(File.expand_path("~/.config/swift/sonyctl-live.swift")).include?("NanoleafClient") rescue false),
    "AI model integration"  => (File.read(File.expand_path("~/.config/swift/sonyctl-live.swift")).include?("AIBridge") rescue false),
    "Compile & sign"        => File.exist?(File.expand_path("~/.config/swift/sonyctl-live")) &&
                               (File.mtime(File.expand_path("~/.config/swift/sonyctl-live")) >
                                File.mtime(File.expand_path("~/.config/swift/sonyctl-live.swift")) rescue false),
    "Full test suite"       => (File.read(File.expand_path("~/.config/ruby/sonyctl_test.rb")).include?("nanoleaf") rescue false),
    "Fix all errors"        => false,
    "WLAN/Bluetooth"        => false,
  }
end

# Resolve :check status against file system
checks = check_file_status
resolved_tasks = TASKS.map do |t|
  if t[:status] == :check
    done = checks[t[:name]]
    t.merge(status: done ? :done : :wip, progress: done ? 1.0 : 0.3)
  else
    t
  end
end

mode = ARGV.include?("--rainbow") ? :rainbow :
       ARGV.include?("--fire")    ? :fire :
       ARGV.include?("--matrix")  ? :matrix :
       ARGV.include?("--neon")    ? :neon : :tufte

if ARGV.include?("--svg")
  chart = Cockpit3000::Gantt.new(resolved_tasks,
    title: "SONY! HATE! 3000! — sonyctl v2 build progress",
    mode: mode,
  )
  puts chart.render_svg
  exit
end

chart = Cockpit3000::Gantt.new(resolved_tasks,
  title: "SONY! HATE! 3000! — sonyctl v2 build progress",
  mode: mode,
  show_progress: true,
)

chart.run(fps: mode == :tufte ? 0.04 : 2)  # 25s refresh for tufte, 0.5s for animated
```

**Step 2: Test manually**

Run: `cd "/Users/matti/p/SONYHATE3000" && ruby ruby/sonyctl_gantt.rb --tufte`
Expected: Beautiful Tufte-style Gantt chart with ocean/amber/gray bars

Run: `ruby ruby/sonyctl_gantt.rb --rainbow`
Expected: Rainbow vomit cycling animation

Run: `ruby ruby/sonyctl_gantt.rb --svg > doc/gantt.svg`
Expected: SVG file generated

**Step 3: Commit**

```bash
cd "/Users/matti/p/SONYHATE3000"
# Note: not a git repo, so just verify files are saved
```

---

### Task 4: Update SONYHATE3000 README

**Files:**
- Modify: `/Users/matti/p/SONYHATE3000/README.md` (update Files table, add Cockpit3000 reference)

**Step 1: Update the Files table**

Change the `sonyctl_gantt.rb` entry to note it uses Cockpit3000, and add the gem as a dependency note.

**Step 2: Verify README renders correctly**

Skim the updated README to ensure markdown is valid.

**Step 3: Done**

No commit needed (not a git repo).
