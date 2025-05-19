require 'unimidi'
require 'webrick'
require 'driq'
require 'driq/webrick'
require 'drb'
require 'monitor'
require_relative 'midim'

module MidiM
  class DJ2GO2Dev
    NAME = 'Numark DJ2GO2 Touch'
    QUERY_MESSAGE = [240, 0, 32, 127, 0, 247]
    
    def initialize
      @input = UniMIDI::Input.find_by_name(NAME)
      @output = UniMIDI::Output.find_by_name(NAME)
    end
    attr_reader :input, :output

    def query_message
      @output.puts(QUERY_MESSAGE)
    end

    def reader(&blk)
      Treatment.reader(@input, &blk)
    end
  end

  class DJ2GO2WebUI
    def initialize(port=8086)
      @src = Driq::EventSource.new
      @svr = WEBrick::HTTPServer.new(:Port => port)

      @svr.mount_proc '/' do |req, res|
        res.body = body
      end
      
      @svr.mount_proc('/stream') {|req, res|
        last_event_id = req["Last-Event-ID"] || 0
        res.content_type = 'text/event-stream'
        res.chunked = true
        res.body = WEBrick::ChunkedStream.new(Driq::EventStream.new(@src, last_event_id))
      }

      @dev = MidiM::DJ2GO2Dev.new
      @dev.query_message
      Thread.new do
        @dev.reader do |it|
          @src.write(it)
        end
      end
    end

    def start
      @svr.start
    end

    def body
      <<EOS
<!DOCTYPE html>
<html>
  <head>
    <title>DJ2GO2</title>
  </head>
  <body>
    <h1>It Works!</h1>
    <p><span id="last-data" /></p>
    <dl>
    <dt>145,6</dt><dd id="145,6"></dd>
    <dt>176,9</dt><dd id="176,9"></dd>
    <dt>177,9</dt><dd id="177,9"></dd>
    <dt>191,8</dt><dd id="191,8"></dd>
    </dl>
  </body>
  <script>
  var evt = new EventSource('/stream');
  evt.onmessage = function(e) {
    let text = document.getElementById('last-data');
    let json = JSON.parse(e.data)
    text.innerHTML = "message: " + e.data;
    
    let place = document.getElementById(json.data.slice(0,2).toString());
    if (place) { place.textContent = json.data[2]};
  };
  </script>
</html>
EOS
    end
  end

  class DJ2GO2Server
    def initialize
      @chan = [nil, nil]
    end
  
    def connect(queue)
      if @chan[0].nil?
        @chan[0] = queue
        1
      elsif @chan[1].nil?
        @chan[1] = queue
        2
      else
        false
      end
    end

    def push(data)
      case data
      when [176, 6, 1]
        @chan[0]&.push(:up) rescue @chan[0] = nil
      when [176, 6, 127]
        @chan[0]&.push(:down) rescue @chan[0] = nil
      when [177, 6, 1]
        @chan[1]&.push(:up) rescue @chan[1] = nil
      when [177, 6, 127]
        @chan[1]&.push(:down) rescue @chan[1] = nil
      end
    end
  end
end

if __FILE__ == $0
  dev = MidiM::DJ2GO2Dev.new
  if false
    MidiM::DJ2GO2WebUI.new.start
  elsif true
    DRb.start_service('druby://localhost:8085', MidiM::DJ2GO2Server.new)
    dev.reader do |e|
      DRb.front.push(e[:data])
    end
  end
  gets
end