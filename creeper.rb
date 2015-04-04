require 'mechanize'
require 'json'

# Credentials
@li_user = "my_email"
@li_pass = "my_password"

# Form action to look for when signing in
@li_action = "https://www.linkedin.com/uas/login-submit"

# Initialize crawler.
crawler = Mechanize.new
crawler.user_agent_alias = "Linux FireFox"
crawler.follow_meta_refresh = true
crawler.get("https://www.linkedin.com")

# Attempt to log into LinkedIn.
form = crawler.page.form_with(:action => @li_action)
if form.nil?
  abort("Could not find form to sign in. Did something change?")
end
form['session_key'] = @li_user
form['session_password'] = @li_pass
crawler.submit(form)

# Confirm login success by ensuring login form no longer exists.
logincheck = crawler.page.form_with(:action => @li_action)
if !logincheck.nil?
  abort("Failed to sign in with user #{@li_user}")
else
  puts "Successfully signed in with user #{@li_user}"
end

# Go to People You May Know page to pull LinkedIn's random seed and CSRF token for the PYMK ajax feed.
crawler.get("https://www.linkedin.com/people/pymk/hub")
if !crawler.page.nil? && crawler.page.body.include?("People You May Know")
  begin
    random_seed = crawler.page.body.split('"randomSeed":')[1].split(',')[0]
    csrf_token = crawler.page.body.split('&csrfToken=')[1].split('"')[0]
  rescue
    abort("Could not obtain seed ID and CRSF token due to an error.")
  end
  if random_seed.nil? || csrf_token.nil?
    abort("Seed ID or CRSF token missing.")
  end
else
  abort("Could not validate People You May Know page. Did something change?")
end

# Starting page for PYMK feed.
ajax_page = 0

# Number of records to pull at a time. LinkedIn default is currently 12.
ajax_records = 12

# Loop through people until no more can be retrieved.
loop do

  crawler.get("https://www.linkedin.com/people/pymk-connect-hub-scroll?pageNum=#{ajax_page}&boostID=&seed=#{random_seed}&location=desktop-connect-hub-scroll&trk=connect_hub_load_more&csrfToken=#{csrf_token}&decorate=false&facetType=&facetID=&offset=#{ajax_page * ajax_records}&records=#{ajax_records}")

  parsedJson = JSON.parse(crawler.page.body)

  if parsedJson["content"]["contacts_pymk_people_cards"]["people"].empty?
    break
  else
    parsedJson["content"]["contacts_pymk_people_cards"]["people"].each do |person|

      crawler.get(person["profileURL"])
      puts "Pinged #{person["fullName"]} (#{person["memberID"]}). You have #{person["numSharedConnections"]} shared connections."

      # Sleep a few seconds as not to spam.
      sleep(rand(3))
    end
  end

  ajax_page += 1

  # Sleep another 1-5 seconds before next feed request.
  sleep(rand(5))
end


