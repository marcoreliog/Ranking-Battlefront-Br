import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
export async function createClient() {
  const cookieStore = await cookies();
  return createServerClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!, { cookies: { getAll: () => cookieStore.getAll(), setAll: (items) => { try { items.forEach(({ name, value, options }) => cookieStore.set(name, value, options)); } catch { /* refreshed by proxy */ } } } });
}
export async function getCurrentProfile() {
  const supabase = await createClient(); const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;
  const { data } = await supabase.from("profiles").select("id, username, display_name, gamertag, public_slug, avatar_url, bio, role").eq("id", user.id).single();
  return data;
}
