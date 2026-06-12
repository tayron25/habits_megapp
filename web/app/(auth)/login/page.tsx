import { LoginForm } from "@/features/auth/login-form";

export default function LoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center px-4 py-10">
      <div className="w-full max-w-md">
        <div className="mb-6 text-center">
          <p className="text-sm text-primary">Life OS Ecosystem</p>
          <h1 className="mt-2 text-3xl font-semibold">Dashboard analítico</h1>
          <p className="mt-2 text-sm text-muted-foreground">
            Entra con tu cuenta Supabase para ver solo tus datos.
          </p>
        </div>
        <LoginForm />
      </div>
    </main>
  );
}
