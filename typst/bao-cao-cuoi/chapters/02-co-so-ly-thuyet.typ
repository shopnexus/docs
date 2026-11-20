#import "../../common/tokens.typ": *

= CƠ SỞ LÝ THUYẾT VÀ CÔNG NGHỆ

== Thương mại điện tử C2C và bài toán niềm tin

Trong thương mại điện tử giữa các cá nhân (C2C), người bán không phải doanh nghiệp mà là một người dùng bình thường, còn sàn chỉ đứng giữa để hai bên tìm thấy nhau. Với hàng đã qua sử dụng, mỗi món là duy nhất và tình trạng thật của nó chỉ người bán biết. Thông tin giữa hai bên vì vậy không cân xứng: người mua phải quyết định trả tiền dựa trên ảnh và lời mô tả của một người lạ, còn người bán phải gửi hàng cho một người chưa chắc sẽ nhận.

Các sàn hiện nay thu hẹp khoảng cách này theo một trong hai cách. Cách thứ nhất là sàn giữ tiền: người mua trả cho sàn, sàn chỉ chuyển cho người bán khi người mua xác nhận hàng đúng, và khi có tranh chấp thì nhân viên của sàn phân xử. Cách này cho người mua cảm giác an toàn nhưng đòi hỏi giấy phép trung gian thanh toán, một bộ phận xử lý khiếu nại lớn dần theo số đơn, trong khi người phân xử hiếm khi có căn cứ nào hơn lời kể của hai bên. Cách thứ hai là sàn chỉ đăng tin, để hai bên tự thỏa thuận chuyển khoản hoặc gặp mặt; chi phí vận hành thấp nhưng mọi rủi ro dồn về người dùng.

Đề tài dựa trên ba cơ chế được trình bày trong chương này: giao hàng thu tiền hộ có đồng kiểm để người mua chỉ trả tiền sau khi thấy hàng; uy tín gồm các số liệu quan sát được, công khai cho người sau đọc; và AI hỗ trợ ở những chỗ người dùng tốn công nhất, gồm viết tin đăng, tìm đúng món trong kho tin do người không chuyên viết, và nhận ra dấu hiệu lừa đảo trong tin nhắn.

== Giao hàng thu tiền hộ có đồng kiểm

Giao hàng thu tiền hộ (COD) là dịch vụ trong đó hãng vận chuyển giao hàng, thu tiền của người nhận rồi chuyển lại cho người gửi theo kỳ đối soát. Đồng kiểm là lựa chọn cho phép người nhận mở gói xem hàng trước khi trả tiền. Nếu hàng không đúng, người nhận từ chối, shipper mang hàng về và hãng tính phí cả chiều đi lẫn chiều về cho người gửi. GHTK và GHN đều cung cấp dịch vụ này và cho phép một ứng dụng thay mặt người gửi tạo, hủy vận đơn, hỏi phí và nhận trạng thái giao hàng [16], [17].

Với bài toán niềm tin, điểm quan trọng của COD đồng kiểm là thời điểm trả tiền được dời tới sau khi người mua đã thấy hàng, và bên cầm tiền trong khoảng giữa là hãng vận chuyển chứ không phải sàn. Trong hệ thống, vận đơn được tạo trên tài khoản hãng của chính người bán và đặt chế độ người nhận trả phí ship. Hình 2.1 tách ba dòng chảy của một giao dịch: hàng đi từ người bán qua hãng tới người mua; tiền đi ngược lại từ người mua qua shipper và hãng về tài khoản ngân hàng của người bán; hệ thống chỉ trao đổi thông tin, gồm lệnh tạo vận đơn và trạng thái hãng báo về. Khi người mua từ chối, hàng quay về người bán và không có khoản tiền nào phải hoàn.

#fig(
  [Dòng hàng, dòng tiền và dòng thông tin của giao dịch COD đồng kiểm],
  spacing: (36mm, 12mm),
  node(enclose: ((0, 0), (2, 0)), text(weight: 700)[Hệ thống: chỉ trao đổi thông tin, không giữ tiền],
    fill: rgb("#E4E4E4"), stroke: 1pt + ink, corner-radius: 5pt, name: <shop>),
  np((0, 2), [Người bán], name: <ban>),
  np((1, 2), [Hãng vận chuyển\ và shipper], name: <hang>),
  np((2, 2), [Người mua], name: <mua>),

  edge((0, 2), (0, 0), "<|-|>", snap-to: (<ban>, <shop>), stroke: (dash: "dashed"),
    label-side: right, text(size: 8.5pt)[đăng tin, tạo đơn;\ trạng thái đơn]),
  edge((1, 2), (1, 0), "<|-|>", snap-to: (<hang>, <shop>), stroke: (dash: "dashed"),
    label-side: right, text(size: 8.5pt)[tạo, hủy vận đơn;\ báo trạng thái]),
  edge((2, 2), (2, 0), "<|-|>", snap-to: (<mua>, <shop>), stroke: (dash: "dashed"),
    label-side: left, text(size: 8.5pt)[tìm hàng, thương lượng,\ yêu cầu COD; trạng thái]),

  edge(<ban>, <hang>, "-|>", shift: 5pt, label-side: left, text(size: 8.5pt)[Hàng: giao cho hãng]),
  edge(<hang>, <ban>, "=|>", shift: 5pt, label-side: left,
    text(size: 8.5pt)[Tiền: chuyển tiền hàng\ vào tài khoản người bán]),
  edge(<hang>, <mua>, "-|>", shift: 5pt, label-side: left, text(size: 8.5pt)[Hàng: giao tới cửa,\ mở xem trước]),
  edge(<mua>, <hang>, "=|>", shift: 5pt, label-side: left,
    text(size: 8.5pt)[Tiền: nhận hàng thì trả\ tiền hàng và phí ship]),
  edge(<mua>, (2, 3.6), (0, 3.6), <ban>, "-|>", stroke: (dash: "dotted"), corner-radius: 4pt,
    label-pos: 0.5, label-side: left,
    box(fill: soft, inset: 2pt, text(size: 8.5pt)[Từ chối nhận: hàng quay về người bán, hãng tính phí hai chiều cho người bán])),
  node((1, 4.5), text(size: 8pt)[Nét liền: hàng · nét đôi: tiền · nét đứt: thông tin · nét chấm: hàng hoàn],
    stroke: none, fill: none),
)

Sau khi người mua đã trả tiền cho shipper thì không còn bên thứ ba nào đang giữ tiền để hoàn lại. Rủi ro còn sót là lỗi không thấy được khi xem tại cửa. Hai bên tự trao đổi về phần này trong cuộc trò chuyện, và đánh giá sau đơn ghi lại kết quả cho người mua sau đọc.

== Uy tín dựa trên số liệu quan sát được

Hệ thống uy tín thay câu hỏi khó trả lời "lần này ai đúng" bằng câu hỏi dễ hơn "người này thường cư xử ra sao". Đánh giá sao sau giao dịch là dạng phổ biến nhất nhưng có hai nhược điểm: người dùng hiếm khi chấm dưới mức tối đa vì ngại bị đánh giá trả đũa, và một tài khoản mới chưa có lịch sử thì không mang thông tin gì.

Hệ thống xử lý nhược điểm thứ nhất bằng đánh giá hai chiều ẩn: người mua và người bán đánh giá nhau sau mỗi đơn, nhưng mỗi đánh giá chỉ hiện khi bên kia cũng đã đánh giá hoặc sau 7 ngày, nên không ai viết theo số sao của người kia. Người được đánh giá trả lời được một lần, rồi đánh giá khóa lại. Với nhược điểm thứ hai, hệ thống dùng thêm các số liệu do hành vi sinh ra và được bên thứ ba xác nhận: số món đã bán, tỉ lệ trả lời tin nhắn trong 24 giờ, và số đơn giao không thành trong 90 ngày theo báo cáo của hãng vận chuyển.

Một lần giao không thành đơn lẻ không nói lên điều gì, vì hàng có thể sai thật; một tỉ lệ cao trên nhiều đơn thì có. Vì vậy các số liệu được hiện kèm số đơn hay số cuộc trò chuyện làm mẫu, và tỉ lệ trả lời chỉ tính khi có từ 5 cuộc trò chuyện trong 90 ngày. Hệ thống không quy đổi các số liệu thành một điểm tổng hay một bậc: một con số tổng hợp cần một bảng cộng trừ do sàn tự đặt, người dùng khó kiểm lại, còn số liệu gốc thì ai cũng hiểu. Hạn mức (3 đơn COD đang mở, 20 tin đang bán) như nhau cho mọi tài khoản và không mua được bằng gói trả phí, vì nếu mua được thì con số không còn phản ánh hành vi.

== Tìm kiếm ngữ nghĩa và tìm kiếm lai

Tin đăng do người không chuyên viết: cùng một món có thể được ghi "ip 13 zin", "iPhone 13 cũ" hay "điện thoại Apple". Tìm kiếm theo từ khóa dùng hàm xếp hạng BM25 [12], cho điểm một tin theo số lần từ của câu tìm xuất hiện trong tin và độ hiếm của từ đó; nó tốt với tên riêng và mã model nhưng không hiểu "đồ tặng sinh nhật" và "quà" là gần nhau. Phần mở rộng pg_search của ParadeDB [19] đặt chỉ mục BM25 ngay trong PostgreSQL, cập nhật cùng giao dịch ghi tin.

Tìm kiếm ngữ nghĩa biểu diễn mỗi đoạn văn bản thành một vector nhúng sao cho các câu cùng nghĩa có vector gần nhau, rồi trả về những tin gần câu tìm nhất. Mô hình BGE-M3 [4] cho vector 1024 chiều và hiểu được tiếng Việt viết tự do. Ảnh được nhúng bằng mô hình SigLIP 2 [13], đưa ảnh và câu chữ vào cùng một không gian vector, nhờ đó người mua tìm được bằng một tấm ảnh chụp món đồ, và hai tin có ảnh giống nhau được xem là tương tự. Để không phải so câu tìm với mọi tin, chỉ mục HNSW [9] tìm lân cận gần đúng với số phép so sánh nhỏ hơn nhiều; phần mở rộng pgvector [20] đặt chỉ mục này trong PostgreSQL, cạnh các bộ lọc giá, danh mục và vị trí.

Các cách tìm trên cho các danh sách xếp hạng với thang điểm khác nhau, không cộng trực tiếp được. Reciprocal Rank Fusion [5] chỉ dùng thứ hạng: một tin được cộng điểm theo nghịch đảo thứ hạng của nó trong từng danh sách, theo công thức (2.1):

#[
  #set math.equation(numbering: n => "(2." + str(n) + ")", block: true)
  $ "RRF"(d) = sum_(i) w_i / (k + r_i (d)) $
]

trong đó $r_i (d)$ là thứ hạng của tin $d$ trong danh sách thứ $i$, $w_i$ là trọng số của danh sách và $k$ là hằng số làm mượt, hệ thống dùng $k = 60$. Tin không có trong một danh sách thì không nhận điểm từ danh sách đó. Hằng số $k$ làm giảm chênh lệch giữa hạng 1 và hạng 2, nên một tin đứng khá cao ở nhiều danh sách thường vượt một tin chỉ đứng đầu ở một danh sách.

== Mô hình ngôn ngữ lớn trong hệ thống

Mô hình ngôn ngữ lớn (LLM) hiểu được câu chữ tự do nhưng có thể trả lời sai, chậm hoặc tự thêm điều người dùng không nói. Hệ thống dùng LLM theo cách giới hạn được các rủi ro đó: mô hình chỉ trả về dữ liệu theo một lược đồ cố định, hệ thống kiểm từng giá trị với dữ liệu thật trước khi dùng, và quyết định cuối thuộc về người dùng hoặc nhân viên.

Với câu tìm như "xe đạp cho bé 6 tuổi, tầm 500 nghìn, gần đây thôi", mô hình đọc câu một lần và trả về các điều kiện ưu tiên: cụm từ cần khớp, danh mục, khoảng giá, tình trạng, nơi bán, độ gần, độ mới. Mô hình không đặt trọng số; danh mục, tỉnh, xã mà mô hình nêu phải khớp một dòng có thật, không khớp thì bị bỏ. Câu gốc luôn được giữ làm một cụm từ tìm, nên khi mô hình lỗi hoặc quá 4 giây, kết quả bằng kết quả tìm theo câu gốc. Mỗi điều kiện hiện thành một chip người mua tắt được.

Với cảnh báo lừa đảo, mô hình làm việc như một bộ phân loại nhiều nhãn: đọc các tin nhắn gần nhất của cuộc trò chuyện và chỉ chọn trong một danh sách mã dấu hiệu cố định do hệ thống định nghĩa. Vì đầu ra là danh sách mã, các kết quả đã lưu dùng được làm dữ liệu huấn luyện cho một mô hình riêng sau này mà không đổi phần còn lại của hệ thống.

Với nhân viên, hệ thống dùng một agent: mô hình được phép gọi các công cụ đã khai báo trước, như đọc phiếu hỗ trợ, đơn hàng hay lịch sử tài khoản, rồi đọc kết quả và quyết định bước tiếp. Vòng lặp ReAct [14] xen kẽ suy luận và hành động theo cách này cho đến khi đủ thông tin để trả lời. Mọi công cụ của agent chỉ đọc; agent trình bằng chứng và đề xuất, nhân viên là người bấm thao tác.

== Kiến trúc microservice và độ tin cậy của quy trình

Kiến trúc microservice chia hệ thống thành các dịch vụ nhỏ theo phân hệ nghiệp vụ; mỗi dịch vụ giữ dữ liệu riêng và chỉ cho dịch vụ khác dùng qua giao diện đã công bố [10], [11]. Trong hệ thống, thương lượng và đơn COD thuộc một phân hệ, đánh giá và cảnh báo lừa đảo thuộc một phân hệ khác, nên mỗi quy tắc nghiệp vụ nằm ở đúng một chỗ. Để nhóm ba người không phải vận hành nhiều tiến trình ngay từ đầu, các dịch vụ chạy chung một tiến trình nhưng vẫn giữ nguyên ranh giới, và có thể tách ra khi cần mà không sửa nghiệp vụ.

Khi một thao tác gồm nhiều bước chạm tới hệ thống ngoài, sự cố máy chủ giữa chừng có thể để lại dữ liệu dở dang. Chẳng hạn, khi người bán tạo đơn, hệ thống lần lượt tạo vận đơn trên tài khoản hãng của người bán, giữ tin cho người mua này và hủy các yêu cầu COD khác trên tin. Cách truyền thống là viết kèm mỗi bước một thao tác bù trừ để hoàn tác [6]. Hệ thống dùng Restate [21], một nền tảng thực thi bền [3]: mỗi bước đã xong được ghi lại, nên sau sự cố quy trình chạy tiếp từ bước dang dở và không tạo vận đơn thứ hai. Các thao tác ghi cũng được thiết kế để một yêu cầu gửi lặp cho cùng kết quả như gửi một lần [7], còn thông báo giữa các phân hệ được lưu cùng lúc với thay đổi dữ liệu nên không bị mất khi có sự cố [8].

Ứng dụng Android viết bằng Jetpack Compose theo hướng dẫn kiến trúc của Android [15]: mỗi màn hình hiển thị một trạng thái do tầng xử lý giữ, thao tác của người dùng được gửi ngược về tầng đó, nên trạng thái chỉ đổi ở một nơi và dễ kiểm thử. Website dựng trang ở phía máy chủ và đứng giữa trình duyệt với dịch vụ nền: mã phiên nằm trong cookie mà mã chạy trên trình duyệt không đọc được. Trang điều hành của nhân viên là một ứng dụng web riêng, gọi cùng dịch vụ nền qua nhóm chức năng dành cho nhân viên.

== Công nghệ sử dụng

Bảng 2.1 liệt kê các công nghệ chính và lý do chọn.

#figure(
  kind: table,
  caption: [Công nghệ sử dụng trong hệ thống],
  table(
    columns: (2.8cm, 4.2cm, 1fr),
    table.header([Thành phần], [Công nghệ, phiên bản], [Lý do chọn]),
    [Dịch vụ nền], [Go], [Chạy nhẹ, khởi động nhanh, một tệp chạy cho mọi phân hệ],
    [CSDL], [PostgreSQL 18, ParadeDB 0.26.3 (pg_search), pgvector], [Dữ liệu nhất quán; tìm theo từ khóa và theo nghĩa trong cùng một hệ],
    [Thực thi bền], [Restate 1.8.0, Go SDK v1.1.0], [Quy trình nhiều bước chạy tiếp sau sự cố, không lặp vận đơn hay tin nhắn],
    [Kho ảnh], [RustFS 1.0.4], [Lưu ảnh và video tin đăng, tương thích chuẩn S3],
    [Quan trắc], [OpenTelemetry, Grafana LGTM, Prometheus], [Theo dõi lỗi và thời gian phản hồi của từng yêu cầu],
    [Đặc tả API], [OpenAPI 3.2 [18]], [Hợp đồng chung cho ứng dụng, website, dịch vụ nền và kiểm thử],
    [Mô hình AI], [Cổng LiteLLM; BGE-M3; SigLIP 2; Gipformer 1.5 (nhận dạng tiếng nói tiếng Việt)], [Một cổng chung có hạn mức chi phí theo ngày; mô hình ảnh và tiếng nói chạy trên máy chủ của nhóm],
    [Agent nhân viên], [NestJS, Strands Agents SDK], [Vòng lặp gọi công cụ, chạy riêng trong mạng nội bộ],
    [Vận chuyển], [API GHTK [17], GHN [16]], [Tạo, hủy vận đơn, báo phí và trạng thái giao hàng],
    [Xác thực, thông báo], [Firebase Authentication, Firebase Cloud Messaging], [Xác minh số điện thoại, đăng nhập Google, đẩy thông báo tới điện thoại],
    [Ứng dụng], [Kotlin 2.4.21, Jetpack Compose, Material 3, Hilt 2.60.1], [Giao diện khai báo theo chuẩn Android],
    [Website], [Astro 7, React 19, Tailwind CSS 4], [Dựng trang phía máy chủ, giữ phiên trong cookie],
    [Trang điều hành], [React 19, Vite 8, TanStack Query], [Ứng dụng web cho nhân viên],
    [Triển khai], [Kubernetes (k3s), Argo CD, Docker Compose], [Cụm máy chủ cho môi trường thử và chính thức; Compose cho máy phát triển],
  ),
)
