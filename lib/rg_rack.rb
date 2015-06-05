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
    when "/" then Rack::Response.new(render("index.html.erb"))
    when "/guess" then guess
    when "/start" then start
    when '/hint' then hint
    else Rack::Response.new("Not Found", 404)
    end
  end

  def render(template)
    path = File.expand_path("../views/#{template}", __FILE__)
    ERB.new(File.read(path)).result(binding)
  end

  def load(cookie)
    YAML::load(@request.cookies[cookie])
  end

  def dump(name)
    YAML::dump(name)
  end

  def guess_log
    @request.cookies["guess_log"].split('*').reject{|i| i == 'invalid' || i.empty?}.reverse || [] if @request.cookies["guess_log"]
  end

  def flash
    if @request.cookies["guess_log"]
      'Invalid guess, try again!' if @request.cookies["guess_log"].split('*').last == 'invalid'
    end
  end

  def attempt
    YAML::load(@request.cookies['var']).attempts if @request.cookies['var']
  end

  def help
    @request.cookies['hint']
  end

  def start
    @game.start
    Rack::Response.new do |response|
      response.set_cookie("guess_log", '*')
      response.set_cookie("hint", '')
      response.set_cookie('var', dump(@game))
      response.redirect("/")
    end
  end

  def guess
    Rack::Response.new do |response|
      @game = load('var')
      response.set_cookie("guess_log", @request.cookies["guess_log"] + "*" + @game.compare(@request.params["guess"]))
      response.set_cookie('var', dump(@game))
      response.redirect("/")
    end
  end

  def hint
    @game = YAML::load(@request.cookies['var'])
    Rack::Response.new do |response|
      response.set_cookie("hint", @game.compare('hint'))
      response.set_cookie('var', dump(@game))
      response.redirect("/")
    end
  end
end
