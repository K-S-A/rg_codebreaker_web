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
    @top = 4
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

private

  def start
    @game.start
    Rack::Response.new do |response|
      %w(hint saved).each { |cookie| response.delete_cookie(cookie) }
      dump(response)
    end
  end

  def guess
    Rack::Response.new do |response|
      @game.compare(@request.params['guess'])
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
    @game.guess_log.reverse
  end

  def flash
      'Invalid guess, try again!' if @game.invalid
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
    attempts && attempts < 1 && !win
  end

  def win
    guess_log.first && guess_log.first.include?('++++')
  end

  def stat_games_played(size = @top)
    stat_desc_sort(statistics, size)
  end

  def stat_games_won(size = @top)
    item = statistics.each { |name, games| games.reject!{ |game| game.attempts == 0 } }
    stat_desc_sort(item, size)
  end

  def stat_games_quot(size = @top)
    stat = stat_games_won(-1).each_with_object({}) {|(name, games), hsh| hsh[name] =\
      (games.count.to_f / stat_games_played(-1).to_h[name].count * 100).round(2) }
      stat_desc_sort(stat, size)
  end

  def stat_duration(size = @top)
    item = stat_games_won.each_with_object({}) { |(name, games), hsh| hsh[name] = games.map {|i| i.duration}.min }
    stat_desc_sort(item, size).reverse
  end

  def stat_win_streak
#    item = stat_games_played.each_with_object({}) { |(name, games), hsh| hsh[name] = games.map {|i| i.duration}.min }
#    stat_desc_sort(item, size)
  end

  def statistics
    @game.statistics ? @game.statistics : {}
  end

  def stat_desc_sort(item, size)
    item.sort_by { |name, games| games.is_a?(Array) ? games.count : games }.reverse[0..size]
  end

  def render(template)
    path = File.expand_path("../views/#{template}", __FILE__)
    ERB.new(File.read(path), nil, '>').result(binding)
  end

end
