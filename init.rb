$stdout.sync = true

Mongoid.configure do |config|
  config.master = Mongo::Connection.new("127.0.0.1", "27017").db("seller_info_collection")
end

Info::ResClientCollector.configure do |config|
  config.debug = true

  config.sellers_threads = 9
  config.seller_sleep_time = 2

  config.info_products = 100
  config.info_threads = 5
  config.flash_info_products_time = 30
  config.info_sleep_time = 1
end

$count_catagory = Catagory.all.count
$count_sellers = Seller.all.count
