#!/usr/bin/env ruby1.9

# Image in PNM order
class Image
  attr_reader :xsize, :ysize, :data
  def initialize(xsize, ysize, data=nil)
    data ||= "\x00" * (3*xsize*ysize)
    raise "Data size is wrong" unless xsize*ysize*3 == data.size
    @xsize, @ysize, @data = xsize, ysize, data
  end

  def self.parse_pnm(path)
    xsize, ysize, data = PNM.parse(path)
    Image.new(xsize, ysize, data)
  end

  def self.flip_data(xsize, ysize, data)
    # Y flip
    data = (0...ysize).map{|y| data[(ysize-1-y)*xsize*3, xsize*3] }.join
    # Pixel flip
    (0...xsize*ysize).map{|i| data[i*3,3].reverse}.join
  end

  def [](x,y)
    unless x >= 0 and y >=0 and x < @xsize and y < @ysize
      raise "Coordinates(#{x},#{y}) outside image size (#{@xsize}x#{@ysize})"
    end
    @data[(@xsize*y + x) * 3, 3].unpack("CCC")
  end
  
  def []=(x,y,v)
    unless x >= 0 and y >=0 and x < @xsize and y < @ysize
      raise "Coordinates(#{x},#{y}) outside image size (#{@xsize}x#{@ysize})"
    end
    @data[(@xsize*y + x) * 3, 3] = v.pack("CCC")
  end

  def self.read_tga(path)
    data = File.open(path, 'rb', &:read)
    header = data[0,18]
    data = data[18..-1]
    raise "Only uncompressed 24-bit TGAs supported" unless header[0, 12].unpack("C12") == [0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0] and header[16,2].unpack("v") == [24]
    x, y = header[12,4].unpack("vv")
    raise "FAIL, expected #{x*y*3} bytes, got #{data.size} bytes" unless data.size == x*y*3
    return [x,y,Image.flip_data(x,y,data)]
  end

  def self.read_pnm(path)
    File.open(path,'rb'){|fh|
      raise "FAIL" unless fh.readline == "P6\n"
      raise "FAIL" unless fh.readline =~ /\A(\d+) (\d+)\n/
      x, y = $1.to_i, $2.to_i
      raise "FAIL" unless fh.readline == "255\n"
      data = fh.read
      raise "FAIL, expected #{x*y*3} bytes, got #{data.size} bytes" unless data.size == x*y*3
      return [x,y,data]
    }
  end
  
  def each_pixel
    (0...ysize).each{|y|
      (0...xsize).each{|x|
        yield(x,y,self[x,y])
      }
    }
  end
  
  def save_tga!(path)
    rv =  [0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0].pack("C12")
    rv << [@xsize, @ysize, 24].pack("vvv")
    rv << Image.flip_data(@xsize, @ysize, @data)
    File.open(path, 'wb'){|fh|
      fh.write rv
    }
  end
end

class RegionsFile
  attr_reader :data
  # Rome has 8 lines per region
  # M2   has 9 lines per region (religion last)
  def initialize(path_in)
    @data = {}
    region = nil
    lines = File.read(path_in).gsub("\r", "").gsub(/;.*/, "").gsub(/^\s*$\n/, "").split("\n")
    lines.each{|line|
      if line =~ /\A(\S+)\z/
        region = $1
        @data[region] ||= []
      else
        @data[region] << line.strip
      end
    }
  end
  
  def color_lookup_table
    unless @color_lookup_table
      @color_lookup_table = {}
      @data.each{|region, rdata|
        color = rdata[3].split.map(&:to_i)
        @color_lookup_table[color] = [region, rdata[0]]
      }
    end
    @color_lookup_table
  end
end

class StratFile
  attr_reader :data
  def initialize(path_in)
    @data = {}
    faction = nil
    File.readlines(path_in).each{|line|
      if line =~ /\Afaction\s+(\S+)\s*,/
        faction = $1
        @data[faction] ||= []
      elsif line =~ /\A\s*region\s*(\S+)/
        @data[faction] << $1
      end
    }
  end
end

class SMFactionsFile
  attr_reader :data
  def initialize(path_in)
    @data = {}
    faction = nil
    File.readlines(path_in).each{|line|
      line.strip!
      if line =~ /\Afaction\s+(\S+)/
        faction = $1
        @data[faction] ||= [nil, nil]
      elsif line =~ /\Aprimary_colour\s+(.*)/
        @data[faction][0] = parse_color($1)
      elsif line =~ /\Asecondary_colour\s+(.*)/
        @data[faction][1] = parse_color($1)
      end
    }
  end
  
  def parse_color(color)
    raise "Parse error: `#{color}'" unless color.gsub(/\s+/, "") =~ /\Ared(\d+),green(\d+),blue(\d+)\z/
    [$1.to_i, $2.to_i, $3.to_i]
  end
end

class RegionsMap < Image
  def initialize(path, color_lookup_table)
    @xsize, @ysize, @data = Image.read_tga(path)
    @color_lookup_table = {}
    @color_lookup_table["\x00\x00\x00"] = :port
    @color_lookup_table["\xff\xff\xff"] = :city
    color_lookup_table.each{|c,(rn,cn)|
      @color_lookup_table[c.pack("CCC")] = rn
    }
  end
  
  def region_at(x,y)
    unless x >= 0 and y >=0 and x < @xsize and y < @ysize
      raise "Coordinates(#{x},#{y}) outside image size (#{@xsize}x#{@ysize})"
    end
    @color_lookup_table[@data[(@xsize*y + x) * 3, 3]] || :water
  end
end

class PoliticalMapMaker
  def initialize(base_dir)
    @base_dir       = base_dir
    @regions        = RegionsFile.new("#{base_dir}/world/maps/base/descr_regions.txt")
    @strat          = StratFile.new("#{base_dir}/world/maps/campaign/imperial_campaign/descr_strat.txt")
    @faction_colors = SMFactionsFile.new("#{base_dir}/descr_sm_factions.txt")
    @regions_map    = RegionsMap.new("#{base_dir}/world/maps/base/map_regions.tga", @regions.color_lookup_table)
    @xsize = @regions_map.xsize
    @ysize = @regions_map.ysize
  end

  def region_to_faction_colors
    unless @region_to_faction_colors
      @region_to_faction_colors = {}
      @strat.data.each{|fn, regions|
        regions.each{|rn|
          @region_to_faction_colors[rn] = @faction_colors.data[fn]
        }
      }
    end
    @region_to_faction_colors
  end

  def run!(path_out)
    new_img  = Image.new(2*@xsize-1, 2*@ysize-1)
    new_img2 = Image.new(2*@xsize-1, 2*@ysize-1)
    (0...2*@ysize-1).each{|y|
      (0...2*@xsize-1).each{|x|
        a = @regions_map.region_at((x)  /2,(y)/2  )
        b = @regions_map.region_at((x+1)/2,(y)/2  )
        c = @regions_map.region_at((x)  /2,(y+1)/2)
        d = @regions_map.region_at((x+1)/2,(y+1)/2)
        regions = [a,b,c,d].uniq
        regions2 = regions - [:water, :city, :port]

        new_img2[x,y] = [1,1,1] # Ignore

        if regions.include?(:water) # water
          new_img[x,y] = [41, 140, 233]
        elsif regions == [:port]
          new_img[x,y] = [0,0,0]
        elsif regions == [:city]
          new_img[x,y] = [255, 255, 255]
        elsif regions2.size == 1
          rn = regions2[0]
          colors = region_to_faction_colors[rn]
          colors ||= @faction_colors.data["slave"]
          new_img[x,y] = colors[0]
          new_img2[x,y] = colors[1]
        else
          new_img[x,y] = [64, 64, 64]
        end
      }
    }
    (0...2*@ysize-1).each{|y|
      (0...2*@xsize-1).each{|x|
        a  = new_img[x,y]
        a2 = new_img2[x,y]
        b  = new_img[x+1,y] rescue nil
        c  = new_img[x-1,y] rescue nil
        d  = new_img[x,y+1] rescue nil
        e  = new_img[x,y-1] rescue nil
        if a2 != [1,1,1] and ([b,c,d,e].include?([64,64,64]) or [b,c,d,e].include?([41, 140, 233]))
          new_img[x,y] = a2
        end
      }
    }
    new_img.save_tga!(path_out)
  end
end

if __FILE__ == $0
  pmm = PoliticalMapMaker.new("output/mods/concentrated_vanilla/data/")
  pmm.run!("output/political_map.tga")
end
