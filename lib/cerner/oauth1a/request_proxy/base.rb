# frozen_string_literal: true

require 'cerner/oauth1a/request_proxy'

module Cerner
  module OAuth1a
    module RequestProxy
      # Public: A base class for requests.
      class Base
        def self.proxies(klass)
          available_proxies[klass] = self
        end

        attr_accessor :request

        def initialize(request)
          @request = request
        end

        def parameters
          raise NotImplementedError, 'Must be implemented by subclasses'
        end

        def accessor_secret
          parameters['accessor_secret']
        end

        def consumer_key
          parameters['oauth_consumer_key']
        end

        def expires_at
          parameters['expires_at']
        end

        def nonce
          parameters['oauth_nonce']
        end

        def timestamp
          parameters['oauth_timestamp']
        end

        def token
          parameters['oauth_token']
        end

        def token_secret
          parameters['token_secret']
        end

        def signature_method
          parameters['oauth_signature_method']
        end

        def signature
          parameters['oauth_signature']
        end

        def consumer_principal
          parameters['consumer_principal']
        end

        def realm
          parameters['realm']
        end

        def normalized_uri
          u = URI.parse(uri)
          normalized_uri = "#{u.scheme.downcase}://#{u.host.downcase}"
          if (u.scheme.downcase == 'http' && u.port != 80) || (u.scheme.downcase == 'https' && u.port != 443)
            normalized_uri += ":#{u.port}"
          end

          if u.path && u.path != ''
            normalized_uri += u.path.to_s
          else
            normalized_uri += '/'
          end

          normalized_uri
        end

        def normalized_parameters
          # Normalize parameters
          parameters.reject { |k, _v| k == 'oauth_signature' }
        end

        def signature_base_string
          base = [method, normalized_uri, normalized_parameters]
          base.map { |v| escape(v) }.join('&')
        end
      end
    end
  end
end
