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

  before { server.listen }
  after do
    connection.close
    server.stop
  end

  it "calls the APN with the correct parameters" do
    notification       = Apnotic::Notification.new(device_id)
    notification.alert = "test-notification"

    request       = nil
    server.on_req = Proc.new { |req| request = req }

    response = connection.push(notification)

    expect(response).to be_a Apnotic::Response

    expect(request).not_to be_nil
    expect(request.headers[":scheme"]).to eq "https"
    expect(request.headers[":method"]).to eq "POST"
    expect(request.headers[":path"]).to eq "/3/device/#{device_id}"
    expect(request.headers["host"]).to eq "localhost"
    expect(request.headers["apns-id"]).to eq notification.id
    expect(request.body).to eq({ aps: { alert: "test-notification" } }.to_json)
  end

  it "can receive multiple requests simultaneously" do
    notification_1       = Apnotic::Notification.new(device_id)
    notification_1.alert = "test-notification-1"
    notification_2       = Apnotic::Notification.new(device_id)
    notification_2.alert = "test-notification-2"

    requests      = []
    server.on_req = Proc.new { |req| requests << req }

    response_1 = connection.push(notification_1)
    response_2 = connection.push(notification_2)

    expect(response_1).to be_a Apnotic::Response
    expect(response_2).to be_a Apnotic::Response

    request_1, request_2 = requests
    expect(request_1).not_to be_nil
    expect(request_2).not_to be_nil

    expect(request_1.body).to eq({ aps: { alert: "test-notification-1" } }.to_json)
    expect(request_2.body).to eq({ aps: { alert: "test-notification-2" } }.to_json)
  end
end
