-- Create budget_items_table to store patterns identified by Gemini
CREATE TABLE IF NOT EXISTS public.budget_items_table (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    pattern TEXT NOT NULL,
    amount NUMERIC(28,2) NOT NULL,
    frequency TEXT NOT NULL CHECK (frequency IN ('weekly', 'bi-weekly', 'monthly', 'quarterly', 'yearly', 'irregular')),
    monthly_amount NUMERIC(28,2) NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'fixed_expense')),
    confidence NUMERIC(3,2) NOT NULL,
    last_seen_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, pattern)
);

-- Enable RLS
ALTER TABLE public.budget_items_table ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own budget items" 
ON public.budget_items_table FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own budget items" 
ON public.budget_items_table FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own budget items" 
ON public.budget_items_table FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own budget items" 
ON public.budget_items_table FOR DELETE 
USING (auth.uid() = user_id);

-- Update trigger
CREATE TRIGGER set_timestamp_budget_items
BEFORE UPDATE ON public.budget_items_table
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_budget_items_user_id ON public.budget_items_table(user_id);
CREATE INDEX IF NOT EXISTS idx_budget_items_pattern ON public.budget_items_table(pattern);

-- Update profiles view to include budget columns if not already there (though they should be from previous migration)
-- This is just for safety/completeness in development
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles_table' AND column_name='monthly_income') THEN
        ALTER TABLE public.profiles_table ADD COLUMN monthly_income numeric(28,2) DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles_table' AND column_name='monthly_mandatory_expenses') THEN
        ALTER TABLE public.profiles_table ADD COLUMN monthly_mandatory_expenses numeric(28,2) DEFAULT 0;
    END IF;
END $$;
