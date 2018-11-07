CREATE TABLE companies (
  id serial PRIMARY KEY,
  name text NOT NULL,
  url text UNIQUE NOT NULL,
  location text NOT NULL,
  created_at timestamp NOT NULL DEFAULT NOW()
);

CREATE TABLE jobs (
  id serial PRIMARY KEY,
  title text NOT NULL,
  description text,
  url text UNIQUE NOT NULL,
  location text,
  compensation text,
  company_id integer REFERENCES companies(id) NOT NULL,
  reviewed boolean NOT NULL DEFAULT false,
  created_at timestamp NOT NULL DEFAULT NOW()
);