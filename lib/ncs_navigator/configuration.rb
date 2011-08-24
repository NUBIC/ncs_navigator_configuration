require 'inifile'

module NcsNavigator
  # Additions to the root module are defined here instead of in
  # lib/ncs_navigator.rb to avoid conflicts with other gems. There is
  # no single gem which defines the NcsNavigator module, so no gem
  # should respond when `require`ing 'ncs_navigator'.

  class Configuration
    autoload :VERSION, 'ncs_navigator/configuration/version'

    ######

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
          v = coerce(v)
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

        def coerce(raw_value)
          return options[:default] if raw_value.nil?
          case
          when type == String
            raw_value.to_s
          else
            fail "Do not know how to coerce to #{type} for #{name} from [#{section}]: #{key}"
          end
        end
      end
    end

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
        init_from_hash(IniFile.new(filename).to_h)
      else
        raise Error.new("NCS Navigator configuration file #{filename.inspect} does not exist or is not readable.")
      end
    end
    private :init_from_ini

    def init_from_hash(h)
      self.class.configuration_attributes.each do |attr|
        attr.extract_and_set(self, stringify_keys(h))
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

    class Error < StandardError; end
  end
end
