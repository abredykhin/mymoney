-- Create coach_insights table to cache AI coach recommendations
CREATE TABLE public.coach_insights (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  badge text NOT NULL,
  headline text NOT NULL,
  nudge_text text NOT NULL,
  action_label text NOT NULL,
  alternative_tip text NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Enable Row Level Security
ALTER TABLE public.coach_insights ENABLE ROW LEVEL SECURITY;

-- Allow users to view their own coach insights
CREATE POLICY "Users can view their own coach insights" 
  ON public.coach_insights FOR SELECT 
  USING (auth.uid() = user_id);

-- Update the updated_at timestamp automatically on updates
CREATE TRIGGER coach_insights_updated_at_timestamp
  BEFORE UPDATE ON public.coach_insights
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_set_timestamp();
