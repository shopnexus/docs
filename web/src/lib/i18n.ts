export const LANGS = ["en", "vi"] as const;
export type Lang = (typeof LANGS)[number];

/** Product name shown in the top bar, page titles and footer. */
export const SITE_NAME = "ShopNexus";
export const SITE_TITLE = `${SITE_NAME} Docs`;

export const STRINGS = {
  en: {
    docs: "Docs",
    search: "Search docs…",
    searchHero: "Search listings, deals, modules and terms…",
    onThisPage: "On this page",
    related: "Related",
    helpful: "Was this page helpful?",
    yes: "Yes",
    no: "No",
    thanks: "Thanks — your answer is saved in this browser.",
    prev: "Previous",
    next: "Next",
    minRead: (n: number | string) => `${n} min read`,
    updated: (d: string) => `Updated ${d}`,
    copyPage: "Copy page",
    copied: "Copied",
    menu: "Menu",
    close: "Close",
    theme: "Theme",
    themeNames: { system: "System", light: "Light", dark: "Dark" },
    language: "Language",
    skip: "Skip to content",
    zoom: "Zoom",
    tapZoom: "Tap to zoom",
    fit: "Fit",
    actualSize: "Actual size",
    openGlossary: "Open in glossary",
    stepsProgress: (done: number | string, total: number | string) => `${done} of ${total} steps`,
    markDone: "Mark step as done",
    beforeStart: "Before you start",
    time: "Time",
    who: "Who can do this",
    keyRules: "Key rules",
    internalRibbon: "Internal — not published",
    untranslatedTitle: "This page isn’t translated yet — showing English",
    untranslatedBody: "A translation is being prepared. On-screen labels stay in English, as in the app.",
    untranslatedGlossary: "Look up Vietnamese terms",
    footerCopy: `© 2026 ${SITE_NAME}.`,
    glossary: "Glossary",
    troubleshooting: "Troubleshooting",
  },
  vi: {
    docs: "Docs",
    search: "Tìm trong tài liệu…",
    searchHero: "Tìm tin đăng, giao dịch, module và thuật ngữ…",
    onThisPage: "Trên trang này",
    related: "Liên quan",
    helpful: "Trang này có hữu ích không?",
    yes: "Có",
    no: "Không",
    thanks: "Cảm ơn bạn — câu trả lời được lưu trong trình duyệt này.",
    prev: "Trước",
    next: "Tiếp",
    minRead: (n: number | string) => `${n} phút đọc`,
    updated: (d: string) => `Cập nhật ${d}`,
    copyPage: "Sao chép trang",
    copied: "Đã sao chép",
    menu: "Menu",
    close: "Đóng",
    theme: "Giao diện",
    themeNames: { system: "Theo hệ thống", light: "Sáng", dark: "Tối" },
    language: "Ngôn ngữ",
    skip: "Bỏ qua đến nội dung",
    zoom: "Phóng to",
    tapZoom: "Chạm để phóng to",
    fit: "Vừa khung",
    actualSize: "Kích thước thật",
    openGlossary: "Mở trong Thuật ngữ",
    stepsProgress: (done: number | string, total: number | string) => `${done}/${total} bước`,
    markDone: "Đánh dấu đã xong",
    beforeStart: "Trước khi bắt đầu",
    time: "Thời gian",
    who: "Ai làm được",
    keyRules: "Quy tắc chính",
    internalRibbon: "Nội bộ — không công khai",
    untranslatedTitle: "Trang này chưa được dịch — đang hiển thị bản tiếng Anh",
    untranslatedBody:
      "Bản tiếng Việt đang được chuẩn bị. Các nhãn trên màn hình vẫn giữ tiếng Anh, giống trong ứng dụng.",
    untranslatedGlossary: "Tra thuật ngữ tiếng Việt",
    footerCopy: `© 2026 ${SITE_NAME}.`,
    glossary: "Thuật ngữ",
    troubleshooting: "Khắc phục sự cố",
  },
} satisfies Record<Lang, Record<string, unknown>>;

export const AUDIENCE_LABEL: Record<string, Record<Lang, string>> = {
  everyone: { en: "Everyone", vi: "Mọi người" },
  users: { en: "Users", vi: "Người dùng" },
  admins: { en: "Admins", vi: "Quản trị viên" },
  developers: { en: "Developers", vi: "Nhà phát triển" },
};

export const AUDIENCE_ICON: Record<string, string> = {
  everyone: "ri:user-line",
  users: "ri:user-line",
  admins: "ri:shield-user-line",
  developers: "ri:code-s-slash-line",
};

export const TYPE_LABEL: Record<string, Record<Lang, string>> = {
  tutorial: { en: "Tutorial", vi: "Hướng dẫn từng bước" },
  "how-to": { en: "How-to", vi: "Hướng dẫn" },
  concept: { en: "Concept", vi: "Khái niệm" },
  reference: { en: "Reference", vi: "Tham chiếu" },
  overview: { en: "Overview", vi: "Tổng quan" },
};

export const TYPE_ICON: Record<string, string> = {
  tutorial: "ri:graduation-cap-line",
  "how-to": "ri:guide-line",
  concept: "ri:lightbulb-line",
  reference: "ri:book-2-line",
  overview: "ri:compass-3-line",
};

const MONTHS_EN = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/** "12 Oct 2026" / "12 thg 10, 2026" (docs DS §9); `short` drops the year. */
export function formatDate(date: Date, lang: Lang, short = false): string {
  const d = date.getUTCDate();
  const m = date.getUTCMonth();
  const y = date.getUTCFullYear();
  if (lang === "vi") return short ? `${d} thg ${m + 1}` : `${d} thg ${m + 1}, ${y}`;
  return short ? `${d} ${MONTHS_EN[m]}` : `${d} ${MONTHS_EN[m]} ${y}`;
}
