= TỔNG QUAN

== Bối cảnh và Lý do chọn đề tài

Thị trường giao dịch trực tuyến giữa các cá nhân (C2C - Consumer-to-Consumer) tại Việt Nam đang chứng kiến sự tăng trưởng vượt bậc, đặc biệt trong các lĩnh vực mua bán đồ cũ, thanh lý thiết bị điện tử, sách giáo khoa, đồ gia dụng, thời trang và các sản phẩm thủ công (handmade). Sự phổ biến của các mạng xã hội, hội nhóm và diễn đàn trực tuyến đã tạo tiền đề cho những cộng đồng trao đổi hàng hóa sôi động, góp phần thúc đẩy mô hình kinh tế tuần hoàn (Circular Economy) và tiêu dùng bền vững. Tuy nhiên, khi các giao dịch diễn ra tự phát mà không có sự bảo lãnh tài chính và giám sát chuẩn mực, thị trường C2C truyền thống đang phải đối mặt với rào cản lớn nhất là khủng hoảng niềm tin giữa các bên tham gia giao dịch.

Cụ thể, những thách thức cốt lõi đang kìm hãm sự phát triển lành mạnh của hệ sinh thái này bao gồm:
- *Rủi ro từ góc độ Người mua:* Khi tham gia mua sắm hàng thanh lý từ một cá nhân xa lạ, người mua luôn rơi vào tình huống bất lợi nếu phải đặt cọc hoặc thanh toán trước (chuyển khoản trực tiếp qua tài khoản ngân hàng cá nhân). Tình trạng "lừa đảo" (scam) cụ thể là nhận tiền nhưng không giao hàng, hoặc cố tình giao sai sản phẩm, hàng giả, hàng lỗi/hỏng nặng không đúng mô tả diễn ra phổ biến. Khi sự cố xảy ra, người mua gần như không có cơ chế pháp lý hay bên thứ ba nào bảo vệ; người bán cá nhân thường tìm cách từ chối hoàn tiền, chặn liên lạc hoặc xóa tài khoản.
- *Rủi ro từ góc độ Người bán cá nhân:* Để tạo lòng tin cho người mua, nhiều người bán phải chấp nhận hình thức giao hàng thu tiền hộ (COD - Cash on Delivery). Tuy nhiên, giải pháp này lại đẩy rủi ro về phía người bán: tỷ lệ người mua đặt hàng tùy hứng rồi từ chối nhận hàng ("boom hàng") mà không có lý do chính đáng rất cao. Trong trường hợp đó, người bán cá nhân không những phải gánh chịu gấp đôi chi phí vận chuyển hai chiều (chi phí gửi đi và hoàn về) mà sản phẩm còn có nguy cơ bị hư hỏng, thất lạc hoặc suy giảm giá trị trong quá trình luân chuyển đường dài. Nghiêm trọng hơn, một số đối tượng xấu còn lợi dụng việc kiểm hàng để tráo đổi linh kiện chính hãng rồi từ chối nhận.
- *Sự phân mảnh trong giao tiếp và thỏa thuận giao dịch:* Đặc thù của mua bán đồ cũ là nhu cầu thương lượng giá (mặc cả) và kiểm chứng thực tế bằng hình ảnh/video trực tiếp. Hiện nay, quy trình này thường diễn ra phân mảnh trên các ứng dụng nhắn tin bên thứ ba ngoài sàn (như Zalo, Messenger, Telegram). Khi hai bên thống nhất một mức giá ưu đãi (ví dụ: bớt 50.000 VNĐ vì hỗ trợ phí vận chuyển), việc thanh toán trên sàn giao dịch lại không đồng bộ được mức giá thỏa thuận này một cách tự động. Đồng thời, khi tranh chấp xảy ra, các sàn thương mại điện tử (TMĐT) truyền thống không có quyền truy cập hoặc không thể xác thực tính chính xác của các đoạn chat bên ngoài, dẫn đến thiếu chứng cứ lịch sử gắn liền với đơn hàng để phân xử công bằng.

Trước thực trạng và những khoảng trống lớn của thị trường, đề tài *"Ứng dụng thương mại điện tử sử dụng kiến trúc Microservices"* được lựa chọn nhằm nghiên cứu, phân tích và thiết kế một hệ sinh thái giao dịch C2C an toàn, minh bạch và hiện đại, đặt trọng tâm giải quyết bài toán "lòng tin" bằng việc thiết lập ba trụ cột nghiệp vụ và kỹ thuật chính sau:
+ *Cơ chế Bảo lãnh tài chính tạm giữ (Escrow Payment):* Sàn thương mại điện tử sẽ đóng vai trò là bên thứ ba trung gian đáng tin cậy giữ tiền giao dịch. Dòng tiền của người mua sẽ được khóa bảo mật trong ví trung gian cho đến khi giao hàng thành công và người mua xác nhận hài lòng (hoặc hết thời hạn đếm ngược 3 ngày(72 giờ) mà không có khiếu nại).
+ *Tích hợp Nhắn tin trực tuyến và Thẻ Đề xuất giá (Offer Card):* Xây dựng hệ thống giao tiếp gắn liền liền mạch vào sàn, cho phép thương lượng giá động ngay trong khung chat qua Thẻ Đề xuất giá có hiệu lực trong 24 giờ, ràng buộc trực tiếp thỏa thuận giá vào luồng thanh toán đơn hàng.
+ *Quy trình Hoàn tiền và Phân xử tranh chấp (Refund & Dispute) minh bạch:* Thiết lập quy trình khiếu nại với ràng buộc bắt buộc cung cấp bằng chứng số đa phương tiện (video mở hộp, ảnh chụp đóng gói). Khi không đạt được thỏa thuận hoàn tiền, vụ việc được thăng cấp lên Điều phối viên (Moderator) nội bộ để thẩm định và ra quyết định công bằng cho cả hai bên.

== Mục tiêu của nghiên cứu

Mục tiêu tổng quát của nghiên cứu là áp dụng triệt để các phương pháp kỹ thuật phần mềm tiên tiến, đặc biệt là kiến trúc hướng dịch vụ (SOA) và mô hình Microservices hiện đại, để thiết kế và hiện thực hóa một nền tảng TMĐT C2C toàn diện, an toàn và có khả năng chịu tải, mở rộng cao.

Các mục tiêu cụ thể của đề tài được phân chia theo từng phương diện nghiệp vụ và công nghệ cốt lõi:

1. *Xây dựng cơ chế Thanh toán tạm giữ (Escrow) bền vững và luồng tài chính an toàn:*
   - Thiết kế luồng thanh toán tích hợp cổng ngân hàng/ví điện tử ngoại vi (SePay), quản lý dòng tiền theo mô hình ví nội bộ (Internal Wallet).
   - Đảm bảo quy trình khóa tiền tạm giữ (Escrow Held) chính xác trong vòng 3 ngày (72 giờ) kể từ thời điểm đối tác vận chuyển xác nhận giao hàng thành công.
   - Chuẩn hóa cơ chế tính toán phí vận chuyển động và phí sàn (Transaction Fee), cho phép cấu hình linh hoạt bên chịu phí vận chuyển (Người mua hoặc Người bán chịu phí, tự động trừ vào thực nhận hoặc cộng vào hóa đơn).

2. *Tích hợp Nhắn tin trực tuyến thời gian thực và Chuẩn hóa quy trình Đàm phán giá (Offer Card):*
   - Xây dựng module Chat đa phương tiện thời gian thực, cho phép gửi hình ảnh, video thực tế sản phẩm độ phân giải cao giữa người mua và người bán.
   - Đối với sản phẩm đăng bán ở chế độ "Giá thương lượng", cung cấp quy trình đàm phán giá chuẩn hóa thông qua Thẻ Đề xuất giá (Offer Card): người bán phát hành thẻ với mức giá giảm và lý do cụ thể; người mua chấp nhận thẻ để khởi tạo đơn hàng với mức giá đã cam kết, tự động vô hiệu hóa thẻ nếu đơn hàng bị hủy hoặc hết hạn sau 24 giờ.

3. *Thiết lập quy trình Hoàn tiền (Refund), Phân xử tranh chấp (Dispute) và Kiểm duyệt nội dung:*
   - Xây dựng luồng xử lý khiếu nại trong hạn 3 ngày với ràng buộc cung cấp bằng chứng số (ảnh/video mở hộp hàng hóa).
   - Cung cấp cơ chế phản bác cho người bán (được phản hồi trong 48 giờ) và quy trình thăng cấp thành vụ Tranh chấp (Dispute) để Điều phối viên (Moderator) can thiệp thẩm định bằng chứng, ra quyết định hoàn tiền (Refund to Buyer) hoặc giải ngân (Release to Seller).
   - Xây dựng quy trình Kiểm duyệt nội dung (Content Moderation): tiếp nhận báo cáo từ người dùng và quy trình xử lý bài đăng khả nghi (hàng cấm, vi phạm pháp luật) của Moderator.

4. *Thiết lập mô hình Phân quyền chặt chẽ theo 3 vai trò (Persona) hệ thống:*
   - *Người dùng (User):* Tài khoản khách hàng tự do đăng ký, sở hữu vai trò kép (vừa mua vừa bán trên cùng một định danh).
   - *Điều phối viên (Moderator):* Tài khoản nội bộ do Quản trị viên cấp phát, chịu trách nhiệm thẩm định khiếu nại, phân xử tranh chấp và kiểm duyệt bài đăng vi phạm.
   - *Quản trị viên tối cao (Super Admin):* Tài khoản duy nhất cấu hình sẵn, có thẩm quyền thiết lập tham số hệ thống, kiểm soát dòng tiền tổng thể và quản lý nhân sự Moderator.

5. *Nghiên cứu ứng dụng kiến trúc Durable Microservices:*
   - Phân rã hệ thống thành các dịch vụ độc lập áp dụng triệt để nguyên lý *Database-per-service*, bảo đảm sự cô lập về cơ sở dữ liệu và khả năng chọn lựa công nghệ lưu trữ phù hợp (Polyglot Persistence).
   - Ứng dụng cơ chế Thực thi Bền vững *Restate* (Journal-based Durable Execution) để quản lý các luồng nghiệp vụ dài hạn (Escrow, Refund, Dispute,...), loại bỏ hoàn toàn độ phức tạp của mẫu thiết kế Saga truyền thống, tự động phục hồi lỗi (Crash Recovery) và bảo đảm ngữ nghĩa thực thi chính xác một lần (Exact-once semantics).

6. *Nghiên cứu tìm kiếm dựa trên từ khóa và ngữ nghĩa:*
   - Nghiên cứu và tích hợp cơ chế Tìm kiếm Ngữ nghĩa Lai (Hybrid Search), kết hợp giữa Tìm kiếm văn bản (Full-text Search) dựa trên từ khóa và tìm kiếm ngữ nghĩa (Semantic Vector Search) thông qua cơ sở dữ liệu pgvector trên PostgreSQL, sử dụng mô hình embedding đa ngôn ngữ bge-m3 để sinh biểu diễn vector (vector embeddings) cho dữ liệu văn bản.
   - Nâng cao độ chính xác và khả năng truy xuất sản phẩm từ các mô tả tự do, viết tắt, từ lóng hoặc thiếu từ khóa chuẩn của người bán cá nhân.

7. *Nghiên cứu hệ thống gợi ý sản phẩm (Recommender System):*
    - Xây dựng cơ chế gợi ý sản phẩm cá nhân hóa đa hướng quan tâm (multi-interest), biểu diễn sở thích người dùng qua nhiều vector đặc trưng được cập nhật liên tục dựa trên lịch sử tương tác, hành vi tìm kiếm và độ tương đồng ngữ nghĩa của mặt hàng.
    - Kết hợp điểm uy tín của người bán và mức độ phổ biến sản phẩm để đưa ra các gợi ý phù hợp, giúp tối ưu trải nghiệm mua sắm và tăng tỷ lệ chuyển đổi đơn hàng.

== Phạm vi hệ thống

=== Trong phạm vi nghiên cứu (In-Scope)

Hệ thống được thiết kế bao phủ toàn bộ vòng đời giao dịch thương mại điện tử giữa các cá nhân (C2C), bao gồm 8 phân hệ chức năng và nghiệp vụ cốt lõi sau:

1. *Quản lý tài khoản, Phân quyền (RBAC) và Ví điện tử:*
   - Hỗ trợ đăng ký, đăng nhập bảo mật (JWT), xác thực tài khoản và quản lý thông tin hồ sơ người dùng.
   - Cấu hình phân định ranh giới chức năng rõ ràng cho 3 vai trò: *User* (quyền kép mua/bán, sở hữu ví cá nhân), *Moderator* (nội bộ, thẩm định và CSKH), *Super Admin* (quản trị toàn cục).
   - Quản lý số dư ví điện tử nội bộ, nạp tiền và theo dõi lịch sử biến động số dư (Transaction Ledger).

2. *Quản lý danh mục và Đăng bán sản phẩm C2C:*
   - Cho phép người bán đăng tải sản phẩm thanh lý với thông tin chi tiết: tên, mô tả, hình ảnh/video đa phương tiện, phân loại tình trạng (Mới, Gần như mới, Tốt, Cũ).
   - Cung cấp tùy chọn 2 chế độ bán: *Giá cố định* (niêm yết cứng, mua ngay không trả giá) hoặc *Giá thương lượng* (mở ra luồng đàm phán qua Chat).
   - Cấu hình linh hoạt bên chịu phí vận chuyển: Người mua trả phí hoặc Người bán hỗ trợ chi trả phí vận chuyển.

3. *Tìm kiếm thông minh và Gợi ý sản phẩm:*
   - Cung cấp công cụ tìm kiếm kết hợp giữa tìm kiếm từ khóa đầy đủ (Full-text Search) và tìm kiếm vector ngữ nghĩa (Semantic Search dựa trên pgvector và mô hình bge-m3).
   - Hỗ trợ bộ lọc đa chiều theo khoảng giá, khu vực địa lý, tình trạng sản phẩm và điểm đánh giá độ uy tín của người bán.

4. *Hệ thống Chat trực tuyến và Thương lượng giá (Offer Card):*
   - Kênh giao tiếp tin nhắn văn bản và chia sẻ phương tiện thời gian thực giữa người mua và người bán.
   - Luồng nghiệp vụ Thẻ Đề xuất giá (Offer Card): khởi tạo, gửi, chấp nhận hoặc từ chối đề xuất giá; tự động ràng buộc giá thỏa thuận vào phiên thanh toán đơn hàng.

5. *Đặt hàng, Tính phí vận chuyển động và Thanh toán (Escrow):*
   - Quy trình khởi tạo đơn hàng từ trang chi tiết sản phẩm (giá cố định) hoặc từ Offer Card trong Chat (giá thương lượng).
   - Tích hợp (hoặc giả lập/mocking chuẩn hóa) API đối tác vận chuyển (GHN, GHTK) để tính toán phí vận chuyển động theo khoảng cách địa lý và khối lượng kiện hàng.
   - Tích hợp cổng thanh toán ngân hàng (SePay), thực hiện thanh toán an toàn và chuyển trạng thái dòng tiền vào ví tạm giữ (Escrow Held).

6. *Xác nhận giao hàng và Bộ đếm thời gian tạm giữ:*
   - Lắng nghe sự kiện cập nhật hành trình vận đơn từ đơn vị giao nhận; tự động kích hoạt bộ đếm thời gian đếm ngược 3 ngày (72 giờ) khi đơn hàng chuyển sang trạng thái "Giao hàng thành công".
   - Cho phép người mua chủ động xác nhận "Đã nhận hàng" để chấm dứt sớm bộ đếm thời gian, ngay lập tức giải ngân cho người bán.
   - Xử lý tự động giải ngân (Release Escrow) sau khi hết hạn 72 giờ nếu không có khiếu nại phát sinh.

7. *Khiếu nại Hoàn tiền (Refund), Tranh chấp (Dispute) và Phân xử:*
   - Quy trình gửi yêu cầu Refund/Return trong khung thời gian 72 giờ kèm việc tải lên bằng chứng số đa phương tiện bắt buộc.
   - Cơ chế tương tác phản hồi giữa hai bên trong hạn 48 giờ; tự động khóa đơn hàng và nâng cấp thành vụ Tranh chấp (Dispute) khi xảy ra bất đồng.
   - Giao diện thẩm định dành riêng cho Điều phối viên (Moderator): đối chiếu chứng cứ mở hộp/đóng gói, ra quyết định cuối cùng về việc phân bổ dòng tiền.

8. *Kiểm duyệt Nội dung và Báo cáo vi phạm (Content Moderation):*
   - Nghiên cứu và xây dựng cơ chế kiểm duyệt nội dung nhằm phát hiện các bài đăng có dấu hiệu vi phạm (lừa đảo, hàng giả, hàng cấm...).
   - Xây dựng quy trình xử lý vi phạm, bao gồm việc tạm ẩn, thẩm định và xử phạt/khóa tài khoản đối với các trường hợp vi phạm được xác nhận.

=== Ngoài phạm vi nghiên cứu (Out-of-Scope)

Để đảm bảo tính khả thi, độ tập trung chuyên sâu vào mô hình kiến trúc Microservices và trọn vẹn luồng giao dịch C2C cá nhân, các hạng mục sau được xác định nằm ngoài phạm vi nghiên cứu của đề tài:

1. *Gian hàng doanh nghiệp chính hãng (B2C / Shop Mall):* Hệ thống hiện tại chỉ thiết kế tối ưu cho giao dịch cá nhân bán cho cá nhân (C2C). Việc phát triển các gian hàng thương hiệu chính hãng quy mô lớn từ các doanh nghiệp (với quy trình hóa đơn đỏ, quản lý kho hàng nghìn SKUs phức tạp) là định hướng mở rộng trong tương lai.
2. *Giao dịch và vận chuyển quốc tế:* Đề tài chỉ tập trung vào thị trường nội địa Việt Nam; không xử lý các luồng thanh toán đa ngoại tệ, chuyển đổi tỷ giá, thủ tục hải quan hay tích hợp các đơn vị vận chuyển xuyên biên giới.
3. *Gọi thoại và gọi video trực tiếp (Voice/Video Call):* Không triển khai tính năng gọi điện thoại hay gọi video trực tiếp trên nền tảng web/mobi qua WebRTC. Toàn bộ quá trình đàm phán, trao đổi và làm bằng chứng được thực hiện bằng tin nhắn văn bản, hình ảnh và video quay sẵn tải lên khung chat.
4. *Đăng ký công khai cho vai trò Moderator và Super Admin:* Các tài khoản quản trị viên và điều phối viên là tài khoản nội bộ có thẩm quyền cao, được kiểm soát và khởi tạo theo quy trình quản trị tập trung, không cung cấp biểu mẫu đăng ký tự do công khai ra bên ngoài.
5. *Tự động kết nối pháp lý và báo cáo cơ quan chức năng:* Đối với các trường hợp phát hiện bài đăng buôn bán hàng hóa cấm, vi phạm pháp luật nghiêm trọng, phạm vi hệ thống chỉ dừng lại ở việc gỡ bỏ bài đăng, đóng băng ví/tài khoản người dùng và lưu vết nhật ký kiểm toán (Audit Trail). Việc trình báo, phối hợp xử lý pháp lý với các cơ quan chức năng (Công an, Quản lý thị trường) được thực hiện thủ công ngoài hệ thống bởi Ban quản trị sàn.

== Phương pháp nghiên cứu

Để giải quyết thành công các bài toán phức tạp về nghiệp vụ và kiến trúc kỹ thuật đã đặt ra, đề tài kết hợp sử dụng bốn nhóm phương pháp nghiên cứu khoa học kỹ thuật phần mềm hiện đại:

1. *Phương pháp Phân tích và Thiết kế Hướng đối tượng (OOAD) & Thiết kế Hướng miền (Domain-Driven Design — DDD):*
   - Triển khai phân rã bài toán thương mại điện tử thành các miền con nghiệp vụ (Subdomains) và xác định rõ Ranh giới ngữ cảnh (Bounded Contexts) cho từng module: `Account Context`, `Catalog Context`, `Order Context`, `Inventory Context`, `Chat Context`, và `Analytic Context`.
   - Sử dụng ngôn ngữ mô hình hóa thống nhất (UML) để chuẩn hóa tài liệu thiết kế: Biểu đồ ca sử dụng (Use Case Diagram), Biểu đồ hoạt động (Activity Diagram), Biểu đồ trình tự (Sequence Diagram), Biểu đồ lớp (Class Diagram) và Biểu đồ thực thể - quan hệ (ERD).

2. *Phương pháp Kiến trúc Hướng dịch vụ (SOA) và mô hình Microservices:*
   - Áp dụng mẫu thiết kế *Database-per-service*, đảm bảo mỗi dịch vụ microservice sở hữu cấu trúc lưu trữ và cơ sở dữ liệu riêng biệt. Triệt tiêu hiện tượng nghẽn cổ chai CSDL tập trung và ngăn chặn truy cập dữ liệu chéo trái phép.
   - Thiết lập mô hình giao tiếp liên dịch vụ lai (Hybrid Communication): kết hợp gọi hàm từ xa đồng bộ tốc độ cao (HTTP/2 RPC) cho các tác vụ truy vấn dữ liệu tức thời, và giao tiếp bất đồng bộ dựa trên sự kiện (Event-Driven Architecture thông qua NATS JetStream) cho các luồng cập nhật trạng thái hậu kỳ, gửi thông báo thời gian thực (SSE) và phân tích dữ liệu.

3. *Phương pháp Thực thi Bền vững (Durable Execution):*
   - Nghiên cứu và áp dụng nền tảng thực thi bền vững *Restate* dựa trên triết lý *Journal-based Execution* (thực thi dựa trên nhật ký ghi trước - Write-Ahead Log).
   - Thay thế mẫu thiết kế Saga truyền thống trong các luồng giao dịch tài chính phân tán (Escrow, Refund, Dispute). Phương pháp này cho phép hệ thống tự động ghi nhận mọi tương tác I/O; khi xảy ra sự cố sập nguồn hay mất mạng (Crash), tiến trình sẽ tự động phát lại (replay) từ nhật ký và tiếp tục chạy tiếp từ điểm dừng mà không bị lặp lại tác vụ mutation hay cần viết các hàm bù trừ (Compensation) thủ công.

4. *Phương pháp Quản lý Quyết định Kiến trúc (ADR — Architectural Decision Records):*
   - Áp dụng quy trình ra quyết định kỹ thuật có ghi nhận minh bạch theo chuẩn ADR. Mọi quyết định lựa chọn stack công nghệ quan trọng (ví dụ: Next.js/Flutter cho UI, Go/NestJS cho Backend, Restate cho điều phối, NATS cho Event Bus, pgvector cho tìm kiếm) đều được lập hồ sơ chi tiết bao gồm: bối cảnh thực trạng, các giải pháp thay thế đã đánh giá, lý do chốt phương án và phân tích các sự đánh đổi (Trade-offs).

== Đóng góp của đề tài

Đề tài nghiên cứu và xây dựng nền tảng ShopNexus mang lại bốn đóng góp quan trọng trên cả phương diện lý luận, công nghệ và giá trị ứng dụng thực tiễn:

1. *Đóng góp về Giải pháp Nghiệp vụ cho thị trường TMĐT C2C:*
   - Đề xuất và hiện thực hóa thành công mô hình sàn giao dịch C2C thế hệ mới, giải quyết triệt để bài toán "khủng hoảng niềm tin" và sự phân mảnh trong giao tiếp truyền thống.
   - Thiết lập mô hình kết hợp hoàn hảo giữa ba yếu tố: Ví bảo lãnh tài chính tạm giữ 72 giờ (Escrow), Thẻ thương lượng giá trong Chat (Offer Card), và Quy trình phân xử tranh chấp dựa trên chứng cứ đa phương tiện (Dispute Moderation).

2. *Đóng góp về Kiến trúc Phần mềm và Công nghệ Thực thi Bền vững:*
   - Tiên phong nghiên cứu và triển khai mô hình *Durable Microservices trên nền tảng Restate* trong một hệ thống thương mại điện tử thực tế tại Việt Nam.
   - Đề xuất giải pháp kiến trúc thay thế cho mẫu thiết kế Saga/Orchestration truyền thống, giúp giảm thiểu lượng mã nguồn xử lý lỗi và hàm bù trừ (compensating actions) thủ công, đồng thời góp phần nâng cao độ tin cậy và khả năng chống chịu lỗi (Fault Tolerance) của hệ thống phân tán.

3. *Đóng góp về Sản phẩm Thực tiễn và Tài liệu Quy chuẩn:*
   - Bàn giao một bộ sản phẩm phần mềm hoạt động trọn vẹn, bao gồm: Giao diện web người dùng (Next.js), Giao diện quản trị viên/điều phối viên, Hệ thống Backend Microservices hoàn chỉnh cùng bộ cấu hình triển khai tự động (Docker, Kubernetes).
   - Cung cấp hệ thống tài liệu nghiên cứu học thuật chuẩn mực, được mô hình hóa chi tiết từ yêu cầu nghiệp vụ đến thiết kế hệ thống và hồ sơ quyết định kiến trúc (ADRs), có giá trị tham khảo tốt cho các dự án phát triển phần mềm quy mô lớn.

== Bố cục báo cáo

Báo cáo định kỳ thực tập tốt nghiệp đại học (Lần 1) được bố cục chặt chẽ thành 3 chương nội dung chính, thể hiện tiến trình từ khảo sát bài toán, xây dựng nền tảng lý thuyết đến phân tích yêu cầu và thiết kế hệ thống tổng thể:

- *Chương 1: Tổng quan:* Trình bày bối cảnh thực tế của thị trường TMĐT C2C và những thách thức về niềm tin giao dịch; xác định lý do chọn đề tài, mục tiêu nghiên cứu, phạm vi hệ thống (các chức năng thuộc trong và ngoài phạm vi); phương pháp nghiên cứu áp dụng; các đóng góp chính của đề tài và bố cục của tài liệu báo cáo.
- *Chương 2: Cơ sở lý thuyết:* Trang bị nền tảng lý luận chuyên sâu làm chỗ dựa kỹ thuật cho toàn bộ dự án, bao gồm: Nguyên lý Kiến trúc Hướng dịch vụ (SOA), mô hình Microservices và triết lý Database-per-service; Lý thuyết về Thực thi bền vững (Durable Execution) và cơ chế Journal-based của nền tảng Restate; Các mô hình giao tiếp liên dịch vụ (HTTP/2 RPC và Event-Driven với NATS JetStream); cùng Lý thuyết về nhúng ngữ nghĩa vector và cơ sở dữ liệu vector (pgvector, bge-m3).
- *Chương 3: Phân tích yêu cầu và thiết kế hệ thống:* Trình bày chi tiết phân tích các tác nhân (User, Moderator, Super Admin) và Sơ đồ ngữ cảnh hệ thống (System Context Diagram); Đặc tả danh mục 13 ca sử dụng cốt lõi (Use Case Portfolio) của sàn ShopNexus cùng toàn bộ bộ Quy tắc nghiệp vụ (Business Rules) trọng yếu ràng buộc sự vận hành của nền tảng.

== Tiểu kết chương

Chương 1 đã trình bày tổng quan về hiện trạng thị trường thương mại điện tử C2C tại Việt Nam, trong đó vấn đề niềm tin giữa người mua và người bán được xác định là rào cản chính đối với sự phát triển của mô hình này. Trên cơ sở phân tích các vấn đề tồn tại, rủi ro lừa đảo, tình trạng bùng hàng khi thanh toán COD, và sự phân mảnh trong giao tiếp giữa các bên, đề tài đã xác định mục tiêu và phạm vi nghiên cứu cho hệ thống Thương mại điện tử C2C này.

Phạm vi nghiên cứu được xây dựng dựa trên sự kết hợp giữa các giải pháp nghiệp vụ (ví ký quỹ tạm giữ trong 72 giờ, thẻ đề nghị giao dịch Offer Card, cơ chế phân xử tranh chấp dựa trên bằng chứng số) và các phương pháp kỹ thuật được lựa chọn. Đây là nền tảng để triển khai các nội dung tiếp theo: hệ thống hóa cơ sở lý thuyết liên quan ở Chương 2, và tiến hành phân tích yêu cầu, thiết kế hệ thống ở Chương 3.