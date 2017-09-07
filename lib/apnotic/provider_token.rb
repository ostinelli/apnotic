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
      [encode(header), encode(payload), encode(signature)].join(".")
    end

    private

    def header
      JSON.generate({
        alg: "ES256",
        kid: @key_id
      })
    end

    def payload
      JSON.generate({
        iss: @team_id,
        iat: Time.now.to_i
      })
    end

    def signature
      data = [encode(header), encode(payload)].join(".")
      digest = OpenSSL::Digest::SHA256.new().digest(data)
      @key.dsa_sign_asn1(digest)
    end

    def encode(data)
      Base64.encode64(data).tr('+/', '-_').gsub(/[\n=]/, '')
    end
  end
end