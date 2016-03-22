
get '/' do
  erb :index
end

get '/api' do
  g = Search.new
  g.start(params[:duration].to_i)
  json g.render.to_json
end

post '/api' do
  g = Search.new(params[:fen])
  g.history = params[:history]
  g.start(params[:duration].to_i)
  json g.render.to_json
end
