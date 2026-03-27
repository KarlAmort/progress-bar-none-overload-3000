# Cockpit3000::Gantt Module Design

> Move the SONYHATE3000 Gantt chart into Cockpit3000 as a generic, reusable module.
> Tufte-inspired defaults. Rainbow vomit optional.

## Data Model

```ruby
task = {
  name: "sonyctl.rb v1",   # task label
  group: "P1",              # phase/category (left column)
  start: 0,                 # relative start unit
  duration: 8,              # width in time units
  status: :done,            # :done, :wip, :pending
  progress: 1.0,            # 0.0-1.0 for partial fill
}
```

## API

```ruby
chart = Cockpit3000::Gantt.new(tasks,
  title: "sonyctl v2 build progress",
  mode: :tufte,          # color scheme
  width: 80,             # terminal columns
  show_progress: true,   # footer progress bar
  animated: false,       # animation effects
  frame_style: :rounded, # border style
)

# Terminal output
puts chart.render          # => Array<String>
puts chart                 # => joined string

# SVG export
File.write("gantt.svg", chart.render_svg)

# Animated loop (for tmux dashboards)
chart.run(fps: 1)          # clear-screen loop
```

## Color Modes

| Mode | Default | Status Mapping | Effects |
|------|---------|----------------|---------|
| `:tufte` | YES | done=`:ocean`, wip=`:sunset`(amber range), pending=dim gray | None. Clean. Tufte. |
| `:phase` | no | Each group gets a unique palette from rotation | Gradient fill within bars |
| `:rainbow` | no | All statuses rainbow-cycle | `rainbow_cycle`, `BLINK` on WIP |
| `:fire` | no | All bars use `:lava` palette | `fire_flicker` animation |
| `:matrix` | no | All bars use `:matrix` palette | Binary rain in empty space |
| `:neon` | no | `:synthwave` palette | `neon_glow`, pulsing borders |
| `:custom` | no | User provides `{done: :ice, wip: :fire, pending: :mono}` | User choice |

### Tufte Mode Details (Default)

Edward Tufte's principles applied:
- **Maximize data-ink ratio**: No decorative elements. Every pixel of color = information.
- **Done tasks**: Ocean palette (calm blue-green). Completed = cool, settled.
- **WIP tasks**: Sunset palette, amber range only (warm, draws attention). In-progress = active, warm.
- **Pending tasks**: Dim gray (`DIM` + mono palette). Future = backgrounded, unobtrusive.
- **No borders on bars**: Just colored blocks, flush left.
- **Gridlines**: Dim dotted lines at time markers. Barely visible.
- **Status icons**: `✓` (done), `◆` (wip), `○` (pending). Small, precise.
- **Progress bar**: Uses existing `Renderer` with `:ocean` palette.
- **No title border**: Just bold text + dim subtitle.

### Rainbow Vomit Mode

The opposite of Tufte. Maximum pizzazz:
- Every bar character cycles through full rainbow via `ANSI.rainbow_cycle(position, time, speed)`
- WIP bars blink (`ANSI::BLINK`)
- Border uses `Frames.wrap(animated: true)` with rainbow cycling
- Title is rainbow text via `Frames.rainbow_text`
- Empty space has occasional `✨` sparkles
- Progress bar uses `:rainbow` palette with celebration mode
- Spinner animation in footer

## Rendering Structure

```
╭── SONY! HATE! 3000! — sonyctl v2 build progress ──╮  ← Frames.wrap (optional)
│                                                      │
│  Phase Task                  T0  T2  T4  T6  T8     │  ← timeline header
│  ──────────────────────────────────────────────────  │  ← separator
│  P1  ✓ sonyctl.rb v1        ██████                   │  ← task rows
│  P1  ✓ AudioRecorder             ████                │
│  P6  ◆ Nanoleaf API                  ▓▓▓▓           │  ← WIP = partial fill char
│  P10 ○ WLAN/Bluetooth                    ░░░        │  ← pending = empty char
│  ──────────────────────────────────────────────────  │
│  Progress: ⟨████████████████████████░░░░░⟩ 86%      │  ← Renderer progress bar
│  Updated: 23:19:27  •  Make Edward Tufte proud       │
╰──────────────────────────────────────────────────────╯
```

## File Layout

```
lib/cockpit3000/
  gantt.rb          ← NEW: Gantt chart renderer
lib/cockpit3000.rb  ← ADD: require_relative "cockpit3000/gantt"
```

## SVG Export

Generate SVG that matches the terminal aesthetic:
- Dark background (`#1a1a2e`)
- Monospace font (SF Mono / Menlo)
- Colored rects for bars, using the same palette RGB values
- Status icons as text elements
- Replaces hand-coded `doc/gantt.svg` in SONYHATE3000

## SONYHATE3000 Integration

After the module exists, `ruby/sonyctl_gantt.rb` becomes a thin wrapper:

```ruby
require 'cockpit3000'

tasks = [ ... ] # same task data
chart = Cockpit3000::Gantt.new(tasks,
  title: "SONY! HATE! 3000! — sonyctl v2 build progress",
  mode: :tufte,
  show_progress: true,
)

loop do
  print "\e[2J\e[H"
  puts chart.render(frame_num: frame)
  frame += 1
  sleep 25
end
```

## Dependencies

None new. Pure Ruby, uses only existing Cockpit3000 modules:
- `ANSI` for colors, effects
- `Renderer` for progress bar
- `Frames` for borders
- `Sparkline` for optional velocity graphs
