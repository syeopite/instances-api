module InstancesApi::Helpers
  extend self

  module InstanceWrapperInterface
    abstract def get
  end

  # Wraps a mutex around some object
  macro create_mutex_storage(storage_name, key, value, initialize = false, type = Type)
    struct {{storage_name.id}}
      @mutex : Mutex = Mutex.new()
      {% if !initialize %}
        @{{key.id}} = {{value}}
      {% else %}
        def initialize(@{{key.id}} : {{type.id}})
        end
      {% end %}

      {{yield}}

      def get(&)
        @mutex.lock
        begin
          yield @{{key.id}}
        ensure
          @mutex.unlock
        end
      end
    end
  end

  # HTTP::Client is wrapped around a mutex just in case. There shouldn't be any fiber that will
  # access the same HTTP::Client
  create_mutex_storage("RequestClient", "client", nil, initialize: true, type: HTTP::Client) do
    def self.new(url, config : InstancesApi::Config::Provider)
      client = HTTP::Client.new(url)

      client.dns_timeout = config.http_request_timeout.seconds
      client.read_timeout = config.http_request_timeout.seconds
      client.connect_timeout = config.http_request_timeout.seconds
      client.write_timeout = config.http_request_timeout.seconds

      return new(client)
    end
  end

  @[ADI::Register]
  struct ClientProvider
    private InstancesApi::Helpers.create_mutex_storage("RequestClientsStorage", "clients", {} of String => RequestClient)
    private RequestClients = RequestClientsStorage.new

    def initialize(@config : InstancesApi::Config::Provider)
    end

    def get(&block)
      RequestClients.get(&block)
    end

    def client(url : URI)
      if !(host = url.host)
        raise Exception.new
      end

      RequestClients.get do |clients|
        if client = clients[host]?
        else
          client = Helpers::RequestClient.new(url, @config)
          clients[host] = client
        end

        return client
      end
    end
  end

  def get_serialization_ctx
    ctx = ASR::SerializationContext.new
    ctx.emit_nil = true

    return ctx
  end
end
