require 'pg'

class Database
  def initialize
    @db = PG.connect(dbname: 'productjobs')
  end

  def company_existed?(name, url)
    sql = "SELECT * FROM companies WHERE name = $1 AND url = $2"
    result = @db.exec_params(sql, [name, url])
    result.ntuples != 0
  end

  def update_companies(companies, location)
    companies.each do |company|
      name = company[:name]
      url = company[:job_url]
      if !company_existed?(name, url)
        sql = "INSERT INTO companies (name, url, location) VALUES ($1, $2, $3)"
        params = [name, url, location]
        @db.exec_params(sql, params)
      end
    end
  end

  def find_job_id(url)
    sql = "SELECT id FROM jobs WHERE url = $1"
    result = @db.exec_params(sql, [url])
    result.ntuples == 0 ? nil : result[0]["id"]
  end

  def find_company_id_from_url(url)
    sql = "SELECT id FROM companies WHERE url = $1"
    result = @db.exec_params(sql, [url])
    result[0]["id"].to_i
  end

  def update_job(job_details, company_url)
    # { title: title, url: url, location: location, description: description, compensation: compensation }
    job_id = find_job_id(job_details[:url])
    company_id = find_company_id_from_url(company_url)
    params = [ job_details[:title], job_details[:url], job_details[:location],
                 job_details[:description], job_details[:compensation], company_id ]
    if job_id.nil?
      sql = "INSERT INTO jobs (title, url, location, description, compensation, company_id) 
             VALUES ($1, $2, $3, $4, $5, $6)"
      @db.exec_params(sql, params)
    else
      sql = "UPDATE jobs SET title = $1, url = $2, location = $3, description = $4, compensation = $5, company_id = $6
             WHERE id = $7"
      @db.exec_params(sql, params + company_id)
    end

  end

  def get_companies
    result = @db.exec  "SELECT  * FROM companies;"
    result.map do |company|
      { name: company["name"], job_url: company["url"] }
    end
  end
end