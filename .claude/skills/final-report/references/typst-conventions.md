# Convention Typst cho báo cáo cuối ShopNexus

Tham chiếu chi tiết để viết/sửa chương đúng quy ước repo `typst/`. Đọc khi cần ví dụ cụ thể.

## Theme & cấu trúc chương

- Theme áp dụng **một lần** ở `main.typ` bằng `#show: report-theme`. Chương **không** áp dụng lại theme.
- Mỗi file chương tự `#import` thứ cần dùng ở đầu file. Mẫu chuẩn (theo các chương hiện có):
  ```typst
  #import "../lib/theme.typ": diag, c-primary, c-soft, c-mid, c-line
  #import "@preview/fletcher:0.5.7" as fletcher: diagram, node, edge
  #import fletcher.shapes: pill
  ```
- Chỉ import token màu/helper thực sự dùng trong chương đó.

## Heading

- Tự động đánh số: level 1 = `I.`, sâu hơn = `1.1.1.`. **Không** tự gõ số vào tiêu đề.
- Level-1 (`= TIÊU ĐỀ`) tự sang trang mới và canh giữa, in hoa.
- Dùng `=`, `==`, `===` cho 3 cấp.

## Sơ đồ (diagram)

- Vẽ inline bằng `fletcher`, **luôn** bọc trong helper `diag()` để figure vào "Danh mục hình" (kind `"diagram"`, supplement `[Hình]`):
  ```typst
  #diag(
    diagram(
      node((0,0), [Client]),
      edge("->"),
      node((1,0), [Service]),
    ),
    caption: [Luồng gọi dịch vụ],
  )
  ```
- Ảnh xuất sẵn: đặt file vào `typst/assets/`, chèn:
  ```typst
  #diag(image("assets/er-order.png", width: 80%), caption: [ERD module order])
  ```
- Đừng dùng `figure` trần cho sơ đồ — sẽ lệch khỏi danh mục hình.

## Code block

- Dùng fenced block thường, codly đã cấu hình toàn cục (số dòng, nền xám):
  ````typst
  ```go
  type Saga struct { /* ... */ }
  ```
  ````
- Không tự style raw block; theme lo phần đó.

## Màu sắc & bảng

- Dùng token có sẵn: `c-primary` (#1a1a1a), `c-accent` (#444), `c-soft` (#f0f0f0 — nền nhạt), `c-mid` (#ddd), `c-line` (#999). **Không** hardcode mã màu mới.
- Bảng đã có style toàn cục (header nền xám đậm, viền `c-line`). Dùng `table.header(...)` cho hàng tiêu đề.

## Trích dẫn

- Thêm entry vào `refs.bib` (BibTeX) theo style hiện có (key dạng `tác-giả + năm`, ví dụ `richardson2019`).
- Trích dẫn trong văn bản bằng `@key`. Chương 13 (`13-tai-lieu-tham-khao.typ`) render danh mục.

## Văn phong

- Tiếng Việt, giữ dấu đầy đủ (`lang: "vi"`).
- Học thuật, súc tích; ưu tiên bảng + gạch đầu dòng cho so sánh/liệt kê.
- Thuật ngữ kỹ thuật giữ nguyên tiếng Anh khi phổ biến (`saga`, `compensating action`, `CQRS`), có giải thích lần đầu.

## Biên dịch

```bash
cd typst
typst compile main.typ main.pdf      # bản đầy đủ
typst watch  main.typ main.pdf       # xem trực tiếp khi sửa
```
Cần font hệ thống: TeX Gyre Termes, TeX Gyre Heros, DejaVu Sans Mono. Gói `codly`, `fletcher` tự tải lần đầu.
