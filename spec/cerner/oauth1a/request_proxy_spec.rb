# frozen_string_literal: true

require 'spec_helper'
require 'cerner/oauth1a/request_proxy'
require 'cerner/oauth1a/request_proxy/rack_request'
require 'net/http'
require 'rack'

RSpec.describe Cerner::OAuth1a::RequestProxy do
  rack_request = Rack::Request.new(Rack::MockRequest.env_for("http://example.com:8080?a=2", {'method': 'GET'}))

  describe '.proxy' do
    context 'raises error' do
      it 'when there are no available proxies' do
        expect do
          Cerner::OAuth1a::RequestProxy.proxy(Net::HTTP::Get.new(URI.parse("http://example.com:8080?a=2")))
        end.to(
          raise_error(Cerner::OAuth1a::OAuthError, /unsupported_request_type/)
        )
      end

      it 'when the class is not a request type' do
        expect do
          Cerner::OAuth1a::RequestProxy.proxy(RSpec)
        end.to(
          raise_error(Cerner::OAuth1a::OAuthError, /unsupported_request_type/)
        )
      end

      it 'when the class is of type Cerner::OAuth1a::RequestProxy::Base' do
        expect do
          Cerner::OAuth1a::RequestProxy.proxy(Cerner::OAuth1a::RequestProxy::Base.new(rack_request))
        end.to(
          raise_error(Cerner::OAuth1a::OAuthError, /unsupported_request_type/)
        )
      end
    end

    context 'returns a request class' do
      it 'when the request has a registered proxy to handle the request' do
        request_class = Cerner::OAuth1a::RequestProxy.proxy(rack_request)

        expect(request_class).to be_a(Cerner::OAuth1a::RequestProxy::Base)
      end

      class Test < Rack::Request
        def initialize(request)
          super(request)
        end
      end

      it 'when the request superclass has a registered proxy to handle the request' do
          request_class = Cerner::OAuth1a::RequestProxy.proxy(Test.new(Rack::MockRequest.env_for("http://example.com:8080?a=2", {'method': 'GET'})))
          
          expect(request_class).to be_a(Cerner::OAuth1a::RequestProxy::Base)
      end
    end
  end
end