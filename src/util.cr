module Wsman
  class Util
    def self.cmd(cmd, args = [] of String)
      log = Logger.new(STDOUT)
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      if !Process.find_executable(cmd)
        raise "Cannot find #{cmd} executable, aborting."
      end

      status = Process.run(cmd, args: args, output: stdout, error: stderr)

      if status.success?
        log.debug(stdout.to_s.strip)
        {status.exit_code, stdout.to_s.strip}
      else
        log.error(stderr.to_s.strip)
        {status.exit_code, stderr.to_s.strip}
      end
    end

    def self.randstr(length)
      (0...length).map { (65 + rand(26)).chr }.join
    end

    def self.remove_file(path)
      log = Logger.new(STDOUT)
      if File.exists?(path)
        FileUtils.rm_rf(path)
        log.info("Removed #{path}.")
      else
        log.info("Not removing #{path}, does not exist.")
      end
    end
  end
end
