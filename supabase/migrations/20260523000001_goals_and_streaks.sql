-- Create Savings Goals and Streaks schemas

-- 1. Create savings_goals_table to support visual progress cards
CREATE TABLE IF NOT EXISTS public.savings_goals_table (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.profiles_table(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    target_amount NUMERIC(28,2) NOT NULL CHECK (target_amount > 0),
    current_amount NUMERIC(28,2) NOT NULL DEFAULT 0 CHECK (current_amount >= 0),
    eta_date DATE,
    category_icon TEXT DEFAULT '✈️', -- Emojis or SFSymbol names
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast user goal lookup
CREATE INDEX IF NOT EXISTS idx_savings_goals_user_id ON public.savings_goals_table(user_id);

-- Enable RLS
ALTER TABLE public.savings_goals_table ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own savings goals" ON public.savings_goals_table;
CREATE POLICY "Users can manage their own savings goals"
    ON public.savings_goals_table FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 2. Create savings_deposits_table to track historical progress
CREATE TABLE IF NOT EXISTS public.savings_deposits_table (
    id SERIAL PRIMARY KEY,
    goal_id INTEGER NOT NULL REFERENCES public.savings_goals_table(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles_table(id) ON DELETE CASCADE,
    amount NUMERIC(28,2) NOT NULL CHECK (amount > 0),
    deposit_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast user deposit lookup
CREATE INDEX IF NOT EXISTS idx_savings_deposits_goal_date ON public.savings_deposits_table(goal_id, deposit_date);

-- Enable RLS
ALTER TABLE public.savings_deposits_table ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own savings deposits" ON public.savings_deposits_table;
CREATE POLICY "Users can manage their own savings deposits"
    ON public.savings_deposits_table FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 3. Create or replace trigger function to update current savings amounts automatically
CREATE OR REPLACE FUNCTION public.update_goal_current_amount()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.savings_goals_table
        SET current_amount = current_amount + NEW.amount
        WHERE id = NEW.goal_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.savings_goals_table
        SET current_amount = current_amount - OLD.amount
        WHERE id = OLD.goal_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_goal_amount ON public.savings_deposits_table;
CREATE TRIGGER trigger_update_goal_amount
AFTER INSERT OR DELETE ON public.savings_deposits_table
FOR EACH ROW EXECUTE FUNCTION public.update_goal_current_amount();


-- 4. Dynamic spending streak calculations
DROP FUNCTION IF EXISTS public.get_user_spending_streak();
CREATE OR REPLACE FUNCTION public.get_user_spending_streak()
RETURNS TABLE (
    current_streak INT,
    max_streak INT,
    last_10_days_status BOOLEAN[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    income_val NUMERIC(28,2);
    fixed_exp NUMERIC(28,2);
    daily_limit NUMERIC(28,2);
    streak_count INT := 0;
    max_streak_count INT := 0;
    temp_streak INT := 0;
    day_idx INT;
    spend_on_day NUMERIC(28,2);
    status_arr BOOLEAN[] := '{}';
    day_date DATE;
    started_streak BOOLEAN := FALSE;
BEGIN
    -- 1. Get user profile budget guidelines
    SELECT COALESCE(monthly_income, 0), COALESCE(monthly_mandatory_expenses, 0)
    INTO income_val, fixed_exp
    FROM public.profiles_table
    WHERE id = auth.uid();

    -- Calculate daily variable allowance (discretionary budget / 30)
    daily_limit := (income_val - fixed_exp) / 30.0;
    IF daily_limit <= 0 THEN
        daily_limit := 50.00; -- Fallback allowance ($50/day)
    END IF;

    -- 2. Build 10-day status and calculate streaks over the past 90 days
    FOR day_idx IN 0..90 LOOP
        day_date := CURRENT_DATE - day_idx;
        
        -- Get total variable spend for that day
        SELECT COALESCE(SUM(amount), 0)
        INTO spend_on_day
        FROM public.transactions_table
        WHERE user_id = auth.uid()
          AND COALESCE(authorized_date, date) = day_date
          AND amount > 0
          -- Exclude fixed/recurring bills (if column exists, or fallback is_recurring)
          AND (personal_finance_category IS NULL OR personal_finance_category NOT ILIKE '%TRANSFER%');

        -- Determine if under budget on that day
        IF spend_on_day <= daily_limit THEN
            temp_streak := temp_streak + 1;
            IF day_idx < 10 THEN
                status_arr := array_append(status_arr, TRUE);
            END IF;
        ELSE
            -- Streak broken
            IF temp_streak > max_streak_count THEN
                max_streak_count := temp_streak;
            END IF;
            
            -- If we are evaluating the consecutive active current streak (starting from today)
            -- and it was broken, freeze current_streak calculation
            IF streak_count = 0 AND day_idx > 0 THEN
                streak_count := temp_streak;
            END IF;
            
            temp_streak := 0;
            IF day_idx < 10 THEN
                status_arr := array_append(status_arr, FALSE);
            END IF;
        END IF;
    END LOOP;

    -- If streak is still active up to today
    IF streak_count = 0 THEN
        streak_count := temp_streak;
    END IF;
    IF temp_streak > max_streak_count THEN
        max_streak_count := temp_streak;
    END IF;

    RETURN QUERY SELECT streak_count, max_streak_count, status_arr;
END;
$$;
