require 'spec_helper'

describe Apnotic::ConnectionPool do
  let(:options) do
    {
      cert_path: apn_file_path
    }
  end

  let(:pool_options) do
    {
      # Using 6 since default value is 5 in both 2.x & 3.x
      size: 6
    }
  end

  shared_examples_for "connection pool" do |connection_method|

    context "without block" do

      subject { described_class.public_send(connection_method, options, pool_options) }

      it "requires a block" do
        expect { subject.with {} }.to raise_error(LocalJumpError, "a block is needed when initializing an Apnotic::ConnectionPool")
      end
    end

    context "with block" do
      let(:connection) { double }

      subject do
        described_class.public_send(connection_method, options, pool_options) do |connection|
          connection.on(:error) {}
        end
      end

      it "returns a connection pool" do
        expect(subject).to be_kind_of(::ConnectionPool)
        expect(subject.size).to eq(6)
      end

      it "passes the connection into a block" do
        expect(Apnotic::Connection).to receive(connection_method) \
          .with(options).and_return(connection)

        expect(connection).to receive(:on).with(:error)
        subject.with {}
      end
    end
  end

  describe ".new" do
    it_behaves_like "connection pool", :new
  end

  describe ".development" do
    it_behaves_like "connection pool", :development
  end
end
