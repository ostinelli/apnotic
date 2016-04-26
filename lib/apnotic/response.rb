require 'json'

module Apnotic

  class Response
    attr_reader :headers

    def initialize(options={})
      @headers = options[:headers]
      @body    = options[:body]
    end

    def status
      @headers[':status'] if @headers
    end

    def ok?
      status == '200'
    end

    def body
      JSON.parse(@body) rescue @body
    end
  end
end
