require 'rubygems'
require 'bundler'
Bundler.require
require './constants.rb'
require './search.rb'

map '/assets' do
  environment = Sprockets::Environment.new
  environment.append_path 'assets/javascripts'
  environment.append_path 'assets/stylesheets'
  environment.append_path 'assets/templates'
  environment.append_path 'assets/images'
  configure :production, :test do
    environment.js_compressor  = :uglify
    environment.css_compressor = :scss
  end
  run environment
end

require './app.rb'

map '/' do
  run Sinatra::Application
end
