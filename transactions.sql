create table if not exists public.transactions
(
    id uuid primary key default gen_random_uuid(),

    profile_id uuid not null,

    ride_id uuid,

    amount numeric not null,

    type text not null,

    category text not null,
    description text,
    remarks text,

    created_at timestamptz not null default now(),

    metadata jsonb not null default '{}',

    constraint transactions_profile_id_fkey
    foreign key (profile_id)
    references public.profiles(id)
    on delete cascade,

    constraint transactions_ride_id_fkey
    foreign key (ride_id)
    references public.rides(id)
    on delete set null,

    constraint transactions_type_check
    check (type in ('credit', 'debit'))
    );

create index if not exists transactions_profile_created_at_idx
    on public.transactions (profile_id, created_at desc);

create index if not exists transactions_ride_id_idx
    on public.transactions (ride_id)
    where ride_id is not null;