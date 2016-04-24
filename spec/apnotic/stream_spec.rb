require 'spec_helper'

describe Apnotic::Stream do

  describe "#sent_at" do
    let(:stream) { Apnotic::Stream.new }
    let(:current_time) { Time.utc(2016, 4, 24, 12) }

    before { allow(Time).to receive_message_chain(:now, :utc) { current_time } }

    it "initializes the value to the current time" do
      expect(stream.sent_at).to eq current_time
    end
  end

  describe "#trigger_callback" do
    let(:headers) { double(:headers) }
    let(:data) { double(:data) }
    let(:stream) do
      s         = Apnotic::Stream.new(&block)
      s.headers = headers
      s.data    = data
      s
    end

    def trigger_callback
      stream.trigger_callback
    end

    context "when block has been passed" do
      let(:block) { Proc.new { |_res| nil } }

      it "calls the block with a response" do
        expect(block).to receive(:call) do |res|
          expect(res).to be_a Apnotic::Response
          expect(res.headers).to eq headers
          expect(res.body).to eq data
        end

        trigger_callback
      end
    end

    context "when block has not been passed" do
      let(:block) { nil }

      it "does not call a block" do
        expect { trigger_callback }.to_not raise_error
      end
    end
  end

  describe "#trigger_timeout" do
    let(:stream) { Apnotic::Stream.new(&block) }

    def trigger_timeout
      stream.trigger_timeout
    end

    context "when block has been passed" do
      let(:block) { Proc.new { |_res| nil } }

      it "calls the block with nil" do
        expect(block).to receive(:call).with(nil)

        trigger_timeout
      end
    end

    context "when block has not been passed" do
      let(:block) { nil }

      it "does not call a block" do
        expect { trigger_timeout }.to_not raise_error
      end
    end
  end
end
