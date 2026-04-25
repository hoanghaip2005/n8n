create table if not exists public.order_drafts (
  id bigint generated always as identity primary key,
  handoff_queue_id bigint not null references public.lead_handoff_queue(id) on delete cascade,
  customer_phase_state_id bigint references public.customer_phase_state(id) on delete set null,
  oa_id text,
  group_id text,
  status text not null default 'draft',
  source_command_text text,
  customer_name text,
  phone text,
  address text,
  city_name text,
  city_id bigint,
  district_name text,
  district_id bigint,
  ward_name text,
  ward_id bigint,
  location_version text not null default 'v1',
  product_query text,
  product_id bigint,
  product_code text,
  product_name text,
  unit_price numeric(14,2),
  quantity integer not null default 1,
  note text,
  private_note text,
  customer_ship_fee numeric(14,2),
  deposit_amount numeric(14,2),
  transfer_amount numeric(14,2),
  raw_ai_patch jsonb not null default '{}'::jsonb,
  merged_snapshot jsonb not null default '{}'::jsonb,
  product_search_result jsonb not null default '[]'::jsonb,
  location_search_result jsonb not null default '{}'::jsonb,
  order_add_payload jsonb not null default '{}'::jsonb,
  app_order_id text,
  nhanh_order_id bigint,
  nhanh_tracking_url text,
  nhanh_response jsonb not null default '{}'::jsonb,
  last_error_code text,
  last_error text,
  confirmed_at timestamptz,
  confirmed_by_user_id text,
  confirmed_by_display_name text,
  cancelled_at timestamptz,
  cancelled_by_user_id text,
  cancelled_by_display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uq_order_drafts_handoff_queue unique (handoff_queue_id),
  constraint uq_order_drafts_app_order_id unique (app_order_id),
  constraint chk_order_drafts_status check (
    status in (
      'draft',
      'needs_clarification',
      'ready_to_confirm',
      'submitting',
      'created',
      'failed',
      'cancelled'
    )
  ),
  constraint chk_order_drafts_location_version check (
    location_version in ('v1', 'v2')
  ),
  constraint chk_order_drafts_quantity check (
    quantity >= 1
  )
);

create index if not exists idx_order_drafts_status_updated
  on public.order_drafts (status, updated_at desc);

create index if not exists idx_order_drafts_group_updated
  on public.order_drafts (group_id, updated_at desc);

create index if not exists idx_order_drafts_customer_phase
  on public.order_drafts (customer_phase_state_id);

create index if not exists idx_order_drafts_nhanh_order_id
  on public.order_drafts (nhanh_order_id);

create or replace function public.set_order_drafts_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_order_drafts_updated_at
on public.order_drafts;

create trigger trg_order_drafts_updated_at
before update on public.order_drafts
for each row
execute function public.set_order_drafts_updated_at();
