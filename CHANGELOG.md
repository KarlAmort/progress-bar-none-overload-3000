# Changelog

## [6000.0.3000] - 2026-03-04

### Added
- `Cockpit3000::Gantt` — generic, reusable Gantt chart renderer
  - 7 color modes: `:tufte` (default), `:phase`, `:rainbow`, `:fire`, `:matrix`, `:neon`, `:custom`
  - Tufte mode: data-ink ratio maximized (done=ocean, WIP=amber, pending=gray)
  - Rainbow vomit mode: full spectrum cycling + blink + sparkles
  - SVG export with dark theme matching terminal aesthetic
  - Animation support with `frame_num` parameter for tmux dashboards
  - `chart.run(fps:)` for auto-refreshing terminal display
- `CLAUDE.md` project context file
- Design document: `docs/plans/2026-03-04-gantt-module-design.md`

### Changed
- Version bumped from 3000.0.3000 to 6000.0.3000 (because 3000 more is always better)

## [3000.0.3000] - 2025-01-14

### Initial Release
- 15+ color palettes (crystal, fire, ocean, neon, synthwave, vaporwave, acid, matrix, lava, ice, galaxy, toxic, hacker...)
- 20+ bar styles (crystal, blocks, dots, fire, nyan, matrix, glitch, plasma, wave, electric, skull, hearts, stars, cyberpunk, pixel, snake, music, rocket...)
- 27 spinner animations
- True-color (24-bit) RGB gradients
- Shimmer, pulse, fire flicker, glitch, neon glow effects
- Sparkline + braille graphs with colored gradients
- Kitty + iTerm2 inline image protocol support
- Decorative frames with animated borders
- `.with_progress` Enumerable extension
- Real-time metrics tracking (avg/min/max/cumulative)
- Pure Ruby, zero dependencies
