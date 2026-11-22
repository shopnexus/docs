# Soát UI website, 23/11/2026

Ba agent soát website trên dev stack compose ngày 23/11/2026: soát từng trang (1280 và 390, có và không đăng nhập, dark mode), đi luồng mua và bán bằng tài khoản thử, và research các sàn C2C. Ảnh chụp ở `tmp/ui-review/pages/` và `tmp/ui-review/flows/` trong umbrella (không commit).

Đã làm trước đợt soát (website `1c3e2ce`): Be Vietnam Pro thay Inter, thang chữ tăng một bậc (chữ chính 15 và 14px, không bậc nào dưới 12px), thanh bên tài khoản còn 6 mục chia hai nhóm Mua và Bán. Lý do: ở trang tin, Chợ Tốt, Mercari, Vinted, Carousell và Facebook Marketplace đều dùng 14–16px, ShopNexus dùng 13px.

## 1. Lỗi hỏng

- [x] Ảnh trong nháp trả 403 (`/_img/.../shopnexus/uploads/<id>`) khi mở lại nháp hoặc quay lại form sau khi đăng lỗi; ảnh trong Xem trước cũng vỡ. Sửa ở website `c9353ca`: URL ký sẵn tải thẳng, không qua imgproxy.
- [x] `sign-in.astro` đưa tài khoản mới tới Hoàn thiện hồ sơ và bỏ `next`; khách vừa bấm Trả giá mất việc đang làm. Website `c9353ca`: về `next`, chỉ mở Hoàn thiện hồ sơ khi đến từ Home.
- [x] Ô giá trả có sẵn giá, gõ thêm thành "4.200.380.000.000 ₫"; "Gửi giá" không gửi và không báo gì. Website `c9353ca`: ô tiền chọn hết cho tới khi người dùng sửa; giá sai báo dưới ô.
- [x] Tài khoản mới không có tên: thông báo ghi "trả 3,8 tr cho …", thẻ người bán ở 1280 để trống tên, chat ghi "Người dùng". Server `2b8dfbb0` (câu thông báo, push chat) và website `c9353ca` (`shownName` ở mọi trang) dùng "Người dùng".
- [x] Cột dính `sticky-fit` ở 1280 cắt nội dung: "Tin khác của…" trên trang tin, thẻ "Mua bằng COD" trên rail của Home. Website `c9353ca`: cột cao hơn cửa sổ cuộn theo trang tới đáy rồi mới dính.
- [x] Tìm kiếm: hai chip "iPhone ×" giống nhau (model đặt "iPhone" vừa là danh mục vừa là cụm từ). Server `076616d8`: một chip cho cả hai, tắt chip thì bỏ cả hai.
- [ ] Tìm kiếm: không có số kết quả, kết quả khớp một phần (`?q=xyzqwv abc`) hiện như khớp đủ. Cần server trả tổng số và cờ khớp đủ; một session khác đang sửa phần đếm của search.
- [x] Thông số tin lệch tiêu đề (tiêu đề iPhone 13 Pro 128GB, bảng ghi iPhone 12 64GB). Không phải lỗi: tin `wvnyyejb` là bản sao do tài khoản "Seller Tools" (công cụ test) đăng; dòng seed `p-iphone13` đúng.

## 2. Chặn luồng chính

- [x] Tài khoản chỉ có email bị chặn chat, trả giá và mua (`phone_required`); lỗi ghi "Xem Bảo mật". website `be94cd7`: link "Thêm số điện thoại" tới bước SĐT của Bảo mật, xong thì quay lại trang cũ (mua thì mở lại hộp mua). Chưa làm sheet ngay tại chỗ: bước SĐT cần reCAPTCHA của Firebase và xác thực lại.
- [x] "Tự gửi" chỉ hiện khi đã liên kết GHTK/GHN (`ShipForm.astro`). Giữ yêu cầu này: server đọc trạng thái vận đơn bằng tài khoản hãng của người bán (UC-DEAL-04, E3), đó là thứ chốt đơn COD. website `be94cd7`: một dòng giải thích, liên kết xong quay về đơn.
- [x] Trang Tôi dưới 840px không có link Đơn mua, Đơn bán, Trả giá, Tin của bạn; chỉ có trong menu avatar ở góc. Thêm hai nhóm Mua và Bán. website `be94cd7`: `AccountLinks` dùng chung cho thanh bên, Tôi và menu avatar.
- [x] Trang tin ở 390: cuộn qua "Mua ngay" thì không còn nút mua, nút Đăng tin nổi che Hỏi nhanh. Thanh dính giá, Trả giá, Mua ngay; ẩn nút Đăng tin nổi ở trang tin, trang đơn và Tin nhắn. website `be94cd7`: nút Đăng tin nổi chỉ còn ở Khám phá, Danh mục, Tìm kiếm.
- [x] Tin nhắn trên bottom bar không có số chưa đọc (header ở desktop có). website `be94cd7`.
- [x] "Cho phép trả giá" mặc định tắt; chạm vào chữ không bật. Mặc định vốn bật, AI điền tin ghi đè thành tắt. website `be94cd7`: AI chỉ được bật, chạm cả hàng.
- [x] Đăng tin: AI để trống thông số bắt buộc, Xem trước vẫn cho đăng, server mới từ chối và lỗi hiện ở đầu trang. Kiểm tra trước Xem trước, cuộn tới ô lỗi. website `be94cd7`: ô bắt buộc có `required`, báo "Điền <thông số>".
- [x] Lưu và Mua ngay khi chưa đăng nhập: sau khi đăng nhập chỉ về trang tin, tim chưa lưu, hộp mua không mở. website `be94cd7`: `?then=` cho Lưu, Theo dõi, Mua ngay.
- [x] Phường/xã là danh sách thả xuống 169 mục. website `be94cd7`: gõ để lọc, không cần dấu.

## 3. Đồng nhất UI

- [x] Năm kiểu empty state (Đơn mua, Trả giá, Đã lưu, Tin của bạn, Tin nhắn). Một component `EmptyState`: icon tròn, một dòng, một nút viền. Đơn bán đang gợi ý "Khám phá tin đang bán". website `85a5948`: `EmptyState.astro`.
- [x] Bốn kiểu tab: gạch chân (Home, Tìm kiếm), segmented (Đơn hàng, Người bán), chip mint (Tin của bạn), pill (Tin nhắn). Chỉ dùng `Seg`. website `85a5948`: `TabLinks.astro` (seg, tabs) cho tab dạng link.
- [x] Teal đặc ở ô "Như mới" của thang Tình trạng, CTA cuối trang Danh mục, banner Trợ giúp, vòng chỉ số ở Tin của bạn, nút "Báo khi có tin mới". Chuyển sang mint. website `85a5948`.
- [x] Chỉ số rỗng ("– Chưa có đánh giá", "Đơn COD đang mở 0/3", "0 lượt xem"); ba chỉ số trên Tôi ở 390 rớt thành 2+1. website `85a5948`: ẩn khi chưa có dữ liệu, ô bằng nhau.
- [x] Lối vào trùng: toggle Mua/Bán ở Đơn hàng trùng thanh bên; thẻ "Hãng vận chuyển" ở Đơn bán trùng Giao COD; Đã lưu có ở header, rail và thanh bên. website `85a5948`: toggle chỉ còn trên điện thoại, thẻ hãng vận chuyển chỉ hiện khi có đơn chờ.
- [x] Thông báo: 7 công tắc và nút "Lưu cài đặt" lấn át danh sách; giờ hiện "10:00 PM". Đưa cài đặt ra sau bánh răng, công tắc tự lưu, giờ 24h. website `85a5948`: gập sau bánh răng, tự lưu, giờ 24h.
- [x] Feed Dành cho bạn lặp một tin iPhone 4 lần (slug khác, cùng ảnh và tiêu đề); Tin tương tự có bản sao của tin đang xem. Trên dev, 3 trong 4 bản là tin do công cụ test đăng lại; vẫn nên gộp tin trùng của cùng người bán. Server `ff39ba34`: feed và hàng Vì bạn đã xem bỏ tin trùng người bán và tiêu đề.
- [x] Tìm kiếm ở 390: "Bộ lọc" chiếm một hàng, tab "Giá thấp" bị nút lưới/danh sách che. website `85a5948`.
- [x] Đăng tin: dải "AI điền giúp" chỉ có icon bóng đèn trước khi có ảnh; header vẫn hiện nút Đăng tin trên /sell. website `85a5948`.
- [x] Tin nhắn ở 1280 dừng ở 904px; dark mode: nút "Xem 3 ảnh" vẫn là pill trắng. website `85a5948`.
- [x] Hộp Giao COD là hộp thoại giữa màn hình trong khi Mua ngay là bottom sheet; "+ phí ship" không có số tiền; "Hủy giá đã chốt" đứng trước "Đặt giao COD". website `85a5948`: chưa có phí ship ước tính từ server nên ghi "báo khi gửi".

## 4. Ý tưởng từ các sàn C2C

Xếp theo giá trị trên công sức.

| # | Ý tưởng | Sàn | Server | Công sức |
|---|---|---|---|---|
| 1 | Báo cáo tin trên trang tin và trang người bán (`POST /v1/reports` đã nhận `listing_id`) | [Vinted](https://www.vinted.com/help/288-report-a-member-or-listing) | không | S |
| 2 | "Bán món giống vậy?" dưới Thông số, mở `/sell` điền sẵn danh mục và thông số | Chợ Tốt, Mercari JP | không | S |
| 3 | Chế độ tạm nghỉ: tắt Mua ngay và Trả giá, chat vẫn mở | [Depop](https://depophelp.zendesk.com/hc/en-gb/articles/12267530258833-Vacation-Mode), [Kleinanzeigen](https://hilfe.kleinanzeigen.de/hc/de/articles/19895418433564-Abwesenheit-einstellen-Anzeigen-pausieren-bei-Kleinanzeigen) | có | S–M |
| 4 | Gửi giá cho người đã lưu tin | [Mercari](https://www.mercari.com/us/help_center/article/347/) | có | M |
| 5 | Giá sàn ẩn, tự trả giá lại bằng giá sàn | Mercari Smart Offers | có | M |
| 6 | Giữ hàng giữa lúc chốt giá và lúc tạo đơn | Facebook, [Kleinanzeigen](https://hilfe.kleinanzeigen.de/hc/de/articles/17088055736476-Kann-ich-auch-Ware-reservieren) | có | M |
| 7 | Chip đánh giá "Đúng mô tả", "Trả lời nhanh", "Gói kỹ" | [Carousell](https://carousell.sg/u/carousellmobile/reviews) | có | M |
| 8 | Tab "Đang theo dõi" trên Home | [Vinted](https://www.vinted.co.uk/help/35-finding-items) | có | S–M |
| 9 | Lọc Cá nhân / Cửa hàng | Chợ Tốt | có | S–M |
| 10 | Chọn nhiều trong Tin của bạn (Ẩn, Đã bán, Giảm 10%) | Poshmark | tùy | M |
| 11 | Tự hạ giá dần tới giá sàn (sau mục 5) | Mercari Smart Pricing | có | M |
| 12 | Gom nhiều món của một người bán vào một đơn COD | [Vinted](https://www.vinted.co.uk/help/260-buying-a-bundle) | có | L |

Bỏ: tỉ lệ phản hồi (web đã hiện `reply_time`); xác thực hàng thật và bảo vệ người mua (cần giữ tiền); hiện số điện thoại (kéo giao dịch ra ngoài chat); hẹn gặp trực tiếp (bỏ qua vận đơn COD); tìm trên bản đồ (đã có lọc khoảng cách); nhãn ship trả trước (cần thu tiền).

## Dữ liệu thử còn trên dev

Tài khoản flow-buyer-0107, flow-seller-0107 (SĐT giả +84977010701 và +84977010702 chèn thẳng vào `identities`), flow-guest-0107; tin "Máy ảnh Fujifilm FinePix S Series Xanh Đen"; đơn COD SN-145375; 2 nháp.
