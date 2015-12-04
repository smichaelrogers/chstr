require 'bundler'
Bundler.require
require 'json'

class Chstr
  @@book = JSON.parse(File.read('book.json'))
end

config_file 'config.yml'
enable :sessions
set :session_secret, settings.session_secret

get '/' do
  erb :index
end

get '/show' do
  @chstr = Chstr.new
  @chstr.init_search(4)
  json @chstr.generate_json
end

post '/show' do
  @chstr = Chstr.new(params[:fen])
  @chstr.input_move(params[:from], params[:to])
  if @chstr.init_search(params[:duration])
    json @chstr.generate_json
  else
    json 'checkmate'
  end
end
