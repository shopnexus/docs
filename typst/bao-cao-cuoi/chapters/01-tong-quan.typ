#import "../../common/tokens.typ": *

= TỔNG QUAN

== Bối cảnh và vấn đề

Thị trường mua bán hàng đã qua sử dụng giữa các cá nhân tại Việt Nam diễn ra chủ yếu trên các trang rao vặt và các nhóm mạng xã hội. Điện thoại, máy tính, xe đạp, đồ gia dụng được rao với giá thấp hơn hàng mới, người mua và người bán thường ở xa nhau và chưa từng giao dịch trước đó. Khác với TMĐT kiểu B2C, mỗi món hàng cũ là duy nhất: tình trạng của nó chỉ người bán biết, và mô tả thường là một đoạn văn tự do không có chuẩn chung.

Trong điều kiện đó, hai bên chỉ có vài cách trả tiền. Chuyển khoản trước đặt toàn bộ rủi ro lên người mua, và đây là kịch bản lừa đảo phổ biến nhất: nhận tiền rồi biến mất. COD tự phát, tức người bán gửi hàng thu hộ qua một hãng vận chuyển, chuyển rủi ro sang người bán: người mua đặt rồi không nhận ("bom hàng"), người bán chịu phí ship hai chiều mà không có cách nào ghi nhận người mua đó. Việc thương lượng giá diễn ra qua tin nhắn Zalo hoặc Messenger, tách khỏi tin đăng, nên giá đã chốt, địa chỉ nhận hàng và mã vận đơn nằm rải rác ở nhiều nơi và không thể dùng làm căn cứ khi có sự cố.

Ở phía tìm kiếm, người mua phải dịch nhu cầu của mình thành từ khóa và bộ lọc. Một câu như "kiếm gì đó tặng sinh nhật bạn, tầm 500 nghìn, gần đây thôi" không ứng với một từ khóa nào; người mua phải tự chọn danh mục, khoảng giá, khu vực, rồi lặp lại khi kết quả không vừa ý.

Về pháp lý, Luật Bảo vệ quyền lợi người tiêu dùng [1] và Luật Thương mại điện tử [2] đặt ra trách nhiệm cung cấp thông tin trung thực về hàng hóa và trách nhiệm của chủ nền tảng đối với người bán trên nền tảng. Một sàn muốn giữ tiền của người mua thì phải trở thành hoặc hợp tác với tổ chức trung gian thanh toán có giấy phép, điều vượt khỏi khả năng của một nhóm sinh viên và cũng không cần thiết cho phân khúc hàng cũ giá vừa phải.

== Khảo sát các giải pháp hiện có

Nhóm khảo sát ba nền tảng có lượng người dùng lớn tại Việt Nam: Chợ Tốt, Facebook Marketplace và Shopee. Bảng 1.1 so sánh chúng với ShopNexus theo năm tiêu chí gắn trực tiếp với các vấn đề nêu trên.

#figure(
  kind: table,
  caption: [So sánh các nền tảng theo tiêu chí giao dịch C2C hàng cũ],
  table(
    columns: (1fr, 2cm, 2.3cm, 1.8cm, 2.6cm),
    align: (left, center, center, center, center),
    table.header([Tiêu chí], [Chợ Tốt], [Facebook Marketplace], [Shopee], [ShopNexus]),
    [Sàn giữ tiền người mua], [Không], [Không], [Có], [Không],
    [Sàn phân xử khiếu nại], [Không], [Không], [Có], [Không],
    [Thương lượng giá trong ứng dụng], [Qua chat], [Qua Messenger], [Hạn chế], [Có, theo luật giá],
    [COD đồng kiểm qua vận đơn đứng tên người bán], [Không], [Không], [Không], [Có (GHTK, GHN)],
    [Tìm bằng câu tự nhiên], [Không], [Không], [Không], [Có (AI agent)],
  ),
)

Chợ Tốt và Facebook Marketplace chỉ làm nơi gặp nhau: việc trả tiền, gửi hàng và xử lý sự cố do hai bên tự lo. Shopee bảo vệ người mua bằng cách giữ tiền và phân xử khiếu nại, nhưng mô hình này được thiết kế cho hàng mới của người bán chuyên nghiệp, đòi giấy phép thanh toán, đội ngũ xử lý khiếu nại tăng theo số đơn và không hợp với một chiếc điện thoại cũ bán một lần. Khoảng trống mà đề tài nhắm tới nằm giữa hai nhóm: một sàn không giữ tiền và không phán xử, nhưng đưa toàn bộ giao dịch vào ứng dụng, để mọi dữ kiện quan trọng đều có nguồn quan sát được và có thể tính thành uy tín.

== Mô hình nghiệp vụ đề xuất

Mô hình của ShopNexus bắt đầu từ hai ràng buộc gốc. Thứ nhất, sàn không giữ tiền của ai: không ví, không cọc, không thu hộ, không hoàn tiền qua sàn. Thứ hai, sàn không phán xử từng vụ việc. Hai ràng buộc này loại bỏ yêu cầu giấy phép thanh toán và bộ phận xử lý khiếu nại, đồng thời buộc mọi quy tắc còn lại phải dựa trên dữ kiện quan sát được thay vì lời khai của hai bên. Chín nguyên tắc dưới đây được suy ra từ đó.

+ Tin đăng là một tập cam kết. Tình trạng hàng chọn trên thang ba mức Mới, Như mới, Đã dùng. Mỗi khuyết tật ("vết") phải khai kèm ảnh cận chụp trong ứng dụng; ảnh mang dấu thời gian chụp và đóng vai trò "vân tay" của món hàng để chống tráo hàng. AI đọc ảnh hoặc video để điền giúp tin đăng, và mọi vết mà mô hình nhìn thấy phải được người bán khai hoặc bác bỏ rõ ràng thì tin mới đăng được. Luật công bố trước: vết đã khai không là căn cứ khiếu nại, vết không khai mà hàng có thì mặc định là lỗi người bán.

+ Chỉ có một đường giao dịch trong ứng dụng là COD đồng kiểm: người mua xem hàng tại cửa rồi mới trả tiền cho shipper. Người bán liên kết một lần tài khoản GHTK hoặc GHN đứng tên mình; hệ thống tạo vận đơn trên tài khoản đó và lấy phí thật từ hãng, còn tiền thu hộ do hãng chuyển thẳng vào tài khoản ngân hàng của người bán. Người bán cũng có thể tự gửi qua hãng khác và nhập mã vận đơn bằng tay.

+ Tiền chỉ chảy theo sự kiện quan sát được. Người mua không trả gì trong ứng dụng; vận đơn đặt chế độ người nhận trả phí ship. Trước khi hãng lấy hàng, một trong hai bên được hủy đơn. Mọi dữ kiện của đơn GHTK/GHN do hãng tự động báo về nên không ai phải đọc bằng chứng; đơn tự gửi không theo dõi được và không tính vào các tỉ lệ chế tài.

+ "Hoàn tiền" thực chất là từ chối nhận. Người mua từ chối tại cửa thì hàng quay về, người mua không mất đồng nào và hãng tính phí hai chiều vào tài khoản người bán. Sau khi đã trả tiền cho shipper thì sàn không có cơ chế đòi lại, và ứng dụng nói rõ điều này trước thời điểm trả tiền.

+ Sự cố sau khi nhận được ghi nhận chứ không phân xử. Người mua mở ghi nhận sự cố kèm ảnh trong cuộc trò chuyện; người bán có 3 ngày để tự hoàn tiền (được cộng điểm) hoặc từ chối, và vụ bị từ chối trở thành dữ kiện công khai trên hồ sơ người bán. AI viết một nhận xét trung lập cho cả hai cùng đọc.

+ Chế tài là mất quyền chứ không mất tiền. Hệ thống theo dõi tỉ lệ từ chối nhận của người mua, tỉ lệ bị từ chối và số ghi nhận chưa trả lời của người bán; vượt ngưỡng thì lần lượt bị hạ hiển thị, giới hạn số đơn COD, mất quyền COD rồi khóa tài khoản. Ở quy mô một vụ, sàn không biết ai đúng; ở quy mô năm mươi vụ, con số đủ để kết luận.

+ Người thật chỉ xử lý ba việc: hàng cấm hoặc hàng giả bị báo cáo, lừa đảo có dấu hiệu tổ chức, và yêu cầu hợp lệ của cơ quan có thẩm quyền, cùng với việc duyệt tay hồ sơ eKYC khi máy không đọc được chip. Khối lượng các việc này không tăng theo số đơn.

+ Doanh thu đến từ đẩy tin và gói người bán. Sàn không thu phí ship vì vận đơn nằm trên tài khoản của người bán, và không thu phần trăm mỗi đơn vì không chạm vào tiền hàng. Quyền COD và bậc uy tín không mua được.

+ Thanh toán tạm giữ qua đơn vị có giấy phép được để dành cho nhóm hàng giá cao. Vì hệ thống đã có khái niệm đường giao dịch, đó sẽ là thêm một lựa chọn chứ không phải làm lại hệ thống.

== Mục tiêu và phạm vi

Mục tiêu của đồ án là hiện thực trọn mô hình trên thành một hệ thống chạy được: người dùng đăng nhập bằng OTP, xác minh danh tính bằng CCCD gắn chip, đăng tin với AI điền giúp, tìm hàng bằng câu tự nhiên, thương lượng giá trong khung chat, đặt COD và tạo vận đơn GHTK/GHN, nhận hoặc từ chối hàng tại cửa, đánh giá, ghi nhận sự cố, và thấy điểm uy tín cùng quyền của mình thay đổi theo các sự kiện đó. Hệ thống cũng phải đáng tin cậy ở mức vận hành: khi máy chủ gặp sự cố giữa chừng, đơn không bị mất, vận đơn không bị tạo hai lần và người dùng không nhận hai mã OTP.

Phạm vi gồm hệ thống dịch vụ nền chia theo phân hệ nghiệp vụ, ứng dụng Android cho người mua và người bán, chức năng quản lý cho điều phối viên và quản trị viên, cùng kết nối với GHTK, GHN, nhà cung cấp tin nhắn, dịch vụ thông báo đẩy và mô hình AI. Ngoài phạm vi là thanh toán tạm giữ, ứng dụng iOS và giao diện web cho khách hàng, giao hàng quốc tế, gian hàng doanh nghiệp theo mô hình B2C, và gọi thoại giữa hai bên.

== Phương pháp thực hiện

Nhóm bắt đầu bằng khảo sát: tìm hiểu cách người dùng đang mua bán đồ cũ trên các trang rao vặt và mạng xã hội, so sánh các nền tảng ở mục 1.2, và liệt kê các rủi ro mà người mua, người bán thường gặp như chuyển khoản rồi mất tiền, bom hàng, tráo hàng hay tranh cãi về tình trạng hàng. Mỗi rủi ro được đối chiếu với một nguyên tắc trong mô hình nghiệp vụ ở mục 1.3.

Từ mô hình đó, nhóm mô hình hóa nghiệp vụ bằng UML. Sơ đồ ca sử dụng xác định ai làm gì trên hệ thống; sơ đồ hoạt động mô tả các quy trình đăng tin, thương lượng, giao nhận và ghi nhận sự cố; sơ đồ trạng thái mô tả vòng đời của tin đăng và đơn hàng. Các quy tắc nghiệp vụ được ghi thành danh mục đánh mã BR, yêu cầu chức năng và phi chức năng được đánh mã REQ và NFR, để mỗi quy tắc truy vết được tới ca sử dụng và ca kiểm thử tương ứng.

Hệ thống được chia theo phân hệ nghiệp vụ: tài khoản và xác minh danh tính, tin đăng, tìm kiếm, thương lượng và đơn COD, vận chuyển, uy tín và chế tài, thông báo. Mỗi phân hệ chịu trách nhiệm cho một nhóm quy tắc và một phần dữ liệu riêng, nên khi một quy tắc thay đổi thì chỉ một phân hệ phải sửa.

Công việc chia thành ba giai đoạn bốn tuần. Giai đoạn 1 gồm khảo sát, đặc tả, thiết kế tổng thể và nguyên mẫu màn hình. Giai đoạn 2 hoàn thành các quy trình chính: đăng tin, tìm kiếm, thương lượng, đặt COD, kết nối hãng vận chuyển và tính uy tín. Giai đoạn 3 hoàn thiện xác minh danh tính, thông báo, gói người bán, kiểm thử và triển khai. Cuối mỗi giai đoạn nhóm có một phiên bản chạy được để giáo viên hướng dẫn góp ý.

Kiểm thử được thực hiện theo kịch bản nghiệp vụ: mỗi kịch bản đi trọn một quy trình như người bán đăng tin, người mua trả giá, hai bên chốt giá, hãng báo đã giao hoặc người mua từ chối nhận, rồi kiểm tra kết quả mà từng bên nhìn thấy, gồm trạng thái đơn, điểm uy tín và quyền COD. Kịch bản chạy trên cơ sở dữ liệu và dịch vụ thật thay vì dữ liệu giả lập, để kết quả phản ánh đúng hành vi khi vận hành.
