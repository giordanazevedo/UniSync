-- UniSync: Tabela principal de sincronização em nuvem por usuário
-- Cole e execute este script no SQL Editor do seu projeto Supabase.

create table if not exists public.user_app_data (
  user_id uuid primary key references auth.users (id) on delete cascade,
  email text not null default '',
  onboarding_complete boolean not null default false,
  profile jsonb not null default '{}'::jsonb,
  subjects jsonb not null default '[]'::jsonb,
  subject_notes jsonb not null default '{}'::jsonb,
  fixed_tasks jsonb not null default '[]'::jsonb,
  attendance_records jsonb not null default '{}'::jsonb,
  finance_entries jsonb not null default '[]'::jsonb,
  notifications_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_app_data enable row level security;

grant usage on schema public to authenticated;
grant select, insert, update, delete on table public.user_app_data to authenticated;

drop policy if exists "Users manage own app data" on public.user_app_data;
create policy "Users manage own app data" on public.user_app_data
  for all
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create or replace function public.touch_user_app_data_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_touch_user_app_data on public.user_app_data;
create trigger trg_touch_user_app_data
  before update on public.user_app_data
  for each row execute procedure public.touch_user_app_data_updated_at();

create or replace function public.init_user_app_data_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.user_app_data (user_id, email)
  values (new.id, coalesce(new.email, ''))
  on conflict (user_id) do update
    set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists trg_init_user_app_data_after_signup on auth.users;
create trigger trg_init_user_app_data_after_signup
  after insert on auth.users
  for each row execute procedure public.init_user_app_data_for_new_user();
