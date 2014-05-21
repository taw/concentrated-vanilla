#!/usr/bin/ruby

require 'pp'

###########################################################
# RAW DATA                                                #
###########################################################
def units
  File.open('data/packed/export_descr_unit.txt').readlines
end

def strat
  File.open('data/imperial-campaign/descr_strat.txt').readlines
end

###########################################################
# REPORTS                                                 #
###########################################################
def factions
  unless @factions
    lines = strat.map{|line| line.gsub(/\r\n/, "")}
    @factions = lines[lines.index("playable")..lines.index("\tslave")].grep(/\A\t/).map{|line| line.gsub(/\t/, "")}.sort
  end
  @factions
end

def faction_standings
  ft = {}
  factions.each{|f|
    ft[f] = {}
  }
  strat.grep(/\Afaction_standings\s+/).map{|line|
    line.gsub(/(\s|,)+/, ' ').gsub(/\Afaction_standings /, '').split(/ /)
  }.each{|from, value, *tos|
    tos.each{|to|
      next if to == 'slave'
      ft[from][to] = value
    }
  }
  ft
end

if ARGV[0] =~ /\A--([a-zA-Z0-9_]+)\Z/
  pp send($1)
end
