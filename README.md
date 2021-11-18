[![Build Status](https://travis-ci.org/ostinelli/apnotic.svg?branch=master)](https://travis-ci.org/ostinelli/apnotic)
[![Code Climate](https://codeclimate.com/github/ostinelli/apnotic/badges/gpa.svg)](https://codeclimate.com/github/ostinelli/apnotic)
[![Gem Version](https://badge.fury.io/rb/apnotic.svg)](https://badge.fury.io/rb/apnotic)

# Apnotic

Apnotic is a gem for sending Apple Push Notifications using the [HTTP-2 specifics](https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html).


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
connection.join(timeout: 5)

# close the connection
connection.close
```

#### Mobile Device Management (MDM) notifications

If you are building an iOS MDM solution, you can as well use apnotic to send mdm push notifications with the `Apnotic::MdmNotification` class. Sending a MDM notification requires a token and a push magic value, which is sent by the iOS device during its MDM enrollment:

```ruby
require 'apnotic'

# create a persistent connection
connection = Apnotic::Connection.new(cert_path: "apns_certificate.pem", cert_pass: "pass")

# create a notification for a specific device token
token = '6c267f26b173cd9595ae2f6702b1ab560371a60e7c8a9e27419bd0fa4a42e58f'

# push magic value given by the iOS device during enrollment
push_magic = '7F399691-C3D9-4795-ACF8-0B51D7073497'

notification = Apnotic::MdmNotification.new(token: token, push_magic: push_magic)

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

#### Token-based authentication
Token-based authentication is supported. There are several advantages with token-based auth:

- There is no need to renew push certificates annually.
- A single key can be used for every app in your developer account.

First, you will need a [token signing key](http://help.apple.com/xcode/mac/current/#/dev54d690a66?sub=dev1eb5dfe65) from your Apple developer account.

Then configure your connection for `:token` authentication:

```ruby
require 'apnotic'
connection = Apnotic::Connection.new(
  auth_method: :token,
  cert_path: "key.p8",
  key_id: "p8_key_id",
  team_id: "apple_team_id"
)
```

### With Sidekiq / Resque / ...
> In case that errors are encountered, Apnotic will raise the error and repair the underlying connection, but it will not retry the requests that have failed. This is by design,  so that the job manager (Sidekiq, Resque,...) can retry the job that failed. For this reason, it is recommended to use a queue engine that will retry unsuccessful pushes.

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
  }, size: 5) do |connection|
    connection.on(:error) { |exception| puts "Exception has been raised: #{exception}" }
  end

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

> The official [APNs Provider API documentation](https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html) explains how to interpret the responses given by the APNS.

You may also consider using async pushes instead in a Sidekiq / Rescue worker.


## Objects

### `Apnotic::Connection`
To create a new persistent connection:

```ruby
Apnotic::Connection.new(options)
```

| Option           | Description
|------------------|------------
| :cert_path       | `Required` The path to a valid APNS push certificate or any object that responds to `:read`. Supported formats: `.pem`, `.p12` (`:cert` auth), or `.p8` (`:token` auth).
| :cert_pass       | `Optional` The certificate's password.
| :auth_method     | `Optional` The options are `:cert` or `:token`. Defaults to `:cert`.
| :team_id         | `Required for :token auth` Team ID from [Membership Details](https://developer.apple.com/account/#!/membership/).
| :key_id          | `Required for :token auth` ID from [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/authkeys).
| :url             | `Optional` Defaults to https://api.push.apple.com:443.
| :connect_timeout | `Optional` Expressed in seconds, defaults to 30.
| :proxy_addr      | `Optional` Proxy server. e.g. http://proxy.example.com
| :proxy_port      | `Optional` Proxy port. e.g. 8080
| :proxy_user      | `Optional` User name for proxy authentication. e.g. user_name
| :proxy_pass      | `Optional` Password for proxy authentication. e.g. pass_word

Note that since `:cert_path` can be any object that responds to `:read`, it is possible to pass in a certificate string directly by wrapping it up in a `StringIO` object:

```ruby
Apnotic::Connection.new(cert_path: StringIO.new("pem cert as string"))
```

It is also possible to create a connection that points to the Apple Development servers by calling instead:

```ruby
Apnotic::Connection.development(options)
```

> The concepts of PRODUCTION and DEVELOPMENT are different from what they used to be in previous specifications. Anything built directly from Xcode and loaded on your phone will have the app generate DEVELOPMENT tokens, while everything else (TestFlight, Apple Store, HockeyApp, ...) will be considered as PRODUCTION environment.

#### Methods

- **cert_path** → **`string`**

    Returns the path to the certificate.

- **on(event, &block)**

    Allows to set a callback for the connection. The only available event is `:error`, which allows to set a callback when an error is raised at socket level, hence in the underlying socket thread.

    ```ruby
    connection.on(:error) { |exception| puts "Exception has been raised: #{exception}" }
    ```

    > If the `:error` callback is not set, the underlying socket thread may raise an error in the main thread at unexpected execution times.

- **url** → **`URL`**

    Returns the URL of the APNS endpoint.

##### Blocking calls

- **push(notification, timeout: 30)** → **`Apnotic::Response` or `nil`**

    Sends a notification. Returns `nil` in case a timeout occurs.

##### Non-blocking calls

- **prepare_push(notification)** → **`Apnotic::Push`**

    Prepares an async push.

    ```ruby
    push = client.prepare_push(notification)
    ```

- **push_async(push)**

    Sends the push asynchronously.


### `Apnotic::ConnectionPool`
For your convenience, a wrapper around the [Connection Pool](https://github.com/mperham/connection_pool) gem is here for you. To create a new connection pool:

```ruby
Apnotic::ConnectionPool.new(connection_options, connection_pool_options) do |connection|
  connection.on(:error) { |exception| puts "Exception has been raised: #{exception}" }
end
```

For example:

```ruby
APNOTIC_POOL = Apnotic::ConnectionPool.new({
  cert_path: "apns_certificate.pem"
}, size: 5) do |connection|
  connection.on(:error) { |exception| puts "Exception has been raised: #{exception}" }
end
```

It is also possible to create a connection pool that points to the Apple Development servers by calling instead:

```ruby
Apnotic::ConnectionPool.development(connection_options, connection_pool_options) do |connection|
  connection.on(:error) { |exception| puts "Exception has been raised: #{exception}" }
end
```

> Since `1.4.0.` you are required to pass in a block when defining an `Apnotic::ConnectionPool`. This is to enforce a proper implementation of the library. You can read more [here](https://github.com/ostinelli/apnotic/issues/69).

### `Apnotic::Notification`
To create a notification for a specific device token:

```ruby
notification = Apnotic::Notification.new(token)
```

#### Methods
These are all Accessor attributes.

| Method | Documentation
|-----|-----
| `alert` | Refer to the official Apple documentation of [The Payload Key Reference](https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/PayloadKeyReference.html) for details.
| `badge` | "
| `sound` | "
| `content_available` | "
| `category` | "
| `custom_payload` | "
| `thread_id` | "
| `target_content_id` | "
| `interruption_level` | Refer to [Payload Key Reference](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/generating_a_remote_notification#2943363) for details. iOS 15+
| `relevance_score` | Refer to [Payload Key Reference](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/generating_a_remote_notification#2943363) for details. iOS 15+
| `apns_id` | Refer to [Communicating with APNs](https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html) for details.
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

-  **body** → **`hash` or `string`**

    Returns the body of the response in Hash format if a valid JSON was returned, otherwise just the RAW body.

- **headers** → **`hash`**

    Returns a Hash containing the Headers of the response.

- **ok?** → **`boolean`**

    Returns if the push was successful.

- **status** → **`string`**

    Returns the status code.


### `Apnotic::Push`
The push object to be sent in an async call.

#### Methods

- **http2_request**  → **`NetHttp2::Request`**

    Returns the HTTP/2 request of the push.

- **on(event, &block)**

    Allows to set a callback for the request. Available events are:

    `:response`: triggered when a response is fully received (called once).

    Even if Apnotic is thread-safe, the async callbacks will be executed in a different thread, so ensure that your code in the callbacks is thread-safe.

    ```ruby
    push.on(:response) { |response| p response.headers }
    ```

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


## Thread-Safety
Apnotic is thread-safe. However, some caution is imperative:

  * The async callbacks will be executed in a different thread, so ensure that your code in the callbacks is thread-safe.
  * Errors in the underlying socket loop thread will be raised in the main thread at unexpected execution times, unless you specify the `:error` callback on the Connection. If you're using Apnotic with a job manager you should be fine by not specifying this callback.


## Contributing
So you want to contribute? That's great! Please follow the guidelines below. It will make it easier to get merged in.

Before implementing a new feature, please submit a ticket to discuss what you intend to do. Your feature might already be in the works, or an alternative implementation might have already been discussed.

Do not commit to master in your fork. Provide a clean branch without merge commits. Every pull request should have its own topic branch. In this way, every additional adjustments to the original pull request might be done easily, and squashed with `git rebase -i`. The updated branch will be visible in the same pull request, so there will be no need to open new pull requests when there are changes to be applied.

Ensure that proper testing is included. To run tests you simply have to be in the project's root directory and run:

```bash
$ rake
```
