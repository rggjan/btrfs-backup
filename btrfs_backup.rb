#!/usr/bin/ruby1.9.1
require 'fileutils'

def get_list()
  list = Dir[@dir + "/self_backups/*"]
  for i in 0...list.size
    tmp = list[i].split("-backup.")
    raise @dir + list[i] + " has wrong format!" if tmp.size != 2
    raise @dir + list[i] + " has wrong format in number!" if tmp[1].to_i.to_s != tmp[1]

    list[i]=[tmp[1].to_i, tmp[0]] # Converts "12-34-56-backup.7" to an Array entry [7, 12-34-56].
  end
  list.sort!
  list.compact!

  return list
end

def get_delete_name(dirlist)
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
    original=@dir.to_s+element[1].to_s+"-backup."+element[0].to_s
    incremented=@dir.to_s+element[1].to_s+"-backup."+(element[0]+1).to_s
    FileUtils.move(original, incremented)
  end
end

def backup()
  system("btrfsctl -s #{@dir}/self_backups/`date +%F`-backup.0 #{@dir}")
end

args = ARGV.reverse
backup_dir = nil
commands = Array.new

while args.size > 0
  argument = args.pop
  case argument
  when "--backup"
    commands << :backup
  else
    if backup_dir.nil?
      backup_dir = argument
    else
      puts "Unknown argument '#{argument}'!"
      exit
    end
  end
end

if commands.size == 0
  puts "Usage: ./btrfs_backup [--backup] /root/path"
else
  if commands.include?(:backup)
    if backup_dir.nil?
      raise "No backup directory!"
    else
      @dir = backup_dir
      raise if @dir.size < 1
      puts "Backing up #{@dir}"
      increment_names()
      backup()
    end
  end
end

#puts get_delete_name(dirlist)
