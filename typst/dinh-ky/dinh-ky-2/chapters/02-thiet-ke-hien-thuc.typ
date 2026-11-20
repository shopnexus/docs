#import "../../../common/tokens.typ": *

#show table.cell: set text(size: 10pt)

// Ảnh chụp website, cùng kiểu chú thích với anh-mobile
#let anh-web(cap, tep, rong: 100%) = figure(
  box(stroke: 0.6pt + hairline, image("../../../common/assets/web/" + tep, width: rong)),
  caption: cap,
  kind: image,
)

= KẾT QUẢ HIỆN THỰC

Chương này đi theo thứ tự một giao dịch: người bán đăng tin, người mua tìm hàng, hai bên trò chuyện và chốt giá, đơn COD đi qua hãng vận chuyển, rồi hai bên đánh giá nhau. Phần cuối trình bày trang điều hành của nhân viên và các kênh người dùng truy cập. Mọi chức năng dưới đây chạy trên cùng một dịch vụ nền cho cả ứng dụng Android và website.

== Đăng tin với AI điền giúp

Người bán có ba cách bắt đầu một tin đăng (UC-LST-01). Cách thứ nhất là quay video món đồ, xoay các mặt và nói giá muốn bán; AI nghe tiếng Việt trong video, xem các khung hình rồi điền tên, danh mục, tình trạng, thông số, mô tả và giá người bán vừa nói. Cách thứ hai là chụp ảnh, AI điền theo những gì ảnh cho thấy. Cách thứ ba dành cho người đã bán trên Chợ Tốt: dán link tin cũ, AI lấy ảnh và nội dung, đồng thời bỏ số điện thoại, Zalo trong mô tả. Người bán sửa lại mọi ô trước khi đăng.

Bước "Giá" cho người bán thấy thị trường của món đồ: các tin tương tự đang bán và đã bán, số người mua đang theo dõi tìm kiếm khớp với món này, và hai mức gợi ý. "Giá thị trường" là giá giữa của các tin tương tự, kèm số ngày bán thường gặp. "Bán nhanh" là giá giữa của nhóm tin bán nhanh hơn mức thường, chỉ hiện khi thấp hơn giá thị trường.

Nháp tin đăng được lưu trên máy chủ nên người bán bắt đầu trên điện thoại và đăng tiếp trên website được, tối đa 20 nháp, nháp không sửa trong 30 ngày thì bị xóa. Mỗi người có tối đa 20 tin đang bán. Trang "Tin của bạn" hiện lượt xem, lượt hỏi và lượt lưu của từng tin (UC-LST-02).

== Tìm kiếm và khám phá

Người mua gõ một câu như "xe đạp cũ dưới 3 triệu" (UC-DSC-01). AI đọc câu một lần và đổi thành điều kiện tìm: danh mục, khoảng giá, tình trạng, nơi bán, độ gần. Kết quả hiện kèm các chip điều kiện người mua tắt được, cùng một câu ngắn cho biết hệ thống đã hiểu câu tìm thế nào. AI chỉ đọc câu tìm, không đặt hàng hay nhắn tin thay người dùng.

Kết quả được ghép từ ba cách tìm trên các tin đang bán: khớp từ khóa tiếng Việt, tìm theo nghĩa bằng mô hình nhúng văn bản đa ngôn ngữ [3], và so ảnh bằng mô hình hiểu ảnh [5]. Ba danh sách được hợp nhất theo thứ hạng [4] (Hình 2.1). Nhờ phần so ảnh, người mua còn tìm được bằng một tấm ảnh chụp món đồ, và trang chi tiết tin có mục tin tương tự. Tin đã bán, đang giữ cho người khác, đang ẩn, hay của người đã chặn mình (theo cả hai chiều) không hiện trong kết quả.

#fig(
  [Các bước của một lần tìm kiếm],
  spacing: (14mm, 8mm),
  nt((0, 1), [Câu tìm\ hoặc ảnh]),
  np((1, 1), [AI đọc câu\ thành điều kiện]),
  np((2, 0), [Tìm theo nghĩa]),
  np((2, 1), [So ảnh]),
  np((2, 2), [Khớp từ khóa]),
  ncore((3, 1), [Hợp nhất\ thứ hạng]),
  np((4, 1), [Lọc theo điều kiện\ và người đã chặn]),
  nt((5, 1), [Kết quả\ và chip]),
  edge((0, 1), (1, 1), "-|>"),
  edge((1, 1), (2, 0), "-|>"),
  edge((1, 1), (2, 1), "-|>"),
  edge((1, 1), (2, 2), "-|>"),
  edge((2, 0), (3, 1), "-|>"),
  edge((2, 1), (3, 1), "-|>"),
  edge((2, 2), (3, 1), "-|>"),
  edge((3, 1), (4, 1), "-|>"),
  edge((4, 1), (5, 1), "-|>"),
)

Hình 2.2 là luồng tìm trên ứng dụng: người mua gõ câu (a) và nhận kết quả kèm chip "Xe đạp", "Dưới 3 tr" (b). Hình 2.3 là cùng câu tìm trên website, có thêm bộ lọc giá, tình trạng, khoảng cách ở cột trái và nút "Báo khi có tin mới".

#anh-mobile(
  [Tìm kiếm bằng câu tự nhiên trên ứng dụng],
  ("search-typing.png", "results.png"),
  nhan: ("Gõ câu tìm kiếm", "Kết quả và chip"),
  cao: 9cm,
)

#anh-web([Kết quả tìm kiếm trên website], "search.png")

Người mua không phải tìm lại mỗi ngày (UC-DSC-03). Một câu tìm được theo dõi thì hệ thống quét tin mới mỗi 30 phút và báo số tin mới khớp. Tin đã lưu có thể đặt mức giá, khi người bán hạ giá xuống dưới mức đó thì người mua nhận thông báo. Người mua cũng theo dõi được một người bán để biết khi người đó đăng tin mới, và ẩn những tin không muốn thấy lại. Trang chủ có ba tab: "Gợi ý" xếp theo danh mục người mua đã lưu, đã tìm, đã xem trong 30 ngày; "Gần bạn" xếp theo khoảng cách và độ mới; "Mới nhất" xếp theo thời gian đăng. Khách chưa đăng nhập vẫn xem và tìm được.

== Trò chuyện, thương lượng và cảnh báo lừa đảo

Người mua nhắn tin cho người bán ngay từ tin đăng (UC-DEAL-01). Tin nhắn đến tức thời, hai bên thấy "đang nhập…" và mốc đã đọc, gửi được ảnh, trả lời một tin cụ thể bằng cách vuốt tin đó, và link tin đăng hiện thành thẻ có ảnh và giá. Trong cùng cuộc trò chuyện, hai bên trả giá, đồng ý hoặc rút giá (UC-DEAL-02). Khi đã chốt, người mua chọn giao COD (Hình 2.4).

Sau mỗi tin nhắn có chữ, AI đọc 20 tin gần nhất của cuộc trò chuyện để tìm dấu hiệu lừa đảo. Số điện thoại, số tài khoản ngân hàng, số thẻ, email và link được che trước khi AI đọc. Cảnh báo chỉ hiện khi có ít nhất một dấu hiệu trong tin nhắn; các dữ kiện về tài khoản và giá chỉ đi kèm làm bằng chứng thêm (Bảng 2.1). Người dùng tắt được cảnh báo; cảnh báo hiện lại khi xuất hiện dấu hiệu mới chưa có lúc tắt. Từ cảnh báo, người dùng chặn và báo cáo người kia trong một lần bấm.

#figure(
  kind: table,
  caption: [Các dấu hiệu lừa đảo trong trò chuyện],
  table(
    columns: (1fr, 2.6fr),
    align: (left + top, left + top),
    table.header([*Nguồn*], [*Dấu hiệu hiện cho người dùng*]),
    [Tin nhắn], [Đòi chuyển tiền hoặc đặt cọc trước],
    [Tin nhắn], [Rủ chuyển sang Zalo, Telegram, Facebook],
    [Tin nhắn], [Gửi link lạ, giả trang thanh toán hoặc giao hàng],
    [Tin nhắn], [Xin mã OTP, mật khẩu hoặc thông tin thẻ],
    [Tin nhắn], [Mạo danh sàn, ngân hàng hoặc hãng vận chuyển],
    [Tin nhắn], [Gửi biên lai giả hoặc bảo "chuyển dư, hoàn lại giúp"],
    [Tin nhắn], [Hối thúc, ép quyết định ngay],
    [Dữ kiện], [Tài khoản mới tạo dưới 7 ngày],
    [Dữ kiện], [Giá thấp hơn tin tương tự từ 30% trở lên],
  ),
)

#anh-mobile(
  [Trả giá, chốt giá và cảnh báo lừa đảo trong hộp thư],
  ("chat-offering.png", "chat-agreed-cod.png", "inbox-scam.png"),
  nhan: ("Trả giá", "Chốt giá, chọn COD", "Cảnh báo lừa đảo"),
  cao: 8cm,
)

== Đơn COD qua GHTK và GHN

Người bán vào "Thiết lập giao COD" một lần (UC-ACC-04, Hình 2.5): khai địa chỉ lấy hàng và liên kết tài khoản GHTK hoặc GHN đứng tên mình. Với GHTK, người bán nhập email và mật khẩu, hệ thống đổi ngay thành mã kết nối của cửa hàng và không lưu mật khẩu [9]. Với GHN, người bán nhập mã kết nối và mã cửa hàng do GHN cấp, hệ thống kiểm tra với GHN trước khi lưu [8]. Mã kết nối được mã hóa và không bao giờ hiện ra ngoài, kể cả với nhân viên. Tiền thu hộ do hãng chuyển về tài khoản ngân hàng người bán đã khai với hãng, nên hệ thống không hỏi tài khoản ngân hàng.

#anh-web([Thiết lập giao COD trên website], "cod.png")

Khi có yêu cầu COD, người bán tạo đơn theo một trong hai cách (UC-DEAL-04). Cách thứ nhất, hệ thống tạo vận đơn trên tài khoản hãng của người bán: người bán chọn điểm lấy hàng, dịch vụ và khối lượng, rồi thấy phí thật do hãng báo. Cách thứ hai, người bán đã tạo vận đơn trên ứng dụng của hãng thì nhập mã; hệ thống đọc mã đó bằng tài khoản hãng của người bán, mã không thuộc tài khoản này bị từ chối ngay. Vận đơn luôn đặt chế độ thu hộ tiền hàng và cho người nhận xem hàng.

Trạng thái vận đơn do hãng báo về ngay khi có thay đổi; ngoài ra hệ thống hỏi lại hãng mỗi 2 giờ cho mọi vận đơn đang mở, phòng khi hãng báo sót (UC-DEAL-05). Bảng 2.2 là hệ quả của từng sự kiện với người mua, người bán và tin đăng.

#figure(
  kind: table,
  caption: [Sự kiện của đơn COD và hệ quả],
  table(
    columns: (1.6fr, 1fr, 2.2fr),
    align: (left + top, left + top, left + top),
    table.header([*Sự kiện*], [*Trạng thái đơn*], [*Hệ quả*]),
    [Người mua gửi yêu cầu COD], [Chờ tạo đơn], [Người mua có tối đa 3 đơn COD đang mở; tin vẫn đang bán],
    [Người bán tạo vận đơn hoặc nhập mã], [Đã gửi], [Tin được giữ cho người mua này, các yêu cầu COD khác trên tin tự hủy],
    [Một bên hủy trước khi gửi], [Đã hủy], [Tin tiếp tục bán],
    [Người bán không tạo đơn trong 3 ngày], [Đã hủy], [Tin tiếp tục bán],
    [Hãng chưa lấy hàng sau 3 ngày], [Đã hủy], [Vận đơn trên tài khoản hãng bị hủy theo, tin mở bán lại],
    [Người mua bấm đã nhận hàng], [Hoàn tất], [Tin thành đã bán, hai bên được mời đánh giá nhau],
    [Hãng báo đã giao, người mua không bấm], [Hoàn tất sau 3 ngày], [Như trên],
    [Người mua từ chối nhận, hoặc hãng báo không giao được], [Giao không thành], [Tin mở bán lại; người mua không mất tiền, hãng tính phí hai chiều vào tài khoản người bán],
  ),
)

Hãng có thể báo trùng hoặc báo sai thứ tự. Mỗi tin báo chỉ được tính một lần và đơn không lùi trạng thái, nên một lần giao không bị tính hai lần. Nếu người mua chưa nhận được hàng mà đơn đã báo giao, người mua gửi phiếu "Báo chưa nhận hàng" từ màn hình đơn (mục 2.5). Người bán gỡ liên kết hãng được khi không còn vận đơn đang mở ở hãng đó.

Phần vận chuyển đang chạy trên môi trường thử của GHTK và GHN. Bản chính thức sẽ bật khi nhóm ký hợp đồng đối tác với GHTK. Trên môi trường chạy thử của nhóm, một hãng giả lập trả trạng thái theo đúng cách hãng thật báo về để kiểm thử trọn luồng.

== Sau giao dịch: đánh giá, uy tín và hỗ trợ

Sau khi đơn hoàn tất, người mua đánh giá người bán và người bán đánh giá người mua, từ 1 đến 5 sao, kèm tối đa 500 chữ (UC-TRS-01). Đánh giá được ẩn cho đến khi bên kia cũng đánh giá, hoặc sau 7 ngày, để không ai viết theo số sao của người kia. Người được đánh giá trả lời được một lần; sau câu trả lời, đánh giá khóa lại, không sửa hay xóa được. Hồ sơ mỗi người hiện hai điểm riêng: khi bán và khi mua.

Trang "Uy tín của bạn" (UC-TRS-04, Hình 2.6) hiện các số liệu hệ thống đang giữ: số sao trung bình và số lượt đánh giá, số món đã bán, ngày tham gia, số người theo dõi, tỉ lệ trả lời tin nhắn trong 24 giờ (tính khi có từ 5 cuộc trò chuyện trong 90 ngày), số đơn COD và số đơn giao không thành trong 90 ngày, cùng hạn mức đang dùng.

#anh-web([Trang Uy tín của bạn trên website], "rep.png")

Người dùng liên hệ bộ phận hỗ trợ qua phiếu hỗ trợ, gồm ba loại: "Báo chưa nhận hàng" gắn với một đơn, "Xin thêm hãng" khi người bán dùng hãng vận chuyển hệ thống chưa đọc được, và "Yêu cầu khác" (Hình 2.7). Mỗi phiếu là một cuộc trò chuyện riêng giữa người dùng và bộ phận hỗ trợ, có ảnh, mốc đã đọc và thông báo như trò chuyện thường. Người dùng còn báo cáo được một tin đăng hoặc một người bán vi phạm (UC-MOD-01) và rút lại báo cáo.

#anh-web([Gửi phiếu hỗ trợ trên website], "support.png")

Thông báo đẩy về điện thoại có sáu công tắc riêng: tin nhắn, trả giá, đơn hàng, giảm giá, người đang theo dõi, đánh giá, cùng giờ yên lặng mặc định từ 22:00 đến 07:00. Ở phần tài khoản, người dùng xem các thiết bị đang đăng nhập và đăng xuất từng máy, quản lý tối đa 10 địa chỉ theo danh mục hành chính sau sáp nhập năm 2025, và xóa tài khoản khi không còn đơn đang chờ hoặc đang giao.

== Trang điều hành cho nhân viên

Theo nguyên tắc ở định kỳ 1, nhân viên vận hành chỉ xử lý những việc thống kê không tự giải quyết được. Trang điều hành là website riêng cho nhân viên, tách khỏi tài khoản khách hàng. Ở hàng đợi Hỗ trợ, nhân viên mở phiếu ngay trên cuộc trò chuyện của khách và trả lời dưới tên chung của sàn; hệ thống ghi lại nhân viên nào đã trả lời. Nhân viên có quyền tạm khóa một tài khoản, và mọi thao tác được ghi vào nhật ký.

Mỗi phiếu, báo cáo hoặc tài khoản có một trợ lý AI đi kèm. Trợ lý tự tra cứu qua nhiều bước [6]: đọc phiếu, đơn liên quan, lịch sử tin nhắn và các tài khoản có liên hệ, rồi trả lời nhân viên bằng bằng chứng, một đề xuất để nhân viên đánh dấu từng mục và một câu trả lời soạn sẵn cho khách. Trợ lý chỉ đọc: tạm khóa, ẩn tin hay gửi câu trả lời đều do nhân viên bấm, và mỗi thao tác có nút hoàn tác. Chi phí AI của trang điều hành có hạn mức 20 USD mỗi ngày. Phần trợ lý đã chạy ở mức trả lời câu hỏi kèm nguồn; phần tổng hợp nhiều phiếu một lúc đang làm.

== Ứng dụng, website và môi trường chạy

Ứng dụng Android dùng dữ liệu thật từ ngày 17/11/2026, giao diện giữ theo nguyên mẫu ở giai đoạn 1 [7]. Đăng nhập có ba cách: số điện thoại, email nhận mã, hoặc tài khoản Google; người chưa có số điện thoại được yêu cầu thêm số khi bắt đầu giao dịch. Ứng dụng tự nối lại khi mất mạng và nhận đủ các tin nhắn, thay đổi đơn đã lỡ.

Website (Hình 2.8) có các chức năng chính như ứng dụng: xem và tìm tin, lưu tin, trò chuyện tức thời, đăng tin, đơn COD, phiếu hỗ trợ và tài khoản. Để kiểm thử trên khối lượng giống thật, nhóm nạp một bộ dữ liệu thử gồm khoảng 7.000 tài khoản và hàng chục nghìn tin đăng có ảnh, trải đều 14 danh mục.

#anh-web([Trang chủ website với ba tab Gợi ý, Gần bạn, Mới nhất], "home.png")

Hệ thống chạy hai môi trường trên cụm máy chủ của nhóm: môi trường chạy thử để nhóm thử mỗi thay đổi, và môi trường chính thức chỉ nhận các bản đã thử xong. Nhân viên xem tình trạng hoạt động của hệ thống trên các bảng theo dõi, đăng nhập bằng tài khoản trang điều hành. Mô hình nghe tiếng Việt và mô hình hiểu ảnh chạy trên máy chủ của nhóm; các mô hình ngôn ngữ lớn đi qua một cổng chung có hạn mức chi phí mỗi ngày cho từng chức năng.
