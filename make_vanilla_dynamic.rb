#!/usr/bin/env ruby1.9

require './find_file'
require 'fileutils'
require "pathname"
require "find"
require "pp"

class File
  def self.write(path, content)
    File.open(path, 'wb'){|fh|
      fh.write(content)
    }
  end
end

class Float
  def round2
    (self*100).round.to_i / 100.0
  end
  def to_s_without_e_notation 
    # This is such a pile of fail of a conversion, ...
    # represent as integer if possible
    ("%.12f" % self).sub(/0*\z/, "").sub(/\.\z/, "")
  end
end

class Mod
  def initialize(&blk)
    @files = {}
    @save_as = {}
    open_files!
    instance_eval(&blk)
    save!
  end

  def open(name, file_name, save_dir=nil)
    save_as = File.join(*["output/concentrated_vanilla/data",  save_dir, file_name].compact)
    included = []
    included << 'Cities_Castles_Strat_v1.0/data'
    # merge bai2+bai
    included << 'better_bai'
    included << 'better_bai2' # this super-passive bai, but their 
    included << 'better_cai'
    included << 'vanilla' << 'vanilla/packed' << 'vanilla/imperial-campaign'
    
    included = included.map{|path| "data/#{path}" }
    source = File.first_matching(file_name, *included)
    puts source
    @files[name] = File.open(source, 'rb').read.gsub("\r", "")
    @save_as[name] = save_as
  end

  def modify(name)
    @files[name] = yield(@files[name])
  end
  
  def modify_by_line(name)
    @files[name] = yield(@files[name].split(/\n/)).join("\n") + "\n"
  end

  def save!
    @files.each{|name, value|
      FileUtils.mkdir_p File.dirname(@save_as[name])
      File.write @save_as[name], value.gsub("\n", "\r\n")
    }
  end
  
  def open_files!
  end
end


class GuildData
  def initialize(txt)
    @entries = []
    txt.split(/\n/).each{|line|
      case line
      when /\A\z/
        # Ignore whitespace within triggers etc.
        @entries << [:comment, line] if @entries[-1] == :comment
      when /\A\s*;/
        @entries << [:comment, line]
      when /\ATrigger\s+(\S+)\z/
        @entries << [:trigger, $1]
      when /\A\s+(WhenToTest|Condition|and|Guild)\s+/
        raise "Wrong place - expected Trigger, got: #{@entries[-1].inspect} | #{line.inspect}" unless @entries[-1][0] == :trigger
        @entries[-1] << line
      when /\AGuild\s+(\S+)/
        @entries << [:guild, $1]
      when /\A\s+(exclude|building|levels)\s+/
        raise "Wrong place - expected Guild, got: #{@entries[-1].inspect} | #{line.inspect}" unless @entries[-1][0] == :guild
        @entries[-1] << line
      else
        p [:wut, line]
      end
    }
  end
  def remove_triggers_for_dead_buildings!
    # Same for 1-type and 2-type simplified trees
    dead_buildings = %W[
      mustering_hall
      garrison_quarters
      drill_square
      barracks
      armoury
      town_watch
      town_guard
      city_watch
      militia_drill_square
      militia_barracks
      army_barracks
      royal_armoury
      leather_tanner
      blacksmith
      armourer
      heavy_armourer
      plate_armourer
      gothic_armourer
      c_leather_tanner
      c_blacksmith
      c_armourer
      c_heavy_armourer
      c_plate_armourer
      c_gothic_armourer
      bowyer
      practice_range
      archery_range
      marksmans_range
      merchants_wharf
      warehouse
      docklands
      market
      fairground
      great_market
      merchants_quarter
      brothel
      inn
      tavern
      coaching_house
      pleasure_palace
      stables
      knights_stables
      earls_stables
      barons_stables
      kings_stables
      racing_track
      sultans_racing_track
      alchemists_lab
      gunsmith
      cannon_maker
      cannon_foundry
      royal_arsenal
    ]
    map_triggers!{|e, name, *data|
      if data.any?{|l| l =~ /Condition SettlementBuildingFinished = (\S+)/ and dead_buildings.include?($1) }
        nil
      else
        [e, name, *data]
      end
    }
  end
  def map_triggers!
    @entries = @entries.map{|e|
      if e[0] == :trigger
        yield(e)
      else
        e
      end
    }.compact
  end
  def map_guilds!
    @entries = @entries.map{|e|
      if e[0] == :guild
        yield(e)
      else
        e
      end
    }.compact
  end
  def guild_levels!(lvl)
    map_guilds!{|e, name, *data|
      data = data.map{|l|
        if l =~ /\A\s*levels\b/
          "    levels\t#{lvl}"
        else
          l
        end
      }
      [e, name, *data]
    }
  end
  def no_excludes!
    map_guilds!{|e, name, *data|
      data = data.map{|l|
        if l =~ /\A\s*exclude\b/
          nil
        else
          l
        end
      }
      [e, name, *data]
    }
  end
  def compact_comments!
    (0...@entries.size).each{|i|
      next unless @entries[i][0] == :comment
      next unless @entries[i][1] =~ /\A;-+\z/
      next unless @entries[i+1]
      next unless @entries[i+1][0] == :comment
      next unless @entries[i][1] == @entries[i+1][1]
      @entries[i] = nil
    }
    @entries.compact!
  end
  def alt_guild_system!
    remove_triggers_for_dead_buildings!
    guild_levels!("25 50 100")
    no_excludes!
    compact_comments!
  end
  def to_s
    @entries.map{|e|
      case e[0]
      when :comment
        e[1]
      when :trigger
        data = e[2..-1]
        ["Trigger #{e[1]}", data]
      when :guild
        data = e[2..-1]
        ["Guild #{e[1]}", data]
      else
        raise "Unknown guild data: #{e[0]}"
      end
    }.flatten.join("\n") + "\n"
  end
end

module CastlesAndCitiesAreSameThing
  def modify_buildings_table
    modify('buildings'){|file|
      all = []
      file = file.gsub(/(^building\s+(\S+).*?^\}\s*)/m){
        all << [$2, $1]
        ""
      }
      all = yield(all)
      all.each{|name, desc|
        file << desc
      }
      file
    }
  end
  def merge_town_castle_building(ht, town, castle)
    b = ht[town]
    c = ht[castle]
    b = b.gsub(/^\s+convert_to \S+\n/, "")
    c = c.gsub(/^\s+convert_to \S+\n/, "")
    c = c.gsub(/\bc_(\S+) castle/){ "#{$1} city" }
    c = c.gsub(/\bc_(\S+)\b/){ $1 }
    c = c.sub("building #{castle}", "building #{town}")
    
    ## Information loss necessary to make it compatible
    bx = b
    cx = c
    bx = bx.gsub("settlement_min huge_city", "settlement_min large_city")
    # cx = cx.gsub("settlement_min huge_city", "settlement_min large_city")
    
    ht[town] = b
    ht.delete(castle)
    if bx != cx
      diff(bx, cx)
      warn "#{castle} not fully compatible with #{town}"
    end
  end
  def diff(a, b)
    File.write('/tmp/a.txt', a)
    File.write('/tmp/b.txt', b)
    system "diff", "-u", "/tmp/a.txt", '/tmp/b.txt'
  end
  def building_disable_conversion(ht, key)
    ht[key] = ht[key].gsub(/^\s+convert_to \S+\n/, "")
  end
  def delete_redundant_castle_buildings!
    modify_buildings_table{|buildings|
      ht = Hash[buildings]
      ## Essentially identical
      merge_town_castle_building(ht, 'port', 'castle_port')
      merge_town_castle_building(ht, 'smith', 'castle_smith')
      merge_town_castle_building(ht, 'hinterland_mines', 'hinterland_castle_mines')
      merge_town_castle_building(ht, 'hinterland_roads', 'hinterland_castle_roads')
      merge_town_castle_building(ht, 'siege', 'castle_siege')
      merge_town_castle_building(ht, 'cannon', 'castle_cannon')
      merge_town_castle_building(ht, 'tower', 'castle_tower')

      ## More different but, just keep city version
      ht.delete('temple_muslim_castle')
      ht.delete('temple_orthodox_castle')
      ht.delete('temple_catholic_castle')
      
      building_disable_conversion(ht, 'temple_muslim')
      building_disable_conversion(ht, 'temple_orthodox')
      building_disable_conversion(ht, 'temple_catholic')
      building_disable_conversion(ht, 'core_building')
      
      # Conversions are out
      ht.delete 'convert_to_city'
      ht.delete 'convert_to_castle'
      
      # puts ht.keys.grep(/castle/)
      ht.to_a
    }
  end
  def campaign_map_turn_all_castles_into_cities
    modify('strat'){|file|
      file = file.gsub(/^settlement castle\b/, "settlement")
      file = file.gsub("type hinterland_castle_roads c_roads", "type hinterland_roads roads")
      file = file.gsub("type castle_port c_port", "type port port")
      # Levels:
      # no building      - motte_and_bailey
      # wooden_pallisade - wooden_castle
      # wooden_wall      - castle
      # stone_wall       - fortress
      # large_stone_wall - citadel
      # huge_stone_wall  - no equivalent
      file = file.gsub(/^\s*building\s*\{\s*type core_castle_building motte_and_bailey\s*\}\s*?\n/, "")
      file = file.gsub("type core_castle_building wooden_castle", "type core_building wooden_pallisade")
      file = file.gsub("type core_castle_building castle", "type core_building wooden_wall")
      file
    }
  end
  def units_recruitable_at(ht, key)
    ht[key].scan(/recruit_pool "(.*?)"/).flatten.uniq.sort
  end
  def check_if_all_castle_units_are_still_recruitable
    modify_buildings_table{|buildings|
      ht = Hash[buildings]
      castle   = units_recruitable_at(ht, 'core_castle_building')
      barracks = units_recruitable_at(ht, 'castle_barracks')
      stables  = units_recruitable_at(ht, 'equestrian')
      missile  = units_recruitable_at(ht, 'missiles')
      castle   = castle - barracks - stables - missile
      p castle
      ht.to_a
    }
  end
  def find_castle_unique_units
    units = [
      "Dismounted Arab Cavalry",
      "Dismounted Boyar Sons",
      "Dismounted Chivalric Knights",
      "Dismounted E Chivalric Knights",
      "Dismounted English Knights",
      "Dismounted Feudal Knights",
      "Dismounted Heavy Archers",
      "Dismounted Imperial Knights",
      "Dismounted Italian MAA",
      "Dismounted Noble Knights",
      "Dismounted Norman Knights",
      "Dismounted Polish Knights",
      "Dismounted Polish Nobles",
      "Dismounted Portuguese Knights",
      "Dismounted Sipahi Lancers",
      "English Huscarls",
      "Noble Knights",
      "Polish Retainers",
      "Theigns",
      "Vardariotai",
    ]
    sets = []
    modify_buildings_table{|buildings|
      ht = Hash[buildings]
      ht['core_castle_building'].split(/\n/).each{|line|
        if line =~ /capability/
          sets << []
        elsif line =~ /recruit_pool "(.*?)"/
          if units.include?($1)
            sets[-1] << line
          end
        end
      }
      buildings
    }
    sets
  end
  def reassign_unique_castle_units
    sets = find_castle_unique_units
    modify_buildings_table{|buildings|
      ht = Hash[buildings]
      ht['core_building'] = ht['core_building'].gsub(/(capability\n\s*\{\n)/){
        $1 + sets.shift.join("\n") + "\n"
      }
      ht.to_a
    }
  end
  def single_settlement_type!
    campaign_map_turn_all_castles_into_cities
    # delete_redundant_castle_buildings!
    modify('buildings'){|file|
      file = file.gsub(/\b(stables|knights_stables|barons_stables|earls_stables|kings_stables) castle/){ $1 }
      file = file.gsub(/\b(bowyer|practice_range|archery_range|marksmans_range) castle/){ $1 }
      file = file.gsub(/\b(caravan_stop|caravanersary) castle/){ $1 }
      file = file.gsub(/\b(mustering_hall|garrison_quarters|drill_square|barracks|armoury) castle/){ $1 }
      file = file.gsub(/\b(library|academy) castle/){ $1 }
      file = file.gsub(/\b(jousting_lists|tourney_fields) castle/){ $1 }
      file = file.gsub(/\b((?:|m_|gm_)woodsmens_guild) castle/){ $1 }
      file
    }
    # Kingdoms only anyway
    #modify('dbxml'){|file|
    #  file.sub("</display>"){ '   <show_building_browser_castles bool="false"/>' + "\n   #{$&}" }
    #}
    modify_buildings_table{|buildings|
      ht = Hash[buildings]
      ht.delete 'convert_to_city'
      ht.delete 'convert_to_castle'
      ht.to_a
    }
    #check_if_all_castle_units_are_still_recruitable
    reassign_unique_castle_units
  end
end

module SimplifyBuildingTree
  def parse_building_dsc(dsc)
    out = []
    cur = [out]
    dsc.split("\n").each{|line|
      line.strip!
      if line == "{"
        cur << cur[-1][-1]
      elsif line == "}"
        cur.pop
      else
        cur[-1] << [line]
      end
    }
    raise "Should have one entry" unless out.size == 1
    out[0]
  end
  def get_capacity(dsc)
    dsc = parse_building_dsc(dsc)
    levels = dsc.find{|e| e[0] =~ /\Alevels\b/}
    levels[1..-1].map{|level|
      name = level[0][/\A(\S+)/]
      smintable = {
        "village" => 0,
        "town" => 1,
        "large_town" => 2,
        "city" => 3,
        "large_city" => 4,
        "huge_city" => 5,
      }
      smin = level.map{|e| e[0] =~ /\Asettlement_min\s+(.*)/; $1}.compact[0]
      raise "Settlement minimum unknown #{smin.inpect}" unless smintable[smin]
      cap  = level.find{|e| e[0] == "capability"}[1..-1].flatten
      [name, smintable[smin], cap]
    }
  end
  def reassign_capability!(ht, target, source, levelshift=false)
    raise "No such building #{source}" unless ht[source]
    raise "No such building #{target}" unless ht[target]
    tlevels = get_capacity(ht[target])
    tlevels.each{|x| x[1] += 1} if levelshift
    slevels = get_capacity(ht[source])
    tlevelmax = tlevels.map{|x| x[1]}.max
    slevelmax = slevels.map{|x| x[1]}.max
    raise "Max level of #{source} #{slevelmax} > #{target} #{tlevelmax}" if slevelmax > tlevelmax
    ht[target] = ht[target].gsub(/(capability\n\s*\{\n)(.*?)(^\s+\}\n)/m){
      header, origcapa, trailer = $1, $2,$3
      tbuild = tlevels.shift
      tlev   = tbuild[1]
      sbuild = slevels.select{|x| x[1] <= tlev}[-1]
      if sbuild
        cap = (tbuild[2] + sbuild[2]).sort
        happy, law, tower = 0, 0, 0
        pools = {}
        cap = cap.map{|c|
          if c =~ /\Ahappiness_bonus\s+bonus\s+(\d+)\s*\z/
            happy += $1.to_i
            nil
          elsif c =~ /\Alaw_bonus\s+bonus\s+(\d+)\s*\z/
            law += $1.to_i
            nil
          elsif c =~ /\Atower_level\s+(\d+)\s*\z/
            tower = [$1.to_i, tower].max
            nil
          elsif c =~ /\A(recruit_pool\s+"[^"]+"\s+)(\d+)(\s+)([\.\d]+)(\s+)([\.\d]+)(\s+.*)\z/
            pkey = [$1,$3,$5,$7]
            # initial, inrease, max (then experience but we fold it into reqs)
            # max can be 0.999 (= retrain ok, but no recruit)
            pools[pkey] ||= [0, 0.0, 0]
            pools[pkey][0] += $2.to_i
            pools[pkey][1] += $4.to_f
            pools[pkey][2] += $6.to_f
            nil
          else
            c
          end
        }.compact
        cap << "happiness_bonus bonus #{happy}" if happy > 0
        cap << "law_bonus bonus #{law}" if law > 0
        cap << "tower_level #{tower}" if tower > 0
        pools.to_a.sort.each{|(a,c,e,g),(b,d,f)|
          cap << "#{a}#{b}#{c}#{d.to_s_without_e_notation}#{e}#{f.to_s_without_e_notation}#{g}"
        }
        
        header+ cap.sort.map{|x| " "*16+x}.join("\n") + "\n" + trailer
      else
        "#{header}#{origcapa}#{trailer}"
      end
    }
    raise "Not all builigs parsed" unless tlevels.empty?
  end

  def remove_buildings_from_map!(buildings_to_kill)
    modify('strat'){|file|
      file.gsub(/^(\s+building\s+\{\s+type\s+(\S+)\s+(\S+)\s+\}\s*?\n)/){
        if buildings_to_kill.include?($2)
          #puts "Removing #{$2} #{$3}"
          ""
        else
          #puts "Keepin #{$2} #{$3}"
          $1
        end
      }
    }
  end
  
  def simplify_building_tree_1_type!
    buildings_to_kill = %W[
        tower
        castle_tower
        castle_barracks
        city_hall
        smith
        castle_smith
        market
        taverns
        academic
        equestrian
        professional_military
        missiles
        castle_academic
        sea_trade
        admiralty
        hinterland_roads
        hinterland_farms
        hinterland_mines
        hinterland_castle_roads
        hinterland_castle_farms
        hinterland_castle_mines
        cannon
        castle_cannon
        siege
        castle_siege
        barracks
    ]
    modify_buildings_table{|buildings|
      ht = Hash[buildings]
      [
        "tower",
        "city_hall",
        "smith",
        "market",
        "taverns",
        "academic",
        # Hinterland
        "hinterland_roads",
        "hinterland_farms",
        "hinterland_mines",
        # Barracks
        "barracks",
        "equestrian",
        "professional_military",
        "castle_barracks",
        "missiles",
        "cannon",
      ].each{|b|
        reassign_capability!(ht, "core_building", b, true)
      }
      # reassign_capability!(ht, "barracks", "equestrian")
      # reassign_capability!(ht, "barracks", "missiles")
      # reassign_capability!(ht, "barracks", "professional_military")
      # reassign_capability!(ht, "barracks", "castle_barracks")
      reassign_capability!(ht, "port", "sea_trade")
      reassign_capability!(ht, "port", "admiralty")
      buildings_to_kill.each{|b| ht.delete b}
      ht.each{|name,dsc|
        dsc.gsub!(/^\s*convert_to.*?\n/, "")
        dsc.gsub!(/\s+and\s+building_present_min_level\s+market\s+\S+/, "")
      }
      ht.to_a
    }
    remove_buildings_from_map!(buildings_to_kill)
  end

  def simplify_building_tree_2_types!
    buildings_to_kill = %W[
        tower
        castle_tower
        castle_barracks
        city_hall
        smith
        castle_smith
        market
        taverns
        academic
        castle_academic
        equestrian
        professional_military
        missiles
        sea_trade
        admiralty
        hinterland_roads
        hinterland_farms
        hinterland_mines
        hinterland_castle_roads
        hinterland_castle_farms
        hinterland_castle_mines
        cannon
        castle_cannon
        siege
        castle_siege
        barracks
    ]
    modify_buildings_table{|buildings|
      ht = Hash[buildings]
      [
        "tower",
        "city_hall",
        "smith",
        "market",
        "taverns",
        "academic",
        # Hinterland
        "hinterland_roads",
        "hinterland_farms",
        "hinterland_mines",
        # Barracks
        "barracks",
        "siege",
        "cannon",
        "professional_military",
      ].each{|b|
        reassign_capability!(ht, "core_building", b, true)
      }
      [
        "castle_tower",
        "castle_smith",
        "castle_academic",
        # Hinterland
        "hinterland_castle_roads",
        "hinterland_farms", # It's same building in both trees somehow
        "hinterland_castle_mines",
        # Barracks
        "equestrian",
        "castle_barracks",
        "missiles",
        "castle_siege",
        "castle_cannon",
      ].each{|b|
        reassign_capability!(ht, "core_castle_building", b, true)
      }
      reassign_capability!(ht, "port", "sea_trade")
      reassign_capability!(ht, "port", "admiralty")
      buildings_to_kill.each{|b| ht.delete b}
      ht.each{|name,dsc|
        # dsc.gsub!(/^\s*convert_to.*?\n/, "")
        dsc.gsub!(/\s+and\s+building_present_min_level\s+market\s+\S+/, "")
      }
      ht.to_a
    }
    remove_buildings_from_map!(buildings_to_kill)
  end
end

class M2TW_Mod < Mod
  include CastlesAndCitiesAreSameThing
  include SimplifyBuildingTree
  def open_files!
    open 'character', 'descr_character.txt'
    open 'engines', 'descr_engines.txt'
    open 'settlement', 'descr_settlement_mechanics.xml'
    open 'resources', 'descr_sm_resources.txt'
    open 'walls', 'descr_walls.txt'
    open 'buildings', 'export_descr_buildings.txt'
    open 'units', 'export_descr_unit.txt'
    open 'cultures', 'descr_cultures.txt'
    open 'character_traits', 'export_descr_character_traits.txt'
    open 'standing', 'descr_faction_standing.txt'
    open 'regions', 'descr_regions.txt', 'world/maps/base'
    open 'rebels', 'descr_rebel_factions.txt'
    open 'sounds', 'descr_sounds_units.txt'
    open 'dbxml', 'descr_campaign_db.xml'
    open 'battle_config', 'battle_config.xml'
    open 'factions', 'descr_sm_factions.txt'
    open 'recruitment', 'descr_recruitment.xml'
    open 'battle_events', 'export_descr_sounds_units_battle_events.txt'
    open 'projectile', 'descr_projectile.txt'
    open 'guilds', 'export_descr_guilds.txt' 
    
    # Imperial campaign
    open 'strat', 'descr_strat.txt', 'world/maps/campaign/imperial_campaign'
    open 'mercenaries', 'descr_mercenaries.txt', 'world/maps/campaign/imperial_campaign'
    open 'events', 'descr_events.txt', 'world/maps/campaign/imperial_campaign'
    
    # We need to copy stuff from better_bai anyway
    open 'ai_battle', 'config_ai_battle.xml'
    open 'ai_formations', 'descr_formations_ai.txt'
    open 'formations', 'descr_formations.txt'
    open 'pathfinding', 'descr_pathfinding.txt' # bai1 only
    open 'map_mods', 'descr_battle_map_movement_modifiers.txt'  # bai2 only
    # +battle_config
    
    # We need to copy stuff from better_cai anyway
    open 'dbaixml', 'descr_campaign_ai_db.xml'
    open' diplomacy', 'descr_diplomacy.xml'
    # +standing
    
    copy_mod_skeleton!
    copy_new_models!
  end
  
  def copy_mod_skeleton!
    mod_skeleton = Pathname("data/mod_skeleton")
    mod_build_dir = Pathname("output")
    mod_skeleton.find do |file|
      target = mod_build_dir + file.relative_path_from(mod_skeleton)
      if file.directory?
        FileUtils.mkdir_p target
      else
        FileUtils.cp file, target
      end
    end
  end
  
  def copy_new_models!
    models_path = "data/Cities_Castles_Strat_v1.0/data/models_strat"
    models_target_path = "output/concentrated_vanilla/data"
    FileUtils.mkdir_p models_target_path
    FileUtils.cp_r models_path, models_target_path
  end

  # Soldier ration 1.0 pretty much removes plaza capture
  # ~0.999-ish means even defending soldier can hold plaza like in RTW
  # AI stupidly believes it's still RTW, so we need to mod it to be like RTW
  def plaza_capture!(time, ratio)
    modify('battle_config'){|file|
      file.sub(%r[<time-limit>[\d\.]+</time-limit>], "<time-limit>#{time.to_f}</time-limit>").
           sub(%r[<soldier-ratio>[\d\.]+</soldier-ratio>], "<soldier-ratio>#{ratio.to_f}</soldier-ratio>")
    }
  end

  def free_retraining!
    modify('dbxml'){|file|
      file.sub(%r[(<retraining_slots uint=")\d+("/>)]){"#{$1}0#{$2}"}
    }
    modify('recruitment'){|file|
      file.sub(%r[(<retraining slots_required=")\d+("/>)]){"#{$1}0#{$2}"}
    }
  end
  
  def nerf_rams!
    #Rams should really suck - 20% attack, 50% health
    modify('engines'){|file|
      file.sub(/^(type\s+tortoise_ram.*?^attack_stat\s+)([^\n]+)/m){
        $1 + "2, 2, no, 0, 0, melee, melee_simple, blunt"
      }.sub(/^(type\s+tortoise_ram.*?^engine_health\s+)([^\n]+)/m){
        $1 + "75"
      }
    }
  end

  def taxes_influence_on_growth!(influence=2.0)
    # Taxes should influence settlement growth rates twice as much
    modify('settlement'){|file|
      file.gsub(/(<factor name="SPF_TAX_RATE_(?:BONUS|PENALTY)">\s+<pip_modifier value=")1.0(")/){
        "#{$1}#{influence}#{$2}"
      }
    }
  end

  def resource_value!(value=1.5)
    # Resources 50% more valuable
    modify('resources'){|file|
      file.gsub(/^(trade_value\s+)(\d+)/){ "#{$1}#{(value*$2.to_i).to_i}" }
    }
  end

  def spy_cost!(mult)
    # Spies twice the recruitment cost
    modify('cultures'){|file|
      file.gsub(/^(spy.*?\s+)(\d+)\b/) { "#{$1}#{($2.to_i * mult).to_i}"}
    }
    # Spies x2 more expensive
    modify('character'){|file|
      type = nil
      file.gsub(/(?:^type\s*(\S+))|(?:^(wage_base\s*)(\d+))/) {
        if $1
          type = $1
          $&
        elsif type == 'spy'
          "#{$2}#{($3.to_i*mult).to_i}"
        else
          $&
        end
      }
    }
  end
  
  def campaign_movement_speed!(mult)
    # Everyone move mult times faster
    modify('character'){|file|
      file.gsub(/^(starting_action_points\s+)(\d+)/){"#{$1}#{(mult*$2.to_i).to_i}"}
    }
  end
  
  def agent_speed!(name, mult)
    modify('character'){|file|
      cur = false
      file.split(/\n/).map{|line|
        if line =~ /\Atype\s+(\S+)/ and $1 == name
          cur = true
        elsif line =~ /^(starting_action_points\s+)(\d+)/ and cur
          line = "#{$1}#{(mult*$2.to_i).to_i}"
          cur = false
        end
        line
      }.join("\n")
    }
  end
  
  def wall_strength!(wall_mult, tower_mult)
    # Gates and walls 5x stronger
    # towers 0% stronger
    modify('walls'){|file|
      t = nil
      file.gsub(/(.*)/){|line|
        if line =~ /^\s+(wall|gateway|tower|gate)/
          t = $1
        elsif line =~ /\A(\s*full_health\s*)(\d+)(.*)/
          if t == 'tower'
            line = "#{$1}#{($2.to_i*tower_mult).to_i}#{$3}"
          else
            line = "#{$1}#{($2.to_i*wall_mult).to_i}#{$3}"
          end
        end
        line
      }
    }
  end

  def tower_fire_rate!(normal, flaming)
    # 2x faster tower firing rate, flaming reload the same
    modify('walls'){|file|
      file.gsub(/^(\s+fire_rate\s+\S+\s+)(\d+)(\s+)(\d+)/) {
        "#{$1}#{($2.to_i/normal).to_i}#{$3}#{(($4.to_i)/flaming).to_i}"
      }
    }
  end

  def wall_control_area!(mult)
    # WAS: All towers are manned as long as any unit is inside walls
    # NOW: Much higher tower control radius
    modify('walls'){|file|
      file.gsub(/(control_area_radius\s*)(\d+)/){ "#{$1}#{($2.to_i*mult).to_i}" }
    }
  end

  def construction_time_one_turn!
    # All buildings can be constructed in one turn
    modify('buildings'){|file|
      file.gsub(/^(\s+construction\s+)(\d+)/) { "#{$1}1" }
    }
  end

  def construction_time_turns!
    # All buildings can be constructed in f(x) turns
    # 0 turn build times are not supported
    modify('buildings'){|file|
      file.gsub(/^(\s+construction\s+)(\d+)/) { "#{$1}#{yield($2.to_i).to_i}" }
    }
  end

  def building_cost!(cost_mult, mine_extra_mult)
    # All buildings 50% more expensive, mines 100% more expensive extra (for total of 300%)
    modify('buildings'){|file|
      file.gsub(/^(building hinterland_(?:castle_)?mines.*?^\})/m) {
        $1.gsub(/(cost\s+)(\d+)/) {"#{$1}#{(mine_extra_mult*$2.to_i).to_i}"}
      }.gsub(/(cost\s+)(\d+)/) {"#{$1}#{(cost_mult*$2.to_i).to_i}"}
    }
  end
  
  def mine_resource!(mult)
    # Mines levels are 2x, for total of 3x more money
    modify('buildings'){|file|
      file.gsub(/(mine_resource\s+)(\d+)/m) {
        "#{$1}#{($2.to_i*mult).to_i}"
      }
    }
  end

  def bodyguard_size!(mult)
    # Bodyguards nerfed to half size, no more 1hp nerfing, as they were useless late in game
    # TODO: Their price in custom battles should be reduced
    modify('units'){|file|
      file.gsub(/(.*\S.*\n)+/) {|para|
        if para =~ /\Atype\s*.*Bodyguard/
          para = para.sub(/^(soldier\s+\S+, )(\d+)/){ "#{$1}#{($2.to_i*mult).to_i}" }
        end
        para
      }
    }
  end

  def modify_units
    modify('units'){|file|
      file.gsub(/(.*\S.*\n)+/){|para|
        yield(para.dup) || para
      }
    }
  end

  def cavalry_size!(mult)
    modify_units{|para|
      next unless para =~ /^category\s*cavalry/
      para.sub(/^(soldier\s+\S+, )(\d+)/){ "#{$1}#{($2.to_i*mult).to_i}" }
    }
  end

  def cavalry_cost!(normal, bodyguard)
    # Heavy cavalry 50% more expensive.
    # Take bodyguards to 25% down because they're half as numerous and
    # they were just insanely expensive without this.
    modify_units{|para|
      next unless para =~ /^category\s*cavalry/
      mult = normal
      mult = bodyguard if para =~ /\Atype\s*.*Bodyguard/
      para = para.sub(/(stat_cost\s*)([0-9, ]*)/) {
        pre, data = $1, $2.split(/,\s*/).map{|x|x.to_i}
        # 0=turns(1), 6=custom battle too-many-same-units penalty(4)
        [1,2,3,4,5,7].each{|i| data[i] = (data[i]*mult).to_i}
        "#{pre}#{data.join(', ')}"
      }
      para
    }
  end

  def missile_infantry_ammo!(mult)
    # More ammo for missile infantry
    modify('units'){|file|
      file.gsub(/^(category\s+infantry.*?stat_pri\s+\d+,\s*\d+,\s*\S+,\s*\d+,\s*)(\d+)/m){
        "#{$1}#{($2.to_i*mult).to_i}"
      }
    }
  end

  def missile_infantry_size!(mult)
    modify_units{|para|
      next unless para =~ /^category\s*infantry/ and para =~ /^class\s*missile/
      next if para =~ /^stat_pri.*javelin/ # These aren't real missive units
      para.sub(/^(soldier\s+\S+, )(\d+)/){ "#{$1}#{($2.to_i*mult).to_i}" }
    }
  end

  def all_archers_stakes!
    modify_units{|para|
      next unless para =~ /^category\s*infantry/ and para =~ /^class\s*missile/
      next unless para =~ /^stat_pri.*arrow/ # arrow|bodkin_arrow|composite_arrow
      next if para =~ /^attributes.*\bstakes\b/
      para.sub(/^(attributes\s*.*)/) { "#{$1}, stakes, stakes" }
    }
  end

  def artillery_range_ammo!(range_mult, ammo_mult)
    # More ammo for artillery
    modify('units'){|file|
      file.gsub(/(\d+)(,\s*)(\d+)(,\s*siege_missile,\s*artillery)/){
        "#{($1.to_i*range_mult).to_i}#{$2}#{($3.to_i*ammo_mult).to_i}#{$4}"
      }
    }
  end

  def rebel_spawn_rates!(mult)
    # Make rebels and pirates spawn 10x less often - doesn't really seem to work
    modify('strat'){|file|
      file.gsub(/^((?:pirate|brigand)_spawn_value\s+)(\d+)/){"#{$1}#{($2.to_i*mult).to_i}"}
    }
  end
  
  def king_purse!(mult)
    # Double king's purse to help small countries
    modify('strat'){|file|
      file.gsub(/^(denari_kings_purse\s+)(\d+)/){"#{$1}#{($2.to_i*mult).to_i}"}
    }
  end

  def big_garrisons!
    # More free garrisons
    # Cities: 0 2 3 4 5 6 -> 0 4 6 8 10 12
    # Castles:  0 0 0 0 0 ->   1 2 4  7 12
    modify('buildings'){|file|
      file.sub(/^(building core_building\s*\{)(.*?)(^\})/m){
        prefix, description, suffix = $1,$2,$3
        description = description.gsub(/(free_upkeep bonus )(\d+)/) {"#{$1}#{$2.to_i*2}"}
        "#{prefix}#{description}#{suffix}"
      }.sub(/^(building core_castle_building\s*\{)(.*?)(^\})/m){
        prefix, description, suffix = $1,$2,$3
        by_level = [0, 1, 2, 4, 7, 12]
        description = description.gsub(/^(\s*)(law_bonus bonus )(\d+)(\s*?\n)/) { "#{$1}#{$2}#{$3}#{$4}#{$1}free_upkeep bonus #{by_level[$3.to_i]}#{$4}" }
        "#{prefix}#{description}#{suffix}"
      }
    }
  end
  def more_recruitment_slots!
    # Cities: 0 1 2 2 3 3 -> 0 2 3 5 7 9
    # Castles:  1 2 3 3 3 ->   2 3 5 7 9
    modify('buildings'){|file|
      file.sub(/^(building core_building\s*\{)(.*?)(^\})/m){
        prefix, description, suffix = $1,$2,$3
        by_level = [2, 3, 5, 7, 9]
        description = description.gsub(/(recruitment_slots )(\d+)/) {"#{$1}#{by_level.shift}"}
        "#{prefix}#{description}#{suffix}"
      }.sub(/^(building core_castle_building\s*\{)(.*?)(^\})/m){
        prefix, description, suffix = $1,$2,$3
        by_level = [2, 3, 5, 7, 9]
        description = description.gsub(/(recruitment_slots )(\d+)/) {"#{$1}#{by_level.shift}"}
        "#{prefix}#{description}#{suffix}"
      }
    }
  end

  def basic_infantry_garrisonned_for_free!
    # Basic non-merc infantry should be free upkeep - where basic means morale <= 5 and upkeep <= 155,
    # what works quite well
    modify('units'){|file|
      file.gsub(/(.*\S.*\n)+/){|para|
        if para =~ /\Atype/ and
           para =~ /^category\s+infantry/ and
           para !~ /attributes.*\b(free_upkeep_unit|mercenary_unit|general_unit)\b/ and
           para !~ /^ownership\s+(slave|saxons)\s*$/

          raise "Parse error: #{para}" unless para =~ /^stat_cost\s+\d+,\s+(\d+),\s+(\d+)/
          r, u = $1.to_i, $2.to_i
          raise "Parse error: #{para}" unless para =~ /stat_mental\s+(\d+)/
          m = $1.to_i
          para = para.sub(/(attributes[^\n]+)/){"#{$1}, free_upkeep_unit"} if m <= 5 && u <= 155

          # c = [m <= 5 && u <= 155].select{|x|x}.size
          # c += 10 if u == 0 # Irrelevant anyways
          # para =~ /dictionary\s*(\S+)/
          # puts "#{c} #{m} #{u} #{r} #{$1}"
        end
        para
      }
    }
  end

  def fix_standing!
    modify('standing'){|file|
      file.sub(/;Trigger 0102_city_razed_decrease_global.*?; make all other factions hate the rebels/m) {|part|
        part.gsub(/^;*/, ';')
      }
    }
  end
  
  def fix_rubber_swords!
    # Heavy cavalry 50% more expensive.
    # Take bodyguards to 25% down because they're half as numerous and
    # they were just insanely expensive without this.
    modify('units'){|file|
      file.gsub(/(.*\S.*\n)+/) {|para|
        if para =~ /^formation.*phalanx/
          para.sub!(/^(stat_sec\s+)(.*)/){"#{$1}0, 0, no, 0, 0, no, melee_simple, blunt, none, 25, 1"}
        end
        para
      }
    }
  end

  def change_regions!
    modify('regions'){|file|
      file.gsub(/^([A-Z].*\n(?:\t.*\n)+)/){|region|
        yield(region)
      }
    }
  end

  def change_region_resources!
    change_regions!{|region|
      lines = region.split(/\n/)
      lines[5] =~ /\A(\s*)(.*?)(\s*)\Z/
      st, en  = $1, $3
      resources = $2.split(/,\s+/)
      resources = [] if resources == ['none']
      resources = yield(resources).uniq
      resources = ['none'] if resources == []
      lines[5] = st + resources.join(', ') + en
      lines.join("\n") + "\n"
    }
  end

  def no_rebels!
    change_region_resources!{|res|
      res + ['no_brigands', 'no_pirates']
    }
  end
  
  def crusades_everywhere!
    change_region_resources!{|res|
      res += ['crusade', 'jihad', 'horde_target'] unless res.include? 'america'
      res
    }
  end
  
  def no_siege!
    modify('buildings'){|file|
      file.sub(/^building siege.*?^\}\n/m, '').sub(/^building castle_siege.*?^\}\n/m, '')
    }
  end
  
  def all_mercenaries_available!
    modify('mercenaries'){|file|
      file.gsub(/^\s+unit.*$/){|line|
        line.gsub(/ start_year \d+/, '').gsub(/ end_year \d+/, '').gsub(/\s*events\s*\{(?: |gunpowder_discovered|mongols_invasion_warn)*\}/, '')
      }
    }
  end
  
  def more_mercenaries!
    modify('mercenaries'){|file|
      file.gsub(/(replenish\s+)([0-9.]+)(\s*-\s*)([0-9.]+)(\s+max\s+)(\d+)(\s+initial\s+)(\d+)/){
        a0, b0, mx, ini = $2.to_f, $4.to_f, $6.to_i, $8.to_i
        a = (a0*8).round2
        b = (b0*8).round2
        ini += mx * 2
        mx *= 4
        "#{$1}#{a}#{$3}#{b}#{$5}#{mx}#{$7}#{ini}"
      }
    }
  end
  
  def all_buildings_available!
    modify('buildings'){|file|
      file.gsub(/ and event_counter (?:first_printing_press|gunpowder_discovered|world_is_round) 1/, '')
    }
  end

  def reduce_captain_obvious!
    modify('sounds'){|file|
      file.gsub(/(unit_under_attack_delay )(\d+)/){ "#{$1}#{$2.to_i*100}"}
    }
  end
  # def more_rebels!
  #   modify('rebels'){|file|
  #     file.gsub(/(chance\s+)3/){ "#{$1}50"}
  #   }
  # end

  def remove_agents!(type)
    modify('buildings'){|file|
      file = file.gsub(/^\s+agent\s+#{type}\b.*\n/, "")
      file = file.gsub(/^\s+agent_limit\s+#{type}\b.*\n/, "")
    }
    modify('strat'){|file|
      file.gsub(/^character\s+[^,]+,\s*#{type}.*\n(.*\S.*\n)*\n/, "")
    }
  end

  def fast_crusades!
    modify('dbxml'){|file|
      file.gsub(/(<(?:jihad|crusade)_called_start_turn\s+float=")[0-9.]+("\/>)/){
        "#{$1}1#{$2}"
      }
    }
  end
  
  def min_jihad_piety!(piety)
    modify('dbxml'){|file|
      file.sub(/<required_jihad_piety\s+int="\d+"\/>/, "<required_jihad_piety int=\"#{piety}\"/>")
    }
  end
  
  def change_resource_values!
    modify('resources'){|file|
      file.gsub(/^(type\s*)(\S+)(\s*trade_value\s*)(\d+)/){
        name, value = $2, $4.to_i
        value = yield(name, value)
        "#{$1}#{name}#{$3}#{value}"
      }
    }
  end

  def rearrange_resource_values!
    change_resource_values!{|name, value|
      {
        #"ivory"  => 50, # 12
        #"slaves" => 40, #  8
        "silk"   => 90, # 12
        #"amber" => 60, # 12
      }[name] || value
    }
  end

  def trade_bonus!(mult)
    modify('buildings'){|file|
      file.gsub(/(\btrade_base_income_bonus\s+bonus\s+)(\d+)/){
        "#{$1}#{($2.to_i*mult).to_i}"
      }
    }
  end
  
  def villages_800_people!
    modify('settlement'){|file|
      file.gsub('="400"', '="800"')
    }
  end
  
  # Balanced - biases towards growth, taxable income, trade level bonuses (roads), walls and xp bonus buildings
  # Religious - biases towards growth, loyalty, taxable income, farming, walls and law
  # Trader - biases towards growth, trade level, trade base, weapon upgrades, games, races and xp bonus buildings
  # Comfort - biases towards growth, farming, games, races, xp bonus and happiness
  # Bureaucrat - biases towards taxable income, growth, pop health, trade, walls, improved bodyguards and law
  # Craftsman - biases towards walls, races, taxable income, weapon upgrades, xp bonuses, mines, health and growth
  # Sailor - biases towards sea trade, taxable income, walls, growth, trade
  # Fortified - biases towards walls, taxable income, growth, loyalty, defenses, bodyguards and law
  
  # Smith - exactly level
  # Mao - biased towards mass troops, light infantry
  # Genghis - biased towards missile cavalry and light cavalry
  # Stalin - biased towards heavy infantry, mass troops and artillery
  # Napoleon - biased towards a mix of light and heavy infantry, light cavalry
  # Henry - biased towards heavy and light cavalry, missile infantry
  # Caesar - biased towards heavy infantry, light cavalry, siege artillery
    
  def ai_personality!(a, b)
     modify('strat'){|file|
       file.gsub(/^(faction\s*\S+,\s*)balanced\s*smith/){ "#{$1}#{a} #{b}" }
     }
  end
  
  def start_war!(faction1, faction2)
    modify('strat'){|file|
      file.gsub(/^(faction_relationships\s+(\S+),\s+at_war_with\s+.*)(\n)/){
        if $2 == faction1
          "#{$1}, #{faction2}#{$3}"
        elsif $2 == faction2
          "#{$1}, #{faction1}#{$3}"
        else
          "#{$1}#{$3}"
        end
      }
    }
  end
  
  def change_faction_religion!(faction, religion)
    modify_by_line('factions'){|lines|
      cur = false
      lines.map{|line|
        if line =~ /\Afaction\s+(\S+)/ and $1 == faction
          cur = true
        elsif line =~ /\A(religion\s+)\S+/ and cur
          line = "#{$1}#{religion}"
          cur = false
        end
        line
      }
    }
  end
  
  def population!(province, size)
    modify_by_line('strat'){|lines|
      cur = false
      lines.map{|line|
        if line =~ /^\s*region\s+(\S+)/ and $1 == province
          cur = true
        elsif cur and line =~ /^(\s*population\s*)\d+(.*)/
          line = "#{$1}#{size}#{$2}"
          cur = false
        end
        line
      }
    }
  end
  
  def building!(province, bfrom, bto)
    modify_by_line('strat'){|lines|
      cur = false
      lines.map{|line|
        if line =~ /^\s*region\s+(\S+)/ and $1 == province
          cur = true
        elsif cur and line =~ /^(\s*type\s+)(.*)/ and $2 == bfrom
          line = "#{$1}#{bto}"
          cur = false
        end
        line
      }
    }
  end

  def silicy_scenario!
    # It mostly works but culture needs changing to middle eastern or sth
    modify_buildings_table{|buildings|
      ht = Hash[buildings]
      ht["temple_catholic"].gsub!(/sicily, /, "")
      ht["temple_catholic_castle"].gsub!(/sicily, /, "")
      ht["temple_muslim"].gsub!(/(factions \{)/){ "#{$1} sicily," }
      ht["temple_muslim_castle"].gsub!(/(factions \{)/){ "#{$1} sicily," }
      ht.to_a 
    }
    change_faction_religion!("sicily", "islam")
    start_war!("sicily", "papal_states")
    population!("Roman_Province", 24000)
    building!("Roman_Province", "core_building stone_wall", "core_building huge_stone_wall")
  end
  
  def modify_standings!
    modify('strat'){|file|
      file.sub(/((?:faction_standings.*\n)+)/){
        standings_block = $1
        st = {}
        standings_block.split(/\n/).each{|line|
          line =~ /\Afaction_standings\s+(\S+)\s*,\s*(-?\d\.\d+)\s+(.*?)\s*\z/ or raise "Parse error: #{line}"
          faction  = $1
          standing = $2.to_f
          $3.split(/,/).map(&:strip).each{|towards|
            st[[faction, towards]] = standing
          }
        }
        st = yield(st)
        st.to_a.map{|(a,b),s| [a,b,s]}.sort.map{|a,b,s|
          res  = "faction_standings      #{a},"
          res  = "%-47s" % res
          res += "#{s}"
          res  = "%-55s" % res
          res += b
          res + "\n"
        }.join
        
        #standings_block
      }
    }
  end
  
  def start_wars!
    wars = [
      ["england", "france"],
      ["england", "scotland"],
      ["denmark", "scotland"],
      ["denmark", "england"],
      ["denmark", "russia"],
      ["milan", "france"],
      ["milan", "venice"],
      ["hre", "venice"],
      ["hre", "hungary"],
      ["venice", "byzantium"],
      ["venice", "egypt"],
      ["turks", "russia"],
      ["poland", "hungary"],
      ["poland", "hre"],
      ["poland", "denmark"],
      ["france", "hre"],
      ["turks", "egypt"],
      ["milan", "sicily"],
      ["byzantium", "sicily"],
      ["byzantium", "turks"],
      ["poland", "russia"],
      ["russia", "hungary"],
      ["portugal", "spain"],
      ["spain", "sicily"],
      ["portugal", "france"],
      ["portugal", "moors"],
      ["spain", "moors"],
    ]
    wars.each{|a,b|
      start_war!(a,b)
    }
    modify_standings!{|st|
      wars.each{|a,b|
        st[[a,b]] = -1.0
        st[[b,a]] = -1.0
      }
      st
    }
  end
  
  def artillery_size!(soldier_mult, item_mult)
    modify('units'){|file|
      file.gsub(/(.*\S.*\n)+/) {|para|
        if para =~ /^category\s+siege/ and para !~ /Carroccio_Standard|Great_Cross/
          para.sub!(/^(soldier\s+\S+,\s*)(\d+)(,\s*)(\d+)/){
            "#{$1}#{($2.to_i * soldier_mult).round.to_i}#{$3}#{($4.to_i*item_mult).round.to_i}"
          }
        end
        para
      }
    }
  end
  
  def religion_bonus!(mult)
    modify('buildings'){|file|
      file.gsub(/(\breligion_level\s+bonus\s+)(\d+)/){
        "#{$1}#{($2.to_i*mult).to_i}"
      }
    }
  end
  
  def low_morale!
    # Rescale 1..11 to 1..6
    modify("units"){|file|
      file.gsub(/^(stat_mental\s+)(\d+)/){
        "#{$1}#{(($2.to_i-1)*0.5).to_i+1}"
      }
    }
  end
  
  def sally_out_ratio!(ratio)
    modify('ai_battle'){|file|
      file.gsub(%r[(<sally-out-ratio>)(\d+\.\d+)(</sally-out-ratio>)]){ "#{$1}#{ratio}#{$3}"}
    }
  end

  def stronger_ratio!(ratio)
    modify('ai_battle'){|file|
      file.gsub(%r[(<friendly-to-enemy-strength-ratio>)(\d+\.\d+)(</friendly-to-enemy-strength-ratio>)]){ "#{$1}#{ratio}#{$3}"}
    }
  end
  
  def no_crusade_disband!
     modify('dbxml'){|file|
       file = file.sub(/<max_disband_progress float="\S+?"\/>/, '<max_disband_progress float="0"/>')
       file = file.sub(/<disband_progress_window float="\S+?"\/>/, '<disband_progress_window float="0"/>')
       file = file.sub(/<near_target_no_disband_distance float="\S+?"\/>/, '<near_target_no_disband_distance float="1000.0"/>')
       file
     }
  end

  def map_settlements!(&blk)
    modify('strat'){|file|
      file.gsub(/^(settlement\s+(?:castle\s+)?\{.*?^\})/m, &blk)
    }
  end

  def increase_settlement_size!
    map_settlements!{|para|
      levels      = %W[village town large_town city large_city huge_city]
      core        = %W[wooden_pallisade wooden_wall stone_wall large_stone_wall huge_stone_wall]
      castle_core = %W[motte_and_bailey wooden_castle castle fortress citadel]
      # Conversion table (found in strat.txt):
      # * village    = none             = motte_and_bailey
      # * town       = wooden_pallisade = wooden_castle
      # * large_town = wooden_wall      = castle
      # * city       = stone_wall
      # * large_city = large_stone_wall
    
      para = para.sub(/(population\s+)(\d+)/){ "#{$1}#{$2.to_i * 2}" }
      para = para.sub(/(level\s+)(\S+)/){ $1 + (levels[levels.index($2)+1] || levels[-1]) }
      para = para.sub(/(type core_building\s+)(\S+)/){ $1 + (core[core.index($2)+1] || core[-1]) }
      para = para.sub(/(type core_castle_building\s+)(\S+)/){ $1 + (castle_core[castle_core.index($2)+1] || castle_core[-1]) }
      if para !~ /type core/
        para = para.sub(/(^\})/){
          "        building\n"+
          "        {\n"+
          "                type core_building wooden_pallisade\n"+
          "        }\n"+
          $1
        }
      end
      
      para
    }
  end
  
  def remove_useless_sounds!
    # Sadly this just kills all sounds, the only way is probably
    # using a "blank" sound instead
    modify('battle_events'){|file|
      remove_sounds = %W[
        Player_Army_Tired
        Player_Under_Attack_Idle
        Enemy_Ladders_Attacking_Walls
        Enemy_Siege_Towers_Attacking_Walls
        Enemy_Siege_Towers_Destroyed
        Enemy_Walls_Breached_By_Player
        Enemy_Walls_Captured_By_Player
        Player_Ammo_Low
        Player_Ammo_Depleted
        Player_Army_Routing
        Player_Ladders_Attacking_Walls
        Player_Ram_Attacking_Gate
        Player_Ram_Breached_Gate
        Player_Breached_Gate
        Enemy_Ram_Attacking_Gate
        Enemy_Ram_Breached_Gate
        Enemy_Breached_Gate
        Player_Siege_Towers_Attacking_Walls
        Player_Siege_Towers_Destroyed
        Player_Walls_Breached_By_Enemy
        Player_Walls_Captured_By_Enemy
        Player_Walls_Undermined_By_Enemy
        Player_Cavalry_Almost_Depleted
        Player_Infantry_Almost_Depleted
        Player_Missile_Units_Almost_Depleted
        Player_Army_Half_Gone
        Enemy_Army_Half_Gone
        Player_Siege_Ammunition
        Player_Winning_Combat
        Player_Losing_Combat
        Player_Tide_Of_Battle_Up
        Player_Tide_Of_Battle_Down
      ]
      file.gsub(/^(\s+notification\s+(\S+)\s+\d+\s+event\s+folder\s+\S+\s+\S+\s+end\s*?\n)/){
        if remove_sounds.include?($2)
          ""
        else
          $1
        end
      }
    }
  end

  def simplify_unit_tree!
    units = [
      "Peasant Spearmen",
      "Peasants",
      "Town Militia",
      "Spear Militia",
      "Dismounted Feudal Knights",
      "Sergeant Spearmen",  # made hre specific
      "Armored Sergeants",  # made hre specific
      "Highland Rabble", # essentially  =Peasants
      "Halberd Militia",
      "Pike Militia",
      "Spearmen",
      "Transilvanian Peasants",
      #"Byzantine Spearmen", # essentially = Spearmen (but then they get very little else)

      "Peasant Archers",
      "Peasant Crossbowmen",
      "Crossbowmen",
      "Archer Militia",
      "Crossbow Militia",
      "Pavise Crossbowmen",
      #"Pavise Crossbow Militia",

      "Arquebusiers",
      "Hand Gunners",

      "Mounted Sergeants",
      "Mailed Knights",
      "Feudal Knights",
      "Chivalric Knights", # sicily doesn't get them
      "EE Cavalry Militia",
      #"Mounted Crossbowmen",
      #"Italian MAA",


      # Castle/City near-duplicates, late crappy units etc,
      "Bill Militia",
      "Heavy Bill Militia",
      # "Italian Militia",
      # "Italian Spear Militia",
      # "Gendarmes",
      "Scots Pike Militia",
      "Genoese Crossbow Militia",

      # Just mass disable all of them
      "Ballista",
      "Catapult",
      #"Trebuchet",

      # Just mass disable all of them
      "Grand Bombard",
      "Monster Bombard",
      #"Rocket Launcher",
      "Bombard",
      "Cannon",
      #"Ribault",
      #"Mortar",
      "Basilisk",
      "Culverin",
      "Serpentine",
      #"Monster Ribault",
    ]

    move_earlier = [
      ["huge_stone_wall",
        %Q[recruit_pool "Sergeant Spearmen"  1   0.5   4  0  requires factions { hre, }],
        %Q[recruit_pool "Armored Sergeants"  1   0.5   4  0  requires factions { hre, }],
        %Q[recruit_pool "Chivalric Knights"  1   0.7   6  0  requires factions { france, denmark, spain, }],
        %Q[recruit_pool "E Chivalric Knights"  1   0.7   6  0  requires factions { hungary, }],
      ],
      ["large_stone_wall",
        %Q[recruit_pool "Sergeant Spearmen"  1   0.5   4  0  requires factions { hre, }],
        %Q[recruit_pool "Armored Sergeants"  1   0.5   4  0  requires factions { hre, }],
        %Q[recruit_pool "Chivalric Knights"  1   0.7   6  0  requires factions { france, denmark, spain, }],
        %Q[recruit_pool "E Chivalric Knights"  1   0.7   6  0  requires factions { hungary, }],
      ],
      ["stone_wall",
        %Q[recruit_pool "Swordsmen Militia"  1   0.5   4  0  requires factions { spain, portugal, }],
        %Q[recruit_pool "Imperial Knights"  1   0.7   6  0  requires factions { hre, }],
        %Q[recruit_pool "Partisan Militia"  1   0.5   4  0  requires factions { france, }],
        %Q[recruit_pool "Sergeant Spearmen"  1   0.5   4  0  requires factions { hre, }],
        %Q[recruit_pool "Armored Sergeants"  1   0.5   4  0  requires factions { hre, }],
        %Q[recruit_pool "Chivalric Knights"  1   0.7   6  0  requires factions { france, denmark, spain, }],
        %Q[recruit_pool "E Chivalric Knights"  1   0.7   6  0  requires factions { hungary, }],
      ],
      ["wooden_wall",
        %Q[recruit_pool "Partisan Militia"  1   0.5   4  0  requires factions { france, }],
        %Q[recruit_pool "Voulgier"  1   0.5   4  0  requires factions { france, }],
        %Q[recruit_pool "Sergeant Spearmen"  1   0.5   4  0  requires factions { hre, }],
        %Q[recruit_pool "Armored Sergeants"  1   0.5   4  0  requires factions { hre, }],
      ],
      ["wooden_pallisade",
        %Q[recruit_pool "Partisan Militia"  1   0.5   4  0  requires factions { france, }],
        %Q[recruit_pool "Sergeant Spearmen"  1   0.5   4  0  requires factions { hre, }],
      ],
    ]

    prefixes = ["", "Southern ", "EE ", "SE ", "NE ", "AS ", "S ", "ME ", "GR ", "E "]
    delete_me = prefixes.map{|px| units.map{|u| "#{px}#{u}"}}.flatten

    modify('buildings'){|file|
      file = file.gsub(/^(\s+recruit_pool\s+"([^\"]+)".*\n)/){
        if delete_me.include?($2)
          ""
        else
          $1
        end
      }
      move_earlier.each{|level, *entries|
        file = file.sub(/^(\s*#{level}.*?)^(\s*)(recruit_pool)/m){
          init, spacing, rest = $1, $2, $3
          entries = entries.map{|e| spacing + e + "\n"}.join
          init + entries + spacing + rest
        }
      }
      file
    }
  end
  
  def unit_cost!(build_mod=1.0, upkeep_mod=1.0)
    modify('units'){|file|
      file.gsub(/^(stat_cost\s+\d+,\s+)(\d+)(,\s+)(\d+)/){
        "#{$1}#{($2.to_i*build_mod).to_i}#{$3}#{($4.to_i*upkeep_mod).to_i}"
      }
    }
  end
  
  def remove_siege_units!
    units = [
      "Ballista",
      "Catapult",
      "Trebuchet",
      # Just making everyone's lives harder, but then Byzantium has nothing else
#      "Bombard",
#      "Grand Bombard",
    ]
    prefixes = ["", "Southern ", "EE ", "SE ", "NE ", "AS ", "S ", "ME ", "GR ", "E "]
    delete_me = prefixes.map{|px| units.map{|u| "#{px}#{u}"}}.flatten

    modify('buildings'){|file|
      file = file.gsub(/^(\s+recruit_pool\s+"([^\"]+)".*\n)/){
        if delete_me.include?($2)
          ""
        else
          $1
        end
      }
    }
  end
  
  
  def show_date_as_year!
    modify('strat'){|file|
      file.sub(/^show_date_as_turns\s*/, "")
    }
  end
  
  def move_event!(name, date1, date2)
    modify('events'){|file|
      file.sub(%r[(event\s+historic\s+#{name}\s+date\s+)\d+(\s+)\d+]){
        "#{$1}#{date1}#{$2}#{date2}"
      }
    }
  end

  def no_fire_by_rank!
    modify('units'){|file|
      file.gsub(/,\s*fire_by_rank\b/, "")
    }
  end

  def high_fertility!
    modify('character_traits'){|file|
      file + "
;------------------------------------------                                                                                                                  
Trigger fertility_men                                                                                                                                        
  WhenToTest CharacterTurnEnd
  
  Condition IsGeneral
  
  Affects Fertile 1 Chance 50
  
Trigger fertility_women
  WhenToTest CharacterTurnEnd
  
  Condition AgentType = princess
  
  Affects FertileWoman 1 Chance 50
"
    }
  end

  def fix_naval_autoresolve!
    modify('dbxml'){|file|
      file = file.sub(%r[(<naval_sink_max\s+float\s*=\s*")[^\"]*("\s*/>)]){ "#{$1}100.0#{$2}" }
    }
  end
  
  def increase_unit_defense!
    modify('units'){|file|
      # armour, skill, shield
      file.gsub(/(stat_pri_armour\s+)(\d+)(\s*,\s*)(\d+)(\s*,\s*)(\d+)/){
        "#{$1}#{$2.to_i*2}#{$3}#{$4.to_i*2}#{$5}#{$6.to_i*2}"
      }.gsub(/(stat_sec_armour\s+)(\d+)(\s*,\s*)(\d+)/){
        "#{$1}#{$2.to_i*2}#{$3}#{$4.to_i*2}"
      }
    }
  end
  
  def mod_unit_attack!(mod=0.5)
    modify('units'){|file|
      file.gsub(/(stat_(?:pri|sec|ter)\s*)(\d+)/){
        # Mod but don't make it meaningless
        at = (($2.to_i)*mod).ceil.to_i
        "#{$1}#{at}"
      }
    }
  end

  def mod_unit_charge!(mod)
    modify('units'){|file|
      file.gsub(/(stat_(?:pri|sec|ter)\s*\d+\s*,\s*)(\d+)/){
        # Mod but don't make it meaningless
        at = (($2.to_i)*mod).ceil.to_i
        "#{$1}#{at}"
      }
    }
    #stat_charge_distance
  end
  

  def select_more_units(sub_faction, unit_types)
    # 3..10 (where the fuck is there 10 ???)
    old_count = unit_types.size
    new_extra = [20, old_count*2 + 4].min - old_count

    # Old: 0  1  2  3  4  5  6  7  8  9 10
    # New: 4  6  8 10 12 14 16 18 20 20 20

    avail = case sub_faction
    when 'poland'
      ["Polish Nobles", "Lithuanian Cavalry", "Lithuanian Archers", "Lithuanian Archers"]
    when 'russia'
      ["Boyar Sons", "EE Spearmen", "EE Spearmen", "EE Crossbow Militia"]
    when 'byzantium'
      ["Byzantine Cavalry", "Trebizond Archers", "Trebizond Archers", "Byzantine Spearmen"]
    when 'denmark'
      ["Huscarls", "Norse Swordsmen", "Viking Raiders", "Viking Raiders"]
    when 'france' 
      ["Mailed Knights", "Flemish Pikemen"]
    when 'scotland'
      ["Highlanders", "Highland Archers"]
    when 'england'
      ["Welsh Longbowmen", "Welsh Longbowmen", "Welsh Spearmen"]
    when 'spain'
      ["Jinetes", "Javelinmen"]
    when 'hungary'
      ["Bulgarian Brigands", "Croat Axemen", "Magyar Cavalry"]
    when 'aztecs'
      ["Native Warriors", "Native Archers"]
    when 'turks'
      if unit_types.include?("Turkomans")
        ["Turkomans", "Turkish Archers"]
      else
        ["Bedouin Camel Riders", "Desert Archers"]
      end
    when 'egypt'
      ["Tuareg Camel Spearmens", "Sudanese Tribesmen", "Sudanese Tribesmen"]
    when 'venice'
      ["Italian Spear Militia", "Italian Militia", "Peasant Crossbowmen"]
    when 'sicily'
      ["Sicilian Muslim Archers", "Italian Spear Militia"]
    when 'milan'
      ["Sergeant Spearmen", "Italian Militia", "Peasant Crossbowmen"]
    when 'hre'
      ["Armored Sergeants", "Mailed Knights", "Slav Levies", "Slav Mercenaries"]
    when 'moors'
      ["Tuareg Camel Spearmens", "Sudanese Javelinmen", "Nubian Spearmen", "Sudanese Tribesmen"]
    else
      p [sub_faction, unit_types.size, new_extra, unit_types.uniq]
      return []
    end

    ((avail * 20)[0, new_extra]).sort
  end

  def make_army_epic(para, faction)
    lines = para.chomp.split(/\n/)
    lines = lines.map{|l|
      if l =~ /unit/
        if l =~ /Bodyguard/
          l.sub(/exp \d+/, "exp 6")
        else
          nil
        end
      else
        l
      end
    }.compact
    
    units = case faction
    when 'russia'
      [
        'EE Basilisk', 'EE Basilisk','EE Basilisk', 'EE Basilisk',
        'Tsars Guard', 'Tsars Guard', 'Tsars Guard', 'Tsars Guard', 'Tsars Guard', 
        'Cossack Musketeers','Cossack Musketeers','Cossack Musketeers','Cossack Musketeers',
        'Berdiche Axemen','Berdiche Axemen','Berdiche Axemen','Berdiche Axemen',
        'Dismounted Dvor', 'Dismounted Dvor',
      ]
    when 'hungary'
      [
        'EE Basilisk', 'EE Basilisk',
        'Battlefield Assassins', "Battlefield Assassins",
        "Hussars", "Hussars",
        'Royal Banderium', 'Royal Banderium', 'Royal Banderium', 'Royal Banderium', 
        'Hungarian Nobles', 'Hungarian Nobles', 'Hungarian Nobles', 'Hungarian Nobles', 
        'Dismounted E Chivalric Knights', 'Dismounted E Chivalric Knights',
        'Dismounted E Chivalric Knights', 'Dismounted E Chivalric Knights',
        'Dismounted E Chivalric Knights',
      ]
    when 'turks'
      [
        'ME Monster Bombard', 'ME Monster Bombard',
        'Quapukulu', 'Quapukulu', 'Quapukulu', 'Quapukulu', 'Quapukulu', 
        'Sipahis','Sipahis','Sipahis','Sipahis',
        'Janissary Heavy Inf', 'Janissary Heavy Inf', 'Janissary Heavy Inf', 'Janissary Heavy Inf',
        'Ottoman Infantry', 'Ottoman Infantry', 'Ottoman Infantry', 'Ottoman Infantry', 
      ]
    when 'milan'
      [
        'Carroccio Standard M', 'NE Culverin', 'NE Culverin',
        'Famiglia Ducale', 'Famiglia Ducale', 'Famiglia Ducale', 'Famiglia Ducale',
        'Genoese Crossbowmen', 'Genoese Crossbowmen', 'Genoese Crossbowmen', 'Genoese Crossbowmen',
        'Genoese Crossbowmen', 'Genoese Crossbowmen', 'Genoese Crossbowmen', 'Genoese Crossbowmen',
        "Hand Gunners", "Hand Gunners", "Hand Gunners", "Hand Gunners",
      ]
    when 'byzantium'
      [
        'GR Trebuchet', 'GR Trebuchet',
        'Vardariotai', 'Vardariotai', 'Vardariotai', 'Vardariotai','Vardariotai',
        'Kataphractoi', 'Kataphractoi', 'Kataphractoi', 'Kataphractoi',
        "Varangian Guard", "Varangian Guard", "Varangian Guard", "Varangian Guard",
        'Byzantine Guard Archers', "Byzantine Guard Archers", "Byzantine Guard Archers", "Byzantine Guard Archers",
      ]
    when 'denmark'
      [
        'NE Cannon', 'NE Cannon',
        'Obudshaer', 'Obudshaer', 'Obudshaer', 'Obudshaer',
        'Mounted Crossbowmen','Mounted Crossbowmen','Mounted Crossbowmen',
        'Armored Clergy', 'Armored Clergy',
        'Huscarls', 'Huscarls', 'Huscarls', 'Huscarls',
        'Norse Axemen','Norse Axemen','Norse Axemen','Norse Axemen',
      ]
    when 'scotland'
      [
        'NE Culverin', 'NE Mortar',
        'Noble Pikemen', 'Noble Pikemen', 'Noble Pikemen', 'Noble Pikemen', 'Noble Pikemen', 'Noble Pikemen', 
        'Highland Nobles','Highland Nobles','Highland Nobles', 
        'Noble Swordsmen','Noble Swordsmen','Noble Swordsmen','Noble Swordsmen',
        'Noble Highland Archers', 'Noble Highland Archers', 'Noble Highland Archers', 'Noble Highland Archers',
      ]
    when 'moors'
      [
        'ME Cannon', 'ME Cannon',
        'Camel Gunners','Camel Gunners','Camel Gunners','Camel Gunners','Camel Gunners',
        'Camel Gunners','Camel Gunners','Camel Gunners',
        'Tuareg Camel Spearmens', 'Tuareg Camel Spearmens', 'Tuareg Camel Spearmens',
        'Urban Militia', 'Urban Militia','Urban Militia','Urban Militia',
        'Dismounted Christian Guard', 'Dismounted Christian Guard',
      ]
    when 'egypt'
      [
        'ME Cannon', 'ME Cannon',
        'Royal Mamluks', 'Royal Mamluks', 'Royal Mamluks', 'Royal Mamluks', 'Royal Mamluks', 
        'Mamluk Archers','Mamluk Archers','Mamluk Archers','Mamluk Archers','Mamluk Archers',
        'Naffatun', 'Naffatun',
        'Sudanese Gunners', 'Sudanese Gunners', 'Tabardariyya', 'Tabardariyya', 'Tabardariyya',
      ]      
    when 'spain'
      [
        'NE Basilisk', 'NE Basilisk',
        'Knights of Santiago', 'Knights of Santiago', 'Knights of Santiago', 'Knights of Santiago',
        'Jinetes', 'Jinetes', 'Jinetes', 'Jinetes', 'Jinetes', 
        'Tercio Pikemen', 'Tercio Pikemen', 'Tercio Pikemen', 'Tercio Pikemen',
        'Musketeers', 'Musketeers', 'Musketeers', 'Musketeers',
      ]
    when 'france'
      [
        'NE Basilisk', 'NE Basilisk',
        'Lancers', 'Lancers', 'Lancers', 'Lancers', 'Lancers', 'Lancers',
        'French Mounted Archers', 'French Mounted Archers', 'French Mounted Archers', 'French Mounted Archers',
        'Aventurier', 'Aventurier', 'Aventurier', 'Aventurier', 'Aventurier', 'Aventurier', 'Aventurier',
      ]
    when 'england'
      [
        'NE Culverin', 'NE Culverin', 'NE Mortar', 'NE Mortar',
        'Dismounted English Knights', 'Dismounted English Knights', 'Dismounted English Knights',
        'Dismounted English Knights', 'Dismounted English Knights', 'Dismounted English Knights',
        'Yeoman Archers', 'Yeoman Archers', 'Yeoman Archers', 'Yeoman Archers', 'Yeoman Archers',
        'Sherwood Archers', 'Sherwood Archers', 'Sherwood Archers', 'Sherwood Archers',        
      ]
    when 'hre'
      [
        'NE Basilisk', 'NE Basilisk',
        'Teutonic Knights', 'Teutonic Knights', 'Teutonic Knights', 'Teutonic Knights',
        'Gothic Knights', 'Gothic Knights', 'Gothic Knights', 'Gothic Knights',
        'Reiters', 'Reiters', 'Reiters', 'Reiters',
        'Zweihander', 'Zweihander', 'Zweihander', 'Zweihander', 'Zweihander',
      ]
    when 'venice'
      [
        'Carroccio Standard V', 'NE Culverin', 'NE Mortar',
        'Venetian Heavy Infantry', 'Venetian Heavy Infantry', 'Venetian Heavy Infantry', 'Venetian Heavy Infantry',
        'Mounted Crossbowmen', 'Mounted Crossbowmen', 'Mounted Crossbowmen', 'Mounted Crossbowmen', 
        'Pavise Crossbow Militia', 'Pavise Crossbow Militia', 'Pavise Crossbow Militia', 'Pavise Crossbow Militia',
        'Venetian Archers', 'Venetian Archers', 'Venetian Archers', 'Venetian Archers',
      ]
    when 'poland'
      [
        'EE Serpentine', 'EE Serpentine',
        'Polish Nobles', 'Polish Nobles', 'Polish Nobles', 'Polish Nobles', 'Polish Nobles',
        'Lithuanian Cavalry', 'Lithuanian Cavalry', 'Lithuanian Cavalry', 'Lithuanian Cavalry',
        'Lithuanian Cavalry',
        'Lithuanian Archers', 'Lithuanian Archers', 'Lithuanian Archers', 'Lithuanian Archers',
        'Lithuanian Archers', 'Lithuanian Archers', 'Lithuanian Archers',
      ]
    when 'papal_states'
      [
        'Great Cross', 'NE Culverin', 'NE Mortar',
        'Crusader Knights', 'Crusader Knights', 'Crusader Knights', 'Crusader Knights',
        'Crusader Knights', 'Crusader Knights', 'Crusader Knights', 
        'Papal Guard', 'Papal Guard', 'Papal Guard', 'Papal Guard',
        'Papal Guard', 'Papal Guard', 'Papal Guard', 'Papal Guard', 'Papal Guard',
      ]
    when 'sicily'
      [
        'NE Cannon', 'NE Mortar',
        'Norman Knights','Norman Knights','Norman Knights','Norman Knights',
        'Norman Knights','Norman Knights','Norman Knights','Norman Knights',
        'Dismounted Norman Knights', 'Dismounted Norman Knights', 'Dismounted Norman Knights', 
        'Sicilian Muslim Archers', 'Sicilian Muslim Archers', 'Sicilian Muslim Archers',
        'Sicilian Muslim Archers', 'Sicilian Muslim Archers', 'Sicilian Muslim Archers',
      ]
    when 'portugal'
      [
        "NE Basilisk", "NE Basilisk", "NE Basilisk",
        "Knights of Santiago", "Knights of Santiago", "Knights of Santiago", "Knights of Santiago",
        "Mounted Crossbowmen", "Mounted Crossbowmen", "Mounted Crossbowmen", "Mounted Crossbowmen",
        "Mounted Crossbowmen", "Mounted Crossbowmen",
        'Musketeers', 'Musketeers', 'Musketeers', 'Musketeers', 'Musketeers', 'Musketeers',
      ]
    else
      []
    end
    
    puts "#{faction} #{units.size}" if units.size != 19
    
    lines += units.map{|u|
      "unit\t\t#{u}\t\t\texp 6 armour 1 weapon_lvl 1"
    }

    lines.join("\n") + "\n"
  end
    
  def epic_armies!
    puts ""
    modify('strat'){|file|
      faction = nil
      file.gsub(/(.*\S.*\n)+/){|para|
        if para =~ /^faction\s+(\S+),/
          faction = $1
        end
        next para unless para =~ /\Acharacter\s+(.*?)\s*,/
        name = $1
        if para =~ /Factionleader|Factionheir/ and faction != 'aztecs'
          para = make_army_epic(para, faction)
        end  
        para
      }
    }
  end
  
  def more_initial_rebels!
    modify('strat'){|file|
      file.gsub(/(.*\S.*\n)+/){|para|
        next para unless para =~ /\Acharacter\s+sub_faction\s+(\S+)\s*,/
        sub_faction = $1
        lines = para.split(/\n/)
        next para unless lines[1] == "army"
        units = lines[2..-1]
        unit_types = []
        units.each{|u|
          uf = u.split(/\t+/)
          raise "WTF: #{u}" unless uf[0] = "unit"
          unit_types << uf[1]
        }
        more_units = select_more_units(sub_faction, unit_types)
        lines += more_units.map{|u| "unit\t\t#{u}\t\t\t\texp 0 armour 0 weapon_lvl 0"}
        lines.join("\n") + "\n"
      }
    }
  end
  
  def add_buildings!(ht)
    level_names = parse_level_names
    ht = ht.dup
    map_settlements!{|para|
      if para =~ /^\s+region\s+(\S+)_Province/
        name = $1
        buildings_to_add = ht.delete(name) || {}
        txt = buildings_to_add.to_a.map{|building, level|
          raise "No levels for #{building}" unless level_names[building]
          "        building\n"+
          "        {\n"+
          "                type #{building} #{level_names[building][level-1]}\n"+
          "        }\n"
        }.join
        para = para.sub(/(^\})/){ txt + $1 }
      end      
      para
    }
    unless ht.keys.empty?
      warn "Buildings not added in: #{ht.keys.join(' ')}"
    end
    
  end
  
  def parse_level_names
    rv = {}
    modify('buildings'){|file|
      building = nil
      file.each_line{|line|
        if line =~ /^building\s+(\S+)/
          building = $1
        elsif line =~ /^\s*levels\s+(.*)/
          raise "Levels without buildings: #{line}" unless building
          rv[building] = $1.split(/\s+/)
          building = nil
        end
      }
      file 
    }
    rv
  end
  
  def add_guilds!
    add_buildings!({
      "Bran" => {"guild_assassins_guild" => 2},
      # "Acre" => {"guild_assassins_muslim_guild" => 1}, # seem broken ?
      "Paris" => {"guild_theologians_guild" => 2},
      "Florence" => {"guild_theologians_guild" => 1},
      "Venice" => {"guild_merchants_guild" => 1}, 
      "Milan" => {"guild_merchants_guild" => 1},
      "Genoa" => {"guild_explorers_guild" => 1},
      "Lisbon" => {"guild_explorers_guild" => 1},
      "Toledo" => {"guild_swordsmiths_guild" => 2},
      "Thorn" => {"guild_teutonic_knights_chapter_house" => 2},
      "Nuremburg" => {"guild_alchemists_guild" => 1},
      "Prague" => {"guild_thiefs_guild" => 1},
      "Nottingham" => {"guild_woodsmens_guild" => 2},
      "Valencia" => {"guild_knights_of_santiago_chapter_house" => 2},
      "Hohenstauffen" => {"guild_teutonic_knights_chapter_house" => 1},
      "Caesarea" => {"guild_horse_breeders_guild" => 1},
      "Damascus" => {"guild_swordsmiths_guild" => 2},
      "Jerusalem" => {"guild_templars_chapter_house" => 2},
      "Toulouse" => {"guild_templars_chapter_house" => 1},
      "Antioch" => {"guild_st_johns_chapter_house" => 2},
      "Constantinople" => {"guild_masons_guild" => 1},
    })
  end
  
  def increase_artillery_accuracy!(factor=2.0)
    modify('projectile'){|file|
      file.gsub(/(.*\S.*\n)+/){|para|
        if para =~ /accuracy_vs_towers/ # Only artillery has it (maybe disable for elephants???)
          # vs towers and walls works well already
          # /4 is way too powerful, especially with the usual range/ammo/size increases
          # para = para.sub(/(accuracy_vs_units\s+)(\S+)/){ "#{$1}#{$2.to_f/2}"}
          # Why not just everywhere?
          para = para.sub(/(accuracy_vs_\S+\s+)(\S+)/){ "#{$1}#{$2.to_f/factor}"}
        end
        para
      }
    }
  end
  
  def better_guild_units!
    modify('units'){|file|
      file.gsub(/(.*\S.*\n)+/) {|para|
        if para =~ /\Atype\s*.(Knights of Santiago|Teutonic Knights|Knights Hospitaller|Knights Templar)/
          para = para.gsub(/^(stat_(?:pri|sec)\s+)(\d+)(\s*,\s*)(\d+)(.*)/){ "#{$1}#{$2.to_i+6}#{$3}#{$4.to_i+6}#{$5}" }
        elsif para =~ /\Atype\s*.(Sherwood Archers)/
          para = para.sub(/^(stat_pri\s+)(\d+)(.*)/){ "#{$1}#{$2.to_i+6}#{$3}" }
        end
        para
      }
    }
    # Sadly this won't work without some major retexturing work
    # + I need to change ownership in 'units'
    # Oh well, the idea was good
    # modify_buildings_table{|buildings|
    #   ht = Hash[buildings]
    #   catholic = "  { spain, portugal, hre, england, scotland, france, denmark, milan, venice, papal_states, sicily, poland, hungary, }"
    #   %W[
    #     guild_templars_chapter_house
    #     guild_st_johns_chapter_house
    #     guild_teutonic_knights_chapter_house
    #     guild_knights_of_santiago_chapter_house
    #     guild_woodsmens_guild
    #   ].each{|g|
    #     ht[g].gsub!(/requires factions\s+\{.*?\}/, "requires factions#{catholic}")
    #   }
    #   ht.to_a
    # }
  end
  
  def alt_guild_system!
    modify('guilds'){|file|
      gd = GuildData.new(file)
      gd.alt_guild_system!
      gd.to_s
    }
  end
  
  def easy_guilds!
    modify('guilds'){|file|
      gd = GuildData.new(file)
      gd.guild_levels!("25 50 100")
      gd.no_excludes!
      gd.compact_comments!
      gd.to_s
    }
  end
  
  def older_cardinals!
    # Aging cardinals by 20+ doesn't give factions enough time to make good priests
    modify('strat'){|file|
      file.split(/\n/).map{|line|
        next line unless line =~ /\Acharacter\b/
        if line =~ /,\s*priest\s*,/
          line.sub(/(age\s+)(\d+)/){
            "#{$1}#{$2.to_i + 15}"
          }
        elsif line =~ /^character\s+Gregory/
          line.sub(/(age\s+)(\d+)/){
            "#{$1}#{$2.to_i + 25}"
          }
        else
          line
        end
      }.join("\n")
    }
  end
  
  # arrows faster and strong against low level units, bad against heavily armored units
  def rebalance_wall_arrows!(power)
    modify('walls'){|file|
      file.split(/\n/).map{|line|
        if line =~ /^\s+stat/ and line =~ /\barrow_tower\b/
          line.sub(/(stat\s+)12/){ "#{$1}#{power}" }
        # elsif line =~ /^(\s+fire_angle\s+)90/
        #   "#{$1}75"
        else
          line
        end
      }.join("\n")
    }
  end
end

M2TW_Mod.new do
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
  # rebel_spawn_rates!(1000)
  plaza_capture!(1.0, 0.95)
  fix_standing!
  # all_mercenaries_available!
  more_mercenaries!
  # no_rebels!
  show_date_as_year!
  # more_rebels!

  ### Campaign
  # silicy_scenario!
  # start_wars!
  more_initial_rebels!
  # epic_armies!

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
  #move_event!('mongols_invasion_warn', 20, 30) # 10-15 turns
  #move_event!('timurids_invasion_warn', 70, 80) # 35-40 turns

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
  increase_artillery_accuracy!(2.5)

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
