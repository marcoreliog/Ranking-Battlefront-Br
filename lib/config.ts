export const MIN_RATINGS_PER_MODE = Number.parseInt(process.env.MIN_RATINGS_PER_MODE ?? "3", 10) || 3;
export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000";
export const MODES = [
  { value: "galactic_assault", label: "Assalto Galáctico" },
  { value: "heroes_vs_villains", label: "Heróis vs. Vilões" },
  { value: "hero_showdown", label: "Confronto Heroico" },
] as const;
export type GameMode = (typeof MODES)[number]["value"];
