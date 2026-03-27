# progress_bar_none_overload_3000 (Cockpit3000)

Ruby gem for maximum terminal pizzazz. PROGRESS INFO-OVERLOAD COCKPIT 3000. Pure Ruby, no runtime dependencies.

- Gem name: `progress_bar_none_overload_3000`
- Internal name: Cockpit3000
- Version: 3000.0.3000

## Structure

```
lib/
  cockpit3000.rb              # Main require
  cockpit3000/
    ansi.rb                   # Color palettes, effects, spinners
    bar.rb                    # Main progress bar class
    renderer.rb               # Bar style rendering
    sparkline.rb              # Unicode/braille sparklines
    metrics.rb                # Metrics tracking
    graphics.rb               # Kitty + iTerm2 inline images, ASCII art
    frames.rb                 # Decorative borders and banners
    enumerable_extension.rb   # .with_progress on any Enumerable
    version.rb
test/
  ...
```

## Running Tests

```bash
ruby test/test_name.rb
rake test
```

## Usage Pattern

```ruby
require 'cockpit3000'

items.with_progress(title: "Processing", palette: :fire).each { |item| ... }
```

## Key Modules

### ANSI (`ansi.rb`)
- 15+ color palettes: `:crystal`, `:fire`, `:ocean`, `:neon`, `:synthwave`, `:vaporwave`, `:acid`, `:matrix`, `:lava`, `:ice`, `:galaxy`, `:toxic`, `:hacker`, and more
- True-color RGB support
- Cursor control
- Effects: shimmer, pulse, flicker, glitch, neon glow, celebration
- 27 spinner animations

### Renderer (`renderer.rb`)
- 20+ bar styles: `crystal`, `blocks`, `dots`, `fire`, `nyan`, `matrix`, `glitch`, `plasma`, `wave`, `electric`, `skull`, `hearts`, `stars`, `cyberpunk`, `pixel`, `snake`, `music`, `rocket`, and more
- Gradient rendering, shimmer wave

### Sparkline (`sparkline.rb`)
- Unicode block + braille sparklines
- Colored gradients, histograms

### Graphics (`graphics.rb`)
- Inline image protocols: Kitty and iTerm2
- ASCII art animations

### Frames (`frames.rb`)
- Border styles: single, double, rounded, bold, cyber, neon, stars
- Animated frames, banners, ASCII titles

### Bar (`bar.rb`)
- `.start` / `.increment` / `.finish` API

### EnumerableExtension (`enumerable_extension.rb`)
- `.with_progress` mixin on any Enumerable

## Context

This gem is the destination for terminal visualization code being migrated out of `~/p/SONYHATE3000/ruby/sonyctl_gantt.rb`.
