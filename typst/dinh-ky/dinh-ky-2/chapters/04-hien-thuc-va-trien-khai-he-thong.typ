#import "../../../common/tokens.typ": *

#let anh-web(cap, tep, rong: 100%) = figure(
  box(stroke: 0.6pt + hairline, image("../../../common/assets/web/" + tep, width: rong)),
  caption: cap,
  kind: image,
)

#let anh-mobile(cap, tep, nhan: (), cao: 9.2cm) = figure(
  align(center, stack(
    dir: ltr, spacing: 7mm,
    ..tep.enumerate().map(((i, t)) => stack(
      spacing: 4pt,
      image("../../../common/assets/mobile/" + t, height: cao),
      text(size: 8pt, fill: muted, {
        "(" + str.from-unicode(97 + i) + ")"
        if i < nhan.len() { " " + nhan.at(i) }
      }),
    )),
  )),
  caption: cap,
  kind: image,
)

= HIỆN THỰC VÀ TRIỂN KHAI HỆ THỐNG

== Môi trường và công nghệ hiện thực

=== Hạ tầng dịch vụ nền và cơ sở dữ liệu

Dịch vụ nền của hệ thống được phát triển bằng ngôn ngữ Go (Golang), phân rã thành các phân hệ độc lập tương ứng với thiết kế nghiệp vụ ở Chương 3. Việc sử dụng Go mang lại ưu thế vượt trội về hiệu năng xử lý đồng thời thông qua cơ chế Goroutine, thời gian khởi động nhanh và tiêu tốn ít bộ nhớ.

Toàn bộ dữ liệu nghiệp vụ được quản lý tập trung trên hệ quản trị cơ sở dữ liệu quan hệ PostgreSQL phiên bản 18, kết hợp với hai tiện ích mở rộng chuyên sâu:
- ParadeDB (`pg_search`): Tích hợp trực tiếp công cụ tìm kiếm toàn văn vào cơ sở dữ liệu, cho phép truy vấn từ khóa theo mô hình xác suất BM25 tối ưu với độ trễ thấp.
- `pgvector` [17]: Cung cấp kiểu dữ liệu vector và cấu trúc chỉ mục đồ thị phân tầng HNSW (Hierarchical Navigable Small World), phục vụ tác vụ tìm kiếm tương đồng vector trong không gian đa chiều.

Các tệp tin đa phương tiện bao gồm ảnh món hàng và video quay thực tế được lưu trữ trên hệ thống kho lưu trữ đối tượng (Object Storage tương thích chuẩn S3), tách biệt hoàn toàn khỏi cơ sở dữ liệu quan hệ nhằm bảo đảm hiệu năng truy xuất và khả năng mở rộng dung lượng linh hoạt.

=== Dịch vụ điều phối thực thi bền bỉ

Đối với các quy trình nghiệp vụ nhiều bước phức tạp và có trạng thái kéo dài như xác thực đăng nhập, pipeline xử lý kiểm duyệt ảnh, chuỗi nghiệp vụ xuất vận đơn COD và các bộ đếm thời hạn tự động, hệ thống sử dụng công cụ điều phối thực thi bền bỉ Restate [18].

Restate đóng vai trò là một máy trạng thái phân tán, tự động ghi nhận nhật ký kết quả trung gian của từng bước xử lý. Khi xảy ra sự cố phần cứng, sập nguồn hoặc gián đoạn kết nối mạng giữa chừng, tiến trình sẽ tự động khôi phục và tiếp tục thực thi chính xác từ bước đã hoàn thành. Cơ chế này loại bỏ hoàn toàn rủi ro phát sinh dữ liệu rác, tránh thất thoát trạng thái và bảo đảm tính lũy đẳng (NFR-IDEM-01) cũng như độ tin cậy tuyệt đối (NFR-DUR-01) khi tương tác với các hệ thống bên thứ ba.

=== Cấu hình xử lý trí tuệ nhân tạo và AI Gateway

Nhằm tối ưu hóa chi phí vận hành và tài nguyên phần cứng, hệ thống áp dụng kiến trúc xử lý AI phân tầng:
- Tác vụ xử lý cục bộ: Các tác vụ nặng về tính toán ảnh và âm thanh như cắt trích xuất khung hình video (keyframe extraction), nhận dạng tiếng nói tiếng Việt (ASR) và mô hình trích xuất vector đặc trưng ảnh SigLIP 2 được đóng gói chạy trong các tiến trình cục bộ riêng biệt trên máy chủ, tận dụng tối đa năng lực xử lý CPU/GPU tại chỗ.
- Cổng AI Gateway tập trung: Các mô hình ngôn ngữ lớn (LLM) và mô hình nhúng văn bản (Embedding) bên thứ ba được kết nối thông qua một cổng quản trị tập trung. AI Gateway chịu trách nhiệm quản lý an toàn mã khóa API, cân bằng tải, điều tiết lưu lượng và khống chế trần hạn mức chi phí (quota) chi tiết cho từng phân hệ nghiệp vụ, ngăn chặn nguy cơ chi phí phát sinh ngoài tầm kiểm soát.

== Hiện thực các phân hệ nghiệp vụ cốt lõi

=== Phân hệ tài khoản và định danh

Phân hệ tài khoản đảm nhiệm vai trò quản lý danh tính số, bảo vệ dữ liệu người dùng và kiểm soát phiên làm việc trên toàn hệ thống.

Hệ thống cung cấp ba phương thức xác thực chính trong ca sử dụng UC-ACC-01 (@fig-impl-web-signin): đăng nhập bằng số điện thoại được xác minh qua mã SMS hoặc trực tiếp qua SIM, đăng nhập thông qua tài khoản Google (Google OAuth 2.0), hoặc nhận mã OTP gồm sáu chữ số gửi qua hộp thư điện tử. Ở lần xác thực đầu tiên, tài khoản người dùng được tự động khởi tạo trong cơ sở dữ liệu, giúp hợp nhất thao tác đăng ký và đăng nhập thành một bước duy nhất. Mỗi tài khoản có thể liên kết đồng thời cả số điện thoại lẫn địa chỉ email.

#anh-web([Giao diện đăng nhập trên website], "signin.png") <fig-impl-web-signin>

Để giảm thiểu rào cản tiếp cận, người dùng chỉ duyệt tin và tìm kiếm tin đăng không bắt buộc phải khai báo số điện thoại. Tuy nhiên, số điện thoại đã qua xác minh là điều kiện tiên quyết để người dùng thực hiện các thao tác giao dịch cốt lõi bao gồm: đăng tin bán hàng, mở cuộc trò chuyện trao đổi hoặc bắt đầu phiên trả giá theo quy tắc BR-ACC-03. Khi người dùng kích hoạt các hành vi này, ứng dụng sẽ yêu cầu bổ sung và xác thực số điện thoại trước khi tiếp tục.

Nhằm bảo đảm nguyên tắc bảo mật và hạn chế nguy cơ bị dò quét danh sách người dùng (User Enumeration Attack), hệ thống áp dụng nghiêm ngặt quy tắc BR-ACC-02: phản hồi từ máy chủ khi yêu cầu cấp mã OTP qua email là hoàn toàn đồng nhất trong cả hai trường hợp email đã tồn tại hoặc chưa từng đăng ký tài khoản trên hệ thống.

Một tài khoản được sử dụng chung cho cả hai vai trò mua và bán, không phân chia thành loại tài khoản người bán riêng biệt. Trong chức năng quản lý thiết bị đang đăng nhập (UC-ACC-02), người dùng có thể theo dõi danh sách các phiên làm việc và chủ động đăng xuất khỏi từng thiết bị cụ thể hoặc đăng xuất khỏi toàn bộ các thiết bị khác từ xa, trong khi thiết bị hiện tại vẫn duy trì đăng nhập. Để bảo vệ an toàn tài khoản, thao tác này bắt buộc người dùng phải có phiên xác thực hợp lệ trong vòng 15 phút gần nhất.

Sổ địa chỉ của mỗi tài khoản lưu trữ tối đa 10 địa chỉ nhận hàng hoặc gửi hàng. Toàn bộ dữ liệu địa giới hành chính được chuẩn hóa theo danh mục 34 tỉnh, thành phố và 3.321 phường/xã sau đợt sắp xếp, sáp nhập đơn vị hành chính năm 2025. Ứng dụng tích hợp dịch vụ định vị GPS nhằm gợi ý đơn vị hành chính cấp xã gần nhất từ vị trí địa lý thực tế, giảm thiểu sai sót khi người dùng nhập liệu thủ công.

Bên cạnh đó, người dùng có quyền chặn một tài khoản khác khi phát sinh bất đồng (UC-ACC-05). Quy tắc BR-ACC-01 quy định cơ chế chặn có hiệu lực hai chiều: hai tài khoản bị chặn không thể nhắn tin, không thể mở phiên trả giá trên các tin đăng của nhau, đồng thời tin đăng của đối phương sẽ bị ẩn hoàn toàn khỏi kết quả tìm kiếm và trang chủ. Người dùng cũng có thể yêu cầu xóa tài khoản cá nhân khi không còn bất kỳ đơn COD nào đang trong trạng thái chờ xử lý hoặc đang vận chuyển.

=== Phân hệ đăng tin và quản lý tin đăng

Quy trình đăng tin bán hàng (UC-LST-01) là khâu khởi tạo dữ liệu hàng hóa cho toàn bộ hệ thống. Phân hệ được thiết kế với các quy tắc nghiệp vụ chặt chẽ nhằm bảo đảm chất lượng dữ liệu và hạn chế tranh chấp phát sinh:
- Ràng buộc dữ liệu tin đăng (BR-LST-03): Tiêu đề có độ dài từ 1 đến 70 ký tự, giá niêm yết là số nguyên đồng nằm trong khoảng từ 10.000 đến 1.000.000.000 đ, nội dung mô tả không vượt quá 1.500 ký tự và tối đa 20 thông số kỹ thuật kèm theo.
- Hạn mức tin đăng (BR-LST-02): Mỗi tài khoản được phép duy trì tối đa 20 tin đăng đang mở bán đồng thời nhằm ngăn chặn hành vi spam tin rác.
- Nguyên tắc không khai vết khuyết tật (BR-LST-01): Hệ thống không thiết kế biểu mẫu khai vết và không yêu cầu người bán phải liệt kê các tì vết vật lý. Do tính chất đặc thù của đồ cũ, sự đánh giá hao mòn mang tính cảm quan chủ quan; việc ép buộc khai vết dễ tạo kẽ hở cho các tranh chấp không đáng có. Trách nhiệm thẩm định chất lượng thực tế được trao trọn vẹn cho người mua thông qua cơ chế đồng kiểm trực tiếp tại cửa lúc nhận hàng (BR-DEAL-02).

Nhằm hỗ trợ người bán định giá hợp lý, hệ thống tích hợp thuật toán phân tích thị trường: tổng hợp tối đa 12 tin đăng tương tự đang bán và đã giao dịch thành công trong cùng phân khúc để tính toán "Giá thị trường" (mức giá trung vị median) kèm số ngày bán trung bình, đồng thời đưa ra mức giá "Bán nhanh" (giá trung vị của nhóm 50% tin bán nhanh nhất) nhằm kích thích thanh khoản.

Pipeline xử lý ảnh tin đăng diễn ra hoàn toàn bất đồng bộ: kiểm tra định dạng tệp, tự động xoay ảnh đúng chiều chụp, nén ảnh, tạo bản thu nhỏ (thumbnail) và loại bỏ hoàn toàn các trường dữ liệu EXIF/GPS nhằm bảo vệ sự riêng tư về vị trí sinh sống của người bán. Bản nháp tin đăng được lưu trữ đồng bộ trên máy chủ (tối đa 20 bản nháp, tự dọn sau 30 ngày), cho phép người bán tạo tin dở dang trên điện thoại và hoàn thiện trên website.

Tại mục quản lý tin đăng (UC-LST-02), người bán có thể chỉnh sửa nội dung, thay đổi giá, ẩn/hiện tin, đánh dấu đã bán ngoài hệ thống hoặc xóa tin. Đặc biệt, hệ thống tự động khóa tính năng chỉnh sửa và xóa đối với các tin đăng đang giữ chỗ cho một đơn COD đang xử lý, bảo đảm quyền lợi cho người mua đang chờ nhận hàng.

=== Phân hệ trao đổi và trả giá

Phân hệ trò chuyện (UC-DEAL-01) thiết lập không gian giao tiếp trực tiếp, an toàn giữa người mua và người bán, gắn liền với từng tin đăng cụ thể.

Mỗi cặp người dùng có một cuộc trò chuyện duy nhất, dùng chung cho mọi tin đăng giữa hai người. Kênh truyền thông tin thời gian thực hoạt động qua giao thức WebSocket hỗ trợ gửi nhận tin nhắn tức thời, hiển thị trạng thái đang soạn thảo ("đang nhập..."), mốc thời gian đã đọc (read receipt), đính kèm ảnh và trích dẫn trả lời tin nhắn cụ thể bằng cử chỉ vuốt. Mọi biến động trong quy trình trả giá và trạng thái đơn đều tự động sinh ra tin nhắn hệ thống trong cuộc trò chuyện và đẩy thông báo cho đối phương (FR-SHR-02). Hộp thư hỗ trợ tìm kiếm linh hoạt theo tên người dùng hoặc nội dung tin nhắn không dấu.

Quy trình trả giá (UC-DEAL-02) được tự động hóa nghiêm ngặt theo quy tắc BR-DEAL-03:
- Bước giá bắt buộc là bội số của 1.000 đ.
- Mức giá người mua đề xuất không được thấp hơn 50% giá niêm yết (làm tròn lên mốc 1.000 đ) và phải thấp hơn giá niêm yết hoặc giá người bán vừa phản hồi.
- Mức giá phản hồi của người bán phải cao hơn giá người mua vừa trả và thấp hơn giá niêm yết ban đầu.
- Nguyên tắc trạng thái đơn nhất (Single open offer): Tại mỗi thời điểm chỉ tồn tại duy nhất một mức giá mở và giá mở không tự hết hạn.
- Giao diện thanh chọn giá khóa sẵn trong khoảng giá hợp lệ, ngăn chặn thao tác sai. Thao tác chấp nhận giá mang theo phiên bản mức giá người dùng đã thấy; nếu giá bị thay đổi trước đó, thao tác chấp nhận bị từ chối và hiển thị giá mới. Người mua cũng có thể chấp nhận ngay giá niêm yết ban đầu.

=== Phân hệ đánh giá và hồ sơ uy tín

Cơ chế đánh giá sau giao dịch (UC-TRS-01) được kích hoạt khi đơn COD chuyển sang trạng thái Hoàn tất. Người mua và người bán đánh giá lẫn nhau theo thang điểm từ 1 đến 5 sao kèm nội dung đánh giá không quá 500 ký tự.

Để ngăn chặn tâm lý đánh giá trả đũa, hệ thống áp dụng cơ chế đánh giá mù (Blind Review): nội dung đánh giá được giữ ẩn hoàn toàn cho đến khi cả hai bên cùng hoàn thành đánh giá hoặc tự động mở sau 7 ngày. Người nhận đánh giá có quyền phản hồi công khai một lần duy nhất; trước khi có phản hồi, người viết có thể chỉnh sửa hoặc xóa đánh giá trong vòng 7 ngày, sau khi phản hồi đã gửi thì nội dung đánh giá được khóa vĩnh viễn (BR-TRS-04). Đánh giá không hỗ trợ đính kèm ảnh; mọi chứng cứ vi phạm thuộc thẩm quyền của kênh hỗ trợ.

#anh-web([Giao diện trang hồ sơ Uy tín của bạn trên Website], "rep.png") <fig-impl-web-rep>

Trang "Uy tín của bạn" (UC-TRS-04, @fig-impl-web-rep) hiển thị minh bạch các dữ kiện thống kê khách quan (BR-TRS-05): số sao trung bình và tổng lượt đánh giá nhận được, số lượng món hàng đã bán thành công, ngày tham gia hệ thống, số người theo dõi, tỷ lệ phản hồi tin nhắn trong vòng 24 giờ (tính trên tối thiểu 5 cuộc trò chuyện trong 90 ngày), tổng số đơn COD thành công và số đơn giao không thành trong 90 ngày.

== Hiện thực tích hợp trí tuệ nhân tạo

=== Hỗ trợ tạo tin đăng đa phương thức bằng AI

Để đơn giản hóa quy trình đăng tin bán hàng đã qua sử dụng, hệ thống hiện thực hóa ba phương thức tạo tin với sự hỗ trợ của trí tuệ nhân tạo (UC-LST-01):
1. Đăng tin qua video đa phương thức: Người bán quay video ngắn xoay quanh món đồ và nói mức giá muốn bán. Phân hệ đa phương tiện trích xuất các khung hình sắc nét nhất, nhận dạng tiếng nói tiếng Việt qua mô hình ASR, sau đó mô hình ngôn ngữ lớn (Multimodal LLM) phân tích đồng thời thị giác và âm thanh để tự động điền các trường tiêu đề, danh mục, thông số kỹ thuật, mô tả và giá niêm yết.
2. Đăng tin qua ảnh: Mô hình thị giác phân tích từ 1 đến 10 ảnh thực tế của món hàng để nhận diện đặc điểm và điền thông tin tương ứng.
3. Nhập tự động từ liên kết Chợ Tốt: Dịch vụ nền tự động thu thập ảnh và nội dung tin đăng cũ, đồng thời chủ động loại bỏ số điện thoại và thông tin Zalo trong văn bản để bảo vệ an toàn giao dịch.

#anh-mobile(
  [Quy trình đăng tin với sự hỗ trợ của AI trên ứng dụng di động],
  ("sell-reading.png", "sell-filled-gate.png", "sell-done.png"),
  nhan: ("Đọc video và ảnh", "Biểu mẫu điền tự động", "Hoàn tất đăng tin"),
  cao: 9.2cm,
) <fig-impl-mobile-sell>

Hệ thống thiết lập hạn mức gọi AI trong 24 giờ cho mỗi tài khoản: tối đa 30 lượt video, 60 lượt ảnh và 30 lượt link, giúp kiểm soát ngân sách vận hành (@fig-impl-mobile-sell). Người bán có toàn quyền chỉnh sửa và bổ sung mọi thông tin trước khi xuất bản tin.

=== Hệ thống tìm kiếm lai và diễn giải ngôn ngữ tự nhiên

Phân hệ tìm kiếm hiện thực ca sử dụng UC-DSC-01 cho phép người mua nhập câu truy vấn hoàn toàn bằng ngôn ngữ tự nhiên (ví dụ: "xe đạp cũ dưới 3 triệu").

Mô hình ngôn ngữ lớn phân tích ngữ nghĩa truy vấn một lần và chuyển đổi thành tập các điều kiện ưu tiên có cấu trúc theo quy tắc BR-DSC-01. Kết quả tìm kiếm trả về kèm theo các chip điều kiện trực quan (như "Xe đạp", "Dưới 3 tr") và câu giải thích ngắn gọn về cách hệ thống đã hiểu câu tìm kiếm (@fig-impl-web-search). Người mua có thể nhấn tắt các chip điều kiện nếu AI hiểu sai; kết quả tìm kiếm được cập nhật ngay lập tức mà không cần gọi lại mô hình ngôn ngữ. Kết quả phân tích cú pháp được lưu đệm 7 ngày; hệ thống tự động chuyển sang tìm kiếm từ khóa thuần nếu AI phản hồi quá 4 giây hoặc gặp sự cố.

#anh-web([Kết quả tìm kiếm bằng câu ngôn ngữ tự nhiên trên Website], "search.png") <fig-impl-web-search>

Danh sách kết quả tìm kiếm được hợp nhất từ ba luồng truy vấn độc lập trên tập tin đăng đang bán:
1. Khớp từ khóa toàn văn BM25 qua ParadeDB `pg_search`.
2. Tìm kiếm ngữ nghĩa văn bản bằng vector nhúng BGE-M3 [4] qua `pgvector` [17].
3. So khớp ảnh bằng vector SigLIP 2 (mô hình ngôn ngữ tự động sinh thêm mô tả hình dáng ngắn gọn từ câu truy vấn văn bản để so khớp không gian vector ảnh).

#anh-web([Giao diện chi tiết tin đăng trên Website], "listing.png") <fig-impl-web-listing>

Các danh sách kết quả được hợp nhất theo giải thuật Reciprocal Rank Fusion (RRF) [5], kết hợp cộng điểm ưu tiên cho danh mục, khoảng giá, tình trạng, khoảng cách địa lý và độ mới. Các tin đăng đang giữ chỗ, đã bán, bị ẩn, đã xóa hoặc của tài khoản bị chặn đều bị loại bỏ. Hệ thống cung cấp thêm chức năng tìm kiếm bằng ảnh chụp, đề xuất tin tương tự tại trang chi tiết (@fig-impl-web-listing), ba thẻ điều hướng trang chủ (Gợi ý, Gần bạn, Mới nhất), theo dõi câu tìm kiếm (quét định kỳ 30 phút) và thông báo khi tin đăng giảm giá (UC-DSC-03).

=== Bộ lọc phát hiện và cảnh báo rủi ro lừa đảo thời gian thực

Song song với quá trình trao đổi, sau mỗi tin nhắn văn bản, hệ thống tự động kiểm tra 20 tin nhắn gần nhất của cuộc trò chuyện để nhận diện dấu hiệu lừa đảo tiềm ẩn (FR-TRS-04).

Trước khi chuyển dữ liệu cho mô hình ngôn ngữ phân tích, cơ chế mặt nạ dữ liệu nhạy cảm (PII Masking) tự động che mờ số điện thoại, số tài khoản, số thẻ, địa chỉ email và các liên kết web. @fig-impl-table-scam liệt kê danh mục 9 dấu hiệu lừa đảo đặc thù được cấu hình nhận diện.

#figure(
  table(
    columns: (1fr, 2.5fr),
    align: (left + top, left + top),
    table.header([*Phân loại*], [*Dấu hiệu hiển thị cảnh báo cho người dùng*]),
    [Tin nhắn văn bản], [Yêu cầu chuyển khoản thanh toán hoặc đặt cọc trước.],
    [Tin nhắn văn bản], [Rủ rê chuyển kênh liên lạc sang Zalo, Telegram, Facebook.],
    [Tin nhắn văn bản], [Gửi đường dẫn lạ, giả mạo cổng thanh toán hoặc trang theo dõi vận chuyển.],
    [Tin nhắn văn bản], [Yêu cầu cung cấp mã OTP, mật khẩu hoặc thông tin thẻ ngân hàng.],
    [Tin nhắn văn bản], [Mạo danh ban quản trị hệ thống, ngân hàng hoặc hãng vận chuyển.],
    [Tin nhắn văn bản], [Gửi biên lai chuyển tiền giả mạo hoặc viện cớ "chuyển nhầm, xin hoàn lại".],
    [Tin nhắn văn bản], [Sử dụng từ ngữ hối thúc, gây áp lực buộc đối phương ra quyết định gấp.],
    [Dữ kiện hệ thống], [Tài khoản đối tác mới được khởi tạo dưới 7 ngày.],
    [Dữ kiện hệ thống], [Giá niêm yết thấp hơn từ 30% trở lên so với mặt bằng tin tương tự (khi có từ 5 tin so sánh).],
  ),
  caption: [Danh mục các dấu hiệu nhận diện rủi ro lừa đảo trong trò chuyện],
) <fig-impl-table-scam>

Khi phát hiện có dấu hiệu vi phạm, cuộc trò chuyện trong hộp thư được gắn nhãn "Nghi lừa đảo", màn hình trò chuyện hiển thị banner cảnh báo chi tiết các dấu hiệu phát hiện (@fig-impl-mobile-deal-scam (c)). Người dùng có thể đóng dải cảnh báo; thông báo sẽ tái hiện nếu xuất hiện dấu hiệu mới. Ngay từ cảnh báo, người dùng được cung cấp phím tắt chặn và báo cáo tài khoản đối phương, kèm cơ chế hoàn tác tức thì.

#anh-mobile(
  [Giao diện trả giá, chốt giá và cảnh báo lừa đảo trên ứng dụng di động],
  ("chat-offering.png", "chat-agreed-cod.png", "inbox-scam.png"),
  nhan: ("Thanh trả giá", "Chốt giá chọn COD", "Cảnh báo lừa đảo"),
  cao: 9.2cm,
) <fig-impl-mobile-deal-scam>

=== Trợ lý AI đồng hành hỗ trợ nhân viên

Hệ thống tích hợp trợ lý AI thông minh hỗ trợ nhân viên trên trang điều hành (UC-MOD-07, UC-MOD-08).

Khi tiếp nhận một phiếu hỗ trợ hoặc báo cáo mới, trợ lý AI tự động kích hoạt chạy ngầm: rà soát nội dung phản ánh, đối chiếu thông tin đơn COD, tra cứu hành trình vận đơn, trích xuất lịch sử nhắn tin liên quan và lập bản đồ các tài khoản có mối liên hệ nghi vấn. Từ các dữ kiện thu thập, trợ lý AI tổng hợp hồ sơ chứng cứ, đề xuất hướng xử lý phù hợp và soạn sẵn nội dung phản hồi người dùng.

Nhân viên kiểm tra từng đề xuất, có thể yêu cầu trợ lý AI chỉnh sửa qua cuộc trò chuyện, sau đó nhấn xác nhận áp dụng; mọi thao tác can thiệp dữ liệu đều được trang bị tính năng hoàn tác tức thì. Thời gian phản hồi của trợ lý AI được khống chế tối đa 60 giây; chi phí vận hành AI được kiểm soát với hạn mức 20 USD mỗi ngày cho trang điều hành; toàn bộ lịch sử trao đổi được lưu trữ 180 ngày.

== Hiện thực tích hợp hãng vận chuyển và quy trình COD

=== Ràng buộc nghiệp vụ giao dịch COD đồng kiểm

Mô hình giao dịch của hệ thống được xây dựng dựa trên nguyên tắc: hệ thống không giữ tiền trung gian và áp dụng hình thức giao hàng thu tiền hộ (COD) có đồng kiểm tại cửa.

Theo quy tắc BR-DEAL-04, việc hai bên đồng ý một mức giá trong phiên trả giá không đồng nghĩa với việc giữ chỗ tin đăng. Nhiều người mua có thể cùng chốt giá một tin đăng và cùng gửi yêu cầu giao hàng COD (UC-DEAL-03) kèm địa chỉ nhận hàng; người bán giữ toàn quyền lựa chọn giao hàng cho ai. Mỗi tài khoản người mua chỉ được phép có tối đa 3 đơn COD đang mở đồng thời theo quy tắc BR-DEAL-06 để ngăn ngừa hành vi đặt đơn ảo. Đơn COD được cấp mã định danh dạng `SN-100001` ở trạng thái chờ tạo đơn; người bán có 3 ngày để thực hiện gửi hàng, quá thời hạn đơn tự động bị hủy.

Tiền thu hộ COD được hãng vận chuyển đối soát và chuyển trực tiếp vào tài khoản ngân hàng của người bán theo thỏa thuận giữa người bán và hãng; dòng tiền hoàn toàn không đi qua hệ thống theo quy tắc BR-DEAL-01. Do vận đơn phát hành trực tiếp trên tài khoản của người bán, hệ thống cũng không thu phí vận chuyển.

=== Kết nối kỹ thuật với GHTK và GHN

Hệ thống kết nối trực tiếp với API của Giao Hàng Tiết Kiệm (GHTK) [15] và Giao Hàng Nhanh (GHN) [14]. Người bán thực hiện liên kết tài khoản vận chuyển cá nhân một lần duy nhất tại mục Thiết lập giao COD (UC-ACC-04, @fig-impl-web-cod).

#anh-web([Giao diện thiết lập kết nối giao COD trên Website], "cod.png") <fig-impl-web-cod>

Với GHTK, người bán nhập thông tin tài khoản để hệ thống yêu cầu cấp mã kết nối cửa hàng (token) và không lưu trữ mật khẩu; với GHN, người bán cung cấp mã kết nối và mã cửa hàng từ trang quản trị của hãng. Toàn bộ mã kết nối được mã hóa an toàn trong cơ sở dữ liệu.

Khi thực hiện gửi hàng (UC-DEAL-04), người bán lựa chọn một trong hai phương thức:
1. Tạo vận đơn trực tiếp qua API của hãng: Chọn điểm lấy hàng, gói dịch vụ và khối lượng kiện hàng (tối đa 20 kg); hệ thống truy vấn phí vận chuyển thực tế từ hãng. Vận đơn thu hộ thiết lập đúng giá chốt, mặc định áp dụng tùy chọn người nhận trả phí và cho xem hàng đồng kiểm. Mã đơn của hệ thống được truyền làm mã đơn tham chiếu của hãng.
2. Nhập mã vận đơn đã tạo sẵn: Người bán tự tạo vận đơn ngoài rồi nhập mã; hệ thống truy vấn đối soát thông qua tài khoản hãng của người bán và từ chối nếu mã không thuộc tài khoản này theo quy tắc BR-DEAL-12.

=== Điều phối quy trình gửi hàng bền bỉ và đồng bộ hành trình

Quy trình xuất đơn bao gồm chuỗi thao tác liên tiếp: kiểm tra đơn -> tạo/xác thực vận đơn -> khóa giữ chỗ tin đăng -> cập nhật trạng thái đơn sang Đã gửi -> tự động hủy các yêu cầu COD cạnh tranh còn lại với lý do "đã gửi cho người khác" (người mua bị hủy nhận thông báo ngay). Toàn bộ quy trình được quản lý qua Restate [18]. Kết quả từng bước được ghi nhận liên tục; khi xảy ra sự cố giữa chừng, tiến trình tự động khôi phục từ bước đã hoàn thành, không gọi tạo vận đơn lặp lại lần hai trên hãng (đáp ứng NFR-DUR-01 và NFR-IDEM-01).

#figure(
  table(
    columns: (1.3fr, 1fr, 1fr, 1.8fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([*Diễn biến thực tế*], [*Mã trạng thái GHTK*], [*Trạng thái đơn*], [*Hệ quả nghiệp vụ*]),
    [Hãng chưa lấy hàng sau 3 ngày], [1, 2], [Đã hủy], [Hủy vận đơn trên hãng, tin đăng tự động mở bán lại.],
    [Hãng đã tiếp nhận, đang luân chuyển], [3, 4], [Đã gửi], [Ghi nhận lộ trình kiện hàng; từ bước này hai bên không thể tự hủy đơn.],
    [Hãng phát hàng thành công], [5, 6], [Đã gửi], [Kích hoạt thời hạn 3 ngày tự động hoàn tất giao dịch.],
    [Người mua bấm Đã nhận, hoặc quá 3 ngày], [—], [Hoàn tất], [Tin đăng và phiên trả giá chuyển sang trạng thái Đã bán; mở quyền đánh giá hai bên.],
    [Giao không thành, đang/đã hoàn hàng], [9, 20, 21], [Giao không thành], [Tin đăng mở bán lại; người mua không mất tiền; phí vận chuyển chiều hoàn do hãng thu từ người bán.],
  ),
  caption: [Bảng quy đổi trạng thái hãng vận chuyển và hệ quả xử lý đơn COD],
) <fig-impl-table-cod>

Sau khi xuất kho, mọi diễn biến của kiện hàng đều căn cứ vào trạng thái do hãng vận chuyển cập nhật (UC-DEAL-05). Bên cạnh việc tiếp nhận thông báo tức thời qua Webhook, hệ thống duy trì tiến trình quét định kỳ 2 giờ một lần đối với toàn bộ các vận đơn đang mở để phòng ngừa thông báo bị thất lạc. Các thông báo trùng lặp được khử trùng lặp và không làm lùi trạng thái đơn (@fig-impl-table-cod).

Tại thời điểm giao hàng, người mua được quyền mở kiện hàng kiểm tra thực tế trước khi thanh toán (BR-DEAL-05). Sau khi người mua đã đồng ý trả tiền và nhận hàng, hệ thống không cung cấp cơ chế đòi lại tiền (BR-DEAL-09). Trường hợp hàng hóa không đúng mô tả, người mua có quyền từ chối nhận hàng: kiện hàng được chuyển hoàn về cho người bán, người mua không mất tiền và tin đăng tự động quay lại trạng thái đang bán (BR-DEAL-08). Người mua hoặc người bán có quyền hủy đơn khi người bán chưa bàn giao hàng cho hãng (UC-DEAL-06, BR-DEAL-07). Hệ thống được kiểm thử thông qua máy chủ giả lập (Mock Carrier API) mô phỏng chính xác giao thức trao đổi dữ liệu của hai hãng.

== Hiện thực giao diện người dùng và trang điều hành

=== Ứng dụng di động Android

Ứng dụng di động Android được phát triển bằng ngôn ngữ Kotlin, sử dụng bộ công cụ giao diện khai báo Jetpack Compose, hỗ trợ các dòng thiết bị chạy từ Android 12 trở lên. Ứng dụng đáp ứng các tiêu chuẩn trải nghiệm người dùng NFR-UX-01 bao gồm việc hỗ trợ giao diện nền tối (Dark Theme) và tự động thích ứng với cấu hình kích thước phông chữ lớn của hệ điều hành.

Trong phiên bản phát hành của giai đoạn 2, ứng dụng Android đã loại bỏ hoàn toàn 100% các thành phần dữ liệu giả lập (mock data). Quy trình đóng gói tự động tích hợp bước kiểm tra mã nguồn (lint check), tự động báo lỗi và ngăn chặn quá trình biên dịch nếu phát hiện còn bất kỳ tham chiếu nào đến dữ liệu giả.

Toàn bộ mã nguồn gọi API phía client được sinh tự động (Code generation) trực tiếp từ bản đặc tả giao tiếp chuẩn OpenAPI v3.2.0 [16] dùng chung, bảo đảm tính thống nhất tuyệt đối giữa ứng dụng di động và hệ thống microservices về định dạng trường dữ liệu cũng như mã lỗi nghiệp vụ. Ứng dụng tích hợp cơ chế tự phục hồi kết nối khi mạng gián đoạn, tự động tải bù thông điệp bị lỡ, tự làm mới phiên đăng nhập, và kiểm soát tính lũy đẳng nhằm ngăn chặn việc gửi yêu cầu trùng lặp khi người dùng bấm phím nhiều lần.

=== Ứng dụng Web Client

Ứng dụng Web được xây dựng theo kiến trúc dựng sẵn từ phía máy chủ (Server-Side Rendering - SSR) (@fig-impl-web-home).

#anh-web([Giao diện Trang chủ trên Website với ba tab Gợi ý, Gần bạn, Mới nhất], "home.png") <fig-impl-web-home>

Máy chủ web đóng vai trò cổng trung gian bảo mật giữa trình duyệt và hệ thống dịch vụ nền backend. Cơ chế quản lý phiên lưu trữ mã phiên an toàn trong HTTP-only cookies mà mã nguồn chạy trên trình duyệt không thể đọc được, giúp triệt tiêu hoàn toàn nguy cơ tấn công đánh cắp phiên qua lỗi XSS (Cross-Site Scripting). Máy chủ tự động làm mới phiên làm việc khi hết hạn; trình duyệt chỉ tiếp nhận mã HTML đã kết xuất hoàn chỉnh cùng kênh kết nối thời gian thực phục vụ cập nhật tin nhắn và thông báo.

=== Trang điều hành

Trang điều hành là phân hệ dành riêng cho nhân viên, hoạt động trên một ứng dụng web tách biệt nhằm bảo đảm an toàn dữ liệu.

Phân hệ tuân thủ nguyên tắc can thiệp tối thiểu BR-MOD-01: nhân viên tuyệt đối không can thiệp vào các vấn đề thuộc thỏa thuận dân sự giữa hai bên như mức giá hay cảm nhận tình trạng món hàng. Trọng tâm xử lý giới hạn trong các trường hợp: giải quyết phiếu hỗ trợ, rà soát tin đăng hàng cấm/hàng giả mạo bị báo cáo, ngăn chặn các hành vi lừa đảo có tổ chức và phối hợp cung cấp thông tin theo yêu cầu hợp pháp của cơ quan chức năng.

#anh-web([Giao diện tiếp nhận phiếu hỗ trợ trên Website], "support.png") <fig-impl-web-support>

Tại hàng đợi tiếp nhận hỗ trợ (@fig-impl-web-support), nhân viên mở trực tiếp phiếu trên giao diện cuộc trò chuyện của người dùng và trao đổi dưới danh nghĩa đại diện hệ thống; hệ thống ghi nhận chính xác danh tính nhân viên đã thao tác (UC-MOD-09). Hệ thống phân chia ba nhóm phiếu hỗ trợ: "Báo chưa nhận hàng", "Xin thêm hãng vận chuyển" và "Yêu cầu khác", kèm chức năng tiếp nhận báo cáo vi phạm (UC-MOD-01).

Nhân viên có thẩm quyền có thể thực hiện tạm khóa tài khoản vi phạm kèm lý do xác đáng (UC-MOD-02). Tài khoản bị tạm khóa sẽ bị tước quyền đăng tin mới, không thể trả giá hay gửi yêu cầu COD, tuy nhiên vẫn được phép thực hiện các thao tác rút giá, từ chối hoặc hủy các đơn COD đang dang dở theo quy tắc BR-MOD-02.

Nhân viên xác thực bằng tài khoản email và mật khẩu riêng; hệ thống chặn đăng nhập 15 phút nếu nhập sai quá 5 lần liên tiếp. Thời lượng phiên làm việc cố định 8 giờ và không tự động gia hạn. Phân quyền hệ thống phân chia thành hai vai trò: Điều phối viên và Quản trị viên (UC-MOD-04), trong đó Quản trị viên nắm toàn quyền quản lý tài khoản và phân quyền nhân viên. Mọi hành vi làm thay đổi trạng thái dữ liệu của nhân viên đều được ghi nhận vào nhật ký kiểm toán bất biến (UC-MOD-05) đồng thời với chính thao tác đó, hỗ trợ tra cứu chi tiết theo danh tính nhân viên, loại hành vi và mốc thời gian.

== Kết quả thực nghiệm và đánh giá giai đoạn 2

=== Kết quả vận hành trọn vẹn trên dữ liệu thật

Tính đến thời điểm kết thúc giai đoạn 2 (tuần 8), nhóm nghiên cứu đã vận hành trơn tru chu trình mua bán khép kín trên dữ liệu thật: từ khâu người bán quay video đăng tin, AI trích xuất thuộc tính, người mua tìm kiếm bằng ngôn ngữ tự nhiên, trả giá qua thanh trả giá trong cuộc trò chuyện, cảnh báo lừa đảo chủ động, thiết lập vận đơn COD kết nối hãng vận chuyển, cho tới khâu đồng kiểm nhận hàng tại cửa và hoàn tất đánh giá hai chiều.

Toàn bộ 10 hạng mục công việc đã cam kết trong kế hoạch giai đoạn 2 đều đã được hoàn thành, kiểm chứng qua các kịch bản thực tế.

=== Đánh giá tính nhất quán và loại bỏ mock data

Ứng dụng di động Android và ứng dụng Web đã hoàn tất kết nối đồng bộ 100% với hệ thống dịch vụ nền thực tế. Toàn bộ các luồng màn hình của ứng dụng Android đã gỡ bỏ hoàn toàn dữ liệu giả lập, các kiểm thử giao diện và kiểm thử tích hợp đều chạy trên dữ liệu thật phát sinh từ backend microservices. Tính nhất quán về kiểu dữ liệu và mã lỗi giữa client và server được bảo đảm nhờ cơ chế sinh mã tự động từ OpenAPI.

=== Đánh giá các quyết định tinh giản mô hình nghiệp vụ

Nhóm đã chủ động tinh giản các quy trình nặng nề so với thiết kế ban đầu ở định kỳ 1:
- Loại bỏ cơ chế tích lũy điểm và bậc uy tín phức tạp, thay thế bằng việc công khai các dữ kiện thống kê hoạt động thực tế khách quan.
- Loại bỏ yêu cầu xác minh danh tính eKYC bắt buộc và lược bỏ bước khai vết khuyết tật món hàng thủ công.

Các quyết định tinh giản này giúp hệ thống vận hành gọn nhẹ, bám sát hai ràng buộc cốt lõi: hệ thống không giữ tiền của người dùng và không can thiệp phân xử từng vụ việc.

=== Các thách thức kỹ thuật đã giải quyết và kế hoạch chuẩn bị

Trong quá trình thực hiện giai đoạn 2, nhóm đã giải quyết ba thách thức kỹ thuật trọng tâm:
- Việc điều chỉnh mô hình nghiệp vụ đòi hỏi phải đồng bộ đồng thời mã nguồn ứng dụng di động, các dịch vụ nền và tài liệu đặc tả, dẫn đến khối lượng công việc kiểm thử hồi quy lớn trong tuần 6 và tuần 7.
- Do tài liệu API của GHN chưa công bố cơ chế đăng ký nhận trạng thái tự động qua webhook, nhóm đã thiết lập giải pháp kết hợp tiến trình quét định kỳ mỗi 2 giờ để cập nhật tiến trình đơn.
- Sự biến động về độ trễ và chi phí suy luận của các mô hình ngôn ngữ lớn đã được khắc phục bằng giải pháp thiết lập hạn ngạch cuộc gọi theo ngày và tối ưu hóa bộ nhớ đệm kết quả.

Những kết quả đạt được trong giai đoạn 2 là tiền đề vững chắc để nhóm chuẩn bị triển khai các hạng mục của giai đoạn 3, bao gồm việc hoàn thiện tính năng đẩy tin và gói dịch vụ người bán, xử lý kiểm duyệt nội dung chuyên sâu, kiểm thử tải diện rộng và nghiệm thu toàn diện hệ thống.
