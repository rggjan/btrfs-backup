#!/usr/bin/ruby
require 'fileutils'

def check_directory(directory_name)
  unless directory_name =~ /\A((([a-zA-Z]+@)?([0-9]{1,3}\.){3}[0-9]{1,3}:)?((\/[^\s\/]+)+\/?|\/))\z/
    raise "Wrong directory format '#{directory_name}'"
  end

  # Cut off trailing "/" unless is root dir
  if directory_name[-1] != "/"
    return directory_name + "/"
  end

  return directory_name
end

def get_list(params = {})
  list = Dir.entries(self_backup_dir) - [".", ".."]
  for i in 0...list.size
    tmp = list[i].split("-backup.")
    raise self_backup_dir + list[i] + " has wrong format!" if tmp.size != 2
    raise self_backup_dir + list[i] + " has wrong format in number!" if tmp[1].to_i.to_s != tmp[1]
    raise self_backup_dir + list[i] + " is left over!" if tmp[1].to_i == 0 and not params[:can_have_zero]

    list[i]=[tmp[1].to_i, tmp[0]] # Converts "12-34-56-backup.7" to an Array entry [7, 12-34-56].
  end
  list.sort!
  list.compact!

  return list
end

def check_backup_dir()
  get_list().each do |num, name|
    if (num == 0)
      raise "Have directory with number '0' left!"
    end
  end
end

def get_delete_name()
  dirlist = get_list()
  for i in 0...(dirlist.size-1)
    if (dirlist[i+1][0]-(2**i)).abs < (dirlist[i][0]-(2**i)).abs && dirlist[i][0] != 0 #Smarbs CORE, the secret formula :)
      deleted=true
      a = dirlist[i][1]
      b = dirlist[i][0]
      break
    end
  end

  if not deleted
    a = dirlist[-1][1]
    b = dirlist[-1][0]
  end
  return a + "-backup." + b.to_s
end

def increment_names()
  dirlist = get_list(:can_have_zero => true)
  dirlist.reverse.each do |element|
    original="#{self_backup_dir}#{element[1]}-backup.#{element[0]}"
    incremented="#{self_backup_dir}#{element[1]}-backup.#{element[0]+1}"
    FileUtils.move(original, incremented)
  end
end

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
WHITE="\033[0m"

def execute(command, params = {})
  answer = "?"

  puts "Execute #{RED}#{command}#{WHITE}?"

  while true
    print "(Y/n): "
    begin
      system("stty raw -echo")
      answer = STDIN.getc
    ensure
      system("stty -raw echo")
    end

    answer = answer.downcase

    p answer

    case answer
      when "n"
        puts "Not executing command..."
        return
      when "\u0003"
        puts "Not executing command... Exit..."
        exit
      when "y", "\r"
        system(command)
        raise "Wrong return value #{$?}" unless $?.success? or params[:can_fail]

        return
      else
        puts "Unknown answer..."
    end
  end
end

def self_backup_dir
  return @destination_dir + "self_backups/"
end

####################
# Begin of Program #
####################

# Main function
if __FILE__ == $0
  args = ARGV.reverse
  @source_dir = nil
  @destination_dir = nil
  @self_backup_dir = nil

  commands = Array.new
  leftover_args = Array.new

  rsync_args = ""
  while args.size > 0
    argument = args.pop
    case argument
    when "--backup"
      commands << :backup
    when "--delete"
      commands << :delete
    when "--status"
      commands << :status
    when "--hostname"
      commands << :hostname
      @hostname = args.pop
      raise "Wrong hostname '#{@hostname}'" unless @hostname =~ /\A[a-zA-Z0-9]+\z/
    when "--exclude"
      rsync_args += " --exclude=#{args.pop} "
    else
      leftover_args << argument
    end
  end

  if leftover_args.size > 2
    raise "Unknown argument '#{leftover_args[0]}'"
  end
  
  if leftover_args.size < 1
    leftover_args = ["/"]
  end

  @hostname = `hostname` if @hostname.nil? 
  @destination_dir = check_directory(leftover_args.pop)
  @source_dir = check_directory(leftover_args.pop) if leftover_args.size > 0

  if commands.size == 0
    puts "Usage: ./btrfs_backup [--backup] [--delete] [/source/path] /target/path"
  else
    if commands.include?(:delete)
      delete_name = get_delete_name()
      puts "\n#{BLUE}Deleting #{delete_name}#{WHITE}"
      execute("btrfsctl -D #{delete_name} #{self_backup_dir}", :can_fail => true)
    end

    if commands.include?(:backup)
      unless @source_dir.nil?
        puts "\n#{BLUE}Syncing from #{@source_dir} to #{@destination_dir}#{WHITE}"
        rsync_args += " --exclude=/self_backups " if @dir == "/"
        
        options = "rsync --archive --one-file-system --hard-links --inplace --numeric-ids --progress --verbose --delete --exclude=/self_backups"
        options += rsync_args
        options += " #{@source_dir} #{@destination_dir}backups/#{@hostname}"
        execute(options)
      end
      
      # TODO check if already -backup.0 there!
      puts "\n#{BLUE}Snapshotting #{self_backup_dir}#{WHITE}"
      date = `date +%F`.strip
      check_backup_dir()
      execute("btrfsctl -s #{self_backup_dir}#{date}-backup.0 #{@destination_dir}", :can_fail => true) # TODO wrong btrfs
      increment_names()
    end

    # Status output
    puts "\n#{BLUE}Self backups#{WHITE}"
    get_list().each do |number, date|
      puts "#{date} #{RED}=> #{RED}#{number}#{WHITE}"
    end

    puts "\n#{BLUE}Status of #{@destination_dir}#{WHITE}"
    mount_name = @destination_dir
    mount_name = mount_name[0...-1] unless mount_name[-1] != "/" or mount_name == "/"
    stats = `df -h #{mount_name}`.split("\n")[1].split

    free = stats[3]
    used = stats[4][0..-2]
    puts "Free: #{GREEN}#{free}#{WHITE} / Used: #{RED}#{used}%#{WHITE}"

    if (commands.include?(:backup))
      max_used = 80
      if (used.to_i > max_used)
        delete_name = get_delete_name()
        puts "\n#{BLUE}Deleting #{delete_name}, used > #{max_used}%#{WHITE}"
        execute("btrfsctl -D #{delete_name} #{self_backup_dir}", :can_fail => true)
      end
    end
  end
end
