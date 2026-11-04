#import "../../common/tokens.typ": *

= KIỂM THỬ VÀ ĐÁNH GIÁ

Chương này trình bày cách nhóm kiểm chứng hệ thống theo các kịch bản nghiệp vụ. Mỗi kịch bản xuất phát từ một ca sử dụng hoặc một quy tắc nghiệp vụ ở Chương 3 và trả lời một câu hỏi cụ thể: khi người dùng, hãng vận chuyển hay chính máy chủ gặp tình huống xấu, bên nào có thể bị thiệt và hệ thống có giữ đúng cam kết với bên đó không. Phần cuối chương trình bày phương pháp đánh giá AI agent tìm kiếm.

== Phương pháp kiểm thử

Kịch bản kiểm thử được chọn theo rủi ro nghiệp vụ. Nhóm ưu tiên bốn loại tình huống: một thao tác của người dùng bị thực hiện hai lần và sinh ra hai đơn hay hai vận đơn; máy chủ dừng giữa một quy trình nhiều bước và để tin, đơn, thương lượng lệch nhau; nhiều thao tác cùng lúc vượt qua một hạn mức như số đơn COD đang mở hay số lần nhập sai mã; và một hạn chờ như 3 ngày của ghi nhận sự cố không được thực thi.

Các kịch bản chạy trên cơ sở dữ liệu thật, mỗi kịch bản có một bản dữ liệu riêng nên không ảnh hưởng lẫn nhau. Đồng hồ trong môi trường kiểm thử chỉnh tay được, nhờ đó hạn 3 ngày của ghi nhận sự cố hay hạn 24 giờ của ảnh được kiểm mà không phải chờ. Một bộ tiêm lỗi cho phép làm máy chủ dừng ngay sau khi một bước đã ghi xong, để kiểm rằng lần chạy lại không lặp hành động. Kiểm thử đầu-cuối chạy toàn bộ hệ thống với một hộp thư giả thu mã gửi qua SMS và email; hai hãng vận chuyển và mô hình ngôn ngữ được thay bằng máy chủ giả trả lời đúng như bên thật, và mọi phản hồi được đối chiếu với đặc tả. Mỗi phân hệ của dịch vụ nền đều có kiểm thử tự động cho các quy tắc nghiệp vụ của mình. Ở ứng dụng di động, luật nghiệp vụ và từng màn hình đều có kiểm thử; giao diện được so ảnh chụp ở chế độ sáng, tối và cỡ chữ lớn, và có các kịch bản đi trọn luồng đăng tin, thương lượng, tài khoản và khám phá.

== Các kịch bản nghiệp vụ trọng tâm

Bảng 6.1 và Bảng 6.2 đặc tả hai kịch bản khó nhất: máy chủ gặp sự cố đúng lúc người bán tạo đơn, và kẻ gian đoán mã đăng nhập bằng nhiều lượt gửi cùng lúc. Các kịch bản còn lại được tóm tắt ở Bảng 6.3.

#tcspec(
  "TC-01", "Máy chủ gặp sự cố giữa lúc tạo đơn gửi hàng",
  [Mục tiêu], [Xác nhận sự cố máy chủ trong lúc tạo đơn không sinh ra vận đơn trùng và không để tin, đơn, thương lượng lệch nhau],
  [Truy vết], [UC-16, BR-07; REQ-15; NFR-01, NFR-02],
  [Tiền điều kiện], [Người mua A đã chốt giá và gửi yêu cầu COD; người mua B cũng gửi yêu cầu COD trên cùng tin; tin đang bán; người bán đã liên kết hãng vận chuyển, máy chủ giả của hãng đếm số vận đơn được tạo],
  [Các bước], [
    1. Đặt máy chủ dừng ngay sau khi bước lưu đơn ghi xong.
    2. Người bán bấm Tạo đơn cho người mua A.
    3. Máy chủ chạy lại và quy trình tạo đơn tiếp tục; ứng dụng của người bán gửi lại thao tác vừa rồi.
    4. Kiểm tra số vận đơn bên hãng, trạng thái đơn, tin, thương lượng và yêu cầu của người mua B.
  ],
  [Kết quả mong đợi], [Hãng chỉ nhận đúng một lệnh tạo vận đơn; đơn của A ở trạng thái đã tạo vận đơn với phí thật do hãng báo; tin chuyển sang đang giữ chỗ; yêu cầu của B bị hủy với lý do "đã gửi cho người khác"; lần gửi lại nhận đúng kết quả của lần đầu; mỗi bên chỉ nhận một thông báo đơn đã tạo],
)

#tcspec(
  "TC-02", "Năm mươi lượt đoán mã đăng nhập cùng lúc",
  [Mục tiêu], [Xác nhận kẻ gian gửi đồng thời nhiều lượt đoán vẫn không vượt được giới hạn 5 lần nhập sai, và phản hồi không cho biết lượt nào đã đoán đúng],
  [Truy vết], [UC-01, BR-21; REQ-01; NFR-03, NFR-06],
  [Tiền điều kiện], [Một mã đăng nhập đang còn hiệu lực cho một số di động; mã đúng đọc được từ hộp thư giả],
  [Các bước], [
    1. Gửi cùng lúc 50 lượt nhập mã, trong đó chỉ một lượt mang mã đúng.
    2. Ghi lại phản hồi của từng lượt.
    3. Đọc lại trạng thái của mã sau cùng.
  ],
  [Kết quả mong đợi], [Số lần thử được ghi nhận không vượt quá 5; mã kết thúc ở một trong hai trạng thái bị khóa hoặc đã dùng, không bao giờ cả hai; nếu mã đã bị khóa trước khi lượt mang mã đúng được xét thì lượt đó cũng bị từ chối như các lượt khác; các lượt bị xử lý chen nhau nhận cùng một lời nhắn "thử lại", không lộ mã vừa thử là đúng hay sai],
)

#figure(
  kind: table,
  caption: [Tóm tắt các kịch bản TC-03 đến TC-14],
  table(
    columns: (auto, 1fr, auto),
    align: (left + top, left + top, left + top),
    table.header([*Mã*], [*Kịch bản và kết quả mong đợi*], [*Truy vết*]),
    [TC-03], [Mạng chập chờn khiến ứng dụng gửi lại yêu cầu COD; người mua nhận đúng phản hồi lần đầu, chỉ có một đơn], [UC-15, NFR-02],
    [TC-04], [Hãng vận chuyển báo "đã giao" hai lần cho cùng một đơn; đơn chỉ chuyển sang đã giao một lần, tin chỉ bán một lần], [UC-17, REQ-16, NFR-02],
    [TC-05], [Người mua chấp nhận giá đúng lúc người bán gửi phản giá; một thao tác được nhận, thao tác kia được báo thương lượng vừa thay đổi và hiện lại trạng thái mới], [UC-14, NFR-03],
    [TC-06], [Người mua bậc Mới gửi cùng lúc 5 yêu cầu COD trên 5 tin; đúng 2 yêu cầu được nhận, 3 yêu cầu bị từ chối vì vượt hạn mức], [BR-09, NFR-03],
    [TC-07], [Kẻ gian dùng lại một phiên đã bị lấy cắp sau khi thiết bị thật đã làm mới; cả phiên bị thu hồi, hai bên đều phải đăng nhập lại], [UC-02, NFR-06],
    [TC-08], [Xin mã cho một số đã có tài khoản và một số chưa có; hai phản hồi giống hệt nhau], [UC-01, BR-21, NFR-06],
    [TC-09], [Báo "đã giao" cho đơn còn ở trạng thái đã yêu cầu, và hủy một đơn đang giao; cả hai thao tác bị từ chối, đơn không đổi], [UC-17, UC-18, BR-10],
    [TC-10], [Trả giá thấp hơn nửa giá niêm yết; lời trả giá bị từ chối kèm khoảng giá hợp lệ], [UC-14, BR-06, REQ-14],
    [TC-11], [Người mua có 5 đơn COD trong 90 ngày, trong đó 1 lần từ chối nhận (20%); hạn mức còn 1 đơn COD đang mở], [UC-22, BR-15, REQ-19],
    [TC-12], [Người bán không trả lời ghi nhận sự cố; sau 3 ngày ghi nhận tự chuyển sang bị từ chối và hiện trên hồ sơ người bán], [UC-21, BR-14, REQ-18],
    [TC-13], [Mô hình ngôn ngữ trả lời chậm hơn 8 giây; người mua vẫn nhận kết quả tìm kiếm lai theo câu gốc], [UC-09, REQ-10, NFR-05],
    [TC-14], [Người bán tải ảnh có ghi tọa độ vị trí và thông tin máy chụp; ảnh trên tin không còn thông tin nào trong số đó], [UC-06, REQ-06, NFR-07],
  ),
)

== Đối chiếu yêu cầu phi chức năng

Bảng 6.4 đối chiếu từng yêu cầu phi chức năng ở Chương 3 với cách kiểm chứng. Riêng NFR-05 được kiểm bằng kiểm thử tải trên bộ dữ liệu trình diễn: thời gian phản hồi mà 95% số yêu cầu đạt được so với các ngưỡng 300 ms cho thao tác xem, 800 ms cho tìm kiếm lai và 8 giây cho AI agent.

#figure(
  kind: table,
  caption: [Đối chiếu yêu cầu phi chức năng],
  table(
    columns: (auto, 1fr),
    align: (left + top, left + top),
    table.header([*Mã*], [*Cách kiểm chứng*]),
    [NFR-01], [Làm máy chủ dừng giữa các quy trình gửi mã, đăng nhập lần đầu, đăng tin, tạo đơn và kết thúc đơn; quy trình phải chạy tiếp, không gửi hai tin nhắn, không tạo hai vận đơn (TC-01)],
    [NFR-02], [Gửi lại mọi thao tác ghi quan trọng; hãng vận chuyển gửi trùng thông báo (TC-03, TC-04)],
    [NFR-03], [Cho nhiều thao tác chạy cùng lúc trên một thương lượng, trên hạn mức đơn COD và trên số tin đang bán (TC-02, TC-05, TC-06)],
    [NFR-04], [Tạm dừng nền tảng điều phối quy trình khi đang có thay đổi: thay đổi vẫn phải được lưu, thông báo cho các phân hệ chờ lại và được gửi khi nền tảng chạy lại; người dùng vẫn xem được và giữ được phiên đăng nhập],
    [NFR-05], [Kiểm thử tải trên bộ dữ liệu trình diễn với các ngưỡng đã đặt; AI agent quá giờ (TC-13)],
    [NFR-06], [Dùng lại phiên cũ, vượt hạn mức gửi mã, so phản hồi cho số có và chưa có tài khoản (TC-02, TC-07, TC-08)],
    [NFR-07], [Ảnh không còn tọa độ (TC-14); tin chỉ lưu phường xã; nhật ký không chứa số điện thoại, email; thông tin kết nối hãng vận chuyển được giữ kín],
    [NFR-08], [Mỗi lỗi người dùng gặp phải tra lại được đúng yêu cầu gây lỗi trên màn hình quan trắc],
    [NFR-09], [Mọi phản hồi trong kiểm thử đầu-cuối được đối chiếu với đặc tả; mọi trường hợp đã khai trong đặc tả phải xuất hiện ít nhất một lần],
    [NFR-10], [Kiểm tra tự động chặn mọi lời gọi từ một phân hệ vào phần bên trong của phân hệ khác],
    [NFR-11], [Chạy trên điện thoại có phiên bản hệ điều hành thấp nhất mà yêu cầu đặt ra; so ảnh chụp giao diện tối và cỡ chữ lớn; kiểm vùng chạm tối thiểu trên từng màn hình],
  ),
)

== Đánh giá AI agent tìm kiếm

Phương pháp đánh giá dùng một bộ 200 câu nhu cầu tiếng Việt, mỗi câu được gán nhãn các tin liên quan trong bộ dữ liệu trình diễn. Ba cấu hình được so sánh: A chỉ dùng tìm kiếm lai; B thêm một lần gọi mô hình ngôn ngữ để phân tích ý định rồi điền bộ lọc; C là B cộng vòng lặp agent có công cụ và trí nhớ hội thoại. Độ đo gồm nDCG\@10, MRR\@10, Recall\@50 và tỉ lệ kết quả rỗng. Bên cạnh đánh giá ngoại tuyến, một nghiên cứu tác vụ với khoảng 20 người dùng ghi lại thời gian hoàn thành, số thao tác và tỉ lệ chip bị sửa.

Kết quả được báo cáo ở mức định tính và qua các bảo đảm do thiết kế. Cấu hình C không kém A: câu gốc luôn được giữ với trọng số dương trong mọi lần tìm mà agent thực hiện, agent chỉ điền bộ lọc, và khi quá 8 giây hay công cụ lỗi thì kết quả chính là kết quả của A. Agent giúp nhiều nhất ở các câu có ràng buộc giá, vị trí hoặc phủ định, loại câu mà tìm kiếm lai dùng nguyên văn không tách được, ví dụ "đừng ồn" lại kéo kết quả về phía các tin có chữ "ồn". Câu chỉ gồm tên món hàng không cho agent ràng buộc nào để thêm, nên ở loại câu này C chạy gần như A. Khi agent đọc sai một ràng buộc, người dùng thấy ngay trên chip và sửa được mà không phải gõ lại câu, lượt chạy lại cũng không qua mô hình ngôn ngữ; tỉ lệ chip bị sửa trong nghiên cứu tác vụ vì vậy là thước đo trực tiếp cho những lần agent hiểu sai.
