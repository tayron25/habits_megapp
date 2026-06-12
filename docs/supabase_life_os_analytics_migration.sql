-- Life OS analytics migration
-- Run this in the Supabase SQL Editor.

ALTER TABLE public.notes
ADD COLUMN IF NOT EXISTS life_area_id UUID REFERENCES public.life_areas(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'captured',
ADD COLUMN IF NOT EXISTS processed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS converted_to_type TEXT,
ADD COLUMN IF NOT EXISTS converted_to_id UUID,
ADD COLUMN IF NOT EXISTS note_type TEXT;

ALTER TABLE public.tasks
ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active',
ADD COLUMN IF NOT EXISTS processed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS planned_date TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS missed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS origin_type TEXT,
ADD COLUMN IF NOT EXISTS origin_id UUID;

ALTER TABLE public.roadmaps
ADD COLUMN IF NOT EXISTS show_on_home BOOLEAN NOT NULL DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS life_area_id UUID REFERENCES public.life_areas(id) ON DELETE SET NULL;

ALTER TABLE public.milestone_tasks
ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active',
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

ALTER TABLE public.habit_logs
ADD COLUMN IF NOT EXISTS target_date TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'done',
ADD COLUMN IF NOT EXISTS logged_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS amount INTEGER,
ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'manual';

CREATE TABLE IF NOT EXISTS public.activity_events (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  event_type TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  life_area_id UUID REFERENCES public.life_areas(id) ON DELETE SET NULL,
  occurred_at TIMESTAMPTZ NOT NULL,
  local_date DATE NOT NULL,
  source_app TEXT NOT NULL DEFAULT 'life_os',
  metadata_json JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.activity_events TO authenticated;
ALTER TABLE public.activity_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own activity_events" ON public.activity_events;

CREATE POLICY "Users can manage their own activity_events"
ON public.activity_events
FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

NOTIFY pgrst, 'reload schema';
