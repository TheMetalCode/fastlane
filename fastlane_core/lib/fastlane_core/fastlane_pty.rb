# Source: Mix of https://github.com/fastlane/fastlane/pull/7202/files,
# https://github.com/fastlane/fastlane/pull/11384#issuecomment-356084518 and
# https://github.com/DragonBox/u3d/blob/59e471ad78ac00cb629f479dbe386c5ad2dc5075/lib/u3d_core/command_runner.rb#L88-L96

class StandardError
  def exit_status
    return -1
  end
end

module FastlaneCore
  class FastlanePtyError < StandardError
    attr_reader :exit_status
    def initialize(e, exit_status)
      super(e)
      set_backtrace(e.backtrace) if e
      @exit_status = exit_status
    end
  end

  class FastlanePty
    def self.spawn(command)
      require 'pty'
      PTY.spawn(command) do |command_stdout, command_stdin, pid|
        begin
          yield(command_stdout, command_stdin, pid)
        rescue Errno::EIO
          puts "Rescuing Errno::EIO..."
          # Exception ignored intentionally.
          # https://stackoverflow.com/questions/10238298/ruby-on-linux-pty-goes-away-without-eof-raises-errnoeio
          # This is expected on some linux systems, that indicates that the subcommand finished
          # and we kept trying to read, ignore it
        ensure
          begin
            puts "Waiting on process #{pid}..."
            Process.wait(pid)
          rescue Errno::ECHILD, PTY::ChildExited
            puts "Rescuing Errno::ECHILD or PTY::ChildExited..."
            # The process might have exited.
          rescue StandardError => e
            # could an error other than the above two happen here?
            puts "Rescuing StandardError, raising FastlanePtyError..."
            puts $?.exitstatus
            # Wrapping any error in FastlanePtyError to allow
            # callers to see and use $?.exitstatus that
            # would usually get returned
            raise FastlanePtyError.new(e, $?.exitstatus)
          end
        end
      end
      puts "No obvioius errors, returning exit status..."
      puts $?.exitstatus
      $?.exitstatus
    rescue LoadError
      puts "Rescuing LoadError, retrying with Open3.popen3e..."
      require 'open3'
      Open3.popen2e(command) do |command_stdin, command_stdout, p| # note the inversion
        yield(command_stdout, command_stdin, p.value.pid)

        command_stdin.close
        command_stdout.close
        puts p.value.exitstatus
        p.value.exitstatus
      end
    rescue StandardError => e
      puts "Rescuing StandardError, raising FastlanePtyError..."
      puts $?.exitstatus
      # Wrapping any error in FastlanePtyError to allow
      # callers to see and use $?.exitstatus that
      # would usually get returned
      raise FastlanePtyError.new(e, $?.exitstatus)
    end
  end
end
