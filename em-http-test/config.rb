class Info
  module Collector
    class << self
        attr_accessor :config
        def configure
            c = self.config ||= Config.new
            yield c
        end
    end

    class Config
        attr_accessor :debug

        def initialize
            self.debug = false
        end
    end
  end
end
