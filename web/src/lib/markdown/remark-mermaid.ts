import type { Code, Root } from "mdast";
import { visit } from "unist-util-visit";

const TITLE = /title=(?:"([^"]*)"|'([^']*)')/;

/**
 * Turn ```mermaid fences into a figure that `src/scripts/mermaid.ts` renders in the
 * browser. The source stays in a <pre> so the page reads as text before the script runs.
 */
export function remarkMermaid() {
  return (tree: Root) => {
    visit(tree, "code", (node: Code, index, parent) => {
      if (node.lang !== "mermaid" || !parent || index === undefined) return;
      const match = TITLE.exec(node.meta ?? "");
      const caption = match ? (match[1] ?? match[2]) : undefined;
      const children = [
        {
          type: "element",
          tagName: "pre",
          properties: { className: ["diagram-src"], "data-diagram-src": "" },
          children: [{ type: "text", value: node.value }],
        },
        ...(caption
          ? [{ type: "element", tagName: "figcaption", properties: {}, children: [{ type: "text", value: caption }] }]
          : []),
      ];
      parent.children[index] = {
        type: "paragraph",
        children: [],
        data: { hName: "figure", hProperties: { className: ["diagram"], "data-diagram": "" }, hChildren: children },
      } as never;
    });
  };
}
