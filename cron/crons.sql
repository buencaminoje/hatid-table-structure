create index if not exists riders_online_last_updated_idx
    on public.riders (last_updated)
    where is_online = true;

create index if not exists rides_pending_created_at_idx
    on public.rides (created_at)
    where status = 'Pending';


create or replace function public.cancel_expired_pending_rides(
    p_holding_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
v_ride_id uuid;
begin
for v_ride_id in
select id
from public.rides
where status = 'Pending'
  and created_at < now() - interval '2 minutes 20 seconds'
    for update skip locked
            loop
            perform public.cancel_ride(
            p_ride_id := v_ride_id,
            p_holding_profile_id := p_holding_profile_id,
            p_cancellation_reason := 'ORDER TIMEOUT - DB ACTION',
            p_is_system := true
            );
end loop;
end;
$$;


select cron.schedule(
               'mark-inactive-riders-offline',
               '* * * * *',
               $$
                   update public.riders
    set is_online = false
    where is_online = true
      and last_updated < now() - interval '5 minutes';
$$
);

select cron.schedule(
               'close-pending-orders',
               '* * * * *',
               $$
                   select public.cancel_expired_pending_rides(
        'YOUR-HOLDING-PROFILE-ID'::uuid
    );
$$
);