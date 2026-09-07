create or replace function public.get_admin_dashboard()
returns jsonb
language sql
security definer
set search_path = public
as $$
with ride_metrics as (
    select
        count(*) filter (
            where r.status in ('Accepted', 'Arrived', 'Started')
        ) as active_rides,

        count(*) filter (
            where r.status = 'Pending'
        ) as pending_rides,

        count(*) filter (
            where r.status = 'Completed'
            and r.completed_at >= current_date
            and r.completed_at < current_date + interval '1 day'
        ) as completed_rides_today,

        count(*) filter (
            where r.status = 'Cancelled'
            and r.cancelled_at >= current_date
            and r.cancelled_at < current_date + interval '1 day'
        ) as cancelled_rides_today,

        count(*) filter (
            where r.created_at >= current_date
            and r.created_at < current_date + interval '1 day'
        ) as rides_today,

        coalesce(
            sum(r.fare) filter (
                where r.status = 'Completed'
                and r.completed_at >= current_date
                and r.completed_at < current_date + interval '1 day'
            ),
            0
        ) as gross_sales_today,

        coalesce(
            sum(
                case
                    when r.status = 'Completed'
                    and r.completed_at >= current_date
                    and r.completed_at < current_date + interval '1 day'
                    and r.promo_applied = true
                    then greatest(
                        coalesce(r.fare, 0) -
                        coalesce(r.final_fare, 0),
                        0
                    )
                    else 0
                end
            ),
            0
        ) as marketing_subsidy_today,

        coalesce(
            sum(r.final_fare) filter (
                where r.status = 'Completed'
                and r.completed_at >= current_date
                and r.completed_at < current_date + interval '1 day'
            ),
            0
        ) as net_sales_today

    from public.rides r
),

platform_revenue as (
    select
        coalesce(
            sum(t.amount),
            0
        ) as platform_revenue_today
    from public.transactions t
    join public.rides r
        on r.id = t.ride_id
    where t.category = 'platform_fee'
      and t.type = 'credit'
      and r.status = 'Completed'
      and r.completed_at >= current_date
      and r.completed_at < current_date + interval '1 day'
),

rider_metrics as (
    select
        count(*) as riders,

        count(*) filter (
            where r.is_online = true
        ) as online_riders,

        coalesce(
            sum(
                case
                    when p.wallet_balance < 0
                    then abs(p.wallet_balance)
                    else 0
                end
            ),
            0
        ) as pending_remittance

    from public.riders r
    join public.profiles p
        on p.id = r.profile_id
    where p.type = 'Rider'
),

customer_metrics as (
    select
        count(*) as customers
    from public.profiles p
    where p.type = 'Customer'
),

active_customers as (
    select
        count(distinct r.customer_profile_id)
        as active_customers_today
    from public.rides r
    where r.created_at >= current_date
      and r.created_at < current_date + interval '1 day'
),

completion_metrics as (
    select
        count(*) filter (
            where r.status = 'Completed'
        ) as completed,

        count(*) filter (
            where r.status in ('Completed', 'Cancelled')
        ) as finished

    from public.rides r
    where r.created_at >= current_date
      and r.created_at < current_date + interval '1 day'
)

select jsonb_build_object(
               'activeRides',
               rm.active_rides,

               'pendingRides',
               rm.pending_rides,

               'onlineRiders',
               rdm.online_riders,

               'completedRidesToday',
               rm.completed_rides_today,

               'cancelledRidesToday',
               rm.cancelled_rides_today,

               'ridesToday',
               rm.rides_today,

               'grossSalesToday',
               rm.gross_sales_today,

               'netSalesToday',
               rm.net_sales_today,

               'platformRevenueToday',
               pr.platform_revenue_today,

               'marketingSubsidyToday',
               rm.marketing_subsidy_today,

               'pendingRemittance',
               rdm.pending_remittance,

               'customers',
               cm.customers,

               'activeCustomersToday',
               ac.active_customers_today,

               'riders',
               rdm.riders,

               'activeRiders',
               rdm.online_riders,

               'completionRate',
               case
                   when c.finished = 0 then 0
                   else round(
                           c.completed::numeric /
                c.finished::numeric * 100,
                           1
                        )
                   end,

               'cancellationRate',
               case
                   when rm.rides_today = 0 then 0
                   else round(
                           rm.cancelled_rides_today::numeric /
                rm.rides_today::numeric * 100,
                           1
                        )
                   end
       )
from ride_metrics rm
         cross join platform_revenue pr
         cross join rider_metrics rdm
         cross join customer_metrics cm
         cross join active_customers ac
         cross join completion_metrics c;
$$;