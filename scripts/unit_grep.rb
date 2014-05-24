#!/usr/bin/env ruby

require "pp"

def read_data_file(fn)
  File.read("/home/taw/m2tw-cv-mod/m2tw/data/packed/#{fn}").gsub(/\r/, '').gsub(/[ \t]*\n/, "\n")
end

units = read_data_file('export_descr_unit.txt').split(/\n{2,}/).grep(/\Atype/)

buildings = read_data_file('export_descr_buildings.txt').scan(/^building.*\n\{\n(?:\s+.*\n)*?\}\n/)

# The first number is the starting number of points.
# The second number is the number of points that the building gains each turn.
# The third number is the maximum number of points.
# The last number, which must be between 0 and 9, is the starting experience of the units trained there. 
recruit_pools = {}
buildings.each{|b|
  b =~ /\Abuilding\s+(.*)/
  type = $1
  levels = []
  levels_rx = false
  level = nil
  b.each_line{|line|
    #puts line
    case line
    when /\A\s+levels\s+(.*)/
      levels = $1.split(/\s+/)
      levels_rx = Regexp.new("\\A\\s*(#{levels.map{|x| Regexp.escape(x)}.join("|")})\\s+(city|castle|)\s*(.+)")
    when levels_rx
      level = [$1, $2, $3]
      level[1] = 'any' if level[1] == ''
#      puts "Here starts: #{level.join(" - ")}"
    when /\A\s+recruit_pool\s*"([^"]+)"\s+(.*)/
      (recruit_pools[$1] ||= []) << [type] + level + [$2]
    end
  }
}

units.each{|u|
  u =~ /\Atype\s+(.*)/
  un = $1
  ps = recruit_pools[un]
  next unless ps.to_s =~ /gunpowder_discovered/
  next if u =~ /^category\b*(siege|ship)/
  puts u
  pp ps
  puts ""
}
