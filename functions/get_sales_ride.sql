create or replace function public.get_sales_rides(
    p_from timestamptz default null,
    p_to timestamptz default null,
    p_payment_method text default null,
    p_service_type text default null,
    p_limit integer default 50,
    p_offset integer default 0
)
returns table (
    ride_id uuid,
    status text,
    type text,
    category text,
    payment_method text,
    fare numeric,
    final_fare numeric,
    gross_sale numeric,
    marketing_subsidy numeric,
    net_sale numeric,
    platform_fee numeric,
    created_at timestamptz,
    completed_at timestamptz
)
language sql
security definer
set search_path = public
as $$
select
    r.id as ride_id,
    r.status,
    r.type,
    r.category,
    r.payment_method,
    r.fare,
    r.final_fare,

    coalesce(r.fare, 0) as gross_sale,

    case
        when coalesce(r.promo_applied, false)
            then greatest(
                coalesce(r.fare, 0) - coalesce(r.final_fare, 0),
                0
                 )
        else 0
        end as marketing_subsidy,

    coalesce(r.final_fare, r.fare, 0) as net_sale,

    coalesce(tf.platform_fee, 0) as platform_fee,

    r.created_at,
    r.completed_at

from public.rides r

         left join lateral (
    select
        coalesce(sum(t.amount), 0) as platform_fee
    from public.transactions t
    where t.ride_id = r.id
      and t.category = 'platform_fee'
      and t.type = 'credit'
        ) tf on true

where r.status = 'Completed'

  and (
    p_from is null
        or r.completed_at >= p_from
    )

  and (
    p_to is null
        or r.completed_at < p_to
    )

  and (
    p_payment_method is null
        or upper(r.payment_method) = upper(p_payment_method)
    )

  and (
    p_service_type is null
        or upper(r.type) = upper(p_service_type)
    )

order by r.completed_at desc

    limit greatest(p_limit, 1)
offset greatest(p_offset, 0);
$$;