-- This test runs after the candidate migration in a disposable PostgreSQL service.
insert into auth.users(id,email) values
('10000000-0000-0000-0000-000000000001','admin@example.test'),
('10000000-0000-0000-0000-000000000002','trainer@example.test');
insert into public.teams(id,name) values ('20000000-0000-0000-0000-000000000001','Test Team');
insert into public.team_members(team_id,user_id,role,admin_label) values
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','admin','Admin'),
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','trainer','Trainer');
insert into public.team_member_roles(team_id,user_id,role) values
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','admin'),
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','trainer');
