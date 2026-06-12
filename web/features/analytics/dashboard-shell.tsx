"use client";

import { useEffect, useState } from "react";
import { Activity, BarChart3, CalendarDays, Dumbbell, Map, Target, TrendingUp } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { AreaBars } from "@/features/analytics/components/area-bars";
import { CalendarHeatmap } from "@/features/analytics/components/calendar-heatmap";
import { GymLifeCard } from "@/features/analytics/components/gym-life-card";
import { InsightCard } from "@/features/analytics/components/insight-card";
import { RoadmapList } from "@/features/analytics/components/roadmap-list";
import { ScoreCard } from "@/features/analytics/components/score-card";
import { ScoreChart } from "@/features/analytics/components/score-chart";
import { EmptyState, StateCard } from "@/features/analytics/components/state-card";
import type { DashboardData } from "@/features/analytics/types";
import { buildDashboardModel } from "@/features/analytics/model";
import { defaultRange, type DateRange, type RangePreset } from "@/lib/date/ranges";
import { fetchRawAnalyticsData } from "@/lib/queries/analytics";
import { createClient } from "@/lib/supabase/client";

const presetOptions: Array<{ value: RangePreset; label: string }> = [
  { value: "7d", label: "7 dias" },
  { value: "30d", label: "30 dias" },
  { value: "90d", label: "90 dias" },
  { value: "custom", label: "Personalizado" }
];

const sections = [
  { id: "diagnostico", label: "Diagnóstico", icon: Activity },
  { id: "areas", label: "Áreas", icon: Map },
  { id: "patrones", label: "Patrones", icon: TrendingUp },
  { id: "calendario", label: "Calendario", icon: CalendarDays },
  { id: "gym", label: "Gym + Vida", icon: Dumbbell },
  { id: "roadmaps", label: "Roadmaps", icon: Target }
];

export function DashboardShell() {
  const [range, setRange] = useState<DateRange>(() => defaultRange(30));
  const [areaId, setAreaId] = useState<string | "all">("all");
  const [data, setData] = useState<DashboardData | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let isMounted = true;

    async function load() {
      setIsLoading(true);
      setError(null);
      const supabase = createClient();
      const raw = await fetchRawAnalyticsData(supabase, range);
      const result = buildDashboardModel(raw, range, areaId);
      if (!isMounted) return;
      setData(result);
      setIsLoading(false);
    }

    load().catch((loadError: unknown) => {
      if (!isMounted) return;
      setError(loadError instanceof Error ? loadError.message : "No se pudo cargar el diagnostico.");
      setIsLoading(false);
    });

    return () => {
      isMounted = false;
    };
  }, [range, areaId]);

  function updatePreset(value: RangePreset) {
    if (value === "custom") {
      setRange((current) => ({ ...current, preset: "custom" }));
      return;
    }
    const days = value === "7d" ? 7 : value === "90d" ? 90 : 30;
    setRange(defaultRange(days));
  }

  const positiveInsights = data?.insights.filter((insight) => insight.kind === "positive") ?? [];
  const negativeInsights = data?.insights.filter((insight) => insight.kind === "negative") ?? [];
  const neutralInsights = data?.insights.filter((insight) => insight.kind === "neutral") ?? [];

  return (
    <div className="space-y-6">
      <section className="rounded-lg border bg-card/70 p-4">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p className="text-sm text-primary">Diagnóstico personal</p>
            <h2 className="mt-1 text-2xl font-semibold">Qué patrones te ayudan y cuáles te frenan</h2>
            <p className="mt-1 max-w-3xl text-sm text-muted-foreground">
              La web interpreta tus datos de Life OS y Gym para encontrar señales accionables. No edita nada: solo lee Supabase con tu sesión.
            </p>
          </div>
          <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
            <Select value={range.preset} onChange={(event) => updatePreset(event.target.value as RangePreset)}>
              {presetOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </Select>
            <Input
              disabled={range.preset !== "custom"}
              onChange={(event) => setRange((current) => ({ ...current, from: event.target.value, preset: "custom" }))}
              type="date"
              value={range.from}
            />
            <Input
              disabled={range.preset !== "custom"}
              onChange={(event) => setRange((current) => ({ ...current, to: event.target.value, preset: "custom" }))}
              type="date"
              value={range.to}
            />
            <Select value={areaId} onChange={(event) => setAreaId(event.target.value)}>
              <option value="all">Todas las areas</option>
              {data?.areas.map((area) => (
                <option key={area.id} value={area.id}>
                  {area.icon ? `${area.icon} ` : ""}
                  {area.name}
                </option>
              ))}
            </Select>
          </div>
        </div>
        <nav className="mt-4 flex gap-2 overflow-x-auto pb-1">
          {sections.map((section) => {
            const Icon = section.icon;
            return (
              <a
                className="inline-flex shrink-0 items-center gap-2 rounded-md border bg-background/60 px-3 py-2 text-sm text-muted-foreground transition hover:text-foreground"
                href={`#${section.id}`}
                key={section.id}
              >
                <Icon className="h-4 w-4" />
                {section.label}
              </a>
            );
          })}
        </nav>
      </section>

      {error ? <StateCard title="No se pudo cargar" body={error} tone="error" /> : null}
      {isLoading ? <StateCard title="Cargando diagnóstico" body="Leyendo Supabase y calculando patrones..." /> : null}

      {data && !isLoading ? (
        <>
          {data.warnings.length ? (
            <StateCard
              title="Datos parciales"
              body="Algunas tablas o columnas no respondieron. El diagnóstico evita conclusiones con datos incompletos."
              details={data.warnings}
            />
          ) : null}

          <section className="space-y-4" id="diagnostico">
            <ScoreCard scores={data.scores} />
            <div className="grid gap-4 xl:grid-cols-[1.2fr_0.8fr]">
              <Card>
                <CardContent className="p-5">
                  <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                    <div>
                      <Badge>Diagnóstico semanal</Badge>
                      <h3 className="mt-3 text-2xl font-semibold">{data.diagnosis.headline}</h3>
                      <p className="mt-2 max-w-2xl text-sm text-muted-foreground">{data.diagnosis.summary}</p>
                    </div>
                    <div className="rounded-md border bg-background/60 p-4 lg:max-w-sm">
                      <p className="text-sm font-medium text-primary">Foco recomendado</p>
                      <p className="mt-2 text-sm text-muted-foreground">{data.diagnosis.recommendedFocus}</p>
                    </div>
                  </div>
                  <div className="mt-5 grid gap-3 md:grid-cols-2">
                    <InsightCard insight={data.diagnosis.helpingPattern} label="Patrón que ayuda" />
                    <InsightCard insight={data.diagnosis.harmfulPattern} label="Patrón que perjudica" />
                  </div>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <CardTitle>Áreas clave</CardTitle>
                </CardHeader>
                <CardContent className="space-y-3">
                  <AreaSummary label="Más fuerte" area={data.diagnosis.strongestArea} />
                  <AreaSummary label="Más descuidada" area={data.diagnosis.weakestArea} />
                </CardContent>
              </Card>
            </div>
            <ScoreChart data={data.scoreSeries} />
          </section>

          <section className="space-y-4" id="areas">
            <SectionTitle
              eyebrow="Balance"
              title="Áreas de vida"
              body="Compara acción, carga mental, progreso y fricción para ver dónde estás fuerte o bloqueado."
            />
            <AreaBars areas={data.areaHealth} />
            <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
              {data.areaHealth.slice(0, 6).map((area) => (
                <Card key={area.id ?? "none"}>
                  <CardContent className="p-4">
                    <div className="flex items-center justify-between gap-3">
                      <p className="font-medium">{area.name}</p>
                      <Badge>{area.score}/100</Badge>
                    </div>
                    <p className="mt-3 text-sm text-muted-foreground">
                      Acción {area.action} · Carga mental {area.mentalLoad} · Progreso {area.progress}% · Fricción {area.friction}
                    </p>
                  </CardContent>
                </Card>
              ))}
            </div>
          </section>

          <section className="space-y-4" id="patrones">
            <SectionTitle
              eyebrow="Insights"
              title="Patrones accionables"
              body="Cada patrón incluye evidencia y una acción concreta. Si no hay suficiente información, se muestra como baja confianza."
            />
            <div className="grid gap-4 lg:grid-cols-2">
              <div className="space-y-3">
                <h3 className="font-semibold text-primary">Lo que te ayuda</h3>
                {positiveInsights.length ? (
                  positiveInsights.map((insight) => <InsightCard insight={insight} key={insight.id} />)
                ) : (
                  <EmptyState text="Aún no hay patrones positivos claros." />
                )}
              </div>
              <div className="space-y-3">
                <h3 className="font-semibold text-red-300">Lo que te perjudica</h3>
                {negativeInsights.length ? (
                  negativeInsights.map((insight) => <InsightCard insight={insight} key={insight.id} />)
                ) : (
                  <EmptyState text="Aún no hay patrones perjudiciales claros." />
                )}
              </div>
            </div>
            {neutralInsights.length ? (
              <div className="grid gap-3 lg:grid-cols-2">
                {neutralInsights.map((insight) => (
                  <InsightCard insight={insight} key={insight.id} />
                ))}
              </div>
            ) : null}
          </section>

          <section className="space-y-4" id="calendario">
            <SectionTitle
              eyebrow="Ciclos"
              title="Calendario de comportamiento"
              body="Busca días buenos, mixtos o con fricción. La meta es ver patrones de semana, no culparte por un día aislado."
            />
            <CalendarHeatmap days={data.calendarDays} />
          </section>

          <section className="grid gap-4 xl:grid-cols-[0.9fr_1.1fr]" id="gym">
            <div>
              <SectionTitle
                eyebrow="Cruce"
                title="Gym + Vida"
                body="Compara días con entrenamiento contra días sin gym para entender si te da energía o compite con tus tareas."
              />
              <div className="mt-4">
                <GymLifeCard correlation={data.gymCorrelation} />
              </div>
            </div>
            <Card>
              <CardHeader>
                <CardTitle>Eventos relevantes</CardTitle>
              </CardHeader>
              <CardContent>
                {data.recentEvents.length ? (
                  <div className="space-y-3">
                    {data.recentEvents.map((event) => (
                      <div className="rounded-md border bg-background/50 p-3" key={event.id}>
                        <div className="flex items-center justify-between gap-3">
                          <p className="text-sm font-medium">{humanEvent(event.event_type)}</p>
                          <Badge>{event.source_app}</Badge>
                        </div>
                        <p className="mt-1 text-xs text-muted-foreground">
                          {new Intl.DateTimeFormat("es", { dateStyle: "medium", timeStyle: "short" }).format(new Date(event.occurred_at))}
                        </p>
                      </div>
                    ))}
                  </div>
                ) : (
                  <EmptyState text="Sin eventos relevantes para este filtro." />
                )}
              </CardContent>
            </Card>
          </section>

          <section className="space-y-4" id="roadmaps">
            <SectionTitle
              eyebrow="Metas largas"
              title="Roadmaps"
              body="Mide si tus metas están recibiendo acción real o si se están quedando congeladas."
            />
            <RoadmapList roadmaps={data.roadmapHealth} />
          </section>
        </>
      ) : null}
    </div>
  );
}

function SectionTitle({ eyebrow, title, body }: { eyebrow: string; title: string; body: string }) {
  return (
    <div>
      <p className="text-sm text-primary">{eyebrow}</p>
      <h2 className="mt-1 text-xl font-semibold">{title}</h2>
      <p className="mt-1 max-w-3xl text-sm text-muted-foreground">{body}</p>
    </div>
  );
}

function AreaSummary({ label, area }: { label: string; area: DashboardData["diagnosis"]["strongestArea"] }) {
  return (
    <div className="rounded-md border bg-background/50 p-3">
      <p className="text-xs text-muted-foreground">{label}</p>
      {area ? (
        <>
          <div className="mt-2 flex items-center justify-between gap-3">
            <p className="font-medium">{area.name}</p>
            <Badge>{area.score}/100</Badge>
          </div>
          <p className="mt-2 text-xs text-muted-foreground">
            Acción {area.action} · Carga mental {area.mentalLoad} · Fricción {area.friction}
          </p>
        </>
      ) : (
        <p className="mt-2 text-sm text-muted-foreground">Sin evidencia suficiente.</p>
      )}
    </div>
  );
}

function humanEvent(eventType: string) {
  const labels: Record<string, string> = {
    habit_completed: "Hábito completado",
    habit_uncompleted: "Hábito desmarcado",
    task_done: "Tarea hecha",
    task_missed: "Tarea no hecha",
    task_created: "Tarea creada",
    note_captured: "Nota capturada",
    note_categorized: "Nota categorizada",
    note_discarded: "Nota descartada",
    roadmap_task_completed: "Avance de roadmap",
    roadmap_task_reopened: "Tarea de roadmap reabierta",
    roadmap_created: "Roadmap creado"
  };

  return labels[eventType] ?? eventType.replaceAll("_", " ");
}
