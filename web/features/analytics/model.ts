import { eachDay, formatShortDate, rangeToBounds, type DateRange } from "@/lib/date/ranges";
import type {
  AreaHealth,
  CalendarDay,
  DashboardData,
  GymCorrelation,
  RawAnalyticsData,
  RoadmapHealth,
  ScoreBreakdown
} from "@/features/analytics/types";
import { buildDiagnosis, buildInsights } from "@/features/analytics/insights";

function clamp(value: number, min = 0, max = 100) {
  return Math.max(min, Math.min(max, Math.round(value)));
}

function dayKey(value: string) {
  return value.slice(0, 10);
}

function inRange(value: string | null | undefined, fromIso: string, toIso: string) {
  if (!value) return false;
  const time = new Date(value).getTime();
  return time >= new Date(fromIso).getTime() && time <= new Date(toIso).getTime();
}

function matchesArea(lifeAreaId: string | null | undefined, selectedAreaId: string | "all") {
  return selectedAreaId === "all" || lifeAreaId === selectedAreaId;
}

export function buildDashboardModel(raw: RawAnalyticsData, range: DateRange, selectedAreaId: string | "all"): DashboardData {
  const bounds = rangeToBounds(range);
  const areas = raw.areas;
  const areaName = new Map(areas.map((area) => [area.id, area.name]));
  const filteredEvents = raw.events.filter((event) => matchesArea(event.life_area_id, selectedAreaId));
  const tasks = raw.tasks.filter((task) => matchesArea(task.life_area_id, selectedAreaId));
  const notes = raw.notes.filter((note) => matchesArea(note.life_area_id, selectedAreaId));
  const roadmaps = raw.roadmaps.filter((roadmap) => matchesArea(roadmap.life_area_id, selectedAreaId));

  const habitDone = raw.habitLogs.filter((log) => (log.status ?? "done") === "done").length;
  const previousHabitDone = raw.previousHabitLogs.filter((log) => (log.status ?? "done") === "done").length;
  const taskDone = tasks.filter((task) => task.status === "done" && inRange(task.completed_at ?? task.processed_at, bounds.fromIso, bounds.toIso)).length;
  const taskMissed = tasks.filter((task) => task.status === "missed" && inRange(task.missed_at ?? task.processed_at, bounds.fromIso, bounds.toIso)).length;
  const notesCaptured = notes.filter((note) => inRange(note.created_at, bounds.fromIso, bounds.toIso)).length;
  const notesProcessed = notes.filter((note) => note.status !== "captured" && inRange(note.processed_at, bounds.fromIso, bounds.toIso)).length;

  const calendarDays = buildCalendarDays(raw, range, tasks, notes);
  const roadmapHealth = buildRoadmapHealth(raw, roadmaps, areaName);
  const areaHealth = buildAreaHealth(raw, areaName, tasks, notes, roadmapHealth, selectedAreaId);
  const gymCorrelation = buildGymCorrelation(calendarDays);
  const scores = buildScores({
    habitDone,
    previousHabitDone,
    taskDone,
    taskMissed,
    notesCaptured,
    notesProcessed,
    workoutDays: raw.workoutLogs.length,
    previousWorkoutDays: raw.previousWorkoutLogs.length,
    roadmapHealth
  });
  const scoreSeries = calendarDays.map((day) => ({
    date: day.date,
    label: formatShortDate(day.date),
    score: day.score,
    execution: clamp(day.tasksDone * 30 - day.tasksMissed * 25 + 50),
    mentalLoad: clamp(100 - day.notes * 12)
  }));
  const insights = buildInsights({
    scores,
    areaHealth,
    calendarDays,
    gymCorrelation,
    roadmapHealth,
    notesCaptured,
    notesProcessed,
    taskDone,
    taskMissed
  });
  const diagnosis = buildDiagnosis(scores, insights, areaHealth);

  return {
    areas,
    diagnosis,
    scores,
    insights,
    areaHealth,
    calendarDays,
    scoreSeries,
    gymCorrelation,
    roadmapHealth,
    recentEvents: filteredEvents.slice(0, 12),
    warnings: raw.warnings
  };
}

function buildScores(input: {
  habitDone: number;
  previousHabitDone: number;
  taskDone: number;
  taskMissed: number;
  notesCaptured: number;
  notesProcessed: number;
  workoutDays: number;
  previousWorkoutDays: number;
  roadmapHealth: RoadmapHealth[];
}): ScoreBreakdown {
  const consistency = clamp(45 + input.habitDone * 4 + input.workoutDays * 6 - Math.max(0, input.previousHabitDone - input.habitDone) * 3);
  const taskTotal = input.taskDone + input.taskMissed;
  const execution = taskTotal ? clamp((input.taskDone / taskTotal) * 100) : 50;
  const mentalLoad = input.notesCaptured
    ? clamp(70 + (input.notesProcessed / Math.max(1, input.notesCaptured)) * 30 - Math.max(0, input.notesCaptured - input.notesProcessed) * 5)
    : 75;
  const roadmapsWithTasks = input.roadmapHealth.filter((roadmap) => roadmap.totalTasks > 0);
  const progress = roadmapsWithTasks.length
    ? clamp(roadmapsWithTasks.reduce((sum, roadmap) => sum + roadmap.progress, 0) / roadmapsWithTasks.length)
    : 50;
  const overall = clamp(consistency * 0.3 + execution * 0.3 + mentalLoad * 0.2 + progress * 0.2);

  return {
    overall,
    consistency,
    execution,
    mentalLoad,
    progress,
    explanation: [
      { label: "Consistencia", value: consistency, detail: "Habitos cumplidos y entrenamientos del periodo." },
      { label: "Ejecucion", value: execution, detail: "Tareas hechas frente a tareas no hechas." },
      { label: "Carga mental", value: mentalLoad, detail: "Notas capturadas y procesadas sin quedarse como ruido." },
      { label: "Progreso real", value: progress, detail: "Avance promedio de tareas en roadmaps." }
    ]
  };
}

function buildCalendarDays(raw: RawAnalyticsData, range: DateRange, tasks: RawAnalyticsData["tasks"], notes: RawAnalyticsData["notes"]): CalendarDay[] {
  const workoutDays = new Set(raw.workoutLogs.map((log) => dayKey(log.date)));
  const habitCount = new Map<string, number>();
  const taskDoneCount = new Map<string, number>();
  const taskMissedCount = new Map<string, number>();
  const noteCount = new Map<string, number>();

  for (const log of raw.habitLogs) {
    const key = dayKey(log.target_date ?? log.completed_date);
    habitCount.set(key, (habitCount.get(key) ?? 0) + 1);
  }
  for (const task of tasks) {
    if (task.status === "done" && (task.completed_at ?? task.processed_at)) {
      const key = dayKey(task.completed_at ?? task.processed_at ?? "");
      taskDoneCount.set(key, (taskDoneCount.get(key) ?? 0) + 1);
    }
    if (task.status === "missed" && (task.missed_at ?? task.processed_at)) {
      const key = dayKey(task.missed_at ?? task.processed_at ?? "");
      taskMissedCount.set(key, (taskMissedCount.get(key) ?? 0) + 1);
    }
  }
  for (const note of notes) {
    const key = dayKey(note.created_at);
    noteCount.set(key, (noteCount.get(key) ?? 0) + 1);
  }

  return eachDay(range).map((date) => {
    const habits = habitCount.get(date) ?? 0;
    const tasksDone = taskDoneCount.get(date) ?? 0;
    const tasksMissed = taskMissedCount.get(date) ?? 0;
    const notesForDay = noteCount.get(date) ?? 0;
    const workouts = workoutDays.has(date) ? 1 : 0;
    const score = clamp(45 + habits * 12 + tasksDone * 14 + workouts * 16 - tasksMissed * 22 - Math.max(0, notesForDay - 3) * 8);
    const status: CalendarDay["status"] =
      habits + tasksDone + tasksMissed + notesForDay + workouts === 0
        ? "empty"
        : score >= 72
          ? "good"
          : score >= 45
            ? "mixed"
            : "friction";

    return {
      date,
      label: formatShortDate(date),
      status,
      score,
      habits,
      tasksDone,
      tasksMissed,
      notes: notesForDay,
      workouts
    };
  });
}

function buildAreaHealth(
  raw: RawAnalyticsData,
  areaName: Map<string, string>,
  tasks: RawAnalyticsData["tasks"],
  notes: RawAnalyticsData["notes"],
  roadmapHealth: RoadmapHealth[],
  selectedAreaId: string | "all"
): AreaHealth[] {
  const ids = new Set<string | null>(raw.areas.map((area) => area.id));
  ids.add(null);
  if (selectedAreaId !== "all") {
    ids.clear();
    ids.add(selectedAreaId);
  }

  return Array.from(ids).map((id) => {
    const areaTasks = tasks.filter((task) => (id ? task.life_area_id === id : !task.life_area_id));
    const areaNotes = notes.filter((note) => (id ? note.life_area_id === id : !note.life_area_id));
    const areaRoadmaps = roadmapHealth.filter((roadmap) => roadmap.areaName === (id ? areaName.get(id) : "Sin area"));
    const done = areaTasks.filter((task) => task.status === "done").length;
    const missed = areaTasks.filter((task) => task.status === "missed").length;
    const action = done + missed;
    const mentalLoad = areaNotes.length;
    const progress = areaRoadmaps.length
      ? Math.round(areaRoadmaps.reduce((sum, roadmap) => sum + roadmap.progress, 0) / areaRoadmaps.length)
      : 0;
    const friction = missed * 2 + Math.max(0, mentalLoad - done);
    const score = clamp(50 + done * 8 + progress * 0.35 - missed * 12 - Math.max(0, mentalLoad - done) * 5);

    return {
      id,
      name: id ? areaName.get(id) ?? "Sin nombre" : "Sin area",
      action,
      mentalLoad,
      progress,
      friction,
      score
    };
  }).sort((a, b) => b.score - a.score);
}

function buildRoadmapHealth(raw: RawAnalyticsData, roadmaps: RawAnalyticsData["roadmaps"], areaName: Map<string, string>): RoadmapHealth[] {
  const milestonesByRoadmap = new Map<string, string[]>();
  for (const milestone of raw.milestones) {
    const list = milestonesByRoadmap.get(milestone.roadmap_id) ?? [];
    list.push(milestone.id);
    milestonesByRoadmap.set(milestone.roadmap_id, list);
  }

  return roadmaps.map((roadmap) => {
    const milestoneIds = new Set(milestonesByRoadmap.get(roadmap.id) ?? []);
    const tasks = raw.milestoneTasks.filter((task) => milestoneIds.has(task.milestone_id));
    const completed = tasks.filter((task) => task.is_completed || task.status === "done");
    const lastProgress = completed
      .map((task) => task.completed_at)
      .filter(Boolean)
      .sort()
      .at(-1);
    const daysSinceLastProgress = lastProgress
      ? Math.floor((Date.now() - new Date(lastProgress).getTime()) / 86_400_000)
      : null;
    const progress = tasks.length ? clamp((completed.length / tasks.length) * 100) : 0;

    return {
      id: roadmap.id,
      title: roadmap.title,
      areaName: roadmap.life_area_id ? areaName.get(roadmap.life_area_id) ?? "Sin nombre" : "Sin area",
      progress,
      completedTasks: completed.length,
      totalTasks: tasks.length,
      daysSinceLastProgress,
      status: tasks.length === 0 ? "sin tareas" : daysSinceLastProgress === null || daysSinceLastProgress > 14 ? "estancado" : "activo"
    };
  });
}

function buildGymCorrelation(days: CalendarDay[]): GymCorrelation {
  const workoutDays = days.filter((day) => day.workouts > 0);
  const restDays = days.filter((day) => day.workouts === 0 && day.status !== "empty");
  const avg = (items: CalendarDay[], key: "tasksDone" | "habits") =>
    items.length ? items.reduce((sum, item) => sum + item[key], 0) / items.length : 0;
  const taskDoneOnWorkoutDays = avg(workoutDays, "tasksDone");
  const taskDoneOnRestDays = avg(restDays, "tasksDone");
  const habitDoneOnWorkoutDays = avg(workoutDays, "habits");
  const habitDoneOnRestDays = avg(restDays, "habits");
  const delta = taskDoneOnWorkoutDays - taskDoneOnRestDays;

  return {
    workoutDays: workoutDays.length,
    restDays: restDays.length,
    taskDoneOnWorkoutDays,
    taskDoneOnRestDays,
    habitDoneOnWorkoutDays,
    habitDoneOnRestDays,
    message:
      workoutDays.length < 2 || restDays.length < 2
        ? "Aun no hay suficientes dias con y sin gym para comparar con confianza."
        : delta > 0.3
          ? "Tus dias con gym tienden a cerrar mas tareas."
          : delta < -0.3
            ? "Tus dias con gym estan cerrando menos tareas; revisa carga o horario."
            : "Gym y ejecucion estan parejos por ahora."
  };
}
