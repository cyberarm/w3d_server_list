class W3DServerList
  class RosterWorker # Fetch Tester Roster and List of Test Events to track attendance
    include SuckerPunch::Job

    USER_AGENT = "Cyberarm's Server List".freeze
    DEFAULT_HEADERS = {
      "User-Agent": USER_AGENT,
      "Accept": "application/json"
    }.freeze

    def perform
      # Schedule next run before crashy code
      W3DServerList::RosterWorker.perform_in(60 * 60) # Update every hour

      # Fetch Test Events
      events_response = Excon.get("https://secure.w3dhub.com/apis/w3dhub/1/get-testing-times", DEFAULT_HEADERS)

      # Fetch Tester Roster
      roster_response = Excon.get("https://secure.w3dhub.com/apis/w3dhub/1/get-testers", DEFAULT_HEADERS)

      if events_response.status == 200
        W3DServerList::MemStore.data[:test_events] = JSON.parse(events_response.body, symbolize_names: true)
        W3DServerList::MemStore.data[:test_events_updated_at] = Time.now.utc
      end

      if roster_response.status == 200
        W3DServerList::MemStore.data[:tester_roster] = JSON.parse(roster_response.body, symbolize_names: true)
        W3DServerList::MemStore.data[:tester_roster_updated_at] = Time.now.utc

        CONFIG[:exclude_testers].each do |nickname|
          W3DServerList::MemStore.data.dig(:tester_roster, :users)&.delete_if { |t| (t[:alternate] || t[:name]).downcase == nickname.downcase }
        end
      end

      ActiveRecord::Base.connection_pool.with_connection do
        # Create record for event(s)
        W3DServerList::MemStore.data.dig(:test_events, :events)&.each do |event|
          TestSession.find_or_create_by(event_id: event[:eventId], title: event[:title], start_time: Time.parse(event[:forumTime]))
        end
      end
    end
  end
end
