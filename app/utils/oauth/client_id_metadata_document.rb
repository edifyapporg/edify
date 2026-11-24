module Oauth
  # Resolves an OAuth client that identifies itself with a Client ID Metadata Document (CIMD): its client_id is an
  # HTTPS URL, and the JSON at that URL names the client and lists its redirect URIs (#323). This is how Claude, on
  # claude.ai and in Claude Code, registers with Edify; there is no dynamic client registration.
  #
  # Only client_ids on TRUSTED_HOSTS are accepted, which also bounds what Edify ever fetches. Documents are fetched
  # only at the signed-in authorization step (Oauth::AuthorizationsController): the first time a client_id arrives,
  # and again once REFRESH_AFTER has passed. If a refresh fails, the last valid copy keeps working. The draft spec's
  # checks apply: the document's client_id must equal the URL exactly, and the redirect URIs it lists are the only
  # ones Doorkeeper will accept for that client.
  #
  # @see https://datatracker.ietf.org/doc/html/draft-ietf-oauth-client-id-metadata-document-00
  class ClientIdMetadataDocument
    TRUSTED_HOSTS = %w[claude.ai].freeze
    REFRESH_AFTER = 1.day
    MAX_NAME_LENGTH = 100

    # Fetches a document over HTTPS, with no redirects, short timeouts and a size limit. Separate so specs can stub
    # the network.
    module Fetcher
      MAX_BYTES = 5_120
      TIMEOUT_SECONDS = 3
      class Error < StandardError
      end

      # @param uri [URI::HTTPS]
      # @return [String] the response body
      # @raise [Error] on any non-200 response, an oversized body, or a network failure
      def self.call(uri)
        ::Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                              open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
          read(http, uri)
        end
      rescue ::Timeout::Error, ::SystemCallError, ::SocketError, ::IOError, ::OpenSSL::SSL::SSLError,
             ::Net::HTTPBadResponse, ::Net::ProtocolError => e
        raise Error, "#{e.class}: #{e.message}"
      end

      def self.read(http, uri)
        body = +""
        http.request(::Net::HTTP::Get.new(uri, "Accept" => "application/json")) do |response|
          raise Error, "HTTP #{response.code}" unless response.is_a?(::Net::HTTPOK)

          response.read_body do |chunk|
            body << chunk
            raise Error, "larger than #{MAX_BYTES} bytes" if body.bytesize > MAX_BYTES
          end
        end
        body
      end
      private_class_method :read
    end

    # @param uid [#to_s] a client_id as the client sent it
    # @return [Boolean] true for an https URL with a path on a trusted host, without credentials, a port or a fragment
    def self.client_id?(uid)
      uri = ::URI.parse(uid.to_s)
      uri.is_a?(::URI::HTTPS) && TRUSTED_HOSTS.include?(uri.host) && uri.port == 443 && uri.path.length > 1 &&
        uri.userinfo.nil? && uri.fragment.nil?
    rescue ::URI::InvalidURIError
      false
    end

    attr_reader :client_id

    # @param client_id [String] a URL for which .client_id? is true
    def initialize(client_id)
      @client_id = client_id
    end

    # @return [OauthApplication, nil] the client, created or refreshed from its document as needed, or nil when it has
    #   never been fetched successfully
    def application
      existing = ::OauthApplication.find_by(uid: client_id)
      return existing if existing && !stale?(existing)

      save_from_document(existing || ::OauthApplication.new(uid: client_id)) || existing
    rescue ::ActiveRecord::RecordNotUnique
      # Another request created it at the same moment.
      ::OauthApplication.find_by(uid: client_id)
    end

    private

    def stale?(application)
      application.metadata_fetched_at.nil? || application.metadata_fetched_at < REFRESH_AFTER.ago
    end

    # @return [OauthApplication, nil] the saved client, or nil if the document could not be fetched or is invalid
    def save_from_document(application)
      metadata = fetch_metadata
      return unless metadata

      application.assign_attributes(
        name: metadata.fetch("client_name").strip.truncate(MAX_NAME_LENGTH),
        redirect_uri: metadata.fetch("redirect_uris").join("\n"),
        confidential: false,
        scopes: ::Doorkeeper.config.default_scopes.to_s,
        metadata_fetched_at: ::Time.current
      )
      return application if application.save

      log("its redirect URIs were rejected: #{application.errors.full_messages.to_sentence}")
      # The caller falls back to the last good copy, so it must not keep the rejected values.
      application.reload if application.persisted?
      nil
    end

    # @return [Hash, nil]
    def fetch_metadata
      metadata = ::JSON.parse(Fetcher.call(::URI.parse(client_id)))
      problem = problem_with(metadata)
      return metadata unless problem

      log(problem)
      nil
    rescue Fetcher::Error, ::JSON::ParserError => e
      log("it could not be fetched: #{e.message}")
      nil
    end

    # @return [String, nil] why the document can't be used, or nil when it can
    def problem_with(metadata)
      return "it is not a JSON object" unless metadata.is_a?(::Hash)
      return "its client_id does not match its URL" unless metadata["client_id"] == client_id
      return "it has no client_name" unless metadata["client_name"].is_a?(::String) && metadata["client_name"].present?

      redirect_uris = metadata["redirect_uris"]
      return if redirect_uris.is_a?(::Array) && redirect_uris.any? && redirect_uris.all?(::String)

      "it has no list of redirect_uris"
    end

    def log(problem)
      ::Rails.logger.warn("[OAuth] Client ID Metadata Document #{client_id} not used: #{problem}")
    end
  end
end
