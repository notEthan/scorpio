require('googleauth')
require('faraday')

# references
#
# https://developers.google.com/identity/protocols/oauth2/web-server
# https://github.com/googleapis/google-auth-library-ruby


# Configures authorization for making requests to google APIs on behalf of a user.
# This uses OAuth 2.0 as a web application (though written to integrate with a CLI)
#
# needs ENV:
# GOOGLE_CLIENT_ID_JSON
# GOOGLE_TOKEN_STORE
# GOOGLE_USER_ID
module GoogleUserAuth
  attr_writer(:client_id)
  def client_id
    @client_id ||= Google::Auth::ClientId.from_file(client_id_file)
  end

  attr_writer(:client_id_file)

  # client_id_file comes from
  # https://console.cloud.google.com/apis/credentials/oauthclient/
  # https://console.cloud.google.com/apis/credentials
  # an OAuth 2.0 Client ID
  # with type: Web Application
  # with Authorized redirect URIs: http://localhost:8080/
  #   or whatever port is configured
  def client_id_file
    @client_id_file ||= ENV['GOOGLE_CLIENT_ID_JSON'] || raise("need env: GOOGLE_CLIENT_ID_JSON (filename of JSON auth 2 web application client id)")
  end

  attr_writer(:token_store)
  def token_store
    @token_store ||= begin
      require('googleauth/stores/file_token_store')
      Google::Auth::Stores::FileTokenStore.new(file: token_store_file)
    end
  end

  attr_writer(:token_store_file)
  # this can be empty/not exist; will be populated by authorizer.handle_auth_callback
  def token_store_file
    @token_store_file ||= ENV['GOOGLE_TOKEN_STORE'] || raise("need env: GOOGLE_TOKEN_STORE (yaml filename, may be empty)")
  end

  attr_writer(:callback_port)
  def callback_port
    @callback_port ||= ENV['GOOGLE_CALLBACK_PORT'] || 8080
  end

  attr_writer(:callback_uri)

  def callback_uri
    @callback_uri ||= ENV['GOOGLE_CALLBACK_URI'] || "http://localhost:#{callback_port}/"
  end

  attr_writer(:scope)
  # scopes are configured here:
  # https://console.cloud.google.com/apis/credentials/consent/edit
  #
  # list:
  # https://developers.google.com/identity/protocols/oauth2/scopes
  def scope
    @scope ||= ENV['GOOGLE_OAUTH_SCOPE'] || raise("need env: GOOGLE_OAUTH_SCOPE (scope URL)")
  end

  attr_writer(:user_authorizer)

  def user_authorizer
    @user_authorizer ||= Google::Auth::UserAuthorizer.new(
      client_id,
      scope,
      token_store,
      callback_uri: callback_uri,
    )
  end

  attr_writer(:web_user_authorizer)

  def web_user_authorizer
    @web_user_authorizer ||= Google::Auth::WebUserAuthorizer.new(
      client_id,
      scope,
      token_store,
      callback_uri: callback_uri,
    )
  end

  attr_writer(:user_id)

  def user_id
    @user_id ||= ENV['GOOGLE_USER_ID'] || raise("need env: GOOGLE_USER_ID (google account email)")
  end

  class WithAccessToken < Faraday::Middleware
    def initialize(app, user_auth)
      super(app)
      @app = app
      @user_auth = user_auth
    end

    attr_reader(:user_auth)

    def call(env)
      set_auth(env)
      @app.call(env)
    end

    def set_auth(env)
      credentials = user_auth.user_authorizer.get_credentials(user_auth.user_id)

      if credentials.nil? || credentials.expired?
        url = user_auth.user_authorizer.get_authorization_url(login_hint: user_auth.user_id)
        STDERR.puts("please authorize in the browser here:\n🔗\t#{url}")

        require('webrick')
        require('rackup')

        rack_app = proc do |request_env|
          rack_request = Rack::Request.new(request_env)

          unless rack_request.request_method == 'GET' && rack_request.path == '/'
            next([404, {}, '?'])
          end

          # this stores the session authorization token
          target_url = user_auth.web_user_authorizer.handle_auth_callback(user_auth.user_id, rack_request)

          credentials = user_auth.user_authorizer.get_credentials(user_auth.user_id)

          if credentials
            STDERR.puts "✅ authorized!"
            Rackup::Handler::WEBrick.shutdown # shuts down asynchronously, after response
            [200, {'content-type' => 'text/plain; charset=utf-8'}, "✅ Authorized! You may close this page."]
          else
            STDERR.puts "❌ no credentials!"
            body = %Q(❌ No credentials! Try again? <a href="#{Addressable::URI.escape(target_url)}">Authorize</a>)
            [200, {'content-type' => 'text/html; charset=utf-8'}, body]
          end
        end

        Rackup::Handler::WEBrick.run(rack_app, Port: user_auth.callback_port)
      end

      env.request_headers['authorization'] = "Bearer #{credentials.access_token}"
    end
  end

  Faraday::Request.register_middleware(google_user_auth_access_token: proc { WithAccessToken })
end
