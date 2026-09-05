create table if not exists public.promos
(
    id uuid primary key default gen_random_uuid(),

    code text not null,
    name text not null,
    description text,

    discount_type text not null,

    discount_value numeric(10, 2) not null,

    max_discount numeric(10, 2),

    min_fare numeric(10, 2),

    max_fare numeric(10, 2),

    service_types text[] not null default '{Ride,Delivery}',

    start_at timestamptz not null,
    end_at timestamptz not null,

    usage_limit integer,

    usage_limit_per_user integer,

    used_count integer not null default 0,

    is_active boolean not null default true,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    metadata jsonb not null default '{}',

    constraint promos_discount_type_check
    check (discount_type in ('percentage', 'fixed')),

    constraint promos_discount_value_check
    check (discount_value >= 0),

    constraint promos_max_discount_check
    check (
              max_discount is null
              or max_discount >= 0
          ),

    constraint promos_min_fare_check
    check (
              min_fare is null
              or min_fare >= 0
          ),

    constraint promos_max_fare_check
    check (
              max_fare is null
              or max_fare >= 0
          ),

    constraint promos_service_types_check
    check (
              array_length(service_types, 1) > 0
    and service_types <@ array['Ride', 'Delivery']::text[]
    ),

    constraint promos_usage_limit_check
    check (
              usage_limit is null
              or usage_limit > 0
          ),

    constraint promos_usage_limit_per_user_check
    check (
              usage_limit_per_user is null
              or usage_limit_per_user > 0
          ),

    constraint promos_used_count_check
    check (used_count >= 0),

    constraint promos_date_range_check
    check (end_at > start_at),

    constraint promos_percentage_discount_check
    check (
              discount_type <> 'percentage'
              or discount_value <= 100
          ),

    constraint promos_fare_range_check
    check (
              min_fare is null
              or max_fare is null
              or max_fare >= min_fare
          ),

    constraint promos_code_format_check
    check (code ~ '^[A-Za-z0-9_-]{3,20}$'),

    constraint promos_usage_count_check
    check (
              usage_limit is null
              or used_count <= usage_limit
          )
    );

create unique index if not exists promos_code_unique
    on public.promos (upper(code));

create index if not exists promos_active_window_idx
    on public.promos (start_at, end_at)
    where is_active = true;

create index if not exists promos_service_types_idx
    on public.promos
    using gin (service_types);

drop trigger if exists handle_updated_at
    on public.promos;

create trigger handle_updated_at
    before update
    on public.promos
    for each row
    execute function public.update_updated_at_column();


create table if not exists public.promo_redemptions
(
    id uuid primary key default gen_random_uuid(),

    promo_id uuid not null,

    profile_id uuid not null,

    ride_id uuid not null unique,

    discount_applied numeric(10, 2) not null,

    status text not null default 'APPLIED',

    redeemed_at timestamptz not null default now(),

    reversed_at timestamptz,

    metadata jsonb not null default '{}',

    constraint promo_redemptions_promo_id_fkey
    foreign key (promo_id)
    references public.promos(id)
    on delete restrict,

    constraint promo_redemptions_profile_id_fkey
    foreign key (profile_id)
    references public.profiles(id)
    on delete cascade,

    constraint promo_redemptions_ride_id_fkey
    foreign key (ride_id)
    references public.rides(id)
    on delete restrict,

    constraint promo_redemptions_discount_applied_check
    check (discount_applied >= 0),

    constraint promo_redemptions_status_check
    check (status in ('APPLIED', 'REVERSED')),

    constraint promo_redemptions_status_reversed_at_check
    check (
(
              status = 'APPLIED'
              and reversed_at is null
)
    or
(
    status = 'REVERSED'
    and reversed_at is not null
)
    )
    );

create index if not exists promo_redemptions_promo_profile_idx
    on public.promo_redemptions (
    promo_id,
    profile_id
    )
    where status = 'APPLIED';

create index if not exists promo_redemptions_profile_idx
    on public.promo_redemptions (profile_id);