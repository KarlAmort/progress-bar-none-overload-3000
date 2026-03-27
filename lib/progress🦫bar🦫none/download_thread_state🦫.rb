# frozen_string_literal: true

module ProgressBarNone
  module DownloadThreadState
    ThreadState = Struct.new(
      :site,
      :thread,
      :total,
      :done,
      :status,
      :reason,
      :resume_at,
      :slug,
      :percent,
      :size_str,
      :speed_str,
      :attempt,
      :message,
      keyword_init: true
    )

    class Tracker
      attr_reader :cycle_id

      def initialize(sites:, threads_per_site:)
        @mutex = Mutex.new
        @cycle_id = "%d-%04d" % [Process.pid, rand(1000..9999)]
        @states = {}

        sites.each do |site|
          @states[site.to_sym] = {}
          (1..threads_per_site.to_i).each do |thread_number|
            @states[site.to_sym][thread_number] = ThreadState.new(
              site: site.to_sym,
              thread: thread_number,
              total: 0,
              done: 0,
              status: :idle,
              reason: :waiting,
              resume_at: nil,
              slug: nil,
              percent: nil,
              size_str: nil,
              speed_str: nil,
              attempt: nil,
              message: "waiting"
            )
          end
        end
      end

      def set_plan(site:, thread:, total:)
        mutate(site, thread) do |state|
          state.total = [total.to_i, 0].max
          state.done = 0
          state.status = :idle
          state.reason = state.total.zero? ? :no_work : :waiting
          state.resume_at = nil
          state.slug = nil
          state.percent = nil
          state.size_str = nil
          state.speed_str = nil
          state.attempt = nil
          state.message = state.total.zero? ? "blocked: no work" : "queued"
        end
      end

      def mark_active(site:, thread:, slug:)
        mutate(site, thread) do |state|
          state.status = :active
          state.reason = nil
          state.resume_at = nil
          state.slug = slug
          state.message = "active"
        end
      end

      def mark_progress(site:, thread:, slug:, percent:, size_str:, speed_str:)
        mutate(site, thread) do |state|
          state.status = :active
          state.reason = nil
          state.resume_at = nil
          state.slug = slug
          state.percent = percent.to_f
          state.size_str = size_str.to_s
          state.speed_str = speed_str.to_s
          state.message = "downloading"
        end
      end

      def mark_blocked(site:, thread:, reason:, resume_at: nil, attempt: nil, message: nil)
        mutate(site, thread) do |state|
          state.status = :blocked
          state.reason = reason.to_sym
          state.resume_at = resume_at
          state.attempt = attempt.to_i if attempt
          state.message = message.to_s if message
        end
      end

      def mark_resumed(site:, thread:)
        mutate(site, thread) do |state|
          state.status = :active
          state.reason = nil
          state.resume_at = nil
          state.message = "resumed"
        end
      end

      def increment_done(site:, thread:, ok:, cause: nil)
        mutate(site, thread) do |state|
          state.done += 1
          state.status = :idle
          state.reason = ok ? :waiting : (cause || :failed)
          state.resume_at = nil
          state.percent = nil
          state.size_str = nil
          state.speed_str = nil
          state.message = ok ? "ok" : "failed: #{cause || :unknown}"
        end
      end

      def finish_thread(site:, thread:)
        mutate(site, thread) do |state|
          if state.total.zero?
            state.status = :blocked
            state.reason = :no_work
            state.message = "blocked: no work"
          else
            state.status = :done
            state.reason = nil
            state.message = "done"
          end
          state.resume_at = nil
          state.percent = nil
          state.size_str = nil
          state.speed_str = nil
        end
      end

      def snapshot
        @mutex.synchronize do
          now = Time.now
          {
            cycle_id: @cycle_id,
            sites: @states.each_with_object({}) do |(site, threads), out|
              out[site] = threads.each_with_object({}) do |(thread, state), th_out|
                resume_in = if state.resume_at
                  [state.resume_at - now, 0.0].max
                end

                th_out[thread] = {
                  total: state.total,
                  done: state.done,
                  status: state.status,
                  reason: state.reason,
                  slug: state.slug,
                  percent: state.percent,
                  size_str: state.size_str,
                  speed_str: state.speed_str,
                  attempt: state.attempt,
                  resume_at: state.resume_at,
                  resume_in: resume_in,
                  message: state.message
                }
              end
            end
          }
        end
      end

      private

      def mutate(site, thread)
        @mutex.synchronize do
          state = @states.dig(site.to_sym, thread.to_i)
          return unless state

          yield(state)
        end
      end
    end

    MUTEX = Mutex.new

    class << self
      def start_cycle!(sites:, threads_per_site: 2)
        tracker = Tracker.new(sites: sites, threads_per_site: threads_per_site)
        MUTEX.synchronize { @tracker = tracker }
        tracker
      end

      def tracker
        MUTEX.synchronize { @tracker }
      end

      def clear_cycle!
        MUTEX.synchronize { @tracker = nil }
      end

      def snapshot
        tracker&.snapshot || { cycle_id: nil, sites: {} }
      end

      def format_line(site:, thread:, state:)
        prefix = "%s t%d" % [site.to_s, thread.to_i]
        total = state[:total].to_i
        done = state[:done].to_i

        case state[:status]
        when :blocked
          reason = state[:reason] || :blocked
          if state[:resume_in]
            "%s | %d/%d | blocked(%s), resumes in %ds" % [prefix, done, total, reason, state[:resume_in].ceil]
          else
            "%s | %d/%d | blocked(%s)" % [prefix, done, total, reason]
          end
        when :active
          if state[:percent]
            "%s | %d/%d | %.0f%% of %s @ %s | %s" % [
              prefix,
              done,
              total,
              state[:percent].to_f,
              state[:size_str],
              state[:speed_str],
              state[:slug].to_s
            ]
          else
            "%s | %d/%d | active | %s" % [prefix, done, total, state[:slug].to_s]
          end
        when :done
          "%s | %d/%d | done" % [prefix, done, total]
        else
          "%s | %d/%d | %s" % [prefix, done, total, state[:message] || "idle"]
        end
      end

      def backoff_wait(seconds, tick: 1)
        remain = [seconds.to_i, 0].max
        while remain.positive?
          yield(remain) if block_given?
          sleep([tick.to_i, remain].min)
          remain -= tick.to_i
        end
      end
    end
  end
end
