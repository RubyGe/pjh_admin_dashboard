SLEEP = {lower_limit: 3, higher_limit: 5}
LOGIN = { username: "genie@intventures.co", password: "JqQA&gvV$M01#Sf" }
NEW_SESSION = false

module Navigate
  def pause (multi)
    sleep rand(SLEEP[:lower_limit] * multi..SLEEP[:higher_limit] * multi)
  end

  def save_cookies
    cookies = @driver.manage.all_cookies
    data_dump("cookies", cookies)
  end

  def data_dump(file_name, file_content)
    File.write(file_name, file_content)
  end

  def data_load(file_name)
    YAML::load(File.read(file_name))
  end

  def load_cookies
    cookies = data_load("cookies")
    cookies.each do |cookie|
      @driver.manage.add_cookie(cookie)
    end
  end

  def enter_credentials
    element = @driver.find_element(id: 'user_email')
    element.send_keys LOGIN[:username]

    element = @driver.find_element(id: 'user_password')
    element.send_keys LOGIN[:password]

    element.submit
  end

  def login
    @driver.navigate.to "https://angel.co/login"
   
    if NEW_SESSION
      enter_credentials
      save_cookies
    else
      load_cookies
    end
  end
end