require "log"

module Wsman
  class Util
    def self.cmd(cmd, args = [] of String)
      stdout = IO::Memory.new
      stderr = IO::Memory.new

      if !Process.find_executable(cmd)
        raise "Cannot find #{cmd} executable, aborting."
      end

      status = Process.run(cmd, args: args, output: stdout, error: stderr)

      if status.success?
        Log.debug { stdout.to_s.strip }
        {status.exit_code, stdout.to_s.strip}
      else
        Log.error { stderr.to_s.strip }
        {status.exit_code, stderr.to_s.strip}
      end
    end

    def self.randstr(length)
      (0...length).map { (65 + rand(26)).chr }.join
    end

    def self.remove_file(path)
      if File.exists?(path)
        FileUtils.rm_rf(path)
        Log.info { "Removed #{path}." }
      else
        Log.info { "Not removing #{path}, does not exist." }
      end
    end

    def self.get_gid_for(name)
      _,id = Wsman::Util.cmd("id", ["-g", name])
      id.to_i
    end

    def self.get_uid_for(name)
      _,id = Wsman::Util.cmd("id", ["-u", name])
      id.to_i
    end
  end
end
