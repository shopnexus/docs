# Convention Typst cho báo cáo ShopNexus

Tham chiếu chi tiết để viết/sửa chương đúng quy ước repo `typst/`. Đọc khi cần ví dụ cụ thể.
Tổng quan cấu trúc: `typst/README.md`.

## Template & cấu trúc chương

- Template áp dụng **một lần** ở `main.typ` của từng báo cáo. Chương **không** áp dụng lại.
  - Quyển nộp trường (định kỳ, cuối): `#show: quyen.with(...)` từ `common/style-quyen.typ`.
  - Tài liệu A4 (báo cáo tuần, spec): `#show: a4.with(...)` từ `common/style-a4.typ`.
- Mỗi file chương mở đầu bằng đúng một dòng import:
  ```typst
  #import "../../common/tokens.typ": *
  ```
  `tokens.typ` đã re-export `fletcher` (`diagram`, `node`, `edge`) và các shape, nên
  **không** import `@preview/fletcher` lần nữa trong chương.
- Không định nghĩa lại design token trong file chương — đó là lỗi cũ đã dọn, đừng tái lập.

## Thông tin nhóm/đề tài

Lấy từ `common/info.typ` (`de-tai`, `gvhd`, `lop`, `nhom`, `sinh-vien`, …).
Không gõ cứng tên người, MSSV, tên đề tài vào nội dung báo cáo.

## Heading

- Tự động đánh số. **Không** tự gõ số vào tiêu đề.
  - Quyển: level 1 = `CHƯƠNG n:` (canh giữa, tự sang trang), level 2 = `n.m`, level 3 = `n.m.k`.
  - A4: level 1 gạch chân, level 2/3 = `1.1.`, `1.1.1.`.
- Mục không đánh số (Mở đầu, Kết luận, Lời cảm ơn…): dùng `sechead([TÊN MỤC])`,
  thêm `outlined: false` nếu không muốn vào mục lục. Mục loại này **không** tự sang
  trang — tự thêm `#pagebreak()` trước nó.

## Sơ đồ

- Vẽ inline bằng `fletcher`, **luôn** bọc trong `fig()` để figure vào *Danh mục các hình*
  (`kind: image`, supplement `[Hình]`):
  ```typst
  #fig([Luồng gọi dịch vụ],
    np((0,0), [Client]),
    edge("->"),
    ncore((1,0), [Order Service]),
  )
  ```
  Node helper: `nt` (terminal/pill), `np` (process), `nd` (decision/diamond),
  `ng` (success), `nr` (reject, viền đứt), `ncore` (thành phần lõi), `nact` (actor).
- Ảnh giao diện: `#mockup("checkout", width: 90%)` — tự trỏ vào `common/assets/mockups/`.
- Ảnh khác: `#image("../../common/assets/er-order.png", width: 80%)`.
- Đừng dùng `figure` trần cho sơ đồ — sẽ lệch khỏi danh mục hình.

## Bảng

- Bảng có style toàn cục (header nền xám nhạt, kẻ mảnh). Dùng `table.header(...)`
  cho hàng tiêu đề để lặp lại khi bảng qua trang.
- Muốn bảng vào *Danh mục các bảng*: bọc trong `#figure(kind: table, caption: [...])[...]`.

## Code block

- Dùng fenced block thường; template đã style raw block (nền xám, viền mảnh):
  ````typst
  ```go
  type Saga struct { /* ... */ }
  ```
  ````
- Không tự style raw block.

## Màu sắc

- Bảng màu **đơn sắc là chủ ý** (báo cáo in đen trắng). Dùng token trong `common/tokens.typ`:
  `ink`, `muted`, `hairline`, `headfill`, `soft`, và các tên giữ theo màu gốc
  (`blue`, `teal`, `amber`, `green`, `red` + biến thể `-l`, `-s`) đều ánh xạ về thang xám.
- **Không** hardcode mã màu mới.

## Trích dẫn

- Thêm entry vào `common/refs.bib` (BibTeX) theo style hiện có (key dạng `tác-giả + năm`,
  ví dụ `richardson2019`).
- Trích dẫn trong văn bản bằng `@key`. Danh mục render bằng
  `#bibliography("../common/refs.bib", title: none, full: true, style: "ieee")`
  ở cuối `main.typ`.

## Văn phong

- Tiếng Việt, giữ dấu đầy đủ (`lang: "vi"`).
- Học thuật, súc tích; ưu tiên bảng + gạch đầu dòng cho so sánh/liệt kê.
- Thuật ngữ kỹ thuật giữ nguyên tiếng Anh khi phổ biến (`saga`, `compensating action`,
  `CQRS`), có giải thích lần đầu.

## Biên dịch

```bash
cd typst
make              # danh sách lệnh
make cuoi         # báo cáo cuối
make dinh-ky      # 2 bản định kỳ
make tuan         # 3 báo cáo tuần
make all
make watch SRC=bao-cao-cuoi/main.typ    # xem trực tiếp khi sửa
```

Đừng gọi `typst compile` trần: mọi tài liệu import từ `common/` nên bắt buộc
`--root .`, và font quyển nằm trong `common/fonts` nên cần `--font-path`.
Makefile đã lo cả hai.

Font hệ thống cần có: TeX Gyre Termes, TeX Gyre Heros, DejaVu Sans Mono.
Gói `fletcher` tự tải lần đầu.
