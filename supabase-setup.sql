-- นรต.79 Station Draft: sync storage
-- Paste everything below into Supabase → SQL Editor → New query → Run.
-- Each person gets a private random code. The table itself is locked: the app can only
-- read or write the one row whose code it already knows, through the two functions below.

create table if not exists public.nrt79_sync (
  code       text primary key,
  data       jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.nrt79_sync enable row level security;
-- No policies on purpose: nobody can list or browse the table directly.
revoke all on table public.nrt79_sync from anon, authenticated;

create or replace function public.nrt79_get(p_code text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object('data', data, 'updated_at', updated_at)
  from public.nrt79_sync
  where code = p_code;
$$;

create or replace function public.nrt79_put(p_code text, p_data jsonb)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare t timestamptz;
begin
  if p_code is null or length(regexp_replace(p_code, '[^A-Z0-9]', '', 'g')) < 16 then
    raise exception 'invalid code';
  end if;
  if pg_column_size(p_data) > 400000 then
    raise exception 'data too large';
  end if;
  insert into public.nrt79_sync (code, data, updated_at)
  values (p_code, p_data, now())
  on conflict (code) do update set data = excluded.data, updated_at = now()
  returning updated_at into t;
  return t;
end;
$$;

revoke all on function public.nrt79_get(text) from public;
revoke all on function public.nrt79_put(text, jsonb) from public;
grant execute on function public.nrt79_get(text) to anon, authenticated;
grant execute on function public.nrt79_put(text, jsonb) to anon, authenticated;
