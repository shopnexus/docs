#import "../../../common/tokens.typ": *

= KHẢO SÁT VÀ CƠ SỞ LÝ THUYẾT
== Khảo sát hiện trạng

=== Các sàn mua bán đồ cũ hiện có

- Chợ Tốt: Hệ thống này tổ chức thông tin theo hình thức tin đăng với hình ảnh, mô tả và các nhóm danh mục. Phạm vi hàng hóa đa dạng, trong đó có những mặt hàng đã qua sử dụng như đồ điện tử, phương tiện và đồ dùng cá nhân. Cách tổ chức theo danh mục và khu vực giúp người bán giới thiệu sản phẩm, đồng thời tạo điểm tiếp cận cho người mua có nhu cầu tương ứng.

- Facebook Marketplace: Là 1 dịch vụ được tích hợp vào ứng dụng Facebook cung cấp không gian xem và đăng các mặt hàng, với thông tin như hình ảnh, giá và địa điểm. Cho phép khám phá hàng hóa theo danh mục và vị trí địa lý gần với người dùng. Hệ thống này được thiết kế để người mua tương tác trực tiếp với người bán và đề nghị mức giá trực tiếp qua một nền tảng chung, qua đó thể hiện cách tiếp cận kết nối trực tiếp các cá nhân.

// Facebook Marketplace là trường hợp tham khảo cho việc kết hợp tin đăng với trao đổi giữa người mua và người bán. Tuy nhiên, tài liệu giới thiệu không đủ để khẳng định chính sách thanh toán và giao nhận hiện hành tại Việt Nam. Do tính năng có thể khác theo thị trường và thời điểm, phần so sánh chỉ sử dụng các đặc điểm có căn cứ công khai, không mặc định mọi tài khoản đều có cùng chức năng. TODO:. ..

=== So sánh và định hướng của đề tài

Hai nền tảng trên cho thấy tin đăng, phân loại sản phẩm và khả năng kết nối người mua với người bán là những thành phần cơ bản của giao dịch hàng đã qua sử dụng. Hệ thống kế thừa các nhu cầu này, đồng thời lựa chọn phạm vi nghiên cứu tập trung vào sự liên kết giữa các bước giao dịch và khả năng hỗ trợ khai thác thông tin.

#figure(
  table(
    columns: (1fr, 1.6fr, 1.8fr),
    align: left,
    table.header([Tiêu chí], [Đặc điểm tham khảo], [Định hướng của đề tài]),
    [Thông tin sản phẩm], [Tin đăng có hình ảnh, mô tả, giá và phân loại hàng hóa.], [Tổ chức dữ liệu tin đăng phù hợp với đặc thù từng món hàng đã qua sử dụng.],
    [Tiếp cận sản phẩm], [Khám phá theo danh mục và khu vực; người mua xem thông tin trước khi liên hệ.], [Nghiên cứu tìm kiếm từ khóa kết hợp ngữ nghĩa và diễn giải nhu cầu bằng ngôn ngữ tự nhiên.],
    [Trao đổi và giao dịch], [Kết nối người mua với người bán trong trên cùng một nền tảng.], [Nền tảng hỗ trợ kết nối, giao tiếp, thương lượng, đặt hàng, vận chuyển, đánh giá và xử lý khiếu nại trong một quy trình xuyên suốt, được tích hợp trên cùng một hệ thống.],
    [Thông tin sau giao dịch], [ Đánh giá người bán và lịch sử giao dịch là cơ sở để người mua tham khảo trước khi quyết định mua hàng.], [Gắn đánh giá và thông tin uy tín với lịch sử giao dịch của hệ thống.],
    [Hỗ trợ sử dụng và vận hành], [Tài liệu công khai chưa đủ để đánh giá công cụ nội bộ của các nền tảng.], [Nghiên cứu AI Agent, LLM để hỗ trợ nhân sự quản lý hệ thống và người dùng tìm kiếm bằng ngôn ngữ tự nhiên.],
  ),
  caption: [Đối chiếu các đặc điểm tham khảo và định hướng của ShopNexus],
)

== Mô hình nghiệp vụ

=== Mô hình C2C

C2C (Consumer to Consumer) là mô hình giao dịch giữa các cá nhân thông qua một nền tảng trung gian. Người bán cung cấp thông tin sản phẩm và tiếp nhận đề nghị mua; người mua tìm kiếm, trao đổi và quyết định giao dịch. Khác với mô hình doanh nghiệp bán hàng cho người tiêu dùng, nguồn hàng trong C2C đến từ nhiều cá nhân, có mức độ chuẩn hóa thông tin và tần suất bán khác nhau. Một người có thể đồng thời mua và bán mà không cần hai loại tài khoản riêng.

Đối với hàng đã qua sử dụng, mỗi món hàng thường có đặc điểm riêng về tình trạng, phụ kiện và lịch sử sử dụng. Tin đăng vì vậy cần thể hiện không chỉ tên và giá mà còn hình ảnh, mô tả và thông số liên quan. Quy trình mua bán cũng có thể bao gồm bước hỏi thêm thông tin và thương lượng trước khi đặt hàng. Nền tảng cần liên kết phiên trao đổi với tin đăng và đơn hàng để các bên theo dõi được nội dung đã thỏa thuận.

Trong hệ thống, tin đăng, thương lượng và đơn hàng được xem là các đối tượng có vòng đời riêng. Việc đồng ý một mức giá chưa đồng nghĩa với giữ hàng cho người mua. Khi nhiều người quan tâm đến cùng một món hàng, hệ thống cần kiểm soát thời điểm giữ tin và xử lý các yêu cầu cạnh tranh để tránh đưa cùng một sản phẩm vào nhiều giao dịch giao nhận đồng thời. Sự phân biệt này là cơ sở thiết kế trạng thái và kiểm soát thao tác đồng thời trong các chương sau.

=== Giao hàng thu tiền hộ và đồng kiểm

Giao hàng thu tiền hộ (Cash on Delivery - COD) là hình thức đơn vị vận chuyển thu tiền của người nhận khi giao hàng, sau đó đối soát và chuyển tiền theo thỏa thuận dịch vụ với người gửi. COD liên quan đến cả luồng giao nhận và luồng thu hộ; trạng thái giao thành công cần được phân biệt với thời điểm tiền được đối soát về tài khoản người bán.

Đồng kiểm là việc kiểm tra hàng khi nhận, trước khi quyết định thanh toán, trong phạm vi chính sách của đơn vị vận chuyển. Nội dung được kiểm tra, khả năng mở kiện hoặc thử sản phẩm phụ thuộc vào loại hàng và cấu hình dịch vụ. Do đó, không thể mặc định rằng đồng kiểm cho phép kiểm tra đầy đủ mọi chức năng hoặc loại bỏ hoàn toàn rủi ro của hàng đã qua sử dụng.

Luồng nghiệp vụ cơ bản gồm xác nhận thông tin người nhận, tạo đơn, tạo vận đơn, bàn giao cho đơn vị vận chuyển, theo dõi quá trình giao hàng và ghi nhận kết quả. Các thao tác vận chuyển gắn với tài khoản bên thứ 3 của người bán; tiền thu hộ được hãng chuyển trực tiếp về người bán theo thỏa thuận tương ứng. Khi tích hợp API, hệ thống cần đối chiếu mã vận đơn, lưu thông tin liên kết và quy đổi trạng thái của từng hãng về trạng thái nghiệp vụ thống nhất.

=== Cơ chế uy tín và đánh giá

Trong giao dịch C2C, uy tín cung cấp thêm thông tin để cân nhắc trước khi mua bán. Cơ chế đánh giá cho phép người tham gia phản ánh trải nghiệm sau giao dịch, còn lịch sử hoạt động cung cấp các dấu hiệu như số giao dịch, mức độ phản hồi và tình trạng giao nhận giúp người mua có cái nhìn khách quan hơn trong giao dịch.

Đánh giá cần tham chiếu với giao dịch đủ điều kiện để hạn chế nhận xét không có căn cứ. Hệ thống cũng cần quy định người được đánh giá, thời điểm hiển thị, khả năng trả lời và giới hạn chỉnh sửa.

=== Mô tả tổng quan hệ thống

Hệ thống thương mại điện tử phục vụ mua bán hàng đã qua sử dụng giữa các cá nhân. Người dùng có thể đăng tin bán hàng kèm hình ảnh, mô tả và giá; tìm kiếm sản phẩm theo danh mục, tình trạng, mức giá và khu vực; trao đổi, thương lượng, tạo đơn COD và theo dõi giao nhận. Hệ thống ứng dụng tìm kiếm thông minh bằng LLM để hỗ trợ tìm kiếm bằng ngôn ngữ tự nhiên, đồng thời cung cấp AI agent hỗ trợ nhân sự quản lý tra cứu và tổng hợp thông tin khi xử lý yêu cầu.

Hệ thống phân quyền cho ba nhóm: Quản trị viên, điều phối viên và người dùng. Người dùng có thể vừa là người mua và vừa là người bán, quản lý tin đăng, trao đổi, theo dõi đơn hàng, đánh giá sau giao dịch và gửi yêu cầu hỗ trợ. Điều phối viên (moderator) tiếp nhận phiếu hỗ trợ, xử lý báo cáo vi phạm, quản lý nội dung và thực hiện khóa hoặc mở khóa tài khoản theo quyền được cấp. Quản trị viên (admin) có các quyền của điều phối viên, đồng thời quản lý tài khoản điều phối viên và tra cứu nhật ký thao tác. Tài khoản nhân sự được tách biệt với tài khoản mua bán thông thường.

Trong khuôn khổ đề tài, nhóm tập trung thực hiện các nhiệm vụ cốt lõi sau:

- Thiết kế dữ liệu lưu trữ tài khoản, tin đăng, hình ảnh, hội thoại, thương lượng, đơn hàng, vận đơn và đánh giá; xác định trách nhiệm quản lý dữ liệu của từng mô-đun nghiệp vụ.
- Xây dựng chức năng đăng và quản lý tin, tìm kiếm sản phẩm, trò chuyện, thương lượng giá, tạo đơn hàng và theo dõi trạng thái giao dịch.
- Tích hợp đơn vị vận chuyển để hỗ trợ liên kết tài khoản người bán, tra cứu phí, tạo hoặc hủy vận đơn và cập nhật kết quả giao nhận.
- Thiết kế ứng dụng Android và Website cho người mua, người bán và giao diện quản lý riêng trên Website cho điều phối viên, quản trị viên.
- Triển khai xác thực, quản lý phiên và phân quyền, bảo đảm mỗi đối tượng chỉ truy cập dữ liệu và chức năng phù hợp.
- Phát triển tìm kiếm kết hợp từ khóa và ngữ nghĩa, tích hợp LLM để diễn giải truy vấn từ ngôn ngữ tự nhiên thành điều kiện tìm kiếm sản phẩm.
- Tích hợp AI agent hỗ trợ nhân sự quản lý đọc hồ sơ, tóm tắt vụ việc và đề xuất hướng xử lý có dẫn chiếu dữ liệu. Agent chỉ đọc dữ liệu trong phạm vi được cấp; nhân sự phụ trách kiểm tra đề xuất và thực hiện thao tác quản lý.
- Xây dựng API cho các nghiệp vụ, tổ chức các thành phần theo ranh giới trách nhiệm và kiểm thử tính đúng đắn, nhất quán của các luồng xử lý.

== Cơ sở lý thuyết

=== Kiến trúc Microservices và nguyên lý Database-per-Service

Microservices là kiến trúc tổ chức ứng dụng thành các dịch vụ nhỏ, mỗi dịch vụ đảm nhận một nhóm nghiệp vụ riêng và giao tiếp với nhau thông qua các giao diện (API) được xác định rõ. Mỗi dịch vụ có thể được phát triển, triển khai và mở rộng tương đối độc lập. So với kiến trúc nguyên khối (monolithic), cách tổ chức này giúp thay đổi từng chức năng linh hoạt hơn, nhưng đồng thời làm tăng yêu cầu về giao tiếp qua mạng, xử lý lỗi và đồng bộ dữ liệu giữa các dịch vụ.

#figure(
  table(
    columns: (1fr, 1.7fr, 1.7fr),
    align: left,
    table.header([*Tiêu chí*], [*Monolithic*], [*Microservices*]),
    [Tổ chức ứng dụng], [Các mô-đun được tích hợp trong một đơn vị triển khai.], [Các dịch vụ được phân tách theo trách nhiệm nghiệp vụ.],
    [Triển khai], [Mỗi lần cập nhật phải xây dựng và triển khai lại toàn bộ ứng dụng.], [Từng dịch vụ có thể được triển khai độc lập.],
    [Mở rộng], [Nhân bản toàn bộ ứng dụng.], [Có thể mở rộng riêng các dịch vụ có nhu cầu tài nguyên và tải cao.],
    [Giao tiếp], [Gọi trực tiếp trong cùng tiến trình.], [Giao tiếp qua mạng bằng API, RPC hoặc sự kiện, cần xử lý độ trễ và lỗi kết nối.],
    [Quản lý dữ liệu], [Dùng chung một cơ sở dữ liệu, thuận lợi cho các giao dịch cục bộ.], [Mỗi dịch vụ quản lý dữ liệu riêng; nghiệp vụ liên quan đến nhiều dịch vụ khác cần cơ chế đảm bảo tính nhất quán.],
    [Phạm vi ảnh hưởng của lỗi], [Lỗi nghiêm trọng trong tiến trình có thể làm gián đoạn toàn bộ ứng dụng.], [Lỗi có thể được cô lập theo dịch vụ, nhưng vẫn có nguy cơ lan truyền qua các dịch vụ phụ thuộc.],
    [Kiểm thử và vận hành], [Thiết lập đơn giản, nhưng độ phức tạp tăng khi ứng dụng lớn dần.], [Cần kiểm thử tích hợp giữa các dịch vụ, giám sát phân tán và quản lý nhiều đơn vị triển khai.],
  ),
  caption: [So sánh kiến trúc Monolithic và Microservices],
)

Database-per-Service là nguyên lý mỗi dịch vụ sở hữu và quản lý dữ liệu thuộc phạm vi nghiệp vụ của mình. Các dịch vụ khác truy cập thông tin thông qua API, RPC hoặc sự kiện, không đọc hoặc ghi trực tiếp vào các bảng nội bộ của dịch vụ đó. Việc phân tách dữ liệu có thể thực hiện bằng bảng, schema hoặc cơ sở dữ liệu riêng kèm cơ chế phân quyền truy cập phù hợp, và không nhất thiết phải dùng máy chủ vật lý riêng. Nguyên lý này giúp giảm sự phụ thuộc về dữ liệu giữa các dịch vụ, nhưng đặt ra bài toán đảm bảo nhất quán cho các nghiệp vụ liên quan đến nhiều dịch vụ khác.
#pagebreak()
=== Mô hình giao tiếp hướng sự kiện

Trong mô hình hướng sự kiện, một thành phần phát thông báo về thay đổi đã xảy ra, còn các thành phần đăng ký nhận sẽ xử lý theo trách nhiệm của mình. Bên phát không cần biết toàn bộ bên nhận, nhờ đó giảm sự phụ thuộc trực tiếp và cho phép bổ sung các phản ứng mới mà ít ảnh hưởng đến nơi phát sinh thay đổi.

Khác với giao tiếp đồng bộ, nơi bên gọi chờ kết quả trước khi tiếp tục, giao tiếp bất đồng bộ cho phép bên nhận xử lý sau thời điểm sự kiện phát sinh. Sự kiện có thể được chuyển qua event bus hoặc message broker tùy cách triển khai. Thiết kế cần xét đến độ trễ, thứ tự nhận và khả năng giao tiếp lặp lại; bên nhận phải kiểm tra trạng thái phù hợp trước khi thực hiện các hàm nghiệp vụ.
#align(center)[
  #image("../../../common/assets/chuong2-image/event-driven.png", width: 100%)
]
=== Transactional Outbox và tính idempotent

Transactional Outbox là mẫu thiết kế lưu thay đổi nghiệp vụ và sự kiện tương ứng trong cùng một giao dịch cơ sở dữ liệu. Sau khi giao dịch hoàn tất, một tiến trình chuyển tiếp đọc các sự kiện đang chờ và gửi đến bên xử lý. Cách làm này tránh tình huống dữ liệu đã được cập nhật nhưng sự kiện bị mất do lỗi xảy ra giữa hai thao tác ghi và gửi.

Tiến trình chuyển tiếp có thể gửi lại sự kiện nếu chưa xác nhận được kết quả lần gửi trước. Vì vậy, bên nhận cần bảo đảm tính idempotent: xử lý lại cùng một thao tác không tạo thêm tác động ngoài kết quả hợp lệ đã có. Các biện pháp thường dùng gồm định danh yêu cầu hoặc sự kiện, ràng buộc duy nhất và kiểm tra trạng thái trước khi cập nhật. Outbox bảo đảm sự kiện được ghi cùng dữ liệu, còn idempotency giúp xử lý an toàn khi sự kiện hoặc yêu cầu được thực hiện lại.
#pagebreak()
=== Saga Pattern

Saga là mẫu thiết kế tổ chức một quy trình nghiệp vụ thành chuỗi giao dịch cục bộ. Mỗi giao dịch cập nhật dữ liệu trong phạm vi của một thành phần và được commit độc lập. Nếu quy trình không thể tiếp tục, các thao tác bù tương ứng được thực hiện để xử lý tác động của những bước đã hoàn thành theo quy tắc nghiệp vụ.

Saga có hai hình thức phối hợp phổ biến: choreography, trong đó các thành phần phản ứng với sự kiện; và orchestration, trong đó một bộ điều phối quản lý các bước thực hiện. Thao tác bù trừ là một giao dịch nghiệp vụ mới, không phải rollback các giao dịch đã commit và không nhất thiết khôi phục chính xác trạng thái ban đầu. Saga không bảo đảm tính cô lập như một giao dịch ACID duy nhất; vì vậy, hệ thống cần kiểm soát các trạng thái trung gian, đồng thời thiết kế cơ chế chịu lỗi và xử lý bù trừ an toàn.


=== Durable Execution

Durable Execution, hay thực thi bền vững, là cơ chế lưu tiến trình và kết quả các bước để quy trình có thể tiếp tục sau khi ứng dụng bị gián đoạn. Thay vì chạy lại mọi bước xử lý từ đầu, hệ thống sử dụng lịch sử đã ghi nhận để khôi phục trạng thái xử lý và tiếp tục những phần chưa hoàn thành.

Một quy trình cần tách rõ bước tương tác dữ liệu hoặc dịch vụ bên ngoài với phần quyết định nghiệp vụ. Các giá trị như định danh và thời gian phải được quản lý nhất quán khi chạy lại. Durable Execution hỗ trợ phục hồi và thử lại, nhưng không tự làm cho mọi tác động bên ngoài trở thành idempotent. Vì vậy, cơ chế này cần kết hợp với khoá định danh và xử lý bù trừ khi quy trình yêu cầu. Saga mô tả cách phối hợp và bù trừ nghiệp vụ, còn Durable Execution cung cấp cơ chế duy trì việc thực thi qua sự cố.

=== WebSocket và Server-Sent Events

WebSocket là giao thức duy trì kết nối hai chiều giữa ứng dụng khách và máy chủ, cho phép hai bên gửi dữ liệu mà không phải tạo một yêu cầu HTTP mới cho mỗi thông điệp. Đặc điểm này phù hợp với các chức năng như trò chuyện và thông báo thay đổi trạng thái.

Server-Sent Events (SSE) cung cấp luồng sự kiện một chiều từ máy chủ đến ứng dụng khách qua HTTP, phù hợp với việc hiển thị tiến trình hoặc phản hồi được gửi dần.

=== LLM, Hybrid Search và Image Search

Mô hình ngôn ngữ lớn (Large Language Model - LLM) có khả năng xử lý và sinh nội dung ngôn ngữ theo ngữ cảnh đầu vào. Trong tìm kiếm, LLM có thể diễn giải nhu cầu thành câu truy vấn hoặc các điều kiện như danh mục, khoảng giá và tình trạng sản phẩm, địa danh. Đầu ra cần được kiểm tra với dữ liệu hợp lệ; khi mô hình lỗi, hệ thống có thể sử dụng truy vấn gốc làm phương án dự phòng.

Hybrid Search kết hợp tìm kiếm từ khóa và tìm kiếm ngữ nghĩa. Nhánh từ khóa khai thác sự xuất hiện của từ trong nội dung, có thể xếp hạng bằng BM25; nhánh ngữ nghĩa so sánh các vector embedding của truy vấn và tài liệu. Hai cách tiếp cận bổ sung cho nhau khi người dùng cần khớp chính xác tên sản phẩm hoặc diễn đạt nhu cầu bằng những từ khác với tin đăng. Kết quả có thể được hợp nhất bằng Reciprocal Rank Fusion (RRF) dựa trên thứ hạng trong từng danh sách kết quả:

$ "RRF"(d) = sum_(i=1)^m frac(1, k + "rank"_i(d)) $


Image Search sử dụng ảnh làm đầu vào để tìm những hình ảnh hoặc sản phẩm có biểu diễn gần nhau. Đề tài sử dụng SigLIP2 cung cấp embedding ảnh và văn bản để hỗ trợ truy xuất giữa các loại dữ liệu. Tùy thiết kế, kết quả từ nhánh hình ảnh có thể được sử dụng riêng hoặc hợp nhất với các nhánh tìm kiếm khác. Dù truy xuất bằng văn bản hay ảnh, kết quả vẫn cần tuân thủ các điều kiện về trạng thái hiển thị, giá và danh mục.

=== AI Agent và Model Context Protocol

AI agent kết hợp mô hình ngôn ngữ với công cụ và cơ chế điều phối để thực hiện nhiệm vụ qua nhiều bước. Thay vì chỉ sinh một phản hồi từ đầu vào, agent có thể lựa chọn công cụ, truy xuất dữ liệu, xem xét kết quả và tiếp tục xử lý hoặc hỏi lại khi thiếu thông tin. Các kết quả công cụ cung cấp căn cứ để tổng hợp câu trả lời, nhưng vẫn cần được kiểm tra về độ chính xác và mức độ liên quan.

Model Context Protocol (MCP) là giao thức kết nối ứng dụng AI với các công cụ và nguồn dữ liệu thông qua giao diện thống nhất. MCP không tự quyết định quyền truy cập; hệ thống cung cấp công cụ phải xác thực chủ thể và kiểm tra quyền cho từng yêu cầu. Việc giới hạn công cụ ở chế độ chỉ đọc giúp giảm tác động trực tiếp lên dữ liệu, trong khi dẫn nguồn và lưu lịch sử hỗ trợ kiểm tra kết quả.

Khi sử dụng agent, cần giới hạn thời gian, số lần gọi mô hình và ngân sách, đồng thời phân biệt nội dung được truy xuất với chỉ dẫn điều khiển. Những đề xuất có ảnh hưởng đến tài khoản hoặc nội dung cần được người có thẩm quyền xem xét trước khi thực hiện. Cách tiếp cận này giữ vai trò của agent ở mức hỗ trợ phân tích và tổng hợp, thay vì mặc định giao toàn bộ quyền quyết định cho mô hình.

== Công nghệ sử dụng

#figure(
  table(
    columns: (0.9fr, 1.3fr, 2fr, 2fr),
    align: left,
    table.header([*Nhóm*], [*Công nghệ*], [*Vai trò trong hệ thống*], [*Lý do sử dụng*]),
    [Backend], [Go], [Xây dựng API và xử lý các luồng nghiệp vụ.], [Hỗ trợ xử lý đồng thời, biên dịch thành tệp thực thi và thuận tiện đóng gói dịch vụ.],
    [Cơ sở dữ liệu], [PostgreSQL], [Lưu trữ dữ liệu nghiệp vụ, quản lý giao dịch và kiểm soát truy cập đồng thời.], [Cung cấp giao dịch ACID, ràng buộc dữ liệu và khả năng mở rộng bằng các extension.],
    [Tìm kiếm], [ParadeDB (`pg_search`), pgvector], [Hỗ trợ Full-text Search và truy vấn vector phục vụ tìm kiếm ngữ nghĩa, hình ảnh.], [Kết hợp tìm kiếm từ khóa và vector trong PostgreSQL, hạn chế nhu cầu đồng bộ dữ liệu sang hệ thống tìm kiếm riêng biệt.],
    [Durable Execution], [Restate], [Lưu tiến trình, hỗ trợ thử lại và phục hồi các quy trình xử lý nhiều bước.], [Phù hợp với các luồng nghiệp vụ cần tiếp tục thực thi sau sự cố và các lời gọi hàm từ xa có khả năng được thực hiện lại nhiều lần mà vẫn bảo đảm tính nhất quán của dữ liệu.],
    [Lưu trữ đối tượng], [RustFS], [Lưu trữ hình ảnh và tệp đa phương tiện, hỗ trợ tải tệp qua URL ký sẵn.], [Tách dữ liệu tệp khỏi cơ sở dữ liệu nghiệp vụ và tận dụng công cụ tương thích với S3.],
    [Ứng dụng di động], [Android native], [Cung cấp giao diện đăng tin, tìm kiếm, trò chuyện và theo dõi giao dịch cho người mua, người bán trên hệ điều hành Android.], [Thuận tiện tích hợp camera, chọn ảnh và các chức năng của nền tảng Android.],
    [AI agent], [NestJS, Strands Agent SDK], [Xây dựng dịch vụ agent, điều phối mô hình và công cụ; truy xuất dữ liệu theo quyền để hỗ trợ admin và moderator.], [Tách agent khỏi lõi nghiệp vụ, hỗ trợ xử lý nhiều bước và chuẩn hóa giao diện công cụ.],
    [AI Gateway], [LiteLLM], [Định tuyến các lời gọi đến mô hình, quản lý khóa truy cập và ngân sách theo mục đích sử dụng.], [Tập trung cấu hình mô hình và kiểm soát chi phí cho nhiều chức năng AI.],
    [Tích hợp vận chuyển], [GHTK, GHN], [Liên kết tài khoản người bán, tra cứu phí, tạo hoặc hủy vận đơn và cập nhật trạng thái giao nhận.], [Kết nối trực tiếp với đơn vị vận chuyển, giảm nhập liệu thủ công và hỗ trợ theo dõi giao nhận.],
    [Đặc tả API], [OpenAPI 3.2.0], [Mô tả các API endpoints, cấu trúc dữ liệu và cơ chế bảo mật; làm cơ sở đối chiếu hợp đồng API.], [Thống nhất hợp đồng giao tiếp giữa backend và ứng dụng khách, thuận tiện tra cứu và kiểm thử.],
    [Đóng gói và triển khai], [Docker Compose, k3d, Helm, Argo CD], [Tổ chức môi trường phát triển, đóng gói và triển khai ứng dụng theo GitOps.], [Giúp tái tạo môi trường và quản lý cấu hình triển khai có phiên bản trong Git.],
    [CI/CD], [GitHub Actions, GHCR], [Tự động hóa quy trình xây dựng, kiểm tra và lưu trữ Image của ứng dụng.], [Liên kết quy trình kiểm tra và phát hành với mã nguồn trên GitHub, giảm thao tác thủ công.],
    [Quan sát hệ thống], [OpenTelemetry], [Hỗ trợ thu thập log, trace và metric để theo dõi, phân tích quá trình xử lý.], [Chuẩn hóa dữ liệu quan sát, hỗ trợ lần theo yêu cầu qua các thành phần và xác định nguyên nhân lỗi.],
  ),
  caption: [Các công nghệ sử dụng trong hệ thống],
)

