// ============================================================
//  de-xuat-de-tai.typ — bản nộp A4: bìa + mục lục + header/footer.
//  Nội dung nằm ở de-xuat-noi-dung.typ, dùng chung với idea.typ.
// ============================================================
#import "common/style-a4.typ": *
#show: a4.with(
  tieu-de: "ĐỀ XUẤT ĐỀ TÀI ĐỒ ÁN TỐT NGHIỆP",
  phu-de: "AGENT HỖ TRỢ TÌM KIẾM VÀ GỢI Ý SẢN PHẨM",
  chay: "Đề xuất đề tài đồ án tốt nghiệp",
  de-tai: "Agent hỗ trợ tìm kiếm và gợi ý sản phẩm trên sàn thương mại điện tử C2C",
)

// Template A4 bỏ số ở tiêu đề cấp 1, làm "3.1." trông như mất mục cha.
#show heading.where(level: 1): it => {
  set text(size: 14pt, weight: 800, font: font-head)
  block(above: 1.8em, below: 0.35em,
    grid(columns: (auto, 1fr), column-gutter: 9pt,
      counter(heading).display(), it.body))
  line(length: 100%, stroke: 1.2pt + ink)
  v(0.55em)
}

#include "de-xuat-noi-dung.typ"
