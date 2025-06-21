module MidiM
  class Treatment
    DataSize = [0] * 256
    [0x80..0xbf, 0xe0..0xef, [0xf2]].map(&:to_a).flatten.each {|s| DataSize[s] = 2}
    [0xc0..0xdf, [0xf1, 0xf3]].map(&:to_a).flatten.each {|s| DataSize[s] = 1}
=begin
    (0x80..0xbf).each {|x| DataSize[x] = 2}
    (0xc0..0xdf).each {|x| DataSize[x] = 1}
    (0xe0..0xef).each {|x| DataSize[x] = 2}
    DataSize[0xf1] = 1
    DataSize[0xf2] = 2
    DataSize[0xf3] = 1
    (0xf4..0xff).each {|x| DataSize[x] = 0}
=end

    def self.reader(input)
      it = self.new.reader(input)
      return it unless block_given?
      loop do
        yield(it.gets)
      end    
    end

    def initialize
      @running = nil
      @buff = []
      @timestamp = nil
      @fiber = nil
    end

    def reader(input)
      @fiber = Fiber.new do 
        while true
          data = input.gets rescue nil
          next unless data
          data.each do |datum|
            @timestamp = datum[:timestamp]
            datum[:data].each do |atom|
              feed(atom)
            end
          end
        end
      end
      self
    end

    def feed(curr)
      case curr
      when 0..0x7f
        pp [:discard_1, curr] unless @running
        return unless @running
        @buff << curr
        yield_if_data_full
      when 0x80..0xf6
        reset_running(curr)
      when 0xf7
        yield_exclusive
      when 0xf8..0xff
        realtime_message(curr)
      end
    end

    def reset_running(curr)
      if @buff.size > 0
        pp [:discard, @buff]
      end

      @running = curr
      @buff = []
    end

    def realtime_message(curr)
      Fiber.yield({:data => [curr], :timestamp => @timestamp})
    end

    def yield_if_data_full
      if @buff.size == DataSize[@running]
        Fiber.yield({:data => [@running] + @buff, :timestamp => @timestamp})
        @buff = []
      end
    end

    def yield_exclusive
      if @running != 0xf0
        pp [:discard, @buff]
        reset_running(@cunning)
        return
      end

      Fiber.yield({:data => [@running] + @buff + [0xf7], :timestamp => @timestamp})
    end

    def gets
      @fiber.resume
    end
  end
end

if __FILE__ == $0
  require_relative 'dj2go2'

  dj2 = MidiM::DJ2GO2Dev.new
  dj2.query_message
  
  e = MidiM::Treatment.reader(dj2.input)
  loop do
    it = e.gets
    pp it
  end
end