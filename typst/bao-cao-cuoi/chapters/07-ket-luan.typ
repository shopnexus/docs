#import "../../common/tokens.typ": *

= KẾT LUẬN VÀ KIẾN NGHỊ
== Những kết quả đã đạt được

Đề tài đã hoàn thiện quy trình xây dựng nền tảng thương mại điện tử C2C từ giai đoạn phân tích thiết kế đến hiện thực và kiểm thử, đáp ứng các mục tiêu cốt lõi đã đề ra:

- *Về mặt kiến trúc và thiết kế:* Đã xây dựng thành công kiến trúc, phân tách rành mạch mô hình dữ liệu vật lý cho 7 phân hệ. Các quy tắc nghiệp vụ khép kín được thiết lập chặt chẽ để bảo vệ luồng tiền và luồng trạng thái đơn hàng.
- *Về mặt hiện thực:* Khối dịch vụ nền tảng đã vận hành ổn định, cung cấp các endpoint API giao tiếp đồng bộ với hai ứng dụng khách trên nền tảng Web và Di động.
- *Về giải pháp nghiệp vụ cốt lõi:* Hệ thống đã chuyển hóa các chính sách bảo vệ giao dịch thành ràng buộc kỹ thuật. Tiền thanh toán tự động chuyển vào sổ cái ký quỹ, đơn hàng chỉ hình thành sau khi dòng tiền đã xác nhận, và mọi tranh chấp được quản lý qua một quy trình khiếu nại hợp nhất, giải quyết triệt để bài toán niềm tin giữa hai người dùng xa lạ.

== Hạn chế

Bên cạnh những kết quả đạt được, do giới hạn về mặt thời gian và nguồn lực, hệ thống vẫn còn một số điểm chưa hoàn thiện:

- *Phụ thuộc độ trễ và chi phí của mô hình ngôn ngữ bên ngoài:* Tính năng gợi ý điền tin đăng phải gọi mạng tới mô hình ngôn ngữ lớn, nên độ trễ cao hơn tương tác web thông thường và phụ thuộc giới hạn tốc độ của nhà cung cấp.
- *Phạm vi tích hợp và thử nghiệm:* Trong phạm vi đồ án, hệ thống mới chỉ tập trung xử lý trọn vẹn luồng giao dịch cốt lõi (ký quỹ, khiếu nại). Mảng vận chuyển thực tế và các cổng thanh toán mới dừng ở mức chạy trên bộ giả lập (Mock) nội bộ, chưa kết nối trực tiếp đến môi trường Production của đối tác để đối soát giao dịch thật.
- *Mức độ bao phủ kiểm thử:* Kiểm thử mới dừng ở cấp đơn vị, chưa có kịch bản toàn trình, và dây chuyền tích hợp liên tục còn thiếu khâu chạy nhóm kiểm thử tầng truy cập dữ liệu vì cần cấp phát cơ sở dữ liệu thật.
- *Khả năng chịu tải:* Đề tài chưa tiến hành đo đạc sức tải (load testing) và chưa có bộ số liệu vận hành thực tế để đánh giá định lượng tính sẵn sàng của hạ tầng khi có lượng truy cập lớn.

== Hướng phát triển

Từ các hạn chế trên, hệ thống có 3 hướng hoàn thiện. Thứ nhất là tối ưu chi phí và hiệu năng mô hình ngôn ngữ, bằng cách lưu đệm các truy vấn trí tuệ nhân tạo và dùng mô hình cục bộ nhỏ gọn hơn để giảm độ trễ và chi phí. Thứ hai là khép kín nghiệp vụ vận hành, tích hợp một hãng vận chuyển và một cổng thanh toán thật, đồng thời đưa cơ sở dữ liệu dùng một lần vào dây chuyền tích hợp liên tục. Thứ ba là bổ sung mô hình B2C bên cạnh C2C, cho nhà bán chuyên nghiệp mở gian hàng kèm công cụ quản lý tồn kho.
