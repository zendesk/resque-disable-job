require_relative '../../spec_helper'
describe Resque::Disable::Job do
  it 'has a version number' do
    expect(Resque::Disable::Job::VERSION).wont_be_nil
  end
end
