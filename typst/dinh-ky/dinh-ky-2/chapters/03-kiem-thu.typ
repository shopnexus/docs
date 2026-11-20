#import "../../../common/tokens.typ": *

#show table.cell: set text(size: 10pt)

= KIỂM THỬ BƯỚC ĐẦU

Mỗi kịch bản kiểm thử là một tình huống người mua, người bán hoặc hãng vận chuyển có thể gây ra, được truy về ca sử dụng tương ứng. Nhóm kiểm thử ở ba mức:

- kiểm thử tự động của từng phân hệ và kiểm thử trọn quy trình trên cơ sở dữ liệu thật, chạy lại ở mỗi lần cập nhật;
- kiểm thử trực tiếp trên môi trường chạy thử bằng hai tài khoản thật, một người bán và một người mua, đi qua nhắn tin, trả giá, đơn COD, đăng tin và tài khoản;
- kiểm thử phần vận chuyển với một hãng giả lập trả lời đúng định dạng tài liệu API của GHTK và GHN, dựng được các tình huống khó gặp như hãng báo trùng, báo sai thứ tự hay không đến lấy hàng.

Các thời hạn 3 ngày và 7 ngày được kiểm bằng cách cho đồng hồ của bài kiểm thử chạy nhanh. Bảng 3.1 liệt kê các kịch bản chính của giai đoạn 2.

#figure(
  kind: table,
  caption: [Các kịch bản kiểm thử chính của giai đoạn 2],
  table(
    columns: (0.6fr, 3.4fr, 1fr),
    align: (left + top, left + top, left + top),
    table.header([*Mã*], [*Kịch bản*], [*Ca sử dụng*]),
    [TC-01], [Hãng báo đã giao hai lần; đơn chỉ hoàn tất một lần], [UC-DEAL-05],
    [TC-02], [Hãng báo đã lấy hàng sau khi đã báo giao; đơn không lùi trạng thái], [UC-DEAL-05],
    [TC-03], [Người bán không tạo đơn trong 3 ngày; đơn tự hủy, tin tiếp tục bán], [UC-DEAL-04],
    [TC-04], [Hãng chưa lấy hàng sau 3 ngày; đơn hủy, vận đơn trên tài khoản hãng hủy theo, tin mở bán lại], [UC-DEAL-06],
    [TC-05], [Người mua không bấm đã nhận; 3 ngày sau khi hãng báo giao, đơn tự hoàn tất và tin thành đã bán], [UC-DEAL-05],
    [TC-06], [Người mua từ chối nhận; đơn giao không thành, tin mở bán lại, số đơn giao không thành của người mua tăng], [UC-DEAL-05, UC-TRS-04],
    [TC-07], [Người bán nhập mã vận đơn không thuộc tài khoản hãng của mình; mã bị từ chối], [UC-DEAL-04],
    [TC-08], [Người mua đang có 3 đơn COD mở gửi yêu cầu thứ tư; yêu cầu bị từ chối], [UC-DEAL-03],
    [TC-09], [Người bán gỡ liên kết GHTK khi còn vận đơn GHTK đang mở; bị từ chối], [UC-ACC-04],
    [TC-10], [Tin nhắn đòi đặt cọc và rủ sang Zalo; cảnh báo hiện. Người dùng tắt cảnh báo, sau đó có tin xin mã OTP; cảnh báo hiện lại], [UC-DEAL-01],
    [TC-11], [Người bán đánh giá người mua trước; đánh giá ẩn với người mua cho đến khi người mua đánh giá lại hoặc qua 7 ngày. Sau câu trả lời, đánh giá không sửa được], [UC-TRS-01],
    [TC-12], [Người dùng chặn một người bán; tin của người bán đó không còn trong tìm kiếm, trang chủ và Gần bạn của cả hai bên], [UC-DSC-01, UC-ACC-05],
    [TC-13], [Người dùng xóa tài khoản khi còn đơn đang giao; bị từ chối cho đến khi đơn đóng], [Tài khoản],
  ),
)

Chất lượng tìm kiếm cần một phép đo riêng. Nhóm đang soạn bộ câu tìm tiếng Việt có gán sẵn các tin liên quan, tập trung vào câu nhiều điều kiện, câu có phủ định và câu cần vị trí. Bộ câu dùng để so sánh ba cách: chỉ khớp từ khóa, ghép ba cách tìm, và ghép ba cách tìm có AI đọc câu. Số đo sẽ trình bày trong báo cáo cuối.
