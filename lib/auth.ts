/** Supabase password auth requires an e-mail identifier. This is an internal,
 * non-deliverable identifier; users only ever provide a username. */
export const INTERNAL_AUTH_DOMAIN = "users.battlefrontbr.invalid";
export function usernameToInternalEmail(username: string) {
  return `${username.trim().toLowerCase()}@${INTERNAL_AUTH_DOMAIN}`;
}
