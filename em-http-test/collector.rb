class Info
  module Collector
    def self.start_collect
      Debugger.start if Info::Collector.config.debug == true
      Info::Collector.collect_catagory
      puts "ALL REQUEST DONE"
    end

    # 获取所有目录的url连接，并存入数据库
    def self.collect_catagory
      site = "http://www.aliexpress.com/all-wholesale-products.html"

      create_multirequest_and_add_httprequests([site],'catagory') do |doc|
        nodes = doc.css('div.sec-categories > ul > li > a').each do | var| 
           if var['href'][0..6] == 'http://'
             n = { :title => var.content, :href => var['href'] } 
             Catagory.create(n) unless Catagory.where(:href => var['href']).size > 0
             Info::Collector.info("---> Got Catagory:: name => #{var.content} ,url => #{var['href']}")
             Info::Collector.start_collect_sellers(var['href'], var.content)
           end
        end
      end
      # FIXME
      # test sellers_collect
      # Info::Collector.start_collect_sellers("http://www.aliexpress.com/category/200000361/transporting-storage.html")
    end

    #
    # 根据目录获取所有的卖家信息
    #
    def self.start_collect_sellers(catagory_uri,catagory_name = "ALL")
      create_multirequest_and_add_httprequests([catagory_uri],"page_no") do |doc|
        node = doc.css("span.page-no").first
        if node != nil
          counts = node.content.split("/").last.to_i

          #FIXME
          Info::Collector.info("Start collecting #{catagory_name} Page No.::**** #{counts} ****")
            
          sites = []
          counts.times do |c|
            sites << "#{catagory_uri[0..catagory_uri.length - 6]}/#{c+1}.html?needQuery=n"
          end

          create_multirequest_and_add_httprequests(sites, "seller_list") do |doc|
            doc.css("a.store").each do |seller|
              seller_uri = seller['href']
              #
              # uri_info = "www.example.com/:store_type/:store_number"
              #
              uri_info = seller_uri.split("/")
              seller_number = uri_info[-1]
              seller_type = uri_info[-2]

              Seller.create(
                :name => seller.content,
                :uri => seller_uri,
                :number => seller_number,
                :type => seller_type,
                :catagory_name => catagory_name
              ) unless Seller.where(:number => seller_number, :type => seller_type).size > 0
              Info::Collector.info("---> Got Seller:: Number => #{seller_number} ,name => #{seller.content}")
            end
          end
        end
      end
    end

    private

      def self.create_multirequest_and_add_httprequests(sites,type)
        sites.each do |site|
          http_request = EventMachine::HttpRequest.new(site, :connect_timeout => 20, :inactivity_timeout => 40).get
          Info::Collector.info(">>> Collecting #{type} page :: #{site}")
          http_request.callback {
            if http_request.response_header.status == 200
              html = http_request.response
              doc = Nokogiri::HTML(html)
              yield doc
            else
              failed_req(http_request,"#{type}::ResponseNot200 --> #{http_request.response_header.status}")
            end
          }
          http_request.errback  { failed_req(http_request, "#{type}::ErrBack") }
          #sleep 2
        end

       # multi = EM::MultiRequest.new
       # sites.each_with_index do |site,index|
       #   Info::Collector.info("collecting #{type} site :: #{site}")
       #   multi.add index,EM::HttpRequest.new(site).get
       # end

       # multi.callback {
       #   multi.responses[:callback].each do |index, h|
       #     if h.response_header.status == 200
       #       html = h.response
       #       doc = Nokogiri::HTML(html)
       #       yield doc
       #     else
       #       failed_req(h,type)
       #     end
       #   end
       #   multi.responses[:errback].each do |h|
       #     failed_req(h,type)
       #   end
       #   print "> "
       # }
      end

      def self.failed_req(http_request, type)
        # debugger
        puts '==================Failed======================'
        Failure.create(:type => type , :http_request => http_request.inspect)
        # debugger
        Info::Collector.info("#{type}:: #{http_request.response_header.inspect}")
        puts '==================Failed======================'
      end

      def self.info(msg)
        #return if not Info::Collector.config.debug == false
        msg = "\e[32m[Collection::Info] #{msg}\e[0m"
        puts msg
      end

  end
end
