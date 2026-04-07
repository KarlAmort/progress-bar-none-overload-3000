# frozen_string_literal: true

require "rake" unless defined?(::Rake)
require_relative "sound🦫"
require_relative "multi_bar🦫"
require_relative "ansi🦫"

module ProgressBarNone
  # Automatically attaches progress bars and sound effects to every Rake task.
  #
  # Usage (in Rakefile or a railtie):
  #   require "progress🦫bar🦫none/rake🦫"
  #   ProgressBarNone::Rake.install!
  #
  # Each task gets a live spinner bar while running.  Parallel multitask
  # dependencies appear as sibling bars.  Sound events fire on:
  #   item        — call ProgressBarNone::Rake.item(task_name) from inside a task
  #   task_done   — any task finishes cleanly
  #   run_done    — Rake::Application#top_level returns
  #   error       — any task raises
  module Rake
    # Curated style/palette/spinner presets that look great together
    PRESETS = [
      { style: :crystal,   palette: :crystal,   spinner: :braille,   celebration: :confetti  },
      { style: :fire,      palette: :fire,       spinner: :fire,      celebration: :firework  },
      { style: :matrix,    palette: :matrix,     spinner: :binary,    celebration: :success   },
      { style: :electric,  palette: :neon,       spinner: :explosion, celebration: :firework  },
      { style: :wave,      palette: :ocean,      spinner: :moon,      celebration: :confetti  },
      { style: :plasma,    palette: :plasma,     spinner: :dna,       celebration: :firework  },
      { style: :glitch,    palette: :acid,       spinner: :noise,     celebration: :party     },
      { style: :stars,     palette: :galaxy,     spinner: :sparkle,   celebration: :firework  },
      { style: :cyberpunk, palette: :synthwave,  spinner: :eyes,      celebration: :party     },
      { style: :skull,     palette: :toxic,      spinner: :skull,     celebration: :party     },
      { style: :nyan,      palette: :rainbow,    spinner: :nyan,      celebration: :party     },
      { style: :rocket,    palette: :ice,        spinner: :rocket,    celebration: :firework  },
      { style: :hearts,    palette: :vaporwave,  spinner: :hearts,    celebration: :confetti  },
      { style: :snake,     palette: :hacker,     spinner: :snake,     celebration: :success   },
      { style: :blocks,    palette: :sunset,     spinner: :arc,       celebration: :confetti  },
    ].freeze

    SKIP_TASKS = %w[environment db:prepare db:create db:schema:load db:seed].freeze

    class << self
      attr_reader :theme

      # Install Rake patches. Call once at startup.
      def install!
        @theme      = PRESETS.sample
        @multi_bar  = nil
        @bar_mutex  = Mutex.new
        @started    = false
        @task_times = {}

        print_theme_info

        ::Rake::Task.prepend(TaskPatch)
        ::Rake::Application.prepend(ApplicationPatch)
      end

      def multi_bar
        bar_mutex.synchronize do
          @multi_bar ||= MultiBar.new(output: $stderr, fps: 14, width: terminal_width - 4)
        end
      end

      def bar_mutex
        @bar_mutex ||= Mutex.new
      end

      # Called by TaskPatch when a task body starts executing
      def on_task_start(task_name)
        return if skip?(task_name)
        @task_times[task_name] = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        ensure_started
        multi_bar.add(
          task_name.to_sym,
          title:      task_name,
          style:      @theme[:style],
          palette:    @theme[:palette],
          spinner:    @theme[:spinner],
          celebration: @theme[:celebration]
        )
      end

      # Advance item counter for a running task and play geiger click
      def item(task_name, amount = 1)
        return if skip?(task_name)
        multi_bar.increment(task_name.to_sym, amount)
        Sound.play(:item)
      end

      # Called by TaskPatch on clean task completion
      def on_task_done(task_name)
        return if skip?(task_name)
        elapsed = elapsed_for(task_name)
        multi_bar.log(task_name.to_sym, "#{task_name}  #{ANSI::DIM}(#{format_elapsed(elapsed)})#{ANSI::RESET}")
        multi_bar.finish_bar(task_name.to_sym)
        Sound.play(:task_done)
      end

      # Called by TaskPatch on task error
      def on_task_error(task_name, err)
        return if skip?(task_name)
        elapsed = elapsed_for(task_name)
        msg = "#{ANSI::RED}✗ #{task_name}: #{err.class}#{ANSI::RESET}  #{ANSI::DIM}(#{format_elapsed(elapsed)})#{ANSI::RESET}"
        multi_bar.log(task_name.to_sym, msg)
        multi_bar.finish_bar(task_name.to_sym)
        Sound.play(:error)
      end

      # Called by ApplicationPatch when the whole run succeeds
      def on_run_done
        multi_bar.finish if @started
        Sound.play(:run_done)
      end

      # Called by ApplicationPatch when the whole run fails
      def on_run_error
        multi_bar.finish if @started
        Sound.play(:error)
      end

      private

      def skip?(task_name)
        SKIP_TASKS.any? { |t| task_name.start_with?(t) }
      end

      def ensure_started
        @bar_mutex.synchronize do
          unless @started
            @started = true
            multi_bar.start
          end
        end
      end

      def elapsed_for(task_name)
        start = @task_times[task_name]
        return 0 unless start
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      end

      def format_elapsed(secs)
        secs < 60 ? "#{secs.round(1)}s" : "#{(secs / 60).floor}m#{(secs % 60).round}s"
      end

      def print_theme_info
        t      = @theme
        col    = ANSI.palette_color(t[:palette], 0.6)
        bold   = ANSI::BOLD
        dim    = ANSI::DIM
        reset  = ANSI::RESET
        tw     = terminal_width

        label  = " 🎨 #{t[:style]} · #{t[:palette]} · #{t[:spinner]} "
        padded = label.ljust(tw - 2)

        $stderr.puts "#{col}#{bold}#{padded}#{reset}"
        $stderr.puts "#{dim}#{"─" * tw}#{reset}"
      end

      def terminal_width
        Integer(`tput cols 2>/dev/null`.strip)
      rescue StandardError
        80
      end
    end

    # ── Patches ─────────────────────────────────────────────────────────────────

    module TaskPatch
      def execute(args = nil)
        ProgressBarNone::Rake.on_task_start(name)
        begin
          super
          ProgressBarNone::Rake.on_task_done(name)
        rescue Exception => e
          ProgressBarNone::Rake.on_task_error(name, e)
          raise
        end
      end
    end

    module ApplicationPatch
      def top_level
        begin
          super
          ProgressBarNone::Rake.on_run_done
        rescue Exception
          ProgressBarNone::Rake.on_run_error
          raise
        end
      end
    end
  end
end
