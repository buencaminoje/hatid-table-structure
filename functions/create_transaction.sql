create or replace function public.create_transaction(
    p_profile_id uuid,
    p_ride_id uuid,
    p_amount numeric,
    p_type text,
    p_category text,
    p_description text default null,
    p_remarks text default null,
    p_metadata jsonb default '{}',
    p_allow_negative boolean default false
)
returns public.transactions
language plpgsql
security definer
set search_path = public
as $$
declare
v_transaction public.transactions;
    v_wallet_balance numeric;
    v_remarks text;
begin
    if p_profile_id is null then
        raise exception 'PROFILE_REQUIRED';
end if;

    if p_amount is null or p_amount <= 0 then
        raise exception 'INVALID_TRANSACTION_AMOUNT';
end if;

    if p_type is null
       or lower(trim(p_type)) not in ('debit', 'credit') then
        raise exception 'INVALID_TRANSACTION_TYPE';
end if;

    if p_category is null
       or trim(p_category) = '' then
        raise exception 'CATEGORY_REQUIRED';
end if;

    p_type := lower(trim(p_type));

    if p_type = 'debit' then

        if p_allow_negative then

update public.profiles
set wallet_balance = wallet_balance - p_amount
where id = p_profile_id
    returning wallet_balance
into v_wallet_balance;

if not found then
                raise exception 'PROFILE_NOT_FOUND';
end if;

else

update public.profiles
set wallet_balance = wallet_balance - p_amount
where id = p_profile_id
  and wallet_balance >= p_amount
    returning wallet_balance
into v_wallet_balance;

if not found then

                perform 1
                from public.profiles
                where id = p_profile_id;

                if not found then
                    raise exception 'PROFILE_NOT_FOUND';
end if;

                raise exception 'INSUFFICIENT_WALLET_BALANCE';

end if;

end if;

else

update public.profiles
set wallet_balance = wallet_balance + p_amount
where id = p_profile_id
    returning wallet_balance
into v_wallet_balance;

if not found then
            raise exception 'PROFILE_NOT_FOUND';
end if;

end if;

    v_remarks := p_remarks;

    if p_type = 'debit'
       and v_wallet_balance < 0 then

        v_remarks := concat_ws(
            ' | ',
            p_remarks,
            format(
                'Wallet balance became negative; outstanding balance: %s',
                to_char(abs(v_wallet_balance), 'FM999999999990.00')
            )
        );

end if;

insert into public.transactions (
    profile_id,
    ride_id,
    amount,
    type,
    category,
    description,
    remarks,
    metadata
)
values (
           p_profile_id,
           p_ride_id,
           p_amount,
           p_type,
           trim(p_category),
           p_description,
           v_remarks,
           coalesce(p_metadata, '{}'::jsonb)
       )
    returning *
into v_transaction;

return v_transaction;
end;
$$;