import type { GlossaryCategory } from "../../data/glossary";
import type { Lang } from "../../lib/i18n";

interface GlossaryStrings {
  filter: string;
  all: string;
  category: string;
  show: string;
  oneLang: string;
  bothLangs: string;
  term: string;
  meaning: string;
  otherLang: string;
  count: string;
  seeAlso: string;
  none: string;
  categories: Record<GlossaryCategory, string>;
}

export const GLOSSARY_STRINGS: Record<Lang, GlossaryStrings> = {
  en: {
    filter: "Filter terms…",
    all: "All",
    category: "Category",
    show: "Show",
    oneLang: "English",
    bothLangs: "English + Tiếng Việt",
    term: "Term",
    meaning: "What it means",
    otherLang: "Tiếng Việt",
    count: "{n} terms",
    seeAlso: "See also",
    none: "No terms match. Try fewer letters.",
    categories: {
      marketplace: "Marketplace",
      architecture: "Architecture",
      api: "API & integration",
    },
  },
  vi: {
    filter: "Lọc thuật ngữ…",
    all: "Tất cả",
    category: "Nhóm",
    show: "Hiển thị",
    oneLang: "Tiếng Việt",
    bothLangs: "Tiếng Việt + English",
    term: "Thuật ngữ",
    meaning: "Nghĩa là gì",
    otherLang: "English",
    count: "{n} thuật ngữ",
    seeAlso: "Xem thêm",
    none: "Không có thuật ngữ phù hợp. Hãy thử ít chữ hơn.",
    categories: {
      marketplace: "Mô hình sàn",
      architecture: "Kiến trúc",
      api: "API & tích hợp",
    },
  },
};
