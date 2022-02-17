class W3DServerList
  class FetchWorker
    include SuckerPunch::Job

    USER_AGENT = "Cyberarm's Server List"
    END_POINT = "https://gsh.w3dhub.com/listings/getAll/v2?statusLevel=2".freeze
    DEFAULT_HEADERS = [
      ["User-Agent", USER_AGENT],
      ["Accept", "application/json"]
    ].freeze

    def perform
      # Schedule next run before crashy code
      W3DServerList::FetchWorker.perform_in(5 * 60) # Update every 5 minutes


      # fetch server list
      # parse
      server_list = nil

      Sync do
        server_list = fetch_server_list
      end

      return unless server_list

      server_list.each { |server| server[:status][:numplayers] ||= 0 }

      W3DServerList::MemStore.data[:server_list] = server_list.sort_by { |server| server[:status][:numplayers] }.reverse
      W3DServerList::MemStore.data[:server_list_updated_at] = Time.now.utc

      return if ENV["RACK_ENV"] == "development"

      ActiveRecord::Base.connection_pool.with_connection do
        server_list.each do |server|
          ActiveRecord::Base.transaction do
            model = Server.find_by(uid: server[:id]) || Server.find_by(address: server[:address], port: server[:port])

            if model
              model.update(uid: server[:id], hostname: server[:status][:name])
            else
              model ||= Server.create(
                uid: server[:id],
                hostname: server[:status][:name],
                game: server[:game],
                address: server[:address],
                port: server[:port]
              )
            end

            Report.create(
              server_id: model.id,
              map_name: server[:status][:map],
              player_count: server[:status][:numplayers] || 0,
              started_at: server[:status][:started],
              remaining: server[:status][:remaining]
            )
          end
        end
      end
    end

    def fetch_server_list
      _cache_path = "_server_list_2.json"

      return JSON.parse(File.read(_cache_path), symbolize_names: true) if ENV["RACK_ENV"] == "development" && File.exist?(_cache_path)

      client = Async::HTTP::Client.new(
        Async::HTTP::Endpoint.parse(END_POINT, protocol: Async::HTTP::Protocol::HTTP11)
      )

      response = client.get(END_POINT, DEFAULT_HEADERS)

      return [] unless response.success?

      body = response.read
      File.write(_cache_path, body) if ENV["RACK_ENV"] == "development"

      JSON.parse(body, symbolize_names: true)
    end
  end
end
