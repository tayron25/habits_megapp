import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { GymCorrelation } from "@/features/analytics/types";

export function GymLifeCard({ correlation }: { correlation: GymCorrelation }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Gym + Vida</CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-sm text-muted-foreground">{correlation.message}</p>
        <div className="mt-4 grid gap-3 sm:grid-cols-2">
          <Metric label="Días con gym" value={correlation.workoutDays} />
          <Metric label="Días sin gym medibles" value={correlation.restDays} />
          <Metric label="Tareas/día con gym" value={correlation.taskDoneOnWorkoutDays.toFixed(1)} />
          <Metric label="Tareas/día sin gym" value={correlation.taskDoneOnRestDays.toFixed(1)} />
          <Metric label="Hábitos/día con gym" value={correlation.habitDoneOnWorkoutDays.toFixed(1)} />
          <Metric label="Hábitos/día sin gym" value={correlation.habitDoneOnRestDays.toFixed(1)} />
        </div>
      </CardContent>
    </Card>
  );
}

function Metric({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-md border bg-background/50 p-3">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="mt-1 text-2xl font-semibold">{value}</p>
    </div>
  );
}
