-- Apply with the database migration owner, never with an anon/service-role HTTP key.
create schema if not exists backend;
revoke all on schema backend from public;
do $$ begin
 if not exists(select 1 from pg_roles where rolname='game_backend') then create role game_backend nologin; end if;
end $$;

create table backend.users (
 id uuid primary key, email text not null unique, password_hash text not null,
 email_verified_at timestamptz, created_at timestamptz not null default now()
);
create table backend.sessions (
 id uuid primary key, user_id uuid not null references backend.users(id), family_id uuid not null,
 token_hash text not null unique, expires_at timestamptz not null, used_at timestamptz,
 revoked_at timestamptz, created_at timestamptz not null default now()
);
create index on backend.sessions(user_id);
create index on backend.sessions(family_id);
create table backend.auth_tokens (
 token_hash text primary key, user_id uuid not null references backend.users(id),
 purpose text not null check(purpose in ('verify','reset')), expires_at timestamptz not null,
 used_at timestamptz, created_at timestamptz not null default now()
);
create table backend.games (
 id text primary key check(id ~ '^[a-z][a-z0-9_-]{1,47}$'),
 android_package text not null unique, enabled boolean not null default false,
 allow_test_purchases boolean not null default false,
 pubsub_subscription text unique, last_reconciled_at timestamptz,
 created_at timestamptz not null default now()
);
create table backend.products (
 game_id text not null references backend.games(id), id text not null,
 kind text not null check(kind in ('consumable','non_consumable')),
 units bigint not null default 0 check(units between 0 and 1000000000),
 currency text, entitlement text, active boolean not null default true,
 primary key(game_id,id),
 check((kind='consumable' and units>0 and currency is not null and entitlement is null)
    or (kind='non_consumable' and units=0 and currency is null and entitlement is not null))
);
create table backend.game_accounts (
 game_id text not null references backend.games(id), user_id uuid not null references backend.users(id),
 billing_id text not null unique, created_at timestamptz not null default now(),
 primary key(game_id,user_id)
);
create table backend.purchases (
 id uuid primary key, game_id text not null, user_id uuid not null, product_id text not null,
 token_hash text not null unique, token_cipher text not null,
 order_id text, state text not null check(state in ('PENDING','PURCHASED','CANCELLED')),
 kind text not null check(kind in ('consumable','non_consumable')), units bigint not null,
 currency text, entitlement text, quantity integer not null check(quantity between 1 and 1000),
 granted_quantity integer not null default 0 check(granted_quantity>=0),
 revoked_quantity integer not null default 0 check(revoked_quantity>=0),
 refundable_quantity integer, test_purchase boolean not null,
 finalized_at timestamptz, next_check_at timestamptz not null default now(),
 checked_at timestamptz not null default now(), created_at timestamptz not null default now(),
 foreign key(game_id,user_id) references backend.game_accounts(game_id,user_id),
 foreign key(game_id,product_id) references backend.products(game_id,id),
 check(revoked_quantity<=granted_quantity and granted_quantity<=quantity)
);
create index on backend.purchases(game_id,user_id);
create index on backend.purchases(next_check_at);
create table backend.ledger (
 sequence bigserial primary key, purchase_id uuid not null references backend.purchases(id),
 game_id text not null, user_id uuid not null, event_key text not null unique,
 reason text not null check(reason in ('purchase','refund')), currency text,
 amount bigint not null, entitlement text, quantity_delta integer not null,
 created_at timestamptz not null default now(),
 foreign key(game_id,user_id) references backend.game_accounts(game_id,user_id)
);
create index on backend.ledger(game_id,user_id,sequence);
create function backend.immutable_ledger() returns trigger language plpgsql as $$
 begin raise exception 'Commerce ledger is append-only'; end $$;
create trigger immutable_ledger before update or delete on backend.ledger
 for each row execute function backend.immutable_ledger();

-- Inbox/outbox and retries survive restarts. Payloads containing tokens are encrypted.
create table backend.jobs (
 id bigserial primary key, dedupe_key text not null unique,
 kind text not null check(kind in ('notification','finalize','sync','reconcile','email')),
 payload_cipher text not null, status text not null default 'ready' check(status in ('ready','running','done','dead')),
 attempts integer not null default 0, available_at timestamptz not null default now(),
 lease_id uuid, lease_until timestamptz, error_code text,
 created_at timestamptz not null default now(), completed_at timestamptz
);
create index on backend.jobs(status,available_at);
create table backend.rate_limits (
 key text primary key, count integer not null, expires_at timestamptz not null
);

-- Only a dedicated backend DB role can use these tables; Supabase anon/authenticated cannot.
grant usage on schema backend to game_backend;
grant select,insert,update,delete on all tables in schema backend to game_backend;
revoke update,delete on backend.ledger from game_backend;
grant usage,select on all sequences in schema backend to game_backend;
do $$ declare tab record; begin
 for tab in select tablename from pg_tables where schemaname='backend' loop
  execute format('alter table backend.%I enable row level security',tab.tablename);
  execute format('create policy backend_only on backend.%I to game_backend using (true) with check (true)',tab.tablename);
 end loop;
end $$;
revoke all on backend.schema_migrations from game_backend;
