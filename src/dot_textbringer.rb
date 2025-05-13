require 'drb'

DRb.start_service('druby://localhost:8085',
  {'controller' => Textbringer::Controller}
)

module Textbringer
  class Controller
    attr_reader :last_keyboard_macro

    def self.execute_keyboard_macro(queue)
      c = current
      c.next_tick { c.execute_keyboard_macro(queue.pop) }
    end
  end
end