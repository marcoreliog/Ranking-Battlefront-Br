import { z } from "zod";
import { isHalfStep } from "@/lib/rankings/calculations";

const slug = z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, "Use apenas letras minúsculas, números e hífens");
export const usernameSchema = z.string().trim().toLowerCase().regex(/^[a-z0-9](?:[a-z0-9_]{1,22}[a-z0-9])$/, "Use 3–24 letras, números ou _, começando e terminando em letra ou número");
export const scoreSchema = z.coerce.number().refine(isHalfStep, "A nota deve ser de 0,5 a 10, em intervalos de 0,5");
export const ratingSchema = z.object({ playerSlug: slug, mode: z.enum(["galactic_assault", "heroes_vs_villains", "hero_showdown"]), score: scoreSchema });
export const heroRatingSchema = z.object({ playerSlug: slug, heroSlug: slug, score: scoreSchema });
export const profileSchema = z.object({ displayName: z.string().trim().min(2).max(40), gamertag: z.string().trim().min(2).max(32), publicSlug: slug.max(50), avatarUrl: z.union([z.literal(""), z.string().url()]), bio: z.string().trim().max(280) });
export const favoritesSchema = z.object({ heroes: z.array(slug).length(4).refine((items) => new Set(items).size === 4, "Não repita personagens") });
export const playerSchema = z.object({ gamertag: z.string().trim().min(2).max(32), displayName: z.string().trim().max(40).optional(), bio: z.string().trim().max(500).optional(), isActive: z.boolean().default(true) });
export const heroSchema = z.object({ name: z.string().trim().min(2).max(60), description: z.string().trim().max(280), isActive: z.boolean() });
export type ProfileInput = z.infer<typeof profileSchema>;
