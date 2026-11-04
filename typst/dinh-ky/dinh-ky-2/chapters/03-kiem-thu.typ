#import "../../../common/tokens.typ": *

= KIỂM THỬ BƯỚC ĐẦU

Mỗi ca kiểm thử mô tả một tình huống người mua hoặc người bán có thể gặp và được truy về ca sử dụng, quy tắc nghiệp vụ mà tình huống đó phải tuân theo. Các ca chạy trên cơ sở dữ liệu thật, mỗi ca có dữ liệu riêng. GHTK và GHN được thay bằng máy chủ giả trả phản hồi đúng định dạng tài liệu của hãng [9][10], nhờ đó dựng được các tình huống khó gặp như hãng báo trùng, báo sai thứ tự hay hủy khi hàng đã được lấy. Mô hình ngôn ngữ được thay bằng bản giả có thể trả lời chậm hoặc lỗi, và hạn 3 ngày của ghi nhận sự cố được kiểm bằng cách cho đồng hồ chạy nhanh. Bảng 3.1 liệt kê các kịch bản chính.

#figure(
  kind: table,
  caption: [Các kịch bản kiểm thử chính của giai đoạn 2],
  table(
    columns: (0.6fr, 3.4fr, 1.1fr),
    align: (left + top, left + top, left + top),
    table.header([*Mã*], [*Kịch bản nghiệp vụ*], [*Truy vết*]),
    [TC-01], [Hãng báo giao thành công nhiều lần; đơn chỉ hoàn tất một lần và người bán chỉ được cộng 10 điểm một lần], [NFR-02, UC-17],
    [TC-02], [Máy chủ gặp sự cố ngay sau khi hãng đã tạo vận đơn; lần chạy lại không tạo vận đơn thứ hai], [NFR-01, UC-16],
    [TC-03], [Người bán tạo đơn đúng lúc tin vừa bị đóng; vận đơn vừa tạo được hủy, đơn chuyển sang đã hủy], [REQ-15, BR-07],
    [TC-04], [Hủy đơn khi hãng chưa lấy hàng thì vận đơn bị hủy theo; hủy sau khi hãng đã lấy hàng bị từ chối], [UC-18, BR-10],
    [TC-05], [Hãng báo đã lấy hàng sau khi đã báo giao thành công; đơn không lùi trạng thái], [REQ-16, UC-17],
    [TC-06], [Người mua từ chối nhận tại cửa; người mua không mất tiền, tin đăng mở bán lại], [BR-11, UC-17],
    [TC-07], [Ghi nhận sự cố quá 3 ngày không trả lời tự chuyển sang bị từ chối và hiện công khai], [BR-14, UC-21],
    [TC-08], [Người mua bậc Mới mở đơn COD thứ ba cùng lúc bị từ chối; tỉ lệ từ chối nhận 35% trên ít nhất 5 đơn làm mất quyền COD 30 ngày], [BR-09, BR-15],
    [TC-09], [Agent quá 8 giây hoặc gặp lỗi; người dùng vẫn nhận kết quả tìm kiếm lai theo câu gốc], [NFR-05, BR-18, UC-09],
  ),
)

Chất lượng kết quả của AI agent cần đánh giá riêng. Nhóm đang xây dựng một bộ câu nhu cầu tiếng Việt có gán nhãn tin liên quan, tập trung vào câu nhiều ràng buộc, câu có phủ định và câu cần thông tin vị trí. Ba cấu hình được so sánh: chỉ tìm kiếm lai, tìm kiếm lai cộng một lần gọi LLM phân tích ý định, và agent đầy đủ. Độ đo gồm nDCG\@10, MRR\@10 và tỉ lệ truy vấn không có kết quả. Số đo sẽ được trình bày trong báo cáo cuối, sau khi hoàn tất gán nhãn ở giai đoạn 3.
