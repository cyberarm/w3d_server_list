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
      Async do
        # Schedule next run before crashy code
        W3DServerList::FetchWorker.perform_in(5 * 60) # Update every 5 minutes


        # fetch server list
        # parse
        server_list = fetch_server_list

        return unless server_list

        server_list.each { |server| server[:status][:numplayers] ||= 0 }

        W3DServerList::MemStore.data[:server_list] = server_list.sort_by { |server| server[:status][:numplayers] }.reverse
        W3DServerList::MemStore.data[:server_list_updated_at] = Time.now.utc

        # ActiveRecord::Base.connection_pool.with_connection do
          # server_list.each do |server|
            # create missing servers
            # update servers
            # generate and save report
          # end
        # end
      end
    end

    def fetch_server_list
      # request = Excon.get(END_POINT, HEADERS)
      # pp request

      # JSON.parse(request.body, symbolize_names: true) if request && request.response == 200

      client = Async::HTTP::Client.new(
        Async::HTTP::Endpoint.parse(END_POINT, protocol: Async::HTTP::Protocol::HTTP11)
      )

      response = client.get(END_POINT, DEFAULT_HEADERS)
      JSON.parse(response.read, symbolize_names: true) if response.success?
    end
  end
end
