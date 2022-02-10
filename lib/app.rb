require "async/http/internet"
require "async/http/client"
require "sucker_punch"

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
require_relative "fetch_worker"

require_relative "controllers/server"

require_relative "models/server"
require_relative "models/report"

# Start data collection worker
W3DServerList::FetchWorker.perform_async

class W3DServerList
  NET_HOST = "localhost"
  NET_PORT = 9292
  SESSION_SECRET = "CHANGEME"

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

    not_found do
      slim :"errors/404"
    end

    error 403 do
      slim :"errors/403"
    end

    get "/css/application.css" do
      content_type "text/css"

      sass :application
    end

    get "/?" do
      slim :"servers/index"
    end

    get "/server/:id?" do
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
