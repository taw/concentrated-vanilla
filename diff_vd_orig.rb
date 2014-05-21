#!/usr/bin/ruby

require 'find_file'

Dir.glob("vanilla-dynamic/*").each{|file|
  orig_file = File.first_matching(File.basename(file), 'data', 'data/packed', 'data/imperial-campaign')
  system 'diff', '-u', orig_file, file
}
