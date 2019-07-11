# frozen_string_literal: true

require 'cerner/oauth1a/request_proxy/base'
require 'cerner/oauth1a/protocol'
require 'rack'

module Cerner
  module Oauth1a
    # Internal: A class providing the Rack::Request bindings in order to correctly implement the 
    # Cerner::OAuth1a::RequestProxy::Base class.
    class RackRequest < Cerner::OAuth1a::RequestProxy::Base
      proxies Rack::Request

      def method
        request.env['rack.methodoverride.original_method'] || request.request_method
      end

      def uri
        request.url
      end

      def parameters
        request_params.merge(query_params).merge(authorization_header)
      end

      private

        def query_params
          request.GET.transform_keys { |k| k.to_sym }
        end

        def request_params
          if request.content_type && request.content_type.to_s.downcase.start_with?('application/x-www-form-urlencoded')
            request.POST.transform_keys { |k| k.to_sym }
          else
            {}
          end
        end

        def authorization_header
          if request.has_header?('Authorization')
            Cerner::OAuth1a::Protocol.parse_authorization_header(request.get_header('Authorization'))
          else
            {}
          end
        end
    end
  end
end
