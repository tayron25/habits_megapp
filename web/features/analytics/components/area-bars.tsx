"use client";

import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { AreaHealth } from "@/features/analytics/types";
import { EmptyState } from "@/features/analytics/components/state-card";

export function AreaBars({ areas }: { areas: AreaHealth[] }) {
  const data = areas.filter((area) => area.action + area.mentalLoad + area.progress > 0).slice(0, 8);

  return (
    <Card>
      <CardHeader>
        <CardTitle>Mapa de áreas de vida</CardTitle>
      </CardHeader>
      <CardContent className="h-80">
        {data.length ? (
          <ResponsiveContainer height="100%" width="100%">
            <BarChart data={data} layout="vertical" margin={{ left: 12 }}>
              <CartesianGrid stroke="rgba(255,255,255,0.08)" horizontal={false} />
              <XAxis allowDecimals={false} stroke="rgba(255,255,255,0.45)" type="number" />
              <YAxis dataKey="name" stroke="rgba(255,255,255,0.45)" type="category" width={96} />
              <Tooltip contentStyle={{ background: "#111827", border: "1px solid #273244", borderRadius: 8 }} />
              <Bar dataKey="action" fill="#22c55e" name="Acción" radius={[0, 4, 4, 0]} />
              <Bar dataKey="mentalLoad" fill="#fbbf24" name="Carga mental" radius={[0, 4, 4, 0]} />
              <Bar dataKey="friction" fill="#ef4444" name="Fricción" radius={[0, 4, 4, 0]} />
            </BarChart>
          </ResponsiveContainer>
        ) : (
          <EmptyState text="Aún no hay datos suficientes por área." />
        )}
      </CardContent>
    </Card>
  );
}
