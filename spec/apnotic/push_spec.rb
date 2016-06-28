require 'spec_helper'

describe Apnotic::Push do
  let(:http2_request) { double(:http2_request) }
  let(:push) { Apnotic::Push.new(http2_request) }

  before { allow(http2_request).to receive(:on) }

  describe "attributes" do

    subject { push }

    it { is_expected.to have_attributes(http2_request: http2_request) }
  end

  describe "Events subscription & emission" do

    [
      :response
    ].each do |event|
      it "subscribes and emits for event #{event}" do
        calls = []
        push.on(event) { calls << :one }
        push.on(event) { calls << :two }

        push.emit(event, "param")

        expect(calls).to match_array [:one, :two]
      end
    end
  end
end
