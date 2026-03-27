require_relative "test_helper"
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

  def test_render_svg_returns_valid_svg
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

  def test_all_modes_render_without_error
    [:tufte, :phase, :rainbow, :fire, :matrix, :neon].each do |mode|
      chart = Cockpit3000::Gantt.new(@tasks, mode: mode)
      assert_kind_of String, chart.to_s, "Mode #{mode} failed to render"
    end
  end
end
