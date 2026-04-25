alter table public.lead_handoff_queue
  add column if not exists group_id text;

alter table public.lead_handoff_queue
  add column if not exists customer_phase_state_id bigint references public.customer_phase_state(id) on delete set null;

alter table public.lead_handoff_queue
  add column if not exists claimed_by_user_id text;

alter table public.lead_handoff_queue
  add column if not exists claimed_by_display_name text;

alter table public.lead_handoff_queue
  add column if not exists claimed_at timestamptz;

alter table public.lead_handoff_queue
  add column if not exists closed_by_user_id text;

alter table public.lead_handoff_queue
  add column if not exists closed_by_display_name text;

alter table public.lead_handoff_queue
  add column if not exists closed_reason text;

alter table public.lead_handoff_queue
  add column if not exists closed_at timestamptz;

alter table public.lead_handoff_queue
  add column if not exists source_event_id text;

alter table public.lead_handoff_queue
  drop constraint if exists chk_lead_handoff_queue_status;

alter table public.lead_handoff_queue
  add constraint chk_lead_handoff_queue_status check (
    status in (
      'pending',
      'sent',
      'notified',
      'claimed',
      'done',
      'closed',
      'cancelled'
    )
  );

create index if not exists idx_lead_handoff_queue_group_status
  on public.lead_handoff_queue (group_id, status, created_at desc);

create index if not exists idx_lead_handoff_queue_sender
  on public.lead_handoff_queue (channel, page_id, sender_id, created_at desc);

create index if not exists idx_lead_handoff_queue_claimed_by
  on public.lead_handoff_queue (claimed_by_user_id, claimed_at desc);
