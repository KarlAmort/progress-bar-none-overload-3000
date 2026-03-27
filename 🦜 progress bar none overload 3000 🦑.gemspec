# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "progress_bar_none_overload_3000"
  spec.version       = "3000.0-alpha2"
  spec.authors       = ["Karl Amort"]
  spec.email         = ["karl@amort.berlin"]

  spec.summary       = "Animated progress bars for Ruby CLI applications with 15+ palettes and 20+ styles"
  spec.description   = <<~DESC
    Animated progress bars for Ruby CLI applications. Features include 15+ color
    palettes, 20+ bar styles, 27 spinner animations, real-time metrics with
    sparklines, Gantt chart rendering, Kitty/iTerm2 inline graphics support,
    and decorative ASCII frames. Pure Ruby, zero dependencies.
    Works with any Enumerable via .with_progress extension.
  DESC
  spec.homepage      = "https://github.com/KarlAmort/progress-bar-none-overload-3000"
  spec.licenses      = ["CC0-1.0", "Nonstandard"]
  spec.required_ruby_version = ">= 4.0"
  spec.platform = Gem::Platform::RUBY

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.glob(%w[
    lib/**/*.rb
    LICENSE
    README.md
  ])
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # base64 was extracted from stdlib in Ruby 3.4
  spec.add_dependency "base64"

  spec.add_development_dependency "minitest", ">= 5.0"
  spec.add_development_dependency "rubocop", ">= 1.0"
  spec.add_development_dependency "simplecov", ">= 0.22"
  spec.add_development_dependency "mdl", ">= 0.13"
end
