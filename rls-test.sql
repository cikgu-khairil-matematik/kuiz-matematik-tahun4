-- Ujian pengasingan akses pada projek ujian Supabase. Semua perubahan di-ROLLBACK.
-- Jalankan selepas schema dan answer keys. Mesti dijalankan sebagai postgres melalui SQL Editor.
begin;
insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data) values
 ('00000000-0000-4000-8000-000000000001','ceria-test-a@example.invalid','{}','{}'),
 ('00000000-0000-4000-8000-000000000002','ceria-test-b@example.invalid','{}','{}'),
 ('00000000-0000-4000-8000-000000000003','ceria-test-manager@example.invalid','{}','{}');
insert into public.ceria_managers values('00000000-0000-4000-8000-000000000003');
insert into public.ceria_classes(id,name,grade,join_code,created_by) values
 ('10000000-0000-4000-8000-000000000001','Kelas Ujian A',4,'1234567890abcdef','00000000-0000-4000-8000-000000000003'),
 ('10000000-0000-4000-8000-000000000002','Kelas Ujian B',4,'abcdef1234567890','00000000-0000-4000-8000-000000000003');
insert into public.ceria_class_managers values('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000003');
insert into public.ceria_memberships(class_id,user_id,alias) values
 ('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','Murid A'),
 ('10000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000002','Murid B');
insert into ceria_private.answer_keys(id,grade,mode,topic,answer,marks)
 select 'ceria-test-'||i,4,'topic','num','1/2',1 from generate_series(1,10) i;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":true}',true);
do $$ declare r jsonb; begin
 select public.submit_attempt('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','topic',4,null,(select jsonb_agg(jsonb_build_object('id','ceria-test-'||i,'value','2/4')) from generate_series(1,10)i),'num') into r;
 if (r->>'score')::int<>10 or (r->>'total')::int<>10 then raise exception 'FAIL: server grading / equivalent fractions';end if;
 if (select count(*) from public.ceria_attempts)<>1 then raise exception 'FAIL: own attempts';end if;
 if (select count(*) from public.ceria_classes)<>0 then raise exception 'FAIL: student can read join-code table';end if;
 begin
  perform public.create_class('Tidak dibenarkan',4);
  raise exception 'FAIL: student manager escalation';
 exception when raise_exception then
  if sqlerrm='FAIL: student manager escalation' then raise;end if;
 end;
 begin
  insert into public.ceria_managers values(auth.uid());
  raise exception 'FAIL: student can insert manager';
 exception when insufficient_privilege then null;
 end;
end $$;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000002","role":"authenticated","is_anonymous":true}',true);
do $$begin
 if (select count(*) from public.ceria_attempts)<>0 then raise exception 'FAIL: student B sees student A';end if;
 if jsonb_array_length(public.my_dashboard()->'attempts')<>0 then raise exception 'FAIL: dashboard leaks student A';end if;
 begin
  perform public.submit_attempt('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','topic',4,null,'[]'::jsonb,'num');
  raise exception 'FAIL: attempt into another class';
 exception when raise_exception then
  if sqlerrm='FAIL: attempt into another class' then raise;end if;
 end;
end $$;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000003","role":"authenticated","is_anonymous":false}',true);
do $$begin
 if (select count(*) from public.ceria_attempts)<>1 then raise exception 'FAIL: manager cannot read assigned class';end if;
 if (select count(*) from public.ceria_classes)<>1 then raise exception 'FAIL: manager sees unassigned class';end if;
end $$;
reset role;
rollback;
-- Jika tiada ralat, ujian lulus. Tiada pengguna atau rekod ujian dikekalkan.
