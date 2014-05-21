#!/usr/bin/ruby

require 'find_file'

Dir.glob("vanilla-dynamic/*").each{|file|
  dist_file = File.first_matching(File.basename(file),
                                  'mod/vanilla-dynamic/data',
                                  'mod/vanilla-dynamic/data/world/maps/campaign/imperial_campaign')
  system 'diff', '-u', file, dist_file
}
