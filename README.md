NCS Navigator Common Configuration
==================================

This gem provides common configuration services to the various
applications that make up NCS Navigator. It's not generally useful
outside of that suite.

Use
---

{NcsNavigator::Configuration} defines the common configuration
attributes for applications in the NCS Navigator suite. It also
provides helpers (e.g.,
{NcsNavigator::Configuration#action_mailer_smtp_settings} for applying
the configuration to some utility libraries.

{NcsNavigator.configuration} provides a global access point for an
instance of `NcsNavigator::Configuration`. It can be explicitly set,
but more commonly it is initialized from a configuration file named
`/etc/nubic/ncs/navigator.ini` (see next section) on first access. If
the INI file is changed, you'll need to set
`NcsNavigator.configuration` to `nil` to have the changes reflected in
the global instance.

Configuration
-------------

An instance of {NcsNavigator::Configuration} may be initialized from
an INI file or by passing a Hash to its constructor.  The INI file
should match {file:sample_configuration.ini} available alongside this
file. The Hash should have two levels, the top level matching the INI
file's sections and the second level the keys.

In addition to the typed configuration properties available on
`NcsNavigator::Configuration`, there are also three
application-specific accessors:
{NcsNavigator::Configuration#staff_portal #staff_portal},
{NcsNavigator::Configuration#core #core}, and
{NcsNavigator::Configuration#psc #psc}. These provide untyped direct
access to the configuration properties in the respective sections of
the INI file, allowing applications to define their own additional
configuration properties without modifying this library.
