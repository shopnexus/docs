#import "../../common/tokens.typ": *

= CƠ SỞ LÝ THUYẾT VÀ CÔNG NGHỆ

== Thương mại điện tử C2C và bài toán niềm tin

Trong thương mại điện tử giữa các cá nhân (C2C), người bán không phải doanh nghiệp mà là một người dùng bình thường, còn sàn chỉ đứng giữa để hai bên tìm thấy nhau. Với hàng đã qua sử dụng, mỗi món là duy nhất và tình trạng thật của nó chỉ người bán biết. Thông tin giữa hai bên vì vậy không cân xứng: người mua phải quyết định trả tiền dựa trên ảnh và lời mô tả của một người lạ, còn người bán phải gửi hàng cho một người chưa chắc sẽ nhận.

Các sàn hiện nay thu hẹp khoảng cách này theo một trong hai cách. Cách thứ nhất là sàn giữ tiền: người mua trả cho sàn, sàn chỉ chuyển cho người bán khi người mua xác nhận hàng đúng, và khi có tranh chấp thì nhân viên của sàn phân xử. Cách này cho người mua cảm giác an toàn nhưng đòi hỏi giấy phép trung gian thanh toán, một bộ phận xử lý khiếu nại lớn dần theo số đơn, trong khi người phân xử hiếm khi có căn cứ nào hơn lời kể của hai bên. Cách thứ hai là sàn chỉ đăng tin, để hai bên tự thỏa thuận chuyển khoản hoặc gặp mặt; chi phí vận hành thấp nhưng mọi rủi ro dồn về người dùng.

ShopNexus đi theo hướng khác, dựa trên ba cơ chế được trình bày trong chương này: giao hàng thu tiền hộ có đồng kiểm để người mua chỉ trả tiền sau khi thấy hàng; uy tín tính từ thống kê các sự kiện quan sát được thay cho phân xử từng vụ; và tìm kiếm có AI hỗ trợ để người mua tìm đúng món cần trong kho tin đăng do người không chuyên viết.

== Giao hàng thu tiền hộ có đồng kiểm

Giao hàng thu tiền hộ (COD) là dịch vụ trong đó hãng vận chuyển giao hàng, thu tiền của người nhận rồi chuyển lại cho người gửi theo kỳ đối soát. Đồng kiểm là lựa chọn cho phép người nhận mở gói xem hàng trước khi trả tiền. Nếu hàng không đúng, người nhận từ chối, shipper mang hàng về và hãng tính phí cả chiều đi lẫn chiều về cho người gửi. GHTK và GHN đều cung cấp dịch vụ này và cho phép một ứng dụng thay mặt người gửi tạo, hủy vận đơn, hỏi phí và nhận trạng thái giao hàng [14], [15].

Với bài toán niềm tin, điểm quan trọng của COD đồng kiểm là thời điểm trả tiền được dời tới sau khi người mua đã thấy hàng, và bên cầm tiền trong khoảng giữa là hãng vận chuyển chứ không phải sàn. Trong ShopNexus, vận đơn được tạo trên tài khoản hãng của chính người bán và đặt chế độ người nhận trả phí ship. Hình 2.1 tách ba dòng chảy của một giao dịch: hàng đi từ người bán qua hãng tới người mua; tiền đi ngược lại từ người mua qua shipper và hãng về tài khoản ngân hàng của người bán; ShopNexus chỉ trao đổi thông tin, gồm lệnh tạo vận đơn và trạng thái hãng báo về. Khi người mua từ chối, hàng quay về người bán và không có khoản tiền nào phải hoàn.

#fig(
  [Dòng hàng, dòng tiền và dòng thông tin của giao dịch COD đồng kiểm],
  spacing: (36mm, 12mm),
  node(enclose: ((0, 0), (2, 0)), text(weight: 700)[ShopNexus: chỉ trao đổi thông tin, không giữ tiền],
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

Đổi lại, sau khi người mua đã trả tiền cho shipper thì không còn bên thứ ba nào đang giữ tiền để hoàn lại. Rủi ro còn sót là lỗi không thấy được khi xem tại cửa; phần này được xử lý bằng ghi nhận sự cố công khai và cơ chế uy tín ở mục sau, không phải bằng hoàn tiền.

== Uy tín dựa trên thống kê

Hệ thống uy tín thay câu hỏi khó trả lời "lần này ai đúng" bằng câu hỏi dễ hơn "người này thường cư xử ra sao". Đánh giá sao sau giao dịch là dạng phổ biến nhất nhưng có hai nhược điểm: người dùng hiếm khi chấm dưới mức tối đa vì ngại va chạm, và một tài khoản mới chưa có lịch sử thì không mang thông tin gì. ShopNexus vì vậy dùng thêm các tín hiệu do hành vi sinh ra và được bên thứ ba xác nhận: hãng vận chuyển báo người mua có nhận hàng hay không, hệ thống ghi nhận người bán có trả lời ghi nhận sự cố trong hạn hay không.

Một lần từ chối nhận đơn lẻ không nói lên điều gì, vì hàng có thể sai thật; một tỉ lệ từ chối cao trên nhiều đơn thì có. Chế tài do đó chỉ xét khi đủ mẫu, từ 5 đơn COD trong 90 ngày, và tăng theo nấc: tỉ lệ từ chối nhận từ 20% thì người mua chỉ còn được mở 1 đơn COD cùng lúc, từ 35% thì mất quyền COD 30 ngày, và mỗi 30 ngày không có lần từ chối nào thì hồi lại một nấc (BR-15). Chế tài là mất quyền chứ không mất tiền, nên một kết luận sai ở quy mô nhỏ chỉ gây bất tiện tạm thời. Bên cạnh các tỉ lệ, điểm uy tín 0–1000 được cộng trừ theo từng loại sự kiện và quyết định bậc của tài khoản; bậc lại quyết định số tin được đăng và số đơn COD được mở cùng lúc. Quyền COD và bậc uy tín không mua được bằng gói trả phí (BR-16), vì nếu mua được thì con số không còn phản ánh hành vi.

== Tìm kiếm ngữ nghĩa và tìm kiếm lai

Tin đăng do người không chuyên viết: cùng một món có thể được ghi "ip 13 zin", "iPhone 13 cũ" hay "điện thoại Apple". Tìm kiếm theo từ khóa khớp chính xác các từ có trong tin; nó tốt với tên riêng và mã model, và khi văn bản được bỏ dấu trước thì "xe dap" vẫn khớp "xe đạp", nhưng nó không hiểu "đồ tặng sinh nhật" và "quà" là gần nhau.

Tìm kiếm ngữ nghĩa biểu diễn mỗi đoạn văn bản thành một vector nhúng sao cho các câu cùng nghĩa có vector gần nhau, rồi trả về những tin gần truy vấn nhất. Mô hình BGE-M3 [4] cho cùng lúc hai biểu diễn: vector dày 1024 chiều mang nghĩa tổng quát, và vector thưa gồm trọng số của từng từ, gần với tìm kiếm từ khóa nhưng trọng số được học từ dữ liệu. Để không phải so truy vấn với mọi tin, chỉ mục HNSW [9] tìm lân cận gần đúng với số phép so sánh nhỏ hơn nhiều; phần mở rộng pgvector [17] đặt chỉ mục này ngay trong PostgreSQL, cạnh các bộ lọc giá, danh mục và vị trí.

Ba cách tìm trên cho ba danh sách xếp hạng với thang điểm khác nhau, không cộng trực tiếp được. Reciprocal Rank Fusion [5] chỉ dùng thứ hạng: một tin được cộng điểm theo nghịch đảo thứ hạng của nó trong từng danh sách, theo công thức (2.1):

#[
  #set math.equation(numbering: n => "(2." + str(n) + ")", block: true)
  $ "RRF"(d) = sum_(i) w_i / (k + r_i (d)) $
]

trong đó $r_i (d)$ là thứ hạng của tin $d$ trong danh sách thứ $i$, $w_i$ là trọng số của tín hiệu và $k$ là hằng số làm mượt, ShopNexus dùng $k = 60$. Tin không có trong một danh sách thì không nhận điểm từ danh sách đó. Hằng số $k$ làm giảm chênh lệch giữa hạng 1 và hạng 2, nên một tin đứng khá cao ở cả ba danh sách thường vượt một tin chỉ đứng đầu ở một danh sách.

== AI agent hỗ trợ người mua

Người mua thường nói nhu cầu bằng một câu như "xe đạp cho bé 6 tuổi, tầm 500 nghìn, gần đây thôi" chứ không tự chọn danh mục, khoảng giá và bán kính. Mô hình ngôn ngữ lớn (LLM) hiểu được câu đó, nhưng tự nó không biết sàn có những danh mục nào hay tin nào đang bán. Cơ chế gọi công cụ cho phép mô hình, thay vì trả lời ngay, yêu cầu ứng dụng chạy một thao tác đã khai báo trước, như tra danh mục hay tìm tin, rồi đọc kết quả trả về. Vòng lặp ReAct [12] xen kẽ suy luận và hành động theo cách này cho đến khi đủ thông tin để trả lời. Với câu trên, agent tách ra ràng buộc giá và khoảng cách, tra danh mục xe đạp trẻ em, rồi gọi tìm kiếm lai với bộ lọc tương ứng.

Rủi ro của agent là mô hình có thể chọn sai công cụ, lặp không dừng, chậm hoặc tự thêm ràng buộc mà người dùng không nói. ShopNexus giới hạn các rủi ro này ngay từ nghiệp vụ: agent chỉ được đọc, không đặt hàng, không thương lượng (BR-18); mỗi lượt tìm dừng sau tối đa 4 lần gọi công cụ hoặc 8 giây, quá giới hạn thì trả về kết quả tìm kiếm lai với câu gốc; mỗi ràng buộc agent đặt ra hiện thành một chip người dùng sửa hoặc xóa được. Vì câu gốc của người dùng luôn được giữ trong lượt tìm, kết quả xấu nhất vẫn bằng tìm kiếm lai thông thường.

== Kiến trúc microservice và độ tin cậy của quy trình

Kiến trúc microservice chia hệ thống thành các dịch vụ nhỏ theo phân hệ nghiệp vụ; mỗi dịch vụ giữ dữ liệu riêng và chỉ cho dịch vụ khác dùng qua giao diện đã công bố [10], [11]. Ở ShopNexus, thương lượng và đơn COD thuộc một dịch vụ, đánh giá và uy tín thuộc một dịch vụ khác, nên mỗi quy tắc nghiệp vụ nằm ở đúng một chỗ. Để nhóm ba người không phải vận hành nhiều tiến trình ngay từ đầu, các dịch vụ chạy chung một tiến trình nhưng vẫn giữ nguyên ranh giới, và có thể tách ra khi cần mà không sửa nghiệp vụ.

Khi một thao tác gồm nhiều bước chạm tới hệ thống ngoài, sự cố máy chủ giữa chừng có thể để lại dữ liệu dở dang. Chẳng hạn, khi người bán tạo đơn, hệ thống lần lượt tạo vận đơn trên tài khoản hãng của người bán, giữ tin cho người mua này và hủy các yêu cầu COD khác trên tin. Cách truyền thống là viết kèm mỗi bước một thao tác bù trừ để hoàn tác [6]. ShopNexus dùng Restate [18], một nền tảng thực thi bền [3]: mỗi bước đã xong được ghi lại, nên sau sự cố quy trình chạy tiếp từ bước dang dở và không tạo vận đơn thứ hai. Các thao tác ghi cũng được thiết kế để một yêu cầu gửi lặp cho cùng kết quả như gửi một lần [7], còn thông báo giữa các phân hệ được lưu cùng lúc với thay đổi dữ liệu nên không bị mất khi có sự cố [8].

Ứng dụng Android viết bằng Jetpack Compose theo hướng dẫn kiến trúc của Android [13]: mỗi màn hình hiển thị một trạng thái do tầng xử lý giữ, thao tác của người dùng được gửi ngược về tầng đó, nên trạng thái chỉ đổi ở một nơi và dễ kiểm thử.

== Công nghệ sử dụng

Bảng 2.1 liệt kê các công nghệ chính và lý do chọn.

#figure(
  kind: table,
  caption: [Công nghệ sử dụng trong hệ thống],
  table(
    columns: (2.8cm, 4.2cm, 1fr),
    table.header([Thành phần], [Công nghệ, phiên bản], [Lý do chọn]),
    [Dịch vụ nền], [Go], [Chạy nhẹ, khởi động nhanh, phù hợp nhiều dịch vụ nhỏ],
    [CSDL], [PostgreSQL 19, pgvector], [Dữ liệu nhất quán; tìm kiếm từ khóa và ngữ nghĩa trong cùng một hệ],
    [Thực thi bền], [Restate 1.8.0, Go SDK v1.1.0], [Quy trình nhiều bước chạy tiếp sau sự cố, không lặp vận đơn hay tin nhắn],
    [Kho ảnh], [RustFS 1.0.4], [Lưu ảnh tin đăng, tương thích chuẩn S3],
    [Quan trắc], [OpenTelemetry, Grafana LGTM], [Theo dõi lỗi và thời gian phản hồi của từng yêu cầu],
    [Đặc tả API], [OpenAPI 3.2], [Hợp đồng chung cho ứng dụng, dịch vụ nền và kiểm thử],
    [Tìm kiếm, AI], [BGE-M3, LLM qua LiteLLM], [Hiểu tiếng Việt viết tự do; đổi mô hình không phải sửa hệ thống],
    [Vận chuyển], [API GHTK [15], GHN [14]], [Tạo, hủy vận đơn, báo phí và trạng thái giao hàng],
    [Ứng dụng], [Kotlin 2.4.21, Jetpack Compose, Material 3, Hilt 2.60.1], [Giao diện khai báo theo chuẩn Android],
    [Kiểm thử ứng dụng], [JUnit 4, Turbine, Robolectric 4.17, Roborazzi 1.76], [Kiểm tra màn hình và so ảnh chụp không cần thiết bị thật],
  ),
)
