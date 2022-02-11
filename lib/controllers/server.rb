class W3DServerList
  class App < Sinatra::Application
    def server_match_time(server)
      diff = Time.now.to_i - Time.parse(server[:status][:started]).to_i

      hours   = diff / (1000 * 60 * 60)
      minutes = diff / (1000 * 60) % 60
      seconds = diff /  1000 % 60

      format("%02d:%02d:%02d", hours.round, minutes.round, seconds.round)
    end

    def player_count(uid, range = :week, mode = :average)
      days = [
        Array.new(24) { [] }, # sunday
        Array.new(24) { [] }, # monday
        Array.new(24) { [] }, # tuesday
        Array.new(24) { [] }, # wednesday
        Array.new(24) { [] }, # thursday
        Array.new(24) { [] }, # friday
        Array.new(24) { [] }  # saturday
      ]

      server = Server.find_by(uid: uid)

      return [] unless server

      reports = Report.all.where(server_id: server.id, created_at: 1.send(range).ago..Time.now.utc)

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
  end
end
