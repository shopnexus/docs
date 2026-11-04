import type { Element, Root } from "hast";
import { visit } from "unist-util-visit";

/**
 * Prefix the root-relative links and images of markdown content with the site base, so
 * content keeps writing `/en/use` and `/shots/home.png` whatever path the site is served under.
 * MDX components (`<Card href>`, `<Shot src>`) prefix their own props.
 */
export function rehypeBaseLinks({ base }: { base: string }) {
  const prefix = base.replace(/\/+$/, "");
  return (tree: Root) => {
    if (!prefix) return;
    visit(tree, "element", (node: Element) => {
      const key = node.tagName === "a" ? "href" : node.tagName === "img" ? "src" : undefined;
      if (!key) return;
      const value = node.properties[key];
      if (typeof value === "string" && value.startsWith("/") && !value.startsWith("//")) {
        node.properties[key] = `${prefix}${value}`;
      }
    });
  };
}
