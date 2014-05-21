#!/usr/bin/env ruby1.9

require "./concentrated_vanilla"

M2TW_Mod.new({
  :cai => false,
  :bai => true,
  :strat => true,
}) do
  ### Setup map
  add_regions!

  ### Building tree
  # single_settlement_type!
  # simplify_building_tree_1_type!
  # simplify_building_tree_2_types!

  ### Settlement
  construction_time_one_turn!
  building_cost!(1.5, 1.0)
  religion_bonus!(1.5)
  # rearrange_resource_values!
  # resource_value!(1.5) # 2.5 is way too much, especially with trade or mine bonuses
  # trade_bonus!(1.0)
  mine_resource!(2.0) # this gets multiplied by resource value, so don't overdo
  # all_buildings_available!
  villages_800_people!
  # no_siege!
  # increase_settlement_size!
  # increase_settlement_size! # double increase !
  distance_to_capital_penalty!(0.2, 0.3)

  ### Unit tree
  # simplify_unit_tree!
  # remove_siege_units!

  ### Unit recruitment and upkeep
  big_garrisons!
  more_recruitment_slots!
  # free_retraining! # Doesn't work anyway, even with both xmls
  unit_cost!(1.0, 0.6)

  ### Basic settings
  # taxes_influence_on_growth!(0.0) # stop tax shenanigans
  # king_purse!(1.5)
  rebel_spawn_rates!(5)
  plaza_capture!(1.0, 0.95)
  fix_standing!
  # all_mercenaries_available!
  more_mercenaries!(2.0, 4.0, 0.25)
  # no_rebels!
  show_date_as_year!
  # more_rebels!

  ### Campaign
  random_seed!(ENV["RANDOM_SEED"] || "0")
  # silicy_scenario!
  # byzantine_scenario!
  # random_scenario!({
  #   "byzantium"    => 4..9,
  #   "moors"        => 4..9,
  #   "turks"        => 4..9,
  #   "egypt"        => 4..9,
  #   "russia"       => 4..9,
  #   "hre"          => 2..7,
  #   "france"       => 2..7,
  #   "scotland"     => 2..7,
  #   "hungary"      => 2..7,
  #   "venice"       => 2..7,
  #   "milan"        => 2..7,
  #   "spain"        => 2..7,
  #   "sicily"       => 2..7,
  #   "england"      => 2..7,
  #   "poland"       => 2..7,
  #   "portugal"     => 2..7,
  #   "denmark"      => 2..7,
  #   "papal_states" => 2..7,
  # }, 0.8)
  # start_wars!
  more_initial_rebels!
  # epic_armies!
  long_campaign_regions_to_take!(50)

  ### Captain obvious
  reduce_captain_obvious!
  # remove_useless_sounds!

  ### Crusades
  fast_crusades!
  min_jihad_piety!(2)
  crusades_everywhere!
  no_crusade_disband!
  older_cardinals!

  ### Events
  move_event!('mongols_invasion_warn', 1208..1224)
  move_event!('gunpowder_discovered', 1290..1300)
  move_event!('timurids_invasion_warn', 1368..1384)
  move_event!('world_is_round', 1400..1408)
  move_event!('first_printing_press', 1454..1454)

  ### CAI
  # ai_personality!("sailor", "henry")
  fix_naval_autoresolve! # It doesn't seem to be doing anything whatsoever...

  ### BAI - contrary to internet these are BAI-only settings without CAI effects
  sally_out_ratio!(0.65)
  stronger_ratio!(0.65)

  ### Agents
  remove_agents!('merchant')
  # remove_agents!('spy')
  # remove_agents!('assassin')
  campaign_movement_speed!(1.5)
  agent_speed!('diplomat', 5.0)
  agent_speed!('princess', 5.0)
  agent_speed!('merchant', 3.0)
  agent_speed!('spy', 3.0)
  agent_speed!('assassin', 3.0)
  agent_speed!('priest', 3.0)
  # spy_cost!(2.0)
  # high_fertility! # good idea but maybe too extreme

  ### Guilds
  # add_guilds!
  # alt_guild_system!
  # better_guild_units! # units are modded here and later, order matters...
  easy_guilds!

  ### Units
  # bodyguard_size!(0.5)
  # cavalry_cost!(1.0, 0.5)
  missile_infantry_ammo!(2.0)
  # missile_infantry_size!(0.75)
  all_archers_stakes!
  artillery_range_ammo!(1.0, 2.5)
  artillery_size!(1.0, 1.5)
  # basic_infantry_garrisonned_for_free!
  # low_morale!
  # cavalry_size!(0.75)
  # increase_unit_defense!
  mod_unit_attack!(0.6)
  # mod_unit_charge!(1.5)
  nerf_rams!
  increase_artillery_accuracy!(2.25)
  mod_mercenary_cost!(1.25, 1.25)
  mod_unit_upgrade_cost!(0.0)

  ### Units - bug workarounds (with pretty massive balance implications)
  ### (pikes are extremely powerful with this as long as they stay in formation)
  fix_rubber_swords!
  no_fire_by_rank!

  ### Sieges
  wall_control_area!(4.0) # Not sure if setting it lower than 1.0 actually does much, even if >1.0 definitely should
  # wall_strength!(3.0, 1.0)
  tower_fire_rate!(3.0, 1.0)
  rebalance_wall_arrows!(3)
end
