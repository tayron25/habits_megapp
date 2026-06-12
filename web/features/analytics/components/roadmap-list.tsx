import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { RoadmapHealth } from "@/features/analytics/types";
import { EmptyState } from "@/features/analytics/components/state-card";

export function RoadmapList({ roadmaps }: { roadmaps: RoadmapHealth[] }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Roadmaps: progreso real</CardTitle>
      </CardHeader>
      <CardContent>
        {roadmaps.length ? (
          <div className="space-y-3">
            {roadmaps.slice(0, 8).map((roadmap) => (
              <div className="rounded-md border bg-background/50 p-3" key={roadmap.id}>
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="truncate text-sm font-medium">{roadmap.title}</p>
                    <p className="text-xs text-muted-foreground">
                      {roadmap.areaName} · {roadmap.completedTasks}/{roadmap.totalTasks} tareas
                    </p>
                  </div>
                  <Badge>{roadmap.status}</Badge>
                </div>
                <div className="mt-3 h-2 overflow-hidden rounded-full bg-muted">
                  <div className="h-full rounded-full bg-primary" style={{ width: `${roadmap.progress}%` }} />
                </div>
                <p className="mt-2 text-xs text-muted-foreground">
                  {roadmap.daysSinceLastProgress === null
                    ? "Sin avance registrado."
                    : `${roadmap.daysSinceLastProgress} días desde el último avance.`}
                </p>
              </div>
            ))}
          </div>
        ) : (
          <EmptyState text="No hay roadmaps para este filtro." />
        )}
      </CardContent>
    </Card>
  );
}
