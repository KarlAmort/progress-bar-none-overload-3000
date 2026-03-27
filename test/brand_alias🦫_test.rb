require "minitest/autorun"
require_relative "../lib/cockpit3000"

class BrandAliasTest < Minitest::Test
  def test_brand_name_constant
    assert_equal "PROGRESS🦫BAR🦫NONE", Cockpit3000::BRAND_NAME
  end

  def test_upper_alias
    assert_equal Cockpit3000, PROGRESSBARNONE
    assert_equal Cockpit3000::Bar, PROGRESSBARNONE::Bar
  end

  def test_camel_alias
    assert_equal Cockpit3000, ProgressBarNone
    assert_equal Cockpit3000::MultiBar, ProgressBarNone::MultiBar
  end
end
