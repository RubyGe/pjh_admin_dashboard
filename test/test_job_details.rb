ENV['environment'] = "test"

require 'minitest/autorun'
require_relative '../job_details'

class JobDetailsTest < Minitest::Test
  def setup
    @scraper = JobListingScraper.new
  end

  def test_import_job_listing_urls

    assert_equal @scraper.companies.size, 8

    assert_equal @scraper.companies[0][:name], "CryptoKitties"
    assert_equal @scraper.companies[0][:career_url], "https://angel.co/cryptokitties/jobs"

    assert_equal @scraper.companies[7][:name], "News360"
    assert_equal @scraper.companies[7][:career_url], "https://angel.co/news360/jobs"
  end

  def test_loading_career_page
    @scraper.load_career_page

    assert_includes @scraper.companies[0][:career_page], "Jobs at CryptoKitties"
    assert_includes @scraper.companies[0][:career_page], "At CryptoKitties—born out of blockchain studio Dapper Labs"
  end
end