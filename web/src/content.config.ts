import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

export const AUDIENCES = ["everyone", "users", "admins", "developers"] as const;

export const PAGE_TYPES = ["tutorial", "how-to", "concept", "reference", "overview"] as const;

const docs = defineCollection({
  loader: glob({
    pattern: "**/*.mdx",
    base: "./src/content/docs",
    // Keep the file path as the id ("en/use/knowledge/index" → "en/use/knowledge").
    generateId: ({ entry }) => entry.replace(/\.mdx$/, "").replace(/\/index$/, ""),
  }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    group: z.string(),
    order: z.number(),
    groupOrder: z.number(),
    audience: z.array(z.enum(AUDIENCES)).min(1),
    type: z.enum(PAGE_TYPES),
    readingTime: z.number(),
    updated: z.coerce.date(),
    internal: z.boolean().default(false),
    related: z.array(z.string()).optional(),
    toc: z.boolean().default(true),
  }),
});

export const collections = { docs };
