"use client";

import { Area, AreaChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/features/analytics/components/state-card";

export function ScoreChart({ data }: { data: Array<{ label: string; score: number; execution: number; mentalLoad: number }> }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Línea semanal de score</CardTitle>
      </CardHeader>
      <CardContent className="h-80">
        {data.some((item) => item.score > 0) ? (
          <ResponsiveContainer height="100%" width="100%">
            <AreaChart data={data}>
              <CartesianGrid stroke="rgba(255,255,255,0.08)" vertical={false} />
              <XAxis dataKey="label" stroke="rgba(255,255,255,0.45)" tickLine={false} />
              <YAxis domain={[0, 100]} stroke="rgba(255,255,255,0.45)" tickLine={false} />
              <Tooltip contentStyle={{ background: "#111827", border: "1px solid #273244", borderRadius: 8 }} />
              <Area dataKey="score" fill="#22c55e" fillOpacity={0.3} name="Score" stroke="#22c55e" />
              <Area dataKey="execution" fill="#60a5fa" fillOpacity={0.18} name="Ejecución" stroke="#60a5fa" />
              <Area dataKey="mentalLoad" fill="#fbbf24" fillOpacity={0.14} name="Carga mental" stroke="#fbbf24" />
            </AreaChart>
          </ResponsiveContainer>
        ) : (
          <EmptyState text="Aún no hay serie suficiente para graficar." />
        )}
      </CardContent>
    </Card>
  );
}
