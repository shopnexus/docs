#import "../../common/tokens.typ": *

= KẾT LUẬN VÀ KIẾN NGHỊ
== Những kết quả đã đạt được

Đề tài đã đi trọn một vòng đời phát triển phần mềm cho nền tảng thương mại điện tử giữa các cá nhân, từ khảo sát bối cảnh và phân tích yêu cầu, qua thiết kế kiến trúc và thiết kế chi tiết, tới hiện thực và kiểm thử. Sản phẩm bàn giao không dừng ở một bản mô tả ý tưởng mà là một hệ thống chạy được, kèm bộ hồ sơ thiết kế đủ để người khác đọc và tiếp tục phát triển. Các mục tiêu cốt lõi đặt ra ở Chương 1 đều đã được đáp ứng:

- *Về mặt phân tích và thiết kế:* Bộ hồ sơ yêu cầu gồm 30 ca sử dụng, 50 yêu cầu chức năng, 19 yêu cầu phi chức năng kiểm chứng được và 56 quy tắc nghiệp vụ, tất cả đánh mã liên tục và truy vết được hai chiều từ ca sử dụng tới yêu cầu rồi tới thành phần hiện thực. Về thiết kế, hệ thống được mô tả ở cả ba mức: mô hình khái niệm, bản đồ ngữ cảnh giới hạn phân định quyền sở hữu dữ liệu, và thiết kế cơ sở dữ liệu vật lý gồm 45 bảng nghiệp vụ trải trên 7 lược đồ, trong đó không có khoá ngoại nào bắc qua ranh giới hai lược đồ.
- *Về mặt hiện thực:* Ba thành phần gồm dịch vụ nền, ứng dụng web và ứng dụng di động đều đã chạy được và giao tiếp với nhau qua cùng một bản đặc tả giao diện lập trình, nhờ đó hai ứng dụng khách dùng chung một hợp đồng thay vì mỗi bên tự suy diễn. Bảy module nghiệp vụ được đóng gói chung thành một đơn vị triển khai nhưng ranh giới giữa chúng đã được cưỡng chế bằng cơ chế kỹ thuật, nên việc tách một module ra chạy riêng về sau không phải viết lại quy tắc nghiệp vụ.
- *Về giải pháp nghiệp vụ cốt lõi:* Hệ thống chuyển các chính sách bảo vệ giao dịch thành ràng buộc kỹ thuật thay vì để chúng nằm ở dạng cam kết trên giấy. Tiền của người mua vào thẳng sổ ký quỹ chứ không tới người bán; đơn hàng chỉ ra đời sau khi cổng thanh toán xác nhận đã thu được tiền; và mọi khiếu nại, dù xuất phát từ tin đăng, từ đơn hàng hay từ hành vi người dùng, đều đi qua cùng một loại phiếu với cùng một vòng đời. Nhờ vậy bài toán niềm tin giữa hai người xa lạ được giải bằng cấu trúc dữ liệu và luồng điều khiển, chứ không bằng việc trông cậy vào thiện chí của các bên.

== Hạn chế

Bên cạnh kết quả đạt được, hệ thống còn 4 điểm chưa hoàn thiện. Cần phân biệt hai loại: có điểm nằm ngoài phạm vi đã tuyên bố từ đầu, có điểm là thứ nhóm định làm nhưng chưa kịp. Danh sách dưới đây nêu trung thực cả hai, kèm ảnh hưởng thực tế của từng điểm tới sản phẩm bàn giao:

- *Phụ thuộc vào độ trễ và chi phí của API LLM bên ngoài:* Tính năng hỗ trợ điền tự động biểu mẫu đăng bán (trích xuất thông tin từ hình ảnh/giọng nói) yêu cầu gọi mạng tới mô hình ngôn ngữ lớn (Vision/Transcription). Điều này dẫn đến độ trễ tạo phản hồi ở một số tình huống còn hơi cao so với các tương tác web thông thường, đồng thời tạo ra sự phụ thuộc vào giới hạn tốc độ (rate limit) của nhà cung cấp.
- *Phạm vi tích hợp và thử nghiệm:* Trong phạm vi đồ án, hệ thống mới chỉ tập trung xử lý trọn vẹn luồng giao dịch cốt lõi (ký quỹ, khiếu nại). Mảng vận chuyển thực tế và các cổng thanh toán mới dừng ở mức chạy trên bộ giả lập (Mock) nội bộ, chưa kết nối trực tiếp đến môi trường Production của đối tác để đối soát giao dịch thật.
- *Mức độ bao phủ kiểm thử:* Công tác kiểm thử mã nguồn mới chỉ tập trung ở cấp độ kiểm thử đơn vị (Unit Test). Hệ thống chưa có thời gian xây dựng các kịch bản kiểm thử tích hợp toàn trình (End-to-End Test), và đường ống CI/CD hiện thiếu khâu chạy tự động nhóm kiểm thử tầng truy cập dữ liệu do yêu cầu cấp phát cơ sở dữ liệu thực.
- *Khả năng chịu tải:* Đề tài chưa tiến hành đo đạc sức tải (load testing) và chưa có bộ số liệu vận hành thực tế để đánh giá định lượng tính sẵn sàng của hạ tầng khi có lượng truy cập lớn.

== Hướng phát triển

Các hạn chế trên gợi ra 3 hướng hoàn thiện, xếp theo thứ tự nên làm trước. Hai hướng đầu nhằm đưa hệ thống từ trạng thái chạy được trong môi trường phát triển sang trạng thái vận hành được với người dùng thật; hướng thứ ba mở rộng phạm vi nghiệp vụ khi nền tảng đã đủ vững:
- *Tối ưu hóa chi phí và hiệu năng LLM:* Triển khai cơ chế lưu đệm (caching) cho các truy vấn trí tuệ nhân tạo và nghiên cứu sử dụng các mô hình ngôn ngữ cục bộ (local LLM) quy mô nhỏ gọn hơn nhằm giảm thiểu độ trễ và chi phí.
- *Khép kín nghiệp vụ vận hành:* Tích hợp chính thức ít nhất một đơn vị vận chuyển và cổng thanh toán thật để hoàn thiện toàn trình vòng đời đơn hàng, đồng thời thiết lập cơ sở dữ liệu dùng một lần (ephemeral database) vào CI/CD để tự động hóa toàn bộ quá trình kiểm thử.
- *Mở rộng mô hình kinh doanh:* Bổ sung mô hình B2C bên cạnh C2C hiện tại, cho phép doanh nghiệp và nhà bán lẻ chuyên nghiệp mở gian hàng kèm công cụ quản lý tồn kho và tiếp thị. Hướng này đòi hỏi mở rộng mô hình tin đăng và bổ sung nghiệp vụ hóa đơn, nhưng không phải thiết kế lại luồng tiền, vì cơ chế ký quỹ đã tách rời khỏi việc người bán là cá nhân hay tổ chức.

Nhìn lại toàn bộ quá trình, đóng góp có giá trị lâu dài nhất của đề tài không nằm ở số lượng tính năng đã dựng mà ở cách đặt lại bài toán: thay vì cố làm cho hai người xa lạ tin nhau, hệ thống được thiết kế để họ không cần tin nhau vẫn giao dịch được. Mọi quyết định kiến trúc trong quyển, từ việc giữ tiền ở sổ ký quỹ, sinh đơn theo thông báo của cổng thanh toán, cho tới việc gom mọi khiếu nại về một loại phiếu duy nhất, đều là hệ quả của cách đặt bài toán đó.
