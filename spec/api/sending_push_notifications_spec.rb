require 'spec_helper'

describe "Sending Push Notifications" do
  let(:port) { 9516 }
  let(:server) { Apnotic::Dummy::Server.new(port: port) }
  let(:connection) do
    Apnotic::Connection.new(
      uri:       "https://localhost:#{port}",
      cert_path: apn_file_path
    )
  end
  let(:device_id) { "device-id" }
  let(:notification) { Apnotic::Notification.new(device_id) }

  before { server.listen }
  after do
    connection.close
    server.stop
  end

  it "calls the APN with the correct parameters" do
    notification.alert = "test-notification"

    request       = nil
    server.on_req = Proc.new { |req| request = req }

    connection.push(notification)

    wait_for { request.nil? == false }
    expect(request).not_to be_nil

    expect(request.headers[":scheme"]).to eq "https"
    expect(request.headers[":method"]).to eq "POST"
    expect(request.headers[":path"]).to eq "/3/device/#{device_id}"
    expect(request.headers["host"]).to eq "localhost"
    expect(request.headers["apns-id"]).to eq notification.id
    expect(request.body).to eq({ aps: { alert: "test-notification" } }.to_json)
  end
end
