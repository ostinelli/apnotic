require 'spec_helper'

describe "Triggering timeouts" do
  let(:port) { 9516 }
  let(:server) { Apnotic::Dummy::Server.new(port: port) }
  let(:connection) do
    Apnotic::Connection.new(
      uri:       "https://localhost:#{port}",
      cert_path: apn_file_path,
      timeout: 1
    )
  end
  let(:device_id) { "device-id" }

  before { server.listen }
  after do
    connection.close
    server.stop
  end

  it "triggers a timeout when no response is received" do
    notification       = Apnotic::Notification.new(device_id)
    notification.alert = "test-notification"

    server.on_req = Proc.new { |_req| sleep 2 }

    response = nil
    connection.push(notification) { |res| response = res.nil? }

    wait_for { response.nil? == false }
    expect(response).to eq true
  end
end
