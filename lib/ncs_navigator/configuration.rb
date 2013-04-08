require 'inifile'
require 'pathname'
require 'uri'

module NcsNavigator
  # Additions to the root module are defined here instead of in
  # lib/ncs_navigator.rb to avoid conflicts with other gems. There is
  # no single gem which defines the NcsNavigator module, so no gem
  # should respond when `require`ing 'ncs_navigator'.

  ##
  # The location from which the global configuration instance is read
  # if a global instance is not explicitly set.
  DEFAULT_CONFIGURATION_PATH = '/etc/nubic/ncs/navigator.ini'

  ##
  # The global configuration instance. Automatically instantiated on
  # first reference from {.DEFAULT_CONFIGURATION_PATH} if it is not
  # set explicitly.
  #
  # @return [Configuration]
  def self.configuration
    @configuration ||= Configuration.new(DEFAULT_CONFIGURATION_PATH)
  end

  ##
  # Replaces the global configuration with a provided instance.
  # Set to `nil` to reload from {.DEFAULT_CONFIGURATION_PATH}.
  #
  # @param [Configuration,nil] config the new configuration
  # @return [void]
  def self.configuration=(config)
    @configuration = config
  end

  ##
  # The typed access point for the common configuration in the NCS
  # Navigator suite.
  class Configuration
    autoload :VERSION, 'ncs_navigator/configuration/version'

    autoload :PrimarySamplingUnit,   'ncs_navigator/configuration/sampling_units'
    autoload :SecondarySamplingUnit, 'ncs_navigator/configuration/sampling_units'
    autoload :TertiarySamplingUnit,  'ncs_navigator/configuration/sampling_units'
    autoload :SamplingUnitArea,      'ncs_navigator/configuration/sampling_units'

    ######

    APPLICATION_SECTIONS = ['Staff Portal', 'Core', 'PSC', 'Pancakes']

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
      #
      # @return [void]
      def configuration_attribute(name, section, key, type, options={})
        configuration_attributes << ConfigurationAttribute.new(name, section, key, type, options)
        attr_accessor name
      end

      ##
      # Defines an attribute that exposes the raw contents of a
      # section.
      #
      # @param [#to_s] section_name the name of the section in the INI
      #   file.
      # @param [#to_sym] accessor_name the name for the generated accessor.
      #
      # @return [void]
      def section_accessor(section_name, accessor_name)
        define_method accessor_name.to_sym do
          @application_sections[section_name.to_s] ||= {}
        end
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
          when type == Symbol
            raw_value.to_sym
          when type == Fixnum
            raw_value.to_i
          when type == Pathname
            coerce_to_pathname(raw_value, config)
          when type == URI
            URI.parse(raw_value.to_s)
          when type == 'Boolean'
            raw_value.to_s.downcase.strip == 'true' ? true : false
          when type == Array
            coerce_to_string_array(raw_value)
          else
            fail "Do not know how to coerce to #{type} for #{name} from [#{section}]: #{key}"
          end
        end

        def coerce_to_pathname(raw_value, config)
          base = Pathname.new(raw_value.to_s)
          if base.absolute? || !config.ini_filename
            base
          else
            config.ini_filename.dirname + base
          end
        end

        def coerce_to_string_array(raw_value)
          raw_value.split(/\s*,\s*/)
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
    configuration_attribute :study_center_id, 'Study Center', 'sc_id', String

    alias :sc_id :study_center_id

    ##
    # The recruitment strategy for this study center. The acceptable
    # values are those from the code list `recruit_type_cl1` in the
    # MDES.
    configuration_attribute :recruitment_type_id, 'Study Center', 'recruitment_type_id', String

    ##
    # A short, human-readable name or abbreviation for the Study
    # Center.
    configuration_attribute :study_center_short_name, 'Study Center', 'short_name', String,
      :default => 'SC'

    ##
    # The e-mail addresses which will receive uncaught exceptions from
    # any application in the suite.
    configuration_attribute :exception_email_recipients, 'Study Center',
      'exception_email_recipients', Array, :default => []

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
    configuration_attribute :sampling_units_file, 'Study Center', 'sampling_units_file', Pathname

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
    # The address from which mail sent by Staff Portal will appear to come.
    configuration_attribute :staff_portal_mail_from, 'Staff Portal', 'mail_from', String,
      :default => 'ops@navigator.example.edu'

    ##
    # The MDES version for Pancakes.
    configuration_attribute :pancakes_mdes_version, 'Pancakes', 'mdes_version', String

    ##
    # The root URI for the NCS Navigator Core deployment in this instance of
    # the suite.
    configuration_attribute :core_uri, 'Core', 'uri', URI

    ##
    # Machine account for Cases.
    configuration_attribute :core_machine_account_username, 'Core',
      'machine_account_username', String

    configuration_attribute :core_machine_account_password, 'Core',
      'machine_account_password', String

    ##
    # The address from which mail sent by Core will appear to come.
    configuration_attribute :core_mail_from, 'Core', 'mail_from', String,
      :default => 'cases@navigator.example.edu'

    ##
    # When a merge conflict occurs in Cases, send emails to these addresses.
    configuration_attribute :core_conflict_email_recipients, 'Core',
      'conflict_email_recipients', Array, :default => []

    ##
    # The root URI for the PSC deployment in this instance of
    # the suite.
    configuration_attribute :psc_uri, 'PSC', 'uri', URI, :required => true

    ##
    # The hostname of the SMTP server the suite should use to send
    # mail.
    configuration_attribute :smtp_host, 'SMTP', 'host', String, :default => 'localhost'

    ##
    # The port for the SMTP server the suite should use.
    configuration_attribute :smtp_port, 'SMTP', 'port', Fixnum, :default => 25

    ##
    # The the HELO domain for the SMTP server, if any.
    configuration_attribute :smtp_helo_domain, 'SMTP', 'domain', String

    ##
    # The type of authentication needed for the SMTP server, if any.
    configuration_attribute :smtp_authentication_method, 'SMTP', 'authentication', Symbol

    ##
    # The username to use when authenticating to the SMTP server, if
    # authentication is required.
    configuration_attribute :smtp_username, 'SMTP', 'username', String

    ##
    # The password to use when authenticating to the SMTP server, if
    # authentication is required.
    configuration_attribute :smtp_password, 'SMTP', 'password', String

    ##
    # Whether to try to use STARTTLS if the SMTP server supports
    # it. Defaults to false.
    configuration_attribute :smtp_starttls, 'SMTP', 'starttls', 'Boolean', :default => false

    # While the following could be generated metaprogrammatically
    # using APPLICATION_SECTIONS, they are unrolled for the benefit of
    # YARD.

    ##
    # @macro [attach] section_accessor
    # @method $2
    #
    # Exposes all the values from the [$1] section. This allows for
    # flexibility in adding new options. The downside is that they are
    # not automatically coerced or documented.
    #
    # @return [Hash<String, String>] the raw values from the [$1] section
    section_accessor 'Staff Portal', :staff_portal
    section_accessor 'Core', :core
    section_accessor 'PSC', :psc
    section_accessor 'Pancakes', :pancakes

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
        init_from_hash(IniFile.new(filename, :encoding => 'UTF-8').to_h)
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
    # @return [Array<SamplingUnitArea>] the areas defined in {#sampling_units_file}.
    def sampling_unit_areas
      @sampling_unit_areas ||= primary_sampling_units.collect(&:sampling_unit_areas).flatten
    end
    alias :areas :sampling_unit_areas

    def read_primary_sampling_units
      psus = {}
      areas = {}
      ssus = {}

      if sampling_units_file && !sampling_units_file.readable?
        raise Error.new("Could not read sampling units CSV #{sampling_units_file}")
      end

      strip_ws = lambda { |h| h.nil? ? nil : h.strip }

      return [] unless sampling_units_file
      faster_csv_class.foreach(sampling_units_file,
        :headers => true, :encoding => 'utf-8',
        :converters => [strip_ws], :header_converters => [strip_ws]
      ) do |row|
        psu = (psus[row['PSU_ID']] ||= PrimarySamplingUnit.new(row['PSU_ID']))
        if row['AREA']
          area = (areas[row['AREA']] ||= SamplingUnitArea.new(row['AREA'], psu))
          if row['SSU_ID']
            area = (areas[row['AREA']] ||= SamplingUnitArea.new(row['AREA'], psu))
            ssu = (ssus[row['SSU_ID']] ||= SecondarySamplingUnit.new(row['SSU_ID'], row['SSU_NAME'], area))
            if row['TSU_ID']
              TertiarySamplingUnit.new(row['TSU_ID'], row['TSU_NAME'], ssu)
            end
          end
        end
      end
      psus.values
    end
    private :read_primary_sampling_units

    ##
    # @return [Array<PrimarySamplingUnit>] the PSUs defined in {#sampling_units_file}.
    def primary_sampling_units
      @primary_sampling_units ||= read_primary_sampling_units
    end
    alias :psus :primary_sampling_units

    ##
    # @return [Array<SecondarySamplingUnit>] the SSUs defined in {#sampling_units_file}.
    def secondary_sampling_units
      @secondary_sampling_units ||= primary_sampling_units.collect(&:secondary_sampling_units).flatten
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

    ##
    # Provides a configuration hash suitable for passing to
    # `ActionMailer::Base.smtp_settings`.
    #
    # @return [Hash<Symbol, Object>]
    def action_mailer_smtp_settings
      Hash[
        {
          :address => smtp_host,
          :port => smtp_port,
          :domain => smtp_helo_domain,
          :user_name => smtp_username,
          :password => smtp_password,
          :authentication => smtp_authentication_method,
          :enable_starttls_auto => smtp_starttls
        }.select { |k, v| v }
      ]
    end

    ##
    # @return [Class] the main class for FasterCSV-like behavior. On
    #   1.9+, this is the built-in CSV lib.
    def faster_csv_class
      @faster_csv_class ||=
        if RUBY_VERSION < '1.9'
          require 'fastercsv'
          FasterCSV
        else
          require 'csv'
          CSV
        end
    end
    private :faster_csv_class

    class Error < StandardError; end
  end
end
