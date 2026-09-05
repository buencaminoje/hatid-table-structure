create or replace function public.create_ride_order(
    p_profile_id uuid,
    p_holding_profile_id uuid,
    p_promo_code text default null,
    p_discount_applied numeric default null,
    p_ride_data jsonb default '{}',
    p_delivery_details jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
v_promo_id uuid;
    v_ride public.rides;
    v_redemption public.promo_redemptions;
    v_promo_code_normalized text;
begin
    v_promo_code_normalized := nullif(
        upper(trim(p_promo_code)),
        ''
    );

    if v_promo_code_normalized is not null then
select id
into v_promo_id
from public.promos
where upper(code) = v_promo_code_normalized;

if not found then
            raise exception 'PROMO_INVALID';
end if;
end if;

   if upper(p_ride_data->>'payment_method') = 'WALLET'
   and (p_ride_data->>'final_fare')::numeric > 0 then
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
end if;

insert into public.rides (
    customer_profile_id,
    pickup_location,
    drop_location,
    pickup_latitude,
    pickup_longitude,
    drop_latitude,
    drop_longitude,
    pickup_coords,
    drop_coords,
    final_fare,
    fare,
    passenger_count,
    status,
    category,
    type,
    payment_method,
    service_model,
    remarks,
    notes,
    promo_applied,
    metadata
)
values (
           p_profile_id,
           p_ride_data->>'pickup_location',
           p_ride_data->>'drop_location',
           (p_ride_data->>'pickup_latitude')::double precision,
           (p_ride_data->>'pickup_longitude')::double precision,
           (p_ride_data->>'drop_latitude')::double precision,
           (p_ride_data->>'drop_longitude')::double precision,

           extensions.ST_SetSRID(
                   extensions.ST_MakePoint(
                           (p_ride_data->>'pickup_longitude')::double precision,
                           (p_ride_data->>'pickup_latitude')::double precision
                   ),
                   4326
           )::extensions.geography,

           extensions.ST_SetSRID(
                   extensions.ST_MakePoint(
                           (p_ride_data->>'drop_longitude')::double precision,
                           (p_ride_data->>'drop_latitude')::double precision
                   ),
                   4326
           )::extensions.geography,

           (p_ride_data->>'final_fare')::numeric,
           (p_ride_data->>'fare')::numeric,

           nullif(
                   p_ride_data->>'passenger_count',
        ''
    )::integer,

           'Pending',
           p_ride_data->>'category',
           p_ride_data->>'type',
           p_ride_data->>'payment_method',
           p_ride_data->>'service_model',
           p_ride_data->>'remarks',
           p_ride_data->>'notes',

           v_promo_id is not null,

           coalesce(
                   p_ride_data->'metadata',
                   '{}'::jsonb
           )
               ||
           (
               p_ride_data
                   - 'pickup_location'
                   - 'drop_location'
                   - 'pickup_latitude'
                   - 'pickup_longitude'
                   - 'drop_latitude'
                   - 'drop_longitude'
                   - 'final_fare'
                   - 'fare'
                   - 'passenger_count'
                   - 'category'
                   - 'type'
                   - 'payment_method'
                   - 'service_model'
                   - 'remarks'
                   - 'notes'
                   - 'metadata'
                   - 'promo_applied'
               )
       )
    returning *
into v_ride;

if upper(v_ride.payment_method) = 'WALLET'
   and v_ride.final_fare > 0 then

    perform public.create_transaction(
        p_profile_id,
        v_ride.id,
        v_ride.final_fare,
        'debit',
        'ride_payment',
        'Ride payment transferred to holding wallet',
        null,
        jsonb_build_object(
            'status', 'HELD',
            'holding_profile_id', p_holding_profile_id
        )
    );

    perform public.create_transaction(
        p_holding_profile_id,
        v_ride.id,
        v_ride.final_fare,
        'credit',
        'ride_payment_hold',
        'Ride payment received into holding wallet',
        null,
        jsonb_build_object(
            'status', 'HELD',
            'customer_profile_id', p_profile_id
        )
    );
end if;

    if p_delivery_details is not null then
        insert into public.delivery_details (
            ride_id,
            is_pabili,
            estimated_purchase_amount,
            sender_name,
            sender_contact_number,
            receiver_name,
            receiver_contact_number,
            package_description,
            pickup_instructions,
            delivery_instructions
        )
        values (
            v_ride.id,
            coalesce(
                (p_delivery_details->>'is_pabili')::boolean,
                false
            ),
            nullif(
                p_delivery_details->>'estimated_purchase_amount',
                ''
            )::numeric,
            p_delivery_details->>'sender_name',
            p_delivery_details->>'sender_contact_number',
            p_delivery_details->>'receiver_name',
            p_delivery_details->>'receiver_contact_number',
            p_delivery_details->>'package_description',
            p_delivery_details->>'pickup_instructions',
            p_delivery_details->>'delivery_instructions'
        );
end if;

    if v_promo_id is not null then
select *
into v_redemption
from public.redeem_promo(
        v_promo_id,
        p_profile_id,
        v_ride.id,
        coalesce(p_discount_applied, 0)
     );
end if;

return jsonb_build_object(
        'ride',
        to_jsonb(v_ride),
        'promoRedemption',
        case
            when v_redemption.id is not null
                then to_jsonb(v_redemption)
            else null
            end
       );
end;
$$;