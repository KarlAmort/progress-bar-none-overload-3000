require_relative "test_helper"
require_relative "../lib/cockpit3000"

class ProgressbarCompatTest < Minitest::Test
  def test_progress_bar_create_and_increment
    output = StringIO.new
    bar = ProgressBar.create(total: 3, title: "compat", output: output, fps: 60)

    bar.increment
    bar.increment

    assert_equal 2, bar.progress
    assert_equal 3, bar.total
  ensure
    bar&.finish
  end

  def test_progress_assignment_and_total_resize
    output = StringIO.new
    bar = ProgressBar.create(total: 10, output: output, fps: 60)

    bar.progress = 7
    assert_equal 7, bar.progress

    bar.total = 5
    assert_equal 5, bar.total
    assert_equal 5, bar.progress
  ensure
    bar&.finish
  end

  def test_log_writes_to_output
    output = StringIO.new
    bar = ProgressBar.create(total: 1, output: output, fps: 60)

    bar.log("hello")

    assert_includes output.string, "hello"
  ensure
    bar&.finish
  end
end
