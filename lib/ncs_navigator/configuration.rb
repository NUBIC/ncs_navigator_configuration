require 'inifile'
require 'pathname'
require 'fastercsv'
require 'uri'

module NcsNavigator
  # Additions to the root module are defined here instead of in
  # lib/ncs_navigator.rb to avoid conflicts with other gems. There is
  # no single gem which defines the NcsNavigator module, so no gem
  # should respond when `require`ing 'ncs_navigator'.

  class Configuration
    autoload :VERSION, 'ncs_navigator/configuration/version'

    autoload :PrimarySamplingUnit,   'ncs_navigator/configuration/sampling_units'
    autoload :SecondarySamplingUnit, 'ncs_navigator/configuration/sampling_units'
    autoload :TertiarySamplingUnit,  'ncs_navigator/configuration/sampling_units'
    autoload :SamplingUnitArea,      'ncs_navigator/configuration/sampling_units'

    ######

    APPLICATION_SECTIONS = ['Staff Portal', 'Core', 'PSC']

    class << self
      ##
      # Defines a mapping from the configuration file to an attribute
      # on this class.
      #
      # @param [Symbol] name the name of the attribute.
      # @param [String] section the section of the configuration file
      #   from which it is read.
      # @param [String] key the configuration key within the section
      #   for the attribute.
      # @param [Class] type the type to which the configuration value
      #   should be coerced.
      # @param [Hash] options additional options controlling the
      #   behavior of the attribute.
      # @option options [Boolean] :required (false) is the
      #   configuration property mandatory? If it is, reading the
      #   configuration will fail if it is not provided or is blank.
      # @option options [Object] :default the default value for the
      #   configuration property.
      def configuration_attribute(name, section, key, type, options={})
        configuration_attributes << ConfigurationAttribute.new(name, section, key, type, options)
        attr_accessor name
      end

      ##
      # @private used by instances, but not intended to be public.
      def configuration_attributes
        @configuration_attributes ||= []
      end

      ##
      # @private implementation detail
      class ConfigurationAttribute < Struct.new(:name, :section, :key, :type, :options)
        def extract_and_set(config, hash)
          v = raw_value_from(hash)
          v = coerce(v, config)
          if v.nil? && options[:required]
            fail "Please set a value for [#{section}]: #{key}"
          end
          config.send(:"#{name}=", v)
        end

        def raw_value_from(hash)
          if hash[section]
            hash[section][key]
          end
        end

        def coerce(raw_value, config)
          return options[:default] if raw_value.nil?
          case
          when type == String
            raw_value.to_s
          when type == Pathname
            base = Pathname.new(raw_value.to_s)
            if base.absolute? || !config.ini_filename
              base
            else
              config.ini_filename.dirname + base
            end
          when type == URI
            URI.parse(raw_value.to_s)
          else
            fail "Do not know how to coerce to #{type} for #{name} from [#{section}]: #{key}"
          end
        end
      end
    end

    ##
    # The file from which this configuration was initialized, if any.
    #
    # @return [Pathname]
    attr_reader :ini_filename

    # TODO: it would be nice if the macro below generated method doc
    # for both the reader and the writer.

    ##
    # The SC_ID for the study center using this deployment of NCS
    # Navigator. This value must match an ID in the MDES.
    #
    # @macro [attach] configuration_attribute
    #   Read from the `[$2]` section, key `$3`.
    #   @return [$4]
    configuration_attribute :study_center_id, 'Study Center', 'sc_id', String,
      :required => true

    ##
    # The name for the institutional identity used in this deployment
    # of NCS Navigator. For instance, for the Greater Chicago Study
    # Center, it is "Northwestern NetID". The default is "Username".
    configuration_attribute :study_center_username, 'Study Center', 'username', String,
      :default => 'Username'

    ##
    # The CSV describing the PSU, "sampling areas", SSUs, and (if
    # applicable) TSUs for this center.
    #
    # The format is described in the comments in the
    # {file:sample_configuration.ini sample INI}.
    configuration_attribute :sampling_units_file, 'Study Center', 'sampling_units_file', Pathname,
      :required => true

    ##
    # The image that should appear on the left side of the footer in
    # Staff Portal and Core. This should be a path to a file on the
    # deployed server.
    configuration_attribute :footer_logo_left, 'Study Center', 'footer_logo_left', Pathname

    ##
    # The image that should appear on the right side of the footer in
    # Staff Portal and Core. This should be a path to a file on the
    # deployed server.
    configuration_attribute :footer_logo_right, 'Study Center', 'footer_logo_right', Pathname

    ##
    # The text that should appear in the center of the footer in Staff
    # Portal and Core. This is usually the center's contact
    # information.
    configuration_attribute :footer_text, 'Study Center', 'footer_text', String

    ##
    # The root URI for the Staff Portal deployment in this instance of
    # the suite.
    configuration_attribute :staff_portal_uri, 'Staff Portal', 'uri', URI, :required => true

    ##
    # The root URI for the NCS Navigator Core deployment in this instance of
    # the suite.
    configuration_attribute :core_uri, 'Core', 'uri', URI, :required => true

    ##
    # The root URI for the PSC deployment in this instance of
    # the suite.
    configuration_attribute :psc_uri, 'PSC', 'uri', URI, :required => true

    ##
    # Creates a new Configuration.
    #
    # @param [String, Hash] source the basis for this
    #   configuration. If it's a `String`, it's interpreted as a the
    #   filename for an INI file ({file:sample_configuration.ini
    #   sample}). If it's a `Hash`, it should have two levels. The
    #   first level represents the sections and the second level the
    #   keys and values.
    def initialize(source)
      case source
      when String
        init_from_ini(source)
      else
        init_from_hash(source)
      end
    end

    def init_from_ini(filename)
      if File.readable?(filename)
        @ini_filename = Pathname.new(filename)
        init_from_hash(IniFile.new(filename).to_h)
      else
        raise Error.new("NCS Navigator configuration file #{filename.inspect} does not exist or is not readable.")
      end
    end
    private :init_from_ini

    def init_from_hash(h)
      h = stringify_keys(h)
      self.class.configuration_attributes.each do |attr|
        attr.extract_and_set(self, h)
      end
      @application_sections = APPLICATION_SECTIONS.inject({}) do |s, section|
        s[section] = h[section].dup if h[section]
        s
      end
    end
    private :init_from_hash

    def stringify_keys(h)
      h.dup.tap do |z|
        z.keys.each do |k|
          v = z.delete(k)
          z[k.to_s] =
            case v
            when Hash
              stringify_keys(v)
            else
              v
            end
        end
      end
    end
    private :stringify_keys

    ##
    # @return [Array<SampleUnitArea>] the areas defined in {#sampling_units_file}.
    def sampling_unit_areas
      @sampling_unit_areas ||= read_sampling_unit_areas
    end
    alias :areas :sampling_unit_areas

    def read_sampling_unit_areas
      psus = {}
      areas = {}
      ssus = {}

      unless sampling_units_file.readable?
        raise Error.new("Could not read sampling units CSV #{sampling_units_file}")
      end

      FasterCSV.foreach(sampling_units_file, :headers => true) do |row|
        psu = (psus[row['PSU_ID']] ||= PrimarySamplingUnit.new(row['PSU_ID']))
        area = (areas[row['AREA']] ||= SamplingUnitArea.new(row['AREA'], psu))
        ssu = (ssus[row['SSU_ID']] ||= SecondarySamplingUnit.new(row['SSU_ID'], row['SSU_NAME'], area))
        if row['TSU_ID']
          TertiarySamplingUnit.new(row['TSU_ID'], row['TSU_NAME'], ssu)
        end
      end

      areas.values
    end
    private :read_sampling_unit_areas

    ##
    # @return [Array<SampleUnitArea>] the PSUs defined in {#sampling_units_file}.
    def primary_sampling_units
      @primary_sampling_units ||= sampling_unit_areas.collect(&:primary_sampling_unit).uniq
    end
    alias :psus :primary_sampling_units

    ##
    # @return [Array<SampleUnitArea>] the SSUs defined in {#sampling_units_file}.
    def secondary_sampling_units
      @secondary_sampling_units ||= sampling_unit_areas.collect(&:secondary_sampling_units).flatten
    end
    alias :ssus :secondary_sampling_units

    ##
    # Converts {#footer_text} into equivalent HTML.
    #
    # @return [String]
    def footer_center_html
      return nil unless footer_text
      html = footer_text.split("\n").join("<br>\n")
      if html.respond_to?(:html_safe)
        html.html_safe
      else
        html
      end
    end

    APPLICATION_SECTIONS.each do |section|
      ##
      # Exposes all the values from the [#{section}] section. This
      # allows for flexibility in adding new options, with the downside
      # that they are not automatically coerced or documented.
      #
      # @return [Hash<String, String>]
      define_method section.downcase.gsub(' ', '_').to_sym do
        @application_sections[section] ||= {}
      end
    end

    class Error < StandardError; end
  end
end
