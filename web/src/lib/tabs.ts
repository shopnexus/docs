import { DOCS_INTERNAL } from "astro:env/server";
import type { Lang } from "./i18n";

export type TabId = "get-started" | "marketplace" | "architecture" | "api" | "operations" | "developers";

export interface Tab {
  id: TabId;
  /** Section illustration under public/img/. */
  img: string;
  /** Remix icon used where an illustration is too large (search scopes). */
  icon: string;
  internal: boolean;
  label: Record<Lang, string>;
  blurb: Record<Lang, string>;
}

/** Internal tabs and internal pages exist only in a `DOCS_INTERNAL=true` build. */
export const INTERNAL_BUILD = DOCS_INTERNAL;

const ALL_TABS: Tab[] = [
  {
    id: "get-started",
    img: "/img/sec-start.webp",
    icon: "ri:flag-line",
    internal: false,
    label: { en: "Get started", vi: "Bắt đầu" },
    blurb: {
      en: "What ShopNexus is, how to run it and the words the docs use.",
      vi: "ShopNexus là gì, cách chạy nó và các từ tài liệu hay dùng.",
    },
  },
  {
    id: "marketplace",
    img: "/img/sec-guides.webp",
    icon: "ri:store-2-line",
    internal: false,
    label: { en: "Marketplace", vi: "Mô hình sàn" },
    blurb: {
      en: "How buying and selling work: listings, COD with inspection, trust.",
      vi: "Mua bán diễn ra thế nào: tin đăng, COD đồng kiểm, uy tín.",
    },
  },
  {
    id: "architecture",
    img: "/img/sec-reference.webp",
    icon: "ri:node-tree",
    internal: false,
    label: { en: "Architecture", vi: "Kiến trúc" },
    blurb: {
      en: "The backend's modules, durable flows and the features built on them.",
      vi: "Các module của backend, luồng bền vững và các tính năng xây trên đó.",
    },
  },
  {
    id: "api",
    img: "/img/sec-developers.webp",
    icon: "ri:braces-line",
    internal: false,
    label: { en: "API", vi: "API" },
    blurb: {
      en: "How clients talk to the server: sign-in, errors, paging, live updates.",
      vi: "Client nói chuyện với server thế nào: đăng nhập, lỗi, phân trang, cập nhật trực tiếp.",
    },
  },
  {
    id: "operations",
    img: "/img/docs-troubleshoot.webp",
    icon: "ri:rocket-2-line",
    internal: false,
    label: { en: "Operations", vi: "Vận hành" },
    blurb: {
      en: "Running, deploying and watching the system.",
      vi: "Chạy, triển khai và theo dõi hệ thống.",
    },
  },
  {
    id: "developers",
    img: "/img/sec-developers.webp",
    icon: "ri:code-s-slash-line",
    internal: true,
    label: { en: "Developers", vi: "Nhà phát triển" },
    blurb: {
      en: "Write and publish pages on this site.",
      vi: "Viết và xuất bản trang trên site này.",
    },
  },
];

export const TABS: Tab[] = ALL_TABS.filter((tab) => INTERNAL_BUILD || !tab.internal);

export function findTab(id: string): Tab | undefined {
  return TABS.find((tab) => tab.id === id);
}
