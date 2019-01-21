require 'spec_helper'

describe "Sending Async Push Notifications" do
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

  it "sends async notifications with the correct parameters" do
    notification       = Apnotic::Notification.new(device_id)
    notification.alert = "test-notification"

    request       = nil
    server.on_req = Proc.new { |req| request = req }

    push = connection.prepare_push(notification)

    connection.push_async(push)
    connection.join

    expect(request).not_to be_nil
    expect(request.headers[":scheme"]).to eq "https"
    expect(request.headers[":method"]).to eq "POST"
    expect(request.headers[":path"]).to eq "/3/device/#{device_id}"
    expect(request.headers[":authority"]).to eq "localhost:9516"
    expect(request.headers["apns-id"]).to eq notification.apns_id
    expect(request.body).to eq({ aps: { alert: "test-notification" } }.to_json)
  end

  it "sends many async notifications without exceeding stream limit" do
    notification       = Apnotic::Notification.new(device_id)
    notification.alert = "test-notification"

    requests       = []
    server.on_req = Proc.new { |req| requests.push(req) }

    count = 100

    expect do
      count.times do
        push = connection.prepare_push(notification)
        connection.push_async(push)
      end
    end.to_not raise_error

    connection.join

    expect(requests.count).to eq count
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

    push = connection.prepare_push(notification)

    response = nil
    push.on(:response) { |res| response = res }

    connection.push_async(push)
    connection.join

    expect(response).to be_a Apnotic::Response

    expect(response.ok?).to eq true
    expect(response.status).to eq "200"
    expect(response.headers[":status"]).to eq "200"
    expect(response.body).to eq "response body"
  end
end
