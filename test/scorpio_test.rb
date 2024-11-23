# frozen_string_literal: true

require_relative 'test_helper'

describe 'blog' do
  let(:blog_article) { Article.post('title' => "sports!") }

  it 'indexes articles' do
    blog_article

    articles = Article.index

    assert_equal(1, articles.size)
    article = articles[0]
    assert_equal(1, article['id'])
    assert(article.is_a?(Article))
    assert_equal('sports!', article['title'])
    assert_equal('sports!', article.title)
  end
  it 'indexes articles with root' do
    blog_article

    articles = Article.index_with_root
    assert_respond_to(articles, :to_hash)
    assert_equal('v1', articles['version'])
    assert_equal('hi!', articles['note'])
    assert_instance_of(Article, articles['best_article'])
    assert_equal(articles['articles'].last, articles['best_article'])
    assert_equal(1, articles['articles'].size)
    article = articles['articles'][0]
    assert_equal(1, article['id'])
    assert(article.is_a?(Article))
    assert_equal('sports!', article['title'])
    assert_equal('sports!', article.title)
  end
  it 'reads an article' do
    blog_article
    article = Article.read(id: blog_article.id)
    assert(article.is_a?(Article))
    assert_equal('sports!', article['title'])
    assert_equal('sports!', article.title)
  end
  it 'tries to read an article without a required path variable' do
    blog_article
    e = assert_raises(ArgumentError) do
      Article.read({})
    end
    path = BlogModel.openapi_document.operations['articles.read'].path_template_str
    assert_equal(%Q(path #{path} for operation articles.read requires path_params which were missing: ["id"]),
      e.message)
    e = assert_raises(ArgumentError) do
      Article.read({id: ''})
    end
    assert_equal(%Q(path #{path} for operation articles.read requires path_params which were empty: ["id"]),
      e.message)
  end
  it 'tries to read a nonexistent article' do
    err = assert_raises(Scorpio::NotFound404Error) do
      Article.read(id: 99)
    end
    assert_equal({"article" => ["Unknown article! id: 99"]}, JSI::Util.as_json(err.response_object['errors']))
    assert_match(/Unknown article! id: 99/, err.message)
  end
  it 'updates an article on the class' do
    blog_article
    Article.patch({id: blog_article.id, title: 'politics!'})
    assert_equal('politics!', Article.read(id: blog_article.id).title)
  end
  it 'updates an article on the instance' do
    blog_article
    article = Article.read(id: blog_article.id)
    article.title = 'politics!'
    article.patch
    assert_equal('politics!', Article.read(id: blog_article.id).title)
  end
  it 'updates an article with an unsuccessful response' do
    blog_article
    err = assert_raises(Scorpio::UnprocessableEntity422Error) do
      Article.patch({id: blog_article.id, title: 'politics?'})
    end
    assert_equal({"title" => ["with gusto!"]}, JSI::Util.as_json(err.response_object['errors']))
    assert_match(/with gusto!/, err.message)
    assert_equal('sports!', Article.read(id: blog_article.id).title)
  end
  it 'instantiates an article with bad argument' do
    assert_raises(ArgumentError) { Article.new("foo") }
  end
  it 'reports schema failure when the request does not match the request schema' do
    # TODO handle blame
    assert_raises(Scorpio::HTTPErrors::UnprocessableEntity422Error) do
      # title is supposed to be a string
      Article.post('title' => {'music' => '!'})
    end
  end
  it 'checks equality' do
    assert_equal(Article.read(id: blog_article.id), Article.read(id: blog_article.id))
  end
  it 'consistently keys a hash' do
    hash = {Article.read(id: blog_article.id) => 0}
    assert_equal(0, hash[Article.read(id: blog_article.id)])
  end
end

describe 'openapi boolean schema' do
  it("is a schema, v3.0") do
    document = Scorpio::OpenAPI::V3_0::Document.new_jsi({
      'components' => {
        'schemas' => {
          'a' => {
            'additionalProperties' => true
          }
        }
      }
    })
    assert_kind_of(JSI::Schema, document.components.schemas['a'].additionalProperties)
  end
  it 'is a schema, v2' do
    document = Scorpio::OpenAPI::V2::Document.new_jsi({
      'definitions' => {
        'a' => {
          'additionalProperties' => true
        }
      }
    })
    assert_kind_of(JSI::Schema, document.definitions['a'].additionalProperties)
  end
end

describe 'openapi tags' do
  it 'associates operations with a tag' do
    exp_opIds = %w(
      articles.index
      articles.post
      articles.index_with_root
      articles.read
      articles.patch
    )
    exp_ops = exp_opIds.map { |id| BlogModel.openapi_document.operations[id] }.to_set
    if BlogModel.openapi_document.is_a?(Scorpio::Google::RestDescription)
      act_ops = BlogModel.openapi_document.operations.select { |op| op.tagged?('articles') }.to_set
    else
      tag = BlogModel.openapi_document.tags.detect { |t| t.name == 'articles' }
      act_ops = tag.operations.to_set
    end
    assert_equal(exp_ops, act_ops)
  end
end

describe("openapi securitySchemes") do
  it("#operations") do
    oad = Scorpio::OpenAPI::V3_0::Document.new_jsi({
      paths: {'/': {get: {security: [{a: {}}]}}},
      components: {securitySchemes: {a: {type: 'apiKey', in: 'x', name: 'x'}}},
    }, stringify_symbol_keys: true)
    assert_equal(1, oad.components.securitySchemes['a'].operations.count)
  end
end
