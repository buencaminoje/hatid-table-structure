create table if not exists public.messages
(
    id uuid primary key default gen_random_uuid(),

    sender_id uuid not null,

    receiver_id uuid not null,

    ride_id uuid not null,

    text text,

    image_url text,

    created_at timestamptz not null default now(),

    metadata jsonb not null default '{}',

    constraint messages_sender_id_fkey
    foreign key (sender_id)
    references public.profiles(id)
    on delete cascade,

    constraint messages_receiver_id_fkey
    foreign key (receiver_id)
    references public.profiles(id)
    on delete cascade,

    constraint messages_ride_id_fkey
    foreign key (ride_id)
    references public.rides(id)
    on delete cascade,

    constraint messages_content_check
    check (
              text is not null
              or image_url is not null
          )
    );

create index if not exists messages_ride_created_at_idx
    on public.messages (ride_id, created_at desc);