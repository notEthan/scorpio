# frozen_string_literal: true

require "scorpio/version"
require "jsi"
require "ur"
require "addressable"
require "faraday"
require "pathname"
require "pp"

module Scorpio
  def self.root
    @root ||= Pathname.new(__FILE__).dirname.parent.expand_path
  end
end

module Scorpio
  # generally put in code paths that are not expected to be valid control flow paths.
  # rather a NotImplementedCorrectlyError. but that's too long.
  class Bug < NotImplementedError
  end

  proc { |v| define_singleton_method(:error_classes_by_status) { v } }.call({})
  # Scorpio::Error encompasses certain Scorpio-defined errors encountered in using Scorpio.
  # at the moment this only includes HTTPError[^1], but will likely cover errors in schemas and
  # other things in the future.
  #
  # [^1]: unless I have, since writing this, implemented other things but forgotten to update this
  # comment, which does seem likely enough.
  class Error < StandardError; end
  class HTTPError < Error
    # for HTTPError subclasses representing a single status, sets and/or returns the represented status.
    #
    # @param status [Integer] if specified, sets the HTTP status the class represents
    # @return [Integer] the HTTP status the class represents
    def self.status(status = nil)
      if status
        @status = status
        Scorpio.error_classes_by_status[status] = self
      else
        @status
      end
    end
    attr_accessor :ur, :response_object
  end
  # HTTP Error classes' canonical names are like Scorpio::HTTPErrors::BadRequest400Error, but can
  # be referred to like Scorpio::BadRequest400Error. this is just to avoid clutter in the Scorpio
  # namespace in yardoc.
  module HTTPErrors
    # an HTTP response with a status of 400-499
    class ClientError < HTTPError; end
    # an HTTP response with a status of 500-599
    class ServerError < HTTPError; end

    class BadRequest400Error < ClientError;                    status(400); end
    class Unauthorized401Error < ClientError;                  status(401); end
    class PaymentRequired402Error < ClientError;               status(402); end
    class Forbidden403Error < ClientError;                     status(403); end
    class NotFound404Error < ClientError;                      status(404); end
    class MethodNotAllowed405Error < ClientError;              status(405); end
    class NotAcceptable406Error < ClientError;                 status(406); end
    class ProxyAuthenticationRequired407Error < ClientError;   status(407); end
    class RequestTimeout408Error < ClientError;                status(408); end
    class Conflict409Error < ClientError;                      status(409); end
    class Gone410Error < ClientError;                          status(410); end
    class LengthRequired411Error < ClientError;                status(411); end
    class PreconditionFailed412Error < ClientError;            status(412); end
    class PayloadTooLarge413Error < ClientError;               status(413); end
    class URITooLong414Error < ClientError;                    status(414); end
    class UnsupportedMediaType415Error < ClientError;          status(415); end
    class RangeNotSatisfiable416Error < ClientError;           status(416); end
    class ExpectationFailed417Error < ClientError;             status(417); end
    class ImaTeapot418Error < ClientError;                     status(418); end
    class MisdirectedRequest421Error < ClientError;            status(421); end
    class UnprocessableEntity422Error < ClientError;           status(422); end
    class Locked423Error < ClientError;                        status(423); end
    class FailedDependency424Error < ClientError;              status(424); end
    class UpgradeRequired426Error < ClientError;               status(426); end
    class PreconditionRequired428Error < ClientError;          status(428); end
    class TooManyRequests429Error < ClientError;               status(429); end
    class RequestHeaderFieldsTooLarge431Error < ClientError;   status(431); end
    class UnavailableForLegalReasons451Error < ClientError;    status(451); end

    class InternalServerError500Error < ServerError;           status(500); end
    class NotImplemented501Error < ServerError;                status(501); end
    class BadGateway502Error < ServerError;                    status(502); end
    class ServiceUnavailable503Error < ServerError;            status(503); end
    class GatewayTimeout504Error < ServerError;                status(504); end
    class HTTPVersionNotSupported505Error < ServerError;       status(505); end
    class VariantAlsoNegotiates506Error < ServerError;         status(506); end
    class InsufficientStorage507Error < ServerError;           status(507); end
    class LoopDetected508Error < ServerError;                  status(508); end
    class NotExtended510Error < ServerError;                   status(510); end
    class NetworkAuthenticationRequired511Error < ServerError; status(511); end
  end
  include HTTPErrors
  error_classes_by_status.freeze

  class ConfigError < Error
    attr_accessor :name
  end
  class ParameterError < ConfigError
  end
  class AmbiguousParameter < ConfigError
  end

  autoload :Google, 'scorpio/google_api_document'
  autoload :OpenAPI, 'scorpio/openapi'
  autoload :Ur, 'scorpio/ur'
  autoload :ResourceBase, 'scorpio/resource_base'
  autoload :Request, 'scorpio/request'
  autoload :Response, 'scorpio/response'
end
