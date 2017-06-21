require 'spec_helper'

describe Apnotic::ProviderToken do
  def decode(data)
    data += '=' * (4 - data.length.modulo(4))
    Base64.decode64(data.tr('-_', '+/'))
  end

  let(:team_id) { "team_id" }
  let(:key_id) { "key_id" }
  let(:private_key) do
    OpenSSL::PKey::EC.new('prime256v1').tap do |key|
      key.generate_key
    end
  end
  let(:public_key) do
    OpenSSL::PKey::EC.new(private_key).tap do |key|
      key.private_key = nil
    end
  end
  let(:provider_token) do
    Apnotic::ProviderToken.new(private_key, team_id, key_id)
  end

  describe "token" do
    subject { provider_token.token }
    describe "should build token" do
      it "generates a json web token" do
        expect(subject).to be_truthy
      end
    end
  end

  describe "header" do
    subject do
      header, _, _ = provider_token.token.split(".")
      JSON.parse(decode(header))
    end
    it { is_expected.to eq({"alg"=>"ES256", "kid"=>key_id}) }
  end

  describe "payload" do
    subject do
      _, payload, _ = provider_token.token.split(".")
      JSON.parse(decode(payload))
    end
    let(:time_now) { Time.now }
    it do
      allow(Time).to receive(:now).and_return(time_now)
      is_expected.to eq({"iss"=>team_id, "iat"=>time_now.to_i})
    end
  end

  describe "signature" do
    it "has a valid signature" do
      data = provider_token.token
      header, payload, signature = data.split(".")
      signature = decode(signature)
      digest = OpenSSL::Digest::SHA256.new().digest("#{header}.#{payload}")
      result = public_key.dsa_verify_asn1(digest, signature)
      expect(result).to eq true
    end

  end

end