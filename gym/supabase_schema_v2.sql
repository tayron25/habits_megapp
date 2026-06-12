-- gym_schema_v2.sql
-- Ejecuta esto en el SQL Editor de Supabase

-- 1. Añadir columna note a workout_sets
ALTER TABLE public.workout_sets ADD COLUMN IF NOT EXISTS note TEXT;

-- 2. Crear tabla planned_workouts
CREATE TABLE IF NOT EXISTS public.planned_workouts (
    id UUID PRIMARY KEY,
    template_id UUID REFERENCES public.workout_templates(id) ON DELETE CASCADE,
    planned_date TIMESTAMPTZ NOT NULL,
    is_completed BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    is_synced BOOLEAN DEFAULT false NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL
);

-- 3. Crear tabla planned_exercises
CREATE TABLE IF NOT EXISTS public.planned_exercises (
    id UUID PRIMARY KEY,
    planned_workout_id UUID REFERENCES public.planned_workouts(id) ON DELETE CASCADE,
    exercise_name TEXT NOT NULL,
    target_weight NUMERIC,
    target_reps INT4,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    is_synced BOOLEAN DEFAULT false NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL
);

-- Permisos necesarios
GRANT SELECT, INSERT, UPDATE, DELETE ON public.planned_workouts TO authenticated;
ALTER TABLE public.planned_workouts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own planned workouts"
ON public.planned_workouts
FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.planned_exercises TO authenticated;
ALTER TABLE public.planned_exercises ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own planned exercises"
ON public.planned_exercises
FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
