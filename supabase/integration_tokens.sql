create table if not exists public.zalo_oa_tokens (
  token_key text primary key,
  app_id text,
  oa_id text,
  access_token text,
  refresh_token text not null,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_zalo_oa_tokens_expires_at
  on public.zalo_oa_tokens (expires_at);

insert into public.zalo_oa_tokens (
  token_key,
  app_id,
  oa_id,
  access_token,
  refresh_token,
  expires_at
)
values (
  'oa_main',
  null,
  null,
  null,
  'PASTE_ZALO_REFRESH_TOKEN_HERE',
  now() - interval '1 day'
)
on conflict (token_key) do nothing;


create table if not exists public.nhanh_api_tokens (
  token_key text primary key,
  app_id bigint,
  business_id bigint,
  access_token text,
  secret_key text,
  expires_at timestamptz,
  permissions jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  warning_sent_at timestamptz
);

create index if not exists idx_nhanh_api_tokens_expires_at
  on public.nhanh_api_tokens (expires_at);

insert into public.nhanh_api_tokens (
  token_key,
  app_id,
  business_id,
  access_token,
  secret_key,
  expires_at,
  permissions
)
values (
  'nhanh_main',
  null,
  null,
  null,
  null,
  now() - interval '1 day',
  '[]'::jsonb
)
on conflict (token_key) do nothing;
