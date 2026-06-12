import { AlertTriangle, CheckCircle2, Info } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import type { Insight } from "@/features/analytics/types";

export function InsightCard({ insight, label }: { insight: Insight; label?: string }) {
  const Icon = insight.kind === "positive" ? CheckCircle2 : insight.kind === "negative" ? AlertTriangle : Info;
  const color =
    insight.kind === "positive"
      ? "border-primary/30 bg-primary/5 text-primary"
      : insight.kind === "negative"
        ? "border-destructive/40 bg-destructive/10 text-red-300"
        : "border-border bg-card text-muted-foreground";

  return (
    <Card className={color}>
      <CardContent className="p-4">
        <div className="flex items-start gap-3">
          <Icon className="mt-0.5 h-5 w-5 shrink-0" />
          <div className="min-w-0">
            {label ? <p className="text-xs uppercase tracking-wide text-muted-foreground">{label}</p> : null}
            <h3 className="mt-1 text-base font-semibold text-foreground">{insight.title}</h3>
            <p className="mt-2 text-sm text-muted-foreground">{insight.body}</p>
            <p className="mt-3 text-sm">
              <span className="font-medium text-foreground">Evidencia:</span>{" "}
              <span className="text-muted-foreground">{insight.evidence}</span>
            </p>
            <p className="mt-1 text-sm">
              <span className="font-medium text-foreground">Acción:</span>{" "}
              <span className="text-muted-foreground">{insight.action}</span>
            </p>
            <Badge className="mt-3">confianza {insight.confidence}</Badge>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
