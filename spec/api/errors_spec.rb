require 'spec_helper'

describe "Errors" do
  let(:port) { 9516 }
  let(:server) { Apnotic::Dummy::Server.new(port: port) }
  let(:connection) do
    Apnotic::Connection.new(
      uri:       "https://localhost:#{port}",
      cert_path: apn_file_path
    )
  end
  let(:device_id) { "device-id" }

  before do
    allow(Apnotic::Response).to receive(:new).and_raise "Something bad happened"
    server.listen
  end

  after do
    connection.close
    server.stop
  end

  it "does not eat errors" do
    notification       = Apnotic::Notification.new(device_id)
    notification.alert = "test-notification"

    expect { connection.push(notification) }.to raise_error "Something bad happened"
  end
end
