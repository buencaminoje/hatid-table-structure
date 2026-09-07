create or replace function public.get_pending_rider_remittances(
    p_limit integer default 50,
    p_offset integer default 0
)
returns table (
    profile_id uuid,
    nickname text,
    mobile_number text,
    wallet_balance numeric,
    pending_remittance numeric
)
language sql
security definer
set search_path = public
as $$
select
    p.id as profile_id,
    trim(concat_ws(' ', p.nickname)) as nickname,
    p.mobile_number,
    p.wallet_balance,
    abs(p.wallet_balance) as pending_remittance
from public.profiles p
where p.wallet_balance < 0 AND
      p.type = 'Rider'
order by p.wallet_balance asc
    limit greatest(p_limit, 1)
offset greatest(p_offset, 0);
$$;