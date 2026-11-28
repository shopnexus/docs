// The placeholder syntax of the registry's prose, shared by trace and the
// docs site, with no dependency so the site can import it (values.ts).

export const PLACEHOLDER = /\{([a-z][a-z0-9/]*)\.([A-Za-z_][\w.()[\]]*)(?:\|([\w%]+))?\}/g;

export interface Text {
  vi: string;
  en: string;
}

/** Replaces each placeholder in s by its value in lang; unknown gets one without a value. */
export function fill(s: string, values: Record<string, Text>, lang: keyof Text, unknown: (key: string) => string = (k) => `{${k}}`): string {
  return s.replace(PLACEHOLDER, (m) => {
    const key = m.slice(1, -1);
    return values[key]?.[lang] ?? unknown(key);
  });
}
