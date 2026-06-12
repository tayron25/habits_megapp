import type { AreaHealth, Diagnosis, GymCorrelation, Insight, RoadmapHealth, ScoreBreakdown, CalendarDay } from "@/features/analytics/types";

type InsightInput = {
  scores: ScoreBreakdown;
  areaHealth: AreaHealth[];
  calendarDays: CalendarDay[];
  gymCorrelation: GymCorrelation;
  roadmapHealth: RoadmapHealth[];
  notesCaptured: number;
  notesProcessed: number;
  taskDone: number;
  taskMissed: number;
};

const notEnoughData: Insight = {
  id: "not-enough-data",
  kind: "neutral",
  title: "Aun falta evidencia",
  body: "Todavia hay pocos datos para afirmar un patron con seguridad.",
  evidence: "Necesitamos mas dias con habitos, tareas, notas o entrenamientos.",
  action: "Sigue usando las apps esta semana y vuelve a revisar el diagnostico.",
  confidence: "baja"
};

export function buildInsights(input: InsightInput): Insight[] {
  const insights: Insight[] = [];
  const gymDelta = input.gymCorrelation.taskDoneOnWorkoutDays - input.gymCorrelation.taskDoneOnRestDays;
  const noisyDays = input.calendarDays.filter((day) => day.notes >= 4 && day.tasksMissed > 0);
  const weakDay = weakestWeekday(input.calendarDays);
  const strongDay = strongestWeekday(input.calendarDays);
  const frictionArea = input.areaHealth.filter((area) => area.action + area.mentalLoad > 0).sort((a, b) => b.friction - a.friction)[0];
  const bestArea = input.areaHealth.filter((area) => area.action + area.mentalLoad + area.progress > 0).sort((a, b) => b.score - a.score)[0];
  const stalledRoadmap = input.roadmapHealth
    .filter((roadmap) => roadmap.status === "estancado")
    .sort((a, b) => (b.daysSinceLastProgress ?? 999) - (a.daysSinceLastProgress ?? 999))[0];

  if (input.gymCorrelation.workoutDays >= 2 && input.gymCorrelation.restDays >= 2) {
    insights.push({
      id: "gym-correlation",
      kind: gymDelta >= 0 ? "positive" : "negative",
      title: gymDelta >= 0 ? "Entrenar parece ayudarte" : "Gym puede estar compitiendo con tu energia",
      body:
        gymDelta >= 0
          ? "Los dias con entrenamiento estan cerrando mas tareas que los dias sin entrenamiento."
          : "Los dias con entrenamiento estan cerrando menos tareas que tus dias sin gym.",
      evidence: `${input.gymCorrelation.taskDoneOnWorkoutDays.toFixed(1)} tareas/dia con gym vs ${input.gymCorrelation.taskDoneOnRestDays.toFixed(1)} sin gym.`,
      action: gymDelta >= 0 ? "Protege el horario de entrenamiento en dias importantes." : "Prueba bajar carga o mover el entrenamiento a otro horario.",
      confidence: Math.abs(gymDelta) > 0.8 ? "alta" : "media"
    });
  }

  if (noisyDays.length >= 2) {
    insights.push({
      id: "mental-load",
      kind: "negative",
      title: "Carga mental alta reduce ejecucion",
      body: "Varios dias mezclan muchas notas con tareas no hechas. Eso suele indicar ruido sin cierre.",
      evidence: `${noisyDays.length} dias tuvieron 4+ notas y al menos una tarea no hecha.`,
      action: "Procesa notas antes de abrir nuevas tareas; convierte solo una en siguiente accion.",
      confidence: noisyDays.length >= 4 ? "alta" : "media"
    });
  }

  if (frictionArea && frictionArea.friction >= 3) {
    insights.push({
      id: "area-friction",
      kind: "negative",
      title: `${frictionArea.name} esta generando friccion`,
      body: "Esta area concentra ruido mental o tareas no cerradas frente a poca accion efectiva.",
      evidence: `${frictionArea.mentalLoad} notas, ${frictionArea.action} acciones y friccion ${frictionArea.friction}.`,
      action: `Haz una limpieza de ${frictionArea.name}: elimina lo que no importa y deja una accion concreta.`,
      confidence: frictionArea.friction >= 6 ? "alta" : "media"
    });
  }

  if (stalledRoadmap) {
    insights.push({
      id: "roadmap-stalled",
      kind: "negative",
      title: "Hay un roadmap estancado",
      body: `${stalledRoadmap.title} no muestra avance reciente.`,
      evidence:
        stalledRoadmap.daysSinceLastProgress === null
          ? "No hay tareas completadas registradas."
          : `${stalledRoadmap.daysSinceLastProgress} dias desde el ultimo avance.`,
      action: "Define una accion pequena de 15 minutos o archiva el roadmap si ya no importa.",
      confidence: "media"
    });
  }

  if (bestArea && bestArea.score >= 65) {
    insights.push({
      id: "best-area",
      kind: "positive",
      title: `${bestArea.name} esta funcionando`,
      body: "Esta area combina mejor accion, progreso y baja friccion.",
      evidence: `Score ${bestArea.score}/100 con ${bestArea.action} acciones y progreso ${bestArea.progress}%.`,
      action: "Replica el mismo tipo de accion concreta en un area mas debil.",
      confidence: bestArea.score >= 78 ? "alta" : "media"
    });
  }

  if (strongDay && strongDay.score >= 70) {
    insights.push({
      id: "strong-weekday",
      kind: "positive",
      title: `${strongDay.label} es tu dia fuerte`,
      body: "Ese dia suele concentrar mejores cierres y menos friccion.",
      evidence: `Promedio ${strongDay.score}/100 en el periodo.`,
      action: "Agenda ahi las tareas que mas empujan tus metas.",
      confidence: strongDay.samples >= 2 ? "media" : "baja"
    });
  }

  if (weakDay && weakDay.score < 45) {
    insights.push({
      id: "weak-weekday",
      kind: "negative",
      title: `${weakDay.label} necesita menos carga`,
      body: "Ese dia aparece como punto bajo de ejecucion o consistencia.",
      evidence: `Promedio ${weakDay.score}/100 en el periodo.`,
      action: "Reduce compromisos ese dia o deja solo una accion esencial.",
      confidence: weakDay.samples >= 2 ? "media" : "baja"
    });
  }

  if (input.notesCaptured >= 3 && input.notesProcessed / Math.max(1, input.notesCaptured) >= 0.6) {
    insights.push({
      id: "notes-processed",
      kind: "positive",
      title: "Estas cerrando ruido mental",
      body: "Buena parte de tus notas ya se procesan en vez de quedarse abiertas.",
      evidence: `${input.notesProcessed}/${input.notesCaptured} notas procesadas.`,
      action: "Mantén la captura rapida, pero procesa en bloques cortos.",
      confidence: "media"
    });
  }

  if (input.taskMissed > input.taskDone && input.taskMissed >= 2) {
    insights.push({
      id: "execution-risk",
      kind: "negative",
      title: "La ejecucion esta perdiendo contra la carga",
      body: "Hay mas tareas no hechas que hechas en este periodo.",
      evidence: `${input.taskDone} hechas vs ${input.taskMissed} no hechas.`,
      action: "Baja el numero de tareas visibles y deja solo las que cambian el dia.",
      confidence: "alta"
    });
  }

  return insights.length ? insights : [notEnoughData];
}

export function buildDiagnosis(scores: ScoreBreakdown, insights: Insight[], areaHealth: AreaHealth[]): Diagnosis {
  const positive = insights.find((insight) => insight.kind === "positive") ?? notEnoughData;
  const negative = insights.find((insight) => insight.kind === "negative") ?? notEnoughData;
  const activeAreas = areaHealth.filter((area) => area.action + area.mentalLoad + area.progress > 0);
  const strongestArea = activeAreas[0] ?? null;
  const weakestArea = activeAreas.at(-1) ?? null;
  const recommendedFocus =
    negative.kind === "negative"
      ? negative.action
      : weakestArea
        ? `Dale una accion concreta a ${weakestArea.name}; esta es el area mas debil del periodo.`
        : "Sigue registrando datos esta semana para detectar patrones reales.";

  return {
    headline: scores.overall >= 75 ? "Semana fuerte" : scores.overall >= 55 ? "Semana mixta" : "Semana con friccion",
    summary:
      scores.overall >= 75
        ? "Hay buena senal de consistencia y ejecucion. Conviene repetir lo que ya esta funcionando."
        : scores.overall >= 55
          ? "Hay avance, pero tambien ruido. El foco es proteger lo que ayuda y recortar friccion."
          : "Los datos muestran friccion clara. La prioridad es simplificar y elegir una sola accion de alto impacto.",
    helpingPattern: positive,
    harmfulPattern: negative,
    strongestArea,
    weakestArea,
    recommendedFocus
  };
}

function strongestWeekday(days: CalendarDay[]) {
  return weekdayScore(days).sort((a, b) => b.score - a.score)[0] ?? null;
}

function weakestWeekday(days: CalendarDay[]) {
  return weekdayScore(days).filter((day) => day.samples > 0).sort((a, b) => a.score - b.score)[0] ?? null;
}

function weekdayScore(days: CalendarDay[]) {
  const formatter = new Intl.DateTimeFormat("es", { weekday: "long" });
  const map = new Map<string, { label: string; total: number; samples: number }>();

  for (const day of days) {
    if (day.status === "empty") continue;
    const label = formatter.format(new Date(`${day.date}T00:00:00`));
    const item = map.get(label) ?? { label, total: 0, samples: 0 };
    item.total += day.score;
    item.samples += 1;
    map.set(label, item);
  }

  return Array.from(map.values()).map((item) => ({
    label: item.label,
    samples: item.samples,
    score: Math.round(item.total / Math.max(1, item.samples))
  }));
}
