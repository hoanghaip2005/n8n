create extension if not exists vector;

create table if not exists public.product_image_vectors (
  id bigserial primary key,
  product_id bigint not null,
  image_url text not null,
  model_name text not null,
  embedding vector(512) not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (product_id, image_url)
);

create index if not exists idx_product_image_vectors_product_id
  on public.product_image_vectors (product_id);

create index if not exists idx_product_image_vectors_image_url
  on public.product_image_vectors (image_url);

create index if not exists idx_product_image_vectors_embedding_hnsw
  on public.product_image_vectors
  using hnsw (embedding vector_cosine_ops);

create or replace function public.set_product_image_vectors_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_product_image_vectors_updated_at
on public.product_image_vectors;

create trigger trg_product_image_vectors_updated_at
before update on public.product_image_vectors
for each row
execute function public.set_product_image_vectors_updated_at();
