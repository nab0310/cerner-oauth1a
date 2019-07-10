# frozen_string_literal: true

require 'cerner/oauth1a/request_proxy/base'
require 'rack'

module Cerner
  module Oauth1a
    # Internal: The conversion from a Rack::Request to an Cerner::OAuth1a::RequestProxy::Base
    class RackRequest < Cerner::OAuth1a::RequestProxy::Base
      proxies Rack::Request

      def method
        request.env['rack.methodoverride.original_method'] || request.request_method
      end

      def uri
        request.url
      end

      def parameters
        params = request_params.merge(query_params).merge(header_params)
        params.merge(options[:parameters] || {})
      end

      def signature
        parameters['oauth_signature']
      end

      protected

      def query_params
        request.GET
      end

      def request_params
        if request.content_type && request.content_type.to_s.downcase.start_with?('application/x-www-form-urlencoded')
          request.POST
        else
          {}
        end
      end
    end
  end
end
