#!/usr/bin/ruby1.9.1

def get_list(list)
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

puts "Listing #{ARGV[0]}"
dirlist = get_list(Dir[ARGV[0] + "/*"])
puts get_delete_name(dirlist)
