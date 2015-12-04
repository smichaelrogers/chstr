require 'bundler'
Bundler.require
require 'json'

class Chstr
  @@book = JSON.parse(File.read('book.json'))
end

configure :development do
  use BetterErrors::Middleware
  BetterErrors.application_root = __dir__
end

get '/' do
  erb :index
end

get '/new' do
  puts 'new'
  @chstr = Chstr.new
  @chstr.init_search(params[:duration].to_i)
  json @chstr.gamestate.to_json
end

post '/move' do
  @chstr = Chstr.new(params[:fen])
  @chstr.input_move(params[:from], params[:to])
  @chstr.init_search(params[:duration].to_i)
  json @chstr.gamestate.to_json
end
