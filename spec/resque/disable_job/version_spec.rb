# frozen_string_literal: true

require_relative '../../spec_helper'
describe Resque::DisableJob do
  it 'has a version number' do
    expect(Resque::DisableJob::VERSION).wont_be_nil
  end
end
