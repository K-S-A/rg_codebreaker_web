require "erb"
require 'rg_codebreaker'
require 'yaml'

class Racker
  def self.call(env)
    new(env).response.finish
  end

  def initialize(env)
    @request = Rack::Request.new(env)
    @game = RgCodebreaker::Game.new
  end

  def response
    case @request.path
    when "/"
      Rack::Response.new(render("index.html.erb"))
    when "/guess"
      Rack::Response.new do |response|
        @game = YAML::load(@request.cookies['var'])
        response.set_cookie("guess_log", @request.cookies["guess_log"] + "*" + @game.compare(@request.params["guess"]))
        response.set_cookie('var', YAML::dump(@game))
        response.redirect("/")
      end
    when "/start"
      @game.start
      Rack::Response.new do |response|
        response.set_cookie("guess_log", '*')
        response.set_cookie("var", YAML::dump(@game))
        response.redirect("/")
      end
    else Rack::Response.new("Not Found", 404)
    end
  end

  def render(template)
    path = File.expand_path("../views/#{template}", __FILE__)
    ERB.new(File.read(path)).result(binding)
  end

  def guess_log
    @request.cookies["guess_log"].split('*').reject{|i| i == 'Invalid guess, try again:' }.reject(&:empty?).reverse || []
  end
  def flash
    'Invalid guess, try again:' if @request.cookies["guess_log"].split('*').last == 'Invalid guess, try again:'
  end
  def attempt
    @game.attempts
  end
end
