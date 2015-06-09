require 'erb'
require 'rg_codebreaker'
require 'base64'

class Racker
  def self.call(env)
    new(env).response.finish
  end

  def initialize(env)
    @request = Rack::Request.new(env)
    @game = @request.cookies['var'] ? YAML::load(Base64.decode64(@request.cookies['var'])) : RgCodebreaker::Game.new
    @player_name = player_name
  end

  def response
    case @request.path
      when '/'      then Rack::Response.new(render("index.html.erb"))
      when '/start' then start
      when '/guess' then guess
      when '/hint'  then hint
      when '/save' then save
      else               Rack::Response.new("Not Found", 404)
    end
  end

  def start
    @game.start
    Rack::Response.new do |response|
      %w(hint guess_log saved).each { |cookie| response.delete_cookie(cookie) }
      dump(response)
    end
  end

  def guess
    Rack::Response.new do |response|
      response.set_cookie('guess_log', "#{@request.cookies['guess_log'] || ''}*#{@game.compare(@request.params['guess'])}")
      save(@request.cookies['name']) if @request.cookies['name'] && loose
      dump(response)
    end
  end

  def hint
    Rack::Response.new do |response|
      response.set_cookie('hint', @game.compare('hint'))
      dump(response)
    end
  end

  def save(name = @request.params['save'])
    Rack::Response.new do |response|
      unless name == ''
        @game.save(name)
        response.set_cookie('name', name)
      end
      response.set_cookie('saved', name)
      dump(response)
    end
  end

  def dump(response)
    response.set_cookie('var', Base64.encode64(YAML::dump(@game)))
    response.redirect('/')
  end

  def guess_log
    @request.cookies['guess_log'].split('*').reject{|i| i == 'invalid' || i.empty?}.reverse if @request.cookies['guess_log']
  end

  def flash
      'Invalid guess, try again!' if @request.cookies['guess_log'] && @request.cookies['guess_log'].split('*').last == 'invalid'
  end

  def help
    @request.cookies['hint']
  end

  def attempts
    @game.attempts
  end

  def player_name
    @request.cookies['name'] || "UnnamedPlayer#{rand(999)}"
  end

  def saved
    @request.cookies['saved']
  end

  def loose
    attempts && attempts < 1 && !guess_log.first.include?('++++')
  end

  def win
    guess_log && guess_log.last && guess_log.first.include?('++++')
  end

  def stat_games_played
    stat_desc_sort(statistics)
  end

  def stat_games_won
    order = statistics.each { |name, games| games.reject!{ |game| game.attempts == 0 } }
    order = order.reject { |name, games| games.count == 0 }
    stat_desc_sort(order)
  end

  def stat_games_quot
    order = stat_games_won.each_with_object({}) {|item, hsh| hsh[item.first] = (item.last.count.to_f / stat_games_played.to_h[item.first].count * 100).round(2) }
    order.sort_by { |name, quot| quot }.reverse
  end

  def statistics
    @game.statistics ? @game.statistics : {}
  end

  def stat_desc_sort(item)
    item.sort_by { |name, games| games.count }.reverse
  end

  def render(template)
    path = File.expand_path("../views/#{template}", __FILE__)
    ERB.new(File.read(path), nil, '>').result(binding)
  end

end
