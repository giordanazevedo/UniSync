create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null default '',
  full_name text not null default '',
  course text not null default '',
  notifications_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now(),
  unique (id, user_id)
);

create table if not exists public.class_schedules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  subject_id uuid not null,
  weekday smallint not null check (weekday between 1 and 7),
  starts_at time not null,
  ends_at time not null,
  location text not null default '',
  created_at timestamptz not null default now(),
  check (ends_at > starts_at),
  foreign key (subject_id, user_id)
    references public.subjects (id, user_id) on delete cascade,
  unique (id, user_id),
  unique (subject_id, weekday, starts_at)
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'class_schedules_id_user_id_key'
      and conrelid = 'public.class_schedules'::regclass
  ) then
    alter table public.class_schedules
      add constraint class_schedules_id_user_id_key unique (id, user_id);
  end if;
end;
$$;

create table if not exists public.attendances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  schedule_id uuid not null,
  class_date date not null,
  status text not null check (status in ('present', 'absent', 'justified')),
  created_at timestamptz not null default now(),
  foreign key (schedule_id, user_id)
    references public.class_schedules (id, user_id) on delete cascade,
  unique (schedule_id, class_date)
);

create table if not exists public.fixed_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  category text not null default 'Pessoal',
  weekdays smallint[] not null default '{}',
  due_time time,
  due_on date,
  reminder_enabled boolean not null default false,
  legacy_id text,
  created_at timestamptz not null default now(),
  unique (id, user_id),
  unique (user_id, legacy_id),
  check (weekdays <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]),
  check (cardinality(weekdays) > 0 or due_on is not null)
);

create table if not exists public.task_completions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  task_id uuid not null,
  completed_on date not null,
  created_at timestamptz not null default now(),
  foreign key (task_id, user_id)
    references public.fixed_tasks (id, user_id) on delete cascade,
  unique (task_id, completed_on)
);

create table if not exists public.academic_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  description text not null default '',
  event_type text not null default 'other'
    check (event_type in ('exam', 'assignment', 'holiday', 'other')),
  starts_on date not null,
  ends_on date not null,
  created_at timestamptz not null default now(),
  check (ends_on >= starts_on)
);

create table if not exists public.finance_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  entry_type text not null check (entry_type in ('income', 'expense')),
  amount numeric(12, 2) not null check (amount > 0),
  category text not null,
  description text not null default '',
  occurred_on date not null,
  created_at timestamptz not null default now()
);

create index if not exists class_schedules_user_weekday_idx
  on public.class_schedules (user_id, weekday, starts_at);
create index if not exists attendances_user_date_idx
  on public.attendances (user_id, class_date);
create index if not exists task_completions_user_date_idx
  on public.task_completions (user_id, completed_on);
create index if not exists academic_events_user_dates_idx
  on public.academic_events (user_id, starts_on, ends_on);
create index if not exists finance_entries_user_date_idx
  on public.finance_entries (user_id, occurred_on);

alter table public.profiles enable row level security;
alter table public.subjects enable row level security;
alter table public.class_schedules enable row level security;
alter table public.attendances enable row level security;
alter table public.fixed_tasks enable row level security;
alter table public.task_completions enable row level security;
alter table public.academic_events enable row level security;
alter table public.finance_entries enable row level security;

grant usage on schema public to authenticated;
grant select, insert, update, delete on table
  public.profiles,
  public.subjects,
  public.class_schedules,
  public.attendances,
  public.fixed_tasks,
  public.task_completions,
  public.academic_events,
  public.finance_entries
to authenticated;

drop policy if exists "Users manage their profile" on public.profiles;
create policy "Users manage their profile" on public.profiles
  for all using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

drop policy if exists "Users manage their subjects" on public.subjects;
create policy "Users manage their subjects" on public.subjects
  for all using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "Users manage their schedules" on public.class_schedules;
create policy "Users manage their schedules" on public.class_schedules
  for all using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "Users manage their attendance" on public.attendances;
create policy "Users manage their attendance" on public.attendances
  for all using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "Users manage their fixed tasks" on public.fixed_tasks;
create policy "Users manage their fixed tasks" on public.fixed_tasks
  for all using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "Users manage their task completions" on public.task_completions;
create policy "Users manage their task completions" on public.task_completions
  for all using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "Users manage their academic events" on public.academic_events;
create policy "Users manage their academic events" on public.academic_events
  for all using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "Users manage their finance entries" on public.finance_entries;
create policy "Users manage their finance entries" on public.finance_entries
  for all using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name, course)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'course', '')
  )
  on conflict (id) do update
    set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists create_profile_after_signup on auth.users;
create trigger create_profile_after_signup
  after insert on auth.users
  for each row execute procedure public.create_profile_for_new_user();
