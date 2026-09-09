create table backend.cloud_saves (
 game_id text not null, user_id uuid not null,
 revision bigint not null check(revision>0), schema_version integer not null check(schema_version>0),
 purchase_cursor bigint not null check(purchase_cursor>=0), payload jsonb not null check(jsonb_typeof(payload)='object'),
 updated_at timestamptz not null default now(), primary key(game_id,user_id),
 foreign key(game_id,user_id) references backend.game_accounts(game_id,user_id),
 check(octet_length(payload::text)<=524288)
);
create table backend.cloud_save_history (
 game_id text not null, user_id uuid not null, revision bigint not null,
 schema_version integer not null, purchase_cursor bigint not null, payload jsonb not null,
 created_at timestamptz not null default now(), primary key(game_id,user_id,revision),
 foreign key(game_id,user_id) references backend.game_accounts(game_id,user_id)
);
grant select,insert,update,delete on backend.cloud_saves,backend.cloud_save_history to game_backend;
alter table backend.cloud_saves enable row level security;
alter table backend.cloud_save_history enable row level security;
create policy backend_only on backend.cloud_saves to game_backend using(true) with check(true);
create policy backend_only on backend.cloud_save_history to game_backend using(true) with check(true);
