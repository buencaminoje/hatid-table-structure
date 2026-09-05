create or replace function public.cancel_ride(
    p_ride_id uuid,
    p_profile_id uuid default null,
    p_holding_profile_id uuid default null,
    p_cancellation_reason text default null,
    p_is_system boolean default false
)
returns public.rides
language plpgsql
security definer
set search_path = public
as $$
declare
v_ride public.rides;
    v_cancelled_by text;
begin
select *
into v_ride
from public.rides
where id = p_ride_id
  and (
    p_is_system
        or customer_profile_id = p_profile_id
        or rider_profile_id = p_profile_id
    )
    for update;

if not found then
        raise exception 'RIDE_NOT_FOUND';
end if;

    if v_ride.status = 'Cancelled' then
        return v_ride;
end if;

    if v_ride.status = 'Completed' then
        raise exception 'RIDE_ALREADY_COMPLETED';
end if;

    if p_is_system then
        v_cancelled_by := 'System';

    elsif v_ride.customer_profile_id = p_profile_id then
        v_cancelled_by := 'Customer';

    elsif v_ride.rider_profile_id = p_profile_id then
        v_cancelled_by := 'Rider';

else
        raise exception 'UNAUTHORIZED_CANCELLATION';
end if;

    if upper(v_ride.payment_method) = 'WALLET'
   and v_ride.final_fare > 0 then
        if p_holding_profile_id is null then
            raise exception 'HOLDING_PROFILE_REQUIRED';
end if;

        perform 1
        from public.profiles
        where id = p_holding_profile_id
        for update;

if not found then
            raise exception 'HOLDING_PROFILE_NOT_FOUND';
end if;

        perform public.create_transaction(
            p_holding_profile_id,
            v_ride.id,
            v_ride.final_fare,
            'debit',
            'ride_payment_refund',
            'Ride payment refunded to customer',
            null,
            jsonb_build_object(
                'status', 'REFUNDED',
                'customer_profile_id', v_ride.customer_profile_id,
                'cancelled_by', v_cancelled_by
            )
        );

        perform public.create_transaction(
            v_ride.customer_profile_id,
            v_ride.id,
            v_ride.final_fare,
            'credit',
            'ride_payment_refund',
            'Ride payment refunded',
            null,
            jsonb_build_object(
                'status', 'REFUNDED',
                'holding_profile_id', p_holding_profile_id,
                'cancelled_by', v_cancelled_by
            )
        );
end if;

update public.rides
set
    status = 'Cancelled',
    cancelled_by = v_cancelled_by,
    remarks = coalesce(
            p_cancellation_reason,
            remarks
              ),
    cancelled_at = now()
where id = v_ride.id
    returning *
into v_ride;

perform public.reverse_promo_redemption(v_ride.id);

return v_ride;
end;
$$;