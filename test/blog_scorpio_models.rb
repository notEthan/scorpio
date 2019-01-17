require 'logger'
require 'api_hammer'

# this is a virtual model to parent models representing resources of the blog. it sets
# up connection information including base url, custom middleware or adapter for faraday.
# it describes the API by setting the API document, but this class itself represents no
# resources - it sets no resource_name and defines no schema_keys.
class BlogModel < Scorpio::ResourceBase
  define_inheritable_accessor(:logger)
  logpath = Pathname.new('log/test.log')
  FileUtils.mkdir_p(logpath.dirname)
  self.logger = ::Logger.new(logpath)

  if ENV['SCORPIO_API_SPECIFIER'] == 'rest_description'
    self.openapi_document = Scorpio::Google::RestDescription.new(YAML.load_file('test/blog.rest_description.yml')).to_openapi_document
    self.base_url = File.join("http://localhost:#{$blog_port || raise(Bug)}/", openapi_document.basePath)
  elsif ENV['SCORPIO_API_SPECIFIER'] == 'openapi2'
    self.openapi_document = YAML.load_file('test/blog.openapi2.yml')
    self.base_url = File.join("http://localhost:#{$blog_port || raise(Bug)}/", openapi_document.basePath)
  elsif ENV['SCORPIO_API_SPECIFIER'] == 'openapi3' || ENV['SCORPIO_API_SPECIFIER'].nil?
    self.openapi_document = YAML.load_file('test/blog.openapi3.yml')
    self.server_variables = {
      'scheme' => 'http',
      'host' => 'localhost',
      'port' => $blog_port || raise(Bug),
    }
  else
    abort("bad SCORPIO_API_SPECIFIER")
  end
  self.faraday_builder = -> (conn) {
    conn.request(:api_hammer_request_logger, logger)
  }
end

# this is a model of Article, a resource of the blog API. it sets the resource_name
# to the key of the 'resources' section of the API (described by the api document
# specified to BlogModel) 
class Article < BlogModel
  self.tag_name = 'articles'
  if openapi_document.v2?
    self.represented_schemas = [openapi_document.definitions['articles']]
  else
    self.represented_schemas = [openapi_document.components.schemas['articles']]
  end
end

class BlogClean < BlogModel
  self.tag_name = 'clean'
end
