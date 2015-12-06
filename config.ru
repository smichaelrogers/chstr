require 'rubygems'
require 'bundler'
%w(sprockets sass uglifier sinatra sinatra/contrib sinatra/reloader json ./lib/chstr).each do |dep|
  require dep
end
%w(definitions move move_generation search evaluation).each do |dep|
  require "./lib/chstr/#{dep}"
end

require './app'

set :root, File.dirname(__FILE__)
set :logging, true
map '/assets' do
  environment = Sprockets::Environment.new
  environment.append_path 'assets/javascripts'
  environment.append_path 'assets/stylesheets'
  environment.append_path 'assets/templates'
  # environment.js_compressor  = :uglify
  # environment.css_compressor = :scss
  run environment
end

map '/' do
  run Sinatra::Application
end
