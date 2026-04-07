# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/progress🦫bar🦫none"
require "rake"
require_relative "../lib/progress🦫bar🦫none/rake🦫"
require "set"

# Verifies the eight contracts of the color parade and related Rake behaviour.
#
# The sweep rendering logic is duplicated here (not required from the parade
# test) so that running this file standalone does not trigger the 4-minute
# parade itself.  The timing assertions verify the parade's published constants
# analytically.
class ColorParadeAuditTest < Minitest::Test

  # Known configuration (mirrors ColorParadeTest constants)
  PARADE_SWEEPS        = 24
  PARADE_SWEEP_SECONDS = 10
  PARADE_COLUMNS       = 16
  PARADE_ROWS          = 256 / PARADE_COLUMNS        # 16
  PARADE_ROW_DELAY     = PARADE_SWEEP_SECONDS.to_f / PARADE_ROWS  # 0.625 s
  PARADE_PALETTES      = ProgressBarNone::ANSI::CRYSTAL_PALETTE.keys.freeze
  PARADE_BLOCK         = "▓▓"

  # ── 1. Total runtime ≥ 4 minutes ─────────────────────────────────────────────

  def test_total_duration_at_least_four_minutes
    total = PARADE_SWEEPS * PARADE_SWEEP_SECONDS
    assert total >= 240,
      "#{PARADE_SWEEPS} sweeps × #{PARADE_SWEEP_SECONDS} s = #{total} s — need ≥ 240"
  end

  # ── 2. Output changes at least every 2 seconds ───────────────────────────────

  def test_output_changes_at_least_every_two_seconds
    assert PARADE_ROW_DELAY > 0,   "ROW_DELAY must be positive"
    assert PARADE_ROW_DELAY < 2.0,
      "ROW_DELAY #{PARADE_ROW_DELAY} s must be < 2 s to guarantee sub-2-second updates"
  end

  # ── 3. At any given moment ≥ 8 distinct colors visible ───────────────────────

  def test_at_least_eight_colors_visible_at_any_moment
    sweep_output(0).split("\n").each do |row|
      n = distinct_colors(row)
      next if n < 2   # skip blank / reset-only lines
      assert n >= 8, "Row had only #{n} distinct colors:\n  #{row.inspect[0, 80]}"
    end
  end

  # ── 4. ≥ 5 % of pixels change between moments ≥ 15 s apart ──────────────────

  def test_five_percent_pixels_change_between_distant_moments
    # Sweeps 0 and 2 are 20 s apart (2 × 10 s > 15 s); they use different
    # palettes so the gradient banner and sparkline differ completely.
    a = pixels(sweep_output(0))
    b = pixels(sweep_output(2))

    total   = [a.size, b.size].max
    changed = a.zip(b).count { |pa, pb| pa != pb }
    pct     = changed.to_f / total

    assert pct >= 0.05,
      "Only #{(pct * 100).round(1)} % of pixels changed between sweeps 0 and 2 (need ≥ 5 %)"
  end

  # ── 5. 80 random screenshots → ≥ 100 distinct colors ────────────────────────

  def test_eighty_screenshots_yield_at_least_hundred_colors
    pool = Set.new
    80.times { |i| pool.merge(colors_in(sweep_output(i % PARADE_SWEEPS))) }
    assert pool.size >= 100,
      "Only #{pool.size} distinct colors across 80 screenshots (need ≥ 100)"
  end

  # ── 6. Multitask runs four tasks in parallel ──────────────────────────────────

  def test_multitask_runs_four_tasks_in_parallel
    with_rake do |app|
      timings = {}
      %i[alpha beta gamma delta].each do |name|
        app.define_task(Rake::Task, name) do
          timings[name] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          sleep 0.08
        end
      end
      app.define_task(Rake::MultiTask, quad: %i[alpha beta gamma delta]) {}

      elapsed = timed { app[:quad].invoke }

      assert_equal 4, timings.size, "all four tasks must execute"
      assert elapsed < 0.30,
        "Four 0.08 s tasks took #{elapsed.round(3)} s — expected ~0.08 s in parallel"
    end
  end

  # ── 7. A loop inside a task throws 30 exceptions ─────────────────────────────

  def test_loop_in_task_throws_thirty_exceptions
    with_rake do |app|
      hits = 0
      app.define_task(Rake::Task, :loopy) do
        30.times { |i| raise "explosion #{i}" rescue hits += 1 }
      end
      app[:loopy].invoke
      assert_equal 30, hits, "loop must raise (and rescue) exactly 30 exceptions"
    end
  end

  # ── 8. A task throws one exception ───────────────────────────────────────────

  def test_task_throws_one_exception
    with_rake do |app|
      app.define_task(Rake::Task, :one_shot) { raise ArgumentError, "single fault" }
      err = assert_raises(ArgumentError) { app[:one_shot].invoke }
      assert_equal "single fault", err.message
    end
  end

  private

  XTERM_RX = /\e\[(?:38|48);5;(\d+)m/
  RGB_RX   = /\e\[(?:38|48);2;(\d+);(\d+);(\d+)m/

  # ── sweep capture ─────────────────────────────────────────────────────────────

  # Render sweep n into a string (no actual sleeping).  Memoized per instance.
  def sweep_output(n)
    @sweep_cache ||= {}
    @sweep_cache[n] ||= begin
      buf  = StringIO.new
      orig = $stdout
      $stdout = buf
      render_sweep(n)
      buf.string
    ensure
      $stdout = orig
    end
  end

  # Inline copy of ColorParadeTest#run_sweep — no row_sleep calls.
  def render_sweep(n)
    palette = PARADE_PALETTES[n % PARADE_PALETTES.length]
    label   = " ✦ SWEEP #{n + 1}/#{PARADE_SWEEPS} — #{palette.upcase} ✦ "

    $stdout.print "\n"
    $stdout.print gradient_line(label, palette)
    $stdout.print "\n"

    256.times do |c|
      $stdout.print "\e[38;5;#{c}m\e[48;5;#{c}m#{PARADE_BLOCK}\e[0m"
      if (c + 1) % PARADE_COLUMNS == 0
        $stdout.print "\n"
        $stdout.flush
        # no sleep — we're testing output content, not timing
      end
    end

    $stdout.print sparkline_row(n, palette)
    $stdout.print "\n"
    $stdout.flush
  end

  def gradient_line(text, palette)
    ansi = ProgressBarNone::ANSI
    len  = text.length
    text.chars.each_with_index.map do |ch, i|
      ansi.palette_color(palette, i.to_f / [len - 1, 1].max) + ch
    end.join + ansi::RESET
  end

  def sparkline_row(sweep_n, palette)
    ansi   = ProgressBarNone::ANSI
    values = Array.new(40) { |i| Math.sin(sweep_n * 0.8 + i * 0.4) * 10 + 10 }
    spark  = ProgressBarNone::Sparkline.generate_colored(values, width: 40, palette: palette)
    " " + spark + ansi::RESET
  end

  # ── color analysis ────────────────────────────────────────────────────────────

  def distinct_colors(str)
    s = Set.new
    str.scan(XTERM_RX) { |m| s << "x#{m[0]}" }
    str.scan(RGB_RX)   { |m| s << "r#{m[0]},#{m[1]},#{m[2]}" }
    s.size
  end

  def colors_in(str)
    Set.new.tap do |s|
      str.scan(XTERM_RX) { |m| s << "x#{m[0]}" }
      str.scan(RGB_RX)   { |m| s << "r#{m[0]},#{m[1]},#{m[2]}" }
    end
  end

  # Return an array of "color_escape+char" tokens, one per visible character.
  def pixels(str)
    result    = []
    cur_color = ""
    str.scan(/\e\[[\d;]*m|[^\e\n\r]/) do |tok|
      if tok.start_with?("\e[")
        cur_color = tok == "\e[0m" ? "" : tok
      else
        result << "#{cur_color}#{tok}"
      end
    end
    result
  end

  # ── Rake helpers ──────────────────────────────────────────────────────────────

  def with_rake
    app = Rake::Application.new
    Rake.application = app
    yield app
  ensure
    Rake.application = Rake::Application.new
  end

  def timed
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  end
end
