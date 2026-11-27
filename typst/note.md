# Typst: những chỗ cần sửa

Ghi ngày 2026-11-27, sau đợt rà docs cho release. Site docs và
`registry/requirements.yaml` đã đúng với code; các file Typst chưa sửa.
Bảng và đặc tả lấy từ registry qua `common/req.typ` (ví dụ `#ucspec-of`,
`n-uc`) sẽ tự đúng khi build lại. Danh sách dưới đây là chữ viết tay.

Báo cáo cuối (`bao-cao-cuoi/`) là bản cần sửa. Định kỳ 1 và 2 đã nộp, chỉ
sửa nếu cần build lại; các dòng của chúng ghi ở cuối file.

## Thay đổi cần phản ánh

1. **Bỏ vận đơn nhập tay.** Người bán không còn tự nhập mã vận đơn;
   BR-DEAL-12 và UC-DEAL-04 A2, A3, E1 (`shipment_not_found`) đã retired.
2. **Bỏ đọc tin từ link Chợ Tốt.** Lượt đọc bằng AI chỉ còn video và ảnh
   (UC-LST-01 A2, E7 retired); hạn mức còn 30 video, 60 ảnh mỗi 24 giờ.
   Tin Chợ Tốt sang qua UC-LST-04 (liên kết trang cá nhân, nhập tin).
3. **Hàng thất lạc là lỗi của hãng.** Hãng làm mất hàng sau khi lấy, hoặc
   30 ngày sau khi lấy hàng không còn biết vận đơn: đơn giao không thành
   với vận đơn "thất lạc", không tính vào số đơn giao không thành của người
   mua, không mở đánh giá, tin chuyển sang ẩn, hai bên được báo (người bán
   đòi bồi thường với hãng). Xem UC-DEAL-05 E4, BR-DEAL-11, BR-TRS-04.
4. **Theo dõi tìm kiếm là UC-DSC-06.** UC-DSC-03 giờ chỉ là lưu tin và báo
   giảm giá ("Lưu tin và nhận cảnh báo giảm giá").
5. **Thông báo có ca dùng chung UC-SHR-03.** FR-SHR-02 trỏ về UC-SHR-03.
6. **UC mới** (bảng tự có khi build lại, nhưng phần văn nên nhắc nếu
   cần): UC-ACC-06…09, UC-LST-04, UC-DSC-05, UC-DSC-06, UC-TRS-05,
   UC-MOD-10…12, UC-SHR-03; ADR-0004, ADR-0005.
7. **Thuật ngữ:** dùng "module", không dùng "phân hệ" (glossary
   `i18n/glossary.yaml` đã đổi).

## Báo cáo cuối: từng chỗ

- `03-phan-tich-yeu-cau.typ:85`: "cộng hai ca dùng chung UC-SHR-01 và
  UC-SHR-02" → ba ca, thêm UC-SHR-03.
- `03-phan-tich-yeu-cau.typ:153`: quy trình giao dịch (Hình 3.3) còn nhắc
  BR-DEAL-12 / mã nhập tay.
- `03-phan-tich-yeu-cau.typ:193` và đoạn `:227`: sơ đồ trạng thái đơn chỉ
  có "Đơn giao không thành, tin về đang bán"; thêm nhánh thất lạc (tin
  chuyển sang ẩn, không tính cho người mua).
- `04-thiet-ke-he-thong.typ:85`: "AI đọc video, ảnh, link Chợ Tốt" → bỏ
  link.
- `04-thiet-ke-he-thong.typ:277`: trình tự UC-DEAL-04 (Hình 4.5) còn nhánh
  mã nhập tay và BR-DEAL-12.
- `04-thiet-ke-he-thong.typ:348`: bảng luồng "Đọc tin đăng" còn "hoặc link
  Chợ Tốt" và hạn mức link.
- `05-hien-thuc-trien-khai.typ:24`: "Người bán có ba cách", cách thứ ba
  dán link Chợ Tốt và "30 lượt đọc link" → còn hai cách; nhắc UC-LST-04.
- `05-hien-thuc-trien-khai.typ:42`: theo dõi câu tìm ghi UC-DSC-03 → tách:
  theo dõi tìm kiếm UC-DSC-06, tin đã lưu và báo giá UC-DSC-03.
- `05-hien-thuc-trien-khai.typ:92`: "theo một trong hai cách" tạo đơn,
  cách thứ hai nhập mã tay (BR-DEAL-12) → chỉ còn tạo qua hãng.
- `05-hien-thuc-trien-khai.typ:113`: trạng thái giao không thành; thêm
  trường hợp thất lạc.
- `06-kiem-thu-danh-gia.typ:61`: TC-11 kiểm mã vận đơn nhập tay
  (UC-DEAL-04, BR-DEAL-12) → bỏ hoặc thay bằng ca thất lạc (UC-DEAL-05 E4).
- "phân hệ" → "module": 35 chỗ, nhiều nhất ở `04-thiet-ke-he-thong.typ`
  (23); còn lại ở chương 01, 02, 03, 05, 06, 07.
- `01-tong-quan.typ:51` ghi số đơn giao không thành "công khai trên hồ
  sơ"; theo UC-TRS-04 con số này chỉ chủ tài khoản thấy ở "Uy tín của
  bạn". Kiểm lại câu này.

## Định kỳ 2 (đã nộp, chỉ sửa khi build lại)

- BR-DEAL-12: `03-phan-tich-va-thiet-ke-he-thong.typ:351, 474, 855, 920`,
  `04-hien-thuc-va-trien-khai-he-thong.typ:203`, `05-kiem-thu-danh-gia.typ:77`.
- Mã nhập tay trong đặc tả UC-DEAL-04: `03-…typ:325, 334, 335`.
- Link Chợ Tốt: `02-thiet-ke-hien-thuc.typ:18`, `03-…typ:37, 118, 211,
  229, 244`.
- UC-DSC-03 gồm theo dõi tìm kiếm: `02-thiet-ke-hien-thuc.typ:63`,
  `03-…typ:42, 136, 271`.
- Bảng UC thiếu UC-SHR-03 (`03-…typ:202`); FR-SHR-02 (`03-…typ:51`).
- "phân hệ": 82 chỗ.

Định kỳ 1 (`dinh-ky-1/chapters/02-phan-tich-yeu-cau.typ:52`) mô tả mô
hình cũ; để nguyên.

Kiểm lại sau khi sửa: từ thư mục umbrella chạy `make trace`; phần cảnh báo
"BR-DEAL-12 is retired" trong Typst phải hết.
