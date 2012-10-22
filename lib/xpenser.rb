require 'rubygems'
require 'httparty'
require 'prawn'
require 'prawn/layout'
require 'faster_csv'
require 'pp'
require '../config/passwords.rb'
require 'mongo_mapper'
require 'bigdecimal'
require 'cubicle'

#http://tomdoc.org/

class Expense
  include MongoMapper::Document
  
  key :expense_id, ObjectId
  key :amount, Float
  key :date, Time
  key :notes, String
  key :tags, Array
  key :type, String # type => company 
end

class Xpenser
  
  include HTTParty
  base_uri 'http://xpenser.com'
  basic_auth XPENSER[:username], XPENSER[:password]
  default_params :format => 'json'
  format :json

  # Public: Initialize a httparty instance with xpenser.com.
  #
  # user  - The String username.
  # pass  - The String password.
  #
  # Examples
  #
  #   initialize('my.xpenser@username.com', 'myxpenserpassword')
  #   # => 'Unsure...what does the initialize return?'
  #
  # Returns the duplicated String.
  def initialize(user, pass)
    self.class.basic_auth user, pass
  end
  
  
  # Public: Parse date into xpenser date format.
  #
  # date  - The String or Date object that a user passes in for parsing.
  #
  # Examples
  #
  #   puts format_xpenser_dates('20080924')
  #   # => 2008-09-24
  #   puts format_xpenser_dates('2010-05-21')
  #   # => 2010-05-21
  #   puts format_xpenser_dates('05/03/2010')
  #   # => 2010-05-03
  #   puts format_xpenser_dates('jello')
  #   # => ArgumentError: Could not turn jello into an xpenser formatted date
  #
  # Returns a xpenser date formatted String. 
  def self.format_xpenser_dates(date)
    date = date.to_s if date.class == Date

    if date =~ /\d{4}-\d{2}-\d{2}/ 
      return date 
    else
      begin
        date = Date.parse(date).strftime('%Y-%m-%d') #need to catch errors here
      rescue
        raise ArgumentError.new("Could not turn #{date} into an xpenser formatted date")
      end
    end

    if date =~ /\d{4}-\d{2}-\d{2}/ 
      return date
    else
        "The parsed date is #{date} and is not correctly formatted"
    end
  end


  # Public: Get all expenses for the default report. 
  #
  # Examples
  #
  #   pp Class.get_default_report 
  #   # => #<Expense category: [36677], notes: "UpsellIt.com - 5% of July's Upsellit Generated Sales", 
  #         amount: 2131, expense_id: nil, _id: BSON::ObjectID('4c7921426cd1692525000066'), tags: [], 
  #         date: Sat Jul 31 14:04:00 UTC 2010, type: "Web Software Rental">,
  #         <Expense category: [36675], notes: "Endicia.com - US Mail Shipments Conf 161474", 
  #          amount: 400, expense_id: nil, _id: BSON::ObjectID('4c7921426cd1692525000001'), tags: [], 
  #          date: Wed Aug 25 21:43:45 UTC 2010, type: "Freight">
  #
  # Returns HTTParty::Response Object. 
  def self.get_default_report_expenses
    get("/api/expenses/")
  end
  
  # Public: Get all expenses for a single report.
  #
  # report_id  - The Integer of the report you want returned. 
  #
  # Examples
  #
  #   pp Class.get_default_report(report_id)
  # 
  #   # => #<Expense category: [36677], notes: "UpsellIt.com - 5% of July's Upsellit Generated Sales", 
  #         amount: 2131, expense_id: nil, _id: BSON::ObjectID('4c7921426cd1692525000066'), tags: [], 
  #         date: Sat Jul 31 14:04:00 UTC 2010, type: "Web Software Rental">,
  #         <Expense category: [36675], notes: "Endicia.com - US Mail Shipments Conf 161474", 
  #          amount: 400, expense_id: nil, _id: BSON::ObjectID('4c7921426cd1692525000001'), tags: [], 
  #          date: Wed Aug 25 21:43:45 UTC 2010, type: "Freight">
  #
  # Returns HTTParty::Response Object.
  def self.get_report(report_id)
    get("/api/v1.0/ expenses/?report=#{report_id}")
  end
  
  # Public: Get all expenses for all reports.
  #
  # Examples
  #
  #   pp Class.get_default_report 
  #
  #   # => #<Expense category: [36677], notes: "UpsellIt.com - 5% of July's Upsellit Generated Sales", 
  #         amount: 2131, expense_id: nil, _id: BSON::ObjectID('4c7921426cd1692525000066'), tags: [], 
  #         date: Sat Jul 31 14:04:00 UTC 2010, type: "Web Software Rental">,
  #         <Expense category: [36675], notes: "Endicia.com - US Mail Shipments Conf 161474", 
  #          amount: 400, expense_id: nil, _id: BSON::ObjectID('4c7921426cd1692525000001'), tags: [], 
  #          date: Wed Aug 25 21:43:45 UTC 2010, type: "Freight">
  #
  # Returns HTTParty::Response Object.
  def self.get_all_reports
    get("/api/v1.0/expenses/?report=*")
  end
  
  def self.get_all_reports_with_date(date)
    get("/api/v1.0/expenses/?report=*&date_op=gt&date=#{date}")
  end
  

  # Public: Get a id => name hash of all tags used in your xpenser reports
  #
  # Examples
  #
  #   xpenser_tag_hash = Xpenser.get_all_tags
  #   pp xpenser_tag_hash
  #
  #   #=>  {93923 =>"Tag1",
  #         84526 =>"Tag2",
  #         50587 =>"Tag3",
  #         25247=>"Tag4"}
  #   
  # Returns Hash of tag names in tag_id => tag_name format
  def self.get_all_tags
    array = get("/api/v1.0/tags/")
    name_array = []
    id_array = []
    
    array.each do |hash_row|
      hash_row.each_pair do |k,v|
         k == "id" ?  id_array << v : name_array << v
      end
    end
    Hash[id_array.zip(name_array)]
  end
  
  
  # Public: Convert tag ids to tag names for each tag id present.
  #
  # tag_id_array - The Array that contains each tag_id in the json array
  # xpenser_tag_array - The Hash that contains all tags in tag_id => tag_name format
  #
  # Examples
  #
  #   returned_array = Xpenser.tag_to_name(tag_id_array, xpenser_tag_array)
  #   # => ['Tag1', Tag2'] 
  #   
  # Returns Array of matching tag names
  def self.tag_id_to_name(tag_id_array, xpenser_tag_hash)
    array = Array.new
    
    tag_id_array.each do |tag_id|
      xpenser_tag_hash.each_pair do |id,name|
        array << name if tag_id == id
      end
    end
    array
  end
  
end