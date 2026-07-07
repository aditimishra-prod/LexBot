-- Enable pgvector
create extension if not exists vector;

-- Main content items table (scraped + user-added DPDP content)
create table if not exists items (
  id            uuid primary key default gen_random_uuid(),
  url           text not null unique,
  title         text,
  raw_text      text,
  summary       text,
  content_type  text check (content_type in ('article','podcast','video','other')) default 'article',
  difficulty    text check (difficulty in ('beginner','intermediate','advanced')) default 'beginner',
  source        text,
  tags          text[] default '{}',
  news_category text,
  embedding     vector(1536),
  is_read       boolean default false,
  last_accessed timestamptz,
  user_note     text,
  remind_at     timestamptz,
  reminder_sent boolean default false,
  created_at    timestamptz default now()
);

-- Weekly learning plans
create table if not exists plans (
  id           uuid primary key default gen_random_uuid(),
  week_start   date not null unique,
  plan_json    jsonb not null,
  generated_at timestamptz default now()
);

-- Registered devices for FCM push
create table if not exists devices (
  id           uuid primary key default gen_random_uuid(),
  fcm_token    text not null unique,
  user_email   text,
  registered_at timestamptz default now()
);

-- Indexes for fast queries
create index if not exists items_is_read_idx on items(is_read);
create index if not exists items_created_at_idx on items(created_at desc);
create index if not exists items_remind_at_idx on items(remind_at) where remind_at is not null;

-- Vector similarity search function
create or replace function match_items(
  query_embedding vector(1536),
  match_threshold float default 0.4,
  match_count     int   default 10
)
returns table (
  id           uuid,
  url          text,
  title        text,
  summary      text,
  content_type text,
  difficulty   text,
  source       text,
  tags         text[],
  is_read      boolean,
  similarity   float
)
language sql stable as $$
  select id, url, title, summary, content_type, difficulty, source, tags, is_read,
         1 - (embedding <=> query_embedding) as similarity
  from items
  where 1 - (embedding <=> query_embedding) > match_threshold
  order by embedding <=> query_embedding
  limit match_count;
$$;
