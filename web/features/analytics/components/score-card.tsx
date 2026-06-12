import { Card, CardContent } from "@/components/ui/card";
import type { ScoreBreakdown } from "@/features/analytics/types";

export function ScoreCard({ scores }: { scores: ScoreBreakdown }) {
  return (
    <Card className="overflow-hidden border-primary/30 bg-primary/5">
      <CardContent className="p-5">
        <div className="flex flex-col gap-5 lg:flex-row lg:items-center">
          <div className="flex items-center gap-5">
            <div className="grid h-28 w-28 place-items-center rounded-full border-8 border-primary/30 bg-background">
              <div className="text-center">
                <p className="text-4xl font-semibold text-primary">{scores.overall}</p>
                <p className="text-xs text-muted-foreground">/100</p>
              </div>
            </div>
            <div>
              <p className="text-sm text-primary">Score general</p>
              <h2 className="mt-1 text-2xl font-semibold">Diagnóstico explicable</h2>
              <p className="mt-2 max-w-xl text-sm text-muted-foreground">
                Promedio ponderado de consistencia, ejecución, carga mental y progreso real.
              </p>
            </div>
          </div>
          <div className="grid flex-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
            {scores.explanation.map((item) => (
              <div className="rounded-md border bg-background/60 p-3" key={item.label}>
                <div className="flex items-center justify-between gap-2">
                  <p className="text-sm font-medium">{item.label}</p>
                  <span className="text-sm text-primary">{item.value}</span>
                </div>
                <div className="mt-2 h-2 overflow-hidden rounded-full bg-muted">
                  <div className="h-full rounded-full bg-primary" style={{ width: `${item.value}%` }} />
                </div>
                <p className="mt-2 text-xs text-muted-foreground">{item.detail}</p>
              </div>
            ))}
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
