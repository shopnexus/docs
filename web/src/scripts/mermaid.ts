/**
 * Renders ```mermaid figures (see src/lib/markdown/remark-mermaid.ts). Mermaid is loaded
 * only on pages that have a diagram, and every diagram is drawn again when the theme flips,
 * because Mermaid bakes its colours into the SVG.
 */
type Mermaid = typeof import("mermaid").default;

// The prebuilt bundle carries its own copy of langium's dependencies. The package entry
// would resolve them from node_modules, where @astrojs/check hoists an incompatible
// vscode-jsonrpc.
const load = () =>
  // @ts-expect-error the bundle ships no type declarations; the type comes from the package entry
  import("mermaid/dist/mermaid.esm.min.mjs").then((m: { default: Mermaid }) => m.default);

let mermaid: Promise<Mermaid> | undefined;
let run = 0;

function token(style: CSSStyleDeclaration, name: string): string {
  return style.getPropertyValue(name).trim();
}

function themeVariables() {
  const s = getComputedStyle(document.documentElement);
  const node = token(s, "--diagram-node");
  const line = token(s, "--diagram-line");
  const text = token(s, "--diagram-text");
  const edge = token(s, "--diagram-edge");
  const store = token(s, "--diagram-store");
  return {
    fontFamily: '"Inter Variable", ui-sans-serif, system-ui, sans-serif',
    fontSize: "14px",
    background: "transparent",
    primaryColor: node,
    primaryBorderColor: line,
    primaryTextColor: text,
    secondaryColor: store,
    secondaryBorderColor: line,
    secondaryTextColor: text,
    tertiaryColor: node,
    tertiaryBorderColor: line,
    tertiaryTextColor: text,
    lineColor: edge,
    textColor: text,
    mainBkg: node,
    nodeBorder: line,
    clusterBkg: store,
    clusterBorder: line,
    edgeLabelBackground: token(s, "--bg-page"),
    actorBkg: node,
    actorBorder: line,
    actorTextColor: text,
    actorLineColor: edge,
    signalColor: text,
    signalTextColor: text,
    labelBoxBkgColor: node,
    labelBoxBorderColor: line,
    labelTextColor: text,
    loopTextColor: text,
    noteBkgColor: store,
    noteBorderColor: line,
    noteTextColor: text,
    activationBkgColor: store,
    activationBorderColor: line,
    sequenceNumberColor: token(s, "--on-brand"),
  };
}

async function renderAll() {
  const figures = [...document.querySelectorAll<HTMLElement>("[data-diagram]")];
  if (figures.length === 0) return;
  mermaid ??= load();
  const m = await mermaid;
  const pass = ++run;
  m.initialize({
    startOnLoad: false,
    theme: "base",
    themeVariables: themeVariables(),
    securityLevel: "strict",
    flowchart: { curve: "basis", padding: 14, nodeSpacing: 36, rankSpacing: 44, htmlLabels: true },
    sequence: { actorMargin: 56, boxMargin: 8, mirrorActors: false, showSequenceNumbers: true },
  });
  for (const [i, figure] of figures.entries()) {
    const source = figure.querySelector<HTMLElement>("[data-diagram-src]")?.textContent ?? "";
    try {
      const { svg } = await m.render(`diagram-${pass}-${i}`, source);
      if (pass !== run) return;
      let canvas = figure.querySelector<HTMLElement>(".diagram-canvas");
      if (!canvas) {
        canvas = document.createElement("div");
        canvas.className = "diagram-canvas";
        figure.prepend(canvas);
      }
      canvas.innerHTML = svg;
      figure.dataset.rendered = "";
    } catch (error) {
      console.error("diagram failed to render", error);
    }
  }
}

new MutationObserver(() => void renderAll()).observe(document.documentElement, {
  attributes: true,
  attributeFilter: ["data-theme"],
});

export function initDiagrams() {
  void renderAll();
}
