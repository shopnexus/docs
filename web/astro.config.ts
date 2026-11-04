import { rehypeHeadingIds } from "@astrojs/markdown-remark";
import mdx from "@astrojs/mdx";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig, envField } from "astro/config";
import icon from "astro-icon";
import { rehypeAssetFormat } from "./src/lib/markdown/rehype-asset-format";
import { rehypeBaseLinks } from "./src/lib/markdown/rehype-base-links";
import { rehypeHeadingAnchors } from "./src/lib/markdown/rehype-heading-anchors";
import { rehypeTableWrap } from "./src/lib/markdown/rehype-table-wrap";
import { remarkMermaid } from "./src/lib/markdown/remark-mermaid";
import { codeFrameTransformer } from "./src/lib/markdown/shiki-code-frame";

// `DOCS_BASE=/docs` serves the site under a path prefix, as a portal deployment does.
const base = process.env.DOCS_BASE || "/";

export default defineConfig({
  base,
  trailingSlash: "ignore",
  env: {
    schema: {
      // `DOCS_INTERNAL=true` adds the internal tabs (Developers, Delivery) and internal pages.
      DOCS_INTERNAL: envField.boolean({ context: "server", access: "public", default: false }),
    },
  },
  build: { format: "directory" },
  i18n: {
    locales: ["en", "vi"],
    defaultLocale: "en",
    routing: { prefixDefaultLocale: true, redirectToDefaultLocale: false },
  },
  integrations: [mdx(), icon({ iconDir: "src/icons" })],
  markdown: {
    remarkPlugins: [remarkMermaid],
    shikiConfig: {
      themes: { light: "github-light", dark: "github-dark-dimmed" },
      defaultColor: false,
      wrap: false,
      transformers: [codeFrameTransformer()],
    },
    rehypePlugins: [
      rehypeHeadingIds,
      rehypeHeadingAnchors,
      rehypeAssetFormat,
      rehypeTableWrap,
      [rehypeBaseLinks, { base }],
    ],
  },
  vite: {
    plugins: [tailwindcss()],
    // Mermaid is one large chunk, loaded only on pages that have a diagram.
    build: { chunkSizeWarningLimit: 3000 },
  },
});
