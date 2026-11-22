#import "../../common/tokens.typ": *

= KIỂM THỬ VÀ ĐÁNH GIÁ

Chương này trình bày cách nhóm kiểm chứng hệ thống theo các kịch bản nghiệp vụ. Mỗi kịch bản xuất phát từ một ca sử dụng hoặc một quy tắc nghiệp vụ ở Chương 3 và trả lời một câu hỏi cụ thể: khi người dùng, hãng vận chuyển hay chính máy chủ gặp tình huống xấu, bên nào có thể bị thiệt và hệ thống có giữ đúng cam kết với bên đó không. Phần cuối chương trình bày kết quả đo chất lượng tìm kiếm.

== Phương pháp kiểm thử

Kịch bản kiểm thử được chọn theo rủi ro nghiệp vụ. Nhóm ưu tiên bốn loại tình huống: một thao tác của người dùng bị thực hiện hai lần và sinh ra hai đơn hay hai vận đơn; máy chủ dừng giữa một quy trình nhiều bước và để tin, đơn, phiên trả giá lệch nhau; nhiều thao tác cùng lúc vượt qua một hạn mức như số đơn COD đang mở hay số lần nhập sai mã; và một thời hạn như 3 ngày của đơn không được thực thi.

Ở dịch vụ nền, mọi kiểm thử chạm tới dữ liệu đều chạy trên PostgreSQL thật; mỗi kiểm thử nhận một bản sao riêng của cơ sở dữ liệu nên không ảnh hưởng lẫn nhau. Đồng hồ trong môi trường kiểm thử chỉnh tay được, nhờ đó các thời hạn 3 ngày của đơn, 7 ngày của đánh giá hay 24 giờ của ảnh được kiểm mà không phải chờ. Một bộ tiêm lỗi làm một bước ghi xong dữ liệu rồi báo lỗi một lần, để kiểm rằng lần chạy lại không lặp hành động. Kiểm thử đầu-cuối chạy toàn bộ hệ thống với một hộp thư giả thu mã gửi qua email và một bộ ký giả cho mã xác minh số điện thoại và Google; hãng vận chuyển được thay bằng hãng giả lập trả lời đúng định dạng tài liệu của hãng [16], [17], và mọi phản hồi được đối chiếu với đặc tả.

Ở ứng dụng Android, luật nghiệp vụ và tầng xử lý của từng màn hình có kiểm thử tự động. Sau mỗi phần nối ứng dụng với dịch vụ nền, nhóm chạy kiểm thử trực tiếp trên môi trường thử bằng hai tài khoản thật, một người bán và một người mua, đi qua nhắn tin, trả giá, đơn COD, đăng tin, tài khoản và thông báo; các tài khoản tạm dùng cho thao tác xóa được xóa ngay sau mỗi lượt chạy. Ở website, mỗi trang được mở ở bề rộng máy tính và điện thoại, cả khi chưa và đã đăng nhập, để tìm lỗi hiển thị và lỗi gọi dịch vụ.

== Các kịch bản nghiệp vụ trọng tâm

Bảng 6.1 và Bảng 6.2 đặc tả hai kịch bản khó nhất: máy chủ gặp sự cố đúng lúc người bán tạo đơn, và kẻ gian đoán mã OTP bằng nhiều lượt gửi cùng lúc. Các kịch bản còn lại được tóm tắt ở Bảng 6.3.

#tcspec(
  "TC-01", "Máy chủ gặp sự cố giữa lúc tạo đơn gửi hàng",
  [Mục tiêu], [Xác nhận sự cố máy chủ trong lúc tạo đơn không sinh ra vận đơn trùng và không để tin, đơn, phiên trả giá lệch nhau],
  [Truy vết], [UC-DEAL-04, BR-DEAL-04; FR-DEAL-03; NFR-DUR-01, NFR-IDEM-01],
  [Tiền điều kiện], [Người mua A đã chốt giá và gửi yêu cầu COD; người mua B cũng gửi yêu cầu COD trên cùng tin; tin đang bán; người bán đã liên kết hãng giả lập, hãng giả lập đếm số vận đơn được tạo],
  [Các bước], [
    1. Đặt máy chủ báo lỗi một lần ngay sau khi bước lưu đơn ghi xong.
    2. Người bán bấm Tạo đơn cho người mua A.
    3. Quy trình tạo đơn chạy lại; ứng dụng của người bán gửi lại thao tác vừa rồi.
    4. Kiểm tra số vận đơn bên hãng, trạng thái đơn, tin, phiên trả giá và yêu cầu của người mua B.
  ],
  [Kết quả mong đợi], [Hãng chỉ nhận đúng một lệnh tạo vận đơn; đơn của A ở trạng thái đã gửi với phí thật do hãng báo; tin chuyển sang đang giữ chỗ; yêu cầu của B bị hủy với lý do "đã gửi cho người khác"; lần gửi lại nhận đúng kết quả của lần đầu; mỗi bên chỉ nhận một thông báo],
)

#tcspec(
  "TC-02", "Năm mươi lượt đoán mã OTP cùng lúc",
  [Mục tiêu], [Xác nhận kẻ gian gửi đồng thời nhiều lượt đoán vẫn không vượt được giới hạn số lần nhập sai, và phản hồi không cho biết lượt nào đã đoán đúng],
  [Truy vết], [UC-ACC-01, BR-ACC-02; FR-ACC-01; NFR-CONC-01, NFR-SEC-01],
  [Tiền điều kiện], [Một mã OTP gửi qua email đang còn hiệu lực; mã đúng đọc được từ hộp thư giả],
  [Các bước], [
    1. Gửi cùng lúc 50 lượt nhập mã, trong đó chỉ một lượt mang mã đúng.
    2. Ghi lại phản hồi của từng lượt.
    3. Đọc lại trạng thái của mã sau cùng.
  ],
  [Kết quả mong đợi], [Số lần thử được ghi nhận không vượt quá giới hạn; mã kết thúc ở một trong hai trạng thái hết lượt hoặc đã dùng, không bao giờ cả hai; nếu mã đã hết lượt trước khi lượt mang mã đúng được xét thì lượt đó cũng bị từ chối như các lượt khác; các lượt bị xử lý chen nhau nhận cùng một lời nhắn "thử lại", không lộ mã vừa thử là đúng hay sai],
)

#figure(
  kind: table,
  caption: [Tóm tắt các kịch bản TC-03 đến TC-16],
  table(
    columns: (auto, 1fr, auto),
    align: (left + top, left + top, left + top),
    table.header([*Mã*], [*Kịch bản và kết quả mong đợi*], [*Truy vết*]),
    [TC-03], [Mạng chập chờn khiến ứng dụng gửi lại yêu cầu COD; người mua nhận đúng phản hồi lần đầu, chỉ có một đơn], [UC-DEAL-03, NFR-IDEM-01],
    [TC-04], [Hãng báo "đã giao" hai lần, rồi báo "đã lấy hàng" đến trễ; đơn không đổi trạng thái hai lần và không lùi trạng thái], [UC-DEAL-05, FR-DEAL-04, NFR-IDEM-01],
    [TC-05], [Người mua chấp nhận giá đúng lúc người bán gửi phản giá; một thao tác được nhận, thao tác kia được báo phiên trả giá vừa thay đổi], [UC-DEAL-02, NFR-CONC-01],
    [TC-06], [Người mua gửi cùng lúc 5 yêu cầu COD trên 5 tin; đúng 3 yêu cầu được nhận, 2 yêu cầu bị từ chối vì vượt hạn mức], [BR-DEAL-06, NFR-CONC-01],
    [TC-07], [Người bán không tạo đơn trong 3 ngày; đơn tự hủy, tin tiếp tục bán], [UC-DEAL-06, BR-DEAL-07],
    [TC-08], [Hãng chưa lấy hàng 3 ngày sau khi gửi; đơn bị hủy, vận đơn trên tài khoản hãng bị hủy theo, tin mở bán lại], [UC-DEAL-06, BR-DEAL-07],
    [TC-09], [Hãng báo đã giao mà người mua không bấm đã nhận; sau 3 ngày đơn tự hoàn tất, tin chuyển sang đã bán], [UC-DEAL-05, BR-DEAL-11],
    [TC-10], [Người mua từ chối nhận tại cửa; đơn giao không thành, tin về đang bán, số đơn giao không thành trên trang Uy tín của người mua tăng một], [UC-DEAL-05, UC-TRS-04, BR-DEAL-08],
    [TC-11], [Người bán nhập mã vận đơn không thuộc tài khoản hãng của mình; mã bị từ chối, đơn không đổi], [UC-DEAL-04, BR-DEAL-12],
    [TC-12], [Tin nhắn đòi đặt cọc và rủ sang Zalo; cảnh báo hiện. Người dùng tắt cảnh báo, sau đó có tin xin mã OTP; cảnh báo hiện lại], [UC-DEAL-01, FR-TRS-04, BR-TRS-06],
    [TC-13], [Người bán đánh giá người mua trước; đánh giá ẩn với người mua cho đến khi người mua đánh giá lại hoặc qua 7 ngày; sau câu trả lời, đánh giá không sửa được], [UC-TRS-01, BR-TRS-04],
    [TC-14], [Mô hình ngôn ngữ lớn (LLM) trả lời chậm hơn 4 giây khi đọc câu tìm; người mua vẫn nhận kết quả theo câu gốc, không có chip], [UC-DSC-01, FR-DSC-01, NFR-PERF-01],
    [TC-15], [Người dùng chặn một người bán; tin của người bán đó không còn trong tìm kiếm, trang chủ và Gần bạn của cả hai bên], [UC-DSC-01, UC-ACC-05, BR-ACC-01],
    [TC-16], [Người bán tải ảnh có ghi tọa độ vị trí và thông tin máy chụp; ảnh trên tin không còn thông tin nào trong số đó], [UC-LST-01, FR-SHR-01, NFR-PRIV-01],
  ),
)

== Đối chiếu yêu cầu phi chức năng

Bảng 6.4 đối chiếu từng yêu cầu phi chức năng ở Chương 3 với cách kiểm chứng.

#figure(
  kind: table,
  caption: [Đối chiếu yêu cầu phi chức năng],
  table(
    columns: (auto, 1fr),
    align: (left + top, left + top),
    table.header([*Mã*], [*Cách kiểm chứng*]),
    [NFR-DUR-01], [Làm một bước báo lỗi sau khi đã ghi, trong các quy trình đăng nhập, gửi mã, đăng tin, gửi hàng và thời hạn của đơn; quy trình phải chạy tiếp, không gửi hai email, không tạo hai vận đơn (TC-01)],
    [NFR-IDEM-01], [Gửi lại mọi thao tác ghi quan trọng; hãng giả lập gửi trùng và gửi sai thứ tự thông báo (TC-03, TC-04)],
    [NFR-CONC-01], [Cho nhiều thao tác chạy cùng lúc trên một phiên trả giá, trên hạn mức đơn COD và trên số tin đang bán (TC-02, TC-05, TC-06)],
    [NFR-MSG-01], [Tạm dừng dịch vụ điều phối quy trình khi đang có thay đổi: thay đổi vẫn phải được lưu, tin báo cho các phân hệ chờ lại và được gửi khi dịch vụ chạy lại; người dùng vẫn xem được và giữ được phiên đăng nhập],
    [NFR-PERF-01], [Đo thời gian phản hồi trên bộ dữ liệu thử; mô hình đọc câu quá giờ (TC-14)],
    [NFR-SEC-01], [Dùng lại mã làm mới phiên cũ, vượt hạn mức gửi mã, so phản hồi cho email có và chưa có tài khoản (TC-02)],
    [NFR-PRIV-01], [Ảnh không còn tọa độ (TC-16); tin chỉ lưu phường/xã hoặc điểm đã làm mờ; nhật ký không chứa số điện thoại, email; mã kết nối hãng vận chuyển không có trong phản hồi và nhật ký],
    [NFR-OBS-01], [Mỗi lỗi người dùng gặp phải tra lại được đúng yêu cầu gây lỗi trên màn hình quan trắc],
    [NFR-PERF-02], [Lượt hỏi trợ lý AI quá 60 giây dừng lại và cho chạy nền],
    [NFR-PRIV-02], [Mỗi lần trợ lý AI đọc dữ liệu cá nhân có một dòng ghi nhân viên đã hỏi; xóa tài khoản thì các phần trích của tài khoản đó trong cuộc trò chuyện với trợ lý AI bị xóa],
    [NFR-API-01], [Mọi phản hồi trong kiểm thử đầu-cuối được đối chiếu với đặc tả; mọi trường hợp đã khai trong đặc tả phải xuất hiện ít nhất một lần],
    [NFR-ARCH-01], [Kiểm tra tự động chặn mọi lời gọi từ một phân hệ vào phần bên trong của phân hệ khác],
    [NFR-UX-01], [Chạy trên điện thoại có phiên bản hệ điều hành thấp nhất mà yêu cầu đặt ra, ở giao diện tối và cỡ chữ lớn; mở mọi trang website ở bề rộng điện thoại],
  ),
)

== Đánh giá chất lượng tìm kiếm

Nhóm đo chất lượng tìm kiếm trên một bộ mẫu gồm 42 tin đăng có ảnh và 46 câu tìm có gán sẵn các tin liên quan: 30 câu chữ, 10 lượt tìm bằng ảnh và 6 lượt tìm tin tương tự. Lượt chạy dùng đúng các mô hình của hệ thống: mô hình đọc câu, BGE-M3 cho văn bản và SigLIP 2 cho ảnh. Độ đo là tỉ lệ tin liên quan có trong 10 kết quả đầu (recall\@10) và nDCG\@10, độ đo thưởng cho việc đặt tin liên quan ở thứ hạng cao. Bảng 6.5 là kết quả với các trọng số ban đầu.

#figure(
  kind: table,
  caption: [Chất lượng tìm kiếm trên bộ mẫu 46 câu],
  table(
    columns: (1.6fr, 0.8fr, 0.9fr, 0.9fr),
    align: (left, center, center, center),
    table.header([*Loại tìm*], [*Số câu*], [*recall\@10*], [*nDCG\@10*]),
    [Câu chữ], [30], [1,000], [0,946],
    [Bằng ảnh], [10], [1,000], [1,000],
    [Tin tương tự], [6], [1,000], [1,000],
    [Tất cả], [46], [1,000], [0,965],
  ),
)

Bộ mẫu nhỏ nên recall\@10 dễ đạt tối đa; con số đáng chú ý hơn là nDCG\@10 của câu chữ, cho thấy có câu mà tin đúng không đứng đầu. Hai độ đo này cũng không phạt tin không liên quan xếp sau tin đúng: tìm bằng ảnh một đôi giày trắng vẫn kéo theo tai nghe và máy giặt ở cuối trang. Bước tiếp theo là thêm một độ đo độ chính xác, nâng ngưỡng tương đồng tối thiểu của danh sách theo nghĩa và theo ảnh, và mở rộng bộ câu sang câu nhiều điều kiện, câu có phủ định và câu cần vị trí.

Gợi ý danh mục khi đăng tin được đo trên 86 tin của bộ mẫu và bộ dữ liệu trình diễn. Trong 77 tin không thuộc nhóm Khác, hệ thống đoán đúng danh mục con của 71 tin khi dùng cả tiêu đề và mô tả, và 69 tin khi chỉ dùng tiêu đề.

Với phần AI đọc câu tìm, thiết kế bảo đảm kết quả không kém tìm theo câu gốc: câu gốc luôn được giữ làm một cụm từ tìm, mô hình chỉ thêm điều kiện ưu tiên, và khi mô hình lỗi hay quá 4 giây thì kết quả chính là kết quả tìm theo câu gốc. Khi mô hình đọc sai một điều kiện, người dùng thấy ngay trên chip và tắt được mà không phải gõ lại câu, lượt tìm lại cũng không qua mô hình.
