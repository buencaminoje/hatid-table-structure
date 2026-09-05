create or replace function public.create_user_profile(
    p_auth_id uuid,
    p_type text,
    p_status text,
    p_nickname text default null,
    p_phone text default null,
    p_email text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
v_profile public.profiles;
    v_type text;
    v_status text;
begin
    if p_auth_id is null then
        raise exception 'AUTH_ID_REQUIRED';
end if;

    v_type := initcap(lower(trim(p_type)));
    v_status := initcap(lower(trim(p_status)));

    if v_type not in ('Customer', 'Rider') then
        raise exception 'INVALID_PROFILE_TYPE';
end if;

    if v_status not in ('Active', 'Pending') then
        raise exception 'INVALID_PROFILE_STATUS';
end if;

insert into public.profiles (
    auth_id,
    type,
    nickname,
    mobile_number,
    email,
    status
)
values (
           p_auth_id,
           v_type,
           p_nickname,
           coalesce(p_phone, ''),
           coalesce(p_email, ''),
           v_status
       )
    on conflict (auth_id, type)
    do update set
    nickname = excluded.nickname,
               mobile_number = excluded.mobile_number,
               email = excluded.email,
               status = excluded.status
               returning *
       into v_profile;

if v_type = 'Rider' then
        insert into public.riders (
            profile_id
        )
        values (
            v_profile.id
        )
        on conflict (profile_id) do nothing;
end if;

return jsonb_build_object(
        'success', true,
        'profile', to_jsonb(v_profile)
       );
end;
$$;