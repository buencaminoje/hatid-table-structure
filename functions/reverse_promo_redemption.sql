create or replace function public.reverse_promo_redemption(
    p_ride_id uuid
)
returns public.promo_redemptions
language plpgsql
security definer
set search_path = public
as $$
declare
v_redemption public.promo_redemptions;
begin
    if p_ride_id is null then
        raise exception 'RIDE_REQUIRED';
end if;

select *
into v_redemption
from public.promo_redemptions
where ride_id = p_ride_id
  and status = 'APPLIED'
    for update;

if not found then
        return null;
end if;

update public.promos
set used_count = greatest(used_count - 1, 0)
where id = v_redemption.promo_id;

update public.promo_redemptions
set
    status = 'REVERSED',
    reversed_at = now()
where id = v_redemption.id
    returning *
into v_redemption;

return v_redemption;
end;
$$;