# frozen_string_literal: true

require 'logger'
require 'api_hammer'

# this is a virtual model to parent models representing resources of the blog. it sets
# up connection information including base url, custom middleware or adapter for faraday.
# it describes the API by setting the API document, but this class itself represents no
# resources - it sets no tag_name and defines no represented_schemas.
class BlogModel < Scorpio::ResourceBase
  define_inheritable_accessor(:logger)
  logpath = 'log/blog_client.log'
  FileUtils.mkdir_p(File.dirname(logpath))
  self.logger = ::Logger.new(logpath)

  blog_port = $blog_port || raise('$blog_port is nil')

  self.openapi_document = YAML.load_file(-"test/blog.#{ENV['SCORPIO_API_DESCRIPTION_FORMAT'] || 'openapi3_1'}.yml")
  if openapi_document['kind'] == 'discovery#restDescription'
    self.openapi_document.base_url = File.join("http://localhost:#{blog_port}/", openapi_document.servicePath)
  elsif openapi_document.v2?
    self.openapi_document.base_url = File.join("http://localhost:#{blog_port}/", openapi_document.basePath)
  else
    self.openapi_document.server_variables = {
      'scheme' => 'http',
      'host' => 'localhost',
      'port' => blog_port,
    }
  end
  self.faraday_builder = -> (conn) {
    conn.request(:api_hammer_request_logger, logger)
  }
end

# this model, Article, is a resource of the blog API.
class Article < BlogModel
  self.tag_name = 'articles'
  if ENV['SCORPIO_API_DESCRIPTION_FORMAT'] == 'rest_description'
    self.represented_schemas = [openapi_document.schemas['article']]
  elsif openapi_document.v2?
    self.represented_schemas = [openapi_document.definitions['article']]
  else
    self.represented_schemas = [openapi_document.components.schemas['article']]
  end
end

class BlogClean < BlogModel
  self.tag_name = 'clean'
end
