require 'unimidi'
require 'webrick'
require 'driq'
require 'driq/webrick'
require 'drb'

module MidiM
  class DJ2GO2Dev
    NAME = 'Numark DJ2GO2 Touch'
    def initialize
      @input = UniMIDI::Input.find_by_name(NAME)
    end
    attr_reader :input

    def reader
      Thread.new do
        while data = @input.gets
          data = prepare(data)
          yield(data) if data
        end
      end
    end

    def prepare(data)
      return data if data.size == 1 && data.first[:data].size == 3
      it = data.inject([]) do |nu, x|
        if (3..12) === x[:data].size && x[:data].size % 3 == 0
          x[:data].each_slice(3) {|chunk|
            nu << {data: chunk, timestamp: x[:timestamp], edited: 1}
          }
        end
        nu
      end
      pp [data, it]
      it
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
      @dev.reader {|x| @src.write(x)}
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
    json.forEach(data => {
      let place = document.getElementById(data.data.slice(0,2).toString())
      if (place) { place.textContent = data.data[2]}
    });
  };
  </script>
</html>
EOS
    end
  end
end

if __FILE__ == $0
  # dev = MidiM::DJ2GO2Dev.new
  # (dev.reader {|x| pp x}).join
  MidiM::DJ2GO2WebUI.new.start
end