[![Build Status](https://travis-ci.org/ostinelli/apnotic.svg?branch=master)](https://travis-ci.org/ostinelli/apnotic)
[![Code Climate](https://codeclimate.com/github/ostinelli/apnotic/badges/gpa.svg)](https://codeclimate.com/github/ostinelli/apnotic)

# Apnotic

Apnotic is a gem for sending Apple Push Notifications using the [HTTP-2 specifics](https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/ApplePushService.html#//apple_ref/doc/uid/TP40008194-CH100-SW9).


## Why "Yet Another APN" gem?
If you have used the previous Apple Push Notification specifications you may have noticed that it was hard to know whether a Push Notification was successful or not. It is a common problem that has been reported multiple times. In addition, you had to run a separate Feedback service to retrieve the list of the device tokens that were no longer valid, and ensure to purge them from your systems.

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

### With Sidekiq / Rescue
A practical example of a Sidekiq / Rescue worker will probably have to:

 * Use a pool of persistent connections.
 * Send a push notification.
 * Remove a device with an invalid token. 

An example of a Sidekiq worker with such features follows.

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

      if response.status == '410' ||
        (response.status == '400' && response.body['reason'] == 'BadDeviceToken')
        Device.find_by(token: token).destroy
      end
    end
  end
end
```

> The official [APNs Provider API documentation](https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/APNsProviderAPI.html) explains how to interpret the responses given by the APNS.



## Objects

### `Apnotic::Connection`
To create a new persistent connection:

```ruby
Apnotic::Connection.new(options)
```

| Option | Description
|-----|-----
| :cert_path | Required. The path to a valid APNS push certificate in .pem format (see "Convert your certificate" here below for instructions).
| :cert_pass | Optional. The certificate's password.
| :uri | Optional. Defaults to https://api.push.apple.com:443.

It is also possible to create a connection that points to the Apple Development servers by calling instead:

```ruby
Apnotic::Connection.development(options)
```

> The concepts of PRODUCTION and DEVELOPMENT are different from what they used to be in previous specifications. Anything built directly from XCode and loaded on your phone will have the app generate DEVELOPMENT tokens, while everything else (TestFlight, Apple Store, HockeyApp, ...) will be considered as PRODUCTION environment. 

#### Methods

 * **uri** → **`URI`**
 Returns the URI of the APNS endpoint.

 * **cert_path** → **`string`**
 Returns the path to the certificate
 
 * **push(notification, timeout=30)** → **`Apnotic::Response` or `nil`**
 Sends a notification. Returns `nil` in case a timeout occurs.


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
| `apns_id` | Refer to the [APNs Provider API](https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/APNsProviderAPI.html) for details. If you don't provide any, one will be generated for you.
| `expiration` | "
| `priority` | "
| `topic` | "

For example:

```ruby
notification          = Apnotic::Notification.new(token)
notification.alert    = "Notification from Apnotic!"
notification.badge    = 2
notification.sound    = "bells.wav"
notification.priority = 5
```


### `Apnotic::Response`
The response to a call to `connection.push`.

#### Methods

 * **headers** → **`hash`**
 Returns a Hash containing the Headers of the response.

 * **status** → **`string`**
 Returns the status code.

 * **body** → **`hash` or `string`**
 Returns the body of the response in Hash format if a valid JSON was returned, otherwise just the RAW body.

 * **headers** → **`boolean`**
 Returns if the push was successful.


## Converting Your Certificate

> These instructions come from another great gem, [apn_on_rails](https://github.com/PRX/apn_on_rails).

Once you have the certificate from Apple for your application, export your key and the apple certificate as p12 files. Here is a quick walkthrough on how to do this:

1. Click the disclosure arrow next to your certificate in Keychain Access and select the certificate and the key. 
2. Right click and choose `Export 2 items…`. 
3. Choose the p12 format from the drop down and name it `cert.p12`.

Now covert the p12 file to a pem file:
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
