import { type Lang, SITE_NAME } from "../../lib/i18n";

interface PathCard {
  /** Page the card opens (path without the language prefix). */
  href: string;
  /** Illustration on the card. */
  img: string;
  title: string;
  body: string;
  cta: string;
  /** Only shown in an internal build (links into an internal tab). */
  internal?: boolean;
}

interface HomeStrings {
  badge: string;
  title: string;
  lead: string;
  popularLabel: string;
  startTitle: string;
  startLead: string;
  paths: PathCard[];
  popularTitle: string;
  popularLead: string;
  browseTitle: string;
  browseLead: (n: number) => string;
  recentTitle: string;
  recentLead: string;
  updatedBadge: string;
  stuckTitle: string;
  stuckBody: string;
  stuckCta: string;
  footerGlossary: string;
  footerTroubleshooting: string;
  footerAdmin: string;
}

/** Curated starting points; entries whose page does not exist are skipped at build time. */
export const POPULAR = [
  { href: "/marketplace", icon: "ri:store-2-line" },
  { href: "/marketplace/cod-deal", icon: "ri:truck-line" },
  { href: "/marketplace/trust-and-sanctions", icon: "ri:shield-check-line" },
  { href: "/architecture", icon: "ri:node-tree" },
  { href: "/architecture/durable-flows", icon: "ri:loop-left-line" },
  { href: "/api", icon: "ri:braces-line" },
];

export const QUICK_CHIPS = ["/marketplace/cod-deal", "/architecture", "/get-started/quick-start"];

export const HOME_STRINGS: Record<Lang, HomeStrings> = {
  en: {
    badge: `${SITE_NAME} developer docs`,
    title: `How ${SITE_NAME} works, from listing to doorstep.`,
    lead: "A second-hand marketplace where buyers check the item at the door before they pay. How it works, and how it is built.",
    popularLabel: "Popular:",
    startTitle: "Start here",
    startLead: "Pick the path that matches what you came to do.",
    paths: [
      {
        href: "/get-started/quick-start",
        img: "/img/sec-start.webp",
        title: "I'm new here",
        body: "Run the docs and the platform on your machine.",
        cta: "Quick start",
      },
      {
        href: "/marketplace",
        img: "/img/sec-guides.webp",
        title: "I want the big picture",
        body: "Listings, COD with inspection and how trust replaces a judge.",
        cta: "Read the model",
      },
      {
        href: "/architecture",
        img: "/img/sec-reference.webp",
        title: "I work on the backend",
        body: "Modules, durable flows and the features built on them.",
        cta: "Read the architecture",
      },
      {
        href: "/api",
        img: "/img/sec-developers.webp",
        title: "I build a client",
        body: "Sign-in, errors, paging and live updates.",
        cta: "Open the API",
      },
    ],
    popularTitle: "Good places to start",
    popularLead: "Pages that make the rest of the docs easier to read.",
    browseTitle: "Browse the docs",
    browseLead: (n) => `${n} sections, from the marketplace rules down to deployment.`,
    recentTitle: "Recently updated",
    recentLead: "Pages changed most recently, newest first.",
    updatedBadge: "Updated",
    stuckTitle: "Stuck on something?",
    stuckBody: "Common problems when running the stack or calling the API.",
    stuckCta: "Open troubleshooting",
    footerGlossary: "Glossary",
    footerTroubleshooting: "Troubleshooting",
    footerAdmin: "Contact your administrator",
  },
  vi: {
    badge: `Tài liệu kỹ thuật ${SITE_NAME}`,
    title: `${SITE_NAME} vận hành ra sao, từ tin đăng tới tận cửa.`,
    lead: "Sàn đồ cũ nơi người mua xem hàng tại cửa rồi mới trả tiền. Sàn vận hành ra sao và được xây thế nào.",
    popularLabel: "Phổ biến:",
    startTitle: "Bắt đầu từ đây",
    startLead: "Chọn lối đi đúng với việc bạn cần làm.",
    paths: [
      {
        href: "/get-started/quick-start",
        img: "/img/sec-start.webp",
        title: "Tôi mới đến",
        body: "Chạy tài liệu và nền tảng trên máy của bạn.",
        cta: "Bắt đầu nhanh",
      },
      {
        href: "/marketplace",
        img: "/img/sec-guides.webp",
        title: "Tôi muốn nhìn toàn cảnh",
        body: "Tin đăng, COD đồng kiểm và uy tín thay cho phân xử.",
        cta: "Đọc mô hình sàn",
      },
      {
        href: "/architecture",
        img: "/img/sec-reference.webp",
        title: "Tôi làm backend",
        body: "Các module, luồng bền vững và tính năng xây trên đó.",
        cta: "Đọc phần kiến trúc",
      },
      {
        href: "/api",
        img: "/img/sec-developers.webp",
        title: "Tôi viết client",
        body: "Đăng nhập, lỗi, phân trang và cập nhật trực tiếp.",
        cta: "Mở phần API",
      },
    ],
    popularTitle: "Nên đọc trước",
    popularLead: "Những trang giúp đọc phần còn lại dễ hơn.",
    browseTitle: "Khám phá tài liệu",
    browseLead: (n) => `${n} phần, từ luật của sàn tới triển khai.`,
    recentTitle: "Mới cập nhật",
    recentLead: "Các trang vừa thay đổi, mới nhất ở trên.",
    updatedBadge: "Cập nhật",
    stuckTitle: "Gặp khó khăn?",
    stuckBody: "Các lỗi hay gặp khi chạy hệ thống hoặc gọi API.",
    stuckCta: "Mở trang khắc phục sự cố",
    footerGlossary: "Thuật ngữ",
    footerTroubleshooting: "Khắc phục sự cố",
    footerAdmin: "Liên hệ quản trị viên",
  },
};
