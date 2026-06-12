export type LifeArea = {
  id: string;
  name: string;
  icon: string | null;
};

export type ActivityEvent = {
  id: string;
  event_type: string;
  entity_type: string;
  entity_id: string;
  life_area_id: string | null;
  occurred_at: string;
  local_date: string;
  source_app: string;
  metadata_json: Record<string, unknown> | null;
};

export type HabitLogRow = {
  id: string;
  habit_id: string;
  completed_date: string;
  target_date: string | null;
  status: string | null;
  logged_at: string | null;
};

export type TaskRow = {
  id: string;
  status: string | null;
  life_area_id: string | null;
  created_at: string;
  processed_at: string | null;
  completed_at: string | null;
  missed_at: string | null;
};

export type NoteRow = {
  id: string;
  life_area_id: string | null;
  status: string | null;
  created_at: string;
  processed_at: string | null;
};

export type RoadmapRow = {
  id: string;
  title: string;
  life_area_id: string | null;
};

export type MilestoneRow = {
  id: string;
  roadmap_id: string;
};

export type MilestoneTaskRow = {
  id: string;
  milestone_id: string;
  is_completed: boolean | null;
  status: string | null;
  completed_at: string | null;
};

export type WorkoutLogRow = {
  id: string;
  template_id: string | null;
  date: string;
};

export type WorkoutSetRow = {
  id: string;
  workout_log_id: string;
  exercise_name: string;
  weight: number | null;
  reps: number | null;
};

export type RawAnalyticsData = {
  areas: LifeArea[];
  events: ActivityEvent[];
  previousEvents: ActivityEvent[];
  habitLogs: HabitLogRow[];
  previousHabitLogs: HabitLogRow[];
  tasks: TaskRow[];
  notes: NoteRow[];
  roadmaps: RoadmapRow[];
  milestones: MilestoneRow[];
  milestoneTasks: MilestoneTaskRow[];
  workoutLogs: WorkoutLogRow[];
  previousWorkoutLogs: WorkoutLogRow[];
  workoutSets: WorkoutSetRow[];
  warnings: string[];
};

export type Insight = {
  id: string;
  kind: "positive" | "negative" | "neutral";
  title: string;
  body: string;
  evidence: string;
  action: string;
  confidence: "alta" | "media" | "baja";
};

export type ScoreBreakdown = {
  overall: number;
  consistency: number;
  execution: number;
  mentalLoad: number;
  progress: number;
  explanation: Array<{ label: string; value: number; detail: string }>;
};

export type AreaHealth = {
  id: string | null;
  name: string;
  action: number;
  mentalLoad: number;
  progress: number;
  friction: number;
  score: number;
};

export type CalendarDay = {
  date: string;
  label: string;
  status: "good" | "mixed" | "friction" | "empty";
  score: number;
  habits: number;
  tasksDone: number;
  tasksMissed: number;
  notes: number;
  workouts: number;
};

export type GymCorrelation = {
  workoutDays: number;
  restDays: number;
  taskDoneOnWorkoutDays: number;
  taskDoneOnRestDays: number;
  habitDoneOnWorkoutDays: number;
  habitDoneOnRestDays: number;
  message: string;
};

export type RoadmapHealth = {
  id: string;
  title: string;
  areaName: string;
  progress: number;
  completedTasks: number;
  totalTasks: number;
  daysSinceLastProgress: number | null;
  status: "activo" | "estancado" | "sin tareas";
};

export type Diagnosis = {
  headline: string;
  summary: string;
  helpingPattern: Insight;
  harmfulPattern: Insight;
  strongestArea: AreaHealth | null;
  weakestArea: AreaHealth | null;
  recommendedFocus: string;
};

export type DashboardData = {
  areas: LifeArea[];
  diagnosis: Diagnosis;
  scores: ScoreBreakdown;
  insights: Insight[];
  areaHealth: AreaHealth[];
  calendarDays: CalendarDay[];
  scoreSeries: Array<{ date: string; label: string; score: number; execution: number; mentalLoad: number }>;
  gymCorrelation: GymCorrelation;
  roadmapHealth: RoadmapHealth[];
  recentEvents: ActivityEvent[];
  warnings: string[];
};
