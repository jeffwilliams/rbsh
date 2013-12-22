require 'rbsh/id_generator'

module Rbsh
  class JobProcess
    def initialize(id, cmd, pid, status)
      @id = id
      @cmd = cmd
      @pid = pid
      @status = status
      @fg_or_bg = :foreground
    end
    
    attr_accessor :id
    attr_accessor :cmd
    attr_accessor :pid
    attr_accessor :fg_or_bg

    def completed?
      @status == :completed
    end
    def stopped?  
      @status == :stopped
    end
    attr_accessor :status

    def set_status_from_process_status(s)
      if s.stopped?
        @status = :stopped
      else
        @status = :completed
      end
    end

  end

  class JobControl
    def initialize
      #"A subshell that runs interactively has to ensure that it has been placed in the foreground by its 
      # parent shell before it can enable job control itself. It does this by getting its initial process group ID 
      # with the getpgrp function, and comparing it to the process group ID of the current foreground job associated 
      # with its controlling terminal (which can be retrieved using the tcgetpgrp function).
      # If the subshell is not running as a foreground job, it must stop itself by sending a SIGTTIN signal to its 
      # own process group. It may not arbitrarily put itself into the foreground; it must wait for the user to tell 
      # the parent shell to do this. If the subshell is continued again, it should repeat the check and stop itself 
      # again if it is still not in the foreground. "
      while Termios.tcgetpgrp($stdin) != Process.getpgrp
        Process.kill("TTIN", 0)
      end

      # Put ourself in our own process group
      Process.setpgid Process.pid, Process.pid
      # Get control of terminal
      Termios.tcsetpgrp $stdin, Process.pid
      # Save default terminal attributes for shell
      @default_term_attrs = Termios.tcgetattr($stdin)


      # Ignore interactive and job-control signals.
      Signal.trap('INT', 'SIG_IGN');
      Signal.trap('QUIT', 'SIG_IGN');
      Signal.trap('TSTP', 'SIG_IGN');
      Signal.trap('TTIN', 'SIG_IGN');
      Signal.trap('TTOU', 'SIG_IGN');
      # The GNU libc documentation mentions that shells should ignore SIG_CHLD, but it seems
      # to cause waitpid to not work correctly (it returns -1 ECHILD even when there are children)
      #Signal.trap('CHLD', 'SIG_IGN');

      @id_generator = IdGenerator.new

      @processes = {}
      @last_stopped_job_pid = nil
    end

    attr_accessor :processes
    attr_accessor :last_stopped_job_pid

    # Fork and start a process in the foreground. Returns the JobProcess
    # representing the new process.
    def launch_process(cmd, fg_or_bg = :foreground)
      child_pid = Process.fork do
        # This process starts as a new process group
        Process.setpgid Process.pid, Process.pid
        # Give this process control of the terminal
        Termios.tcsetpgrp $stdin, Process.pid if fg_or_bg == :foreground
        # Set the handling for job control back to the default
        Signal.trap('INT', 'SIG_DFL');
        Signal.trap('QUIT', 'SIG_DFL');
        Signal.trap('TSTP', 'SIG_DFL');
        Signal.trap('TTIN', 'SIG_DFL');
        Signal.trap('TTOU', 'SIG_DFL');
        Signal.trap('CHLD', 'SIG_DFL');

        $stdout.reopen($stdout.dup)
        $stderr.reopen($stderr.dup)
        $stdin.reopen($stdin.dup)
      
        exec cmd
      end

      # The call to setpgid and tcsetpgrp on the child process needs to
      # be done in the child and the shell to prevent race conditions
      Process.setpgid(child_pid, child_pid)

      job_process = JobProcess.new(@id_generator.get, cmd, child_pid, :running)
      job_process.fg_or_bg = fg_or_bg
      @processes[child_pid] = job_process
      if fg_or_bg == :foreground
        put_in_foreground(child_pid)
      else
        put_in_background(child_pid)
      end
    end

    # Check the status of existing jobs. If a block is passed it is called with
    # any JobProcesses that changed status.
    def update_job_status
      # See if any pids have changed status
      begin
        loop do
          pid = Process.waitpid(-1, Process::WUNTRACED|Process::WNOHANG)
          break if pid.nil? || pid == 0
          @processes[pid].set_status_from_process_status($?)
          yield @processes[pid] if block_given?
        end
      rescue Errno::ECHILD
        # No children
      end

      remove = []
      @processes.each{ |pid, j| remove.push j if j.completed? }
      remove.each do |j| 
        @processes.delete j.pid
        @id_generator.recycle j.id
        @last_stopped_job_pid = nil if @last_stopped_job_pid == j.pid
      end
    end

    def put_in_foreground(pid, cont = false)
      # Give control of terminal to job 
      Termios.tcsetpgrp $stdin, pid

      Process.kill("SIGCONT", -pid) if cont

      # Wait for the pid. It will either complete or get stopped
      pid = nil
      begin
        pid = Process.waitpid(-1, Process::WUNTRACED)
      rescue Errno::ECHILD
        puts "Child exited before wait: #{$!}"
      end

      @last_stopped_job_pid = pid if $?.stopped?

      # Get control of terminal back to the shell
      Termios.tcsetpgrp $stdin, Process.pid
      @processes[pid].set_status_from_process_status($?) if @processes[pid]
      @processes[pid]
    end

    def put_in_background(pid, cont = false)
      Process.kill("SIGCONT", -pid) if cont
      @processes[pid]
    end
  end
end
