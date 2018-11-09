CREATE TABLE companies (
  id serial PRIMARY KEY, -- done
  name text NOT NULL, -- done
  logo_url text, -- done
  website_url text UNIQUE, -- done
  job_board_url text UNIQUE NOT NULL, -- done
  added_at timestamp NOT NULL DEFAULT NOW()
);

CREATE TABLE jobs (
  id serial PRIMARY KEY,
  title text NOT NULL, -- done
  description text, -- done
  job_listing_url text UNIQUE NOT NULL, -- done
  locations text,  -- format: City, Country|City, Country| City, Country
  salary_min integer, -- done
  salary_max integer, -- done
  company_id integer REFERENCES companies(id) NOT NULL,
  reviewed boolean NOT NULL DEFAULT false, -- auto
  active boolean NOT NULL DEFAULT true, -- auto
  date_posted timestamp, -- done
  updated_at timestamp NOT NULL DEFAULT NOW()
);