# frozen_string_literal: true

require 'spec_helper'
require 'mock_access_token_server'

require 'base64'
require 'cerner/oauth1a/access_token_agent'
require 'cerner/oauth1a/access_token'
require 'cerner/oauth1a/oauth_error'
require 'json'

RSpec.describe Cerner::OAuth1a::AccessTokenAgent do
  describe '#realm_eql?' do
    context 'initalized realm_aliases to empty' do
      it 'returns true' do
        agent = Cerner::OAuth1a::AccessTokenAgent.new(
          access_token_url: 'https://oauth-api.cerner.com/oauth/access',
          consumer_key: 'CONSUMER KEY',
          consumer_secret: 'CONSUMER SECRET',
          realm_aliases: []
        )
        expect(agent.realm_eql?('https://oauth-api.cerner.com')).to be true
      end

      it 'returns false' do
        agent = Cerner::OAuth1a::AccessTokenAgent.new(
          access_token_url: 'https://api.cernercare.com/oauth/access',
          consumer_key: 'CONSUMER KEY',
          consumer_secret: 'CONSUMER SECRET',
          realm_aliases: []
        )
        expect(agent.realm_eql?('https://oauth-api.cerner.com')).to be false
      end
    end

    context 'initalized realm_aliases to default' do
      it 'returns true when the same' do
        agent = Cerner::OAuth1a::AccessTokenAgent.new(
          access_token_url: 'https://oauth-api.cerner.com/oauth/access',
          consumer_key: 'CONSUMER KEY',
          consumer_secret: 'CONSUMER SECRET'
        )
        expect(agent.realm_eql?('https://oauth-api.cerner.com')).to be true
      end

      it 'returns true when an alias' do
        agent = Cerner::OAuth1a::AccessTokenAgent.new(
          access_token_url: 'https://api.cernercare.com/oauth/access',
          consumer_key: 'CONSUMER KEY',
          consumer_secret: 'CONSUMER SECRET'
        )
        expect(agent.realm_eql?('https://oauth-api.cerner.com')).to be true
      end

      it 'returns false' do
        agent = Cerner::OAuth1a::AccessTokenAgent.new(
          access_token_url: 'https://api.cernercare.com/oauth/access',
          consumer_key: 'CONSUMER KEY',
          consumer_secret: 'CONSUMER SECRET'
        )
        expect(agent.realm_eql?('https://not-equal')).to be false
      end
    end
  end

  describe '#retrieve_keys' do
    before(:all) do
      @server = MockAccessTokenServer.new(
        [
          {
            path: '/oauth/access', response: {
              status: 200,
              content_type: 'application/x-www-form-urlencoded',
              body: 'oauth_token=TOKEN'\
                '&oauth_token_secret=TOKEN%20SECRET'\
                '&oauth_session_handle=SESSION'\
                '&oauth_expires_in=3600'\
                '&oauth_authorization_expires_in=86400'
            }
          },
          {
            path: '/oauth/access/keys/1', response: {
              status: 200,
              content_type: 'application/json',
              body: JSON.generate(
                aesKey: {
                  secretKey: Base64.encode64('123456')
                },
                rsaKey: {
                  publicKey: Base64.encode64('789012')
                }
              )
            }
          },
          {
            path: '/oauth/access/keys/token_rejected', response: {
              status: 401,
              content_type: 'text/plain',
              www_authenticate: 'OAuth realm="http://localhost", oauth_problem="token_rejected"',
              body: 'TOKEN REJECTED'
            }
          },
          {
            path: '/oauth/access/keys/missing_secret_key', response: {
              status: 200,
              content_type: 'application/json',
              body: JSON.generate(
                rsaKey: {
                  publicKey: Base64.encode64('789012')
                }
              )
            }
          },
          {
            path: '/oauth/access/keys/missing_public_key', response: {
              status: 200,
              content_type: 'application/json',
              body: JSON.generate(
                aesKey: {
                  secretKey: Base64.encode64('123456')
                }
              )
            }
          }
        ]
      )
      @server.startup
    end

    after(:all) do
      @server.shutdown
    end

    it 'gets valid keys' do
      agent = Cerner::OAuth1a::AccessTokenAgent.new(
        access_token_url: "#{@server.base_uri}/oauth/access",
        consumer_key: 'CONSUMER KEY',
        consumer_secret: 'CONSUMER SECRET'
      )
      keys = agent.retrieve_keys('1')
      expect(keys.version).to eq('1')
      expect(keys.aes_secret_key).to eq('123456')
      expect(keys.rsa_public_key).to eq('789012')
    end

    it 'throw OAuthError with token_rejected oauth_problem' do
      agent = Cerner::OAuth1a::AccessTokenAgent.new(
        access_token_url: "#{@server.base_uri}/oauth/access",
        consumer_key: 'CONSUMER KEY',
        consumer_secret: 'CONSUMER SECRET'
      )
      expect { agent.retrieve_keys('token_rejected') }.to raise_error do |error|
        expect(error).to be_a(Cerner::OAuth1a::OAuthError)
        expect(error.message).to include 'token_rejected'
        expect(error.to_http_www_authenticate_header).to include "realm=\"#{@server.base_uri}\""
      end
    end

    it 'throws OAuthError when the response is missing the secret key' do
      agent = Cerner::OAuth1a::AccessTokenAgent.new(
        access_token_url: "#{@server.base_uri}/oauth/access",
        consumer_key: 'CONSUMER KEY',
        consumer_secret: 'CONSUMER SECRET'
      )
      expect { agent.retrieve_keys('missing_secret_key') }.to raise_error do |error|
        expect(error).to be_a(Cerner::OAuth1a::OAuthError)
        expect(error.message).to include 'AES secret key'
        expect(error.to_http_www_authenticate_header).to include "realm=\"#{@server.base_uri}\""
      end
    end

    it 'throws OAuthError when the response is missing the public key' do
      agent = Cerner::OAuth1a::AccessTokenAgent.new(
        access_token_url: "#{@server.base_uri}/oauth/access",
        consumer_key: 'CONSUMER KEY',
        consumer_secret: 'CONSUMER SECRET'
      )
      expect { agent.retrieve_keys('missing_public_key') }.to raise_error do |error|
        expect(error).to be_a(Cerner::OAuth1a::OAuthError)
        expect(error.message).to include 'RSA public key'
        expect(error.to_http_www_authenticate_header).to include "realm=\"#{@server.base_uri}\""
      end
    end
  end

  describe '#retrieve' do
    before(:all) do
      @server = MockAccessTokenServer.new(
        [
          {
            path: '/oauth/access_success', response: {
              status: 200,
              content_type: 'application/x-www-form-urlencoded',
              body: 'oauth_token=TOKEN'\
                '&oauth_token_secret=TOKEN%20SECRET'\
                '&oauth_session_handle=SESSION'\
                '&oauth_expires_in=3600'\
                '&oauth_authorization_expires_in=86400'
            }
          },
          {
            path: '/oauth/access_token_rejected', response: {
              status: 401,
              content_type: 'text/plain',
              www_authenticate: 'OAuth realm="http://Flocalhost", oauth_problem="token_rejected"',
              body: 'TOKEN REJECTED'
            }
          }
        ]
      )
      @server.startup
    end

    after(:all) do
      @server.shutdown
    end

    it 'gets a valid access token' do
      agent = Cerner::OAuth1a::AccessTokenAgent.new(
        access_token_url: "#{@server.base_uri}/oauth/access_success",
        consumer_key: 'CONSUMER KEY',
        consumer_secret: 'CONSUMER SECRET',
        cache_access_tokens: false
      )
      access_token = agent.retrieve
      expect(access_token.consumer_key).to eq 'CONSUMER KEY'
      expect(access_token.token).to eq 'TOKEN'
      expect(access_token.token_secret).to eq 'TOKEN SECRET'
      expect(access_token.realm).to eq @server.base_uri
    end

    it 'throw OAuthError with token_rejected oauth_problem' do
      agent = Cerner::OAuth1a::AccessTokenAgent.new(
        access_token_url: "#{@server.base_uri}/oauth/access_token_rejected",
        consumer_key: 'CONSUMER KEY',
        consumer_secret: 'CONSUMER SECRET',
        cache_access_tokens: false
      )
      expect { agent.retrieve }.to raise_error do |error|
        expect(error).to be_a(Cerner::OAuth1a::OAuthError)
        expect(error.message).to include 'token_rejected'
        expect(error.to_http_www_authenticate_header).to include "realm=\"#{@server.base_uri}\""
      end
    end
  end

  describe '#initialize' do
    it 'sets the open_timeout and read_timeout using to_i' do
      agent = Cerner::OAuth1a::AccessTokenAgent.new(access_token_url: 'http://localhost',
                                                    consumer_key: 'KEY',
                                                    consumer_secret: 'SECRET',
                                                    open_timeout: '10',
                                                    read_timeout: '15')
      expect(agent.instance_variable_get(:@open_timeout)).to eq(10)
      expect(agent.instance_variable_get(:@read_timeout)).to eq(15)
    end

    it 'sets the open_timeout and read_timeout as default' do
      agent = Cerner::OAuth1a::AccessTokenAgent.new(access_token_url: 'http://localhost',
                                                    consumer_key: 'KEY',
                                                    consumer_secret: 'SECRET')
      expect(agent.instance_variable_get(:@open_timeout)).to eq(5)
      expect(agent.instance_variable_get(:@read_timeout)).to eq(5)
    end

    it 'sets the open_timeout and read_timeout as default when nil' do
      agent = Cerner::OAuth1a::AccessTokenAgent.new(access_token_url: 'http://localhost',
                                                    consumer_key: 'KEY',
                                                    consumer_secret: 'SECRET',
                                                    open_timeout: nil,
                                                    read_timeout: nil)
      expect(agent.instance_variable_get(:@open_timeout)).to eq(5)
      expect(agent.instance_variable_get(:@read_timeout)).to eq(5)
    end

    it 'sets the consumer_key' do
      agent = Cerner::OAuth1a::AccessTokenAgent.new(access_token_url: 'http://localhost',
                                                    consumer_key: 'KEY',
                                                    consumer_secret: 'SECRET')
      expect(agent.consumer_key).to eq('KEY')
    end

    it 'requires a non-nil consumer_key' do
      expect do
        Cerner::OAuth1a::AccessTokenAgent.new(access_token_url: 'http://localhost',
                                              consumer_key: nil,
                                              consumer_secret: 'SECRET')
      end.to raise_error ArgumentError, /consumer_key/
    end

    it 'sets the consumer_secret' do
      agent = Cerner::OAuth1a::AccessTokenAgent.new(access_token_url: 'http://localhost',
                                                    consumer_key: 'KEY',
                                                    consumer_secret: 'SECRET')
      expect(agent.consumer_secret).to eq('SECRET')
    end

    it 'requires a non-nil consumer_secret' do
      expect do
        Cerner::OAuth1a::AccessTokenAgent.new(access_token_url: 'http://localhost',
                                              consumer_key: 'KEY',
                                              consumer_secret: nil)
      end.to raise_error ArgumentError, /consumer_secret/
    end

    it 'converts String to URI for access_token_url' do
      agent = Cerner::OAuth1a::AccessTokenAgent.new(access_token_url: 'http://localhost',
                                                    consumer_key: 'KEY',
                                                    consumer_secret: 'SECRET')
      expect(agent.access_token_url).to eq(URI('http://localhost'))
    end

    it 'accepts a URI for access_token_url' do
      fixture = URI('http://localhost')
      agent = Cerner::OAuth1a::AccessTokenAgent.new(access_token_url: fixture,
                                                    consumer_key: 'KEY',
                                                    consumer_secret: 'SECRET')
      expect(agent.access_token_url).to be(fixture)
    end

    it 'requires an HTTP URL for access_token_url' do
      expect do
        Cerner::OAuth1a::AccessTokenAgent.new(access_token_url: 'ftp://localhost',
                                              consumer_key: 'KEY',
                                              consumer_secret: 'SECRET')
      end.to raise_error ArgumentError, /access_token_url/
    end

    it 'requires a valid URL for access_token_url' do
      expect do
        Cerner::OAuth1a::AccessTokenAgent.new(access_token_url: '\\not_valid',
                                              consumer_key: 'KEY',
                                              consumer_secret: 'SECRET')
      end.to raise_error ArgumentError, /access_token_url/
    end

    it 'requires a non-nil access_token_url' do
      expect do
        Cerner::OAuth1a::AccessTokenAgent.new(access_token_url: nil,
                                              consumer_key: 'KEY',
                                              consumer_secret: 'SECRET')
      end.to raise_error ArgumentError, /access_token_url/
    end

    it 'sets the realm from the canonical root URI of the access_token_url with default http port' do
      agent = Cerner::OAuth1a::AccessTokenAgent.new(access_token_url: 'http://localhost/oauth/access',
                                                    consumer_key: 'KEY',
                                                    consumer_secret: 'SECRET')
      expect(agent.realm).to eq('http://localhost')
    end

    it 'sets the realm from the canonical root URI of the access_token_url with default https port' do
      agent = Cerner::OAuth1a::AccessTokenAgent.new(access_token_url: 'https://localhost/oauth/access',
                                                    consumer_key: 'KEY',
                                                    consumer_secret: 'SECRET')
      expect(agent.realm).to eq('https://localhost')
    end

    it 'sets the realm from the canonical root URI of the access_token_url with non-default port' do
      agent = Cerner::OAuth1a::AccessTokenAgent.new(access_token_url: 'http://localhost:8080/oauth/access',
                                                    consumer_key: 'KEY',
                                                    consumer_secret: 'SECRET')
      expect(agent.realm).to eq('http://localhost:8080')
    end
  end
end
