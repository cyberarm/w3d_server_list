require "roda"
require "excon"
require "async"
require "async/http/internet/instance"
require "json"
require "sucker_punch"
require "sass-embedded"
require "slim"
require "sequel"

ENV["RACK_ENV"] ||= "development"

DB = Sequel.connect("sqlite://./db/#{ENV["RACK_ENV"]}.db")
# Log sequel queries to make debugging wrong or long queries easier
DB.loggers << Logger.new($stdout) if ENV["RACK_ENV"] == "development"

# Require the database models
require_relative "lib/models/report"
require_relative "lib/models/server"
require_relative "lib/models/test_player"
require_relative "lib/models/test_session"

# Require workers
require_relative "lib/workers/fetch_worker"
require_relative "lib/workers/repair_worker"
require_relative "lib/workers/roster_worker"

# Require misc.
require_relative "lib/memstore"

module W3DServerList
  NET_HOST = "localhost"
  NET_PORT = 9292
  CONFIG = JSON.parse(File.read("config.json"), symbolize_names: true)
  SESSION_SECRET = CONFIG[:session_secret]
  TEST_SESSIONS_TOKEN = CONFIG[:test_sessions_token]
  raise "TEST_SESSIONS_TOKEN is null or empty!" unless TEST_SESSIONS_TOKEN.to_s.length > 10

  class App < Roda
    DATA_CACHE = {}

    # Don't start workers when running rake tasks
    unless defined?(Rake)
      # Start data collection worker
      W3DServerList::FetchWorker.perform_async

      # Repair incorrectly creating a new server when its uid changes on game server restart
      W3DServerList::RepairWorker.perform_async

      # Track attendance of test sessions
      W3DServerList::RosterWorker.perform_async
    end

    plugin :sinatra_helpers
    plugin :slash_path_empty
    plugin :halt
    plugin :head
    plugin :default_headers, "Access-Control-Allow-Origin" => "*"

    plugin :public
    plugin :sessions, secret: SESSION_SECRET
    plugin :additional_render_engines, [:slim, :sass]
    plugin :render
    plugin :type_routing
    plugin :all_verbs
    plugin :heartbeat
    plugin :flash
    plugin :route_csrf
    plugin :common_logger
    plugin :environments
    plugin :json
    plugin :cookies
    plugin :content_for
    plugin :request_headers
    plugin :status_handler
    plugin :exception_page
    plugin :error_handler do |e|
      next exception_page(e) if ENV["RACK_ENV"] == "development"
    end

    status_handler(404) do
      view :"errors/404"
    end

    route do |r|
      r.public

      r.root do
        current_time = Time.now.utc
        servers = Server.order(Sequel.desc(:player_count), Sequel.desc(:game)).all
        @online_servers = servers.select { |s| s.updated_at >= time_minutes_ago(6) }
        @offline_servers = servers.select { |s| s.updated_at < time_minutes_ago(6) }

        view :"servers/index"
      end

      # Server listing
      r.on "server" do

        r.get String do |uid|
          @server = Server.first(uid: uid)
          r.halt 404 unless @server

          view :"servers/show"
        end
      end

      r.on "test_sessions" do
        halt 401, "Not authorized" unless authorized_to_view_test_sessions?

        r.on Integer do |event_id|
          @test_session = TestSession.first(event_id: params[:event_id])

          halt 404 unless @test_session

          if !@test_session.testing_roster.empty?
            @testing_roster = JSON.parse(@test_session.testing_roster, symbolize_names: true)
          else
            @testing_roster = W3DServerList::MemStore.data.dig(:tester_roster, :users)
          end

          @testing_roster.each { |t| @test_session_absent_testers << t }

          @test_session_players.each do |player|
            @test_session_absent_testers.delete_if { |t| (t[:alternate] || t[:name]).downcase == player.nickname.downcase || t[:name].downcase == player.nickname.downcase }
          end

          halt 404 unless @test_session

          view :"test_sessions/show"
        end
      end

      r.is "css/application.css" do
        content_type(:css)
        Sass.compile("views/application.sass").css
      end
    end

    def time_minutes_ago(minutes)
      Time.at(Time.now.utc - 60 * minutes).utc
    end

    def time_hours_ago(hours)
      Time.at(Time.now.utc - 60 * 60 * hours).utc
    end

    def time_days_ago(days)
      Time.at(Time.now.utc - 60 * 60 * 24 * days).utc
    end

    def time_weeks_ago(weeks)
      Time.at(Time.now.utc - 60 * 60 * 24 * 7 * weeks).utc
    end

    def time_months_ago(months)
      Time.at(Time.now.utc - 60 * 60 * 24 * 30 * months).utc # assumes a month is 30 days... close enough for our use case, probably.
    end

    def kd_ratio(player)
      ratio = (player[:kills].to_f / player[:deaths].to_f).round(1)

      if ratio == Float::INFINITY
        player[:kills]
      elsif ratio.nan?
        0.0
      else
        ratio
      end
    end

    def server_match_time(gsh_server)
      return "00:00:00" unless gsh_server

      diff = Time.now.to_i - Time.parse(gsh_server[:status][:started]).to_i

      hours   = diff / (60 * 60)
      minutes = (diff / 60) % 60
      seconds = diff % 60

      format("%02d:%02d:%02d", hours.round, minutes.round, seconds.round)
    end

    def player_count(server, last_report, range = :week, mode = :average)
      days = [
        Array.new(24) { [] }, # sunday
        Array.new(24) { [] }, # monday
        Array.new(24) { [] }, # tuesday
        Array.new(24) { [] }, # wednesday
        Array.new(24) { [] }, # thursday
        Array.new(24) { [] }, # friday
        Array.new(24) { [] }  # saturday
      ]

      return [] unless server
      return [] unless last_report

      offline_server = last_report.created_at <= time_minutes_ago(6)

      timespan = send(:"time_#{range}s_ago", 1)
      oldest_time = offline_server ? Time.at(last_report.created_at - timespan) : timespan
      newest_time = offline_server ? last_report.created_at : Time.now.utc

      reports = server.reports.all.where(created_at: oldest_time..newest_time)

      reports.each do |report|
        next if report.map_name.empty? # Don't count map transitions as player count is normally 0

        days[report.created_at.wday][report.created_at.hour] << report.player_count
      end

      days.each_with_index do |day, di|
        day.each_with_index do |hour, hi|
          case mode
          when :average
            avg = hour.sum / hour.size.to_f

            days[di][hi] = avg.nan? ? nil : avg.round
          when :max
            days[di][hi] = hour.max
          end
        end
      end

      days.flatten.map { |v| v.nil? ? "nil" : v.to_s }.join(",")
    end

    def graph_timespan(last_report, range)
      # March 5, 2012 - April 5 2012

      offline_server = last_report.created_at <= time_minutes_ago(6)

      timespan = send(:"time_#{range}s_ago", 1)
      oldest_time = offline_server ? Time.at(last_report.created_at - timespan) : timespan
      newest_time = offline_server ? last_report.created_at : Time.now.utc

      "#{oldest_time.strftime("%B %e %Y")} — #{newest_time.strftime("%B %e %Y")}"
    end

    def player_count(server, last_report, range = :week, mode = :average)
      days = [
        Array.new(24) { [] }, # sunday
        Array.new(24) { [] }, # monday
        Array.new(24) { [] }, # tuesday
        Array.new(24) { [] }, # wednesday
        Array.new(24) { [] }, # thursday
        Array.new(24) { [] }, # friday
        Array.new(24) { [] }  # saturday
      ]

      return [] unless server
      return [] unless last_report

      offline_server = last_report.created_at <= time_minutes_ago(6)

      timespan = send(:"time_#{range}s_ago", 1)
      oldest_time = offline_server ? Time.at(last_report.created_at - timespan) : timespan
      newest_time = offline_server ? last_report.created_at : Time.now.utc

      reports = server.reports_dataset.where(created_at: oldest_time..newest_time).where{ Sequel.~(map_name: "") }.all

      reports.each do |report|
        next if report.map_name.empty? # Don't count map transitions as player count is normally 0

        days[report.created_at.wday][report.created_at.hour] << report.player_count
      end

      days.each_with_index do |day, di|
        day.each_with_index do |hour, hi|
          case mode
          when :average
            avg = hour.sum / hour.size.to_f

            days[di][hi] = avg.nan? ? nil : avg.round
          when :max
            days[di][hi] = hour.max
          end
        end
      end

      days.flatten.map { |v| v.nil? ? "nil" : v.to_s }.join(",")
    end

    def game_player_count(game = nil, range = :week, mode = :average)
      cache = DATA_CACHE[format("%s:%s:%s", game, range, mode)]

      if cache && Time.now.utc - cache[:_updated_at_] < Time.at(cache[:_updated_at_] + 60 * 60).to_f
        return cache[:_data_]
      end

      server_days = [
        Array.new(24) { -1 }, # sunday
        Array.new(24) { -1 }, # monday
        Array.new(24) { -1 }, # tuesday
        Array.new(24) { -1 }, # wednesday
        Array.new(24) { -1 }, # thursday
        Array.new(24) { -1 }, # friday
        Array.new(24) { -1 }  # saturday
      ]

      oldest_time = send(:"time_#{range}s_ago", 1)
      newest_time = Time.now.utc

      # NOTE: Timespans greater than about a week are doomed to be inaccurate due to servers not keeping a fixed unique identifier
      #       and needing to "repair" reports to point to the current server which sometimes misassigns reports :(
      server_ids = Server.select(:id).where(updated_at: oldest_time..newest_time).map(&:id) unless game
      server_ids = Server.select(:id).where(updated_at: oldest_time..newest_time, game: game).map(&:id) if game
      hash = Report.select{ [player_count, created_at] }.where(created_at: oldest_time..newest_time, server_id: server_ids).where{ Sequel.~(map_name: "") }.all.group_by { |r| r.created_at.utc.strftime("%w-%H") } #.max(:player_count)

      hash.each do |key, values|
        di, hi = key.split("-", 2).map(&:to_i)

        server_days[di][hi] = 0 if server_days[di][hi].negative?
        server_days[di][hi] += values.map(&:player_count).max
      end

      _updated_at_ = Time.now.utc
      _data_ = server_days.flatten.map { |v| v.negative? ? "nil" : v.to_s }.join(",")

      DATA_CACHE[format("%s:%s:%s", game, range, mode)] = {_updated_at_: _updated_at_, _data_: _data_}

      _data_
    end

    def game_graph_timespan(oldest_time = Time.at(Time.now.utc - 60 * 60 * 24 * 7), newest_time = Time.now.utc)
      # March 5, 2012 - April 5 2012

      "#{oldest_time.strftime("%B %e %Y")} — #{newest_time.strftime("%B %e %Y")}"
    end

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
      # FIXME!
      return false

      pp request, response
      if (r && r.params[:token] == W3DServerList::TEST_SESSIONS_TOKEN) || cookies[:test_sessions_token] == W3DServerList::TEST_SESSIONS_TOKEN
        Sinatra::Application.set(:cookie_options) do
          { expires: Time.now.utc + 30.days }
        end

        cookies[:test_sessions_token] = W3DServerList::TEST_SESSIONS_TOKEN

        return true
      end

      false
    end
  end
end
