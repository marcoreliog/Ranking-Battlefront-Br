import { cn } from "@/lib/utils"; import type { HTMLAttributes } from "react";
export function Card({ className, ...props }: HTMLAttributes<HTMLDivElement>) { return <div className={cn("rounded-xl border border-slate-800 bg-slate-900/70 p-5 shadow-[0_0_30px_rgba(34,211,238,.04)]", className)} {...props} />; }
