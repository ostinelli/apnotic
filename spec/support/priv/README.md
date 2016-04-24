# Private Key and Cert - Disclaimer

Please note that the included certificate 'server.crt' and private key 'server.key' are
publicly available via the Apnotic repositories, and should NOT be used for any secure application.
These have been provided here for your testing comfort only.

You may consider getting your copy of [OpenSSL](http://www.openssl.org) to generate your server's own
certificate and private key by issuing a command similar to:

```
$ openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt
```
