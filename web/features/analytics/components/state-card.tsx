import { Card, CardContent } from "@/components/ui/card";

export function StateCard({
  title,
  body,
  details,
  tone
}: {
  title: string;
  body: string;
  details?: string[];
  tone?: "error";
}) {
  return (
    <Card className={tone === "error" ? "border-destructive/50" : undefined}>
      <CardContent className="pt-4">
        <p className="font-medium">{title}</p>
        <p className="mt-1 text-sm text-muted-foreground">{body}</p>
        {details?.length ? (
          <ul className="mt-3 space-y-1 text-xs text-muted-foreground">
            {details.slice(0, 6).map((detail) => (
              <li key={detail}>{detail}</li>
            ))}
          </ul>
        ) : null}
      </CardContent>
    </Card>
  );
}

export function EmptyState({ text }: { text: string }) {
  return <div className="flex h-full min-h-24 items-center justify-center text-center text-sm text-muted-foreground">{text}</div>;
}
