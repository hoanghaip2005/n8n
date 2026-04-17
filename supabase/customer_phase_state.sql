create table if not exists public.customer_phase_state (
  id bigint generated always as identity primary key,
  channel text not null,
  page_id text,
  sender_id text not null,
  customer_stage text not null default 'new',
  lead_status text not null default 'unknown',
  intent_score integer not null default 0,
  has_clear_need boolean not null default false,
  ask_for_phone_now boolean not null default false,
  handoff_ready boolean not null default false,
  handoff_created boolean not null default false,
  phone_capture_status text not null default 'unknown',
  handoff_reason text,
  need_summary text,
  products_interested text,
  fullname text,
  phone text,
  address text,
  customer_city text,
  customer_district text,
  quoted_at timestamptz,
  asked_phone_at timestamptz,
  last_customer_message_at timestamptz,
  last_bot_reply_at timestamptz,
  last_customer_message_excerpt text,
  last_bot_reply_excerpt text,
  first_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uq_customer_phase_state unique (channel, page_id, sender_id),
  constraint chk_customer_stage check (
    customer_stage in (
      'new',
      'discovering',
      'quoted',
      'qualified',
      'waiting_phone',
      'handoff_ready',
      'cold'
    )
  ),
  constraint chk_lead_status check (
    lead_status in (
      'unknown',
      'interested',
      'qualified',
      'not_interested',
      'inactive'
    )
  ),
  constraint chk_phone_capture_status check (
    phone_capture_status in (
      'unknown',
      'requested',
      'provided',
      'invalid'
    )
  ),
  constraint chk_intent_score check (
    intent_score >= 0 and intent_score <= 100
  )
);

create index if not exists idx_customer_phase_state_sender
  on public.customer_phase_state (sender_id);

create index if not exists idx_customer_phase_state_stage
  on public.customer_phase_state (customer_stage, lead_status);

create index if not exists idx_customer_phase_state_handoff
  on public.customer_phase_state (handoff_ready, handoff_created);

create index if not exists idx_customer_phase_state_last_customer_message_at
  on public.customer_phase_state (last_customer_message_at desc);


create or replace function public.set_customer_phase_state_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_customer_phase_state_updated_at
on public.customer_phase_state;

create trigger trg_customer_phase_state_updated_at
before update on public.customer_phase_state
for each row
execute function public.set_customer_phase_state_updated_at();


create table if not exists public.lead_handoff_queue (
  id bigint generated always as identity primary key,
  channel text not null,
  page_id text,
  sender_id text not null,
  phone text,
  fullname text,
  products_interested text,
  need_summary text,
  handoff_reason text,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  processed_at timestamptz,
  constraint chk_lead_handoff_queue_status check (
    status in ('pending', 'sent', 'done', 'cancelled')
  )
);

create index if not exists idx_lead_handoff_queue_status
  on public.lead_handoff_queue (status, created_at);
