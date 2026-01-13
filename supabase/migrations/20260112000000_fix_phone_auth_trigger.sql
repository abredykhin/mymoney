-- Fix handle_new_user trigger to support phone authentication
-- When users sign up with phone, NEW.email is NULL, so we use phone instead

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles_table (id, username)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, NEW.phone, NEW.id::text)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
