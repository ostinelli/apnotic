require 'spec_helper'

describe Apnotic::InstanceCache do
  let(:seconds) { 60 }
  let(:now) { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
  let(:instance_cache) do
    Apnotic::InstanceCache.new(Time, :now, seconds)
  end

  describe "instance cache" do
    subject { instance_cache }

    it "has the same token in the same period" do
      original = subject.call
      valid_time = now + seconds - 1
      allow(Process).to receive(:clock_gettime).and_return(valid_time)
      expect(original).to eq subject.call
    end

    it "should change after ttl expires" do
      original = subject.call
      expired_time = now + seconds
      allow(Process).to receive(:clock_gettime).and_return(expired_time)
      expect(original).not_to eq subject.call
    end
  end
end
