-- Battlefront BR: application schema, access rules and aggregate rankings.
create extension if not exists pgcrypto;
create extension if not exists citext;

create type public.app_role as enum ('user', 'admin');
create type public.game_mode as enum ('galactic_assault', 'heroes_vs_villains', 'hero_showdown');
create type public.hero_side as enum ('light', 'dark');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username citext not null unique check (username ~ '^[a-z0-9](?:[a-z0-9_]{1,22}[a-z0-9])$'),
  display_name text not null check (char_length(display_name) between 2 and 40),
  gamertag citext not null unique check (char_length(gamertag) between 2 and 32),
  public_slug citext not null unique check (public_slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  avatar_url text check (avatar_url is null or avatar_url ~ '^https://'),
  bio text not null default '' check (char_length(bio) <= 280),
  role public.app_role not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.players (
  id uuid primary key default gen_random_uuid(),
  gamertag citext not null unique check (char_length(gamertag) between 2 and 32),
  slug citext not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  display_name text check (display_name is null or char_length(display_name) <= 40),
  bio text not null default '' check (char_length(bio) <= 500),
  avatar_url text check (avatar_url is null or avatar_url ~ '^https://'),
  profile_id uuid unique references public.profiles(id) on delete set null,
  is_active boolean not null default true,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.heroes (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (char_length(name) between 2 and 60),
  slug citext not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  side public.hero_side not null,
  description text not null default '' check (char_length(description) <= 280),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.ratings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete restrict,
  mode public.game_mode not null,
  score numeric(3,1) not null check (score >= 0.5 and score <= 10 and mod(score * 2, 1) = 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, player_id, mode)
);

create table public.hero_ratings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete restrict,
  hero_id uuid not null references public.heroes(id) on delete restrict,
  score numeric(3,1) not null check (score >= 0.5 and score <= 10 and mod(score * 2, 1) = 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, player_id, hero_id)
);

create table public.favorite_heroes (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  hero_id uuid not null references public.heroes(id) on delete restrict,
  position smallint not null check (position between 1 and 4),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (profile_id, position),
  unique (profile_id, hero_id)
);

-- This table is deliberately private; only the controlled RPC functions touch it.
create table public.rating_rate_limits (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  last_rating_at timestamptz not null default now()
);

create index ratings_player_mode_idx on public.ratings (player_id, mode) include (score);
create index ratings_user_idx on public.ratings (user_id);
create index hero_ratings_hero_player_idx on public.hero_ratings (hero_id, player_id) include (score);
create index hero_ratings_user_idx on public.hero_ratings (user_id);
create index players_active_slug_idx on public.players (is_active, slug);
create index favorite_heroes_profile_idx on public.favorite_heroes (profile_id, position);

create or replace function public.set_updated_at() returns trigger
language plpgsql security invoker set search_path = public as $$
begin new.updated_at = now(); return new; end; $$;

create trigger profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger players_updated_at before update on public.players for each row execute function public.set_updated_at();
create trigger heroes_updated_at before update on public.heroes for each row execute function public.set_updated_at();
create trigger ratings_updated_at before update on public.ratings for each row execute function public.set_updated_at();
create trigger hero_ratings_updated_at before update on public.hero_ratings for each row execute function public.set_updated_at();
create trigger favorites_updated_at before update on public.favorite_heroes for each row execute function public.set_updated_at();

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare base_slug text; requested_username text;
begin
  requested_username := lower(coalesce(new.raw_user_meta_data->>'username', ''));
  if requested_username !~ '^[a-z0-9](?:[a-z0-9_]{1,22}[a-z0-9])$' then requested_username := null; end if;
  base_slug := coalesce(requested_username, lower(regexp_replace(split_part(coalesce(new.email, new.id::text), '@', 1), '[^a-z0-9]+', '-', 'g')));
  base_slug := trim(both '-' from base_slug);
  if char_length(base_slug) < 2 then base_slug := 'membro'; end if;
  insert into public.profiles (id, username, display_name, gamertag, public_slug)
  values (new.id, coalesce(requested_username, 'membro_' || substr(new.id::text, 1, 6)), left(base_slug, 40), left(base_slug, 25) || '-' || substr(new.id::text, 1, 6), replace(left(base_slug, 50), '_', '-') || '-' || substr(new.id::text, 1, 6));
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- Role is never writable through application API. Supabase SQL Editor (postgres) remains
-- the deliberate bootstrap path for the first administrator.
create or replace function public.prevent_role_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role and current_user <> 'postgres' then
    raise exception 'role changes are only allowed from the Supabase SQL Editor';
  end if;
  return new;
end; $$;
create trigger profiles_prevent_role_change before update on public.profiles for each row execute function public.prevent_role_change();

create or replace function public.prevent_username_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.username is distinct from old.username then raise exception 'username cannot be changed'; end if;
  return new;
end; $$;
create trigger profiles_prevent_username_change before update on public.profiles for each row execute function public.prevent_username_change();

alter table public.profiles enable row level security;
alter table public.players enable row level security;
alter table public.heroes enable row level security;
alter table public.ratings enable row level security;
alter table public.hero_ratings enable row level security;
alter table public.favorite_heroes enable row level security;
alter table public.rating_rate_limits enable row level security;

create policy "profiles: own read" on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin());
create policy "profiles: own update" on public.profiles for update to authenticated using (id = auth.uid() or public.is_admin()) with check (id = auth.uid() or public.is_admin());
create policy "players: admins manage" on public.players for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "heroes: public read" on public.heroes for select using (is_active or public.is_admin());
create policy "heroes: admins manage" on public.heroes for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "ratings: owner read" on public.ratings for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "ratings: owner write" on public.ratings for all to authenticated using (user_id = auth.uid() or public.is_admin()) with check (user_id = auth.uid() or public.is_admin());
create policy "hero ratings: owner read" on public.hero_ratings for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "hero ratings: owner write" on public.hero_ratings for all to authenticated using (user_id = auth.uid() or public.is_admin()) with check (user_id = auth.uid() or public.is_admin());
create policy "favorites: owner manage" on public.favorite_heroes for all to authenticated using (profile_id = auth.uid() or public.is_admin()) with check (profile_id = auth.uid() or public.is_admin());

-- Sanitized public read models: UUIDs, emails and rating authors are never exposed.
create or replace view public.public_players as
select slug::text, gamertag::text, display_name, bio, avatar_url, created_at
from public.players where is_active;
create or replace view public.public_heroes as
select slug::text, name, side::text, description
from public.heroes where is_active;
create or replace view public.public_profiles as
select p.public_slug::text, p.display_name, p.gamertag::text, p.avatar_url, p.bio, p.created_at,
  coalesce((select count(*) from public.ratings r where r.user_id = p.id), 0) +
  coalesce((select count(*) from public.hero_ratings hr where hr.user_id = p.id), 0) as ratings_count
from public.profiles p;
create or replace view public.public_favorite_heroes as
select p.public_slug::text as member_slug, h.slug::text as hero_slug, h.name as hero_name, h.side::text, f.position
from public.favorite_heroes f join public.profiles p on p.id=f.profile_id join public.heroes h on h.id=f.hero_id
where h.is_active;

revoke all on public.profiles, public.players, public.ratings, public.hero_ratings, public.favorite_heroes, public.rating_rate_limits from anon;
grant select on public.public_players, public.public_heroes, public.public_profiles, public.public_favorite_heroes to anon, authenticated;

create or replace function public.check_rating_limit() returns void
language plpgsql security definer set search_path = public as $$
declare last_at timestamptz;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  insert into public.rating_rate_limits(user_id) values (auth.uid())
  on conflict (user_id) do update set last_rating_at = public.rating_rate_limits.last_rating_at
  returning last_rating_at into last_at;
  if last_at > now() - interval '2 seconds' then raise exception 'please wait before rating again'; end if;
  update public.rating_rate_limits set last_rating_at=now() where user_id=auth.uid();
end; $$;

create or replace function public.submit_rating(p_player_slug text, p_mode public.game_mode, p_score numeric)
returns void language plpgsql security definer set search_path = public as $$
declare target_id uuid;
begin
  if p_score < .5 or p_score > 10 or mod(p_score * 2, 1) <> 0 then raise exception 'invalid score'; end if;
  perform public.check_rating_limit();
  select id into target_id from public.players where slug = p_player_slug::citext and is_active;
  if target_id is null then raise exception 'player not found'; end if;
  insert into public.ratings(user_id, player_id, mode, score) values(auth.uid(), target_id, p_mode, p_score)
  on conflict (user_id, player_id, mode) do update set score=excluded.score, updated_at=now();
end; $$;

create or replace function public.submit_hero_rating(p_player_slug text, p_hero_slug text, p_score numeric)
returns void language plpgsql security definer set search_path = public as $$
declare target_player uuid; target_hero uuid;
begin
  if p_score < .5 or p_score > 10 or mod(p_score * 2, 1) <> 0 then raise exception 'invalid score'; end if;
  perform public.check_rating_limit();
  select id into target_player from public.players where slug=p_player_slug::citext and is_active;
  select id into target_hero from public.heroes where slug=p_hero_slug::citext and is_active;
  if target_player is null or target_hero is null then raise exception 'target not found'; end if;
  insert into public.hero_ratings(user_id, player_id, hero_id, score) values(auth.uid(), target_player, target_hero, p_score)
  on conflict (user_id, player_id, hero_id) do update set score=excluded.score, updated_at=now();
end; $$;

create or replace function public.set_favorite_heroes(p_hero_slugs text[])
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if coalesce(array_length(p_hero_slugs, 1), 0) <> 4 or (select count(distinct lower(x)) from unnest(p_hero_slugs) x) <> 4 then
    raise exception 'choose exactly four different heroes';
  end if;
  if (select count(*) from public.heroes where slug = any(p_hero_slugs::citext[]) and is_active) <> 4 then raise exception 'hero not found'; end if;
  delete from public.favorite_heroes where profile_id=auth.uid();
  insert into public.favorite_heroes(profile_id, hero_id, position)
  select auth.uid(), h.id, s.ordinality::smallint from unnest(p_hero_slugs) with ordinality s(slug, ordinality)
  join public.heroes h on h.slug=s.slug::citext;
end; $$;

create or replace function public.ranking_by_mode(p_mode public.game_mode, p_min integer default 3)
returns table(player_slug text, gamertag text, display_name text, avatar_url text, average_score numeric, ratings_count bigint, position bigint, provisional boolean)
language sql stable security definer set search_path = public as $$
 with scores as (select p.id,p.slug::text player_slug,p.gamertag::text,p.display_name,p.avatar_url,round(avg(r.score),2) average_score,count(r.id) ratings_count from public.players p join public.ratings r on r.player_id=p.id and r.mode=p_mode where p.is_active group by p.id),
 official as (select *, rank() over(order by average_score desc, ratings_count desc, gamertag) position from scores where ratings_count >= greatest(p_min,1))
 select s.player_slug,s.gamertag,s.display_name,s.avatar_url,s.average_score,s.ratings_count,o.position,(s.ratings_count < greatest(p_min,1)) from scores s left join official o using(player_slug) order by (s.ratings_count < greatest(p_min,1)), o.position nulls last, s.average_score desc, s.gamertag;
$$;

create or replace function public.general_ranking(p_min integer default 3)
returns table(player_slug text, gamertag text, display_name text, avatar_url text, average_score numeric, assault_average numeric, hvv_average numeric, showdown_average numeric, ratings_count bigint, position bigint, provisional boolean)
language sql stable security definer set search_path = public as $$
 with piv as (select p.id,p.slug::text player_slug,p.gamertag::text,p.display_name,p.avatar_url,
   round(avg(r.score) filter(where r.mode='galactic_assault'),2) assault_average, round(avg(r.score) filter(where r.mode='heroes_vs_villains'),2) hvv_average, round(avg(r.score) filter(where r.mode='hero_showdown'),2) showdown_average,
   count(r.id) filter(where r.mode='galactic_assault') assault_count,count(r.id) filter(where r.mode='heroes_vs_villains') hvv_count,count(r.id) filter(where r.mode='hero_showdown') showdown_count
   from public.players p join public.ratings r on r.player_id=p.id where p.is_active group by p.id),
 scores as (select *,round((assault_average+hvv_average+showdown_average)/3,2) average_score,(assault_count+hvv_count+showdown_count) ratings_count,
  (assault_count>=greatest(p_min,1) and hvv_count>=greatest(p_min,1) and showdown_count>=greatest(p_min,1)) official from piv where assault_average is not null and hvv_average is not null and showdown_average is not null),
 official as (select *,rank() over(order by average_score desc,ratings_count desc,gamertag) position from scores where official)
 select s.player_slug,s.gamertag,s.display_name,s.avatar_url,s.average_score,s.assault_average,s.hvv_average,s.showdown_average,s.ratings_count,o.position,not s.official from scores s left join official o using(player_slug) order by not s.official,o.position nulls last,s.average_score desc;
$$;

create or replace function public.hero_ranking(p_hero_slug text, p_min integer default 3)
returns table(player_slug text, gamertag text, display_name text, avatar_url text, average_score numeric, ratings_count bigint, position bigint, provisional boolean)
language sql stable security definer set search_path = public as $$
 with scores as (select p.id,p.slug::text player_slug,p.gamertag::text,p.display_name,p.avatar_url,round(avg(hr.score),2) average_score,count(hr.id) ratings_count from public.players p join public.hero_ratings hr on hr.player_id=p.id join public.heroes h on h.id=hr.hero_id where p.is_active and h.slug=p_hero_slug::citext group by p.id),
 official as (select *,rank() over(order by average_score desc,ratings_count desc,gamertag) position from scores where ratings_count>=greatest(p_min,1))
 select s.player_slug,s.gamertag,s.display_name,s.avatar_url,s.average_score,s.ratings_count,o.position,(s.ratings_count<greatest(p_min,1)) from scores s left join official o using(player_slug) order by (s.ratings_count<greatest(p_min,1)),o.position nulls last,s.average_score desc;
$$;

create or replace function public.admin_import_players(p_rows jsonb)
returns table(line integer, gamertag text, error text) language plpgsql security definer set search_path=public as $$
declare row_data jsonb; i integer:=0; clean_tag text; clean_name text; clean_bio text; clean_slug text; has_errors boolean:=false;
begin
 if not public.is_admin() then raise exception 'admin required'; end if;
 if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows)>100 then raise exception 'invalid import size'; end if;
 create temporary table import_candidates(line integer, gamertag text, display_name text, bio text, slug text, error text) on commit drop;
 for row_data in select * from jsonb_array_elements(p_rows) loop
   i:=i+1; clean_tag:=trim(row_data->>'gamertag'); clean_name:=nullif(trim(row_data->>'display_name'),''); clean_bio:=coalesce(trim(row_data->>'bio'),'');
   clean_slug:=trim(both '-' from lower(regexp_replace(clean_tag,'[^a-z0-9]+','-','g')));
   insert into import_candidates values (i,clean_tag,clean_name,clean_bio,clean_slug,case when clean_tag='' or length(clean_tag)>32 or clean_slug='' then 'gamertag inválido' when exists(select 1 from public.players where gamertag=clean_tag::citext) then 'gamertag já cadastrado' else null end);
 end loop;
 update import_candidates c set error='gamertag repetido no CSV' where error is null and exists(select 1 from import_candidates d where lower(d.gamertag)=lower(c.gamertag) and d.line<>c.line);
 select exists(select 1 from import_candidates where error is not null) into has_errors;
 if has_errors then return query select c.line,c.gamertag,c.error from import_candidates c where c.error is not null order by c.line; return; end if;
 insert into public.players(gamertag,slug,display_name,bio,created_by) select gamertag,slug||'-'||substr(gen_random_uuid()::text,1,6),display_name,bio,auth.uid() from import_candidates;
end; $$;

grant execute on function public.ranking_by_mode(public.game_mode, integer), public.general_ranking(integer), public.hero_ranking(text, integer) to anon, authenticated;
grant execute on function public.submit_rating(text, public.game_mode, numeric), public.submit_hero_rating(text,text,numeric), public.set_favorite_heroes(text[]), public.admin_import_players(jsonb) to authenticated;
