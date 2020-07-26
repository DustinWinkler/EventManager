require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir("output") unless Dir.exists?("output")

  filename = "output/thanks_#{id}.html"

  File.open(filename,'w') do |file|
    file.puts form_letter
  end
end

def clean_phone_number(number)
  number = number.gsub(/[()-.' ']/, '')
  if number.length < 10
    'Bad phone number'
  elsif number.length == 10
    number
  elsif number.length == 11 && number[0] == '1'
    number[1..11]
  elsif number.length > 11
    'Bad phone number'
  end
end
puts "EventManager initialized."

contents = CSV.open 'event_attendees.csv', headers: true, header_converters: :symbol

template_letter = File.read "form_letter.erb"
erb_template = ERB.new template_letter
text_alert_list = File.open("mobile_alerts_list.txt", 'w')
time_targeting = File.open("time_targeting.txt", 'w')
day_of_week_targeting = File.open("day_of_week_targeting.txt", 'w')
time_hash = {}
week_hash = {}

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone_number = clean_phone_number(row[:homephone])
  text_alert_list.puts phone_number
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  time = DateTime.strptime(row[:regdate], '%m/%d/%Y %H:%M')
  if time_hash.has_key?(time.hour)
    time_hash[time.hour] += 1
  else
    time_hash[time.hour] = 1
  end

  if week_hash.has_key?(time.wday)
    week_hash[time.wday] += 1
  else
    week_hash[time.wday] = 1
  end

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)
  puts "#{name}'s letter complete!"
end

time_targeting.puts time_hash.sort_by{|k,v| -v}.to_s
day_of_week_targeting.puts week_hash.sort_by{|k,v| -v}.to_s
