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
- `x-uc` của một operation lệch với danh sách `api` của UC.

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

`trace.json` ghi commit của server lúc chạy, để link trên web trỏ đúng dòng.
Commit server trước, rồi chạy `make trace` và commit `trace.json` vào docs.
