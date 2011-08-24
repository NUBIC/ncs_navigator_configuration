require File.expand_path('../../spec_helper', __FILE__)

describe NcsNavigator do
end

module NcsNavigator
  describe Configuration do
    let(:everything) { Configuration.new(File.expand_path('../everything.ini', __FILE__)) }

    # input_hash should be kept minimally valid
    let(:input_hash) {
      {
        'Study Center' => {
          'sc_id' => '23000000'
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
        input_hash.delete 'Study Center'
        input_hash[:'Study Center'] = { :sc_id => '345' }
        from_hash.study_center_id.should == '345'
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

    describe '#sampling_unit_areas' do
    end

    describe '#primary_sampling_units' do
    end

    describe '#secondary_sampling_units' do
    end

    describe '#tertiary_sampling_units' do
    end

    
  end
end
