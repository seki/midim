require_relative 'dj2go2'
require 'rb-scpt'

class MyKeynote
  def initialize
    @keynote = Appscript.app('keynote')
    @name = @keynote.get(@keynote.documents.name)
    pp @name
    @last_tick = Time.now.to_f
  end
  attr_reader :name, :last_tick

  def switch_to_left
    switch_to(1)
  end

  def switch_to_right
    switch_to(2)
  end

  def switch_to(n)
    name = @keynote.windows[1].name.get
    if name == @name[n - 1]
    else
      @keynote.windows[1].document.stop rescue nil
    end
    @keynote.documents[@name[n-1]].start rescue nil
  end

  def switching
    # @keynote.windows[1].document.stop rescue nil
  end

  def cue_left
    cue(1)
  end

  def cue_right
    cue(2)
  end

  def cue(n)
    @keynote.documents[@name[n-1]].slides[1].show
  end

  def next_left
    show_next(1)
  end

  def next_right
    show_next(2)
  end

  def show_next(n)
    name = @keynote.windows[1].name.get
    if name == @name[n - 1]
      @keynote.documents[@name[n-1]].show_next rescue nil
    end
    @last_tick = Time.now.to_f
  end

  def previous_left
    show_prev(1)
  end

  def previous_right
    show_prev(2)
  end

  def show_prev(n)
    name = @keynote.windows[1].name.get
    if name == @name[n - 1]
      @keynote.documents[@name[n-1]].show_previous rescue nil
    end
    @last_tick = Time.now.to_f
  end
end

class UI
  def initialize
    @dev = MidiM::DJ2GO2Dev.new
    @dev.query_message
  end

  def main(app)
    @dev.reader do |event|
      dispatch(event, app)
      @last_event = event
    end
  end

  def dispatch(event, app)
    case event[:data]
    in [191, 8, 0]
      app.switch_to_left
    in [191, 8, 127]
      app.switch_to_right
    in [191, 8, Integer]
      case (@last_event[:data] rescue [])
      in [191, 8, 1..126]
      else
        app.switching
      end
      # nop
    in [176, 6, 1]
      app.next_left if app.last_tick < event[:timestamp]
    in [176, 6, 127]
      app.previous_left if app.last_tick < event[:timestamp]
    in [177, 6, 1]
      app.next_right if app.last_tick < event[:timestamp]
    in [177, 6, 127]
      app.previous_right if app.last_tick < event[:timestamp]
    in [128, 1, 0]
      app.cue_left
    in [129, 1, 0]
      app.cue_right
    else
      pp event
    end
  end
end


if __FILE__ == $0
  keynote = MyKeynote.new
  ui = UI.new
  ui.main(keynote)
end