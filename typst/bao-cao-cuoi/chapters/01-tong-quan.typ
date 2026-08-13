= TỔNG QUAN

== Bối cảnh và Lý do chọn đề tài

Thị trường giao dịch trực tuyến giữa các cá nhân (C2C - Consumer-to-Consumer) tại Việt Nam đang chứng kiến sự tăng trưởng vượt bậc, đặc biệt trong các lĩnh vực mua bán đồ cũ, thanh lý thiết bị điện tử, sách giáo khoa, đồ gia dụng, thời trang và các sản phẩm thủ công (handmade). Tuy nhiên, khi các giao dịch diễn ra tự phát mà không có sự bảo lãnh tài chính và giám sát chuẩn mực, thị trường C2C truyền thống đang phải đối mặt với rào cản lớn nhất là khủng hoảng niềm tin giữa các bên tham gia giao dịch.

Khi nghiên cứu kĩ vào từng vai trò tham gia giao dịch cũng như cách hai bên trao đổi và thống nhất với nhau, có thể thấy những thách thức cốt lõi đang kìm hãm sự phát triển lành mạnh của hệ sinh thái này tập trung ở 3 nhóm sau:
- *Rủi ro từ phía Người mua:* Khi phải đặt cọc hoặc thanh toán trước cho người bán cá nhân, người mua có nguy cơ bị lừa đảo như không giao hàng, giao sai sản phẩm, hàng giả hoặc hàng không đúng mô tả. Khi sự cố xảy ra, việc đòi hoàn tiền và bảo vệ quyền lợi thường gặp nhiều khó khăn do thiếu cơ chế trung gian xử lý.

- *Rủi ro từ phía Người bán:* Hình thức COD giúp tăng niềm tin cho người mua nhưng lại khiến người bán đối mặt với tình trạng từ chối nhận hàng, phát sinh chi phí vận chuyển hai chiều và nguy cơ sản phẩm bị hư hỏng, thất lạc hoặc tráo đổi trong quá trình giao nhận.

- *Sự phân mảnh trong giao tiếp và thỏa thuận:* Quá trình thương lượng giá, trao đổi hình ảnh và xác nhận thông tin thường diễn ra trên các ứng dụng bên ngoài nền tảng. Điều này làm cho giá đã thỏa thuận khó đồng bộ với đơn hàng, đồng thời khiến lịch sử trao đổi khó được xác minh và sử dụng làm bằng chứng khi phát sinh tranh chấp.

Xét trên phương diện tổng thể, thương mại điện tử Việt Nam liên tục duy trì tốc độ tăng trưởng hai con số, song phần lớn các nền tảng rao vặt C2C hiện hữu như Chợ Tốt vẫn chủ yếu đóng vai trò kết nối thông tin, để hai bên tự thỏa thuận và tự chuyển tiền cho nhau mà không có cơ chế bảo lãnh dòng tiền tập trung. Về mặt pháp lý, hoạt động của các sàn giao dịch thương mại điện tử tại Việt Nam vừa bước sang một khung mới: Luật Thương mại điện tử số 122/2025/QH15 được Quốc hội thông qua ngày 10 tháng 12 năm 2025 và có hiệu lực từ ngày 1 tháng 7 năm 2026, thay cho cách điều chỉnh bằng nghị định trước đây. Luật xác lập trách nhiệm của nền tảng thương mại điện tử trong việc định danh và quản lý thông tin người bán, tiếp nhận và xử lý khiếu nại, đồng thời quy định trách nhiệm liên đới khi người tiêu dùng bị thiệt hại. Bổ trợ cho khung này, quyền được thông tin, được bảo vệ và được giải quyết tranh chấp của người mua được ghi nhận trong Luật Bảo vệ quyền lợi người tiêu dùng số 19/2023/QH15, hiệu lực từ ngày 1 tháng 7 năm 2024 [1] [2].

Trước thực trạng và những khoảng trống lớn của thị trường, đề tài này được thực hiện nhằm nghiên cứu, phân tích và thiết kế một hệ sinh thái giao dịch C2C an toàn, minh bạch và hiện đại, đặt trọng tâm giải quyết bài toán "lòng tin" thông qua ba nhóm giải pháp cốt lõi sau:
+ *Cơ chế ký quỹ (escrow):* Sàn thương mại điện tử đóng vai trò bên thứ ba trung gian đáng tin cậy giữ tiền giao dịch. Dòng tiền của người mua được khóa bảo mật trong ví ký quỹ cho đến khi giao hàng thành công và người mua xác nhận hài lòng (hoặc hết thời hạn đếm ngược 3 ngày (72 giờ) mà không có khiếu nại).
+ *Tích hợp Nhắn tin trực tuyến và Thẻ Đề xuất giá (Offer Card):* Xây dựng hệ thống giao tiếp gắn liền mạch vào sàn, cho phép thương lượng giá động ngay trong khung chat qua Thẻ Đề xuất giá có hiệu lực trong 12 giờ, ràng buộc trực tiếp thỏa thuận giá vào luồng thanh toán đơn hàng.
+ *Quy trình Hoàn tiền và Phân xử tranh chấp (Refund & Dispute) minh bạch:* Thiết lập quy trình khiếu nại với ràng buộc bắt buộc cung cấp bằng chứng số đa phương tiện (video mở hộp, ảnh chụp đóng gói). Khi không đạt được thỏa thuận hoàn tiền, vụ việc được thăng cấp lên Điều phối viên (Moderator) nội bộ để thẩm định và ra quyết định công bằng cho cả 2 bên.

== Mục tiêu của nghiên cứu

Mục tiêu tổng quát của nghiên cứu là áp dụng triệt để các phương pháp kỹ thuật phần mềm tiên tiến, đặc biệt là kiến trúc hướng dịch vụ (SOA) và mô hình Microservices hiện đại, để thiết kế và hiện thực hóa một nền tảng TMĐT C2C toàn diện, an toàn và có khả năng chịu tải, mở rộng cao [9]. Các mục tiêu cụ thể được phân chia theo từng phương diện nghiệp vụ và công nghệ cốt lõi:

1. *Xây dựng cơ chế ký quỹ bền vững và luồng tài chính an toàn:* Thiết kế luồng thanh toán tích hợp cổng ngân hàng/ví điện tử ngoại vi, quản lý dòng tiền theo mô hình ví nội bộ (Internal Wallet).

2. *Tích hợp Nhắn tin trực tuyến thời gian thực và Chuẩn hóa quy trình Đàm phán giá (Offer Card):* Xây dựng module Chat đa phương tiện thời gian thực, cho phép gửi hình ảnh và video thực tế của sản phẩm giữa người mua và người bán.

3. *Thiết lập quy trình Hoàn tiền (Refund), Phân xử tranh chấp (Dispute) và Kiểm duyệt nội dung:* Xây dựng luồng xử lý khiếu nại trong hạn 3 ngày với ràng buộc cung cấp bằng chứng số (ảnh/video mở hộp hàng hóa).

4. *Thiết lập mô hình Phân quyền chặt chẽ theo 3 vai trò (Persona) hệ thống:* Người dùng (User) là tài khoản tự do đăng ký, sở hữu vai trò kép (vừa mua vừa bán trên cùng một định danh); Điều phối viên (Moderator) là tài khoản nội bộ do Quản trị viên cấp phát, chịu trách nhiệm thẩm định khiếu nại, phân xử tranh chấp và kiểm duyệt tin đăng vi phạm; Quản trị viên tối cao (Super Admin) là tài khoản duy nhất cấu hình sẵn, có thẩm quyền thiết lập tham số hệ thống, kiểm soát dòng tiền tổng thể và quản lý nhân sự điều phối viên.

5. *Nghiên cứu ứng dụng kiến trúc Durable Microservices:* Phân rã hệ thống thành các dịch vụ độc lập áp dụng triệt để nguyên lý Database-per-service [10], bảo đảm sự cô lập về cơ sở dữ liệu và khả năng chọn lựa công nghệ lưu trữ phù hợp (Polyglot Persistence); đồng thời ứng dụng cơ chế durable execution (thực thi bền) Restate (Journal-based Durable Execution) để quản lý các luồng nghiệp vụ dài hạn (ký quỹ, hoàn tiền, tranh chấp,...), loại bỏ hoàn toàn độ phức tạp của mẫu thiết kế Saga truyền thống [5], tự động phục hồi lỗi (Crash Recovery) và bảo đảm ngữ nghĩa thực thi chính xác một lần (Exact-once semantics).

6. *Nghiên cứu tìm kiếm dựa trên từ khóa và ngữ nghĩa:* Nghiên cứu và tích hợp cơ chế Tìm kiếm Ngữ nghĩa Lai (Hybrid Search), kết hợp giữa Tìm kiếm văn bản (Full-text Search) dựa trên từ khóa và tìm kiếm ngữ nghĩa (Semantic Vector Search) thông qua cơ sở dữ liệu pgvector trên PostgreSQL [11], sử dụng mô hình embedding đa ngôn ngữ bge-m3 để sinh biểu diễn vector (vector embeddings) cho dữ liệu văn bản [4].

7. *Nghiên cứu hệ thống gợi ý sản phẩm (Recommender System):* Xây dựng cơ chế gợi ý sản phẩm cá nhân hóa đa hướng quan tâm (multi-interest), biểu diễn sở thích người dùng qua nhiều vector đặc trưng được cập nhật liên tục dựa trên lịch sử tương tác, hành vi tìm kiếm và độ tương đồng ngữ nghĩa của mặt hàng [8].

== Phạm vi hệ thống

=== Trong phạm vi nghiên cứu (In-Scope)

Hệ thống được thiết kế bao phủ toàn bộ vòng đời giao dịch thương mại điện tử giữa các cá nhân (C2C), bao gồm các phân hệ chức năng và nghiệp vụ cốt lõi sau:

1. *Quản lý tài khoản, Phân quyền (RBAC) và Ví nội bộ:* Hỗ trợ đăng ký, đăng nhập bảo mật (JWT), xác thực tài khoản và quản lý thông tin hồ sơ người dùng.

2. *Quản lý danh mục và Đăng bán sản phẩm C2C:* Cho phép người bán đăng tải sản phẩm thanh lý với thông tin chi tiết: tên, mô tả, hình ảnh/video đa phương tiện, phân loại tình trạng (Mới, Cũ, Bị hư hại một phần).

3. *Tìm kiếm thông minh và Gợi ý sản phẩm:* Cung cấp công cụ tìm kiếm kết hợp giữa tìm kiếm từ khóa đầy đủ (Full-text Search) và tìm kiếm vector ngữ nghĩa (Semantic Search dựa trên pgvector và mô hình bge-m3).

4. *Hệ thống Chat trực tuyến và Thương lượng giá (Offer Card):* Kênh giao tiếp tin nhắn văn bản và chia sẻ phương tiện thời gian thực giữa người mua và người bán.

5. *Đặt hàng, Tính phí vận chuyển động và Ký quỹ:* Quy trình khởi tạo đơn hàng từ trang chi tiết sản phẩm (giá cố định) hoặc từ Offer Card trong Chat (giá thương lượng).

6. *Xác nhận giao hàng và Bộ đếm thời gian tạm giữ:* Lắng nghe sự kiện cập nhật hành trình vận đơn từ đơn vị giao nhận; tự động kích hoạt bộ đếm thời gian đếm ngược 3 ngày (72 giờ) khi đơn hàng chuyển sang trạng thái "Giao hàng thành công".

7. *Khiếu nại Hoàn tiền (Refund), Tranh chấp (Dispute) và Phân xử:* Quy trình gửi yêu cầu Refund/Return trong khung thời gian 72 giờ kèm việc tải lên bằng chứng số đa phương tiện bắt buộc.

8. *Kiểm duyệt Nội dung và Báo cáo vi phạm (Content Moderation):* Nghiên cứu và xây dựng cơ chế kiểm duyệt nội dung nhằm phát hiện các tin đăng có dấu hiệu vi phạm (lừa đảo, hàng giả, hàng cấm...).

=== Ngoài phạm vi nghiên cứu (Out-of-Scope)

Để đảm bảo tính khả thi và độ tập trung chuyên sâu vào mô hình kiến trúc Microservices cùng trọn vẹn luồng giao dịch C2C cá nhân, các hạng mục sau nằm ngoài phạm vi nghiên cứu của đề tài:

1. *Gian hàng doanh nghiệp chính hãng (B2C / Shop Mall):* Hệ thống chỉ thiết kế tối ưu cho giao dịch cá nhân bán cho cá nhân (C2C). Việc phát triển các gian hàng thương hiệu chính hãng quy mô lớn (với quy trình hóa đơn đỏ, quản lý kho hàng nghìn SKUs phức tạp) là định hướng mở rộng trong tương lai.
2. *Giao dịch và vận chuyển quốc tế:* Đề tài chỉ tập trung vào thị trường nội địa Việt Nam; không xử lý các luồng thanh toán đa ngoại tệ, chuyển đổi tỷ giá, thủ tục hải quan hay tích hợp các đơn vị vận chuyển xuyên biên giới.
3. *Chương trình khuyến mãi và mã giảm giá:* Đề tài không xây dựng công cụ cho người bán tạo đợt giảm giá, phát hành mã giảm giá hay các chương trình khuyến mại của sàn. Cơ chế điều chỉnh giá trong phạm vi đề tài chỉ diễn ra theo từng giao dịch, thông qua Thẻ Đề xuất giá trong khung trò chuyện giữa hai bên, vì đây mới là hình thức mặc cả đặc trưng của thị trường mua bán đồ cũ giữa các cá nhân.
4. *Gọi thoại và gọi video trực tiếp (Voice/Video Call):* Không triển khai tính năng gọi điện thoại hay gọi video trực tiếp qua WebRTC. Toàn bộ quá trình đàm phán, trao đổi và làm bằng chứng được thực hiện bằng tin nhắn văn bản, hình ảnh và video quay sẵn tải lên khung chat.

== Phương pháp nghiên cứu

Đề tài kết hợp 3 phương pháp sau:

1. *Phân tích và thiết kế hướng đối tượng (OOAD):* Dùng ngôn ngữ mô hình hóa thống nhất (UML) để chuẩn hóa tài liệu thiết kế, gồm biểu đồ ca sử dụng, hoạt động, trình tự, lớp và thực thể quan hệ.

2. *Kiến trúc hướng dịch vụ (SOA) và Microservices:* Áp dụng mẫu Database-per-service, mỗi dịch vụ sở hữu cơ sở dữ liệu riêng, nhờ đó không còn nghẽn cổ chai ở một CSDL tập trung và không thể truy cập dữ liệu chéo.

3. *Phương pháp durable execution:* Nghiên cứu và áp dụng nền tảng durable execution Restate dựa trên triết lý Journal-based Execution (thực thi dựa trên nhật ký ghi trước - Write-Ahead Log) [12].

== Đóng góp của đề tài

Đề tài mang lại 3 đóng góp. Về giải pháp nghiệp vụ, đề tài đề xuất và hiện thực hóa mô hình sàn C2C giải quyết bài toán khủng hoảng niềm tin và sự phân mảnh trong giao tiếp. Về kiến trúc phần mềm, đề tài triển khai mô hình Durable Microservices trên nền tảng Restate trong một hệ thống thương mại điện tử thực tế. Về sản phẩm, đề tài bàn giao bộ phần mềm chạy được trọn vẹn gồm ứng dụng web, ứng dụng di động và hệ thống dịch vụ nền.
