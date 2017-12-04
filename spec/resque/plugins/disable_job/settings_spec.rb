# frozen_string_literal: true

require_relative '../../../spec_helper'

module Resque::Plugins::DisableJob
  describe Settings do
    describe '#initialize' do
      it 'should initialize with name and args' do
        name = 'TestJob'
        args = [765]
        settings = Settings.new(name, args)

        settings.main_set.must_equal Settings::SETTINGS_SET
        settings.name.must_equal name
        settings.args.must_equal args
        settings.all_key.must_equal settings.main_set + ':' + name
        settings.setting_key.must_equal settings.all_key + ':' + settings.digest
        settings.data.must_equal args.to_json
        settings.digest.must_equal Digest::SHA1.hexdigest(settings.data)
      end

      it 'should initialize with name and digest' do
        name = 'TestJob'
        args_data = [765].to_json
        digest = Digest::SHA1.hexdigest(args_data)
        settings = Settings.new(name, args_data, digest)

        settings.main_set.must_equal Settings::SETTINGS_SET
        settings.name.must_equal name
        settings.all_key.must_equal settings.main_set + ':' + name
        settings.setting_key.must_equal settings.all_key + ':' + digest
        settings.data.must_equal args_data
        settings.digest.must_equal digest
      end

      it 'should initialize with just a name' do
        name = 'TestJob'
        settings = Settings.new(name)

        settings.main_set.must_equal Settings::SETTINGS_SET
        settings.name.must_equal name
        settings.all_key.must_equal settings.main_set + ':' + name
      end
    end
  end
end
