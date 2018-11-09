require 'pg'

class Database
  def initialize
    @db = PG.connect(dbname: 'productjobs')
  end

  # def company_existed?(name, job_board_url)
  #   sql = "SELECT * FROM companies WHERE name = $1 AND job_board_url = $2"
  #   result = @db.exec_params(sql, [name, url])
  #   result.ntuples != 0
  # end

  def query(statement, *params)
    puts "DB: #{statement} -> #{params}"
    @db.exec_params(statement, params)
  end

  def update_company(company)
    name = company[:name]
    job_board_url = company[:job_board_url]
    logo_url = company[:logo_url]
    website_url = company[:website_url]

    company_id = find_company_id(name, job_board_url)

    if company_id.nil?
      sql = "INSERT INTO companies (name, job_board_url, logo_url, website_url) VALUES ($1, $2, $3, $4)"
      query(sql, name, job_board_url, logo_url, website_url)
    else
      sql = "UPDATE companies SET logo_url = $1, website_url = $2 WHERE id = $3"
      query(sql, logo_url, website_url, company_id)
    end
  end

  def find_job_id(url)
    sql = "SELECT id FROM jobs WHERE job_listing_url = $1"
    result = query(sql, url)
    result.ntuples == 0 ? nil : result[0]["id"]
  end

  def find_company_id(name, job_board_url)
    sql = "SELECT id FROM companies WHERE name = $1 AND job_board_url = $2"
    result = query(sql, name, job_board_url)
    result.ntuples == 0 ? nil : result[0]["id"].to_i
  end

  # rewrite
  def update_job(job_listing, company)
  #       { title: title, job_listing_url: job_listing_url, locations: locations, 
  #       salary_min: salary_min, salary_max: salary_max, description: description,
  #       date_posted: date_posted }
    job_id = find_job_id(job_listing[:job_listing_url])
    company_id = find_company_id(company[:name], company[:job_board_url])
    if job_id.nil?
      params = [ job_listing[:title], job_listing[:job_listing_url], job_listing[:locations],
               job_listing[:salary_min], job_listing[:salary_max], job_listing[:description],
               job_listing[:date_posted], company_id ]
      sql = "INSERT INTO jobs (title, job_listing_url, locations, 
                               salary_min, salary_max, description,
                               date_posted, company_id) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8)"
      query(sql, *params)
    else
      params = [ job_listing[:title], job_listing[:job_listing_url], job_listing[:locations],
               job_listing[:salary_min], job_listing[:salary_max], job_listing[:description],
               job_listing[:date_posted], Time.now, job_id ]
      sql = "UPDATE jobs SET title = $1, job_listing_url = $2, locations = $3, 
                             salary_min = $4, salary_max = $5, description = $6,
                             date_posted = $7, updated_at = $8
             WHERE id = $9"
      timestamp = Time.now
      query(sql, *params)
    end
  end

  def get_companies
    result = query("SELECT  * FROM companies;")
    result.map do |company|
      { name: company["name"], job_board_url: company["job_board_url"] }
    end
  end
end