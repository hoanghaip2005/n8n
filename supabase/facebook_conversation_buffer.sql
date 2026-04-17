create table if not exists public.fb_raw_events (
  id bigint generated always as identity primary key,
  channel text not null default 'facebook',
  page_id text not null,
  sender_id text not null,
  mid text not null,
  event_timestamp timestamptz,
  message_text text,
  image_urls jsonb not null default '[]'::jsonb,
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (channel, page_id, sender_id, mid)
);

create index if not exists idx_fb_raw_events_sender_created_at
on public.fb_raw_events (sender_id, created_at desc);

create table if not exists public.fb_conversation_buffer (
  channel text not null default 'facebook',
  page_id text not null,
  sender_id text not null,
  merged_text text not null default '',
  image_urls jsonb not null default '[]'::jsonb,
  first_event_at timestamptz,
  last_event_at timestamptz,
  release_at timestamptz,
  fragment_count integer not null default 0,
  buffer_version integer not null default 0,
  status text not null default 'buffering',
  last_mid text,
  processed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (channel, page_id, sender_id)
);

create index if not exists idx_fb_conversation_buffer_release_at
on public.fb_conversation_buffer (status, release_at);

create or replace function public.merge_facebook_conversation_event(
  p_channel text,
  p_page_id text,
  p_sender_id text,
  p_mid text,
  p_message_text text,
  p_image_urls jsonb default '[]'::jsonb,
  p_event_timestamp timestamptz default now(),
  p_raw_payload jsonb default '{}'::jsonb,
  p_hold_seconds integer default 5
)
returns table (
  channel text,
  page_id text,
  sender_id text,
  buffer_version integer,
  is_duplicate boolean,
  release_at timestamptz,
  fragment_count integer,
  last_mid text
)
language plpgsql
as $$
#variable_conflict use_column
declare
  v_inserted_mid text;
  v_now timestamptz := now();
  v_row public.fb_conversation_buffer%rowtype;
begin
  insert into public.fb_raw_events (
    channel,
    page_id,
    sender_id,
    mid,
    event_timestamp,
    message_text,
    image_urls,
    raw_payload,
    created_at
  )
  values (
    p_channel,
    p_page_id,
    p_sender_id,
    p_mid,
    coalesce(p_event_timestamp, v_now),
    coalesce(p_message_text, ''),
    coalesce(p_image_urls, '[]'::jsonb),
    coalesce(p_raw_payload, '{}'::jsonb),
    v_now
  )
  on conflict (channel, page_id, sender_id, mid) do nothing
  returning mid into v_inserted_mid;

  if v_inserted_mid is null then
    select *
    into v_row
    from public.fb_conversation_buffer as b
    where b.channel = p_channel
      and b.page_id = p_page_id
      and b.sender_id = p_sender_id;

    return query
    select
      p_channel,
      p_page_id,
      p_sender_id,
      coalesce(v_row.buffer_version, 0),
      true,
      coalesce(v_row.release_at, v_now),
      coalesce(v_row.fragment_count, 0),
      coalesce(v_row.last_mid, p_mid);
    return;
  end if;

  insert into public.fb_conversation_buffer (
    channel,
    page_id,
    sender_id,
    merged_text,
    image_urls,
    first_event_at,
    last_event_at,
    release_at,
    fragment_count,
    buffer_version,
    status,
    last_mid,
    processed_at,
    updated_at
  )
  values (
    p_channel,
    p_page_id,
    p_sender_id,
    coalesce(p_message_text, ''),
    coalesce(p_image_urls, '[]'::jsonb),
    coalesce(p_event_timestamp, v_now),
    v_now,
    v_now + make_interval(secs => greatest(p_hold_seconds, 1)),
    1,
    1,
    'buffering',
    p_mid,
    null,
    v_now
  )
  on conflict (channel, page_id, sender_id) do update
  set
    merged_text = case
      when coalesce(public.fb_conversation_buffer.status, '') = 'processed' then
        coalesce(excluded.merged_text, '')
      when coalesce(excluded.merged_text, '') = '' then
        public.fb_conversation_buffer.merged_text
      when coalesce(public.fb_conversation_buffer.merged_text, '') = '' then
        excluded.merged_text
      else
        public.fb_conversation_buffer.merged_text || E'\n' || excluded.merged_text
    end,
    image_urls = case
      when coalesce(public.fb_conversation_buffer.status, '') = 'processed' then
        excluded.image_urls
      else
        coalesce(public.fb_conversation_buffer.image_urls, '[]'::jsonb) || coalesce(excluded.image_urls, '[]'::jsonb)
    end,
    first_event_at = case
      when coalesce(public.fb_conversation_buffer.status, '') = 'processed' then
        excluded.first_event_at
      else
        coalesce(public.fb_conversation_buffer.first_event_at, excluded.first_event_at)
    end,
    last_event_at = v_now,
    release_at = v_now + make_interval(secs => greatest(p_hold_seconds, 1)),
    fragment_count = case
      when coalesce(public.fb_conversation_buffer.status, '') = 'processed' then 1
      else public.fb_conversation_buffer.fragment_count + 1
    end,
    buffer_version = public.fb_conversation_buffer.buffer_version + 1,
    status = 'buffering',
    last_mid = excluded.last_mid,
    processed_at = null,
    updated_at = v_now
  returning *
  into v_row;

  return query
  select
    v_row.channel,
    v_row.page_id,
    v_row.sender_id,
    v_row.buffer_version,
    false,
    v_row.release_at,
    v_row.fragment_count,
    v_row.last_mid;
end;
$$;
