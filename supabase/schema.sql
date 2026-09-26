-- =====================================================================
--  Déclic — schéma Supabase
--  À exécuter une fois dans : Supabase > SQL Editor > New query > Run
--  Le script est ré-exécutable (idempotent).
-- =====================================================================


-- ---------------------------------------------------------------------
--  Tables
-- ---------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  username text not null check (char_length(username) between 1 and 24),
  avatar_emoji text not null default '😎',
  avatar_color int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 40),
  emoji text not null default '📸',
  invite_code text not null unique,
  vote_hour int not null default 20 check (vote_hour between 8 and 23),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id uuid not null references public.groups on delete cascade,
  user_id uuid not null references public.profiles on delete cascade,
  role text not null default 'member' check (role in ('admin', 'member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table if not exists public.prompts (
  id bigserial primary key,
  group_id uuid references public.groups on delete cascade,
  text text not null check (char_length(text) between 3 and 80),
  emoji text not null default '📸',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create unique index if not exists prompts_unique_text
  on public.prompts (coalesce(group_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(text));

create table if not exists public.challenges (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups on delete cascade,
  day date not null,
  prompt_id bigint references public.prompts on delete set null,
  text text not null,
  emoji text not null,
  created_at timestamptz not null default now(),
  unique (group_id, day)
);

create table if not exists public.submissions (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges on delete cascade,
  user_id uuid not null references public.profiles on delete cascade,
  photo_path text not null,
  caption text check (caption is null or char_length(caption) <= 140),
  created_at timestamptz not null default now(),
  unique (challenge_id, user_id)
);

create table if not exists public.votes (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges on delete cascade,
  voter_id uuid not null references public.profiles on delete cascade,
  submission_id uuid not null references public.submissions on delete cascade,
  category text not null check (category in ('funny', 'beautiful', 'original')),
  created_at timestamptz not null default now(),
  unique (challenge_id, voter_id, category)
);

create index if not exists challenges_group_day on public.challenges (group_id, day desc);
create index if not exists submissions_challenge on public.submissions (challenge_id);
create index if not exists votes_challenge on public.votes (challenge_id);
create index if not exists members_user on public.group_members (user_id);

-- ---------------------------------------------------------------------
--  Helpers (fuseau horaire du jeu : Europe/Paris)
-- ---------------------------------------------------------------------

create or replace function public.app_today() returns date
language sql stable as $$ select (now() at time zone 'Europe/Paris')::date $$;

create or replace function public.app_hour() returns int
language sql stable as $$ select extract(hour from (now() at time zone 'Europe/Paris'))::int $$;

create or replace function public.is_member(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from group_members where group_id = gid and user_id = auth.uid())
$$;

create or replace function public.is_admin(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from group_members where group_id = gid and user_id = auth.uid() and role = 'admin')
$$;

create or replace function public.challenge_group(cid uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select group_id from challenges where id = cid
$$;

-- Phase d'un défi : 'upcoming' | 'submission' | 'voting' | 'closed'
--  * submission : on poste sa photo (jusqu'à l'heure du vote, ou dès que tout le monde a posté)
--    Le vote ne s'ouvre pas tant qu'il y a moins de 2 photos.
--  * voting     : on vote (3 catégories) jusqu'à minuit, ou jusqu'à ce que tout le monde ait voté
--  * closed     : résultats visibles, points comptés
create or replace function public.challenge_phase(cid uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare
  c challenges;
  g groups;
  n_members int;
  n_subs int;
  n_eligible int;
  n_done int;
begin
  select * into c from challenges where id = cid;
  if not found then return null; end if;
  if c.day < app_today() then return 'closed'; end if;
  if c.day > app_today() then return 'upcoming'; end if;

  select * into g from groups where id = c.group_id;
  select count(*) into n_members from group_members where group_id = c.group_id;
  select count(*) into n_subs from submissions where challenge_id = cid;

  if n_subs < 2 or (app_hour() < g.vote_hour and n_subs < n_members) then
    return 'submission';
  end if;

  select count(*) into n_eligible from group_members m
   where m.group_id = c.group_id
     and exists (select 1 from submissions s where s.challenge_id = cid and s.user_id <> m.user_id);
  select count(*) into n_done from group_members m
   where m.group_id = c.group_id
     and (select count(*) from votes v where v.challenge_id = cid and v.voter_id = m.user_id) >= 3;
  if n_eligible > 0 and n_done >= n_eligible then return 'closed'; end if;
  return 'voting';
end $$;

create or replace function public.has_submitted(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from submissions where challenge_id = cid and user_id = auth.uid())
$$;

create or replace function public.can_see_submissions(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_member(challenge_group(cid))
     and (has_submitted(cid) or challenge_phase(cid) <> 'submission')
$$;

create or replace function public.gen_invite_code() returns text
language plpgsql volatile as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text;
begin
  loop
    code := '';
    for i in 1..6 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.groups where invite_code = code);
  end loop;
  return code;
end $$;

-- Crée (si besoin) le défi d'un groupe pour un jour donné.
-- Les idées proposées par le groupe passent en priorité, puis le catalogue global.
create or replace function public.ensure_challenge(gid uuid, d date) returns challenges
language plpgsql security definer set search_path = public as $$
declare
  c challenges;
  p prompts;
begin
  select * into c from challenges where group_id = gid and day = d;
  if found then return c; end if;

  select * into p from prompts pr
   where (pr.group_id is null or pr.group_id = gid)
     and not exists (select 1 from challenges ch where ch.group_id = gid and ch.prompt_id = pr.id)
   order by (pr.group_id is not null) desc, random()
   limit 1;
  if not found then
    select * into p from prompts pr
     where pr.group_id is null or pr.group_id = gid
     order by random() limit 1;
  end if;

  insert into challenges (group_id, day, prompt_id, text, emoji)
  values (gid, d, p.id, coalesce(p.text, 'Photo libre !'), coalesce(p.emoji, '📸'))
  on conflict (group_id, day) do nothing
  returning * into c;
  if c.id is null then
    select * into c from challenges where group_id = gid and day = d;
  end if;
  return c;
end $$;
revoke execute on function public.ensure_challenge(uuid, date) from public, anon, authenticated;

create or replace function public.my_streak(gid uuid) returns int
language plpgsql stable security definer set search_path = public as $$
declare
  d date := app_today();
  n int := 0;
begin
  -- aujourd'hui compte si déjà posté, sinon on part d'hier (la série n'est pas encore cassée)
  if not exists (select 1 from submissions s join challenges c on c.id = s.challenge_id
                  where c.group_id = gid and c.day = d and s.user_id = auth.uid()) then
    d := d - 1;
  end if;
  while exists (select 1 from submissions s join challenges c on c.id = s.challenge_id
                 where c.group_id = gid and c.day = d and s.user_id = auth.uid()) loop
    n := n + 1;
    d := d - 1;
  end loop;
  return n;
end $$;

-- ---------------------------------------------------------------------
--  RPC appelées par l'application
-- ---------------------------------------------------------------------

create or replace function public.create_group(p_name text, p_emoji text) returns groups
language plpgsql security definer set search_path = public as $$
declare g groups;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  insert into groups (name, emoji, invite_code, created_by)
  values (trim(p_name), coalesce(nullif(p_emoji, ''), '📸'), gen_invite_code(), auth.uid())
  returning * into g;
  insert into group_members (group_id, user_id, role) values (g.id, auth.uid(), 'admin');
  return g;
end $$;

create or replace function public.join_group(p_code text) returns groups
language plpgsql security definer set search_path = public as $$
declare g groups;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into g from groups where invite_code = upper(trim(p_code));
  if not found then raise exception 'invalid_code'; end if;
  if (select count(*) from group_members where group_id = g.id) >= 50 then
    raise exception 'group_full';
  end if;
  insert into group_members (group_id, user_id) values (g.id, auth.uid())
  on conflict do nothing;
  return g;
end $$;

create or replace function public.leave_group(gid uuid) returns void
language plpgsql security definer set search_path = public as $$
declare was_admin boolean;
begin
  select role = 'admin' into was_admin from group_members where group_id = gid and user_id = auth.uid();
  if not found then return; end if;
  delete from group_members where group_id = gid and user_id = auth.uid();
  if not exists (select 1 from group_members where group_id = gid) then
    delete from groups where id = gid;
  elsif was_admin and not exists (select 1 from group_members where group_id = gid and role = 'admin') then
    update group_members set role = 'admin'
     where group_id = gid
       and user_id = (select user_id from group_members where group_id = gid order by joined_at limit 1);
  end if;
end $$;

create or replace function public.regenerate_invite_code(gid uuid) returns text
language plpgsql security definer set search_path = public as $$
declare code text;
begin
  if not is_admin(gid) then raise exception 'not_admin'; end if;
  code := gen_invite_code();
  update groups set invite_code = code where id = gid;
  return code;
end $$;

-- État du jour pour un groupe (écran principal du groupe)
create or replace function public.get_group_today(gid uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  c challenges;
  g groups;
begin
  if not is_member(gid) then raise exception 'not_member'; end if;
  select * into g from groups where id = gid;
  c := ensure_challenge(gid, app_today());
  return jsonb_build_object(
    'challenge', to_jsonb(c),
    'phase', challenge_phase(c.id),
    'vote_hour', g.vote_hour,
    'member_count', (select count(*) from group_members where group_id = gid),
    'submission_count', (select count(*) from submissions where challenge_id = c.id),
    'my_submission', (select to_jsonb(s) from submissions s where s.challenge_id = c.id and s.user_id = auth.uid()),
    'my_vote_count', (select count(*) from votes v where v.challenge_id = c.id and v.voter_id = auth.uid()),
    'voters_done', (select count(*) from group_members m where m.group_id = gid
                     and (select count(*) from votes v where v.challenge_id = c.id and v.voter_id = m.user_id) >= 3),
    'streak', my_streak(gid)
  );
end $$;

-- Liste de mes groupes avec le défi du jour (écran d'accueil)
create or replace function public.get_my_groups() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  result jsonb := '[]'::jsonb;
  g groups;
  c challenges;
begin
  for g in
    select gr.* from groups gr join group_members m on m.group_id = gr.id
     where m.user_id = auth.uid() order by m.joined_at
  loop
    c := ensure_challenge(g.id, app_today());
    result := result || jsonb_build_object(
      'group', to_jsonb(g),
      'role', (select role from group_members where group_id = g.id and user_id = auth.uid()),
      'member_count', (select count(*) from group_members where group_id = g.id),
      'challenge', to_jsonb(c),
      'phase', challenge_phase(c.id),
      'submission_count', (select count(*) from submissions where challenge_id = c.id),
      'has_submitted', exists (select 1 from submissions where challenge_id = c.id and user_id = auth.uid()),
      'my_vote_count', (select count(*) from votes where challenge_id = c.id and voter_id = auth.uid()),
      'streak', my_streak(g.id)
    );
  end loop;
  return result;
end $$;

-- Défis des 7 prochains jours (pour programmer les notifications avec le thème du jour)
create or replace function public.get_upcoming_challenges() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  result jsonb := '[]'::jsonb;
  g groups;
  c challenges;
  i int;
begin
  for g in
    select gr.* from groups gr join group_members m on m.group_id = gr.id where m.user_id = auth.uid()
  loop
    for i in 0..7 loop
      c := ensure_challenge(g.id, app_today() + i);
      result := result || jsonb_build_object(
        'group_name', g.name, 'group_emoji', g.emoji, 'vote_hour', g.vote_hour,
        'day', c.day, 'text', c.text, 'emoji', c.emoji);
    end loop;
  end loop;
  return result;
end $$;

-- Classement d'un groupe sur une période (une saison = un mois)
--  +1 pt par photo postée, +2 pts par vote reçu, +3 pts par catégorie remportée
create or replace function public.get_leaderboard(gid uuid, from_day date, to_day date)
returns table (
  user_id uuid, username text, avatar_emoji text, avatar_color int,
  points int, participations int, votes_received int, wins int
)
language sql stable security definer set search_path = public as $$
  with ch as (
    select c.id from challenges c
     where c.group_id = gid and c.day between from_day and least(to_day, app_today())
       and challenge_phase(c.id) = 'closed'
  ),
  subs as (select s.* from submissions s join ch on ch.id = s.challenge_id),
  vr as (
    select s.user_id, v.challenge_id, v.category, count(*) as n
      from votes v join subs s on s.id = v.submission_id
     group by 1, 2, 3
  ),
  best as (select challenge_id, category, max(n) as mx from vr group by 1, 2),
  w as (
    select vr.user_id, count(*) as wins
      from vr join best b on b.challenge_id = vr.challenge_id and b.category = vr.category
     where vr.n = b.mx
     group by 1
  ),
  agg as (
    select m.user_id,
           (select count(*) from subs s where s.user_id = m.user_id)::int as participations,
           coalesce((select sum(n) from vr where vr.user_id = m.user_id), 0)::int as votes_received,
           coalesce((select w.wins from w where w.user_id = m.user_id), 0)::int as wins
      from group_members m
     where m.group_id = gid
  )
  select a.user_id, p.username, p.avatar_emoji, p.avatar_color,
         (a.participations * 1 + a.votes_received * 2 + a.wins * 3)::int as points,
         a.participations, a.votes_received, a.wins
    from agg a join profiles p on p.id = a.user_id
   where is_member(gid)
   order by points desc, wins desc, votes_received desc, p.username
$$;

create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public, auth as $$
declare gid uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  for gid in select group_id from public.group_members where user_id = auth.uid() loop
    perform public.leave_group(gid);
  end loop;
  delete from auth.users where id = auth.uid();
end $$;

-- ---------------------------------------------------------------------
--  Création automatique du profil à l'inscription
-- ---------------------------------------------------------------------

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, avatar_emoji, avatar_color)
  values (
    new.id,
    left(coalesce(nullif(trim(new.raw_user_meta_data ->> 'username'), ''), split_part(new.email, '@', 1), 'Joueur'), 24),
    coalesce(nullif(new.raw_user_meta_data ->> 'avatar_emoji', ''), '😎'),
    coalesce((new.raw_user_meta_data ->> 'avatar_color')::int, 0)
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
--  Row Level Security
-- ---------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.prompts enable row level security;
alter table public.challenges enable row level security;
alter table public.submissions enable row level security;
alter table public.votes enable row level security;

drop policy if exists "profiles read" on public.profiles;
create policy "profiles read" on public.profiles for select to authenticated using (true);
drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "groups read" on public.groups;
create policy "groups read" on public.groups for select to authenticated using (is_member(id));
drop policy if exists "groups update admin" on public.groups;
create policy "groups update admin" on public.groups for update to authenticated
  using (is_admin(id)) with check (is_admin(id));

drop policy if exists "members read" on public.group_members;
create policy "members read" on public.group_members for select to authenticated using (is_member(group_id));
drop policy if exists "members kick" on public.group_members;
create policy "members kick" on public.group_members for delete to authenticated
  using (is_admin(group_id) and user_id <> auth.uid());

drop policy if exists "prompts read" on public.prompts;
create policy "prompts read" on public.prompts for select to authenticated
  using (group_id is null or is_member(group_id));
drop policy if exists "prompts add" on public.prompts;
create policy "prompts add" on public.prompts for insert to authenticated
  with check (group_id is not null and is_member(group_id) and created_by = auth.uid());
drop policy if exists "prompts delete" on public.prompts;
create policy "prompts delete" on public.prompts for delete to authenticated
  using (group_id is not null and (created_by = auth.uid() or is_admin(group_id)));

drop policy if exists "challenges read" on public.challenges;
create policy "challenges read" on public.challenges for select to authenticated
  using (is_member(group_id) and day <= app_today());

drop policy if exists "submissions read" on public.submissions;
create policy "submissions read" on public.submissions for select to authenticated
  using (user_id = auth.uid() or can_see_submissions(challenge_id));
drop policy if exists "submissions insert" on public.submissions;
create policy "submissions insert" on public.submissions for insert to authenticated
  with check (
    user_id = auth.uid()
    and is_member(challenge_group(challenge_id))
    and challenge_phase(challenge_id) = 'submission'
    and split_part(photo_path, '/', 1) = challenge_group(challenge_id)::text
  );
drop policy if exists "submissions update" on public.submissions;
create policy "submissions update" on public.submissions for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "submissions delete" on public.submissions;
create policy "submissions delete" on public.submissions for delete to authenticated
  using (user_id = auth.uid() and challenge_phase(challenge_id) = 'submission');

drop policy if exists "votes read" on public.votes;
create policy "votes read" on public.votes for select to authenticated
  using (voter_id = auth.uid()
         or (is_member(challenge_group(challenge_id)) and challenge_phase(challenge_id) = 'closed'));
drop policy if exists "votes insert" on public.votes;
create policy "votes insert" on public.votes for insert to authenticated
  with check (
    voter_id = auth.uid()
    and is_member(challenge_group(challenge_id))
    and challenge_phase(challenge_id) = 'voting'
    and exists (select 1 from public.submissions s
                 where s.id = submission_id and s.challenge_id = votes.challenge_id and s.user_id <> auth.uid())
  );
drop policy if exists "votes delete" on public.votes;
create policy "votes delete" on public.votes for delete to authenticated
  using (voter_id = auth.uid() and challenge_phase(challenge_id) = 'voting');

-- ---------------------------------------------------------------------
--  Stockage des photos (bucket privé, un dossier par groupe)
-- ---------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

drop policy if exists "photos read members" on storage.objects;
create policy "photos read members" on storage.objects for select to authenticated
  using (bucket_id = 'photos' and public.is_member(((storage.foldername(name))[1])::uuid));
drop policy if exists "photos upload members" on storage.objects;
create policy "photos upload members" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and public.is_member(((storage.foldername(name))[1])::uuid));
drop policy if exists "photos delete own" on storage.objects;
create policy "photos delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and owner_id = (select auth.uid()::text));

-- ---------------------------------------------------------------------
--  Catalogue de défis
-- ---------------------------------------------------------------------

insert into public.prompts (text, emoji) values
  ('Quelque chose de bleu', '🔵'),
  ('Ta tasse de café (ou de thé)', '☕'),
  ('Le pire stylo de ta trousse', '🖊️'),
  ('Ta vue depuis la fenêtre', '🪟'),
  ('Ton petit-déjeuner', '🥐'),
  ('Quelque chose de rouge', '🔴'),
  ('Quelque chose de vert', '🟢'),
  ('Quelque chose de jaune', '🟡'),
  ('Un objet en forme de cœur', '❤️'),
  ('Tes chaussures du jour', '👟'),
  ('Le truc le plus vieux que tu possèdes', '🕰️'),
  ('Ton coin préféré de ta maison', '🛋️'),
  ('Un visage caché dans un objet', '👀'),
  ('Ton fond d''écran', '📱'),
  ('Le ciel, maintenant', '☁️'),
  ('Une ombre stylée', '🌗'),
  ('Ton repas de midi', '🍽️'),
  ('Un animal (vrai ou pas)', '🐶'),
  ('Le contenu de ton frigo', '🧊'),
  ('Ta meilleure grimace', '🤪'),
  ('Un selfie avec un inconnu (poli !)', '🤳'),
  ('Quelque chose de rond', '⭕'),
  ('Quelque chose de minuscule', '🔬'),
  ('Quelque chose d''énorme', '🏔️'),
  ('Le bazar de ton bureau', '🗂️'),
  ('Ta plante (ou ce qu''il en reste)', '🪴'),
  ('Une photo qui sent bon', '🌸'),
  ('Un reflet', '🪞'),
  ('Ton moyen de transport du jour', '🚲'),
  ('Le pire objet de déco de la maison', '🗿'),
  ('Un truc qui traîne depuis trop longtemps', '🕸️'),
  ('Ton snack du moment', '🍫'),
  ('Une lettre de l''alphabet trouvée dans la rue', '🔤'),
  ('Un chiffre qui compte pour toi', '🔢'),
  ('Ta tête au réveil', '😴'),
  ('Ton outfit du jour', '👕'),
  ('Quelque chose qui te rend heureux', '😊'),
  ('Un truc que tu devrais jeter', '🗑️'),
  ('Ta boisson du soir', '🍹'),
  ('La chose la plus chère de ton sac', '👜'),
  ('Le contenu de tes poches', '👖'),
  ('Un panneau bizarre', '🪧'),
  ('Une porte intéressante', '🚪'),
  ('Des escaliers', '🪜'),
  ('Un coucher (ou lever) de soleil', '🌅'),
  ('Ta main + un objet random', '✋'),
  ('Quelque chose de rayé', '🦓'),
  ('Quelque chose à pois', '🍄'),
  ('Un truc qui brille', '✨'),
  ('Un objet des années 2000', '💿'),
  ('Ton livre du moment', '📚'),
  ('Le dernier truc que tu as acheté', '🛒'),
  ('Ta collection secrète', '🗃️'),
  ('Un plat que tu as cuisiné', '👨‍🍳'),
  ('Le pire emballage de ta cuisine', '📦'),
  ('Quelque chose de symétrique', '🦋'),
  ('Une photo en contre-plongée', '📐'),
  ('Un objet vu de très près', '🔍'),
  ('Ton trousseau de clés', '🔑'),
  ('Ce que tu vois en levant la tête', '⬆️'),
  ('Ce que tu vois à tes pieds', '⬇️'),
  ('Un arbre', '🌳'),
  ('Une fleur', '🌼'),
  ('Un fruit ou un légume rigolo', '🥕'),
  ('Ta playlist du moment (capture)', '🎧'),
  ('Un objet que tu as fabriqué', '🛠️'),
  ('Ton porte-bonheur', '🍀'),
  ('Un souvenir de vacances', '🏖️'),
  ('Un truc qui fait peur', '👻'),
  ('Un truc trop mignon', '🥹'),
  ('Ta meilleure pose de mannequin', '💃'),
  ('Un duo improbable d''objets', '🤝'),
  ('Quelque chose en bois', '🪵'),
  ('Quelque chose en métal', '🔩'),
  ('De l''eau', '💧'),
  ('Du feu (prudemment)', '🔥'),
  ('Un nuage qui ressemble à quelque chose', '🌥️'),
  ('Une photo en noir et blanc', '🖤'),
  ('Ton reflet dans une cuillère', '🥄'),
  ('Un truc que tu ne comprends pas', '❓'),
  ('La chose la plus orange autour de toi', '🟠'),
  ('La chose la plus violette autour de toi', '🟣'),
  ('La chose la plus rose autour de toi', '🩷'),
  ('Ta chaussette la plus usée', '🧦'),
  ('Ton oreiller', '🛏️'),
  ('Ton bureau de travail', '💻'),
  ('Le truc le plus bizarre de ta chambre', '🦄'),
  ('Un bâtiment que tu trouves beau', '🏛️'),
  ('Une voiture qui a du style', '🚗'),
  ('Un vélo abandonné', '🚳'),
  ('Un graffiti', '🎨'),
  ('Une affiche dans la rue', '📰'),
  ('La file d''attente la plus longue du jour', '🚶'),
  ('Ton pire ticket de caisse', '🧾'),
  ('Ta plus belle tache', '🫠'),
  ('Un objet détourné de son usage', '🔄'),
  ('Une photo avec un effet de perspective', '🤏'),
  ('Ton dessin en 30 secondes', '✏️'),
  ('Un mot écrit avec des objets', '🔠'),
  ('Ton animal totem en objet', '🐻'),
  ('Ton sport du jour', '🏃'),
  ('Ton jeu (vidéo ou de société) du moment', '🎮'),
  ('Un bouton', '🔘'),
  ('Un câble emmêlé', '🧶'),
  ('Une chaise', '🪑'),
  ('Une lampe', '💡'),
  ('Une horloge', '⏰'),
  ('Un miroir', '🪞'),
  ('Un parapluie', '☂️'),
  ('Un chapeau', '🎩'),
  ('Des lunettes', '🕶️'),
  ('Ton verre d''eau', '🥛'),
  ('Un bonbon', '🍬'),
  ('Une pizza (ou ce qui s''en rapproche)', '🍕'),
  ('Ton dessert', '🍰'),
  ('Quelque chose de piquant', '🌵'),
  ('Quelque chose de doux', '🧸'),
  ('Quelque chose de froid', '❄️'),
  ('Quelque chose de chaud', '♨️'),
  ('Quelque chose de collant', '🍯'),
  ('Quelque chose de cassé', '💔'),
  ('Quelque chose de neuf', '🆕'),
  ('Quelque chose de fait main', '🧵'),
  ('Quelque chose de trop grand', '🦒'),
  ('Quelque chose de trop petit', '🐜'),
  ('Un truc que tu adores et que les autres détestent', '😈'),
  ('Ton superpouvoir en photo', '🦸'),
  ('Ton humeur du jour en objet', '🎭'),
  ('Ton film préféré en une photo', '🎬'),
  ('Une chanson en une photo', '🎵'),
  ('Un proverbe en une photo', '📜'),
  ('Le lundi en une photo', '😩'),
  ('Le vendredi soir en une photo', '🎉'),
  ('Le luxe à petit prix', '💎'),
  ('Ta routine du soir', '🌙'),
  ('Ton trajet en une image', '🛣️'),
  ('La chose la plus française autour de toi', '🥖'),
  ('Un truc qui fait du bruit', '📢'),
  ('Un truc silencieux', '🤫'),
  ('Une photo floue exprès', '🌫️'),
  ('Un selfie sans montrer ton visage', '🙈'),
  ('Ta main qui fait un signe', '🤘'),
  ('Un objet qui te représente', '🪪'),
  ('Ce que tu vas manger ce soir', '🍝'),
  ('Le truc le plus propre de chez toi', '🧼'),
  ('Le truc le plus sale de chez toi', '🦠'),
  ('Une couleur que tu n''aimes pas', '🤢'),
  ('Ta couleur préférée', '🌈'),
  ('Une texture intéressante', '🧱'),
  ('Un motif répétitif', '🔁'),
  ('Une ligne droite parfaite', '📏'),
  ('Un cercle parfait', '🟢'),
  ('Un triangle caché', '🔺'),
  ('Quelque chose qui vole', '🕊️'),
  ('Quelque chose qui roule', '🛞'),
  ('Quelque chose qui flotte', '🛟'),
  ('La vue la plus haute que tu trouves', '🏙️'),
  ('Le plus petit espace que tu trouves', '📦'),
  ('Un truc qui date de ta naissance', '👶'),
  ('Ton objet le plus inutile', '🤷'),
  ('Ton objet le plus utile', '🧰'),
  ('Une photo « avant / après »', '⏪')
on conflict do nothing;
