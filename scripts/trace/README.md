# trace

`trace` giữ code, test, đặc tả API của server và tài liệu khớp với
`registry/requirements.yaml`, nơi duy nhất định nghĩa mã UC, FR, BR, NFR và
ADR. Chạy từ repo gốc `shopnexus`, nơi có đủ submodule `docs` và `server`:

```sh
make trace                                         # kiểm tra, ghi registry/trace.json và web/public/openapi.json
make trace-rename FROM=UC-DEAL-02 TO=UC-DEAL-07    # đổi một mã ở mọi nơi
make trace-rename FROM_WAS=1                       # thay mọi mã cũ ghi trong `was`
cd docs/scripts/trace && bun test                  # test của chính công cụ
```

`openapi` gom `server/api/openapi.yaml` và các file nó tham chiếu thành
`web/public/openapi.json` cho trang Playground. Schema, response và parameter
giữ tên dưới `components`; tên trùng giữa hai file được thêm tên file phía
trước (`ChatQuote`, `ShippingQuote`); file `paths/` được chép thẳng vào.

## Lỗi (thoát 1)

- Mã trong code, test, `x-uc` của OpenAPI, Typst hay trang MDX không có trong registry.
- Mã cũ còn được dùng (mã nằm trong `was` của một mục).
- Mã của mục đã bỏ (`status: retired`), trừ trong báo cáo Typst.
- Luồng không có trong UC, ví dụ `UC-DEAL-02 E12`.
- Dấu luồng hay dấu bước (`// E2`, `// 1.`) nằm ngoài hàm có ghi UC.
- Registry trỏ tới mã không có, trùng mã, hay chữ có dấu phẩy mà không đặt trong ngoặc kép.
- `error:` của một luồng không có trong `apperr.New` của server.
- Chỗ giữ giá trị (`{catalog.MaxOnSale}`) không đọc được: tên không có trong module, có ở hai package, khóa env không có, hoặc `|gợi ý` không hợp.

## Cảnh báo

- UC `done` mà không có code hoặc không có test nào ghi mã.
- Luồng ngoại lệ của UC `done` chưa có test.
- UC `untraced` hay `planned` mà code đã ghi mã.
- BR, NFR, ADR không được nhắc ở đâu.
- Báo cáo Typst còn nhắc mã hay luồng đã bỏ: báo cáo đi sau trang web, sửa khi viết lại chương đó.
- Mọi mục `gaps` của UC: chỗ code đang khác đặc tả.

## Cách code ghi mã

Quy ước nằm ở mục Code shape của `server/AGENTS.md`. Tóm tắt: doc comment
của hàm ghi `// Open is UC-DEAL-02.`, trong hàm `// 1.` là bước của luồng
chính, `// A1` và `// E2` là luồng thay thế và luồng ngoại lệ, test ghi
`// UC-DEAL-02 A1, E1, E2.` phía trên `func Test…`.

## Giá trị lấy từ code

Chữ trong registry không chép con số của server mà ghi chỗ giữ; `make trace`
đọc giá trị rồi ghi vào `trace.json` (`values`), web và Typst thay vào khi
dựng. Sửa hằng số trong code rồi chạy `make trace` là docs theo kịp.

| Chỗ giữ | Đọc từ |
|---|---|
| `{catalog.MaxOnSale}` | hằng số, biến hay hàm của một package dưới `server/internal/catalog/`, kể cả tên viết thường |
| `{deal.OrderWaits.Seller}` | một biểu thức Go bắt đầu bằng tên đó |
| `{provider/firebase.freshFor}` | thư mục con, khi tên có ở hai package của module |
| `{env.BOOST_PACKAGES\|packages}` | khóa trong `infra/stack/env/server.env` |

Sau `|` là cách đọc: `MB` (byte), `%` (tỉ lệ), `M` (triệu), `s` hay `days`
(số giây, số ngày), `packages` (các cặp ngày:giá của `BOOST_PACKAGES`).
Không có gợi ý thì `time.Duration` đọc thành thời lượng (24 giờ, 3 ngày),
số đọc theo từng ngôn ngữ (1.000 / 1,000). trace đọc bằng `go test -overlay`:
mỗi package nhận tạm một file test in giá trị, không file nào được ghi vào
cây code. Mục `retired` giữ nguyên con số cũ vì code không còn.

Endpoint của mỗi UC cũng không ghi trong registry: `trace.json` (`api`) lấy
từ `x-uc` của đặc tả OpenAPI.

`trace.json` ghi commit của server lúc chạy, để link trên web trỏ đúng dòng.
Commit server trước, rồi chạy `make trace` và commit `trace.json` vào docs.
