= KẾT LUẬN <ketluan>

== Kết quả đạt được

Đề tài đã xây dựng *ShopNexus* — một sàn TMĐT đa người bán — và dùng nó để vận dụng
trọn vẹn các nội dung của học phần *Phát triển phần mềm hướng dịch vụ*. Đối chiếu
với ba chuẩn đầu ra:

#table(
  columns: (1fr, 2fr),
  table.header([Chuẩn đầu ra], [Kết quả]),
  [CLO1 — hiểu phân tích/thiết kế dịch vụ với SOAP/REST/Microservice], [Đã so sánh ba cách tiếp cận và lý giải lựa chọn REST + Microservice (Chương 2); phân tích, mô hình hóa và phân rã dịch vụ theo miền con (Chương 4); thiết kế hợp đồng và API (Chương 5).],
  [CLO2 — áp dụng phát triển phần mềm hướng dịch vụ cho bài toán cụ thể], [Đã hiện thực 8 dịch vụ + 2 workflow: giao tiếp liên dịch vụ qua proxy/ingress (Chương 6), giao dịch phân tán bằng Saga (Chương 7), logic nghiệp vụ theo DDD và event-driven (Chương 8), truy vấn bằng API Composition + CQRS (Chương 9), API ngoài Gateway/BFF + webhook (Chương 10), triển khai production-ready (Chương 11).],
  [CLO3 — trình bày kết quả dự án], [Báo cáo này cùng mã nguồn và app khách là sản phẩm trình bày; mọi đoạn mã trích dẫn nguyên văn, có đường dẫn tệp.],
)

Một số điểm nhấn về mặt kiến trúc hướng dịch vụ:

- *Hợp đồng tường minh, kiểm tra tại biên dịch.* Dùng interface Go làm hợp đồng
  dịch vụ, sinh proxy tự động — loại bỏ "proxy drift", giữ trải nghiệm điều hướng
  của monolith trên một hệ nhiều dịch vụ.
- *Một đường giao tiếp thống nhất.* Mọi lời gọi (ngoài và liên dịch vụ) hội tụ qua
  Restate ingress, nên bền vững, thử lại và quan sát áp dụng *đồng nhất*.
- *Nhất quán phân tán không cần 2PC.* Saga + durable execution xử lý các giao dịch
  dài (escrow tới 14 ngày) mà không khóa toàn cục.
- *Tách triển khai là lựa chọn cấu hình.* Mỗi dịch vụ tách schema, gọi qua ingress
  → nhấc thành deployment riêng không cần refactor.
#pagebreak()
== Hạn chế


Các điểm còn hạn chế:

- *Tách rời thời gian biên dịch chưa hoàn tất.* Proxy client vẫn nằm trong gói
  `biz` của từng dịch vụ; muốn deploy độc lập *thực sự* (không biên dịch code dịch
  vụ khác) cần tách proxy ra gói `contract` chỉ-có-kiểu. Hiện mới đạt tách rời
  *thời gian chạy*.
- *Hợp đồng gắn một ngôn ngữ.* Hợp đồng interface là Go; liên thông đa ngôn ngữ
  thực sự (thế mạnh kinh điển của SOAP/gRPC) sẽ cần phơi bày thêm hợp đồng trung
  lập ngôn ngữ.
- *Chưa có GraphQL.* Nhu cầu hiện được API Composition phục vụ; GraphQL để ngỏ cho
  tương lai khi loại client đa dạng hơn.
- *Nhất quán cuối ở đường đọc CQRS.* Mô hình đọc (tìm kiếm, xếp hạng) có độ trễ nhỏ
  so với đường ghi — chấp nhận được với gợi ý nhưng cần lưu ý khi mở rộng.

== Hướng phát triển

Xuất phát từ các hạn chế đã nêu, có thể đề xuất một số việc cần làm tiếp theo:

- *Tách interface ra gói riêng.* Proxy client hiện vẫn nằm trong gói `biz` của từng
  dịch vụ, nên khi biên dịch một dịch vụ vẫn phải kéo mã nguồn dịch vụ khác. Nếu
  trích riêng các interface và kiểu dữ liệu vào một gói `contract`, bộ sinh
  `genrestate` chỉ cần nhìn gói đó, mỗi dịch vụ lúc này biên dịch và triển khai
  hoàn toàn độc lập, không còn phụ thuộc mã nguồn lẫn nhau.
- *Phơi bày hợp đồng đa ngôn ngữ.* Hợp đồng hiện là interface Go, chỉ dùng được
  trong hệ sinh thái Go. Nếu sau này cần viết một dịch vụ bằng ngôn ngữ khác (chẳng
  hạn Python cho mô hình gợi ý), sẽ cần sinh thêm đặc tả OpenAPI hoặc Protobuf từ
  interface Go, giữ nguồn chân lý vẫn là code Go nhưng các ngôn ngữ khác đọc được.
- *Thử tách deployment thực tế.* Chương 11 cho thấy kiến trúc đã sẵn sàng tách dịch
  vụ mà không cần refactor. Bước tiếp là thực sự tách `catalog` và `order` thành
  deployment riêng trên Kubernetes, chạy autoscaler và đo xem hiệu quả mở rộng ngang
  đạt được bao nhiêu so với chạy chung một tiến trình.
- *Thêm lớp GraphQL hoặc BFF.* Khi có thêm loại client (mobile nhẹ, đối tác B2B),
  mỗi bên cần dữ liệu khác nhau. Một lớp GraphQL hoặc BFF (Backend For Frontend)
  đặt trước gateway sẽ cho phép client lấy đúng dữ liệu cần, bớt tạo endpoint
  riêng cho từng màn hình.
- *Tracing phân tán và kiểm thử chịu lỗi.* Hệ thống đang có metrics và log, nhưng
  chưa có tracing xuyên suốt giữa các dịch vụ. Tích hợp OpenTelemetry sẽ giúp nhìn
  được toàn bộ luồng gọi khi đã tách deployment. Ngoài ra, chạy thử chaos testing
  (ví dụ cố tình làm lỗi một bước saga) để kiểm tra xem cơ chế bù trừ có hoạt động
  đúng trong điều kiện thực tế hay không.
