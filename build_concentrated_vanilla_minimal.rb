#!/usr/bin/env ruby

require "./concentrated_vanilla"

M2TW_Mod.new do
  ### Setup map
  add_regions!
  show_date_as_year!
  reduce_captain_obvious!
end
