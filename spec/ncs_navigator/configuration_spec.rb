# -*- coding: utf-8 -*-
require File.expand_path('../../spec_helper', __FILE__)

describe NcsNavigator do
  # Load the test INI into memory so it can be put into FakeFS
  let(:everything_file) { File.expand_path('../everything.ini', __FILE__) }
  let!(:everything_contents) {
    opts = ({ :external_encoding => 'UTF-8' } if RUBY_VERSION > '1.9')
    File.read(everything_file, opts)
  }

  after do
    NcsNavigator.configuration = nil
  end

  describe '.configuration' do
    include FakeFS::SpecHelpers

    before do
      pending "FakeFS issue #93" if RUBY_VERSION > '1.9'

      File.open('/etc/nubic/ncs/navigator.ini', 'w') do |f|
        f.puts '[Study Center]'
        f.puts 'sc_id = 18'
        f.puts 'recruitment_type_id = 2'
        f.puts 'sampling_units_file = foo.csv'
        f.puts '[Staff Portal]'
        f.puts 'uri = https://foo.example.com/sp'
        f.puts '[Core]'
        f.puts 'uri = https://foo.example.com/core'
        f.puts '[PSC]'
        f.puts 'uri = https://foo.example.com/psc'
      end

      File.open(everything_file, RUBY_VERSION > '1.9' ? 'w:UTF-8' : 'w') { |f|
        f.write everything_contents
      }
    end

    it 'is read from /etc/nubic/ncs/navigator.ini' do
      NcsNavigator.configuration.study_center_id.should == '18'
    end

    it 'can be set explicitly' do
      NcsNavigator.configuration = NcsNavigator::Configuration.new(everything_file)
      NcsNavigator.configuration.study_center_id.should == '20000000'
    end
  end
end

module NcsNavigator
  describe Configuration do
    let(:everything) { Configuration.new(everything_file) }
    let(:everything_file) { File.expand_path('../everything.ini', __FILE__) }

    # input_hash should be kept minimally valid
    # ToDo: update minimally valid input_hash with required fields only.
    let(:input_hash) {
      {
        'Study Center' => {
          'sc_id' => '23000000',
          'recruitment_type_id' => '3',
          'sampling_units_file' => 'foo.csv'
        },
        'Staff Portal' => {
          'uri' => 'https://sp.example.edu/'
        },
        'PSC' => {
          'uri' => 'https://psc.example.edu/'
        }
      }
    }
    let(:from_hash) { Configuration.new(input_hash) }
    let(:minimum_valid_hash) {
      {
        'Staff Portal' => {
          'uri' => 'https://sp.example.edu/'
        },
        'PSC' => {
          'uri' => 'https://psc.example.edu/'
        }
      }
    }
    let(:from_minimum_valid_hash) { Configuration.new(minimum_valid_hash) }


    describe '#initialize' do
      describe 'from an INI file' do
        it 'works when the file exists' do
          everything.study_center_id.should == '20000000'
        end

        it 'gives a useful error when the file does not exist' do
          lambda { Configuration.new('/foo/bar.ini') }.should(
            raise_error('NCS Navigator configuration file "/foo/bar.ini" does not exist or is not readable.'))
        end
      end

      it 'accepts a hash' do
        from_hash.study_center_id.should == '23000000'
      end

      it 'accepts a hash with symbol keys' do
        input_hash[:'Study Center'] = input_hash.delete 'Study Center'
        input_hash[:'Study Center'][:sc_id] = input_hash[:'Study Center'].delete 'sc_id'
        from_hash.study_center_id.should == '23000000'
      end
    end

    describe '#pancakes_mdes_version' do
      it 'is not mandatory' do
        lambda { from_minimum_valid_hash }.
          should_not raise_error
      end

      it "returns Pancakes' MDES version" do
        input_hash['Pancakes'] = { 'mdes_version' => '3.2' }

        from_hash.pancakes_mdes_version.should == '3.2'
      end
    end

    describe '#study_center_id' do
      it 'reflects the configured value' do
        from_hash.study_center_id.should == '23000000'
      end

      it 'is always a string' do
        input_hash['Study Center']['sc_id'] = 234
        from_hash.study_center_id.should == '234'
      end

      it 'is not mandatory' do
        lambda { from_minimum_valid_hash }.
          should_not raise_error
      end
    end

    describe '#recruitment_type_id' do
      it 'reflects the configured value' do
        everything.recruitment_type_id.should == '1'
      end

      it 'is always a string' do
        input_hash['Study Center']['recruitment_type_id'] = 234
        from_hash.recruitment_type_id.should == '234'
      end

      it 'is not mandatory' do
        lambda { from_minimum_valid_hash }.
          should_not raise_error
      end
    end

    describe '#study_center_short_name' do
      it 'defaults to SC' do
        from_hash.study_center_short_name.should == 'SC'
      end

      it 'reflects the configured value' do
        input_hash['Study Center']['short_name'] = 'GCSC'
        from_hash.study_center_short_name.should == 'GCSC'
      end
    end

    describe '#study_center_username' do
      it 'reflects the configured value' do
        everything.study_center_username.should == 'NetID'
      end

      it 'defaults to "Username"' do
        from_hash.study_center_username.should == 'Username'
      end
    end

    describe '#exception_email_recipients' do
      it 'reflects the configured value' do
        everything.exception_email_recipients.should == [
          'Fred MacMurray <fred@pacificlife.net>',
          'Barbara Stanwyck <b@aol.com>'
        ]
      end

      it 'is optional' do
        from_hash.exception_email_recipients.should be_empty
      end
    end

    describe '#sampling_units_file' do
      it 'reflects the configured value, absolutized, when read from an INI' do
        everything.sampling_units_file.to_s.should ==
          File.expand_path('../every_su.csv', everything_file)
      end

      it 'is just the value when read from a Hash' do
        from_hash.sampling_units_file.to_s.should == 'foo.csv'
      end

      it 'is a Pathname' do
        everything.sampling_units_file.should be_a(Pathname)
      end

      it 'is not required' do
        lambda { from_minimum_valid_hash }.
          should_not raise_error
      end
    end

    describe '#sampling_unit_areas' do
      describe 'when no sampling_unit_file' do
        it 'is an empty array' do
          from_minimum_valid_hash.sampling_unit_areas.should be_empty
        end
      end

      describe 'when sampling_units_file is present' do
        subject { everything.sampling_unit_areas }

        it 'has the right number' do
          subject.size.should == 2
        end

        describe 'an individual area' do
          let(:area) { subject.sort_by { |a| a.name }.last }

          it 'has a name' do
            area.name.should == 'Uptown'
          end

          it 'has the right number of SSUs' do
            area.secondary_sampling_units.size.should == 2
          end

          it 'has the right PSU' do
            area.primary_sampling_unit.id.should == '204'
          end
        end
      end
    end

    describe '#primary_sampling_units' do
      describe 'when no sampling_unit_file' do
        it 'is an empty array' do
          from_minimum_valid_hash.primary_sampling_units.should be_empty
        end
      end

      describe 'when sampling_units_file is present' do
        subject { everything.primary_sampling_units }

        it 'has the right number' do
          subject.size.should == 1
        end

        describe 'an individual PSU' do
          let(:psu) { subject.first }

          it 'has the correct ID' do
            psu.id.should == '204'
          end

          it 'has the correct SSUs' do
            psu.secondary_sampling_units.collect(&:id).should == %w(One Two Three)
          end
        end

        context 'without Areas and SSUs' do
          before do
            input_hash['Study Center']['sampling_units_file'] =
              File.expand_path('../no_ssus.csv', __FILE__)
          end

          subject { from_hash.primary_sampling_units }

          it 'has the right number' do
            subject.size.should == 1
          end

          describe 'an individual PSU' do
            let(:psu) { subject.first }

            it 'has the correct ID' do
              psu.id.should == '204'
            end

            it 'has no Areas' do
              psu.should have(0).sampling_unit_areas
            end

            it 'has no SSUs' do
              psu.should have(0).secondary_sampling_units
            end
          end
        end
      end
    end

    describe '#secondary_sampling_units' do
      describe 'when no sampling_unit_file' do
        it 'is an empty array' do
          from_minimum_valid_hash.secondary_sampling_units.should be_empty
        end
      end

      describe 'when sampling_units_file is present' do
        subject { everything.secondary_sampling_units }

        it 'has the right number' do
          subject.size.should == 3
        end

        describe 'an individual SSU' do
          let(:ssu) { subject.sort_by { |ssu| ssu.id }.first }

          it 'has the correct ID' do
            ssu.id.should == 'One'
          end

          it 'has the correct name' do
            ssu.name.should == 'West Side'
          end

          it 'has the correct area' do
            ssu.area.name.should == 'Uptown'
          end

          it 'has the same area as another SSU in the same area' do
            ssu.area.should eql(subject.find { |ssu| ssu.name == 'West Side' }.area)
          end

          it 'has the correct PSU' do
            ssu.primary_sampling_unit.id.should == '204'
          end

          it 'has the correct TSUs' do
            ssu.should have(1).tertiary_sampling_units
          end

          describe 'a TSU' do
            let(:tsu) { ssu.tertiary_sampling_units.first }

            it 'has a name' do
              tsu.name.should == 'Center'
            end

            it 'has an ID' do
              tsu.id.should == '1-1'
            end
          end
        end

        context 'without TSUs' do
          before do
            input_hash['Study Center']['sampling_units_file'] =
              File.expand_path('../no_tsus.csv', __FILE__)
          end

          subject { from_hash.secondary_sampling_units }

          it 'has the right number' do
            subject.size.should == 3
          end

          describe 'an individual SSU' do
            let(:ssu) { subject.first }

            it 'has no TSUs' do
              ssu.should have(0).tertiary_sampling_units
            end
          end
        end

        context 'with extra whitespace' do
          before do
            input_hash['Study Center']['sampling_units_file'] =
              File.expand_path('../spaces.csv', __FILE__)
          end

          subject { from_hash.secondary_sampling_units }

          it 'has the right number' do
            subject.size.should == 3
          end

          describe 'an individual SSU' do
            let(:ssu) { subject.detect { |s| s.id == 'One' } }

            it 'has the name' do
              ssu.name.should == 'West Side'
            end
          end
        end
      end
    end

    describe 'footer' do
      describe '#footer_logo_left' do
        subject { everything.footer_logo_left }

        it 'is the correct value' do
          subject.to_s.should == "/etc/nubic/ncs/logos/sc_20000000L.png"
        end
      end

      describe '#footer_logo_right' do
        subject { everything.footer_logo_right }

        it 'is the correct value' do
          subject.to_s.should == "/etc/nubic/ncs/logos/sc_20000000R.png"
        end
      end

      describe '#footer_text' do
        subject { everything.footer_text }

        it 'is the configured value' do
          subject.should =~ /Greater Chicago Study Center/
        end

        it 'preserves newlines' do
          subject.split(/\n/).size.should == 5
        end

        if RUBY_VERSION > '1.9'
          it 'can contain non-ASCII characters' do
            subject.should =~ /’/
          end
        end
      end

      describe '#footer_center_html' do
        subject { everything.footer_center_html }

        it 'converts newlines to BRs' do
          subject.split("\n")[3].should == "420 East Superior, 10th Floor<br>"
        end

        it 'is nil if no footer text' do
          from_hash.footer_center_html.should be_nil
        end
      end
    end

    describe 'Staff Portal parts' do
      describe '#staff_portal_uri' do
        subject { everything.staff_portal_uri }

        it 'is the configured value' do
          subject.to_s.should == 'https://staffportal.greaterchicagoncs.org/'
        end

        it 'can expose the hostname, e.g.' do
          subject.host.should == 'staffportal.greaterchicagoncs.org'
        end
      end

      describe '#staff_portal' do
        it 'exposes all the raw values in the Staff Portal section' do
          everything.staff_portal['mail_from'].should == "staffportal@greaterchicagoncs.org"
        end
      end

      describe '#staff_portal_mail_from' do
        it 'is the configured value' do
          everything.staff_portal_mail_from.should == 'staffportal@greaterchicagoncs.org'
        end

        it 'has a reasonable default' do
          from_hash.staff_portal_mail_from.should == 'ops@navigator.example.edu'
        end
      end
    end

    describe 'Core parts' do
      describe '#core_uri' do
        subject { everything.core_uri }

        it 'is the configured value' do
          subject.to_s.should == 'https://ncsnavigator.greaterchicagoncs.org/'
        end

        it 'can expose the hostname, e.g.' do
          subject.host.should == 'ncsnavigator.greaterchicagoncs.org'
        end
      end

      describe '#core_machine_account_username' do
        it 'is the configured value' do
          everything.core_machine_account_username.should == 'ncs_navigator_cases_foobar'
        end
      end

      describe '#core_machine_account_password' do
        it 'is the configured value' do
          everything.core_machine_account_password.should == 'foobar'
        end
      end

      describe '#core_conflict_email_recipients' do
        it 'is the configured value' do
          everything.core_conflict_email_recipients.should == [
            'Foo Bar <foobar@example.edu>',
            'Baz Quux <bazquux@example.edu>'
          ]
        end
      end

      describe '#core' do
        it 'exposes all the raw values in the Staff Portal section' do
          everything.core['uri'].should == "https://ncsnavigator.greaterchicagoncs.org/"
        end
      end

      describe '#core_mail_from' do
        it 'is the configured value' do
          everything.core_mail_from.should == 'ncs-navigator@greaterchicagoncs.org'
        end

        it 'has a reasonable default' do
          from_hash.core_mail_from.should == 'cases@navigator.example.edu'
        end
      end
    end

    describe 'PSC parts' do
      describe '#psc_uri' do
        subject { everything.psc_uri }

        it 'is the configured value' do
          subject.to_s.should == 'https://calendar.greaterchicagoncs.org/'
        end

        it 'can expose the hostname, e.g.' do
          subject.host.should == 'calendar.greaterchicagoncs.org'
        end
      end

      describe '#psc' do
        it 'exposes all the raw values in the PSC section' do
          everything.psc['uri'].should == "https://calendar.greaterchicagoncs.org/"
        end
      end
    end

    describe 'SMTP' do
      describe '#smtp_host' do
        it 'defaults to "localhost"' do
          from_hash.smtp_host.should == 'localhost'
        end

        it 'takes the configured value' do
          everything.smtp_host.should == 'smtp.greaterchicagoncs.org'
        end
      end

      describe '#smtp_port' do
        it 'defaults to 25' do
          from_hash.smtp_port.should == 25
        end

        it 'takes the configured value' do
          everything.smtp_port.should == 2025
        end
      end

      describe '#smtp_helo_domain' do
        it 'defaults to nil' do
          from_hash.smtp_helo_domain.should be_nil
        end

        it 'takes the configured value' do
          everything.smtp_helo_domain.should == 'greaterchicagoncs.org'
        end
      end

      describe '#smtp_authentication_method' do
        it 'defaults to nil' do
          from_hash.smtp_authentication_method.should be_nil
        end

        it 'takes the configured value (as a symbol)' do
          everything.smtp_authentication_method.should == :plain
        end
      end

      describe '#smtp_username' do
        it 'defaults to nil' do
          from_hash.smtp_username.should be_nil
        end

        it 'takes the configured value' do
          everything.smtp_username.should == 'mailman'
        end
      end

      describe '#smtp_password' do
        it 'defaults to nil' do
          from_hash.smtp_password.should be_nil
        end

        it 'takes the configured value' do
          everything.smtp_password.should == 'tiger'
        end
      end

      describe '#starttls' do
        it 'defaults to false' do
          from_hash.smtp_starttls.should == false
        end

        it 'takes the configured value' do
          everything.smtp_starttls.should == true
        end
      end

      describe '#action_mailer_smtp_settings' do
        context 'with everything' do
          subject { everything.action_mailer_smtp_settings }

          it 'has :address' do
            subject[:address].should == 'smtp.greaterchicagoncs.org'
          end

          it 'has :port' do
            subject[:port].should == 2025
          end

          it 'has :domain' do
            subject[:domain].should == 'greaterchicagoncs.org'
          end

          it 'has :authentication' do
            subject[:authentication].should == :plain
          end

          it 'has :user_name' do
            subject[:user_name].should == 'mailman'
          end

          it 'has :password' do
            subject[:password].should == 'tiger'
          end

          it 'has :enable_starttls_auto' do
            subject[:enable_starttls_auto].should == true
          end
        end

        context 'with defaults' do
          subject { from_hash.action_mailer_smtp_settings }

          it 'has :address' do
            subject[:address].should == 'localhost'
          end

          it 'has :port' do
            subject[:port].should == 25
          end

          [:domain, :authentication, :user_name, :password, :enable_starttls_auto].each do |nil_key|
            it "does not have #{nil_key}" do
              subject.should_not have_key(nil_key)
            end
          end
        end
      end
    end
  end
end
