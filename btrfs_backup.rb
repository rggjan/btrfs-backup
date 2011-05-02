#!/usr/bin/ruby1.9.1
require 'fileutils'

def check_directory(directory_name)
  unless directory_name =~ /\A(\/[^\s\/]+)+\/?\z|\A\/\z/
    raise "Wrong directory format '#{directory_name}'"
  end

  # Cut off trailing "/" unless is root dir
  if directory_name[-1] == "/" and directory_name != "/"
    return directory_name[0...-1]
  end

  return directory_name
end

def get_list()
  list = Dir.entries(self_backup_dir) - [".", ".."]
  for i in 0...list.size
    tmp = list[i].split("-backup.")
    raise self_backup_dir + list[i] + " has wrong format!" if tmp.size != 2
    raise self_backup_dir + list[i] + " has wrong format in number!" if tmp[1].to_i.to_s != tmp[1]

    list[i]=[tmp[1].to_i, tmp[0]] # Converts "12-34-56-backup.7" to an Array entry [7, 12-34-56].
  end
  list.sort!
  list.compact!

  return list
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
  dirlist = get_list()
  dirlist.reverse.each do |element|
    original="#{self_backup_dir}#{element[1]}-backup.#{element[0]}"
    incremented="#{self_backup_dir}#{element[1]}-backup.#{element[0]+1}"
    FileUtils.move(original, incremented)
  end
end

RED="\033[1;31m"
GREEN="\033[1;32m"
WHITE="\033[0m"

def execute(command)
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
    raise "Wrong return value" unless $?.success?

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
        return
      else
        puts "Unknown answer..."
    end
  end
end

def self_backup_dir
  if @destination_dir == "/"
    return "/self_backups"
  else
    return @destination_dir + "/self_backups/"
  end
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

  while args.size > 0
    argument = args.pop
    case argument
    when "--backup"
      commands << :backup
    when "--delete"
      commands << :delete
    when "--status"
      commands << :status
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

  @destination_dir = check_directory(leftover_args.pop)
  @source_dir = check_directory(leftover_args.pop) if leftover_args.size > 0

  if commands.size == 0
    puts "Usage: ./btrfs_backup [--backup] [--delete] [/source/path] /target/path"
  else
    if commands.include?(:backup)
      unless @source_dir.nil?
        puts "\n#{GREEN}Syncing from #{@source_dir} to #{@destination_dir}#{WHITE}"
        additional_options = ""
        additional_options = " --exclude=/self_backups" if @dir == "/"
        
        options = "rsync --archive --one-file-system --hard-links --inplace --numeric-ids --progress --verbose --delete --exclude=/self_backups"
        options += additional_options
        options += " #{@source_dir} #{@destination_dir}/backups/`hostname`"
        execute(options)
      end

      puts "\n#{GREEN}Snapshotting #{self_backup_dir}#{WHITE}"
      execute("btrfsctl -s #{self_backup_dir}`date +%F`-backup.0 #{@destination_dir}")
      increment_names()
    end

    if commands.include?(:delete)
      delete_name = get_delete_name()
      puts "\n#{GREEN}Deleting #{delete_name}#{WHITE}"
      execute("btrfsctl -D #{delete_name} #{self_backup_dir}/")
    end

    puts "\n#{GREEN}Status of #{@destination_dir}#{WHITE}"
    system("btrfs fi df #{@destination_dir}")
  end
end
