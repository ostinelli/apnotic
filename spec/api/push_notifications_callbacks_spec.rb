require 'spec_helper'

describe "Push notification callbacks" do
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

  it "returns a response" do
    notification       = Apnotic::Notification.new(device_id)
    notification.alert = "test-notification"

    server.on_req = Proc.new do |_req|
      res                    = Apnotic::Dummy::Response.new
      res.headers[":status"] = "200"
      res.body               = "response body"
      res
    end

    response = connection.push(notification)

    expect(response).not_to be_nil

    expect(response.ok?).to eq true
    expect(response.status).to eq "200"
    expect(response.headers[":status"]).to eq "200"
    expect(response.body).to eq "response body"
  end

  it "returns multiple responses sequentially" do
    notification_1       = Apnotic::Notification.new(device_id)
    notification_1.alert = "test-notification-1"
    notification_2       = Apnotic::Notification.new(device_id)
    notification_2.alert = "test-notification-2"

    server.on_req = Proc.new do |req|
      res                    = Apnotic::Dummy::Response.new
      res.headers[":status"] = "200"
      res.body               = "response body for #{req.body}"
      res
    end

    responses = []
    responses << connection.push(notification_1)
    responses << connection.push(notification_2)

    expect(responses.length).to eq 2

    response_1, response_2 = responses

    expect(response_1.body).to eq "response body for {\"aps\":{\"alert\":\"test-notification-1\"}}"
    expect(response_2.body).to eq "response body for {\"aps\":{\"alert\":\"test-notification-2\"}}"
  end

  it "returns multiple responses concurrently" do
    notification_1       = Apnotic::Notification.new(device_id)
    notification_1.alert = "test-notification-1"
    notification_2       = Apnotic::Notification.new(device_id)
    notification_2.alert = "test-notification-2"

    server.on_req = Proc.new do |req|
      res                    = Apnotic::Dummy::Response.new
      res.headers[":status"] = "200"
      res.body               = "response body for #{req.body}"
      res
    end

    response_1 = nil
    thread     = Thread.new { response_1 = connection.push(notification_1) }
    response_2 = connection.push(notification_2)

    thread.join

    expect(response_1).to_not be_nil
    expect(response_2).to_not be_nil

    expect(response_1.body).to eq "response body for {\"aps\":{\"alert\":\"test-notification-1\"}}"
    expect(response_2.body).to eq "response body for {\"aps\":{\"alert\":\"test-notification-2\"}}"
  end
end
