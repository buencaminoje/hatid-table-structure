create extension if not exists postgis with schema extensions;

create table if not exists public.riders
(
    id uuid primary key default gen_random_uuid(),

    profile_id uuid not null unique,

    vehicle_model text,
    vehicle_type text,
    vehicle_color text,
    plate_no text,

    license_url text,
    license_status text not null default 'Pending',

    reg_url text,
    reg_book_status text not null default 'Pending',

    vehicle_url text,
    vehicle_status text not null default 'Pending',

    lat double precision,
    lng double precision,

    current_location extensions.geography(Point, 4326),

    is_online boolean not null default false,

    last_updated timestamptz not null default now(),
    created_at timestamptz not null default now(),

    metadata jsonb not null default '{}',

    constraint riders_profile_id_fkey
    foreign key (profile_id)
    references public.profiles(id)
    on delete cascade
    );

create index if not exists riders_available_location_idx
    on public.riders
    using gist (current_location)
    where is_online = true;

create index if not exists riders_available_vehicle_type_idx
    on public.riders (vehicle_type)
    where is_online = true;