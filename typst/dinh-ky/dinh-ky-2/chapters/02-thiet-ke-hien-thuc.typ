#import "../../../common/tokens.typ": *

// Nhãn sơ đồ trình tự xoay ngang: phóng nhãn 7pt mặc định cho dễ đọc khi in
#let nl(b) = text(size: 10.5pt, b)

= THIẾT KẾ VÀ HIỆN THỰC

Chương này trình bày bốn nhóm chức năng của giai đoạn 2 theo góc nhìn người dùng: vận chuyển qua hãng, tìm kiếm bằng AI agent, uy tín và chế tài, và ứng dụng di động chạy trên dữ liệu thật. Mỗi phân hệ tự quản lý dữ liệu của mình và chỉ trao đổi với phân hệ khác qua các chức năng đã công bố, như đã thống nhất ở định kỳ 1.

== Vận chuyển qua GHTK và GHN

Người bán liên kết tài khoản GHTK hoặc GHN đứng tên mình một lần trong màn hình "Thiết lập giao COD" (UC-04): khai địa chỉ lấy hàng, chọn hãng và nhập khóa kết nối do hãng cấp. Trước khi lưu, hệ thống thử hỏi phí với hãng nên khóa sai bị báo ngay. Khóa được mã hóa khi lưu; hệ thống không bao giờ giữ mật khẩu tài khoản hãng (NFR-07).

Khi có yêu cầu COD, người mua đã thấy phí ship ước tính (UC-15). Người bán chỉ cần chọn dịch vụ nhanh hoặc tiết kiệm và nhập khối lượng (UC-16); hệ thống tạo vận đơn trên tài khoản hãng của người bán và hiện phí thật. Vận đơn luôn đặt chế độ người nhận trả phí ship và cho xem hàng [9][10], nên shipper thu tiền hàng cùng phí ship tại cửa sau khi người mua đã xem hàng (BR-08). Nếu người mua từ chối nhận, hàng quay về, hãng tính phí hai chiều vào tài khoản người bán và người mua không mất tiền (BR-11). Người bán vẫn có thể tự gửi qua hãng khác bằng cách nhập mã vận đơn, nhưng đơn tự gửi không được tính vào tỉ lệ dùng cho chế tài.

Hình 2.1 là trình tự tạo đơn gửi hàng. Quy trình gồm nhiều bước nối tiếp: kiểm tra đơn, tạo vận đơn, giữ tin cho người mua này và hủy các yêu cầu COD khác trên cùng tin. Kết quả mỗi bước được ghi lại [12], nên nếu máy chủ gặp sự cố giữa chừng, quy trình chạy tiếp từ bước đã xong và không tạo vận đơn thứ hai (NFR-01) [3]. Nếu tin đã đóng trước khi kịp giữ, vận đơn vừa tạo bị hủy ngay.

#fig-xoay(
  [Sơ đồ trình tự tạo đơn gửi hàng qua hãng vận chuyển],
  spacing: (44mm, 13mm),
  np((0, 0), [:Người bán\ (ứng dụng)]),
  ncore((1, 0), [Phân hệ\ giao dịch]),
  np((2, 0), [Phân hệ\ vận chuyển]),
  np((3, 0), [Hãng\ vận chuyển]),
  np((4, 0), [Phân hệ\ tin đăng], shape: rect),
  ..lifelines(5, y1: 13.9),
  msg(0, 1, 1, nl[1\. Xác nhận gửi hàng:\ dịch vụ, khối lượng]),
  step(1, 2, nl[2\. Kiểm tra đơn đang ở đã yêu cầu,\ đúng người bán, đã liên kết hãng]),
  msg(1, 2, 3, nl[3\. Tạo vận đơn\ (dịch vụ, khối lượng)]),
  msg(2, 3, 4, nl[4\. Tạo vận đơn người nhận trả phí,\ thu hộ tiền hàng]),
  rmsg(3, 2, 5, nl[5\. Mã vận đơn, phí thật]),
  rmsg(2, 1, 6, nl[6\. Lưu vận đơn, trả mã và phí]),
  msg(1, 4, 7, nl[7\. Giữ tin cho người mua này]),
  ..khung(nl[*alt*], 0.6, 4.35, 7.7, 12.4),
  dkien(1.5, 7.75, nl[tin còn đang bán]),
  rmsg(4, 1, 8.4, nl[8a. Tin chuyển đang giữ chỗ]),
  step(1, 9.4, nl[9a. Đơn sang đã tạo vận đơn; hủy các yêu cầu COD\ khác với lý do đã gửi cho người khác]),
  ngan(0.6, 4.35, 10.3),
  dkien(1.5, 10.35, nl[tin đã đóng]),
  rmsg(4, 1, 11.0, nl[8b. Từ chối giữ tin]),
  msg(1, 2, 12.0, nl[9b. Hủy vận đơn vừa tạo;\ đơn sang đã hủy]),
  rmsg(1, 0, 13.6, nl[10. Báo kết quả: mã vận đơn, phí thật]),
)

Trước khi hãng lấy hàng, cả hai bên đều hủy được đơn và vận đơn trên tài khoản hãng bị hủy theo; khi hãng đã lấy hàng, lệnh hủy bị từ chối (UC-18, BR-10). Sau đó người mua theo dõi đơn theo trạng thái hãng báo về (UC-17) mà không phải tự xác nhận. Hai hãng gọi trạng thái khác nhau nên được quy về trạng thái chung của đơn như ở Bảng 2.1. Hãng có thể báo trùng hoặc sai thứ tự; mỗi tin báo chỉ được ghi nhận một lần và chỉ áp vào đơn khi đơn đang ở đúng bước liền trước, nên đơn không lùi trạng thái và một lần giao không bị tính hai lần (NFR-02) [6].

#figure(
  kind: table,
  caption: [Ánh xạ trạng thái vận đơn GHTK, GHN sang trạng thái đơn],
  table(
    columns: (1.5fr, 1.5fr, 1fr, 1.9fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([*GHTK (mã số)*], [*GHN*], [*Trạng thái đơn*], [*Hệ quả*]),
    [1 chưa tiếp nhận, 2 đã tiếp nhận], [Chờ lấy hàng, đang lấy hàng], [Đã tạo vận đơn], [Giữ nguyên, còn hủy được],
    [3 đã lấy hàng], [Đã lấy hàng, đang lưu kho], [Đang giao], [Từ đây không hủy được],
    [4 đang giao, 9 không giao được], [Đang giao, giao không thành công], [Đang giao], [Chỉ ghi vào lịch sử vận đơn],
    [5 đã giao, 6 đã đối soát], [Đã giao], [Đã giao], [Tin được tính là đã bán],
    [20 đang hoàn, 21 đã hoàn], [Chờ hoàn, đang hoàn, đã hoàn], [Đã hoàn], [Tin trở về đang bán],
    [−1 hủy], [Hủy], [Đã hủy], [Tin trở về đang bán],
  ),
)

== Tìm kiếm bằng AI agent

Lớp dưới là tìm kiếm lai trên các tin đang bán. Mỗi tin được lập chỉ mục theo nghĩa bằng một mô hình nhúng văn bản đa ngôn ngữ [4][11] và theo từ khóa tiếng Việt không phân biệt dấu. Hình 2.2 tóm tắt một lần tìm: ba phép tìm chạy trên cùng tập tin đã qua bộ lọc, ba danh sách được hợp nhất theo thứ hạng [5], rồi kết quả được xếp lại nhẹ theo khoảng cách và bậc uy tín người bán. Tin đang giữ chỗ, đã bán hoặc đang ẩn không xuất hiện trong kết quả.

#fig(
  [Các bước của truy vấn tìm kiếm lai],
  spacing: (14mm, 8mm),
  nt((0, 1), [Câu tìm\ và bộ lọc]),
  np((1, 1), [Chuyển câu\ thành vector]),
  np((2, 0), [Tìm theo nghĩa]),
  np((2, 1), [Tìm theo\ trọng số từ]),
  np((2, 2), [Khớp đúng\ từ khóa]),
  ncore((3, 1), [Hợp nhất\ thứ hạng]),
  np((4, 1), [Xếp lại theo\ khoảng cách, uy tín]),
  nt((5, 1), [Kết quả]),
  edge((0, 1), (1, 1), "-|>"),
  edge((1, 1), (2, 0), "-|>"),
  edge((1, 1), (2, 1), "-|>"),
  edge((0, 1), (0, 2), (2, 2), "-|>"),
  edge((2, 0), (3, 1), "-|>"),
  edge((2, 1), (3, 1), "-|>"),
  edge((2, 2), (3, 1), "-|>"),
  edge((3, 1), (4, 1), "-|>"),
  edge((4, 1), (5, 1), "-|>"),
)

Lớp trên là AI agent (UC-09). Người dùng gõ một câu như "kiếm xe đạp cũ dưới 3 triệu, gần đây"; agent dùng một mô hình ngôn ngữ lớn có sẵn, tự chọn công cụ cần tra cứu như tìm tin, xem danh mục, xem khu vực hay sở thích của người dùng, rồi đặt bộ lọc phù hợp [7]. Kết quả gồm danh sách tin, các chip điều kiện sửa được và một câu diễn giải ngắn. Lượt sau trong cùng phiên kế thừa các điều kiện đã chốt. Agent chỉ đọc (BR-18): không đặt hàng, không thương lượng, không thanh toán. Mỗi lượt gọi công cụ tối đa 4 lần; quá 8 giây hoặc gặp lỗi thì hệ thống trả kết quả tìm kiếm lai với câu gốc (NFR-05). Người dùng cũng lưu được tin để theo dõi giá (REQ-12).

== Uy tín và chế tài

Sau khi đơn đã gửi, người mua đánh giá người bán một lần từ 1 đến 5 sao (UC-19, BR-17). Nếu phát hiện vấn đề sau khi nhận hàng, người mua mở ghi nhận sự cố kèm ảnh (UC-20); AI viết một nhận xét trung lập đối chiếu mô tả với cam kết của tin đăng, không kết luận ai đúng. Người bán có 3 ngày để tự hoàn hoặc từ chối (UC-21); từ chối hoặc quá hạn thì ghi nhận hiện công khai trên hồ sơ người bán (BR-14).

Điểm uy tín từ 0 đến 1000 được tính lại sau mỗi sự kiện: giao dịch thành công cộng 10, được đánh giá 5 sao cộng 5, tự hoàn cho một ghi nhận cộng 15, xác minh danh tính cộng 100, bị đánh giá 1–2 sao trừ 15; sự kiện cũ hơn 365 ngày chỉ tính một nửa. Điểm quyết định bậc và quyền như ở Bảng 2.2. Quyền COD và bậc uy tín không mua được bằng gói trả phí (BR-16).

#figure(
  kind: table,
  caption: [Bậc uy tín và quyền tương ứng],
  table(
    columns: (1fr, 0.8fr, 1.1fr, 1.1fr, 2fr),
    align: (left, center, center, center, left),
    table.header([*Bậc*], [*Điểm từ*], [*Đơn COD mở tối đa*], [*Tin đang bán tối đa*], [*Quyền lợi thêm*]),
    [Mới], [0], [2], [5], [],
    [Tin cậy], [200], [5], [20], [],
    [Uy tín], [500], [10], [20], [Ưu tiên hiển thị],
    [Xuất sắc], [800], [20], [20], [Huy hiệu, giảm 20% phí đẩy tin],
  ),
)

Chế tài chạy tự động theo BR-15 khi người mua có ít nhất 5 đơn COD qua hãng trong 90 ngày: tỉ lệ từ chối nhận từ 20% thì chỉ còn 1 đơn COD mở, từ 35% thì mất quyền COD trong 30 ngày, và 30 ngày không từ chối lần nào thì hồi lại một nấc. Hạn mức được kiểm tra ngay khi gửi yêu cầu COD; hai yêu cầu cùng lúc được xét lần lượt nên không vượt hạn mức được (BR-09, NFR-03).

== Ứng dụng di động

Các màn hình làm ở giai đoạn 1 nay lấy và ghi dữ liệu thật mà giao diện giữ nguyên [8]. Ứng dụng nhận cập nhật tức thời khi có tin nhắn, nước đi thương lượng hay đơn đổi trạng thái, tự giữ phiên đăng nhập, và bấm lại nút khi mạng chập chờn không tạo hai yêu cầu COD.

Hình 2.3 là luồng tìm kiếm: người dùng gõ câu tự nhiên (a), nhận kết quả kèm chip "Xe đạp", "Dưới 3 tr" (b), rồi mở chi tiết tin để trả giá (c).

#anh-mobile(
  [Tìm kiếm bằng câu tự nhiên và chi tiết tin],
  ("search-typing.png", "results.png", "detail.png"),
  nhan: ("Gõ câu tìm kiếm", "Kết quả và chip", "Chi tiết tin"),
  cao: 8cm,
)

Hình 2.4 là luồng đơn COD: người bán chọn hãng, khối lượng, dịch vụ và xem phí trước khi tạo đơn (a); khi shipper đến, người mua được nhắc xem hàng trước vì sau khi trả tiền sàn không đòi lại được (b, BR-12); màn hình (c) hiện điểm uy tín 386/1000 ở bậc Tin cậy với hạn mức 5 đơn COD mở và 20 tin đang bán.

#anh-mobile(
  [Tạo đơn gửi hàng, nhận hàng đồng kiểm và điểm uy tín],
  ("order-ship-to-create.png", "order-cod-door.png", "rep.png"),
  nhan: ("Người bán tạo đơn", "Shipper ở cửa", "Điểm uy tín"),
  cao: 8cm,
)
