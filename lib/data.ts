import { MIN_RATINGS_PER_MODE } from "@/lib/config"; import { createClient } from "@/lib/supabase/server";
export type RankingRow = { player_slug: string; gamertag: string; display_name: string | null; avatar_url: string | null; average_score: number; ratings_count: number; position: number | null; provisional: boolean; assault_average?: number; hvv_average?: number; showdown_average?: number };
export async function rpc<T>(name: string, args: Record<string, unknown>) { const supabase = await createClient(); const result = await (supabase.rpc as unknown as (n: string, a: Record<string, unknown>) => Promise<{ data: T; error: { message: string } | null }>)(name,args); if (result.error) throw new Error(result.error.message); return result.data; }
export async function generalRanking() { return rpc<RankingRow[]>("general_ranking", { p_min: MIN_RATINGS_PER_MODE }); }
export async function modeRanking(mode: string) { return rpc<RankingRow[]>("ranking_by_mode", { p_mode: mode, p_min: MIN_RATINGS_PER_MODE }); }
export async function heroRanking(slug: string) { return rpc<RankingRow[]>("hero_ranking", { p_hero_slug: slug, p_min: MIN_RATINGS_PER_MODE }); }
