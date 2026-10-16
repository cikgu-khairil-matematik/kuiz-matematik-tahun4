-- Ceria Matematik v2. Jalankan sekali pada projek Supabase baharu.
-- Semua rekod murid dilindungi RLS; markah dikira semula oleh submit_attempt.
begin;
create extension if not exists pgcrypto with schema extensions;
create schema if not exists ceria_private;
revoke all on schema ceria_private from public, anon, authenticated;
create table public.ceria_managers (
 user_id uuid primary key references auth.users(id) on delete cascade
);
create table public.ceria_classes (
 id uuid primary key default gen_random_uuid(),
 name text not null check(length(name) between 1 and 60),
 grade smallint not null check(grade between 1 and 6),
 join_code text not null unique default encode(extensions.gen_random_bytes(8),'hex'),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
create table public.ceria_class_managers (
 class_id uuid not null references public.ceria_classes(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 primary key(class_id,user_id)
);
create table public.ceria_memberships (
 class_id uuid not null references public.ceria_classes(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 alias text not null check(length(alias) between 1 and 40),
 joined_at timestamptz not null default now(),
 primary key(class_id,user_id)
);
create table ceria_private.answer_keys (
 id text primary key, grade smallint not null, mode text not null,
 set_no smallint, topic text not null, answer text not null, marks smallint not null check(marks between 1 and 4)
);
create table public.ceria_attempts (
 id uuid primary key default gen_random_uuid(),
 client_id uuid not null unique,
 class_id uuid not null references public.ceria_classes(id),
 student_id uuid not null references auth.users(id),
 alias text not null,
 grade smallint not null check(grade between 1 and 6),
 mode text not null check(mode in ('topic','uasa','matriks')),
 topic text, set_no smallint,
 title text not null,
 score integer not null check(score>=0),
 total integer not null check(total>0 and score<=total),
 answers jsonb not null,
 submitted_at timestamptz not null default now()
);
create index ceria_attempts_class_date on public.ceria_attempts(class_id,submitted_at desc);
create index ceria_attempts_student_date on public.ceria_attempts(student_id,submitted_at desc);
create or replace function public.ceria_is_manager(p_class_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.ceria_class_managers where class_id=p_class_id and user_id=auth.uid());
$$;
revoke all on function public.ceria_is_manager(uuid) from public,anon;
grant execute on function public.ceria_is_manager(uuid) to authenticated;
alter table public.ceria_managers enable row level security;
alter table public.ceria_classes enable row level security;
alter table public.ceria_class_managers enable row level security;
alter table public.ceria_memberships enable row level security;
alter table public.ceria_attempts enable row level security;
alter table ceria_private.answer_keys enable row level security;
create policy manager_self on public.ceria_managers for select to authenticated using (user_id=auth.uid());
create policy class_manager on public.ceria_classes for select to authenticated using(public.ceria_is_manager(id));
create policy class_managers_self on public.ceria_class_managers for select to authenticated using(user_id=auth.uid() or public.ceria_is_manager(class_id));
create policy member_self_or_manager on public.ceria_memberships for select to authenticated using(user_id=auth.uid() or public.ceria_is_manager(class_id));
create policy attempt_self_or_manager on public.ceria_attempts for select to authenticated using(student_id=auth.uid() or public.ceria_is_manager(class_id));
revoke all on public.ceria_managers,public.ceria_classes,public.ceria_class_managers,public.ceria_memberships,public.ceria_attempts from anon,authenticated;
grant select on public.ceria_managers,public.ceria_classes,public.ceria_class_managers,public.ceria_memberships,public.ceria_attempts to authenticated;
-- Tiada polisi INSERT/UPDATE/DELETE melalui REST. Semua perubahan melalui RPC terhad.
create or replace function public.create_class(p_name text,p_grade integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.ceria_classes;
begin
 if auth.uid() is null or not exists(select 1 from public.ceria_managers where user_id=auth.uid()) or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Akaun tidak dibenarkan mengurus kelas.'; end if;
 if p_name is null or length(trim(p_name)) not between 1 and 60 or p_grade is null or p_grade not between 1 and 6 then raise exception 'Nama / tahun kelas tidak sah.'; end if;
 if (select count(*) from public.ceria_classes where created_by=auth.uid())>=100 then raise exception 'Had 100 kelas telah dicapai.';end if;
 insert into public.ceria_classes(name,grade,created_by) values(trim(p_name),p_grade,auth.uid()) returning * into v;
 insert into public.ceria_class_managers(class_id,user_id) values(v.id,auth.uid());
 return jsonb_build_object('id',v.id,'name',v.name,'grade',v.grade,'join_code',v.join_code);
end $$;
create or replace function public.join_class(p_code text,p_alias text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.ceria_classes;
begin
 if auth.uid() is null then raise exception 'Sila mulakan sesi murid.';end if;
 if p_alias is null or length(trim(p_alias)) not between 1 and 40 or p_code is null or p_code !~ '^[a-fA-F0-9]{16}$' then raise exception 'Kod kelas / nama tidak sah.';end if;
 select * into v from public.ceria_classes where join_code=lower(trim(p_code));
 if v.id is null then raise exception 'Kod kelas tidak ditemui.';end if;
 insert into public.ceria_memberships(class_id,user_id,alias) values(v.id,auth.uid(),trim(p_alias)) on conflict(class_id,user_id) do update set alias=excluded.alias;
 return jsonb_build_object('class_id',v.id,'class_name',v.name,'grade',v.grade,'alias',trim(p_alias),'user_id',auth.uid());
end $$;
create or replace function ceria_private.numeric_value(p_value text)
returns numeric language plpgsql immutable set search_path='' as $$
declare s text; f text[];
begin
 s:=lower(trim(p_value));s:=replace(s,'−','-');s:=regexp_replace(s,'^(rm)\s*','');s:=regexp_replace(s,'\s+','','g');s:=regexp_replace(s,'(cm²|cm³|mℓ|ml|minit|hari|sen|pagi|unit|sisi|buah|orang|buku|km|kg|cm|mm|jam|%|ℓ|liter|g|m)$','');
 if s ~ '^[+-]?[0-9]+(\.[0-9]+)?$' then return s::numeric;end if;
 f:=regexp_match(s,'^([+-]?[0-9]+)/([0-9]+)$');
 if f is not null and f[2]::numeric<>0 then return f[1]::numeric/f[2]::numeric;end if;
 return null;
exception when others then return null;
end $$;
create or replace function ceria_private.equivalent(p_value text,p_answer text)
returns boolean language plpgsql immutable set search_path='' as $$
declare a numeric;b numeric;
begin
 if p_value is null or trim(p_value)='' then return false;end if;
 a:=ceria_private.numeric_value(p_value);b:=ceria_private.numeric_value(p_answer);
 if a is not null and b is not null then return abs(a-b)<0.0000001;end if;
 return regexp_replace(lower(p_value),'\s+','','g')=regexp_replace(lower(p_answer),'\s+','','g');
end $$;
create or replace function public.submit_attempt(p_client_id uuid,p_class_id uuid,p_mode text,p_grade integer,p_set integer,p_answers jsonb,p_topic text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_member public.ceria_memberships;v_existing public.ceria_attempts;v_count integer;v_distinct integer;v_valid integer;v_score integer;v_total integer;v_title text;
begin
 if auth.uid() is null then raise exception 'Sesi log masuk diperlukan.';end if;
 select * into v_existing from public.ceria_attempts where client_id=p_client_id;
 if found then
  if v_existing.student_id<>auth.uid() or v_existing.class_id<>p_class_id then raise exception 'ID percubaan tidak sah.';end if;
  return jsonb_build_object('score',v_existing.score,'total',v_existing.total,'id',v_existing.id);
 end if;
 select * into v_member from public.ceria_memberships where class_id=p_class_id and user_id=auth.uid();
 if v_member.user_id is null then raise exception 'Sertai kelas dahulu.';end if;
 if p_grade is null or not exists(select 1 from public.ceria_classes where id=p_class_id and grade=p_grade) then raise exception 'Tahun latihan mesti sama dengan tahun kelas aktif.';end if;
 if p_mode is null or p_mode not in ('topic','uasa','matriks') or (p_mode='uasa' and p_grade<4) or (p_mode<>'topic' and (p_set is null or p_set not between 1 and 3)) then raise exception 'Jenis latihan tidak sah.';end if;
 if p_answers is null or jsonb_typeof(p_answers)<>'array' or octet_length(p_answers::text)>50000 then raise exception 'Jawapan tidak sah.';end if;
 select count(*),count(distinct x->>'id') into v_count,v_distinct from jsonb_array_elements(p_answers) x;
 if v_count<>v_distinct or v_count<>(case p_mode when 'topic' then 10 when 'uasa' then 21 else 29 end) then raise exception 'Bilangan item latihan tidak sah.';end if;
 if (select count(*) from public.ceria_attempts where student_id=auth.uid() and submitted_at>now()-interval '1 hour')>=60 then raise exception 'Had percubaan sejam dicapai. Cuba kemudian.';end if;
 select count(*),coalesce(sum(k.marks),0),coalesce(sum(case when ceria_private.equivalent(x->>'value',k.answer) then k.marks else 0 end),0)
 into v_valid,v_total,v_score
 from jsonb_array_elements(p_answers) x join ceria_private.answer_keys k on k.id=x->>'id'
 where k.grade=p_grade and k.mode=p_mode and ((p_mode='topic' and k.topic=p_topic) or (p_mode<>'topic' and k.set_no=p_set));
 if v_valid<>v_count or (p_mode<>'topic' and v_total<>50) then raise exception 'Kunci soalan tidak sepadan. Kemas kini bank soalan.';end if;
 v_title:=case p_mode when 'topic' then 'Kuiz '||p_topic when 'uasa' then 'Latihan UASA' else 'Ujian Matriks' end||' Tahun '||p_grade||case when p_mode<>'topic' then ' · Set '||chr(64+p_set) else '' end;
 insert into public.ceria_attempts(client_id,class_id,student_id,alias,grade,mode,topic,set_no,title,score,total,answers)
 values(p_client_id,p_class_id,auth.uid(),v_member.alias,p_grade,p_mode,p_topic,p_set,v_title,v_score,v_total,p_answers) returning * into v_existing;
 return jsonb_build_object('id',v_existing.id,'score',v_score,'total',v_total);
end $$;
create or replace function public.my_dashboard()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_classes jsonb;v_attempts jsonb;
begin
 if auth.uid() is null then raise exception 'Log masuk dahulu.';end if;
 select coalesce(jsonb_agg(t order by t.name),'[]'::jsonb) into v_classes from (
  select c.id,c.name,c.grade,public.ceria_is_manager(c.id) as manager,
  case when public.ceria_is_manager(c.id) then c.join_code else null end as join_code,m.alias
  from public.ceria_classes c left join public.ceria_memberships m on m.class_id=c.id and m.user_id=auth.uid()
  where m.user_id=auth.uid() or public.ceria_is_manager(c.id)
 )t;
 select coalesce(jsonb_agg(t order by t.submitted_at desc),'[]'::jsonb) into v_attempts from (
  select a.id,a.class_id,c.name as class_name,a.student_id,a.alias,a.title,a.grade,a.mode,a.topic,a.score,a.total,a.submitted_at
  from public.ceria_attempts a join public.ceria_classes c on c.id=a.class_id
  where a.student_id=auth.uid() or public.ceria_is_manager(a.class_id)
  order by a.submitted_at desc limit 500
 )t;
 return jsonb_build_object('classes',v_classes,'attempts',v_attempts,'can_manage',exists(select 1 from public.ceria_managers where user_id=auth.uid()) and not coalesce((auth.jwt()->>'is_anonymous')::boolean,false));
end $$;
revoke all on function public.create_class(text,integer),public.join_class(text,text),public.submit_attempt(uuid,uuid,text,integer,integer,jsonb,text),public.my_dashboard() from public,anon;
grant execute on function public.create_class(text,integer),public.join_class(text,text),public.submit_attempt(uuid,uuid,text,integer,integer,jsonb,text),public.my_dashboard() to authenticated;
revoke all on all functions in schema ceria_private from public,anon,authenticated;
commit;
