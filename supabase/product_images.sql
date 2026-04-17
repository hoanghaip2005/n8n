create table if not exists public.product_images (
  id bigserial primary key,
  product_id bigint not null,
  image_url text not null,
  title text,
  website_url text,
  status text,
  brand text,
  category text,
  size text,
  image_angle text,
  source_name text not null default 'shop',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (product_id, image_url)
);

alter table if exists public.product_images
  add column if not exists title text,
  add column if not exists website_url text,
  add column if not exists status text,
  add column if not exists brand text,
  add column if not exists category text,
  add column if not exists size text,
  add column if not exists image_angle text,
  add column if not exists source_name text not null default 'shop',
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create index if not exists idx_product_images_product_id
  on public.product_images (product_id);

create index if not exists idx_product_images_is_active
  on public.product_images (is_active);

create index if not exists idx_product_images_website_url
  on public.product_images (website_url);
