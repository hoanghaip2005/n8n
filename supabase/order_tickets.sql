create extension if not exists pgcrypto;

create table if not exists public.order_tickets (
  id uuid primary key default gen_random_uuid(),
  ticket_code text not null unique,
  source text not null,
  source_user_id text not null,
  source_message_id text unique,
  customer_name text,
  phone text,
  address text,
  product_summary text,
  product_details jsonb not null default '[]'::jsonb,
  latest_customer_message text,
  ticket_message text,
  status text not null default 'pending_send',
  zalo_group_id text,
  zalo_sent_at timestamptz,
  zalo_response jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists order_tickets_status_idx
  on public.order_tickets (status);

create index if not exists order_tickets_source_user_id_idx
  on public.order_tickets (source_user_id);
