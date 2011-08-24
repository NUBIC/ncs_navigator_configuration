require 'ncs_navigator/configuration'

class NcsNavigator::Configuration
  class PrimarySamplingUnit < Struct.new(:id)
    ##
    # @return [Array<SamplingUnitArea>] the areas in this PSU.
    def sampling_unit_areas
      @sampling_unit_areas ||= []
    end

    ##
    # @return [Array<SecondarySamplingUnit>] the SSUs in this PSU.
    def secondary_sampling_units
      sampling_unit_areas.collect(&:secondary_sampling_units).flatten
    end

    alias :areas :sampling_unit_areas
    alias :ssus :secondary_sampling_units
  end

  ##
  # NCS Navigator defines the concept of an "area" encompassing one or
  # more SSUs. See {file:sample_configuration.ini} for more information.
  class SamplingUnitArea < Struct.new(:name, :primary_sampling_unit)
    def initialize(*)
      super
      primary_sampling_unit.sampling_unit_areas << self
    end

    ##
    # @return [Array<SecondarySamplingUnit>] the SSUs in this area.
    def secondary_sampling_units
      @secondary_sampling_units ||= []
    end

    alias :psu :primary_sampling_unit
    alias :ssus :secondary_sampling_units
  end

  class SecondarySamplingUnit < Struct.new(:id, :name, :sampling_unit_area)
    def initialize(*)
      super
      sampling_unit_area.secondary_sampling_units << self
    end

    ##
    # @return [PrimarySamplingUnit] the PSU to which this SSU belongs.
    def primary_sampling_unit
      area.psu
    end

    ##
    # @return [TertiarySamplingUnit] any TSUs defined for this SSU.
    def tertiary_sampling_units
      @tertiary_sampling_units ||= []
    end

    alias :psu :primary_sampling_unit
    alias :area :sampling_unit_area
    alias :tsus :tertiary_sampling_units
  end

  class TertiarySamplingUnit < Struct.new(:id, :name, :secondary_sampling_unit)
    def initialize(*)
      super
      secondary_sampling_unit.tertiary_sampling_units << self
    end

    alias :ssu :secondary_sampling_unit
  end
end
