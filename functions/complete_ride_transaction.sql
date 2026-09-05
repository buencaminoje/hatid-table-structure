create or replace function public.complete_ride(
    p_ride_id uuid,
    p_holding_profile_id uuid default null,
    p_platform_profile_id uuid default null,
    p_marketing_profile_id uuid default null,
    p_platform_fee numeric default 0
)
returns public.rides
language plpgsql
security definer
set search_path = public
as $$
declare
v_ride public.rides;
    v_rider_earning numeric;
    v_marketing_amount numeric;
begin
select *
into v_ride
from public.rides
where id = p_ride_id
    for update;

if not found then
        raise exception 'RIDE_NOT_FOUND';
end if;

    if v_ride.status = 'Completed' then
        return v_ride;
end if;

    if v_ride.status = 'Cancelled' then
        raise exception 'RIDE_CANCELLED';
end if;

    if v_ride.status <> 'Started' then
        raise exception 'INVALID_RIDE_STATUS';
end if;

    if v_ride.rider_profile_id is null then
        raise exception 'RIDER_NOT_ASSIGNED';
end if;

    if v_ride.fare < 0 then
        raise exception 'INVALID_FARE';
end if;

    if v_ride.final_fare < 0 then
        raise exception 'INVALID_FINAL_FARE';
end if;

    if v_ride.final_fare > v_ride.fare then
        raise exception 'INVALID_FINAL_FARE';
end if;

    if p_platform_fee is null
       or p_platform_fee < 0
       or p_platform_fee > v_ride.fare then
        raise exception 'INVALID_PLATFORM_FEE';
end if;

    if v_ride.promo_applied then

        v_marketing_amount := v_ride.fare - v_ride.final_fare;

        if v_marketing_amount <= 0 then
            raise exception 'INVALID_PROMO_SUBSIDY';
end if;

        if p_marketing_profile_id is null then
            raise exception 'MARKETING_PROFILE_REQUIRED';
end if;

        perform 1
        from public.profiles
        where id = p_marketing_profile_id
        for update;

if not found then
            raise exception 'MARKETING_PROFILE_NOT_FOUND';
end if;

else
        v_marketing_amount := 0;
end if;

    v_rider_earning := v_ride.fare - p_platform_fee;

    if p_platform_fee > 0 then

        if p_platform_profile_id is null then
            raise exception 'PLATFORM_PROFILE_REQUIRED';
end if;

        perform 1
        from public.profiles
        where id = p_platform_profile_id
        for update;

if not found then
            raise exception 'PLATFORM_PROFILE_NOT_FOUND';
end if;

end if;

    if upper(v_ride.payment_method) = 'WALLET' then

        if v_ride.final_fare > 0
           and p_holding_profile_id is null then
            raise exception 'HOLDING_PROFILE_REQUIRED';
end if;

        if p_holding_profile_id is not null then

            perform 1
            from public.profiles
            where id = p_holding_profile_id
            for update;

if not found then
                raise exception 'HOLDING_PROFILE_NOT_FOUND';
end if;

end if;

        if v_marketing_amount > 0 then

            if p_holding_profile_id is null then
                raise exception 'HOLDING_PROFILE_REQUIRED';
end if;

            perform public.create_transaction(
                p_marketing_profile_id,
                v_ride.id,
                v_marketing_amount,
                'debit',
                'promo_subsidy',
                'Marketing funded ride discount',
                null,
                jsonb_build_object(
                    'fare', v_ride.fare,
                    'final_fare', v_ride.final_fare,
                    'marketing_amount', v_marketing_amount,
                    'holding_profile_id', p_holding_profile_id
                )
            );

            perform public.create_transaction(
                p_holding_profile_id,
                v_ride.id,
                v_marketing_amount,
                'credit',
                'promo_subsidy',
                'Marketing subsidy received for ride',
                null,
                jsonb_build_object(
                    'fare', v_ride.fare,
                    'final_fare', v_ride.final_fare,
                    'marketing_amount', v_marketing_amount,
                    'marketing_profile_id', p_marketing_profile_id
                )
            );

end if;

        if v_ride.fare > 0 then

            perform public.create_transaction(
                p_holding_profile_id,
                v_ride.id,
                v_ride.fare,
                'debit',
                'ride_payment_release',
                'Ride payment released to rider',
                null,
                jsonb_build_object(
                    'fare', v_ride.fare,
                    'final_fare', v_ride.final_fare,
                    'platform_fee', p_platform_fee,
                    'rider_earning', v_rider_earning,
                    'rider_profile_id', v_ride.rider_profile_id
                )
            );

            perform public.create_transaction(
                v_ride.rider_profile_id,
                v_ride.id,
                v_ride.fare,
                'credit',
                'ride_earning',
                'Ride earnings',
                null,
                jsonb_build_object(
                    'fare', v_ride.fare,
                    'final_fare', v_ride.final_fare,
                    'platform_fee', p_platform_fee,
                    'rider_earning', v_rider_earning,
                    'payment_method', v_ride.payment_method
                )
            );

end if;

        if p_platform_fee > 0 then

            perform public.create_transaction(
                v_ride.rider_profile_id,
                v_ride.id,
                p_platform_fee,
                'debit',
                'platform_fee',
                'Platform fee deducted from rider wallet',
                null,
                jsonb_build_object(
                    'fare', v_ride.fare,
                    'final_fare', v_ride.final_fare,
                    'platform_fee', p_platform_fee,
                    'rider_earning', v_rider_earning,
                    'platform_profile_id', p_platform_profile_id,
                    'payment_method', v_ride.payment_method
                )
            );

            perform public.create_transaction(
                p_platform_profile_id,
                v_ride.id,
                p_platform_fee,
                'credit',
                'platform_fee',
                'Platform fee received',
                null,
                jsonb_build_object(
                    'fare', v_ride.fare,
                    'final_fare', v_ride.final_fare,
                    'platform_fee', p_platform_fee,
                    'rider_profile_id', v_ride.rider_profile_id,
                    'payment_method', v_ride.payment_method
                )
            );

end if;

    elsif upper(v_ride.payment_method) = 'CASH' then

        if v_marketing_amount > 0 then

            perform public.create_transaction(
                p_marketing_profile_id,
                v_ride.id,
                v_marketing_amount,
                'debit',
                'promo_subsidy',
                'Marketing funded ride discount',
                null,
                jsonb_build_object(
                    'fare', v_ride.fare,
                    'final_fare', v_ride.final_fare,
                    'marketing_amount', v_marketing_amount,
                    'rider_profile_id', v_ride.rider_profile_id
                )
            );

            perform public.create_transaction(
                v_ride.rider_profile_id,
                v_ride.id,
                v_marketing_amount,
                'credit',
                'promo_subsidy',
                'Marketing funded ride amount',
                null,
                jsonb_build_object(
                    'fare', v_ride.fare,
                    'final_fare', v_ride.final_fare,
                    'marketing_amount', v_marketing_amount,
                    'marketing_profile_id', p_marketing_profile_id
                )
            );

end if;

        if p_platform_fee > 0 then

            perform public.create_transaction(
                v_ride.rider_profile_id,
                v_ride.id,
                p_platform_fee,
                'debit',
                'platform_fee',
                'Platform fee deducted from rider wallet',
                null,
                jsonb_build_object(
                    'fare', v_ride.fare,
                    'final_fare', v_ride.final_fare,
                    'platform_fee', p_platform_fee,
                    'rider_earning', v_rider_earning,
                    'payment_method', v_ride.payment_method
                ),
                true
            );

            perform public.create_transaction(
                p_platform_profile_id,
                v_ride.id,
                p_platform_fee,
                'credit',
                'platform_fee',
                'Platform fee received from cash ride',
                null,
                jsonb_build_object(
                    'fare', v_ride.fare,
                    'final_fare', v_ride.final_fare,
                    'platform_fee', p_platform_fee,
                    'rider_profile_id', v_ride.rider_profile_id,
                    'payment_method', v_ride.payment_method
                )
            );

end if;

else
        raise exception 'INVALID_PAYMENT_METHOD';
end if;

update public.rides
set
    status = 'Completed',
    completed_at = now()
where id = v_ride.id
    returning *
into v_ride;

return v_ride;
end;
$$;