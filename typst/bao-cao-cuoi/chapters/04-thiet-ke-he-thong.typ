#import "../../common/tokens.typ": *

// Nhãn thông điệp của sơ đồ trình tự: nền trắng để đường sinh đi sau nhãn không cắt chữ.
#let ml(b) = lbl(text(size: 8.5pt, b))

= THIẾT KẾ HỆ THỐNG

Chương này đi từ những yêu cầu chi phối thiết kế tới kiến trúc tổng thể, cách các phân hệ phối hợp với nhau, thiết kế uy tín và cảnh báo lừa đảo, dữ liệu, hai quy trình chính, các chức năng AI, giao diện lập trình và bảo mật. Trọng tâm là hệ thống bảo đảm gì cho người mua và người bán; cách hiện thực cụ thể được trình bày ở Chương 5.

== Yếu tố dẫn dắt thiết kế

Phần lớn yêu cầu chức năng ở Chương 3 chỉ thêm một chức năng vào một phân hệ đã có. Sáu yếu tố trong Bảng 4.1 thì khác: bỏ qua chúng sẽ phải thay đổi cấu trúc hệ thống. Mỗi yếu tố gắn với yêu cầu sinh ra nó và cách thiết kế đáp ứng; các mục sau lần lượt triển khai từng cách.

#figure(
  kind: table,
  caption: [Các yếu tố dẫn dắt thiết kế và cách hệ thống đáp ứng],
  table(
    columns: (0.5fr, 1.7fr, 0.6fr, 2.3fr),
    align: (center + horizon, left + horizon, left + horizon, left + horizon),
    table.header([Mã], [Yếu tố], [Nguồn], [Cách thiết kế đáp ứng]),
    [AD-01], [Quy trình nhiều bước có liên quan tới hãng vận chuyển không được dừng dở dang], [NFR-DUR-01],
    [Mỗi quy trình ghi nhận từng bước đã xong; máy chủ gặp sự cố thì quy trình chạy tiếp từ bước đã ghi, không làm lại bước cũ [3]],
    [AD-02], [Người dùng bấm lặp, mạng chập chờn hoặc hãng báo trùng không được tạo hai đơn, hai vận đơn], [NFR-IDEM-01],
    [Mỗi thao tác quan trọng mang một mã yêu cầu do ứng dụng sinh; gửi lại cùng mã thì nhận lại kết quả của lần đầu [7]],
    [AD-03], [Hai người cùng thao tác trên một phiên trả giá; hạn mức đơn COD và số tin đang bán không được vượt], [NFR-CONC-01],
    [Chỉ lượt ghi đến trước được nhận, lượt sau được báo dữ liệu đã đổi để xem lại; hạn mức được đếm lần lượt theo từng người],
    [AD-04], [Tin báo giữa các phân hệ, như đơn đã hoàn tất hay tin đã bán, không được mất], [NFR-MSG-01],
    [Tin báo được lưu cùng lúc với thay đổi sinh ra nó và được gửi lại cho tới khi nơi nhận xử lý xong [8]],
    [AD-05], [Tách một phân hệ ra máy chủ riêng khi tải tăng mà không viết lại nghiệp vụ], [NFR-ARCH-01],
    [Phân hệ chỉ gọi nhau qua các chức năng đã công bố và chỉ dùng dữ liệu của chính mình [10]],
    [AD-06], [Tìm kiếm có AI phải trả kết quả nhanh và không kém tìm theo từ khóa], [NFR-PERF-01],
    [Mô hình đọc câu một lần, tối đa 4 giây, cách đọc được lưu 7 ngày; quá hạn thì tìm bằng câu gốc],
  ),
)

== Kiến trúc tổng thể

Hình 4.1 trình bày kiến trúc theo năm tầng. Tầng khách gồm ứng dụng Android và website cho người mua, người bán, cùng trang điều hành cho nhân viên. Tầng giao tiếp là nơi duy nhất nhận yêu cầu từ bên ngoài: giao diện lập trình được đặc tả trước [19], kênh cập nhật thời gian thực cho màn hình đang mở, và cổng nhận trạng thái vận đơn do hãng vận chuyển báo về. Mọi yêu cầu được kiểm theo đặc tả và xác thực người gọi trước khi tới phân hệ nghiệp vụ. Tầng nền tảng cung cấp những thứ mọi phân hệ dùng chung: điều phối quy trình nhiều bước, kênh tin báo giữa các phân hệ, cơ sở dữ liệu có tìm kiếm theo từ khóa và theo nghĩa, kho ảnh, cổng mô hình ngôn ngữ lớn (LLM) và giám sát vận hành.

#fig(
  [Kiến trúc tổng thể của hệ thống],
  spacing: (0mm, 5mm),
  band((0, 0), "KHÁCH", (
    [Ứng dụng Android], [Website], [Trang điều hành],
  ), rong: 150mm, name: <a-client>),
  band((0, 1), "GIAO TIẾP", (
    [Giao diện lập trình theo đặc tả], [Kênh cập nhật thời gian thực], [Cổng nhận trạng thái vận đơn],
  ), rong: 150mm,
    ghi: [Kiểm yêu cầu theo đặc tả, xác thực người gọi, giới hạn kích thước yêu cầu.],
    name: <a-api>),
  band((0, 2), "PHÂN HỆ NGHIỆP VỤ", (
    [Tài khoản], [Trang điều hành], [Ảnh], [Tin đăng], [Hỗ trợ đăng tin], [Khám phá],
    [Trò chuyện], [Giao dịch], [Vận chuyển], [Uy tín], [Hỗ trợ], [Thông báo],
    [Màn hình], [Xóa dữ liệu], [AI], [Trợ lý AI],
  ), cot: 6, rong: 150mm, nen: headfill,
    ghi: [Phân hệ gọi nhau qua chức năng đã công bố; mỗi phân hệ chỉ dùng dữ liệu của mình.],
    name: <a-svc>),
  band((0, 3), "NỀN TẢNG", (
    [Điều phối quy trình], [Kênh tin báo], [Cơ sở dữ liệu], [Kho ảnh], [Cổng mô hình ngôn ngữ], [Giám sát],
  ), rong: 150mm, name: <a-plat>),
  band((0, 4), "HỆ THỐNG BÊN NGOÀI", (
    [GHTK, GHN], [Mô hình ngôn ngữ lớn], [Xác thực số điện thoại, Google], [Email], [Đẩy thông báo], [Chợ Tốt],
  ), rong: 150mm,
    ghi: [Mọi lời gọi ra ngoài là một bước có ghi nhận của quy trình, nên không bị lặp khi thử lại.],
    name: <a-ext>),
  edge(<a-client>, <a-api>, "-|>", rel[yêu cầu của người dùng]),
  edge(<a-api>, <a-svc>, "-|>", rel[gọi chức năng nghiệp vụ]),
  edge(<a-svc>, <a-plat>, "-|>", rel[lưu dữ liệu, chạy quy trình, gửi tin báo]),
  edge(<a-plat>, <a-ext>, "-|>", rel[gọi đối tác trong một bước]),
)

Bảng 4.2 liệt kê chức năng và dữ liệu của từng phân hệ. Ngoài 16 phân hệ này, vòng lặp của trợ lý AI cho nhân viên chạy thành một dịch vụ riêng trong mạng nội bộ; phân hệ Trợ lý AI chỉ chuyển tiếp yêu cầu của trang điều hành tới dịch vụ đó và cấp cho nó các công cụ chỉ đọc.

#figure(
  kind: table,
  caption: [Các phân hệ của dịch vụ nền],
  table(
    columns: (0.9fr, 2.3fr, 1.6fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Phân hệ], [Chức năng], [Dữ liệu quản lý]),
    [Tài khoản], [Đăng nhập, phiên, hồ sơ, sổ địa chỉ, chặn, theo dõi người bán, tạm khóa], [Tài khoản, định danh, phiên, địa chỉ],
    [Trang điều hành], [Nhân viên, phân quyền, nhật ký kiểm toán], [Nhân viên, phiên, nhật ký],
    [Ảnh], [Nhận ảnh và video tải lên, xử lý ảnh], [Tệp đã tải],
    [Tin đăng], [Tin đăng, nháp, danh mục, địa giới, chỉ mục tìm kiếm, lượt xem], [Tin, nháp, danh mục, xã],
    [Hỗ trợ đăng tin], [AI đọc video, ảnh, link Chợ Tốt; gợi ý giá], [Lượt đọc],
    [Khám phá], [Hiểu câu tìm, tìm kiếm lai, lưu tin, báo giảm giá, theo dõi tìm kiếm, ẩn tin], [Cách đọc câu, tin đã lưu, câu theo dõi],
    [Trò chuyện], [Cuộc trò chuyện, tin nhắn, tìm trong hộp thư], [Cuộc trò chuyện, tin nhắn],
    [Giao dịch], [Trả giá, đơn COD, thời hạn của đơn], [Phiên trả giá, lượt trả giá, đơn],
    [Vận chuyển], [Liên kết tài khoản hãng, phí, vận đơn, trạng thái hãng báo], [Liên kết hãng],
    [Uy tín], [Đánh giá hai chiều, báo cáo vi phạm, cảnh báo lừa đảo], [Đánh giá, báo cáo, cảnh báo],
    [Hỗ trợ], [Phiếu hỗ trợ], [Phiếu],
    [Thông báo], [Thông báo trong ứng dụng, đẩy về điện thoại, cài đặt], [Thông báo, thiết bị],
    [Màn hình], [Ghép dữ liệu của nhiều phân hệ cho một màn hình, như trang Uy tín], [Không có],
    [Xóa dữ liệu], [Xóa tài khoản theo yêu cầu của người dùng], [Không có],
    [AI], [Nhận dạng tiếng nói, cắt khung hình video, nhúng ảnh], [Không có],
    [Trợ lý AI], [Chuyển tiếp tới dịch vụ trợ lý AI, chạy nền, công cụ chỉ đọc], [Không có],
  ),
)

Các phân hệ chạy trong cùng một chương trình; khi triển khai, phần AI chạy thành tiến trình riêng vì cần nhiều bộ nhớ. Chạy chung không làm mờ ranh giới: một phân hệ chỉ thấy các chức năng mà phân hệ khác công bố, không đọc thẳng dữ liệu của nhau, và việc kiểm tra tự động trước mỗi lần tích hợp mã từ chối mọi chỗ vượt ranh giới. Nhờ vậy, khi cần tách một phân hệ ra máy chủ riêng, chỉ phải đổi cách gọi từ gọi trong máy sang gọi qua mạng, nghiệp vụ giữ nguyên (AD-05).

== Phối hợp giữa các phân hệ

Các phân hệ phối hợp theo ba cách. Khi cần câu trả lời ngay, một phân hệ hỏi trực tiếp phân hệ kia, ví dụ phân hệ giao dịch hỏi phân hệ tin đăng giá niêm yết và tình trạng tin trước khi nhận một giá trả. Khi công việc gồm nhiều bước có tác động ra bên ngoài, nó chạy thành một quy trình có ghi nhận tiến độ. Khi một thay đổi cần được nhiều nơi biết mà bên gây ra không cần chờ, nó được gửi đi dưới dạng tin báo.

=== Quy trình nhiều bước

Một thao tác ghi vào nhiều nhóm dữ liệu, gọi tới đối tác bên ngoài hoặc phải chờ một thời hạn chạy thành một quy trình có ghi nhận tiến độ (AD-01). Bảng 4.3 liệt kê các quy trình chính. Mỗi bước sau khi xong được ghi lại cùng kết quả; nếu máy chủ sập, quy trình chạy tiếp từ bước kế tiếp và dùng lại kết quả đã ghi, nên người bán không nhận hai vận đơn, người dùng không nhận hai email mã OTP. Khi một bước bị từ chối vì lý do nghiệp vụ, chẳng hạn người mua đã đủ 3 đơn COD đang mở, quy trình dừng và báo lý do thay vì thử lại một việc không thể thành công. Mã OTP không bao giờ được ghi vào nhật ký tiến độ.

#figure(
  kind: table,
  caption: [Các quy trình nhiều bước có ghi nhận tiến độ],
  table(
    columns: (1.35fr, 0.85fr, 2.25fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Quy trình], [Phân hệ], [Việc thực hiện]),
    [Đăng nhập], [Tài khoản], [Tìm định danh hoặc tạo tài khoản ở lần đầu; trùng thì không ghi gì [6]],
    [Gửi mã email], [Tài khoản], [Kiểm hạn mức gửi, gửi mã sáu chữ số],
    [Đăng tin, sửa tin], [Tin đăng], [Kiểm hạn mức số tin, gắn ảnh vào tin],
    [Mở bán, lập chỉ mục], [Tin đăng], [Chuyển tin sang đang bán, nhúng văn bản và ảnh của tin],
    [Xử lý ảnh, dọn ảnh thừa], [Ảnh], [Kiểm định dạng, thu nhỏ, xóa thông tin kèm ảnh; xóa ảnh không dùng sau 24 giờ],
    [AI đọc tin], [Hỗ trợ đăng tin], [Đọc video, ảnh hoặc link thành bản nháp tin đăng],
    [Gửi, phát tin nhắn], [Trò chuyện], [Gửi tin nhắn, phát tới người nhận khi ảnh đính kèm xử lý xong],
    [Kiểm tra lừa đảo], [Uy tín], [Đọc 20 tin nhắn gần nhất của một cuộc trò chuyện, ghi cảnh báo],
    [Yêu cầu COD], [Giao dịch], [Kiểm hạn mức, tạo đơn chờ, hẹn 3 ngày cho người bán],
    [Tạo đơn gửi hàng], [Giao dịch], [Tạo hoặc đọc vận đơn, giữ chỗ tin, hủy yêu cầu COD khác],
    [Thời hạn của đơn], [Giao dịch], [Hủy khi người bán hay hãng quá 3 ngày; tự hoàn tất 3 ngày sau khi giao; hỏi lại hãng mỗi 2 giờ],
    [Nhận trạng thái vận đơn], [Vận chuyển], [Ghi trạng thái hãng báo về, mỗi trạng thái đúng một lần],
    [Mở phiếu hỗ trợ], [Hỗ trợ], [Tạo phiếu và cuộc trò chuyện của phiếu],
    [Quét theo dõi tìm kiếm], [Khám phá], [Mỗi 30 phút tìm tin mới khớp câu đã theo dõi],
    [Chạy nền trợ lý AI], [Trợ lý AI], [Cho trợ lý AI đọc phiếu, báo cáo mới và soạn đề xuất],
  ),
)

=== Tin báo giữa các phân hệ

Khi một đơn COD hay một tin đăng đổi trạng thái, hệ thống ghi lại sự thay đổi đó cùng lúc với tin báo cho các phân hệ liên quan, nên không có trường hợp đơn đã đổi mà phân hệ tìm kiếm hay thông báo không biết (AD-04). Nếu một phân hệ tạm thời không nhận được, tin báo được giữ lại và gửi lại sau với khoảng chờ tăng dần, tối đa một giờ; một nơi nhận lỗi không chặn các nơi khác. Hình 4.2 lấy ví dụ lúc người mua bấm đã nhận hàng.

#fig(
  [Luồng thông tin giữa các phân hệ khi một đơn hoàn tất],
  spacing: (10mm, 14mm),
  np((0, 0), [Người mua\ #text(size: 8.5pt)[bấm đã nhận hàng]], shape: rect, name: <f-hang>),
  ncore((1, 0), [Giao dịch\ #text(size: 8.5pt, weight: 400)[đơn chuyển hoàn tất]], shape: rect, name: <f-gd>),
  np((0, 1), [Tìm kiếm\ #text(size: 8.5pt)[bỏ tin khỏi kết quả]], shape: rect, name: <f-tk>),
  np((1, 1), [Tin đăng\ #text(size: 8.5pt)[tin chuyển đã bán]], shape: rect, name: <f-tin>),
  np((2, 1), [Trò chuyện\ #text(size: 8.5pt)[hiện bước của đơn]], shape: rect, name: <f-ct>),
  np((3, 1), [Thông báo\ #text(size: 8.5pt)[báo hai bên, mời đánh giá]], shape: rect, name: <f-tb>),
  edge(<f-hang>, <f-gd>, "-|>"),
  edge(<f-gd>, <f-tin>, "-|>", label-side: right, rel[bán tin]),
  edge(<f-gd>, <f-ct>, "-|>", stroke: (dash: "dashed")),
  edge(<f-gd>, <f-tb>, "-|>", stroke: (dash: "dashed")),
  edge(<f-tin>, <f-tk>, "-|>", stroke: (dash: "dashed")),
  node((3, 0), align(left, text(size: 8pt)[
    #box(line(length: 9mm, stroke: 1.1pt + muted), baseline: -0.3em) bước trong quy trình\
    #box(line(length: 9mm, stroke: (paint: muted, thickness: 1.1pt, dash: "dashed")), baseline: -0.3em) tin báo
  ]), stroke: none, fill: none),
)

Tin báo chỉ nói điều gì đã xảy ra với đối tượng nào; nơi nhận tự hỏi lại trạng thái hiện tại của đối tượng đó. Vì vậy tin đến chậm, đến sai thứ tự hay đến hai lần đều cho cùng kết quả. Theo cách này, phân hệ tin đăng lập lại chỉ mục mỗi khi tin đổi; phân hệ giao dịch đóng giá đang mở và hủy yêu cầu COD khi tin bị sửa, ẩn, bán hay xóa; phân hệ khám phá báo người đã lưu tin khi tin giảm giá và báo người theo dõi khi người bán đăng tin mới; phân hệ thông báo báo cho người dùng mọi thay đổi của phiên trả giá, đơn COD, đánh giá và phiếu hỗ trợ; khi một tài khoản bị xóa, mỗi phân hệ tự xóa dữ liệu của tài khoản đó.

Màn hình đang mở trên ứng dụng và website được cập nhật qua một kết nối thời gian thực. Mỗi tài khoản có một dãy sự kiện đánh số tăng dần; khi mất kết nối, ứng dụng nối lại kèm số cuối cùng đã nhận và nhận đúng phần đã lỡ. Sự kiện chỉ nói tin nhắn, phiên trả giá, đơn COD hay thông báo nào vừa đổi, ứng dụng tự lấy dữ liệu mới, nên một sự kiện bị lỡ chỉ làm màn hình cập nhật chậm hơn chứ không hiển thị sai.

== Thiết kế uy tín và cảnh báo lừa đảo

Hệ thống không phán xử từng vụ việc, nên thông tin giúp người dùng quyết định có giao dịch với một người hay không đi qua hai kênh: số liệu uy tín công khai và cảnh báo trong cuộc trò chuyện. Hình 4.3 cho thấy nguồn của từng số liệu trên trang Uy tín và trang hồ sơ người bán. Mỗi số liệu đến từ phân hệ đang giữ dữ liệu gốc và được tính lại mỗi lần có người mở trang, nên không có bảng điểm riêng nào có thể lệch với dữ liệu thật.

#fig(
  [Nguồn của các số liệu uy tín],
  spacing: (15mm, 8mm),
  np((0, 0), align(left, text(size: 9pt)[
    *Uy tín*\
    đánh giá khi bán, khi mua:\ #h(1em) số sao trung bình, số lượt
  ]), shape: rect, name: <r-dg>),
  np((0, 1), align(left, text(size: 9pt)[
    *Giao dịch*\
    số món đã bán;\
    số đơn COD và số đơn\ #h(1em) giao không thành trong 90 ngày
  ]), shape: rect, name: <r-gd>),
  np((0, 2), align(left, text(size: 9pt)[
    *Trò chuyện*\
    tỉ lệ trả lời trong 24 giờ,\ #h(1em) từ 5 cuộc trò chuyện trong 90 ngày
  ]), shape: rect, name: <r-ct>),
  np((0, 3), align(left, text(size: 9pt)[
    *Tài khoản*\
    ngày tham gia, số người theo dõi
  ]), shape: rect, name: <r-tk>),
  ncore((1.3, 1.5), [Trang Uy tín\ và hồ sơ người bán], shape: rect, name: <r-man>),
  nr((2.4, 1.5), align(left, text(size: 9pt)[
    *Hạn mức chung*\
    3 đơn COD đang mở khi mua\
    20 tin đang bán
  ]), shape: rect, name: <r-hm>),
  edge(<r-dg>, <r-man>, "-|>"),
  edge(<r-gd>, <r-man>, "-|>"),
  edge(<r-ct>, <r-man>, "-|>"),
  edge(<r-tk>, <r-man>, "-|>"),
  edge(<r-hm>, <r-man>, "-|>", stroke: (dash: "dashed"), label-side: right, rel[đang dùng]),
)

Đánh giá hai chiều được thiết kế để giảm đánh giá trả đũa (BR-TRS-04). Sau khi đơn hoàn tất, mỗi bên có một đánh giá về bên kia. Một đánh giá chỉ hiện với người được đánh giá và người ngoài khi bên kia cũng đã đánh giá, hoặc khi đã qua 7 ngày kể từ lúc giao. Người được đánh giá trả lời được một lần; sau câu trả lời, đánh giá không sửa hay xóa được nữa. Hồ sơ hiện hai điểm sao riêng, khi bán và khi mua, vì người bán và người mua chịu các rủi ro khác nhau.

Cảnh báo lừa đảo chạy sau mỗi tin nhắn có chữ, từ bất kỳ bên nào (BR-TRS-06). Trước khi đưa cho bộ phát hiện, hệ thống thay số điện thoại, số tài khoản, số thẻ, email và link bằng ký hiệu giữ chỗ. Bộ phát hiện chỉ chọn mã trong một danh sách dấu hiệu cố định, gồm bảy dấu hiệu trong tin nhắn và hai dữ kiện về tài khoản và giá (Bảng 5.1). Cảnh báo chỉ hiện khi có ít nhất một dấu hiệu trong tin nhắn; hai dữ kiện chỉ đi kèm làm bằng chứng. Bộ phát hiện đứng sau một giao diện riêng: hiện nay là mô hình ngôn ngữ, sau này có thể là một mô hình được huấn luyện trên chính các kết quả đã lưu, mà không đổi bảng dữ liệu, giao diện lập trình hay ứng dụng.

== Thiết kế dữ liệu

Hình 4.4 là sơ đồ thực thể quan hệ mức khái niệm, các thực thể được nhóm theo phân hệ quản lý bằng khung nét đứt. Quan hệ vượt khung chỉ là mã tham chiếu: phân hệ này ghi mã đối tượng của phân hệ kia chứ không đọc thẳng dữ liệu của nó.

#fig(
  [Sơ đồ thực thể quan hệ mức khái niệm, nhóm theo phân hệ],
  spacing: (13mm, 11mm),
  edge-stroke: 1pt + blue-s,
  label-wrapper: wlabel,
  label-size: 8pt,
  nent((0, 0), <e-addr>, [ĐỊA CHỈ]),
  nent((0, 1), <e-acc>, [TÀI KHOẢN]),
  nent((0, 2.2), <e-conv>, [CUỘC TRÒ CHUYỆN]),
  nent((0, 3.2), <e-msg>, [TIN NHẮN]),
  nent((-1, 2.2), <e-tick>, [PHIẾU HỖ TRỢ]),
  nent((1, 0), <e-cat>, [DANH MỤC]),
  nent((1, 1), <e-lst>, [TIN ĐĂNG]),
  nent((1, 2), <e-com>, [PHƯỜNG/XÃ]),
  nent((2, 0), <e-mv>, [LƯỢT TRẢ GIÁ]),
  nent((2, 1), <e-deal>, [PHIÊN TRẢ GIÁ]),
  nent((2, 2), <e-ord>, [ĐƠN COD]),
  nent((2, 3.2), <e-link>, [LIÊN KẾT HÃNG]),
  nent((3, 2), <e-rev>, [ĐÁNH GIÁ]),
  nent((3, 3.2), <e-scam>, [CẢNH BÁO\ LỪA ĐẢO]),

  ngroup((<e-addr>, <e-acc>)), gtitle((0, -0.55), [tài khoản]),
  ngroup((<e-conv>, <e-msg>)), gtitle((0, 3.72), [trò chuyện]),
  ngroup((<e-tick>,)), gtitle((-1, 2.72), [hỗ trợ]),
  ngroup((<e-cat>, <e-lst>, <e-com>)), gtitle((1, -0.55), [tin đăng]),
  ngroup((<e-mv>, <e-deal>, <e-ord>)), gtitle((2, -0.55), [giao dịch]),
  ngroup((<e-link>,)), gtitle((2, 3.72), [vận chuyển]),
  ngroup((<e-rev>, <e-scam>)), gtitle((3, 1.48), [uy tín]),

  edge(<e-acc>, <e-addr>, "1-n", [có]),
  edge(<e-acc>, <e-lst>, "1-n", [đăng bán]),
  edge(<e-acc>, <e-deal>, "1-n", bend: 32deg, label-pos: 0.8, [mua qua]),
  edge(<e-acc>, <e-conv>, "n-n", [tham gia]),
  edge(<e-conv>, <e-msg>, "1-n", [chứa]),
  edge(<e-tick>, <e-conv>, "1-1", [mở]),
  edge(<e-cat>, <e-lst>, "1-n", [phân loại]),
  edge(<e-com>, <e-lst>, "1-n", [vị trí]),
  edge(<e-lst>, <e-deal>, "1-n", [được trả giá]),
  edge(<e-deal>, <e-mv>, "1-n", [ghi]),
  edge(<e-deal>, <e-ord>, "1-n", [sinh]),
  edge(<e-ord>, <e-link>, "n-1", [gửi qua]),
  edge(<e-ord>, <e-rev>, "1-n", [được]),
  edge(<e-conv>, <e-scam>, "1-1?", bend: -28deg, label-pos: 0.6, [có]),
)

Mỗi tin đăng có nhiều phiên trả giá nhưng mỗi người mua chỉ có một phiên trả giá trên một tin; mỗi phiên trả giá có thể sinh nhiều đơn theo thời gian, vì khi đơn giao không thành hoặc bị hủy, phiên trả giá trở về đang trả giá; mỗi đơn có tối đa hai đánh giá, một của mỗi bên. Một phiếu hỗ trợ là một cuộc trò chuyện loại hỗ trợ giữa người dùng và hệ thống, nên tin nhắn của phiếu dùng chung mọi chức năng của trò chuyện. Mỗi cuộc trò chuyện có tối đa một cảnh báo lừa đảo đang hiệu lực. Bảng 4.4 tóm tắt dữ liệu chính của từng phân hệ cùng những quy tắc mà cơ sở dữ liệu trực tiếp bảo đảm, để luật nghiệp vụ đúng ngay cả khi có lỗi lập trình ở phía trên.

#figure(
  kind: table,
  caption: [Dữ liệu chính theo phân hệ và các quy tắc được bảo đảm],
  table(
    columns: (0.75fr, 1.45fr, 2.6fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Phân hệ], [Dữ liệu], [Quy tắc được bảo đảm]),
    [Tài khoản], [Tài khoản, định danh, phiên, địa chỉ], [Mỗi số điện thoại hoặc email chỉ gắn với một tài khoản; mỗi mã làm mới phiên chỉ dùng được một lần; tối đa 10 địa chỉ],
    [Tin đăng], [Tin đăng, nháp, danh mục, phường/xã], [Ảnh và thông số lưu cùng tin; vị trí chỉ lưu đến 3.321 phường/xã sau sáp nhập 2025; chỉ mục từ khóa cập nhật cùng giao dịch ghi tin],
    [Khám phá], [Cách đọc câu, tin đã lưu, câu theo dõi], [Cách đọc câu lưu theo câu tìm, không gắn tài khoản, hết hạn sau 7 ngày],
    [Giao dịch], [Phiên trả giá, lượt trả giá, đơn COD], [Mỗi người mua một phiên trả giá trên một tin; mỗi phiên trả giá một đơn đang mở; mỗi tin một đơn đã gửi],
    [Vận chuyển], [Liên kết hãng], [Mỗi người bán tối đa một tài khoản mỗi hãng; khóa kết nối được mã hóa],
    [Trò chuyện], [Cuộc trò chuyện, tin nhắn], [Mỗi cặp người dùng chỉ có một cuộc trò chuyện; mỗi phiếu một cuộc trò chuyện riêng],
    [Uy tín], [Đánh giá, báo cáo, cảnh báo], [Mỗi bên tối đa một đánh giá trên một đơn và một câu trả lời trên một đánh giá],
    [Trang điều hành], [Nhân viên, nhật ký kiểm toán], [Email nhân viên không trùng; mọi thao tác ghi đều có dòng nhật ký],
  ),
)

Khi hai thao tác cùng sửa một phiên trả giá, ví dụ người bán phản giá đúng lúc người mua chấp nhận giá cũ, chỉ lượt đến trước được ghi; lượt sau được báo phiên trả giá vừa thay đổi, ứng dụng hiện giá mới để người dùng quyết định lại (AD-03). Hạn mức như số đơn COD đang mở hay số tin đang bán được kiểm lần lượt theo từng người: người mua gửi cùng lúc năm yêu cầu COD thì đúng ba yêu cầu được nhận.

== Thiết kế các luồng xử lý chính

Hình 4.5 là trình tự của UC-DEAL-04. Khi người bán tạo đơn, phân hệ giao dịch kiểm đơn còn ở trạng thái chờ tạo đơn. Nếu người bán chọn tạo qua hãng, phân hệ vận chuyển tạo vận đơn trên tài khoản hãng của chính người bán, thu hộ tiền hàng, đặt chế độ người nhận trả phí vận chuyển, rồi nhận mã vận đơn và phí thật. Nếu người bán nhập mã đã tạo trên ứng dụng của hãng, phân hệ vận chuyển đọc vận đơn đó bằng tài khoản của người bán; mã không thuộc tài khoản này bị từ chối (BR-DEAL-12). Sau đó phân hệ tin đăng giữ tin cho người mua này, đơn chuyển sang đã gửi và các yêu cầu COD khác trên cùng tin tự hủy với lý do đã gửi cho người khác (BR-DEAL-04); người mua và những người bị hủy yêu cầu đều được báo. Quy trình hẹn 3 ngày cho hãng lấy hàng và bắt đầu hỏi lại hãng mỗi 2 giờ. Nếu máy chủ gặp sự cố giữa chừng, quy trình tiếp tục từ bước đã xong nên hãng không nhận lệnh tạo vận đơn lần hai (NFR-DUR-01); người bán bấm lặp cũng chỉ nhận lại đơn đã tạo (NFR-IDEM-01).

#fig(
  [Sơ đồ trình tự UC-DEAL-04: người bán tạo đơn gửi hàng],
  spacing: (10mm, 4.9mm),
  np((0, 0), [:Người bán], shape: rect),
  ncore((1, 0), [Giao dịch], shape: rect),
  np((2, 0), [Vận chuyển], shape: rect),
  np((3, 0), [Hãng vận chuyển], shape: rect),
  np((4, 0), [Tin đăng], shape: rect),
  np((5, 0), [Thông báo], shape: rect),
  ..lifelines(6, y1: 18.8),
  msg(0, 1, 1.5, ml[1\. Tạo đơn gửi hàng]),
  durable(1, 2.4, text(size: 8.5pt)[2\. Kiểm đơn\ chờ tạo đơn]),
  ..khung("alt", 0.55, 3.45, 3.7, 12.0),
  dkien(1.25, 3.7, text(size: 8pt)[tạo qua hãng]),
  msg(1, 2, 5.0, ml[3a. Tạo vận đơn]),
  msg(2, 3, 6.2, ml[4a. Tạo vận đơn, thu hộ,\ người nhận trả phí]),
  rmsg(3, 2, 7.5, ml[5a. Mã vận đơn, phí thật]),
  rmsg(2, 1, 8.6, ml[6a. Vận đơn và phí]),
  ngan(0.55, 3.45, 9.1),
  dkien(1.1, 9.45, text(size: 8pt)[nhập mã]),
  msg(1, 2, 10.6, ml[3b. Đọc mã bằng\ tài khoản người bán]),
  rmsg(2, 1, 11.6, ml[4b. Vận đơn, phí]),
  msg(1, 4, 12.9, ml[7\. Giữ tin cho người mua này]),
  rmsg(4, 1, 14.0, ml[8\. Tin đang giữ chỗ]),
  durable(1, 15.2, text(size: 8.5pt)[9\. Đơn đã gửi; hủy yêu cầu\ COD khác; hẹn 3 ngày]),
  msg(1, 5, 16.6, ml[10\. Báo người mua và người bị hủy]),
  rmsg(1, 0, 18.0, ml[11\. Đơn đã gửi]),
  nr((4.5, 8.2), text(size: 8pt)[Sự cố giữa chừng:\ quy trình chạy tiếp\ từ bước đã xong,\ không tạo vận đơn\ lần hai], shape: rect),
)

Hình 4.6 là trình tự của UC-DSC-01. Phân hệ khám phá tìm cách đọc đã lưu của câu này. Nếu chưa có, nó gửi câu cho mô hình ngôn ngữ một lần kèm lược đồ trả lời cố định; mô hình trả về các điều kiện ưu tiên, phân hệ khám phá kiểm từng điều kiện với danh mục và địa giới thật rồi lưu cách đọc trong 7 ngày. Khung alt thể hiện trần thời gian: mô hình lỗi hoặc quá 4 giây thì chỉ có câu gốc, không có chip. Sau đó phân hệ tin đăng chạy ba cách tìm trong cùng một câu truy vấn và hợp nhất thứ hạng [5].

#fig(
  [Sơ đồ trình tự UC-DSC-01: tìm kiếm bằng câu tự nhiên],
  spacing: (12mm, 5.6mm),
  np((0, 0), [:Người mua], shape: rect),
  ncore((1, 0), [Khám phá], shape: rect),
  np((2, 0), [Cách đọc đã lưu], shape: rect),
  np((3, 0), [Mô hình ngôn ngữ], shape: rect),
  np((4, 0), [Tin đăng], shape: rect),
  ..lifelines(5, y1: 18.6),
  msg(0, 1, 1.2, ml[1\. Câu nhu cầu, bộ lọc]),
  msg(1, 2, 2.5, ml[2\. Tìm cách đọc của câu]),
  rmsg(2, 1, 3.7, ml[3\. Chưa có]),
  ..khung("alt", 0.75, 3.45, 4.6, 12.6),
  dkien(1.35, 4.6, text(size: 8pt)[trong 4 s]),
  msg(1, 3, 6.0, ml[4\. Câu, lược đồ điều kiện]),
  rmsg(3, 1, 7.4, ml[5\. Điều kiện ưu tiên, câu viết lại]),
  step(1, 8.6, text(size: 8.5pt)[6\. Kiểm với danh mục,\ địa giới thật]),
  msg(1, 2, 10.0, ml[7\. Lưu 7 ngày]),
  ngan(0.75, 3.45, 10.8),
  dkien(1.35, 11.1, text(size: 8pt)[quá 4 s hoặc lỗi]),
  step(1, 12.0, text(size: 8.5pt)[6'. Chỉ câu gốc]),
  msg(1, 4, 13.6, ml[8\. Tìm từ khóa, theo nghĩa,\ theo ảnh; hợp nhất]),
  rmsg(4, 1, 15.2, ml[9\. Tin đã xếp hạng]),
  rmsg(1, 0, 17.4, ml[10\. Tin, chip, câu diễn giải]),
)

== Thiết kế các chức năng AI

Hệ thống dùng AI ở năm chỗ, liệt kê trong Bảng 4.5. Mỗi chỗ có một quy tắc chặn rủi ro riêng, và ở chỗ nào AI lỗi thì người dùng vẫn đi tiếp được. Mọi lời gọi mô hình ngôn ngữ đi qua một cổng chung; mỗi chức năng có khóa riêng và hạn mức chi phí theo tháng, nên một chức năng dùng quá mức không làm hỏng các chức năng khác.

#figure(
  kind: table,
  caption: [Các chức năng AI của hệ thống],
  table(
    columns: (1fr, 1.5fr, 1.5fr, 1.8fr),
    align: (left + horizon, left + horizon, left + horizon, left + horizon),
    table.header([Chức năng], [Đầu vào], [Đầu ra], [Giới hạn và khi lỗi]),
    [Đọc tin đăng], [Video (khung hình, tiếng nói), ảnh, hoặc link Chợ Tốt], [Bản nháp tin và khoảng giá tham khảo], [Người bán sửa mọi ô; mỗi ngày tối đa 30 video, 60 ảnh, 30 link; lỗi thì người bán tự điền],
    [Đọc câu tìm], [Câu của người mua], [Điều kiện ưu tiên, câu diễn giải], [Giá trị phải khớp dữ liệu thật; quá 4 giây thì tìm bằng câu gốc],
    [Tìm bằng ảnh], [Ảnh người mua chụp], [Tin có ảnh gần nhất], [Chỉ người đã đăng nhập; mô hình lỗi thì báo tạm không tìm được],
    [Cảnh báo lừa đảo], [20 tin nhắn gần nhất đã che thông tin], [Danh sách mã dấu hiệu], [Chỉ cảnh báo, không chặn; người dùng tắt được],
    [Trợ lý AI], [Phiếu, báo cáo hoặc tài khoản], [Bằng chứng, đề xuất, câu trả lời soạn sẵn], [Chỉ đọc; nhân viên bấm thao tác; 60 giây mỗi lượt; 100 USD mỗi tháng],
  ),
)

Trợ lý AI của nhân viên [14] chạy thành dịch vụ riêng trong mạng nội bộ. Trang điều hành chỉ gọi dịch vụ nền; dịch vụ nền kiểm phiên và quyền của nhân viên rồi mới chuyển tiếp. Trợ lý AI lấy dữ liệu qua các công cụ chỉ đọc mà dịch vụ nền cung cấp: đọc phiếu, đơn, vận đơn, tin nhắn, tin đăng và lịch sử tài khoản. Mỗi lần trợ lý AI đọc dữ liệu cá nhân được ghi lại kèm nhân viên đã hỏi (NFR-PRIV-02). Mỗi phiếu, báo cáo hoặc tài khoản có một cuộc trò chuyện với trợ lý AI dùng chung cho mọi nhân viên, nên ca sau thấy ca trước đã hỏi gì. Câu trả lời gồm các khối có kiểu: nguồn đã đọc, bằng chứng, đề xuất để nhân viên đánh dấu từng mục, câu trả lời soạn sẵn cho người dùng, bảng và đồ thị liên kết tài khoản. Thao tác tạm khóa, ẩn tin hay gửi trả lời là lời gọi của trang điều hành tới dịch vụ nền bằng phiên của nhân viên, có nhật ký và có nút hoàn tác (BR-MOD-03).

== Chức năng cung cấp cho ứng dụng và bảo vệ người dùng

Mọi chức năng mà ứng dụng, website và trang điều hành gọi tới được mô tả trước trong một bản đặc tả chung [19], dùng làm căn cứ cho cả lập trình lẫn kiểm thử. Khi một thao tác bị từ chối, bên gọi luôn nhận được lý do cụ thể để báo cho người dùng, ví dụ giá đã đổi, cần đăng nhập lại hoặc đã đủ 3 đơn COD đang mở. Với các thao tác quan trọng, người dùng bấm hai lần hoặc mạng chập chờn khiến ứng dụng gửi lại thì kết quả vẫn chỉ là một (AD-02). Bảng 4.6 tóm tắt các nhóm chức năng tiêu biểu.

#figure(
  kind: table,
  caption: [Các nhóm chức năng tiêu biểu cung cấp cho ứng dụng],
  table(
    columns: (0.95fr, 2.6fr, 1.1fr, 0.95fr),
    align: (left + horizon, left + horizon, left + horizon, center + horizon),
    table.header([Nhóm], [Chức năng], [Người gọi], [Chống gửi lặp]),
    [Đăng nhập], [Gửi mã email; đăng nhập bằng số điện thoại, Google hoặc mã email], [Khách], [Có],
    [Tin đăng], [Xin đường tải ảnh; AI đọc tin; gợi ý giá; lưu nháp; đăng tin], [Người bán], [Có],
    [Tìm kiếm], [Tìm bằng câu, bằng ảnh, tin tương tự; theo dõi tìm kiếm], [Khách, người mua], [Không],
    [Trò chuyện], [Mở cuộc trò chuyện theo tin; gửi tin nhắn; tắt cảnh báo lừa đảo], [Người dùng], [Có],
    [Giao dịch], [Trả giá, phản giá, chấp nhận], [Hai bên], [Không],
    [Giao dịch], [Gửi yêu cầu COD; tạo đơn gửi hàng; bấm đã nhận hàng; hủy đơn], [Người mua, người bán], [Có],
    [Vận chuyển], [Liên kết hãng; nhận trạng thái vận đơn từ hãng], [Người bán, hãng], [Không],
    [Uy tín], [Đánh giá, trả lời đánh giá; báo cáo vi phạm], [Người dùng], [Không],
    [Hỗ trợ], [Mở phiếu hỗ trợ], [Người dùng], [Có],
    [Cập nhật], [Kênh cập nhật thời gian thực; đọc phần đã lỡ], [Người dùng], [Không],
  ),
)

Về đăng nhập (NFR-SEC-01), người dùng có ba cách: số điện thoại được xác minh qua dịch vụ xác thực, tài khoản Google, hoặc mã sáu chữ số gửi qua email. Lần đăng nhập đầu tiên tạo tài khoản, nên đăng ký và đăng nhập là một thao tác. Người dùng xem được danh sách thiết bị đang đăng nhập, đăng xuất từng máy hoặc mọi máy khác; thao tác nhạy cảm như đăng xuất máy khác hay xóa tài khoản đòi người dùng vừa đăng nhập trong 15 phút gần nhất. Nếu một mã làm mới phiên bị dùng lại, hệ thống coi phiên đã bị đánh cắp và thu hồi nó. Nhân viên dùng tài khoản tách hẳn khỏi tài khoản người dùng: đăng nhập bằng email và mật khẩu, sai 5 lần thì email bị khóa 15 phút, phiên dài 8 giờ, và mọi thao tác của nhân viên lên dữ liệu người dùng đều được ghi lại để quản trị viên tra cứu.

Về quyền riêng tư (NFR-PRIV-01), ảnh tải lên được xóa thông tin vị trí chụp trước khi hiển thị; vị trí tin đăng chỉ ghi tới phường/xã, hoặc một điểm đã làm mờ khi người bán cho dùng vị trí, nên người lạ không suy ra được nhà của người bán. Thông tin kết nối tới tài khoản hãng của người bán được mã hóa và không bao giờ trả ra ngoài, kể cả cho nhân viên; hệ thống không giữ mật khẩu tài khoản hãng. Theo BR-ACC-02, phản hồi khi gửi mã giống hệt nhau dù email đã có tài khoản hay chưa, và dữ liệu người dùng không được xem thì được báo là không tồn tại, nên không ai dò được một địa chỉ đã đăng ký hay một đơn COD có thật hay không. Khi người dùng xóa tài khoản, tài khoản bị xóa ngay; tên trên đơn, đánh giá và tin nhắn cũ hiện là "đã xóa".
