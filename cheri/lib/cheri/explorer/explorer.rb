#--
# Copyright (C) 2007,2008,2009 William N Dortch <bill.dortch@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++
#

require 'drb'
require 'rbconfig'
require 'cheri/cheri'

module Cheri
#
# I just want to reiterate this section from the license. Be *VERY* sure you
# have adequate safeguards in place (firewalls, secure network, etc.) before
# you install this component on a remote machine, particularly anything running
# live applications with real (therefore potentially private/sensitive) data.
# 
# "Careful, it's hot!"
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
module Explorer

  def self.start(port)
    if (server = @server)
      raise "server active -- call stop first" if server.alive?
      server.stop_service rescue nil
      server.thread.kill rescue nil
    end
    @explorer = RubyExplorer.new
    @server = DRb::DRbServer.new("druby://localhost:#{port}",@explorer)
    puts "Cheri::Explorer started on port #{port}\n"
    STDERR.puts %{
 WARNING! This server can expose sensitive information about the Ruby instance
 in which it runs, including file/directory paths, configuration information,
 and, if ObjectSpace is enabled, any object that has not been garbage-collected.
 If you have not taken adequate precautions to secure this installation, such as,
 but not limited to, firewalls, secure network access, and access control lists,
 you should terminate this application now by entering the following command:

 Cheri::Explorer.thread.kill

}   
  end
  def self.stop
    if (server = @server)
      server.stop_service rescue nil
      server.thread.kill rescue nil
      @explorer = nil
      @server = nil
    end
  end
  def self.thread
    @server.thread if @server  
  end

class ObjectRec
  # TODO: make this configurable (or settable in search dialog)
  MaxDataLength = 100000

  def initialize(obj)
    @z = obj.class.to_s rescue nil
    @i = obj.__id__ rescue nil
    if obj.respond_to?(:instance_variables) && (vars = (obj.instance_variables rescue nil)) && !vars.empty?
      @v = []
      vars.each do |v|
        value = obj.instance_variable_get(v.to_sym) rescue nil
        type = value.class rescue nil
        @v << NameTypeValue.new(v,type,value)
      end
    end
    if obj.respond_to?(:ancestors) && (a = obj.ancestors rescue nil)
      @a = Array.new(a.length) {|i| ValueType.new(a[i]) }
    end
    @u = (obj.superclass.to_s rescue nil) if obj.respond_to?(:superclass)
    @s = obj.inspect rescue nil
    # we're going allow a maximum of ~ 64K for value
    @s = @s[0,MaxDataLength] << '...' if @s && @s.length > MaxDataLength
  end
  def clazz
    @z  
  end
  def superclazz
    @u  
  end
  def id
    @i  
  end
  def value
    @s  
  end
  def vars
    @v  
  end
  def ancestors
    @a  
  end
  def <=>(other)
    if ObjectRec === other
      value <=> other.value
    else
      value <=> (other.to_s rescue '')
    end
  end
  def to_s
    @s || ''
  end

end #ObjectRec

class ConstRec < ObjectRec
  def initialize(parent,name,obj)
    raise Cheri.type_error(name,String) unless String === name
    raise Cheri.type_error(parent,String) if parent && !(String === parent)
    super(obj)
    @p = parent if parent
    @n = name
  end
  def parent
    @p  
  end
  def name
    @n  
  end
  def qname
    @p ? "#{@p}::#{@n}" : @n
  end
  def <=>(other)
    if ConstRec === other
      name <=> other.name
    else
      name <=> (other.to_s rescue '')
    end
  end
end #ConstRec

class ValueType
  def initialize(value)
    @z = value.class.to_s rescue '?'
    @i = value.__id__ rescue '?'
    @v = value.to_s rescue '?'
  end
  def clazz
    @z  
  end
  def id
    @i  
  end
  def value
    @v  
  end
  def <=>(other)
    if ValueRec === other
      value <=> other.value
    else
      value <=> (other.to_s rescue '')
    end
  end
  def to_a
    [@v,@z,@i]  
  end
  alias_method :to_ary, :to_a
end #ValueType

class NameValue
  def initialize(name,value)
    raise Cheri.type_error(name,String) unless String === name
    @n = name
    @i = value.__id__ rescue '?'
    @v = String === value ? value[0,128] : (value.to_s[0,128] rescue '?')
  end
  def name
    @n  
  end
  def value
    @v
  end
  def id
    @i  
  end
  def <=>(other)
    if NameValue === other
      value <=> other.value
    else
      value <=> (other.to_s rescue '')
    end  
  end
  def to_a
    [@n,@v,@i]
  end
  alias_method :to_ary, :to_a
end #NameValue

class NameTypeValue < NameValue
  def initialize(name,type,value)
    super(name,value)
    @t = String === type ? type : (type.to_s rescue '?')
    @d = type.__id__ rescue nil
  end
  def type
    @t  
  end
  def type_id
    @d
  end
  def to_a
    [@n,@t,@v,@i]  
  end
  alias_method :to_ary, :to_a
end #NameTypeValue

class SearchArgs
  attr :gc, true
  def initialize(clazz,vars=nil,any=nil)
    raise Cheri.type_error(clazz,String) unless String === clazz
    raise ArgumentError,"Invalid class "+ clazz unless /^([A-Z])((\w|::[A-Z])*)$/.match clazz
    @z = clazz
    if vars
      raise Cheri.type_error(vars,Array) unless Array === vars
      vars.each do |v|
        raise Cheri.type_error(v,SearchNameValue) unless SearchNameValue === v
        raise Cheri.type_error(v.name,Symbol) if v.name && !(Symbol === v.name)
      end
      @v = vars
      @a = !(any == nil || any == false)
    end
  end
  
  def clazz
    @z  
  end

  def vars
    @v  
  end
  
  def any
    @a  
  end

end #SearchArgs

class SearchNameValue
  def initialize(name,value)
    @n = name
    @v = value
    @r = Regexp === value
  end
  def name
    @n
  end
  def value
    @v  
  end
  def rx?
    @r 
  end
end

class SearchResults
  def initialize(sargs,results)
    raise Cheri.type_error(sargs,SearchArgs) unless SearchArgs === sargs
    raise Cheri.type_error(results,Array) unless Array === results
    @a = sargs
    @r = results
  end
  def args
    @a
  end
  def results
    @r  
  end
  def length
    @r.length  
  end
end
class MethodRec
  def initialize(mod)
    @pu = mod.public_methods(false) if mod.respond_to?(:public_methods)
    # rescue works around JRuby bug prior to 1.0.0RC3
    @pt = mod.protected_methods(false) rescue mod.protected_methods if mod.respond_to?(:protected_methods)
    @pv = mod.private_methods(false) rescue mod.private_methods if mod.respond_to?(:private_methods)
    @pui = mod.public_instance_methods(false) if mod.respond_to?(:public_instance_methods)
    @pti = mod.protected_instance_methods(false) if mod.respond_to?(:protected_instance_methods)
    @pvi = mod.private_instance_methods(false) if mod.respond_to?(:private_instance_methods)
  end

  def pub
    @pu  
  end
  def pro
    @pt
  end
  def pri
    @pv
  end
  def pub_inst
    @pui
  end
  def pro_inst
    @pti  
  end
  def pri_inst
    @pvi  
  end
end #MethodRec


class RubyExplorer
  DeprecatedVars = ["$="]
  # TODO: aggregate values that will be displayed together
  def ruby_platform
    RUBY_PLATFORM
  end
  def ruby_version
    RUBY_VERSION  
  end
  def ruby_release_date
    RUBY_RELEASE_DATE  
  end
  def env
    ENV.to_a
  end
  # TODO: this doesn't make much sense, needs to be per thread
  def global_vars
    result = []
    global_variables.each do |v|
      next if DeprecatedVars.include?v
      ev = eval(v) rescue '???'
      if Array === ev
        eva = []
        ev.each do |e|
          eva << e.to_s        
        end
        ev = eva
      elsif Hash === ev
        eva = []
      ev.each_pair do |k,e|
        eva << [k.to_s,e.to_s]      
      end
        ev = eva
      else
        ev = ev.to_s 
      end
      result << [v,ev]
    end
    result
  end
  def constants
    result = []
    begin
      Module.constants.each do |c|
        result << ([c,eval("::#{c}.class").to_s,eval("::#{c}.to_s")] rescue [c.to_s,'???', '???'])
      end
    rescue
    end
    result
  end
  def const_recs(parent_str=nil)
    parent_str = nil if 'Module' == parent_str
    result = []
    if parent_str
      raise Cheri.type_error(parent_str,String) unless String === parent_str
      # make sure we don't have anything executable before we eval it
      raise ArgumentError,"Invalid constant "+parent_str unless /^([A-Z])((\w|::[A-Z])*)$/.match parent_str
      parent_str = parent_str[2,parent_str.length-2] if parent_str.rindex('::',0)
      if (parent = eval("::#{parent_str}") rescue nil) &&
          ((parent.respond_to?(:constants) && (consts = parent.constants rescue nil)) ||
           (parent.respond_to?(:__constants__) && (consts = parent.__constants__ rescue nil)))
        consts.each do |c|
          if (ec = (eval("::#{parent_str}::#{c}") rescue nil))
            result << ConstRec.new(parent_str,c,ec)
          end
        end
      end
    else
      Module.constants.each do |c|
        if (ec = (eval("::#{c}") rescue nil))
          result << ConstRec.new(nil,c,ec)
        end
      end
    end
    result
  end

  def module_methods(name,id=nil)
    if id && defined?ObjectSpace
      raise Cheri.type_error(id,Fixnum) unless Fixnum === id
      # doing this in two steps to work around JRuby bug (JRUBY-1125)
      mod = ObjectSpace._id2ref(id)
      if Module === mod
        return MethodRec.new(mod)
      end
    elsif name
      raise Cheri.type_error(name,String) unless String === name
      return if /#/.match name
      # make sure we don't have anything executable before we eval it
      raise ArgumentError,"Invalid module "+name unless /^([A-Z])((\w|::[A-Z])*)$/.match name
      if Module === (mod = eval("::#{name}") rescue nil)
        return MethodRec.new(mod)       
      end
    end
    nil
  end
  
  def object(id)
    return unless id && defined?ObjectSpace
    raise Cheri.type_error(id,Fixnum) unless Fixnum === id
    # doing this in two steps to work around JRuby bug (JRUBY-1125)
    obj = ObjectSpace._id2ref(id)
    if obj && !(Fixnum === obj)
      if Module === obj && (name = obj.name rescue nil)
        if (ix = name.rindex('::'))
          parent = name[0,ix]
          name = name[ix+2,name.length - ix - 2]
        else
          parent = nil
        end
        ConstRec.new(parent,name,obj)
      else
        ObjectRec.new(obj)
      end
    else
      nil
    end
  end

  def object_methods(id)
    return unless id && defined?ObjectSpace
    raise Cheri.type_error(id,Fixnum) unless Fixnum === id
    # doing this in two steps to work around JRuby bug (JRUBY-1125)
    obj = ObjectSpace._id2ref(id)
    if obj && !(Fixnum === obj)
      return MethodRec.new(obj)    
    end
  end
  
  def simple_value(id,maxlen=80)
    return unless id && defined?ObjectSpace
    raise Cheri.type_error(id,Fixnum) unless Fixnum === id
    # doing this in two steps to work around JRuby bug (JRUBY-1125)
    obj = ObjectSpace._id2ref(id)
    if obj && !(Fixnum === obj)
      obj.to_s[0,maxlen] rescue 'Unreadable'
    else
      nil
    end
  end
  
  def find(sargs)
    return unless sargs && defined?ObjectSpace
    raise Cheri.type_error(sargs,SearchArgs) unless SearchArgs === sargs
    sclazz = sargs.clazz
    raise Cheri.type_error(sclazz,String) unless String === sclazz
    # make sure we don't have anything executable before we eval it
    raise ArgumentError,"Invalid class "+ sclazz unless /^([A-Z])((\w|::[A-Z])*)$/.match sclazz
    if Module === (clazz = (eval("::#{sclazz}") rescue nil))
      GC.start if sargs.gc
      result = []
      if (vars = sargs.vars) && !vars.empty?
        # just supporting one var name and/or value for now
        sname = vars[0].name
        raise ArgumentError,"Invalid instance variable" if sname && !(Symbol === sname)
        sval = vars[0].value
        sval = nil if String === sval && sval.empty?
        rx = Regexp === sval
      else
        sname = nil
        sval = nil
      end
      if sname && sval
        ObjectSpace.each_object(clazz) do |o|
          if Fixnum === (id = o.__id__ rescue nil) &&
              #(o.respond_to?(:instance_variable_get) rescue nil) &&
              (iv = o.instance_variable_get(sname) rescue nil) &&
              (String === iv || String === (iv = iv.to_s rescue nil)) &&
              (rx ? (iv =~ sval rescue nil) : (iv.index(sval) rescue nil))
            result << id
          end
        end
      elsif sname
        sname = sname.to_s
        ObjectSpace.each_object(clazz) do |o|
          if Fixnum === (id = o.__id__ rescue nil) &&
              #(o.respond_to?(:instance_variables) rescue nil) &&
              Array === (ivs = o.instance_variables rescue nil) &&
              (ivs.include?(sname) rescue nil)
            result << id
          end
        end
      elsif sval
        # note: _not_ calling inspect here to avoid circular reference trap;
        # examining (potentially) each instance var instead
        ObjectSpace.each_object(clazz) do |o|
          if Fixnum === (id = o.__id__ rescue nil)
            if (String === (os = o) || String === (os = o.to_s rescue nil)) &&
                (rx ? (os =~ sval rescue nil) : (os.index(sval) rescue nil))
              result << id
            elsif Array === (ivs = o.instance_variables rescue nil)
              hit = nil
              ivs.each do |ivn|
                if (iv = o.instance_variable_get(ivn.to_sym) rescue nil) &&
                    (String === iv || String === (iv = iv.to_s rescue nil)) &&
                    (rx ? (iv =~ sval rescue nil) : (iv.index(sval) rescue nil))
                  result << id unless hit
                  hit = true
                  # this doesn't appear to be breaking?
                  break # TODO: check for LocalJumpError
                end
              end
            end
          end
        end
      else
        ObjectSpace.each_object(clazz) do |o|
          if Fixnum === (id = o.__id__ rescue nil)
            result << id
          end
        end
      end
      result
    else
      []
    end
  end

  def config
    Config::CONFIG  
  end

if (defined?JRUBY_VERSION) &&
    ((JRUBY_VERSION =~ /^(\d+\.\d+\.\d+)([-\.A-Z0-9]*)/ &&
      (($1 == '1.0.0' && ($2.empty? || $2 >= 'RC3')) || $1 > '1.0.0')) ||
    (JRUBY_VERSION =~ /^(\d+\.\d+)([-\.A-Z0-9]*)/ &&  $1 >= '1.0'))

  System = ::Java::JavaLang::System
  Runtime = ::Java::JavaLang::Runtime
  JDate = ::Java::JavaUtil::Date
  JVersion = 'java.version'.freeze
  JVendor = 'java.vendor'.freeze
  RtName = 'java.runtime.name'.freeze
  RtVersion = 'java.runtime.version'.freeze
  VmName = 'java.vm.name'.freeze
  VmVersion = 'java.vm.version'.freeze
  VmVendor = 'java.vm.vendor'.freeze
    
  def jruby_version
    JRUBY_VERSION  
  end
  def env_java
    ENV_JAVA.to_hash
  end
  def env_java_brief
    {
      JVersion => ENV_JAVA[JVersion],
      JVendor => ENV_JAVA[JVendor],
      RtName => ENV_JAVA[RtName],
      RtVersion => ENV_JAVA[RtVersion],
      VmName => ENV_JAVA[VmName],
      VmVersion => ENV_JAVA[VmVersion],
      VmVendor => ENV_JAVA[VmVendor],
    }
  end
  def security_manager
    System.security_manager ? System.security_manager.to_string : nil
  end
  def available_processors
    Runtime.runtime.available_processors
  end
  def free_memory
    Runtime.runtime.free_memory  
  end
  def total_memory
    Runtime.runtime.total_memory  
  end
  def max_memory
    Runtime.runtime.max_memory  
  end
  def jruby_start_time
    @start_time ||= JDate.new(Cheri::JRuby.start_time).to_string
  end
  def object_space?
    Cheri::JRuby.object_space?  
  end

end # if defined...

end #RubyExplorer

end #Explorer
end #Cheri
