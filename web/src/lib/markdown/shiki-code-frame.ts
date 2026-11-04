import type { Element, ElementContent } from "hast";
import type { ShikiTransformer } from "shiki";
import { iconSvg } from "./icon-paths";

const TITLE = /title=(?:"([^"]*)"|'([^']*)')/;

/**
 * Wrap every fenced code block in a frame with an optional title (```bash title="Terminal")
 * and a copy button. The copy behaviour lives in `src/scripts/code-copy.ts`.
 */
export function codeFrameTransformer(): ShikiTransformer {
  return {
    name: "docs-code-frame",
    root(root) {
      const raw = (this.options.meta as { __raw?: string } | undefined)?.__raw ?? "";
      const match = TITLE.exec(raw);
      const title = match ? (match[1] ?? match[2]) : undefined;
      const pre = root.children.find((child): child is Element => child.type === "element");
      if (!pre) return;

      const copy: Element = {
        type: "element",
        tagName: "button",
        properties: {
          type: "button",
          className: ["code-copy"],
          "aria-label": "Copy code",
          "data-copy-code": "",
        },
        children: [iconSvg("copy", 15, "i-copy"), iconSvg("check", 15, "i-check")],
      };
      const head: ElementContent[] = title
        ? [
            {
              type: "element",
              tagName: "div",
              properties: { className: ["code-head"] },
              children: [
                {
                  type: "element",
                  tagName: "span",
                  properties: { className: ["code-title"] },
                  children: [{ type: "text", value: title }],
                },
                copy,
              ],
            },
          ]
        : [copy];

      root.children = [
        {
          type: "element",
          tagName: "div",
          properties: {
            className: ["code-block", title ? "has-title" : "no-title"],
            "data-lang": this.options.lang,
          },
          children: [...head, pre],
        },
      ];
    },
  };
}
