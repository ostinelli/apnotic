require 'base64'
require 'openssl'
require 'json'

module Apnotic
  class ProviderToken
    def initialize(key, team_id, key_id)
      @key     = OpenSSL::PKey::EC.new(key)
      @team_id = team_id
      @key_id  = key_id
    end

    def token
      Array.new.tap do |array|
        array.push encode_data(header)
        array.push encode_data(payload)
        array.push base64_urlsafe_encode(signature)
      end.join(".")
    end

    private

    def payload
      {
        iss: @team_id,
        iat: Time.now.to_i
      }
    end

    def header
      {
        alg: "ES256",
        kid: @key_id
      }
    end

    def signature
      data = [encode_data(header), encode_data(payload)].join(".")
      @key.dsa_sign_asn1(OpenSSL::Digest::SHA256.new().digest(data))
    end

    def encode_data(data)
      base64_urlsafe_encode(JSON.generate(data))
    end

    def base64_urlsafe_encode(data)
      Base64.encode64(data).tr('+/', '-_').gsub(/[\n=]/, '')
    end

  end
end