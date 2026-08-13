#import "../../common/tokens.typ": *

== Sơ đồ hoạt động: Thanh toán ký quỹ và sinh đơn hàng

Sơ đồ dưới đây tách thành 3 luồng dọc theo tác nhân: người mua, hệ thống và nhà cung cấp thanh
toán. Toàn bộ quy trình có 2 điểm rẽ nhánh, và cả 2 đều nhằm chặn một trạng thái nửa vời trước
khi nó kịp hình thành. Điểm rẽ thứ nhất nằm ở khâu báo giá vận chuyển: hệ thống hỏi giá từng
hãng đang bật cho tuyến đường, và nếu không hãng nào phục vụ được địa chỉ đó thì lượt mua
dừng ngay tại đây, trước khi người mua bị hỏi tới tiền. Điểm rẽ thứ hai nằm ở khâu chờ báo
đã trả tiền; nếu quá hạn mà chưa có báo về thì phiên hết hiệu lực và quyền dùng bản chốt giá
được trả lại cho tin đăng.

Ba chi tiết trong sơ đồ đáng được nói rõ vì chúng quyết định tính đúng đắn của dòng tiền. Thứ
nhất, hệ thống chiếm quyền dùng bản chốt giá hoặc đề xuất đã chấp nhận ngay trước khi mở
phiên thanh toán, chứ không phải sau khi thu được tiền; nhờ vậy 2 cú bấm mua liên tiếp trên
cùng một mặt hàng chỉ mở được một phiên. Thứ hai, tiền hàng và phí vận chuyển được tách thành
2 chặng riêng ngay từ lúc giữ ký quỹ, vì 2 khoản này có quy tắc hoàn khác nhau: tiền hàng hoàn
được, còn phí vận chuyển đã dùng thì không. Thứ ba, đơn hàng chỉ được sinh ra sau khi tiền đã
nằm trong ký quỹ, và việc sinh đơn đi kèm khởi động đồng hồ chờ người bán xác nhận; điều này
có nghĩa trong hệ thống không tồn tại đơn hàng nào chưa được trả tiền.

#let elabel(body) = box(fill: white, inset: (x: 2pt, y: 1pt), text(size: 8pt, body))
#let lane-v = (paint: luma(60%), thickness: 0.6pt, dash: "dashed")
#let lane-h = (paint: luma(75%), thickness: 0.5pt)

#fig(
  [Sơ đồ hoạt động quy trình thanh toán ký quỹ và sinh đơn hàng],
  spacing: (44mm, 11mm),

  // vùng phân chia actor
  edge((0.5, -0.5), (0.5, 13.1), stroke: lane-v),
  edge((1.5, -0.5), (1.5, 13.1), stroke: lane-v),
  edge((-0.7, 0.5), (2.4, 0.5), stroke: lane-h),

  ncore((0, 0), [NGƯỜI MUA]),
  ncore((1, 0), [HỆ THỐNG]),
  ncore((2, 0), [NHÀ CUNG CẤP\ THANH TOÁN]),
  nt((0, 1), [Bắt đầu]),
  edge((0, 1), (0, 2), "-|>"),
  np((0, 2), [Chọn mục hàng, chốt\ địa chỉ giao, xin báo giá]),
  edge((0, 2), (1, 3), "-|>"),
  np((1, 3), [Hỏi giá từng hãng vận\ chuyển đang bật cho tuyến]),
  edge((1, 3), (1, 4), "-|>"),
  nd((1, 4), [Còn hãng nào\ phục vụ được?]),
  edge((1, 4), (0, 4), "-|>", elabel[Không], label-side: left),
  nr((0, 4), [Báo không giao được\ tới địa chỉ này]),
  edge((1, 4), (0, 5), "-|>", elabel[Có]),
  np((0, 5), [Chọn hãng vận chuyển\ và phương thức trả tiền]),
  edge((0, 5), (1, 6), "-|>"),
  np((1, 6), [Chiếm quyền dùng bản chốt\ giá hoặc đề xuất đã chấp nhận,\ rồi mở phiên 15 phút]),
  edge((1, 6), (0, 7), "-|>"),
  np((0, 7), [Trả tiền trên trang\ của nhà cung cấp]),
  edge((0, 7), (2, 8), "-|>"),
  np((2, 8), [Thu tiền và gọi lại\ kết quả cho sàn]),
  edge((2, 8), (1, 9), "-|>"),
  nd((1, 9), [Nhận báo đã trả\ trong 15 phút?]),
  edge((1, 9), (0, 10), "-|>", elabel[Không], label-side: left),
  nr((0, 10), [Phiên hết hạn, quyền dùng\ bản chốt giá được trả lại]),
  edge((1, 9), (1, 10), "-|>", elabel[Có]),
  ng((1, 10), [Giữ tiền hàng vào ký quỹ,\ phí vận chuyển thành\ một chặng riêng]),
  edge((1, 10), (1, 11), "-|>"),
  ng((1, 11), [Sinh đơn hàng ở trạng thái\ chờ người bán xác nhận,\ khởi động đồng hồ 48 giờ]),
  edge((1, 11), (1, 12), "-|>"),
  nt((1, 12), [Kết thúc]),

  // 2 đường hồi quy chạy trong máng lề trái, vẫn thuộc làn người mua
  edge((0, 10), (-0.25, 10), (-0.25, 12), (1, 12), "-|>", corner-radius: 5pt),
  edge((0, 4), (-0.6, 4), (-0.6, 12.6), (1, 12.6), (1, 12), "-|>", corner-radius: 5pt),
)


== Sơ đồ hoạt động: Trả hàng, hoàn tiền và leo thang thành phiếu hỗ trợ

#fig(
  [Sơ đồ hoạt động quy trình trả hàng, hoàn tiền và nhánh leo thang phân xử],
  spacing: (37mm, 10mm),

  edge((0.5, -0.5), (0.5, 16.6), stroke: lane-v),
  edge((1.5, -0.5), (1.5, 16.6), stroke: lane-v),
  edge((2.5, -0.5), (2.5, 16.6), stroke: lane-v),
  edge((-0.4, 0.5), (3.4, 0.5), stroke: lane-h),

  ncore((0, 0), [NGƯỜI MUA]),
  ncore((1, 0), [HỆ THỐNG]),
  ncore((2, 0), [NGƯỜI BÁN]),
  ncore((3, 0), [BỘ PHẬN VẬN HÀNH]),

  nt((0, 1), [Bắt đầu]),
  edge((0, 1), (0, 2), "-|>"),
  np((0, 2), [Gửi yêu cầu hoàn tiền\ kèm lý do và bằng chứng]),
  edge((0, 2), (1, 3), "-|>"),
  np((1, 3), [Mở hồ sơ chờ người bán\ xem xét, loại đơn khỏi\ danh sách giải ngân, hẹn 48 giờ]),
  edge((1, 3), (2, 4), "-|>"),
  nd((2, 4), [Người bán làm gì\ trong 48 giờ?]),

  edge((2, 4), (1, 5), "-|>", elabel[Chấp nhận], label-side: left),
  np((1, 5), [Mở chặng trả hàng,\ không tính phí]),
  edge((1, 5), (0, 6), "-|>"),
  np((0, 6), [Gửi hàng trả lại]),
  edge((0, 6), (2, 7), "-|>"),
  np((2, 7), [Xác nhận đã nhận hàng,\ bắt đầu 48 giờ kiểm hàng]),
  edge((2, 7), (2, 8), "-|>"),
  nd((2, 8), [Kết luận kiểm hàng?]),

  // nhánh thuận: hoàn tiền rồi kết thúc tại chỗ
  edge((2, 8), (1, 9), "-|>", elabel[Đồng ý hoặc hết 48 giờ], label-side: left),
  ng((1, 9), [Hoàn tiền hàng cho người mua;\ phí vận chuyển đã dùng\ không được hoàn]),
  edge((1, 9), (1, 10), "-|>"),
  nt((1, 10), [Kết thúc]),

  // 2 nguồn leo thang bên người bán gộp chung trục dọc trong làn người bán
  edge((2, 4), (2.4, 4), (2.4, 11), (1, 11), "-|>", corner-radius: 5pt,
    elabel[Nhờ phân xử\ hoặc im lặng hết hạn], label-pos: 0.22, label-side: right),
  edge((2, 8), (2.4, 8), (2.4, 11), (1, 11), "-|>", corner-radius: 5pt,
    elabel[Phản đối hàng trả về], label-pos: 0.29, label-side: right),
  // nguồn leo thang bên người mua đi thẳng xuống trong làn của mình
  edge((0, 6), (0, 11), (1, 11), "-|>", corner-radius: 5pt,
    elabel[Người mua tự khai đã trả], label-pos: 0.3, label-side: left),
  np((1, 11), [Chuyển hồ sơ sang phân xử,\ mở phiếu hỗ trợ gắn với hồ sơ]),

  edge((1, 11), (1, 11.6), (3, 11.6), (3, 12), "-|>", corner-radius: 5pt),
  np((3, 12), [Đối soát bằng chứng hai phía\ qua luồng trao đổi của phiếu]),
  edge((3, 12), (3, 13), "-|>"),
  nd((3, 13), [Phán quyết?]),
  edge((3, 13), (1, 14), "-|>", elabel[Người mua thắng], label-side: left),
  ng((1, 14), [Hoàn tiền hàng\ cho người mua]),
  edge((3, 13), (3, 14), "-|>", elabel[Người bán thắng]),
  ng((3, 14), [Hồ sơ bị bác bỏ;\ tiền tiếp tục về người bán]),
  edge((1, 14), (1, 15), "-|>"),
  edge((3, 14), (1, 15), "-|>"),
  np((1, 15), [Đóng mọi phiếu hỗ trợ đang mở\ về hồ sơ, ghi phán quyết\ vào luồng trao đổi]),
  edge((1, 15), (1, 16), "-|>"),
  nt((1, 16), [Kết thúc]),
)


== Sơ đồ trạng thái vòng đời đơn hàng

Đơn hàng có 4 trạng thái, và cả 4 đều được suy ra từ các mốc thời gian kết quả chứ
không lưu thành một trường trạng thái riêng, nhờ vậy không tồn tại khả năng trường trạng
thái lệch với các mốc thời gian sinh ra nó. Sơ đồ dưới đây là hợp đồng mà tầng nghiệp vụ
phải tuân thủ: mọi phép chuyển không xuất hiện trên sơ đồ đều bị từ chối.

#fig(
  [Sơ đồ trạng thái vòng đời đơn hàng],
  spacing: (46mm, 30mm),

  // ===== TRỤC CHÍNH (x = 0) =====
  nt((0, 0), [Khởi tạo]),
  np((0, 1), [CHỜ NGƯỜI BÁN\ XÁC NHẬN]),
  np((0, 2), [ĐANG MỞ]),
  ng((0, 3), [HOÀN THÀNH]),

  // ===== NHÁNH PHẢI: hạ xuống giữa hàng 1 và 2 để nhận hai cạnh ở hai góc khác nhau =====
  ng((1.5, 1.5), [ĐÃ HUỶ]),

  // ===== HỘI TỤ =====
  nt((0.65, 4), [Kết thúc]),

  // ===== TRỤC CHÍNH =====
  edge((0, 0), (0, 1), "-|>",
    text(size: 7.5pt)[phiên thanh toán hoàn tất:\ tiền vào ký quỹ]),
  edge((0, 1), (0, 2), "-|>",
    text(size: 7.5pt)[người bán xác nhận:\ đặt vận đơn với hãng]),
  edge((0, 2), (0, 3), "-|>",
    text(size: 7.5pt)[người mua xác nhận nhận hàng,\ qua 72 giờ không có hồ sơ\ hoàn tiền đang mở: giải ngân]),

  // ===== VÀO ĐÃ HUỶ: hai cạnh thẳng tạo hình chữ V, cắm vào hai góc đối nhau =====
  edge((0, 1), (1.5, 1.5), "-|>", label-side: left,
    text(size: 7.5pt)[người bán từ chối:\ hoàn tiền hàng và cước]),
  edge((0, 2), (1.5, 1.5), "-|>", stroke: (dash: "dashed"), label-side: right,
    text(size: 7.5pt)[\ hoàn tiền được chấp thuận\ hoặc phân xử cho người mua]),

  // ===== HAI KẾT THÚC HỘI TỤ =====
  edge((0, 3), (0.65, 4), "-|>"),
  edge((1.5, 1.5), (1.5, 4), (0.65, 4), "-|>", corner-radius: 6pt),
)


== Yêu cầu chức năng

#figure(
  kind: table,
  caption: [Danh mục yêu cầu chức năng của hệ thống ShopNexus],
  table(
    columns: (0.7fr, 3.5fr, 0.7fr, 1fr, 0.7fr),
    align: (center + horizon, left + horizon, center + horizon, center + horizon, center + horizon),
    table.header([Mã], [Mô tả], [UC], [Miền nghiệp vụ], [Quy tắc]),

    table.cell(colspan: 5, align: left)[*Nhóm 1. Định danh, phiên làm việc và phân quyền*],
    [REQ-01], [khởi tạo một tài khoản mới ở vai trò người dùng từ email, tên đăng nhập, mật khẩu và tên hiển thị.], [UC-01], [tài khoản], [BR-02],
    [REQ-02], [mã hoá mật khẩu trước khi lưu vào cơ sở dữ liệu, và không ghi mật khẩu gốc vào bất kỳ bản ghi hay nhật ký nào.], [UC-01], [tài khoản], [BR-05],
    [REQ-03], [tạo phiên đăng nhập và cấp mã định danh truy cập có thời hạn khi xác thực thành công, áp dụng cho cả đăng nhập qua nhà cung cấp danh tính liên kết với hệ thống.], [UC-01, UC-02], [tài khoản], [BR-06],
    [REQ-04], [tra cứu phiên đăng nhập tương ứng ở mọi yêu cầu đã xác thực, và từ chối mã định danh thuộc một phiên đã bị thu hồi.], [UC-02], [tài khoản], [BR-06],
    [REQ-05], [kiểm tra vai trò của người gọi tại tầng dịch vụ trước mọi thao tác quản trị và kiểm duyệt.], [UC-02, UC-05], [tất cả], [BR-01, BR-04],
    [REQ-06], [cho phép người dùng sửa thông tin hiển thị, quản lý sổ địa chỉ với một mặc định cho mỗi loại.], [UC-04], [tài khoản], [BR-55],
    [REQ-49], [thu hồi phiên đăng nhập hiện tại khi người dùng đăng xuất, và thu hồi mọi phiên còn lại của tài khoản khi đổi mật khẩu hoặc khi tài khoản bị khoá.], [UC-02], [tài khoản], [BR-06],

    table.cell(colspan: 5, align: left)[*Nhóm 2. Xác minh danh tính*],
    [REQ-07], [tiếp nhận hồ sơ giấy tờ tuỳ thân vào hàng đợi cho điều phối viên duyệt.], [UC-03, UC-26], [tài khoản], [BR-08],
    [REQ-08], [từ chối tạo tin đăng và từ chối yêu cầu rút tiền của tài khoản chưa được xác minh danh tính.], [UC-03], [tài khoản, danh mục, tài chính], [BR-07],

    table.cell(colspan: 5, align: left)[*Nhóm 3. Tin đăng và kiểm duyệt*],
    [REQ-09], [cho phép người bán soạn tin đăng gồm ảnh, tên, mô tả, danh mục, chế độ giá và ít nhất một phiên bản kèm số lượng tồn.], [UC-06], [danh mục], [BR-14, BR-15],
    [REQ-10], [từ chối công bố tin đăng nếu người bán chưa khai báo địa chỉ lấy hàng, và gắn cứng địa chỉ đó vào tin ngay tại thời điểm công bố.], [UC-06], [danh mục, tài khoản], [BR-11],
    [REQ-11], [giữ mọi tin đăng mới công bố và mọi bản sửa ở trạng thái chờ duyệt theo thứ tự gửi, và không hiển thị công khai trước khi được duyệt.], [UC-06, UC-08, UC-24], [danh mục], [BR-10, BR-12],
    [REQ-12], [cho phép điều phối viên duyệt, từ chối kèm lý do hoặc gỡ một tin đăng, và phân biệt tin bị gỡ với tin người bán tự ẩn.], [UC-24], [danh mục], [BR-13, BR-49],
    [REQ-13], [sinh một biểu mẫu tin đăng điền sẵn từ ảnh và ghi chú của người bán, mà không tạo bất kỳ bản ghi nghiệp vụ nào.], [UC-07], [danh mục], [],

    table.cell(colspan: 5, align: left)[*Nhóm 4. Tìm kiếm, duyệt và quan tâm*],
    [REQ-14], [trả kết quả tìm kiếm theo từ khoá tự nhiên, kết hợp đối sánh chuỗi với đối sánh ngữ nghĩa khi tin đăng đã có embedding.], [UC-09], [danh mục], [],
    [REQ-15], [cho phép lọc kết quả theo danh mục, khoảng giá, tình trạng và khoảng cách, và sắp xếp theo mới nhất, giá, lượt bán hoặc điểm đánh giá.], [UC-09], [danh mục], [],
    [REQ-16], [đánh dấu tin đăng, danh mục và thẻ là cần sinh lại embedding mỗi khi phần nội dung mô tả của chúng thay đổi.], [UC-06, UC-08], [danh mục], [],
    [REQ-17], [cho phép người mua theo dõi một người bán và đánh dấu một tin đăng để xem lại về sau.], [UC-10], [danh mục, tài khoản], [],

    table.cell(colspan: 5, align: left)[*Nhóm 5. Hội thoại và thương lượng giá*],
    [REQ-18], [duy trì đúng một hội thoại trực tiếp cho mỗi cặp tài khoản, và đẩy tin nhắn mới tới thiết bị đang kết nối.], [UC-11], [trò chuyện], [BR-56],
    [REQ-19], [cho phép người mua mở thương lượng và hai bên luân phiên đưa đề xuất trên tin ở chế độ thương lượng, và từ chối đề xuất nhắm vào tin giá cố định.], [UC-12], [đơn hàng, danh mục], [BR-14, BR-16, BR-19, BR-20],
    [REQ-20], [cho phép bên không đang giữ đề xuất hiện hành chấp thuận điều khoản, đóng băng mức giá đó trong 30 phút mà không thu bất kỳ khoản nào.], [UC-12], [đơn hàng], [BR-16, BR-18],
    [REQ-21], [đánh dấu hết hiệu lực cho đề xuất không được phản hồi trong 12 giờ, và cho điều khoản đã chấp thuận không được tạo đơn trong 30 phút.], [UC-12], [đơn hàng], [BR-17, BR-18],

    table.cell(colspan: 5, align: left)[*Nhóm 6. Đặt hàng và thanh toán ký quỹ*],
    [REQ-22], [lập một phiếu mua tạm đóng băng giá niêm yết trong 30 phút từ các mục người mua đã chọn.], [UC-13], [đơn hàng], [BR-54],
    [REQ-23], [hỏi giá vận chuyển từ mọi hãng đang bật cho một phiếu mua tạm hoặc một thương lượng đã chấp thuận, và loại hãng nào không báo giá được.], [UC-13], [đơn hàng], [BR-25, BR-52],
    [REQ-24], [giành quyền dùng phiếu mua tạm hoặc thương lượng đã chấp thuận trước khi mở phiên thanh toán 15 phút, và trả lại quyền đó khi phiên hết hạn.], [UC-14], [đơn hàng, tài chính], [BR-23, BR-24],
    [REQ-25], [chỉ ghi nhận kết quả thanh toán từ thông báo gọi lại của nhà cung cấp, và không phát sinh bút toán mới khi cùng một thông báo được gửi lại.], [UC-14], [tài chính], [BR-22],
    [REQ-26], [giữ tiền hàng vào ký quỹ, tách phí giao hàng thành chặng riêng, rồi tạo đơn hàng và kiện hàng ở trạng thái chờ người bán xác nhận.], [UC-14, UC-15], [tài chính, đơn hàng], [BR-21, BR-26],

    table.cell(colspan: 5, align: left)[*Nhóm 7. Vòng đời đơn hàng và giải ngân*],
    [REQ-27], [cho phép người bán xác nhận đơn trong 48 giờ, và chỉ đặt vận đơn với hãng sau khi đơn đã được xác nhận.], [UC-15], [đơn hàng], [BR-28, BR-30],
    [REQ-28], [cho phép người bán từ chối đơn kèm lý do bắt buộc, hoàn cho người mua cả tiền hàng lẫn phí giao hàng, và trả lại tồn kho.], [UC-15], [đơn hàng, tài chính, danh mục], [BR-27, BR-29],
    [REQ-29], [cảnh báo bộ phận vận hành khi hết 48 giờ mà đơn chưa được xác nhận, và giữ nguyên trạng thái của đơn.], [UC-15], [đơn hàng, tín nhiệm], [BR-28],
    [REQ-30], [cập nhật mốc hành trình của kiện hàng theo thông báo của hãng, bỏ qua mốc lùi và mốc không thuộc từ vựng hệ thống.], [UC-16], [đơn hàng], [BR-31],
    [REQ-31], [bắt buộc người mua đính kèm ít nhất một tệp bằng chứng khi xác nhận đã nhận hàng.], [UC-17], [đơn hàng], [BR-33],
    [REQ-32], [chuyển tiền hàng từ ký quỹ sang số dư khả dụng của người bán sau 72 giờ kể từ khi người mua xác nhận, nếu không có hồ sơ hoàn tiền đang sống.], [UC-17], [đơn hàng, tài chính], [BR-32, BR-34],

    table.cell(colspan: 5, align: left)[*Nhóm 8. Trả hàng, hoàn tiền và phiếu hỗ trợ*],
    [REQ-33], [cho phép người mua mở hồ sơ hoàn tiền kèm lý do và bằng chứng trước khi đơn kết thúc, và loại đơn đó khỏi danh sách chờ giải ngân.], [UC-19], [đơn hàng], [BR-37],
    [REQ-34], [giới hạn nước đi của người bán trong 48 giờ ở hai lựa chọn là chấp nhận cho trả hàng hoặc chuyển hồ sơ cho sàn, và tự chuyển khi hết hạn.], [UC-20], [đơn hàng], [BR-39, BR-40],
    [REQ-35], [mở chặng trả hàng với phí bằng không khi hồ sơ được chấp nhận, mở 48 giờ kiểm hàng khi người bán xác nhận đã nhận hàng, và hoàn tiền khi hết cửa sổ đó.], [UC-20], [đơn hàng, tài chính], [BR-38, BR-42],
    [REQ-36], [cho phép điều phối viên ra phán quyết với đúng 2 kết cục cho một hồ sơ đang chờ phân xử, và đóng mọi phiếu hỗ trợ đang mở nhắm vào hồ sơ đó.], [UC-25], [đơn hàng, tín nhiệm], [BR-41, BR-43, BR-50],
    [REQ-37], [tiếp nhận mọi loại yêu cầu người dùng gửi lên dưới dạng một phiếu hỗ trợ có hội thoại riêng với bàn hỗ trợ, và ẩn danh tính người trả lời.], [UC-22, UC-23], [tín nhiệm, trò chuyện], [BR-03, BR-44, BR-45, BR-46, BR-47, BR-48],
    [REQ-47], [cho phép người mua rút hồ sơ hoàn tiền khi người bán chưa trả lời, đưa hồ sơ về một trạng thái kết thúc riêng khác với bị bác bỏ, và trả đơn về danh sách chờ giải ngân.], [UC-19], [đơn hàng], [BR-37],

    table.cell(colspan: 5, align: left)[*Nhóm 9. Đánh giá, uy tín và ví*],
    [REQ-38], [cho phép người đã mua viết nhận xét sản phẩm, người bán phản hồi và người dùng bình chọn hữu ích, đếm tách rời với đánh giá giao dịch.], [UC-21], [tín nhiệm, danh mục], [BR-52, BR-51],
    [REQ-39], [hiển thị số dư khả dụng, số dư đang giữ và sổ bút toán chỉ-thêm-mới của ví.], [UC-18], [tài chính], [BR-35],
    [REQ-40], [cho phép rút phần số dư khả dụng về tài khoản ngân hàng đã đăng ký, trừ ví ngay khi yêu cầu được tạo và hoàn lại khi bị từ chối.], [UC-18, UC-28], [tài chính], [BR-07, BR-36],
    [REQ-48], [cho phép quản trị viên ghi một bút toán điều chỉnh số dư bằng tay kèm lý do bắt buộc, cùng đường ghi sổ như mọi biến động khác.], [UC-28], [tài chính], [BR-35, BR-53],

    table.cell(colspan: 5, align: left)[*Nhóm 10. Quản trị, tệp đính kèm và vận hành*],
    [REQ-41], [cho phép duy nhất quản trị viên cấp phát và thu hồi tài khoản điều phối viên.], [UC-05], [tài khoản], [BR-04],
    [REQ-42], [cho phép quản trị viên bật, tắt hoặc đổi nhà cung cấp phục vụ cho từng dòng của sổ tuỳ chọn, và giữ dòng đã tắt ở dạng đọc được cho bản ghi cũ.], [UC-27], [tài chính, đơn hàng], [BR-52],
    [REQ-46], [cho phép quản trị viên tạo, đổi tên và sắp lại cây danh mục, từ chối một phép sắp lại tạo ra chu trình, và từ chối xoá danh mục đang có tin đăng.], [UC-27], [danh mục], [],
    [REQ-43], [cấp một đường tải lên có chữ ký cho mỗi tệp, và chỉ gắn tệp vào nghiệp vụ gọi tới sau khi người dùng xác nhận đã tải xong.], [UC-S1], [mọi dịch vụ có nghiệp vụ nhận tệp], [],
    [REQ-44], [ghi một bản ghi kiểm toán chỉ-thêm-mới trong cùng giao dịch cơ sở dữ liệu với mỗi quyết định nghiệp vụ và mỗi biến động tiền.], [UC-S2], [tất cả], [BR-53],
    [REQ-45], [thu thập 4 tín hiệu vận hành gồm lưu lượng vào, lời gọi ra ngoài, sự kiện nghiệp vụ và số đo thời gian chạy, không làm chậm yêu cầu đang phục vụ.], [UC-29], [quan trắc], [],
  )
)

== Yêu cầu phi chức năng
#figure(
  kind: table,
  caption: [Bộ yêu cầu phi chức năng kiểm chứng được],
  table(
    columns: (0.7fr, 5.6fr),
    align: (center + horizon, left + top),
    table.header([Mã], [Phát biểu]),

    table.cell(colspan: 2, align: left)[*a) Bảo mật, phân quyền và kiểm toán*],
    [NFR-01], [Mật khẩu có độ dài 8–72 ký tự, được xác thực tại mọi luồng nhập liệu. Mật khẩu được băm bằng thuật toán bcrypt với muối (salt) độc lập; bản rõ bị hủy ngay tại tầng dịch vụ. Cố ý không áp dụng các quy tắc ép buộc ký tự đặc biệt nhằm tránh việc người dùng thiết lập các biến thể dễ đoán.],
    [NFR-02], [Vòng đời Access Token tối đa 15 phút; phiên đăng nhập tối đa 30 ngày. Mọi yêu cầu API có xác thực đều phải đi qua bộ lọc kiểm tra trạng thái phiên tương ứng trước khi được xử lý.],
    [NFR-03], [Thao tác thu hồi phiên có hiệu lực tức thời ở yêu cầu API kế tiếp. Cơ chế thu hồi toàn bộ phiên của một tài khoản được thực thi bằng một phép cập nhật nguyên tử, không phụ thuộc vào số lượng thiết bị đang đăng nhập.],
    [NFR-04], [Mọi định danh thực thể công bố qua API đều được làm mờ (obfuscated) thông qua phép hoán vị bảo toàn định dạng (FPE) với khóa bí mật, ngăn chặn việc dò đoán quy mô bản ghi bằng cách tịnh tiến ID.],
    [NFR-05], [Cơ chế kiểm soát truy cập theo vai trò (RBAC) được thực thi tại tầng dịch vụ (Service Layer) thay vì lớp API Gateway trung gian. Quyết định kiến trúc này đòi hỏi mọi điểm vào quản trị và kiểm duyệt đều phải tường minh gọi hàm kiểm tra vai trò do không có middleware lớp trên chặn thay.],
    [NFR-06], [Tài nguyên không thuộc quyền sở hữu của người gọi ngoài cuộc phải trả về mã `404 Not Found` thay vì `403 Forbidden` nhằm che giấu sự tồn tại của bản ghi. Mã `403` chỉ dành cho chủ thể có liên quan nhưng thao tác sai vai trò.],
    [NFR-07], [Toàn bộ dữ liệu người dùng truyền vào CSDL phải thông qua tham số truy vấn (parameterized query). Các đoạn truy vấn động chỉ được phép ghép từ các hằng số biên dịch thông qua phép rẽ nhánh trên tập giá trị đóng (enum), tuyệt đối không dùng phép nối chuỗi.],
    [NFR-08], [Toàn bộ giao tiếp mạng phải được mã hóa bằng TLS 1.2 trở lên; từ chối phục vụ nội dung trên kênh HTTP thuần. Yêu cầu này được thực thi tại lớp biên hạ tầng (Reverse Proxy) thông qua cơ chế TLS Termination.],
    [NFR-09], [Thông tin định danh cá nhân (PII) chỉ được tiết lộ cho chủ sở hữu hợp pháp. Danh tính của điều phối viên xử lý phiếu được ẩn danh hóa (anonymized) đối với người dùng ở mọi giao diện hiển thị.],
    [NFR-19], [Bản ghi kiểm toán mang tính bất biến (Append-only). Ứng dụng không được phép phát lệnh sửa/xóa trên bảng này; ràng buộc duy nhất (Unique) ở mức CSDL sẽ từ chối mọi nỗ lực ghi đè phiên bản. *Hạn chế:* Quyền sửa/xóa chưa bị thu hồi ở cấp độ CSDL do tài khoản ứng dụng đang giữ quyền sở hữu lược đồ.],

    table.cell(colspan: 2, align: left)[*b) Tin cậy và toàn vẹn dữ liệu*],
    [NFR-10], [Mọi thao tác chuyển trạng thái theo thời hạn đều mang tính lũy đẳng (idempotent). Hệ thống chấp nhận 2 nguồn kích hoạt song song (Durable Workflow và Cronjob) cùng chia sẻ một định nghĩa logic về thời điểm "đến hạn", đảm bảo không sinh hiệu ứng phụ khi gọi trùng lặp.],
    [NFR-11], [Cấm tuyệt đối hiện tượng nhân đôi đơn hàng hoặc quyết toán kép. Nguyên tắc này được bảo vệ cứng ở tầng CSDL bằng các ràng buộc duy nhất (Unique Constraints), thay vì phụ thuộc vào phép kiểm tra logic (Check-then-Act) dễ sinh lỗi tương tranh.],
    [NFR-12], [Số dư ví không được phép âm, và tổng các biến động trong sổ bút toán phải luôn khớp với số dư hiện hành. Các bất biến này được cưỡng chế trực tiếp bằng ràng buộc kiểm tra (Check Constraints) tại CSDL, lập tức từ chối thao tác ghi gây sai lệch.],
    [NFR-13], [Áp dụng cơ chế khóa lạc quan (Optimistic Locking). Hai giao dịch đồng thời lên cùng một bản ghi phải khiến giao dịch đến sau thất bại bằng lỗi xung đột (Conflict), ngăn chặn việc âm thầm ghi đè lên dữ liệu đã bị biến đổi.],
    [NFR-14], [Mỗi dịch vụ sở hữu độc quyền một lược đồ CSDL riêng, quản lý qua nhóm kết nối có đường dẫn tìm kiếm (search path) bị khóa cứng. Tuyệt đối không sử dụng khóa ngoại vật lý xuyên lược đồ. *Hạn chế:* Sự cô lập hiện tại được giữ bằng cấu hình định tuyến thay vì phân quyền tài khoản CSDL.],

    table.cell(colspan: 2, align: left)[*c) Khả năng bảo trì và ràng buộc kỹ thuật*],
    [NFR-15], [Mọi kết nối ra nhà cung cấp bên ngoài phải khai báo hạn định thời gian (Timeout) rõ ràng. Thao tác có đặc thù độ trễ khác biệt phải cấu hình Timeout độc lập. *Hạn chế:* Tiêu chuẩn này chưa đạt độ phủ toàn diện; hãng vận chuyển vẫn chưa khai báo Timeout hợp lệ.],
    [NFR-16], [Quy tụ toàn bộ cấu hình hệ thống vào một tệp duy nhất. Cơ chế nạp cấu hình áp dụng nguyên tắc Fail-fast: mọi trường thiếu, thừa hoặc sai định dạng đều khiến tiến trình lập tức từ chối khởi động và báo lỗi chính xác vị trí, ngăn ứng dụng chạy ngầm với cấu hình sai lệch.],
    [NFR-17], [Tài liệu đặc tả OpenAPI đóng vai trò nguồn chân lý duy nhất (Single Source of Truth), được tổng hợp tự động từ mã nguồn các dịch vụ và đủ tiêu chuẩn để khởi tạo máy chủ giả lập (Mock Server).],
    [NFR-18], [Thông điệp ngoại lệ trả về máy khách được bọc trong phong bì (Error Envelope) kèm một mã lỗi (Error Code) độc lập với ngôn ngữ.],
  )
)