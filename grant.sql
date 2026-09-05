GRANT USAGE ON SCHEMA public TO service_role;

GRANT SELECT, UPDATE
    ON TABLE public.profiles
    TO service_role;

GRANT SELECT, UPDATE
    ON TABLE public.rides
    TO service_role;

GRANT SELECT, UPDATE
    ON TABLE public.delivery_details
    TO service_role;

GRANT SELECT, UPDATE
    ON TABLE public.riders
    TO service_role;

GRANT SELECT, INSERT
    ON TABLE public.messages
    TO service_role;

GRANT SELECT, INSERT, UPDATE
    ON TABLE public.transactions
    TO service_role;

GRANT SELECT, INSERT, UPDATE
    ON TABLE public.promos
    TO service_role;

GRANT SELECT, INSERT, UPDATE
    ON TABLE public.promo_redemptions
    TO service_role;


