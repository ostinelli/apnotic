require 'spec_helper'

describe Apnotic::Stream do

  describe ".new" do
    let(:h2_stream) do
      s = double(:h2_stream)
      allow(s).to receive(:on)
      s
    end
    let(:stream) { Apnotic::Stream.new(h2_stream: h2_stream) }

    subject { stream }

    it { is_expected.to have_attributes(h2_stream: h2_stream) }
  end
end
