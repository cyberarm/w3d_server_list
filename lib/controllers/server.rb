class W3DServerList
  class App < Sinatra::Application
    def player_count(uid, mode = :week)
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

      reports = Report.all.where(server_id: server.id, created_at: 1.send(mode).ago..Time.now.utc)

      reports.each do |report|
        next if report.map_name.empty? # Don't count map transitions as player count is normally 0

        days[report.created_at.wday][report.created_at.hour] << report.player_count
      end

      days.each_with_index do |day, di|
        day.each_with_index do |hour, hi|
          avg = hour.sum / hour.size.to_f

          days[di][hi] = avg.nan? ? nil : avg.round
        end
      end

      days.map(&:to_s).flatten.join(",")
    end
  end
end
