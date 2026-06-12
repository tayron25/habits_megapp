import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { CalendarDay } from "@/features/analytics/types";

const statusClass = {
  good: "bg-primary text-primary-foreground",
  mixed: "bg-yellow-400/80 text-yellow-950",
  friction: "bg-destructive/80 text-white",
  empty: "bg-muted text-muted-foreground"
};

export function CalendarHeatmap({ days }: { days: CalendarDay[] }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Calendario de comportamiento</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-7 gap-2">
          {days.map((day) => (
            <div
              className={`min-h-20 rounded-md p-2 ${statusClass[day.status]}`}
              key={day.date}
              title={`${day.date}: score ${day.score}`}
            >
              <p className="text-xs font-medium">{day.label}</p>
              <p className="mt-1 text-lg font-semibold">{day.status === "empty" ? "-" : day.score}</p>
              <p className="mt-1 text-[10px] opacity-80">
                H{day.habits} T{day.tasksDone}/{day.tasksMissed} N{day.notes} G{day.workouts}
              </p>
            </div>
          ))}
        </div>
        <p className="mt-3 text-xs text-muted-foreground">
          Verde: buen dia. Amarillo: mixto. Rojo: fricción. Gris: sin datos.
        </p>
      </CardContent>
    </Card>
  );
}
