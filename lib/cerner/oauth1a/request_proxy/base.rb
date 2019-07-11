# frozen_string_literal: true

require 'cerner/oauth1a/request_proxy'
require 'uri'

module Cerner
  module OAuth1a
    module RequestProxy
      # Public: A base class for requests inside of Cerner OAuth1a.
      class Base
        # Internal: A DSL function that registeres subclasses as valid proxies
        # for specific types of requests.
        def self.proxies(klass)
          Cerner::OAuth1a::RequestProxy.available_proxies[klass] = self
        end

        attr_accessor :request

        def initialize(request)
          @request = request
        end

        def accessor_secret
          parameters[:accessor_secret]
        end

        def consumer_key
          parameters[:oauth_consumer_key]
        end

        def expires_at
          parameters[:expires_at]
        end

        def nonce
          parameters[:oauth_nonce]
        end

        def timestamp
          parameters[:oauth_timestamp]
        end

        def token
          parameters[:oauth_token]
        end

        def token_secret
          parameters[:token_secret]
        end

        def signature_method
          parameters[:oauth_signature_method]
        end

        def signature
          parameters[:oauth_signature]
        end

        def consumer_principal
          parameters[:consumer_principal]
        end

        def realm
          parameters[:realm]
        end

        def signature_base_string
          base = [method, normalized_uri, normalized_parameters]
          base.map { |v| URI::DEFAULT_PARSER.escape(v.to_s.to_str, /[^a-zA-Z0-9\-\.\_\~]/) }.join('&')
        end

        protected
          def uri
            raise NotImplementedError, 'Must be implemented by subclasses'
          end
  
          def method
            raise NotImplementedError, 'Must be implemented by subclasses'
          end
  
          def parameters
            raise NotImplementedError, 'Must be implemented by subclasses'
          end

        private
        def normalized_uri
          u = URI(uri)
          normalized_uri = "#{u.scheme.downcase}://#{u.host.downcase}"
          normalized_uri += ":#{u.port}" unless uri_scheme_with_default_port(u)

          normalized_uri += if u.path != ''
                              u.path.to_s
                            else
                              '/'
                            end

          normalized_uri
        end

        def uri_scheme_with_default_port(uri)
          (uri.scheme.downcase == 'http' && uri.port == 80) || (uri.scheme.downcase == 'https' && uri.port == 443)
        end

        def normalized_parameters
          params = parameters.reject { |k, _v| k == 'oauth_signature' }

          encoded_params = params.map do |k, v|
            key = URI.encode_www_form_component(k).gsub('+', '%20')
            value = URI.encode_www_form_component(v).gsub('+', '%20')
            "#{key}=\"#{value}\""
          end

          encoded_params.join('&')
        end
      end
    end
  end
end
