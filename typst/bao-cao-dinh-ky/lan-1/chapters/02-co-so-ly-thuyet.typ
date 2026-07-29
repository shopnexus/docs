= CƠ SỞ LÝ THUYẾT

== Kiến trúc Hướng dịch vụ (SOA) và mô hình Microservices

=== Nguyên lý của Kiến trúc Hướng dịch vụ (Service-Oriented Architecture)
Kiến trúc Hướng dịch vụ (SOA - Service-Oriented Architecture) là một mô hình thiết kế và phân rã hệ thống phần mềm trong đó các năng lực nghiệp vụ phức tạp được xây dựng từ các khối chức năng tự chứa, độc lập gọi là *dịch vụ* (services). Mỗi dịch vụ thực hiện một tác vụ nghiệp vụ có ranh giới rõ ràng, không phụ thuộc vào cấu trúc lập trình nội bộ của các dịch vụ khác và giao tiếp thông qua các giao diện (interfaces) cùng *hợp đồng dịch vụ* (service contracts) chuẩn hóa qua mạng.

Nguyên lý cốt lõi của SOA tập trung vào các tiêu chí kỹ thuật mang tính nền tảng:
- *Tính độc lập và ghép nối lỏng giữa các thành phần (Loose Coupling):* Các dịch vụ hạn chế tối đa sự phụ thuộc trực tiếp vào nhau. Khi logic xử lý nội bộ hoặc cấu trúc dữ liệu riêng của một dịch vụ thay đổi, các dịch vụ tiêu thụ (consumer services) không bị ảnh hưởng, miễn là hợp đồng API công khai (REST/gRPC/OpenAPI) vẫn được giữ nguyên.
- *Tính tự trị (Autonomy) và tái sử dụng (Reusability):* Một dịch vụ tự kiểm soát hoàn toàn vòng đời, logic nghiệp vụ và dữ liệu của nó. Đồng thời, một năng lực dịch vụ (ví dụ: xác thực danh tính, thanh toán) có thể được tái sử dụng đồng thời cho nhiều nền tảng client khác nhau (Web App, Mobile App, hệ thống bên thứ ba).
- *Tính trừu tượng (Abstraction):* Mọi chi tiết phức tạp về thuật toán xử lý, ngôn ngữ lập trình cài đặt và hệ quản trị cơ sở dữ liệu bên dưới đều được ẩn giấu hoàn toàn sau các hợp đồng giao tiếp chuẩn.

=== Mô hình Microservices và Triết lý Database-per-service
Microservices là bước tiến hóa hiện đại và thực dụng của kiến trúc SOA, trong đó hệ thống được chia nhỏ thành các dịch vụ có độ mịn cao (fine-grained), mỗi dịch vụ ánh xạ trực tiếp với một miền con nghiệp vụ cụ thể theo phương pháp Thiết kế Hướng miền (Domain-Driven Design - DDD).

Khác với kiến trúc khối liền (Monolithic) truyền thống, nơi toàn bộ các module nghiệp vụ phải chia sẻ chung một hệ quản trị cơ sở dữ liệu quan hệ khổng lồ, mô hình Microservices trong đề tài này áp dụng triệt để nguyên lý *Database-per-service (Mỗi dịch vụ một cơ sở dữ liệu độc lập)*:
- *Cô lập tuyệt đối về dữ liệu:* Mỗi vi dịch vụ sở hữu và quản lý độc lập một schema hoặc một instance cơ sở dữ liệu riêng biệt.
- *Nghiêm cấm truy cập dữ liệu chéo:* Không một dịch vụ hay module nào được phép truy cập trực tiếp vào bảng dữ liệu SQL của dịch vụ khác. Mọi nhu cầu truy xuất hoặc đồng bộ thông tin liên miền đều bắt buộc phải thực hiện thông qua lời gọi hàm từ xa (Remote Procedure Call — RPC) hoặc thông qua việc lắng nghe sự kiện nghiệp vụ bất đồng bộ (Domain Events).
- *Tránh điểm nghẽn tập trung (Single Point of Bottleneck):* Triết lý này ngăn chặn hiệu quả hiện tượng khóa bảng (table locking) và nghẽn cổ chai tài nguyên CSDL tập trung khi hệ thống chịu tải cao, đồng thời ngăn ngừa hiện tượng rò rỉ logic nghiệp vụ qua tầng dữ liệu.

=== Sự cô lập dữ liệu và đa dạng hóa công nghệ lưu trữ (Polyglot Persistence)
Việc áp dụng triệt để Database-per-service mang lại lợi thế chiến lược về *Polyglot Persistence (Đa dạng hóa công nghệ lưu trữ)*. Hệ thống không bị ép buộc phải sử dụng một giải pháp cơ sở dữ liệu duy nhất cho mọi bài toán mà có thể tự do lựa chọn công nghệ lưu trữ tối ưu nhất cho đặc thù của từng vi dịch vụ:
- Đối với dịch vụ Quản lý Đơn hàng (`Order Service`) và Quản lý Tài khoản (`Account Service`) - nơi yêu cầu tính nhất quán ACID tuyệt đối cho dòng tiền và trạng thái giao dịch, hệ quản trị cơ sở dữ liệu quan hệ PostgreSQL được sử dụng.
- Đối với dịch vụ Tìm kiếm và Danh mục (`Catalog Service`) - nơi đặc thù nghiệp vụ là truy vấn thông tin đa chiều và tìm kiếm tương đồng vector, hệ thống tích hợp phần mở rộng `pgvector` để lưu trữ và tính toán khoảng cách nhúng ngữ nghĩa tốc độ cao.

== Thực thi Bền vững (Durable Execution) trong hệ thống phân tán

=== Thách thức của giao dịch phân tán và giới hạn của mô hình Saga truyền thống
Trong một kiến trúc Microservices tuân thủ Database-per-service, thách thức kỹ thuật phức tạp nhất là duy trì tính nhất quán dữ liệu cho một quy trình nghiệp vụ dài hạn (Long-running Business Process) trải dài qua nhiều dịch vụ. Ví dụ, trong quy trình đặt hàng và thanh toán tạm giữ (Escrow Payment), luồng thực thi phải tuần tự đi qua nhiều bước bước: (1) kiểm tra và trừ tồn kho tại `Inventory Service`, (2) tạo hóa đơn tại `Order Service`, (3) khởi tạo phiên giao dịch trên cổng thanh toán bên ngoài (SePay), (4) khóa dòng tiền vào ví trung gian tại `Account Service`, và (5) thiết lập bộ đếm thời gian 72 giờ chờ người mua xác nhận nhận hàng.

Nếu sử dụng mẫu thiết kế *Saga (Choreography hoặc Orchestration)* truyền thống, các kỹ sư phần mềm phải đối mặt với một gánh nặng phát triển cực lớn:
- *Lập trình thủ công các hàm bù trừ:* Phải tự viết mã cho từng hàm thực thi xuôi (Action) kèm theo hàm bù trừ ngược (Compensation Action) tương ứng cho từng module để hoàn tác dữ liệu khi có lỗi xảy ra giữa chừng.
- *Quản lý trạng thái trung gian phức tạp:* Phải tự thiết kế và duy trì các bảng trạng thái máy (State Machine Tables) trong CSDL để lưu vết đơn hàng đang ở bước thứ mấy của Saga.
- *Xử lý rủi ro hệ thống phân tán:* Khi xảy ra các sự cố hạ tầng như mất kết nối mạng chập chờn, lỗi timeout, pod Kubernetes bị khởi động lại (restart/crash) hoặc tin nhắn hàng đợi bị gửi lặp lại (duplicate delivery), logic xử lý lỗi trong Saga thường phình to gấp nhiều lần mã nghiệp vụ chính, dễ gây sai lệch dòng tiền hoặc lặp giao dịch (ví dụ: trừ tiền hai lần hoặc hoàn kho sai).

=== Khái niệm Thực thi Bền vững và triết lý Journal-based Execution
Để khắc phục triệt để các nhược điểm của Saga mà không làm tăng độ phức tạp của mã nguồn nghiệp vụ, dự án lựa chọn mô hình *Thực thi Bền vững (Durable Execution)*. Đây là mô hình lập trình trong đó nền tảng thực thi đảm bảo một hàm nghiệp vụ có thể chạy liên tục đến khi hoàn thành, tự động tạm dừng khi chờ sự kiện ngoại vi và tự động phục hồi về đúng trạng thái trước khi lỗi xảy ra nếu máy chủ bị sập.

Cơ chế cốt lõi của Durable Execution dựa trên triết lý *Journal-based Execution (Thực thi dựa trên nhật ký ghi trước)*:
- Thay vì để mã ứng dụng tự quản lý trạng thái, một lớp điều phối trung gian (Durable Engine) sẽ đứng ra chặn (intercept) và quản lý toàn bộ các thao tác tương tác vào/ra (I/O operations) của hàm nghiệp vụ, bao gồm lời gọi RPC sang dịch vụ khác, đặt hẹn giờ (timer/sleep), hoặc đọc/ghi biến trạng thái.
- Trước khi một thao tác I/O được thực thi, lệnh gọi và tham số được ghi vào một nhật ký bất biến (Write-Ahead Log / Step Journal) có tính bền vững. Khi thao tác hoàn tất, kết quả trả về cũng được appended vào nhật ký này trước khi luồng code ứng dụng chạy tiếp bước tiếp theo.

=== Nền tảng Restate: Quản lý trạng thái, phục hồi lỗi và ngữ nghĩa Exact-once
Hệ thống tích hợp nền tảng mã nguồn mở *Restate* làm máy chủ điều phối thực thi bền vững (Stateful RPC Proxy & Durable Execution Engine). Restate mang lại những năng lực đột phá cho các dịch vụ cốt lõi:
- *Tự động phục hồi sau lỗi (Crash Recovery & Replay):* Khi một tiến trình dịch vụ đang xử lý giao dịch Escrow bị ngắt đột ngột (do crash ứng dụng, mất mạng hoặc nâng cấp máy chủ), Restate sẽ lập tức phát hiện và tự động điều phối khởi chạy lại hàm nghiệp vụ đó trên một node máy chủ khỏe mạnh khác. Quá trình phục hồi diễn ra qua cơ chế *Replay (Phát lại nhật ký)*: Restate duyệt qua đoạn code từ đầu, nhưng đối với các bước I/O đã có kết quả trong nhật ký, Restate lập tức trả về kết quả cũ trong vài micro giây mà *không hề kích hoạt lại lời gọi thực tế ra bên ngoài*. Luồng code tiếp tục chạy mượt mà từ chính điểm dừng gần nhất, loại bỏ hoàn toàn việc phải lập trình hàm bù trừ (Compensation) thủ công.
- *Đảm bảo tính Idempotent tuyệt đối (Exact-once Semantics):* Restate tự động quản lý các khóa chống trùng lặp (idempotency keys) gắn với từng ngữ cảnh thực thi. Nếu client gửi lại một yêu cầu đặt hàng nhiều lần do nghẽn mạng, Restate nhận diện khóa giao dịch và ngăn chặn việc thực thi lặp lại luồng mutation bên trong, bảo đảm mỗi lệnh thay đổi dòng tiền chỉ diễn ra đúng một lần duy nhất.
- *Quản lý trạng thái và định thời tích hợp (State & Timers):* Restate cung cấp các nguyên hàm đặt hẹn giờ bền vững (`ctx.sleep`) và lưu trữ trạng thái key-value nội bộ (`ctx.get/set`). Khi luồng Escrow cần chờ 72 giờ, hàm nghiệp vụ chỉ cần gọi `sleep(72 hours)`; Restate sẽ giải phóng toàn bộ tài nguyên RAM/CPU của tiến trình đó và tự động đánh thức (resume) luồng code chính xác sau 3 ngày mà không cần thiết lập thêm bất kỳ hệ thống cronjob hay hàng đợi phức tạp nào bên ngoài.

== Giao tiếp liên dịch vụ (Inter-service Communication) và xử lý sự kiện

Hệ thống thiết lập một mô hình giao tiếp lai 3 tầng (3-tier Hybrid Communication Model), kết hợp giữa định tuyến Lệnh/Truy vấn (CQRS-like Routing), cơ chế tín hiệu bền vững và kiến trúc hướng sự kiện, nhằm đạt sự cân bằng tối ưu giữa độ trễ thời gian thực và độ tin cậy tuyệt đối cho dữ liệu.

=== Phân luồng giao tiếp theo mô hình Lệnh/Truy vấn (CQRS-like Routing)
Để tận dụng tối đa năng lực phục hồi lỗi của Restate mà không làm hy sinh hiệu năng của các tác vụ truy vấn dữ liệu thông thường, ShopNexus phân luồng giao tiếp API thành hai con đường riêng biệt:

- *Luồng Lệnh / Thao tác Ghi (Mutations - M) qua Restate Ingress Proxy:*
  - Mọi yêu cầu làm thay đổi trạng thái nhạy cảm của hệ thống (như `CreateOrder`, `AcceptOffer`, `ConfirmEscrowDelivery`, `SubmitDisputeRuling`) đều bắt buộc phải đi qua cổng *Restate Ingress*.
  - *Cơ chế hoạt động:* Restate Ingress đóng vai trò là một API Gateway thông minh. Khi tiếp nhận request, Ingress thực hiện kiểm duyệt bảo mật lớp đầu tiên (xác thực token JWT, kiểm tra quyền RBAC claims), gắn khóa `idempotency-key` từ header để chống lặp giao dịch, sau đó ghi nhận yêu cầu vào nhật ký bền vững (Write-Ahead Log) rồi mới điều hướng lời gọi RPC vào hàm bền vững (Durable Function) của microservice tương ứng.
  - *Lý do kiến trúc:* Đảm bảo 100% các thao tác liên quan đến tài chính và đơn hàng đều được journal hóa, có khả năng tự phục hồi (Crash Recovery) và tuân thủ ngữ nghĩa Exact-once.

- *Luồng Truy vấn / Thao tác Đọc (Queries — Q) qua HTTP/2 RPC trực tiếp:*
  - Các thao tác chỉ đọc dữ liệu (như `GetProductDetails`, `SearchProducts`, `ListUserOrders`, `GetSellerProfile`) được định tuyến *gọi thẳng trực tiếp* từ API Gateway/Frontend vào các microservices thông qua giao thức đồng bộ *HTTP/2 RPC*, hoàn toàn bỏ qua lớp Restate Ingress.
  - *Lý do kiến trúc:* Mỗi lần chuyển tiếp (hop) qua Restate Ingress để thực hiện theo dõi trạng thái và ghi nhật ký sẽ làm phát sinh một độ trễ trung gian (mất khoảng ~50ms kể cả trong mạng nội bộ). Với các tác vụ truy vấn đọc dữ liệu chiếm tần suất cao nhất hệ thống nhưng không làm thay đổi trạng thái, việc bỏ qua Ingress giúp tối ưu độ trễ phản hồi xuống thấp hơn, loại bỏ thuế hiệu năng (durability tax) không cần thiết.

=== Cơ chế điều hướng và đánh thức luồng bất đồng bộ với Restate Ingress
Bên cạnh khả năng định thời (`sleep`), Restate Ingress cung cấp hai phương thức giao tiếp phi đồng bộ mạnh mẽ cho các luồng nghiệp vụ C2C phối hợp:
- *Giao tiếp Fire-and-Forget (`/send` endpoint):* Khi một dịch vụ cần khởi chạy một tác vụ nền (ví dụ: tổng hợp báo cáo hoặc gửi email biên lai), client hoặc dịch vụ gọi có thể gửi request đến endpoint `/send` của Restate Ingress. Ingress ngay lập tức tiếp nhận, lưu nhật ký, trả về một mã nhận diện `Invocation ID` cho client trong vài mili giây và đẩy tác vụ vào hàng đợi xử lý ngầm của Restate mà không bắt client phải chờ tác vụ hoàn thành.
- *Cơ chế Tín hiệu Đánh thức (Awakables / Promise Signaling):* Trong quy trình Escrow hoặc Dispute, quy trình nghiệp vụ thường phải tạm dừng để chờ một sự kiện xác nhận từ hệ thống bên ngoài (ví dụ: chờ webhook từ cổng thanh toán VNPay xác nhận đã nạp tiền, hoặc chờ webhook từ đối tác vận chuyển GHN báo cáo đã giao hàng thành công). Restate cung cấp nguyên hàm *Awakable* - một đối tượng tương đương với Promise phân tán có định danh duy nhất. Luồng code gọi `ctx.awakable()` để tạo định danh và tạm dừng thực thi; khi hệ thống ngoại vi gửi webhook về Ingress kèm định danh này, Ingress lập tức giải phóng Awakable, "đánh thức" (resume) chính xác luồng Escrow đang ngủ và tiếp tục xử lý giải ngân.

=== Kiến trúc hướng sự kiện (Event-Driven) với NATS JetStream
Đối với các thao tác phối hợp hậu kỳ sau khi một giao dịch mutation đã hoàn tất thành công, ShopNexus áp dụng Kiến trúc Hướng sự kiện (Event-Driven Architecture) nhằm giảm độ ghép nối giữa các module:
- *Hệ thống thông điệp NATS JetStream:* Được lựa chọn làm trục sự kiện trung tâm (Event Bus) nhờ kiến trúc siêu nhẹ (được viết bằng Go, tiêu thụ tài nguyên RAM/CPU tối thiểu), độ trễ truyền tải dưới 1ms, nhưng vẫn cung cấp đầy đủ các tính năng doanh nghiệp: lưu trữ sự kiện bền vững trên đĩa (Persistence), phân phối theo nhóm tiêu thụ (Consumer Groups để cân bằng tải), và khả năng phát lại tin nhắn (Message Replay) khi có dịch vụ mới tham gia.
- *Đồng bộ dữ liệu với Transactional Outbox Pattern:* Để tránh hiện tượng bất nhất dữ liệu giữa việc ghi CSDL nội bộ và phát hành sự kiện (ví dụ: đơn hàng đã lưu vào DB nhưng lỗi mạng khiến sự kiện không phát được ra NATS), các microservices áp dụng mẫu thiết kế Outbox. Mọi sự kiện miền (Domain Events như `OrderPaidEvent`, `OfferAcceptedEvent`, `DisputeOpenedEvent`) được ghi song song vào bảng `outbox_events` trong cùng một giao dịch SQL ACID với nghiệp vụ chính. Một tiến trình nền (hoặc bước bền vững của Restate) sẽ chịu trách nhiệm đọc bảng Outbox và phát hành sự kiện an toàn lên NATS JetStream.
- *Tiêu thụ sự kiện và thông báo thời gian thực:* Các dịch vụ phụ trợ lắng nghe sự kiện từ NATS để xử lý độc lập. Dịch vụ Phân tích (`Analytic Service`) tiếp nhận sự kiện đặt hàng để tính toán điểm phổ biến sản phẩm; Dịch vụ Chung (`Common Service`) lắng nghe sự kiện chat và trạng thái đơn hàng để lập tức đẩy thông báo thời gian thực đến trình duyệt và thiết bị di động của người dùng thông qua kết nối *Server-Sent Events (SSE)*.

== Tìm kiếm thông tin dựa trên từ khóa và ngữ nghĩa (Hybrid Search)

=== Tìm kiếm từ khóa truyền thống và các hạn chế trong TMĐT C2C
Trong các sàn thương mại điện tử C2C, sản phẩm được đăng bán bởi các cá nhân không chuyên. Ngôn ngữ mô tả mặt hàng thanh lý thường có tính tự do cao, sử dụng nhiều từ viết tắt, từ lóng, sai chính tả hoặc cấu trúc câu không theo quy chuẩn (ví dụ: "tl ip 15 prm 256 gb zin keng" cho sản phẩm iPhone 15 Pro Max 256GB). 

Nếu chỉ áp dụng các kỹ thuật tìm kiếm từ khóa truyền thống (Full-text Search dựa trên từ vựng hoặc SQL `LIKE`/BM25 thuần túy), hệ thống sẽ gặp phải hai hạn chế nghiêm trọng:
- *Hiện tượng bỏ lót kết quả (False Negatives):* Công cụ tìm kiếm từ vựng đòi hỏi sự trùng khớp chính xác về ký tự giữa từ khóa truy vấn và văn bản mô tả. Khi người mua truy vấn "điện thoại Apple cũ giá rẻ", hệ thống truyền thống sẽ bỏ qua các sản phẩm mô tả là "iPhone 13 thanh lý lên đời" do không trùng từ khóa "điện thoại Apple".
- *Thiếu khả năng nhận thức ngữ cảnh:* Tìm kiếm từ vựng không hiểu được mối liên hệ ngữ nghĩa giữa các từ đồng nghĩa hoặc khái niệm tương đương trong ngữ cảnh mua sắm đồ cũ.

=== Tìm kiếm ngữ nghĩa (Semantic Search) với mô hình nhúng vector\ bge-m3
Để khắc phục rào cản trên, ShopNexus ứng dụng công nghệ Tìm kiếm Ngữ nghĩa (Semantic Search) dựa trên biểu diễn không gian nhúng (vector embeddings). Khi một sản phẩm được tạo mới hoặc cập nhật tại `Catalog Service`, toàn bộ tiêu đề, mô tả và thuộc tính mặt hàng được truyền qua mô hình học sâu *bge-m3 (BAAI General Embedding M3)* để tạo ra các vector đặc trưng.

Mô hình bge-m3 được lựa chọn nhờ năng lực kiến trúc vượt trội, hỗ trợ tạo ra biểu diễn lai (Hybrid Representation) đồng thời trong một lần suy luận:
- *Vector nhúng dày đặc (Dense Embedding):* Là một vector số thực liên tục 1024 chiều ($v in R^1024$). Vector này đóng gói toàn bộ ngữ nghĩa sâu xa và ý định của văn bản, đưa các khái niệm có ý nghĩa tương đồng lại gần nhau trong không gian vector. Nhờ đó, truy vấn "áo giữ ấm mùa đông" có thể tính toán khoảng cách rất gần với sản phẩm "áo khoác len cổ lọ dày dặn".
- *Vector nhúng thưa (Sparse Embedding / Lexical Weights):* Sinh ra trọng số cho các từ vựng xuất hiện trong câu tương tự thuật toán BM25. Biểu diễn thưa này rất quan trọng trong thương mại điện tử vì nó giữ lại độ chính xác tuyệt đối cho các thông số kỹ thuật, mã model sản phẩm (như "RTX 4090", "M3 Max") - những từ khóa chuyên ngành rất dễ bị "hòa tan" và mất độ nét nếu chỉ dùng vector dày đặc.

=== Cơ sở dữ liệu vector pgvector và thuật toán kết hợp lai (Hybrid Search)
Thay vì phải vận hành thêm một hệ quản trị cơ sở dữ liệu vector độc lập (như Milvus, Pinecone hay Qdrant), điều sẽ làm tăng chi phí hạ tầng và phát sinh độ phức tạp lớn trong việc duy trì các pipeline bộ dữ liệu ETL từ cơ sở dữ liệu chính, ShopNexus sử dụng trực tiếp phần mở rộng mã nguồn mở *pgvector* được cài đặt ngay bên trong PostgreSQL của `Catalog Service`.

Việc tích hợp pgvector cho phép thực thi chiến lược *Tìm kiếm lai trong một lệnh truy vấn duy nhất (Single-query Hybrid Retrieval)* với các ưu điểm kỹ thuật:
- *Chỉ mục HNSW tốc độ cao:* Các vector nhúng 1024 chiều của sản phẩm được lưu trữ và đánh chỉ mục bằng thuật toán *HNSW (Hierarchical Navigable Small World)*. Chỉ mục cấu trúc đồ thị nhiều lớp này cho phép thực hiện tìm kiếm lân cận gần nhất gần đúng (ANN — Approximate Nearest Neighbors) với độ phức tạp thời gian chỉ ở mức đối số $O(log N)$.
- *Kết hợp bộ lọc cấu trúc và ngữ nghĩa:* SQL query cho phép tính toán đồng thời khoảng cách Cosine giữa vector truy vấn và vector sản phẩm `(embedding <=> query_embedding)`, kết hợp trực tiếp với các bộ lọc dữ liệu có cấu trúc truyền thống trong mệnh đề `WHERE` (như `price BETWEEN 1000000 AND 5000000`, `category_id = 5`, `status = 'ACTIVE'`, `location_city = 'TP.HCM'`).
- *Thuật toán xếp hạng dung hợp (Reranking & Fusion):* Điểm số liên quan cuối cùng của mỗi mặt hàng được tính bằng thuật toán kết hợp trọng số, cân bằng giữa điểm số khớp từ khóa (Sparse/Full-text), khoảng cách ngữ nghĩa Cosine (Dense), và điểm uy tín người bán, tạo ra danh sách kết quả vừa chính xác về thông số vừa thấu hiểu nhu cầu ngữ nghĩa của người mua.

== Hệ thống gợi ý sản phẩm đa sở thích (Multi-Interest Recommender System)

=== Mô hình hóa người dùng với 4 cụm sở thích (4-Bucket Interest Vectors)
Trong thương mại điện tử C2C, hành vi khám phá và mua sắm của người dùng có đặc tính rất đa dạng, phân mảnh và thay đổi nhanh theo thời gian thực. Một người dùng có thể buổi sáng tìm kiếm điện thoại iPhone cũ, buổi chiều tìm sách giáo khoa đại học, và buổi tối tham khảo các món đồ thủ công trang trí nhà cửa. 

Nếu áp dụng mô hình biểu diễn người dùng truyền thống bằng một vector sở thích duy nhất (Single-vector User Profile - tính trung bình cộng của tất cả các sản phẩm đã xem), vector tổng hợp này sẽ bị "trung bình hóa", bị kéo về vùng không gian ở giữa và mất hoàn toàn khả năng đại diện chính xác cho bất kỳ ý định cụ thể nào của người dùng.

Để giải quyết bài toán này, hệ thống xây dựng theo mô hình *Gợi ý Đa sở thích (Multi-Interest Content-Based Recommendation)*. Theo đó:
- Hồ sơ của mỗi người dùng (User Profile) được biểu diễn bằng một tập hợp $K=4$ vector sở thích độc lập: $U = {u_1, u_2, u_3, u_4}$, với mỗi vector $u_k in R^1024$ nằm trong cùng không gian nhúng ngữ nghĩa `bge-m3` với vector sản phẩm.
- Mỗi vector sở thích (gọi là một *Interest Bucket*) đóng vai trò đại diện cho một cụm ý định mua sắm hoặc một lĩnh vực quan tâm song song của người dùng, giúp hệ thống duy trì nhận thức đồng thời về nhiều nhu cầu khác nhau mà không bị pha trộn.

=== Cập nhật hồ sơ trực tuyến với Exponential Moving Average (Online EMA)
Để hồ sơ người dùng phản ánh tức thời xu hướng quan tâm mới nhất mà không cần phải chạy các luồng huấn luyện lại mô hình học sâu (model retraining) tốn kém tài nguyên, ta áp dụng thuật toán *Cập nhật trực tuyến theo trung bình cộng trượt hàm mũ (Online Exponential Moving Average — EMA)*:

1. *Định tuyến tương tác vào cụm sở thích (Nearest Bucket Matching):* Khi người dùng thực hiện một hành vi tương tác có ý nghĩa với một sản phẩm $p$ có vector nhúng $v_"item" in R^1024$ (các hành vi được gắn trọng số độ quan trọng khác nhau: Click xem = 1, Thêm vào giỏ/Wishlist = 3, Gửi Offer Card đàm phán = 5, Đặt hàng thành công = 10), hệ thống tính toán độ tương đồng Cosine giữa vector sản phẩm $v_"item"$ và cả 4 vector sở thích hiện tại của người dùng. Bucket có khoảng cách gần nhất sẽ được chọn làm mục tiêu cập nhật:
   $ k^* = arg max_(k in {1, 2, 3, 4}) cos(u_k, v_"item") $

2. *Cập nhật trạng thái EMA trực tuyến:* Chỉ riêng vector sở thích gần nhất $u_(k^*)$ được cập nhật lại theo công thức hàm mũ trượt, trong khi 3 bucket còn lại giữ nguyên để bảo toàn các sở thích song song khác:
   $ u_(k^*) arrow.l alpha dot v_"item" + (1 - alpha) dot u_(k^*) $
   - Trong đó, $alpha in (0, 1)$ là hệ số học (learning rate / decay factor). Hệ số $alpha$ được điều chỉnh động dựa trên cường độ của hành vi tương tác (ví dụ: $alpha = 0.1$ cho hành vi click xem lướt qua, $alpha = 0.4$ cho hành vi chốt đơn mua hàng). Cơ chế này giúp vector sở thích nhanh chóng dịch chuyển về phía các mặt hàng đang được quan tâm mạnh mẽ hiện tại nhưng vẫn giữ lại bộ nhớ về các gu thẩm mỹ dài hạn.
3. *Khởi tạo và thay thế cụm sở thích (Bucket Lifecycle):* Nếu một người dùng bắt đầu tìm kiếm một mặt hàng hoàn toàn mới nằm rất xa cả 4 bucket hiện tại (độ tương đồng Cosine của cả 4 bucket đều dưới ngưỡng $theta_"new"$), hệ thống sẽ chọn bucket có thời gian không hoạt động lâu nhất (theo chiến lược LRU — Least Recently Used) hoặc bucket đang trống để khởi tạo trực tiếp bằng vector $v_"item"$ của mặt hàng mới đó.

=== Truy xuất gần đúng (ANN Retrieval) và Dung hợp trọng số (Weighted Fusion)
Quy trình sinh danh sách gợi ý cá nhân hóa cho người dùng tại `Catalog Service` diễn ra qua hai giai đoạn tốc độ cao:

- *Giai đoạn 1: Truy xuất ứng viên song song (Multi-vector ANN Retrieval):*
  - Thay vì gửi 1 câu truy vấn, hệ thống sử dụng đồng thời cả 4 vector sở thích ${u_1, u_2, u_3, u_4}$ để thực hiện 4 luồng truy vấn lân cận gần nhất gần đúng (ANN Search trên chỉ mục HNSW của `pgvector`).
  - Mỗi bucket mang về Top-$N$ (ví dụ: $N=25$) mặt hàng có độ tương đồng Cosine cao nhất, tạo thành một tập hợp ứng viên đa dạng gồm tối đa 100 sản phẩm ($4 times 25$), bao phủ toàn bộ các dải sở thích của người dùng.

- *Giai đoạn 2: Xếp hạng dung hợp có trọng số (Weighted Fusion Ranking):*
  - Tập ứng viên được hợp nhất (tách trùng lặp) và đưa vào bước tính điểm xếp hạng cuối cùng (Final Score) để chọn ra Top 20 sản phẩm hiển thị lên trang chủ hoặc bảng tin của người dùng.
  - Công thức điểm xếp hạng dung hợp tích hợp 4 yếu tố then chốt của thị trường C2C:
    $ "Score"(p) = w_1 dot S_"semantic"(u_(k^*), v_p) + w_2 dot R_"seller"(p) + w_3 dot F_"freshness"(p) + w_4 dot A_"bucket"(k^*) $
    - *$S_"semantic"$ (Điểm tương đồng ngữ nghĩa):* Độ tương đồng Cosine giữa sản phẩm ứng viên $p$ và bucket sở thích khớp với nó.
    - *$R_"seller"$ (Độ uy tín người bán):* Điểm đánh giá sao trung bình và tỷ lệ hoàn thành đơn hàng thành công của chủ sở hữu mặt hàng, giúp ưu tiên hiển thị sản phẩm từ những người bán tin cậy, giảm thiểu rủi ro lừa đảo cho người mua.
    - *$F_"freshness"$ (Độ tươi mới sản phẩm):* Đặc thù cốt lõi của hàng C2C thanh lý là tính duy nhất (mỗi sản phẩm thường chỉ có 1 sản phẩm tồn kho, bán là hết). Do đó, hàm suy giảm hàm mũ theo thời gian đăng bài được áp dụng để ưu tiên mạnh mẽ cho các mặt hàng vừa mới được đăng tải trong vòng 24–48 giờ, tránh gợi ý các mặt hàng đã treo quá lâu hoặc đã bị mua mất.
    - *$A_"bucket"$ (Trọng số hoạt động của bucket):* Bucket nào được người dùng tương tác gần đây nhất và với tần suất dày nhất sẽ được cấp trọng số cao hơn, đảm bảo luồng gợi ý phản ánh đúng nhất trọng tâm mua sắm ở thời điểm hiện tại của người dùng.

== Các công nghệ và nền tảng phát triển ứng dụng

=== Công nghệ phát triển Giao diện: Next.js (Web) và Flutter (Mobile)
Để mang lại trải nghiệm người dùng mượt mà, tốc độ phản hồi cao và đồng bộ trên mọi thiết bị, hệ thống lựa chọn hai nền tảng phát triển giao diện hàng đầu:
- *Giao diện Web với Next.js (React Framework):* Next.js được sử dụng để xây dựng ứng dụng nền web cho cả Người dùng (Web Marketplace) và Điều phối viên/Quản trị viên (Admin/Moderator Portal). Next.js cung cấp cơ chế kết hợp giữa Server-Side Rendering (SSR) và Static Site Generation (SSG), giúp các trang chi tiết sản phẩm và danh mục có tốc độ tải trang ban đầu (FCP) cực nhanh, đồng thời tối ưu hóa tuyệt đối cho công cụ tìm kiếm (SEO) - yếu tố sống còn để các bài đăng bán hàng C2C tiếp cận được người mua tự nhiên từ Google.
- *Giao diện Di động với Flutter:* Flutter (framework đa nền tảng từ Google sử dụng ngôn ngữ Dart) được sử dụng để phát triển ứng dụng di động native cho 2 hệ điều hành iOS và Android từ một tập mã nguồn duy nhất (Single Codebase). Flutter sử dụng engine render đồ họa riêng Skia/Impulse, mang lại hiệu năng giao diện 60/120 FPS mượt mà, tích hợp sâu sắc với camera và thư viện phương tiện của thiết bị di động, giúp người bán dễ dàng chụp ảnh, quay video mở hộp/đóng gói và tải trực tiếp lên khung Chat Offer Card hoặc form khiếu nại Dispute một cách tiện lợi.

=== Công nghệ phát triển Dịch vụ Backend: Go (Golang)
Tầng Backend Microservices được thống nhất phát triển trên nền tảng ngôn ngữ Go (Golang), nhằm đảm bảo tính đồng bộ trong toàn bộ hệ thống về hiệu năng, khả năng bảo trì và tốc độ phát triển:
- *Dịch vụ lõi bền vững với Go (Golang):* Ngôn ngữ Go được lựa chọn làm công nghệ lập trình cho các microservices cốt lõi chịu trách nhiệm về giao dịch tài chính và quy trình dài hạn, bao gồm `Order Service` (Escrow/Dispute) và `Account Service` (Internal Wallet). Quyết định này xuất phát từ sự tương thích hoàn hảo giữa Go và nền tảng *Restate*. SDK Go của Restate là bộ thư viện đạt độ tối ưu cao nhất. Bên cạnh đó, Go biên dịch ra tệp thực thi nhị phân tĩnh (static binary) siêu nhỏ, tiêu thụ tài nguyên bộ nhớ cực thấp (chỉ khoảng 10–30 MB RAM cho mỗi container dịch vụ), tốc độ khởi động ban đầu (cold start) dưới vài mili giây và mô hình xử lý đồng thời (goroutines) siêu nhẹ. Nhóm chấp nhận việc không sử dụng các ORM cồng kềnh mà viết code truy xuất dữ liệu trực tiếp bằng bộ công cụ *SQLC + pgx* (sinh code Go type-safe từ SQL chuẩn) nhằm đạt hiệu năng tối đa và tích hợp Restate mượt mà nhất.
- Tính nhất quán toàn hệ thống: Việc thống nhất một ngôn ngữ duy nhất cho toàn bộ Backend giúp nhóm phát triển giảm chi phí chuyển đổi ngữ cảnh (context switching) khi làm việc trên nhiều dịch vụ, đồng thời thuận lợi cho việc chuẩn hóa quy trình CI/CD, kiểm thử và giám sát (observability) trên cùng một hệ sinh thái công cụ Go.
=== Nền tảng đóng gói, triển khai và quản lý ranh giới
Để hệ thống Microservices vận hành ổn định, an toàn và dễ dàng mở rộng trong môi trường sản xuất, ShopNexus tích hợp các tiêu chuẩn công nghệ hạ tầng và bảo mật hiện đại:
- *Đóng gói và Điều phối Container (Docker & Kubernetes):* Toàn bộ các vi dịch vụ Backend, Frontend, máy chủ Restate, NATS JetStream và các instance PostgreSQL/pgvector đều được đóng gói theo tiêu chuẩn container hóa *Docker*. Hệ thống được triển khai và điều phối tự động trên cụm máy chủ *Kubernetes (K8s)*. Kubernetes chịu trách nhiệm quản lý vòng đời container, tự động khởi động lại pod khi có sự cố, tự động mở rộng quy mô ngang (Horizontal Pod Autoscaler - HPA) khi lượng truy cập sàn tăng đột biến, và định tuyến lưu lượng nội bộ thông qua dịch vụ mạng K8s DNS.
- *Xác thực và Kiểm soát truy cập (JWT & RBAC):* An ninh mạng và ranh giới phân quyền được thiết lập qua mô hình bảo mật hai lớp:
  1. *Xác thực danh tính (Authentication):* Sử dụng giao thức *JSON Web Token (JWT)* không lưu trạng thái (Stateless). Khi người dùng đăng nhập thành công, hệ thống cấp phát một Access Token có thời hạn ngắn (gắn kèm chữ ký số bảo mật) và một Refresh Token. Mọi request gửi lên API Gateway/Restate Ingress đều phải đính kèm token này trong header HTTP Authorization.
  2. *Kiểm soát truy cập dựa trên vai trò (RBAC — Role-Based Access Control) & Quyền sở hữu đối tượng:* Tầng Gateway/Ingress thực hiện xác minh chữ ký JWT và kiểm tra claim `role` (`User`, `Moderator`, `Super Admin`) để chặn đứng các yêu cầu trái phép ngay từ vòng ngoài (ví dụ: User không thể gọi vào API duyệt khiếu nại của Moderator). Tiếp đó, tại tầng Business Logic bên trong từng microservice, hệ thống thực hiện kiểm tra quyền sở hữu đối tượng (Object-level Ownership Validation) — đảm bảo một User dù có token hợp lệ cũng chỉ được phép xem và thao tác trên chính đơn hàng, ví tiền hoặc bài đăng bán do tài khoản của họ sở hữu .
