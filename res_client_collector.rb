class Info
  module ResClientCollector
    def self.start_collect
      # Debugger.start if Info::ResClientCollector.config.debug == true
      Info::ResClientCollector.collect_catagory
      # puts "ALL REQUEST DONE"
    end

    def self.start_collect_feedback_info
      Info::ResClientCollector.collect_seller_feedback_info
    end

    # 创建3个线程获取卖家的feedback等信息
    def self.collect_seller_feedback_info
      # TODO use mutil process
      # fork do
        threads = []
        seller_queue = Queue.new #创建处理队列

        seller_with_no_feedback_productor = Thread.new() do
          loop do
            limit = 100 - seller_queue.size
            if limit > 0
              sellers = Seller.where(:positive_feedback => nil).limit(limit)
              sellers.each { |seller| seller_queue << seller } unless sellers.empty?
            end
            sleep 30
            Info::ResClientCollector.info("******Got #{limit} Sellers Info ********")
          end
        end
        
        seller_info_collectors = (1..5).map do |i|
          Thread.new() do
            loop do
              if seller_queue.empty?
                sleep 1
              else
                seller = seller_queue.deq
                seller.update_attributes(:positive_feedback => "")
                                                #卖家的url末尾包含productlist.html都是没有店铺信息的
                get_seller_info_and_save(seller) if not seller_uri.include?("productlist.html") 
              end
            end
          end
        end
        
        seller_info_collectors.each { |sth| sth.join }
        seller_with_no_feedback_productor.join
      # end
    end

    #
    # 获取所有目录的url连接，并存入数据库
    #     1.目录名称 -> title
    #     2.目录商品url -> href
    # 获取目录下所有的卖家的基本信息,根据url分析：
    #     1.店铺编号::number ->203943
    #     2.店铺类型::type ->store ; fm-store ; ...
    #     3.店铺url::url
    #     4.店铺所属目录::catagory_name
    #
    def self.collect_catagory
      site = "http://www.aliexpress.com/all-wholesale-products.html"

      create_multirequest_and_add_httprequests([site],'catagory') do |doc|
        catagorys = []
        doc.css('div.sec-categories > ul > li > a').each do | var| 
           if var['href'][0..6] == 'http://'
             n = { :title => var.content, :href => var['href'] } 
             Catagory.create(n) unless Catagory.where(:href => var['href']).size > 0
             Info::ResClientCollector.info("---> Got Catagory:: name => #{var.content} ,url => #{var['href']}")
             catagorys << n
           end
        end

        #
        # 创建6个线程进行页面数据抓取
        # 
        threads = []
        offset, limit = 0, catagorys.size/6
        6.times do |number|
          limit += catagorys.size%6 if number == 5
          cs = catagorys[offset,limit]
          offset += limit

          threads << Thread.new(cs) do |cs|
            cs.each do |catagory|
              Info::ResClientCollector.start_collect_sellers(catagory[:href], catagory[:title])
            end
          end
        end
        threads.each { |t| t.join }
      end
      # FIXME
      # test sellers_collect
      # Info::ResClientCollector.start_collect_sellers("http://www.aliexpress.com/category/200000361/transporting-storage.html")
    end

    def self.start_collect_sellers(catagory_uri,catagory_name = "ALL")
      create_multirequest_and_add_httprequests([catagory_uri],"page_no") do |doc|
        node = doc.css("span.page-no").first
        if node != nil
          counts = node.content.split("/").last.to_i

          #FIXME
          Info::ResClientCollector.info("Start collecting #{catagory_name} Page No.::**** #{counts} ****")
            
          sites = []
          counts.times do |c|
            sites << "#{catagory_uri[0..catagory_uri.length - 6]}/#{c+1}.html?needQuery=n"
          end

          create_multirequest_and_add_httprequests(sites, "seller_list") do |production_list_doc|
            production_list_doc.css("ul#list-items > li > div.detail > div > span > a.store").each do |seller|
              seller_uri = seller['href']
              #
              # uri_info = "www.example.com/:store_type/:store_number"
              #
              uri_info = seller_uri.split("/")
              seller_number = uri_info[-1]
              seller_type = uri_info[-2]

              unless Seller.where(:number => seller_number, :type => seller_type).size > 0 || seller_uri.include?("ress.com/category/")
                s = Seller.create(
                  :name => seller.content,
                  :uri => seller_uri,
                  :number => seller_number,
                  :type => seller_type,
                  :catagory_name => catagory_name
                )
                Info::ResClientCollector.info("---> Got Seller:: Number => #{seller_number} ,name => #{seller.content}")
              end
            end
          end
        end
      end
    end

    private
      def self.get_seller_info_and_save(seller)
        #
        # 获取seller的feedback信息
        #
        # TODO collect feedback info
        # need the below 3 params
        #
        # 1.companyId	110544644
        # 2.memberType	seller
        # 3.ownerMemberId	119186546
        # example_reqest: 
        #   http://feedback.aliexpress.com/display/evaluationAjaxService.htm?ownerMemberId=200267449&companyId=200430123&memberType=seller
        #
        # detail feedback:
        # 1.ownerAdminSeq 200267449
        # example_request:
        #   http://feedback.aliexpress.com/display/evaluationDsrAjaxService.htm?ownerAdminSeq=200267449 
        #
	
        seller_info_uri = "#{seller.uri}/contactinfo.html"
        feed_back_uri = "http://feedback.aliexpress.com/display/evaluationAjaxService.htm"
        details_feed_back_uri = "http://feedback.aliexpress.com/display/evaluationDsrAjaxService.htm"

        create_multirequest_and_add_httprequests(seller_info_uri,"seller_info", 1) do |doc|
          s_info = doc.css("textarea#store-params").first
          # s_info 获取的信息如下(String)：
          #	{
          #    "tabFeedbackTabUrl"	:	'http://www.aliexpress.com/store/302056/feedback-score.html',
          #    "feedbackServer"     :	'http://feedback.aliexpress.com',
          #    "shopcartServer"     :	'http://shoppingcart.aliexpress.com',
          #    "ownerMemberId"      :	'200267449',
          #    "companyId"		      :	'200430123'
          # }
          #
          if s_info != nil
            string_info = s_info.content.gsub(/\w/).inject("") {|s,v| s+=v}
            re1='.*?'	
            re2='\\d+'
            re3='.*?'	
            re4='(\\d+)'
            re5='.*?'	
            re6='(\\d+)'
            re=(re1+re2+re3+re4+re5+re6)
            matcher=Regexp.new(re,Regexp::IGNORECASE)
            if matcher.match(string_info)
                owner_member_id, company_id = matcher.match(string_info)[1], matcher.match(string_info)[2]
                seller_feedback_uri = "#{feed_back_uri}?ownerMemberId=#{owner_member_id}&companyId=#{company_id}&memberType=seller"
                seller_feedback_detail_uri = "#{details_feed_back_uri}?ownerAdminSeq=#{owner_member_id}"

                create_multirequest_and_add_httprequests(seller_feedback_uri, "seller_feedback",0.3) do |sfr_doc|
                  #
                  # example doc data
                  # 1461,97.3,23-s,3165
                  # ratings, postice feedback, ?? , feedback score
                  #
                  data = sfr_doc.content.split(',')
                  ratings, positive_feedback, feedback_score = data[0], data[1], data[3] 
                  seller.update_attributes( 
                    :positive_feedback => positive_feedback || "",
                    :feedback_score => feedback_score,
                    :ratings => ratings
                  )

                  Info::ResClientCollector.info("--->> Got Seller #{seller.name} feedback_ratings: [#{positive_feedback} , #{ratings}]")
                end

                create_multirequest_and_add_httprequests(seller_feedback_detail_uri, "seller_detail_feedback", 0.3) do |feed_detail_doc|
                  #
                  # example doc data
                  # {
                  #   "desc":{"score":"4.8","ratings":"473","percent":"5.73"}, 
                  #   "seller":{"score":"4.8","ratings":"472","percent":"5.96"}, 
                  #   "shipping":{"score":"4.6","ratings":"471","percent":"4.31"} 
                  # }
                  #
                  detail_feedback = ""
                  begin
                    feed_detail_doc.content.each_line {|l| detail_feedback += l.strip}
                  rescue => e
                    detail_feedback = "no_feedback_details"
                  end
                  seller.update_attributes(:feedback_detail => detail_feedback)

                  Info::ResClientCollector.info("--->> Got Seller #{seller.name} feedback details: [ #{detail_feedback} ]")
                end
                  
            end
          end
          
        end
      end

      def self.create_multirequest_and_add_httprequests(sites, type, sleep_time = 2)
        sites = [sites] if sites.is_a?(String)
        sites.each do |site|
          begin
            response = RestClient.get site
            Info::ResClientCollector.info(">>> Collecting #{type} page :: #{site}")
            if response.code == 200
              doc = Nokogiri::HTML(response)
              yield doc
            else
              failed_req(site,type,response.to_str)
            end
          rescue => e
            failed_req(site,type,e.inspect)
          end
          sleep sleep_time
        end
      end

      def self.failed_req(uri, type,response = "")
        # FIXME
        # debugger
        Failure.create(:type => type , :uri => uri, :response => response)
        puts '******************Failed**********************'
        Info::ResClientCollector.info("#{type}::Collecting Failure #{uri}")
        puts '******************Failed**********************'
      end

      def self.info(msg)
        #
        # TODO
        # Log 记录
        # return if not Info::Collector.config.debug == false
        #
        msg = "\e[32m[Collection::Info] #{msg}\e[0m"
        puts msg
      end

  end
end
