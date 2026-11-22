#import "../../../common/tokens.typ": *

= PHÂN TÍCH VÀ THIẾT KẾ HỆ THỐNG

== Phân tích yêu cầu hệ thống

=== Các tác nhân của hệ thống

Hệ thống phục vụ người dùng bao gồm cả vai trò mua và bán, điều phối viên và quản trị viên. Một tài khoản của người dùng có thể đăng bán hàng của mình và mua hàng của người dùng khác. Tài khoản nhân viên thuộc phạm vi trang điều hành, được quản lý riêng với tài khoản mua bán.

#figure(
  table(
    columns: (1fr, 3fr),
    align: left,
    table.header([Tác nhân], [Vai trò và phạm vi tương tác]),
    [Khách], [Duyệt danh mục, tìm kiếm và xem tin đăng trước khi đăng nhập.],
    [Người dùng], [Quản lý tài khoản; đăng tin, tìm kiếm, trò chuyện, trả giá, đặt hàng, theo dõi giao nhận, đánh giá, báo cáo và gửi phiếu hỗ trợ.],
    [Điều phối viên], [Tra cứu tài khoản, tin đăng và đơn COD; xử lý báo cáo, phiếu hỗ trợ; thực hiện thao tác quản lý theo quyền và sử dụng trợ lý AI trên trang điều hành.],
    [Quản trị viên], [Có quyền của điều phối viên, đồng thời quản lý nhân viên, tra cứu nhật ký kiểm toán và quản lý cấu hình dịch vụ bên thứ 3.],
  ),
  caption: [Các tác nhân của hệ thống],
)
=== Yêu cầu chức năng

#figure(
  kind: table,
  table(
    columns: (auto, 1fr, 2.4cm, 3.4cm),
    inset: (x: 6pt, y: 3pt),
    align: left + top,
    table.header([Mã], [Yêu cầu], [Phân hệ], [UC liên quan]),
    [#box("FR-ACC-01")], [#text("Đăng nhập bằng số điện thoại, mã gửi qua email hoặc tài khoản Google; tự tạo tài khoản ở lần đầu")], [#text("Xác thực")], [#text("UC-ACC-01")],
    [#box("FR-ACC-02")], [#text("Liệt kê phiên, đăng xuất một thiết bị hoặc mọi thiết bị")], [#text("Xác thực")], [#text("UC-ACC-02")],
    [#box("FR-ACC-03")], [#text("Sửa tên hiển thị; chặn và bỏ chặn người dùng")], [#text("Tài khoản")], [#text("UC-ACC-05")],
    [#box("FR-ACC-05")], [#text("Thiết lập giao COD: địa chỉ lấy hàng, liên kết tài khoản GHTK/GHN của người bán")], [#text("Vận chuyển")], [#text("UC-ACC-04")],
    [#box("FR-SHR-01")], [#text("Tải ảnh lên, chuẩn hóa ảnh, xóa thông tin vị trí chụp")], [#text("Media")], [#text("UC-SHR-01")],
    [#box("FR-LST-01")], [#text("Đăng tin từ video, ảnh hoặc link Chợ Tốt với AI điền giúp; gợi ý giá từ tin tương tự; lưu nháp")], [#text("Tin đăng")], [#text("UC-LST-01")],
    [#box("FR-LST-02")], [#text("Quản lý tin: sửa, đổi giá, ẩn/hiện, đánh dấu đã bán, xóa")], [#text("Tin đăng")], [#text("UC-LST-02")],
    [#box("FR-LST-03")], [#text("Đẩy tin và gói người bán")], [#text("Tin đăng")], [#text("UC-LST-03")],
    [#box("FR-DSC-01")], [#text("Tìm kiếm bằng câu tự nhiên: AI đọc câu thành điều kiện, trả chip tắt được và câu diễn giải; tìm bằng ảnh")], [#text("Khám phá")], [#text("UC-DSC-01")],
    [#box("FR-DSC-02")], [#text("Tìm theo bộ lọc, duyệt danh mục, xem tin tương tự")], [#text("Khám phá")], [#text("UC-DSC-02")],
    [#box("FR-DSC-03")], [#text("Lưu tin, báo giảm giá dưới mức đặt, theo dõi tìm kiếm, theo dõi người bán, ẩn tin")], [#text("Khám phá")], [#text("UC-DSC-03")],
    [#box("FR-DEAL-01")], [#text("Nhắn tin văn bản và ảnh, đánh dấu đã đọc, tìm trong hộp thư, cập nhật thời gian thực")], [#text("Trò chuyện")], [#text("UC-DEAL-01")],
    [#box("FR-DEAL-02")], [#text("Trả giá theo BR-DEAL-03")], [#text("Giao dịch")], [#text("UC-DEAL-02")],
    [#box("FR-DEAL-03")], [#text("Yêu cầu COD; tạo vận đơn GHTK/GHN trên tài khoản người bán hoặc nhập mã; hủy trước khi gửi")], [#text("Giao dịch, Vận chuyển")], [#text("UC-DEAL-03, UC-DEAL-04, UC-DEAL-06")],
    [#box("FR-DEAL-04")], [#text("Nhận trạng thái vận đơn từ hãng, hỏi lại mỗi 2 giờ; cập nhật đơn, phiên trả giá, tin đăng; tự hoàn tất và tự hủy theo thời hạn")], [#text("Vận chuyển, Giao dịch")], [#text("UC-DEAL-05")],
    [#box("FR-TRS-01")], [#text("Đánh giá hai chiều sau đơn, người được đánh giá trả lời một lần")], [#text("Uy tín")], [#text("UC-TRS-01")],
    [#box("FR-TRS-03")], [#text("Tính số liệu uy tín: sao trung bình khi bán và khi mua, số món đã bán, tỉ lệ trả lời trong 24 giờ, đơn giao không thành trong 90 ngày")], [#text("Uy tín")], [#text("UC-DSC-04, UC-TRS-04")],
    [#box("FR-TRS-04")], [#text("Cảnh báo dấu hiệu lừa đảo trong trò chuyện; người dùng tắt được cảnh báo")], [#text("Uy tín")], [#text("UC-DEAL-01")],
    [#box("FR-MOD-01")], [#text("Báo cáo vi phạm; nhân viên xử lý và tạm khóa tài khoản")], [#text("Uy tín, Nhân viên")], [#text("UC-MOD-01, UC-MOD-02")],
    [#box("FR-SHR-02")], [#text("Thông báo trong ứng dụng và đẩy tới điện thoại; công tắc theo loại và giờ yên lặng")], [#text("Thông báo")], [#text("UC-DEAL-02 – UC-TRS-01")],
    [#box("FR-MOD-02")], [#text("Quản lý tài khoản nhân viên, đăng nhập riêng vào trang điều hành, nhật ký kiểm toán")], [#text("Nhân viên")], [#text("UC-MOD-04, UC-MOD-05, UC-SHR-02")],
    [#box("FR-MOD-03")], [#text("Trợ lý AI của trang điều hành đọc ca báo cáo và phiếu hỗ trợ, trình bằng chứng, đề xuất thao tác và soạn câu trả lời; nhân viên duyệt, sửa bằng tick hoặc qua cuộc trò chuyện, làm theo và hoàn tác")], [#text("Nhân viên, AI")], [#text("UC-MOD-06, UC-MOD-07, UC-MOD-08")],
    [#box("FR-MOD-04")], [#text("Phiếu hỗ trợ là một cuộc trò chuyện giữa người dùng và hệ thống; nhân viên trả lời trên trang điều hành")], [#text("Hỗ trợ")], [#text("UC-MOD-09, UC-MOD-07")],
  ),
  caption: [Danh mục yêu cầu chức năng],
) <tab-functional-requirements>

=== Yêu cầu phi chức năng

#figure(
  kind: table,
  table(
    columns: (auto, 3.2cm, 1fr),
    inset: (x: 6pt, y: 3pt),
    align: left + top,
    table.header([Mã], [Thuộc tính], [Tiêu chí kiểm chứng]),
    [#box("NFR-DUR-01")], [#text("Độ bền")], [#text("Máy chủ gặp sự cố giữa một quy trình nhiều bước không để lại dữ liệu dở dang; quy trình chạy tiếp từ bước đã xong và không lặp việc đã làm (không tạo hai vận đơn, không gửi hai email mã OTP).")],
    [#box("NFR-IDEM-01")], [#text("Không lặp khi gửi lại")], [#text("Một thao tác được ứng dụng gửi lại vì mạng chập chờn cho đúng kết quả của lần đầu; hãng báo trùng một trạng thái thì đơn không đổi trạng thái hai lần.")],
    [#box("NFR-CONC-01")], [#text("Nhất quán khi đồng thời")], [#text("Hai người cùng sửa một dữ liệu thì người sửa sau được báo dữ liệu đã thay đổi thay vì ghi đè; các hạn mức (số đơn COD đang mở, số tin đang bán) vẫn đúng khi nhiều yêu cầu đến cùng lúc.")],
    [#box("NFR-MSG-01")], [#text("Không mất thông báo giữa phân hệ")], [#text("Thông báo cho các phân hệ khác được ghi cùng lúc với thay đổi dữ liệu; khi phần điều phối quy trình tạm ngừng, thông báo được giữ lại và gửi sau, người dùng vẫn xem được dữ liệu và giữ được phiên đăng nhập.")],
    [#box("NFR-PERF-01")], [#text("Hiệu năng")], [#text("95% lượt xem dữ liệu trả về dưới 300 ms; 95% lượt tìm kiếm có câu đã đọc trả về dưới 800 ms; mô hình đọc câu quá 4 giây thì hệ thống tìm bằng câu gốc.")],
    [#box("NFR-SEC-01")], [#text("An toàn xác thực")], [#text("Phiên đăng nhập ngắn hạn sống 15 phút và được làm mới tự động; mã làm mới bị dùng lại thì phiên bị thu hồi; có hạn mức gửi OTP; không lộ việc một số điện thoại hay email đã có tài khoản.")],
    [#box("NFR-PRIV-01")], [#text("Quyền riêng tư")], [#text("Xóa thông tin vị trí chụp khỏi ảnh; vị trí tin theo phường/xã; che số điện thoại, email trong nhật ký; mã hóa khóa kết nối tài khoản hãng vận chuyển của người bán.")],
    [#box("NFR-OBS-01")], [#text("Quan trắc")], [#text("Mọi yêu cầu được theo vết; thông báo lỗi mang mã tra cứu để đối chiếu nhật ký; có số liệu đăng nhập, gửi OTP và thông báo đã gửi giữa các phân hệ.")],
    [#box("NFR-PERF-02")], [#text("Hiệu năng")], [#text("Một lượt hỏi trợ lý AI của trang điều hành trả lời trong 60 giây hoặc dừng và cho chạy nền, báo khi xong.")],
    [#box("NFR-PRIV-02")], [#text("Quyền riêng tư")], [#text("Mỗi lần trợ lý AI của trang điều hành đọc dữ liệu cá nhân được ghi lại kèm nhân viên đã hỏi; cuộc trò chuyện với trợ lý AI giữ 180 ngày; xóa tài khoản thì xóa các phần trích dữ liệu của tài khoản đó.")],
    [#box("NFR-API-01")], [#text("Tuân thủ hợp đồng API")], [#text("Mọi yêu cầu được kiểm theo đặc tả API; bộ kiểm thử đầu-cuối gặp đủ mọi kết quả trả về đã khai trong đặc tả.")],
    [#box("NFR-ARCH-01")], [#text("Khả năng tách phân hệ")], [#text("Mỗi phân hệ chỉ cho phân hệ khác dùng qua giao diện đã công bố; tách ra chạy riêng không phải sửa nghiệp vụ.")],
    [#box("NFR-UX-01")], [#text("Ứng dụng di động")], [#text("Ứng dụng chạy trên Android 12 trở lên, có giao diện tối, cỡ chữ 130%, vùng chạm tối thiểu 48 dp; website dùng được ở bề rộng điện thoại.")],
  ),
  caption: [Danh mục yêu cầu phi chức năng],
) <tab-nonfunctional-requirements>
== Mô hình ca sử dụng

// === Sơ đồ ca sử dụng tổng quát

// Sơ đồ tổng quát biểu diễn các nhóm ca sử dụng chính của người dùng, điều phối viên và quản trị viên.

// #figure(
//   image("../../../common/assets/chuong3/use-case-overview.png", width: 100%),
//   caption: [Sơ đồ ca sử dụng tổng quát theo nhóm chức năng],
// ) <fig-use-case-overview>
=== Danh sách ca sử dụng

==== Tài khoản và định danh

#figure(
  table(
    columns: (1.1fr, 3.2fr, 1.8fr),
    align: left,
    table.header([Mã], [Tên ca sử dụng], [Tác nhân chính]),
    [UC-ACC-01], [Đăng nhập bằng số điện thoại, email hoặc Google (lần đầu tự tạo tài khoản)], [Người dùng],
    [UC-ACC-02], [Quản lý phiên đăng nhập trên các thiết bị], [Người dùng],
    [UC-ACC-04], [Thiết lập giao COD (địa chỉ lấy hàng, liên kết tài khoản GHTK/GHN)], [Người dùng (vai trò bán)],
    [UC-ACC-05], [Chặn người dùng khác], [Người dùng],
  ),
  caption: [Ca sử dụng về tài khoản và định danh],
) <tab-use-case-account>

==== Đăng bán

#figure(
  table(
    columns: (1.1fr, 3.2fr, 1.8fr),
    align: left,
    table.header([Mã], [Tên ca sử dụng], [Tác nhân chính]),
    [UC-LST-01], [Đăng tin với AI điền giúp (từ video, ảnh hoặc link Chợ Tốt)], [Người dùng (vai trò bán)],
    [UC-LST-02], [Quản lý tin đăng (sửa, đổi giá, ẩn/hiện, đánh dấu đã bán, xóa)], [Người dùng (vai trò bán)],
    [UC-LST-03], [Đẩy tin và đăng ký gói người bán], [Người dùng (vai trò bán)],
  ),
  caption: [Ca sử dụng về đăng bán],
) <tab-use-case-listing>

UC-LST-03 được tài liệu nguồn ghi là dự kiến.

==== Khám phá tin đăng

#figure(
  table(
    columns: (1.1fr, 3.2fr, 1.8fr),
    align: left,
    table.header([Mã], [Tên ca sử dụng], [Tác nhân chính]),
    [UC-DSC-01], [Tìm kiếm bằng câu tự nhiên với AI], [Người dùng, Khách],
    [UC-DSC-02], [Duyệt danh mục và lọc kết quả], [Người dùng, Khách],
    [UC-DSC-03], [Lưu tin, theo dõi tìm kiếm và nhận cảnh báo giảm giá], [Người dùng],
    [UC-DSC-04], [Xem hồ sơ người bán (đánh giá khi bán và khi mua, số liệu, tin đang bán)], [Người dùng (vai trò mua)],
  ),
  caption: [Ca sử dụng về khám phá tin đăng],
) <tab-use-case-discovery>

==== Trao đổi và giao dịch

#figure(
  table(
    columns: (1.1fr, 3.2fr, 1.8fr),
    align: left,
    table.header([Mã], [Tên ca sử dụng], [Tác nhân chính]),
    [UC-DEAL-01], [Nhắn tin theo tin đăng], [Người dùng],
    [UC-DEAL-02], [Trả giá], [Người dùng],
    [UC-DEAL-03], [Yêu cầu giao COD], [Người dùng (vai trò mua)],
    [UC-DEAL-04], [Tạo đơn gửi hàng (vận đơn GHTK/GHN hoặc nhập mã)], [Người dùng (vai trò bán)],
    [UC-DEAL-05], [Theo dõi đơn và nhận hàng đồng kiểm (nhận hoặc từ chối tại cửa)], [Người dùng (vai trò mua)],
    [UC-DEAL-06], [Hủy đơn trước khi gửi hàng], [Người dùng],
  ),
  caption: [Ca sử dụng về trao đổi và giao dịch],
) <tab-use-case-deal>

==== Hậu giao dịch và uy tín

#figure(
  table(
    columns: (1.1fr, 3.2fr, 1.8fr),
    align: left,
    table.header([Mã], [Tên ca sử dụng], [Tác nhân chính]),
    [UC-TRS-01], [Đánh giá người cùng giao dịch và trả lời đánh giá], [Người dùng],
    [UC-TRS-04], [Xem số liệu uy tín và hạn mức], [Người dùng],
  ),
  caption: [Ca sử dụng về hậu giao dịch và uy tín],
) <tab-use-case-trust>

==== Vận hành và hỗ trợ

#figure(
  table(
    columns: (1.1fr, 3.2fr, 1.8fr),
    align: left,
    table.header([Mã], [Tên ca sử dụng], [Tác nhân chính]),
    [UC-MOD-01], [Báo cáo vi phạm (hàng cấm, hàng giả, lừa đảo, khác)], [Người dùng],
    [UC-MOD-02], [Xử lý báo cáo vi phạm và tạm khóa tài khoản], [Điều phối viên],
    [UC-MOD-04], [Quản lý tài khoản điều phối viên], [Quản trị viên],
    [UC-MOD-05], [Tra cứu nhật ký kiểm toán], [Quản trị viên],
    [UC-MOD-06], [Xử lý ca báo cáo với đề xuất của trợ lý AI], [Điều phối viên],
    [UC-MOD-07], [Trả lời phiếu hỗ trợ bằng câu trả lời trợ lý AI soạn], [Điều phối viên],
    [UC-MOD-08], [Hỏi trợ lý AI về một phiếu hỗ trợ, ca báo cáo hoặc tài khoản], [Điều phối viên, Quản trị viên],
    [UC-MOD-09], [Gửi phiếu hỗ trợ (báo chưa nhận hàng, xin thêm hãng, yêu cầu khác)], [Người dùng],
  ),
  caption: [Ca sử dụng về vận hành và hỗ trợ],
) <tab-use-case-moderation>


==== Ca dùng chung

Hai ca dưới đây được sử dụng trong các luồng nghiệp vụ khác, không có tác nhân bên ngoài được chỉ định riêng.

#figure(
  table(
    columns: (1.1fr, 3.2fr, 1.8fr),
    align: left,
    table.header([Mã], [Tên ca sử dụng], [Tác nhân chính]),
    [UC-SHR-01], [Tải ảnh lên (kiểm tra, chuẩn hóa và lưu ảnh)], [Ca con],
    [UC-SHR-02], [Ghi nhật ký kiểm toán], [Ca con],
  ),
  caption: [Các ca sử dụng dùng chung],
) <tab-use-case-shared>



=== Đặc tả các ca sử dụng tiêu biểu

#ucspec("UC-LST-01", "Đăng tin với AI điền giúp (từ video, ảnh hoặc link Chợ Tốt)",
  [Tác nhân chính], [#text("Người dùng (vai trò bán); tác nhân phụ: dịch vụ AI.")],
  [Tiền điều kiện], [#text("Đã đăng nhập.")],
  [Hậu điều kiện], [#text("Tin được lưu ở trạng thái đang xử lý; khi mọi ảnh xử lý xong, tin chuyển sang đang bán và bắt đầu xuất hiện trong kết quả tìm kiếm.")],
  [Luồng chính], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("1.")], [#text("Người bán chụp hoặc chọn từ thư viện 1–10 ảnh, hoặc quay video; ảnh được tải lên qua UC-SHR-01.")],
      [#text("2.")], [#text("AI đọc ảnh, hoặc khung hình và lời nói tiếng Việt trong video, rồi điền tiêu đề, danh mục, tình trạng theo thang Mới/Như mới/Đã dùng, thông số, mô tả và khoảng giá tham khảo.")],
      [#text("3.")], [#text("Người bán sửa biểu mẫu, nhập giá, xác nhận phường/xã rồi bấm Đăng.")],
      [#text("4.")], [#text("Hệ thống kiểm quyền đăng và trần số tin của người bán (BR-LST-02), kể cả khi người bán gửi nhiều tin cùng lúc; kiểm giới hạn từng mục (BR-LST-03).")],
      [#text("5.")], [#text("Hệ thống lưu tin ở trạng thái đang xử lý, chuẩn hóa ảnh và xóa thông tin vị trí chụp trong ảnh; xong thì tin chuyển sang đang bán, ứng dụng báo \"Đã đăng tin\".")],
    )
  ],
  [Luồng thay thế], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("A1 -")], [#text("Ở bước 2: Mô hình không trả kết quả: người bán tự điền biểu mẫu, tiếp tục bước 3.")],
      [#text("A2 -")], [#text("Ở bước 1: Người bán dán link tin của mình trên Chợ Tốt: hệ thống hiện thẻ xem trước rồi đọc tin đó thành biểu mẫu, bỏ số điện thoại và Zalo trong mô tả.")],
      [#text("A3 -")], [#text("Ở bước 3: Hệ thống hiện các tin tương tự, số người mua đang theo dõi loại hàng này và hai mức gợi ý: giá thị trường và giá bán nhanh, kèm số ngày bán.")],
      [#text("A4 -")], [#text("Ở bước 3: Người bán lưu nháp và quay lại sau; nháp giữ ảnh đã tải.")],
      [#text("A5 -")], [#text("Ở bước 1: Người bán đăng lại từ một tin cũ của mình: ảnh của tin đó được chép thành ảnh tải lên mới.")],
      [#text("A6 -")], [#text("Ở bước 4: Ứng dụng gửi lại cùng một lần đăng: trả đúng tin của lần đầu, không tạo tin thứ hai.")],
    )
  ],
  [Luồng ngoại lệ], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("E1 -")], [#text("Ở bước 4: Tài khoản đang bị tạm khóa: từ chối đăng.")],
      [#text("E2 -")], [#text("Ở bước 4: Đã có 20 tin đang bán: từ chối, báo số tin tối đa.")],
      [#text("E3 -")], [#text("Ở bước 5: Có ảnh lỗi: tin chuyển sang bị từ chối kèm lý do; sửa tin hoặc thêm ảnh đưa tin về đang xử lý.")],
      [#text("E4 -")], [#text("Ở bước 4: Người bán chưa có số điện thoại.")],
      [#text("E5 -")], [#text("Ở bước 4: Nội dung tin sai giới hạn.")],
      [#text("E6 -")], [#text("Ở bước 2: Người bán đã dùng hết lượt đọc bằng AI trong 24 giờ (30 video, 60 ảnh, 30 link).")],
      [#text("E7 -")], [#text("Ở bước 1: Link không phải tin trên Chợ Tốt.")],
      [#text("E8 -")], [#text("Ở bước 4: Ảnh không thuộc người bán hoặc chưa tải xong.")],
    )
  ],
  [Quy tắc liên quan], [#text("BR-LST-01, BR-LST-02, BR-LST-03.")],
) <tab-spec-listing>

#ucspec("UC-DSC-01", "Tìm kiếm bằng câu tự nhiên với AI",
  [Tác nhân chính], [#text("Người dùng hoặc Khách; tác nhân phụ: dịch vụ AI.")],
  [Tiền điều kiện], [#text("Không bắt buộc đăng nhập.")],
  [Hậu điều kiện], [#text("Hệ thống hiển thị danh sách tin phù hợp, các điều kiện lọc (người dùng có thể tắt từng điều kiện) và một câu diễn giải kết quả tìm kiếm. Dữ liệu nghiệp vụ không thay đổi.")],
  [Luồng chính], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("1.")], [#text("Người dùng gõ một câu nhu cầu, hoặc chọn một ảnh để tìm món giống.")],
      [#text("2.")], [#text("Hệ thống gửi câu truy vấn đến mô hình ngôn ngữ lớn (LLM). Mô hình diễn giải câu đó thành các điều kiện lọc: cụm từ khóa, danh mục, giá, tình trạng, nơi bán, độ gần và độ mới. Những điều kiện không khớp với dữ liệu thật (danh mục, tỉnh, xã) bị loại bỏ.")],
      [#text("3.")], [#text("Hệ thống tìm trên các tin đang bán theo ba cách (khớp từ khóa, theo nghĩa của câu, theo ảnh) rồi hợp nhất thứ hạng; câu gốc luôn được giữ làm một cụm từ tìm.")],
      [#text("4.")], [#text("Hệ thống trả tin, điều kiện lọc và câu diễn giải; kết quả diễn giải được lưu vào bộ nhớ đệm 7 ngày; trong thời gian này, các lần tìm có cùng câu tìm kiếm dùng lại kết quả đã lưu mà không gọi lại mô hình.")],
      [#text("5.")], [#text("Người dùng bỏ một điều kiện lọc; hệ thống áp dụng lại các điều kiện còn lại để tìm kiếm và cập nhật danh sách tin, không gọi lại mô hình ngôn ngữ.")],
    )
  ],
  [Luồng thay thế], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("A1 -")], [#text("Ở bước 2: Mô hình lỗi hoặc quá 4 giây: hệ thống tìm bằng câu truy vấn gốc, bỏ qua bước xử lý AI.")],
      [#text("A2 -")], [#text("Ở bước 4: Không có tin phù hợp: trả kết quả rỗng kèm điều kiện lọc để người dùng nới điều kiện.")],
      [#text("A3 -")], [#text("Ở bước 4: Người dùng theo dõi câu tìm: hệ thống quét tin mới mỗi 30 phút và báo số tin mới khớp (UC-DSC-03).")],
    )
  ],
  [Quy tắc liên quan], [#text("BR-DSC-01; Kết quả tìm kiếm không bao gồm các tin có trạng thái đang giữ chỗ, đã bán, đang ẩn hoặc đã xóa, và các tin của người dùng có quan hệ chặn với người đang tìm (bất kể bên nào chặn bên nào).")],
) <tab-spec-search>

#ucspec("UC-DEAL-02", "Trả giá",
  [Tác nhân chính], [#text("Người dùng (vai trò mua).")],
  [Tiền điều kiện], [#text("Đã đăng nhập; tin đăng đang bán.")],
  [Hậu điều kiện], [#text("Phiên trả giá ở trạng thái đã chốt giá; người mua có thể yêu cầu COD (UC-DEAL-03).")],
  [Luồng chính], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("1.")], [#text("Người mua mở phiên trả giá trên tin đăng; hệ thống mở hoặc dùng lại cuộc trò chuyện của hai người.")],
      [#text("2.")], [#text("Người mua trả giá theo BR-DEAL-03.")],
      [#text("3.")], [#text("Người bán đề xuất mức giá khác hoặc từ chối; người đưa giá có thể rút giá của mình. Hai bên lặp lại cho tới khi một bên chấp nhận.")],
      [#text("4.")], [#text("Một bên chấp nhận đúng giá mình đang thấy; phiên trả giá chuyển sang đã chốt giá.")],
    )
  ],
  [Luồng thay thế], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("A1 -")], [#text("Ở bước 1: Người mua đã có phiên trả giá trên tin: hệ thống mở lại phiên trả giá đó.")],
      [#text("A2 -")], [#text("Ở bước 2: Người mua chấp nhận ngay giá niêm yết, không trả giá.")],
      [#text("A3 -")], [#text("Ở bước 4: Sau khi chốt, một bên hủy chốt giá khi chưa có đơn: phiên trả giá quay lại bước 2.")],
      [#text("A4 -")], [#text("Ở bước 3: Người bán đổi giá niêm yết, tắt trả giá, ẩn hoặc xóa tin: giá đang mở bị rút; tin bị xóa thì chốt giá cũng bị bỏ.")],
    )
  ],
  [Luồng ngoại lệ], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("E1 -")], [#text("Ở bước 1: Tài khoản đang bị tạm khóa.")],
      [#text("E2 -")], [#text("Ở bước 1: Người mua chưa có số điện thoại.")],
      [#text("E3 -")], [#text("Ở bước 1: Tin đăng của chính người mua.")],
      [#text("E4 -")], [#text("Ở bước 1: Hai người đã chặn nhau.")],
      [#text("E5 -")], [#text("Ở bước 1: Tin không còn đang bán.")],
      [#text("E6 -")], [#text("Ở bước 2: Giá trả sai bước giá hoặc ngoài khoảng cho phép.")],
      [#text("E7 -")], [#text("Ở bước 4: Giá vừa bị đổi trước khi chấp nhận.")],
      [#text("E8 -")], [#text("Ở bước 3: Bên kia vừa đi trước một bước.")],
      [#text("E9 -")], [#text("Ở bước 3: Chưa tới lượt hoặc trạng thái không cho bước này.")],
    )
  ],
  [Quy tắc liên quan], [#text("BR-DEAL-03, BR-DEAL-04, BR-ACC-01, BR-ACC-03, BR-MOD-02.")],
) <tab-spec-negotiation>

#ucspec("UC-DEAL-04", "Tạo đơn gửi hàng (vận đơn GHTK/GHN hoặc nhập mã)",
  [Tác nhân chính], [#text("Người dùng (vai trò bán); tác nhân phụ: hãng vận chuyển.")],
  [Tiền điều kiện], [#text("Có đơn đang chờ gửi; người bán đã liên kết tài khoản GHTK hoặc GHN (UC-ACC-04).")],
  [Hậu điều kiện], [#text("Đơn ở trạng thái đã gửi, tin đăng được giữ cho đơn này; các đơn chờ khác trên tin bị hủy.")],
  [Luồng chính], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("1 -")], [#text("Người bán chọn tạo vận đơn qua hãng đã liên kết (điểm lấy hàng, dịch vụ, khối lượng), hoặc nhập mã vận đơn đã tạo trên ứng dụng của hãng đó.")],
      [#text("2 -")], [#text("Hệ thống giữ tin đăng cho đơn.")],
      [#text("3 -")], [#text("Hệ thống tạo vận đơn trên tài khoản hãng của người bán, thu hộ tiền hàng, người nhận trả phí vận chuyển; với mã nhập tay, hệ thống đọc vận đơn bằng tài khoản hãng của người bán.")],
      [#text("4 -")], [#text("Đơn chuyển sang đã gửi; các đơn chờ khác trên tin tự hủy với lý do \"đã gửi cho người khác\".")],
      [#text("5 -")], [#text("Hệ thống bắt đầu đếm thời hạn hãng lấy hàng và theo dõi trạng thái vận đơn.")],
    )
  ],
  [Luồng thay thế], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("A1 -")], [#text("Ở bước 1: Ứng dụng gửi lại cùng một yêu cầu: trả đúng kết quả lần đầu, không tạo thêm vận đơn.")],
      [#text("A2 -")], [#text("Ở bước 4: Hãng báo vận đơn nhập tay đã giao: hệ thống hẹn giờ tự hoàn tất đơn.")],
      [#text("A3 -")], [#text("Ở bước 5: Người bán sửa mã vận đơn nhập tay khi hàng chưa giao.")],
    )
  ],
  [Luồng ngoại lệ], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("E1 -")], [#text("Ở bước 3: Mã vận đơn không thuộc tài khoản hãng của người bán.")],
      [#text("E2 -")], [#text("Ở bước 1: Hệ thống không bật hãng vận chuyển nào.")],
      [#text("E3 -")], [#text("Ở bước 1: Người bán chưa liên kết hãng.")],
      [#text("E4 -")], [#text("Ở bước 3: Hãng không giao tới địa chỉ; tin đăng được trả lại.")],
      [#text("E5 -")], [#text("Ở bước 2: Tin không còn đang bán.")],
      [#text("E6 -")], [#text("Ở bước 3: Vận đơn sai quy tắc hoặc hãng báo vận đơn hỏng.")],
      [#text("E7 -")], [#text("Ở bước 4: Đơn bị hủy cùng lúc: tin đăng được trả lại, vận đơn vừa tạo bị hủy trên hãng.")],
      [#text("E8 -")], [#text("Ở bước 1: Đơn không còn chờ gửi hoặc không phải của người bán.")],
    )
  ],
  [Quy tắc liên quan], [#text("BR-DEAL-04, BR-DEAL-05, BR-DEAL-12.")],
) <tab-spec-shipping>

#ucspec("UC-DEAL-05", "Theo dõi đơn và nhận hàng đồng kiểm (nhận hoặc từ chối tại cửa)",
  [Tác nhân chính], [#text("Người mua; tác nhân phụ: hãng vận chuyển.")],
  [Tiền điều kiện], [#text("UC-DEAL-04 đã hoàn tất: đơn ở trạng thái đã gửi, vận đơn nằm trên tài khoản GHTK/GHN của người bán.")],
  [Hậu điều kiện], [#text("Nhận: đơn hoàn tất, tin và phiên trả giá đã bán, hai bên được mời đánh giá nhau (UC-TRS-01). Từ chối: đơn giao không thành, tin về đang bán, phiên trả giá về đang trả giá, số đơn giao không thành của người mua tăng (UC-TRS-04).")],
  [Luồng chính], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("1.")], [#text("Hãng lấy hàng và báo trạng thái về hệ thống; ứng dụng cập nhật màn hình đơn và gửi thông báo đẩy. Hãng không báo thì hệ thống hỏi lại mỗi 2 giờ.")],
      [#text("2.")], [#text("Shipper mang hàng tới cửa người mua.")],
      [#text("3.")], [#text("Người mua xem hàng, đồng ý nhận và trả tiền hàng cùng phí vận chuyển chiều đi cho shipper.")],
      [#text("4.")], [#text("Hãng báo đã giao; người mua bấm đã nhận hàng; hệ thống chuyển đơn sang hoàn tất, đánh dấu tin đã bán và đóng phiên trả giá.")],
    )
  ],
  [Luồng thay thế], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("A1.")], [#text("Ở bước 4: Hãng báo lặp cùng một trạng thái của cùng một vận đơn: hệ thống chỉ ghi nhận lần đầu, đơn không đổi trạng thái hai lần.")],
      [#text("A2.")], [#text("Ở bước 4: Người mua bấm đã nhận hàng trước khi hãng báo: đơn hoàn tất ngay.")],
      [#text("A3.")], [#text("Ở bước 4: Đơn đã báo giao mà người mua chưa nhận được hàng: người mua gửi phiếu Báo chưa nhận hàng (UC-MOD-09).")],
      [#text("A4.")], [#text("Ở bước 4: Hãng báo đã giao mà người mua không bấm: 3 ngày sau hệ thống tự hoàn tất đơn.")],
    )
  ],
  [Luồng ngoại lệ], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("E1.")], [#text("Ở bước 1: Hãng chưa lấy hàng sau 3 ngày: đơn bị hủy, vận đơn trên tài khoản hãng bị hủy theo (UC-DEAL-06 A2).")],
      [#text("E2.")], [#text("Ở bước 3: Người mua không ưng hàng: người mua từ chối nhận, không trả đồng nào; hãng hoàn hàng, đơn giao không thành, hãng tính phí hai chiều vào tài khoản người bán.")],
      [#text("E3.")], [#text("Ở bước 4: Đơn không còn ở trạng thái đã gửi.")],
    )
  ],
  [Quy tắc liên quan], [#text("BR-DEAL-02, BR-DEAL-05, BR-DEAL-08, BR-DEAL-09, BR-DEAL-11.")],
) <tab-spec-delivery>

#ucspec("UC-MOD-08", "Hỏi trợ lý AI về một phiếu hỗ trợ, ca báo cáo hoặc tài khoản",
  [Tác nhân chính], [#text("Điều phối viên hoặc Quản trị viên; tác nhân phụ: dịch vụ AI.")],
  [Tiền điều kiện], [#text("Nhân viên đã đăng nhập trang điều hành.")],
  [Hậu điều kiện], [#text("Nhân viên nhận câu trả lời kèm các nguồn trợ lý AI đã đọc. Dữ liệu nghiệp vụ không thay đổi; mỗi lần trợ lý AI đọc dữ liệu cá nhân được ghi lại kèm nhân viên đã hỏi.")],
  [Luồng chính], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("1.")], [#text("Nhân viên mở cuộc trò chuyện với trợ lý AI của một phiếu hỗ trợ, ca báo cáo hoặc tài khoản, hoặc tạo cuộc trò chuyện mới gắn với một bản ghi.")],
      [#text("2.")], [#text("Nhân viên đặt câu hỏi. Mỗi câu hỏi ghi tên người hỏi; cuộc trò chuyện của một bản ghi dùng chung cho mọi nhân viên.")],
      [#text("3.")], [#text("Hệ thống kiểm tra phiên đăng nhập của nhân viên rồi chuyển câu hỏi tới trợ lý AI.")],
      [#text("4.")], [#text("Trợ lý AI đọc dữ liệu bằng các công cụ chỉ đọc; trang điều hành hiển thị lần lượt các nguồn trợ lý AI đã đọc.")],
      [#text("5.")], [#text("Trợ lý AI trả lời bằng văn bản và các khối trình bày: bằng chứng, bảng, đồ thị liên kết giữa các tài khoản.")],
    )
  ],
  [Luồng thay thế], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("A1 -")], [#text("Ở bước 4: Lượt hỏi quá 60 giây: lượt dừng lại; nhân viên hỏi lại hoặc cho chạy nền và được báo khi có kết quả.")],
      [#text("A2 -")], [#text("Ở bước 4: Nhân viên bấm Dừng: lượt bị hủy, phần dữ liệu trợ lý AI đã đọc được giữ lại trong cuộc trò chuyện.")],
    )
  ],
  [Luồng ngoại lệ], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("E1 -")], [#text("Ở bước 3: Đã hết hạn mức chi phí AI trong ngày: trợ lý AI không trả lời; các chức năng khác của trang điều hành vẫn dùng được.")],
    )
  ],
  [Quy tắc liên quan], [#text("BR-MOD-03; NFR-PERF-02, NFR-PRIV-02. Trợ lý AI chỉ có công cụ đọc; mọi thao tác ghi đi qua các chức năng của trang điều hành và được ghi nhật ký.")],
) <tab-spec-agent-ask>

#ucspec("UC-MOD-06", "Xử lý ca báo cáo với đề xuất của trợ lý AI",
  [Tác nhân chính], [#text("Điều phối viên; tác nhân phụ: dịch vụ AI.")],
  [Tiền điều kiện], [#text("Có ít nhất một báo cáo vi phạm đang mở về một tài khoản; điều phối viên đã đăng nhập trang điều hành.")],
  [Hậu điều kiện], [#text("Đề xuất được thực hiện, sửa hoặc bỏ qua. Mọi thay đổi trên tài khoản do điều phối viên thực hiện và được ghi nhật ký kiểm toán.")],
  [Luồng chính], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("1.")], [#text("Khi có báo cáo mới, hệ thống gom các báo cáo về cùng một tài khoản thành một ca và cho trợ lý AI đọc ca ở chế độ chạy nền.")],
      [#text("2.")], [#text("Trợ lý AI đọc tin đăng, các ảnh giống nhau, giá tham khảo, các cuộc trò chuyện bị báo cáo và lịch sử tài khoản bằng công cụ chỉ đọc, rồi ghi lại bằng chứng và một đề xuất xử lý (ẩn tin, tạm khóa tài khoản, nhắn cho người mua).")],
      [#text("3.")], [#text("Điều phối viên mở ca, xem bằng chứng và đề xuất, chọn hoặc bỏ chọn từng thao tác.")],
      [#text("4.")], [#text("Điều phối viên bấm Thực hiện; trang điều hành gọi từng thao tác quản lý, mỗi thao tác ghi một dòng nhật ký (UC-SHR-02).")],
      [#text("5.")], [#text("Khối đề xuất chuyển sang đã thực hiện, ghi người thực hiện và thời điểm, kèm nút Hoàn tác.")],
    )
  ],
  [Luồng thay thế], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("A1 -")], [#text("Ở bước 2: Ca liên quan đến một nhóm tài khoản: trợ lý AI vẽ đồ thị liên kết giữa các tài khoản và đề xuất cho cả nhóm.")],
      [#text("A2 -")], [#text("Ở bước 3: Điều phối viên nhắn để trợ lý AI sửa đề xuất: trợ lý AI trả lời bằng bản đề xuất kế tiếp, bản cũ được thu gọn.")],
      [#text("A3 -")], [#text("Ở bước 3: Điều phối viên chọn Không vi phạm: ca được đóng, không có thao tác nào trên tài khoản.")],
      [#text("A4 -")], [#text("Ở bước 5: Điều phối viên bấm Hoàn tác: hệ thống đảo ngược từng thao tác, bỏ qua thao tác có dữ liệu đã bị thay đổi sau đó; tin nhắn đã gửi cho người mua được giữ nguyên.")],
    )
  ],
  [Luồng ngoại lệ], [
    #grid(
      columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
      [#text("E1 -")], [#text("Ở bước 2: Đã hết hạn mức chi phí AI trong ngày: ca không có đề xuất; điều phối viên xử lý báo cáo theo UC-MOD-02.")],
    )
  ],
  [Quy tắc liên quan], [#text("BR-MOD-01, BR-MOD-03. Trợ lý AI không có quyền ghi; một chỉ dẫn lẫn trong tin nhắn của người dùng chỉ có thể làm sai đề xuất, không thay đổi được dữ liệu.")],
) <tab-spec-agent-case>


=== Danh mục quy tắc nghiệp vụ

Bảng sau tổng hợp các quy tắc nghiệp vụ làm căn cứ kiểm tra điều kiện và xử lý các luồng của hệ thống.

#figure(
  kind: table,
  table(
    columns: (auto, 1fr),
    align: left,
    inset: (x: 6pt, y: 4pt),
    table.header([Mã quy tắc], [Nội dung]),
    [#box("BR-DEAL-01")], [#text("Hệ thống không giữ tiền: không có ví, không đặt cọc, không thu hộ và không hoàn tiền qua hệ thống.")],
    [#box("BR-LST-01")], [#text("Tin đăng gồm tình trạng hàng theo thang Mới / Như mới / Đã dùng, các thông tin do người bán tự điền và ảnh của hàng. Nếu người bán không khai báo vết (trầy xước, móp, nứt...), AI không tự chỉ ra vết nào trên hàng.")],
    [#box("BR-DEAL-02")], [#text("Người mua tự kiểm tra hàng khi đồng kiểm tại cửa rồi quyết định nhận hoặc từ chối; ứng dụng không gợi ý nội dung cần kiểm tra.")],
    [#box("BR-LST-02")], [#text("Chỉ tài khoản đã xác minh số điện thoại và không bị tạm khóa mới được đăng tin; mỗi người dùng có tối đa 20 tin đang bán.")],
    [#box("BR-LST-03")], [#text("Tiêu đề dài 1–70 ký tự; giá là số nguyên đồng, từ 10.000 đến 1.000.000.000; mô tả tối đa 1.500 ký tự; 1–10 ảnh, ảnh đầu tiên là ảnh bìa; tối đa 20 thông số. Vị trí được lưu theo phường/xã (tọa độ trung tâm phường/xã), không lưu GPS của người bán.")],
    [#box("BR-DEAL-03")], [#text("Mọi mức giá trong phiên trả giá là bội số của 1.000 đ. Giá đề nghị của người mua không thấp hơn một nửa giá niêm yết (làm tròn lên đến 1.000 đ) và thấp hơn giá niêm yết hoặc mức phản giá hiện có; mức phản giá cao hơn giá đề nghị và thấp hơn giá niêm yết. Tại mỗi thời điểm chỉ có một mức giá đang mở và mức giá này không hết hạn. Người chấp nhận phải chấp nhận đúng mức giá mà mình đang thấy; nếu giá vừa thay đổi, lượt chấp nhận bị từ chối và ứng dụng thông báo giá đã thay đổi.")],
    [#box("BR-DEAL-04")], [#text("Chốt giá không giữ hàng; nhiều người mua có thể cùng chốt giá trên một tin. Khi người bán gửi hàng cho một người mua, các yêu cầu COD khác trên tin đó tự động hủy với lý do \"đã gửi cho người khác\".")],
    [#box("BR-DEAL-05")], [#text("COD đồng kiểm qua GHTK hoặc GHN, trên tài khoản của người bán, là hình thức giao dịch duy nhất trong ứng dụng. Vận đơn thu hộ tiền hàng và quy định người nhận trả phí vận chuyển; người mua chỉ trả tiền sau khi xem hàng.")],
    [#box("BR-DEAL-06")], [#text("Mỗi người mua có tối đa 3 đơn COD đang mở.")],
    [#box("BR-DEAL-07")], [#text("Người mua hoặc người bán được hủy đơn khi người bán chưa gửi hàng. Đơn tự động hủy nếu người bán không gửi hàng trong 3 ngày; nếu hãng chưa lấy hàng sau 3 ngày kể từ khi người bán gửi, đơn bị hủy và vận đơn trên tài khoản hãng cũng bị hủy theo.")],
    [#box("BR-DEAL-08")], [#text("Khi người mua từ chối nhận hàng tại cửa: người mua không mất tiền; phí vận chuyển hai chiều do hãng tính vào tài khoản người bán; tin đăng được mở bán lại.")],
    [#box("BR-DEAL-09")], [#text("Sau khi người mua đã trả tiền cho shipper, hệ thống không có cơ chế đòi lại tiền. Nội dung này được ghi trong mục Trợ giúp; màn hình nhận hàng không nhắc lại.")],
    [#box("BR-DEAL-11")], [#text("Đơn hoàn tất khi người mua bấm xác nhận đã nhận hàng, hoặc sau 3 ngày kể từ khi hãng báo đã giao. Nếu hãng báo không giao được hoặc hoàn hàng, đơn chuyển sang trạng thái giao không thành.")],
    [#box("BR-DEAL-12")], [#text("Mã vận đơn do người bán nhập thủ công phải thuộc tài khoản GHTK/GHN mà người bán đã liên kết; muốn dùng hãng khác, người bán gửi yêu cầu bổ sung qua phiếu hỗ trợ.")],
    [#box("BR-TRS-04")], [#text("Sau khi đơn hoàn tất, người mua và người bán đánh giá lẫn nhau, mỗi bên một lần (1–5 sao, tối đa 500 ký tự). Đánh giá được ẩn cho đến khi bên kia cũng đánh giá hoặc sau 7 ngày. Người được đánh giá có thể trả lời một lần (tối đa 500 ký tự), sau đó đánh giá bị khóa; trước khi có câu trả lời, người viết được sửa hoặc xóa đánh giá trong 7 ngày.")],
    [#box("BR-TRS-05")], [#text("Uy tín được hiển thị bằng các số liệu quan sát được, không quy thành điểm hay bậc. Hạn mức áp dụng như nhau cho mọi tài khoản và không thể mua bằng gói trả phí. Tỉ lệ trả lời chỉ được tính khi có từ 5 cuộc trò chuyện trong 90 ngày.")],
    [#box("BR-TRS-06")], [#text("Cảnh báo lừa đảo cần có ít nhất một dấu hiệu trong tin nhắn. Số điện thoại, số tài khoản, số thẻ, email và đường dẫn được che trước khi AI đọc. Cảnh báo đã bị người dùng tắt sẽ hiển thị lại khi xuất hiện dấu hiệu mới.")],
    [#box("BR-DSC-01")], [#text("AI tìm kiếm chỉ đọc câu tìm kiếm: không đặt hàng, không trả giá và không nhắn tin thay người dùng. Mọi điều kiện do AI đặt ra đều hiển thị thành điều kiện lọc mà người dùng có thể bỏ.")],
    [#box("BR-MOD-01")], [#text("Nhân viên chỉ xử lý phiếu hỗ trợ, hàng cấm và hàng giả bị báo cáo, lừa đảo có tổ chức và yêu cầu của cơ quan có thẩm quyền; giá và tình trạng hàng là việc giữa hai bên giao dịch.")],
    [#box("BR-ACC-01")], [#text("Chặn có hiệu lực hai chiều: hai bên không thể nhắn tin cho nhau và không thể mở phiên trả giá trên tin của nhau.")],
    [#box("BR-ACC-02")], [#text("Không luồng nào tiết lộ một số điện thoại hoặc email đã có tài khoản hay chưa. Khi người dùng mở nội dung không thuộc quyền xem của mình, hệ thống phản hồi như thể nội dung đó không tồn tại.")],
    [#box("BR-ACC-03")], [#text("Tài khoản phải có số điện thoại mới được đăng tin, mở phiên trả giá hoặc mở cuộc trò chuyện.")],
    [#box("BR-MOD-02")], [#text("Tài khoản đang bị tạm khóa không được đưa giá đề nghị, chấp nhận giá hay yêu cầu COD, nhưng vẫn được rút giá, từ chối và hủy.")],
    [#box("BR-MOD-03")], [#text("Trợ lý AI của trang điều hành chỉ đọc và đề xuất; mọi thay đổi do nhân viên thực hiện và được ghi vào nhật ký kiểm toán. Tin nhắn gửi cho người dùng luôn mang danh nghĩa chung của hệ thống.")],
  ),
  caption: [Danh mục quy tắc nghiệp vụ của hệ thống],
) <tab-business-rules>

== Thiết kế kiến trúc hệ thống
=== Yếu tố dẫn dắt thiết kế

#figure(
  kind: table,
  caption: [Các yếu tố dẫn dắt thiết kế và cách hệ thống đáp ứng],
  table(
    columns: (0.4fr, 1.7fr, 1.1fr, 2.3fr),
    align: (center + horizon, left + horizon, left + horizon, left + horizon),
    table.header([Mã], [Yếu tố], [Nguồn], [Cách thiết kế đáp ứng]),
    [AD-01], [Quy trình nhiều bước liên quan đến hãng vận chuyển không được gián đoạn giữa chừng], [NFR-DUR-01],
    [Mỗi quy trình ghi nhận từng bước đã hoàn thành. Khi máy chủ gặp sự cố, quy trình tiếp tục từ bước đã ghi nhận mà không thực hiện lại các bước trước đó [3]],
    [AD-02], [Việc người dùng bấm lặp, mạng chập chờn hoặc hãng báo trùng không được tạo ra hai đơn hoặc hai vận đơn], [NFR-IDEM-01],
    [Mỗi thao tác quan trọng mang một mã yêu cầu do ứng dụng sinh ra. Khi cùng mã được gửi lại, hệ thống trả về kết quả của lần xử lý đầu tiên [7]],
    [AD-03], [Hạn mức đơn COD và số tin đang bán không bị vượt khi nhiều người cùng thao tác, kể cả hai bên cùng thao tác trên một phiên trả giá], [NFR-CONC-01],
    [Hệ thống chỉ nhận lượt ghi đến trước; lượt đến sau được báo dữ liệu đã thay đổi để người dùng xem lại. Hạn mức được kiểm tra tuần tự theo từng người dùng],
    [AD-04], [Thông điệp giữa các phân hệ, như đơn đã hoàn tất hay tin đã bán, không bị mất], [NFR-MSG-01],
    [Thông điệp được lưu cùng lúc với thay đổi sinh ra nó và được gửi lại cho đến khi nơi nhận xử lý xong [8]],
    [AD-05], [Có thể tách một phân hệ ra máy chủ riêng khi tải tăng mà không phải viết lại nghiệp vụ], [NFR-ARCH-01],
    [Các phân hệ chỉ gọi nhau qua những chức năng đã công bố và chỉ truy cập dữ liệu của chính mình [10]],
    [AD-06], [Tìm kiếm có AI phải trả kết quả nhanh, không chậm hơn tìm kiếm theo từ khóa], [NFR-PERF-01],
    [Mô hình ngôn ngữ diễn giải câu tìm kiếm một lần, tối đa 4 giây; kết quả diễn giải được lưu vào bộ nhớ đệm 7 ngày. Khi quá thời hạn này, hệ thống tìm bằng câu tìm kiếm gốc],
  ),
) <tab-design-drivers>
=== Kiến trúc tổng thể
#figure(
  image("../../../common/assets/chuong3/shopnexus-architecture.png", width: 80%),
  caption: [Sơ đồ kiến trúc hệ thống],
) <architecture>

#figure(
  kind: table,
  caption: [Các phân hệ nghiệp vụ trong kiến trúc đề xuất],
  table(
    columns: (0.9fr, 2.3fr, 1.6fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Phân hệ], [Chức năng], [Dữ liệu quản lý]),
    [Tài khoản],
    [Đăng nhập, quản lý phiên, hồ sơ, địa chỉ, chặn và theo dõi người bán],
    [Tài khoản, định danh, phiên, địa chỉ],

    [Tin đăng],
    [Quản lý tin, bản nháp, danh mục, địa giới, chỉ mục tìm kiếm và lượt xem],
    [Tin, nháp, danh mục, địa giới, chỉ mục],

    [Khám phá],
    [Hiểu truy vấn, phối hợp tìm kiếm lai, lưu tin, theo dõi tìm kiếm và báo giảm giá],
    [Truy vấn đã diễn giải, tin đã lưu, câu theo dõi],

    [Trò chuyện],
    [Quản lý cuộc trò chuyện, gửi nhận tin nhắn và tìm kiếm trong hộp thư],
    [Cuộc trò chuyện, tin nhắn],

    [Giao dịch],
    [Trả giá, quản lý đơn COD và thời hạn xử lý đơn],
    [Phiên trả giá, lượt trả giá, đơn COD],

    [Vận chuyển],
    [Liên kết tài khoản hãng, tra phí, tạo và đọc vận đơn, nhận trạng thái giao hàng],
    [Liên kết tài khoản hãng],

    [Vận hành và hỗ trợ],
    [Quản lý nhân viên, phân quyền, phiếu hỗ trợ và nhật ký kiểm toán],
    [Nhân viên, phiên, phiếu hỗ trợ, nhật ký],

    [Uy tín],
    [Đánh giá hai chiều, tiếp nhận báo cáo vi phạm và cảnh báo lừa đảo],
    [Đánh giá, báo cáo, cảnh báo],

    [Thông báo],
    [Thông báo trong ứng dụng, gửi thông báo đẩy và quản lý tùy chọn nhận],
    [Thông báo, thiết bị, tùy chọn nhận],

    [Media],
    [Tiếp nhận, xử lý và quản lý ảnh, video; lưu tệp trong RustFS],
    [Thông tin tệp đã tải],

    [AI đăng tin],
    [Phân tích video, ảnh để tạo bản nháp và gợi ý giá],
    [Lượt phân tích],

    [Trợ lý AI],
    [Chuyển tiếp yêu cầu tới dịch vụ trợ lý AI nội bộ, điều phối tác vụ nền và cung cấp công cụ chỉ đọc],
    [Không quản lý dữ liệu nghiệp vụ riêng],
  ),
)


=== Phối hợp giữa các phân hệ

Các phân hệ phối hợp thông qua ba cơ chế: gọi đồng bộ, thực thi quy trình nhiều bước và trao đổi sự kiện bất đồng bộ.

+ Gọi đồng bộ: được sử dụng khi cần kết quả để tiếp tục xử lý.
+ Quy trình nhiều bước: được sử dụng cho các thao tác liên quan đến nhiều nhóm dữ liệu, hệ thống bên ngoài hoặc cần thời hạn xử lý. Tiến độ và kết quả từng bước được ghi nhận để tiếp tục thực thi sau sự cố.
+ Sự kiện bất đồng bộ: được sử dụng khi một thay đổi cần được chuyển đến các phân hệ liên quan mà bên phát không phải chờ các bên nhận hoàn tất xử lý.

-*Quy trình nhiều bước:*

Các thao tác cập nhật nhiều nhóm dữ liệu, gọi hệ thống bên ngoài hoặc chờ đến một thời hạn được tổ chức thành quy trình thực thi bền bằng Restate (AD-01). @tab-durable-processes tổng hợp các quy trình chính. Kết quả của từng bước được ghi nhận để quy trình có thể tiếp tục sau sự cố và sử dụng lại kết quả đã có. Cơ chế này kết hợp với xử lý yêu cầu lặp nhằm tránh tạo thêm vận đơn hoặc gửi lại email mã OTP cho cùng một yêu cầu (AD-02).

Lỗi tạm thời được xử lý bằng cơ chế thử lại. Ngược lại, khi điều kiện nghiệp vụ không được đáp ứng, chẳng hạn người mua đã có đủ 3 đơn COD đang mở, quy trình kết thúc và trả về lý do từ chối. Mã OTP không được ghi vào nhật ký thực thi.

#figure(
  kind: table,
  caption: [Các quy trình thực thi bền chính],
  table(
    columns: (1.35fr, 0.85fr, 2.25fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Quy trình], [Phân hệ], [Nội dung xử lý]),
    [Đăng nhập], [Tài khoản], [Tra cứu định danh, tạo tài khoản khi đăng nhập lần đầu; không tạo thêm bản ghi khi định danh đã tồn tại],
    [Gửi mã OTP qua email], [Tài khoản], [Kiểm tra hạn mức và gửi mã OTP gồm sáu chữ số],
    [Đăng và chỉnh sửa tin], [Tin đăng], [Kiểm tra hạn mức tin đăng và liên kết ảnh với tin],
    [Công khai và lập chỉ mục tin], [Tin đăng], [Chuyển tin sang trạng thái đang bán; tạo embedding vector cho văn bản và ảnh],
    [Xử lý và dọn dẹp ảnh], [Media], [Kiểm tra định dạng, tạo ảnh thu nhỏ, loại bỏ siêu dữ liệu; xóa ảnh không được sử dụng sau 24 giờ],
    [Tạo bản nháp bằng AI], [AI đăng tin], [Phân tích video, ảnh hoặc liên kết để đề xuất nội dung bản nháp],
    [Gửi và phân phối tin nhắn], [Trò chuyện], [Ghi nhận tin nhắn và chuyển đến người nhận sau khi ảnh đính kèm được xử lý],
    [Phát hiện dấu hiệu lừa đảo], [Uy tín], [Phân tích 20 tin nhắn gần nhất và ghi nhận cảnh báo khi có dấu hiệu phù hợp],
    [Tiếp nhận yêu cầu COD], [Giao dịch], [Kiểm tra hạn mức, tạo đơn chờ và thiết lập thời hạn 3 ngày để người bán gửi hàng],
    [Tạo đơn gửi hàng], [Giao dịch], [Tạo hoặc tra cứu vận đơn, giữ tin cho đơn và hủy các yêu cầu COD khác trên cùng tin],
    [Theo dõi thời hạn đơn], [Giao dịch], [Hủy khi quá hạn gửi hoặc lấy hàng 3 ngày; tự hoàn tất sau 3 ngày kể từ khi hãng báo đã giao; tra cứu trạng thái mỗi 2 giờ],
    [Tiếp nhận trạng thái vận đơn], [Vận chuyển], [Ghi nhận trạng thái do hãng gửi về và loại bỏ cập nhật trùng lặp],
    [Mở phiếu hỗ trợ], [Vận hành và hỗ trợ], [Tạo phiếu và cuộc trò chuyện hỗ trợ tương ứng],
    [Kiểm tra tìm kiếm được theo dõi], [Khám phá], [Định kỳ 30 phút tìm các tin mới phù hợp với truy vấn đã theo dõi],
    [Chạy nền trợ lý AI], [Trợ lý AI], [Yêu cầu trợ lý AI tra cứu phiếu hỗ trợ, báo cáo mới và soạn đề xuất xử lý],
  ),
) <tab-durable-processes>

#pagebreak()
- *Trao đổi sự kiện giữa các phân hệ:*

Khi đơn COD hoặc tin đăng thay đổi trạng thái, hệ thống ghi dữ liệu nghiệp vụ và sự kiện tương ứng trong cùng một giao dịch thông qua Transactional Outbox (AD-04). Cách tổ chức này tránh trường hợp thay đổi đã được lưu nhưng sự kiện chưa được ghi nhận để chuyển đến các phân hệ liên quan.

Event Bus chuyển các sự kiện trong Outbox đến Restate để phân phối cho từng bên nhận. Khi việc chuyển giao gặp lỗi tạm thời, sự kiện được giữ lại và thử lại với khoảng chờ tăng dần, tối đa một giờ. Việc xử lý của từng bên nhận được thực hiện độc lập để lỗi tại một phân hệ không chặn các phân hệ khác.

#fig(
  [Luồng phối hợp giữa các phân hệ khi đơn COD hoàn tất],
  spacing: (10mm, 14mm),
  np((0, 0), [Người mua\ #text(size: 8.5pt)[xác nhận đã nhận hàng]], shape: rect, name: <f-hang>),
  ncore((1, 0), [Giao dịch\ #text(size: 8.5pt, weight: 400)[đơn chuyển sang hoàn tất]], shape: rect, name: <f-gd>),
  np((0, 1), [Tìm kiếm\ #text(size: 8.5pt)[loại tin khỏi kết quả]], shape: rect, name: <f-tk>),
  np((1, 1), [Tin đăng\ #text(size: 8.5pt)[tin chuyển sang đã bán]], shape: rect, name: <f-tin>),
  np((2, 1), [Trò chuyện\ #text(size: 8.5pt)[cập nhật trạng thái đơn]], shape: rect, name: <f-ct>),
  np((3, 1), [Thông báo\ #text(size: 8.5pt)[thông báo và mời đánh giá]], shape: rect, name: <f-tb>),
  edge(<f-hang>, <f-gd>, "-|>"),
  edge(<f-gd>, <f-tin>, "-|>", label-side: right, rel[đánh dấu đã bán]),
  edge(<f-gd>, <f-ct>, "-|>", stroke: (dash: "dashed")),
  edge(<f-gd>, <f-tb>, "-|>", stroke: (dash: "dashed")),
  edge(<f-tin>, <f-tk>, "-|>", stroke: (dash: "dashed")),
  node((3, 0), align(left, text(size: 8pt)[
    #box(line(length: 9mm, stroke: 1.1pt + muted), baseline: -0.3em) bước trong quy trình\
    #box(line(length: 9mm, stroke: (paint: muted, thickness: 1.1pt, dash: "dashed")), baseline: -0.3em) sự kiện bất đồng bộ
  ]), stroke: none, fill: none),
) <fig-completion-events>

Sự kiện mô tả loại thay đổi và định danh đối tượng liên quan; bên nhận đọc lại trạng thái hiện tại thông qua giao diện của phân hệ nguồn trước khi xử lý. Các thao tác xử lý phải có tính idempotent để sự kiện được chuyển lại không tạo thêm tác động nghiệp vụ. Việc đọc trạng thái hiện tại cũng giúp hạn chế ảnh hưởng của sự kiện đến chậm hoặc không đúng thứ tự.

Các trường hợp phối hợp tiêu biểu gồm:

+ Phân hệ Tin đăng cập nhật chỉ mục khi nội dung hoặc trạng thái tin thay đổi.
+ Phân hệ Giao dịch đóng mức giá đang mở và hủy yêu cầu COD khi tin bị chỉnh sửa, ẩn, đánh dấu đã bán hoặc xóa theo quy tắc nghiệp vụ.
+ Phân hệ Khám phá xác định các thay đổi cần thông báo cho người đã lưu tin, theo dõi tìm kiếm hoặc theo dõi người bán.
+ Phân hệ Thông báo gửi thông tin về thay đổi của phiên trả giá, đơn COD, đánh giá và phiếu hỗ trợ đến người dùng liên quan.
+ Khi tài khoản bị xóa, từng phân hệ xử lý dữ liệu thuộc phạm vi quản lý của mình theo yêu cầu xóa dữ liệu.

Ứng dụng và website nhận cập nhật qua kết nối thời gian thực. Mỗi tài khoản có một luồng sự kiện với số thứ tự tăng dần. Khi kết nối bị gián đoạn, ứng dụng gửi số thứ tự cuối đã nhận để đồng bộ phần còn thiếu. Sự kiện chỉ cung cấp định danh của tin nhắn, phiên trả giá, đơn COD hoặc thông báo vừa thay đổi; ứng dụng tải lại dữ liệu qua API để cập nhật thay đổi. Luồng này phục vụ đồng bộ giao diện, không thay thế việc kiểm tra trạng thái tại máy chủ khi thực hiện thao tác nghiệp vụ.

=== Thiết kế uy tín và cảnh báo lừa đảo

Thiết kế uy tín hỗ trợ người dùng đánh giá đối tác thông qua hai nhóm thông tin: số liệu uy tín công khai và cảnh báo dấu hiệu lừa đảo trong cuộc trò chuyện.

#fig(
  [Nguồn của các số liệu uy tín],
  spacing: (15mm, 8mm),
  np((0, 0), align(left, text(size: 9pt)[
    *Uy tín*\
    Đánh giá khi bán và khi mua:\ #h(1em) Số sao trung bình, số lượt
  ]), shape: rect, name: <r-dg>),
  np((0, 1), align(left, text(size: 9pt)[
    *Giao dịch*\
    Số món đã bán;\
    Số đơn COD và số đơn\ #h(1em) giao không thành trong 90 ngày
  ]), shape: rect, name: <r-gd>),
  np((0, 2), align(left, text(size: 9pt)[
    *Trò chuyện*\
    tỉ lệ trả lời trong 24 giờ,\ #h(1em) từ 5 cuộc trò chuyện trong 90 ngày
  ]), shape: rect, name: <r-ct>),
  np((0, 3), align(left, text(size: 9pt)[
    *Tài khoản*\
    Ngày tham gia, số người theo dõi
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
  edge(<r-hm>, <r-man>, "-|>", stroke: (dash: "dashed"), label-side: right, rel[hạn mức áp dụng]),
) <fig-reputation-sources>

Cơ chế đánh giá hai chiều được sử dụng để hạn chế đánh giá trả đũa (BR-TRS-04). Sau khi đơn COD hoàn tất, mỗi bên được đánh giá đối tác một lần. Đánh giá được ẩn với đối tác và người dùng khác cho đến khi cả hai bên đã đánh giá hoặc hết thời hạn 7 ngày theo quy tắc nghiệp vụ. Người được đánh giá có thể phản hồi một lần; sau khi có phản hồi, đánh giá không được chỉnh sửa hoặc xóa. Hồ sơ hiển thị riêng điểm đánh giá khi mua và khi bán để phản ánh đúng vai trò của người dùng trong giao dịch.

Chức năng phát hiện dấu hiệu lừa đảo được kích hoạt sau mỗi tin nhắn văn bản của một trong hai bên (BR-TRS-06). Trước khi phân tích, hệ thống thay số điện thoại, số tài khoản, số thẻ, email và đường dẫn bằng ký hiệu giữ chỗ nhằm hạn chế cung cấp thông tin nhạy cảm cho mô hình. Bộ phát hiện chỉ được trả về các mã thuộc danh sách định sẵn, gồm bảy dấu hiệu trong nội dung tin nhắn và hai dữ kiện bổ sung về tài khoản, giá niêm yết. Cảnh báo chỉ được hiển thị khi có ít nhất một dấu hiệu trong tin nhắn; các dữ kiện bổ sung đóng vai trò ngữ cảnh hỗ trợ.

Bộ phát hiện được đặt sau một giao diện độc lập với phần xử lý nghiệp vụ. Thiết kế này cho phép sử dụng mô hình ngôn ngữ lớn ở giai đoạn hiện tại và thay thế bằng mô hình được huấn luyện từ dữ liệu đã lưu trong tương lai mà không phải thay đổi cấu trúc dữ liệu, hợp đồng API hoặc ứng dụng. Kết quả phát hiện là thông tin cảnh báo để người dùng cân nhắc, không phải kết luận vi phạm.


== Thiết kế dữ liệu

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

Các luồng xử lý chính được mô tả bằng sơ đồ hoạt động cho quy trình giao dịch COD đồng kiểm, sơ đồ trạng thái cho vòng đời đơn COD và tin đăng, và sơ đồ trình tự cho hai ca sử dụng UC-DEAL-04 và UC-DSC-01.

#let process-elabel(body) = box(fill: white, inset: (x: 2pt, y: 1pt), text(size: 8pt, body))
#let process-lane-v = (paint: luma(60%), thickness: 0.6pt, dash: "dashed")
#let process-lane-h = (paint: luma(75%), thickness: 0.5pt)
#let flow-message(body) = box(
  fill: white, inset: (x: 3.5pt, y: 2pt),
  text(size: 8.5pt, body),
)

=== Quy trình giao dịch COD đồng kiểm

#fig(
  [Sơ đồ hoạt động quy trình giao dịch COD đồng kiểm],
  spacing: (10mm, 3.2mm), node-inset: 4pt,

  edge((0.5, -0.5), (0.5, 17.5), stroke: process-lane-v),
  edge((1.5, -0.5), (1.5, 17.5), stroke: process-lane-v),
  edge((2.5, -0.5), (2.5, 17.5), stroke: process-lane-v),
  edge((-0.55, 0.5), (3.55, 0.5), stroke: process-lane-h),

  ncore((0, 0), [NGƯỜI MUA]),
  ncore((1, 0), [NGƯỜI BÁN]),
  ncore((2, 0), [HỆ THỐNG]),
  ncore((3, 0), [HÃNG VẬN CHUYỂN]),

  ..{
    let w = 40mm
    let s(b) = text(size: 9.5pt, b)
    let quyet(p, b) = nd(p, text(size: 9pt, b), inset: 6.5pt)
    (
      nt((0, 1), s[Hai bên đã chốt giá]),
      np((0, 2), s[Chọn giao COD,\ chọn địa chỉ nhận], width: w),
      quyet((2, 3), [Đủ 3 đơn\ COD mở?]),
      nr((0, 3), s[Nhận báo vượt hạn mức], width: w),
      nt((0, 5), s[Kết thúc]),
      np((2, 5), s[Lưu đơn chờ tạo đơn,\ báo người bán], width: w),
      quyet((1, 6), [Tạo qua hãng\ hay nhập mã?]),
      np((2, 6), s[Tạo vận đơn trên tài\ khoản hãng của người bán], width: w),
      np((3, 6), s[Tạo vận đơn,\ báo phí thật], width: w),
      np((1, 8), s[Nhập mã vận đơn\ đã tạo trên ứng dụng hãng], width: w),
      ng((2, 8), s[Đơn đã gửi, tin đang\ giữ chỗ, hủy các\ yêu cầu COD khác], width: w),
      quyet((2, 10), [Hãng lấy hàng\ trong 3 ngày?]),
      np((3, 10), s[Lấy hàng,\ vận chuyển], width: w),
      ng((2, 12), s[Đơn đã hủy, hủy vận\ đơn, tin về đang bán], width: w),
      nt((1, 12), s[Kết thúc]),
      np((3, 13), s[Giao tới cửa,\ người mua mở xem], width: w),
      quyet((0, 14), [Nhận hay\ từ chối?]),
      np((3, 14), s[Hoàn hàng về người bán,\ tính phí hai chiều], width: w),
      nr((0, 16), s[Trả tiền hàng và phí\ vận chuyển cho shipper], width: w),
      ng((2, 16), s[Đơn giao không thành,\ tin về đang bán], width: w),
      nt((1, 16), s[Kết thúc]),
      ng((2, 17), s[Người mua bấm đã nhận\ hoặc sau 3 ngày: đơn\ hoàn tất, tin đã bán], width: w),
      nt((3, 17), s[Kết thúc]),
    )
  },

  edge((0, 1), (0, 2), "-|>"),
  edge((0, 2), (2, 2), (2, 3), "-|>", corner-radius: 4pt),
  edge((2, 3), (0, 3), "-|>", label-side: right, label-pos: 0.3, process-elabel[Có]),
  edge((0, 3), (0, 5), "-|>"),
  edge((2, 3), (2, 5), "-|>", label-side: left, label-sep: 5pt, process-elabel[Không]),
  edge((2, 5), (1, 6), "-|>"),
  edge((1, 6), (2, 6), "-|>"),
  edge((2, 6), (3, 6), "<|-|>"),
  edge((1, 6), (1, 8), "-|>", label-side: right, label-sep: 5pt, process-elabel[Nhập mã]),
  edge((2, 6), (2, 8), "-|>"),
  edge((1, 8), (2, 8), "-|>"),
  edge((2, 8), (2, 10), "-|>"),
  edge((2, 10), (2, 12), "-|>", label-side: right, label-sep: 5pt, process-elabel[Không]),
  edge((2, 12), (1, 12), "-|>"),
  edge((2, 10), (3, 10), "-|>", label-side: left, label-pos: 0.4, process-elabel[Có]),
  edge((3, 10), (3, 13), "-|>"),
  edge((3, 13), (0, 13), (0, 14), "-|>", corner-radius: 4pt),
  edge((0, 14), (0, 16), "-|>", label-side: right, label-sep: 5pt, process-elabel[Nhận]),
  edge((0, 14), (3, 14), "-|>", label-side: left, label-pos: 0.3, process-elabel[Từ chối]),
  edge((3, 14), (3, 16), (2, 16), "-|>", corner-radius: 4pt, label-pos: 0.75, label-side: right,
    process-elabel[hãng báo hoàn]),
  edge((2, 16), (1, 16), "-|>"),
  edge((0, 16), (0, 17), (2, 17), "-|>", corner-radius: 4pt, label-pos: 0.6, label-side: left,
    process-elabel[hãng báo đã giao]),
  edge((2, 17), (3, 17), "-|>"),
) <fig-process-cod>

@fig-process-cod mô tả quy trình giao dịch từ khi chốt giá đến khi đơn kết thúc, gồm bốn bên tham gia: Người mua, Người bán, Hệ thống và Hãng vận chuyển. Quy trình có bốn điểm chính:

+ Hệ thống kiểm tra số đơn COD đang mở của người mua và từ chối yêu cầu mới khi đã đủ 3 đơn (BR-DEAL-06). Hai yêu cầu gửi đồng thời cũng không thể vượt hạn mức này.
+ Người bán tạo vận đơn qua hãng đã liên kết, hoặc nhập mã vận đơn đã tạo trên ứng dụng của hãng. Hệ thống đọc mã này bằng tài khoản hãng của người bán (BR-DEAL-12).
+ Hãng phải lấy hàng trong 3 ngày, nếu không đơn sẽ bị hủy (BR-DEAL-07).
+ Tại cửa, người mua xem hàng rồi nhận hoặc từ chối.

Tiền hàng được trả trực tiếp cho shipper; hệ thống chỉ biết kết quả thông qua báo cáo trạng thái của hãng vận chuyển.

=== Trạng thái của đơn COD và tin đăng

#fig(
  [Sơ đồ trạng thái của đơn COD],
  spacing: (30mm, 9mm),

  node((0, 0), [], shape: circle, radius: 5pt, fill: ink, stroke: none),
  np((1, 0), [Chờ tạo đơn]),
  np((2, 0), [Đã gửi]),
  ng((1.3, 2.3), [Hoàn tất]),
  ng((2.7, 2.3), [Giao không thành]),
  ng((1.5, -1.7), [Đã hủy\ #text(size: 8pt)[lý do: một bên hủy, người bán quá hạn,\ hãng quá hạn lấy hàng, đã gửi cho người khác]]),

  edge((0, 0), (1, 0), "-|>", label-side: right, process-elabel[người mua gửi\ yêu cầu COD]),
  edge((1, 0), (2, 0), "-|>", label-side: left, process-elabel[người bán tạo vận đơn\ hoặc nhập mã]),
  edge((2, 0), (1.3, 2.3), "-|>", label-side: right, label-pos: 0.62, process-elabel[người mua bấm đã nhận /\ 3 ngày sau khi hãng báo giao]),
  edge((2, 0), (2.7, 2.3), "-|>", label-side: left, process-elabel[từ chối nhận /\ không giao được]),
  edge((1, 0), (1.5, -1.7), "-|>", label-side: left, label-pos: 0.4, process-elabel[một bên hủy,\ người bán quá 3 ngày]),
  edge((2, 0), (1.5, -1.7), "-|>", label-side: right, label-pos: 0.3, process-elabel[hãng chưa lấy\ hàng sau 3 ngày]),
) <fig-state-cod>

@fig-state-cod là sơ đồ trạng thái của đơn COD, mỗi cạnh ghi sự kiện làm đơn đổi trạng thái. Đơn có mã dạng SN-100001, bắt đầu ở trạng thái chờ tạo đơn khi người mua gửi yêu cầu kèm một địa chỉ trong sổ địa chỉ của mình. Ba trạng thái nền xám là trạng thái cuối; từ trạng thái đã gửi trở đi, người dùng không thể tự hủy đơn.

Khi đơn đổi trạng thái, tin đăng và phiên trả giá liên quan đổi theo. Khi đơn đã gửi, tin chuyển sang đang giữ chỗ và các yêu cầu COD khác trên tin bị hủy. Khi đơn hoàn tất, tin và phiên trả giá chuyển sang đã bán. Khi đơn giao không thành hoặc đã hủy, tin về đang bán và phiên trả giá về đang trả giá. Hệ thống ghi thay đổi của đơn cùng lúc với thông báo cho các phân hệ liên quan, nên tin đăng và thông báo luôn được cập nhật khi đơn đổi trạng thái.

Tin đăng có vòng đời riêng: từ đang xử lý sang đang bán hoặc bị từ chối tùy kết quả xử lý ảnh; đang bán và đang ẩn chuyển qua lại, và đều có thể sang đã bán khi người bán đánh dấu; đang bán sang đang giữ chỗ khi người bán gửi hàng, rồi sang đã bán hoặc về đang bán theo kết quả đơn. Mọi trạng thái đều có thể sang đã xóa, trừ đang giữ chỗ (tin đang giữ chỗ không thể sửa, ẩn hay xóa).

=== Trình tự tạo đơn gửi hàng

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
  msg(0, 1, 1.5, flow-message[1\. Tạo đơn gửi hàng]),
  durable(1, 2.4, text(size: 8.5pt)[2\. Kiểm đơn\ chờ tạo đơn]),
  ..khung("alt", 0.55, 3.45, 3.7, 12.0),
  dkien(1.25, 3.7, text(size: 8pt)[tạo qua hãng]),
  msg(1, 2, 5.0, flow-message[3a. Tạo vận đơn]),
  msg(2, 3, 6.2, flow-message[4a. Tạo vận đơn, thu hộ,\ người nhận trả phí]),
  rmsg(3, 2, 7.5, flow-message[5a. Mã vận đơn, phí thật]),
  rmsg(2, 1, 8.6, flow-message[6a. Vận đơn và phí]),
  ngan(0.55, 3.45, 9.1),
  dkien(1.1, 9.45, text(size: 8pt)[nhập mã]),
  msg(1, 2, 10.6, flow-message[3b. Đọc mã bằng\ tài khoản người bán]),
  rmsg(2, 1, 11.6, flow-message[4b. Vận đơn, phí]),
  msg(1, 4, 12.9, flow-message[7\. Giữ tin cho người mua này]),
  rmsg(4, 1, 14.0, flow-message[8\. Tin đang giữ chỗ]),
  durable(1, 15.2, text(size: 8.5pt)[9\. Đơn đã gửi; hủy yêu cầu\ COD khác; hẹn 3 ngày]),
  msg(1, 5, 16.6, flow-message[10\. Báo người mua và người bị hủy]),
  rmsg(1, 0, 18.0, flow-message[11\. Đơn đã gửi]),
  nr((4.5, 8.2), text(size: 8pt)[Sự cố giữa chừng:\ quy trình chạy tiếp\ từ bước đã xong,\ không tạo vận đơn\ lần hai], shape: rect),
) <fig-sequence-shipping>

@fig-sequence-shipping mô tả trình tự thực hiện ca sử dụng UC-DEAL-04. Khi người bán tạo đơn vận chuyển, phân hệ giao dịch kiểm tra đơn đang ở trạng thái chờ tạo đơn. Với phương thức tạo vận đơn qua hãng vận chuyển, phân hệ vận chuyển sử dụng tài khoản hãng của người bán để tạo vận đơn, thiết lập thu hộ tiền hàng và người nhận thanh toán phí vận chuyển, sau đó tiếp nhận mã vận đơn và phí vận chuyển thực tế. Với phương thức nhập mã vận đơn có sẵn, hệ thống truy xuất vận đơn bằng tài khoản hãng của người bán và từ chối mã không thuộc tài khoản này theo BR-DEAL-12.

Sau khi xác nhận vận đơn hợp lệ, phân hệ tin đăng giữ tin cho người mua tương ứng, đồng thời đơn giao dịch chuyển sang trạng thái “Đã gửi”. Các yêu cầu COD khác trên cùng tin đăng được tự động hủy với lý do “Đã gửi cho người khác” theo BR-DEAL-04. Hệ thống gửi thông báo cho người mua và những người có yêu cầu bị hủy, thiết lập thời hạn lấy hàng là 3 ngày và truy vấn hãng vận chuyển định kỳ 2 giờ một lần để cập nhật trạng thái.

Quy trình bảo đảm khả năng tiếp tục từ bước đã hoàn tất khi máy chủ gặp sự cố, tránh tạo vận đơn trùng lặp theo NFR-DUR-01. Các thao tác tạo đơn lặp lại của người bán chỉ trả về đơn đã tạo, bảo đảm tính lũy đẳng theo NFR-IDEM-01.

=== Trình tự tìm kiếm bằng câu tự nhiên

#fig(
  [Sơ đồ trình tự UC-DSC-01: tìm kiếm bằng câu tự nhiên],
  spacing: (12mm, 5.6mm),
  np((0, 0), [:Người mua], shape: rect),
  ncore((1, 0), [Khám phá], shape: rect),
  np((2, 0), [Cách đọc đã lưu], shape: rect),
  np((3, 0), [Mô hình ngôn ngữ], shape: rect),
  np((4, 0), [Tin đăng], shape: rect),
  ..lifelines(5, y1: 18.6),
  msg(0, 1, 1.2, flow-message[1\. Câu nhu cầu, bộ lọc]),
  msg(1, 2, 2.5, flow-message[2\. Tìm cách đọc của câu]),
  rmsg(2, 1, 3.7, flow-message[3\. Chưa có]),
  ..khung("alt", 0.75, 3.45, 4.6, 12.6),
  dkien(1.35, 4.6, text(size: 8pt)[trong 4 s]),
  msg(1, 3, 6.0, flow-message[4\. Câu, lược đồ điều kiện]),
  rmsg(3, 1, 7.4, flow-message[5\. Điều kiện ưu tiên, câu viết lại]),
  step(1, 8.6, text(size: 8.5pt)[6\. Kiểm với danh mục,\ địa giới thật]),
  msg(1, 2, 10.0, flow-message[7\. Lưu 7 ngày]),
  ngan(0.75, 3.45, 10.8),
  dkien(1.35, 11.1, text(size: 8pt)[quá 4 s hoặc lỗi]),
  step(1, 12.0, text(size: 8.5pt)[6'. Chỉ câu gốc]),
  msg(1, 4, 13.6, flow-message[8\. Tìm từ khóa, theo nghĩa,\ theo ảnh; hợp nhất]),
  rmsg(4, 1, 15.2, flow-message[9\. Tin đã xếp hạng]),
  rmsg(1, 0, 17.4, flow-message[10\. Tin, chip, câu diễn giải]),
) <fig-sequence-search>

@fig-sequence-search mô tả trình tự thực hiện ca sử dụng UC-DSC-01. Phân hệ khám phá kiểm tra kết quả diễn giải đã lưu của câu tìm kiếm. Nếu chưa có, hệ thống gửi câu tìm kiếm đến mô hình ngôn ngữ một lần, kèm theo lược đồ đầu ra cố định. Các điều kiện ưu tiên do mô hình trả về được đối chiếu với danh mục và dữ liệu địa giới thực tế trước khi lưu kết quả diễn giải trong 7 ngày.

Khung alt thể hiện cơ chế xử lý khi mô hình gặp lỗi hoặc thời gian phản hồi vượt quá 4 giây. Trong trường hợp này, hệ thống chỉ sử dụng câu tìm kiếm gốc và không hiển thị các chip điều kiện. Sau đó, phân hệ tin đăng thực hiện ba phương thức tìm kiếm trong cùng một câu truy vấn và hợp nhất thứ hạng kết quả theo [5].
