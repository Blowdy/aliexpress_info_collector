class Info
  module Collector
    class Seller
      def initialize(options = {})
        attr_accessor :catagory_uri, :catagory_name

        options.keys.each do |k|
          eval("self.#{k} = options[k]")
        end
      end

      def start
      end
    end
  end
end
