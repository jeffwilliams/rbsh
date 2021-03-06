module Rbsh
  class Builtins
    def initialize(dirhistory, job_control, notify_job_status_proc)
      @dirhistory = dirhistory
      @job_control = job_control
      @notify_job_status_proc = notify_job_status_proc
      @warned_stopped_jobs_on_exit = false
    end 
   
    def exit
      stopped = @job_control.jobs.find{ |j| j.stopped? && j.fg_or_bg == :foreground }
      if stopped && !@warned_stopped_jobs_on_exit
        puts "There are stopped jobs."
        @warned_stopped_jobs_on_exit = true
      else
        Kernel.exit! 0
      end
    end

    def cd(*args)
      begin
        if args.length > 0
          Dir.chdir args[0]
        else
          Dir.chdir ENV['HOME']
        end
        @dirhistory.cd File.absolute_path(Dir.pwd)
      rescue Errno::ENOENT
        puts "no such directory"
      end
    end
    
    def cdf
      @dirhistory.forward
      puts
    end

    def cdb
      @dirhistory.back
      puts
    end

    def cdup
      Dir.chdir ".."
      @dirhistory.cd File.absolute_path(Dir.pwd)
      puts
    end

    def jobs
      @job_control.jobs.each do |job|
        puts "[#{job.id}] #{job.cmd}"
      end
    end

    def fg(*args)
      job = nil
      if args.length == 0
        if @job_control.last_stopped_job
          job = @job_control.last_stopped_job
        else
          # Find first stopped job
          job = @job_control.jobs.find{ |j| j.stopped? }
        end
      else
        job_id = args.first.to_i
        job = @job_control.jobs.find{ |j| j.id == job_id }
      end

      if job
        @job_control.put_in_foreground(job, true) if job.stopped?
        @notify_job_status_proc.call job
      else
        puts "#{$shell_name}: No such job"
      end
    end

  end
end
