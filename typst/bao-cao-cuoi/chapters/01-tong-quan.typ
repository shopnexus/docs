= TỔNG QUAN

== Bối cảnh và Lý do chọn đề tài


Cụ thể, những thách thức cốt lõi đang kìm hãm sự phát triển lành mạnh của hệ sinh thái này bao gồm:
- *Rủi ro từ góc độ Người mua:* Khi tham gia mua sắm hàng thanh lý từ một cá nhân xa lạ, người mua luôn rơi vào tình huống bất lợi nếu phải đặt cọc hoặc thanh toán trước (chuyển khoản trực tiếp qua tài khoản ngân hàng cá nhân). Tình trạng "lừa đảo" (scam) cụ thể là nhận tiền nhưng không giao hàng, hoặc cố tình giao sai sản phẩm, hàng giả, hàng lỗi/hỏng nặng không đúng mô tả diễn ra phổ biến. Khi sự cố xảy ra, người mua gần như không có cơ chế pháp lý hay bên thứ ba nào bảo vệ; người bán cá nhân thường tìm cách từ chối hoàn tiền, chặn liên lạc hoặc xóa tài khoản.
- *Rủi ro từ góc độ Người bán cá nhân:* Để tạo lòng tin cho người mua, nhiều người bán phải chấp nhận hình thức giao hàng thu tiền hộ (COD - Cash on Delivery). Tuy nhiên, giải pháp này lại đẩy rủi ro về phía người bán: tỷ lệ người mua đặt hàng tùy hứng rồi từ chối nhận hàng ("boom hàng") mà không có lý do chính đáng rất cao. Trong trường hợp đó, người bán cá nhân không những phải gánh chịu gấp đôi chi phí vận chuyển hai chiều (chi phí gửi đi và hoàn về) mà sản phẩm còn có nguy cơ bị hư hỏng, thất lạc hoặc suy giảm giá trị trong quá trình luân chuyển đường dài. Nghiêm trọng hơn, một số đối tượng xấu còn lợi dụng việc kiểm hàng để tráo đổi linh kiện chính hãng rồi từ chối nhận.
- *Sự phân mảnh trong giao tiếp và thỏa thuận giao dịch:* Đặc thù của mua bán đồ cũ là nhu cầu thương lượng giá (mặc cả) và kiểm chứng thực tế bằng hình ảnh/video trực tiếp. Hiện nay, quy trình này thường diễn ra phân mảnh trên các ứng dụng nhắn tin bên thứ ba ngoài sàn (như Zalo, Messenger, Telegram). Khi hai bên thống nhất một mức giá ưu đãi (ví dụ: bớt 50.000 VNĐ vì hỗ trợ phí vận chuyển), việc thanh toán trên sàn giao dịch lại không đồng bộ được mức giá thỏa thuận này một cách tự động. Đồng thời, khi tranh chấp xảy ra, các sàn thương mại điện tử (TMĐT) truyền thống không có quyền truy cập hoặc không thể xác thực tính chính xác của các đoạn chat bên ngoài, dẫn đến thiếu chứng cứ lịch sử gắn liền với đơn hàng để phân xử công bằng.

Xét ở bình diện vĩ mô, quy mô thị trường thương mại điện tử Việt Nam trong những năm gần đây liên tục duy trì tốc độ tăng trưởng hai con số về doanh thu bán lẻ trực tuyến và tỷ lệ người dân tham gia mua sắm trực tuyến, song phần lớn các nền tảng rao vặt C2C hiện hữu như Chợ Tốt vẫn chủ yếu đóng vai trò kết nối thông tin giữa hai cá nhân, để hai bên tự thỏa thuận và tự chuyển tiền cho nhau mà không có cơ chế bảo lãnh dòng tiền tập trung. Về hành lang pháp lý, hoạt động của các sàn giao dịch thương mại điện tử tại Việt Nam chịu sự điều chỉnh của Nghị định số 52/2013/NĐ-CP về thương mại điện tử cùng những sửa đổi, bổ sung tại Nghị định số 85/2021/NĐ-CP, trong đó xác lập trách nhiệm của đơn vị cung cấp dịch vụ sàn trong việc quản lý thông tin người bán cũng như tiếp nhận và xử lý khiếu nại, trong khi quyền được thông tin, được bảo vệ và được giải quyết tranh chấp của người mua được ghi nhận trong Luật Bảo vệ quyền lợi người tiêu dùng năm 2023 [1] [2].

Trước thực trạng và những khoảng trống lớn của thị trường, đề tài "Ứng dụng thương mại điện tử sử dụng kiến trúc Microservices" được lựa chọn nhằm nghiên cứu, phân tích và thiết kế một hệ sinh thái giao dịch C2C an toàn, minh bạch và hiện đại, đặt trọng tâm giải quyết bài toán "lòng tin" bằng việc thiết lập ba trụ cột nghiệp vụ và kỹ thuật chính sau:
+ *Cơ chế Bảo lãnh tài chính tạm giữ (Escrow Payment):* Sàn thương mại điện tử sẽ đóng vai trò là bên thứ ba trung gian đáng tin cậy giữ tiền giao dịch. Dòng tiền của người mua sẽ được khóa bảo mật trong ví trung gian cho đến khi giao hàng thành công và người mua xác nhận hài lòng (hoặc hết thời hạn đếm ngược 3 ngày(72 giờ) mà không có khiếu nại).
+ *Tích hợp Nhắn tin trực tuyến và Thẻ Đề xuất giá (Offer Card):* Xây dựng hệ thống giao tiếp gắn liền liền mạch vào sàn, cho phép thương lượng giá động ngay trong khung chat qua Thẻ Đề xuất giá có hiệu lực trong 24 giờ, ràng buộc trực tiếp thỏa thuận giá vào luồng thanh toán đơn hàng.
+ *Quy trình Hoàn tiền và Phân xử tranh chấp (Refund & Dispute) minh bạch:* Thiết lập quy trình khiếu nại với ràng buộc bắt buộc cung cấp bằng chứng số đa phương tiện (video mở hộp, ảnh chụp đóng gói). Khi không đạt được thỏa thuận hoàn tiền, vụ việc được thăng cấp lên Điều phối viên (Moderator) nội bộ để thẩm định và ra quyết định công bằng cho cả hai bên.

== Mục tiêu của nghiên cứu

Mục tiêu tổng quát của nghiên cứu là áp dụng triệt để các phương pháp kỹ thuật phần mềm tiên tiến, đặc biệt là kiến trúc hướng dịch vụ (SOA) và mô hình Microservices hiện đại, để thiết kế và hiện thực hóa một nền tảng TMĐT C2C toàn diện, an toàn và có khả năng chịu tải, mở rộng cao [8].

Các mục tiêu cụ thể của đề tài được phân chia theo từng phương diện nghiệp vụ và công nghệ cốt lõi:

1. *Xây dựng cơ chế Thanh toán tạm giữ (Escrow) bền vững và luồng tài chính an toàn:*
   - Thiết kế luồng thanh toán tích hợp cổng ngân hàng/ví điện tử ngoại vi (SePay), quản lý dòng tiền theo mô hình ví nội bộ (Internal Wallet).

2. *Tích hợp Nhắn tin trực tuyến thời gian thực và Chuẩn hóa quy trình Đàm phán giá (Offer Card):*
   - Xây dựng module Chat đa phương tiện thời gian thực, cho phép gửi hình ảnh và video thực tế của sản phẩm giữa người mua và người bán.

3. *Thiết lập quy trình Hoàn tiền (Refund), Phân xử tranh chấp (Dispute) và Kiểm duyệt nội dung:*
   - Xây dựng luồng xử lý khiếu nại trong hạn 3 ngày với ràng buộc cung cấp bằng chứng số (ảnh/video mở hộp hàng hóa).

4. *Thiết lập mô hình Phân quyền chặt chẽ theo 3 vai trò (Persona) hệ thống:*
   - *Người dùng (User):* Tài khoản khách hàng tự do đăng ký, sở hữu vai trò kép (vừa mua vừa bán trên cùng một định danh).

5. *Nghiên cứu ứng dụng kiến trúc Durable Microservices:*
   - Phân rã hệ thống thành các dịch vụ độc lập áp dụng triệt để nguyên lý Database-per-service [9], bảo đảm sự cô lập về cơ sở dữ liệu và khả năng chọn lựa công nghệ lưu trữ phù hợp (Polyglot Persistence).
   - Ứng dụng cơ chế durable execution (thực thi bền vững) Restate (Journal-based Durable Execution) để quản lý các luồng nghiệp vụ dài hạn (Escrow, Refund, Dispute,...), loại bỏ hoàn toàn độ phức tạp của mẫu thiết kế Saga truyền thống [4], tự động phục hồi lỗi (Crash Recovery) và bảo đảm ngữ nghĩa thực thi chính xác một lần (Exact-once semantics).

6. *Nghiên cứu tìm kiếm dựa trên từ khóa và ngữ nghĩa:*
   - Nghiên cứu và tích hợp cơ chế Tìm kiếm Ngữ nghĩa Lai (Hybrid Search), kết hợp giữa Tìm kiếm văn bản (Full-text Search) dựa trên từ khóa và tìm kiếm ngữ nghĩa (Semantic Vector Search) thông qua cơ sở dữ liệu pgvector trên PostgreSQL [11], sử dụng mô hình embedding (véc-tơ nhúng) đa ngôn ngữ bge-m3 để sinh biểu diễn vector (vector embeddings) cho dữ liệu văn bản [3].

7. *Nghiên cứu hệ thống gợi ý sản phẩm (Recommender System):*
    - Xây dựng cơ chế gợi ý sản phẩm cá nhân hóa đa hướng quan tâm (multi-interest), biểu diễn sở thích người dùng qua nhiều vector đặc trưng được cập nhật liên tục dựa trên lịch sử tương tác, hành vi tìm kiếm và độ tương đồng ngữ nghĩa của mặt hàng [7].

== Phạm vi hệ thống

=== Trong phạm vi nghiên cứu (In-Scope)

Hệ thống được thiết kế bao phủ toàn bộ vòng đời giao dịch thương mại điện tử giữa các cá nhân (C2C), bao gồm 8 phân hệ chức năng và nghiệp vụ cốt lõi sau:

1. *Quản lý tài khoản, Phân quyền (RBAC) và Ví nội bộ:*
   - Hỗ trợ đăng ký, đăng nhập bảo mật (JWT), xác thực tài khoản và quản lý thông tin hồ sơ người dùng.

2. *Quản lý danh mục và Đăng bán sản phẩm C2C:*
   - Cho phép người bán đăng tải sản phẩm thanh lý với thông tin chi tiết: tên, mô tả, hình ảnh/video đa phương tiện, phân loại tình trạng (Mới, Cũ, Bị hư hại một phần).

3. *Tìm kiếm thông minh và Gợi ý sản phẩm:*
   - Cung cấp công cụ tìm kiếm kết hợp giữa tìm kiếm từ khóa đầy đủ (Full-text Search) và tìm kiếm vector ngữ nghĩa (Semantic Search dựa trên pgvector và mô hình bge-m3).

4. *Hệ thống Chat trực tuyến và Thương lượng giá (Offer Card):*
   - Kênh giao tiếp tin nhắn văn bản và chia sẻ phương tiện thời gian thực giữa người mua và người bán.

5. *Đặt hàng, Tính phí vận chuyển động và Thanh toán (Escrow):*
   - Quy trình khởi tạo đơn hàng từ trang chi tiết sản phẩm (giá cố định) hoặc từ Offer Card trong Chat (giá thương lượng).

6. *Xác nhận giao hàng và Bộ đếm thời gian tạm giữ:*
   - Lắng nghe sự kiện cập nhật hành trình vận đơn từ đơn vị giao nhận; tự động kích hoạt bộ đếm thời gian đếm ngược 3 ngày (72 giờ) hoặc khi đơn hàng chuyển sang trạng thái "Giao hàng thành công".

7. *Khiếu nại Hoàn tiền (Refund), Tranh chấp (Dispute) và Phân xử:*
   - Quy trình gửi yêu cầu Refund/Return trong khung thời gian 72 giờ kèm việc tải lên bằng chứng số đa phương tiện bắt buộc.

8. *Kiểm duyệt Nội dung và Báo cáo vi phạm (Content Moderation):*
   - Nghiên cứu và xây dựng cơ chế kiểm duyệt nội dung nhằm phát hiện các bài đăng có dấu hiệu vi phạm (lừa đảo, hàng giả, hàng cấm...).

=== Ngoài phạm vi nghiên cứu (Out-of-Scope)

Để đảm bảo tính khả thi, độ tập trung chuyên sâu vào mô hình kiến trúc Microservices và trọn vẹn luồng giao dịch C2C cá nhân, các hạng mục sau được xác định nằm ngoài phạm vi nghiên cứu của đề tài:

1. *Gian hàng doanh nghiệp chính hãng (B2C / Shop Mall):* Hệ thống hiện tại chỉ thiết kế tối ưu cho giao dịch cá nhân bán cho cá nhân (C2C). Việc phát triển các gian hàng thương hiệu chính hãng quy mô lớn từ các doanh nghiệp (với quy trình hóa đơn đỏ, quản lý kho hàng nghìn SKUs phức tạp) là định hướng mở rộng trong tương lai.
2. *Giao dịch và vận chuyển quốc tế:* Đề tài chỉ tập trung vào thị trường nội địa Việt Nam; không xử lý các luồng thanh toán đa ngoại tệ, chuyển đổi tỷ giá, thủ tục hải quan hay tích hợp các đơn vị vận chuyển xuyên biên giới.
3. *Gọi thoại và gọi video trực tiếp (Voice/Video Call):* Không triển khai tính năng gọi điện thoại hay gọi video trực tiếp trên nền tảng web/mobi qua WebRTC. Toàn bộ quá trình đàm phán, trao đổi và làm bằng chứng được thực hiện bằng tin nhắn văn bản, hình ảnh và video quay sẵn tải lên khung chat.
4. *Đăng ký công khai cho vai trò Moderator và Super Admin:* Các tài khoản quản trị viên và điều phối viên là tài khoản nội bộ có thẩm quyền cao, được kiểm soát và khởi tạo theo quy trình quản trị tập trung, không cung cấp biểu mẫu đăng ký tự do công khai ra bên ngoài.

== Phương pháp nghiên cứu

Để giải quyết thành công các bài toán phức tạp về nghiệp vụ và kiến trúc kỹ thuật đã đặt ra, đề tài kết hợp sử dụng các phương pháp nghiên cứu khoa học kỹ thuật phần mềm hiện đại sau:

1. *Phương pháp Phân tích và Thiết kế Hướng đối tượng (OOAD):*
   - Sử dụng ngôn ngữ mô hình hóa thống nhất (UML) để chuẩn hóa tài liệu thiết kế: Biểu đồ ca sử dụng (Use Case Diagram), Biểu đồ hoạt động (Activity Diagram), Biểu đồ trình tự (Sequence Diagram), Biểu đồ lớp (Class Diagram) và Biểu đồ thực thể - quan hệ (ERD).

2. *Phương pháp Kiến trúc Hướng dịch vụ (SOA) và mô hình Microservices:*
   - Áp dụng mẫu thiết kế Database-per-service, đảm bảo mỗi dịch vụ microservice sở hữu cấu trúc lưu trữ và cơ sở dữ liệu riêng biệt. Triệt tiêu hiện tượng nghẽn cổ chai CSDL tập trung và ngăn chặn truy cập dữ liệu chéo trái phép.


3. *Phương pháp durable execution:*
   - Nghiên cứu và áp dụng nền tảng durable execution Restate dựa trên triết lý Journal-based Execution (thực thi dựa trên nhật ký ghi trước - Write-Ahead Log) [12].


== Đóng góp của đề tài

Đề tài nghiên cứu và xây dựng nền tảng ShopNexus mang lại 3 đóng góp quan trọng:

1. *Đóng góp về Giải pháp Nghiệp vụ cho thị trường TMĐT C2C:*
   - Đề xuất và hiện thực hóa thành công mô hình sàn giao dịch C2C thế hệ mới, giải quyết triệt để bài toán "khủng hoảng niềm tin" và sự phân mảnh trong giao tiếp truyền thống.

2. *Đóng góp về Kiến trúc Phần mềm và Công nghệ durable execution:*
   - Tiên phong nghiên cứu và triển khai mô hình Durable Microservices trên nền tảng Restate trong một hệ thống thương mại điện tử thực tế tại Việt Nam.

3. *Đóng góp về Sản phẩm Thực tiễn và Tài liệu Quy chuẩn:*
   - Bàn giao một bộ sản phẩm phần mềm hoạt động trọn vẹn, bao gồm: Giao diện người dùng (Nextjs/ Flutter) và Hệ thống Backend Microservices hoàn chỉnh.

