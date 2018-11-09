require 'bundler/setup'
require 'selenium-webdriver'
require 'nokogiri'
require 'pry-byebug'
require 'yaml'
require 'uri'
require 'json'
require 'open-uri'

require_relative './navigate_module'
require_relative './database.rb'

class JobScraper
  include Navigate

  LOCATIONS_FILE = 'search_keywords.yaml'

  def initialize
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    @driver = Selenium::WebDriver.for :chrome, options: options
    @locations = load_locations
    @title_keywords = load_titles
    @storage = Database.new
    login
  end

  def start
    @locations.each do |location|
      url = create_search_url(location)
      @driver.navigate.to url
      pause(2)
      @companies = get_company_job_board_urls(@driver)
      puts "Fetched all companies:"
      p @companies
      # delete
      fetch_company_and_jobs(@driver)
      # @jobs = get_jobs(@companies)
      # @storage.update_companies(@companies, location)
    end
  end

  def create_search_url(location)
    # improvements: include job title keyword search instead of defaulting to PM as a role filter
    location_url = URI.escape(location)
    "https://angel.co/jobs#find/f!%7B%22types%22%3A%5B%22full-time%22%5D%2C%22keywords%22%3A%5B%22#{location_url}%22%5D%2C%22roles%22%3A%5B%22Product%20Manager%22%5D%7D"
  end

  private

  def load_locations
    keyword_list = YAML.load(File.open(LOCATIONS_FILE))
    keyword_list["locations"]
  end

  def load_titles
    keyword_list = YAML.load(File.open(LOCATIONS_FILE))
    keyword_list["job_titles"]
  end

  def get_logo_url(website_url)
    host = URI.parse(website_url).host
    begin
      url = "http://logo.clearbit.com/#{host}"
      open(url)
    rescue StandardError=>e
      puts "Error: #{e}"
    else
      url
    end
  end

  def parse_job_locations(json)
    json.map do |location|
      country = location["address"]["addressCountry"]
      city = location["address"]["addressLocality"]
      province = location["address"]["addressRegion"]
      "#{city}, #{province}, #{country}"
    end.join("|")
  end

  def fetch_job_listing_details(job_listing_url, title)
    begin
      @driver.navigate.to job_listing_url
      page = driver_to_nokogiri(@driver)
    rescue StandardError=>e
      puts "Error: #{e}"
    else
      begin
        metadata = page.xpath("//script[@type='application/ld+json']")
        json = JSON.parse(metadata.text)
        date_posted = Time.parse(json["datePosted"]) if !json["datePosted"].nil?
        description = json["description"]
        if !json["baseSalary"].nil?
          salary_min = json["baseSalary"]["value"]["minValue"].to_i
          salary_max = json["baseSalary"]["value"]["maxValue"].to_i
        end
        locations = parse_job_locations(json["jobLocation"]) if !json["jobLocation"].nil?
      rescue StandardError=>e
        puts "Error: #{e}"
      end
      { title: title, job_listing_url: job_listing_url, locations: locations, 
        salary_min: salary_min, salary_max: salary_max, description: description,
        date_posted: date_posted }
    ensure
      pause(1)
    end
  end

  def fetch_job_listings(company, page)
    job_cards = page.css("div.jobs div.listing-title>a")
    job_cards.each do |job_card|
      title = job_card.text
      if valid_job_title?(title)
        job_listing_url = job_card['href'].match(/(.+\/jobs\/\d+)-.+/)[1]
        job_listing = fetch_job_listing_details(job_listing_url, title)
        @storage.update_job(job_listing, company) if !job_listing.nil?
      end
    end
  end

  def fetch_company_and_jobs(driver)
    @companies.each do |company|
      # visit job board page
      driver.navigate.to company[:job_board_url]
      pause(1)
      page = driver_to_nokogiri(driver)

      # fetch company website url and logo url
      company_info = fetch_company_details(company, page)
      @storage.update_company(company_info)

      fetch_job_listings(company_info, page)
    end
  end

  def fetch_company_details(company, page)
    company_info = {}
    company_info[:job_board_url] = company[:job_board_url]
    company_info[:name] = company[:name]
    begin
      website_url = page.css("div.showcase-section div.product-metadata a.website-link")[0]['href']
    rescue StandardError=>e
      puts "Error: #{e} for #{company[:name]} at #{company[:job_board_url]}"
    else
      company_info[:website_url] = website_url
      company_info[:logo_url] = get_logo_url(website_url)
    end
    company_info
  end

  def get_company_job_board_urls(driver)
    page = load_with_auto_scroll(driver)
    companies = []
    company_cards = page.css("div.job_listings div.header-info")
    company_cards.each do |card|
      begin
        company = {
          name: card.css("a.startup-link")[0].text,
          job_board_url: card.css("a.startup-link")[0]['href']
        }
      rescue StandardError=>e
        puts "Error: #{e}"
      else
        companies << company
      end
    end
    companies
  end

  def valid_job_title?(title)
    @title_keywords.any? { |keyword| title =~ /#{keyword}/i }
  end

  # def inspect_job_listings(company, company_hash)
  #   job_listings = company.css("div.collapsed-job-listings div.collapsed-listing-row")
  #   job_listings.each do |job|
  #     title = job.css("div.collapsed-title")[0].text.strip if job.css("div.collapsed-title")[0]
  #     next unless valid?(title)
  #     comp = job.css("div.collapsed-compensation")[0].text.strip if job.css("div.collapsed-compensation")[0]
  #     job_hash = {
  #       title: title,
  #       compensation: comp
  #     }
  #     company_hash[:jobs] << job_hash
  #   end
  # end

  def driver_to_nokogiri(driver)
    Nokogiri::HTML(driver.find_element(id: "layouts-base-body").attribute("innerHTML"))
  end

  def load_with_auto_scroll(driver)
    size_before_scroll = 0

    loop do
      elements = driver.find_elements(class: "browse_startups_table_row")
      size_after_scroll = elements.size
      scroll_to_element = elements.last
      driver.action.move_to(scroll_to_element).perform
      break if size_before_scroll == size_after_scroll
      size_before_scroll = size_after_scroll
      p size_before_scroll
      pause(1)
    end

    driver_to_nokogiri(driver)
  end

  def valid?(job_title)
    job_title.downcase =~ /product/ if job_title
  end
end