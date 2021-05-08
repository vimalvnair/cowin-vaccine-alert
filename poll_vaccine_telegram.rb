require 'net/http'
require 'json'
require 'cgi'
require 'date'

TELEGRAM_BOT_API_KEY = ENV['TELEGRAM_BOT_API_KEY']
TELEGRAM_CHAT_ID = ENV['TELEGRAM_CHAT_ID']
TODAY=Date.today.strftime("%d-%m-%Y")

def get_session_details centers
  sessions = centers.map{|c| c['sessions'].map{|s| s.merge(c.select{|k,v| k != "sessions"} || {} )}}.flatten
  available_sessions =  sessions.select{|s| s['available_capacity'] >= 0}
  return "" if available_sessions.nil? || available_sessions.empty?

  details = available_sessions.map{|s|
    %(<u>#{s['date']}</u>
#{s['name']}, <u>#{s['address']}</u>, #{s['block_name']}, <u>#{s['pincode']}</u>
Capacity: <b>#{s['available_capacity']}</b>,  Min age: <b>#{s['min_age_limit']}</b>
<i>-------------------------</i>
)                              
  }
end

def send_telegram_message message, parse_mode = 'html'
  puts message
  uri = URI("https://api.telegram.org/bot#{TELEGRAM_BOT_API_KEY}/sendMessage?chat_id=#{TELEGRAM_CHAT_ID}&parse_mode=#{parse_mode}&text=#{CGI.escape(message)}")
  req = Net::HTTP::Get.new(uri)
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(req)
  end

  puts "send_telegram_message"
  puts res.code
  puts res.body
end

current_key = ""
previous_key = ""

begin
  uri = URI("https://cdn-api.co-vin.in/api/v2/appointment/sessions/public/calendarByDistrict?district_id=303&date=#{TODAY}")
  
  req = Net::HTTP::Get.new(uri)
  req['User-Agent'] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.128 Safari/537.36"

  use_ssl = {use_ssl: uri.scheme == "https"}
  resp = Net::HTTP.start(uri.hostname, uri.port, use_ssl) {|http|
    http.request(req)
  }
  return send_telegram_message("Error, response code: #{resp.code}", "") if resp.code != "200"

  json = JSON.parse(resp.body)
  centers = json['centers']
  sessions = centers.map{|c| c['sessions']}.flatten
  current_key = sessions.select{|s| s['available_capacity'] >= 0}.map{|s| "#{s['session_id']}#{s['available_capacity']}"}.sort.join

  puts current_key

  if current_key != previous_key
    session_details = get_session_details centers
    
    send_telegram_message session_details.join("\n")
  end

  previous_key = current_key
rescue Exception => e
  send_telegram_message e.message, ""
end
