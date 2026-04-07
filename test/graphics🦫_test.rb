# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/progress🦫bar🦫none"

class GraphicsTest < Minitest::Test
  include ProgressBarNone

  # ── detection ────────────────────────────────────────────────────────────────

  def test_kitty_supported_by_ghostty_term
    with_env("TERM" => "xterm-ghostty", "TERM_PROGRAM" => nil,
             "GHOSTTY_RESOURCES_DIR" => nil) do
      assert Graphics.kitty_supported?
    end
  end

  def test_kitty_supported_by_ghostty_resources_dir
    with_env("TERM" => "xterm-256color", "TERM_PROGRAM" => nil,
             "GHOSTTY_RESOURCES_DIR" => "/usr/share/ghostty") do
      assert Graphics.kitty_supported?
    end
  end

  def test_kitty_supported_by_kitty_term
    with_env("TERM" => "xterm-kitty", "TERM_PROGRAM" => nil,
             "GHOSTTY_RESOURCES_DIR" => nil) do
      assert Graphics.kitty_supported?
    end
  end

  def test_kitty_supported_by_term_program
    with_env("TERM" => "xterm-256color", "TERM_PROGRAM" => "WezTerm",
             "GHOSTTY_RESOURCES_DIR" => nil) do
      assert Graphics.kitty_supported?
    end
  end

  def test_kitty_not_supported_in_unknown_terminal
    with_env("TERM" => "xterm-256color", "TERM_PROGRAM" => "tmux",
             "GHOSTTY_RESOURCES_DIR" => nil) do
      refute Graphics.kitty_supported?
    end
  end

  def test_iterm_supported
    with_env("TERM_PROGRAM" => "iTerm.app", "LC_TERMINAL" => nil) do
      assert Graphics.iterm_supported?
    end
  end

  def test_iterm_not_supported_unknown
    with_env("TERM_PROGRAM" => "Terminal", "LC_TERMINAL" => nil) do
      refute Graphics.iterm_supported?
    end
  end

  # ── escape sequence structure ─────────────────────────────────────────────

  def test_kitty_encode_starts_and_ends_correctly
    seq = Graphics.kitty_display_image(fixture_png)
    assert seq.start_with?(Graphics::KITTY_START),
           "must start with APC introducer"
    assert seq.end_with?(Graphics::KITTY_END),
           "must end with string terminator"
  end

  def test_kitty_encode_contains_transmit_action
    seq = Graphics.kitty_display_image(fixture_png)
    assert_includes first_chunk_ctrl(seq), "a=T"
  end

  def test_kitty_encode_png_format
    seq = Graphics.kitty_display_image(fixture_png)
    assert_includes first_chunk_ctrl(seq), "f=100"
  end

  def test_kitty_encode_direct_transmission
    seq = Graphics.kitty_display_image(fixture_png)
    assert_includes first_chunk_ctrl(seq), "t=d"
  end

  def test_kitty_encode_suppresses_response
    seq = Graphics.kitty_display_image(fixture_png)
    assert_includes first_chunk_ctrl(seq), "q=1"
  end

  def test_kitty_encode_cols_rows_in_first_chunk
    seq = Graphics.kitty_display_image(fixture_png, cols: 20, rows: 5)
    ctrl = first_chunk_ctrl(seq)
    assert_includes ctrl, "c=20"
    assert_includes ctrl, "r=5"
  end

  def test_kitty_encode_image_id_in_first_chunk
    seq = Graphics.kitty_display_image(fixture_png, image_id: 42)
    assert_includes first_chunk_ctrl(seq), "i=42"
  end

  # ── single vs multi-chunk ─────────────────────────────────────────────────

  def test_small_data_is_single_chunk
    seq = Graphics.kitty_display_image(fixture_png)
    # Only one APC sequence → no continuation chunk
    chunks = seq.scan(/\e_G[^\e]*\e\\/)
    assert_equal 1, chunks.length
    assert_includes first_chunk_ctrl(seq), "m=0"
  end

  def test_large_data_splits_into_multiple_chunks
    # Build a large enough PNG-like payload to force chunking
    big_data = "X" * (Graphics::KITTY_CHUNK_SIZE * 2)
    seq = kitty_encode_direct(big_data, format: 100)

    chunks = seq.scan(/\e_G[^\e]*\e\\/)
    assert chunks.length >= 2, "large data must produce multiple chunks"

    # First chunk: m=1 (more to come)
    assert_includes chunks.first, "m=1"
    # Last chunk: m=0 (done)
    assert_includes chunks.last, "m=0"
  end

  def test_subsequent_chunks_lack_full_control_data
    big_data = "X" * (Graphics::KITTY_CHUNK_SIZE * 2)
    seq = kitty_encode_direct(big_data, format: 100)

    chunks = seq.scan(/\e_G[^\e]*\e\\/)
    # Strip APC wrapper to get just the control;payload part
    second_ctrl = chunks[1].delete_prefix(Graphics::KITTY_START)
                            .delete_suffix(Graphics::KITTY_END)
                            .split(";", 2).first

    # Subsequent chunks must NOT repeat a=, f=, t=, q=
    refute_match(/\ba=/, second_ctrl)
    refute_match(/\bf=/, second_ctrl)
    refute_match(/\bt=/, second_ctrl)
  end

  def test_payload_is_valid_base64
    seq = Graphics.kitty_display_image(fixture_png)
    payload = seq.split(";", 2).last.delete_suffix(Graphics::KITTY_END)
    assert_match(/\A[A-Za-z0-9+\/]+=*\z/, payload)
  end

  # ── kitty_display_pixels ──────────────────────────────────────────────────

  def test_kitty_display_pixels_format_is_rgba
    rgba = "\xFF\x00\x00\xFF" * 4  # 2×2 red pixels
    seq  = Graphics.kitty_display_pixels(rgba, pixel_width: 2, pixel_height: 2)
    assert_includes first_chunk_ctrl(seq), "f=32"
  end

  def test_kitty_display_pixels_carries_dimensions
    rgba = "\xFF\x00\x00\xFF" * 10 * 3
    seq  = Graphics.kitty_display_pixels(rgba, pixel_width: 10, pixel_height: 3)
    ctrl = first_chunk_ctrl(seq)
    assert_includes ctrl, "s=10"
    assert_includes ctrl, "v=3"
  end

  def test_kitty_display_pixels_payload_decodes_to_original
    rgba = (0..255).map { |i| [i, 255 - i, i / 2, 255] }.flatten.pack("C*")
    seq  = Graphics.kitty_display_pixels(rgba, pixel_width: 256, pixel_height: 1)

    all_payload = seq.scan(/\e_G[^\e]*\e\\/).map do |chunk|
      chunk.delete_prefix(Graphics::KITTY_START)
           .delete_suffix(Graphics::KITTY_END)
           .split(";", 2).last
    end.join

    decoded = Base64.decode64(all_payload)
    assert_equal rgba, decoded
  end

  # ── kitty_progress_bar ────────────────────────────────────────────────────

  def test_kitty_progress_bar_returns_kitty_sequence
    seq = Graphics.kitty_progress_bar(0.5)
    assert seq.start_with?(Graphics::KITTY_START)
    assert_includes first_chunk_ctrl(seq), "f=32"
  end

  def test_kitty_progress_bar_pixel_dimensions
    seq  = Graphics.kitty_progress_bar(0.5, width_px: 200, height_px: 10)
    ctrl = first_chunk_ctrl(seq)
    assert_includes ctrl, "s=200"
    assert_includes ctrl, "v=10"
  end

  def test_kitty_progress_bar_full_progress
    seq = Graphics.kitty_progress_bar(1.0, width_px: 100, height_px: 4,
                                       palette: :fire)
    # Should still produce a valid sequence
    assert seq.start_with?(Graphics::KITTY_START)
  end

  def test_kitty_progress_bar_zero_progress
    seq = Graphics.kitty_progress_bar(0.0, width_px: 100, height_px: 4)
    assert seq.start_with?(Graphics::KITTY_START)
  end

  def test_kitty_progress_bar_pixel_data_size
    width_px  = 80
    height_px = 8
    # Decode all payload chunks back to raw bytes
    seq = Graphics.kitty_progress_bar(0.5, width_px: width_px, height_px: height_px)
    raw = decode_all_chunks(seq)
    # 4 bytes per pixel (RGBA)
    assert_equal width_px * height_px * 4, raw.bytesize
  end

  def test_kitty_progress_bar_all_palettes
    ANSI::CRYSTAL_PALETTE.each_key do |palette|
      seq = Graphics.kitty_progress_bar(0.5, width_px: 10, height_px: 2,
                                         palette: palette)
      assert seq.start_with?(Graphics::KITTY_START),
             "palette #{palette.inspect} did not produce a Kitty sequence"
    end
  end

  def test_kitty_progress_bar_clamps_progress
    # Values outside 0..1 must not crash
    Graphics.kitty_progress_bar(-0.5, width_px: 10, height_px: 2)
    Graphics.kitty_progress_bar(1.5, width_px: 10, height_px: 2)
  end

  # ── kitty_delete_image ────────────────────────────────────────────────────

  def test_kitty_delete_by_id
    seq = Graphics.kitty_delete_image(7)
    assert seq.start_with?(Graphics::KITTY_START)
    assert_includes seq, "a=d"
    assert_includes seq, "i=7"
  end

  def test_kitty_delete_all
    seq = Graphics.kitty_delete_image(0, what: "A")
    assert_includes seq, "d=A"
  end

  # ── display_image dispatch ─────────────────────────────────────────────────

  def test_display_image_missing_file_returns_empty
    assert_equal "", Graphics.display_image("/no/such/file.png")
  end

  def test_display_image_uses_kitty_when_supported
    with_env("TERM" => "xterm-ghostty", "GHOSTTY_RESOURCES_DIR" => nil,
             "TERM_PROGRAM" => nil) do
      seq = Graphics.display_image(fixture_png)
      assert seq.start_with?(Graphics::KITTY_START)
    end
  end

  def test_display_image_falls_back_to_ascii
    with_env("TERM" => "xterm-256color", "TERM_PROGRAM" => "Terminal",
             "LC_TERMINAL" => nil, "GHOSTTY_RESOURCES_DIR" => nil) do
      out = Graphics.display_image(fixture_png, cols: 10, rows: 4)
      assert_includes out, "┌"
      assert_includes out, "└"
    end
  end

  # ── ascii_placeholder ─────────────────────────────────────────────────────

  def test_ascii_placeholder_dimensions
    box = Graphics.ascii_placeholder(12, 5)
    lines = box.lines
    assert_equal 5, lines.length
    # Top/bottom borders: 2 corners + inner_w dashes = cols chars wide
    inner = lines.first.chomp.delete("┌┐")
    assert_equal 10, inner.length
  end

  # ── ascii_art ─────────────────────────────────────────────────────────────

  def test_ascii_art_fire
    out = Graphics.ascii_art(:fire, 0)
    assert_includes out, "\e["
    refute_empty out
  end

  def test_ascii_art_all_named
    %i[fire nyan rocket celebration skull matrix loading].each do |name|
      refute_empty Graphics.ascii_art(name, 0),
                   "ascii_art(#{name.inspect}) returned empty string"
    end
  end

  def test_ascii_art_unknown_returns_empty
    assert_equal "", Graphics.ascii_art(:bogus)
  end

  private

  def fixture_png
    # 1×1 red pixel, minimal valid PNG
    path = File.join(__dir__, "fixtures", "red_pixel.png")
    unless File.exist?(path)
      require "fileutils"
      FileUtils.mkdir_p(File.dirname(path))
      # Minimal 1×1 red PNG (binary-safe, hand-crafted)
      File.binwrite(path, minimal_red_png)
    end
    path
  end

  # A valid minimal 1×1 red PNG (67 bytes)
  def minimal_red_png
    # PNG signature + IHDR + IDAT (1x1 red, no alpha) + IEND
    [
      "89504e470d0a1a0a",                          # PNG signature
      "0000000d49484452" \
      "00000001000000010802000000907753de",          # IHDR 1x1 RGB
      "0000000c49444154" \
      "789c6260f8cf0000000200012721bc3d",            # IDAT (zlib compressed)
      "0000000049454e44ae426082",                   # IEND
    ].join.scan(/../).map { |b| b.to_i(16) }.pack("C*")
  end

  def first_chunk_ctrl(seq)
    # Extract ctrl keys between KITTY_START and the first semicolon
    seq.delete_prefix(Graphics::KITTY_START).split(";", 2).first
  end

  def decode_all_chunks(seq)
    payloads = seq.scan(/\e_G[^\e]*\e\\/).map do |chunk|
      chunk.delete_prefix(Graphics::KITTY_START)
           .delete_suffix(Graphics::KITTY_END)
           .split(";", 2).last
    end
    Base64.decode64(payloads.join)
  end

  # Temporarily override ENV keys; nil value = delete the key
  def with_env(overrides)
    original = overrides.to_h { |k, _| [k, ENV[k.to_s]] }
    overrides.each do |k, v|
      if v.nil?
        ENV.delete(k.to_s)
      else
        ENV[k.to_s] = v
      end
    end
    yield
  ensure
    overrides.each_key do |k|
      orig = original[k]
      if orig.nil?
        ENV.delete(k.to_s)
      else
        ENV[k.to_s] = orig
      end
    end
  end

  # Bypass .display_image to directly test the encoder
  def kitty_encode_direct(data, format:)
    # Use send to access private method for white-box testing
    Graphics.send(:kitty_encode, data, format: format)
  end
end
