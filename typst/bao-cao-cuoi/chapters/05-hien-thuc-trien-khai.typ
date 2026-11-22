#import "../../common/tokens.typ": *

// Ảnh chụp website, cùng kiểu chú thích với anh-mobile
#let anh-web(cap, tep, rong: 100%) = figure(
  box(stroke: 0.6pt + hairline, image("../../common/assets/web/" + tep, width: rong)),
  caption: cap,
  kind: image,
)

= HIỆN THỰC VÀ TRIỂN KHAI

Chương này trình bày hệ thống đã hiện thực theo từng phân hệ nghiệp vụ: người dùng làm gì, hệ thống kiểm những quy tắc nào và mỗi bên được bảo vệ ra sao. Thứ tự các mục đi theo vòng đời của một món hàng, từ lúc người bán tạo tài khoản, đăng tin, người mua tìm thấy, hai bên trò chuyện và trả giá, hàng được giao qua hãng vận chuyển, cho tới đánh giá, hỗ trợ và vận hành. Mọi chức năng chạy trên cùng một dịch vụ nền cho cả ứng dụng Android và website. Phần nền tảng kỹ thuật và cách triển khai được tóm tắt ở mục cuối.

== Phân hệ tài khoản

Người dùng đăng nhập bằng một trong ba cách (UC-ACC-01, Hình 5.1): số điện thoại được xác minh bằng mã SMS hoặc trực tiếp qua SIM, tài khoản Google, hoặc mã sáu chữ số gửi qua email. Ở lần đăng nhập đầu tiên, tài khoản được tạo tự động, nên đăng ký và đăng nhập là một thao tác. Một tài khoản giữ được cả số điện thoại lẫn email. Người chỉ xem và tìm không phải khai số điện thoại; số điện thoại đã xác minh là điều kiện để đăng tin, mở phiên trả giá hay mở cuộc trò chuyện (BR-ACC-03), và ứng dụng hỏi thêm số khi người dùng bắt đầu một việc như vậy. Phản hồi khi xin mã email giống hệt nhau dù email đã có tài khoản hay chưa (BR-ACC-02), nên kẻ gian không dò được danh sách người dùng của hệ thống.

#anh-web([Đăng nhập trên website bằng Google, số điện thoại hoặc email], "signin.png")

Một tài khoản dùng chung cho cả mua và bán, không có vai trò người bán riêng. Trong mục thiết bị đang đăng nhập (UC-ACC-02), người dùng đăng xuất từng thiết bị hoặc mọi thiết bị khác, máy đang dùng giữ đăng nhập; thao tác này đòi người dùng vừa đăng nhập trong 15 phút gần nhất. Sổ địa chỉ giữ tối đa 10 địa chỉ, mỗi địa chỉ chọn theo danh mục 34 tỉnh và 3.321 phường/xã sau sáp nhập năm 2025; ứng dụng gợi ý xã gần nhất từ vị trí hiện tại. Người dùng chặn được một tài khoản khác (UC-ACC-05); việc chặn có hiệu lực hai chiều, hai bên không nhắn tin, không mở phiên trả giá trên tin của nhau, và tin của người kia không còn hiện trong tìm kiếm và trang chủ (BR-ACC-01). Người dùng xóa được tài khoản của mình khi không còn đơn đang chờ hoặc đang giao.

== Phân hệ đăng tin với AI điền giúp

Đăng tin (UC-LST-01) bắt đầu từ món đồ, không bắt đầu từ biểu mẫu. Người bán có ba cách. Cách thứ nhất là quay một đoạn video, xoay món đồ và nói giá muốn bán; hệ thống cắt các khung hình rõ nhất, nhận dạng tiếng nói tiếng Việt, rồi mô hình ngôn ngữ lớn (LLM) đọc cả hai để điền tên, danh mục, tình trạng, thông số, mô tả và giá người bán nói. Cách thứ hai là chụp từ một đến mười ảnh; AI điền theo những gì ảnh cho thấy. Cách thứ ba dành cho người đã bán trên Chợ Tốt: dán link tin cũ, hệ thống lấy ảnh và nội dung, đồng thời bỏ số điện thoại và Zalo trong mô tả. Mỗi người có tối đa 30 lượt đọc video, 60 lượt đọc ảnh và 30 lượt đọc link trong 24 giờ. Người bán sửa mọi ô trước khi đăng.

Tin không có phần khai vết và AI không chỉ ra vết nào trên hàng (BR-LST-01). Mỗi người đánh giá một vết xước hay vết ố trên đồ cũ một khác, nên vết do mô hình nêu ra không phải dữ kiện chắc chắn, và nó dễ thành cớ để người mua khiếu nại khiến người bán rời hệ thống. Tình trạng thật của món hàng do người mua tự xem khi đồng kiểm tại cửa (BR-DEAL-02).

Bước "Giá" cho người bán thấy thị trường của món đồ: tối đa 12 tin tương tự đang bán và đã bán kèm số ngày bán, số người mua đang theo dõi câu tìm khớp với món này, và hai mức gợi ý. "Giá thị trường" là giá giữa của các tin tương tự, kèm số ngày bán thường gặp. "Bán nhanh" là giá giữa của nửa số tin bán nhanh hơn, chỉ hiện khi thấp hơn giá thị trường. Nháp tin đăng lưu trên máy chủ, tối đa 20 nháp, nháp không sửa trong 30 ngày thì bị xóa, nên người bán bắt đầu trên điện thoại và đăng tiếp trên website được.

Trước khi tin được lưu, hệ thống kiểm các giới hạn của BR-LST-03: tiêu đề 1 đến 70 ký tự, giá nguyên đồng từ 10.000 đến 1.000.000.000, mô tả không quá 1.500 ký tự, tối đa 20 thông số. Tài khoản đang bị tạm khóa không đăng được, và mỗi người có tối đa 20 tin đang bán (BR-LST-02). Sau khi bấm Đăng, tin ở trạng thái đang xử lý: hệ thống kiểm định dạng ảnh, xoay ảnh theo hướng chụp, tạo bản lớn và bản thu nhỏ, đồng thời xóa toàn bộ thông tin kèm theo ảnh, kể cả tọa độ do điện thoại ghi vào. Mọi ảnh xử lý xong thì tin chuyển sang đang bán và được lập chỉ mục cho tìm kiếm; có ảnh hỏng thì tin bị từ chối và người bán được báo để thay ảnh. Ảnh đã tải lên mà không gắn vào tin nào sau 24 giờ bị xóa.

Ở mục Tin của bạn (UC-LST-02), người bán sửa nội dung, đổi giá, ẩn hoặc hiện lại tin, đánh dấu đã bán khi món được bán ngoài ứng dụng, đăng lại một tin cũ, hoặc xóa tin, và xem lượt xem, lượt hỏi, lượt lưu của từng tin. Tin đang giữ chỗ cho một đơn thì không sửa, ẩn hay xóa được, để người mua đang chờ hàng không thấy món của mình đổi mô tả giữa chừng. Đẩy tin và gói người bán (UC-LST-03) đã có thiết kế nhưng chưa bật trong bản phát hành.

== Phân hệ tìm kiếm và khám phá

Người mua gõ một câu như cách nhờ người quen, ví dụ "xe đạp cũ dưới 3 triệu" (UC-DSC-01). Mô hình ngôn ngữ đọc câu một lần và đổi thành các điều kiện ưu tiên; kết quả hiện kèm các chip điều kiện, như "Xe đạp" và "Dưới 3 tr", cùng một câu ngắn cho biết hệ thống đã hiểu câu tìm thế nào (BR-DSC-01). Khi AI hiểu sai, người mua tắt chip đó và kết quả cập nhật ngay, không phải gõ lại câu và không phải chờ AI chạy lại. Cách đọc của một câu được lưu 7 ngày, nên người khác tìm cùng câu không phải chờ mô hình. Mô hình lỗi hoặc quá 4 giây thì hệ thống tìm bằng nguyên câu gốc, chỉ không có chip.

Kết quả được ghép từ ba danh sách trên các tin đang bán: khớp từ khóa theo BM25 [12], tìm theo nghĩa bằng vector văn bản BGE-M3 [4], và so ảnh bằng vector SigLIP 2 [13]. Để phần so ảnh dùng được, mô hình viết thêm một mô tả ngắn về hình dáng món đồ từ câu tìm. Các danh sách được hợp nhất theo thứ hạng [5], cộng thêm điểm ưu tiên cho danh mục, giá, tình trạng, độ gần và độ mới mà mô hình đã đọc được. Nhờ so theo nghĩa, câu "xe đi làm" vẫn tìm thấy tin ghi "xe đạp thành phố". Tin đang giữ chỗ, đã bán, đang ẩn, đã xóa hay của người đã chặn mình không xuất hiện trong kết quả.

Cùng cơ chế đó cho thêm hai cách tìm. Người mua đã đăng nhập tìm được bằng một tấm ảnh chụp món đồ. Trang chi tiết tin có mục tin tương tự, dựa trên văn bản, ảnh, danh mục và khoảng giá ±30% của tin đang xem. Ngoài ô tìm kiếm, người mua duyệt danh mục và lọc theo giá, tình trạng, khoảng cách (UC-DSC-02). Trang chủ có ba tab: "Gợi ý" xếp theo danh mục người mua đã lưu, đã tìm và đã xem trong 30 ngày; "Gần bạn" xếp theo khoảng cách và độ mới trong bán kính 50 km; "Mới nhất" xếp theo thời gian đăng.

Người mua không phải tìm lại mỗi ngày (UC-DSC-03). Một câu tìm được theo dõi thì cứ 30 phút hệ thống tìm tin mới khớp và báo số tin mới. Tin đã lưu đặt được mức giá báo, khi người bán hạ giá xuống thấp nhất mới dưới mức đó thì người mua nhận thông báo. Người mua theo dõi được một người bán để biết khi người đó đăng tin mới, và ẩn những tin không muốn thấy lại. Trang người bán (UC-DSC-04) hiện số sao khi bán và khi mua, số món đã bán, ngày tham gia, số người theo dõi và các tin đang bán. Hình 5.2 là kết quả tìm trên website, Hình 5.3 là chi tiết một tin.

#anh-web([Kết quả tìm kiếm bằng câu tự nhiên trên website], "search.png")

#anh-web([Chi tiết tin đăng trên website], "listing.png")

== Phân hệ trò chuyện, trả giá và cảnh báo lừa đảo

Mọi trao đổi giữa hai bên diễn ra trong cuộc trò chuyện gắn với tin đăng (UC-DEAL-01). Mỗi cặp người dùng có một cuộc trò chuyện chung, trong đó hiện mọi phiên trả giá giữa hai người. Tin nhắn đến tức thời, hai bên thấy "đang nhập…" và mốc đã đọc, gửi được ảnh, trả lời một tin cụ thể bằng cách vuốt tin đó, và link tin đăng hiện thành thẻ có ảnh và giá. Hộp thư tìm được theo tên người, tên tin và nội dung tin nhắn, không cần gõ dấu. Mỗi bước của phiên trả giá và của đơn hiện thành một tin nhắn hệ thống trong cuộc trò chuyện, và tạo một thông báo cho bên kia (FR-SHR-02).

Trả giá (UC-DEAL-02) theo BR-DEAL-03. Giá là bội số của 1.000 đ. Giá người mua trả không thấp hơn nửa giá niêm yết, làm tròn lên 1.000 đ, và phải thấp hơn giá niêm yết hoặc giá người bán vừa phản lại; giá phản của người bán phải cao hơn giá trả và thấp hơn giá niêm yết. Tại mỗi thời điểm chỉ có một giá đang mở, và giá mở không tự hết hạn. Ứng dụng hiện sẵn khoảng giá hợp lệ trên thanh chọn giá, nên người dùng hiếm khi gặp lỗi từ chối. Khi bên kia chấp nhận, thao tác chấp nhận mang theo đúng mức giá người đó đã thấy; nếu giá vừa thay đổi thì lời chấp nhận bị từ chối và người dùng được hiện giá mới. Người mua cũng có thể chấp nhận ngay giá niêm yết.

Sau mỗi tin nhắn có chữ, hệ thống kiểm tra 20 tin nhắn gần nhất của cuộc trò chuyện để tìm dấu hiệu lừa đảo (FR-TRS-04). Số điện thoại, số tài khoản, số thẻ, email và link được che trước khi AI đọc. Bảng 5.1 là danh sách dấu hiệu mà bộ phát hiện được chọn. Khi có cảnh báo, hộp thư gắn nhãn "Nghi lừa đảo" cho cuộc trò chuyện và màn hình trò chuyện hiện một dải cảnh báo liệt kê các dấu hiệu. Người dùng tắt được dải cảnh báo; nó hiện lại khi xuất hiện một dấu hiệu trong tin nhắn chưa có lúc tắt. Từ cảnh báo, người dùng chặn và báo cáo người kia trong một lần bấm, và hoàn tác được nếu bấm nhầm.

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
    [Tin nhắn], [Mạo danh hệ thống, ngân hàng hoặc hãng vận chuyển],
    [Tin nhắn], [Gửi biên lai giả hoặc bảo "chuyển dư, hoàn lại giúp"],
    [Tin nhắn], [Hối thúc, ép quyết định ngay],
    [Dữ kiện], [Tài khoản mới tạo dưới 7 ngày],
    [Dữ kiện], [Giá thấp hơn tin tương tự từ 30% trở lên, khi có ít nhất 5 tin để so],
  ),
)

Hình 5.4 là luồng trên ứng dụng: người mua trả giá bằng thanh chọn giá (a), hai bên chốt giá và người mua chọn giao COD (b), và hộp thư với một cuộc trò chuyện bị gắn cảnh báo (c).

#anh-mobile(
  [Trả giá, chốt giá và cảnh báo lừa đảo trên ứng dụng],
  ("chat-offering.png", "chat-agreed-cod.png", "inbox-scam.png"),
  nhan: ("Trả giá", "Chốt giá, chọn COD", "Cảnh báo lừa đảo"),
  cao: 9cm,
)

== Phân hệ đơn COD và kết nối hãng vận chuyển

Chốt giá không giữ hàng (BR-DEAL-04). Nhiều người mua có thể cùng chốt một tin và cùng gửi yêu cầu COD (UC-DEAL-03) kèm một địa chỉ trong sổ địa chỉ; người bán chọn gửi cho ai. Mỗi người mua có tối đa 3 đơn COD đang mở (BR-DEAL-06), nên một tài khoản mới không thể đặt hàng loạt rồi từ chối nhận. Đơn mang mã dạng SN-100001 và ở trạng thái chờ tạo đơn; người bán có 3 ngày để gửi hàng, quá hạn thì đơn tự hủy. Hai bên muốn gặp xem hàng thì tự hẹn trong tin nhắn.

Hệ thống kết nối trực tiếp với Giao Hàng Tiết Kiệm [17] và Giao Hàng Nhanh [16]. Người bán liên kết hãng một lần ở mục Thiết lập giao COD (UC-ACC-04, Hình 5.5), mỗi hãng tối đa một tài khoản. Với GHTK, người bán nhập email và mật khẩu tài khoản của hãng; hệ thống đổi ngay thành mã kết nối của cửa hàng và không lưu mật khẩu. Với GHN, người bán nhập mã kết nối và mã cửa hàng lấy từ trang quản lý của hãng, hệ thống kiểm với GHN trước khi lưu. Mã kết nối được mã hóa và không bao giờ trả ra ngoài. Tiền thu hộ do hãng chuyển thẳng vào tài khoản ngân hàng người bán đã khai với hãng, không đi qua hệ thống (BR-DEAL-01), và vận đơn nằm trên tài khoản của người bán nên hệ thống cũng không thu phí vận chuyển. Người bán gỡ liên kết được khi không còn vận đơn đang mở ở hãng đó.

#anh-web([Thiết lập giao COD trên website], "cod.png")

Người bán tạo đơn (UC-DEAL-04) theo một trong hai cách. Cách thứ nhất, hệ thống tạo vận đơn trên tài khoản hãng của người bán: người bán chọn điểm lấy hàng trong danh sách điểm của hãng hoặc trong sổ địa chỉ, chọn dịch vụ và nhập khối lượng tới 20 kg, rồi thấy phí thật do hãng báo. Vận đơn thu hộ đúng giá đã chốt, đặt chế độ người nhận trả phí vận chuyển và cho xem hàng; mã đơn của hệ thống được dùng làm mã đơn phía hãng, nên một lần tạo lại sau sự cố tìm thấy đúng vận đơn đã tạo. Cách thứ hai, người bán đã tạo vận đơn trên ứng dụng của hãng thì nhập mã; hệ thống đọc vận đơn đó bằng tài khoản của người bán, mã không thuộc tài khoản này bị từ chối ngay (BR-DEAL-12). Người bán dùng hãng khác thì gửi phiếu "Xin thêm hãng".

Ngay khi người bán gửi, đơn chuyển sang đã gửi, tin chuyển sang đang giữ chỗ và mọi yêu cầu COD khác trên tin đó tự hủy với lý do "đã gửi cho người khác"; người mua bị hủy được báo ngay để tìm món khác. Quy trình gửi hàng gồm nhiều bước liên tiếp: kiểm đơn, tạo hoặc đọc vận đơn, giữ chỗ tin, lưu đơn, hủy các yêu cầu còn lại. Mỗi bước được ghi lại khi hoàn tất, nên nếu máy chủ dừng giữa chừng thì quy trình chạy tiếp từ bước đã xong, không gọi hãng lần thứ hai. Nếu tin đã đóng trước khi kịp giữ chỗ, vận đơn vừa tạo bị hủy trên hãng.

Sau khi gửi, mọi diễn biến do hãng báo về (UC-DEAL-05); không bên nào phải chụp hay nộp bằng chứng. Hãng báo tức thời khi có thay đổi, và hệ thống hỏi lại hãng mỗi 2 giờ cho mọi vận đơn đang mở, phòng khi hãng báo sót. Hãng có thể gửi một thông báo nhiều lần hoặc không theo thứ tự; mỗi thông báo chỉ được tính một lần và đơn không lùi trạng thái. Các bước trung gian như đang trung chuyển chỉ dùng để hiện lộ trình kiện hàng cho hai bên. Bảng 5.2 là cách quy đổi trạng thái của hai hãng và các thời hạn tự động.

#figure(
  kind: table,
  caption: [Trạng thái hãng báo, thời hạn và hệ quả với đơn],
  table(
    columns: (1.3fr, 1.1fr, 0.9fr, 1.7fr),
    align: left + top,
    table.header([*Sự kiện*], [*Mã GHTK*], [*Đơn*], [*Hệ quả*]),
    [Hãng chưa lấy hàng sau 3 ngày], [1, 2], [Đã hủy], [Vận đơn bị hủy trên hãng, tin mở bán lại],
    [Hãng đã lấy hàng, đang giao], [3, 4], [Đã gửi], [Chỉ ghi vào lộ trình kiện hàng; từ đây không hủy được],
    [Hãng báo đã giao], [5, 6], [Đã gửi], [Hẹn 3 ngày tự hoàn tất],
    [Người mua bấm đã nhận, hoặc hết 3 ngày], [], [Hoàn tất], [Tin và phiên trả giá chuyển sang đã bán, hai bên được mời đánh giá],
    [Không giao được, đang hoàn, đã hoàn], [9, 20, 21], [Giao không thành], [Tin về đang bán; người mua không mất tiền, hãng tính phí hai chiều vào tài khoản người bán],
  ),
)

Trạng thái của GHN được quy về cùng ba nhóm đang giao, đã giao và giao không thành. Lúc shipper đến, người mua mở hàng xem trước rồi mới trả tiền (BR-DEAL-05). Sau khi trả tiền, hệ thống không có cơ chế đòi lại; mục Trợ giúp ghi rõ điều này (BR-DEAL-09). Nếu hàng không đúng, người mua từ chối nhận: hàng quay về người bán, người mua không mất đồng nào và tin trở về đang bán (BR-DEAL-08). Người mua hoặc người bán hủy được đơn khi người bán chưa gửi (UC-DEAL-06, BR-DEAL-07).

Phần kết nối hãng được viết theo tài liệu API của GHTK [17] và GHN [16], gồm liên kết tài khoản, báo phí, tạo, đọc, hủy vận đơn và nhận trạng thái. Phần này được kiểm thử với một hãng giả lập trả lời đúng định dạng tài liệu đó, chưa chạy với hệ thống thật của hãng: ký hợp đồng đối tác và kết nối với hệ thống thật của hãng nằm ngoài phạm vi đồ án.

== Phân hệ đánh giá, uy tín, hỗ trợ và thông báo

Sau khi đơn hoàn tất, người mua đánh giá người bán và người bán đánh giá người mua (UC-TRS-01), từ 1 đến 5 sao kèm lời đánh giá không quá 500 ký tự. Đánh giá ẩn cho đến khi bên kia cũng đánh giá, hoặc sau 7 ngày. Người được đánh giá trả lời được một lần; trước câu trả lời, người viết sửa hoặc xóa được trong 7 ngày, sau câu trả lời thì đánh giá khóa lại (BR-TRS-04). Đánh giá không kèm ảnh: bằng chứng về một món hàng lỗi thuộc về báo cáo hoặc phiếu hỗ trợ.

Trang "Uy tín của bạn" (UC-TRS-04, Hình 5.6) hiện các số liệu hệ thống đang giữ (BR-TRS-05): số sao trung bình và số lượt đánh giá, số món đã bán, ngày tham gia, số người theo dõi, tỉ lệ trả lời tin nhắn trong 24 giờ (chỉ tính khi có từ 5 cuộc trò chuyện trong 90 ngày), số đơn COD và số đơn giao không thành trong 90 ngày, cùng hạn mức đang dùng. Một cuộc trò chuyện được tính khi người khác mở nó về một tin của mình; nó được tính là trả lời kịp khi tin nhắn đầu của mình đến trong 24 giờ sau tin nhắn đầu của người kia.

#anh-web([Trang Uy tín của bạn trên website], "rep.png")

Người dùng liên hệ với hệ thống qua phiếu hỗ trợ (UC-MOD-09, Hình 5.7), gồm ba loại: "Báo chưa nhận hàng" gắn với một đơn đã báo giao, "Xin thêm hãng" khi người bán dùng hãng vận chuyển hệ thống chưa đọc được, và "Yêu cầu khác", thay cho mục góp ý trước đây. Mỗi phiếu là một cuộc trò chuyện riêng giữa người dùng và bộ phận hỗ trợ, có ảnh, mốc đã đọc và thông báo như trò chuyện thường. Người dùng tìm các phiếu của mình ở mục Trợ giúp, không lẫn vào hộp thư. Người dùng còn báo cáo được một tin đăng hoặc một người bán vi phạm (UC-MOD-01), chọn lý do hàng cấm, hàng giả, lừa đảo hoặc khác, và rút lại báo cáo.

#anh-web([Gửi phiếu hỗ trợ trên website], "support.png")

Thông báo hiện trong ứng dụng và được đẩy tới điện thoại khi ứng dụng đóng. Người dùng có sáu công tắc riêng cho tin nhắn, trả giá, đơn COD, giảm giá, người đang theo dõi và đánh giá, cùng giờ yên lặng mặc định từ 22:00 đến 07:00 theo giờ Việt Nam. Thông báo đẩy của tin nhắn không lặp lại trong danh sách thông báo, vì hộp thư đã liệt kê tin nhắn.

== Phân hệ trang điều hành

Nhân viên chỉ xử lý những việc hai bên không tự giải quyết được (BR-MOD-01): phiếu hỗ trợ, hàng cấm và hàng giả bị báo cáo, lừa đảo có dấu hiệu tổ chức, và yêu cầu hợp lệ từ cơ quan có thẩm quyền. Giá cả và tình trạng hàng là việc giữa hai bên. Trang điều hành là một website riêng. Ở hàng đợi Hỗ trợ, nhân viên mở phiếu ngay trên cuộc trò chuyện của người dùng và trả lời dưới tên chung của hệ thống; hệ thống ghi lại nhân viên nào đã trả lời. Nhân viên tạm khóa được một tài khoản kèm lý do (UC-MOD-02); tài khoản bị tạm khóa không đăng tin, không trả giá và không yêu cầu COD được, nhưng vẫn rút giá, từ chối và hủy được (BR-MOD-02).

Mỗi phiếu, báo cáo hoặc tài khoản có một trợ lý AI đi kèm (UC-MOD-07, UC-MOD-08). Khi có phiếu hoặc báo cáo mới, trợ lý AI chạy nền: đọc phiếu, đơn liên quan, vận đơn, lịch sử tin nhắn và các tài khoản có liên hệ, rồi để sẵn bằng chứng, một đề xuất và một câu trả lời soạn sẵn cho người dùng. Nhân viên đánh dấu từng mục của đề xuất, nhắn để trợ lý AI sửa, rồi bấm làm theo; mỗi thao tác có nút hoàn tác. Một lượt hỏi trợ lý AI dài tối đa 60 giây, quá hạn thì nhân viên hỏi lại hoặc cho chạy nền và được báo khi xong. Chi phí AI của trang điều hành có hạn mức 20 USD mỗi ngày; hết hạn mức thì trợ lý AI ngừng trả lời, các chức năng khác của trang điều hành vẫn dùng được. Cuộc trò chuyện với trợ lý AI được giữ 180 ngày.

Nhân viên đăng nhập bằng email và mật khẩu; sai 5 lần thì email bị khóa 15 phút, phiên dài 8 giờ và không tự gia hạn. Quản trị viên làm được mọi việc của điều phối viên, thêm việc quản lý tài khoản điều phối viên (UC-MOD-04). Mỗi thao tác thay đổi dữ liệu của nhân viên được ghi vào nhật ký kiểm toán cùng lúc với chính thay đổi đó; quản trị viên tra cứu nhật ký theo nhân viên, loại thao tác và thời gian (UC-MOD-05). Nhân viên đã đăng nhập mở được các bảng giám sát vận hành mà không phải đăng nhập lại.

== Website và ứng dụng Android

Website (Hình 5.8) có các chức năng chính như ứng dụng: xem và tìm tin, lưu tin, trò chuyện tức thời, đăng tin, đơn COD, đánh giá, phiếu hỗ trợ và tài khoản. Trang được dựng ở phía máy chủ của website; máy chủ này đứng giữa trình duyệt và dịch vụ nền, giữ mã phiên trong cookie mà mã chạy trên trình duyệt không đọc được, và tự làm mới phiên khi hết hạn. Trình duyệt chỉ nhận dữ liệu đã dựng sẵn và kết nối thời gian thực cho tin nhắn.

#anh-web([Trang chủ website với ba tab Gợi ý, Gần bạn, Mới nhất], "home.png")

Ứng dụng Android viết bằng Kotlin và Jetpack Compose, chạy từ Android 12, có giao diện tối và hỗ trợ cỡ chữ lớn (NFR-UX-01). Bản phát hành không còn dữ liệu giả lập: một bước kiểm tra tự động khi đóng gói báo lỗi nếu bản phát hành còn tham chiếu tới phần dữ liệu giả. Phần gọi dịch vụ nền được sinh từ bản đặc tả chung, nên ứng dụng và dịch vụ nền không lệch nhau về tên trường hay mã lỗi. Ứng dụng tự nối lại khi mất mạng và nhận đủ phần đã lỡ, tự làm mới phiên, và bấm lại một nút khi mạng chập chờn không tạo hai yêu cầu.

== Nền tảng và triển khai

Dịch vụ nền viết bằng Go, chia thành các phân hệ ở Chương 4; dữ liệu nằm trong PostgreSQL 18 với pg_search của ParadeDB [19] cho tìm theo từ khóa và pgvector [20] cho tìm theo nghĩa. Các quy trình nhiều bước như đăng nhập, đăng tin, gửi hàng và các thời hạn của đơn chạy trên Restate [21], công cụ ghi lại kết quả từng bước để quy trình chạy tiếp sau sự cố. Ảnh và video lưu ở một kho lưu trữ đối tượng riêng. Mô hình nhận dạng tiếng nói tiếng Việt, mô hình nhúng ảnh và phần cắt khung hình video chạy trên bộ xử lý của máy chủ trong một tiến trình riêng; các mô hình ngôn ngữ và mô hình nhúng văn bản đi qua một cổng chung có khóa và hạn mức chi phí theo từng chức năng.

Hệ thống chạy hai môi trường trên một cụm Kubernetes của nhóm: môi trường thử nhận mỗi thay đổi đã qua kiểm thử, môi trường chính thức chỉ nhận các bản phát hành được đánh dấu. Mỗi bản phát hành ghi phiên bản của mọi thành phần cùng lúc, nên biết chính xác môi trường chính thức đang chạy bộ phiên bản nào. Cấu trúc cơ sở dữ liệu được cập nhật trước khi phiên bản mới thay phiên bản cũ. Trên máy phát triển, cùng các thành phần chạy bằng Docker Compose, dùng chung tệp cấu hình với cụm máy chủ. Mọi yêu cầu đều được ghi vết; khi xảy ra lỗi, phản hồi trả về một mã truy vết để nhóm phát triển tìm đúng yêu cầu đó trên màn hình quan trắc. Để kiểm thử trên khối lượng giống thật, nhóm nạp một bộ dữ liệu thử gồm khoảng 7.000 tài khoản và hàng chục nghìn tin đăng có ảnh trải đều các danh mục.
