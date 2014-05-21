#--
# Copyright (C) 2007,2008 William N Dortch <bill.dortch@gmail.com>
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

module Cheri
module Java
module Builder

module Util
class << self
  #:stopdoc:
  S = 'set'
  G = 'get'
  I = 'is'
  U = '_'
  #:startdoc:

  # call-seq:
  #   Util.uf('str')          -> 'Str'
  #   Util.upper_first('str') -> 'Str'
  #   
  # Like String#capitalize, but only alters the first character, so 
  # Util.upper_first('abCdeF') -> 'AbCdeF'.
  def uf(y)
    s = y.to_s
    s[0] = s[0,1].upcase[0] unless s.empty?
    s
  end
  alias_method :upper_first, :uf

  # call-seq:
  #   Util.cc('my_string')               -> 'MyString'
  #   Util.camel_case('my_string')       -> 'MyString'
  #   Util.upper_camel_case('my_string') -> 'MyString'
  #   
  # create upper-camel-case string
  def cc(sym)
    s = String === sym ? sym.dup : sym.to_s
    if s.index(?_)
      s.split(U).collect do |n| uf(n); end.join
    else
      # preserve existing camel-case, just force first char to upper
      uf(s)
    end
  end
  alias_method :camel_case, :cc #:nodoc:
  alias_method :upper_camel_case, :cc #:nodoc:

  # call-seq:
  #   Util.lcc('my_string')              -> 'myString'
  #   Util.lower_camel_case('my_string') -> 'myString'
  #   
  def lcc(str)
    s = String === str ? str.dup : str.to_s
    # get lower-camel-case method name
    a = s.split(U)
    a.each_index do |i| a[i].capitalize! if i > 0; end.join
  end
  alias_method :lower_camel_case, :lcc #:nodoc:

  def setter?(s)
    s.to_s.rindex(S,0)
  end
  alias_method :is_setter, :setter?

  def getter?(s)
    s.to_s.rindex(G,0)
  end
  alias_method :is_getter, :getter?

  def iser?(s)
    (s = s.to_s).rindex(I,0) || ?? == s[-1]
  end
  alias_method :is_iser, :iser?
  
  def acc?(s)
    (c = (s = s.to_s)[-1]) == ?= || c == ?? || s.rindex(G,0) || s.rindex(S,0) || s.rindex(I,0)
  end
  alias_method :is_accessor, :acc?

  def setter(y)
    :"set#{cc(y)}"
  end
  alias_method :make_setter, :setter

  def getter(y)
    :"get#{cc(y)}"
  end
  alias_method :make_getter, :getter

  def iser(y)
    :"is#{cc(y)}"
  end
  alias_method :make_iser, :iser

  # symbols are considered constants if the first
  # character is capitalized
  def const?(s)
    (c = s.to_s[0]) >= ?A && c <= ?Z
  end
  alias_method :is_constant, :const?
end #self
end #Util

module Interfaces
#:stopdoc:
CJava = Cheri::Java
#:startdoc:
ListenerInfo = Struct.new(:clazz, :methods, :add_method_name)
@impls = {}
@info = {}
class << self
  def get_listener_impl(info)
    @impls[info.clazz] ||= create_listener_impl(info)
  end
  def create_listener_impl(info)
    # TODO: logic to deal with JRuby pre-1.0.0, remove later
    if (clazz = info.clazz).instance_of?(Module)
      impl = Class.new do
        include clazz
      end
    else
      impl = Class.new(clazz)
    end
    info.methods.each do |m|
      n = m.name
      impl.module_eval <<-EOM
        def #{n}=(blk)
          @#{n} = blk
        end
        def #{n}(e)
          @#{n}.call(e) if @#{n}
        end
      EOM
    end
    impl
  end
  def get_listener_info(java_class,method_name)
    if (info = @info[key = [java_class,method_name]])
      return info
    end
    java_class.java_instance_methods.each do |m|
      if m.name.match(/add(\w+)Listener/) &&
         m.argument_types.length == 1 &&
         m.argument_types[0].name.match(/([\w|.]+)Listener/)
        clazz = m.argument_types[0]
        methods = clazz.java_instance_methods
        methods.each do |im|
          if im.name == method_name
            info = @info[key] =  ListenerInfo.new(CJava.get_class(clazz.name),methods,m.name)
            return info
          end
        end
      end
    end
    nil
  end
end # self
end #Interfaces

# TODO: leftover from JRBuilder, rethink for Cheri

module Constants
#:stopdoc:
CJava = Cheri::Java
#:startdoc:
class ConstRec
  def initialize(t,d,n=nil)
    @t = t
    @d = d
    @n = n if n
  end
  def type_cls
    @t  
  end
  def decl_cls
    @d  
  end
  def next_rec
    @n  
  end
  def next_rec=(n)
    @n = n  
  end
end
@method_cache = {}
class << self
  def resolve_ctor(clazz,args,constants)
    return true if args.empty?
    # try the simple resolve first
    const_arr = simple_resolve(clazz,args)
    return true unless const_arr
    # check against constructor argument types
    argc = args.length
    key = "#{clazz.java_class.name}##{argc}"
    ctor_args = @method_cache[key]
    unless ctor_args
      ctor_args = []
      clazz.java_class.constructors.each do |ctor|
        ctor_args << ctor.argument_types if ctor.arity == argc  
      end
      @method_cache[key] = ctor_args
    end
    if ctor_args.empty?
      raise NoMethodError,"No constructor found for class '#{clazz.java_class.name} with argument count #{argc}"
    end
    arg_type_resolve(clazz,const_arr,ctor_args,args,constants)
  end
  
  def resolve_meth(clazz,method_name,args,constants)
    return true if args.empty?
    # try the simple resolve first
    const_arr = simple_resolve(clazz,args)
    return true unless const_arr
    argc = args.length
    cased_method_name = Util.lcc(method_name)
    key = "#{clazz.java_class.name}##{cased_method_name}##{argc}"
    method_args = @method_cache[key]
    unless method_args
      method_args = []
      clazz.java_class.java_instance_methods.each do |method|
        if method.arity == argc && method.name == cased_method_name
          method_args << method.argument_types
        end
      end
      @method_cache[key] = method_args
    end
    if method_args.empty?
      raise NoMethodError,"No method '#{method_name}' found in class '#{clazz.java_class.name} with argument count #{argc}"
    end
    arg_type_resolve(clazz,const_arr,method_args,args,constants)
  end
  
  private
  def simple_resolve(clazz,args)
    ca = nil
    0.upto(args.length-1) do |i|
      a = args[i]
      next unless const?(a)
      begin
        # try the easy lookup on this class first
        args[i] = clazz.const_get(a)
      rescue
        (ca ||= []) << [a,i,nil]
      end
    end
    ca
  end
  
private

  Strong = 3
  Weak = 2
  def arg_type_resolve(obj_cls,const_arr,target_args,args,constants)
    # first whittle it down on regular args
    argc = args.length
    # skip this step if all args are constants, or if
    # there is only one ctor/method
    unless argc == const_arr.length || target_args.length == 1
      0.upto(argc-1) do |i|
        arg = args[i]
        next if const?(arg)
        (target_args.length - 1).downto(0) do |t|
          arg_type_arr = target_args[t]
          unless Types.type_matches_arg(arg_type_arr[i],arg)
            target_args.delete_at(t)
            if target_args.empty?
              raise NoMethodError,"No matching method/constructor for args [#{args.join(', ')}], class #{obj_cls}"
            end
          end
        end
      end
    end

    matches = Array.new(target_args.length) {
      Array.new(const_arr.length) {
        Array.new(2) }}
    # for each :CONSTANT found in args,
    0.upto(const_arr.length - 1) do |c|
      # the :CONSTANT symbol 
      const_sym = const_arr[c][0]
      # the position of the :CONSTANT in args
      i = const_arr[c][1]
      # for each ctor/method 
      (target_args.length - 1).downto(0) do |t|
        # the expected type of the ith arg
        target_type = target_args[t][i]
        # first, see if the target type defines the :CONSTANT
        begin
          ttcls = CJava.get_class(target_type.name)
          value = ttcls.const_get(const_sym)
          if Types.type_matches_arg(target_type,value)
            matches[t][c][0] = Strong
            matches[t][c][1] = value
            # strong match, no need to check the cached values
            next          
          end
        rescue
        end        
        # go through the constant defs, and take the first
        # one that matches
        # TODO: check package names and give preference to 
        # the definition that occurs in the same package
        # (or nearest package, longest match on pkg name?)
        found_match = false
        rec_arr = constants.get(const_arr[c][0])
        if rec_arr
          0.upto(rec_arr.length-1) do |r|
            
            # TODO: try low-level class for const_type
            
            const_type = CJava.get_class(rec_arr[r].type_cls)
             # TODO: need better type comparison 
            if target_type == const_type || # covers primitives, there's probably a better way...
               target_type.assignable_from?(const_type.java_class)
              found_match = true
              matches[t][c][0] = Weak
              matches[t][c][1] = CJava.get_class(rec_arr[r].decl_cls).const_get(const_sym)
              break
            end
          end
        end
        unless found_match
          target_args.delete_at(t)
          matches.delete_at(t)
          if target_args.empty?
            # TODO: need to pass in class/method names for better message
            raise NoMethodError,"No matching method/constructor for args/constants [#{args.join(', ')}]"
          end
        end
      end
    end
    # some fairly simplistic logic to choose the best candidate
    # set of constants when multiple ctors/methods are matched.
    # probably better to raise an exception asking the user to 
    # specifify the actual Java constants, but I want to play 
    # with this for a while first.
    hi_score = 0
    target = nil
    0.upto(matches.length-1) do |i|
      score = 0
      0.upto(matches[i].length-1) do |j|
        val = matches[i][j]
        score += val[0] if val
      end
      if score > hi_score
        hi_score = score
        target = i
      end
    end
    # plug the values into the args array
    0.upto(const_arr.length-1) do |c|
      args[const_arr[c][1]] = matches[target][c][1]
    end
    true
  end

  def const?(y)
    y.instance_of?(Symbol) && (c = y.to_s[0]) >= ?A && c <= ?Z
  end

end #self
end #Constants

# TODO: leftover from JRBuilder, rethink for Cheri
module Types
#:stopdoc:
BYTE_MIN = -128
BYTE_MAX = 127
CHAR_MIN = 0
CHAR_MAX = 65535
SHORT_MIN = -32768
SHORT_MAX = 32767
INT_MIN = -2147483648
INT_MAX = 2147483647
LONG_MIN = -9223372036854775808
LONG_MAX = 9223372036854775807
FLOAT_MIN = 1.401298464324817E-45
FLOAT_MAX = 3.4028234663852886E38
DOUBLE_MIN = 4.9E-324
DOUBLE_MAX = 1.7976931348623157E308
#:startdoc:
  @map = {
    'boolean' => [[TrueClass, nil],[FalseClass,nil],[NilClass,nil]],
    'byte' => [[Fixnum, [BYTE_MIN,BYTE_MAX]]],
    'char' => [[Fixnum, [CHAR_MIN,CHAR_MAX]]],
    'short' => [[Fixnum, [SHORT_MIN,SHORT_MAX]]],
    'int' => [[Fixnum, [INT_MIN,INT_MAX]]],
    'long' => [[Fixnum, [LONG_MIN,LONG_MAX]]],
    # definitely not right
    #'float' => [[Numeric, [FLOAT_MIN,FLOAT_MAX]]],
    #'double' => [[Numeric, [DOUBLE_MIN,DOUBLE_MAX]]],
    # TODO: need better matching for float/double
    'float' => [[Numeric, nil]],
    'double' => [[Numeric, nil]],

    'java.lang.Boolean' => [[TrueClass, nil],[FalseClass,nil],[NilClass,nil]],
    'java.lang.Byte' => [[Fixnum, [BYTE_MIN,BYTE_MAX]],[NilClass,nil]],
    'java.lang.Character' => [[Fixnum, [CHAR_MIN,CHAR_MAX]],[NilClass,nil]],
    'java.lang.Short' => [[Fixnum, [SHORT_MIN,SHORT_MAX]],[NilClass,nil]],
    'java.lang.Integer' => [[Fixnum, [INT_MIN,INT_MAX]],[NilClass,nil]],
    'java.lang.Long' => [[Fixnum, [LONG_MIN,LONG_MAX]],[NilClass,nil]],
    # definitely not right
    #'java.lang.Float' => [[Numeric, [FLOAT_MIN,FLOAT_MAX]],[NilClass,nil]],
    #'java.lang.Double' => [[Numeric, [DOUBLE_MIN,DOUBLE_MAX]],[NilClass,nil]],
    # TODO: need better matching for float/double
    'java.lang.Float' => [[Numeric, nil],[NilClass,nil]],
    'java.lang.Double' => [[Numeric, nil],[NilClass,nil]],
    'java.lang.Number' => [[Numeric,nil],[NilClass,nil]],

    'java.Math.BigInteger' => [[Integer,nil],[NilClass,nil]],
    'java.Math.BigDecimal' => [[Numeric,nil],[NilClass,nil]],

    'java.lang.String' => [[String,nil],[NilClass,nil]],
    'java.lang.Object' => [[Object,nil]]
  }
class << self
  # type must be a JavaClass
  def type_matches_arg(type,arg)
    return type.assignable_from?(arg.java_class) if arg.respond_to?(:java_class)
    if can_match_type(type.name)      
      return does_type_match(type.name,arg)
    else
      # TODO: deal with subclasses of non-final types in TypeMap
      warn "warning: can't evaluate type #{type.name}"
      return false
    end
  end


  # call-seq:
  #   can_match_type(type_cls_name) -> true or false
  #   
  # this should be called first, otherwise the response
  # of does_type_match is ambiguous
  # TODO: deal with subclasses of non-final types 
  def can_match_type(n)
    @map[n] != nil
  end

  # call-seq:
  #   does_type_match(type_cls_name, value) -> true or false
  #   
  # TODO: deal with subclasses of non-final types 
  def does_type_match(n,v)
    rtypes = @map[n]
    return false unless rtypes
    rtypes.each do |t|
      if v.kind_of?(t[0])
        range = t[1]
        if range 
          return v >= range[0] && v <= range[1]        
        else
          return true 
        end
      end
    end
    false    
  end
end  # self
end #Types

end #Builder
end #Java
end #Cheri
