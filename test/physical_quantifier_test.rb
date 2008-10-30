require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), '../lib')
#RAILS_ROOT = '.' unless defined?(RAILS_ROOT)
require 'physical_quantifier'

class PhysicalQuantifierTest < Test::Unit::TestCase
  
  include PhysicalQuantifier
  
  ##
  # Transformation tests
  #
  def test_transformation_equality
    t1 = Transformation.new(:mm, :m, [lambda{|x| x*2}])
    t2 = Transformation.new(:mm, :m, [lambda{|x| x*2}])
    assert_equal t1, t2
    
    t1 = Transformation.new(:mm, :m, [lambda{|x| 0}])
    t2 = Transformation.new(:mm, :m, [lambda{|x| 0}])
    assert_equal t1, t2
    
    t1 = Transformation.new(:mm, :m, [lambda{|x| x*3.5}])
    t2 = Transformation.new(:mm, :m, [lambda{|x| x*3.5}])
    assert_equal t1, t2
    
    t1 = Transformation.new(:mm, :m, [lambda{|x| x*2}, lambda{|x| x/2}])
    t2 = Transformation.new(:mm, :m, [lambda{|x| x*2}, lambda{|x| x/2}])
    assert_equal t1, t2
  end
  
  def test_transformation_addition
    t1 = Transformation.new(:mm, :m,  [lambda{|x| x / 1000.0}])
    t2 = Transformation.new(:m,  :ft, [lambda{|x| x * 0.3048}])
    t3 = Transformation.new(:mm, :ft, [lambda{|x| x * 0.0003048}])
    assert_equal t3, t1 + t2
  end
  

  ##
  # BaseUnit tests
  #
  def test_base_unit_access
    assert m = BaseUnit.get(:m), "Should be able to call BaseUnit#get"
    assert m.is_a?(BaseUnit), "BaseUnit#get(:m) should return the Meter object"
    assert_equal 'meter', m.name, "Meter object's name should be 'meter'"
  end

  def test_base_unit_normalization
    m = BaseUnit.get(:m)
    t = Transformation.new(m, m, [lambda{|x|x}])
    assert_equal t, m.normalize
  end
  
  
  ##
  # Unit tests
  #
  def test_unit_normalization_and_denormalization
    m  = Unit.get(:m)
    mm = Unit.get(:mm)
    t = Transformation.new(mm, m, [lambda{|x| x / 1000.0}])
    assert_equal t, mm.normalize
    t = Transformation.new(m, mm, [lambda{|x| x * 1000.0}])
    assert_equal t, m.denormalize(:mm)
  end

  def test_unit_conversion
    mm = Unit.get(:mm)
    ft = Unit.get(:ft)
    t = Transformation.new(mm, ft, [lambda{ |x| x / 1000.0 / 0.3048 }])
    assert_equal t, mm.convert_to(ft)
  end


  ##
  # PhysicalQuantity tests
  #
  def test_physical_quantity_initialization
    p = PhysicalQuantity.new(634, :m => 1, :s => -1)
    assert p.is_a?(PhysicalQuantity),
      "Should be able to instantiate valid PhysicalQuantity"
    assert_equal 634, p.quantity,
      "PhysicalQuantity should keep quantity set by initializer"
#    begin
#      PhysicalQuantity.new(634, :m => 1, :mm => 1, :s => -1)
#      assert false, "Specifying more than one unit per quality should raise an error"
#    rescue PhysicalQuantifier::Error => e
#      assert e, "Specifying more than one unit per quality should raise an error"
#    end
  end
  
  def test_physical_quantity_comparison
    a = PhysicalQuantity.new(4321, :mm)
    b = PhysicalQuantity.new(4322, :mm)
    c = PhysicalQuantity.new(  50, :m)
    d = PhysicalQuantity.new(  50, :kg)
    e = PhysicalQuantity.new(   1, :m)
    f = PhysicalQuantity.new(   1, :yd)
    assert a < b, "4321mm should be less than 4322mm"
    assert b < c, "4322mm should be less than 50m"
    assert f < e, "A yard should be less than a meter"
    assert_equal PhysicalQuantity.new(1, :yd), f

    c = PhysicalQuantity.new(60, :cel)
    f = PhysicalQuantity.new(140, :fah)
    k = PhysicalQuantity.new(333.15, :K)
    assert_equal k, c
    assert_equal k, f

    begin
      a < d
    rescue PhysicalQuantifier::Error => e
      assert e, "Attempt to compare un-like PhysicalQuantities should raise exception"
    end    
  end
  
  def test_physical_quantity_addition_and_subtraction
    a = PhysicalQuantity.new(8, :m)
    b = PhysicalQuantity.new(2.2, :m)
    assert_equal PhysicalQuantity.new(10.2, :m), a + b 
    assert_equal PhysicalQuantity.new(5.8, :m), a - b 
    begin
      a + PhysicalQuantity.new(4, :kg)
    rescue PhysicalQuantifier::Error => e
      assert e, "Attempt to add un-like PhysicalQuantities should raise exception"
    end    
  end

  def test_normalization_with_high_powers
    a = PhysicalQuantity.new(  4,  :m => 3)
    b = PhysicalQuantity.new(4e6, :cm => 3)
    assert_equal a, b
    a = PhysicalQuantity.new(   12,  :m => 4)
    b = PhysicalQuantity.new(12e12, :mm => 4)
    assert_equal a, b
  end
  
  def test_physical_quantity_inverse
    a = PhysicalQuantity.new(8, :m => 1, :s => -1)
    b = PhysicalQuantity.new(1.0/8.0, :m => -1, :s => 1)
    assert_equal b, a.inverse
  end

  def test_physical_quantity_multiplication
    a = PhysicalQuantity.new(8, :m)
    b = PhysicalQuantity.new(2, :kg)
    c = PhysicalQuantity.new(16, :m => 1, :kg => 1)
    assert_equal c, a * b 
  end

  def test_physical_quantity_division
    a = PhysicalQuantity.new(32, :m => 1, :s => -1)
    b = PhysicalQuantity.new( 8, :s => 1)
    assert_equal PhysicalQuantity.new(4, :m => 1, :s => -2), a / b
  end
  
  def test_physical_quantity_unit_disappearance
    a = PhysicalQuantity.new(2, :m => 1, :s => -1)
    b = PhysicalQuantity.new(4, :s => 1)
    assert_equal PhysicalQuantity.new(8, :m => 1), a * b
  end
  
  def test_physical_quantity_to_s
    a = PhysicalQuantity.new(2, :m => 1, :s => -1)
    assert_equal "2 m/s", a.to_s
    a = PhysicalQuantity.new(4.8, :m => 2, :s => -1)
    assert_equal "4.8 m^2/s", a.to_s
    assert_equal "4.8 m<sup>2</sup>/s", a.to_s(:html) 
  end
  
  def test_preservation_of_preferred_units
    a = PhysicalQuantity.new(2, :mm => 1, :s => -1)
    assert_equal "2 mm/s", a.to_s
    b = PhysicalQuantity.new(48, :mm => 1, :s => -1)
    assert_equal "50 mm/s", (a + b).to_s
    assert_equal "96 mm^2/s^2", (a * b).to_s
  end
  
  def test_physical_quantity_conversion
    c = PhysicalQuantity.new(60, :cel)
    assert_equal '60 cel', c.to_s
    c.convert_to(:K)
    assert_equal '333.15 K', c.to_s
  end
  
  def test_unit_string_parsing
    units = {:m => 1}
    assert_equal units, parse_units('m')
    units = {:m => 1, :kg => 1, :s => -2}
    assert_equal units, parse_units('m kg / s^2')
    assert_equal units, parse_units('m^1kg^1/s^2')
  end
  

  ##
  # Model integration tests
  #
  
  # Class with existing basic getters overwritten by fancy ones.
  class SteelBeam
    attr_accessor :depth, :weight
    extend PhysicalQuantifier
    getters_return_physical_quantities
    physical_quantity 'mm', :depth
    physical_quantity 'kg/m', :weight
  end
  
  # Make sure fancy getter is "live" (responds to changes in raw attribute).
  def test_getter_is_live
    s = SteelBeam.new
    s.depth = 814
    assert_equal PhysicalQuantity.new(814,  :mm), s.depth
    s.depth = 512
    assert_equal PhysicalQuantity.new(512,  :mm), s.depth
  end
  
  def test_fancy_getters_with_aliasing
    s = SteelBeam.new
    s.depth = 814
    s.weight = 57.3
    assert_equal PhysicalQuantity.new(814,  :mm), s.depth
    assert_equal PhysicalQuantity.new(57.3, :kg => 1, :m => -1), s.weight 
    assert_equal 814,  s.raw_depth
    assert_equal 57.3, s.raw_weight
  end

  # Class with existing basic getters that should NOT be overwritten.
  class SteelSheet
    attr_accessor :depth, :weight
    extend PhysicalQuantifier
    physical_quantity 'mm', :depth
    physical_quantity 'kg/m', :weight
  end
  
  def test_fancy_getters_without_aliasing
    s = SteelSheet.new
    s.depth = 769
    assert_equal 769,  s.depth
    assert_equal PhysicalQuantity.new(769,  :mm), s.depth_qty
  end


#  ##
#  # MeasurementSystem tests
#  #

#  def test_measurement_system_creation
#    assert MeasurementSystem.new('i'), "Should be able to instantiate valid MeasurementSystem"
#    begin
#      b = MeasurementSystem.new('xxx')
#    rescue PhysicalQuantifier::Error => e
#      assert e, "Attempt to instantiate invalid MeasurementSystem should raise exception"
#    end
#    assert b.nil?, "Invalid MeasurementSystem should not be instantiated"
#    assert MeasurementSystem.new('m').units.include?(BaseUnit.new('kg'))
#  end
#  
#  def test_base_unit_attributes
#    assert ms = MeasurementSystem.new('i'), "Should be able to instantiate MeasurementSystem"
#    assert_equal 'Imperial', ms.name, "Imperial MeasurementSystem name should be 'Imperial'"
#  end

end
