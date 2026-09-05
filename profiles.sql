create table if not exists public.profiles
(
    id uuid primary key default gen_random_uuid(),

    auth_id uuid not null,

    nickname text,

    address text,

    date_of_birth date,

    city text,

    postal_code text,

    wallet_balance numeric not null default 0,

    fcm_token text,

    type text not null default 'Customer',

    is_allowed_multiple_order boolean not null default false,

    mobile_number text not null default '',

    email text not null default '',

    status text not null default 'Active',

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    metadata jsonb not null default '{}',

    constraint profiles_auth_id_fkey
    foreign key (auth_id)
    references auth.users(id)
    );

create index if not exists profiles_type_status_created_at_idx
    on public.profiles (type, status, created_at desc);

create unique index if not exists profiles_auth_id_type_idx
    on public.profiles (auth_id, type);