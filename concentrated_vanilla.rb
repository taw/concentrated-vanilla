require "./find_file"
require 'fileutils'
require "pathname"
require "find"
require "pp"
require "set"
require "digest/md5"

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

class Range
  def random_element
    return nil if self.end < self.begin
    self.begin + rand(self.end - self.begin + 1)
  end
end

class Set
  def random_element
    to_a.random_element
  end
end

class Array
  def random_element
    self[rand(size)]
  end
  def shuffle
    sort_by{rand}
  end
end

class CampaignMap
  def initialize
    require "./analyze_map"
    @data = AnalyzeMap.new.run!("data/map_data/vanilla_plus_7")
    @regions = Hash.new{|ht,k| raise "Unknown settlement or region: #{k}" }
    @data.each{|r|
      @regions[r[:region]] = r
      @regions[r[:city]] = r
    }
  end

  def [](name)
    @regions[name]
  end

  def self.instance
    @instance ||= CampaignMap.new
  end
end

class Mod
  def initialize(mod_settings={}, &blk)
    @mod_settings = mod_settings
    @files = {}
    @save_as = {}
    @encodings = {}
    open_files!
    instance_eval(&blk)
    save!
  end

  def encode_file(value, enc)
    if enc == 'utf16'
      value.gsub("\n", "\r\n").unpack("U*").pack("v*")
    else
      value.gsub("\n", "\r\n")
    end
  end
  
  def decode_file(value, enc)
    if enc == 'utf16'
      value.unpack("v*").pack("U*").gsub("\r", "")
    else
      value.gsub("\r", "")
    end
  end

  def open(name, file_name, dir=nil)
    save_as = File.join(*["output/mods/concentrated_vanilla/data", dir, file_name].compact)
    source = File.first_matching(file_name,
      *search_path.map{|path| File.join(["data", path, dir].compact) }
    )
    # puts source
    @files[name] = decode_file(File.open(source, 'rb').read, @encodings[name])
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
      File.write @save_as[name], encode_file(value, @encodings[name])
    }
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
        warn "Parse error for guild data: `#{line}'"
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


module ScenarioBuilder
  def modify_strat_by_sections!
    modify('strat'){|file|
      header   = []
      parts    = []
      
      lines = file.split(/\n/)

      header << lines.shift while lines[0] !~ /\Afaction/
      
      while true
        case lines[0]
        when /\A\s*\z/
          parts[-1] << lines.shift
        when /\Afaction\b/
          parts << [:faction, lines.shift]
        when /\A(character_record|relative|ai_label|undiscovered|denari|denari_kings_purse|dead_until_resurrected)\b/
          if parts[-1][0] == :faction or parts[-1][0] == :faction_info
            parts[-1] << lines.shift
          else
            parts << [:faction_info, lines.shift]
          end
        when /\Asettlement\b/
          dsc = [:settlement]
          until lines[0] =~ /\A\}\z/
            raise "Parse error: #{dsc.inspect}" if lines.empty?
            dsc << lines.shift
          end
          dsc << lines.shift
          parts << dsc
        when /\Acharacter\b/
          chara = [:character]
          chara << lines.shift until lines[0] =~ /\A\s*\z/
          chara << lines.shift
          parts << chara
        when /\A;;;;;;;;;;;;;/
          break
        else
          raise "FAIL: #{lines[0]}"
        end
      end
      
      footer = lines
      
      parts = yield(parts)
      
      (header + parts.map{|tag, *data| data}.flatten + footer).join("\n") + "\n"
    }
  end

  def modify_scenario!
    modify_strat_by_sections!{|strat_data|
      factions = []
      strat_data.each{|part|
        case part[0]
        when :faction
          raise "FAIL: #{part.inspect}" unless part[1] =~ /\Afaction\t(\S+),/
          factions << {
            :name => $1,
            :faction_line => part[1],
            :info => part[2..-1],
            :settlements => [],
            :characters => [],
            :info2 => [],
          }
        when :settlement
          name = part[1..-1].map{|x| x =~ /\A\s*region\s+(\S+)/ ? $1 : nil}.find{|x| x}
          raise "Name not found: #{part.inspect}" unless name
          factions[-1][:settlements] << [name, part[1..-1]]
        when :character
          raise "Parse error: #{part.inspect}" unless part[1] =~ /\bx\s+(\d+),\s*y\s*(\d+)\s*\z/
          x,y = $1.to_i, $2.to_i
          factions[-1][:characters] << [x, y, part[1..-1]]
        when :faction_info
          factions[-1][:info2] << part[1..-1]
        else
          raise "Parse error: #{part.inspect}"
        end
      }
      factions = yield(factions)
      parts = []
      factions.each{|faction|
        parts << [:faction, faction[:faction_line], *faction[:info]]
        faction[:settlements].each{|s|
          parts << [:settlement, *s[1..-1]]
        }
        faction[:characters].each{|c|
          parts << [:character, *c[2..-1]]
        }
        parts << [:faction_info, *faction[:info2]] if faction[:info2]
      }
      parts
    }
  end

  def campaign_map
    @campaign_map ||= CampaignMap.instance
  end

  def extract_settlement(factions, name)
    region_name = campaign_map[name][:region]
    all_extracted_regions = []
    factions.each{|faction|
      extracted_regions, faction[:settlements] = faction[:settlements].partition{|s| s[0] == region_name}
      all_extracted_regions += extracted_regions
    }
    raise "Couldn't extract #{name}(#{region_name})" unless all_extracted_regions.size == 1
    all_extracted_regions[0]
  end
  
  def add_basic_garrison!(faction, faction_name, x, y)
    basic_units = {
      "hungary"      => ["EE Spear Militia", "EE Spear Militia", "Bosnian Archers", "Bosnian Archers"],
      "russia"       => ["EE Spear Militia", "EE Spear Militia", "EE Archer Militia", "EE Archer Militia"],
      "egypt"        => ["ME Spear Militia", "ME Spear Militia", "Desert Archers", "Desert Archers"],
      "turks"        => ["ME Spear Militia", "ME Spear Militia", "Turkish Archers", "Turkish Archers"],
      "moors"        => ["ME Spear Militia", "ME Spear Militia", "Desert Archers", "Desert Archers"],
      "venice"       => ["Italian Spear Militia", "Italian Spear Militia", "Peasant Archers", "Peasant Archers"],
      "milan"        => ["Italian Spear Militia", "Italian Spear Militia", "Peasant Archers", "Peasant Archers"],
      "england"      => ["Spear Militia", "Spear Militia", "Peasant Archers", "Peasant Archers"],
      "france"       => ["Spear Militia", "Spear Militia", "Crossbow Militia", "Crossbow Militia"],
      "hre"          => ["Spear Militia", "Spear Militia", "Peasant Archers", "Peasant Archers"],
      "spain"        => ["Town Militia", "Town Militia", "Peasant Archers", "Peasant Archers"],
      "portugal"     => ["Spear Militia", "Spear Militia", "Peasant Crossbowmen", "Peasant Crossbowmen"],
      "poland"       => ["EE Spear Militia", "EE Spear Militia", "EE Peasant Archers", "EE Peasant Archers"],
      "papal_states" => ["Italian Spear Militia", "Italian Spear Militia", "Pavise Crossbowmen", "Pavise Crossbowmen"],
      "sicily"       => ["Italian Spear Militia", "Italian Spear Militia", "S Peasant Archers", "S Peasant Archers"],
      "scotland"     => ["Town Militia", "Town Militia", "Highland Archers", "Highland Archers"],
      "byzantium"    => ["SE Spear Militia", "SE Spear Militia", "Trebizond Archers", "Trebizond Archers"],
      "denmark"      => ["Spear Militia", "Spear Militia", "Norse Archers", "Norse Archers"],
      "slave"        => ["Town Militia", "Town Militia", "Peasant Archers", "Peasant Archers"], # should depend on culture
    }[faction_name]
    
    raise "Don't know basic units for #{faction_name}" unless basic_units

    age = 20 + (x+y) % 41
    character_name = "Spartacus Maximus"

    army = [
      "character\t#{character_name}, general, male, age #{age}, x #{x}, y #{y} ",
      "army",
    ] + basic_units.map{|u|
      "unit\t#{u}\texp 0 armour 0 weapon_lvl 0"
    } + [""]

    faction[:characters] << [x,y,army]
  end
  
  def add_basic_garrisons!(factions)
    factions.each{|faction|
      name = faction[:name]
      cities = faction[:settlements].map{|s| campaign_map[s[0]][:city]}
      faction[:characters].each{|c|
        xy = c[0,2]
        if c[2].include? "army"
          cities.delete_if{|c| campaign_map[c][:loc] == xy}
        end
      }
      cities.each{|c|
        add_basic_garrison! faction, name, *campaign_map[c][:loc]
      }
    }
  end
  
  def move_army!(faction,x0,y0,x1,y1)
    ok = false
    faction[:characters].each{|c|
      next unless c[0,2] == [x0,y0]
      ok = true
      c[0] = x1
      c[1] = y1
      c[2][0].sub!(/x #{x0}, y #{y0} \z/, "x #{x1}, y #{y1} ") or raise "Bad character line"
    }

    raise "Couldn't find army at #{x0},#{y0}" unless ok
  end
  
  def byzantine_scenario!
    modify_scenario!{|factions|
      byz     = factions.find{|f| f[:name] == "byzantium"}
      venice  = factions.find{|f| f[:name] == "venice"}
      hungary = factions.find{|f| f[:name] == "hungary"}
      turks   = factions.find{|f| f[:name] == "turks"}
      rebel   = factions.find{|f| f[:name] == "slave"}
      egypt   = factions.find{|f| f[:name] == "egypt"}
      russia  = factions.find{|f| f[:name] == "russia"}
      
      byz[:characters].delete_if{|c|
        %W[Nicosia Nicaea Thessalonica].any?{|cn| c[0,2] == campaign_map[cn][:loc]} or
        c[0,2] == [194, 80]
      }
      rebel[:characters].delete_if{|c|
        %W[Smolensk Moscow Kiev Rhodes Sofia Jerusalem Acre Ancyra Antioch Smyrna].any?{|cn| c[0,2] == campaign_map[cn][:loc]}
      }

      thessalonica = extract_settlement(factions, "Thessalonica")
      nicosia      = extract_settlement(factions, "Nicosia")
      nicaea       = extract_settlement(factions, "Nicaea")
      rhodes       = extract_settlement(factions, "Rhodes")
      ancyra       = extract_settlement(factions, "Ancyra")
      sofia        = extract_settlement(factions, "Sofia")
      jerusalem    = extract_settlement(factions, "Jerusalem")
      acre         = extract_settlement(factions, "Acre")
      antioch      = extract_settlement(factions, "Antioch")
      smyrna       = extract_settlement(factions, "Smyrna")
      smolensk     = extract_settlement(factions, "Smolensk")
      moscow       = extract_settlement(factions, "Moscow")
      kiev         = extract_settlement(factions, "Kiev")

      hungary[:settlements] << thessalonica << sofia
      egypt[:settlements] << jerusalem << acre << antioch
      turks[:settlements] << nicaea << smyrna << ancyra
      venice[:settlements] << rhodes << nicosia
      russia[:settlements] << smolensk << moscow << kiev

      move_army! byz, 210, 84, 191, 70

      add_basic_garrisons! factions

      factions
    }

    wars = [
      ["byzantium", "turks"],
      ["byzantium", "venice"],
      ["byzantium", "hungary"],
      ["egypt", "turks"],
      ["venice", "hre"],
    ]
    modify_standings!{|st|
      wars.each{|a,b|
        start_war!(a,b)
        st[[a,b]] = -1.0
        st[[b,a]] = -1.0
      }
      st
    }
  end
  
  def delete_all_characters_if!(factions)
    factions.each{|faction|
      faction[:characters] = faction[:characters].select{|c|
        not yield(faction[:name], *c)
      }
    }
  end
  
  def all_settlements_outside_americas(factions)
    factions.map{|faction|
      faction[:settlements].map{|s| campaign_map[s[0]][:city]}
    }.flatten - [
      "Tenochtitlan",
      "Tlaxcala",
      "Cholula",
      "Fortaleza",
      "Miccosukee",
      "Caribbean",
    ]
  end
  
  def move_character!(character, x, y)
    character[0] = x
    character[1] = y
    character[2][0].sub!(/x \d+, y \d+(\s*)\z/){ "x #{x}, y #{y}#{$1}"} or raise "Bad character line: #{character[2][0]}"
  end
  
  def random_seed!(seed)
    if seed =~ /\A\d+\z/
      srand(seed.to_i)
    else
      srand(Digest::MD5.hexdigest(seed).to_i(16))
    end
  end
  
  def neighbour_settlements(settlements, lvl)
    lvl.times{
      settlements = Set[*settlements.map{|s| campaign_map[s][:neighbours] }.inject(Set[], &:+)]
    }
    settlements
  end
  
  def random_faction_sizes(faction_size_ranges, settlements_count)
    faction_sizes = {}
    faction_size_ranges.each{|name, size_range|
      faction_sizes[name] = size_range.random_element
    }
    faction_sizes["slave"] = [settlements_count - faction_sizes.values.inject(&:+), 0].max
    faction_sizes
  end
  
  def prepare_allocation_requests(faction_size_ranges, settlements_count, allocate_rebels_last)
    faction_sizes = random_faction_sizes(faction_size_ranges, settlements_count)
    allocation_requests  = []
    faction_sizes.each{|name, sz|
      if name == "slave"
       sz.times{
          allocation_requests << [allocate_rebels_last ? 3 : 1, rand, name]
        }
      else
        allocation_requests << [0, rand, name]
        (sz-1).times{
          allocation_requests << [2, rand, name]
        }
      end
    }   
    allocation_requests.sort.map{|req| req[-1]}
  end
  
  def allocate_settlements_by_cluster!(factions, faction_size_ranges, fully_random_ratio, allocate_rebels_last)
    available = Set[*all_settlements_outside_americas(factions)]
    settlements = Hash[available.map{|s| [s, extract_settlement(factions, s)]}]
    
    allocation = Hash.new{|ht,k| ht[k] = []}
    allocation_requests = prepare_allocation_requests(faction_size_ranges, settlements.size, allocate_rebels_last)
    
    until allocation_requests.empty?
      if available.empty?
        warn "Trying to allocate #{allocation_requests.size} more settlements, but none left"
        break
      end
      name = allocation_requests.shift
      cluster_pool, cluster_pool_name = nil, nil
      (1..15).each{|i|
        cluster_pool = neighbour_settlements(allocation[name], i) & available
        cluster_pool_name = :"cluster#{i}"
        break if !cluster_pool.empty?
      }
      if name == "slave"
        pool, pool_name = available, :random_slave
      elsif rand < fully_random_ratio
        pool, pool_name = available, :random
      elsif !cluster_pool.empty?
        pool, pool_name = cluster_pool, cluster_pool_name
      else
        pool, pool_name = available, :random_forced
      end
      s = pool.random_element
      allocation[name] << s
      available.delete s
      pp [:allocating_settlement_for, name, s, pool_name]
    end
    
    allocation.each{|name, ss|
      # pp [:allocated, {name => ss}]
      factions.find{|f| f[:name] == name}[:settlements] += ss.map{|s| settlements.delete(s)}
    }
  end

  def sort_characters_by_importance(characters)
    characters.sort_by{|c|
      [
        c[2][0] =~ /\bleader\b/ ? 0 :
        c[2][0] =~ /\bheir\b/ ? 1 :
        c[2][0] =~ /\bnamed\s+character\b/ ? 2 :
        3,
        rand
      ]
    }
  end
  
  # For some reason Durazzo is missing
  def fix_durazzo! factions
    rebels = factions.find{|f| f[:name] == "slave"}
    rebels[:settlements] += [
      ["Durazzo_Province",
        ["settlement",
          "{",
          "\tlevel village",
          "\tregion Durazzo_Province",
          "",
          "\tyear_founded 0",
          "\tpopulation 400",
          "\tplan_set default_set",
          "\tfaction_creator byzantium",
          "}",
          ""]
      ],
    ]
  end

  def relocate_characters_to_settlements!(factions)
    delete_all_characters_if!(factions){|fn, x, y, c| c[0] =~ /\b(admiral)\b/ and fn != "aztecs"}
    
    factions.each{|faction|
      name = faction[:name]
      next if %W[aztecs mongols timurids].include?(name)
      settlement_xys = faction[:settlements].map{|s| campaign_map[s[0]][:loc]}

      main_characters = []
      
      charas = []
      
      faction[:characters].each{|c|
        if c[2][0] =~ /,\s*(merchant|diplomat|spy|priest|princess)\s*,/
          x,y = settlement_xys.random_element
          move_character! c, x, y
          charas << c
        else
          main_characters << c
        end
      }
      main_characters = sort_characters_by_importance(main_characters)
      
      all_extra_slots = faction[:settlements].map{|s|
        campaign_map[s[0]][:extra_slots]
      }.inject([], &:+).shuffle
      
      main_characters.each_with_index{|c,i|
        xy = settlement_xys[i]
        if xy
          move_character! c, *xy
          charas << c
        elsif name == "slave"
          # Just delete extra characters
        elsif c[2][0] =~ /\bgeneral\b/
          # pp [:extra_general, c[2][0]]
          # Ignore spare generals (not named characters)
        elsif !all_extra_slots.empty?
          move_character! c, *all_extra_slots.shift
          charas << c
        else          
          pp [:no_place_to_put, name, c[2][0]]
          move_character! c, *settlement_xys[0]
          charas << c
        end
      }
      
      faction[:characters] = charas
    }
  end
  
  def faction_name_to_religion
    unless @faction_name_to_religion
       @faction_name_to_religion = Hash[
         @files['factions'].
           gsub("islam","muslim").
           scan(/^faction\s+([a-zA-Z_]+).*?^religion\s+(\S+)/m)]
    end
    @faction_name_to_religion
  end

  def fix_temples_for_reassigned_settlements!(factions)
    temples_by_religion = {
      "catholic" => %W[small_church church abbey cathedral huge_cathedral],
      "orthodox" => %W[small_church_o church_o abbey_o cathedral_o huge_cathedral_o],
      "muslim"   => %W[small_masjid masjid minareted_masjid jama great_jama],
    }
    
    # puts ""
    factions.each{|faction|
      name = faction[:name]
      next if name == "slave"
      religion = faction_name_to_religion[name]
      # p [:faction, name, religion]
      faction[:settlements].each{|s|
        s[1].each_with_index{|line, i|
          next unless line =~ /(\A\s+type\s+temple_)(\S+)(\s+)(\S+)\z/
          next if $2 == religion
          next unless %W[catholic orthodox muslim].include?($2) # skip castle temples and pagan temples
          level = temples_by_religion[$2].index($4)
          # p s[0]
          # p [:line, $1, $2, $3, $4]
          # p [:fixd, $1, religion, $3, temples_by_religion[religion][level]]
          s[1][i] = "#{$1}#{religion}#{$3}#{temples_by_religion[religion][level]}"
        }
      }
    }
  end
  
  def random_scenario!(faction_size_ranges, fully_random_ratio, allocate_rebels_last)
    modify_scenario!{|factions|
      fix_durazzo! factions
      allocate_settlements_by_cluster! factions,
                                       faction_size_ranges,
                                       fully_random_ratio,
                                       allocate_rebels_last
      relocate_characters_to_settlements! factions
      add_basic_garrisons! factions
      fix_temples_for_reassigned_settlements! factions
      factions
    }
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
      smin = level[1..-1].map{|e| e[0] =~ /\Asettlement_min\s+(.*)/; $1}.compact[0]
      raise "Settlement minimum unknown #{smin.inspect}" unless smintable[smin]
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

# All functionality related to adding new settlements/regions
# It needs some serious cleanup but first let's see if it even works at all
# 
# CHECK: cat output/concentrated_vanilla/data/world/maps/base/descr_regions.txt  | gr '\d \d' | sort | uniq -d
# 
# FIXME: Add settlements:
# * Caucasus/Black Sea coast
# * maybe Damietta
# 
# FIXME:
# * city vs castle
# * do not default to just towns

module CampaignMapModding
  # Not idempotent, call just once
  def add_regions_to_merc_pool!(new_regions)
    ht = {}
    new_regions.each{|region, pool|
      ht[pool] ||= []
      ht[pool] << region+"_Province"
    }
    modify('mercenaries'){|file|
      file.gsub(/(.*\S.*\n)+/){|para|
        next para unless para =~ /(\Apool\s+)([^\n]+)(\s+regions\s+)(.*\z)/m
        new_regions = ht.delete($2)
        next para unless new_regions
        "#{$1}#{$2}#{$3}#{new_regions.join(" ")} #{$4}"
      }
    }
    raise "Mercenary pools not found: #{ht.keys}" unless ht.empty?
  end

  def add_region!(opts)
    name           = opts[:name]
    faction        = opts[:faction]
    rebels         = opts[:rebels]
    color          = opts[:color]
    resources      = opts[:resources]
    # 5 seems to be victory points or something
    farming        = opts[:farming]
    religion       = opts[:religion]
    level          = opts[:level]
    population     = opts[:population]
    buildings      = opts[:buildings]
    
    x              = opts[:x]
    y              = opts[:y]
    units          = opts[:units]
    commander_name = opts[:commander_name]

    total_religion = religion.inject(&:+)
    warn "Total religion for #{name} doesn't add up to 100" unless total_religion == 100
    religion = "religions { catholic #{religion[0]} orthodox #{religion[1]} islam #{religion[2]} pagan #{religion[3]} heretic #{religion[4]} }"

    modify('region_name_lookup'){|file|
      file + "#{name}_Province\n#{name}\n"
    }
    
    modify('imperial_region_name_lookup'){|file|
      file + "{#{name}}#{name}\n{#{name}_Province}#{name} Region\n"
    }
    
    modify('regions'){|file|
      file + "#{name}_Province
\t#{name}
\t#{faction}
\t#{rebels}
\t#{color}
\t#{resources}
\t5
\t#{farming}
\t#{religion}
"
    }
    
    modify('strat'){|file|
      buildings = buildings.map{|b|
"\tbuilding
\t{
\t\ttype #{b}
\t}\n"
      }.join
      
      raise "Parse errar" unless file =~ /(\A.*faction\s+slave.*?)(settlement.*\z)/m
      a, b = $1, $2
      
      this_settlement = "settlement
{
\tlevel #{level}
\tregion #{name}_Province

\tyear_founded 0
\tpopulation #{population}
\tplan_set default_set
\tfaction_creator #{faction}
#{buildings}}

"
      a + this_settlement + b
    }
    
    if x and y and units and commander_name
      modify('strat'){|file|
        raise "Parse errar" unless file =~ /(\A.*faction\s+slave.*?)(character.*\z)/m
        a, b = $1, $2
      
        this_army = "character\tsub_faction #{faction}, #{commander_name} Chieftain, general, male, age 30, x #{x}, y #{y}\narmy\n" +
        units.map{|u|
          "unit\t\t#{u}\t\t\t\texp 0 armour 0 weapon_lvl 0\n"
        }.join + "\n"

        a + this_army + b
      }
    end
  end
  
  def add_regions!
    add_regions_to_merc_pool!({
      "Fes"       => "North_Africa",
      "Tlemcen"   => "North_Africa",
      "Kairouan"  => "North_Africa",
      "Sijilmasa" => "West_Africa",
      "Benghazi"  => "North_Africa",
      "Belgrade"  => "East Balkans",
      "Ancyra"    => "Anatolia",
    })
    # Commander names need to be taken from descr_names.txt
    add_region!({
      :name => "Fes",
      :faction => "moors",
      :rebels => "Saharan_Rebels",
      :color => "57 218 57",
      :religion => [0, 0, 90, 5, 5],
      :resources => "none",
      :farming => 3,
      :level => "town",
      :population => 1500,
      :buildings => ["core_building wooden_pallisade"],
      :x => 65,
      :y => 62,
      :commander_name => "Yusuf Hissou",
      :units => [
        "Sudanese Tribesmen", "Desert Archers",
      ]
    })
    add_region!({
      :name => "Tlemcen",
      :faction => "moors",
      :rebels => "Saharan_Rebels",
      :color => "189 62 175",
      :religion => [0, 0, 75, 15, 10],
      :resources => "iron",
      :farming => 3,
      :level => "town",
      :population => 1200,
      :buildings => ["core_building wooden_pallisade"],
      :x => 83,
      :y => 59,
      :commander_name => "Galib Chiba",
      :units => [
        "Sudanese Tribesmen", "ME Town Militia", "ME Town Militia", "Desert Archers",
      ],
    })
    add_region!({
      :name => "Kairouan",
      :faction => "moors",
      :rebels => "Saharan_Rebels",
      :color => "51 208 219",
      :religion => [0, 0, 65, 33, 2],
      :resources => "none",
      :farming => 4,
      :level => "town",
      :population => 1500,
      :buildings => ["core_building wooden_pallisade"],
      :x => 135,
      :y => 55,
      :commander_name => "Da_ud Naybet",
      :units => [
        "Sudanese Tribesmen", "ME Town Militia", "ME Town Militia", "Desert Archers",
      ]
    })
    add_region!({
      :name => "Sijilmasa",
      :faction => "moors",
      :rebels => "Saharan_Rebels",
      :color => "103 218 148",
      :religion => [0, 0, 28, 70, 2],
      :resources => "none",
      :farming => 2,
      :level => "village",
      :buildings => [],
      :population => 400,
      :x => 65  + 6, 
      :y => 62 - 13,
      :commander_name => "Tashfin Mammeri",
      :units => [
        "Tuareg Camel Spearmens", "Sudanese Tribesmen", "Desert Archers", "Desert Archers",
      ],
    })
    add_region!({
      :name => "Benghazi",
      :faction => "moors",
      :rebels => "Saharan_Rebels",
      :color => "230 247 18",
      :religion => [0, 4, 60, 23, 13],
      :resources => "none",
      :farming => 2,
      :level => "village",
      :buildings => ["hinterland_roads roads"],
      :population => 600,
      :x => 181,
      :y => 36,
      :commander_name => "Khaled Jalaf",
      :units => [
        "Tuareg Camel Spearmens", "Tuareg Camel Spearmens", "Sudanese Tribesmen",
      ],
    })
    add_region!({
      :name => "Belgrade",
      :faction => "russia",
      :rebels => "Bulgarian_Rebels",
      :color => "198 68 229",
      :religion => [8, 65, 0, 25, 2],
      :resources => "gold, timber",
      :farming => 4,
      :level => "village",
      :buildings => [],
      :population => 800,
      :x => 177,
      :y => 103,
      :commander_name => "Aleksei Kuritsev",
      :units => [
        "Magyar Cavalry", "Bulgarian Brigands", "Croat Axemen",
      ],
    })
    add_region!({
      :name => "Ancyra",
      :faction => "byzantium",
      :rebels => "Anatolian_Rebels",
      :color => "56 53 103",
      :religion => [0, 65, 30, 2, 3],
    	:resources => "none", # FIXME
      :farming => 5,
      :level => "town",
      :buildings => ["core_building wooden_pallisade"],
      :population => 2000,
      :x => 232,
      :y => 85,
      :commander_name => "Modestos Elesbaam",
      :units => [
        "Byzantine Cavalry", "Trebizond Archers", "Trebizond Archers",
      ],
    })
    change_region_resources!{|name, res| # They end up being in Belgrade region
      if name == "Zagreb"
        res - ['gold', 'timber'] 
      else
        res
      end
    }

    # Since Libya didn't have enough settlements, at least let's build roads there
    add_buildings!({
      "Tripoli"    => {"hinterland_castle_roads" => 1},
      "Alexandria" => {"hinterland_roads" => 1},
    })

    # (px, 186 - py)
    # ADD: * South Sweden
  end
end

class M2TW_Mod < Mod
  include CastlesAndCitiesAreSameThing
  include SimplifyBuildingTree
  include CampaignMapModding
  include ScenarioBuilder
  
  def search_path
    # bai+bai2 are merged.
    # bai2 is super-passive but it has nice nice bettle pathfinding adjustments
    [
      ('Cities_Castles_Strat_v1.0/data' if @mod_settings[:strat]),
      ('better_bai' if @mod_settings[:bai]), 
      ('better_bai2' if @mod_settings[:bai]),
      ('better_cai' if @mod_settings[:cai]),
      'vanilla',
    ].compact
  end
  
  def open_files!
    @encodings['imperial_region_name_lookup'] = 'utf16'
    
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
    open 'win_conditions', 'descr_win_conditions.txt', 'world/maps/campaign/imperial_campaign'
    open 'region_name_lookup', 'descr_regions_and_settlement_name_lookup.txt', 'world/maps/campaign/imperial_campaign'
    open 'imperial_region_name_lookup', 'imperial_campaign_regions_and_settlement_names.txt', 'text'
    
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
    remove_game_generated_files!
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
    FileUtils.cp "data/more_regions/map_regions.tga",
                 "output/mods/concentrated_vanilla/data/world/maps/base/map_regions.tga"
  end
  
  def copy_new_models!
    models_path = "data/Cities_Castles_Strat_v1.0/data/models_strat"
    models_target_path = "output/mods/concentrated_vanilla/data"
    FileUtils.mkdir_p models_target_path
    FileUtils.cp_r models_path, models_target_path
  end

  def remove_game_generated_files!
    FileUtils.rm_f "output/mods/concentrated_vanilla/data/text/imperial_campaign_regions_and_settlement_names.txt.strings.bin"
    FileUtils.rm_f "output/mods/concentrated_vanilla/data/world/maps/base/map.rwm"
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
      name = lines[1].strip
      resources = yield(name, resources).uniq
      resources = ['none'] if resources == []
      lines[5] = st + resources.join(', ') + en
      lines.join("\n") + "\n"
    }
  end

  def no_rebels!
    change_region_resources!{|name, res|
      res + ['no_brigands', 'no_pirates']
    }
  end
  
  def crusades_everywhere!
    change_region_resources!{|name, res|
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
  
  def more_mercenaries!(speed_mod, max_mod, init_to_max_ratio)
    modify('mercenaries'){|file|
      file.gsub(/(replenish\s+)([0-9.]+)(\s*-\s*)([0-9.]+)(\s+max\s+)(\d+)(\s+initial\s+)(\d+)/){
        a0, b0, mx, ini = $2.to_f, $4.to_f, $6.to_i, $8.to_i
        a = (a0*speed_mod).round2
        b = (b0*speed_mod).round2
        mx = (mx * max_mod).round.to_i
        ini = [ini, (mx * init_to_max_ratio).round.to_i].max
        "#{$1}#{a}#{$3}#{b}#{$5}#{mx}#{$7}#{ini}"
      }
    }
  end
  
  def mod_mercenary_cost!(recruitment_mod, upkeep_mod)
    modify('units'){|file|
      file.gsub(/(.*\S.*\n)+/) {|para|
        if para =~ /^attributes.*\bmercenary_unit\b/
          para = para.sub(/(stat_cost\s*)([0-9, ]*)/) {
            pre, data = $1, $2.split(/,\s*/).map(&:to_i)
            data[1] = (data[1] * recruitment_mod).round.to_i
            data[2] = (data[2] * upkeep_mod).round.to_i
            "#{pre}#{data.join(', ')}"
          }
        end
        para
      }
    }
    modify('mercenaries'){|file|
      file.gsub(/(\bcost\b\s+)(\d+)/){
        "#{$1}#{($2.to_i * recruitment_mod).round.to_i}"
      }
    }
  end
  
  def mod_unit_upgrade_cost!(upgrade_mod)
    modify('units'){|file|
      file.gsub(/(^stat_cost\s*)([0-9, ]*)/) {
        pre, data = $1, $2.split(/,\s*/).map(&:to_i)
        data[3] = (data[3] * upgrade_mod).round.to_i
        data[4] = (data[4] * upgrade_mod).round.to_i
        "#{pre}#{data.join(', ')}"
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
  
  def move_event!(name, date_range)
    year0 = 1080
    date1 = date_range.begin - year0
    date2 = date_range.end - year0
    modify('events'){|file|
      file.sub(%r[(event\s+historic\s+#{name}\s+date\s+)(\d+(?:\s+\d+)?)]){
        if date1 == date2
          "#{$1}#{date1}"
        else
          "#{$1}#{date1} #{date2}"
        end
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
    #new_extra= [20, old_count*2 + 4].min - old_count
    new_extra = [20, old_count*2 + 2].min - old_count

    # Old:  0  1  2  3  4  5  6  7  8  9 10
    # New1: 4  6  8 10 12 14 16 18 20 20 20
    # New2: 2  4  6  8 10 12 14 16 18 20 20
 
    avail = case sub_faction
    when 'poland'
      ["Polish Nobles", "Lithuanian Cavalry", "Lithuanian Archers", "Lithuanian Archers"]
    when 'russia'
      ["Boyar Sons", "Kazaks", "EE Crossbow Militia", "EE Crossbow Militia"]
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
      # Reduce thieves guild spamming
      gd.map_triggers!{|e, name, *data|
        if name =~ /0212_Spy_Mission/
          [e, name, *data.map{|d| d.sub(/(Guild\s+thiefs_guild\s+a\s+)\d+/){"#{$1}2"}}]
        else
          [e, name, *data]
        end
      }
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
  
  def long_campaign_regions_to_take!(count)
    modify('win_conditions'){|file|
      file.gsub(/(.*\S.*\n)+/) {|para|
        if para =~ /slave|papal_states/
          para
        else
          para.sub(/(^take_regions\s+)(\d+)/){"#{$1}#{count}"}
        end
      }
    }
  end

  def distance_to_capital_penalty!(income, happiness)
    modify('settlement'){|file|
      file.sub(/(<factor name="SIF_CORRUPTION">\s+<pip_modifier value=")1.0(")/){
        "#{$1}#{income}#{$2}"
      }.sub(/(<factor name="SOF_DISTANCE_TO_CAPITAL">\s+<pip_modifier value=")1.0(")/){
        "#{$1}#{happiness}#{$2}"
      }
    }
  end
  
  def do_not_start_skirmishing!
    modify('units'){|file|
      file.gsub(/(.*\S.*\n)+/) {|para|
        next para if para !~ /^class\s+missile/ or
                     para =~ /\bstart_not_skirmishing\b/ or
                     para =~ /^category\s+siege/
        para.sub(/^(attributes.*)/) { "#{$1}, start_not_skirmishing" }
      }
    }
  end
end
