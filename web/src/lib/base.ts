/**
 * The site may be served under a path prefix (`DOCS_BASE=/docs`).
 * Routes inside the code stay root-relative (`/en/use`); they gain the prefix only where
 * they are written into a page or followed by the browser.
 */
export const BASE = import.meta.env.BASE_URL.replace(/\/+$/, "");

/** Prefix a root-relative path with the base. Anything else (`#x`, `https://…`) is returned as is. */
export function withBase(path: string): string {
  return path.startsWith("/") && !path.startsWith("//") ? `${BASE}${path}` : path;
}

/** The route of a served pathname: the pathname without the base. */
export function stripBase(pathname: string): string {
  if (!BASE || !pathname.startsWith(BASE)) return pathname;
  const rest = pathname.slice(BASE.length);
  return rest === "" ? "/" : rest.startsWith("/") ? rest : pathname;
}
