require 'sinatra'
require 'sinatra/contrib'

class Chstr
  @@book = JSON.parse(File.read('book.json'))
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
