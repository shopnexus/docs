import type { Element, Root } from "hast";
import { visit } from "unist-util-visit";
import { iconSvg } from "./icon-paths";

/** Append a hover "#" link to every h2/h3 that has an id (ids come from rehypeHeadingIds). */
export function rehypeHeadingAnchors() {
  return (tree: Root) => {
    visit(tree, "element", (node: Element) => {
      if (node.tagName !== "h2" && node.tagName !== "h3") return;
      const id = node.properties.id;
      if (typeof id !== "string") return;
      node.properties.className = ["heading", ...asList(node.properties.className)];
      node.children.push({
        type: "element",
        tagName: "a",
        properties: {
          className: ["heading-anchor"],
          href: `#${id}`,
          "aria-label": "Link to this section",
          "data-pagefind-ignore": "",
        },
        children: [iconSvg("link", node.tagName === "h2" ? 18 : 16)],
      });
    });
  };
}

function asList(value: unknown): string[] {
  if (Array.isArray(value)) return value.map(String);
  return typeof value === "string" ? value.split(/\s+/) : [];
}
