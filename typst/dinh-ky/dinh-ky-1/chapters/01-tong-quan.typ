#import "../../../common/tokens.typ": *
#import "../../../common/info.typ" as info

#show table.cell: set text(size: 10pt)

= TỔNG QUAN

== Bối cảnh và khảo sát

Mua bán đồ cũ giữa các cá nhân hiện diễn ra chủ yếu qua tin rao vặt và hội nhóm mạng xã hội. Chuyển khoản trước thì người mua chịu rủi ro không nhận được hàng. Giao hàng thu tiền hộ (COD) thì người bán chịu rủi ro người mua không nhận và mất phí ship hai chiều. Khi hàng khác mô tả, hai bên không có căn cứ chung để đối chiếu.

Các sàn lớn giải quyết bằng cách đứng giữa: thu tiền, giữ tiền đến khi giao xong và phân xử khiếu nại. Cách này đòi giấy phép trung gian thanh toán, đội ngũ xử lý khiếu nại tăng theo số đơn và trách nhiệm pháp lý với khoản tiền đang giữ [1], [2]. Một sàn nhỏ chuyên đồ cũ khó gánh chi phí đó. Nhóm khảo sát ba nền tảng phổ biến, kết quả ở Bảng 1.1.

#figure(
  kind: table,
  caption: [So sánh ba nền tảng mua bán được khảo sát],
  table(
    columns: (1.05fr, 1.3fr, 1.3fr, 1.3fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([Tiêu chí], [Chợ Tốt], [Facebook Marketplace], [Shopee]),
    [Mô tả tình trạng], [Chọn mới/đã dùng, mô tả tự do], [Mô tả tự do, ảnh tùy ý], [Thuộc tính theo ngành hàng, hướng tới hàng mới],
    [Đường tiền], [Hai bên tự thỏa thuận], [Hai bên tự thỏa thuận qua Messenger], [Sàn thu và giữ tiền],
    [Xử lý sự cố], [Sàn không can thiệp giao dịch], [Không có quy trình đơn], [Sàn nhận khiếu nại, hoàn tiền],
    [Hạn chế với đồ cũ], [Không có căn cứ khi hàng khác mô tả], [Tài khoản giả, lừa chuyển khoản trước], [Quy trình người bán nặng, phí theo phần trăm đơn],
  ),
)

Chợ Tốt và Facebook Marketplace đơn giản nhưng bỏ trống khâu giao dịch. Shopee lấp khâu đó bằng cách giữ tiền và phân xử. Đề tài "#info.de-tai" nhắm vào khoảng giữa: có quy trình giao dịch rõ ràng trong ứng dụng nhưng sàn không giữ tiền và không xử lý từng vụ việc.

== Mô hình nghiệp vụ đề xuất

Mô hình xuất phát từ hai ràng buộc gốc: sàn không giữ tiền của ai (không ví, không cọc, không thu hộ, không hoàn tiền qua sàn) và sàn không phán xử từng vụ việc. Từ đó nhóm rút ra chín nguyên tắc:

+ Tin đăng là tập cam kết: tình trạng theo thang Mới, Như mới, Đã dùng; mỗi vết khai kèm ảnh chụp trong ứng dụng. Vết đã khai không dùng làm lý do khiếu nại.
+ Một đường giao dịch duy nhất là COD đồng kiểm: người mua xem hàng tại cửa rồi mới trả tiền cho shipper. Người bán gửi qua tài khoản GHTK hoặc GHN của mình, hoặc tự gửi rồi nhập mã vận đơn.
+ Tiền chảy theo sự kiện quan sát được: người mua không trả gì trong ứng dụng, vận đơn đặt người nhận trả phí ship, đơn chỉ hủy được trước khi hãng lấy hàng.
+ "Hoàn tiền" là từ chối nhận: từ chối tại cửa thì người mua không mất tiền; đã trả tiền thì không đòi lại qua sàn.
+ Sự cố sau khi nhận chỉ được ghi nhận: người bán có 3 ngày để tự hoàn tiền hoặc từ chối, từ chối thì vụ việc hiện công khai trên hồ sơ.
+ Chế tài là mất quyền, không mất tiền: tỉ lệ từ chối nhận cao hoặc bỏ mặc ghi nhận sự cố thì tự động bị hạ hiển thị, giới hạn đơn COD, mất quyền COD.
+ Người thật chỉ xử lý hàng cấm, hàng giả, lừa đảo có tổ chức, yêu cầu của cơ quan có thẩm quyền và hồ sơ xác minh danh tính phải duyệt tay.
+ Doanh thu từ đẩy tin và gói người bán; quyền COD và bậc uy tín không mua được.
+ Thanh toán tạm giữ qua đơn vị có giấy phép được để dành cho sau này.

COD đồng kiểm biến lúc trả tiền thành lúc kiểm hàng. Hãng vận chuyển là bên thứ ba trung lập: thu tiền hộ và chuyển thẳng về tài khoản người bán, đồng thời báo về các trạng thái đã lấy hàng, đã giao, bị từ chối. Vì mọi thay đổi trạng thái đơn đều có nguồn khách quan, sàn không cần người đọc bằng chứng.

Rủi ro còn lại được kiểm soát bằng uy tín theo thống kê. Ở một vụ việc sàn không biết ai đúng, nhưng ở năm mươi vụ thì tỉ lệ cho thấy rõ. Mỗi người dùng có điểm từ 0 đến 1000, quy đổi thành bốn bậc Mới, Tin cậy, Uy tín, Xuất sắc với hạn mức đơn COD mở lần lượt 2, 5, 10, 20. Khi có ít nhất 5 đơn COD trong 90 ngày, tỉ lệ từ chối nhận từ 20% thì chỉ còn 1 đơn COD mở, từ 35% thì mất quyền COD 30 ngày; mỗi 30 ngày không có lần từ chối nào được hồi một nấc.

== Mục tiêu, phạm vi và phương pháp

Mục tiêu là xây dựng sàn C2C cho hàng đã qua sử dụng theo mô hình trên, gồm ứng dụng Android và 12 phân hệ nền theo kiến trúc microservice [10]: đặc tả mô hình thành ca sử dụng, quy tắc và yêu cầu có mã; hiện thực thương lượng giá và đơn COD đồng kiểm kết nối GHTK, GHN; xây dựng tìm kiếm theo ngữ nghĩa và AI agent giúp người mua tìm hàng bằng câu nói tự nhiên.

Ngoài phạm vi có: mọi hình thức sàn thu, giữ hay hoàn tiền; quy trình phân xử khiếu nại; giỏ hàng nhiều món; ứng dụng iOS và web cho người mua; giao hàng quốc tế.

Đề tài chia ba giai đoạn, mỗi giai đoạn bốn tuần. Giai đoạn 1 gồm khảo sát, phân tích, thiết kế, nguyên mẫu ứng dụng và các phân hệ không phụ thuộc hãng vận chuyển. Giai đoạn 2 tích hợp GHTK, GHN, tìm kiếm, AI agent, uy tín và nối ứng dụng với dịch vụ nền. Giai đoạn 3 hoàn thiện, kiểm thử toàn hệ thống và triển khai. Phần phân tích dùng UML; mỗi quy tắc nghiệp vụ gắn với ít nhất một kịch bản kiểm thử tự động.
