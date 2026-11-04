import type { Element, Root } from "hast";
import { visit } from "unist-util-visit";

/** Lazy-load markdown images. */
export function rehypeAssetFormat() {
  return (tree: Root) => {
    visit(tree, "element", (node: Element) => {
      if (node.tagName !== "img" || typeof node.properties.src !== "string") return;
      node.properties.loading ??= "lazy";
      node.properties.decoding ??= "async";
    });
  };
}
