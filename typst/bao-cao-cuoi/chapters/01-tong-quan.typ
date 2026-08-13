= TỔNG QUAN

== Bối cảnh và Lý do chọn đề tài

Thị trường giao dịch trực tuyến giữa các cá nhân (C2C - Consumer-to-Consumer) tại Việt Nam đang chứng kiến sự tăng trưởng vượt bậc, đặc biệt trong các lĩnh vực mua bán đồ cũ, thanh lý thiết bị điện tử, sách giáo khoa, đồ gia dụng, thời trang và các sản phẩm thủ công (handmade). Tuy nhiên, khi các giao dịch diễn ra tự phát mà không có sự bảo lãnh tài chính và giám sát chuẩn mực, thị trường C2C truyền thống đang phải đối mặt với rào cản lớn nhất là khủng hoảng niềm tin giữa các bên tham gia giao dịch.

Ba thách thức cốt lõi đang kìm hãm sự phát triển lành mạnh của hệ sinh thái này. Thứ nhất là rủi ro từ phía người mua. Khi mua hàng thanh lý từ một cá nhân xa lạ, người mua luôn ở thế bất lợi nếu phải đặt cọc hoặc thanh toán trước bằng cách chuyển khoản trực tiếp qua tài khoản ngân hàng cá nhân. Tình trạng lừa đảo (scam) diễn ra phổ biến, cụ thể là nhận tiền nhưng không giao hàng, hoặc cố tình giao sai sản phẩm, hàng giả, hàng lỗi hỏng nặng không đúng mô tả. Khi sự cố xảy ra, người mua gần như không có cơ chế pháp lý hay bên thứ ba nào bảo vệ; người bán cá nhân thường tìm cách từ chối hoàn tiền, chặn liên lạc hoặc xóa tài khoản.

Thứ hai là rủi ro dồn về phía người bán cá nhân. Để tạo lòng tin cho người mua, nhiều người bán phải chấp nhận hình thức giao hàng thu tiền hộ (COD - Cash on Delivery), nhưng giải pháp này lại đẩy rủi ro sang chính họ: tỷ lệ người mua đặt hàng tùy hứng rồi từ chối nhận hàng ("boom hàng") mà không có lý do chính đáng rất cao. Trong trường hợp đó, người bán không những phải gánh gấp đôi chi phí vận chuyển hai chiều, gồm chi phí gửi đi và hoàn về, mà sản phẩm còn có nguy cơ bị hư hỏng, thất lạc hoặc suy giảm giá trị trong quá trình luân chuyển đường dài. Nghiêm trọng hơn, một số đối tượng xấu còn lợi dụng việc kiểm hàng để tráo đổi linh kiện chính hãng rồi từ chối nhận.

Thứ ba là sự phân mảnh trong giao tiếp và thỏa thuận giao dịch. Đặc thù của mua bán đồ cũ là nhu cầu thương lượng giá và kiểm chứng thực tế bằng hình ảnh hoặc video trực tiếp, nhưng quy trình này thường diễn ra phân mảnh trên các ứng dụng nhắn tin bên thứ ba ngoài sàn như Zalo, Messenger hay Telegram. Khi hai bên thống nhất một mức giá ưu đãi, ví dụ bớt 50.000 đồng vì hỗ trợ phí vận chuyển, việc thanh toán trên sàn giao dịch lại không đồng bộ được mức giá thỏa thuận ấy một cách tự động. Đồng thời, khi tranh chấp xảy ra, các sàn thương mại điện tử (TMĐT) truyền thống không có quyền truy cập hoặc không thể xác thực tính chính xác của các đoạn chat bên ngoài, dẫn đến thiếu chứng cứ lịch sử gắn liền với đơn hàng để phân xử công bằng.

Xét ở bình diện vĩ mô, quy mô thị trường thương mại điện tử Việt Nam trong những năm gần đây liên tục duy trì tốc độ tăng trưởng hai con số về doanh thu bán lẻ trực tuyến và tỷ lệ người dân tham gia mua sắm trực tuyến, song phần lớn các nền tảng rao vặt C2C hiện hữu như Chợ Tốt vẫn chủ yếu đóng vai trò kết nối thông tin giữa hai cá nhân, để hai bên tự thỏa thuận và tự chuyển tiền cho nhau mà không có cơ chế bảo lãnh dòng tiền tập trung. Về hành lang pháp lý, hoạt động của các sàn giao dịch thương mại điện tử tại Việt Nam chịu sự điều chỉnh của Nghị định số 52/2013/NĐ-CP về thương mại điện tử cùng những sửa đổi, bổ sung tại Nghị định số 85/2021/NĐ-CP, trong đó xác lập trách nhiệm của đơn vị cung cấp dịch vụ sàn trong việc quản lý thông tin người bán cũng như tiếp nhận và xử lý khiếu nại, trong khi quyền được thông tin, được bảo vệ và được giải quyết tranh chấp của người mua được ghi nhận trong Luật Bảo vệ quyền lợi người tiêu dùng năm 2023 [1] [2].

Trước thực trạng và những khoảng trống lớn của thị trường, đề tài "Ứng dụng thương mại điện tử sử dụng kiến trúc Microservices" được lựa chọn nhằm nghiên cứu, phân tích và thiết kế một hệ sinh thái giao dịch C2C an toàn, minh bạch và hiện đại, đặt trọng tâm giải quyết bài toán "lòng tin" bằng ba trụ cột nghiệp vụ và kỹ thuật.

Trụ cột thứ nhất là cơ chế ký quỹ (escrow): sàn đóng vai trò bên thứ ba trung gian đáng tin cậy giữ tiền giao dịch, dòng tiền của người mua được khóa trong ví ký quỹ cho đến khi giao hàng thành công và người mua xác nhận hài lòng, hoặc cho đến khi hết thời hạn đếm ngược 3 ngày (72 giờ) mà không có khiếu nại. Trụ cột thứ hai là tích hợp nhắn tin trực tuyến và Thẻ Đề xuất giá (Offer Card): hệ thống giao tiếp gắn liền mạch vào sàn cho phép thương lượng giá động ngay trong khung chat qua thẻ đề xuất có hiệu lực 12 giờ, ràng buộc trực tiếp thỏa thuận giá vào luồng thanh toán đơn hàng. Trụ cột thứ ba là quy trình hoàn tiền và phân xử tranh chấp minh bạch: mọi khiếu nại đều bắt buộc kèm bằng chứng số đa phương tiện như video mở hộp hay ảnh chụp đóng gói, và khi hai bên không đạt được thỏa thuận thì vụ việc được thăng cấp lên điều phối viên nội bộ để thẩm định và ra quyết định công bằng cho cả hai bên.

== Mục tiêu của nghiên cứu

Mục tiêu tổng quát của nghiên cứu là áp dụng triệt để các phương pháp kỹ thuật phần mềm tiên tiến, đặc biệt là kiến trúc hướng dịch vụ (SOA) và mô hình Microservices hiện đại, để thiết kế và hiện thực hóa một nền tảng TMĐT C2C toàn diện, an toàn và có khả năng chịu tải, mở rộng cao [8].

Về nghiệp vụ, đề tài đặt bốn mục tiêu cụ thể. Thứ nhất là xây dựng cơ chế ký quỹ bền vững và luồng tài chính an toàn, với luồng thanh toán tích hợp cổng ngân hàng hoặc ví điện tử ngoại vi (SePay) và dòng tiền được quản lý theo mô hình ví nội bộ (Internal Wallet). Thứ hai là tích hợp nhắn tin trực tuyến thời gian thực và chuẩn hóa quy trình đàm phán giá qua Thẻ Đề xuất giá, trong đó module chat đa phương tiện cho phép gửi hình ảnh và video thực tế của sản phẩm giữa người mua và người bán. Thứ ba là thiết lập quy trình hoàn tiền, phân xử tranh chấp và kiểm duyệt nội dung, với luồng xử lý khiếu nại trong hạn 3 ngày kèm ràng buộc cung cấp bằng chứng số. Thứ tư là thiết lập mô hình phân quyền chặt chẽ theo ba vai trò: người dùng là tài khoản tự do đăng ký, sở hữu vai trò kép vừa mua vừa bán trên cùng một định danh; điều phối viên là tài khoản nội bộ do quản trị viên cấp phát, chịu trách nhiệm thẩm định khiếu nại, phân xử tranh chấp và kiểm duyệt tin đăng vi phạm; quản trị viên tối cao là tài khoản duy nhất cấu hình sẵn, có thẩm quyền thiết lập tham số hệ thống, kiểm soát dòng tiền tổng thể và quản lý nhân sự điều phối viên.

Về công nghệ, đề tài đặt ba mục tiêu nghiên cứu. Kiến trúc Durable Microservices phân rã hệ thống thành các dịch vụ độc lập, áp dụng triệt để nguyên lý Database-per-service [9] để bảo đảm sự cô lập về cơ sở dữ liệu và khả năng chọn công nghệ lưu trữ phù hợp (Polyglot Persistence), đồng thời ứng dụng durable execution (thực thi bền) Restate nhằm quản lý các luồng nghiệp vụ dài hạn như ký quỹ, hoàn tiền hay tranh chấp, loại bỏ độ phức tạp của mẫu thiết kế Saga truyền thống [4], tự động phục hồi lỗi và bảo đảm ngữ nghĩa thực thi chính xác một lần. Tìm kiếm lai giữa từ khóa và ngữ nghĩa kết hợp tìm kiếm văn bản (Full-text Search) với tìm kiếm vector ngữ nghĩa qua cơ sở dữ liệu pgvector trên PostgreSQL [11], sử dụng mô hình embedding đa ngôn ngữ bge-m3 để sinh biểu diễn vector cho dữ liệu văn bản [3]. Cuối cùng, hệ gợi ý sản phẩm cá nhân hóa đa hướng quan tâm biểu diễn sở thích người dùng qua nhiều vector đặc trưng, được cập nhật liên tục dựa trên lịch sử tương tác, hành vi tìm kiếm và độ tương đồng ngữ nghĩa của mặt hàng [7].

== Phạm vi hệ thống

=== Trong phạm vi nghiên cứu (In-Scope)

Hệ thống được thiết kế bao phủ toàn bộ vòng đời giao dịch thương mại điện tử giữa các cá nhân (C2C), bao gồm 8 phân hệ chức năng và nghiệp vụ cốt lõi sau:

1. *Quản lý tài khoản, Phân quyền (RBAC) và Ví nội bộ:* Hỗ trợ đăng ký, đăng nhập bảo mật (JWT), xác thực tài khoản và quản lý thông tin hồ sơ người dùng.

2. *Quản lý danh mục và Đăng bán sản phẩm C2C:* Cho phép người bán đăng tải sản phẩm thanh lý với thông tin chi tiết: tên, mô tả, hình ảnh/video đa phương tiện, phân loại tình trạng (Mới, Cũ, Bị hư hại một phần).

3. *Tìm kiếm thông minh và Gợi ý sản phẩm:* Cung cấp công cụ tìm kiếm kết hợp giữa tìm kiếm từ khóa đầy đủ (Full-text Search) và tìm kiếm vector ngữ nghĩa (Semantic Search dựa trên pgvector và mô hình bge-m3).

4. *Hệ thống Chat trực tuyến và Thương lượng giá (Offer Card):* Kênh giao tiếp tin nhắn văn bản và chia sẻ phương tiện thời gian thực giữa người mua và người bán.

5. *Đặt hàng, Tính phí vận chuyển động và Ký quỹ:* Quy trình khởi tạo đơn hàng từ trang chi tiết sản phẩm (giá cố định) hoặc từ Offer Card trong Chat (giá thương lượng).

6. *Xác nhận giao hàng và Bộ đếm thời gian tạm giữ:* Lắng nghe sự kiện cập nhật hành trình vận đơn từ đơn vị giao nhận; tự động kích hoạt bộ đếm thời gian đếm ngược 3 ngày (72 giờ) hoặc khi đơn hàng chuyển sang trạng thái "Giao hàng thành công".

7. *Khiếu nại Hoàn tiền (Refund), Tranh chấp (Dispute) và Phân xử:* Quy trình gửi yêu cầu Refund/Return trong khung thời gian 72 giờ kèm việc tải lên bằng chứng số đa phương tiện bắt buộc.

8. *Kiểm duyệt Nội dung và Báo cáo vi phạm (Content Moderation):* Nghiên cứu và xây dựng cơ chế kiểm duyệt nội dung nhằm phát hiện các tin đăng có dấu hiệu vi phạm (lừa đảo, hàng giả, hàng cấm...).

=== Ngoài phạm vi nghiên cứu (Out-of-Scope)

Để đảm bảo tính khả thi, độ tập trung chuyên sâu vào mô hình kiến trúc Microservices và trọn vẹn luồng giao dịch C2C cá nhân, các hạng mục sau được xác định nằm ngoài phạm vi nghiên cứu của đề tài:

1. *Gian hàng doanh nghiệp chính hãng (B2C / Shop Mall):* Hệ thống hiện tại chỉ thiết kế tối ưu cho giao dịch cá nhân bán cho cá nhân (C2C). Việc phát triển các gian hàng thương hiệu chính hãng quy mô lớn từ các doanh nghiệp (với quy trình hóa đơn đỏ, quản lý kho hàng nghìn SKUs phức tạp) là định hướng mở rộng trong tương lai.
2. *Giao dịch và vận chuyển quốc tế:* Đề tài chỉ tập trung vào thị trường nội địa Việt Nam; không xử lý các luồng thanh toán đa ngoại tệ, chuyển đổi tỷ giá, thủ tục hải quan hay tích hợp các đơn vị vận chuyển xuyên biên giới.
3. *Gọi thoại và gọi video trực tiếp (Voice/Video Call):* Không triển khai tính năng gọi điện thoại hay gọi video trực tiếp trên nền tảng web/mobi qua WebRTC. Toàn bộ quá trình đàm phán, trao đổi và làm bằng chứng được thực hiện bằng tin nhắn văn bản, hình ảnh và video quay sẵn tải lên khung chat.
4. *Đăng ký công khai cho vai trò Moderator và Super Admin:* Các tài khoản quản trị viên và điều phối viên là tài khoản nội bộ có thẩm quyền cao, được kiểm soát và khởi tạo theo quy trình quản trị tập trung, không cung cấp biểu mẫu đăng ký tự do công khai ra bên ngoài.

== Phương pháp nghiên cứu

Để giải quyết các bài toán nghiệp vụ và kiến trúc kỹ thuật đã đặt ra, đề tài kết hợp ba phương pháp. Phân tích và thiết kế hướng đối tượng (OOAD) dùng ngôn ngữ mô hình hóa thống nhất (UML) để chuẩn hóa tài liệu thiết kế, gồm biểu đồ ca sử dụng, biểu đồ hoạt động, biểu đồ trình tự, biểu đồ lớp và biểu đồ thực thể quan hệ. Kiến trúc hướng dịch vụ (SOA) cùng mô hình Microservices áp dụng mẫu thiết kế Database-per-service, bảo đảm mỗi dịch vụ sở hữu cấu trúc lưu trữ và cơ sở dữ liệu riêng biệt, qua đó triệt tiêu hiện tượng nghẽn cổ chai cơ sở dữ liệu tập trung và ngăn chặn truy cập dữ liệu chéo trái phép. Phương pháp durable execution nghiên cứu và áp dụng nền tảng Restate dựa trên triết lý Journal-based Execution, tức thực thi dựa trên nhật ký ghi trước (Write-Ahead Log) [12].

== Đóng góp của đề tài

Đề tài nghiên cứu và xây dựng nền tảng ShopNexus mang lại ba đóng góp. Về giải pháp nghiệp vụ cho thị trường TMĐT C2C, đề tài đề xuất và hiện thực hóa mô hình sàn giao dịch C2C thế hệ mới, giải quyết bài toán khủng hoảng niềm tin và sự phân mảnh trong giao tiếp truyền thống. Về kiến trúc phần mềm, đề tài nghiên cứu và triển khai mô hình Durable Microservices trên nền tảng Restate trong một hệ thống thương mại điện tử thực tế tại Việt Nam. Về sản phẩm thực tiễn, đề tài bàn giao một bộ phần mềm hoạt động trọn vẹn, gồm giao diện người dùng viết bằng Next.js và Flutter cùng hệ thống backend microservices hoàn chỉnh.
