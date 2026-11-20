#import "../../common/tokens.typ": *

= TỔNG QUAN

== Bối cảnh và vấn đề

Thị trường mua bán hàng đã qua sử dụng giữa các cá nhân tại Việt Nam diễn ra chủ yếu trên các trang rao vặt và các nhóm mạng xã hội. Điện thoại, máy tính, xe đạp, đồ gia dụng được rao với giá thấp hơn hàng mới, người mua và người bán thường ở xa nhau và chưa từng giao dịch trước đó. Khác với TMĐT kiểu B2C, mỗi món hàng cũ là duy nhất: tình trạng của nó chỉ người bán biết, và mô tả thường là một đoạn văn tự do không có chuẩn chung.

Trong điều kiện đó, hai bên chỉ có vài cách trả tiền. Chuyển khoản trước đặt toàn bộ rủi ro lên người mua, và đây là kịch bản lừa đảo phổ biến nhất: nhận tiền rồi biến mất. COD tự phát, tức người bán gửi hàng thu hộ qua một hãng vận chuyển, chuyển rủi ro sang người bán: người mua đặt rồi không nhận ("bom hàng"), người bán chịu phí ship hai chiều mà không có cách nào ghi nhận người mua đó. Việc thương lượng giá diễn ra qua tin nhắn Zalo hoặc Messenger, tách khỏi tin đăng, nên giá đã chốt, địa chỉ nhận hàng và mã vận đơn nằm rải rác ở nhiều nơi và không thể dùng làm căn cứ khi có sự cố.

Ở phía tìm kiếm, người mua phải dịch nhu cầu của mình thành từ khóa và bộ lọc. Một câu như "kiếm gì đó tặng sinh nhật bạn, tầm 500 nghìn, gần đây thôi" không ứng với một từ khóa nào; người mua phải tự chọn danh mục, khoảng giá, khu vực, rồi lặp lại khi kết quả không vừa ý.

Về pháp lý, Luật Bảo vệ quyền lợi người tiêu dùng [1] và Luật Thương mại điện tử [2] đặt ra trách nhiệm cung cấp thông tin trung thực về hàng hóa và trách nhiệm của chủ nền tảng đối với người bán trên nền tảng. Một sàn muốn giữ tiền của người mua thì phải trở thành hoặc hợp tác với tổ chức trung gian thanh toán có giấy phép, điều vượt khỏi khả năng của một nhóm sinh viên và cũng không cần thiết cho phân khúc hàng cũ giá vừa phải.

== Khảo sát các giải pháp hiện có

Nhóm khảo sát ba nền tảng có lượng người dùng lớn tại Việt Nam: Chợ Tốt, Facebook Marketplace và Shopee. Bảng 1.1 so sánh chúng với hệ thống của đề tài theo sáu tiêu chí gắn trực tiếp với các vấn đề nêu trên.

#figure(
  kind: table,
  caption: [So sánh các nền tảng theo tiêu chí giao dịch C2C hàng cũ],
  table(
    columns: (1fr, 2cm, 2.3cm, 1.8cm, 2.6cm),
    align: (left, center, center, center, center),
    table.header([Tiêu chí], [Chợ Tốt], [Facebook Marketplace], [Shopee], [Đề tài]),
    [Sàn giữ tiền người mua], [Không], [Không], [Có], [Không],
    [Sàn phân xử khiếu nại], [Không], [Không], [Có], [Không],
    [Thương lượng giá trong ứng dụng], [Qua chat], [Qua Messenger], [Hạn chế], [Có, theo luật giá],
    [COD đồng kiểm qua vận đơn đứng tên người bán], [Không], [Không], [Không], [Có (GHTK, GHN)],
    [Tìm bằng câu tự nhiên, bằng ảnh], [Không], [Không], [Có, bằng ảnh], [Có, cả hai],
    [Cảnh báo lừa đảo trong trò chuyện], [Không], [Không], [Không], [Có],
  ),
)

Chợ Tốt và Facebook Marketplace chỉ làm nơi gặp nhau: việc trả tiền, gửi hàng và xử lý sự cố do hai bên tự lo. Shopee bảo vệ người mua bằng cách giữ tiền và phân xử khiếu nại, nhưng mô hình này được thiết kế cho hàng mới của người bán chuyên nghiệp, đòi giấy phép thanh toán, đội ngũ xử lý khiếu nại tăng theo số đơn và không hợp với một chiếc điện thoại cũ bán một lần. Đề tài nhắm vào khoảng giữa hai nhóm: một sàn không giữ tiền và không phán xử, nhưng đưa toàn bộ giao dịch vào ứng dụng, để mọi dữ kiện quan trọng đều có nguồn quan sát được và hiện thành uy tín công khai.

== Mô hình nghiệp vụ đề xuất

Mô hình của hệ thống bắt đầu từ hai ràng buộc gốc. Thứ nhất, sàn không giữ tiền của ai: không ví, không cọc, không thu hộ, không hoàn tiền qua sàn. Thứ hai, sàn không phán xử từng vụ việc. Hai ràng buộc này loại bỏ yêu cầu giấy phép thanh toán và bộ phận xử lý khiếu nại, đồng thời buộc mọi quy tắc còn lại phải dựa trên dữ kiện quan sát được thay vì lời khai của hai bên. Chín nguyên tắc dưới đây được suy ra từ đó.

+ Tin đăng là một tập cam kết gồm mức tình trạng trên thang ba mức Mới, Như mới, Đã dùng, các thông tin người bán ghi trong tin ("Tin ghi") và ảnh. AI đọc video, ảnh hoặc tin cũ trên Chợ Tốt để điền giúp tin đăng và gợi ý giá. Tin không có phần khai vết và AI không chỉ ra vết nào trên hàng, vì mỗi người đánh giá vết trên đồ cũ một khác, còn vết do mô hình nêu ra dễ thành cớ để người mua khiếu nại và khiến người bán rời sàn. Người mua tự xem tình trạng hàng khi đồng kiểm tại cửa.

+ Chỉ có một đường giao dịch trong ứng dụng là COD đồng kiểm: người mua xem hàng tại cửa rồi mới trả tiền cho shipper. Người bán liên kết một lần tài khoản GHTK hoặc GHN đứng tên mình. Hệ thống tạo vận đơn trên tài khoản đó và lấy phí thật từ hãng, hoặc đọc mã vận đơn người bán đã tạo trên ứng dụng của hãng bằng chính tài khoản ấy. Tiền thu hộ do hãng chuyển thẳng vào tài khoản ngân hàng của người bán.

+ Tiền chỉ chảy theo sự kiện quan sát được. Người mua không trả gì trong ứng dụng; vận đơn đặt chế độ người nhận trả phí ship. Mọi dữ kiện của đơn do hãng báo về nên không ai phải đọc bằng chứng. Các thời hạn chạy tự động: người bán có 3 ngày để gửi hàng, hãng có 3 ngày để lấy hàng, và đơn tự hoàn tất 3 ngày sau khi hãng báo đã giao nếu người mua chưa bấm đã nhận.

+ "Hoàn tiền" thực chất là từ chối nhận. Người mua từ chối tại cửa thì hàng quay về, người mua không mất đồng nào và hãng tính phí hai chiều vào tài khoản người bán. Sau khi đã trả tiền cho shipper thì sàn không có cơ chế đòi lại.

+ Sau khi nhận hàng, hai bên tự trao đổi trong cuộc trò chuyện; sàn không có quy trình khiếu nại hay hoàn tiền. Người mua chưa nhận được hàng mà đơn đã báo giao thì gửi phiếu "Báo chưa nhận hàng" cho bộ phận hỗ trợ.

+ Uy tín là các số liệu quan sát được, công khai trên hồ sơ: số sao trung bình khi bán và khi mua, số món đã bán, tỉ lệ trả lời tin nhắn trong 24 giờ, số đơn giao không thành trong 90 ngày. Hai bên đánh giá nhau sau mỗi đơn. Hạn mức như nhau cho mọi tài khoản, 3 đơn COD đang mở khi mua và 20 tin đang bán, và không mua được bằng gói trả phí.

+ Rủi ro lừa đảo trong trò chuyện được cảnh báo tự động: AI đọc các tin nhắn gần nhất và hiện cảnh báo khi thấy dấu hiệu như đòi đặt cọc trước hay rủ chuyển sang ứng dụng khác. Người dùng quyết định có tiếp tục hay chặn và báo cáo.

+ Người thật chỉ xử lý phiếu hỗ trợ, hàng cấm hoặc hàng giả bị báo cáo, lừa đảo có dấu hiệu tổ chức và yêu cầu hợp lệ của cơ quan có thẩm quyền. Một trợ lý AI đọc hồ sơ và đề xuất cho nhân viên, còn mọi thao tác do nhân viên bấm.

+ Doanh thu đến từ đẩy tin và gói người bán. Sàn không thu phí ship vì vận đơn nằm trên tài khoản của người bán, và không thu phần trăm mỗi đơn vì không chạm vào tiền hàng. Thanh toán tạm giữ qua đơn vị có giấy phép được để dành cho nhóm hàng giá cao, như một đường giao dịch thứ hai.

Mô hình ở định kỳ 1 còn có điểm uy tín 0–1000 với bốn bậc, xác minh danh tính bằng căn cước gắn chip, ghi nhận sự cố có hạn trả lời 3 ngày và chế tài tự động theo tỉ lệ từ chối nhận. Khi chạy thử trên luồng thật ở giai đoạn 2, nhóm bỏ các phần này. Số liệu thật dễ kiểm chứng hơn một thang điểm tự đặt luật. Sàn không giữ tiền nên ghi nhận sự cố không dẫn tới khoản hoàn nào để theo dõi. Ngưỡng chế tài cần dữ liệu giao dịch thật để đặt, nên trong lúc chờ, số đơn giao không thành được hiện công khai.

== Mục tiêu và phạm vi

Mục tiêu của đồ án là hiện thực trọn mô hình trên thành một hệ thống chạy được: người dùng đăng nhập bằng số điện thoại, email hoặc Google, đăng tin với AI điền giúp, tìm hàng bằng câu tự nhiên hoặc bằng ảnh, trò chuyện và thương lượng giá có cảnh báo lừa đảo, đặt COD và tạo vận đơn GHTK/GHN, nhận hoặc từ chối hàng tại cửa, đánh giá nhau, và thấy số liệu uy tín của mình thay đổi theo các sự kiện đó. Nhân viên trả lời phiếu hỗ trợ và xử lý báo cáo trên trang điều hành. Hệ thống cũng phải đáng tin cậy ở mức vận hành: khi máy chủ gặp sự cố giữa chừng, đơn không bị mất, vận đơn không bị tạo hai lần và người dùng không nhận hai mã đăng nhập.

Phạm vi gồm hệ thống dịch vụ nền chia theo phân hệ nghiệp vụ, ứng dụng Android và website cho người mua và người bán, trang điều hành cho điều phối viên và quản trị viên, cùng kết nối với GHTK, GHN, dịch vụ xác thực số điện thoại và Google, dịch vụ gửi email, dịch vụ thông báo đẩy và các mô hình AI. Ngoài phạm vi là thanh toán tạm giữ, ứng dụng iOS, giao hàng quốc tế, gian hàng doanh nghiệp theo mô hình B2C, và gọi thoại giữa hai bên.

== Phương pháp thực hiện

Nhóm bắt đầu bằng khảo sát: tìm hiểu cách người dùng đang mua bán đồ cũ trên các trang rao vặt và mạng xã hội, so sánh các nền tảng ở mục 1.2, và liệt kê các rủi ro mà người mua, người bán thường gặp như chuyển khoản rồi mất tiền, bom hàng, bị dụ đặt cọc hay tranh cãi về tình trạng hàng. Mỗi rủi ro được đối chiếu với một nguyên tắc trong mô hình nghiệp vụ ở mục 1.3.

Từ mô hình đó, nhóm mô hình hóa nghiệp vụ bằng UML. Sơ đồ ca sử dụng xác định ai làm gì trên hệ thống; sơ đồ hoạt động mô tả các quy trình đăng tin, thương lượng và giao nhận; sơ đồ trạng thái mô tả vòng đời của tin đăng và đơn hàng. Các quy tắc nghiệp vụ được ghi thành danh mục đánh mã BR, yêu cầu chức năng và phi chức năng được đánh mã REQ và NFR, để mỗi quy tắc truy vết được tới ca sử dụng và ca kiểm thử tương ứng.

Hệ thống được chia theo phân hệ nghiệp vụ: tài khoản, tin đăng, tìm kiếm, trò chuyện, thương lượng và đơn COD, vận chuyển, đánh giá và uy tín, hỗ trợ, thông báo. Mỗi phân hệ chịu trách nhiệm cho một nhóm quy tắc và một phần dữ liệu riêng, nên khi một quy tắc thay đổi thì chỉ một phân hệ phải sửa.

Công việc chia thành ba giai đoạn bốn tuần. Giai đoạn 1 gồm khảo sát, đặc tả, thiết kế tổng thể và nguyên mẫu màn hình. Giai đoạn 2 hoàn thành các quy trình chính trên dữ liệu thật: đăng tin với AI, tìm kiếm, trò chuyện, thương lượng, đặt COD, kết nối hãng vận chuyển, đánh giá và uy tín, cùng website và trang điều hành. Giai đoạn 3 hoàn thiện trợ lý AI cho nhân viên, kiểm thử, đo chất lượng tìm kiếm và triển khai. Cuối mỗi giai đoạn nhóm có một phiên bản chạy được để giáo viên hướng dẫn góp ý.

Kiểm thử được thực hiện theo kịch bản nghiệp vụ: mỗi kịch bản đi trọn một quy trình như người bán đăng tin, người mua trả giá, hai bên chốt giá, hãng báo đã giao hoặc người mua từ chối nhận, rồi kiểm tra kết quả mà từng bên nhìn thấy, gồm trạng thái đơn, tin đăng và số liệu uy tín. Kịch bản chạy trên cơ sở dữ liệu và dịch vụ thật thay vì dữ liệu giả lập, để kết quả phản ánh đúng hành vi khi vận hành.
