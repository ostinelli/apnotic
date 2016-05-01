require 'spec_helper'

describe "Sending Push Notifications" do
  let(:port) { 9516 }
  let(:server) { Apnotic::Dummy::Server.new(port: port) }
  let(:connection) do
    Apnotic::Connection.new(
      url:       "https://localhost:#{port}",
      cert_path: apn_file_path
    )
  end
  let(:device_id) { "device-id" }

  before { server.listen }
  after do
    connection.close
    server.stop
  end

  it "sends notifications with the correct parameters" do
    notification       = Apnotic::Notification.new(device_id)
    notification.alert = "test-notification"

    request       = nil
    server.on_req = Proc.new { |req| request = req }

    connection.push(notification)

    expect(request).not_to be_nil
    expect(request.headers[":scheme"]).to eq "https"
    expect(request.headers[":method"]).to eq "POST"
    expect(request.headers[":path"]).to eq "/3/device/#{device_id}"
    expect(request.headers["host"]).to eq "localhost"
    expect(request.headers["apns-id"]).to eq notification.apns_id
    expect(request.body).to eq({ aps: { alert: "test-notification" } }.to_json)
  end

  it "returns a response" do
    notification       = Apnotic::Notification.new(device_id)
    notification.alert = "test-notification"

    server.on_req = Proc.new do |_req|
      NetHttp2::Response.new(
        headers: { ":status" => "200" },
        body:    "response body"
      )
    end

    response = connection.push(notification)

    expect(response).to be_a Apnotic::Response

    expect(response.ok?).to eq true
    expect(response.status).to eq "200"
    expect(response.headers[":status"]).to eq "200"
    expect(response.body).to eq "response body"
  end

  it "returns nil when no response is received" do
    notification       = Apnotic::Notification.new(device_id)
    notification.alert = "test-notification"

    server.on_req = Proc.new { |_req| sleep 2 }

    response = connection.push(notification, timeout: 1)

    expect(response).to be_nil
  end
end
