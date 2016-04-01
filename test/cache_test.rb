require 'test_helper'
require 'tmpdir'
require 'tempfile'

module ActiveModelSerializers
  class CacheTest < ActiveSupport::TestCase
    InheritedRoleSerializer = Class.new(RoleSerializer) do
      cache key: 'inherited_role', only: [:name, :special_attribute]
      attribute :special_attribute
    end

    setup do
      cache_store.clear
      @comment        = Comment.new(id: 1, body: 'ZOMG A COMMENT')
      @post           = Post.new(title: 'New Post', body: 'Body')
      @bio            = Bio.new(id: 1, content: 'AMS Contributor')
      @author         = Author.new(name: 'Joao M. D. Moura')
      @blog           = Blog.new(id: 999, name: 'Custom blog', writer: @author, articles: [])
      @role           = Role.new(name: 'Great Author')
      @location       = Location.new(lat: '-23.550520', lng: '-46.633309')
      @place          = Place.new(name: 'Amazing Place')
      @author.posts   = [@post]
      @author.roles   = [@role]
      @role.author    = @author
      @author.bio     = @bio
      @bio.author     = @author
      @post.comments  = [@comment]
      @post.author    = @author
      @comment.post   = @post
      @comment.author = @author
      @post.blog      = @blog
      @location.place = @place

      @location_serializer = LocationSerializer.new(@location)
      @bio_serializer      = BioSerializer.new(@bio)
      @role_serializer     = RoleSerializer.new(@role)
      @post_serializer     = PostSerializer.new(@post)
      @author_serializer   = AuthorSerializer.new(@author)
      @comment_serializer  = CommentSerializer.new(@comment)
      @blog_serializer     = BlogSerializer.new(@blog)
    end

    def test_explicit_cache_store
      default_store = Class.new(ActiveModel::Serializer) do
        cache
      end
      explicit_store = Class.new(ActiveModel::Serializer) do
        cache cache_store: ActiveSupport::Cache::FileStore
      end

      assert ActiveSupport::Cache::MemoryStore, ActiveModelSerializers.config.cache_store
      assert ActiveSupport::Cache::MemoryStore, default_store.cache_store
      assert ActiveSupport::Cache::FileStore, explicit_store.cache_store
    end

    def test_inherited_cache_configuration
      inherited_serializer = Class.new(PostSerializer)

      assert_equal PostSerializer._cache_key, inherited_serializer._cache_key
      assert_equal PostSerializer._cache_options, inherited_serializer._cache_options
    end

    def test_override_cache_configuration
      inherited_serializer = Class.new(PostSerializer) do
        cache key: 'new-key'
      end

      assert_equal PostSerializer._cache_key, 'post'
      assert_equal inherited_serializer._cache_key, 'new-key'
    end

    def test_cache_definition
      assert_equal(cache_store, @post_serializer.class._cache)
      assert_equal(cache_store, @author_serializer.class._cache)
      assert_equal(cache_store, @comment_serializer.class._cache)
    end

    def test_cache_key_definition
      assert_equal('post', @post_serializer.class._cache_key)
      assert_equal('writer', @author_serializer.class._cache_key)
      assert_equal(nil, @comment_serializer.class._cache_key)
    end

    def test_cache_key_interpolation_with_updated_at
      render_object_with_cache(@author)
      assert_equal(nil, cache_store.fetch(@author.cache_key))
      assert_equal(@author_serializer.attributes.to_json, cache_store.fetch("#{@author_serializer.class._cache_key}/#{@author_serializer.object.id}-#{@author_serializer.object.updated_at.strftime("%Y%m%d%H%M%S%9N")}").to_json)
    end

    def test_default_cache_key_fallback
      render_object_with_cache(@comment)
      assert_equal(@comment_serializer.attributes.to_json, cache_store.fetch(@comment.cache_key).to_json)
    end

    def test_cache_options_definition
      assert_equal({ expires_in: 0.1, skip_digest: true }, @post_serializer.class._cache_options)
      assert_equal(nil, @blog_serializer.class._cache_options)
      assert_equal({ expires_in: 1.day, skip_digest: true }, @comment_serializer.class._cache_options)
    end

    def test_fragment_cache_definition
      assert_equal([:name], @role_serializer.class._cache_only)
      assert_equal([:content], @bio_serializer.class._cache_except)
    end

    def test_associations_separately_cache
      cache_store.clear
      assert_equal(nil, cache_store.fetch(@post.cache_key))
      assert_equal(nil, cache_store.fetch(@comment.cache_key))

      Timecop.freeze(Time.current) do
        render_object_with_cache(@post)

        assert_equal(@post_serializer.attributes, cache_store.fetch(@post.cache_key))
        assert_equal(@comment_serializer.attributes, cache_store.fetch(@comment.cache_key))
      end
    end

    def test_associations_cache_when_updated
      Timecop.freeze(Time.current) do
        # Generate a new Cache of Post object and each objects related to it.
        render_object_with_cache(@post)

        # Check if it cached the objects separately
        assert_equal(@post_serializer.attributes,    cached_serialization(@post_serializer))
        assert_equal(@comment_serializer.attributes, cached_serialization(@comment_serializer))

        # Simulating update on comments relationship with Post
        new_comment            = Comment.new(id: 2567, body: 'ZOMG A NEW COMMENT')
        new_comment_serializer = CommentSerializer.new(new_comment)
        @post.comments         = [new_comment]

        # Ask for the serialized object
        render_object_with_cache(@post)

        # Check if the the new comment was cached
        assert_equal(new_comment_serializer.attributes, cached_serialization(new_comment_serializer))
        assert_equal(@post_serializer.attributes, cached_serialization(@post_serializer))
      end
    end

    def test_fragment_fetch_with_virtual_associations
      expected_result = {
        id: @location.id,
        lat: @location.lat,
        lng: @location.lng,
        place: 'Nowhere'
      }

      hash = render_object_with_cache(@location)

      assert_equal(hash, expected_result)
      assert_equal({ place: 'Nowhere' }, cache_store.fetch(@location.cache_key))
    end

    def test_fragment_cache_with_inheritance
      inherited = render_object_with_cache(@role, serializer: InheritedRoleSerializer)
      base = render_object_with_cache(@role)

      assert_includes(inherited.keys, :special_attribute)
      refute_includes(base.keys, :special_attribute)
    end

    def test_a_serializer_rendered_by_two_adapter_returns_differently_cached_attributes
      model = Class.new(ActiveModelSerializers::Model) do
        attr_accessor :id, :status, :resource, :started_at, :ended_at, :updated_at, :created_at
      end
      Object.const_set(:Alert, model)
      serializer = Class.new(ActiveModel::Serializer) do
        cache
        attributes :id, :status, :resource, :started_at, :ended_at, :updated_at, :created_at
      end
      Object.const_set(:AlertSerializer, serializer)

      alert = Alert.new(
        id: 1,
        status: "fail",
        resource: "resource-1",
        started_at: Time.new(2016, 3, 31, 21, 36, 35, 0),
        ended_at: nil,
        updated_at: Time.new(2016, 3, 31, 21, 27, 35, 0),
        created_at: Time.new(2016, 3, 31, 21, 37, 35, 0)
      )


      serializable_alert = serializable(alert, serializer: AlertSerializer, adapter: :attributes)
      attributes_serialization1 = serializable_alert.as_json
      assert_equal alert.status, attributes_serialization1.fetch(:status)

      serializable_alert = serializable(alert, serializer: AlertSerializer, adapter: :attributes)
      attributes_serialization2 = serializable_alert.as_json
      assert_equal attributes_serialization1, attributes_serialization2

      attributes_cache_key = CachedSerializer.new(serializable_alert.adapter.serializer).cache_key
      assert_equal attributes_serialization1, cache_store.fetch(attributes_cache_key)

      serializable_alert = serializable(alert, serializer: AlertSerializer, adapter: :json_api)
      jsonapi_cache_key = CachedSerializer.new(serializable_alert.adapter.serializer).cache_key
      refute_equal attributes_cache_key, jsonapi_cache_key
      jsonapi_serialization1 = serializable_alert.as_json
      assert_equal alert.status, jsonapi_serialization1.fetch(:data).fetch(:attributes).fetch(:status)

      serializable_alert = serializable(alert, serializer: AlertSerializer, adapter: :json_api)
      jsonapi_serialization2 = serializable_alert.as_json
      assert_equal jsonapi_serialization1, jsonapi_serialization2

      cached_serialization = cache_store.fetch(jsonapi_cache_key)
      assert_equal jsonapi_serialization1, cached_serialization

      expected_jsonapi_serialization = {
        id: "1",
         type: "alerts",
         attributes: {
           created_at: 'Thu, 31 Mar 2016 21:37:35 UTC +00:00',
           status: "fail",
           resource: "resource-1",
           updated_at: 'Thu,  31 Mar 2016 21:37:35 UTC +00:00',
           started_at: 'Thu, 31 Mar 2016 21:36:35 UTC +00:00',
           ended_at: nil}
      }
      assert_equal expected_jsonapi_serialization, jsonapi_serialization1
    ensure
      Object.send(:remove_const, :Alert)
      Object.send(:remove_const, :AlertSerializer)
    end

    def test_uses_file_digest_in_cache_key
      render_object_with_cache(@blog)
      assert_equal(@blog_serializer.attributes, cache_store.fetch(@blog.cache_key_with_digest))
    end

    def test_cache_digest_definition
      assert_equal(FILE_DIGEST, @post_serializer.class._cache_digest)
    end

    def test_object_cache_keys
      serializer = ActiveModel::Serializer::CollectionSerializer.new([@comment, @comment])
      include_tree = ActiveModel::Serializer::IncludeTree.from_include_args('*')

      actual = CachedSerializer.object_cache_keys(serializer, include_tree)

      assert_equal actual.size, 3
      assert actual.any? { |key| key == 'comment/1' }
      assert actual.any? { |key| key =~ %r{post/post-\d+} }
      assert actual.any? { |key| key =~ %r{writer/author-\d+} }
    end

    def test_cached_attributes
      serializer = ActiveModel::Serializer::CollectionSerializer.new([@comment, @comment])

      Timecop.freeze(Time.current) do
        render_object_with_cache(@comment)

        attributes = Adapter::Attributes.new(serializer)
        attributes.send(:cache_attributes)
        cached_attributes = attributes.instance_variable_get(:@cached_attributes)

        assert_equal cached_attributes[@comment.cache_key], Comment.new(id: 1, body: 'ZOMG A COMMENT').attributes
        assert_equal cached_attributes[@comment.post.cache_key], Post.new(id: 'post', title: 'New Post', body: 'Body').attributes

        writer = @comment.post.blog.writer
        writer_cache_key = "writer/#{writer.id}-#{writer.updated_at.strftime("%Y%m%d%H%M%S%9N")}"

        assert_equal cached_attributes[writer_cache_key], Author.new(id: 'author', name: 'Joao M. D. Moura').attributes
      end
    end

    def test_serializer_file_path_on_nix
      path = '/Users/git/emberjs/ember-crm-backend/app/serializers/lead_serializer.rb'
      caller_line = "#{path}:1:in `<top (required)>'"
      assert_equal caller_line[ActiveModel::Serializer::CALLER_FILE], path
    end

    def test_serializer_file_path_on_windows
      path = 'c:/git/emberjs/ember-crm-backend/app/serializers/lead_serializer.rb'
      caller_line = "#{path}:1:in `<top (required)>'"
      assert_equal caller_line[ActiveModel::Serializer::CALLER_FILE], path
    end

    def test_serializer_file_path_with_space
      path = '/Users/git/ember js/ember-crm-backend/app/serializers/lead_serializer.rb'
      caller_line = "#{path}:1:in `<top (required)>'"
      assert_equal caller_line[ActiveModel::Serializer::CALLER_FILE], path
    end

    def test_serializer_file_path_with_submatch
      # The submatch in the path ensures we're using a correctly greedy regexp.
      path = '/Users/git/ember js/ember:123:in x/app/serializers/lead_serializer.rb'
      caller_line = "#{path}:1:in `<top (required)>'"
      assert_equal caller_line[ActiveModel::Serializer::CALLER_FILE], path
    end

    def test_digest_caller_file
      contents = "puts 'AMS rocks'!"
      dir = Dir.mktmpdir('space char')
      file = Tempfile.new('some_ruby.rb', dir)
      file.write(contents)
      path = file.path
      caller_line = "#{path}:1:in `<top (required)>'"
      file.close
      assert_equal ActiveModel::Serializer.digest_caller_file(caller_line), Digest::MD5.hexdigest(contents)
    ensure
      file.unlink
      FileUtils.remove_entry dir
    end

    def test_warn_on_serializer_not_defined_in_file
      called = false
      serializer = Class.new(ActiveModel::Serializer)
      assert_output(nil, /_cache_digest/) do
        serializer.digest_caller_file('')
        called = true
      end
      assert called
    end

    private

    def render_object_with_cache(obj, options = {})
      serializable(obj, options).serializable_hash
    end

    def cache_store
      ActiveModelSerializers.config.cache_store
    end

    def cached_serialization(serializer)
      cache_key = CachedSerializer.new(serializer).cache_key
      cache_store.fetch(cache_key)
    end
  end
end
