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
      when '/'          then Rack::Response.new(render("index.html.erb"))
      when '/start'     then start
      when '/guess'     then guess
      when '/hint'      then hint
      when '/save'      then save
      when '/settings'  then settings
      when '/accept'    then accept
      when '/clearstat' then clearstat
      else                   Rack::Response.new("Not Found", 404)
    end
  end

private

  def start
    @game.start(nil, sets[-1], sets[0]..sets[1])
    Rack::Response.new do |response|
      %w(hint saved adjust clearstat).each { |cookie| response.delete_cookie(cookie) }
      dump(response)
    end
  end

  def guess
    Rack::Response.new do |response|
      @game.compare(@request.params['guess'])
      save(name) if name && loose
      dump(response)
    end
  end

  def hint
    Rack::Response.new do |response|
      response.set_cookie('hint', @game.compare('hint'))
      dump(response)
    end
  end

  def save(player = @request.params['save'])
    Rack::Response.new do |response|
      player == '' ? response.delete_cookie('name') : response.set_cookie('name', player)
      @game.save(player) unless player == ''
      response.set_cookie('saved', player)
      dump(response)
    end
  end

  def settings
    Rack::Response.new do |response|
      response.set_cookie('adjust', true)
      response.redirect('/')
    end
  end

  def accept
    Rack::Response.new do |response|
      response.set_cookie('settings', "#{@request.params['first']},#{@request.params['last']},#{@request.params['length']}")
      response.redirect('/start')
    end
  end

  def clearstat
    Rack::Response.new do |response|
      if @request.params['passwd'] == 'codebreaker'
        clear_stats(response) if @request.params['all']
        clear_player(response) if statistics.keys.include?(@request.params['nick'])
      else fail(response)
      end
      response.redirect('/settings')
    end
  end

  def clear_stats(response)
    @game.statsclear
    response.set_cookie('clearstat', "All statistics deleted succesfully...")
  end

  def clear_player(response)
    @game.playerclear(@request.params['nick'])
    response.set_cookie('clearstat', "Player \"#{@request.params['nick']}\"'s information succesfully deleted.")
  end

  def fail(response)
    response.set_cookie('clearstat', "Incorrect password or wrong parameters selected.")
  end

  def clearstat_message
    @request.cookies['clearstat'] if @request.cookies['clearstat']
  end

  def dump(response)
    response.set_cookie('var', Base64.encode64(@game.to_yaml))
    response.redirect('/')
  end

  def render(template)
    path = File.expand_path("../views/#{template}", __FILE__)
    ERB.new(File.read(path), nil, '>').result(binding)
  end

  def render_stat(num, str = 'games')
    "#{num} #{num == 1 ? str[0..-2] : str}"
  end

  def guess_log(game = @game)
    game.guess_log if game.guess_log
  end

  def flash
      'Invalid guess, try again!' if @game.invalid
  end

  def attempts
    @game.attempts
  end

  def help
    @request.cookies['hint']
  end

  def player_name
    name || "UnnamedPlayer#{rand(999)}"
  end

  def name
    @request.cookies['name'] if @request.cookies['name']
  end

  def saved
    @request.cookies['saved']
  end

  def loose
    attempts && attempts < 1 && !win
  end

  def win(game = @game)
    game.win
  end

  def stat_games_played(size = @top)
    item = statistics.map { |plr, gms| [plr, gms.count] }
    stat_desc_sort(item, size).to_h
  end

  def stat_games_won(size = @top)
    item = statistics.reject{ |plr, gms| gms.keep_if{ |gm| win(gm) }.count == 0 }
    stat_desc_sort(item, size)
  end

  def stat_games_quot(size = @top)
    gmsplayed = stat_games_played(-1)
    item = stat_games_won(-1).each_with_object({}){ |(plr, gms), hsh| hsh[plr] = (100.0 * gms.count / gmsplayed[plr]).round(2) }
    stat_desc_sort(item, size)
  end

  def stat_duration(size = @top)
    item = stat_games_won(-1).each_with_object({}) { |(plr, gms), hsh| hsh[plr] = gms.map(&:duration).min }
    stat_desc_sort(item, size).reverse
  end

  def stat_win_streak(size = @top)
    item = statistics.each_with_object({}) do |(plr, gms), hsh|
      hsh[plr] = gms.map{ |gm| win(gm) }.join.gsub(/true/, '1').split('false').map(&:length).max
    end
    stat_desc_sort(item, size)
  end

  def stat_guess_count(size = @top)
    item = stat_games_won(-1).each_with_object({}){ |(plr, gms), hsh| hsh[plr] = gms.map{ |gm| gm.code_length * 2 - gm.attempts }.min }
    stat_desc_sort(item, size).reverse
  end

  def statistics
    @game.statistics ? @game.statistics : {}
  end

  def stat_desc_sort(item, size)
    item.keep_if{ |plr, param| param }.sort_by{ |plr, gms| gms.is_a?(Array) ? gms.count : gms }.reverse[0..size]
  end

  def adjust
    @request.cookies['adjust']
  end

  def sets
    sets = @request.cookies['settings'] ? @request.cookies['settings'].split(',').map(&:to_i) : [1, 6, 4]
    sets[-1] = 4 if sets[-1] < 1 || sets[-1] > 15
    (0..1).each{ |i| sets[i] = sets[i] < 0 ? 0 : sets[i] > 9 ? 9 : sets[i] }
    sets[1], sets[0], sets[2] = sets if sets[0] > sets[1]
    sets
  end

end
