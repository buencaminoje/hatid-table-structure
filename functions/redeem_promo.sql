create or replace function public.redeem_promo(
p_promo_id uuid,
p_profile_id uuid,
p_ride_id uuid,
p_discount_applied numeric default 0
)
returns public.promo_redemptions
language plpgsql
security definer
set search_path = public
as $$
declare
v_promo public.promos;
v_ride public.rides;
v_redemption public.promo_redemptions;
v_user_redemption_count integer;
v_discount numeric;
begin
if p_discount_applied is null
or p_discount_applied < 0 then
raise exception 'INVALID_DISCOUNT';
end if;

v_discount := p_discount_applied;

select *
into v_ride
from public.rides
where id = p_ride_id
  and customer_profile_id = p_profile_id
for update;

if not found then
    raise exception 'RIDE_NOT_FOUND';
end if;

if v_ride.status in ('Cancelled', 'Completed') then
    raise exception 'RIDE_NOT_ELIGIBLE_FOR_PROMO';
end if;

select *
into v_promo
from public.promos
where id = p_promo_id
for update;

if not found then
    raise exception 'PROMO_INVALID';
end if;

if not v_promo.is_active then
    raise exception 'PROMO_NOT_ACTIVE';
end if;

if now() < v_promo.start_at then
    raise exception 'PROMO_NOT_STARTED';
end if;

if v_promo.end_at is not null
   and now() >= v_promo.end_at then
    raise exception 'PROMO_EXPIRED';
end if;

if v_promo.min_fare is not null
   and v_ride.fare < v_promo.min_fare then
    raise exception 'PROMO_MIN_FARE_NOT_MET';
end if;

if v_promo.max_fare is not null
   and v_ride.fare > v_promo.max_fare then
    raise exception 'PROMO_MAX_FARE_EXCEEDED';
end if;

if v_discount > v_ride.fare then
    raise exception 'INVALID_DISCOUNT';
end if;

if v_promo.usage_limit is not null
   and v_promo.used_count >= v_promo.usage_limit then
    raise exception 'PROMO_USAGE_LIMIT_REACHED';
end if;

if v_promo.usage_limit_per_user is not null then
    select count(*)
    into v_user_redemption_count
    from public.promo_redemptions
    where promo_id = v_promo.id
      and profile_id = p_profile_id
      and status = 'APPLIED';

    if v_user_redemption_count >= v_promo.usage_limit_per_user then
        raise exception 'PROMO_USER_USAGE_LIMIT_REACHED';
    end if;
end if;

select *
into v_redemption
from public.promo_redemptions
where ride_id = p_ride_id
for update;

if found then
    raise exception 'RIDE_PROMO_ALREADY_REDEEMED';
end if;

update public.promos
set used_count = used_count + 1
where id = v_promo.id;

insert into public.promo_redemptions (
    promo_id,
    profile_id,
    ride_id,
    discount_applied,
    status
)
values (
    v_promo.id,
    p_profile_id,
    p_ride_id,
    v_discount,
    'APPLIED'
)
returning *
into v_redemption;

return v_redemption;

end;

$$;
