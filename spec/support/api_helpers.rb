module Apnotic

  module ApiHelpers

    def apn_file_path
      File.expand_path('../priv/apn.pem', __FILE__)
    end

    def apn_p12_file_path
      File.expand_path('../priv/apn.p12', __FILE__)
    end

    def cert_file_path
      File.expand_path('../priv/server.crt', __FILE__)
    end

    def key_file_path
      File.expand_path('../priv/server.key', __FILE__)
    end

    def wait_for(seconds=2, &block)
      (0..seconds).each do
        break if block.call
        sleep 1
      end
    end
  end
end
