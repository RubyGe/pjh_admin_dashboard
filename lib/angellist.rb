require 'bundler/setup'
require 'selenium-webdriver'
require 'nokogiri'
require 'pry'
require 'yaml'
require 'csv'
require 'uri'

require_relative './navigate_module'
require_relative './database.rb'

module CSVHelpers
  def export_companies_to_csv
    id = 1
    CSV.open("output.csv", "w:utf-8") do |csv|
      csv << ["Company Name", "Job URL", "Job Title", "Compensation"]
      @companies.each do |company|
        csv << [company[:name], company[:job_url]]
        company[:jobs].each do |job|
          csv << [id, "", job[:title], job[:compensation]]
          id += 1
        end
      end
    end
  end
end

class JobScraper
  include Navigate
  include CSVHelpers

  LOCATIONS_FILE = 'search_keywords.yaml'

  def initialize
    @driver = Selenium::WebDriver.for :chrome
    @locations = load_locations
    @title_keywords = load_titles
    @storage = Database.new
    login
  end

  def start
    # @locations.each do |location|
    #   url = create_search_url(location)
    #   @driver.navigate.to url
    #   pause(2)
    #   @companies = get_companies(@driver)
    #   @jobs = get_jobs(@companies)
    #   @storage.update_companies(@companies, location)
    # end
    @locations.each do |location|
      @companies = @storage.get_companies # temporary test
      @jobs = get_jobs(@companies)
      @storage.update_companies(@companies, location)
    end
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

  def create_search_url(location)
    # improvements: include job title keyword search instead of defaulting to PM as a role filter
    location_url = URI.escape(location)
    "https://angel.co/jobs#find/f!%7B%22types%22%3A%5B%22full-time%22%5D%2C%22keywords%22%3A%5B%22#{location_url}%22%5D%2C%22roles%22%3A%5B%22Product%20Manager%22%5D%7D"
  end

  def get_companies(driver)
    page = load_with_auto_scroll(driver)
    results = []
    companies = page.css("div.header-info")

    companies.each do |company|
      company_hash = {
        name: company.css("a.startup-link")[0].text,
        job_url: company.css("a.startup-link")[0]['href'],
        jobs: []
      }
      inspect_job_listings(company, company_hash)
      results << company_hash if !company_hash[:jobs].empty?
    end

    results
  end

  def get_jobs(companies)
    companies.each do |company|
      career_url = company[:job_url]
      company_name = company[:name]

      # get career page
      @driver.navigate.to career_url
      pause(1)
      page = driver_to_nokogiri(@driver)

      jobs = page.css("div.jobs div.listing-title>a")
      jobs.each do |job|
        title = job.text
        if valid_job_title?(title)
          job_listing_url = job['href'].match(/(.+\/jobs\/\d+)-.+/)[1]
          job_details = get_job_details(job_listing_url, title)
          @storage.update_job(job_details, career_url) if !job_details.nil?
        end
      end
    end
  end

  def get_job_details(url, title)
    begin
      @driver.navigate.to url
      page = driver_to_nokogiri(@driver)
    rescue StandardError=>e
      puts "Error: #{error}"
    else
      begin
        location = page.css("div.company-summary div.high-concept").text.split("·")[0].strip
        description = page.css("div.listing div.job-description").text
        compensation = page.at('div.s-vgBottom0_5:contains("Compensation")')
        if !compensation.nil?
          compensation = compensation.next_element.text
        end
      rescue StandardError=>e
        puts "Error: #{error}"
      end
    { title: title, url: url, location: location, description: description, compensation: compensation }
    ensure
      pause(1)
    end
  end

  def valid_job_title?(title)
    @title_keywords.any? { |keyword| title =~ /#{keyword}/i }
  end

  def inspect_job_listings(company, company_hash)
    job_listings = company.css("div.collapsed-job-listings div.collapsed-listing-row")
    job_listings.each do |job|
      title = job.css("div.collapsed-title")[0].text.strip if job.css("div.collapsed-title")[0]
      next unless valid?(title)
      comp = job.css("div.collapsed-compensation")[0].text.strip if job.css("div.collapsed-compensation")[0]
      job_hash = {
        title: title,
        compensation: comp
      }
      company_hash[:jobs] << job_hash
    end
  end

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

JobScraper.new.start