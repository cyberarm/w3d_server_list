# require "async/http/internet"
# require "async/http/client"
require "excon"
require "csv"
require "sucker_punch"
require "sassc"

require "sinatra/base"

require "sinatra/cookies"
require "sinatra/reloader"
require "sinatra/content_for"
require "sinatra/namespace"

require "sinatra/flash"

require "sinatra/activerecord"

# require "opal"
# require "opal-browser"
# require "uglifier"

require_relative "memstore"
require_relative "workers/fetch_worker"
require_relative "workers/repair_worker"
require_relative "workers/roster_worker"

require_relative "controllers/server"
require_relative "controllers/test_sessions"

require_relative "models/server"
require_relative "models/report"
require_relative "models/test_session"
require_relative "models/test_player"

class W3DServerList
  NET_HOST = "localhost"
  NET_PORT = 9292
  CONFIG = JSON.parse(File.read("config.json"), symbolize_names: true)
  SESSION_SECRET = CONFIG[:session_secret]
  TEST_SESSIONS_TOKEN = CONFIG[:test_sessions_token]
  raise "TEST_SESSIONS_TOKEN is null or empty!" unless TEST_SESSIONS_TOKEN.to_s.length > 10

  class App < Sinatra::Application
    set :root, Dir.pwd
    set :bind, NET_HOST
    set :port, NET_PORT
    set :session_secret, SESSION_SECRET
    set :unallowed_paths, [".", ".."]
    set :static_cache_control, [:public, :max_age => 60 * 60 * 24 * 7]

    ENV["SASS_PATH"] = Dir.pwd

    enable :sessions, :logging
    file = File.new("#{settings.root}/logs/#{settings.environment}.log", 'a+')
    file.sync = true
    use Rack::CommonLogger, file
    use Rack::Protection

    register Sinatra::Flash
    register Sinatra::Namespace # Enables cleaner code
    register Sinatra::ActiveRecordExtension

    helpers Sinatra::ContentFor
    helpers Sinatra::Cookies

    configure :development do
      register Sinatra::Reloader
    end

    configure :production do
      set :cookie_options, domain: "w3d.cyberarm.dev"
    end

    # Don't start workers when running rake tasks
    unless defined?(Rake)
      # Start data collection worker
      W3DServerList::FetchWorker.perform_async

      # Repair incorrectly creating a new server when its uid changes on game server restart
      W3DServerList::RepairWorker.perform_async

      # Track attendance of test sessions
      W3DServerList::RosterWorker.perform_async
    end

    not_found do
      slim :"errors/404"
    end

    error 403 do
      slim :"errors/403"
    end

    get "/css/application.css" do
      content_type "text/css"
      expires 60 * 60 * 24 * 7, :public

      string = "@import \"./views/application\""

      scss = SassC::Sass2Scss.convert(string)
      SassC::Engine.new(scss, style: :compressed).render
    end

    get "/?" do
      servers = Server.all.order(player_count: :desc, game: :asc)
      @online_servers = servers.select { |s| s.updated_at >= 6.minutes.ago } #Server.all.where(Server.arel_table[:updated_at].gt(6.minutes.ago))
      @offline_servers = servers.select { |s| s.updated_at < 6.minutes.ago } #Server.all.where(Server.arel_table[:updated_at].lt(6.minutes.ago))

      slim :"servers/index"
    end

    get "/server/:id?" do
      @server = Server.find_by(uid: params[:id])

      halt 404 unless @server

      slim :"servers/show"
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
  end
end
