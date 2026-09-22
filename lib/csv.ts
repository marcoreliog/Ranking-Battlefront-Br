import { playerSchema } from "@/lib/validators";
export type CsvRow = { gamertag: string; display_name: string; bio: string };
export type CsvIssue = { line: number; error: string };
export function parsePlayersCsv(input: string): { rows: CsvRow[]; issues: CsvIssue[] } {
  const lines = input.replace(/^\uFEFF/, "").split(/\r?\n/).filter((line) => line.trim());
  const rows: CsvRow[] = []; const issues: CsvIssue[] = [];
  const start = lines[0]?.toLowerCase().replace(/\s/g, "") === "gamertag;display_name;bio" ? 1 : 0;
  if (lines.length - start > 100) return { rows, issues: [{ line: 0, error: "Máximo de 100 jogadores por importação" }] };
  for (let i = start; i < lines.length; i++) {
    const fields = lines[i].split(";");
    if (fields.length !== 3) { issues.push({ line: i + 1, error: "Esperadas 3 colunas separadas por ponto e vírgula" }); continue; }
    const row = { gamertag: fields[0].trim(), display_name: fields[1].trim(), bio: fields[2].trim() };
    if (!playerSchema.safeParse({ gamertag: row.gamertag, displayName: row.display_name || undefined, bio: row.bio || undefined }).success) issues.push({ line: i + 1, error: "Dados inválidos" }); else rows.push(row);
  }
  return { rows, issues };
}
