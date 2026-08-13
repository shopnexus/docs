= CƠ SỞ LÝ THUYẾT

== Kiến trúc Hướng dịch vụ (SOA) và mô hình Microservices

=== Nguyên lý của Kiến trúc Hướng dịch vụ (Service-Oriented Architecture)
Kiến trúc Hướng dịch vụ (SOA - Service-Oriented Architecture) là một mô hình thiết kế và phân rã hệ thống phần mềm trong đó các năng lực nghiệp vụ phức tạp được xây dựng từ các khối chức năng tự chứa, độc lập gọi là dịch vụ (services). Mỗi dịch vụ thực hiện một tác vụ nghiệp vụ có ranh giới rõ ràng, không phụ thuộc vào cấu trúc lập trình nội bộ của các dịch vụ khác và giao tiếp thông qua các giao diện (interfaces) cùng hợp đồng dịch vụ (service contracts) chuẩn hóa qua mạng.

Nguyên lý cốt lõi của SOA tập trung vào các tiêu chí kỹ thuật mang tính nền tảng:
- *Tính độc lập và ghép nối lỏng giữa các thành phần (Loose Coupling):* Các dịch vụ hạn chế tối đa sự phụ thuộc trực tiếp vào nhau. Khi logic xử lý nội bộ hoặc cấu trúc dữ liệu riêng của một dịch vụ thay đổi, các dịch vụ tiêu thụ (consumer services) không bị ảnh hưởng, miễn là hợp đồng API công khai (REST/gRPC/OpenAPI) vẫn được giữ nguyên [8].

=== Mô hình Microservices và Triết lý Database-per-service
Microservices là bước tiến hóa hiện đại và thực dụng của kiến trúc SOA, trong đó hệ thống được chia thành nhiều dịch vụ, mỗi dịch vụ ánh xạ trực tiếp với một miền con nghiệp vụ cụ thể theo phương pháp Thiết kế Hướng miền (Domain-Driven Design - DDD).

Khác với kiến trúc khối liền (Monolithic) truyền thống, nơi toàn bộ các module nghiệp vụ phải chia sẻ chung một hệ quản trị cơ sở dữ liệu quan hệ khổng lồ, mô hình Microservices trong đề tài này áp dụng triệt để nguyên lý Database-per-service (Mỗi dịch vụ một cơ sở dữ liệu độc lập):
- *Cô lập tuyệt đối về dữ liệu:* Mỗi vi dịch vụ sở hữu và quản lý độc lập một schema hoặc một instance cơ sở dữ liệu riêng biệt [9].
- *Nghiêm cấm truy cập dữ liệu chéo:* Không một dịch vụ hay module nào được phép truy cập trực tiếp vào bảng dữ liệu SQL của dịch vụ khác. Mọi nhu cầu truy xuất hoặc đồng bộ thông tin liên miền đều bắt buộc phải thực hiện thông qua lời gọi hàm từ xa (Remote Procedure Call - RPC) hoặc thông qua việc lắng nghe sự kiện nghiệp vụ bất đồng bộ (Domain Events).

=== Sự cô lập dữ liệu và đa dạng hóa công nghệ lưu trữ (Polyglot Persistence)
Việc áp dụng triệt để Database-per-service mang lại lợi thế chiến lược về Polyglot Persistence (Đa dạng hóa công nghệ lưu trữ). Hệ thống không bị ép buộc phải sử dụng một giải pháp cơ sở dữ liệu duy nhất cho mọi bài toán mà có thể tự do lựa chọn công nghệ lưu trữ tối ưu nhất cho đặc thù của từng vi dịch vụ:
- Đối với dịch vụ Tìm kiếm và Danh mục (`Catalog Service`) - nơi đặc thù nghiệp vụ là truy vấn thông tin đa chiều và tìm kiếm tương đồng vector, hệ thống tích hợp phần mở rộng `pgvector` để lưu trữ và tính toán khoảng cách nhúng ngữ nghĩa tốc độ cao [11].

== Durable execution trong hệ thống phân tán

=== Thách thức của giao dịch phân tán và giới hạn của mô hình Saga truyền thống
Trong một kiến trúc Microservices tuân thủ Database-per-service, thách thức kỹ thuật phức tạp nhất là duy trì tính nhất quán dữ liệu cho một quy trình nghiệp vụ dài hạn (Long-running Business Process) trải dài qua nhiều dịch vụ. Ví dụ, trong quy trình đặt hàng và thanh toán tạm giữ (Escrow Payment), luồng thực thi phải tuần tự đi qua nhiều bước bước: (1) kiểm tra và trừ tồn kho tại `Inventory Service`, (2) tạo hóa đơn tại `Order Service`, (3) khởi tạo phiên giao dịch trên cổng thanh toán bên ngoài, (4) khóa dòng tiền vào ví trung gian tại `Account Service`, và (5) thiết lập bộ đếm thời gian 72 giờ chờ người mua xác nhận nhận hàng.

Nếu sử dụng mẫu thiết kế Saga (Choreography hoặc Orchestration) truyền thống, các kỹ sư phần mềm phải đối mặt với một gánh nặng phát triển cực lớn:
- *Lập trình thủ công các hàm bù trừ:* Phải tự viết mã cho từng hàm thực thi xuôi (Action) kèm theo hàm bù trừ ngược (Compensation Action) tương ứng cho từng module để hoàn tác dữ liệu khi có lỗi xảy ra giữa chừng [4].
- *Xử lý rủi ro hệ thống phân tán:* Khi xảy ra các sự cố hạ tầng như mất kết nối mạng chập chờn, lỗi timeout, server bị khởi động lại (restart/crash) hoặc tin nhắn hàng đợi bị gửi lặp lại (duplicate delivery), logic xử lý lỗi trong Saga thường phình to gấp nhiều lần mã nghiệp vụ chính, dễ gây sai lệch dòng tiền hoặc lặp giao dịch (ví dụ: trừ tiền hai lần hoặc hoàn kho sai) [6].

=== Khái niệm durable execution và triết lý Journal-based Execution
Để khắc phục triệt để các nhược điểm của Saga mà không làm tăng độ phức tạp của mã nguồn nghiệp vụ, dự án lựa chọn mô hình durable execution. Đây là mô hình lập trình trong đó nền tảng thực thi đảm bảo một hàm nghiệp vụ có thể chạy liên tục đến khi hoàn thành, tự động tạm dừng khi chờ sự kiện ngoại vi và tự động phục hồi về đúng trạng thái trước khi lỗi xảy ra nếu máy chủ bị sập.

Cơ chế cốt lõi của Durable Execution dựa trên triết lý Journal-based Execution (Thực thi dựa trên nhật ký ghi trước):
- Thay vì để mã ứng dụng tự quản lý trạng thái, một lớp điều phối trung gian (Durable Engine) sẽ đứng ra chặn (intercept) và quản lý toàn bộ các thao tác tương tác vào/ra (I/O operations) của hàm nghiệp vụ, bao gồm lời gọi RPC sang dịch vụ khác, đặt hẹn giờ (timer/sleep), hoặc đọc/ghi biến trạng thái.

=== Nền tảng Restate: Quản lý trạng thái, phục hồi lỗi và ngữ nghĩa Exact-once
Hệ thống tích hợp nền tảng mã nguồn mở Restate làm máy chủ điều phối durable execution (Stateful RPC Proxy & Durable Execution Engine). Restate mang lại những năng lực đột phá cho các dịch vụ cốt lõi:
- *Tự động phục hồi sau lỗi (Crash Recovery & Replay):* Khi một tiến trình dịch vụ đang xử lý giao dịch Escrow bị ngắt đột ngột (do crash ứng dụng, mất mạng hoặc nâng cấp máy chủ), Restate sẽ lập tức phát hiện và tự động điều phối khởi chạy lại hàm nghiệp vụ đó trên một node máy chủ khỏe mạnh khác. Quá trình phục hồi diễn ra qua cơ chế Replay (Phát lại nhật ký): Restate duyệt qua đoạn code từ đầu, nhưng đối với các bước I/O đã có kết quả trong nhật ký, Restate lập tức trả về kết quả cũ trong vài micro giây mà không hề kích hoạt lại lời gọi thực tế ra bên ngoài. Luồng code tiếp tục chạy mượt mà từ chính điểm dừng gần nhất, loại bỏ hoàn toàn việc phải lập trình hàm bù trừ (Compensation) thủ công [12].
- *Đảm bảo tính idempotent (lũy đẳng) tuyệt đối (Exact-once Semantics):* Restate tự động quản lý các idempotency key gắn với từng ngữ cảnh thực thi. Nếu client gửi lại một yêu cầu đặt hàng nhiều lần do nghẽn mạng, Restate nhận diện khóa giao dịch và ngăn chặn việc thực thi lặp lại luồng mutation bên trong, bảo đảm mỗi lệnh thay đổi dòng tiền chỉ diễn ra đúng một lần duy nhất [5].

== Giao tiếp liên dịch vụ (Inter-service Communication) và xử lý sự kiện

Hệ thống thiết lập một mô hình giao tiếp lai 3 tầng (3-tier Hybrid Communication Model), kết hợp giữa định tuyến Lệnh/Truy vấn (CQRS-like Routing), cơ chế tín hiệu bền vững và kiến trúc hướng sự kiện, nhằm đạt sự cân bằng tối ưu giữa độ trễ thời gian thực và độ tin cậy tuyệt đối cho dữ liệu.

=== Phân luồng giao tiếp theo mô hình Lệnh/Truy vấn (CQRS-like Routing)
Để tận dụng tối đa năng lực phục hồi lỗi của Restate mà không làm hy sinh hiệu năng của các tác vụ truy vấn dữ liệu thông thường, hệ thống phân luồng giao tiếp API thành hai con đường riêng biệt:

- *Luồng Lệnh / Thao tác Ghi (Mutations - M) qua Restate Ingress Proxy:*
  - Mọi yêu cầu làm thay đổi trạng thái của hệ thống (side effects) đều bắt buộc phải đi qua cổng Restate Ingress.
  - *Cơ chế hoạt động:* Restate Ingress tiếp gắn khóa `idempotency-key` từ header để chống lặp giao dịch, sau đó ghi nhận yêu cầu vào nhật ký bền vững (Write-Ahead Log) rồi mới điều hướng lời gọi RPC vào hàm bền vững (Durable Function) của microservice tương ứng.

- *Luồng Truy vấn / Thao tác Đọc (Queries - Q) qua HTTP/2 RPC trực tiếp:*
  - Các thao tác chỉ đọc dữ liệu được định tuyến gọi thẳng trực tiếp từ API Gateway/Frontend vào các microservices thông qua giao thức đồng bộ HTTP/2 RPC, hoàn toàn bỏ qua lớp Restate Ingress.

=== Cơ chế điều hướng và đánh thức luồng bất đồng bộ với Restate Ingress
Bên cạnh khả năng định thời (`sleep`), Restate Ingress cung cấp hai phương thức giao tiếp phi đồng bộ mạnh mẽ cho các luồng nghiệp vụ C2C phối hợp:
- *Cơ chế Tín hiệu Đánh thức (Awakables / Promise Signaling):* Trong quy trình Escrow hoặc Dispute, quy trình nghiệp vụ thường phải tạm dừng để chờ một sự kiện xác nhận từ hệ thống bên ngoài (ví dụ: chờ webhook từ cổng thanh toán VNPay xác nhận đã nạp tiền, hoặc chờ webhook từ đối tác vận chuyển GHN báo cáo đã giao hàng thành công). Restate cung cấp nguyên hàm Awakable - một đối tượng tương đương với Promise phân tán có định danh duy nhất. Luồng code gọi `ctx.awakable()` để tạo định danh và tạm dừng thực thi; khi hệ thống ngoại vi gửi webhook về Ingress kèm định danh này, Ingress lập tức giải phóng Awakable, "đánh thức" (resume) chính xác luồng đang ngủ và tiếp tục xử lý giải ngân.

=== Kiến trúc hướng sự kiện (Event-Driven) với NATS JetStream
Đối với các thao tác phối hợp hậu kỳ sau khi một giao dịch mutation đã hoàn tất thành công, hệ thống áp dụng Kiến trúc Hướng sự kiện (Event-Driven Architecture) nhằm giảm độ ghép nối giữa các module:
- *Hệ thống thông điệp NATS JetStream:* Được lựa chọn làm trục sự kiện trung tâm (Event Bus), nhưng vẫn cung cấp đầy đủ các tính năng doanh nghiệp: lưu trữ sự kiện bền vững trên đĩa (Persistence), phân phối theo nhóm tiêu thụ (Consumer Groups để cân bằng tải), và khả năng phát lại tin nhắn (Message Replay) khi có dịch vụ mới tham gia.
- *Thông báo và dữ liệu thời gian thực:* Module Account lắng nghe một số sự kiện đơn hàng để tạo thông báo và lưu vào cơ sở dữ liệu. Đối với các sự kiện cần đẩy tức thời đến người dùng, hệ thống phát sự kiện qua Core NATS theo subject riêng của từng tài khoản, để các gateway đang giữ kết nối WebSocket nhận và chuyển tiếp đến client. Kênh truyền tải này mang tính chất best-effort (không đảm bảo tuyệt đối), do đó khi client mất kết nối và kết nối lại, trạng thái chính thức luôn được đồng bộ lại thông qua API.

== Tìm kiếm thông tin dựa trên từ khóa và ngữ nghĩa (Hybrid Search)

=== Tìm kiếm từ khóa truyền thống và các hạn chế trong TMĐT C2C
Trong các sàn thương mại điện tử C2C, sản phẩm được đăng bán bởi các cá nhân không chuyên. Ngôn ngữ mô tả mặt hàng thanh lý thường có tính tự do cao, sử dụng nhiều từ viết tắt, từ lóng, sai chính tả hoặc cấu trúc câu không theo quy chuẩn (ví dụ: "tl ip 15 prm 256 gb zin keng" cho sản phẩm iPhone 15 Pro Max 256GB). 

Nếu chỉ áp dụng các kỹ thuật tìm kiếm từ khóa truyền thống (Full-text Search dựa trên từ vựng hoặc SQL `LIKE`/BM25 thuần túy), hệ thống sẽ gặp phải 2 hạn chế nghiêm trọng:
- *Hiện tượng bỏ lót kết quả (False Negatives):* Công cụ tìm kiếm từ vựng đòi hỏi sự trùng khớp chính xác về ký tự giữa từ khóa truy vấn và văn bản mô tả. Khi người mua truy vấn "điện thoại Apple cũ giá rẻ", hệ thống truyền thống sẽ bỏ qua các sản phẩm mô tả là "iPhone 13 thanh lý lên đời" do không trùng từ khóa "điện thoại Apple".

=== Tìm kiếm ngữ nghĩa (Semantic Search) với mô hình embedding\ bge-m3
Để khắc phục rào cản trên, hệ thống ứng dụng công nghệ Tìm kiếm Ngữ nghĩa (Semantic Search) dựa trên biểu diễn không gian embedding. Khi một sản phẩm được tạo mới hoặc cập nhật tại `Catalog Service`, toàn bộ tiêu đề, mô tả và thuộc tính mặt hàng được truyền qua mô hình học sâu bge-m3 (BAAI General Embedding M3) để tạo ra các vector đặc trưng [3].

Mô hình bge-m3 được lựa chọn nhờ năng lực kiến trúc vượt trội, hỗ trợ tạo ra biểu diễn lai (Hybrid Representation) đồng thời trong một lần suy luận:
- *Embedding dày đặc (Dense Embedding):* Là một vector 1024 chiều ($v in R^1024$). Vector này đóng gói toàn bộ ngữ nghĩa sâu xa và ý định của văn bản, đưa các khái niệm có ý nghĩa tương đồng lại gần nhau trong không gian vector. Nhờ đó, truy vấn "áo giữ ấm mùa đông" có thể tính toán khoảng cách rất gần với sản phẩm "áo khoác len cổ lọ dày dặn".
- *Embedding thưa (Sparse Embedding / Lexical Weights):* Sinh ra trọng số cho các từ vựng xuất hiện trong câu tương tự thuật toán BM25 [10]. Biểu diễn thưa này rất quan trọng trong thương mại điện tử vì nó giữ lại độ chính xác tuyệt đối cho các thông số kỹ thuật, mã model sản phẩm (như "RTX 4090", "M3 Max") - những từ khóa chuyên ngành rất dễ bị "hòa tan" và mất độ nét nếu chỉ dùng vector dày đặc.

=== Cơ sở dữ liệu vector pgvector và thuật toán kết hợp lai (Hybrid Search)
Thay vì phải vận hành thêm một hệ quản trị cơ sở dữ liệu vector độc lập (như Milvus, Pinecone hay Qdrant), điều sẽ làm tăng chi phí hạ tầng và phát sinh độ phức tạp lớn trong việc duy trì các pipeline bộ dữ liệu ETL từ cơ sở dữ liệu chính, ta sử dụng trực tiếp phần mở rộng mã nguồn mở pgvector được cài đặt ngay bên trong PostgreSQL của `Catalog Service` [11].

Việc tích hợp pgvector cho phép thực thi chiến lược Tìm kiếm lai trong một lệnh truy vấn duy nhất (Single-query Hybrid Retrieval) với các ưu điểm kỹ thuật:
- *Chỉ mục HNSW tốc độ cao:* Các embedding 1024 chiều của sản phẩm được lưu trữ và đánh chỉ mục bằng thuật toán HNSW (Hierarchical Navigable Small World). Chỉ mục cấu trúc đồ thị nhiều lớp này cho phép thực hiện tìm kiếm ANN (Approximate Nearest Neighbors — tìm lân cận gần nhất gần đúng) với độ phức tạp thời gian chỉ ở mức đối số $O(log N)$.
- *Thuật toán rank fusion (xếp hạng dung hợp — Reranking & Fusion):* Điểm số liên quan cuối cùng của mỗi mặt hàng được tính bằng thuật toán kết hợp trọng số, cân bằng giữa điểm số khớp từ khóa (Sparse/Full-text), khoảng cách ngữ nghĩa Cosine (Dense), và điểm uy tín người bán, tạo ra danh sách kết quả vừa chính xác về thông số vừa thấu hiểu nhu cầu ngữ nghĩa của người mua.

== Lựa chọn công nghệ

Hệ thống được xây dựng theo kiến trúc đa thành phần, trong đó mỗi thành phần được lựa chọn ngôn ngữ và công nghệ phù hợp với đặc thù bài toán riêng.

  columns: (1.2fr, 1.8fr, 2.5fr),
  align: (center, center, left),
  [Tầng / Lớp], [Công Nghệ], [Mục Đích Sử Dụng],
  [Backend Services], [Go], [Phát triển các core services, API gateway quản lý WebSocket, background workers và tận dụng lợi thế static binary.],
  [Frontend Web], [Next.js, React, TypeScript], [Xây dựng giao diện web theo kiến trúc App Router, hỗ trợ SSR/SSG với strict mode của TypeScript.],
  [Frontend Mobile], [Flutter], [Phát triển ứng dụng di động cross-platform (Android và iOS) dùng chung một codebase.],
  [Database & Search], [PostgreSQL, TimescaleDB, pgvector], [Lưu trữ relational data, time-series (metrics) và hỗ trợ semantic/hybrid search không cần vector DB ngoài.],
  [In-Memory Caching], [Redis], [Quản lý user session và caching dữ liệu truy vấn nóng để tối ưu performance.],
  [Event Bus & Stream], [NATS JetStream], [Giao tiếp pub/sub bất đồng bộ, streaming dữ liệu realtime và làm metrics bus.],
  [Durable execution], [Restate], [Cung cấp runtime chuyên biệt để quản lý các durable workflow phân tán và luồng tài chính dài hạn.],
  [Test & Deployment], [Prism, Docker Compose], [Mocking API contract; container hóa môi trường dev và chạy production image với quyền non-root.],
)

