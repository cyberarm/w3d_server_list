class W3DServerList
  class RepairWorker # Reattach reports to the correct server since server uid are not persistent
    include SuckerPunch::Job

    def perform
      # Schedule next run before crashy code
      W3DServerList::RepairWorker.perform_in(60 * 60) # Update every hour

      ActiveRecord::Base.connection_pool.with_connection do
        duplicates = {}

        Server.all.each do |server|
          key = "#{server.address}:#{server.port}"
          duplicates[key] ||= []

          # Collect duplicate servers
          duplicates[key] << server
        end

        duplicates.each do |key, list|
          next unless list.size > 1

          target_server = list.pop

          list.each do |server|
            ActiveRecord::Base.transaction do
              # Move reports to newest server
              server.reports.update_all(server_id: target_server.id)

              # Remove duplicate servers
              server.destroy
            end
          end
        end

        # Find duplicates by name i.e. servers that have changed address/port but kept name
        duplicates = {}

        Server.all.each do |server|
          key = (server.hostname == "RenCorner AOW" || server.hostname == "RenCorner Marathon") ? "RenCorner Marathon" : server.hostname
          duplicates[key] ||= []

          # Collect duplicate servers
          duplicates[key] << server
        end

        duplicates.each do |key, list|
          next unless list.size > 1

          target_server = list.pop

          list.each do |server|
            ActiveRecord::Base.transaction do
              # Move reports to newest server
              server.reports.update_all(server_id: target_server.id)

              # Remove duplicate servers
              server.destroy
            end
          end
        end
      end
    end
  end
end
