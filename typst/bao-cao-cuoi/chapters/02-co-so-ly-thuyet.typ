#import "../../common/tokens.typ": *

= CƠ SỞ LÝ THUYẾT VÀ CÔNG NGHỆ

== Thương mại điện tử C2C và bài toán niềm tin

Trong thương mại điện tử giữa các cá nhân (C2C), người bán không phải doanh nghiệp mà là một người dùng bình thường, còn nền tảng chỉ đứng giữa để hai bên tìm thấy nhau. Với hàng đã qua sử dụng, mỗi món là duy nhất và tình trạng thật của nó chỉ người bán biết. Thông tin giữa hai bên vì vậy không cân xứng: người mua phải quyết định trả tiền dựa trên ảnh và lời mô tả của một người lạ, còn người bán phải gửi hàng cho một người chưa chắc sẽ nhận.

Các nền tảng hiện nay thu hẹp khoảng cách này theo một trong hai cách. Cách thứ nhất là nền tảng giữ tiền: người mua trả cho nền tảng, nền tảng chỉ chuyển cho người bán khi người mua xác nhận hàng đúng, và khi có tranh chấp thì nhân viên của nền tảng phân xử. Cách này cho người mua cảm giác an toàn nhưng đòi hỏi giấy phép trung gian thanh toán, một bộ phận xử lý khiếu nại lớn dần theo số đơn, trong khi người phân xử hiếm khi có căn cứ nào hơn lời kể của hai bên. Cách thứ hai là nền tảng chỉ đăng tin, để hai bên tự thỏa thuận chuyển khoản hoặc gặp mặt; chi phí vận hành thấp nhưng mọi rủi ro dồn về người dùng.

Đề tài dựa trên ba cơ chế được trình bày trong chương này: giao hàng thu tiền hộ có đồng kiểm để người mua chỉ trả tiền sau khi thấy hàng; uy tín gồm các số liệu quan sát được, công khai cho người sau đọc; và AI hỗ trợ ở những chỗ người dùng tốn công nhất, gồm viết tin đăng, tìm đúng món trong kho tin do người không chuyên viết, và nhận ra dấu hiệu lừa đảo trong tin nhắn.

== Giao hàng thu tiền hộ có đồng kiểm

Giao hàng thu tiền hộ (COD) là dịch vụ trong đó hãng vận chuyển giao hàng, thu tiền của người nhận rồi chuyển lại cho người gửi theo kỳ đối soát. Đồng kiểm là lựa chọn cho phép người nhận mở gói xem hàng trước khi trả tiền. Nếu hàng không đúng, người nhận từ chối, shipper mang hàng về và hãng tính phí cả chiều đi lẫn chiều về cho người gửi. GHTK và GHN đều cung cấp dịch vụ này và cho phép một ứng dụng thay mặt người gửi tạo, hủy vận đơn, hỏi phí và nhận trạng thái giao hàng [17], [18].

Với bài toán niềm tin, điểm quan trọng của COD đồng kiểm là thời điểm trả tiền được dời tới sau khi người mua đã thấy hàng, và bên cầm tiền trong khoảng giữa là hãng vận chuyển chứ không phải hệ thống. Trong hệ thống, vận đơn được tạo trên tài khoản hãng của chính người bán và đặt chế độ người nhận trả phí vận chuyển. Hình 2.1 tách ba dòng chảy của một giao dịch: hàng đi từ người bán qua hãng tới người mua; tiền đi ngược lại từ người mua qua shipper và hãng về tài khoản ngân hàng của người bán; hệ thống chỉ trao đổi thông tin, gồm lệnh tạo vận đơn và trạng thái hãng báo về. Khi người mua từ chối, hàng quay về người bán và không có khoản tiền nào phải hoàn.

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
    label-side: left, text(size: 8.5pt)[tìm hàng, trả giá,\ yêu cầu COD; trạng thái]),

  edge(<ban>, <hang>, "-|>", shift: 5pt, label-side: left, text(size: 8.5pt)[Hàng: giao cho hãng]),
  edge(<hang>, <ban>, "=|>", shift: 5pt, label-side: left,
    text(size: 8.5pt)[Tiền: chuyển tiền hàng\ vào tài khoản người bán]),
  edge(<hang>, <mua>, "-|>", shift: 5pt, label-side: left, text(size: 8.5pt)[Hàng: giao tới cửa,\ mở xem trước]),
  edge(<mua>, <hang>, "=|>", shift: 5pt, label-side: left,
    text(size: 8.5pt)[Tiền: nhận hàng thì trả tiền\ hàng và phí vận chuyển]),
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

Một lần giao không thành đơn lẻ không nói lên điều gì, vì hàng có thể sai thật; một tỉ lệ cao trên nhiều đơn thì có. Vì vậy các số liệu được hiện kèm số đơn hay số cuộc trò chuyện làm mẫu, và tỉ lệ trả lời chỉ tính khi có từ 5 cuộc trò chuyện trong 90 ngày. Hệ thống không quy đổi các số liệu thành một điểm tổng hay một bậc: một con số tổng hợp cần một bảng cộng trừ do hệ thống tự đặt, người dùng khó kiểm lại, còn số liệu gốc thì ai cũng hiểu. Hạn mức (3 đơn COD đang mở, 20 tin đang bán) như nhau cho mọi tài khoản và không mua được bằng gói trả phí, vì nếu mua được thì con số không còn phản ánh hành vi.

== Tìm kiếm ngữ nghĩa và tìm kiếm lai

Tin đăng do người không chuyên viết: cùng một món có thể được ghi "ip 13 zin", "iPhone 13 cũ" hay "điện thoại Apple". Tìm kiếm theo từ khóa dùng hàm xếp hạng BM25 [12], cho điểm một tin theo số lần từ của câu tìm xuất hiện trong tin và độ hiếm của từ đó; nó tốt với tên riêng và mã model nhưng không hiểu "đồ tặng sinh nhật" và "quà" là gần nhau. Phần mở rộng pg_search của ParadeDB [20] đặt chỉ mục BM25 ngay trong PostgreSQL, cập nhật cùng giao dịch ghi tin.

Tìm kiếm ngữ nghĩa biểu diễn mỗi đoạn văn bản thành một vector nhúng sao cho các câu cùng nghĩa có vector gần nhau, rồi trả về những tin gần câu tìm nhất. Mô hình BGE-M3 [4] cho vector 1024 chiều và hiểu được tiếng Việt viết tự do. Ảnh được nhúng bằng mô hình SigLIP 2 [13], đưa ảnh và câu chữ vào cùng một không gian vector, nhờ đó người mua tìm được bằng một tấm ảnh chụp món đồ, và hai tin có ảnh giống nhau được xem là tương tự. Để không phải so câu tìm với mọi tin, chỉ mục HNSW [9] tìm lân cận gần đúng với số phép so sánh nhỏ hơn nhiều; phần mở rộng pgvector [21] đặt chỉ mục này trong PostgreSQL, cạnh các bộ lọc giá, danh mục và vị trí.

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

Với nhân viên, hệ thống dùng một trợ lý AI (AI agent): mô hình được phép gọi các công cụ đã khai báo trước, như đọc phiếu hỗ trợ, đơn COD hay lịch sử tài khoản, rồi đọc kết quả và quyết định bước tiếp. Vòng lặp ReAct [14] xen kẽ suy luận và hành động theo cách này cho đến khi đủ thông tin để trả lời. Mọi công cụ của trợ lý AI chỉ đọc; trợ lý AI trình bằng chứng và đề xuất, nhân viên là người bấm thao tác.

== Cổng mô hình ngôn ngữ

Các chức năng AI của hệ thống gọi mô hình của nhiều nhà cung cấp, mỗi nhà có địa chỉ, khóa truy cập và cách tính tiền riêng. Cổng mô hình ngôn ngữ (LLM gateway) là một dịch vụ đứng giữa bên gọi và các nhà cung cấp, nhận mọi lời gọi qua một giao diện chung theo chuẩn API của OpenAI. Bên gọi chỉ nêu tên mô hình theo dạng nhà cung cấp/mô hình; địa chỉ và khóa của nhà cung cấp do cổng giữ. Nhờ vậy, đổi mô hình của một chức năng không cần sửa mã bên gọi, và cổng là nơi duy nhất đếm chi phí và chặn lời gọi vượt mức.

Cổng cấp cho mỗi bên gọi một khóa ảo (virtual key) thay cho khóa thật của nhà cung cấp. Một khóa ảo thuộc về một chức năng AI và chỉ gọi được mô hình chính cùng các mô hình dự phòng của chức năng đó, nên khóa của chức năng tìm kiếm có bị lộ cũng không gọi được mô hình của trợ lý AI. Giá trị khóa do cổng sinh ra; dịch vụ nền đọc lại và chỉ giữ trong bộ nhớ, rồi gửi khóa của trợ lý AI kèm mỗi lượt chạy. Khóa ảo vì thế không nằm trong mã nguồn hay cơ sở dữ liệu, còn khóa của nhà cung cấp không ra khỏi cổng.

Mỗi chức năng AI có một hạn mức chi phí theo tháng, tính bằng USD, và mỗi bên gọi có giới hạn số yêu cầu và số token (đơn vị văn bản mà mô hình xử lý) trong một phút. Chi phí của một lời gọi bằng số token vào và ra nhân với giá của mô hình; giá do dịch vụ nền lưu theo bảng giá niêm yết của nhà cung cấp, nên hạn mức là tiền thật. Khi hạn mức của tháng đã hết, cổng từ chối lời gọi cho tới khi quản trị viên nâng hạn mức hoặc sang tháng mới. Lời gọi vượt giới hạn tần suất cũng bị từ chối, bên gọi chờ hết khung thời gian rồi gửi lại. Vì hạn mức tách theo chức năng, một chức năng dùng quá mức không làm các chức năng khác ngừng.

Chính sách AI gồm mô hình của từng chức năng, mô hình dự phòng, giá, hạn mức và giới hạn tần suất. Chính sách này nằm trong cơ sở dữ liệu của dịch vụ nền, quản trị viên sửa trên trang điều hành. Sau mỗi lần sửa, dịch vụ nền ghi lại các nhóm, khóa ảo, hạn mức và giá vào cổng qua giao diện quản trị của cổng, và không bên nào khác ghi vào các mục này. Danh sách nhà cung cấp và khóa của họ thuộc cấu hình triển khai: thêm một nhà cung cấp là một thay đổi hạ tầng, không phải một thao tác trên trang điều hành. Mỗi loại dữ liệu chỉ có một nơi ghi, nên cấu hình trên cổng không lệch với cấu hình trên trang điều hành (Hình 2.2).

#fig(
  [Bên gọi, cổng mô hình ngôn ngữ và các nhà cung cấp],
  spacing: (30mm, 12mm),
  np((0, 0), [Dịch vụ nền\ (tìm kiếm, đọc tin,\ cảnh báo lừa đảo)], name: <nen>),
  np((0, 2), [Trợ lý AI], name: <tl>),
  ncore((1, 1), [Cổng Bifrost], name: <cong>),
  np((2, 0), [Nhà cung cấp upstream\ (các mô hình Claude)], name: <up>),
  np((2, 2), [OpenRouter], name: <or>),
  edge(<nen>, <cong>, "-|>", label-pos: 0.45, label-side: right, label-fill: soft, rel[gọi mô hình bằng\ khóa ảo]),
  edge(<tl>, <cong>, "-|>", label-pos: 0.45, label-side: left, label-fill: soft, rel[khóa ảo kèm\ mỗi lượt chạy]),
  edge(<nen>, (1, 0), <cong>, "-|>", stroke: (dash: "dashed"), label-pos: 0.25, label-side: left,
    rel[ghi khóa ảo, hạn mức, giá]),
  edge(<cong>, <up>, "-|>", label-pos: 0.55, label-side: right, label-fill: soft, rel[khóa của\ nhà cung cấp]),
  edge(<cong>, <or>, "-|>", label-pos: 0.55, label-side: left, label-fill: soft, rel[khóa của\ nhà cung cấp]),
)

Hệ thống dùng Bifrost [16], một cổng mã nguồn mở viết bằng Go, thay cho LiteLLM, cổng viết bằng Python mà giai đoạn trước dùng. Trong lần thử ngày 26/11/2026 với phiên bản 2.6.0, Bifrost chạy thành một tệp thực thi duy nhất, dùng 260–440 MiB bộ nhớ và sẵn sàng sau 1–2 giây (20 giây ở lần đầu, khi tạo bảng trong cơ sở dữ liệu trống); LiteLLM dùng tới 1 GiB và cần khoảng 45 giây. Một tệp Go đã biên dịch kéo theo ít gói phụ thuộc hơn một ứng dụng Python cài từ kho PyPI, nên ít chỗ hơn cho một gói bị chèn mã độc lọt vào hệ thống. Trên cụm máy chủ chạy song song hai môi trường, phần bộ nhớ tiết kiệm được để dành cho các mô hình ảnh và tiếng nói chạy trên máy chủ của nhóm.

== Kiến trúc microservice và độ tin cậy của quy trình

Kiến trúc microservice chia hệ thống thành các dịch vụ nhỏ theo phân hệ nghiệp vụ; mỗi dịch vụ giữ dữ liệu riêng và chỉ cho dịch vụ khác dùng qua giao diện đã công bố [10], [11]. Trong hệ thống, phiên trả giá và đơn COD thuộc một phân hệ, đánh giá và cảnh báo lừa đảo thuộc một phân hệ khác, nên mỗi quy tắc nghiệp vụ nằm ở đúng một chỗ. Để nhóm ba người không phải vận hành nhiều tiến trình ngay từ đầu, các phân hệ chạy chung một tiến trình nhưng vẫn giữ nguyên ranh giới, và có thể tách ra khi cần mà không sửa nghiệp vụ.

Khi một thao tác gồm nhiều bước chạm tới hệ thống ngoài, sự cố máy chủ giữa chừng có thể để lại dữ liệu dở dang. Chẳng hạn, khi người bán tạo đơn, hệ thống lần lượt tạo vận đơn trên tài khoản hãng của người bán, giữ tin cho người mua này và hủy các yêu cầu COD khác trên tin. Cách truyền thống là viết kèm mỗi bước một thao tác bù trừ để hoàn tác [6]. Hệ thống dùng Restate [22], một dịch vụ thực thi bền [3]: mỗi bước đã xong được ghi lại, nên sau sự cố quy trình chạy tiếp từ bước dang dở và không tạo vận đơn thứ hai. Các thao tác ghi cũng được thiết kế để một yêu cầu gửi lặp cho cùng kết quả như gửi một lần [7], còn thông báo giữa các phân hệ được lưu cùng lúc với thay đổi dữ liệu nên không bị mất khi có sự cố [8].

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
    [Đặc tả API], [OpenAPI 3.2 [19]], [Hợp đồng chung cho ứng dụng, website, dịch vụ nền và kiểm thử],
    [Dịch vụ AI], [Cổng Bifrost 2.6.0; BGE-M3; SigLIP 2; Gipformer 1.5 (nhận dạng tiếng nói tiếng Việt)], [Một cổng chung, mỗi chức năng AI có khóa ảo và hạn mức chi phí theo tháng; mô hình ảnh và tiếng nói chạy trên máy chủ của nhóm],
    [Trợ lý AI], [NestJS, Strands Agents SDK], [Vòng lặp gọi công cụ, chạy riêng trong mạng nội bộ],
    [Vận chuyển], [API GHTK [18], GHN [17]], [Tạo, hủy vận đơn, báo phí và trạng thái giao hàng],
    [Xác thực, thông báo], [Firebase Authentication, Firebase Cloud Messaging], [Xác minh số điện thoại, đăng nhập Google, đẩy thông báo tới điện thoại],
    [Ứng dụng], [Kotlin 2.4.21, Jetpack Compose, Material 3, Hilt 2.60.1], [Giao diện khai báo theo chuẩn Android],
    [Website], [Astro 7, React 19, Tailwind CSS 4], [Dựng trang phía máy chủ, giữ phiên trong cookie],
    [Trang điều hành], [React 19, Vite 8, TanStack Query], [Ứng dụng web cho nhân viên],
    [Triển khai], [Kubernetes (k3s), Argo CD, Docker Compose], [Cụm máy chủ cho môi trường thử và chính thức; Compose cho máy phát triển],
  ),
)
