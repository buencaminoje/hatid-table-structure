create or replace function public.get_nearby_riders(
    user_lat float8,
    user_lng float8,
    p_vehicle_type text,
    radius_meters float8 default 5000,
    max_results integer default 20
)
returns table (
    id uuid,
    profile_id uuid,
    vehicle_model text,
    vehicle_type text,
    plate_no text,
    lat float8,
    lng float8,
    distance float8
)
language sql
security definer
set search_path = public, extensions
as $$
select
    r.id,
    r.profile_id,
    r.vehicle_model,
    r.vehicle_type,
    r.plate_no,
    r.lat,
    r.lng,
    extensions.ST_Distance(
            r.current_location,
            u.location
    ) as distance
from public.riders r
         join public.profiles p
              on p.id = r.profile_id
         cross join (
    select extensions.ST_SetSRID(
                   extensions.ST_MakePoint(user_lng, user_lat),
                   4326
           )::extensions.geography as location
) u
where r.is_online = true
  and p.status = 'Active'
  and r.vehicle_type = p_vehicle_type
  and r.current_location is not null
  and extensions.ST_DWithin(
        r.current_location,
        u.location,
        radius_meters
      )
order by distance
    limit max_results;
$$;