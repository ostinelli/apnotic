require 'apnotic/connection'
require 'apnotic/connection_pool'
require 'apnotic/notification'
require 'apnotic/response'
require 'apnotic/stream'
require 'apnotic/version'

module Apnotic
  raise "Cannot require Apnotic, unsupported engine '#{RUBY_ENGINE}'" unless RUBY_ENGINE == "ruby"
end
