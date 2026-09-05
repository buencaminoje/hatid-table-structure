create or replace function public.update_updated_at_column()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
return new;
end;
$$;

create table if not exists public.rides (
                                            id uuid primary key default gen_random_uuid(),

    customer_profile_id uuid not null,
    rider_profile_id uuid,

    pickup_location text not null,
    drop_location text not null,

    pickup_latitude double precision not null,
    pickup_longitude double precision not null,
    drop_latitude double precision not null,
    drop_longitude double precision not null,

    pickup_coords geography not null,
    drop_coords geography not null,

    final_fare numeric not null,
    fare numeric not null,

    passenger_count integer check (passenger_count > 0),

    status text not null default 'Pending',

    type text not null,
    category text not null,
    service_model text not null,
    payment_method text not null,

    notes text,

    promo_applied boolean not null default false,

    remarks text,

    accepted_at timestamptz,
    arrived_at timestamptz,
    started_at timestamptz,
    completed_at timestamptz,
    cancelled_at timestamptz,

    cancelled_by text,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    metadata jsonb not null default '{}',

    constraint rides_customer_profile_id_fkey
    foreign key (customer_profile_id)
    references public.profiles(id),

    constraint rides_rider_profile_id_fkey
    foreign key (rider_profile_id)
    references public.profiles(id)
    );

create index if not exists rides_customer_created_at_idx
    on public.rides (customer_profile_id, created_at desc);

create index if not exists rides_rider_created_at_idx
    on public.rides (rider_profile_id, created_at desc)
    where rider_profile_id is not null;

create index if not exists rides_customer_active_idx
    on public.rides (customer_profile_id, created_at desc)
    where status in ('Pending', 'Accepted', 'Arrived', 'Started');

create index if not exists rides_rider_active_idx
    on public.rides (rider_profile_id, updated_at desc)
    where status in ('Accepted', 'Arrived', 'Started');

create index if not exists rides_status_created_at_idx
    on public.rides (status, created_at desc);

create index if not exists rides_created_at_idx
    on public.rides (created_at desc);

create index if not exists rides_pending_pickup_coords_gix
    on public.rides
    using gist (pickup_coords)
    where status = 'Pending';

drop trigger if exists handle_updated_at
    on public.rides;

create trigger handle_updated_at
    before update
    on public.rides
    for each row
    execute function public.update_updated_at_column();