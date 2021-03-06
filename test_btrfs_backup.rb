#!/usr/bin/ruby1.9.1
require 'test/unit'
require './btrfs_backup.rb'

def assert_raise_message(expected_message)
  message = assert_raise RuntimeError do
     yield
   end
   assert_equal(expected_message, message.to_s)
end

class TestBtrfsBackup < Test::Unit::TestCase

  def test_check_directory
    ["abc", "//abc", "19.2.2:/", "@192.168.2.2:/jan", "//", "", "/ab c/", "/abc//de"].each do |directory|
      assert_raise_message("Wrong directory format '#{directory}'") do
        check_directory(directory)
      end
    end

    assert_equal "/", check_directory("/")
    assert_equal "/abc", check_directory("/abc")
    assert_equal "/abc", check_directory("/abc/")
    assert_equal "/abc_defGH/ij", check_directory("/abc_defGH/ij")
    assert_equal "192.168.2.22:/", check_directory("192.168.2.22:/")
    assert_equal "jan@192.168.2.22:/", check_directory("jan@192.168.2.22:/")
    assert_equal "jan@192.168.2.22:/abc", check_directory("jan@192.168.2.22:/abc/")
  end


  def test_execute
    assert_raise_message("Wrong return value") do
      execute("ls /utirane")
    end
  end


end
