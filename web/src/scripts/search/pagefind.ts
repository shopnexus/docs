import { withBase } from "../../lib/base";

/** Minimal typing of the Pagefind JS API (https://pagefind.app/docs/api/). */
export interface PagefindSubResult {
  title: string;
  url: string;
  excerpt: string;
}

export interface PagefindData {
  url: string;
  excerpt: string;
  meta: Record<string, string>;
  filters: Record<string, string[]>;
  sub_results: PagefindSubResult[];
}

interface PagefindApi {
  options(opts: Record<string, unknown>): Promise<void>;
  init(): Promise<void>;
  search(query: string): Promise<{ results: { data(): Promise<PagefindData> }[] }>;
}

let loading: Promise<PagefindApi | null> | undefined;

/** Load /pagefind/pagefind.js on first use. Resolves null when the index has not been built. */
export function loadPagefind(): Promise<PagefindApi | null> {
  loading ??= (async () => {
    try {
      // Runtime-only module: pagefind.js is generated into dist/ after `astro build`.
      const url = withBase("/pagefind/pagefind.js");
      const api = (await import(/* @vite-ignore */ url)) as PagefindApi;
      // Main-thread mode: Pagefind 1.5's shared worker can stall the first query after
      // client-side navigations; the index is small enough that a worker buys nothing.
      // Result URLs stay site routes (`/en/…`); links add the base where they are rendered.
      await api.options({ excerptLength: 18, noWorker: true, baseUrl: "/" });
      await api.init();
      return api;
    } catch {
      loading = undefined;
      return null;
    }
  })();
  return loading;
}

/** Run a query and load the data of the best `limit` pages. */
export async function searchPages(api: PagefindApi, query: string, limit = 40): Promise<PagefindData[]> {
  const { results } = await api.search(query);
  return Promise.all(results.slice(0, limit).map((r) => r.data()));
}
