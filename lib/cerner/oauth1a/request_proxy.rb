# frozen_string_literal: true

module Cerner
  module OAuth1a
    # Internal: An internal request proxy that converts incoming requests to the correct proxies
    module RequestProxy
      # Public: lists the available proxies.
      def self.available_proxies
        @available_proxies ||= {}
      end

      # Public: Proxies the request into a Cerner::OAuth1a::RequestProxy subclass.
      def self.proxy(request)
        return request if request.is_a?(Cerner::OAuth1a::RequestProxy::Base)

        klass = available_proxies[request.class]

        # Search for possible superclass matches.
        if klass.nil?
          request_parent = available_proxies.keys.find { |rc| request.is_a?(rc) }
          klass = available_proxies[request_parent]
        end

        raise UnknownRequestType, request.class.to_s unless klass

        klass.new(request)
      end
    end
  end
end
