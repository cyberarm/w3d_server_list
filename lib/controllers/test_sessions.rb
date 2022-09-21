class W3DServerList
  class App < Sinatra::Application
    def seconds_to_duration(seconds)
      if seconds < 60
        "#{seconds} seconds"
      elsif seconds > 60 && seconds < 60 * 60
        "#{(seconds / 60.0).round(1)} minutes"
      else
        "#{(seconds / 60.0 / 60.0).round(1)} hours"
      end
    end

    def authorized_to_view_test_sessions?
      if params[:token] == W3DServerList::TEST_SESSIONS_TOKEN || cookies[:test_sessions_token] == W3DServerList::TEST_SESSIONS_TOKEN
        Sinatra::Application.set(:cookie_options) do
          { expires: Time.now.utc + 30.days }
        end

        cookies[:test_sessions_token] = W3DServerList::TEST_SESSIONS_TOKEN

        return true
      end

      false
    end

    namespace "/test_sessions?" do
      get "/?" do
        halt 401, "Not authorized" unless authorized_to_view_test_sessions?

        @active_test_sessions = TestSession.all.where(start_time: 4.hours.ago..Time.now)
        @upcoming_test_sessions = TestSession.all.where(start_time: Time.now..)
        @test_session_reports = TestSession.all.where(start_time: ..Time.now)

        slim :"test_sessions/index"
      end

      get "/:event_id?" do
        halt 401, "Not authorized" unless authorized_to_view_test_sessions?

        @test_session = TestSession.find_by(event_id: params[:event_id])

        halt 404 unless @test_session

        @test_session_players = @test_session.test_players
        @test_session_absent_testers = []

        if !@test_session.testing_roster.empty?
          @testing_roster = JSON.parse(@test_session.testing_roster, symbolize_names: true)
        else
          @testing_roster = W3DServerList::MemStore.data.dig(:tester_roster, :users)
        end

        @testing_roster.each { |t| @test_session_absent_testers << t }

        @test_session_players.each do |player|
          @test_session_absent_testers.delete_if { |t| t[:alternate].downcase == player.nickname.downcase }
        end

        halt 404 unless @test_session
        slim :"test_sessions/show"
      end

      get "/:event_id/export?" do
        halt 401, "Not authorized" unless authorized_to_view_test_sessions?

        halt 500, "Not available yet."
      end
    end
  end
end
