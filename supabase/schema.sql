-- ============================================================
-- Meu Dojo — schema Postgres para Supabase
-- Não é servido ao browser. Rodar no SQL Editor do projeto Supabase
-- (ou via `supabase db push`) ao provisionar o backend.
-- ============================================================

-- ============================================================
-- 1. PROFILES (1 linha por usuário; estado agregado/escalar)
-- ============================================================
create table public.profiles (
  user_id               uuid primary key references auth.users(id) on delete cascade,
  display_name          text,
  xp                    integer not null default 0,
  total_sessions        integer not null default 0,
  total_meals           integer not null default 0,
  perfect_days          integer not null default 0,
  current_streak        integer not null default 0,
  best_streak           integer not null default 0,
  last_full_day         date,
  last_streak_day       date,
  unlocked_achievements text[] not null default '{}',
  selected_day_id       uuid,
  notifications         jsonb not null default '{
    "train": {"on": false, "time": "18:00"},
    "meal1": {"on": false, "time": "07:30"},
    "meal2": {"on": false, "time": "12:30"},
    "meal3": {"on": false, "time": "16:00"},
    "meal4": {"on": false, "time": "20:00"},
    "meal5": {"on": false, "time": "22:30"},
    "weigh": {"on": false, "time": "08:00"}
  }'::jsonb,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = user_id);

create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Sem policy de insert/delete: as linhas são criadas pelo trigger abaixo
-- (security definer contorna RLS) e removidas via ON DELETE CASCADE de
-- auth.users. Isso impede o client de forjar um profile para outro user_id.


-- ============================================================
-- 2. TRAINING DAYS (dias de treino do usuário, totalmente editáveis)
-- ============================================================
create table public.training_days (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  title        text not null,
  jp           text,
  position     integer not null default 0,
  archived_at  timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index training_days_user_idx on public.training_days (user_id, position);

alter table public.training_days enable row level security;

create policy "training_days_select_own" on public.training_days
  for select using (auth.uid() = user_id);
create policy "training_days_insert_own" on public.training_days
  for insert with check (auth.uid() = user_id);
create policy "training_days_update_own" on public.training_days
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "training_days_delete_own" on public.training_days
  for delete using (auth.uid() = user_id);


-- ============================================================
-- 3. TRAINING EXERCISES (exercícios de cada dia, mesma lógica de edição)
-- ============================================================
create table public.training_exercises (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  day_id       uuid not null references public.training_days(id) on delete cascade,
  name         text not null,
  position     integer not null default 0,
  archived_at  timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index training_exercises_day_idx on public.training_exercises (day_id, position);
create index training_exercises_user_idx on public.training_exercises (user_id);

alter table public.training_exercises enable row level security;

create policy "training_exercises_select_own" on public.training_exercises
  for select using (auth.uid() = user_id);
create policy "training_exercises_insert_own" on public.training_exercises
  for insert with check (auth.uid() = user_id);
create policy "training_exercises_update_own" on public.training_exercises
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "training_exercises_delete_own" on public.training_exercises
  for delete using (auth.uid() = user_id);


-- ============================================================
-- 4. PERSONAL RECORDS (chaveado por exercise_id, não por nome)
-- ============================================================
create table public.personal_records (
  user_id     uuid not null references auth.users(id) on delete cascade,
  exercise_id uuid not null references public.training_exercises(id) on delete cascade,
  weight      numeric(6,2) not null,
  achieved_on date not null,
  updated_at  timestamptz not null default now(),
  primary key (user_id, exercise_id)
);

alter table public.personal_records enable row level security;

create policy "prs_select_own" on public.personal_records
  for select using (auth.uid() = user_id);
create policy "prs_insert_own" on public.personal_records
  for insert with check (auth.uid() = user_id);
create policy "prs_update_own" on public.personal_records
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "prs_delete_own" on public.personal_records
  for delete using (auth.uid() = user_id);


-- ============================================================
-- 5. EXERCISE LOADS (carga de trabalho atual, independente do PR)
-- ============================================================
create table public.exercise_loads (
  user_id     uuid not null references auth.users(id) on delete cascade,
  exercise_id uuid not null references public.training_exercises(id) on delete cascade,
  weight      numeric(6,2) not null,
  updated_at  timestamptz not null default now(),
  primary key (user_id, exercise_id)
);

alter table public.exercise_loads enable row level security;

create policy "loads_select_own" on public.exercise_loads
  for select using (auth.uid() = user_id);
create policy "loads_insert_own" on public.exercise_loads
  for insert with check (auth.uid() = user_id);
create policy "loads_update_own" on public.exercise_loads
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "loads_delete_own" on public.exercise_loads
  for delete using (auth.uid() = user_id);


-- ============================================================
-- 6. DAY SESSIONS (uma sessão de treino por data)
-- ============================================================
create table public.day_sessions (
  user_id        uuid not null references auth.users(id) on delete cascade,
  session_date   date not null,
  training_day_id uuid not null references public.training_days(id),
  exercises      jsonb not null default '{}'::jsonb, -- {"<exercise_id>": true, ...}
  finished       boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  primary key (user_id, session_date)
);

alter table public.day_sessions enable row level security;

create policy "sessions_select_own" on public.day_sessions
  for select using (auth.uid() = user_id);
create policy "sessions_insert_own" on public.day_sessions
  for insert with check (auth.uid() = user_id);
create policy "sessions_update_own" on public.day_sessions
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "sessions_delete_own" on public.day_sessions
  for delete using (auth.uid() = user_id);


-- ============================================================
-- 7. MEAL DAYS (refeições feitas + opção escolhida, por data)
-- ============================================================
create table public.meal_days (
  user_id       uuid not null references auth.users(id) on delete cascade,
  meal_date     date not null,
  meals_done    jsonb not null default '{}'::jsonb, -- {"1": true, "2": true}
  meal_options  jsonb not null default '{}'::jsonb, -- {"3": "0"}
  updated_at    timestamptz not null default now(),
  primary key (user_id, meal_date)
);

alter table public.meal_days enable row level security;

create policy "meals_select_own" on public.meal_days
  for select using (auth.uid() = user_id);
create policy "meals_insert_own" on public.meal_days
  for insert with check (auth.uid() = user_id);
create policy "meals_update_own" on public.meal_days
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "meals_delete_own" on public.meal_days
  for delete using (auth.uid() = user_id);


-- ============================================================
-- 8. BODY MEASUREMENTS (múltiplos registros por dia permitidos, sem dedupe)
-- ============================================================
create table public.body_measurements (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  measured_on  date not null,
  weight       numeric(6,2) not null,
  waist        numeric(6,2),
  chest        numeric(6,2),
  arm          numeric(6,2),
  thigh        numeric(6,2),
  created_at   timestamptz not null default now()
);

create index body_measurements_user_date_idx on public.body_measurements (user_id, measured_on);

alter table public.body_measurements enable row level security;

create policy "measurements_select_own" on public.body_measurements
  for select using (auth.uid() = user_id);
create policy "measurements_insert_own" on public.body_measurements
  for insert with check (auth.uid() = user_id);
create policy "measurements_update_own" on public.body_measurements
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "measurements_delete_own" on public.body_measurements
  for delete using (auth.uid() = user_id);


-- ============================================================
-- 9. SEED da rotina padrão (usada no signup e no hard reset)
-- ============================================================
create or replace function public.seed_default_routine(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seed jsonb := '[
    {"title":"PEITO","jp":"胸","exercises":["Supino inclinado halter","Supino reto guiado/máquina","Supino declinado / Cross declinado","Crossover / Peck deck"]},
    {"title":"COSTAS + BÍCEPS","jp":"背","exercises":["Barra fixa","Remada baixa máquina","Rosca direta barra","Rosca alternada halter"]},
    {"title":"PERNAS (QUADRÍCEPS)","jp":"脚","exercises":["Hack squat","Leg press","Cadeira extensora","Cadeira abdutora"]},
    {"title":"OMBROS + TRÍCEPS","jp":"肩","exercises":["Desenvolvimento máquina/halter","Elevação lateral","Tríceps francês na polia","Tríceps banco"]},
    {"title":"COSTAS + BÍCEPS II","jp":"背","exercises":["Remada cavalinho (T-bar)","Pull down com corda","Face pull","Rosca Scott máquina articulada"]},
    {"title":"PERNAS (POSTERIOR)","jp":"脚","exercises":["Sumo terra bailarina","Mesa flexora","Cadeira flexora","Panturrilha pé/leg press","Cadeira adutora"]}
  ]'::jsonb;
  v_day        jsonb;
  v_day_id     uuid;
  v_day_pos    int := 0;
  v_ex         text;
  v_ex_pos     int;
  v_first_day  uuid;
begin
  for v_day in select * from jsonb_array_elements(v_seed)
  loop
    v_day_pos := v_day_pos + 1;
    insert into public.training_days (user_id, title, jp, position)
    values (p_user, v_day->>'title', v_day->>'jp', v_day_pos)
    returning id into v_day_id;

    if v_first_day is null then
      v_first_day := v_day_id;
    end if;

    v_ex_pos := 0;
    for v_ex in select jsonb_array_elements_text(v_day->'exercises')
    loop
      v_ex_pos := v_ex_pos + 1;
      insert into public.training_exercises (user_id, day_id, name, position)
      values (p_user, v_day_id, v_ex, v_ex_pos);
    end loop;
  end loop;

  update public.profiles set selected_day_id = v_first_day, updated_at = now()
   where user_id = p_user;
end;
$$;


-- ============================================================
-- 10. CRIAÇÃO AUTOMÁTICA DE PROFILE + ROTINA PADRÃO NO SIGNUP
-- ============================================================
-- Trigger em vez de upsert preguiçoso no client: garante que o profile e a
-- rotina já existem antes de qualquer escrita nas tabelas filhas, não
-- importa o método de signup (email/senha, magic link, admin API), e evita
-- a corrida de um double-click em "marcar refeição" logo após o primeiro
-- login disparar antes de um upsert lazy terminar.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (user_id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  )
  on conflict (user_id) do nothing;

  perform public.seed_default_routine(new.id);

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ============================================================
-- 11. RPCs para ações compostas com XP/streak
-- ============================================================
-- Todas rodam `security invoker` (sujeitas à RLS) e filtram por
-- auth.uid() internamente — nunca confiam em identidade vinda do client.
-- Datas ("hoje", "ontem") sempre são passadas pelo client (calculadas com
-- a mesma lógica UTC de todayStr() no index.html), nunca now()/current_date
-- no Postgres, para não divergir do "hoje" que o client já usa.

-- 11a. Grava carga de trabalho; registra novo PR (+25 XP) se `>` estrito
create or replace function public.rpc_upsert_load(
  p_exercise_id uuid,
  p_weight      numeric,
  p_today       date
) returns boolean  -- true se esta chamada registrou um novo PR
language plpgsql
security invoker
as $$
declare
  v_user    uuid := auth.uid();
  v_current numeric;
begin
  insert into exercise_loads (user_id, exercise_id, weight, updated_at)
  values (v_user, p_exercise_id, p_weight, now())
  on conflict (user_id, exercise_id)
    do update set weight = excluded.weight, updated_at = now();

  select weight into v_current
    from personal_records
   where user_id = v_user and exercise_id = p_exercise_id;

  if v_current is null or p_weight > v_current then
    insert into personal_records (user_id, exercise_id, weight, achieved_on, updated_at)
    values (v_user, p_exercise_id, p_weight, p_today, now())
    on conflict (user_id, exercise_id)
      do update set weight = excluded.weight, achieved_on = excluded.achieved_on, updated_at = now();

    update profiles set xp = xp + 25, updated_at = now() where user_id = v_user;
    return true;
  end if;
  return false;
end;
$$;

grant execute on function public.rpc_upsert_load(uuid, numeric, date) to authenticated;


-- 11b. Encerrar treino: marca sessão finalizada, +50+10*feitos XP, streak
create or replace function public.rpc_finish_training(
  p_session_date date,
  p_yesterday    date
) returns public.profiles
language plpgsql
security invoker
as $$
declare
  v_user    uuid := auth.uid();
  v_session record;
  v_done    int;
  v_profile public.profiles;
  v_new_streak int;
begin
  select * into v_session
    from day_sessions
   where user_id = v_user and session_date = p_session_date
   for update;

  if not found then
    raise exception 'no session for date %', p_session_date;
  end if;

  if v_session.finished then
    select * into v_profile from profiles where user_id = v_user;
    return v_profile; -- no-op, espelha o guard "já encerrado" do client
  end if;

  select count(*) into v_done
    from jsonb_each_text(v_session.exercises) e
   where e.value = 'true';

  update day_sessions
     set finished = true, updated_at = now()
   where user_id = v_user and session_date = p_session_date;

  select case
           when p.last_streak_day = p_yesterday then p.current_streak + 1
           else 1
         end
    into v_new_streak
    from profiles p where p.user_id = v_user;

  update profiles p
     set total_sessions  = p.total_sessions + 1,
         xp              = p.xp + 50 + v_done * 10,
         current_streak  = v_new_streak,
         last_streak_day = p_session_date,
         best_streak     = greatest(p.best_streak, v_new_streak),
         updated_at      = now()
   where p.user_id = v_user
   returning * into v_profile;

  return v_profile;
end;
$$;

grant execute on function public.rpc_finish_training(date, date) to authenticated;


-- 11c. Marcar/desmarcar refeição; +10 XP só ao marcar; bônus de dia perfeito
create or replace function public.rpc_toggle_meal(
  p_meal_date date,
  p_meal_id   text
) returns public.profiles
language plpgsql
security invoker
as $$
declare
  v_user            uuid := auth.uid();
  v_meals           jsonb;
  v_was_done        boolean;
  v_now_done_count  int;
  v_profile         public.profiles;
begin
  insert into meal_days (user_id, meal_date)
  values (v_user, p_meal_date)
  on conflict (user_id, meal_date) do nothing;

  select meals_done into v_meals
    from meal_days
   where user_id = v_user and meal_date = p_meal_date
   for update;

  v_was_done := coalesce((v_meals ->> p_meal_id)::boolean, false);

  if v_was_done then
    update meal_days
       set meals_done = meals_done - p_meal_id, updated_at = now()
     where user_id = v_user and meal_date = p_meal_date;
    -- desmarcar nunca muda contadores/xp, igual ao original
    select * into v_profile from profiles where user_id = v_user;
    return v_profile;
  end if;

  update meal_days
     set meals_done = meals_done || jsonb_build_object(p_meal_id, true),
         updated_at = now()
   where user_id = v_user and meal_date = p_meal_date
   returning (select count(*) from jsonb_object_keys(meals_done)) into v_now_done_count;

  update profiles
     set total_meals = total_meals + 1, xp = xp + 10, updated_at = now()
   where user_id = v_user;

  -- Dia perfeito: só é avaliado no fluxo de marcar refeição, igual hoje.
  if v_now_done_count >= 5 then
    update profiles p
       set perfect_days  = p.perfect_days + 1,
           xp            = p.xp + 30,
           last_full_day = p_meal_date,
           updated_at    = now()
     where p.user_id = v_user
       and p.last_full_day is distinct from p_meal_date
       and exists (
         select 1 from day_sessions ds
          where ds.user_id = v_user and ds.session_date = p_meal_date and ds.finished
       );
  end if;

  select * into v_profile from profiles where user_id = v_user;
  return v_profile;
end;
$$;

grant execute on function public.rpc_toggle_meal(date, text) to authenticated;


-- 11d. Registrar medida corporal (+15 XP); sem dedupe por design
create or replace function public.rpc_log_measurement(
  p_measured_on date,
  p_weight      numeric,
  p_waist       numeric,
  p_chest       numeric,
  p_arm         numeric,
  p_thigh       numeric
) returns public.body_measurements
language plpgsql
security invoker
as $$
declare
  v_user uuid := auth.uid();
  v_row  public.body_measurements;
begin
  insert into body_measurements (user_id, measured_on, weight, waist, chest, arm, thigh)
  values (v_user, p_measured_on, p_weight, p_waist, p_chest, p_arm, p_thigh)
  returning * into v_row;

  update profiles set xp = xp + 15, updated_at = now() where user_id = v_user;

  return v_row;
end;
$$;

grant execute on function public.rpc_log_measurement(date, numeric, numeric, numeric, numeric, numeric) to authenticated;


-- 11e. Desbloquear conquista (+100 XP); idempotente
create or replace function public.rpc_unlock_achievement(
  p_achievement_id text
) returns boolean  -- true se esta chamada de fato desbloqueou
language plpgsql
security invoker
as $$
declare
  v_user    uuid := auth.uid();
  v_updated int;
begin
  update profiles
     set unlocked_achievements = array_append(unlocked_achievements, p_achievement_id),
         xp = xp + 100,
         updated_at = now()
   where user_id = v_user
     and not (p_achievement_id = any(unlocked_achievements));

  get diagnostics v_updated = row_count;
  return v_updated > 0;
end;
$$;

grant execute on function public.rpc_unlock_achievement(text) to authenticated;


-- 11f. Reset total (apaga tudo, re-semeia a rotina padrão)
create or replace function public.rpc_hard_reset()
returns void
language plpgsql
security invoker
as $$
declare v_user uuid := auth.uid();
begin
  delete from personal_records  where user_id = v_user;
  delete from exercise_loads    where user_id = v_user;
  delete from day_sessions      where user_id = v_user;
  delete from meal_days         where user_id = v_user;
  delete from body_measurements where user_id = v_user;
  delete from training_exercises where user_id = v_user;
  delete from training_days      where user_id = v_user;

  update profiles
     set xp = 0, total_sessions = 0, total_meals = 0, perfect_days = 0,
         current_streak = 0, best_streak = 0, last_full_day = null, last_streak_day = null,
         unlocked_achievements = '{}', selected_day_id = null,
         notifications = '{
           "train": {"on": false, "time": "18:00"},
           "meal1": {"on": false, "time": "07:30"},
           "meal2": {"on": false, "time": "12:30"},
           "meal3": {"on": false, "time": "16:00"},
           "meal4": {"on": false, "time": "20:00"},
           "meal5": {"on": false, "time": "22:30"},
           "weigh": {"on": false, "time": "08:00"}
         }'::jsonb,
         updated_at = now()
   where user_id = v_user;

  perform public.seed_default_routine(v_user);
end;
$$;

grant execute on function public.rpc_hard_reset() to authenticated;


-- 11g. Reordenar dias/exercícios em lote (evita estados intermediários)
create or replace function public.rpc_reorder_training_days(p_ids uuid[])
returns void
language plpgsql
security invoker
as $$
declare
  v_user uuid := auth.uid();
  v_id   uuid;
  v_pos  int := 0;
begin
  foreach v_id in array p_ids loop
    v_pos := v_pos + 1;
    update training_days set position = v_pos, updated_at = now()
     where id = v_id and user_id = v_user;
  end loop;
end;
$$;

grant execute on function public.rpc_reorder_training_days(uuid[]) to authenticated;

create or replace function public.rpc_reorder_training_exercises(p_day_id uuid, p_ids uuid[])
returns void
language plpgsql
security invoker
as $$
declare
  v_user uuid := auth.uid();
  v_id   uuid;
  v_pos  int := 0;
begin
  foreach v_id in array p_ids loop
    v_pos := v_pos + 1;
    update training_exercises set position = v_pos, updated_at = now()
     where id = v_id and user_id = v_user and day_id = p_day_id;
  end loop;
end;
$$;

grant execute on function public.rpc_reorder_training_exercises(uuid, uuid[]) to authenticated;
