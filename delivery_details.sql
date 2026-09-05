create or replace function public.update_updated_at_column()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
return new;
end;
$$;

create table if not exists public.delivery_details
(
    id uuid primary key default gen_random_uuid(),

    ride_id uuid not null unique,

    is_pabili boolean not null default false,

    estimated_purchase_amount numeric(12, 2),

    sender_name text not null,
    sender_contact_number text not null,

    receiver_name text not null,
    receiver_contact_number text not null,

    package_description text not null,
    pickup_instructions text,
    delivery_instructions text,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    metadata jsonb not null default '{}',

    constraint delivery_details_ride_id_fkey
    foreign key (ride_id)
    references public.rides(id)
    on delete cascade
    );

drop trigger if exists handle_updated_at
    on public.delivery_details;

create trigger handle_updated_at
    before update
    on public.delivery_details
    for each row
    execute function public.update_updated_at_column();