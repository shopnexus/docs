import type { Element, Root } from "hast";
import { visit } from "unist-util-visit";

/**
 * Wrap markdown tables in a scroll container. The frame and the scrolling live on the
 * wrapper, so the table itself keeps `display: table` and fills the column width.
 */
export function rehypeTableWrap() {
  return (tree: Root) => {
    visit(tree, "element", (node: Element, index, parent) => {
      if (node.tagName !== "table" || !parent || index === undefined) return;
      if (
        parent.type === "element" &&
        parent.tagName === "div" &&
        parent.properties.className?.toString().includes("table-wrap")
      )
        return;
      parent.children[index] = {
        type: "element",
        tagName: "div",
        properties: { className: ["table-wrap"] },
        children: [node],
      };
    });
  };
}
