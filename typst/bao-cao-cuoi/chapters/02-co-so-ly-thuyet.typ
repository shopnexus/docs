= CƠ SỞ LÝ THUYẾT

== Kiến trúc Hướng dịch vụ (SOA) và mô hình Microservices

=== Nguyên lý của Kiến trúc Hướng dịch vụ (Service-Oriented Architecture)
Kiến trúc Hướng dịch vụ (SOA - Service-Oriented Architecture) là một mô hình thiết kế và phân rã hệ thống phần mềm trong đó các năng lực nghiệp vụ phức tạp được xây dựng từ các khối chức năng tự chứa, độc lập gọi là dịch vụ (services). Mỗi dịch vụ thực hiện một tác vụ nghiệp vụ có ranh giới rõ ràng, không phụ thuộc vào cấu trúc lập trình nội bộ của các dịch vụ khác và giao tiếp thông qua các giao diện (interfaces) cùng hợp đồng dịch vụ (service contracts) chuẩn hóa qua mạng.

Nguyên lý cốt lõi của SOA là tính độc lập và ghép nối lỏng giữa các thành phần (Loose Coupling): các dịch vụ hạn chế tối đa sự phụ thuộc trực tiếp vào nhau, nên khi logic xử lý nội bộ hoặc cấu trúc dữ liệu riêng của một dịch vụ thay đổi thì các dịch vụ tiêu thụ (consumer services) không bị ảnh hưởng, miễn là hợp đồng API công khai (REST/gRPC/OpenAPI) vẫn được giữ nguyên [8].

=== Mô hình Microservices và Triết lý Database-per-service
Microservices là bước tiến hóa hiện đại và thực dụng của kiến trúc SOA, trong đó hệ thống được chia thành nhiều dịch vụ, mỗi dịch vụ ánh xạ trực tiếp với một miền con nghiệp vụ cụ thể theo phương pháp Thiết kế Hướng miền (Domain-Driven Design - DDD).

Khác với kiến trúc khối liền (Monolithic) truyền thống, nơi toàn bộ các module nghiệp vụ phải chia sẻ chung một hệ quản trị cơ sở dữ liệu quan hệ khổng lồ, mô hình Microservices trong đề tài này áp dụng triệt để nguyên lý Database-per-service, tức mỗi dịch vụ một cơ sở dữ liệu độc lập. Dữ liệu được cô lập tuyệt đối: mỗi vi dịch vụ sở hữu và quản lý độc lập một schema hoặc một instance cơ sở dữ liệu riêng biệt [9]. Nghiêm cấm việc truy cập dữ liệu chéo: không một dịch vụ hay module nào được phép truy cập trực tiếp vào bảng dữ liệu SQL của dịch vụ khác, mọi nhu cầu truy xuất hoặc đồng bộ thông tin liên miền đều phải thực hiện qua lời gọi hàm từ xa (Remote Procedure Call - RPC) hoặc qua việc lắng nghe sự kiện nghiệp vụ bất đồng bộ (Domain Events).


Cách cô lập dữ liệu này còn mang lại lợi thế chiến lược về Polyglot Persistence (Đa dạng hóa công nghệ lưu trữ). Hệ thống không bị ép buộc phải sử dụng một giải pháp cơ sở dữ liệu duy nhất cho mọi bài toán mà có thể tự do lựa chọn công nghệ lưu trữ tối ưu nhất cho đặc thù của từng vi dịch vụ.

== Durable execution trong hệ thống phân tán

=== Thách thức của giao dịch phân tán và giới hạn của mô hình Saga truyền thống
Trong một kiến trúc Microservices tuân thủ Database-per-service, thách thức kỹ thuật phức tạp nhất là duy trì tính nhất quán dữ liệu cho một quy trình nghiệp vụ dài hạn (Long-running Business Process) trải dài qua nhiều dịch vụ. Ví dụ, trong quy trình đặt hàng và ký quỹ, luồng thực thi phải tuần tự đi qua nhiều bước: 
#block(breakable: false)[
  1. Kiểm tra tính hợp lệ và khóa trạng thái sản phẩm tại `Catalog Service`
  2. Tạo hóa đơn tại `Order Service`
  3. Khởi tạo phiên giao dịch trên cổng thanh toán bên ngoài
  4. Khóa dòng tiền vào ví ký quỹ tại `Account Service`
  5. Thiết lập bộ đếm thời gian 72 giờ chờ người mua xác nhận nhận hàng.
]

Nếu sử dụng mẫu thiết kế Saga (Choreography hoặc Orchestration) truyền thống, các kỹ sư phần mềm phải đối mặt với một gánh nặng phát triển cực lớn. Trước hết là việc lập trình thủ công các hàm bù trừ: phải tự viết mã cho từng hàm thực thi xuôi (Action) kèm hàm bù trừ ngược (Compensation Action) tương ứng cho từng module, để hoàn tác dữ liệu khi có lỗi xảy ra giữa chừng [4]. Kế đó là xử lý rủi ro của hệ thống phân tán: khi gặp sự cố hạ tầng như mất kết nối mạng chập chờn, lỗi timeout, server bị khởi động lại hoặc tin nhắn hàng đợi bị gửi lặp lại (duplicate delivery), logic xử lý lỗi trong Saga thường phình to gấp nhiều lần mã nghiệp vụ chính, dễ gây sai lệch dòng tiền hoặc lặp giao dịch [6].

=== Khái niệm Durable execution và triết lý Journal-based Execution
Để khắc phục triệt để các nhược điểm của Saga mà không làm tăng độ phức tạp của mã nguồn nghiệp vụ, dự án lựa chọn mô hình durable execution. Đây là mô hình lập trình trong đó nền tảng thực thi đảm bảo một hàm nghiệp vụ có thể chạy liên tục đến khi hoàn thành, tự động tạm dừng khi chờ sự kiện ngoại vi và tự động phục hồi về đúng trạng thái trước khi lỗi xảy ra nếu máy chủ bị sập.

Cơ chế cốt lõi của durable execution dựa trên triết lý Journal-based Execution, nó sẽ thực thi dựa trên nhật ký đã ghi trước: thay vì để mã ứng dụng tự quản lý trạng thái, một lớp điều phối trung gian (Durable Engine) đứng ra chặn (intercept) và quản lý toàn bộ các thao tác vào/ra (I/O operations) của hàm nghiệp vụ, bao gồm lời gọi RPC sang dịch vụ khác, đặt hẹn giờ (timer/sleep) hoặc đọc ghi biến trạng thái.

=== Nền tảng Restate: Quản lý trạng thái, phục hồi lỗi và ngữ nghĩa Exact-once
Hệ thống tích hợp nền tảng mã nguồn mở Restate làm máy chủ điều phối durable execution (Stateful RPC Proxy & Durable Execution Engine). Restate mang lại hai năng lực quan trọng cho các dịch vụ cốt lõi. Thứ nhất là tự động phục hồi sau lỗi (Crash Recovery và Replay). Khi một tiến trình dịch vụ đang xử lý giao dịch Ký quỹ bị ngắt đột ngột (do crash ứng dụng, mất mạng hoặc nâng cấp máy chủ), Restate sẽ lập tức phát hiện và tự động điều phối khởi chạy lại hàm nghiệp vụ đó trên một node máy chủ khỏe mạnh khác. Quá trình phục hồi diễn ra qua cơ chế Replay (Phát lại nhật ký): Restate duyệt qua đoạn code từ đầu, nhưng đối với các bước I/O đã có kết quả trong nhật ký, Restate lập tức trả về kết quả cũ trong thời gian ngắn mà không hề kích hoạt lại lời gọi thực tế ra bên ngoài. Luồng code tiếp tục chạy mượt mà từ chính điểm dừng gần nhất, loại bỏ hoàn toàn việc phải lập trình hàm bù trừ (Compensation) thủ công [12]. Thứ hai là bảo đảm tính idempotent (lũy đẳng) tuyệt đối, tức ngữ nghĩa Exact-once: Restate tự động quản lý các idempotency key gắn với từng ngữ cảnh thực thi. Nếu client gửi lại một yêu cầu đặt hàng nhiều lần do nghẽn mạng, Restate nhận diện khóa giao dịch và ngăn chặn việc thực thi lặp lại luồng mutation bên trong, bảo đảm mỗi lệnh thay đổi dòng tiền chỉ diễn ra đúng một lần duy nhất [5].

== Giao tiếp liên dịch vụ (Inter-service Communication) và xử lý sự kiện

Hệ thống thiết lập một mô hình giao tiếp lai 3 tầng (3-tier Hybrid Communication Model), kết hợp giữa định tuyến Lệnh/Truy vấn (CQRS-like Routing), cơ chế tín hiệu bền vững và kiến trúc hướng sự kiện, nhằm đạt sự cân bằng tối ưu giữa độ trễ thời gian thực và độ tin cậy tuyệt đối cho dữ liệu.

=== Phân luồng giao tiếp theo mô hình Lệnh/Truy vấn (CQRS-like Routing)
Để tận dụng tối đa năng lực phục hồi lỗi của Restate mà không làm hy sinh hiệu năng của các tác vụ truy vấn dữ liệu thông thường, hệ thống phân luồng giao tiếp API thành hai đường riêng biệt.

Luồng lệnh, tức các thao tác ghi (Mutations), đi qua Restate Ingress Proxy. Mọi yêu cầu làm thay đổi trạng thái của hệ thống (side effects) đều bắt buộc phải qua cổng này: Restate Ingress gắn khóa `idempotency-key` từ header để chống lặp giao dịch, ghi nhận yêu cầu vào nhật ký (Write-Ahead Log), rồi mới điều hướng lời gọi RPC vào hàm bền vững (Durable Function) của microservice tương ứng.

Luồng truy vấn, tức các thao tác đọc (Queries), đi thẳng bằng HTTP/2 RPC từ API Gateway hoặc giao diện người dùng vào các microservice, hoàn toàn bỏ qua lớp Restate Ingress. Lý do là mỗi lần chuyển tiếp (hop) qua Ingress để theo dõi trạng thái và ghi nhật ký đều làm phát sinh độ trễ trung gian; với các tác vụ đọc dữ liệu chiếm tần suất cao nhất hệ thống nhưng không làm thay đổi trạng thái, việc bỏ qua Ingress giúp hạ độ trễ phản hồi và loại bỏ thuế hiệu năng (durability tax) không cần thiết.

=== Cơ chế điều hướng và đánh thức luồng bất đồng bộ với Restate Ingress
Ngoài cơ chế trì hoãn thực thi theo thời gian (`sleep`), Restate Ingress còn cung cấp cơ chế đánh thức bất đồng bộ (Awakables hay Promise Signaling) nhằm hỗ trợ phối hợp giữa các luồng nghiệp vụ. Trong quy trình ký quỹ hoặc tranh chấp, quy trình nghiệp vụ thường phải tạm dừng để chờ một sự kiện xác nhận từ hệ thống bên ngoài (ví dụ: chờ webhook từ cổng thanh toán xác nhận đã nạp tiền, hoặc chờ webhook từ đối tác vận chuyển báo đã giao hàng thành công). Restate cung cấp nguyên hàm Awakable - một đối tượng tương đương với Promise phân tán có định danh duy nhất. Luồng code gọi `ctx.awakable()` để tạo định danh và tạm dừng thực thi; khi hệ thống ngoại vi gửi webhook về Ingress kèm định danh này, Ingress lập tức giải phóng Awakable, "đánh thức" (resume) chính xác luồng đang ngủ và tiếp tục xử lý giải ngân.

=== Kiến trúc hướng sự kiện (Event-Driven) với NATS JetStream
Đối với các thao tác phối hợp hậu kỳ sau khi một giao dịch mutation đã hoàn tất thành công, hệ thống áp dụng Kiến trúc Hướng sự kiện (Event-Driven Architecture) nhằm giảm độ ghép nối giữa các module. NATS JetStream được chọn làm trục sự kiện trung tâm (Event Bus) vì cung cấp đầy đủ các tính năng cần thiết: lưu trữ sự kiện bền vững trên đĩa (Persistence), phân phối theo nhóm tiêu thụ (Consumer Groups) để cân bằng tải, và khả năng phát lại tin nhắn (Message Replay) khi có dịch vụ mới tham gia.

Về thông báo và dữ liệu thời gian thực, module Account lắng nghe một số sự kiện đơn hàng để tạo thông báo và lưu vào cơ sở dữ liệu. Đối với các sự kiện cần đẩy tức thời đến người dùng, hệ thống phát sự kiện qua Core NATS theo subject riêng của từng tài khoản, để các gateway đang giữ kết nối WebSocket nhận và chuyển tiếp đến client. Kênh truyền tải này mang tính chất best-effort (không đảm bảo tuyệt đối), do đó khi client mất kết nối và kết nối lại, trạng thái chính thức luôn được đồng bộ lại thông qua API.

== Tìm kiếm thông tin dựa trên từ khóa và ngữ nghĩa (Hybrid Search)

=== Tìm kiếm từ khóa truyền thống và các hạn chế trong TMĐT C2C
Trong các sàn thương mại điện tử, sản phẩm được đăng bán bởi các cá nhân không chuyên. Ngôn ngữ mô tả mặt hàng thanh lý thường có tính tự do cao, sử dụng nhiều từ viết tắt, từ lóng, sai chính tả hoặc cấu trúc câu không theo quy chuẩn (ví dụ: "tl ip 15 prm 256 gb zin keng" cho sản phẩm iPhone 15 Pro Max 256GB). 

Nếu chỉ áp dụng các kỹ thuật tìm kiếm từ khóa truyền thống (Full-text Search dựa trên từ vựng hoặc SQL `LIKE`/BM25 thuần túy), hệ thống sẽ gặp hiện tượng bỏ lọt kết quả (False Negatives). Công cụ tìm kiếm từ vựng đòi hỏi sự trùng khớp chính xác về ký tự giữa từ khóa truy vấn và văn bản mô tả. Khi người mua truy vấn "điện thoại Apple cũ giá rẻ", hệ thống truyền thống sẽ bỏ qua các sản phẩm mô tả là "iPhone 13 thanh lý lên đời" do không trùng từ khóa "điện thoại Apple".

=== Tìm kiếm ngữ nghĩa (Semantic Search) với mô hình embedding\ bge-m3
Để khắc phục rào cản trên, hệ thống ứng dụng công nghệ Tìm kiếm Ngữ nghĩa (Semantic Search) dựa trên biểu diễn không gian embedding. Khi một sản phẩm được tạo mới hoặc cập nhật tại `Catalog Service`, toàn bộ tiêu đề, mô tả và thuộc tính mặt hàng được truyền qua mô hình học sâu bge-m3 (BAAI General Embedding M3) để tạo ra các vector đặc trưng [3].

Mô hình bge-m3 được lựa chọn nhờ năng lực kiến trúc vượt trội, hỗ trợ tạo ra biểu diễn lai (Hybrid Representation) đồng thời trong một lần suy luận. Embedding dày đặc (Dense Embedding) là một vector 1024 chiều ($v in R^1024$). Vector này đóng gói toàn bộ ngữ nghĩa sâu xa và ý định của văn bản, đưa các khái niệm có ý nghĩa tương đồng lại gần nhau trong không gian vector. Nhờ đó, truy vấn "áo giữ ấm mùa đông" có thể tính toán khoảng cách rất gần với sản phẩm "áo khoác len cổ lọ dày dặn". Embedding thưa (Sparse Embedding hay Lexical Weights) sinh ra trọng số cho các từ vựng xuất hiện trong câu tương tự thuật toán BM25 [10]. Biểu diễn thưa này rất quan trọng trong thương mại điện tử vì nó giữ lại độ chính xác tuyệt đối cho các thông số kỹ thuật, mã model sản phẩm (như "RTX 4090", "M3 Max") - những từ khóa chuyên ngành rất dễ bị "hòa tan" và mất độ nét nếu chỉ dùng vector dày đặc.

=== Cơ sở dữ liệu vector pgvector và thuật toán kết hợp lai (Hybrid Search)
Thay vì phải vận hành thêm một hệ quản trị cơ sở dữ liệu vector độc lập (như Milvus, Pinecone hay Qdrant), điều sẽ làm tăng chi phí hạ tầng và phát sinh độ phức tạp lớn trong việc duy trì các pipeline bộ dữ liệu ETL từ cơ sở dữ liệu chính, ta sử dụng trực tiếp phần mở rộng mã nguồn mở pgvector được cài đặt ngay bên trong PostgreSQL của `Catalog Service` [11].

Việc tích hợp pgvector cho phép thực thi chiến lược Tìm kiếm lai trong một lệnh truy vấn duy nhất (Single-query Hybrid Retrieval) với hai ưu điểm kỹ thuật. Chỉ mục HNSW cho tốc độ cao: các embedding 1024 chiều của sản phẩm được lưu trữ và đánh chỉ mục bằng thuật toán HNSW (Hierarchical Navigable Small World). Chỉ mục cấu trúc đồ thị nhiều lớp này cho phép thực hiện tìm kiếm ANN (Approximate Nearest Neighbors, tìm lân cận gần nhất gần đúng) với độ phức tạp thời gian chỉ $O(log N)$. Thuật toán rank fusion (xếp hạng dung hợp) quyết định thứ tự cuối cùng: điểm số liên quan cuối cùng của mỗi mặt hàng được tính bằng thuật toán kết hợp trọng số, cân bằng giữa điểm số khớp từ khóa (Sparse/Full-text), khoảng cách ngữ nghĩa Cosine (Dense), và điểm uy tín người bán, tạo ra danh sách kết quả vừa chính xác về thông số vừa thấu hiểu nhu cầu ngữ nghĩa của người mua.

== Lựa chọn công nghệ

Hệ thống được xây dựng theo kiến trúc đa thành phần, trong đó mỗi thành phần được lựa chọn ngôn ngữ và công nghệ phù hợp với đặc thù bài toán riêng.

#table(
  columns: (1.2fr, 1.8fr, 2.8fr),
  align: (center, center, left),
  [Tầng / Lớp], [Công Nghệ], [Mục Đích Sử Dụng],
  [Backend Services], [Go], [Phát triển các core services, API gateway quản lý WebSocket, background workers và tận dụng lợi thế static binary.],
  [Frontend Web], [Next.js, React, TypeScript], [Xây dựng giao diện web theo kiến trúc App Router, hỗ trợ SSR/SSG với strict mode của TypeScript.],
  [Frontend Mobile], [Flutter], [Phát triển ứng dụng di động cross-platform (Android và iOS) dùng chung một mã nguồn.],
  [Database & Search], [PostgreSQL, TimescaleDB, pgvector], [Lưu trữ relational data, time-series (metrics) và hỗ trợ semantic/hybrid search không cần vector DB ngoài.],
  [In-Memory Caching], [Redis], [Quản lý user session và caching dữ liệu truy vấn nóng để tối ưu performance.],
  [Event Bus & Stream], [NATS JetStream], [Giao tiếp pub/sub bất đồng bộ, streaming dữ liệu realtime và làm metrics bus.],
  [Durable execution], [Restate], [Cung cấp runtime chuyên biệt để quản lý các durable workflow phân tán và luồng nghiệp vụ dài hạn.],
  [Test & Deployment], [Prism, Docker Compose], [Mocking API contract; container hóa môi trường dev và chạy production image với quyền non-root.],
)

=== Lý giải lựa chọn stack công nghệ

Mỗi công nghệ trong stack đều có lựa chọn thay thế phổ biến hơn. Thay vì so sánh từng tiêu chí một, phần này tập trung nêu lý do chính khiến nhóm chọn từng công nghệ cho bối cảnh dự án.

- *Go cho Backend:* Go được lựa chọn nhờ khả năng tích hợp tốt với Restate, nền tảng đảm nhiệm cơ chế durable execution cho các quy trình nghiệp vụ dài hạn và nhiều trạng thái như Order, Escrow và Dispute. SDK Go chính thức của Restate hỗ trợ lưu trạng thái, phục hồi và tiếp tục thực thi khi xảy ra sự cố, giúp giảm đáng kể độ phức tạp khi hiện thực các luồng nghiệp vụ bền vững. Bên cạnh đó, Go có thời gian khởi động nhanh, mức tiêu thụ tài nguyên thấp và mô hình goroutine nhẹ, phù hợp với kiến trúc microservices và khả năng mở rộng theo chiều ngang trên Kubernetes.

- *Next.js cho Frontend Web:* Next.js được lựa chọn nhằm đáp ứng yêu cầu SEO cho các trang công khai như danh mục và chi tiết sản phẩm. So với SPA thuần sử dụng React và Vite, Next.js hỗ trợ SSR và SSG, giúp nội dung được lập chỉ mục hiệu quả hơn, đồng thời cung cấp routing theo cấu trúc thư mục và tự động phân tách mã theo route.

- *Flutter cho Mobile:* Flutter được lựa chọn để phát triển ứng dụng đa nền tảng từ một codebase duy nhất, phù hợp với giới hạn về nhân lực và thời gian của dự án. Thay vì duy trì riêng hai ứng dụng native bằng Swift và Kotlin, Flutter cho phép chia sẻ phần lớn mã nguồn giữa iOS và Android, qua đó giảm khối lượng phát triển và bảo trì. Cơ chế rendering riêng cũng giúp giao diện duy trì tính nhất quán và hiệu năng phù hợp trên cả hai nền tảng.

- *PostgreSQL làm CSDL chính:* PostgreSQL được lựa chọn do các miền nghiệp vụ như Order, Escrow và Wallet có quan hệ dữ liệu chặt chẽ và yêu cầu tính nhất quán cao. Hệ quản trị này hỗ trợ đầy đủ ACID, transaction đa bảng, khóa mức dòng và các cơ chế ràng buộc dữ liệu phù hợp với nghiệp vụ thanh toán và ký quỹ. Đồng thời, `JSONB` cho phép lưu trữ các thuộc tính có cấu trúc linh hoạt mà không cần bổ sung một cơ sở dữ liệu document riêng.

- *pgvector và bge-m3 cho tìm kiếm:* `pgvector` được sử dụng để triển khai tìm kiếm vector trực tiếp trên PostgreSQL, tránh phải vận hành thêm một vector database độc lập như Milvus ở quy mô hiện tại. Giải pháp này cho phép lưu embedding cùng dữ liệu nghiệp vụ và kết hợp tìm kiếm vector với các điều kiện lọc như danh mục, giá hoặc trạng thái sản phẩm. Mô hình `bge-m3` hỗ trợ các biểu diễn phục vụ cả tìm kiếm ngữ nghĩa và tìm kiếm dựa trên từ khóa. Khi quy mô dữ liệu tăng đáng kể, hệ thống có thể cân nhắc chuyển sang một vector database chuyên dụng.

- *NATS JetStream làm Event Bus:* NATS JetStream được lựa chọn để truyền tải sự kiện bất đồng bộ và đồng bộ trạng thái giữa các service. Với nhu cầu chủ yếu là phân phối thông báo, cập nhật trạng thái và trao đổi sự kiện miền, hệ thống chưa cần đến một nền tảng event streaming phức tạp như Kafka/RabbitMQ. JetStream có kiến trúc gọn nhẹ nhưng vẫn hỗ trợ persistence, acknowledgement và replay sự kiện. Các tác vụ chờ dài hạn như thời hạn Escrow được giao cho durable timer của Restate thay vì phụ thuộc vào message broker.

- *Redis cho caching:* Redis được lựa chọn làm lớp bộ nhớ đệm nhằm giảm số lần truy vấn trực tiếp đến cơ sở dữ liệu và cải thiện thời gian phản hồi của hệ thống. So với cache nội bộ trong từng service, Redis cung cấp vùng cache dùng chung giữa nhiều replica, phù hợp với kiến trúc microservices khi hệ thống mở rộng theo chiều ngang.