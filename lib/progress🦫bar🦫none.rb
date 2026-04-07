# frozen_string_literal: true

require_relative "progress🦫bar🦫none/version🦫"
require_relative "progress🦫bar🦫none/ansi🦫"
require_relative "progress🦫bar🦫none/sparkline🦫"
require_relative "progress🦫bar🦫none/metrics🦫"
require_relative "progress🦫bar🦫none/renderer🦫"
require_relative "progress🦫bar🦫none/bar🦫"
require_relative "progress🦫bar🦫none/enumerable_extension🦫"
require_relative "progress🦫bar🦫none/graphics🦫"
require_relative "progress🦫bar🦫none/frames🦫"
require_relative "progress🦫bar🦫none/gantt🦫"
require_relative "progress🦫bar🦫none/multi_bar🦫"
require_relative "progress🦫bar🦫none/download_thread_state🦫"
require_relative "progress🦫bar🦫none/progressbar_compat🦫"
require_relative "progress🦫bar🦫none/sound🦫"

# Load Rake integration only when Rake is already in scope
require_relative "progress🦫bar🦫none/dashboard🦫"
require_relative "progress🦫bar🦫none/rake🦫" if defined?(::Rake)

module ProgressBarNone
  BRAND_NAME = "PROGRESS🦫BAR🦫NONE"

  class Error < StandardError; end

  class << self
    # Global configuration
    attr_accessor :default_style, :default_width, :animation_fps,
                  :default_palette, :default_spinner, :rainbow_mode,
                  :celebration_mode, :glow_enabled

    def configure
      yield self if block_given?
    end

    # List all available styles
    def available_styles
      Renderer::STYLES.keys
    end

    # List all available palettes
    def available_palettes
      ANSI::CRYSTAL_PALETTE.keys
    end

    # List all available spinners
    def available_spinners
      ANSI::SPINNERS.keys
    end

    # List all available celebrations
    def available_celebrations
      ANSI::CELEBRATIONS.keys
    end

    # Print a showcase of all palettes
    def palette_showcase
      puts "\n#{ANSI::BOLD}Available Color Palettes:#{ANSI::RESET}\n\n"

      available_palettes.each do |name|
        print "  #{name.to_s.ljust(12)}: "
        20.times do |i|
          color = ANSI.palette_color(name, i / 20.0)
          print "#{color}\u2588#{ANSI::RESET}"
        end
        puts
      end
      puts
    end

    # Print a showcase of all styles
    def style_showcase
      puts "\n#{ANSI::BOLD}Available Bar Styles:#{ANSI::RESET}\n\n"

      available_styles.each do |name|
        style = Renderer::STYLES[name]
        animated = style[:animated] ? " #{ANSI::DIM}(animated)#{ANSI::RESET}" : ""
        print "  #{name.to_s.ljust(12)}: "
        print "#{style[:left]}#{style[:filled] * 10}#{style[:partial]&.last || style[:filled]}#{style[:empty] * 5}#{style[:right]}"
        puts animated
      end
      puts
    end

    # Print a showcase of all spinners
    def spinner_showcase
      puts "\n#{ANSI::BOLD}Available Spinners:#{ANSI::RESET}\n\n"

      available_spinners.each do |name|
        spinners = ANSI::SPINNERS[name]
        print "  #{name.to_s.ljust(12)}: "
        print spinners.join(" ")
        puts
      end
      puts
    end
  end

  # Defaults
  @default_style = :crystal
  @default_palette = :crystal
  @default_width = 40
  @default_spinner = :braille
  @animation_fps = 15
  @rainbow_mode = false
  @celebration_mode = :confetti
  @glow_enabled = false
end

# New brand aliases (Ruby constants cannot contain emoji).
PROGRESSBARNONE = ProgressBarNone unless defined?(::PROGRESSBARNONE)
Cockpit3000 = ProgressBarNone unless defined?(::Cockpit3000)
