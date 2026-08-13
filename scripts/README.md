# Ảnh chụp màn hình website cho chương 5

`capture-web-screenshots.mjs` lái Chromium bằng Playwright, đăng nhập vào bản
ShopNexus đang chạy, đi qua từng luồng và chụp ảnh vào
`docs/typst/common/assets/web/`.

## Chạy lại

Playwright đã có sẵn trong `website/node_modules` — script tự tìm ở đó, không
cần cài thêm. Nếu muốn chạy độc lập với `website/`:

```sh
cd docs/scripts
npm i -D @playwright/test
npx playwright install chromium
```

Truyền thông tin đăng nhập thẳng ở dòng lệnh (đừng ghi vào tệp trong repo):

```sh
cd docs/scripts
SHOPNEXUS_BUYER_EMAIL='...' SHOPNEXUS_BUYER_PASSWORD='...' \
SHOPNEXUS_SELLER_EMAIL='...' SHOPNEXUS_SELLER_PASSWORD='...' \
SHOPNEXUS_ADMIN_USERNAME='...' SHOPNEXUS_ADMIN_PASSWORD='...' \
node capture-web-screenshots.mjs
```

Xem `.env.example` để biết đủ tên biến. `SHOPNEXUS_BASE_URL` bỏ trống thì mặc
định `https://shopnexus.hopto.org`.

Cờ hữu ích:

| Cờ | Tác dụng |
| --- | --- |
| `--list` | in danh sách bước và tên tệp ảnh |
| `--only=tim-kiem,thanh-toan` | chỉ chạy vài bước |
| `--headed` | mở trình duyệt để xem script thao tác |
| `--out=/duong/dan` | đổi thư mục ghi ảnh |

Chạy một bước lẻ khi cần chụp lại đúng một hình:

```sh
SHOPNEXUS_BUYER_EMAIL='...' SHOPNEXUS_BUYER_PASSWORD='...' \
  node capture-web-screenshots.mjs --only=theo-doi-don
```

## Các bước và ảnh sinh ra

| Khoá bước | Tệp | Vai đăng nhập |
| --- | --- | --- |
| `trang-chu` | `web-00-trang-chu.png` | người mua |
| `tim-kiem` | `web-01-tim-kiem.png` | người mua |
| `chi-tiet-san-pham` | `web-02-chi-tiet-san-pham.png` | người mua |
| `thuong-luong` | `web-03-thuong-luong.png` | người mua |
| `thanh-toan` | `web-04-thanh-toan.png` | người mua |
| `theo-doi-don` | `web-05-theo-doi-don.png` | người mua |
| `hoan-tien` | `web-06-hoan-tien.png` | người bán |
| `hang-doi-phieu` | `web-07-hang-doi-phieu.png` | quản trị |

## Quy ước kỹ thuật

- Khung nhìn luôn rộng **1440px**; bề cao đổi theo từng trang cho vừa nội dung.
- `deviceScaleFactor: 2`, nên ảnh xuất ra rộng 2880px.
- Chụp theo khung nhìn (`fullPage: false`) trừ `web-04-thanh-toan.png` — trang
  thanh toán dài hơn một màn hình nên phải chụp full page mới thấy đủ danh sách
  vận chuyển, danh sách kênh thanh toán và bảng tổng tiền.
- Trước mỗi lần chụp, script chờ mạng rảnh, chờ `document.fonts.ready` và chờ mọi
  `<img>` giải mã xong, nên ảnh không dính khung xám placeholder hay icon dạng
  chữ. Huy hiệu "Issues" của Next.js dev cũng bị ẩn đi.

## Dữ liệu bước `thuong-luong` tự tạo

Thẻ đề nghị giá chỉ tồn tại khi có một đề nghị *còn hiệu lực*. Bước này kiểm tra
hộp thư trước; nếu không còn đề nghị nào, nó tự gửi một đề nghị mới từ chính tài
khoản người mua (690.000 ₫ cho tin `lst_6kydfg4dp6gxz`) rồi mới chụp. Đây là dữ
liệu do script tạo ra, không phải trạng thái có sẵn — cần nói rõ khi chú thích
hình nếu người đọc quan tâm.

Bước `thanh-toan` cũng tạo một *đơn nháp* mỗi lần chạy (bấm "Mua ngay" rồi dừng
trước nút "Đặt hàng"). Đơn nháp không phải đơn hàng và không phát sinh thanh
toán.

## Các mã cố định

Các mã tin đăng / đơn hàng / yêu cầu hoàn tiền nằm trong hằng `FIXTURES` ở đầu
script. Nếu dữ liệu thử trên máy chủ đổi thì sửa ở đó.

---

# Lint tệp Typst

`lint-typst.sh` chạy `tinymist lint` trên mọi tệp `.typ` trong `typst/`
(bỏ `tmp/` và `out/`), với `--root typst` và `--font-path typst/common/fonts`
đúng như lúc biên dịch.

```sh
cd docs
./scripts/lint-typst.sh                     # lint hết
./scripts/lint-typst.sh typst/common/*.typ  # chỉ vài tệp
VERBOSE=1 ./scripts/lint-typst.sh           # giữ cả log nội bộ của tinymist
```

Thoát 0 nếu sạch, 1 nếu có tệp bị báo lỗi. Cần cài `tinymist` (≥ 0.15, đây là
bản đầu tiên có lệnh `lint`): `sudo pacman -S tinymist` hoặc
`cargo install --locked tinymist`.

Lint đọc tĩnh từng tệp nên bắt được biến/hàm không tồn tại, tham số trùng, cú
pháp sai — kể cả ở tệp chương lẻ, không phải chỉ `main.typ`. Nó không thay thế
việc biên dịch thật: lỗi lúc dựng hình (thiếu ảnh, tràn trang) vẫn phải chạy
`typst compile` mới thấy.
