#import "../../common/tokens.typ": *

// Nhãn thông điệp của sơ đồ trình tự: nền trắng để đường sinh đi sau nhãn không cắt chữ.
#let ml(b) = lbl(text(size: 8.5pt, b))

= THIẾT KẾ HỆ THỐNG

Chương này đi từ những yêu cầu chi phối thiết kế tới kiến trúc tổng thể, cách các phân hệ phối hợp với nhau, cơ chế uy tín, dữ liệu, hai quy trình chính, AI agent tìm kiếm, giao diện lập trình và bảo mật. Trọng tâm là hệ thống bảo đảm gì cho người mua và người bán; cách hiện thực cụ thể được trình bày ở Chương 5.

== Yếu tố dẫn dắt thiết kế

Phần lớn yêu cầu chức năng ở Chương 3 chỉ thêm một chức năng vào một phân hệ đã có. Sáu yếu tố trong Bảng 4.1 thì khác: bỏ qua chúng sẽ phải thay đổi cấu trúc hệ thống. Mỗi yếu tố gắn với yêu cầu sinh ra nó và cách thiết kế đáp ứng; các mục sau lần lượt triển khai từng cách.

#figure(
  kind: table,
  caption: [Các yếu tố dẫn dắt thiết kế và cách hệ thống đáp ứng],
  table(
    columns: (0.5fr, 1.7fr, 0.6fr, 2.3fr),
    align: (center + horizon, left + horizon, left + horizon, left + horizon),
    table.header([Mã], [Yếu tố], [Nguồn], [Cách thiết kế đáp ứng]),
    [AD-01], [Quy trình nhiều bước có liên quan tới hãng vận chuyển không được dừng dở dang], [NFR-01],
    [Mỗi quy trình ghi nhận từng bước đã xong; máy chủ gặp sự cố thì quy trình chạy tiếp từ bước đã ghi, không làm lại bước cũ [3]],
    [AD-02], [Người dùng bấm lặp, mạng chập chờn hoặc hãng báo trùng không được tạo hai đơn, hai vận đơn], [NFR-02],
    [Mỗi thao tác quan trọng mang một mã yêu cầu do ứng dụng sinh; gửi lại cùng mã thì nhận lại kết quả của lần đầu],
    [AD-03], [Hai người cùng thao tác trên một thương lượng; hạn mức đơn COD và số tin đang bán không được vượt], [NFR-03],
    [Chỉ lượt ghi đến trước được nhận, lượt sau được báo dữ liệu đã đổi để xem lại; hạn mức được đếm lần lượt theo từng người],
    [AD-04], [Tin báo giữa các phân hệ, như đơn đã giao hay tin đã bán, không được mất], [NFR-04],
    [Tin báo được lưu cùng lúc với thay đổi sinh ra nó và được gửi lại cho tới khi nơi nhận xử lý xong],
    [AD-05], [Tách một phân hệ ra máy chủ riêng khi tải tăng mà không viết lại nghiệp vụ], [NFR-10],
    [Phân hệ chỉ gọi nhau qua các chức năng đã công bố và chỉ dùng dữ liệu của chính mình [10]],
    [AD-06], [Tìm kiếm bằng AI phải trả kết quả trong thời gian chờ chấp nhận được và không kém tìm theo bộ lọc], [NFR-05],
    [Agent tối đa 4 vòng gọi công cụ và 8 giây; quá hạn thì dùng tìm kiếm lai với câu gốc của người mua],
  ),
)

== Kiến trúc tổng thể

Hình 4.1 trình bày kiến trúc theo năm tầng. Tầng khách gồm ứng dụng di động cho người mua, người bán và bảng điều khiển cho nhân viên. Tầng giao tiếp là nơi duy nhất nhận yêu cầu từ bên ngoài: giao diện lập trình được đặc tả trước [16], kênh cập nhật thời gian thực cho màn hình đang mở, và cổng nhận trạng thái vận đơn do hãng vận chuyển báo về. Mọi yêu cầu được kiểm theo đặc tả và xác thực người gọi trước khi tới phân hệ nghiệp vụ. Tầng nền tảng cung cấp những thứ mọi phân hệ dùng chung: điều phối quy trình nhiều bước, kênh tin báo giữa các phân hệ, cơ sở dữ liệu có tìm kiếm theo nghĩa, kho ảnh và giám sát vận hành.

#fig(
  [Kiến trúc tổng thể của ShopNexus],
  spacing: (0mm, 5mm),
  band((0, 0), "KHÁCH", (
    [Ứng dụng di động], [Bảng điều khiển nhân viên],
  ), rong: 150mm, name: <a-client>),
  band((0, 1), "GIAO TIẾP", (
    [Giao diện lập trình theo đặc tả], [Kênh cập nhật thời gian thực], [Cổng nhận trạng thái vận đơn],
  ), rong: 150mm,
    ghi: [Kiểm yêu cầu theo đặc tả, xác thực người gọi, giới hạn kích thước yêu cầu.],
    name: <a-api>),
  band((0, 2), "PHÂN HỆ NGHIỆP VỤ", (
    [Đăng nhập], [Tài khoản], [Nhân viên], [Ảnh], [Tin đăng], [Tìm kiếm],
    [Giao dịch], [Vận chuyển], [Nhắn tin], [Uy tín], [Xác minh], [Thông báo],
  ), cot: 6, rong: 150mm, nen: headfill,
    ghi: [Phân hệ gọi nhau qua chức năng đã công bố; mỗi phân hệ chỉ dùng dữ liệu của mình.],
    name: <a-svc>),
  band((0, 3), "NỀN TẢNG", (
    [Điều phối quy trình], [Kênh tin báo], [Cơ sở dữ liệu], [Kho ảnh], [Giám sát vận hành],
  ), rong: 150mm, name: <a-plat>),
  band((0, 4), "HỆ THỐNG BÊN NGOÀI", (
    [Hãng vận chuyển], [Mô hình ngôn ngữ lớn], [Mô hình nhúng], [SMS, email], [Đẩy thông báo],
  ), rong: 150mm,
    ghi: [Mọi lời gọi ra ngoài là một bước có ghi nhận của quy trình, nên không bị lặp khi thử lại.],
    name: <a-ext>),
  edge(<a-client>, <a-api>, "-|>", rel[yêu cầu của người dùng]),
  edge(<a-api>, <a-svc>, "-|>", rel[gọi chức năng nghiệp vụ]),
  edge(<a-svc>, <a-plat>, "-|>", rel[lưu dữ liệu, chạy quy trình, gửi tin báo]),
  edge(<a-plat>, <a-ext>, "-|>", rel[gọi đối tác trong một bước]),
)

Bảng 4.2 liệt kê chức năng và dữ liệu của từng phân hệ. Gói người bán và lượt đẩy tin thuộc phân hệ tin đăng vì chỉ thay đổi cách tin được hiển thị.

#figure(
  kind: table,
  caption: [Mười hai phân hệ của hệ thống],
  table(
    columns: (0.8fr, 2.3fr, 1.7fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Phân hệ], [Chức năng], [Dữ liệu quản lý]),
    [Đăng nhập], [Mã OTP, phiên đăng nhập trên các thiết bị], [Định danh, phiên, mã đã gửi],
    [Tài khoản], [Hồ sơ, tạm khóa, chặn người dùng khác], [Tài khoản, danh sách chặn],
    [Nhân viên], [Tài khoản nhân viên, phân quyền, kiểm toán], [Nhân viên, phiên, nhật ký],
    [Ảnh], [Nhận ảnh tải lên, xử lý ảnh], [Ảnh đã tải],
    [Tin đăng], [Tin đăng, danh mục, địa giới, gói người bán], [Tin, danh mục, xã, gói],
    [Tìm kiếm], [Tìm kiếm lai, AI agent, lưu tin, cảnh báo giá], [Chỉ mục tin, phiên tìm kiếm],
    [Giao dịch], [Thương lượng giá, đơn COD], [Thương lượng, đơn],
    [Vận chuyển], [Liên kết tài khoản hãng, phí, vận đơn], [Liên kết hãng, vận đơn],
    [Nhắn tin], [Hội thoại theo tin đăng, tin nhắn], [Hội thoại, tin nhắn],
    [Uy tín], [Đánh giá, ghi nhận sự cố, điểm, quyền, báo cáo vi phạm], [Đánh giá, ghi nhận, quyền],
    [Xác minh], [Hồ sơ xác minh danh tính], [Hồ sơ eKYC],
    [Thông báo], [Thông báo trong ứng dụng và đẩy về điện thoại], [Thông báo, thiết bị],
  ),
)

Trong giai đoạn phát triển, 12 phân hệ chạy chung một máy chủ; khi triển khai, mỗi nhóm phân hệ chạy riêng. Chạy chung không làm mờ ranh giới: một phân hệ chỉ thấy các chức năng mà phân hệ khác công bố, không đọc thẳng dữ liệu của nhau, và việc kiểm tra tự động trước mỗi lần tích hợp mã từ chối mọi chỗ vượt ranh giới. Nhờ vậy, khi cần tách một phân hệ ra máy chủ riêng, chỉ phải đổi cách gọi từ gọi trong máy sang gọi qua mạng, nghiệp vụ giữ nguyên (AD-05).

== Phối hợp giữa các phân hệ

Các phân hệ phối hợp theo ba cách. Khi cần câu trả lời ngay, một phân hệ hỏi trực tiếp phân hệ kia, ví dụ phân hệ giao dịch hỏi phân hệ tin đăng giá niêm yết và tình trạng tin trước khi nhận một giá trả. Khi công việc gồm nhiều bước có tác động ra bên ngoài, nó chạy thành một quy trình có ghi nhận tiến độ. Khi một thay đổi cần được nhiều nơi biết mà bên gây ra không cần chờ, nó được gửi đi dưới dạng tin báo.

=== Quy trình nhiều bước

Một thao tác ghi vào nhiều nhóm dữ liệu hoặc gọi tới đối tác bên ngoài chạy thành một quy trình có ghi nhận tiến độ (AD-01). Bảng 4.3 liệt kê 14 quy trình như vậy. Mỗi bước sau khi xong được ghi lại cùng kết quả; nếu máy chủ sập, quy trình chạy tiếp từ bước kế tiếp và dùng lại kết quả đã ghi, nên người bán không nhận hai vận đơn, người dùng không nhận hai tin nhắn OTP. Khi một bước bị từ chối vì lý do nghiệp vụ, chẳng hạn người mua đã vượt hạn mức đơn COD, quy trình dừng và báo lý do thay vì thử lại một việc không thể thành công. Mã OTP và thông tin đăng nhập không bao giờ được ghi vào nhật ký tiến độ.

#figure(
  kind: table,
  caption: [Các quy trình nhiều bước có ghi nhận tiến độ],
  table(
    columns: (1.35fr, 0.75fr, 2.35fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Quy trình], [Phân hệ], [Việc thực hiện]),
    [Gửi mã OTP], [Đăng nhập], [Kiểm hạn mức gửi, gửi mã qua SMS hoặc email],
    [Đăng nhập lần đầu], [Đăng nhập], [Tạo tài khoản rồi thông tin đăng nhập; trùng thì hoàn tác phần đã tạo [6]],
    [Đăng tin, sửa tin], [Tin đăng], [Kiểm hạn mức số tin, gắn ảnh vào tin],
    [Mở bán tin], [Tin đăng], [Chuyển tin đang xử lý sang đang bán hoặc bị từ chối],
    [Xử lý ảnh], [Ảnh], [Kiểm định dạng, thu nhỏ, xóa thông tin kèm ảnh],
    [Dọn ảnh thừa], [Ảnh], [Hẹn 24 giờ, xóa ảnh chưa được gắn vào đâu],
    [Gửi, phát tin nhắn], [Nhắn tin], [Gửi tin nhắn, phát tới người nhận khi ảnh đính kèm xử lý xong],
    [Tạo đơn gửi hàng], [Giao dịch], [Tạo vận đơn, giữ chỗ tin, hủy yêu cầu COD khác],
    [Kết thúc đơn], [Giao dịch], [Giao xong thì tin chuyển đã bán; hàng hoàn về thì mở bán lại],
    [Nhận trạng thái vận đơn], [Vận chuyển], [Ghi trạng thái hãng báo về, mỗi trạng thái đúng một lần],
    [Tìm kiếm bằng AI agent], [Tìm kiếm], [Vòng lặp lập kế hoạch, gọi công cụ của agent],
    [Hạn trả lời sự cố], [Uy tín], [Hẹn 3 ngày; người bán chưa trả lời thì ghi nhận chuyển bị từ chối],
  ),
)

=== Tin báo giữa các phân hệ

Khi một đơn hàng hay một tin đăng đổi trạng thái, hệ thống ghi lại sự thay đổi đó cùng lúc với tin báo cho các phân hệ liên quan, nên không có trường hợp đơn đã đổi mà phân hệ uy tín hay thông báo không biết (AD-04). Nếu một phân hệ tạm thời không nhận được, tin báo được giữ lại và gửi lại sau với khoảng chờ tăng dần, tối đa một giờ; một nơi nhận lỗi không chặn các nơi khác. Hình 4.2 lấy ví dụ lúc hãng báo một đơn đã giao thành công.

#fig(
  [Luồng thông tin giữa các phân hệ khi một đơn được giao],
  spacing: (10mm, 14mm),
  np((0, 0), [Hãng vận chuyển\ #text(size: 8.5pt)[báo giao thành công]], shape: rect, name: <f-hang>),
  np((1, 0), [Vận chuyển\ #text(size: 8.5pt)[ghi trạng thái vận đơn]], shape: rect, name: <f-vc>),
  ncore((2, 0), [Giao dịch\ #text(size: 8.5pt, weight: 400)[đơn chuyển đã giao]], shape: rect, name: <f-gd>),
  np((0, 1), [Tìm kiếm\ #text(size: 8.5pt)[gỡ tin khỏi kết quả]], shape: rect, name: <f-tk>),
  np((1, 1), [Tin đăng\ #text(size: 8.5pt)[tin chuyển đã bán]], shape: rect, name: <f-tin>),
  np((2, 1), [Uy tín\ #text(size: 8.5pt)[+10 điểm, tính lại quyền]], shape: rect, name: <f-ut>),
  np((3, 1), [Thông báo\ #text(size: 8.5pt)[báo người mua, người bán]], shape: rect, name: <f-tb>),
  edge(<f-hang>, <f-vc>, "-|>"),
  edge(<f-vc>, <f-gd>, "-|>"),
  edge(<f-gd>, <f-tin>, "-|>", label-side: right, rel[bán tin]),
  edge(<f-gd>, <f-ut>, "-|>", stroke: (dash: "dashed")),
  edge(<f-gd>, <f-tb>, "-|>", stroke: (dash: "dashed")),
  edge(<f-tin>, <f-tk>, "-|>", stroke: (dash: "dashed")),
  node((3, 0), align(left, text(size: 8pt)[
    #box(line(length: 9mm, stroke: 1.1pt + muted), baseline: -0.3em) bước trong quy trình\
    #box(line(length: 9mm, stroke: (paint: muted, thickness: 1.1pt, dash: "dashed")), baseline: -0.3em) tin báo
  ]), stroke: none, fill: none),
)

Tin báo chỉ nói điều gì đã xảy ra với đối tượng nào; nơi nhận tự hỏi lại trạng thái hiện tại của đối tượng đó. Vì vậy tin đến chậm, đến sai thứ tự hay đến hai lần đều cho cùng kết quả. Theo cách này, phân hệ tìm kiếm cập nhật chỉ mục mỗi khi tin đổi; phân hệ giao dịch đóng giá đang mở và hủy yêu cầu COD khi tin bị sửa, ẩn, bán hay xóa; phân hệ uy tín tính lại điểm khi đơn giao xong hoặc hoàn về, khi có đánh giá, ghi nhận sự cố hay xác minh danh tính; phân hệ thông báo báo cho người dùng mọi thay đổi của thương lượng, đơn hàng và sự cố.

Màn hình đang mở trên ứng dụng được cập nhật theo cùng nguyên tắc: hệ thống chỉ gửi một gợi ý ngắn rằng tin nhắn, thương lượng, đơn hàng hay thông báo nào vừa đổi, ứng dụng tự lấy dữ liệu mới. Một gợi ý bị mất chỉ làm màn hình cập nhật chậm hơn chứ không hiển thị sai.

== Thiết kế cơ chế uy tín và quyền

Sàn không phán xử từng vụ việc, nên mọi hệ quả với người dùng đều đi qua điểm uy tín và quyền. Hình 4.3 cho thấy đường đi từ sự kiện giao dịch tới quyền mà người dùng thấy trên màn hình uy tín. Điểm nằm trong khoảng 0–1000, cộng hoặc trừ theo từng sự kiện quan sát được; sự kiện cũ hơn 365 ngày chỉ tính một nửa. Không có sự kiện thắng hay thua tranh chấp, vì sàn không phân xử.

#fig(
  [Từ sự kiện giao dịch tới điểm uy tín, bậc và quyền],
  spacing: (15mm, 8mm),
  np((0, 0), align(left, text(size: 9pt)[
    *Sự kiện uy tín*\
    giao dịch thành công: +10\
    được đánh giá 5 sao: +5\
    được đánh giá 4 sao: +2\
    tự hoàn khi có sự cố: +15\
    trả lời nhanh cả tháng: +20\
    xác minh danh tính: +100\
    bị đánh giá 1–2 sao: −15
  ]), shape: rect, name: <r-ev>),
  ncore((1, 0), [Điểm uy tín\ 0–1000], shape: rect, name: <r-sc>),
  np((2, 0), align(left, text(size: 9pt)[
    *Bậc: đơn COD mở / tin đang bán*\
    Mới, từ 0 điểm: 2 / 5\
    Tin cậy, từ 200 điểm: 5 / 20\
    Uy tín, từ 500 điểm: 10 / 20,\ #h(1em) ưu tiên hiển thị\
    Xuất sắc, từ 800 điểm: 20 / 20,\ #h(1em) huy hiệu
  ]), shape: rect, name: <r-bac>),
  ncore((3, 0), [Quyền\ hiện có], shape: rect, name: <r-q>),
  nr((2.5, 1), align(left, text(size: 9pt)[
    *Chế tài tự động (BR-15)*, khi có ≥ 5 đơn COD/90 ngày\
    từ chối nhận ≥ 20%: còn 1 đơn COD mở\
    từ chối nhận ≥ 35%: mất quyền COD 30 ngày\
    30 ngày không từ chối: hồi lại một nấc
  ]), shape: rect, name: <r-ct>),
  edge(<r-ev>, <r-sc>, "-|>", rel[cộng, trừ]),
  edge(<r-sc>, <r-bac>, "-|>", rel[xếp bậc]),
  edge(<r-bac>, <r-q>, "-|>", rel[hạn mức]),
  edge(<r-ct>, <r-q>, "-|>", stroke: (dash: "dashed"), label-side: right, rel[giới hạn thêm]),
)

Từ điểm suy ra bậc, từ bậc suy ra hạn mức số đơn COD đang mở (BR-09) và số tin đang bán (BR-04). Chế tài đặt chồng lên hạn mức của bậc: người mua thường xuyên từ chối nhận hàng bị giảm số đơn COD được mở rồi mất quyền COD, và được hồi dần khi không còn từ chối. Đơn tự gửi không tính vào tỉ lệ vì sàn không quan sát được việc giao nhận. Phía người bán, tỉ lệ bị từ chối nhận và số ghi nhận sự cố chưa trả lời được theo dõi theo cùng cách, với nấc đầu tiên là hạ thứ tự hiển thị. Quyền COD và bậc uy tín không mua được bằng gói trả phí (BR-16), nên doanh thu của sàn không làm lệch thước đo niềm tin.

== Thiết kế dữ liệu

Hình 4.4 là sơ đồ thực thể quan hệ mức khái niệm, các thực thể được nhóm theo phân hệ quản lý bằng khung nét đứt. Quan hệ vượt khung chỉ là mã tham chiếu: phân hệ này ghi mã đối tượng của phân hệ kia chứ không đọc thẳng dữ liệu của nó.

#fig(
  [Sơ đồ thực thể quan hệ mức khái niệm, nhóm theo phân hệ],
  spacing: (13mm, 11mm),
  edge-stroke: 1pt + blue-s,
  label-wrapper: wlabel,
  label-size: 8pt,
  nent((0, 0), <e-rights>, [QUYỀN]),
  nent((0, 1), <e-acc>, [TÀI KHOẢN]),
  nent((-1, 1), <e-kyc>, [HỒ SƠ eKYC]),
  nent((0, 2.2), <e-conv>, [HỘI THOẠI]),
  nent((0, 3.2), <e-msg>, [TIN NHẮN]),
  nent((1, 0), <e-cat>, [DANH MỤC]),
  nent((1, 1), <e-lst>, [TIN ĐĂNG]),
  nent((1, 2), <e-com>, [XÃ/PHƯỜNG]),
  nent((2, 0), <e-mv>, [NƯỚC ĐI]),
  nent((2, 1), <e-deal>, [THƯƠNG LƯỢNG]),
  nent((2, 2), <e-ord>, [ĐƠN COD]),
  nent((2, 3.2), <e-wb>, [VẬN ĐƠN]),
  nent((3, 2), <e-rev>, [ĐÁNH GIÁ]),
  nent((3, 3.2), <e-inc>, [GHI NHẬN SỰ CỐ]),

  ngroup((<e-rights>,)), gtitle((0, -0.55), [uy tín]),
  ngroup((<e-acc>,)), gtitle((-0.3, 1.47), [tài khoản]),
  ngroup((<e-kyc>,)), gtitle((-1, 1.47), [xác minh]),
  ngroup((<e-conv>, <e-msg>)), gtitle((0, 3.72), [nhắn tin]),
  ngroup((<e-cat>, <e-lst>, <e-com>)), gtitle((1, -0.55), [tin đăng]),
  ngroup((<e-mv>, <e-deal>, <e-ord>)), gtitle((2, -0.55), [giao dịch]),
  ngroup((<e-wb>,)), gtitle((2, 3.72), [vận chuyển]),
  ngroup((<e-rev>, <e-inc>)), gtitle((3, 1.48), [uy tín]),

  edge(<e-acc>, <e-rights>, "1-1", [có]),
  edge(<e-acc>, <e-kyc>, "1-n", [nộp]),
  edge(<e-acc>, <e-lst>, "1-n", [đăng bán]),
  edge(<e-acc>, <e-deal>, "1-n", bend: 32deg, label-pos: 0.8, [mua qua]),
  edge(<e-acc>, <e-conv>, "n-n", [tham gia]),
  edge(<e-conv>, <e-msg>, "1-n", [chứa]),
  edge(<e-cat>, <e-lst>, "1-n", [phân loại]),
  edge(<e-com>, <e-lst>, "1-n", [vị trí]),
  edge(<e-lst>, <e-deal>, "1-n", [được trả giá]),
  edge(<e-deal>, <e-mv>, "1-n", [ghi]),
  edge(<e-deal>, <e-ord>, "1-n", [sinh]),
  edge(<e-ord>, <e-wb>, "1-1?", [gửi qua]),
  edge(<e-ord>, <e-rev>, "1-1?", [được]),
  edge(<e-ord>, <e-inc>, "1-1?", [phát sinh]),
)

Mỗi tin đăng có nhiều thương lượng nhưng mỗi người mua chỉ có một thương lượng trên một tin; mỗi thương lượng có thể sinh nhiều đơn theo thời gian, vì khi đơn bị từ chối nhận hoặc bị hủy, thương lượng trở về đang thương lượng; mỗi đơn có tối đa một vận đơn, một đánh giá và một ghi nhận sự cố. Bảng 4.4 tóm tắt dữ liệu chính của từng phân hệ cùng những quy tắc mà cơ sở dữ liệu trực tiếp bảo đảm, để luật nghiệp vụ đúng ngay cả khi có lỗi lập trình ở phía trên.

#figure(
  kind: table,
  caption: [Dữ liệu chính theo phân hệ và các quy tắc được bảo đảm],
  table(
    columns: (0.75fr, 1.45fr, 2.6fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Phân hệ], [Dữ liệu], [Quy tắc được bảo đảm]),
    [Đăng nhập], [Định danh, phiên, mã OTP], [Mỗi số điện thoại hoặc email chỉ gắn với một tài khoản; mỗi mã làm mới phiên chỉ dùng được một lần],
    [Tin đăng], [Tin đăng, danh mục, xã/phường], [Ảnh, vết và thông số lưu cùng tin; vị trí chỉ lưu đến 3.321 xã/phường],
    [Tìm kiếm], [Chỉ mục tin, phiên tìm kiếm], [Mỗi tin có một vector ngữ nghĩa 1024 chiều và chỉ mục từ khóa; phiên giữ ràng buộc của người mua],
    [Giao dịch], [Thương lượng, nước đi, đơn COD], [Mỗi người mua một thương lượng trên một tin; mỗi thương lượng một đơn đang mở; mỗi tin một đơn đang gửi],
    [Vận chuyển], [Liên kết hãng, trạng thái vận đơn], [Khóa kết nối tới hãng được mã hóa; mỗi trạng thái hãng báo chỉ được ghi một lần],
    [Nhắn tin], [Hội thoại, tin nhắn], [Mỗi cặp người dùng chỉ có một hội thoại],
    [Uy tín], [Đánh giá, ghi nhận sự cố, quyền], [Mỗi đơn tối đa một đánh giá và một ghi nhận; mỗi tài khoản một bản ghi quyền],
    [Nhân viên], [Nhân viên, nhật ký thao tác], [Email nhân viên không trùng; mọi thao tác ghi đều có dòng nhật ký],
  ),
)

Khi hai thao tác cùng sửa một thương lượng, ví dụ người bán phản giá đúng lúc người mua chấp nhận giá cũ, chỉ lượt đến trước được ghi; lượt sau được báo thương lượng vừa thay đổi, ứng dụng hiện giá mới để người dùng quyết định lại (AD-03). Hạn mức như số đơn COD đang mở hay số tin đang bán được kiểm lần lượt theo từng người: người mua bậc Mới gửi cùng lúc năm yêu cầu COD thì đúng hai yêu cầu được nhận.

== Thiết kế các luồng xử lý chính

Hình 4.5 là trình tự của UC-16. Khi người bán tạo đơn, phân hệ giao dịch kiểm đơn còn ở trạng thái đã yêu cầu. Với đơn qua hãng có liên kết, phân hệ vận chuyển tạo vận đơn trên tài khoản hãng của chính người bán, đặt chế độ người nhận trả phí ship, rồi nhận mã vận đơn và phí thật; với đơn tự gửi, hệ thống dùng tên hãng, mã vận đơn và phí do người bán nhập. Sau đó phân hệ tin đăng giữ tin cho người mua này, đơn chuyển đã tạo vận đơn và các yêu cầu COD khác trên cùng tin tự hủy với lý do đã gửi cho người khác (BR-07); người mua và những người bị hủy yêu cầu đều được báo. Nếu máy chủ gặp sự cố giữa chừng, quy trình tiếp tục từ bước đã xong nên hãng không nhận lệnh tạo vận đơn lần hai (NFR-01); người bán bấm lặp cũng chỉ nhận lại đơn đã tạo (NFR-02).

#fig(
  [Sơ đồ trình tự UC-16: người bán tạo đơn gửi hàng],
  spacing: (10mm, 4.9mm),
  np((0, 0), [:Người bán], shape: rect),
  ncore((1, 0), [Giao dịch], shape: rect),
  np((2, 0), [Vận chuyển], shape: rect),
  np((3, 0), [Hãng vận chuyển], shape: rect),
  np((4, 0), [Tin đăng], shape: rect),
  np((5, 0), [Thông báo], shape: rect),
  ..lifelines(6, y1: 17.8),
  msg(0, 1, 1.5, ml[1\. Tạo đơn gửi hàng]),
  durable(1, 2.4, text(size: 8.5pt)[2\. Kiểm đơn\ đã yêu cầu]),
  ..khung("alt", 0.55, 3.45, 3.7, 10.5),
  dkien(1.25, 3.7, text(size: 8pt)[có liên kết hãng]),
  msg(1, 2, 5.0, ml[3a. Tạo vận đơn]),
  msg(2, 3, 6.2, ml[4a. Tạo vận đơn,\ người nhận trả phí]),
  rmsg(3, 2, 7.5, ml[5a. Mã vận đơn, phí thật]),
  rmsg(2, 1, 8.6, ml[6a. Vận đơn và phí]),
  ngan(0.55, 3.45, 9.1),
  dkien(1.1, 9.45, text(size: 8pt)[tự gửi]),
  step(2, 10.0, text(size: 8.5pt)[3b. Hãng, mã, phí\ người bán nhập]),
  msg(1, 4, 12.2, ml[7\. Giữ tin cho người mua này]),
  rmsg(4, 1, 13.6, ml[8\. Tin đang giữ chỗ]),
  durable(1, 14.8, text(size: 8.5pt)[9\. Đơn đã tạo vận đơn;\ hủy yêu cầu COD khác]),
  msg(1, 5, 16.0, ml[10\. Báo người mua và người bị hủy]),
  rmsg(1, 0, 17.2, ml[11\. Đơn đã tạo vận đơn]),
  nr((4.5, 8.2), text(size: 8pt)[Sự cố giữa chừng:\ quy trình chạy tiếp\ từ bước đã xong,\ không tạo vận đơn\ lần hai], shape: rect),
)

Hình 4.6 là trình tự của UC-09. Agent nạp các ràng buộc người mua đã chốt trong phiên rồi vào vòng lặp: hỏi mô hình ngôn ngữ lớn nên làm gì, thực hiện công cụ mô hình chọn (thường là tìm tin trên chỉ mục lai, hợp nhất ba danh sách xếp hạng [5]), rồi đưa kết quả lại cho mô hình. Vòng lặp dừng khi mô hình đưa ra câu trả lời cuối hoặc đủ 4 vòng. Khung alt thể hiện trần thời gian: quá 8 giây hoặc công cụ lỗi thì hệ thống chạy tìm kiếm lai với câu gốc, nên người mua luôn có kết quả trong giới hạn của NFR-05.

#fig(
  [Sơ đồ trình tự UC-09: tìm kiếm bằng AI agent],
  spacing: (12mm, 5.6mm),
  np((0, 0), [:Người mua], shape: rect),
  np((1, 0), [Tìm kiếm], shape: rect),
  ncore((2, 0), [AI agent], shape: rect),
  np((3, 0), [Mô hình ngôn ngữ], shape: rect),
  np((4, 0), [Chỉ mục tin], shape: rect),
  ..lifelines(5, y1: 22.1),
  msg(0, 1, 1.2, ml[1\. Câu nhu cầu]),
  msg(1, 2, 2.5, ml[2\. Giao câu cho agent]),
  durable(2, 3.5, text(size: 8.5pt)[3\. Nạp ràng buộc của phiên]),
  ..khung("alt", 1.45, 4.35, 5.0, 18.4),
  dkien(1.75, 5.0, text(size: 8pt)[trong 8 s]),
  ..khung("loop", 1.7, 4.15, 5.9, 11.8),
  dkien(2.4, 5.9, text(size: 8pt)[≤ 4 vòng gọi công cụ]),
  msg(2, 3, 7.3, ml[4\. Câu, ràng buộc]),
  rmsg(3, 2, 8.8, ml[5\. Công cụ cần gọi]),
  msg(2, 4, 10.3, ml[6\. Tìm tin theo bộ lọc]),
  rmsg(4, 2, 11.8, ml[7\. Tin đã xếp hạng]),
  msg(2, 3, 14.5, ml[8\. Kết quả quan sát]),
  rmsg(3, 2, 16.0, ml[9\. Tin, chip, diễn giải]),
  ngan(1.45, 4.35, 16.7),
  dkien(1.95, 17.05, text(size: 8pt)[quá 8 s hoặc lỗi]),
  msg(2, 4, 18.4, ml[8'. Tìm kiếm lai với câu gốc]),
  durable(2, 20.1, text(size: 8.5pt)[10\. Lưu ràng buộc vào phiên]),
  rmsg(2, 0, 21.6, ml[11\. Tin, chip, câu diễn giải]),
)

== Thiết kế AI agent tìm kiếm

Tìm kiếm lai so khớp cả câu theo nghĩa, nên với câu "kiếm gì đó tặng sinh nhật bạn, tầm 500 nghìn, gần đây thôi" nó không tách được mục tiêu khỏi ràng buộc, không hiểu phủ định và không nhớ giữa các lượt hỏi. Agent là một mô hình ngôn ngữ lớn có quyền gọi công cụ, không huấn luyện lại, làm việc theo vòng lặp lập kế hoạch, gọi công cụ, quan sát, suy luận [12]. Agent chỉ điền bộ lọc và mức ưu tiên cho tìm kiếm lai chứ không thay thế nó. Bảng 4.5 liệt kê sáu công cụ, tất cả chỉ đọc.

#figure(
  kind: table,
  caption: [Bộ công cụ của AI agent tìm kiếm],
  table(
    columns: (1.15fr, 1.35fr, 1.7fr, 0.8fr),
    align: (left + horizon, left + horizon, left + horizon, left + horizon),
    table.header([Công cụ], [Đầu vào], [Thông tin trả về], [Phân hệ]),
    [Tìm tin đăng], [Câu tìm, bộ lọc, mức ưu tiên từng tín hiệu], [Danh sách tin đã xếp hạng], [Tìm kiếm],
    [Tìm tin tương tự], [Một tin đăng], [Các tin gần nghĩa nhất], [Tìm kiếm],
    [Xem danh mục], [Không có], [Cây danh mục 9 nhóm gốc], [Tin đăng],
    [Xem sở thích], [Không có], [Sở thích suy từ tin đã lưu và đã xem], [Tìm kiếm],
    [Xem đơn gần đây], [Không có], [Các đơn gần đây của người dùng], [Giao dịch],
    [Xem vị trí], [Không có], [Xã/phường của người dùng và tọa độ tâm xã], [Tin đăng],
  ),
)

Agent nhớ hội thoại theo phiên: giá tối đa, danh mục, tình trạng, bán kính và những điều cần tránh được lưu lại, lượt hỏi sau kế thừa. Kết quả luôn gồm danh sách tin, các chip ràng buộc và một câu diễn giải. Mọi ràng buộc agent đặt ra đều hiện thành chip (BR-18); khi người mua xóa hoặc sửa chip, ứng dụng tìm lại theo bộ ràng buộc mới mà không hỏi lại mô hình ngôn ngữ.

Có bốn lớp bảo vệ người dùng. Bộ công cụ không có thao tác ghi, nên agent không thể đặt hàng, thương lượng hay thanh toán thay người dùng. Câu gốc của người mua luôn được giữ trong lần tìm, nên trường hợp xấu nhất cũng bằng tìm kiếm lai. Vòng lặp bị chặn ở 4 vòng và 8 giây (AD-06). Mỗi lần hỏi mô hình và gọi công cụ là một bước có ghi nhận, nên thử lại sau sự cố không hỏi mô hình hai lần cho cùng một bước.

== Chức năng cung cấp cho ứng dụng và bảo vệ người dùng

Mọi chức năng mà ứng dụng gọi tới được mô tả trước trong một bản đặc tả chung [16], dùng làm căn cứ cho cả lập trình lẫn kiểm thử. Khi một thao tác bị từ chối, ứng dụng luôn nhận được lý do cụ thể để báo cho người dùng, ví dụ giá đã đổi, cần đăng nhập lại hoặc đã vượt hạn mức đơn COD. Với các thao tác quan trọng, người dùng bấm hai lần hoặc mạng chập chờn khiến ứng dụng gửi lại thì kết quả vẫn chỉ là một (AD-02). Bảng 4.6 tóm tắt các nhóm chức năng tiêu biểu.

#figure(
  kind: table,
  caption: [Các nhóm chức năng tiêu biểu cung cấp cho ứng dụng],
  table(
    columns: (0.95fr, 2.6fr, 1.1fr, 0.95fr),
    align: (left + horizon, left + horizon, left + horizon, center + horizon),
    table.header([Nhóm], [Chức năng], [Người gọi], [Chống gửi lặp]),
    [Đăng nhập], [Gửi mã OTP; xác minh mã và cấp phiên], [Khách], [Có],
    [Tin đăng], [Xin đường tải ảnh; đăng tin], [Người bán], [Có],
    [Tìm kiếm], [Tìm bằng câu tự nhiên qua agent hoặc theo bộ lọc], [Khách, người mua], [Không],
    [Nhắn tin], [Mở hội thoại theo tin; gửi tin nhắn], [Người dùng], [Có],
    [Giao dịch], [Trả giá hoặc phản giá], [Hai bên], [Không],
    [Giao dịch], [Gửi yêu cầu COD; tạo đơn gửi hàng; báo đã nhận (đơn tự gửi)], [Người mua, người bán], [Có],
    [Vận chuyển], [Nhận trạng thái vận đơn từ hãng], [Hãng vận chuyển], [Không],
    [Uy tín], [Mở ghi nhận sự cố], [Người mua], [Không],
    [Cập nhật], [Kênh gợi ý cập nhật thời gian thực], [Người dùng], [Không],
  ),
)

Về đăng nhập (NFR-06), khách hàng dùng mã OTP 6 chữ số, hiệu lực 5 phút, nhập sai 5 lần thì mã bị hủy. Mỗi số điện thoại hay email chỉ nhận tối đa 1 mã mỗi 45 giây và 5 mã mỗi giờ, nên không ai dùng sàn để gửi tin nhắn rác tới người khác. Người dùng xem được danh sách thiết bị đang đăng nhập, đăng xuất từng máy hoặc tất cả; phiên trên một thiết bị hết hạn sau 30 ngày không dùng, và nếu có dấu hiệu phiên bị đánh cắp thì hệ thống tự đăng xuất thiết bị đó. Tài khoản nhân viên tách hẳn khỏi tài khoản khách hàng: nhân viên đăng nhập bằng mật khẩu kèm mã xác thực hai lớp, nhập sai 5 lần bị khóa 15 phút, và mọi thao tác của nhân viên lên tài khoản khách hàng đều được ghi lại để quản trị viên tra cứu.

Về quyền riêng tư (NFR-07), ảnh tải lên được xóa thông tin vị trí chụp trước khi hiển thị; vị trí tin đăng chỉ ghi tới xã, phường nên người lạ không suy ra được nhà của người bán. Thông tin kết nối tới tài khoản hãng của người bán được giữ kín, và hệ thống không bao giờ giữ mật khẩu tài khoản hãng. Theo BR-21, thông báo khi gửi mã OTP giống hệt nhau dù số điện thoại đã có tài khoản hay chưa, và dữ liệu người dùng không được xem thì được báo là không tồn tại, nên không ai dò được một số điện thoại đã đăng ký hay một đơn hàng có thật hay không.
