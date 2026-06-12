-- gym_schema_v3.sql
-- Ejecuta esto en el SQL Editor de Supabase

-- Añadir campos de progresión automática a template_exercises
ALTER TABLE public.template_exercises 
ADD COLUMN IF NOT EXISTS progression_rule TEXT,
ADD COLUMN IF NOT EXISTS progression_target_reps INT4,
ADD COLUMN IF NOT EXISTS progression_target_weight_increase NUMERIC;
