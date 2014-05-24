#!/usr/bin/ruby

class Array
  def group_on(cr)
    res = []
    each{|x|
      res << [] if x =~ cr
      res[-1] << x
    }
    res
  end
  def ungrep(cr)
    res = []
    each{|x| res << x if x !~ cr}
    res
  end
end

def read_data(file_name)
  File.read(file_name).gsub(/\r/, '').gsub(/;.*?\n/, '').split(/\n/)
end

projectiles = read_data('data/packed/descr_projectile.txt').
              grep(/\A(projectile|damage\s)/).group_on(/\Aprojectile/).
              map{|lines|lines.join("\n")+"\n\n"}.ungrep(/^damage\s*0/).
              ungrep(/^projectile\s*(norman|fiery_norman|test|tarred_rock|bolt|tower)/)
proj = {}

projectiles.each{|txt|
  txt =~ /projectile\s*(\S+)\ndamage\s*(\d+)/
  proj[$1] = $2.to_i
}

units = read_data('data/packed/export_descr_unit.txt').
        grep(/\A(type|stat_(pri|sec|ter)\s+.*missile, artillery)|stat_cost/).ungrep(/cow_carcass/).
        map{|line| line.sub(/, (siege_)?missile, artillery_(gunpowder|mechanical), (blunt|piercing), none, 25, 1/, '') }.
        group_on(/\Atype/).map{|lines| lines.join("\n")+"\n\n"}.ungrep(/Norman/).
        grep(/stat_(pri|sec|ter)/).map{|x| x.gsub(/(type\s*)(?:NE|EE|GR|ME|AS|Mercenary) (.*)/){"#{$1}#{$2}"}}.
        uniq.sort

units = units.map{|txt|
  txt =~ /type\s*(.*?)\n/
  name = $1
  txt =~ /stat_(?:pri|sec|ter)\s*(.*?)\n/
  p, range, ammo = $1.split(/,\s*/)[2,3]
  range, ammo = range.to_i, ammo.to_i
  damage = proj[p]
  txt =~ /stat_cost\s*(.*?)\n/
  cost, upkeep = $1.split(/,\s*/)[1,2].map{|x|x.to_i}
  
  {:name => name, :damage => damage, :ammo => ammo, :range => range, :cost => cost, :upkeep => upkeep}
}

units.sort_by{|u| u[:range]}.each{|u|
  ca = sprintf "%d%%", u[:ammo]*u[:damage] / 9.0
  puts "#{u[:name]} - #{u[:ammo]}x#{u[:damage]} damage at range #{u[:range]} [#{ca}, #{u[:cost]}+#{u[:upkeep]}]"
}
