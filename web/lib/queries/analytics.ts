import type { SupabaseClient } from "@supabase/supabase-js";
import { previousRange, rangeToBounds, type DateRange } from "@/lib/date/ranges";
import type {
  ActivityEvent,
  HabitLogRow,
  LifeArea,
  MilestoneRow,
  MilestoneTaskRow,
  NoteRow,
  RawAnalyticsData,
  RoadmapRow,
  TaskRow,
  WorkoutLogRow,
  WorkoutSetRow
} from "@/features/analytics/types";

type QueryResult<T> = {
  data: T[];
  warning?: string;
};

async function safeSelect<T>(
  label: string,
  query: PromiseLike<{ data: T[] | null; error: { message: string } | null }>
): Promise<QueryResult<T>> {
  const { data, error } = await query;
  if (error) {
    return { data: [], warning: `${label}: ${error.message}` };
  }
  return { data: data ?? [] };
}

export async function fetchRawAnalyticsData(supabase: SupabaseClient, range: DateRange): Promise<RawAnalyticsData> {
  const bounds = rangeToBounds(range);
  const previous = previousRange(range);
  const warnings: string[] = [];

  const [
    areasResult,
    eventsResult,
    previousEventsResult,
    habitLogsResult,
    previousHabitLogsResult,
    tasksResult,
    notesResult,
    roadmapsResult,
    milestonesResult,
    milestoneTasksResult,
    workoutLogsResult,
    previousWorkoutLogsResult,
    workoutSetsResult
  ] = await Promise.all([
    safeSelect<LifeArea>("life_areas", supabase.from("life_areas").select("id,name,icon").order("name")),
    safeSelect<ActivityEvent>(
      "activity_events",
      supabase
        .from("activity_events")
        .select("id,event_type,entity_type,entity_id,life_area_id,occurred_at,local_date,source_app,metadata_json")
        .gte("occurred_at", bounds.fromIso)
        .lte("occurred_at", bounds.toIso)
        .order("occurred_at", { ascending: false })
        .limit(500)
    ),
    safeSelect<ActivityEvent>(
      "activity_events previous",
      supabase
        .from("activity_events")
        .select("id,event_type,entity_type,entity_id,life_area_id,occurred_at,local_date,source_app,metadata_json")
        .gte("occurred_at", previous.fromIso)
        .lte("occurred_at", previous.toIso)
        .limit(500)
    ),
    safeSelect<HabitLogRow>(
      "habit_logs",
      supabase
        .from("habit_logs")
        .select("id,habit_id,completed_date,target_date,status,logged_at")
        .gte("completed_date", bounds.fromIso)
        .lte("completed_date", bounds.toIso)
        .limit(2000)
    ),
    safeSelect<HabitLogRow>(
      "habit_logs previous",
      supabase
        .from("habit_logs")
        .select("id,habit_id,completed_date,target_date,status,logged_at")
        .gte("completed_date", previous.fromIso)
        .lte("completed_date", previous.toIso)
        .limit(2000)
    ),
    safeSelect<TaskRow>(
      "tasks",
      supabase
        .from("tasks")
        .select("id,status,life_area_id,created_at,processed_at,completed_at,missed_at")
        .lte("created_at", bounds.toIso)
        .limit(4000)
    ),
    safeSelect<NoteRow>(
      "notes",
      supabase
        .from("notes")
        .select("id,life_area_id,status,created_at,processed_at")
        .lte("created_at", bounds.toIso)
        .limit(4000)
    ),
    safeSelect<RoadmapRow>("roadmaps", supabase.from("roadmaps").select("id,title,life_area_id").limit(1000)),
    safeSelect<MilestoneRow>("roadmap_milestones", supabase.from("roadmap_milestones").select("id,roadmap_id").limit(2000)),
    safeSelect<MilestoneTaskRow>(
      "milestone_tasks",
      supabase.from("milestone_tasks").select("id,milestone_id,is_completed,status,completed_at").limit(4000)
    ),
    safeSelect<WorkoutLogRow>(
      "workout_logs",
      supabase.from("workout_logs").select("id,template_id,date").gte("date", bounds.fromIso).lte("date", bounds.toIso).limit(1000)
    ),
    safeSelect<WorkoutLogRow>(
      "workout_logs previous",
      supabase.from("workout_logs").select("id,template_id,date").gte("date", previous.fromIso).lte("date", previous.toIso).limit(1000)
    ),
    safeSelect<WorkoutSetRow>(
      "workout_sets",
      supabase.from("workout_sets").select("id,workout_log_id,exercise_name,weight,reps").limit(8000)
    )
  ]);

  for (const result of [
    areasResult,
    eventsResult,
    previousEventsResult,
    habitLogsResult,
    previousHabitLogsResult,
    tasksResult,
    notesResult,
    roadmapsResult,
    milestonesResult,
    milestoneTasksResult,
    workoutLogsResult,
    previousWorkoutLogsResult,
    workoutSetsResult
  ]) {
    if (result.warning) warnings.push(result.warning);
  }

  return {
    areas: areasResult.data,
    events: eventsResult.data,
    previousEvents: previousEventsResult.data,
    habitLogs: habitLogsResult.data,
    previousHabitLogs: previousHabitLogsResult.data,
    tasks: tasksResult.data,
    notes: notesResult.data,
    roadmaps: roadmapsResult.data,
    milestones: milestonesResult.data,
    milestoneTasks: milestoneTasksResult.data,
    workoutLogs: workoutLogsResult.data,
    previousWorkoutLogs: previousWorkoutLogsResult.data,
    workoutSets: workoutSetsResult.data,
    warnings
  };
}
