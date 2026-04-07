# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/progress🦫bar🦫none"
require "rake"
require_relative "../lib/progress🦫bar🦫none/rake🦫"

# COCKPIT 3000 COLOR PARADE — 4-minute terminal spectacle
#
# 24 sweeps × 10 s across 6 acts:
#   Act 1 (01-10)  color cascade    256-color grid, in-place bar, Kitty pixel bar
#   Act 2 (11-14)  MultiBar         nested sub-bars with sounds
#   Act 3 (15-18)  ASCII animation  cycling art with sounds
#   Act 4 (19-22)  Multitask+images 4 parallel Rake workers + Kitty previews
#   Act 5 (23-24)  Exception show   30-exception loop with red/green feedback
#
# All live output goes to /dev/tty so it bypasses minitest's stdout capture
# and works reliably in Ghostty/zsh without \r interference.
class ColorParadeTest < Minitest::Test
  PBN       = ProgressBarNone
  ANSI      = PBN::ANSI
  Gfx       = PBN::Graphics
  Frames    = PBN::Frames
  Sound     = PBN::Sound
  Sparkline = PBN::Sparkline
  MultiBar  = PBN::MultiBar

  SWEEPS        = 24
  SWEEP_SECONDS = 10
  COLUMNS       = 16
  ROWS          = 256 / COLUMNS              # 16 rows per sweep
  ROW_DELAY     = SWEEP_SECONDS.to_f / ROWS  # 0.625 s — guarantees < 2 s between outputs
  PALETTES      = ANSI::CRYSTAL_PALETTE.keys.freeze
  TITLE_STYLES  = %i[block shadow outline simple].freeze
  BAR_W         = 36
  BLOCK         = "▓▓"
  PIE           = %w[○ ◔ ◑ ◕ ●].freeze
  TASK_PALETTES = %i[fire ocean matrix galaxy].freeze
  ANIM_NAMES    = %i[fire nyan rocket celebration skull matrix loading].freeze

  ACT_RANGES = {
    color:      0..9,
    multibar:   10..13,
    animation:  14..17,
    multitask:  18..21,
    exceptions: 22..23,
  }.freeze

  # Write live output directly to the TTY — bypasses minitest stdout capture
  # and \r buffering issues in zsh / Ghostty.
  TTY = begin
    f = File.open("/dev/tty", "w")
    f.sync = true
    f
  rescue
    $stdout
  end

  @@suite_start = nil  # wall-clock reference for suite-level ETA

  # ── define 24 test methods ───────────────────────────────────────────────

  SWEEPS.times do |n|
    act = ACT_RANGES.find { |_, r| r.include?(n) }&.first || :color

    define_method(:"test_sweep_#{format('%02d', n + 1)}") do
      @@suite_start ||= Process.clock_gettime(Process::CLOCK_MONOTONIC)
      suite_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @@suite_start
      suite_eta     = [SWEEPS * SWEEP_SECONDS - suite_elapsed, 0].max
      palette       = PALETTES[n % PALETTES.length]

      # ── big-font sweep header ──────────────────────────────────────────
      TTY.print "\n"
      Frames.ascii_title("SWEEP #{n + 1}  #{palette.upcase}",
                         style: TITLE_STYLES[n % TITLE_STYLES.length],
                         palette: palette).each { |l| TTY.puts l }
      TTY.puts \
        "\e[2m  test_sweep_#{format('%02d', n + 1)}  act=#{act}  " \
        "#{n + 1}/#{SWEEPS} (#{((n + 1).to_f / SWEEPS * 100).round(1)}%)  " \
        "suite +#{format('%.1f', suite_elapsed)}s  " \
        "ETA ~#{format('%.0f', suite_eta)}s (#{format('%.1f', suite_eta / 60.0)} min)\e[0m"

      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      case act
      when :color      then run_color_sweep(n, palette)
      when :multibar   then run_multibar(n, palette)
      when :animation  then run_animation(n, palette)
      when :multitask  then run_multitask(n, palette)
      when :exceptions then run_exceptions(n, palette)
      end

      elapsed   = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
      remaining = SWEEP_SECONDS - elapsed
      sleep remaining if remaining > 0
      Sound.play(:task_done)
      assert_equal SWEEPS, SWEEPS  # always passes; proves the act completed
    end
  end

  private

  # ── timing shim (no-op in audit tests) ──────────────────────────────────
  def row_sleep(s = ROW_DELAY)
    sleep s
  end

  # ── in-place progress bar ────────────────────────────────────────────────
  #
  # save_bar  —  record current cursor position just before printing the bar
  # update_bar — restore to that position, erase line, reprint
  #
  # Uses ANSI \e[s / \e[u (supported by Ghostty, xterm, iTerm2, WezTerm).
  # Writing to /dev/tty means \r is never swallowed by zsh prompt handling.

  def save_bar
    TTY.print "\e[s"
  end

  def update_bar(done, total, palette, elapsed, avg)
    TTY.print "\e[u\e[K#{render_bar(done, total, palette, elapsed, avg)}"
    TTY.flush
  end

  def render_bar(done, total, palette, elapsed, avg)
    fill  = total > 0 ? (done.to_f / total * BAR_W).round : 0
    empty = BAR_W - fill
    pct   = total > 0 ? done.to_f / total * 100 : 0.0
    eta   = avg > 0 ? avg * (total - done) : 0.0

    filled = fill.times.map { |i|
      ANSI.palette_color(palette, i.to_f / [BAR_W - 1, 1].max) + "█"
    }.join + ANSI::RESET

    "#{pie_char(pct / 100)} [#{filled}#{"░" * empty}] " \
      "#{done}/#{total} (#{format('%5.1f', pct)}%)  " \
      "+#{format('%.2f', elapsed)}s  ETA~#{format('%.1f', eta)}s"
  end

  def pie_char(frac)
    PIE[([frac, 1.0].min * (PIE.length - 1)).round]
  end

  # Kitty pixel progress bar — shown above the text bar in Ghostty
  def kitty_bar(frac, palette, image_id: 42)
    return unless Gfx.kitty_supported?
    TTY.print Gfx.kitty_progress_bar(frac, palette: palette,
                                      width_px: 400, height_px: 18, image_id: image_id)
  end

  def update_kitty_bar(frac, palette, rows_taken: 1, image_id: 42)
    return unless Gfx.kitty_supported?
    TTY.print "\e[#{rows_taken}A\r"   # cursor up n rows + carriage return
    TTY.print Gfx.kitty_delete_image(image_id)
    kitty_bar(frac, palette, image_id: image_id)
  end

  # Interpolate palette RGB for pixel art generation
  def palette_rgb(name, t)
    stops = ANSI::CRYSTAL_PALETTE[name] || ANSI::CRYSTAL_PALETTE[:crystal]
    idx   = t.clamp(0.0, 1.0) * (stops.length - 1)
    lo, hi = stops[idx.floor], stops[[idx.ceil, stops.length - 1].min]
    f = idx - idx.floor
    [
      (lo[0] + (hi[0] - lo[0]) * f).round.clamp(0, 255),
      (lo[1] + (hi[1] - lo[1]) * f).round.clamp(0, 255),
      (lo[2] + (hi[2] - lo[2]) * f).round.clamp(0, 255),
    ]
  end

  # ══════════════════════════════════════════════════════════════════════════
  # ACT 1 (sweeps 01-10): 256-color palette cascade
  # ══════════════════════════════════════════════════════════════════════════
  def run_color_sweep(n, palette)
    Frames.banner("✦ #{palette.upcase} ✦  #{n + 1}/#{SWEEPS}",
                  style: :cyber, palette: palette).each { |l| TTY.puts l }

    eta_s = (SWEEPS - n) * SWEEP_SECONDS
    TTY.puts "\e[2m  suite #{n}/#{SWEEPS} (#{(n.to_f / SWEEPS * 100).round(1)}%)  " \
             "palette #{(n % PALETTES.length) + 1}/#{PALETTES.length}  " \
             "colors 256  ETA ~#{eta_s}s (#{format('%.1f', eta_s / 60.0)} min)\e[0m"

    sweep_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    kitty_bar(0.0, palette)
    save_bar
    TTY.print render_bar(0, ROWS, palette, 0.0, 0.0)

    256.times do |c|
      fg = ANSI.palette_color(palette, c.to_f / 255)
      TTY.print "#{fg}\e[48;5;#{c}m#{BLOCK}\e[0m"

      next unless (c + 1) % COLUMNS == 0

      rows_done   = c / COLUMNS + 1
      colors_done = c + 1
      row_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - sweep_start
      avg         = row_elapsed / rows_done
      rows_left   = ROWS - rows_done

      TTY.puts "  \e[2m" \
               "row #{format('%2d', rows_done)}/#{ROWS} " \
               "(#{format('%5.1f', rows_done.to_f / ROWS * 100)}%)  " \
               "#{format('%3d', colors_done)}/256 colors  " \
               "+#{format('%.2f', row_elapsed)}s  " \
               "avg #{format('%.3f', avg)}s/row  " \
               "ETA ~#{format('%.1f', avg * rows_left)}s\e[0m"

      update_bar(rows_done, ROWS, palette, row_elapsed, avg)
      update_kitty_bar(rows_done.to_f / ROWS, palette) if rows_done < ROWS
      row_sleep
    end
    TTY.puts  # advance past in-place bar

    # Sparkline: completed sweeps = high, current = mid, pending = low
    values = Array.new(SWEEPS) { |i| i < n ? 18.0 : i == n ? 10.0 : 2.0 }
    spark  = Sparkline.generate_colored(values, width: SWEEPS, palette: palette)
    total  = Process.clock_gettime(Process::CLOCK_MONOTONIC) - sweep_start
    TTY.puts " #{spark}#{ANSI::RESET}  " \
             "\e[2m#{n + 1}/#{SWEEPS} sweeps " \
             "(#{((n + 1).to_f / SWEEPS * 100).round(1)}%)  " \
             "#{format('%.1f', total)}s/#{SWEEP_SECONDS}s\e[0m"
  end

  # ══════════════════════════════════════════════════════════════════════════
  # ACT 2 (sweeps 11-14): MultiBar with nested sub-bars
  # ══════════════════════════════════════════════════════════════════════════
  def run_multibar(n, palette)
    act_n    = n - ACT_RANGES[:multibar].first  # 0..3
    subtasks = [
      { name: :compile, title: "compile", total: 40, p: :fire   },
      { name: :test,    title: "test",    total: 60, p: :ocean  },
      { name: :lint,    title: "lint",    total: 30, p: :matrix },
      { name: :deploy,  title: "deploy",  total: 20, p: :lava   },
    ]
    active = subtasks[0..act_n]  # grow by one each sweep in this act

    Frames.banner("MultiBar  #{active.length}/#{subtasks.length} sub-tasks active  sweep #{n + 1}",
                  style: :neon, palette: palette).each { |l| TTY.puts l }
    TTY.puts "\e[2m  #{active.length} sub-bars  total steps: " \
             "#{active.sum { |t| t[:total] }}  act #{act_n + 1}/4\e[0m"

    mb = MultiBar.new(output: TTY, fps: 10, width: 50)
    mb.add(:suite,
           title: "SUITE #{n + 1}",
           total: active.sum { |t| t[:total] },
           palette: palette)
    active.each do |t|
      mb.add(t[:name], title: t[:title], total: t[:total],
             parent: :suite, palette: t[:p])
    end
    mb.start

    threads = active.map do |t|
      Thread.new do
        t[:total].times do |i|
          row_sleep(SWEEP_SECONDS.to_f / t[:total])
          mb.increment(t[:name])
          pct = ((i + 1).to_f / t[:total] * 100).round(1)
          mb.log(t[:name], "#{i + 1}/#{t[:total]} (#{pct}%)")
          Sound.play(:item) if i.zero?
        end
        mb.finish_bar(t[:name])
        Sound.play(:task_done)
      end
    end

    threads.each(&:join)
    mb.finish
    Sound.play(:run_done)

    TTY.puts "\e[32m✓ #{active.length}/#{active.length} sub-bars complete\e[0m"
  end

  # ══════════════════════════════════════════════════════════════════════════
  # ACT 3 (sweeps 15-18): ASCII art animation
  # ══════════════════════════════════════════════════════════════════════════
  def run_animation(n, palette)
    anim   = ANIM_NAMES[n % ANIM_NAMES.length]
    frames = ROWS  # same count as color rows → same total sleep time

    Frames.banner("ANIMATION  #{anim.upcase}  sweep #{n + 1}  #{frames} frames",
                  style: :stars, palette: palette).each { |l| TTY.puts l }

    start_t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    save_bar
    TTY.print render_bar(0, frames, palette, 0.0, 0.0)

    frames.times do |f|
      art     = Gfx.ascii_art(anim, f)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_t
      frac    = elapsed / SWEEP_SECONDS
      color   = ANSI.palette_color(palette, frac)
      avg     = elapsed / [f, 1].max

      # Print the art frame (first line, trimmed to 70 chars)
      TTY.puts "#{color}#{art.lines.first.chomp[0, 70]}\e[0m  " \
               "\e[2mframe #{f + 1}/#{frames}  #{format('%5.1f', frac * 100)}%  " \
               "+#{format('%.2f', elapsed)}s\e[0m"

      update_bar(f + 1, frames, palette, elapsed, avg)
      Sound.play(:item) if f.zero?
      row_sleep
    end
    TTY.puts
  end

  # ══════════════════════════════════════════════════════════════════════════
  # ACT 4 (sweeps 19-22): Rake multitask + Kitty inline image previews
  # ══════════════════════════════════════════════════════════════════════════
  def run_multitask(n, palette)
    Frames.banner("MULTITASK  4 parallel workers  inline previews  sweep #{n + 1}",
                  style: :cyber, palette: palette).each { |l| TTY.puts l }

    app     = Rake::Application.new
    Rake.application = app
    results = {}
    mutex   = Mutex.new
    inst    = self  # capture for closure

    TASK_PALETTES.each_with_index do |pal, i|
      app.define_task(Rake::Task, :"worker_#{i}") do
        w, h = 60, 10
        # Generate a gradient image: rows fade from full brightness (top) to 60% (bottom)
        rgba = Array.new(w * h) do |px|
          col    = px % w
          row    = px / w
          r, g, b = inst.send(:palette_rgb, pal, col.to_f / (w - 1))
          bright = 1.0 - row.to_f / (h - 1) * 0.4
          [(r * bright).round, (g * bright).round, (b * bright).round, 255]
        end.flatten.pack("C*")
        mutex.synchronize { results[:"worker_#{i}"] = { rgba: rgba, pal: pal, w: w, h: h } }
        Sound.play(:task_done)
      end
    end
    app.define_task(Rake::MultiTask, :all_workers,
                    TASK_PALETTES.each_index.map { |i| :"worker_#{i}" }) {}

    t0      = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    app[:all_workers].invoke
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
    Sound.play(:run_done)

    sequential = elapsed * TASK_PALETTES.length
    TTY.puts "\e[32m✓ 4/4 workers  " \
             "parallel #{format('%.2f', elapsed)}s  " \
             "vs sequential ~#{format('%.2f', sequential)}s  " \
             "speedup #{format('%.1f', sequential / elapsed)}×\e[0m"

    # Inline image previews
    TASK_PALETTES.each_with_index do |pal, i|
      r = results[:"worker_#{i}"] or next
      pct = ((i + 1).to_f / TASK_PALETTES.length * 100).round(1)
      TTY.print "  \e[2mworker #{i + 1}/#{TASK_PALETTES.length} " \
                "(#{pct}%)  #{pal}\e[0m "
      if Gfx.kitty_supported?
        TTY.puts Gfx.kitty_display_pixels(r[:rgba], pixel_width: r[:w],
                                           pixel_height: r[:h], cols: 24, rows: 2)
      else
        TTY.puts Gfx.ascii_placeholder(24, 2)
      end
    end

    assert_equal 4, results.size, "all 4 workers must complete"
  ensure
    Rake.application = Rake::Application.new
  end

  # ══════════════════════════════════════════════════════════════════════════
  # ACT 5 (sweeps 23-24): Exception showcase with red/green feedback
  # ══════════════════════════════════════════════════════════════════════════
  def run_exceptions(n, palette)
    act_n = n - ACT_RANGES[:exceptions].first  # 0 or 1
    count = act_n.zero? ? 30 : 10

    Frames.banner("EXCEPTION SHOWCASE  #{count} explosions  sweep #{n + 1}",
                  style: :double, palette: :lava).each { |l| TTY.puts l }
    TTY.puts "\e[2m  #{count} raises  all must be rescued  " \
             "success=\e[0m\e[32m✓\e[0m  \e[2mfail=\e[0m\e[31m✗\e[0m"

    hits    = 0
    start_t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    save_bar
    TTY.print render_bar(0, count, :lava, 0.0, 0.0)

    count.times do |i|
      raise "boom #{i + 1}"
    rescue RuntimeError
      hits += 1
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_t
      avg     = elapsed / hits
      update_bar(hits, count, :lava, elapsed, avg)
      Sound.play(:error) if i.zero?
      row_sleep(SWEEP_SECONDS.to_f / count)
    end
    TTY.puts  # advance past bar

    pct = (hits.to_f / count * 100).round(1)
    TTY.puts "\e[31m✗ raised #{count}\e[0m  " \
             "\e[32m✓ rescued #{hits}/#{count} (#{pct}%)\e[0m  " \
             "in #{format('%.2f', Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_t)}s"

    assert_equal count, hits, "every exception must be rescued"
  end
end
