class W3DServerList
  class FetchWorker
    include SuckerPunch::Job

    USER_AGENT = "Cyberarm's Server List".freeze
    END_POINT = "https://gsh.w3dhub.com/listings/getAll/v2?statusLevel=2".freeze
    # DEFAULT_HEADERS = [
    #   ["User-Agent", USER_AGENT],
    #   ["Accept", "application/json"]
    # ].freeze
    DEFAULT_HEADERS = {
      "User-Agent": USER_AGENT,
      "Accept": "application/json"
    }.freeze

    def perform
      # Schedule next run before crashy code
      refresh_interval = 5 * 60 # Update every 5 minutes
      W3DServerList::FetchWorker.perform_in(refresh_interval)


      # fetch server list
      # parse
      server_list = nil

      server_list = fetch_server_list

      return unless server_list

      server_list.each { |server| server[:status][:numplayers] ||= 0 }

      W3DServerList::MemStore.data[:server_list] = server_list.sort_by { |server| server[:status][:numplayers] }.reverse
      W3DServerList::MemStore.data[:server_list_updated_at] = Time.now.utc

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

        testing_servers = server_list.select { |server| server[:channel].to_s.strip.downcase == "testing" }

        testing_servers.each do |server|
          ActiveRecord::Base.transaction do
            # Find active test session
            # Record active players

            test_session = TestSession.find_by(start_time: 4.hours.ago..Time.now)

            if test_session
              # TODO: Track when a player leaves
              present_test_players = []

              server[:status][:players].each do |player|
                test_player = TestPlayer.find_by(test_session_id: test_session.id, nickname: player[:nick])

                if test_player
                  present_test_players << test_player

                  test_player.update(
                    nickname: player[:nick],
                    server_game: server[:game],
                    server_name: server[:status][:name],
                    server_address:  "#{server[:address]}:#{server[:port]}",
                    leave_time: 1.hour.from_now,
                    duration: test_player.duration + refresh_interval
                  )
                else
                  TestPlayer.create(
                    test_session_id: test_session.id,
                    nickname: player[:nick],
                    server_game: server[:game],
                    server_name: server[:status][:name],
                    server_address:  "#{server[:address]}:#{server[:port]}",
                    join_time: Time.now.utc,
                    leave_time: 1.hour.from_now,
                    duration: 0
                  )
                end
              end

              # Ensure this a "normal" array and not a ORM array where delete_if my actually DELETE the db entry
              session_test_players = test_session.test_players.map { |ply| ply }
              session_test_players.delete_if { |ply| present_test_players.any? {|tply| tply.id == ply.id } }

              # Player is absent/Left
              session_test_players.each do |player|
                next unless player.leave_time > Time.now

                player.update(leave_time: Time.now, duration: player.duration + refresh_interval)
              end
            end
          end
        end
      end
    end

    def fetch_server_list
      _cache_path = "_server_list_2.json"

      # NOTE: MAYBE REENABLE AFTER ASYNC WORKS ON WINDOWS... 😢
      # client = Async::HTTP::Client.new(
      #   Async::HTTP::Endpoint.parse(END_POINT, protocol: Async::HTTP::Protocol::HTTP11)
      # )

      # response = client.get(END_POINT, DEFAULT_HEADERS)

      # return [] unless response.success?

      # body = response.read

      response = Excon.get(END_POINT, DEFAULT_HEADERS)

      return [] unless response.status == 200

      body = response.body

      # File.write(_cache_path, body) if ENV["RACK_ENV"] == "development"

      JSON.parse(body, symbolize_names: true)
    end
  end
end