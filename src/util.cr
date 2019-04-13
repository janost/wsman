module Wsman
  class Util
    def self.cmd(cmd, args = [] of String)
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      status = Process.run(cmd, args: args, output: stdout, error: stderr)
      if status.success?
        {status.exit_code, stdout.to_s.strip}
      else
        {status.exit_code, stderr.to_s.strip}
      end
    end

    def self.randstr(length)
      (0...length).map { (65 + rand(26)).chr }.join
    end
  end
end
