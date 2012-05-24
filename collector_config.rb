class Info
  module ResClientCollector
    class << self
        attr_accessor :config
        def configure
            c = self.config ||= Config.new
            yield c
        end
    end

    class Config
        attr_accessor :debug #是否启用debug
                      # 卖家基本信息获取配置参数
        attr_accessor :sellers_threads #用户信息收集进程数
        attr_accessor :seller_sleep_time #获取卖家基本信息的请求间隔时间
        # 卖家feedback信息获取配置参数
        attr_accessor :info_products #获取用户feedback等信息，多线程情况下,队列中待处理的用户的数量
        attr_accessor :flash_info_products_time #多线程情况下,队列中数据刷新时间
        attr_accessor :info_threads # 用户feedback信息获取线程数量
        attr_accessor :info_sleep_time #获取卖家feedback信息的请求间隔时间
        # attr_accessor :info_details_sleep_time #feedback

        def initialize
            # 参数的默认值
            self.debug = false

            self.sellers_threads = 12
            self.seller_sleep_time = 2

            self.info_products = 150
            self.info_threads = 7
            self.flash_info_products_time = 20
            self.info_sleep_time = 1
        end

    end
  end
end
