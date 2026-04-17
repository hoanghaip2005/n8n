create extension if not exists pg_trgm;

create or replace function public.vi_normalize(input_text text)
returns text
language sql
immutable
parallel safe
as $$
  select regexp_replace(
    translate(
      lower(coalesce(input_text, '')),
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ',
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
    ),
    '\s+',
    ' ',
    'g'
  );
$$;

create index if not exists idx_product_images_title_trgm
  on public.product_images
  using gin (public.vi_normalize(title) gin_trgm_ops);

create index if not exists idx_product_images_brand_trgm
  on public.product_images
  using gin (public.vi_normalize(brand) gin_trgm_ops);

create index if not exists idx_product_images_category_trgm
  on public.product_images
  using gin (public.vi_normalize(category) gin_trgm_ops);

create index if not exists idx_product_images_size_trgm
  on public.product_images
  using gin (public.vi_normalize(size) gin_trgm_ops);

create or replace view public.v_product_catalog as
select
  product_id,
  image_url,
  title,
  website_url,
  status,
  brand,
  category,
  size,
  is_active,
  updated_at
from public.product_images
where is_active = true;

create or replace function public.search_product_catalog(
  p_query text,
  p_limit integer default 5,
  p_exclude_product_ids bigint[] default '{}'::bigint[],
  p_exclude_website_urls text[] default '{}'::text[]
)
returns table (
  product_id bigint,
  title text,
  image_url text,
  website_url text,
  status text,
  brand text,
  category text,
  size text,
  search_score numeric,
  match_type text
)
language sql
stable
as $$
with params as (
  select
    public.vi_normalize(trim(coalesce(p_query, ''))) as query_norm,
    greatest(1, least(coalesce(p_limit, 5), 10)) as limit_n
),
base as (
  select
    pi.product_id,
    pi.title,
    pi.image_url,
    pi.website_url,
    pi.status,
    pi.brand,
    pi.category,
    pi.size,
    public.vi_normalize(pi.title) as title_norm,
    public.vi_normalize(
      concat_ws(' ', pi.title, pi.brand, pi.category, pi.size, pi.status)
    ) as search_norm,
    coalesce(nullif(trim(pi.website_url), ''), 'product:' || pi.product_id::text) as dedupe_key
  from public.product_images pi
  where pi.is_active = true
    and coalesce(pi.title, '') <> ''
    and coalesce(pi.image_url, '') <> ''
    and (
      coalesce(array_length(p_exclude_product_ids, 1), 0) = 0
      or pi.product_id <> all (p_exclude_product_ids)
    )
    and (
      coalesce(array_length(p_exclude_website_urls, 1), 0) = 0
      or coalesce(pi.website_url, '') <> all (p_exclude_website_urls)
    )
),
scored as (
  select
    b.*,
    p.query_norm,
    case
      when p.query_norm = '' then 0::numeric
      when b.title_norm = p.query_norm then 100::numeric
      when b.search_norm like '%' || p.query_norm || '%' then 80::numeric
      else round(
        (
          greatest(
            similarity(b.title_norm, p.query_norm),
            similarity(b.search_norm, p.query_norm)
          ) * 100
        )::numeric,
        2
      )
    end as search_score,
    case
      when p.query_norm = '' then 'empty_query'
      when b.title_norm = p.query_norm then 'exact_title'
      when b.search_norm like '%' || p.query_norm || '%' then 'contains'
      else 'trigram'
    end as match_type
  from base b
  cross join params p
),
deduped as (
  select
    *,
    row_number() over (
      partition by dedupe_key
      order by search_score desc, product_id desc
    ) as dedupe_rn
  from scored
  where query_norm <> ''
    and search_score >= 20
)
select
  product_id,
  title,
  image_url,
  website_url,
  status,
  brand,
  category,
  size,
  search_score,
  match_type
from deduped
where dedupe_rn = 1
order by search_score desc, title asc
limit (select limit_n from params);
$$;
