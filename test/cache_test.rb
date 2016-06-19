require 'test_helper'

require 'pp'
require 'active_support'
require 'redis'
require 'oj'
require 'readthis'
require 'knuckles'
Readthis.serializers << ::Oj
cache_store = Readthis::Cache.new(
 marshal: Oj,
 compress: true,
 driver: :hiredis
)
# config.action_controller.cache_store = cache_store
ENV['REDIS_URL'] = 'redis://localhost:6379/5'
::Knuckles.configure do |config|
 config.cache = cache_store
 config.keygen = Readthis::Expanders
 config.serializer = Oj
end
# require "minitest/benchmark" if ENV["BENCH"]
# class TestCache < Minitest::Benchmark
#
# end
class CacheTest < ActiveSupport::TestCase
  class Post < ActiveModelSerializers::Model
    attr_accessor :id, :title, :body
  end
  class PostSerializer < ActiveModel::Serializer
    attributes :id, :title, :body
  end
  PRIMARY_RESOURCE = Post.new(id: 1, title: 5, body: 10)
  def test_caching
    ams_options = { adapter: :json }
    pipeline_options = ams_options.merge(view: ActiveModelSerializers::SerializableResource)
    pipeline = Knuckles::Pipeline.new
    json = pipeline.call(Array(PRIMARY_RESOURCE), view: ActiveModelSerializers::SerializableResource)
    pp json
  end

   # config.action_controller.cache_store = :readthis_store, {
   #   expires_in: 15.minutes.to_i,
   #   marshal: ::Oj,
   #   namespace: 'cache',
   #   redis: { url: ENV.fetch('REDIS_URL'), driver: :hiredis, compress: true }
   # }
   #
end
