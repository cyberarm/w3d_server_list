class W3DServerList
  class MemStore
    @@data = {
      server_list: [],
      server_list_updated_at: Time.now.utc
    }

    def self.data
      @@data
    end
  end
end
