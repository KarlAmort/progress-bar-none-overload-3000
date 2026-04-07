# frozen_string_literal: true

module ProgressBarNone
  # Synthesizes and plays sound effects via sox.
  # Silently no-ops when sox is unavailable or no audio device is found.
  #
  # Events:
  #   :item        — geiger counter click (each processed record)
  #   :task_done   — rising chime (one rake task finished)
  #   :run_done    — triumphant fanfare (whole rake run finished)
  #   :error       — descending buzz (task or run failed)
  module Sound
    SOX_BIN = ENV.fetch("SOX_PATH", "sox")
    # Minimum ms between item clicks (rate-limits rapid fire)
    ITEM_THROTTLE_MS = 80

    PLAYERS = [
      %w[paplay],
      %w[aplay -q],
      %w[pw-play],
      -> { [SOX_BIN, "-t", "wav", "-", "-d"] },
    ].freeze

    class << self
      def play(event)
        return unless enabled?

        Thread.new do
          case event
          when :item      then play_item
          when :task_done then play_async { task_chime }
          when :run_done  then play_async { fanfare }
          when :error     then play_async { error_buzz }
          end
        rescue StandardError
          nil
        end
      end

      def enabled?
        return @enabled if defined?(@enabled)
        @enabled = system("#{SOX_BIN} --version > /dev/null 2>&1")
      end

      private

      # Rate-limited geiger click
      def play_item
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
        @last_item_at ||= 0
        return if now - @last_item_at < ITEM_THROTTLE_MS
        @last_item_at = now
        play_async { geiger_click }
      end

      def play_async(&block)
        wav = block.call
        play_wav(wav) if wav
      end

      # ── Synthesis ────────────────────────────────────────────────────────────

      # Short broadband noise burst — classic Geiger counter tick
      def geiger_click
        sox_synth(
          "synth", "0.018", "noise", "vol", "0.85",
          "fade", "0", "0.018", "0.006",
          "rate", "11025"
        )
      end

      # Single rising sine — pleasant task completion ding
      def task_chime
        sox_synth(
          "synth", "0.28", "sine", "523.25:1046.5",
          "fade", "0", "0.28", "0.12",
          "gain", "-7"
        )
      end

      # Three-note arpeggio + sustained chord — triumphant run completion
      def fanfare
        note = lambda do |freq, dur|
          sox_synth("synth", dur.to_s, "sine", freq.to_s, "fade", "0", dur.to_s, (dur * 0.4).to_s, "gain", "-9")
        end

        parts = [note.call(523.25, 0.12), note.call(659.25, 0.12), note.call(783.99, 0.20)]
        chord = sox_synth(
          "synth", "0.45", "sine", "523.25",
          "synth", "0.45", "sine", "mix", "659.25",
          "synth", "0.45", "sine", "mix", "783.99",
          "fade", "0", "0.45", "0.20",
          "gain", "-7"
        )
        parts.compact.reduce("") { |acc, w| concat_wav(acc.empty? ? nil : acc, w) } || chord
      end

      # Descending square wave with overdrive — error alarm
      def error_buzz
        sox_synth(
          "synth", "0.45", "square", "320:140",
          "overdrive", "12",
          "fade", "0", "0.45", "0.10",
          "gain", "-5"
        )
      end

      # ── sox helpers ──────────────────────────────────────────────────────────

      # Run sox -n ... and return WAV bytes, or nil on failure
      def sox_synth(*args)
        cmd = [SOX_BIN, "-n", "-r", "22050", "-c", "1", "-b", "16", "-t", "wav", "-", *args]
        IO.popen(cmd, "rb", err: File::NULL) { |io| io.read }
      rescue StandardError
        nil
      end

      # Concatenate two WAV byte strings (strips second header, appends data)
      def concat_wav(a, b)
        return b if a.nil? || a.empty?
        return a if b.nil? || b.empty?

        # WAV header is 44 bytes; data starts at byte 44
        data_a = a[44..]
        data_b = b[44..]
        combined_data = data_a + data_b

        header = a[0, 44].dup
        total_size = combined_data.bytesize + 36
        header[4, 4] = [total_size].pack("V")
        header[40, 4] = [combined_data.bytesize].pack("V")
        header + combined_data
      rescue StandardError
        a
      end

      # Try each player in turn; silently move on if unavailable or playback fails
      def play_wav(wav_data)
        return if wav_data.nil? || wav_data.empty?

        PLAYERS.each do |player|
          cmd = player.is_a?(Proc) ? player.call : player
          begin
            IO.popen([*cmd, "-"], "wb", err: File::NULL) do |io|
              io.write(wav_data)
            end
            return if $?.success?
          rescue Errno::ENOENT
            next
          end
        end

        # Last resort: terminal bell
        $stderr.print "\a"
      rescue StandardError
        nil
      end
    end
  end
end
