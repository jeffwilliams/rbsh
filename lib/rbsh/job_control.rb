require 'rbsh/id_generator'
require 'rbsh/tokenizer'

module Rbsh
  # A command line for a single process (i.e. without pipes)
  class CmdLine
    def initialize(tokens)
      @argv = []
      @stdin_redirect = nil
      @stdout_redirect = nil
      @stderr_redirect = nil

      parse_tokens(tokens)
    end

    attr_accessor :argv
    attr_accessor :stdin_redirect
    attr_accessor :stdout_redirect
    attr_accessor :stderr_redirect

    private
    def parse_tokens(tokens)
      last = nil
      mode = nil
      tokens.each do |token|
        if token == '>'
          if mode == :maybe_fd_redir
            mode = :redir_stderr
          else
            mode = :redir_stdout
          end
        elsif token == '<'
          mode = :redir_stdin
        elsif token =~ /^\d+$/
          mode = :maybe_fd_redir
        else
          if mode == :redir_stdout
            raise "invalid stdout redirection: only one filename allowed." if @stdout_redirect
            @stdout_redirect = token
          elsif mode == :redir_stderr
            raise "invalid stderr redirection: only one filename allowed." if @stderr_redirect
            @stderr_redirect = token
          elsif mode == :redir_stdin
            raise "invalid stdin redirection: only one filename allowed." if @stdin_redirect
            @stdin_redirect = token
          else
            @argv.push token
          end
        end
        last = token
      end
    end
  end

  # A command line representing a full pipeline
  class Pipeline
    def initialize(cmd)
      tokens = Tokenizer.new.tokenize(cmd)
      cmd_lines = Tokenizer.split tokens, "|"
      @cmd_lines = cmd_lines.collect{ |cmd_line| CmdLine.new cmd_line }
      if @cmd_lines.size > 1
        @cmd_lines[1..(@cmd_lines.size-1)].each do |c|
          raise "invalid stdin redirection: cannot redirect when input is from pipe" if c.stdin_redirect
        end
        @cmd_lines[0..(@cmd_lines.size-2)].each do |c|
          raise "invalid stdout redirection: cannot redirect when output is to pipe" if c.stdout_redirect
        end
      end
    end

    # An array of each single process command line. These are joined together with pipes.
    attr_accessor :cmd_lines

  end

  # A pipeline of processes 
  class Job
    def initialize(id, cmd)
      @id = id
      @cmd = cmd
      @pgid = nil
      @fg_or_bg = :foreground
      @term_attrs = nil
      @processes = []
      @notified = false
    end
    
    attr_accessor :id
    attr_accessor :cmd
    attr_accessor :pgid
    attr_accessor :fg_or_bg
    attr_accessor :term_attrs
    attr_accessor :processes
    # Was the user notified that this job has stopped
    attr_accessor :notified

    def stopped?
      @processes.all?{ |p| p.stopped? || p.completed? } && @processes.any?{ |p| p.stopped? }
    end

    def completed?
      @processes.all?{ |p| p.completed? }
    end

  end

  # A single process
  class JobProcess
    def initialize(argv, pid, status)
      @argv = argv
      @pid = pid
      @status = status
      @term_attrs = nil
    end
    
    attr_accessor :argv
    attr_accessor :pid
    attr_accessor :term_attrs

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
        puts "#{$shell_name}: shell is not foreground. Stopping." if $verbose
        Process.kill("TTIN", 0)
      end

      # Ignore interactive and job-control signals.
      # Note that we must ignore TTIN specifically before calling tcsetpgrp or we will get 
      # a TTIN signal since when we change our pgid we are not necessarily be the foreground pgid anymore.
      Signal.trap('INT', 'SIG_IGN');
      Signal.trap('QUIT', 'SIG_IGN');
      Signal.trap('TSTP', 'SIG_IGN');
      Signal.trap('TTIN', 'SIG_IGN');
      Signal.trap('TTOU', 'SIG_IGN');
      # The GNU libc documentation mentions that shells should ignore SIG_CHLD, but it seems
      # to cause waitpid to not work correctly (it returns -1 ECHILD even when there are children)
      #Signal.trap('CHLD', 'SIG_IGN');

      # Put ourself in our own process group. 
      # If we are the session leader (sid == pid) this call will fail, but it is not necessary (since
      # we are already in our own process group). The correct way to check this would be to call getsid,
      # but that is not available in ruby 1.9. Instead we catch EPERM and assume that it was thrown for this reason.
      begin
        Process.setpgid Process.pid, Process.pid
      rescue Errno::EPERM
      end

      # Get control of terminal
      Termios.tcsetpgrp $stdin, Process.pid
      # Save default terminal attributes for shell
      @default_term_attrs = Termios.tcgetattr($stdin)

      @id_generator = IdGenerator.new

      @jobs = []
      @last_stopped_job = nil
    end

    attr_accessor :jobs
    attr_accessor :last_stopped_job

    # Start a pipeline
    def launch_job(cmd, fg_or_bg = :foreground)
      pipeline = Pipeline.new(cmd)

      infile = $stdin
      job = Job.new(@id_generator.get, cmd)
      job.fg_or_bg = fg_or_bg
      pipeline.cmd_lines.size.times do |i|
        cmd_line = pipeline.cmd_lines[i]
        
        if i != pipeline.cmd_lines.size-1
          # Not last command in pipeline
          piperead, pipewrite = IO.pipe
          outfile = pipewrite
        else
          outfile = $stdout
        end

        # launch command here
        child_pid = launch_process(cmd_line, job.pgid, infile, outfile, $stderr, fg_or_bg)       
        
        # Clean up pipes
        infile.close if infile != $stdin
        outfile.close if outfile != $stdout

        # The call to setpgid and tcsetpgrp on the child process needs to
        # be done in the child and the shell to prevent race conditions
        job.pgid = child_pid if ! job.pgid
        Process.setpgid child_pid, job.pgid

        job_process = JobProcess.new(cmd_line, child_pid, :running)
        job.processes.push job_process

        infile = piperead
      end
      @jobs.push job
      
      if fg_or_bg == :foreground
        put_in_foreground(job)
      else
        put_in_background(job)
      end
      job
    end

    def put_in_foreground(job, cont = false)
      # Give control of terminal to job 
      Termios.tcsetpgrp $stdin, job.pgid

      if cont
        Termios.tcsetattr($stdin, Termios::TCSADRAIN, job.term_attrs) if job && job.term_attrs
        Process.kill("SIGCONT", -job.pgid)
        job.notified = false
      end

      wait_for_job(job)

      @last_stopped_job = job if job.stopped?

      restore_shell(job)

      update_job_status if job 

      job
    end

    def put_in_background(job, cont = false)
      Process.kill("SIGCONT", -job.pgid) if cont
      job
    end

    # Set the shell as the foreground prcess for the terminal, and restore the 
    # shell terminal attributes. If a job is passed, the current terminal attributes
    # are saved on the job.
    def restore_shell(job = nil)
      # Get control of terminal back to the shell
      Termios.tcsetpgrp $stdin, Process.pid
      job.term_attrs = Termios.tcgetattr($stdin) if job
      Termios.tcsetattr($stdin, Termios::TCSADRAIN, @default_term_attrs)
    end

    # Check the status of existing jobs. If a block is passed it is called with
    # any Jobs that changed status.
    def update_job_status
      # See if any pids have changed status
      begin
        loop do
          pid = Process.waitpid(-1, Process::WUNTRACED|Process::WNOHANG)
          break if pid.nil? || pid == 0
        
          update_process_status pid, $? do |job|
            yield job if block_given?
          end
        end
      rescue Errno::ECHILD
        # No children
      end
    end

    private
  
    def update_process_status(pid, status)
      job_process = nil
      @jobs.each do |job|
        job_process = job.processes.find{ |p| p.pid == pid }
        if job_process
          job_process.set_status_from_process_status(status)
          break
        end
      end

      remove = []
      @jobs.each do |job|
        if job.completed?
          yield job if block_given?
          remove.push job
        elsif !job.notified && job.stopped?
          yield job if block_given?
          job.notified = true
        end
      end

      remove.each do |j|
        @jobs.delete j
        @id_generator.recycle j.id
        @last_stopped_job = nil if @last_stopped_job == j
      end

    end

    # Fork and set up the child process. Returns the child processes' pid
    def launch_process(cmd_line, pgid, infile, outfile, errfile, fg_or_bg = :foreground)
      Process.fork do
        pgid = Process.pid if ! pgid
        Process.setpgid Process.pid, pgid
        # Give this process group control of the terminal
        Termios.tcsetpgrp $stdin, pgid if fg_or_bg == :foreground
        # Set the handling for job control back to the default
        Signal.trap('INT', 'SIG_DFL');
        Signal.trap('QUIT', 'SIG_DFL');
        Signal.trap('TSTP', 'SIG_DFL');
        Signal.trap('TTIN', 'SIG_DFL');
        Signal.trap('TTOU', 'SIG_DFL');
        Signal.trap('CHLD', 'SIG_DFL');

        $stdin.reopen(infile.dup)
        $stdout.reopen(outfile.dup)
        $stderr.reopen(errfile.dup)
        infile.close
        outfile.close
        errfile.close
      
        exec *cmd_line.argv
      end
    end

    # Wait for all processes in the job to stop or complete
    def wait_for_job(job)
      loop do
        # Wait for the pid. It will either complete or get stopped
        pid = nil
        begin
          pid = Process.waitpid(-1, Process::WUNTRACED)
          update_process_status pid, $?
        rescue Errno::ECHILD
          puts "Child exited before wait: #{$!}"
        end
        break if job.stopped? || job.completed?
      end
    end
  end
end
