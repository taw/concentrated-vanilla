#!/usr/bin/env jruby

$: << "./cheri/lib"

require "rubygems"
require 'cheri/swing'
require "pp"
require "fileutils"
require "./concentrated_vanilla"

class ModInstaller
  def initialize
    begin
      require "win32/registry"
      @windows = true
    rescue LoadError
      @windows = false
    end
  end

  def hklm
    Win32::Registry::HKEY_LOCAL_MACHINE
  end

  def retail_path
    return nil unless @windows
    @retail_path ||= (hklm.open('SOFTWARE\Wow6432Node\SEGA\Medieval II Total War')["AppPath"] rescue nil)
  end

  def steam_m2_path
    return nil unless @windows
    @steam_m2_path ||= (hklm.open('SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 4700')["InstallLocation"] rescue nil)
  end

  def steam_kingdoms_path
    return nil unless @windows
    @steam_kingdoms_path ||= (hklm.open('SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 4780')["InstallLocation"] rescue nil)
  end

  def detect_medieval_2!
    if @windows
      puts "You're running Windows"
      puts "Retail Medieval 2 path: `#{retail_path}'"
      puts "Steam Medieval 2 path: `#{steam_m2_path}'"
      puts "Steam Kingdoms path: `#{steam_kingdoms_path}'"
    else
      puts "Windows not detected"
    end
  end
  
  def target_directory
    @target_directory ||= [retail_path, steam_m2_path, steam_kingdoms_path].compact[0]
  end
  
  def installable?
    !!target_directory
  end

  def install!
    unless target_directory
      puts "No Medieval 2 installation detected, manual installation required"
      return
    end
    
    FileUtils.rm_rf "#{target_directory}/mods/concentrated_vanilla/data"
    FileUtils.mkdir_p "#{target_directory}/mods/concentrated_vanilla/"
    FileUtils.cp "output/concentrated_vanilla.bat", "#{target_directory}/concentrated_vanilla.bat"
    FileUtils.cp "output/mods/concentrated_vanilla/concentrated_vanilla.cfg",
                 "#{target_directory}/mods/concentrated_vanilla/concentrated_vanilla.cfg"
    FileUtils.cp_r "output/mods/concentrated_vanilla/data", "#{target_directory}/mods/concentrated_vanilla/"
    
    cv = hklm.create('SOFTWARE\Wow6432Node\SEGA\Medieval II Total War\Mods\Unofficial\Concentrated Vanilla')
    cv["Author"]="Tomasz Wegrzanowski"
    cv["ConfigFile"]="concentrated_vanilla.cfg"
    cv["DisplayName"]="Concentrated Vanilla"
    cv["FullName"]="Concentrated Vanilla"
    cv["Language"]="english"
    cv["Path"]="mods/concentrated_vanilla"
    cv["Version"]="0.60"
    cv["GameExe"]="medieval2.exe"
  end

  def uninstall!
    FileUtils.rm_f "#{target_directory}/concentrated_vanilla.bat"
    FileUtils.rm_rf "#{target_directory}/mods/concentrated_vanilla/data"
    hklm.delete_key('SOFTWARE\Wow6432Node\SEGA\Medieval II Total War\Mods\Unofficial\Concentrated Vanilla', true)
  end

  def run_game!
    Dir.chdir(target_directory){
      system "medieval2.exe @mods/concentrated_vanilla/concentrated_vanilla.cfg"
    }
  end
end

def build_mod!(settings)
  s = Hash.new{|ht,k| raise "Field #{k} not in settings"}
  settings.each{|sn,sv|
    s[sn.sub(/\A[^-]+-/, "")] = sv
  }
  M2TW_Mod.new({
    :cai   => s["include_cai"],
    :bai   => s["include_bai"],
    :strat => s["include_strat"],
  }) do
    ### Setup map
    add_regions!

    ### Building tree
    case s["settlement_basic"]
    when "normal"
      # default
    when "one_type"
      single_settlement_type!
    when "simple_two"
      simplify_building_tree_2_types!
    when "simple_one"
      single_settlement_type!
      simplify_building_tree_1_type!
    end
    construction_time_one_turn! if s["construction_one_turn"]
    building_cost! s["construction_cost"], s["mine_cost"]
    religion_bonus! s["conversion_rate"]
    resource_value! s["resource_value"]
    trade_bonus! s["trade_bonus"]
    mine_resource! s["mine_resource"]
    all_buildings_available! if s["all_buildings_available"]
    villages_800_people! if s["village_800_minimum"]
    no_siege! if s["no_siege"]
    case s["settlement_size"]
    when "increased_1"
      increase_settlement_size!
    when "increased_2"
      increase_settlement_size!
      increase_settlement_size!
    end
    distance_to_capital_penalty! s["distance_to_capital_corruption"], s["distance_to_capital_unrest"]

    ### Unit tree
    remove_siege_units! if s["no_siege"]

    ### Unit recruitment and upkeep
    big_garrisons! if s["big_garrisons"]
    more_recruitment_slots! if s["more_recruitment_slots"]
    unit_cost! s["unit_cost"], s["unit_upkeep"]

    ### Basic settings
    king_purse! s["kings_purse"]
    rebel_spawn_rates! s["rebel_spawn_rates"]
    plaza_capture! s["plaza_capture_timeout"], s["plaza_capture_ratio"]
    fix_standing!
    all_mercenaries_available! if s["all_mercenaries_available"]
    more_mercenaries!(2.0, 4.0, 0.25) if s["more_mercenaries"]
    show_date_as_year! if s["display_year"]

    ### Campaign
    random_seed! s["random_seed"]
    random_scenario!({
      "byzantium"    => s["region_count_byzantium"],
      "moors"        => s["region_count_moors"],
      "turks"        => s["region_count_turks"],
      "egypt"        => s["region_count_egypt"],
      "russia"       => s["region_count_russia"],
      "hre"          => s["region_count_hre"],
      "france"       => s["region_count_france"],
      "scotland"     => s["region_count_scotland"],
      "hungary"      => s["region_count_hungary"],
      "venice"       => s["region_count_venice"],
      "milan"        => s["region_count_milan"],
      "spain"        => s["region_count_spain"],
      "sicily"       => s["region_count_sicily"],
      "england"      => s["region_count_england"],
      "poland"       => s["region_count_poland"],
      "portugal"     => s["region_count_portugal"],
      "denmark"      => s["region_count_denmark"],
      "papal_states" => s["region_count_papal_states"],
    }, 1.0 - s["cluster_allocation"], s["allocate_rebels_last"]) if s["random_scenario"]
    more_initial_rebels! if s["more_initial_rebels"]
    epic_armies! if s["epic_armies"]
    long_campaign_regions_to_take! s["regions_to_take"].to_i

    ### Captain obvious
    reduce_captain_obvious!
    
    ### Crusades
    fast_crusades! if s["fast_crusades"]
    min_jihad_piety! s["min_jihad_piety"]
    crusades_everywhere! if s["crusade_everywhere"]
    no_crusade_disband! if s["no_crusade_disband"]
    older_cardinals! if s["older_cardinals"]

    ### Events
    move_event! 'mongols_invasion_warn', s["event_mongols"]
    move_event! 'gunpowder_discovered', s["event_gunpowder"]
    move_event! 'timurids_invasion_warn', s["event_timurids"]
    move_event! 'world_is_round', s["event_world_is_round"]
    move_event! 'first_printing_press', s["event_printing_press"]

    fix_naval_autoresolve!

    ### BAI
    sally_out_ratio! s["sally_out_ratio"]
    stronger_ratio! s["sally_out_ratio"]

    ### Agents
    remove_agents!('merchant') if s["remove_merchant"]
    remove_agents!('spy') if s["remove_spy"]
    remove_agents!('assassin') if s["remove_assassin"]
    campaign_movement_speed! s["campaign_speed"]
    agent_speed! 'diplomat', s["agent_speed_diplomat"]
    agent_speed! 'princess', s["agent_speed_princess"]
    agent_speed! 'merchant', s["agent_speed_merchant"]
    agent_speed! 'spy', s["agent_speed_spy"]
    agent_speed! 'assassin', s["agent_speed_assassin"]
    agent_speed! 'priest', s["agent_speed_priest"]
    
    spy_cost! s["spy_cost"]

    # ### Guilds
    easy_guilds! if s["easy_guilds"]
    
    ### Units
    bodyguard_size! s["bodyguard_size"]
    cavalry_cost! s["cavalry_cost"], s["bodyguard_cost"]
    cavalry_size! s["cavalry_size"]
    missile_infantry_ammo! s["missile_infantry_ammo"]
    missile_infantry_size! s["missile_infantry_size"]
    all_archers_stakes! if s["all_archers_stakes"]
    artillery_range_ammo! s["artillery_range"], s["artillery_ammo"]
    artillery_size! s["artillery_crew"], s["artillery_engines"]
    increase_artillery_accuracy! s["artillery_accuracy"]
    basic_infantry_garrisonned_for_free! if s["more_garrison_units_free"]
    low_morale! if s["low_morale"]
    increase_unit_defense! if s["increase_unit_defense"]
    mod_unit_attack! s["unit_attack"]
    mod_unit_charge! s["unit_charge"]
    mod_mercenary_cost! s["mercenary_recruitment"], s["mercenary_upkeep"]
    mod_unit_upgrade_cost!(0.0) if s["free_unit_upgrade"]
    nerf_rams! if s["nerf_rams"]
    do_not_start_skirmishing! if s["do_not_start_skirmishing"]
    
    ### Units - bug workarounds
    fix_rubber_swords! if s["remove_rubber_swords"]
    no_fire_by_rank! if s["remove_gunpowder_fire_by_rank"]

    ### Sieges
    wall_control_area! s["wall_control_area"]
    wall_strength! s["wall_strength"], s["tower_strength"]
    tower_fire_rate! s["tower_normal_arrows_rate"], s["tower_flaming_arrows_rate"]
    rebalance_wall_arrows! s["tower_arrow_attack"]
  end
end

class ConcentratedVanillaBuilder
  include Cheri::Swing

  def initialize
    @installer = ModInstaller.new
    @installer.detect_medieval_2!
    
    @controls = {}
    @frame = swing.frame('Concentrated Vanilla builder'){ |frm|
      size 800, 800
      default_close_operation :EXIT_ON_CLOSE
      build_menu!
      scroll_pane {
        panel {
          grid_bag_layout
          grid_table {
            background :WHITE
            build_form!
          }
        }
      }
    }
    load_settings! load_settings_file("settings/default.txt")
    @frame.visible = true
  end

  def load_settings_file(path)
    rv = {}
    File.open(path, 'rb').each_line{|line|
      line.sub!(/#.*/, "")
      line.strip!
      next unless line =~ /\S/
      sn, sv = line.split(/\s*=\s*/)
      sv = (sv == "true") if sn =~ /\Acheckbox-/
      sv = sv.to_f if sn =~ /\Afloat-/
      sv = sv.to_i if sn =~ /\Aint-/
      if sn =~ /\Arange-/
        raise "Not a range: #{sv}" unless sv =~ /\A(\d+)\.\.(\d+)\z/
        sv = ($1.to_i)..($2.to_i)
      end
      rv[sn] = sv
    }
    rv
  end

  def load_settings!(settings)
    @controls.each{|cn,cc|
      cv = settings[cn]
      case cn
      when /\Atext-/
        cc.set_text((cv || "").to_s)
      when /\Afloat-/
        cc.set_text((cv || "1.0").to_s)
      when /\Aint-/
        cc.set_text((cv || "0").to_s)
      when /\Aselection-/
        # skip
      when /\Arangemin-(.*)/
        cc.set_text(((settings["range-#{$1}"] || (0..0)).begin).to_s)
      when /\Arangemax-(.*)/
        cc.set_text(((settings["range-#{$1}"] || (0..0)).end).to_s)
      when /\Aradio-(.*?)-(.*)/
        cc.selected = (settings["selection-#{$1}"] == $2)
      when /\Acheckbox-/
        cc.selected = !!cv
      else
        warn "Unknown control type: #{cn}"
      end
    }
  end

  def current_settings
    rv = {}
    @controls.each{|cn,cc|
      case cn
      when /\Atext-/
        rv[cn] = cc.get_text
      when /\Afloat-/
        rv[cn] = cc.get_text.to_f
      when /\Aint-/
        rv[cn] = cc.get_text.to_i
      when /\Aselection-/
        # skip
      when /\Arange-/
        # skip
      when /\Arangemin-(.*)/
        rv["range-#{$1}"] ||= [nil, nil]
        rv["range-#{$1}"][0] = cc.get_text.to_i
      when /\Arangemax-(.*)/
        rv["range-#{$1}"] ||= [nil, nil]
        rv["range-#{$1}"][1] = cc.get_text.to_i
      when /\Aradio-(.*?)-(.*)/
        rv["selection-#{$1}"] = $2 if cc.selected
      when /\Acheckbox-/
        rv[cn] = cc.selected
      else
        warn "Unknown control type: #{cn}"
      end
    }
    rv.each{|sn,sv|
      rv[sn] = sv[0]..sv[1] if sn =~ /\Arange-/
    }
    rv
  end

  def command_build!
    build_mod!(current_settings)
    puts "Build complete"
  end

  def command_open!
    fc = swing.file_chooser("settings")
    rv = fc.show_open_dialog(@frame)
    fn = fc.get_selected_file
    if rv == 0
      load_settings! load_settings_file(fn.path)
    end
  end

  def command_save!
    fc = swing.file_chooser("settings")
    rv = fc.show_save_dialog(@frame)
    fn = fc.get_selected_file
    if rv == 0
      File.open(fn.path, 'wb'){|fh|
        current_settings.sort.each{|k,v|
          fh.puts "#{k} = #{v}"
        }
      }
    end
  end
  
  def command_map!
    system "jruby", "./draw_political_map.rb"
  end

  def build_menu!
    menu_bar { 
      menu('File') {
        menu_item('Build') {
          on_click { command_build! }
        }
        if @installer.installable?
          menu_item('Install') {
            on_click { @installer.install! }
          }
          menu_item('Uninstall') {
            on_click { @installer.uninstall! }
          }
          menu_item('Run game (retail)') {
            on_click { @installer.run_game! }
          }
        end
        menu_item('Open...') {
          on_click { command_open! }
        }
        menu_item('Save...') {
          on_click { command_save! }
        }
        menu_item('Generate Map TGA') {
          on_click { command_map! }
        }
        menu_item('Exit') {
          on_click { @frame.dispose }
        }
      }
    }
  end

  ### UI builder helper methods
  def help_text(msg)
    grid_row{
      text_area(:a => :w, :gridwidth => 3){
        editable false
        text msg.gsub(/^\s+/, "")
      }
    }
  end

  def h1(msg)
    font = java.awt.Font.new('Dialog', java.awt.Font::BOLD, 24)
    grid_row{
      text_area(:a => :w, :gridwidth => 3){
        set_font font
        editable false
        text msg
      }
    }
  end

  def h3(msg)
    font = java.awt.Font.new('Dialog', java.awt.Font::BOLD, 18)
    grid_row{
      text_area(:a => :w, :gridwidth => 3){
        set_font font
        editable false
        text msg
      }
    }
  end

  def checkbox(name, description)
    grid_row{
      @controls["checkbox-#{name}"] = swing.check_box description, :a => :w, :gridwidth => 3
    }
  end

  def radio(group, name, description)
    @controls["selection-#{group}"] ||= button_group
    grid_row{
      b = swing.radio_button(description, :a => :w, :gridwidth => 3)
      @controls["radio-#{group}-#{name}"] = b
      @controls["selection-#{group}"].add b
    }
  end

  def text_field(name, description)
    grid_row{
      @controls["text-#{name}"] = swing.text_field "", :a => :e, :f => :h, :wx => 0.1
      label description, :a => :w, :gridwidth => 2, :wx => 0.5
    }
  end

  def float_field(name, description)
    grid_row{
      @controls["float-#{name}"] = swing.text_field "", :a => :e, :f => :h, :wx => 0.1
      label description, :a => :w, :gridwidth => 2, :wx => 0.5
    }
  end

  def int_field(name, description)
    grid_row{
      @controls["int-#{name}"] = swing.text_field "", :a => :e, :f => :h, :wx => 0.1
      label description, :a => :w, :gridwidth => 2, :wx => 0.5
    }
  end
  
  def range_field(name, description)
    grid_row{
      @controls["rangemin-#{name}"] = swing.text_field "", :a => :e, :f => :h, :wx => 0.1
      @controls["rangemax-#{name}"] = swing.text_field "", :a => :e, :f => :h, :wx => 0.1
      label description, :a => :w, :gridwidth => 1, :wx => 0.5
    }
  end

  ### Build the form
  def build_form!
    h1 "Concentrated Vanilla Builder"
  
    ###
    h3 "Instructions"
    help_text "Most numbers in the settings are values to be multiplied, so 1.0 usually means no change."
    help_text "Not all combinations of options will result in meaningful results."

    ###
    h3 "Included submods"
    help_text "CAI enchantments based on Lusted's Better CAI.
    They make AI smarter, but more passive, especially on highly random map,
    so your choice."
    checkbox :include_cai, "Lusted's CAI mod"
    help_text "BAI enchancements based on Sinuhet's Battle Mechanics and Lusted's Better BAI"
    checkbox :include_bai, "BAI improvements Sinuhet and Lusted"
    help_text "Agart's better settlement models for campaign maps (purely visual)"
    checkbox :include_strat, "Agart's settlement models"

    ###
    h3 "Building tree"
    help_text "One settlement type lets cities build both city-type and castle-type units.
               Simplified building tree makes city or castle walls automatically serve as most buildings,
               if you don't care much for settlement management.
               Using any of these options will result in unusual gameplay,
               but they're not necessarity compatible with everything below."

    radio :settlement_basic, :normal, "Cities and castle, full building tree"
    radio :settlement_basic, :one_type, "Cities only, full building tree"
    radio :settlement_basic, :simple_two, "Cities and castle, simple building tree"
    radio :settlement_basic, :simple_one, "Cities only, simple building tree"

    ###
    h3 "Settlements"
    help_text "Making construction faster but more expensive makes money matter more,
               and can lead to more dynamic campaign."
    
    checkbox :construction_one_turn, "All construction in one turn"
    float_field :construction_cost, "Construction cost (1.0 - vanilla)"
    
    help_text "Making resources more valuable increases income from trade, merchant trade, and mining.
               Values like 2.5 or more may lead to being flooded by money mid-campaign."
    float_field :resource_value, "Resource values (1.0 - vanilla)"
    
    help_text "If you want regions with minable resources to matter more, adjust this."
    help_text "Cost can be adjusted simultaneously for balance."
    float_field :mine_resource, "Mine income (1.0 - vanilla, also multiplied by resource value)"
    float_field :mine_cost, "Mines cost (1.0 - vanilla, also multiplied by construction cost)"
  
    help_text "Religious conversion can be somewhat slow,
               especially for random scenarios.
               This only affects buildings, not priests"
    float_field :conversion_rate, "Religious conversion rate (1.0 - vanilla)"
    
    help_text "Trade resource multiplier. Affects trade and merchant trade.
    Resource values is also multiplied by this.
    High numbers can make coastal settlements flooded with money."
    float_field :trade_bonus, "Trade bonus modifiers (1.0 - vanilla)"
  

    help_text "If you don't want to wait for events like gunpowder/printing press/world is round etc."
    checkbox :all_buildings_available, "Make all buildings available"

    help_text "Tiny villages can take very long time to grow.
    Doubling minimum population can fix it if you're impatient"
    checkbox :village_800_minimum, "Increase minimum village population to 800 people"

    help_text "If you want to play without siege artillery either for difficulty,
    or because you enable early game gunpowder."
    checkbox :no_siege, "Remove mechanical artillery"
    
    help_text "For quick-and-dirty late campaign mode you can just increase settlement sizes"
    radio :settlement_size, :normal, "Normal size"
    radio :settlement_size, :increased_1, "Increase size by one level (population x2)"
    radio :settlement_size, :increased_2, "Increase size by two levels (population x4)"
    
    help_text "Default penalties due to distance can be very high.
    Especially if you want to colonize Americas or play random scenario,
    it's a good idea to decrease them."
    float_field :distance_to_capital_corruption, "Corruption due to distance to capital (1.0 - vanilla)"
    float_field :distance_to_capital_unrest, "Unrest due to distance to capital (1.0 - vanilla)"

    ###
    h3 "Unit recruitment and upkeep"
    checkbox :big_garrisons, "Bigger garrisons for free"
    checkbox :more_recruitment_slots, "More recruitment slots"
    float_field :unit_cost, "Unit recruitment cost (1.0 - vanilla)"
    float_field :unit_upkeep, "Unit upkeep (1.0 - vanilla)"
    
    ###
    h3 "Basic settings"
    checkbox :display_year, "Display date as year (vanilla displays turn number)"
    help_text "Increasing King's Purse helps smaller factions"
    float_field :kings_purse, "Kings' Purse (1.0 - vanilla)"
    help_text "Higher rebel spawn values means LESS frequent spawning"
    float_field :rebel_spawn_rates, "Rebel spawn rates (1.0 - vanilla)"
    help_text "Vanilla plaza capture timeout of 3 minutes is very long,
    and it's pretty much impossible to prevent enemy from coming back in that time.
    Lower values add some strategy, but they can also be abused."
    float_field :plaza_capture_timeout, "Plaza capture timeout (vanilla - 3.0)"
    help_text "Plaza is considered controlled by attacker if at least this % of troops are attackers.
    Very high values prevent Rome Total War problem of single routing soldier
    reaching plaza and reseting the clock.
    On the other hand AI doesn't know this value isn't 100% (like Rome),
    and may stands idle in plaza while timer ticks."
    float_field :plaza_capture_ratio, "Attacker ratio to capture plaza (vanilla - 0.8)"
    help_text "Make all mercenaries available regardless of date and events (like gunpowder).
    Region, religion, pool size etc. restrictions still apply."
    checkbox :all_mercenaries_available, "All mercenaries available"
    help_text "Larger pools make mercenaries more important"
    checkbox :more_mercenaries, "Larger mercenaries pool"

    ###
    h3 "Campaign scenario"
    help_text "Same random seed not guaranteed to produce same scenario for different version."
    text_field :random_seed, "Random seed"
    checkbox :random_scenario, "Enable random scenario"
    help_text "Give all rebel settlements larger armies to slow down early game blitz"
    checkbox :more_initial_rebels, "Larger armies in rebel settlements"
    help_text "Give every faction's king and heir a full stack of good units for instant carnage."
    checkbox :epic_armies, "Epic armies"
    help_text "There are more regions on the map, so small increase to keep it proportional."
    int_field :regions_to_take, "Regions to take to win long campaign (vanilla - 45)"
    help_text "What portion of settlements to allocate by clustering.
    0.0 - fully random all over the map
    1.0 - near other settlements of same faction if possible"
    float_field :cluster_allocation, "Cluster allocation"
    help_text "By default rebels are allocated randomly first.
    You can make factions cluster even more if you make rebels get leftovers instead.
    There's no point using this option unless your clustering setting is near 1.0
    and you still want more clustering."
    checkbox :allocate_rebels_last, "Allocate rebels last"
    help_text "How many settlements to give various factions (min..max)
    Each faction gets random number of settlements from its range.
    If too many settlements are allocated this way, reduce numbers proportionally,
    but each faction gets at least 1.
    If not all settlements are allocated, the rest goes to rebels.
    For more fair campaign you might want to give non-Catholics a few extra settlements."
    range_field :region_count_byzantium, "Byzantium"
    range_field :region_count_denmark, "Denmark"
    range_field :region_count_egypt, "Egypt"
    range_field :region_count_england, "England"
    range_field :region_count_france, "France"
    range_field :region_count_hre, "HRE"
    range_field :region_count_hungary, "Hungary"
    range_field :region_count_milan, "Milan"
    range_field :region_count_moors, "Moors"
    range_field :region_count_papal_states, "Papal States"
    range_field :region_count_poland, "Poland"
    range_field :region_count_portugal, "Portugal"
    range_field :region_count_russia, "Russia"
    range_field :region_count_scotland, "Scotland"
    range_field :region_count_sicily, "Sicily"
    range_field :region_count_spain, "Spain"
    range_field :region_count_turks, "Turks"
    range_field :region_count_venice, "Venice"

    ###
    h3 "Campaign Events"
    help_text "You can change timing of various events.
    These are expressed in calendar years (min..max).
    Since all turns are on even years, I don't know if odd years work here.
    Black Plague not listed since it's implemented differently.
    Minor events like one region earthquakes not listed for simplicity.
    This doesn't affect mercenaries."
    range_field :event_mongols, "Mongol Invasion warning (actual invasion a few turn later)"
    range_field :event_gunpowder, "Gunpowder invented"
    range_field :event_timurids, "Timurid Invasion warning (actual invasion a few turn later)"
    range_field :event_world_is_round, "The World is Round (requires gunpowder first)"
    range_field :event_printing_press, "First Printing Press (allows printing press building)"

    ###
    h3 "Crusades and Jihads"
    checkbox :fast_crusades, "Enable crusades from early game"
    int_field :min_jihad_piety, "Minimum piety to start Jihad"
    checkbox :crusade_everywhere, "Make more settlements possible crusade/jihad target"
    help_text "In vanilla units can desert if you don't go to crusade/jihad target fast enough.
    This is very buggy and only applies to player (not AI).
    Disabling that fixes the bug, but is very exploitable."
    checkbox :no_crusade_disband, "Disable crusade desertion"
    help_text "Due to buggy character aging, papal politics never really matters until very late.
    Making pope and cardinals older is a simple workaround"
    checkbox :older_cardinals, "Make pope and cardinals older"

    ###
    h3 "BAI"
    help_text "To make sieges more interesting, make BAI sally out when attacked more.
    In vanilla defenders only go out of walls if they're 2x stronger than attacker.
    It makes game more interesting to lower this a lot.
    Very low values also make game easier."
    float_field :sally_out_ratio, "Sally out ratio (vanilla - 2.0)"

    ###
    h3 "Agents and campaign movement speed"
    help_text "Agents can lead to a lot of micromanagement.
    If you want less micromanagement, just get rid of some.
    Only some agents can be safely removed from game."
    checkbox :remove_merchant, "Remove merchants"
    checkbox :remove_spy, "Remove spies"
    checkbox :remove_assassin, "Remove assassins"
    help_text "Units move very slowly.
    You can increase this for more dynamic campaign.
    You can also multiply agent speed (especially diplomats).
    Main multiplier applies to agents as well.    
    1.0 means vanilla values."
    float_field :campaign_speed, "Campaign movement speed multiplier"
    float_field :agent_speed_diplomat, "Speed multiplier for diplomats"
    float_field :agent_speed_princess, "Speed multiplier for princesses"
    float_field :agent_speed_merchant, "Speed multiplier for merchants"
    float_field :agent_speed_spy, "Speed multiplier for spies"
    float_field :agent_speed_assassin, "Speed multiplier for assassins "
    float_field :agent_speed_priest, "Speed multiplier for priests"
    help_text "Spies can be extremely powerful since they let
    you largely ignore settlement defenses.
    You can increase their cost for balance."
    float_field :spy_cost, "Spy cost and upkeep (1.0 - vanilla)"

    ###
    h3 "Guilds"
    help_text "Most guilds in vanilla are very easy to get.
    This makes them a lot easier to get for quick workaround.
    It also reduced Thieves Guild proliferation more in like with other guilds."
    checkbox :easy_guilds, "Make guilds easier"

    ###
    h3 "Units"
    help_text "Bodyguard unit is somewhat overpowered early game so you may want to decrease its size."
    float_field :bodyguard_size, "Size of bodyguard unit (1.0 - vanilla)"
    float_field :bodyguard_cost, "Cost/upkeep of bodyguard unit (1.0 - vanilla)"
    
    help_text "Cavalry is somewhat overpowered. You can tweak it now.
               These settings also apply to bodyguards."
    float_field :cavalry_size, "Size of cavalry unit (1.0 - vanilla)"
    float_field :cavalry_cost, "Cost/upkeep of cavalry unit (1.0 - vanilla)"
    
    help_text "You can adjust missile infantry power level here.
               Giving them more ammo matters mostly in siege defenses.
               Giving all archers stakes helps differentiate them from crossbowmen,
               and can lead to interesting battles,
               but it can also be exploited against AI."
    checkbox :all_archers_stakes, "Give all archers stakes"
    float_field :missile_infantry_ammo, "Missile infantry ammo"
    help_text "Increasing this number >1.0 won't work well due to limitations of Medieval 2 enigne.
    (Kingdoms engine increases this limit, but is not yet used by this mod).
    Numbers <=1.0 fully supported."
    float_field :missile_infantry_size, "Missile infantry size"
    help_text "Artillery is extremly weak in vanilla, so we can improve it.
    Only small range increases work because projectile physics aren't changed yet.
    Artillery engines make maneuvering in fortresses and citadels extremely hard.
    Increasing ammo hits limit for rocket launchers and ribaults very fast,
    since max ammo per engine is 99, and they consume a lot of ammo per salvo.
    For all these values vanilla is 1.0"
    float_field :artillery_range, "Artillery range"
    float_field :artillery_ammo, "Artillery ammo"
    float_field :artillery_crew, "Artillery crew"
    float_field :artillery_engines, "Artillery engines"
    float_field :artillery_accuracy, "Artillery accuracy"

    help_text "Melee battles in vanilla usually end up very quickly.
    Slowing them down leaves a lot of interesting strategy.
    Balancing these settings is pretty hard.
    1.0 - vanilla values."
    float_field :unit_attack, "Unit attack"
    float_field :unit_charge, "Unit charge"
    checkbox :low_morale, "Low morale"
    checkbox :increase_unit_defense, "Increase unit defense"

    help_text "Mercenaries can be extremely cheap, and with
    increased mercenary pools they can be too powerful.
    Making them more expensive balances things out.
    1.0 - vanilla values"
    float_field :mercenary_recruitment, "Mercenary recruitment cost"
    float_field :mercenary_upkeep, "Mercenary upkeep cost"

    help_text "Armor upgrades already cost wasting a turn in a city,
    and recruitment slot, so there's little point charging money for it as well.
    It doesn't affect game balance much either way."
    checkbox :free_unit_upgrade, "Unit armor upgrades for free"

    help_text "Make all low/mid-level infantry freely garrisonable.
    This lets castles have big free garrisons."
    checkbox :more_garrison_units_free, "More units freely garrisonable"

    help_text "Battering rams are extremely powerful.
    Nerfing them lets other siege equipment see more action."
    checkbox :nerf_rams, "Nerf battering rams"

    help_text "In vanilla missile units start with skirmish mode on,
    which makes them harder to control and not very effective.
    You can make them start with skirmishing disabled instead.
    You can always enable skirmishing manually if you want."
    checkbox :do_not_start_skirmishing, "Do not start skirmishing"

    ###
    h3 "Minor Bug Fixes"
    help_text "Pikemen in vanilla switch to very weak swords too early.
               Removing them makes them fight more like pikemen,
               but it also makes them significantly stronger."
    checkbox :remove_rubber_swords, "Remove secondary swords from pikemen"
    
    help_text "Fire by rank often results in unit spending more time
               reforming back and forth rather than fighting.
               Removing fire by rank fixes that and it makes gunpowder units easier to control."
    checkbox :remove_gunpowder_fire_by_rank, "Gunpowder units don't use fire by rank"

    ###
    h3 "Sieges"
    help_text "If artillery is too powerful during sieges, this nerfs it."
    float_field :wall_strength, "Wall strength"
    float_field :tower_strength, "Tower strength"
    help_text "How far unit needs to be for tower to be active and shooting"
    float_field :wall_control_area, "Tower control area"
    help_text "Making arrows faster and weaker is better against militias,
    but worse against heavily armored units.
    Attack value only applies to arrows, fire rate also to ballista and cannon towers,
    so it also fixes the problem of ballista towers being awfully weak."
    float_field :tower_normal_arrows_rate, "Normal arrow fire rate"
    float_field :tower_flaming_arrows_rate, "Flaming arrow fire rate"
    int_field :tower_arrow_attack, "Tower arrow attack (vanilla - 12)"
  end
end

ConcentratedVanillaBuilder.new
