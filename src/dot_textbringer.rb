require 'drb'

DRb.start_service
ro = DRbObject.new_with_uri('druby://localhost:8085')
queue = Queue.new
ro.connect(queue)

module Textbringer
  class Controller
    attr_reader :last_keyboard_macro

    def self.execute_keyboard_macro(ary)
      c = current
      c.next_tick { c.execute_keyboard_macro(ary) }
    end
  end
end

Thread.new do
  while true
    Textbringer::Controller.execute_keyboard_macro([queue.pop])
  end
end