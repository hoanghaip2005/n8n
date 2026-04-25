create table if not exists public.lead_handoff_actions (
  id bigint generated always as identity primary key,
  handoff_queue_id bigint references public.lead_handoff_queue(id) on delete cascade,
  action_type text not null,
  oa_id text,
  group_id text,
  actor_user_id text,
  actor_display_name text,
  actor_app_role text,
  command_text text,
  source_event_id text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_lead_handoff_actions_queue_created
  on public.lead_handoff_actions (handoff_queue_id, created_at desc);

create index if not exists idx_lead_handoff_actions_actor_created
  on public.lead_handoff_actions (actor_user_id, created_at desc);

create index if not exists idx_lead_handoff_actions_group_created
  on public.lead_handoff_actions (group_id, created_at desc);

create index if not exists idx_lead_handoff_actions_action_type
  on public.lead_handoff_actions (action_type, created_at desc);
