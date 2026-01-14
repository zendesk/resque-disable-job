# frozen_string_literal: true

require_relative '../../spec_helper'
describe Resque::DisableJob do
  it 'has a version number' do
    refute_nil(Resque::DisableJob::VERSION)
  end
end
