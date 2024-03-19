class W3DServerList
  class App < Sinatra::Application
    DATA_CACHE = {}

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

      offline_server = last_report.created_at <= 6.minutes.ago.utc

      oldest_time = offline_server ? Time.at(last_report.created_at - (Time.now.utc - 1.send(range).ago.utc)).utc : 1.send(range).ago.utc
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

      offline_server = last_report.created_at <= 6.minutes.ago.utc

      oldest_time = offline_server ? Time.at(last_report.created_at - (Time.now.utc - 1.send(range).ago.utc)).utc : 1.send(range).ago.utc
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

      offline_server = last_report.created_at <= 6.minutes.ago.utc

      oldest_time = offline_server ? Time.at(last_report.created_at - (Time.now.utc - 1.send(range).ago.utc)).utc : 1.send(range).ago.utc
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

    def game_player_count(game = nil, range = :week, mode = :average)
      cache = DATA_CACHE[format("%s:%s:%s", game, range, mode)]

      if cache && Time.now.utc - cache[:_updated_at_] < 1.hour.since(cache[:_updated_at_]).to_f
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

      oldest_time = 1.send(range).ago.utc
      newest_time = Time.now.utc

      # NOTE: Timespans greater than about a week are doomed to be inaccurate due to servers not keeping a fixed unique identifier
      #       and needing to "repair" reports to point to the current server which sometimes misassigns reports :(
      server_ids = Server.all.where(updated_at: oldest_time..newest_time).select(:id).map(&:id) unless game
      server_ids = Server.all.where(updated_at: oldest_time..newest_time).where(game: game).select(:id).map(&:id) if game
      hash = Report.where(created_at: oldest_time..newest_time).where(server_id: server_ids).where.not(map_name: [""]).select(:player_count).group("strftime('%w-%H', created_at)").group(:server_id).maximum(:player_count)

      hash.each do |key, value|
        di, hi = key.first.split("-", 2).map(&:to_i)

        server_days[di][hi] = 0 if server_days[di][hi].negative?
        server_days[di][hi] += value
      end

      _updated_at_ = Time.now.utc
      _data_ = server_days.flatten.map { |v| v.negative? ? "nil" : v.to_s }.join(",")

      DATA_CACHE[format("%s:%s:%s", game, range, mode)] = {_updated_at_: _updated_at_, _data_: _data_}

      _data_
    end

    def game_graph_timespan(oldest_time = 1.week.ago.utc, newest_time = Time.now.utc)
      # March 5, 2012 - April 5 2012

      "#{oldest_time.strftime("%B %e %Y")} — #{newest_time.strftime("%B %e %Y")}"
    end
  end
end
