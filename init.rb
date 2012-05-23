$stdout.sync = true

Mongoid.configure do |config|
  config.master = Mongo::Connection.new("127.0.0.1", "27017").db("seller_info_collection")
end

# Info::Collector.configure do |config|
#   config.debug = true
# end

$count_catagory = Catagory.all.count
$count_sellers = Seller.all.count
