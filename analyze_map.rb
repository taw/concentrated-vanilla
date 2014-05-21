#!/usr/bin/env ruby1.9

require "pp"
require "set"

# Image in TGA order
class Image
  attr_reader :xsize, :ysize, :data

  def initialize(path)
    if path =~ /\.tga\z/i
      @xsize, @ysize, @data = Image.read_tga(path)
    elsif path =~ /\.pnm\z/i
      @xsize, @ysize, @data = Image.read_pnm(path)
    else
      raise "Only TGA and PNM formats supported"
    end
  end
  
  def [](x,y)
    @data[(y * @xsize + x) * 3, 3]
  end

  def self.flip_data(xsize, ysize, data)
    # Y flip
    data = (0...ysize).map{|y| data[(ysize-1-y)*xsize*3, xsize*3] }.join
    # Pixel flip
    (0...xsize*ysize).map{|i| data[i*3,3].reverse}.join
  end
  
  def self.read_tga(path)
    data = File.open(path, 'rb', &:read)
    header = data[0,18]
    data = data[18..-1]
    raise "Only uncompressed 24-bit TGAs supported" unless header[0, 12].unpack("C12") == [0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0] and header[16,2].unpack("v") == [24]
    x, y = header[12,4].unpack("vv")
    raise "FAIL, expected #{x*y*3} bytes, got #{data.size} bytes" unless data.size == x*y*3
    return [x,y,data]
  end

  def self.read_pnm(path)
    File.open(path,'rb'){|fh|
      raise "FAIL" unless fh.readline == "P6\n"
      raise "FAIL" unless fh.readline =~ /\A(\d+) (\d+)\n/
      x, y = $1.to_i, $2.to_i
      raise "FAIL" unless fh.readline == "255\n"
      data = fh.read
      raise "FAIL, expected #{x*y*3} bytes, got #{data.size} bytes" unless data.size == x*y*3
      return [x,y,Image.flip_data(x,y,data)]
    }
  end
end

class Features < Image
  def each_land_bridge
    land_bridge_px = "\x00\xFF\x00"
    land_bridge_pixels = Set[]
    (0...@ysize).each{|y|
      (0...@xsize).each{|x|
        next unless self[x,y] == land_bridge_px
        land_bridge_pixels << [x,y]
      }
    }
    land_bridge_pixels.each{|sx,sy|
      next if land_bridge_pixels.include?([sx-1,sy])
      next if land_bridge_pixels.include?([sx,sy-1])
      ex, ey = sx, sy
      while land_bridge_pixels.include?([ex+1,ey])
        ex += 1
      end
      while land_bridge_pixels.include?([ex,ey+1])
        ey += 1
      end
      yield(sx,sy,ex,ey)
    }
  end
end

class Map < Image
  def city?(x,y)
    self[x,y] == "\x00\x00\x00"
  end

  def port?(x,y)
    self[x,y] == "\x00\x00\x00"
  end
  
  def environment(x,y)
    (y-1..y+1).map{|yi|
      next if yi < 0 or yi >= ysize
      (x-1..x+1).map{|xi|
        next if xi < 0 or xi >= xsize
        self[xi,yi]
      }
    }.flatten.compact.uniq
  end
  
  def each_city
    (0...@ysize).each{|y|
      (0...@xsize).each{|x|
        next unless city?(x,y)
        yield(x,y)
      }
    }
  end
  
  def each_neighbour_pixel_pair
    (0..@ysize-2).each{|y|
      (0..@xsize-2).each{|x|
        a = self[x,y]
        b = self[x+1,y]
        c = self[x,y+1]
        d = self[x+1,y+1]
        yield(a,b)
        yield(a,c)
        yield(a,d)
        yield(b,c)
        yield(b,d)
        yield(c,d)
      }
    }
  end
  
  def each_neighbour_region_pair
    pairs = Set[]
    each_neighbour_pixel_pair{|a,b|
      next if a == b
      next if a == "\x00\x00\x00" or b == "\x00\x00\x00"
      next if a == "\xFF\xFF\xFF" or b == "\xFF\xFF\xFF"
      pairs << [a,b]
    } 
    pairs.each{|a,b|
      yield(a,b)
    }
  end
end

class RegionInfo
  attr_reader :region, :city, :color, :color_bin
  
  def initialize(lines)
    raise "Wrong number of lines" unless lines.size == 9
    @region = lines[0].strip
    @city = lines[1].strip
    @color = lines[4].scan(/\d+/).map(&:to_i).reverse
    raise "Parse error" unless @color.size == 3
    @color_bin = @color.pack("CCC")
  end
  
  def to_s
    "Region(#{@region})"
  end
  
  alias_method :inspect, :to_s
end

class AnalyzeMap
  def load_regions(path)
    lines = File.readlines(path)
    lines = lines.map{|line| line.chomp.sub(/;.*/, "")}.grep(/\S/)
    
    regions = []
    while lines.size >= 9
      regions << RegionInfo.new(lines.shift(9))
    end
    raise "Extra lines at end of file" unless lines.empty?
    regions
  end

  def region_map
    unless @region_map
      @region_map = {}
      @regions.each{|r|
        @region_map[r.color_bin] = r
      }
    end
    @region_map
  end
  
  def city_xy
    unless @city_xy
      @city_xy = {}
      @map.each_city{|x,y|
        city = environment_regions(x,y)
        @city_xy[city.city] = [x,y]
      }
    end
    @city_xy
  end

  def environment_regions(x,y)
    rv = []
    rvextra = []
    @map.environment(x,y).each{|e|
      next if e == "\x00\x00\x00" or e == "\xFF\xFF\xFF"
      reg = region_map[e]
      if reg
        rv << reg
      else
        rvextra << e.unpack("CCC")
      end
    }
    if rv.size == 1
      return rv[0]
    else
      raise "Context failure for #{x},#{y}"
    end
  end
  
  def land_bridges
    unless @land_bridges
      rv = []
      @features.each_land_bridge{|sx,sy,ex,ey|
        r1 = region_at(sx,sy)
        r2 = region_at(ex,ey)
        if sx == sy
          r2 ||= region_at(ex+1,ey)
        else
          r2 ||= region_at(ex,ey-1)
        end
        next if r1 == r2
        rv << [r1, r2]
        rv << [r2, r1]
      }
      @land_bridges = rv.uniq
    end
    @land_bridges
  end

  def neighbours
    unless @neighbours
      rv = Hash.new{|ht,k| ht[k] = Set[]}
      @map.each_neighbour_region_pair{|a,b|
        a = region_map[a]
        b = region_map[b]
        next unless a and b
        rv[a.city] << b.city
        rv[b.city] << a.city
      }
      land_bridges.each{|a,b|
        rv[a.city] << b.city
        rv[b.city] << a.city
      }
      @neighbours = rv
    end
    @neighbours
  end

  def neighbours_xy
    unless @neighbours_xy
      @neighbours_xy = {}
      city_xy.each{|c1, (x1,y1)|
        @neighbours_xy[c1] = city_xy.map{|c2,(x2,y2)|
          [Math.sqrt((x1-x2)**2 + (y1-y2)**2), c2]
        }.sort[1..-1].map{|d,c2| c2}
      }
    end
    @neighbours_xy
  end

  def extra_slots(city,x,y)
    rv = []
    (x-5..x+5).each{|cx|
      (y-5..y+5).each{|cy|
        next if cx == x and cy == y
        next if cx < 0 or cy < 0
        next if cx >= @map.xsize or cy >= @map.ysize
        next unless city.color_bin == @map[cx,cy]
        rv << [cx, cy]
      }
    }
    # Some separation
    rv.sort_by{|cx,cy| [cx+cy % 7, cx, cy] }[0,20]
  end
  
  def region_at(x,y)
    region_map[@map[x,y]]
  end

  # @@@
  def full_neighbours
    unless @full_neighbours
      @full_neighbours = Hash.new{|ht,k| ht[k] = Set[]}
      neighbours_xy.each{|c1, nei|
        nei[0,5].each{|c2|
          # Reverse link only if geo-linked
          @full_neighbours[c1] << c2
          @full_neighbours[c2] << c1 if neighbours[c1].include?(c2)
        }
      }
      # @full_neighbours.map{|c1, nei|
      #   [c1, *nei.map{|c2| [c2, neighbours_xy[c1].index(c2), neighbours_xy[c2].index(c1), neighbours[c1].include?(c2)]}.sort_by{|u| u[1]}]
      # }.sort.each{|u| pp u}
    end
    @full_neighbours
  end

  def run!(dir)
    @map = Map.new("#{dir}/map_regions.tga")
    @features = Features.new("#{dir}/map_features.tga")
    @regions = load_regions("#{dir}/descr_regions.txt")
    rv = []
    @map.each_city{|x,y|
      city = environment_regions(x,y)
      rv << {
        :loc => [x, y],
        :region => city.region,
        :city => city.city,
        :neighbours => full_neighbours[city.city].sort,
        :extra_slots => extra_slots(city,x,y),
      }
    }
    rv
  end
end

if __FILE__ == $0
  AnalyzeMap.new.run!(dir)
  print "MapInformation = "
  pp rv
end
