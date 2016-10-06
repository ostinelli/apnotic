[![Build Status](https://travis-ci.org/ostinelli/apnotic.svg?branch=master)](https://travis-ci.org/ostinelli/apnotic)
[![Code Climate](https://codeclimate.com/github/ostinelli/apnotic/badges/gpa.svg)](https://codeclimate.com/github/ostinelli/apnotic)
[![Gem Version](https://badge.fury.io/rb/apnotic.svg)](https://badge.fury.io/rb/apnotic)

# Apnotic

Apnotic is a gem for sending Apple Push Notifications using the [HTTP-2 specifics](https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/ApplePushService.html#//apple_ref/doc/uid/TP40008194-CH100-SW9).


## Why "Yet Another APN" gem?
If you have used the previous Apple Push Notification specifications you may have noticed that it was hard to know whether a Push Notification was successful or not. It was a common problem that has been reported multiple times. In addition, you had to run a separate Feedback service to retrieve the list of the device tokens that were no longer valid, and ensure to purge them from your systems.

All of this is solved by using the HTTP-2 APN specifications. Every Push Notification you make returns a response stating if the Push was successful or, if not, which problems were encountered. This includes the case when invalid device tokens are used, hence making it unnecessary to have a separate Feedback service.

## Installation
Just install the gem:

```
$ gem install apnotic
```

Or add it to your Gemfile:

```ruby
gem 'apnotic'
```

## Usage

### Standalone

#### Sync pushes
Sync pushes are blocking calls that will wait for an APNs response before proceeding.

```ruby
require 'apnotic'

# create a persistent connection
connection = Apnotic::Connection.new(cert_path: "apns_certificate.pem", cert_pass: "pass")

# create a notification for a specific device token
token = "6c267f26b173cd9595ae2f6702b1ab560371a60e7c8a9e27419bd0fa4a42e58f"

notification       = Apnotic::Notification.new(token)
notification.alert = "Notification from Apnotic!"

# send (this is a blocking call)
response = connection.push(notification)

# read the response
response.ok?      # => true
response.status   # => '200'
response.headers  # => {":status"=>"200", "apns-id"=>"6f2cd350-bfad-4af0-a8bc-0d501e9e1799"}
response.body     # => ""

# close the connection
connection.close
```

#### Async pushes
If you are sending out a considerable amount of push notifications, you may consider using async pushes to send out multiple requests in non-blocking calls. This allows to take full advantage of HTTP/2 streams.

```ruby
require 'apnotic'

# create a persistent connection
connection = Apnotic::Connection.new(cert_path: "apns_certificate.pem", cert_pass: "pass")

# create a notification for a specific device token
token = "6c267f26b173cd9595ae2f6702b1ab560371a60e7c8a9e27419bd0fa4a42e58f"

notification       = Apnotic::Notification.new(token)
notification.alert = "Notification from Apnotic!"

# prepare push
push = connection.prepare_push(notification)
push.on(:response) do |response|
  # read the response
  response.ok?      # => true
  response.status   # => '200'
  response.headers  # => {":status"=>"200", "apns-id"=>"6f2cd350-bfad-4af0-a8bc-0d501e9e1799"}
  response.body     # => ""
end

# send
connection.push_async(push)

# wait for all requests to be completed
connection.join

# close the connection
connection.close
```


### With Sidekiq / Rescue / ...
> In case that errors are encountered, Apnotic will repair the underlying connection but will not retry the requests that have failed. For this reason, it is recommended to use a queue engine that will retry unsuccessful pushes.

A practical usage of a Sidekiq / Rescue worker probably has to:

 * Use a pool of persistent connections.
 * Send a push notification.
 * Remove a device with an invalid token.
 * Raise errors when requests timeout, so that the queue engine can retry those.

An example of a Sidekiq worker with such features follows. This presumes a Rails environment, and a model `Device`.

```ruby
require 'apnotic'

class MyWorker
  include Sidekiq::Worker

  sidekiq_options queue: :push_notifications

  APNOTIC_POOL = Apnotic::ConnectionPool.new({
    cert_path: Rails.root.join("config", "certs", "apns_certificate.pem"),
    cert_pass: "mypass"
  }, size: 5)

  def perform(token)
    APNOTIC_POOL.with do |connection|
      notification       = Apnotic::Notification.new(token)
      notification.alert = "Hello from Apnotic!"

      response = connection.push(notification)
      raise "Timeout sending a push notification" unless response

      if response.status == '410' ||
        (response.status == '400' && response.body['reason'] == 'BadDeviceToken')
        Device.find_by(token: token).destroy
      end
    end
  end
end
```

> The official [APNs Provider API documentation](https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/APNsProviderAPI.html) explains how to interpret the responses given by the APNS.

You may also consider using async pushes instead in a Sidekiq / Rescue worker.

#### With Sidekiq and Multiple Certificates
In some situations you may need to deal with multiple certifications or store a certificate in your database.
You can pass in the certificate directly as a PEM or DER when creating your connection pool.

In the example below we setup a connection pool per topic and manage them in a hash.
The certificate is stored in a database (encrypted) and then retrieved based on its topic.

In this situation your worker will need a token AND a topic.

```ruby
  class MyWorker
    include Sidekiq::Worker

    def self.apnotic_pool(topic = "default")
      @apnotic_pool ||= {}
      @apnotic_pool[topic] ||= Apnotic::ConnectionPool.new(
        { 
          cert_pass: ENV["CERTIFICATE_PASSWORD"],
          cert: ( Certificate.find_by_topic(topic).try(:to_pem) ||
          File.read(Rails.root.join("config", "certs", "apns_certificate.pem"))
        }, size: 5)
    end

    def perform(token, topic)
      MyWorker.apnotic_pool(topic).with do |connection|
        notification       = Apnotic::Notification.new(token)
        notification.alert = "Hello from Apnotic!"

        response = connection.push(notification)
        raise "Timeout sending a push notification" unless response

        if response.status == '410' ||
          (response.status == '400' && response.body['reason'] == 'BadDeviceToken')
          Device.find_by(token: token).destroy
        end
      end
    end
  end
```

## Objects

### `Apnotic::Connection`
To create a new persistent connection:

```ruby
Apnotic::Connection.new(options)
```

| Option | Description
|-----|-----
| :cert_path | Requires `cert_path` or `certificate`. The path to a valid APNS push certificate in .pem or .p12 format, or any object that responds to `:read`.
| :certificate |  Requires `cert_path` or `certificate`. A PEM or DER certificate. This option is useful if you are not storing your certificate on the filesystem. 
| :cert_pass | Optional. The certificate's password.
| :url | Optional. Defaults to https://api.push.apple.com:443.
| :connect_timeout | Optional. Expressed in seconds, defaults to 30.

It is also possible to create a connection that points to the Apple Development servers by calling instead:

```ruby
Apnotic::Connection.development(options)
```

> The concepts of PRODUCTION and DEVELOPMENT are different from what they used to be in previous specifications. Anything built directly from XCode and loaded on your phone will have the app generate DEVELOPMENT tokens, while everything else (TestFlight, Apple Store, HockeyApp, ...) will be considered as PRODUCTION environment.

#### Methods

 * **url** → **`URL`**

 Returns the URL of the APNS endpoint.

 * **cert_path** → **`string`**

 Returns the path to the certificate

##### Blocking calls

 * **push(notification, timeout: 30)** → **`Apnotic::Response` or `nil`**

 Sends a notification. Returns `nil` in case a timeout occurs.

##### Non-blocking calls

 * **prepare_push(notification)** → **`Apnotic::Push`**

 Prepares an async push.

 ```ruby
 push = client.prepare_push(notification)
 ```

 * **push_async(push)**

  Sends the push asynchronously.


### `Apnotic::ConnectionPool`
For your convenience, a wrapper around the [Connection Pool](https://github.com/mperham/connection_pool) gem is here for you. To create a new connection pool:

```ruby
Apnotic::ConnectionPool.new(connection_options, connection_pool_options)
```

For example:

```ruby
APNOTIC_POOL = Apnotic::ConnectionPool.new({
  cert_path: "apns_certificate.pem"
}, size: 5)
```

### `Apnotic::Notification`
To create a notification for a specific device token:

```ruby
notification = Apnotic::Notification.new(token)
```

#### Methods
These are all Accessor attributes.

| Method | Documentation
|-----|-----
| `alert` | Refer to the official Apple documentation of [The Notification Payload](https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/TheNotificationPayload.html) for details.
| `badge` | "
| `sound` | "
| `content_available` | "
| `category` | "
| `custom_payload` | "
| `apns_id` | Refer to the [APNs Provider API](https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/APNsProviderAPI.html) for details.
| `expiration` | "
| `priority` | "
| `topic` | "
| `url_args` | Values for [Safari push notifications](https://developer.apple.com/library/mac/documentation/NetworkingInternet/Conceptual/NotificationProgrammingGuideForWebsites/PushNotifications/PushNotifications.html#//apple_ref/doc/uid/TP40013225-CH3-SW12).
| `mutable_content` | Key for [UNNotificationServiceExtension](https://developer.apple.com/reference/usernotifications/unnotificationserviceextension).
| `apns_collapse_id` | Key for setting the identification of a notification and allowing for the updating of the content of that notification in a subsequent push. More information avaible in [WWDC 2016 - Session 707 Introduction to Notifications](https://developer.apple.com/videos/play/wwdc2016/707/?time=1134). iOS 10+

For example:

```ruby
notification          = Apnotic::Notification.new(token)
notification.alert    = "Notification from Apnotic!"
notification.badge    = 2
notification.sound    = "bells.wav"
notification.priority = 5
```

For a [Safari push notification](https://developer.apple.com/notifications/safari-push-notifications/):

```ruby
notification = Apnotic::Notification.new(token)

notification.alert    = {
  title:  "Flight A998 Now Boarding",
  body:   "Boarding has begun for Flight A998.",
  action: "View"
}
notification.url_args = ["boarding", "A998"]
```

### `Apnotic::Response`
The response to a call to `connection.push`.

#### Methods

 * **ok?** → **`boolean`**

 Returns if the push was successful.

 * **headers** → **`hash`**

 Returns a Hash containing the Headers of the response.

 * **status** → **`string`**

 Returns the status code.

 * **body** → **`hash` or `string`**

 Returns the body of the response in Hash format if a valid JSON was returned, otherwise just the RAW body.


### `Apnotic::Push`
The push object to be sent in an async call.

#### Methods

 * **on(event, &block)**

 Allows to set a callback for the request. Available events are:

  * `:response`: triggered when a response is fully received (called once).

 Even if Apnotic is thread-safe, the async callbacks will be executed in a different thread, so ensure that your code in the callbacks is thread-safe.

 ```ruby
 push.on(:response) { |response| p response.headers }
 ```

 * **http2_request**  → **`NetHttp2::Request`**
 
 Returns the HTTP/2 request of the push.



## Getting Your APNs Certificate

> These instructions come from another great gem, [apn_on_rails](https://github.com/PRX/apn_on_rails).

Once you have the certificate from Apple for your application, export your key and the apple certificate as p12 files. Here is a quick walkthrough on how to do this:

1. Click the disclosure arrow next to your certificate in Keychain Access and select the certificate and the key.
2. Right click and choose `Export 2 items…`.
3. Choose the p12 format from the drop down and name it `cert.p12`.

Optionally, you may covert the p12 file to a pem file (this step is optional because Apnotic natively supports p12 files):
```
$ openssl pkcs12 -in cert.p12 -out apple_push_notification_production.pem -nodes -clcerts
```

## Contributing
So you want to contribute? That's great! Please follow the guidelines below. It will make it easier to get merged in.

Before implementing a new feature, please submit a ticket to discuss what you intend to do. Your feature might already be in the works, or an alternative implementation might have already been discussed.

Do not commit to master in your fork. Provide a clean branch without merge commits. Every pull request should have its own topic branch. In this way, every additional adjustments to the original pull request might be done easily, and squashed with `git rebase -i`. The updated branch will be visible in the same pull request, so there will be no need to open new pull requests when there are changes to be applied.

Ensure to include proper testing. To run tests you simply have to be in the project's root directory and run:

```bash
$ rake
```
