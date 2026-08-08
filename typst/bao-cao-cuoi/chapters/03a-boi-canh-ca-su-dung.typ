#import "../../common/tokens.typ": *

== Tầm nhìn và phạm vi đề tài

=== Bối cảnh và động lực nghiệp vụ

Thị trường mua bán đồ đã qua sử dụng giữa các cá nhân tại Việt Nam vận hành trên một nghịch lý dai dẳng: nhu cầu giao dịch rất lớn, nhưng phương tiện giao dịch lại chỉ dừng ở mức một bảng tin. Người bán đăng món đồ của mình lên một nền tảng rao vặt hoặc một hội nhóm mạng xã hội, người mua nhắn tin hỏi, hai bên tự thoả thuận giá, rồi tự xoay xở phần khó nhất là chuyển tiền và chuyển hàng. Ở đúng chỗ khó nhất đó, nền tảng đứng ngoài. Hệ quả là một cấu trúc rủi ro không đối xứng mà cả hai bên đều nhìn thấy nhưng không bên nào tự gỡ được: người mua chuyển khoản trước thì sợ mất tiền, người bán gửi hàng trước thì sợ mất hàng, và khi món hàng nhận được không giống mô tả thì không có ai đứng giữa để phán xử ngoài chính hai người vừa mâu thuẫn với nhau.

Chi phí của khoảng trống này không chỉ là những vụ lừa đảo đơn lẻ. Nó là toàn bộ khối giao dịch đã không xảy ra, vì người mua ở tỉnh khác không dám mua món đồ trị giá vài triệu đồng từ một người lạ, và vì người bán không muốn nhận hàng hoàn về sau một chuyến giao thất bại. Nó cũng là chi phí thời gian: một cuộc thương lượng giá diễn ra rải rác trong hàng chục tin nhắn, không có mốc nào ràng buộc, và cuối cùng một trong hai bên đơn phương im lặng. Mô hình sàn thương mại điện tử chuyên nghiệp đã giải quyết được những vấn đề này cho người bán chuyên nghiệp, nhưng lại dựng lên một hàng rào khác: thủ tục mở gian hàng, mã sản phẩm, cấu hình kho, chính sách vận hành và mức phí hoa hồng vốn được thiết kế cho người bán hàng trăm đơn một tháng, chứ không cho một người muốn thanh lý một chiếc máy ảnh cũ.

ShopNexus được đặt vấn đề ở chính giữa hai thái cực đó: giữ lại sự nhẹ nhàng của việc đăng một món đồ lên bảng tin, nhưng đưa vào đằng sau nó đủ hạ tầng để một giao dịch từ xa giữa hai người lạ trở nên an toàn — tiền được sàn giữ hộ cho tới khi hàng đến nơi, giá được đóng băng khi hai bên đã đồng thuận, mọi khiếu nại đều có một nơi để gửi và một người để trả lời, và mọi quyết định về tiền đều để lại dấu vết đối soát được.

=== Mục tiêu và tiêu chí thành công

Tầm nhìn trên được cụ thể hoá thành năm mục tiêu có thể đo lường, mỗi mục tiêu gắn với một cơ chế cụ thể trong hệ thống chứ không dừng ở một phát biểu định tính.

#figure(
  kind: table,
  caption: [Mục tiêu dự án và tiêu chí đo lường],
  table(
    columns: (0.5fr, 1.35fr, 1.5fr),
    align: (center + horizon, left + top, left + top),
    table.header([Mã], [Mục tiêu], [Tiêu chí thành công]),
    [MT-1],
    [Loại bỏ rủi ro thanh toán trước trong giao dịch giữa hai cá nhân ở xa nhau.],
    [Một trăm phần trăm giao dịch mua bán đi qua cơ chế ký quỹ; không tồn tại đường đi nào chuyển thẳng tiền từ người mua sang người bán mà không qua tài khoản giữ hộ của sàn.],

    [MT-2],
    [Rút ngắn quãng đường từ lúc quan tâm một món hàng tới lúc trả tiền xong.],
    [Người mua hoàn tất một giao dịch giá cố định trong không quá năm bước thao tác kể từ trang chi tiết sản phẩm; giá và phí giao hàng được đóng băng trong suốt phiên thanh toán mười lăm phút.],

    [MT-3],
    [Biến thương lượng giá từ một cuộc trò chuyện không ràng buộc thành một thủ tục có hiệu lực pháp lý nội bộ.],
    [Mỗi vòng thương lượng có một mức giá duy nhất đang trên bàn, một bên đang phải trả lời, và một mốc hết hạn mười hai giờ; giá được chấp thuận được giữ nguyên ba mươi phút để người mua thanh toán.],

    [MT-4],
    [Bảo đảm mọi khiếu nại đều có nơi tiếp nhận và có kết luận.],
    [Mọi loại yêu cầu gửi lên sàn — tố cáo tin đăng, khiếu nại hoàn tiền, sự cố đơn hàng, vướng mắc thanh toán, đề xuất tính năng — nằm trong một hàng đợi duy nhất; không tồn tại trạng thái nào của một khiếu nại mà không có bên nào chịu trách nhiệm trả lời.],

    [MT-5],
    [Bảo đảm mọi biến động tiền và mọi quyết định quản trị đều truy vết được.],
    [Mỗi biến động số dư có một bút toán đối ứng; mỗi quyết định nghiệp vụ để lại một bản ghi kiểm toán chỉ-thêm-mới, được ghi trong cùng giao dịch cơ sở dữ liệu với chính thay đổi đó.],
  )
)

Cả năm mục tiêu được đặt trong khung thời gian mười sáu tuần của kỳ thực tập, với hai mốc nghiệm thu trung gian để tiêu chí đo được không bị dồn về cuối. Tại tuần thứ mười, MT-1, MT-2 và MT-5 phải đạt trên một bản chạy được đi trọn vòng đời từ đăng bán tới lúc tiền về ví người bán; tại tuần thứ mười bốn, MT-3 và MT-4 phải đạt cùng với toàn bộ luồng hoàn tiền và phân xử. Hai tuần còn lại dành cho đo hiệu năng, hoàn thiện tài liệu và các hạng mục ưu tiên thấp.

=== Phạm vi

Phạm vi của đề tài là phần lõi nghiệp vụ phía máy chủ của một sàn thương mại điện tử giữa các cá nhân, cùng hợp đồng giao diện lập trình mà các ứng dụng khách sử dụng. Trong phạm vi có: vòng đời tài khoản và phiên đăng nhập, xác minh danh tính điện tử, vòng đời tin đăng và kiểm duyệt của người thật, tìm kiếm lai ghép giữa từ khoá và ngữ nghĩa, hội thoại thời gian thực, thương lượng giá, chuẩn bị đơn mua và báo giá vận chuyển, thanh toán qua cổng bên thứ ba với cơ chế ký quỹ, vòng đời đơn hàng và kiện hàng, yêu cầu hoàn tiền cùng thủ tục phân xử, ví điện tử và rút tiền, đánh giá hai chiều cùng đánh giá sản phẩm, hệ thống phiếu hỗ trợ hợp nhất, và khối quan trắc vận hành.

Ngoài phạm vi, và được nêu tường minh để tránh hiểu nhầm về năng lực hệ thống: hệ thống không tự động quét và phát hiện hàng cấm — mọi tin đăng khi công bố đều vào hàng đợi duyệt của người thật; không thu hoa hồng trên giá trị hàng hoá; không chia phí giao hàng giữa hai bên, vì người mua luôn trả toàn bộ; không tự động xác nhận đã nhận hàng thay người mua; không tự huỷ đơn và không tự hoàn tiền khi người bán để quá hạn xác nhận. Việc tích hợp với một hãng vận chuyển thật cũng nằm ngoài phạm vi giai đoạn này: khe cắm nhà cung cấp vận chuyển đã được định nghĩa đầy đủ và một bản hiện thực mô phỏng được dùng để đi hết mọi nhánh nghiệp vụ, nhưng chưa có hợp đồng với một đối tác thương mại nào. Phần phân tích hành vi người dùng ở mức sản phẩm được thu thập bởi một nền tảng riêng phía ứng dụng khách, không nằm trong máy chủ này. Sau cùng, hệ thống dừng lại ở mức gỡ tin và khoá tài khoản; việc chuyển hồ sơ cho cơ quan chức năng không được tự động hoá.

=== Ràng buộc, giả định và rủi ro

Ràng buộc lớn nhất là ràng buộc về tính đúng đắn của dòng tiền: mọi lựa chọn kỹ thuật đều phải phục tùng nguyên tắc một khoản tiền chỉ ở đúng một chỗ tại một thời điểm, kể cả khi người dùng bấm hai lần, kể cả khi một tiến trình bị khởi động lại giữa chừng, và kể cả khi cổng thanh toán gửi cùng một thông báo hai lần. Ràng buộc thứ hai là ngân sách vận hành của một đề tài thực tập: hệ thống phải chạy được trọn vẹn trên một máy với hạ tầng nguồn mở, không phụ thuộc dịch vụ đám mây trả phí nào, và phải chạy được cả khi thành phần điều phối tiến trình bền không được bật.

Ba giả định nền tảng được ghi nhận. Thứ nhất, người dùng có tài khoản ngân hàng và có thể thực hiện chuyển khoản trực tuyến — đây là cơ sở của toàn bộ mô hình ký quỹ. Thứ hai, người bán chấp nhận việc phải xác minh danh tính trước khi được đăng bán và trước khi được rút tiền, đổi lại là uy tín trên sàn. Thứ ba, thời hạn của các mốc chờ là lời hứa với người dùng chứ không phải tham số vận hành, nên chúng được cố định trong hệ thống thay vì để lộ ra một bảng cấu hình mà người vận hành có thể sửa giữa chừng.

Rủi ro chính đe doạ các mục tiêu trên là rủi ro vận hành thủ công: vì không có bộ lọc tự động, năng lực kiểm duyệt tin đăng và xử lý phiếu hỗ trợ tỉ lệ thuận với số điều phối viên, nên một đợt tăng trưởng đột ngột sẽ làm hàng đợi dài ra chứ không làm hệ thống sai. Rủi ro thứ hai là phụ thuộc bên thứ ba ở hai điểm sinh tử là cổng thanh toán và hãng vận chuyển; kiến trúc trả lời rủi ro này bằng một sổ tuỳ chọn cho phép nhiều nhà cung cấp cùng sống và cho phép chuyển đổi mà không dừng hệ thống. Rủi ro thứ ba là rủi ro lạm dụng cơ chế hoàn tiền, được kiềm chế bằng nguyên tắc hàng phải quay về trước khi tiền quay về, và bằng cửa sổ kiểm hàng của người bán.

== Phân tích thị trường và các công trình liên quan

=== Các mô hình đang phục vụ thị trường

Ba mô hình đang chiếm phần lớn lưu lượng giao dịch giữa các cá nhân tại Việt Nam, và mỗi mô hình để lại một khoảng trống khác nhau.

Mô hình rao vặt, tiêu biểu là Chợ Tốt, mạnh ở khả năng phủ và ở tốc độ đăng tin. Phân loại theo khu vực địa lý rất tốt, giúp hai người ở gần nhau tìm được nhau. Nhưng bản chất của nền tảng là một bảng tin: sau khi hai bên kết nối, mọi việc còn lại diễn ra ngoài hệ thống. Không có cơ chế giữ tiền, nên người mua ở xa hoặc phải chuyển khoản đặt cọc cho một người lạ, hoặc phải bỏ giao dịch. Khi món hàng không đúng mô tả, nền tảng không có công cụ nào để can thiệp vì nó chưa từng nắm giữ đồng tiền nào.

Mô hình mạng xã hội, tiêu biểu là Facebook Marketplace và các hội nhóm mua bán, mạnh ở khả năng lan truyền và ở việc tận dụng một mạng lưới quan hệ có sẵn. Đổi lại, nó thiếu gần như toàn bộ chuẩn mực của một sàn: không có quản lý đơn hàng, không có cổng thanh toán tích hợp, không có chính sách hoàn tiền, và không có cơ chế nào ngăn một tài khoản giả mạo lặp lại cùng một thủ đoạn.

Mô hình sàn được quản lý, tiêu biểu là Shopee và Lazada, đã giải quyết trọn vẹn bài toán an toàn giao dịch bằng hệ sinh thái logistics và chính sách bảo vệ người mua. Nhưng toàn bộ thiết kế của nó hướng tới người bán chuyên nghiệp: thủ tục mở gian hàng, mã sản phẩm, cấu hình kho, thông tin thuế, và mức phí trên mỗi đơn hàng. Với một cá nhân chỉ muốn bán một hoặc hai món đồ, chi phí gia nhập lớn hơn giá trị món hàng. Thêm vào đó, cơ chế giá của mô hình này được thiết kế quanh mã giảm giá và chương trình khuyến mãi, chứ không quanh việc hai cá nhân mặc cả trực tiếp với nhau — vốn là hành vi tự nhiên nhất của thị trường đồ cũ.

#figure(
  kind: table,
  caption: [So sánh các mô hình nền tảng theo năng lực nghiệp vụ cốt lõi],
  table(
    columns: (1.15fr, 0.85fr, 0.85fr, 0.9fr, 0.85fr),
    align: (left + top, left + top, left + top, left + top, left + top),
    table.header([Năng lực], [Rao vặt], [Mạng xã hội], [Sàn được quản lý], [ShopNexus]),

    [Giữ tiền hộ tới khi nhận hàng], [Không], [Không], [Có], [Có, là đường đi duy nhất],
    [Chi phí gia nhập của người bán cá nhân], [Rất thấp], [Rất thấp], [Cao], [Thấp, chỉ cần xác minh danh tính],
    [Phí trên giá trị hàng hoá], [Không], [Không], [Cao], [Không],
    [Thương lượng giá có ràng buộc], [Không], [Không], [Hạn chế], [Có, luân phiên và có hạn hiệu lực],
    [Quy trình khiếu nại và phân xử], [Không], [Không], [Có], [Có, hợp nhất trong một hàng đợi],
    [Kiểm duyệt nội dung đăng bán], [Có, mức cơ bản], [Rất hạn chế], [Có], [Có, do người thật duyệt toàn bộ],
    [Đánh giá chống trả đũa], [Không], [Không], [Một chiều], [Hai chiều, theo cơ chế ẩn],
  )
)

=== Định vị của đề tài

Bảng so sánh cho thấy khoảng trống mà đề tài nhắm tới không phải là một tính năng đơn lẻ mà là một tổ hợp: chi phí gia nhập thấp của mô hình rao vặt, cộng với bảo đảm tài chính của mô hình sàn được quản lý, cộng với một cơ chế thương lượng giá mà cả hai mô hình kia đều không có. Ba lựa chọn thiết kế đi ra trực tiếp từ định vị này và sẽ được nhắc lại nhiều lần ở các mục sau. Thứ nhất, sàn không thu hoa hồng trên giá trị hàng hoá, vì mức phí là rào cản đầu tiên đẩy người bán cá nhân quay lại các hội nhóm. Thứ hai, mọi tin đăng đều mua thẳng được từ trang chi tiết, còn thương lượng là một con đường bổ sung chứ không phải một con đường thay thế — người bán không bao giờ phải phê duyệt việc có bán hay không, thứ duy nhất họ có thể từ chối là một mức giá. Thứ ba, sàn đứng giữa ở đúng hai chỗ mà hai bên không thể tự tin nhau: giữ tiền, và phân xử khi có tranh cãi.

== Chân dung người dùng và các bên liên quan

=== Ba chân dung người dùng đại diện

Ba chân dung dưới đây phủ dải năng lực công nghệ từ người mới dùng tới người dùng thành thạo, vì một hệ thống chỉ được thiết kế cho người dùng thạo việc là một hệ thống mà người bán lần đầu bỏ dở ngay ở biểu mẫu đăng tin.

*Minh, 27 tuổi, nhân viên văn phòng tại Hà Nội — người bán không chuyên, người dùng mới.* Minh đổi điện thoại và máy ảnh khoảng một lần mỗi năm, mỗi lần lại có ba tới bốn món đồ cũ cần thanh lý. Kỹ năng công nghệ ở mức cơ bản: dùng thành thạo mạng xã hội và ứng dụng nhắn tin, nhưng chưa từng mở gian hàng trên một sàn thương mại điện tử nào và không biết những khái niệm như phiên bản sản phẩm hay mã vận đơn. Minh dùng điện thoại là chính, hiếm khi mở máy tính để đăng bán. Mục tiêu của Minh là bán được nhanh với giá hợp lý và không phải trả lời cùng một câu hỏi hai mươi lần. Điều khiến Minh khó chịu nhất ở cách làm hiện tại là phải soạn thủ công phần mô tả cho từng món và phải chờ người mua chuyển khoản rồi mới dám gửi hàng. Minh dùng hệ thống theo từng đợt: vài ngày liên tục khi có đồ cần bán, rồi im lặng vài tháng. Một ngày tốt với Minh là chụp năm tấm ảnh, nói vài câu vào điện thoại, xem hệ thống điền sẵn giúp phần lớn biểu mẫu, sửa lại giá rồi bấm đăng. Câu Minh hay nói: _"Tôi chỉ muốn bán cái máy ảnh này, đừng bắt tôi học cách làm chủ một cửa hàng."_

*Lan, 22 tuổi, sinh viên tại Đà Nẵng — người mua nhạy giá, người dùng thành thạo.* Lan mua đồ cũ vì ngân sách hạn chế: sách, đồ điện tử nhỏ, đồ dùng phòng trọ. Kỹ năng công nghệ tốt, quen mặc cả, và rất cảnh giác. Nỗi sợ lớn nhất của Lan là chuyển khoản cho một người ở tỉnh khác rồi không nhận được gì, nên trước đây Lan chỉ dám mua của người bán trong cùng thành phố để giao dịch trực tiếp. Lan dùng hệ thống hằng tuần, chủ yếu là tìm kiếm và so sánh. Điều Lan cần là biết chắc tiền của mình không đi thẳng vào túi người bán, và biết chắc rằng nếu món hàng không giống ảnh thì có một nơi để khiếu nại chứ không phải chỉ có một dòng tin nhắn bị chặn. Câu Lan hay nói: _"Tôi trả giá được thì tôi mua; nhưng tiền của tôi phải nằm ở chỗ nào đó lấy lại được đã."_

*Trang, 31 tuổi, điều phối viên vận hành của sàn — người dùng nội bộ, người dùng chuyên gia.* Trang xử lý hàng đợi kiểm duyệt tin đăng, hàng đợi phiếu hỗ trợ, hồ sơ xác minh danh tính và các yêu cầu hoàn tiền được chuyển lên. Kỹ năng công nghệ ở mức thành thạo công cụ nội bộ. Trang làm việc theo ca, mỗi ca xử lý vài chục hồ sơ, nên thứ Trang cần là ngữ cảnh đầy đủ hiện ngay trên một màn hình: nội dung bị tố cáo, số phiếu đang mở nhắm vào cùng đối tượng, lịch sử hội thoại của phiếu, và bằng chứng của cả hai phía. Điều Trang lo nhất là phán quyết sai vì thiếu ngữ cảnh, và việc một hồ sơ bị bỏ quên vì nó nằm ở một danh sách khác mà không ai mở. Câu Trang hay nói: _"Đừng bắt tôi mở bốn danh sách để biết một người đã bị tố cáo mấy lần."_

=== Sổ đăng ký các bên liên quan

#figure(
  kind: table,
  caption: [Sổ đăng ký các bên liên quan và chiến lược tương tác],
  table(
    columns: (1fr, 0.62fr, 0.62fr, 0.62fr, 1.5fr),
    align: (left + top, center + horizon, center + horizon, center + horizon, left + top),
    table.header([Bên liên quan], [Nhóm], [Quyền lực], [Quan tâm], [Mối quan tâm chính và cách tương tác]),

    [Người dùng cuối (vừa mua vừa bán)], [Chính], [Thấp], [Cao], [An toàn tiền và hàng, tốc độ thao tác. Tiếp cận qua phỏng vấn và qua chính hàng đợi phiếu hỗ trợ, vốn là kênh phản hồi trực tiếp nhất.],

    [Điều phối viên], [Chính], [T. bình], [Cao], [Đủ ngữ cảnh để phán quyết, không bỏ sót hồ sơ. Tham gia thiết kế màn hình quản trị và định nghĩa các hàng đợi.],

    [Quản trị viên hệ thống], [Chính], [Cao], [Cao], [Cấu hình nhà cung cấp thanh toán và vận chuyển, đối soát ví, cấp phát tài khoản điều phối viên. Quyết định mọi thay đổi ảnh hưởng dòng tiền.],

    [Bàn hỗ trợ], [Chính], [Thấp], [Cao], [Là một tài khoản kỹ thuật đại diện cho tập thể nhân viên hỗ trợ, đối tác hội thoại của mọi phiếu; giữ cho danh tính cá nhân của nhân viên không lộ ra người khiếu nại.],

    [Giảng viên hướng dẫn], [Dự án], [Cao], [Cao], [Tiến độ, chất lượng tài liệu và mức độ hoàn chỉnh của hệ thống. Báo cáo định kỳ theo tuần.],

    [Nhà cung cấp cổng thanh toán], [Phụ], [T. bình], [T. bình], [Tính đúng đắn của đối soát và của xử lý thông báo lặp. Trao đổi qua tài liệu tích hợp; hệ thống phải chịu được việc nhà cung cấp gửi lại cùng một thông báo.],

    [Đối tác vận chuyển], [Phụ], [T. bình], [Thấp], [Chất lượng dữ liệu địa chỉ và tính ổn định của luồng cập nhật hành trình. Ở giai đoạn này được đại diện bằng một bản hiện thực mô phỏng.],

    [Nhà cung cấp xác minh danh tính], [Phụ], [Thấp], [Thấp], [Chất lượng ảnh giấy tờ gửi lên. Phán quyết của nhà cung cấp vẫn có thể bị điều phối viên phủ quyết.],

    [Cơ quan quản lý về bảo vệ dữ liệu cá nhân], [Phụ], [Cao], [Thấp], [Việc thu thập, lưu trữ và xoá dữ liệu định danh phải tuân thủ quy định hiện hành. Ảnh hưởng trực tiếp tới thiết kế lưu trữ hồ sơ xác minh.],
  )
)

Ba nhóm ở cột quyền lực cao cần được quản lý sát: giảng viên hướng dẫn quyết định phạm vi và tiến độ, quản trị viên quyết định mọi thay đổi chạm vào dòng tiền, và yêu cầu pháp lý về dữ liệu cá nhân là ràng buộc không thương lượng được. Ngược lại, nhóm người dùng cuối tuy quyền lực thấp nhưng quan tâm rất cao và là nguồn yêu cầu phong phú nhất; đây cũng là lý do hệ thống phiếu hỗ trợ được thiết kế để nhận cả loại phiếu đề xuất tính năng, biến kênh khiếu nại thành kênh thu thập yêu cầu.

Sổ đăng ký trên cho biết ai quan tâm tới điều gì, nhưng chưa nói ai được quyền quyết. Bảng dưới đây phân vai cho năm quyết định có khả năng làm đổi phạm vi hoặc đổi dòng tiền, theo bốn vai quen thuộc: chịu trách nhiệm thực hiện, chịu trách nhiệm sau cùng, được hỏi ý kiến, và được thông báo.

#figure(
  kind: table,
  caption: [Phân vai trách nhiệm cho các quyết định trọng yếu của dự án],
  table(
    columns: (1.5fr, 0.72fr, 0.72fr, 0.72fr, 0.72fr, 0.8fr),
    align: (left + top, center + horizon, center + horizon, center + horizon, center + horizon, center + horizon),
    table.header([Quyết định], [Nhóm\ thực hiện], [Giảng viên\ hướng dẫn], [Quản trị\ viên], [Điều phối\ viên], [Người\ dùng cuối]),
    [Chốt phạm vi và danh mục ca sử dụng], [Thực hiện], [Quyết định], [Được hỏi], [Được hỏi], [Được hỏi],
    [Đặt các mốc thời gian nghiệp vụ (12 giờ, 15 phút, 48 giờ, 72 giờ)], [Thực hiện], [Được hỏi], [Quyết định], [Được hỏi], [Được báo],
    [Bật, tắt hoặc chuyển nhà cung cấp thanh toán và vận chuyển], [Thực hiện], [Được báo], [Quyết định], [Được báo], [Được báo],
    [Định nghĩa hàng đợi kiểm duyệt và tiêu chí phán quyết], [Thực hiện], [Được báo], [Được hỏi], [Quyết định], [Được báo],
    [Thay đổi cách thu thập và lưu trữ dữ liệu định danh], [Thực hiện], [Được hỏi], [Quyết định], [Được báo], [Được báo],
  )
)

== Ngữ cảnh hệ thống

=== Các thực thể ngoài biên và dòng thông tin

Ở mức ngữ cảnh, toàn bộ nền tảng được nhìn như một khối duy nhất. Bên ngoài khối đó có ba nhóm tác nhân người và tám nhóm hệ thống ngoại vi.

Nhóm tác nhân người gồm người dùng cuối — một tài khoản duy nhất mang cả vai người mua lẫn vai người bán, nên toàn bộ luồng đăng bán, tìm kiếm, thương lượng, thanh toán, khiếu nại và rút tiền đều đi qua nhóm này; điều phối viên, làm việc trên các hàng đợi kiểm duyệt, phiếu hỗ trợ, hồ sơ xác minh danh tính và yêu cầu hoàn tiền được chuyển lên; và quản trị viên, người cấp phát tài khoản điều phối viên, quản lý sổ tuỳ chọn nhà cung cấp và đối soát ví. Cần lưu ý bàn hỗ trợ không phải một tác nhân ngoài biên mà là một tài khoản bên trong hệ thống: điều phối viên trả lời phiếu với tư cách của tài khoản đó, nên người khiếu nại luôn nhìn thấy một đối tác hội thoại duy nhất và không biết cá nhân nào đang trả lời mình.

Nhóm hệ thống ngoại vi gồm cổng thanh toán, nhận yêu cầu khởi tạo một phiên trả tiền và gửi ngược thông báo kết quả theo thời gian thực; đối tác vận chuyển, nhận yêu cầu báo giá theo cặp địa chỉ, nhận lệnh đặt vận đơn và đẩy về các mốc hành trình của kiện hàng; dịch vụ xác minh danh tính điện tử, nhận ảnh giấy tờ cùng ảnh chân dung và trả về một phán quyết; dịch vụ thư điện tử và tin nhắn ngắn, nhận các mã dùng một lần phục vụ xác minh địa chỉ thư, đặt lại mật khẩu và xác minh số điện thoại; nhà cung cấp định danh liên kết, được hỏi để xác thực một thẻ định danh mà người dùng mang tới từ tài khoản mạng xã hội của họ; dịch vụ mô hình ngôn ngữ, nhận ảnh sản phẩm cùng ghi chú của người bán và trả về một biểu mẫu tin đăng đã điền sẵn; kho lưu trữ đối tượng, giữ toàn bộ ảnh và tệp đính kèm và cấp các đường tải lên, tải xuống có chữ ký; và nền tảng giám sát, nhận nhật ký cùng dữ liệu đo lường của hệ thống theo một chiều duy nhất đi ra.

Điểm cần nhấn ở mức ngữ cảnh là chiều của các dòng thông tin quyết định tiền. Yêu cầu khởi tạo thanh toán đi ra, nhưng bằng chứng của việc trả tiền chỉ đi vào theo một đường duy nhất là thông báo từ cổng thanh toán; trang mà người trả tiền được chuyển tới sau khi thanh toán không phải là bằng chứng, vì đó là thứ bất kỳ ai cũng có thể tự mở. Tương tự, hành trình kiện hàng đi vào theo thông báo của hãng vận chuyển, nhưng việc kết thúc đơn hàng thì không: nó chỉ xảy ra khi chính người mua chủ động xác nhận.

#fig(
  [Sơ đồ ngữ cảnh hệ thống ShopNexus],
  spacing: (56mm, 13mm),

  nt((0, 0), [*Người dùng*\ (mua và bán)]),
  nt((0, 1.6), [*Điều phối viên*\ (kiểm duyệt, phân xử)]),
  nt((0, 3.2), [*Quản trị viên*\ (cấu hình, đối soát)]),

  ncore((1, 1.6), [NỀN TẢNG\ SHOPNEXUS\ \ Sàn giao dịch\ giữa cá nhân\ \ Ký quỹ · Hội thoại\ Phiếu hỗ trợ], width: 46mm),

  ng((2, -0.5), [*Cổng thanh toán*]),
  ng((2, 0.6), [*Đối tác vận chuyển*]),
  ng((2, 1.7), [*Dịch vụ xác minh*\ *danh tính*]),
  ng((2, 2.8), [*Thư điện tử*\ *và tin nhắn ngắn*]),
  ng((2, 3.9), [*Định danh liên kết*\ (OIDC)]),
  ng((2, 5.0), [*Mô hình ngôn ngữ*]),
  ng((2, 6.1), [*Kho lưu trữ đối tượng*]),
  ng((2, 7.2), [*Nền tảng giám sát*]),

  edge((0, 0), (1, 1.6), "<|-|>", text(size: 8pt)[Đăng bán, mua, khiếu nại], label-pos: 0.5, label-side: right),
  edge((0, 1.6), (1, 1.6), "<|-|>", text(size: 8pt)[Hàng đợi, phán quyết], label-pos: 0.5, label-side: left),
  edge((0, 3.2), (1, 1.6), "<|-|>", text(size: 8pt)[Cấu hình, đối soát], label-pos: 0.5, label-side: left),

  edge((1, 1.6), (2, -0.5), "-|>", text(size: 7.5pt)[Yêu cầu mở phiên trả tiền], label-pos: 0.5, label-side: left, bend: 11deg),
  edge((2, -0.5), (1, 1.6), "-|>", text(size: 7.5pt)[Thông báo kết quả trả tiền], label-pos: 0.5, label-side: left, bend: 11deg),
  edge((1, 1.6), (2, 0.6), "-|>", text(size: 7.5pt)[Xin báo giá, đặt vận đơn], label-pos: 0.5, label-side: left, bend: 11deg),
  edge((2, 0.6), (1, 1.6), "-|>", text(size: 7.5pt)[Mức phí, mốc hành trình], label-pos: 0.5, label-side: left, bend: 11deg),
  edge((1, 1.6), (2, 1.7), "<|-|>", text(size: 8pt)[Ảnh giấy tờ, phán quyết], label-pos: 0.5, label-side: left),
  edge((1, 1.6), (2, 2.8), "-|>", text(size: 8pt)[Mã dùng một lần], label-pos: 0.5, label-side: right),
  edge((1, 1.6), (2, 3.9), "<|-|>", text(size: 8pt)[Xác thực thẻ định danh], label-pos: 0.55, label-side: right),
  edge((1, 1.6), (2, 5.0), "<|-|>", text(size: 8pt)[Ảnh và ghi chú, biểu mẫu gợi ý], label-pos: 0.55, label-side: right),
  edge((1, 1.6), (2, 6.1), "<|-|>", text(size: 8pt)[Ảnh, tệp đính kèm], label-pos: 0.6, label-side: right),
  edge((1, 1.6), (2, 7.2), "-|>", text(size: 8pt)[Nhật ký, số đo vận hành], label-pos: 0.6, label-side: right),
)

#note[*Chú giải ký hiệu.* Hình chữ nhật viền đậm ở trung tâm là ranh giới hệ thống, được vẽ như một khối duy nhất theo đúng quy ước sơ đồ ngữ cảnh mức không. Hình viên thuốc là tác nhân người; hình chữ nhật ở vành ngoài là hệ thống ngoại vi. Mũi tên một đầu là dòng một chiều; mũi tên hai đầu chỉ được dùng khi hai chiều mang cùng một loại nội dung trong cùng một lượt gọi. Hai luồng quyết định tiền và hàng — thanh toán và vận chuyển — được tách thành hai mũi tên một chiều có nhãn riêng, vì chiều đi ra là một yêu cầu do hệ thống chủ động phát, còn chiều đi vào là một thông báo do đối tác chủ động gửi và chính nó mới là bằng chứng. Trừ hai luồng gửi mã dùng một lần và gửi dữ liệu quan trắc mang tính nền, toàn bộ các dòng còn lại đều là thời gian thực, phát sinh theo thao tác của người dùng hoặc theo thông báo của đối tác.]

=== Phụ thuộc then chốt

Hai phụ thuộc có khả năng làm gãy nghiệp vụ chứ không chỉ làm chậm nó. Thứ nhất là thông báo kết quả từ cổng thanh toán: đơn hàng chỉ ra đời khi thông báo này đến, nên một thông báo mất là một khoản tiền đã thu mà chưa có đơn. Hệ thống trả lời bằng cách coi việc xử lý thông báo là bất biến với lặp lại và bằng cách báo lỗi cho nhà cung cấp khi xử lý thất bại, để nhà cung cấp gửi lại. Thứ hai là dịch vụ báo giá vận chuyển: nếu không hãng nào báo được giá thì người mua không thể sang bước trả tiền, vì hệ thống từ chối đoán một mức phí. Đây là lựa chọn có chủ ý — một bảng phí dự phòng sẽ khiến sàn phải bù phần chênh lệch cho một chuyến hàng mà nó chưa từng hỏi giá.

== Danh mục ca sử dụng

=== Nguyên tắc phân rã

Mỗi ca sử dụng dưới đây biểu diễn một mục tiêu trọn vẹn của tác nhân chứ không phải một thao tác đơn lẻ, và được đặt tên theo mẫu động từ cộng danh từ. Danh mục gồm ba mươi ca sử dụng nghiệp vụ, đánh mã liên tục từ UC-01 tới UC-30 và chia thành sáu nhóm chức năng, cộng thêm hai ca sử dụng con dùng chung được nhiều ca khác gọi tới theo quan hệ bao hàm. Số lượng này vượt khung tham chiếu thông thường mười tới hai mươi ca, vì hệ thống bao trùm cả sàn giao dịch, khối tài chính, khối tín nhiệm và khối vận hành nội bộ; việc chia nhóm và tách sơ đồ theo phân hệ ở mục sau là để bù lại độ lớn đó.

#figure(
  kind: table,
  caption: [Danh mục ca sử dụng của hệ thống ShopNexus],
  table(
    columns: (0.42fr, 1.45fr, 1fr, 2.5fr, 0.52fr),
    align: (center + horizon, left + top, left + top, left + top, center + horizon),
    table.header([Mã], [Tên ca sử dụng], [Tác nhân chính], [Mô tả ngắn gọn], [Ưu tiên]),

    table.cell(colspan: 5, align: left)[*Nhóm A — Định danh, tài khoản và phân quyền*],
    [UC-01], [Đăng ký tài khoản], [Người dùng], [Tạo tài khoản bằng địa chỉ thư điện tử hoặc bằng một thẻ định danh liên kết.], [Cao],
    [UC-02], [Đăng nhập và quản lý phiên], [Mọi vai trò], [Xác thực, mở một phiên đăng nhập được tra cứu ở mỗi yêu cầu; đăng xuất thu hồi phiên hiện tại, đổi mật khẩu thu hồi mọi phiên còn lại.], [Cao],
    [UC-03], [Xác minh danh tính điện tử], [Người dùng], [Gửi ảnh giấy tờ và ảnh chân dung để được cấp quyền đăng bán và quyền rút tiền.], [Cao],
    [UC-04], [Quản lý hồ sơ, sổ địa chỉ và thiết bị], [Người dùng], [Cập nhật thông tin hiển thị, khai báo địa chỉ giao và địa chỉ lấy hàng, đăng ký thiết bị nhận thông báo.], [T. bình],
    [UC-05], [Cấp phát tài khoản điều phối viên], [Quản trị viên], [Tạo hoặc thu hồi tài khoản điều phối viên; vai trò này không tự đăng ký được.], [Cao],

    table.cell(colspan: 5, align: left)[*Nhóm B — Đăng bán và khám phá*],
    [UC-06], [Đăng bán sản phẩm], [Người bán], [Soạn tin đăng, chọn chế độ giá, khai báo tồn kho theo phiên bản và gửi tin vào hàng đợi duyệt.], [Cao],
    [UC-07], [Gợi ý điền tin đăng bằng trí tuệ nhân tạo], [Người bán], [Từ ảnh sản phẩm cùng ghi chú gõ tay hoặc ghi âm, nhận về một biểu mẫu tin đăng đã điền sẵn để sửa lại.], [T. bình],
    [UC-08], [Chỉnh sửa tin đăng đang hiển thị], [Người bán], [Gửi một bản sửa; bản sửa chờ duyệt trong khi bản đang hiển thị giữ nguyên.], [T. bình],
    [UC-09], [Tìm kiếm và duyệt sản phẩm], [Người mua], [Truy vấn bằng từ khoá tự nhiên kết hợp tìm kiếm ngữ nghĩa, lọc và sắp xếp theo nhiều tiêu chí.], [Cao],
    [UC-10], [Theo dõi người bán và lưu sản phẩm quan tâm], [Người mua], [Theo dõi một người bán, đánh dấu sản phẩm để xem lại.], [Thấp],

    table.cell(colspan: 5, align: left)[*Nhóm C — Trao đổi và thương lượng*],
    [UC-11], [Nhắn tin thời gian thực], [Người dùng], [Trao đổi trực tiếp kèm ảnh và tệp, nhận tin tức thời, theo dõi dấu đã đọc và số tin chưa đọc.], [Cao],
    [UC-12], [Thương lượng giá], [Người mua], [Mở một thương lượng trên tin đăng cho phép trả giá, hai bên luân phiên đề xuất cho tới khi một bên chấp thuận.], [Cao],

    table.cell(colspan: 5, align: left)[*Nhóm D — Giao dịch, ký quỹ và vận chuyển*],
    [UC-13], [Chuẩn bị đơn mua và lấy báo giá vận chuyển], [Người mua], [Chọn hàng, chọn địa chỉ nhận, xin báo giá của từng hãng vận chuyển và chốt một phương án.], [Cao],
    [UC-14], [Thanh toán và ký quỹ], [Người mua], [Mở phiên trả tiền tại cổng thanh toán; khi cổng báo về, tiền vào ký quỹ và đơn hàng ra đời.], [Cao],
    [UC-15], [Xác nhận đơn hàng đã thanh toán], [Người bán], [Xác nhận đơn trong bốn mươi tám giờ để mở đường cho việc đặt vận đơn, hoặc từ chối kèm lý do.], [Cao],
    [UC-16], [Theo dõi hành trình kiện hàng], [Người mua], [Xem các mốc hành trình do hãng vận chuyển báo về theo thứ tự tiến tới.], [T. bình],
    [UC-17], [Xác nhận đã nhận hàng], [Người mua], [Xác nhận kèm bằng chứng, khởi động cửa sổ bảy mươi hai giờ trước khi tiền về người bán.], [Cao],
    [UC-18], [Quản lý ví và rút tiền], [Người dùng], [Theo dõi số dư khả dụng và số dư đang giữ, xem sổ bút toán, gửi yêu cầu rút về tài khoản ngân hàng.], [Cao],

    table.cell(colspan: 5, align: left)[*Nhóm E — Hậu giao dịch và uy tín*],
    [UC-19], [Yêu cầu trả hàng và hoàn tiền], [Người mua], [Mở yêu cầu kèm lý do và bằng chứng ở bất kỳ thời điểm nào trước khi đơn kết thúc.], [Cao],
    [UC-20], [Xử lý yêu cầu hoàn tiền], [Người bán], [Chấp nhận cho trả hàng, hoặc chuyển hồ sơ cho sàn phân xử; không có lựa chọn từ chối.], [Cao],
    [UC-21], [Đánh giá hai chiều theo cơ chế ẩn], [Người dùng], [Đánh giá đối tác sau khi đơn kết thúc; đánh giá bị ẩn cho tới khi cả hai bên gửi hoặc hết mười bốn ngày.], [T. bình],
    [UC-22], [Đánh giá sản phẩm và bình chọn hữu ích], [Người mua], [Viết nhận xét cho sản phẩm đã mua, phản hồi nhận xét, bình chọn một nhận xét là hữu ích.], [T. bình],

    table.cell(colspan: 5, align: left)[*Nhóm F — Hỗ trợ, kiểm duyệt và quản trị*],
    [UC-23], [Gửi phiếu hỗ trợ], [Người dùng], [Gửi mọi loại yêu cầu lên sàn — tố cáo, khiếu nại hoàn tiền, sự cố đơn, vướng mắc thanh toán, đề xuất tính năng.], [Cao],
    [UC-24], [Tiếp nhận và trả lời phiếu hỗ trợ], [Điều phối viên], [Trả lời trong hội thoại của phiếu với tư cách bàn hỗ trợ và ghi kết luận xử lý.], [Cao],
    [UC-25], [Kiểm duyệt tin đăng và bản sửa], [Điều phối viên], [Duyệt hoặc từ chối tin đăng mới và bản sửa; gỡ một tin đang hiển thị khi có vi phạm.], [Cao],
    [UC-26], [Phân xử yêu cầu hoàn tiền], [Điều phối viên], [Ra phán quyết cho hồ sơ đã chuyển lên sàn; phán quyết đóng luôn mọi phiếu liên quan.], [Cao],
    [UC-27], [Duyệt hồ sơ xác minh danh tính], [Điều phối viên], [Xem lại phán quyết của nhà cung cấp, chấp nhận hoặc từ chối kèm lý do.], [T. bình],
    [UC-28], [Quản lý cây danh mục và sổ tuỳ chọn nhà cung cấp], [Quản trị viên], [Tạo, đổi tên và sắp lại cây danh mục sản phẩm; bật, tắt, đổi tên hiển thị và chuyển nhà cung cấp phục vụ cho từng cổng thanh toán hoặc hãng vận chuyển.], [T. bình],
    [UC-29], [Đối soát ví và điều chỉnh số dư], [Quản trị viên], [Xem ví của một tài khoản, ghi một bút toán điều chỉnh kèm lý do, duyệt hoặc từ chối yêu cầu rút tiền.], [Cao],
    [UC-30], [Giám sát vận hành qua dữ liệu quan trắc], [Quản trị viên], [Theo dõi lưu lượng, độ trễ, tỉ lệ lỗi, các lời gọi ra ngoài và các sự kiện nghiệp vụ.], [T. bình],

    table.cell(colspan: 5, align: left)[*Nhóm G — Ca sử dụng con dùng chung (quan hệ «include»)*],
    [UC-S1], [Tải lên và xác nhận tệp đính kèm], [Người dùng], [Xin một đường tải lên có chữ ký, đẩy tệp lên kho lưu trữ và xác nhận để tệp gắn được vào nghiệp vụ gọi tới.], [Cao],
    [UC-S2], [Ghi nhật ký kiểm toán], [(Hệ thống)], [Ghi một bản ghi chỉ-thêm-mới cho mọi quyết định nghiệp vụ, trong cùng giao dịch với chính thay đổi đó.], [Cao],
  )
)

=== Sơ đồ ca sử dụng theo phân hệ

Vì số lượng ca sử dụng vượt ngưỡng đọc hiểu của một sơ đồ đơn, danh mục được tách thành ba sơ đồ theo phân hệ. Ký hiệu dùng chung cho cả ba: hình tròn là tác nhân, hình viên thuốc là ca sử dụng, khung nét đứt là ranh giới hệ thống; nét liền là quan hệ liên kết giữa tác nhân và ca sử dụng, nét đứt kèm nhãn là quan hệ bao hàm, mở rộng hoặc kích hoạt.

#fig(
  [Sơ đồ ca sử dụng phân hệ Định danh, đăng bán và khám phá],
  spacing: (34mm, 11mm),
  node(enclose: (<a1>, <a2>, <a3>, <a4>, <a5>, <a6>, <a7>, <a8>, <a9>, <a10>, <as1>),
    inset: 15pt, stroke: (paint: ink, dash: "dashed", thickness: 0.9pt),
    fill: none, corner-radius: 8pt),
  node((2, -1.15), text(size: 9pt, weight: 700)[Ranh giới hệ thống — Phân hệ Định danh và Đăng bán],
    fill: white, stroke: none),

  nt((2, -0.4), [UC-01 · Đăng ký tài khoản], name: <a1>),
  nt((2, 0.4), [UC-02 · Đăng nhập và quản lý phiên], name: <a2>),
  nt((2, 1.2), [UC-03 · Xác minh danh tính điện tử], name: <a3>),
  nt((2, 2.0), [UC-04 · Quản lý hồ sơ và sổ địa chỉ], name: <a4>),
  nt((2, 2.8), [UC-07 · Gợi ý điền tin đăng], name: <a5>),
  nt((2, 3.6), [UC-06 · Đăng bán sản phẩm], name: <a6>),
  nt((2, 4.4), [UC-08 · Chỉnh sửa tin đăng đang hiển thị], name: <a7>),
  nt((2, 5.2), [UC-09 · Tìm kiếm và duyệt sản phẩm], name: <a8>),
  nt((2, 6.0), [UC-10 · Theo dõi và lưu quan tâm], name: <a9>),
  nt((2, 6.8), [UC-05 · Cấp phát tài khoản điều phối viên], name: <a10>),
  nt((3.25, 1.9), text(size: 8pt)[UC-S1 · Tải lên\ tệp đính kèm], name: <as1>),

  nact((0, 3.0), [Người dùng]),
  nact((0, 6.8), [Quản trị viên]),
  nact((4.4, 0.9), text(size: 7pt)[Định danh\ liên kết]),
  nact((4.4, 2.9), text(size: 7pt)[Dịch vụ xác minh\ danh tính]),
  nact((4.4, 4.6), text(size: 7pt)[Mô hình\ ngôn ngữ]),

  edge((0, 3.0), <a1>, stroke: 0.7pt + blue-s),
  edge((0, 3.0), <a2>, stroke: 0.7pt + blue-s),
  edge((0, 3.0), <a3>, stroke: 0.7pt + blue-s),
  edge((0, 3.0), <a4>, stroke: 0.7pt + blue-s),
  edge((0, 3.0), <a5>, stroke: 0.7pt + blue-s),
  edge((0, 3.0), <a6>, stroke: 0.7pt + blue-s),
  edge((0, 3.0), <a7>, stroke: 0.7pt + blue-s),
  edge((0, 3.0), <a8>, stroke: 0.7pt + blue-s),
  edge((0, 3.0), <a9>, stroke: 0.7pt + blue-s),
  edge((0, 6.8), <a10>, stroke: 0.7pt + red),

  edge((4.4, 0.9), <a1>, stroke: 0.7pt + teal),
  edge((4.4, 2.9), <a3>, stroke: 0.7pt + teal),
  edge((4.4, 4.6), <a5>, stroke: 0.7pt + teal),

  edge(<a3>, <as1>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«include»]),
  edge(<a6>, <as1>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«include»]),
  edge(<a5>, <a6>, "-|>", stroke: (dash: "dashed"), label-side: right,
    text(size: 7pt)[«extend» điền sẵn biểu mẫu]),
  edge(<a3>, <a6>, "-|>", stroke: (dash: "dashed"), bend: -42deg, label-side: right,
    text(size: 7pt)[điều kiện trước]),
)

#fig(
  [Sơ đồ ca sử dụng phân hệ Giao dịch, ký quỹ và vận chuyển],
  spacing: (34mm, 12mm),
  node(enclose: (<b1>, <b2>, <b3>, <b4>, <b5>, <b6>, <b7>, <b8>, <bs1>),
    inset: 15pt, stroke: (paint: ink, dash: "dashed", thickness: 0.9pt),
    fill: none, corner-radius: 8pt),
  node((2, -1.0), text(size: 9pt, weight: 700)[Ranh giới hệ thống — Phân hệ Giao dịch],
    fill: white, stroke: none),

  nt((2, -0.25), [UC-11 · Nhắn tin thời gian thực], name: <b1>),
  nt((2, 0.65), [UC-12 · Thương lượng giá], name: <b2>),
  nt((2, 1.55), [UC-13 · Chuẩn bị đơn mua và báo giá], name: <b3>),
  nt((2, 2.45), [UC-14 · Thanh toán và ký quỹ], name: <b4>),
  nt((2, 3.35), [UC-15 · Xác nhận đơn đã thanh toán], name: <b5>),
  nt((2, 4.25), [UC-16 · Theo dõi hành trình kiện hàng], name: <b6>),
  nt((2, 5.15), [UC-17 · Xác nhận đã nhận hàng], name: <b7>),
  nt((2, 6.05), [UC-18 · Quản lý ví và rút tiền], name: <b8>),
  nt((3.3, 5.6), text(size: 8pt)[UC-S1 · Tải lên\ bằng chứng], name: <bs1>),

  nact((0, 1.6), [Người mua]),
  nact((0, 4.6), [Người bán]),
  nact((4.45, 2.6), text(size: 7pt)[Cổng\ thanh toán]),
  nact((4.45, 4.3), text(size: 7pt)[Đối tác\ vận chuyển]),

  edge((0, 1.6), <b1>, stroke: 0.7pt + blue-s),
  edge((0, 1.6), <b2>, stroke: 0.7pt + blue-s),
  edge((0, 1.6), <b3>, stroke: 0.7pt + blue-s),
  edge((0, 1.6), <b4>, stroke: 0.7pt + blue-s),
  edge((0, 1.6), <b6>, stroke: 0.7pt + blue-s),
  edge((0, 1.6), <b7>, stroke: 0.7pt + blue-s),
  edge((0, 1.6), <b8>, stroke: 0.7pt + blue-s),
  edge((0, 4.6), <b1>, stroke: 0.7pt + teal),
  edge((0, 4.6), <b2>, stroke: 0.7pt + teal),
  edge((0, 4.6), <b5>, stroke: 0.7pt + teal),
  edge((0, 4.6), <b8>, stroke: 0.7pt + teal),

  edge((4.45, 2.6), <b4>, stroke: 0.7pt + teal),
  edge((4.45, 2.6), <b8>, stroke: 0.7pt + teal, text(size: 7pt)[chi trả lệnh rút], label-side: right),
  edge((4.45, 4.3), <b3>, stroke: 0.7pt + teal),
  edge((4.45, 4.3), <b6>, stroke: 0.7pt + teal),

  edge(<b7>, <bs1>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«include»]),
  edge(<b2>, <b4>, "-|>", stroke: (dash: "dashed"), bend: -42deg, label-side: right,
    label-pos: 0.82, text(size: 7pt)[«extend» giá đã đồng thuận]),
  edge(<b4>, <b5>, "-|>", stroke: (dash: "dashed"), label-side: right,
    text(size: 7pt)[«trigger» đơn hàng ra đời]),
)

#fig(
  [Sơ đồ ca sử dụng phân hệ Hậu giao dịch, hỗ trợ và quản trị],
  spacing: (35mm, 12mm),
  node(enclose: (<c1>, <c2>, <c3>, <c4>, <c5>, <c6>, <c7>, <c8>, <c9>, <c10>, <c11>, <c12>, <cs2>),
    inset: 15pt, stroke: (paint: ink, dash: "dashed", thickness: 0.9pt),
    fill: none, corner-radius: 8pt),
  node((2, -1.0), text(size: 9pt, weight: 700)[Ranh giới hệ thống — Phân hệ Hậu giao dịch và Quản trị],
    fill: white, stroke: none),

  nt((2, -0.25), [UC-19 · Yêu cầu trả hàng và hoàn tiền], name: <c1>),
  nt((2, 0.6), [UC-20 · Xử lý yêu cầu hoàn tiền], name: <c2>),
  nt((2, 1.45), [UC-21 · Đánh giá hai chiều theo cơ chế ẩn], name: <c3>),
  nt((2, 2.3), [UC-22 · Đánh giá sản phẩm], name: <c4>),
  nt((2, 3.15), [UC-23 · Gửi phiếu hỗ trợ], name: <c5>),
  nt((2, 4.0), [UC-24 · Tiếp nhận và trả lời phiếu], name: <c6>),
  nt((2, 4.85), [UC-25 · Kiểm duyệt tin đăng và bản sửa], name: <c7>),
  nt((2, 5.7), [UC-26 · Phân xử yêu cầu hoàn tiền], name: <c8>),
  nt((2, 6.55), [UC-27 · Duyệt hồ sơ xác minh danh tính], name: <c9>),
  nt((2, 7.4), [UC-28 · Quản lý danh mục và sổ tuỳ chọn], name: <c10>),
  nt((2, 8.25), [UC-29 · Đối soát ví và điều chỉnh số dư], name: <c11>),
  nt((2, 9.1), [UC-30 · Giám sát vận hành], name: <c12>),
  nt((3.35, 6.1), text(size: 8pt)[UC-S2 · Ghi nhật ký\ kiểm toán], name: <cs2>),

  nact((0, 1.6), [Người mua]),
  nact((0, 4.4), [Người bán]),
  nact((4.5, 4.4), [Điều phối viên]),
  nact((4.5, 8.3), [Quản trị viên]),

  edge((0, 1.6), <c1>, stroke: 0.7pt + blue-s),
  edge((0, 1.6), <c3>, stroke: 0.7pt + blue-s),
  edge((0, 1.6), <c4>, stroke: 0.7pt + blue-s),
  edge((0, 1.6), <c5>, stroke: 0.7pt + blue-s),
  edge((0, 4.4), <c2>, stroke: 0.7pt + teal),
  edge((0, 4.4), <c3>, stroke: 0.7pt + teal),
  edge((0, 4.4), <c5>, stroke: 0.7pt + teal),

  edge((4.5, 4.4), <c6>, stroke: 0.7pt + teal),
  edge((4.5, 4.4), <c7>, stroke: 0.7pt + teal),
  edge((4.5, 4.4), <c8>, stroke: 0.7pt + teal),
  edge((4.5, 4.4), <c9>, stroke: 0.7pt + teal),
  edge((4.5, 8.3), <c10>, stroke: 0.7pt + red),
  edge((4.5, 8.3), <c11>, stroke: 0.7pt + red),
  edge((4.5, 8.3), <c12>, stroke: 0.7pt + red),

  edge(<c2>, <c5>, "-|>", stroke: (dash: "dashed"), bend: -48deg, label-side: right,
    text(size: 7pt)[«trigger» người bán chuyển hồ sơ lên sàn]),
  edge(<c5>, <c6>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«trigger»]),
  edge(<c8>, <cs2>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«include»]),
  edge(<c7>, <cs2>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«include»]),
  edge(<c11>, <cs2>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«include»]),
  edge(<c8>, <c5>, "-|>", stroke: (dash: "dashed"), bend: 48deg, label-side: left,
    text(size: 7pt)[«extend» phán quyết đóng phiếu]),
)

== Đặc tả chi tiết các ca sử dụng trọng yếu

Mười ca sử dụng có độ phức tạp hoặc mức rủi ro nghiệp vụ cao nhất được đặc tả đầy đủ theo mẫu chi tiết của UML: tác nhân, mô tả, điều kiện trước, luồng chính, luồng thay thế, luồng ngoại lệ, điều kiện sau, quy tắc nghiệp vụ tham chiếu, yêu cầu đặc biệt, giả định cùng các vấn đề còn để mở, và tần suất sử dụng. Mục giả định và vấn đề còn để mở được giữ lại đúng như nó vốn có: nó ghi những chỗ đặc tả đang dựa vào một điều chưa được chứng minh, hoặc những chỗ hệ thống chưa có câu trả lời — vì một đặc tả không có mục này thường không phải là một đặc tả không còn câu hỏi nào, mà là một đặc tả đã giấu chúng đi. Việc chọn mười ca này theo hai tiêu chí: ca có chạm vào dòng tiền, và ca có nhiều hơn một nhánh kết thúc. Những ca còn lại có luồng tuyến tính nên chỉ giữ ở mức mô tả trong danh mục.

#ucspec("UC-03", "Xác minh danh tính điện tử",
  [Tác nhân chính], [Người dùng],
  [Tác nhân phụ], [Dịch vụ xác minh danh tính điện tử; điều phối viên (khi cần phúc tra)],
  [Mô tả], [Người dùng gửi ảnh giấy tờ tuỳ thân và ảnh chân dung để được cấp hai quyền mà tài khoản chưa xác minh không có: quyền đăng bán và quyền rút tiền. Đây là cửa vào của toàn bộ vai người bán trên sàn.],
  [Điều kiện trước], [Người dùng đã đăng nhập và chưa có hồ sơ xác minh nào ở trạng thái đang chờ.],
  [Luồng chính], [
    1. Người dùng mở mục xác minh danh tính và chọn loại giấy tờ: căn cước công dân, hộ chiếu hoặc giấy phép lái xe.
    2. Hệ thống yêu cầu tải lên ảnh mặt trước, ảnh mặt sau khi loại giấy tờ có hai mặt, và một ảnh chân dung (bao hàm UC-S1).
    3. Người dùng tải các ảnh lên và gửi hồ sơ.
    4. Hệ thống chuyển ảnh cho nhà cung cấp xác minh và ghi lại mã hồ sơ mà nhà cung cấp trả về.
    5. Nhà cung cấp trả về một phán quyết chấp nhận kèm ngày hết hạn của giấy tờ.
    6. Hệ thống chuyển hồ sơ sang trạng thái đã xác minh, mở quyền đăng bán và quyền rút tiền cho tài khoản, và ghi nhật ký kiểm toán (bao hàm UC-S2).
  ],
  [Luồng thay thế], [
    *[5a] Nhà cung cấp vận hành theo mô hình luồng riêng:* thay vì một phán quyết, nhà cung cấp trả về trạng thái đang chờ kèm một đường dẫn phiên xác minh; hệ thống lưu hồ sơ ở trạng thái đang chờ và hiển thị đường dẫn đó cho người dùng, kết quả sẽ về sau.

    *[5b] Nhà cung cấp trả về phán quyết từ chối:* hồ sơ chuyển sang trạng thái bị từ chối kèm lý do; người dùng được phép gửi lại một hồ sơ mới.

    *[6a] Điều phối viên phúc tra:* một hồ sơ đang chờ có thể được điều phối viên chấp nhận hoặc từ chối bằng tay (UC-27); phán quyết bằng tay đi qua đúng các bước chuyển trạng thái như phán quyết của nhà cung cấp, nên một hồ sơ bị từ chối vẫn bắt buộc phải có lý do.
  ],
  [Luồng ngoại lệ], [
    *[4a] Không liên lạc được với nhà cung cấp:* hệ thống không tạo hồ sơ nào và báo lỗi để người dùng thử lại; một hồ sơ đang chờ vĩnh viễn vì nhà cung cấp không trả lời là thứ không có ai đóng được.

    *[3a] Thiếu ảnh bắt buộc hoặc tệp chưa được xác nhận tải lên xong:* hệ thống từ chối tiếp nhận hồ sơ.
  ],
  [Điều kiện sau], [Tài khoản ở một trong ba trạng thái xác minh rõ ràng; nếu đã xác minh thì quyền đăng bán và quyền rút tiền được mở, và ngày hết hạn của giấy tờ được lưu để các cổng kiểm tra sau này đọc lại.],
  [Quy tắc nghiệp vụ], [BR-07, BR-08],
  [Yêu cầu đặc biệt], [Hệ thống không lưu số giấy tờ; chỉ lưu loại giấy tờ, tên nhà cung cấp, mã hồ sơ bên nhà cung cấp, các ảnh đã gửi và phán quyết — đủ để điều phối viên phúc tra mà không tích trữ dữ liệu định danh quá mức cần thiết.],
  [Giả định và vấn đề còn để mở], [Giả định: ngày hết hạn do nhà cung cấp đọc ra là đáng tin và không cần đối chiếu lại bằng tay. Còn để mở: hệ thống chưa nhắc người dùng nộp lại khi giấy tờ sắp hết hạn, nên quyền đăng bán và quyền rút tiền tắt đi một cách lặng lẽ vào đúng ngày đó.],
  [Tần suất sử dụng], [Thấp — mỗi tài khoản thường chỉ một lần, lặp lại khi giấy tờ hết hạn.],
)

#ucspec("UC-06", "Đăng bán sản phẩm",
  [Tác nhân chính], [Người dùng ở vai người bán],
  [Tác nhân phụ], [Điều phối viên (bên duyệt tin); tiến trình sinh vector nhúng],
  [Mô tả], [Người bán soạn một tin đăng cho món hàng của mình, khai báo các phiên bản cùng số lượng tồn, chọn chế độ giá, rồi gửi tin vào hàng đợi kiểm duyệt. Tin chỉ hiển thị công khai sau khi một điều phối viên duyệt.],
  [Điều kiện trước], [Người bán đã đăng nhập, đã xác minh danh tính (UC-03) và đã khai báo ít nhất một địa chỉ lấy hàng trong sổ địa chỉ.],
  [Luồng chính], [
    1. Người bán chọn chức năng đăng bán.
    2. Hệ thống hiển thị biểu mẫu gồm ảnh, tên, mô tả, danh mục, nhãn, tình trạng hàng và danh sách phiên bản.
    3. Người bán tải lên ít nhất một ảnh (bao hàm UC-S1) và điền các trường bắt buộc.
    4. Người bán khai báo từng phiên bản kèm giá và số lượng tồn.
    5. Người bán chọn chế độ giá: giá cố định, hoặc giá cho phép thương lượng.
    6. Người bán lưu tin ở dạng nháp, xem lại, rồi bấm công bố.
    7. Hệ thống gắn ảnh chụp địa chỉ lấy hàng vào tin đăng, chuyển tin sang trạng thái chờ duyệt và xếp vào cuối hàng đợi kiểm duyệt theo thứ tự thời gian gửi.
    8. Một điều phối viên duyệt tin (UC-25); tin chuyển sang trạng thái đang hiển thị, được đánh dấu cần sinh lại vector nhúng và bắt đầu xuất hiện trong kết quả tìm kiếm.
  ],
  [Luồng thay thế], [
    *[2a] Người bán dùng gợi ý của trí tuệ nhân tạo:* biểu mẫu được điền sẵn từ ảnh và ghi chú (UC-07); người bán vẫn phải xem lại và bấm công bố, vì hệ thống không tự đăng thay người bán.

    *[5a] Chế độ giá cho phép thương lượng:* tin đăng vẫn mua thẳng được theo giá niêm yết; chế độ giá chỉ quyết định tin đó có nhận trả giá hay không (BR-14).

    *[8a] Điều phối viên từ chối tin:* tin quay lại trạng thái nháp kèm lý do; người bán sửa và gửi lại.
  ],
  [Luồng ngoại lệ], [
    *[6a] Người bán chưa xác minh danh tính:* hệ thống từ chối ngay ở bước lưu tin và hướng người bán sang UC-03. Cổng kiểm tra đặt ở bước tạo tin chứ không ở bước công bố, nên một tin đã được lưu từ trước vẫn công bố được kể cả khi hồ sơ xác minh đã hết hạn trong thời gian chờ; đây là một khoảng trống đã biết, được ghi lại ở đây thay vì được phát biểu như một bảo đảm (BR-07).

    *[7a] Người bán không có địa chỉ lấy hàng:* hệ thống từ chối công bố, vì một tin đăng không có điểm lấy hàng sẽ hỏng ở đúng bước tính phí vận chuyển, tức là sau khi người mua đã bỏ công chọn hàng.

    *[4a] Thiếu trường bắt buộc, giá không dương hoặc tồn kho âm:* hệ thống từ chối lưu và chỉ rõ trường sai.
  ],
  [Điều kiện sau], [Tin đăng tồn tại ở một trong các trạng thái nháp, chờ duyệt hoặc đang hiển thị; địa chỉ lấy hàng tại thời điểm công bố đã được chụp lại vào tin và không đổi theo sổ địa chỉ về sau.],
  [Quy tắc nghiệp vụ], [BR-07, BR-10, BR-11, BR-14, BR-15],
  [Yêu cầu đặc biệt], [Không có bộ lọc nội dung tự động nào ở bước này. Toàn bộ tin công bố đều đi vào hàng đợi của người thật; đây là lựa chọn có chủ ý để không có tin nào lọt qua vì một bộ lọc đoán sai.],
  [Giả định và vấn đề còn để mở], [Giả định: năng lực kiểm duyệt tăng kịp theo lượng tin, vì không có bộ lọc tự động nào chia tải. Còn để mở: cổng xác minh danh tính chỉ chặn ở bước tạo tin, nên một tin soạn từ trước vẫn công bố được sau khi hồ sơ xác minh hết hạn.],
  [Tần suất sử dụng], [Cao — là nguồn cung của toàn sàn.],
)

#ucspec("UC-12", "Thương lượng giá",
  [Tác nhân chính], [Người dùng ở vai người mua (bên mở thương lượng)],
  [Tác nhân phụ], [Người dùng ở vai người bán; hạ tầng đẩy tin thời gian thực],
  [Mô tả], [Hai bên thoả thuận một mức giá khác giá niêm yết cho một phiên bản sản phẩm. Thương lượng là một bản ghi có trạng thái và có hạn hiệu lực, còn hội thoại chỉ mang một tin nhắn hệ thống trỏ tới bản ghi đó.],
  [Điều kiện trước], [Cả hai bên đã đăng nhập; tin đăng đang hiển thị và ở chế độ giá cho phép thương lượng; giữa người mua này và phiên bản sản phẩm này chưa có thương lượng nào đang sống.],
  [Luồng chính], [
    1. Người mua mở trang chi tiết sản phẩm và chọn thương lượng giá.
    2. Người mua nhập mức giá và số lượng đề xuất.
    3. Hệ thống tạo bản ghi thương lượng ở trạng thái đang hoạt động với hạn hiệu lực mười hai giờ, và đăng một tin nhắn hệ thống trỏ tới bản ghi đó vào hội thoại sẵn có giữa hai người.
    4. Người bán mở thương lượng và đưa ra một đề xuất ngược lại; hạn hiệu lực mười hai giờ được đặt lại cho lượt mới.
    5. Hai bên luân phiên đề xuất cho tới khi một bên hài lòng. Bên được quyền chấp thuận luôn là bên không đang giữ đề xuất hiện hành.
    6. Bên đó bấm chấp thuận. Hệ thống đóng băng mức giá đã thoả thuận trong ba mươi phút và thông báo cho người mua.
    7. Người mua bấm tạo đơn trong ba mươi phút đó, và luồng chuyển sang UC-14.
  ],
  [Luồng thay thế], [
    *[6a] Người bán là bên chấp thuận:* kết quả giống hệt — chấp thuận không tạo đơn hàng và không thu bất kỳ khoản nào, nên việc người bán đồng ý giá vẫn để người mua toàn quyền quyết định có mua hay không.

    *[5a] Một bên rút lại thương lượng:* bản ghi chuyển sang trạng thái đã rút; hai bên có thể mở một thương lượng mới.

    *[5b] Hết mười hai giờ mà bên đang phải trả lời không trả lời:* bản ghi hết hiệu lực; muốn tiếp tục thì phải mở thương lượng mới.

    *[7a] Hết ba mươi phút mà người mua không tạo đơn:* mức giá đóng băng hết hạn; thương lượng lại là cách khắc phục duy nhất.
  ],
  [Luồng ngoại lệ], [
    *[2a] Tin đăng ở chế độ giá cố định:* hệ thống từ chối mở thương lượng.

    *[7b] Người mua bấm tạo đơn hai lần:* quyền mua được giành trước khi phiên trả tiền được mở, nên chỉ một phiên được tạo và lần bấm sau bị từ chối (BR-24).

    *[3a] Mất kết nối thời gian thực:* hội thoại chuyển sang chế độ tải lại theo chu kỳ; các tin đã gửi không mất vì chúng được ghi bền trước khi phát tán.
  ],
  [Điều kiện sau], [Tồn tại đúng một bản ghi thương lượng phản ánh trạng thái hiện tại; nếu đã được chấp thuận và người mua đã tạo đơn, bản ghi chuyển sang trạng thái đã dùng để mua và không thể dùng lại.],
  [Quy tắc nghiệp vụ], [BR-14, BR-16, BR-17, BR-18, BR-19, BR-20, BR-24],
  [Yêu cầu đặc biệt], [Mức giá không bao giờ được sao chép vào nội dung tin nhắn. Nếu sao chép, một đề xuất ngược lại sẽ để lại trong hội thoại một mức giá không còn trên bàn, và người dùng đọc lại sẽ thấy hai con số mâu thuẫn.],
  [Giả định và vấn đề còn để mở], [Giả định: hai bên chấp nhận một cuộc mặc cả có nhịp luân phiên thay vì trao đổi tự do. Còn để mở: một mức giá đã chấp thuận nhưng hết ba mươi phút không có cách gia hạn, người mua phải mở lại thương lượng từ đầu; chưa rõ tần suất thực tế của tình huống này có đủ lớn để cần một nút gia hạn hay không.],
  [Tần suất sử dụng], [Cao — là hành vi tự nhiên nhất của thị trường hàng đã qua sử dụng.],
)

#ucspec("UC-14", "Thanh toán và ký quỹ",
  [Tác nhân chính], [Người dùng ở vai người mua],
  [Tác nhân phụ], [Cổng thanh toán; đối tác vận chuyển (báo giá đã chốt ở UC-13)],
  [Mô tả], [Người mua trả tiền hàng cộng phí giao hàng qua một cổng thanh toán. Tiền không đi tới người bán mà vào tài khoản giữ hộ của sàn, và đơn hàng ra đời ngay tại thời điểm cổng thanh toán báo về.],
  [Điều kiện trước], [Người mua đã đăng nhập; tồn tại một phiếu mua tạm còn hiệu lực (UC-13) hoặc một thương lượng đã được chấp thuận còn trong ba mươi phút (UC-12); phương án vận chuyển đã được chốt kèm mức phí.],
  [Luồng chính], [
    1. Người mua xem lại đơn: hàng, số lượng, địa chỉ nhận, hãng vận chuyển và tổng tiền phải trả.
    2. Người mua chọn một cổng thanh toán trong danh sách các tuỳ chọn đang bật.
    3. Hệ thống giành quyền mua trước: phiếu mua tạm được đánh dấu đã dùng, hoặc thương lượng được chuyển sang trạng thái đã dùng để mua.
    4. Hệ thống mở một phiên thanh toán có hạn mười lăm phút gồm hai khoản tách bạch là tiền hàng và phí giao hàng, rồi chuyển người mua sang trang trả tiền của cổng.
    5. Người mua hoàn tất thanh toán tại cổng.
    6. Cổng thanh toán gửi thông báo kết quả về hệ thống.
    7. Hệ thống ghi nhận phiên đã trả, giữ tiền hàng vào ký quỹ và tách phí giao hàng thành một khoản riêng không bao giờ vào ví người bán.
    8. Hệ thống tạo đơn hàng ở trạng thái chờ người bán xác nhận, tạo kiện hàng tương ứng, giảm tồn kho và thông báo cho người bán (chuyển sang UC-15).
  ],
  [Luồng thay thế], [
    *[2a] Người mua huỷ giữa chừng hoặc đóng trang trả tiền:* phiên bị huỷ, phần đã giành được trả lại để người mua có thể bắt đầu lại.

    *[5a] Người mua quay về trang kết quả của sàn trước khi thông báo tới:* hệ thống hiển thị trạng thái phiên đang chờ. Trang mà người trả tiền đáp xuống không được coi là bằng chứng đã trả tiền, vì đó là địa chỉ ai cũng mở được.
  ],
  [Luồng ngoại lệ], [
    *[4a] Hết mười lăm phút mà chưa trả tiền:* phiên không còn trả được, phần đã giành được trả lại và tồn kho không bị giữ thêm (BR-23).

    *[6a] Cổng thanh toán gửi lặp cùng một thông báo:* việc xử lý là bất biến với lặp lại, nên chỉ một đơn hàng được tạo.

    *[7a] Xử lý thông báo thất bại:* hệ thống trả về lỗi để cổng thanh toán gửi lại, vì đó là nguồn tin duy nhất sẽ nói lại với hệ thống về khoản tiền này.
  ],
  [Điều kiện sau], [Tiền hàng nằm trong ký quỹ, phí giao hàng nằm ở một khoản riêng, tồn tại đúng một đơn hàng ở trạng thái chờ người bán xác nhận, và đơn đó ghi rõ nó sinh ra từ một phiếu mua tạm hay từ một thương lượng.],
  [Quy tắc nghiệp vụ], [BR-21, BR-22, BR-23, BR-24, BR-25, BR-26, BR-56],
  [Yêu cầu đặc biệt], [Quyền mua phải được giành trước khi phiên thanh toán được mở. Nếu giành sau, hai lần bấm sẽ mở hai phiên, và một lần bán có thể thu được tiền hai lần — khoản thứ hai không có chỗ nào để giữ.],
  [Giả định và vấn đề còn để mở], [Giả định: cổng thanh toán gửi lại thông báo cho tới khi hệ thống nhận thành công. Còn để mở: một phiên quá hạn tuy không trả được nữa và đã trả lại mọi phần đã giành, nhưng vẫn nằm ở trạng thái chờ trong sổ sách thay vì được đóng lại; điều này không sai về tiền nhưng làm danh sách phiên của người dùng dài ra vô ích.],
  [Tần suất sử dụng], [Rất cao — là ca sử dụng trung tâm của toàn hệ thống.],
)

#ucspec("UC-15", "Xác nhận đơn hàng đã thanh toán",
  [Tác nhân chính], [Người dùng ở vai người bán],
  [Tác nhân phụ], [Đối tác vận chuyển; điều phối viên (khi quá hạn)],
  [Mô tả], [Người bán xác nhận rằng mình còn hàng và sẽ giao đơn hàng đã được thanh toán. Xác nhận không tạo ra đơn hàng — đơn đã tồn tại từ lúc tiền vào — mà chỉ mở đường cho việc đặt vận đơn.],
  [Điều kiện trước], [Tồn tại một đơn hàng ở trạng thái chờ người bán xác nhận; tiền hàng đang nằm trong ký quỹ.],
  [Luồng chính], [
    1. Người bán mở danh sách đơn chờ xác nhận.
    2. Hệ thống hiển thị từng đơn kèm hàng, số lượng, địa chỉ nhận, hãng vận chuyển và mức phí người mua đã trả.
    3. Người bán bấm xác nhận.
    4. Hệ thống chuyển đơn sang trạng thái đang mở và đặt vận đơn với hãng vận chuyển đã chọn, lưu lại mã vận đơn.
    5. Hệ thống thông báo mã vận đơn cho người mua; luồng theo dõi hành trình bắt đầu (UC-16).
  ],
  [Luồng thay thế], [
    *[3a] Người bán từ chối đơn:* hệ thống bắt buộc nhập lý do, huỷ đơn, trả lại tồn kho và hoàn cho người mua toàn bộ tiền hàng cộng phí giao hàng, vì kiện hàng chưa hề rời kho (BR-27, BR-29).
  ],
  [Luồng ngoại lệ], [
    *[3b] Người bán để quá bốn mươi tám giờ:* hệ thống đánh dấu đơn là quá hạn xác nhận và mở một phiếu để bộ phận vận hành đi giục. Đơn vẫn ở nguyên trạng thái chờ xác nhận và tiền vẫn nằm trong ký quỹ: hệ thống không tự huỷ bán thay người bán và cũng không tự hoàn tiền, vì cả hai đều là quyết định thay mặt một trong hai bên (BR-28).

    *[4a] Đặt vận đơn với hãng vận chuyển thất bại:* đơn vẫn được xác nhận và tiền vẫn đúng chỗ; việc đặt vận đơn được xếp vào danh sách thử lại, vì tiền đã chuyển động nên một hãng vận chuyển không liên lạc được là việc phải làm lại chứ không phải lý do để từ chối một đơn hàng.
  ],
  [Điều kiện sau], [Đơn hàng ở trạng thái đang mở kèm một kiện hàng, hoặc đã bị huỷ và người mua đã được hoàn đủ, hoặc vẫn chờ xác nhận và đã có một phiếu nhắc bộ phận vận hành.],
  [Quy tắc nghiệp vụ], [BR-27, BR-28, BR-29, BR-30],
  [Yêu cầu đặc biệt], [Mã vận đơn trả về từ hãng vận chuyển đồng thời là dấu hiệu đã đặt: khi thử lại, hệ thống bỏ qua mọi kiện hàng đã có mã, nên một lần bán không bao giờ sinh ra hai kiện hàng.],
  [Giả định và vấn đề còn để mở], [Giả định: một người bán được nhắc thì sẽ trả lời. Còn để mở: không có giới hạn trên cho thời gian một đơn nằm chờ xác nhận, nên một người bán biến mất hẳn để lại một khoản tiền nằm trong ký quỹ mà chỉ một quyết định của người mới gỡ ra được; chưa xác định ngưỡng nào thì chuyển vụ việc thành một phiếu bắt buộc phải kết luận.],
  [Tần suất sử dụng], [Rất cao — mọi giao dịch đều đi qua ca sử dụng này.],
)

#ucspec("UC-17", "Xác nhận đã nhận hàng",
  [Tác nhân chính], [Người dùng ở vai người mua],
  [Tác nhân phụ], [Kho lưu trữ đối tượng (bằng chứng)],
  [Mô tả], [Sau khi nhận hàng, người mua chủ động xác nhận kèm bằng chứng. Đây là mốc duy nhất khởi động cửa sổ bảy mươi hai giờ, sau đó tiền hàng mới rời ký quỹ để về ví người bán.],
  [Điều kiện trước], [Đơn hàng đang mở và chưa kết thúc; tiền hàng vẫn nằm trong ký quỹ.],
  [Luồng chính], [
    1. Người mua mở chi tiết đơn hàng và chọn xác nhận đã nhận hàng.
    2. Hệ thống yêu cầu tải lên từ một tới mười tệp bằng chứng, có thể là ảnh hoặc video (bao hàm UC-S1).
    3. Người mua tải bằng chứng và xác nhận.
    4. Hệ thống ghi mốc nhận hàng, tính mốc giải ngân là bảy mươi hai giờ sau đó và thông báo cho người bán.
    5. Hết bảy mươi hai giờ mà không có yêu cầu hoàn tiền nào đang sống, hệ thống chuyển tiền hàng từ ký quỹ sang số dư khả dụng của người bán, không trừ bất kỳ khoản hoa hồng nào.
    6. Hệ thống đánh dấu đơn đã giải ngân và mở luồng đánh giá hai chiều (UC-21).
  ],
  [Luồng thay thế], [
    *[5a] Có yêu cầu hoàn tiền đang sống:* đơn bị loại khỏi danh sách chờ giải ngân cho tới khi hồ sơ hoàn tiền kết thúc (UC-19, UC-20, UC-26).

    *[1a] Người mua không xác nhận:* không có bộ đếm nào chạy và tiền tiếp tục nằm trong ký quỹ. Hệ thống không tự xác nhận thay người mua, vì làm vậy là tuyên bố thay họ rằng hàng đã về và đúng mô tả.
  ],
  [Luồng ngoại lệ], [
    *[2a] Không có tệp bằng chứng nào:* hệ thống từ chối bước xác nhận (BR-33).

    *[5b] Chuyển tiền thất bại:* mốc giải ngân chưa được đóng dấu nên đơn vẫn nằm trong danh sách chờ; một tác vụ quét định kỳ thử lại và ghi đúng một dòng tổng kết cho mỗi lượt quét thay vì một dòng cho mỗi đơn.
  ],
  [Điều kiện sau], [Bằng chứng nhận hàng được lưu bền và gắn với đơn; cửa sổ bảy mươi hai giờ đang chạy, hoặc tiền hàng đã về ví người bán và mốc giải ngân đã được đóng dấu.],
  [Quy tắc nghiệp vụ], [BR-32, BR-33, BR-34, BR-35],
  [Yêu cầu đặc biệt], [Việc đóng dấu mốc giải ngân là điều kiện để tác vụ quét biết đơn nào còn sót lại; nhờ vậy danh sách phải thử lại là tập đúng bằng số đơn thực sự bị kẹt, thay vì tỉ lệ thuận với toàn bộ lịch sử giao dịch.],
  [Giả định và vấn đề còn để mở], [Giả định: người mua nhận hàng thì sẽ chủ động xác nhận, vì đó cũng là lúc họ mở được luồng đánh giá. Còn để mở: một đơn không bao giờ được xác nhận thì tiền nằm trong ký quỹ vô thời hạn; hệ thống cố ý không tự xác nhận thay người mua, nhưng chưa có thủ tục nào cho nhóm đơn rơi vào tình trạng đó.],
  [Tần suất sử dụng], [Rất cao — mọi đơn hàng giao thành công đều đi qua ca sử dụng này.],
)

#ucspec("UC-19", "Yêu cầu trả hàng và hoàn tiền",
  [Tác nhân chính], [Người dùng ở vai người mua],
  [Tác nhân phụ], [Người dùng ở vai người bán (bên phải trả lời)],
  [Mô tả], [Người mua khiếu nại hàng lỗi hoặc không đúng mô tả. Yêu cầu luôn là toàn phần và khoá đơn hàng khỏi việc giải ngân cho tới khi có kết luận.],
  [Điều kiện trước], [Đơn hàng chưa kết thúc; người mua là chủ đơn; đơn chưa có yêu cầu hoàn tiền nào đang sống.],
  [Luồng chính], [
    1. Người mua mở đơn và chọn yêu cầu trả hàng.
    2. Hệ thống hiển thị biểu mẫu lý do và cho phép đính kèm bằng chứng (bao hàm UC-S1).
    3. Người mua gửi yêu cầu.
    4. Hệ thống tạo hồ sơ ở trạng thái chờ người bán trả lời, đặt hạn bốn mươi tám giờ, loại đơn khỏi danh sách chờ giải ngân và thông báo cho người bán.
    5. Người bán chấp nhận cho trả hàng (UC-20); hệ thống mở một chặng vận chuyển trả hàng với mức phí bằng không.
    6. Người bán nhận được hàng và xác nhận; hệ thống cho người bán bốn mươi tám giờ để kiểm hàng.
    7. Hết bốn mươi tám giờ kiểm hàng mà người bán không có ý kiến, hệ thống hoàn tiền hàng cho người mua và đóng hồ sơ.
  ],
  [Luồng thay thế], [
    *[3a] Người mua rút yêu cầu trước khi người bán trả lời:* hồ sơ chuyển sang trạng thái đã rút, khác hẳn với bị bác bỏ, và đơn quay lại danh sách chờ giải ngân.

    *[5a] Người bán chuyển hồ sơ cho sàn:* hồ sơ sang trạng thái chờ phân xử, và hệ thống tự mở một phiếu hỗ trợ loại khiếu nại hoàn tiền đứng tên người mua để vụ việc có một nơi trao đổi; luồng chuyển sang UC-26. Người mua không phải gửi phiếu lần nữa, nhưng vẫn gửi được một phiếu của riêng mình (UC-23) nếu muốn nói thêm.

    *[5b] Người bán để quá bốn mươi tám giờ không trả lời:* hồ sơ tự chuyển sang chờ phân xử và cũng tự mở phiếu, đúng như khi chính người bán chuyển nó lên. Im lặng của người bán không được coi là đồng ý, cũng không được coi là từ chối (BR-40).

    *[6a] Người mua tự khai đã gửi trả hàng:* đây là một tuyên bố về kho của người khác, nên hồ sơ đi thẳng lên sàn phân xử thay vì mở cửa sổ kiểm hàng của người bán.

    *[6b] Người bán kiểm hàng và thấy thứ nhận về không khớp:* người bán chuyển hồ sơ lên sàn trong cửa sổ bốn mươi tám giờ đó.
  ],
  [Luồng ngoại lệ], [
    *[3b] Đơn đã kết thúc:* hệ thống từ chối mở hồ sơ.

    *[1a] Đã có một hồ sơ đang sống trên cùng đơn:* hệ thống từ chối tạo hồ sơ thứ hai.
  ],
  [Điều kiện sau], [Hồ sơ ở một trạng thái xác định và luôn có một bên đang phải hành động, hoặc đã kết thúc bằng một trong bốn kết cục: hoàn tiền, bị bác bỏ, được rút, hoặc chờ phán quyết của sàn.],
  [Quy tắc nghiệp vụ], [BR-27, BR-37, BR-38, BR-39, BR-40, BR-41, BR-42],
  [Yêu cầu đặc biệt], [Chấp nhận không phải là trả tiền: hàng phải quay về trước. Ngược lại, người bán vừa mất hàng vừa mất tiền chỉ vì một yêu cầu và bốn mươi tám giờ không đọc thông báo.],
  [Giả định và vấn đề còn để mở], [Giả định: hoàn tiền luôn là toàn phần, vì hàng đã qua sử dụng thường không chia nhỏ được thành mức bồi thường một phần. Còn để mở: chặng trả hàng không được đặt với hãng vận chuyển nào, nên không có bên thứ ba xác nhận hàng đã lên đường; đây là lý do một lời khai đã trả hàng phải đi thẳng lên sàn phân xử, và cũng là điểm sẽ thay đổi nếu có hợp đồng vận chuyển thật.],
  [Tần suất sử dụng], [Trung bình thấp — kỳ vọng dưới năm phần trăm số đơn.],
)

#ucspec("UC-23", "Gửi phiếu hỗ trợ",
  [Tác nhân chính], [Người dùng],
  [Tác nhân phụ], [Bàn hỗ trợ (đối tác hội thoại); điều phối viên (bên trả lời)],
  [Mô tả], [Mọi thứ người dùng gửi lên bộ phận hỗ trợ đều là một phiếu: tố cáo một tin đăng, một tài khoản, một tin nhắn hay một nhận xét; khiếu nại một yêu cầu hoàn tiền; báo sự cố đơn hàng hoặc vướng mắc thanh toán; hỏi về tài khoản; hoặc đề xuất một tính năng. Loại phiếu là thứ duy nhất phân biệt chúng.],
  [Điều kiện trước], [Người dùng đã đăng nhập; nếu phiếu nhắm vào một đối tượng thì đối tượng đó tồn tại và người gửi có quyền nhìn thấy nó.],
  [Luồng chính], [
    1. Người dùng chọn gửi phiếu và chọn loại phiếu.
    2. Hệ thống suy ra loại đối tượng từ loại phiếu, nên người dùng không phải khai nó; với các loại phiếu tố cáo, hệ thống yêu cầu chọn thêm một lý do trong danh sách.
    3. Người dùng nhập tiêu đề, nội dung và đính kèm tệp nếu cần (bao hàm UC-S1).
    4. Hệ thống tạo phiếu ở trạng thái mở.
    5. Hệ thống mở một cuộc hội thoại giữa người gửi và bàn hỗ trợ, đưa nội dung cùng tệp đính kèm của phiếu vào làm tin nhắn đầu tiên.
    6. Từ đó về sau, phía người gửi nhìn thấy một cuộc trò chuyện bình thường: gửi thêm ảnh, nhận thông báo, thấy dấu đã đọc.
  ],
  [Luồng thay thế], [
    *[1a] Phiếu khiếu nại một yêu cầu hoàn tiền:* trước khi ghi phiếu, hệ thống chuyển hồ sơ hoàn tiền sang trạng thái chờ phân xử. Nếu bước này bị từ chối — chẳng hạn vì người gửi không phải bên được quyền chuyển hồ sơ lên — thì phiếu không được tạo, vì một phiếu về hồ sơ mà sàn không có quyền quyết là một phiếu không ai trả lời được.

    *[5a] Không mở được hội thoại:* phiếu vẫn tồn tại, và lần đọc phiếu kế tiếp sẽ mở hội thoại bù. Mất cuộc trò chuyện không được phép làm mất khiếu nại.
  ],
  [Luồng ngoại lệ], [
    *[4a] Người gửi đã có một phiếu đang mở về đúng đối tượng đó:* hệ thống từ chối và trỏ về phiếu cũ.

    *[1b] Người dùng nhắn tin trực tiếp cho bàn hỗ trợ:* hệ thống từ chối mở hội thoại trực tiếp, vì đó là cuộc trò chuyện không điều phối viên nào đọc được; muốn liên hệ thì mở phiếu.
  ],
  [Điều kiện sau], [Tồn tại một phiếu ở trạng thái mở nằm trong hàng đợi duy nhất của bộ phận hỗ trợ, gắn với một cuộc hội thoại chứa nguyên văn nội dung người gửi viết.],
  [Quy tắc nghiệp vụ], [BR-44, BR-45, BR-46, BR-47, BR-48],
  [Yêu cầu đặc biệt], [Phiếu không lưu nội dung và không nhận tệp của riêng nó; toàn bộ nội dung nằm trong hội thoại. Nhờ vậy đường tải tệp, đẩy thông báo và đếm tin chưa đọc không phải viết lại lần thứ hai.],
  [Giả định và vấn đề còn để mở], [Giả định: một hàng đợi duy nhất cho mọi loại phiếu vẫn xử lý xuể khi số phiếu tăng, vì loại phiếu đủ để lọc. Còn để mở: nhiều phiếu của nhiều người khác nhau về cùng một đối tượng chưa được gộp thành một hồ sơ chung; điều phối viên chỉ thấy số lượng chứ chưa đọc được chúng cạnh nhau trong một màn hình.],
  [Tần suất sử dụng], [Trung bình — là kênh duy nhất người dùng liên hệ với sàn.],
)

#ucspec("UC-25", "Kiểm duyệt tin đăng và bản sửa",
  [Tác nhân chính], [Điều phối viên],
  [Tác nhân phụ], [Người bán (chủ tin đăng)],
  [Mô tả], [Điều phối viên duyệt các tin đăng mới và các bản sửa đang chờ, đồng thời xử lý các tin bị tố cáo. Đây là cửa duy nhất đưa một tin đăng ra công khai.],
  [Điều kiện trước], [Điều phối viên đã đăng nhập; tồn tại ít nhất một tin ở trạng thái chờ duyệt hoặc một bản sửa đang chờ.],
  [Luồng chính], [
    1. Điều phối viên mở hàng đợi kiểm duyệt, được xếp theo thứ tự thời gian gửi.
    2. Hệ thống hiển thị nội dung tin, ảnh, thông tin người bán và số phiếu đang mở nhắm vào chính tin đó.
    3. Điều phối viên đối chiếu với danh mục hàng hoá bị cấm của nền tảng.
    4. Điều phối viên duyệt; tin chuyển sang trạng thái đang hiển thị và được đánh dấu cần sinh lại vector nhúng.
    5. Hệ thống ghi nhật ký kiểm toán kèm danh tính người duyệt (bao hàm UC-S2).
  ],
  [Luồng thay thế], [
    *[4a] Từ chối tin:* tin quay lại trạng thái nháp kèm lý do; người bán sửa và gửi lại.

    *[1a] Bản sửa của một tin đang hiển thị:* điều phối viên so bản sửa với bản đang hiển thị; duyệt thì bản sửa thay thế bản cũ, từ chối thì bản sửa bị bỏ và bản đang hiển thị giữ nguyên. Trong suốt thời gian chờ, người mua vẫn nhìn thấy bản đã được duyệt trước đó (BR-12).

    *[3a] Tin đang hiển thị bị tố cáo:* điều phối viên gỡ tin, và tuỳ mức độ có thể khoá tài khoản người bán. Tin bị gỡ được phân biệt với tin do chính người bán ẩn đi: người bán gửi lại được, nhưng tin quay về hàng đợi duyệt chứ không trở lại hiển thị, nên chỉ một điều phối viên mới đưa nó ra công khai lần nữa (BR-13).
  ],
  [Luồng ngoại lệ], [
    *[2a] Tin đã bị chính người bán xoá trước khi tới lượt duyệt:* hệ thống đóng mục trong hàng đợi nhưng vẫn giữ nhật ký, phục vụ việc theo dõi hành vi tái phạm.
  ],
  [Điều kiện sau], [Tin đăng ở đúng một trạng thái xác định và mọi quyết định đều có bản ghi kiểm toán ghi rõ ai quyết và vì sao.],
  [Quy tắc nghiệp vụ], [BR-10, BR-12, BR-13, BR-49],
  [Yêu cầu đặc biệt], [Số phiếu đang mở nhắm vào cùng một tin chỉ là thông tin tham khảo cho điều phối viên. Không tồn tại ngưỡng số lượt tố cáo nào tự động ẩn tin, vì một ngưỡng như vậy biến việc gỡ tin của đối thủ thành một trò chơi số đông.],
  [Giả định và vấn đề còn để mở], [Giả định: điều phối viên đủ hiểu danh mục hàng cấm để phán quyết mà không cần một cây quyết định hình thức hoá. Còn để mở: hàng đợi xếp thuần theo thứ tự gửi, nên một tin có nhiều phiếu tố cáo vẫn chờ đúng lượt của nó; việc cho phép ưu tiên sẽ mở lại đúng nguy cơ mà BR-49 đang chặn, và cách dung hoà chưa được quyết.],
  [Tần suất sử dụng], [Cao — mọi tin đăng công bố đều đi qua ca sử dụng này.],
)

#ucspec("UC-26", "Phân xử yêu cầu hoàn tiền",
  [Tác nhân chính], [Điều phối viên],
  [Tác nhân phụ], [Người mua và người bán; khối tài chính giữ ký quỹ],
  [Mô tả], [Điều phối viên ra phán quyết cho một hồ sơ hoàn tiền đã được chuyển lên sàn. Phán quyết được ra ở đúng nơi giữ tiền, và chính nó đóng mọi phiếu đang mở về hồ sơ đó.],
  [Điều kiện trước], [Tồn tại một hồ sơ hoàn tiền ở trạng thái chờ phân xử; điều phối viên đã đăng nhập.],
  [Luồng chính], [
    1. Điều phối viên mở hàng đợi hồ sơ chờ phân xử.
    2. Hệ thống hiển thị toàn bộ ngữ cảnh: đơn hàng, lý do khiếu nại, bằng chứng người mua đính kèm, hội thoại của phiếu, và mốc hàng đã quay về hay chưa.
    3. Điều phối viên nhập lập luận và chọn một trong hai kết cục: người mua thắng, hoặc người bán thắng.
    4. Nếu người mua thắng và hàng chưa quay về, hệ thống mở chặng trả hàng và hồ sơ tiếp tục theo luồng trả hàng.
    5. Nếu người mua thắng và hàng đã quay về, hệ thống hoàn tiền hàng cho người mua ngay.
    6. Nếu người bán thắng, hồ sơ bị bác bỏ và đơn quay lại danh sách chờ giải ngân.
    7. Hệ thống ghi nhật ký kiểm toán (bao hàm UC-S2), phát một sự kiện phán quyết mang theo danh tính người quyết, và đóng mọi phiếu đang mở nhắm vào chính hồ sơ đó, đồng thời đăng kết luận vào hội thoại của các phiếu ấy.
  ],
  [Luồng thay thế], [
    *[7a] Không có phiếu nào đang mở:* hệ thống bỏ qua bước đóng phiếu một cách lặng lẽ. Thông thường mọi hồ sơ chuyển lên sàn đều đã có phiếu, kể cả hồ sơ chuyển lên do quá hạn trả lời; nhưng việc mở phiếu được thực hiện theo lối nỗ lực tối đa qua trục sự kiện, nên một lần gián đoạn để lại một hồ sơ đã chuyển lên mà chưa có phiếu — và phán quyết không được phép thất bại chỉ vì điều đó.

    *[3a] Cả hai bên đều đã mở phiếu về cùng hồ sơ:* phán quyết đóng cả hai. Nếu chỉ đóng một, phiếu còn lại sẽ nằm mở vĩnh viễn, vì phiếu loại này không kết luận bằng tay được.
  ],
  [Luồng ngoại lệ], [
    *[3b] Điều phối viên thử kết luận phiếu ngay ở màn hình phiếu:* hệ thống từ chối, vì đánh dấu vụ việc đã xong bằng tay sẽ để nguyên khoản tiền đang bị giữ ở chỗ cũ.

    *[5a] Chuyển tiền thất bại:* hồ sơ chưa được đóng cho tới khi bút toán hoàn tất; tác vụ quét thử lại.
  ],
  [Điều kiện sau], [Dòng tiền được giải quyết dứt điểm theo một trong hai chiều; mọi phiếu về hồ sơ đã đóng và mang kết luận; nhật ký kiểm toán ghi đủ ai quyết, quyết gì và khi nào.],
  [Quy tắc nghiệp vụ], [BR-38, BR-41, BR-42, BR-43, BR-50],
  [Yêu cầu đặc biệt], [Chỉ tài khoản mang vai điều phối viên hoặc quản trị viên gọi được chức năng này; phán quyết là quyết định cuối cùng và có hiệu lực ngay, bỏ qua mọi mốc chờ còn lại của hồ sơ.],
  [Giả định và vấn đề còn để mở], [Giả định: hai kết cục là đủ, vì hoàn tiền luôn toàn phần nên không có mức phân chia nào để quyết. Còn để mở: phán quyết là quyết định cuối cùng và chưa có đường khiếu nại lại; bên thua chỉ còn cách mở một phiếu mới, mà phiếu mới ấy lại không có hồ sơ nào để mở lại.],
  [Tần suất sử dụng], [Thấp — nhưng là ca sử dụng có rủi ro tài chính và uy tín cao nhất.],
)

== Bộ quy tắc nghiệp vụ

Bộ quy tắc nghiệp vụ là tập ràng buộc bất biến mà mọi ca sử dụng, mọi yêu cầu chức năng và mọi lựa chọn thiết kế phải tuân thủ. Năm mươi tám quy tắc dưới đây được sắp theo bảy nhóm chủ đề để các mục sau tham chiếu tới. Mã được cấp theo thứ tự bổ sung và không bao giờ được đánh số lại, vì các chương thiết kế và kiểm thử đã dẫn chiếu tới chúng; vì vậy ba quy tắc phát hiện thêm ở lượt rà soát chéo với mô hình dữ liệu nằm trong nhóm chủ đề của mình nhưng mang mã cao hơn các quy tắc bên cạnh. Ngoài nhóm chủ đề, mỗi quy tắc còn được xếp vào một trong bốn loại, vì loại quy tắc quyết định nơi nó được thi hành. *Cấu trúc* là những phát biểu về hình dạng của thế giới — có bốn vai trò, một tài khoản vừa mua vừa bán — nên chúng thành lược đồ dữ liệu và thành sự vắng mặt của một số chức năng. *Kiểm tra* là những phát biểu từ chối một trạng thái không hợp lệ, nên chúng thành ràng buộc và thành các cổng chặn ở đầu mỗi thao tác. *Suy dẫn* là những phát biểu tính ra một giá trị từ các giá trị khác, nên chúng không được lưu mà được tính khi đọc. *Thủ tục* là những phát biểu về trình tự và hệ quả, nên chúng thành các bước trong tầng nghiệp vụ và là loại duy nhất cần một phép kiểm thử theo kịch bản mới nghiệm thu được. Các mốc thời gian xuất hiện trong bảng là những con số cố định của sản phẩm chứ không phải tham số vận hành: người dùng đang đếm ngược trên màn hình của họ nhìn thấy đúng những con số đó, nên chúng không được để lộ ra một bảng cấu hình mà người vận hành có thể sửa giữa chừng.

#figure(
  kind: table,
  caption: [Bộ quy tắc nghiệp vụ ràng buộc hệ thống],
  table(
    columns: (0.42fr, 0.72fr, 4.3fr),
    align: (center + horizon, center + horizon, left + top),
    table.header([Mã], [Loại], [Phát biểu]),

    table.cell(colspan: 3, align: left)[*a) Định danh, phân quyền và phiên làm việc*],
    [BR-01], [Cấu trúc], [Hệ thống có bốn vai trò: người dùng đăng ký công khai, điều phối viên do quản trị viên cấp phát, quản trị viên, và bàn hỗ trợ. Quản trị viên có đầy đủ mọi quyền của điều phối viên.],
    [BR-02], [Cấu trúc], [Một tài khoản mang cả năng lực mua lẫn năng lực bán; không có thủ tục mở gian hàng riêng.],
    [BR-03], [Cấu trúc], [Bàn hỗ trợ là một tài khoản kỹ thuật duy nhất do hệ thống khởi tạo. Tên tài khoản đó bị cấm đăng ký, và một triển khai chưa khởi tạo được nó sẽ báo lỗi ngay ở phiếu đầu tiên thay vì chọn nhầm tài khoản của một người dùng thật.],
    [BR-04], [Kiểm tra], [Chỉ quản trị viên được cấp phát hoặc thu hồi tài khoản điều phối viên.],
    [BR-05], [Thủ tục], [Mật khẩu luôn được băm một chiều trước khi lưu; không tồn tại đường đi nào đọc lại được mật khẩu nguyên bản.],
    [BR-06], [Thủ tục], [Mọi yêu cầu đã xác thực đều tra cứu phiên đăng nhập tương ứng. Nhờ vậy một lần đăng xuất, một lần đổi mật khẩu hoặc một lệnh khoá tài khoản có hiệu lực ngay với các thẻ truy cập đang lưu hành, thay vì phải chờ chúng hết hạn.],
    [BR-07], [Kiểm tra], [Chỉ tài khoản đã xác minh danh tính mới tạo được tin đăng và mới rút được tiền. Cổng kiểm tra đặt ở bước tạo tin, không ở bước công bố.],
    [BR-08], [Thủ tục], [Một phán quyết xác minh do nhà cung cấp đưa ra vẫn đi qua đúng các bước chuyển trạng thái như phán quyết của người thật: hồ sơ bị từ chối bắt buộc có lý do, giấy tờ có thời hạn bắt buộc có ngày hết hạn.],
    [BR-09], [Suy dẫn], [Mọi định danh công bố ra ngoài đều ở dạng mờ, không để lộ số thứ tự tăng dần của bản ghi và không cho phép dò tìm bằng cách cộng trừ một đơn vị.],
    [BR-57], [Kiểm tra], [Mỗi loại địa chỉ trong sổ địa chỉ của một tài khoản có tối đa một bản ghi được đánh dấu mặc định. Đây là quy tắc chỉ trải trên tập địa chỉ, không phải một trường của tài khoản.],

    table.cell(colspan: 3, align: left)[*b) Tin đăng và kiểm duyệt*],
    [BR-10], [Thủ tục], [Mọi tin đăng khi công bố đều vào hàng đợi duyệt của người thật, xếp theo thứ tự thời gian gửi. Không tồn tại bộ lọc tự động nào thay thế hoặc rút ngắn bước này.],
    [BR-11], [Kiểm tra], [Người bán chưa khai báo địa chỉ lấy hàng thì không công bố được tin đăng. Địa chỉ lấy hàng được chụp lại vào tin tại thời điểm công bố và không đổi theo sổ địa chỉ về sau.],
    [BR-12], [Thủ tục], [Sửa một tin đang hiển thị không có hiệu lực ngay: bản sửa được giữ ở trạng thái chờ duyệt trong khi bản đang hiển thị vẫn phục vụ người mua.],
    [BR-13], [Cấu trúc], [Tin bị điều phối viên gỡ và tin do chính người bán ẩn đi được phân biệt với nhau. Một tin bị gỡ không tự trở lại hiển thị được: người bán gửi lại thì tin quay về hàng đợi duyệt, và chỉ một điều phối viên mới đưa nó ra công khai.],
    [BR-14], [Kiểm tra], [Chế độ giá chỉ quyết định tin đăng có nhận trả giá hay không. Tin giá cố định từ chối bị thương lượng; tin cho phép thương lượng vẫn mua thẳng được theo giá niêm yết.],
    [BR-15], [Kiểm tra], [Tồn kho được quản lý theo từng phiên bản sản phẩm với ba bộ đếm tách bạch là tổng số, đang giữ và đã bán; số còn lại là hiệu của chúng chứ không phải một bộ đếm thứ tư. Không bộ đếm nào được phép âm, và phần đang giữ cộng phần đã bán không bao giờ vượt tổng số.],

    table.cell(colspan: 3, align: left)[*c) Thương lượng giá*],
    [BR-16], [Thủ tục], [Người mua là bên mở thương lượng. Hai bên luân phiên đưa đề xuất, và bên được quyền chấp thuận luôn là bên không đang giữ đề xuất hiện hành.],
    [BR-17], [Thủ tục], [Một đề xuất đang chờ có hiệu lực mười hai giờ. Quá hạn, thương lượng hết hiệu lực và phải mở lại từ đầu.],
    [BR-18], [Thủ tục], [Chấp thuận một mức giá không tạo đơn hàng và không thu bất kỳ khoản nào; nó chỉ đóng băng mức giá đó trong ba mươi phút để người mua tự quyết định có tạo đơn hay không.],
    [BR-19], [Kiểm tra], [Mỗi cặp người mua và phiên bản sản phẩm chỉ có đúng một thương lượng đang sống tại một thời điểm.],
    [BR-20], [Cấu trúc], [Mức giá đang thương lượng không bao giờ được sao chép vào nội dung tin nhắn; hội thoại chỉ mang một tham chiếu tới bản ghi thương lượng.],

    table.cell(colspan: 3, align: left)[*d) Thanh toán, ký quỹ và vận chuyển*],
    [BR-21], [Thủ tục], [Tiền thanh toán bắt buộc đi vào ký quỹ của sàn trước khi về người bán; không tồn tại đường đi nào chuyển thẳng từ người mua sang người bán.],
    [BR-22], [Thủ tục], [Đơn hàng ra đời khi cổng thanh toán báo kết quả về, không phải khi có ai đó bấm nút. Trang mà người trả tiền đáp xuống sau khi thanh toán không được coi là bằng chứng.],
    [BR-23], [Thủ tục], [Phiên thanh toán chưa trả sống mười lăm phút; quá hạn, phiên không còn trả được và mọi phần đã giành được trả lại.],
    [BR-56], [Thủ tục], [Một phiếu mua tạm có hiệu lực ba mươi phút kể từ lúc lập, đúng bằng thời gian đóng băng của một mức giá đã được chấp thuận. Quá hạn, tồn kho đang giữ được trả lại và người mua phải lập phiếu mới.],
    [BR-24], [Kiểm tra], [Quyền mua phải được giành trước khi phiên thanh toán được mở. Một phiếu mua tạm hoặc một thương lượng đã chấp thuận chỉ sinh ra được đúng một đơn hàng.],
    [BR-25], [Suy dẫn], [Người mua luôn trả toàn bộ phí giao hàng. Sàn không thu hoa hồng trên giá trị hàng hoá và không có phương án chia phí giao hàng giữa hai bên.],
    [BR-26], [Thủ tục], [Phí giao hàng không bao giờ vào ví người bán: ngay khi tiền vào ký quỹ, nó đã được tách thành một khoản riêng vì đó là tiền của bên vận chuyển.],
    [BR-27], [Suy dẫn], [Phí giao hàng đã thu chỉ được trả lại khi kiện hàng chưa từng rời kho, tức là khi đơn bị huỷ hoặc bị người bán từ chối. Một yêu cầu hoàn tiền được chấp thuận không hoàn phí giao hàng, vì chặng vận chuyển đó đã thực sự diễn ra.],
    [BR-28], [Thủ tục], [Người bán có bốn mươi tám giờ để xác nhận một đơn hàng đã thanh toán, và việc xác nhận chỉ mở đường cho việc đặt vận đơn. Quá hạn, hệ thống nhắc bộ phận vận hành đi giục; hệ thống không tự huỷ đơn và không tự hoàn tiền.],
    [BR-29], [Thủ tục], [Người bán từ chối một đơn hàng bắt buộc phải nêu lý do; khi đó toàn bộ tiền hàng cộng phí giao hàng được hoàn cho người mua và tồn kho được trả lại.],
    [BR-30], [Thủ tục], [Việc đặt vận đơn với hãng vận chuyển là nghĩa vụ đi kèm khoản phí đã thu. Nếu lần đặt đầu thất bại, hệ thống thử lại; mã vận đơn đã có là dấu hiệu đã đặt, nên một lần bán không bao giờ sinh ra hai kiện hàng.],
    [BR-31], [Kiểm tra], [Trạng thái hành trình do hãng vận chuyển báo về chỉ tiến chứ không lùi: một mốc tới muộn hơn nhưng ở phía sau vị trí hiện tại của kiện hàng sẽ bị bỏ qua, và một trạng thái hệ thống không mô hình hoá cũng bị bỏ qua thay vì đoán.],

    table.cell(colspan: 3, align: left)[*e) Ví, giải ngân và rút tiền*],
    [BR-32], [Thủ tục], [Đồng hồ bảy mươi hai giờ chỉ bắt đầu chạy từ lúc người mua chủ động xác nhận đã nhận hàng. Hệ thống không tự xác nhận thay người mua trong bất kỳ hoàn cảnh nào.],
    [BR-33], [Kiểm tra], [Xác nhận đã nhận hàng bắt buộc kèm ít nhất một tệp bằng chứng.],
    [BR-34], [Thủ tục], [Hết bảy mươi hai giờ mà không có yêu cầu hoàn tiền nào đang sống, tiền hàng chuyển từ ký quỹ sang số dư khả dụng của người bán, nguyên vẹn và không bị trừ khoản nào.],
    [BR-35], [Kiểm tra], [Mọi biến động số dư đều có một bút toán trong sổ ví; sổ chỉ được thêm mới, và không số dư nào được phép âm.],
    [BR-36], [Kiểm tra], [Chỉ phần số dư khả dụng mới rút được; phần đang bị giữ trong ký quỹ thì không. Số tiền rút bị trừ ngay khi yêu cầu được tạo và được hoàn lại nếu yêu cầu bị từ chối.],

    table.cell(colspan: 3, align: left)[*f) Hoàn tiền và phân xử*],
    [BR-37], [Kiểm tra], [Người mua được mở yêu cầu hoàn tiền ở bất kỳ thời điểm nào trước khi đơn kết thúc. Một đơn có yêu cầu hoàn tiền đang sống thì không được giải ngân.],
    [BR-38], [Suy dẫn], [Hoàn tiền luôn là toàn phần; không có hoàn tiền một phần ở bất kỳ nhánh nào.],
    [BR-39], [Cấu trúc], [Người bán chỉ có hai nước đi trước một yêu cầu hoàn tiền: chấp nhận cho trả hàng, hoặc chuyển hồ sơ cho sàn phân xử. Không tồn tại lựa chọn từ chối bằng lời của chính người bán.],
    [BR-40], [Thủ tục], [Người bán im lặng quá bốn mươi tám giờ thì hồ sơ tự chuyển lên sàn phân xử. Im lặng không phải là đồng ý, cũng không phải là một phán quyết.],
    [BR-41], [Cấu trúc], [Người mua không bao giờ là bên chuyển hồ sơ lên sàn: họ đã mở khiếu nại một lần, và bắt họ mở lần thứ hai chính là bước khiến bên đang mất tiền mất luôn cả vụ việc.],
    [BR-42], [Thủ tục], [Chấp nhận hoàn tiền chưa phải là trả tiền: hàng phải quay về trước. Người bán xác nhận đã nhận hàng trả về thì có bốn mươi tám giờ để kiểm hàng; hết hạn mà không có ý kiến thì tiền về người mua. Nếu chính người mua là bên khai đã trả hàng, hồ sơ đi thẳng lên sàn phân xử.],
    [BR-43], [Thủ tục], [Một phán quyết đóng mọi phiếu đang mở nhắm vào cùng đối tượng, vì cả hai bên đều có thể đã mở phiếu về cùng một hồ sơ.],

    table.cell(colspan: 3, align: left)[*g) Phiếu hỗ trợ, đánh giá và vận hành*],
    [BR-44], [Cấu trúc], [Mọi thứ người dùng gửi lên bộ phận hỗ trợ đều là một phiếu, nằm trong một hàng đợi duy nhất; loại phiếu là thứ duy nhất phân biệt chúng, và loại phiếu quyết định luôn phiếu đó nói về đối tượng nào.],
    [BR-45], [Cấu trúc], [Mỗi phiếu có một cuộc hội thoại giữa người gửi và bàn hỗ trợ; nội dung cùng tệp đính kèm của phiếu chính là tin nhắn đầu tiên của hội thoại đó.],
    [BR-46], [Thủ tục], [Điều phối viên trả lời với tư cách bàn hỗ trợ. Danh tính cá nhân của họ bị ẩn với người gửi ở mọi nơi hiển thị tin nhắn, kể cả ở dòng tin nhắn cuối trong danh sách hội thoại.],
    [BR-47], [Kiểm tra], [Không nhắn tin trực tiếp cho bàn hỗ trợ được; muốn liên hệ với sàn thì mở phiếu, vì một hội thoại riêng với bàn hỗ trợ là hội thoại không điều phối viên nào đọc được.],
    [BR-58], [Kiểm tra], [Mỗi cặp tài khoản có tối đa một hội thoại trực tiếp, mở ra ở lần nhắn đầu tiên và dùng lại mãi về sau. Hội thoại của phiếu hỗ trợ nằm ngoài quy tắc này, vì một người mở nhiều phiếu và phiếu nào cũng ghép họ với bàn hỗ trợ.],
    [BR-48], [Kiểm tra], [Một người gửi chỉ có một phiếu đang mở về cùng một đối tượng.],
    [BR-49], [Cấu trúc], [Không tồn tại ngưỡng số lượt tố cáo nào tự động ẩn một tin đăng. Hệ thống chỉ hiển thị cho điều phối viên số phiếu đang mở nhắm vào cùng đối tượng, như một thông tin tham khảo.],
    [BR-50], [Kiểm tra], [Phiếu khiếu nại hoàn tiền không được kết luận bằng tay ở màn hình phiếu; nó chỉ đóng theo phán quyết ra ở nơi giữ tiền.],
    [BR-51], [Suy dẫn], [Đánh giá giao dịch là hai chiều và ẩn: chiều đánh giá được suy ra từ vị trí của người đánh giá trong đơn chứ không do người dùng khai, và đánh giá chỉ hiện ra khi cả hai bên đã gửi hoặc sau mười bốn ngày.],
    [BR-52], [Thủ tục], [Công bố một đánh giá và cộng nó vào điểm uy tín là cùng một thao tác, nên một đánh giá đã hiện ra luôn là một đánh giá đã được đếm, và không đánh giá nào bị đếm hai lần. Đánh giá giao dịch và đánh giá sản phẩm được đếm tách rời, vì một đơn hàng có thể sinh ra cả hai.],
    [BR-53], [Kiểm tra], [Chỉ người đã mua một sản phẩm mới viết được nhận xét về sản phẩm đó, và mỗi người chỉ bình chọn một nhận xét là hữu ích đúng một lần.],
    [BR-54], [Cấu trúc], [Cổng thanh toán và hãng vận chuyển được chọn theo từng dòng trong sổ tuỳ chọn chứ không theo một tham số chung, nên nhiều nhà cung cấp cùng phục vụ được. Một dòng bị tắt vẫn đọc được, vì các bản ghi cũ đã ghi tên nó và phải giữ nguyên ý nghĩa.],
    [BR-55], [Thủ tục], [Mọi quyết định nghiệp vụ và mọi biến động tiền đều để lại một bản ghi kiểm toán chỉ-thêm-mới, được ghi trong cùng giao dịch cơ sở dữ liệu với chính thay đổi đó.],
  )
)

#note[*Về việc các mốc thời gian không phải tham số cấu hình.* Sáu mốc chờ xuất hiện xuyên suốt bộ quy tắc — mười hai giờ hiệu lực của một đề xuất giá, ba mươi phút đóng băng của một mức giá đã được chấp thuận, ba mươi phút hiệu lực của một phiếu mua tạm, mười lăm phút của một phiên thanh toán, bốn mươi tám giờ để người bán xác nhận đơn hoặc trả lời một yêu cầu hoàn tiền, và bảy mươi hai giờ ký quỹ — đều được cố định trong hệ thống. Lý do là chúng đã được hiển thị cho người dùng dưới dạng một đồng hồ đếm ngược: sửa chúng khi đang có hàng nghìn đồng hồ đang chạy đồng nghĩa với việc thay đổi lời hứa giữa chừng. Thứ quản trị viên thực sự cấu hình được là sổ tuỳ chọn nhà cung cấp (UC-28), tức là bật tắt các cổng thanh toán và hãng vận chuyển.]
