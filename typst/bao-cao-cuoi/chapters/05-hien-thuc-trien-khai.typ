#import "../../common/tokens.typ": *

= HIỆN THỰC VÀ TRIỂN KHAI

Chương này trình bày hệ thống đã hoàn thành theo từng phân hệ nghiệp vụ: người dùng làm gì, hệ thống kiểm những quy tắc nào và mỗi bên được bảo vệ ra sao. Thứ tự các mục đi theo vòng đời của một món hàng, từ lúc người bán tạo tài khoản, đăng tin, người mua tìm thấy, hai bên thương lượng, hàng được giao qua hãng vận chuyển, cho tới phần đánh giá, uy tín và vận hành. Phần nền tảng kỹ thuật và cách triển khai được tóm tắt ở mục cuối.

== Phân hệ tài khoản và xác minh danh tính

Người dùng đăng nhập bằng số di động Việt Nam hoặc email, không có mật khẩu (UC-01). Hệ thống gửi một mã sáu chữ số có hiệu lực 5 phút; nhập sai 5 lần thì mã bị khóa và phải xin mã mới. Ở lần đăng nhập đầu tiên, tài khoản được tạo tự động, nên đăng ký và đăng nhập là một thao tác. Mỗi đích chỉ nhận tối đa một mã trong 45 giây và 5 mã trong một giờ, mỗi địa chỉ mạng tối đa 20 mã trong một giờ; các hạn mức này chặn việc dùng hệ thống để gửi tin nhắn rác và giới hạn chi phí SMS. Phản hồi khi xin mã giống hệt nhau dù số điện thoại đã có tài khoản hay chưa (BR-21), nên kẻ gian không dò được danh sách khách hàng của sàn.

Một tài khoản dùng chung cho cả mua và bán, không có vai trò người bán riêng. Trong mục quản lý phiên (UC-02), người dùng thấy danh sách thiết bị đang đăng nhập, đăng xuất từng thiết bị hoặc đăng xuất mọi thiết bị khi nghi bị lộ; thao tác sau đòi người dùng vừa đăng nhập trong 15 phút gần nhất. Phiên kéo dài tối đa 60 ngày và hết hạn nếu 30 ngày không dùng. Người dùng có thể chặn một tài khoản khác (UC-05); việc chặn có hiệu lực hai chiều, hai bên không nhắn tin và không mở thương lượng trên tin của nhau (BR-20).

Xác minh danh tính điện tử (UC-03) là điều kiện để đăng tin (BR-04). Người dùng chụp hai mặt căn cước công dân, áp điện thoại vào thẻ để ứng dụng đọc chip, rồi quét khuôn mặt. Ứng dụng dùng dãy ký tự máy đọc ở mặt sau thẻ để mở chip, nên chỉ người đang cầm thẻ thật mới đọc được. Khi chip đọc được và khuôn mặt khớp với ảnh trong chip, tài khoản được xác minh ngay và nhận 100 điểm uy tín. Điện thoại không đọc được chip hoặc thẻ bị lỗi chip thì hồ sơ chuyển sang chờ duyệt, điều phối viên xem trong một đến hai ngày rồi chấp nhận hoặc từ chối. Lý do của quy tắc này nằm ở chế tài: sàn không phạt tiền mà chỉ rút quyền, và việc rút quyền chỉ có tác dụng khi người bị chế tài không thể mở ngay một tài khoản mới để đăng lại món hàng cũ.

== Phân hệ đăng tin với AI điền giúp

Đăng tin (UC-06) bắt đầu từ ảnh, không bắt đầu từ biểu mẫu. Người bán chụp từ một đến mười ảnh bằng máy ảnh trong ứng dụng, chọn ảnh có sẵn trong thư viện, hoặc quay một đoạn video ngắn; ảnh đầu tiên làm ảnh bìa. Mỗi ô ảnh trên màn hình đăng tin mang dấu cho biết ảnh lấy từ máy ảnh hay từ thư viện.

AI đọc ảnh và điền sẵn danh mục, tiêu đề, mức tình trạng theo thang ba mức Mới, Như mới, Đã dùng và các thông số nhìn thấy được. Người bán sửa mọi trường trước khi đăng. Tin không có phần khai vết và AI không chỉ ra vết nào trên hàng (BR-02). Mỗi người đánh giá một vết xước hay vết ố trên đồ cũ một khác, nên vết do mô hình nêu ra không phải dữ kiện chắc chắn, và nó dễ thành cớ để người mua khiếu nại khiến người bán rời sàn. Tình trạng thật của món hàng do người mua tự xem khi đồng kiểm tại cửa (BR-03).

Trước khi tin được lưu, hệ thống kiểm các giới hạn của BR-05: tiêu đề 1 đến 70 ký tự, giá nguyên đồng từ 10.000 đến 1.000.000.000, mô tả không quá 1.500 ký tự, tối đa 20 thông số. Vị trí lưu theo phường hoặc xã, lấy tọa độ tâm xã, không lưu vị trí thật của người bán. Tài khoản chưa xác minh danh tính hoặc đang bị tạm khóa không đăng được; số tin đang bán tối đa theo bậc uy tín là 5, 20, 20 và 20. Sau khi bấm Đăng, tin ở trạng thái đang xử lý: hệ thống kiểm định dạng ảnh, xoay ảnh theo hướng chụp, tạo bản lớn và bản thu nhỏ, đồng thời xóa toàn bộ thông tin kèm theo ảnh, kể cả tọa độ vị trí do điện thoại ghi vào. Mọi ảnh xử lý xong thì tin chuyển sang đang bán; có ảnh hỏng thì tin bị từ chối và người bán được báo để thay ảnh. Ảnh đã tải lên mà không gắn vào tin nào sau 24 giờ sẽ bị xóa.

Ở mục quản lý tin (UC-07), người bán sửa nội dung, đổi giá, ẩn hoặc hiện lại tin, đánh dấu đã bán khi món được bán ngoài ứng dụng, hoặc xóa tin. Tin đang giữ chỗ cho một đơn thì không sửa, ẩn hay xóa được, để người mua đang chờ hàng không thấy món của mình đổi mô tả giữa chừng. Doanh thu của sàn đến từ đẩy tin và gói người bán (UC-08): gói Cơ bản miễn phí, gói Plus 49.000 đ mỗi tháng kèm 4 lượt đẩy, gói Cửa hàng 199.000 đ mỗi tháng kèm 20 lượt đẩy; đẩy tin lẻ có giá 15.000 đ cho một ngày và 35.000 đ cho ba ngày, người bán bậc Xuất sắc được giảm 20%. Tin đang có đơn không được đẩy, và không gói nào mua được quyền COD hay bậc uy tín (BR-16).

Hình 5.1 là luồng đăng tin trên ứng dụng. Màn hình (a) hiện ba ảnh vừa chụp và thông báo AI đang đọc ảnh. Màn hình (b) là biểu mẫu đã được điền sẵn, phía dưới hiện tấm xác minh danh tính gồm ba bước căn cước, chip và khuôn mặt, chặn nút Đăng vì tài khoản chưa xác minh. Màn hình (c) xác nhận tin đã đăng và cho phép xem tin hoặc chia sẻ.

// Hai hình một trang: mỗi dãy ảnh cao 9cm, hai dãy vừa một trang A4.
#let cap-doi(..hinh) = place(top, float: true, clearance: 1.2em,
  stack(spacing: 1.4em, ..hinh.pos().map(h => anh-mobile(h.at(0), h.at(1), nhan: h.at(2), cao: 9cm))))

#cap-doi(
  ([Đăng tin với AI điền giúp], ("sell-reading.png", "sell-filled-gate.png", "sell-done.png"),
    ("AI đọc ảnh", "Đòi xác minh", "Đã đăng")),
  ([Khám phá và tìm kiếm bằng câu tự nhiên], ("home.png", "results.png", "detail.png"),
    ("Trang chủ", "Kết quả có chip", "Chi tiết tin")),
)

== Phân hệ tìm kiếm với AI agent

Từ phía người mua, tìm kiếm (UC-09) chỉ có một ô nhập. Người mua gõ hoặc nói một câu như cách nhờ người quen, ví dụ "xe đạp đi làm dưới 3 triệu" hay "quà sinh nhật cho bạn tầm 500 nghìn, gần đây thôi". AI agent đọc câu, tách mục tiêu khỏi các ràng buộc rồi trả về ba thứ: danh sách tin phù hợp, một dãy chip ràng buộc và một câu diễn giải ngắn cho biết agent đã hiểu yêu cầu thế nào. Mỗi ràng buộc agent đặt ra đều hiện thành một chip có biểu tượng lấp lánh để người mua phân biệt với bộ lọc tự chọn (BR-18). Khi agent hiểu sai, chẳng hạn đặt khoảng giá quá hẹp, người mua sửa hoặc xóa chip đó và kết quả cập nhật ngay, không phải gõ lại câu và không phải chờ AI chạy lại. Các ràng buộc đã chốt được nhớ trong phiên tìm kiếm, nên ở lượt sau người mua chỉ cần nói thêm "loại nào nhẹ hơn" mà mức giá cũ vẫn được giữ.

Để trả lời một câu, agent làm việc theo vòng lặp lập kế hoạch, gọi công cụ, quan sát kết quả rồi suy luận tiếp [12], tối đa bốn vòng. Các công cụ của agent đều chỉ đọc: tìm tin theo nội dung và bộ lọc, tìm tin tương tự một tin cho trước, liệt kê danh mục, xem sở thích suy ra từ tin người dùng đã lưu và đã xem, xem các đơn gần đây và lấy phường xã của người dùng. Agent không đặt hàng, không trả giá và không thao tác thay người dùng. Công cụ tìm tin dựa trên tìm kiếm lai: mỗi tin được so với câu tìm kiếm theo nghĩa [4] và theo từ khóa tiếng Việt đã bỏ dấu, các danh sách xếp hạng thu được được hợp nhất theo thứ hạng [5], sau đó xếp lại nhẹ theo khoảng cách và bậc uy tín người bán. Nhờ so theo nghĩa, câu "xe đi làm" vẫn tìm thấy tin ghi "xe đạp thành phố" dù không trùng từ nào ngoài chữ "xe". Tin đang giữ chỗ, đã bán, đang ẩn hoặc đã xóa không xuất hiện trong kết quả.

Thời gian chờ được giới hạn ở 8 giây. Khi agent chưa xong trong 8 giây hoặc một công cụ báo lỗi, hệ thống rơi về tìm kiếm lai với nguyên câu gốc; người mua vẫn nhận được danh sách kết quả, chỉ không có chip và câu diễn giải. Câu gốc của người dùng luôn được giữ trong mọi lần tìm mà agent thực hiện, nên trong trường hợp xấu nhất kết quả bằng kết quả của tìm kiếm thông thường. Ngoài ô tìm kiếm, người mua vẫn duyệt được danh mục và lọc theo giá, tình trạng, khoảng cách (UC-10); lưu tin, so sánh các tin đã lưu, theo dõi một câu tìm kiếm và nhận cảnh báo khi tin đã lưu giảm giá (UC-11); xem hồ sơ người bán với bậc, các đánh giá và những ghi nhận sự cố công khai (UC-12).

Hình 5.2 minh họa phía người mua. Trang chủ (a) có ô tìm kiếm, phường hiện tại và các tin gần đây. Màn hình kết quả (b) cho câu "xe đạp đi làm dưới 3 triệu" hiện hai chip "Xe đạp" và "Dưới 3 tr" do agent đặt, kèm dòng giá tham khảo của loại hàng này. Màn hình chi tiết tin (c) hiện ảnh, giá, thang tình trạng, người bán bậc Xuất sắc và nút Trả giá để mở thương lượng.

== Phân hệ thương lượng và đơn COD

Mọi trao đổi giữa hai bên diễn ra trong cuộc trò chuyện gắn với một tin đăng (UC-13), gồm tin nhắn văn bản và ảnh, trạng thái đã đọc và cập nhật tức thời. Phía trên khung chat là bảng điều khiển giao dịch đi qua bốn giai đoạn: thương lượng, tạo đơn và gửi hàng, xem và nhận hàng, đánh giá. Mỗi bước của bên này tạo một thông báo trong ứng dụng và một thông báo đẩy tới điện thoại của bên kia (REQ-21).

Thương lượng (UC-14) theo BR-06. Giá là bội số của 1.000 đ. Giá người mua trả không thấp hơn nửa giá niêm yết, làm tròn lên 1.000 đ, và phải thấp hơn giá niêm yết hoặc giá người bán vừa phản lại; giá phản của người bán phải cao hơn giá trả và thấp hơn giá niêm yết. Tại mỗi thời điểm chỉ có một giá đang mở, và giá mở không tự hết hạn. Ứng dụng hiện sẵn khoảng giá hợp lệ trên thanh chọn giá, nên người dùng hiếm khi gặp lỗi từ chối. Khi bên kia chấp nhận, thao tác chấp nhận mang theo đúng mức giá người đó đã thấy; nếu giá vừa thay đổi thì lời chấp nhận bị từ chối và người dùng được hiện giá mới. Người mua cũng có thể chấp nhận ngay giá niêm yết. Quy tắc nửa giá loại các lời trả giá mang tính quấy rối, còn quy tắc một giá mở giữ cho hai bên luôn biết mình đang trả lời con số nào.

Chốt giá không giữ hàng (BR-07). Nhiều người mua có thể cùng chốt một tin và cùng gửi yêu cầu COD (UC-15); người bán chọn gửi cho ai. Khi gửi yêu cầu, người mua xác nhận tên, số di động, địa chỉ và phường xã người nhận, thấy phí ship ước tính do hãng báo, và biết trước rằng mình chỉ trả tiền sau khi xem hàng. Số đơn COD đang mở của một người mua bị giới hạn theo bậc là 2, 5, 10 và 20 (BR-09), nên một tài khoản mới không thể đặt hàng loạt rồi từ chối nhận. Với món trên 5.000.000 đ, ứng dụng gợi ý hai bên hẹn gặp xem hàng trước nhưng vẫn cho chọn COD (BR-13); việc hẹn gặp do hai bên tự thỏa thuận trong tin nhắn.

Người bán tạo đơn (UC-16) theo một trong hai cách: tạo vận đơn trên tài khoản hãng vận chuyển của chính mình đã liên kết với sàn, hoặc tự gửi qua một hãng khác như SPX, J&T, Viettel Post rồi nhập tên hãng, mã vận đơn và phí ship. Đơn mang mã có dạng SN kèm số thứ tự từ 100001, ở trạng thái đã tạo vận đơn. Ngay khi đơn được tạo, tin chuyển sang đang giữ chỗ và mọi yêu cầu COD khác trên tin đó tự hủy với lý do "đã gửi cho người khác"; người mua bị hủy được báo ngay để tìm món khác. Quy trình tạo đơn gồm nhiều bước liên tiếp: kiểm thương lượng, giữ chỗ tin, gọi hãng tạo vận đơn, lưu đơn, hủy các yêu cầu còn lại. Mỗi bước được ghi lại khi hoàn tất, nên nếu máy chủ dừng giữa chừng thì quy trình chạy tiếp từ bước đã xong, không gọi hãng lần thứ hai; người bán bấm Tạo đơn hai lần cũng chỉ có một vận đơn. Nhờ đó không có tình huống tin đã giữ chỗ mà không có đơn, hay có hai vận đơn cho cùng một món.

Lúc shipper đến, người mua mở hàng xem trước rồi mới trả tiền (BR-08). Ứng dụng nhắc lại tình trạng và các thông tin người bán ghi trong tin, đồng thời nói rõ rằng sau khi trả tiền, sàn không có cơ chế đòi lại (BR-12). Nếu hàng không đúng, người mua từ chối nhận: hàng quay về người bán, người mua không mất đồng nào, phí ship hai chiều do hãng tính vào tài khoản của người bán và tin trở về đang bán (BR-11). Đơn hủy được khi hãng chưa lấy hàng (UC-18, BR-10), từ người mua hoặc người bán. Với đơn tự gửi, sàn không theo dõi được hành trình: người bán báo đã gửi, người mua báo đã nhận hoặc không nhận được, và các đơn này không tính vào các tỉ lệ dùng cho chế tài.

Hình 5.3 là luồng thương lượng. Màn hình (a) là khung chat với bảng điều khiển đang mở thanh chọn giá. Màn hình (b) hiện trạng thái đã chốt giá 3,8 triệu với nút Chọn giao COD. Màn hình (c) là phía người bán khi tạo đơn: tài khoản hãng vận chuyển đã liên kết, ô nhập khối lượng và phí thật của hai dịch vụ nhanh và tiết kiệm do hãng báo về.

#cap-doi(
  ([Thương lượng và tạo đơn COD], ("chat-offering.png", "chat-agreed-cod.png", "order-ship-to-create.png"),
    ("Trả giá", "Đã chốt giá", "Tạo đơn")),
  ([Nhận hàng, ghi nhận sự cố và uy tín], ("order-cod-door.png", "order-ship-record.png", "rep.png"),
    ("Shipper ở cửa", "Ghi nhận sự cố", "Điểm uy tín")),
)

== Phân hệ kết nối hãng vận chuyển

Sàn kết nối trực tiếp với hai hãng vận chuyển là Giao Hàng Tiết Kiệm [15] và Giao Hàng Nhanh [14]. Người bán liên kết hãng một lần ở mục Thiết lập giao COD (UC-04). Với Giao Hàng Tiết Kiệm, người bán đăng nhập tài khoản của hãng một lần trong ứng dụng; hệ thống lấy khóa kết nối của tài khoản rồi bỏ mật khẩu, không bao giờ lưu mật khẩu. Với Giao Hàng Nhanh, người bán nhập mã kết nối và mã cửa hàng lấy từ trang quản lý của hãng. Khóa của cả hai hãng được mã hóa khi lưu. Người bán khai địa chỉ lấy hàng và xác nhận đã có tài khoản nhận tiền tại hãng. Tiền thu hộ do hãng chuyển thẳng vào tài khoản ngân hàng người bán đã khai với hãng, không đi qua sàn, đúng với ràng buộc gốc là sàn không giữ tiền (BR-01). Vận đơn nằm trên tài khoản của người bán nên sàn cũng không thu phí ship.

Khi người mua chọn giao COD, hệ thống hỏi hãng của người bán để báo phí ước tính theo địa chỉ người nhận. Khi người bán tạo đơn, hệ thống gửi sang hãng khối lượng, dịch vụ nhanh hoặc tiết kiệm, tiền thu hộ bằng giá đã chốt và chế độ người nhận trả phí ship; mã đơn SN được dùng làm mã đơn phía hãng để hai bên tra cứu chéo. Phí thật do hãng trả về được lưu cùng vận đơn và hiện cho người mua. Shipper thu tại cửa tiền hàng cộng phí ship chiều đi, sau khi người mua đã xem hàng. Khi người mua hoặc người bán hủy đơn trước lúc hãng lấy hàng, hệ thống gửi lệnh hủy sang hãng trước, chỉ khi hãng xác nhận mới chuyển đơn sang đã hủy, nên không có vận đơn còn treo bên hãng mà đơn trên sàn đã đóng.

Sau khi đơn được tạo, mọi diễn biến do hãng báo về (UC-17); không bên nào phải chụp hay nộp bằng chứng. Hãng có thể gửi một thông báo nhiều lần hoặc gửi không theo thứ tự. Mỗi thông báo được lưu lại, thông báo trùng bị bỏ qua, các bước trung gian như đang trung chuyển hay đang phát hàng chỉ dùng để hiện hành trình cho hai bên. Những trạng thái làm đổi đơn được ánh xạ theo Bảng 5.1; thông báo đến trễ mà mâu thuẫn với trạng thái hiện tại, ví dụ "đã lấy hàng" đến sau "đã giao", bị bỏ qua.

#figure(
  kind: table,
  caption: [Ánh xạ trạng thái của hãng vận chuyển sang trạng thái đơn],
  table(
    columns: (1.1fr, 1.3fr, 0.8fr, 1.6fr),
    align: left + top,
    table.header([*Giao Hàng Tiết Kiệm*], [*Giao Hàng Nhanh*], [*Đơn chuyển sang*], [*Hệ quả*]),
    [3 Đã lấy hàng], [Đã lấy hàng], [Đang giao], [Đơn không còn hủy được],
    [5 Đã giao hàng], [Giao hàng thành công], [Đã giao], [Tin chuyển sang đã bán, thương lượng chuyển sang đã bán],
    [20 Đang trả hàng, 21 Đã trả hàng], [Chờ trả hàng, Đã trả hàng], [Đã hoàn], [Tin trở về đang bán, thương lượng trở về đang thương lượng],
    [-1 Hủy đơn], [Hủy đơn], [Đã hủy], [Tin trở về đang bán, thương lượng trở về đang thương lượng],
  ),
)

Trạng thái đã giao của hãng có nghĩa người mua đã xem hàng và trả tiền cho shipper, nên đó cũng là thời điểm giao dịch thành công và người bán được cộng 10 điểm uy tín. Đơn đã hoàn là một lần từ chối nhận, được tính vào tỉ lệ của người mua ở mục tiếp theo.

== Phân hệ ghi nhận sự cố, đánh giá, điểm uy tín và chế tài

Sau mỗi đơn đã gửi, người mua đánh giá người bán một lần (UC-19), từ 1 đến 5 sao kèm nhận xét không quá 500 ký tự, và được sửa hoặc xóa trong 7 ngày (BR-17). Khi phát hiện vấn đề sau khi đã nhận hàng, người mua mở ghi nhận sự cố ngay trong cuộc trò chuyện, kèm ảnh (UC-20). AI đọc nội dung tin đăng và ảnh người mua gửi, rồi viết một nhận xét trung lập mà cả hai bên cùng đọc. Sàn không ra phán quyết (BR-14). Người bán có 3 ngày để trả lời (UC-21): tự hoàn tiền trực tiếp cho người mua và được cộng 15 điểm, hoặc từ chối. Ghi nhận bị từ chối, hoặc quá 3 ngày không trả lời thì tự động coi là từ chối, sẽ hiện công khai trên hồ sơ người bán. Người mua có thể rút ghi nhận nếu hai bên đã tự giải quyết. Cách làm này không đòi sàn biết ai đúng trong từng vụ; người mua sau tự đọc lịch sử của người bán và quyết định.

Điểm uy tín nằm trong khoảng 0 đến 1000 (UC-22, BR-16). Giao dịch thành công được cộng 10 điểm, đánh giá 5 sao cộng 5, 4 sao cộng 2, tự hoàn tiền cho ghi nhận cộng 15, trả lời nhanh trong cả tháng cộng 20, xác minh danh tính cộng 100; bị đánh giá 1 hoặc 2 sao trừ 15. Sự kiện cũ hơn 365 ngày chỉ tính một nửa. Bậc uy tín gồm Mới từ 0 điểm, Tin cậy từ 200, Uy tín từ 500 và Xuất sắc từ 800; bậc Uy tín được ưu tiên hiển thị, bậc Xuất sắc có huy hiệu và giảm phí đẩy tin. Không có điểm cho việc thắng hay thua tranh chấp, vì sàn không phân xử.

Chế tài là mất quyền, không phải mất tiền (BR-15). Hệ thống theo dõi tỉ lệ từ chối nhận của người mua, tỉ lệ bị từ chối và số ghi nhận chưa trả lời của người bán, và chỉ xét khi tài khoản có ít nhất 5 đơn COD trong 90 ngày. Tỉ lệ từ chối nhận từ 20% trở lên thì người mua bị hạ một nấc, chỉ còn 1 đơn COD đang mở; từ 35% trở lên thì mất quyền COD trong 30 ngày. Mỗi 30 ngày không có lần từ chối nào thì quyền được hồi lại một nấc. Ngưỡng 5 đơn tồn tại vì ở quy mô một vụ không ai biết bên nào đúng, còn ở quy mô nhiều vụ thì tỉ lệ phản ánh hành vi. Mọi thay đổi điểm, bậc và quyền được tính tự động mỗi khi có sự kiện mới, không cần người duyệt.

Hình 5.4 là phần sau giao dịch. Màn hình (a) là lúc shipper ở cửa: ứng dụng nhắc người mua xem hàng trước và nói rõ sau khi trả tiền sàn không đòi lại được. Màn hình (b) là phía người bán khi có ghi nhận sự cố: nhận xét trung lập của AI, hạn trả lời 3 ngày và hai nút Từ chối, Tự hoàn. Màn hình (c) là trang uy tín của một tài khoản có 386/1000 điểm ở bậc Tin cậy, được tối đa 5 đơn COD đang mở và 20 tin đang bán.

== Phân hệ vận hành

Điều phối viên chỉ xử lý những việc hai bên không tự giải quyết được (BR-19). Người dùng báo cáo vi phạm từ tin đăng, hồ sơ hoặc cuộc trò chuyện với bốn loại lý do: hàng cấm, hàng giả, lừa đảo và lý do khác (UC-23). Điều phối viên xem các báo cáo về hàng cấm, hàng giả và lừa đảo có dấu hiệu tổ chức, gỡ tin hoặc tạm khóa tài khoản kèm lý do và thời hạn (UC-24); tài khoản bị tạm khóa không đăng tin và không giao dịch được. Ngoài ra điều phối viên duyệt tay các hồ sơ xác minh danh tính không đọc được chip (UC-25) và tiếp nhận yêu cầu hợp lệ từ cơ quan có thẩm quyền. Giá cả và tình trạng hàng là việc giữa hai bên, điều phối viên không can thiệp. Vì ba nhóm việc này không tăng theo số đơn, một nhóm vận hành nhỏ đủ phục vụ sàn khi lượng giao dịch tăng.

Tài khoản nhân viên tách hẳn khỏi tài khoản khách hàng và đăng nhập ở một bảng điều khiển riêng bằng email, mật khẩu và mã xác thực sáu số sinh trên ứng dụng xác thực của điện thoại; nhập sai 5 lần thì tài khoản bị khóa 15 phút. Quản trị viên làm được mọi việc của điều phối viên, thêm việc tạo, khóa tài khoản điều phối viên (UC-26). Mỗi thao tác thay đổi dữ liệu của nhân viên được ghi vào nhật ký kiểm toán cùng lúc với chính thay đổi đó, nên không có thao tác nào xảy ra mà không để lại dấu; quản trị viên tra cứu nhật ký theo nhân viên, loại thao tác và thời gian (UC-27).

== Nền tảng và triển khai

Dịch vụ nền viết bằng Go, chia thành 12 dịch vụ theo đúng các phân hệ ở trên; mỗi dịch vụ giữ dữ liệu riêng trong PostgreSQL, phần tìm kiếm theo nghĩa dùng tiện ích pgvector [17]. Các quy trình nhiều bước như đăng nhập lần đầu, đăng tin, tạo đơn và hạn 3 ngày của ghi nhận sự cố chạy trên Restate [18], công cụ ghi lại kết quả từng bước để quy trình chạy tiếp sau sự cố. Ứng dụng Android viết bằng Kotlin, chạy từ Android 12, có giao diện tối và hỗ trợ cỡ chữ lớn. Ảnh lưu ở một kho lưu trữ đối tượng riêng. Khi triển khai, mỗi nhóm dịch vụ được đóng gói thành một container và chạy trên một cụm máy chủ; mỗi phiên bản mới chỉ được đưa lên sau khi toàn bộ bộ kiểm thử ở Chương 6 chạy đạt, và cập nhật cấu trúc dữ liệu trước khi thay phiên bản cũ. Mọi yêu cầu đều được ghi vết; khi xảy ra lỗi, phản hồi trả về một mã truy vết để nhóm phát triển tìm đúng yêu cầu đó trên màn hình quan trắc.
