require File.expand_path('../../spec_helper', __FILE__)

describe NcsNavigator do
end

module NcsNavigator
  describe Configuration do
    let(:everything) { Configuration.new(everything_file) }
    let(:everything_file) { File.expand_path('../everything.ini', __FILE__) }

    # input_hash should be kept minimally valid
    let(:input_hash) {
      {
        'Study Center' => {
          'sc_id' => '23000000',
          'sampling_units_file' => 'foo.csv'
        }
      }
    }
    let(:from_hash) { Configuration.new(input_hash) }

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

    describe '#study_center_id' do
      it 'reflects the configured value' do
        from_hash.study_center_id.should == '23000000'
      end

      it 'is always a string' do
        input_hash['Study Center']['sc_id'] = 234
        from_hash.study_center_id.should == '234'
      end

      it 'is mandatory' do
        input_hash['Study Center'].delete 'sc_id'
        lambda { from_hash }.
          should raise_error("Please set a value for [Study Center]: sc_id")
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

      it 'is required' do
        input_hash['Study Center'].delete 'sampling_units_file'
        lambda { from_hash }.
          should raise_error "Please set a value for [Study Center]: sampling_units_file"
      end
    end

    describe '#sampling_unit_areas' do
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

    describe '#primary_sampling_units' do
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
    end

    describe '#secondary_sampling_units' do
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
    end
  end
end
