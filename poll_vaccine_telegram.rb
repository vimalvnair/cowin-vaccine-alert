require 'net/http'
require 'json'
require 'cgi'
require 'date'

TELEGRAM_BOT_API_KEY = ENV['TELEGRAM_BOT_API_KEY']
TELEGRAM_CHAT_ID = ENV['TELEGRAM_CHAT_ID']
TELEGRAM_ERROR_CHANNEL_CHAT_ID = ENV['TELEGRAM_ERROR_CHANNEL_CHAT_ID']
DISTRICT_ID = ENV['DISTRICT_ID']
MIN_AGE_LIMIT = ENV['MIN_AGE_LIMIT']

def filter_condition session
  session['available_capacity'] > 1 && (MIN_AGE_LIMIT.nil? || session['min_age_limit'].to_i == MIN_AGE_LIMIT.to_i)
end

def get_session_details centers
  sessions = centers.map{|c| c['sessions'].map{|s| s.merge(c.select{|k,v| k != "sessions"} || {} )}}.flatten
  available_sessions =  sessions.select{|session| filter_condition session }
  return ["no sessions"] if available_sessions.nil? || available_sessions.empty?
  puts available_sessions.count
  details = available_sessions.map{|s|
    %(<u>#{s['date']}</u> Age: <b>#{s['min_age_limit']}+</b>
#{s['name']}, <u>#{s['address']}</u>, #{s['block_name']}, <b><u>#{s['pincode']}</u></b>
Vaccine: <b>#{s['vaccine']}</b>
Age: <b>#{s['min_age_limit']}+</b>
Dose 1 Capacity: <b>#{s['available_capacity_dose1']}</b>
Dose 2 Capacity: <b>#{s['available_capacity_dose2']}</b>
Total Capacity: <b>#{s['available_capacity']}</b>
<i>-------------------------</i>
)
  }
end

def send_telegram_message message, chat_id, parse_mode = 'html'
  #puts message
  uri = URI("https://api.telegram.org/bot#{TELEGRAM_BOT_API_KEY}/sendMessage?chat_id=#{chat_id}&parse_mode=#{parse_mode}&text=#{CGI.escape(message)}")
  req = Net::HTTP::Get.new(uri)
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(req)
  end

  puts "send_telegram_message"
  puts res.code
  puts res.body
end

def fetch_centers date
  begin
    uri = URI("https://cdn-api.co-vin.in/api/v2/appointment/sessions/public/calendarByDistrict?district_id=#{DISTRICT_ID}&date=#{date}")
    puts "Date: #{date}"
    puts uri.to_s
    req = Net::HTTP::Get.new(uri)
    req['User-Agent'] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.128 Safari/537.36"

    use_ssl = {use_ssl: uri.scheme == "https"}
    resp = Net::HTTP.start(uri.hostname, uri.port, use_ssl) {|http|
      http.request(req)
    }
    puts "http_code: #{resp.code}"

    centers = []
    if resp.code == "200"
      json = JSON.parse(resp.body)
      puts json
      centers = json['centers']
    else
      send_telegram_message("Error, response code: #{resp.code}", TELEGRAM_ERROR_CHANNEL_CHAT_ID, "")
    end
    puts centers.inspect
    centers
  rescue Exception => e
    send_telegram_message e.message, TELEGRAM_ERROR_CHANNEL_CHAT_ID, "" rescue nil
  ensure
    centers
  end
end

current_key = ""
previous_key = ""

loop do
  begin
    dates = [Date.today, Date.today + 7]

    centers = []
    dates.each do |date|
      centers << fetch_centers(date.strftime("%d-%m-%Y"))
    end
    centers = centers.flatten

    sessions = centers.map{|c| c['sessions']}.flatten
    current_key = sessions
                    .select{|session| filter_condition session}
                    .map{|s| "#{s['session_id']}#{s['available_capacity']}"}.sort.join

    puts current_key

    if current_key != previous_key
      session_details = get_session_details centers
      session_details.each_slice(17).each do |session_slice|
        send_telegram_message session_slice.join("\n"), TELEGRAM_CHAT_ID
        sleep 2
      end
    end

    previous_key = current_key
  rescue Exception => e
    puts e.inspect
    send_telegram_message e.message, TELEGRAM_ERROR_CHANNEL_CHAT_ID, "" rescue nil
  ensure
    sleep 25
  end
end
