module PhysicalQuantifier

  ##
  # Easy access to numeric model attributes as PhysicalQuantities. Takes a
  # unit string and a variable number of attribute names.
  #
  def physical_quantity(*attrs)
    unit = parse_units(attrs.shift)

    attrs.each do |attr|
      attr = attr.to_s

      # Define raw value getter.
      raw_getter_name = "raw_" + attr

      # If getter already defined, create an alias to it.
      if method_defined? attr
        alias_method raw_getter_name, attr

      # If no getter defined, create one.
      else 
        define_method(raw_getter_name) do

          # We might be inheriting from an ActiveRecord-like class in which
          # +attributes+ is defined. If not, fall back to something reliable.
          begin
            attributes[attr]
          rescue NoMethodError
            instance_variable_get '@' + attr
          end
        end
      end

      # Define fancy getter.
      define_method(attr) do
        PhysicalQuantity.new(eval(raw_getter_name), unit)
      end
    end
  end
  
  ##
  # Build a units hash (e.g., {:m => 1, :s => -2}) from a string (e.g., 'm/s^2').
  #
  def parse_units(string)
    (num,den) = string.split('/')
    parse_unit_part(num).merge(parse_unit_part(den, true))
  end
  
  ##
  # Parse a unit string without a '/' (numerator or denominator).
  #
  private; def parse_unit_part(string, denominator = false)
    return {} if string.nil?
    units = {}
    matches = string.scan(/(\w+)(\^\d)?/)
    matches.each do |m|
      exp = (m[1] ? m[1][1..-1].to_i : 1) * (denominator ? -1 : 1)
      units[m[0].intern] = exp
    end
    units
  end; public
  
  
  ##
  # Exception classes.
  #
  class Error                         < RuntimeError; end
  class Error::BaseUnit               < Error; end
  class Error::BaseUnit::Duplicate    < Error::BaseUnit; end
  class Error::BaseUnit::NotDefined   < Error::BaseUnit; end
  class Error::Unit                   < Error; end
  class Error::Unit::Duplicate         < Error::Unit; end
  class Error::Unit::NotDefined       < Error::Unit; end
  class Error::Transformation         < Error; end
  class Error::Transformation::Sum    < Error::Transformation; end


#  ##
#  # A Measurement System represents a collection of BaseUnits.
#  #
#  class MeasurementSystem
#    include Singleton
#    attr_reader :symbol, :name, :units
#  end
#  
#  class ImperialSystem < MeasurementSystem
#    @symbol = 'i'
#    @name = 'imperial'
#    @full_name = 'Imperial System'
#    @unit_classes = [Meter, Kilogram, Second]
#    
#    # Convert classes to BaseUnit instances.
#    @units = @unit_classes.map{ |c| c.instance }
#  end
  
  
  
  
  ##
  # The BaseUnit class represents the single fundamental measure of some
  # physical quality. Any other unit that measures the same quality must define
  # its relationship to the base unit for that quality.
  #
  class BaseUnit
  
    ##
    # Keep a list of instantiated BaseUnits.
    #
    @@registry = {}
    
    ##
    # Keep a list of defined measurable quantities and their base units.
    #
    @@qualities = {}
    
    attr_reader :symbol, :name, :quality
  
    ##
    # Initialize and register a new BaseUnit object.
    #
    def initialize(symbol, name, quality)
      if @@qualities.has_key?(quality)
        raise(PhysicalQuantifier::Error::BaseUnit::Duplicate,
          "Base unit already defined for quality '#{quality.to_s}'")
      else
        @symbol = symbol
        @name = name
        @quality = quality
        @@registry[symbol] = self
        @@qualities[quality] = self
      end
    end
    
    ##
    # Get the BaseUnit object for a given unit (takes a symbol).
    #
    def self.get(symbol)
      if self.exists?(symbol)
        @@registry[symbol]
      else
        raise(PhysicalQuantifier::Error::BaseUnit::NotDefined,
          "BaseUnit '#{symbol}' not defined")
      end
    end
    
    ##
    # Is a given symbol already used for a BaseUnit?
    #
    def self.exists?(symbol)
      @@registry.has_key?(symbol)
    end

    ##
    # De-normalize BaseUnit: convert from BaseUnit to Unit.
    #
    def denormalize(unit)
      unit = Unit.get(unit) if unit.is_a?(Symbol)
      
      # If the target is already a BaseUnit, return null Transformation.
      if unit.is_a?(BaseUnit)
        Transformation.new(self, self, [lambda{|x|x}])
      else
        unit.denormalize
      end
    end

    ##
    # Normalize a BaseUnit (no change).
    #
    def normalize
      Transformation.new(self, self, [lambda{|x|x}])
    end
  end



  ##
  # The Unit class represents a unit which has a defined relationship
  # to an existing BaseUnit.
  #
  class Unit
  
    ##
    # Initialize the registry for storing available simple units.
    #
    @@registry = {}

    attr_reader :symbol, :name, :base

    ##
    # Get the BaseUnit object for a given unit (takes a symbol).
    #
    def self.get(symbol)
      if @@registry.has_key?(symbol)
        @@registry[symbol]
      else
        begin
          return BaseUnit.get(symbol)
        rescue PhysicalQuantifier::Error::BaseUnit::NotDefined
          raise(PhysicalQuantifier::Error::Unit::NotDefined,
            "Unit '#{symbol}' not defined")
        end
      end
    end

    ##
    # Initialize the unit with a unit symbol (as a Ruby symbol object), a name
    # (string), a related BaseUnit (symbol only), and either a numeric factor
    # relating the Unit to its BaseUnit, or two lambda objects converting from
    # BaseUnit to Unit, and vice versa (each lambda object should accept one
    # parameter).
    #
    def initialize(symbol, name, base, from_and_to_base)

      # If a Unit with this symbol exists...
      if @@registry.has_key?(symbol)
        raise(PhysicalQuantifier::Error,
          "Unit already defined for symbol '#{symbol.to_s}'")
      
      # If a BaseUnit with this symbol exists...
      else
        unless BaseUnit.exists?(base)
          raise PhysicalQuantifier::Error::BaseUnit::NotDefined
        end 
        @symbol = symbol
        @name = name
        @base = Unit.get(base)
        if from_and_to_base.kind_of?(Numeric)
          @from_base = eval "[lambda{ |x| x / #{from_and_to_base.to_f} }]"
          @to_base   = eval "[lambda{ |x| x * #{from_and_to_base.to_f} }]"
        else
          unless from_and_to_base.is_a?(Array)
            raise(PhysicalQuantifier::Error,
              "You must pass an array of two lambda objects to Unit#new")
          end
          @from_base = [from_and_to_base[0]]
          @to_base   = [from_and_to_base[1]]
        end
        @@registry[@symbol] = self
      end
    end
    
    ##
    # Get the quality this unit measures.
    #
    def quality
      base.quality
    end

    ##
    # Normalize unit: convert from Unit to BaseUnit. Returns a Transformation.
    #
    def normalize
      Transformation.new(self, base, @to_base)
    end
    
    ##
    # Denormalize unit.
    #
    def denormalize
      Transformation.new(base, self, @from_base)
    end

    ##
    # Convert the Unit to another. Returns a Transformation.
    #
    def convert_to(unit)
      unit = Unit.get(unit) if unit.is_a?(Symbol)
      self.normalize + unit.denormalize
    end
  end

  

  ##
  # A transformation that acts on a PhysicalQuantity object. Transformations
  # handle conversion from one Unit to another. They do NOT handle operations
  # (e.g., +, *) between PhysicalQuantities. Transformations may be added
  # to each other and their order is preserved.
  #
  class Transformation
    include Comparable
    
    ##
    # Define the equality operator for easy comparison of Transformations.
    # Since the == operator won't do what we want for lambda objects, we
    # define equality as mapping [-1, 0, 1, 2, 3.5] to the same values. This
    # isn't perfect but it should work in most practical situations. 
    #
    def ==(b)
      tests = [-1, 0, 1, 2, 3.5]
      [  from,   to] + tests.map{ |i|   apply_to_quantity(i).to_f.to_s } ==
      [b.from, b.to] + tests.map{ |i| b.apply_to_quantity(i).to_f.to_s }
    end
    
    ##
    # Get the null transformation.
    #
    def self.null
      self.new(nil, nil, lambda{ |x| x })
    end
    
    ##
    # Takes two BaseUnit descendant classes (from, to) and a lambda object or
    # an array of lambda objects.
    #
    def initialize(from, to, ops)
      @from = from.is_a?(Symbol) ? Unit.get(from) : from
      @to   =   to.is_a?(Symbol) ? Unit.get(to)   : to
      raise(Error::Transformation, "Put your lambda in an array") if block_given?
      @ops  = ops
    end
    
    attr_reader :from, :to, :ops

#    ##
#    # Apply to a PhysicalQuantity.
#    #
#    def apply_to(physical_quantity)
#      
#      # Transform unit.
#      if physical_quantity.powers.has_key?(from)
#        physical_quantity.powers[from] = to
#      end 
#      
#      # Transform quantity.
#      q = physical_quantity.quantity
#      physical_quantity.quantity = self.apply_to_quantity(q)
#    end
    
    ##
    # Add two Transformations. This returns a single Transformation which is
    # equivalent to its two summands. In order for two Transformations to be
    # sum-able the 'to' unit of the first must be the same as the 'from' unit
    # of the second.
    #
    def +(other)
      unless other.is_a?(Transformation)
        raise(Error::Transformation::Sum,
          "Incompatible summand types (each must be a Transformation)")
      end
      if self.to != other.from
        raise(Error::Transformation::Sum,
          "Incompatible summand types (units don't match)")
      end
      Transformation.new(from, other.to, @ops + other.ops)
    end
    
    ##
    # Transform a simple numeric quantity. This method is defined mainly so
    # the comparison (==) operator works. It works but is not intended for
    # general use.
    #
    def apply_to_quantity(q)
      ops.inject(q){ |tot,op| op.call(tot) }
    end
  end
  


  ##
  # A PhysicalQuantity represents a number with a unit attached. The unit is a
  # "composite" made up of Unit objects raised to different powers.
  #
  class PhysicalQuantity
    include Comparable
    
    ##
    # Define the equality operator.
    #
    def ==(b)
      # Convert quantities to strings to avoid weird problems with floats.
      [quantity.to_s, powers] == [b.quantity.to_s, b.powers]
    end

    ##
    # Define the comparison operator.
    #
    def <=>(b)
      if powers == b.powers
        quantity <=> b.quantity
      else
        raise PhysicalQuantifier::Error,
          "Only physical quantities of like units can be compared"
      end
    end


    ##
    # Initialize a new PhysicalQuantity. Takes a number and a powers hash. As a
    # shorthand, a single unit may be given, whose power is assumed to be one.
    # You may also pass a preferred_units hash but this is usually only
    # necessary within this class and if you use it your powers_hash must
    # contain ONLY BaseUnits (it must be "normalized").
    #
    def initialize(quantity, powers_hash, preferred_units = nil)
      
      # Store powers hash (convert symbol to hash if necessary).
      @powers = {}
      @powers.default = 0
      powers_hash = {powers_hash => 1} if powers_hash.is_a?(Symbol)
      powers_hash.each do |u,p|
        u = Unit.get(u) if u.is_a?(Symbol)
        @powers[u] = p
      end
      
      # Initialize preferred_units hash to pre-normalized state.
      preferred_units = {preferred_units => 1} if preferred_units.is_a?(Symbol)
      @preferred_units = preferred_units || preferred_units_from(powers_hash)
      
      # Store quantity as float.
      @quantity = quantity.to_f
      
      # Normalize.
      normalize
    end
    

    attr_accessor :quantity, :powers
    
    ##
    # Get the PhysicalQuantity's powers hash with zero-power units removed.
    #
    def powers
      @powers.reject{ |u,p| p == 0 }
    end
    
    ##
    # Get a string representing the quantity and units.
    #
    def to_s(format = nil)

      # Go back to preferred units before printing.
      denormalize
      
      q = @quantity # use the de-normalized quantity

      # Split powers into numerator and denominator.
      num = powers.reject{ |u,p| p < 0 }.to_a
      den = powers.reject{ |u,p| p > 0 }.to_a
      den.map!{ |i| [i[0], i[1].abs] } # make all denominator powers positive

      # Convert num and den into strings.
      num = num.map{ |i| i[0].symbol.to_s + (i[1] > 1 ? "^" + i[1].to_s : "") }.join
      den = den.map{ |i| i[0].symbol.to_s + (i[1] > 1 ? "^" + i[1].to_s : "") }.join
      num = "1" if num.size == 0
      den = "/" + den if den.size > 0

      # Round the quantity to an integer if decimal portion is insignificant.
      q = q.to_i if q == q.to_i 

      # Build and format the string.
      string = q.to_s + " " + num + den
      string.gsub!(/\^(\d+)/, '<sup>\1</sup>') if format == :html
      
      # Return to normalized state.
      normalize

      # Return string.
      string
    end
    
    ##
    # Define addition operator.
    #
    def +(other)
      unless powers == other.powers
        raise PhysicalQuantifier::Error,
          "Can only add PhysicalQuantities with like units"
      end
      PhysicalQuantity.new(quantity + other.quantity, powers, @preferred_units)
    end

    ##
    # Define subtraction operator.
    #
    def -(other)
      unless powers == other.powers
        raise PhysicalQuantifier::Error,
          "Can only subtract PhysicalQuantities with like units"
      end
      PhysicalQuantity.new(quantity - other.quantity, powers, @preferred_units)
    end

    ##
    # Define multiplication operator.
    #
    def *(other)
      q = quantity * other.quantity
      new_powers = powers
      new_powers.default = 0
      other.powers.each{ |u,p| new_powers[u] += p }
      PhysicalQuantity.new(q, new_powers, @preferred_units)
    end
    
    ##
    # Define division operator.
    #
    def /(other)
      self * other.inverse
    end
    
    ##
    # Apply a Transformation. Returns a new PhysicalQuantity.
    #
    def transform(transformation)
      if transformation.from == self.from
        transform_quantity(transformation)
        transform_units(transformation)
      # TODO: else raise exception
      end
    end
    
    ##
    # Get the PhysicalQuantity's inverse.
    #
    def inverse
      inverse_powers = {}
      powers.each{ |u,p| inverse_powers[u] = -p }
      PhysicalQuantity.new(1.0/@quantity, inverse_powers)
    end
    
    ##
    # Convert a PhysicalQuantity to different units.
    #
    def convert_to(units)
      units = {units => 1} if units.is_a?(Symbol)
      prefs = {}
      units.each do |u,p|
        u = Unit.get(u) if u.is_a?(Symbol)
        prefs[u.quality] = u
      end
      @preferred_units = prefs
    end
    
    
    private # -----------------------------------------------------------------
    
    ##
    # Is the current object normalized?
    #
    def normalized?
      @preferred_units.values - powers.keys == []
    end
    
    ##
    # Get a preferred_units-style hash (quality => unit) from a powers-style
    # hash (unit => power).
    #
    def preferred_units_from(powers)
      powers = {powers => 1} if powers.is_a?(Symbol)
      preferred_units = {}
      powers.each do |u,p|
        u = Unit.get(u) if u.is_a?(Symbol)
        preferred_units[u.quality] = u
      end
      preferred_units      
    end
    
    ##
    # Convert all Units in powers hash from BaseUnits to preferred units (the
    # units that were used to initialize the object). You may also provide a
    # new preferred units hash to denormalize to.
    #
    def denormalize(to_units = nil)
      x_alize(false, to_units)
    end
    
    ##
    # Convert all Units in powers hash to BaseUnits. This method should only
    # be called on new object initialization.
    #
    def normalize
      x_alize(true)
    end

    ##
    # Normalize/denormalize core functionality. Don't call this directly.
    #
    def x_alize(norm = true, preferred = nil)
      
      # Set up defaults.
      preferred = @preferred_units if preferred.nil?
      new_powers = {}
      new_powers.default = 0
      
      # Convert each unit.
      powers.each do |u,p|
        u = Unit.get(u) if u.is_a?(Symbol)
        if norm
          t = u.normalize
        else
          t = u.denormalize(preferred[u.quality])
        end
        new_powers[t.to] += p

        # Quantity must be transformed more than once if unit is raised to a
        # power greater than 1.
        p.times { transform_quantity(t) unless t.to == t.from }
      end
      @powers = new_powers
    end

    ##
    # Apply the numeric part of a Transformation to self.
    #
    def transform_quantity(transformation)
      @quantity = transformation.apply_to_quantity(@quantity)
    end
    
    ##
    # Apply the units part of a Transformation to self.
    #
    def transform_units(transformation)
      if powers.has_key?(transformation.from)
        @powers[transformation.from] = transformation.to
      end 
    end
  end


  ##
  # BaseUnits.
  #
  BaseUnit.new :m,   'meter',    :length
  BaseUnit.new :kg,  'kilogram', :mass
  BaseUnit.new :s,   'second',   :time
  BaseUnit.new :A,   'ampere',   :electric_current
  BaseUnit.new :K,   'kelvin',   :temperature
  BaseUnit.new :mol, 'mole',     :amount_of_substance
  BaseUnit.new :cd,  'candela',  :luminous_intensity

  ##
  # Length.
  #
  Unit.new :km, 'kilometer',  :m, 1000
  Unit.new :dm, 'decimeter',  :m, 0.1
  Unit.new :cm, 'centimeter', :m, 0.01
  Unit.new :mm, 'millimeter', :m, 1e-3
  Unit.new :um, 'micrometer', :m, 1e-6
  Unit.new :nm, 'nanometer',  :m, 1e-9
  Unit.new :pm, 'picometer',  :m, 1e-12

  Unit.new :in, 'inch',       :m, 0.0254
  Unit.new :ft, 'foot',       :m, 0.3048
  Unit.new :yd, 'yard',       :m, 0.9144
  Unit.new :mi, 'mile',       :m, 1609.344

  ##
  # Mass.
  #
  Unit.new  :g, 'gram',      :kg, 1e-3
  Unit.new :dg, 'decigram',  :kg, 1e-4
  Unit.new :cg, 'centigram', :kg, 1e-5
  Unit.new :mg, 'milligram', :kg, 1e-6

  Unit.new :lb, 'pound',     :kg, 0.45359237
  Unit.new :ou, 'ounce',     :kg, 0.02835

  ##
  # Temperature.
  #
  Unit.new :fah, 'degree fahrenheit', :K,
    [lambda{|x| (x * 9.0/5) - 459.67}, lambda{|x| (x + 459.67) * 5.0/9}]
  Unit.new :cel, 'degree celcius',    :K,
    [lambda{|x| x - 273.15}, lambda{|x| x + 273.15}]

end

