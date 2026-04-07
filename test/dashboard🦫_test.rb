# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/progress🦫bar🦫none"

class DashboardTest < Minitest::Test
  # Fixed, small dimensions so tests are fast and deterministic
  W = 80
  H = 20
  # top_height=3, right_width=28, bottom_height=3 →
  #   sep1 = 5, center_h = 20-3-3-4 = 10, sep2 = 16
  TOP_H   = 3
  RIGHT_W = 28
  BOT_H   = 3

  def setup
    @out  = StringIO.new
    @dash = build_dash
  end

  def teardown
    # Ensure cursor is restored even if a test crashes mid-run
    @out.print ProgressBarNone::ANSI::SHOW_CURSOR rescue nil
  end

  # ── geometry ────────────────────────────────────────────────────────────────

  def test_total_rows_matches_dimensions
    assert_equal H, @dash.total_rows
  end

  def test_pane_names
    assert_equal %i[top center right bottom], @dash.panes.keys
  end

  def test_top_pane_starts_at_row_2
    assert_equal 2, @dash.panes[:top].top_row
    assert_equal 2, @dash.panes[:top].left_col
  end

  def test_right_pane_col_is_after_center_divider
    center_inner_w = W - RIGHT_W - 3
    assert_equal center_inner_w + 3, @dash.panes[:right].left_col
  end

  def test_center_and_right_panes_share_same_top_row
    assert_equal @dash.panes[:center].top_row, @dash.panes[:right].top_row
  end

  def test_bottom_pane_starts_below_center
    center = @dash.panes[:center]
    bottom = @dash.panes[:bottom]
    assert bottom.top_row > center.top_row + center.inner_h
  end

  def test_pane_inner_widths_fit_in_terminal
    left_w  = @dash.panes[:center].inner_w
    right_w = @dash.panes[:right].inner_w
    # Left content + right content + 3 chars for borders = W
    assert_equal W, left_w + right_w + 3
  end

  # ── frame structure ─────────────────────────────────────────────────────────

  def test_frame_contains_title
    frame = @dash.frame_string
    assert_includes frame, "COCKPIT 3000"
  end

  def test_frame_has_top_left_corner
    frame = @dash.frame_string
    assert_includes frame, "╔"
  end

  def test_frame_has_bottom_right_corner
    frame = @dash.frame_string
    assert_includes frame, "╝"
  end

  def test_frame_has_vertical_separator
    frame = @dash.frame_string
    assert_includes frame, "╦"   # top of vertical separator
    assert_includes frame, "╩"   # bottom
  end

  def test_frame_has_horizontal_separators
    frame = @dash.frame_string
    assert_includes frame, "╠"   # left connector of mid rows
    assert_includes frame, "╣"   # right connector
  end

  def test_frame_contains_pane_labels
    frame = @dash.frame_string
    assert_includes frame, "TASKS"
    assert_includes frame, "METRICS"
    assert_includes frame, "LOG"
  end

  def test_frame_positions_row_1_at_top_left
    # Frame starts with cursor-position for (1,1)
    frame = @dash.frame_string
    assert_includes frame, ansi.position(1, 1)
  end

  def test_frame_positions_last_border_row
    frame = @dash.frame_string
    assert_includes frame, ansi.position(H, 1)
  end

  # ── pane content updates ─────────────────────────────────────────────────

  def test_update_sets_pane_content
    @dash.update(:top, ["Hello", "World"])
    assert_equal ["Hello", "World"], @dash.panes[:top].content
  end

  def test_update_each_pane_independently
    @dash.update(:top,    ["top line"])
    @dash.update(:center, ["center line"])
    @dash.update(:right,  ["right line"])
    @dash.update(:bottom, ["bottom line"])

    assert_equal ["top line"],    @dash.panes[:top].content
    assert_equal ["center line"], @dash.panes[:center].content
    assert_equal ["right line"],  @dash.panes[:right].content
    assert_equal ["bottom line"], @dash.panes[:bottom].content
  end

  def test_update_unknown_pane_does_not_raise
    assert_silent { @dash.update(:nonexistent, ["x"]) }
  end

  # ── task management ──────────────────────────────────────────────────────

  def test_add_task_creates_task
    @dash.add_task(:build, message: "compiling")
    assert @dash.tasks.key?(:build)
    assert_equal :pending, @dash.tasks[:build].status
  end

  def test_update_task_changes_status
    @dash.add_task(:test, message: "pending")
    @dash.update_task(:test, status: :running, progress: 0.5, message: "running")
    t = @dash.tasks[:test]
    assert_equal :running, t.status
    assert_in_delta 0.5, t.progress, 0.001
    assert_equal "running", t.message
  end

  def test_update_nonexistent_task_does_not_raise
    assert_silent { @dash.update_task(:ghost, status: :done) }
  end

  def test_add_task_populates_center_pane
    @dash.add_task(:compile, status: :running, progress: 0.3, message: "main.rb")
    center_text = @dash.panes[:center].content.join("\n")
    assert_includes ansi.strip(center_text), "compile"
  end

  def test_done_task_shows_checkmark
    @dash.add_task(:deploy, status: :done, progress: 1.0)
    center_text = @dash.panes[:center].content.join("\n")
    assert_includes ansi.strip(center_text), "✓"
  end

  def test_error_task_shows_cross
    @dash.add_task(:upload, status: :error, message: "timeout")
    center_text = @dash.panes[:center].content.join("\n")
    assert_includes ansi.strip(center_text), "✗"
  end

  def test_running_task_shows_progress_bar
    @dash.add_task(:index, status: :running, progress: 0.6)
    center_text = @dash.panes[:center].content.join("\n")
    stripped = ansi.strip(center_text)
    assert_includes stripped, "█"  # filled portion
    assert_includes stripped, "░"  # empty portion
  end

  # ── log ──────────────────────────────────────────────────────────────────

  def test_log_appends_to_bottom_pane
    # Need a started_at time so format_elapsed works
    @dash.instance_variable_set(:@start_time, Time.now)
    @dash.log("step one done")
    bottom = @dash.panes[:bottom].content.join("\n")
    assert_includes ansi.strip(bottom), "step one done"
  end

  def test_log_scrolls_when_full
    @dash.instance_variable_set(:@start_time, Time.now)
    (BOT_H + 2).times { |i| @dash.log("line #{i}") }
    assert_equal BOT_H, @dash.panes[:bottom].content.length
  end

  # ── write_pane produces cursor-positioned output ──────────────────────────

  def test_write_pane_contains_position_escape
    @dash.update(:top, ["hello"])
    # Trigger a write to the captured output
    @dash.send(:write_pane, @dash.panes[:top])
    output = @out.string
    # Should contain a cursor-position escape pointing into the top pane
    assert_includes output, ansi.position(2, 2)
  end

  def test_write_pane_clips_long_lines
    inner_w = @dash.panes[:top].inner_w
    long_line = "A" * (inner_w + 50)
    @dash.update(:top, [long_line])
    @dash.send(:write_pane, @dash.panes[:top])
    output = ansi.strip(@out.string)
    # No line segment in the output should exceed inner_w "A"s
    refute_includes output, "A" * (inner_w + 1)
  end

  def test_write_pane_pads_short_lines
    @dash.update(:right, ["hi"])
    @dash.send(:write_pane, @dash.panes[:right])
    output = @out.string
    # The raw output string should pad with spaces up to inner_w
    # Check that there's at least some padding after the content
    assert_match(/hi +/, ansi.strip(output))
  end

  def test_each_pane_uses_distinct_row_range
    @dash.update(:top,    ["T"])
    @dash.update(:center, ["C"])
    @dash.update(:right,  ["R"])
    @dash.update(:bottom, ["B"])

    buf = StringIO.new
    dash2 = build_dash(out: buf)
    dash2.update(:top, ["T"]); dash2.update(:center, ["C"])
    dash2.update(:right, ["R"]); dash2.update(:bottom, ["B"])

    %i[top center right bottom].each do |name|
      pane = dash2.panes[name]
      dash2.send(:write_pane, pane)
    end

    # Extract all cursor position rows used
    positions = buf.string.scan(/\e\[(\d+);(\d+)H/).map { |r, c| r.to_i }

    top_rows    = positions.select { |r| r.between?(2, TOP_H + 1) }
    bottom_rows = positions.select { |r| r > H - BOT_H - 1 }

    assert top_rows.any?,    "top pane must write to rows 2..#{TOP_H + 1}"
    assert bottom_rows.any?, "bottom pane must write near the bottom"
  end

  # ── simulated tasks (integration-style) ──────────────────────────────────

  def test_simulated_task_run
    # Run a mini simulation without real timing: add tasks, advance them,
    # verify the dashboard state is internally consistent after each step.

    @dash.instance_variable_set(:@start_time, Time.now)

    @dash.add_task(:compile, status: :pending,  message: "waiting")
    @dash.add_task(:test,    status: :pending,  message: "waiting")
    @dash.add_task(:deploy,  status: :pending,  message: "waiting")

    # Simulate compile running
    @dash.update_task(:compile, status: :running, progress: 0.0, message: "main.rb")
    10.times do |i|
      sleep rand(0.001..0.004)
      @dash.update_task(:compile, progress: (i + 1) / 10.0)
    end
    @dash.update_task(:compile, status: :done, progress: 1.0, message: "OK")
    @dash.log("compile finished")

    # Simulate test running and failing
    @dash.update_task(:test, status: :running, progress: 0.5, message: "suite_a")
    @dash.update_task(:test, status: :error,   message: "assertion failed")
    @dash.log("test FAILED")

    # Simulate deploy skipped
    @dash.update_task(:deploy, status: :done, message: "skipped")

    center_text = ansi.strip(@dash.panes[:center].content.join("\n"))
    bottom_text = ansi.strip(@dash.panes[:bottom].content.join("\n"))

    assert_includes center_text, "✓"    # compile done
    assert_includes center_text, "✗"    # test errored
    assert_includes bottom_text, "compile finished"
    assert_includes bottom_text, "test FAILED"

    # Top pane update with summary
    total    = @dash.tasks.values.count
    done_ct  = @dash.tasks.values.count { |t| t.status == :done }
    error_ct = @dash.tasks.values.count { |t| t.status == :error }
    @dash.update(:top, [
      "Tasks: #{done_ct}/#{total} done, #{error_ct} errors",
    ])
    @dash.update(:right, ["compile  ✓", "test     ✗", "deploy   ✓"])

    assert_equal 1, @dash.panes[:top].content.length
    assert_includes @dash.panes[:top].content[0], "done"
    assert_equal 3, @dash.panes[:right].content.length
  end

  def test_all_four_panes_update_independently_without_interfering
    buf = StringIO.new
    dash = build_dash(out: buf)
    dash.instance_variable_set(:@start_time, Time.now)

    # Capture output of each pane update in isolation
    snapshots = {}
    %i[top center right bottom].each do |name|
      dash.update(name, ["#{name} data"])
      before = buf.string.dup
      dash.send(:write_pane, dash.panes[name])
      snapshots[name] = buf.string[before.length..]
    end

    # Each write affects only its own pane row range
    top_row    = dash.panes[:top].top_row
    center_row = dash.panes[:center].top_row
    right_row  = dash.panes[:right].top_row
    bottom_row = dash.panes[:bottom].top_row

    assert_includes snapshots[:top],    ansi.position(top_row, 2)
    assert_includes snapshots[:center], ansi.position(center_row, 2)
    assert_includes snapshots[:right],  ansi.position(right_row, dash.panes[:right].left_col)
    assert_includes snapshots[:bottom], ansi.position(bottom_row, 2)

    # A pane's snapshot must NOT contain another pane's row
    refute_includes snapshots[:top], ansi.position(bottom_row, 2)
    refute_includes snapshots[:bottom], ansi.position(top_row, 2)
  end

  private

  def build_dash(out: @out)
    ProgressBarNone::Dashboard.new(
      title:         "COCKPIT 3000",
      width:         W,
      height:        H,
      top_height:    TOP_H,
      right_width:   RIGHT_W,
      bottom_height: BOT_H,
      fps:           60,
      output:        out,
    )
  end

  def ansi
    ProgressBarNone::ANSI
  end
end
