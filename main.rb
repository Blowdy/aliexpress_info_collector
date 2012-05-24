require 'rubygems'

require 'eventmachine'
#require 'em-http'
#require 'pp'

#HTTP Client
require "rest_client"
#HTML anylize
require 'nokogiri'
#Debugger
require "ruby-debug"

#database and model save
require 'mongoid'

#$LOAD_PATH.unshift(File.dirname(__FILE__))
require './models'

#em-http-requrest use by collector
#require './config'
#require './collector'

#rest_client use by res_client_collector
require './res_client_collector'
require "./collector_config"

require './init'

class KeyboardHandler < EM::Connection
  include EM::Protocols::LineText2
 
  def post_init
    puts 'sellers   - start sellers collecting.'
    puts 'info      - start sellers" info collecting.'
    puts "exit      - exits the app"
    puts "help      - this help"
    print "> "
  end
 
  def receive_line(line)
    line.chomp!
    line.gsub!(/^\s+/, '')
   
    case(line)
    when /^start$/ then
      # FIXME too much bad request
      # Info::Collector.start_collect
      print "> "
    when /^sellers$/ then
      #
      #TODO mutil thread
      #
      Info::ResClientCollector.start_collect
      print "> "
    when /^info$/ then
      #
      #TODO mutil thread
      #
      Info::ResClientCollector.start_collect_feedback_info
      print "> "
    when /^exit$/ then
      EM.stop
    when /^help$/ then
      puts 'sellers   - start sellers collecting.'
      puts 'info      - start sellers" info collecting.'
      puts "exit      - exits the app"
      puts "help      - this help"
      print "> "
    end
  end
end
EM::run {
  EM.open_keyboard(KeyboardHandler)
}

puts "======= Collected Info ========"
puts "Catagory: #{Catagory.all.count - $count_catagory}"
puts "Seller: #{Seller.all.count - $count_sellers}"
puts "==============================="
