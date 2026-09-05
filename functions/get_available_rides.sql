create
or replace function public.get_available_rides(
    user_lat double precision,
    user_lng double precision,
    p_vehicle_type text,
    radius_meters double precision default 5000
)
returns table (
    id uuid,
    customer_profile_id uuid,
    pickup_location text,
    drop_location text,
    pickup_latitude double precision,
    pickup_longitude double precision,
    drop_latitude double precision,
    drop_longitude double precision,
    distance double precision
)
language sql
security definer
set search_path = public, extensions
as $$
select r.id,
       r.customer_profile_id,
       r.pickup_location,
       r.drop_location,
       r.pickup_latitude,
       r.pickup_longitude,
       r.drop_latitude,
       r.drop_longitude,
       extensions.ST_Distance(
               r.pickup_coords,
               u.location
       ) as distance
from public.rides r
         cross join (select extensions.ST_SetSRID(
                                    extensions.ST_MakePoint(user_lng, user_lat),
                                    4326
                            ) ::extensions.geography as location) u
where r.status = 'Pending'
  and r.category = p_vehicle_type
  and extensions.ST_DWithin(
        r.pickup_coords,
        u.location,
        radius_meters
      )
order by distance asc;
$$;