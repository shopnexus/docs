#import "../common/style-a4.typ": *
#show: a4.with(
  tieu-de: "BÁO CÁO TIẾN ĐỘ HÀNG TUẦN",
  phu-de: "TUẦN 1 & TUẦN 2",
  chay: "Báo cáo tiến độ Tuần 1 & 2",
)

= BÁO CÁO TIẾN ĐỘ TUẦN 1: THIẾT LẬP VÀ HIỂU BIẾT DỰ ÁN

== Tầm Nhìn Dự Án (DOC 1.1-A)

=== Phát biểu vấn đề
Thị trường giao dịch trực tuyến giữa các cá nhân (C2C) tại Việt Nam như mua bán đồ cũ, thanh lý, hàng handmade đang phát triển mạnh mẽ. Tuy nhiên, rào cản lớn nhất ngăn cản sự bùng nổ của mô hình này chính là *thiếu lòng tin*. Người mua lo ngại rủi ro thanh toán trước nhưng không nhận được hàng, nhận hàng không đúng mô tả hoặc hàng giả/hỏng nhưng người bán cá nhân từ chối hoàn tiền. Ngược lại, người bán cá nhân e ngại bị người mua lừa đảo hoặc "boom hàng" (giao hàng COD thất bại gây tốn phí). Bên cạnh đó, việc trao đổi qua lại giữa hai bên thường phân mảnh trên nhiều ứng dụng chat ngoài, dẫn đến khó kiểm soát và không có bằng chứng pháp lý rõ ràng khi phát sinh mâu thuẫn. ShopNexus ra đời nhằm giải quyết vấn đề này bằng cách tích hợp trực tiếp nhắn tin (Chat) trao đổi, cơ chế thanh toán tạm giữ (Escrow) an toàn, cùng quy trình xử lý tranh chấp (Dispute) công bằng. Hệ thống được thiết kế với phân quyền chặt chẽ: tài khoản Người dùng (User) tự do đăng ký để thực hiện cả mua và bán; tài khoản Điều phối viên (Moderator) do Quản trị viên (Admin) cấp phát trực tiếp nhằm xử lý tranh chấp và chăm sóc khách hàng; và duy nhất một tài khoản Quản trị viên tối cao (Admin) được cấu hình sẵn để quản trị toàn sàn.

=== Mục tiêu dự án
- Xây dựng nền tảng thương mại điện tử chuyên biệt cho mô hình giao dịch C2C an toàn.
- Thiết lập cơ chế thanh toán tạm giữ (Escrow) nhằm đóng băng dòng tiền trong ví trung gian trong vòng 3 ngày sau khi giao hàng thành công để bảo vệ người mua.
- Tích hợp hệ thống Nhắn tin trực tuyến (Chat) thời gian thực hỗ trợ đàm phán giá cả (Offer) và gửi hình ảnh, video thực tế sản phẩm giữa các User.
- Xây dựng quy trình Trả hàng/Hoàn tiền (Refund) và Giải quyết Tranh chấp (Dispute) minh bạch dưới sự điều phối trực tiếp của các Moderator dựa trên chứng cứ số (video/hình ảnh lúc mở hộp và đóng gói).
- Cấu hình phân quyền hệ thống rõ ràng: User tự tạo tài khoản; Moderator nhận tài khoản cấp phát; Admin quản lý tối cao.

=== Phạm vi hệ thống

*Trong phạm vi (In-Scope):*
- *Quản lý tài khoản và ví:* Đăng ký, đăng nhập và phân quyền 3 vai trò chính bao gồm:
  1. *User (Người dùng):* Khách hàng tự do đăng ký trực tuyến, tích hợp cả hai chức năng mua và bán. Mỗi User sở hữu một ví điện tử riêng.
  2. *Moderator (Điều phối viên):* Tài khoản do Admin cấp phát (không tự đăng ký), có nhiệm vụ duyệt đơn khiếu nại, xử lý tranh chấp và hỗ trợ CSKH.
  3. *Admin (Quản trị viên tối cao):* Tài khoản duy nhất được cấu hình sẵn (không tự đăng ký), quản lý hệ thống, đối soát dòng tiền và cấp phát tài khoản Moderator.
- *Quản lý sản phẩm C2C:* User đăng tải sản phẩm cá nhân bán lên sàn (hình ảnh, giá, mô tả, tình trạng, danh mục). Cho phép lựa chọn 2 chế độ đặt giá: *Giá cố định (X\$)* hoặc *Giá thương lượng (~X\$)*.
- *Nhắn tin trực tuyến (Chat):* Hỗ trợ User trò chuyện thời gian thực, gửi hình ảnh/video thực tế. Đối với sản phẩm *Giá thương lượng*, hệ thống cung cấp quy trình yêu cầu đề xuất giá, người bán tạo và gửi *Offer Card (Thẻ Đề xuất giá)* kèm lý do giảm giá cụ thể (ví dụ: nhà xa bớt 50k, lỗi nhẹ bớt 100k), người mua chấp nhận thẻ này để tiến hành thanh toán.
- *Đặt hàng & Thanh toán:* Phân tách 2 luồng: đối với sản phẩm *Giá cố định*, bấm "Mua ngay" sẽ chuyển hướng thẳng ra trang thanh toán; đối với sản phẩm *Giá thương lượng*, nút "Mua ngay" sẽ dẫn vào khung Chat để thực hiện quy trình thương lượng qua Offer Card. Tích hợp API đơn vị vận chuyển (GHN/GHTK) để tính phí vận chuyển động và theo dõi hành trình đơn hàng.
- *Thanh toán tạm giữ (Escrow):* Thanh toán qua cổng VNPay/SePay, tiền sẽ được khóa tạm thời trong ví Escrow của hệ thống trước khi giải ngân cho User bán.
- *Trả hàng & Hoàn tiền (Refund):* User mua gửi yêu cầu trả hàng, hoàn tiền trong vòng 3 ngày kể từ khi giao hàng thành công kèm video/hình ảnh mở hộp.
- *Khiếu nại & Tranh chấp (Dispute):* User bán phản đối yêu cầu hoàn tiền, hệ thống khóa dòng tiền và chuyển giao Moderator tiếp nhận xử lý.
- *Đánh giá uy tín:* Đánh giá sao và phản hồi chất lượng sản phẩm & độ uy tín người bán sau khi đơn hoàn thành.

*Ngoài phạm vi (Out-of-Scope):*
- Gian hàng B2C chính hãng của các thương hiệu lớn (Shop Mall).
- Vận chuyển quốc tế và thanh toán bằng ngoại tệ.
- Các cuộc gọi trực tiếp (voice/video call) giữa các bên trong ứng dụng.
- Đăng ký tài khoản tự do đối với vai trò Moderator và Admin.

=== Tiêu chí thành công

*Về mặt chức năng:*
- Hoàn thiện đầy đủ các luồng nghiệp vụ cốt lõi: đăng ký/đăng nhập phân quyền, đăng bán sản phẩm,
  nhắn tin thương lượng giá (Offer Card), đặt hàng và thanh toán (Escrow), trả hàng/hoàn tiền, 
  khiếu nại và phân xử tranh chấp.
- Hệ thống áp dụng đúng và đầy đủ các quy tắc nghiệp vụ (Business Rules) đã đặc tả, đặc biệt là 
  cơ chế khóa/giải ngân dòng tiền Escrow theo đúng điều kiện thời gian và trạng thái đơn hàng.
- Demo thành công toàn bộ kịch bản (use case) chính từ góc nhìn của cả 3 vai trò: User, 
  Moderator, Admin.

*Về mặt phi chức năng:*
- Hệ thống được xây dựng theo kiến trúc microservices, đảm bảo khả năng mở rộng và tách rời 
  giữa các module (account, catalog, order, chat...).
- Thời gian phản hồi trung bình của các API nghiệp vụ chính (đặt hàng, thanh toán, chat) 
  đạt dưới 200 ms trong môi trường kiểm thử.
- Dữ liệu giao dịch và dòng tiền được ghi nhận đầy đủ, có thể truy vết (audit trail) thông qua 
  thực thể Transaction/WalletTransaction.

*Về mặt sản phẩm bàn giao:*
- Hoàn thành tài liệu đặc tả yêu cầu, thiết kế use case, mô hình dữ liệu và quy trình nghiệp vụ.
- Mã nguồn được tổ chức rõ ràng theo module, có kiểm thử (unit test/integration test) cho các 
  luồng nghiệp vụ trọng yếu (Escrow, Refund, Dispute).

== Người Dùng và Bên Liên Quan (DOC 1.2-A & DOC 1.2-B)

=== Danh sách Persona (Người dùng chính)

*Persona 1: Người dùng mua và bán (User)*
- *Mục tiêu:* Có thể vừa tìm mua đồ cũ chất lượng giá tốt vừa đăng thanh lý nhanh chóng các món đồ cá nhân không dùng đến; giao dịch an toàn và có thể thương lượng giá dễ dàng với người bán qua chat; được hoàn tiền nếu sản phẩm bị hỏng/lỗi.
- *Điểm khó khăn:* E ngại hàng nhận được khác hoàn toàn so với ảnh quảng cáo của người bán; rất sợ chuyển tiền trước nhưng bị người bán bùng hàng; sợ người mua tráo đổi hàng lỗi khác rồi khiếu nại vô lý.
- *Trình độ kỹ thuật:* Khá (Intermediate).
- *Cách tham gia hệ thống:* Tự đăng ký tài khoản trực tuyến công khai.

*Persona 2: Điều phối viên (Moderator)*
- *Mục tiêu:* Vận hành, tiếp nhận nhanh chóng các đơn khiếu nại trả hàng/hoàn tiền bị từ chối; xem xét chứng cứ trực quan để giải quyết tranh chấp công bằng giữa các User; hỗ trợ CSKH kịp thời.
- *Điểm khó khăn:* Các bên tranh chấp không cung cấp đủ video mở hộp/đóng gói hàng rõ nét; gặp khó khăn khi số lượng tranh chấp tăng cao đột biến.
- *Trình độ kỹ thuật:* Khá (Intermediate).
- *Cách tham gia hệ thống:* Được Quản trị viên tối cao (Super Admin) cấp phát tài khoản trực tiếp, không tự đăng ký.

*Persona 3: Quản trị viên tối cao (Super Admin)*
- *Mục tiêu:* Theo dõi và đối soát luồng tiền thanh toán tạm giữ tổng thể; quản trị nhân sự Moderator (cấp phát, khóa tài khoản); cấu hình các quy định hệ thống của sàn.
- *Điểm khó khăn:* Phải đảm bảo tính bảo mật tuyệt đối của dòng tiền tạm giữ; kiểm soát hoạt động của các Moderator để tránh hành vi thiên vị hoặc lạm quyền.
- *Trình độ kỹ thuật:* Cao (Advanced).
- *Cách tham gia hệ thống:* Cấu hình sẵn từ đầu, là duy nhất.

=== Sổ Đăng Ký Bên Liên Quan
#table(
  columns: (1.2fr, 1.2fr, 1.8fr, 0.8fr),
  align: (center, center, left, center),
  [Tên/Nhóm], [Vai Trò], [Lợi Ích Trong Dự Án], [Quyền Quyết Định],
  [Ban Giám Đốc], [Người tài trợ], [Đảm bảo tính bảo mật dòng tiền, doanh thu từ phí sàn và sự phát triển C2C], [Có],
  [Đội phát triển], [Thực thi], [Nắm rõ các yêu cầu kỹ thuật để thiết kế, lập trình các tính năng], [Không],
  [Đối tác Vận chuyển], [Bên thứ 3], [Tăng sản lượng đơn hàng thông qua kết nối API tự động và cập nhật trạng thái đơn], [Không],
  [Cổng Thanh toán], [Bên thứ 3], [Xử lý các giao dịch chuyển khoản vào tài khoản tạm giữ an toàn], [Không],
  [Ban Pháp chế & Kiểm toán], [Kiểm soát viên], [Đảm bảo tính pháp lý của cơ chế thanh toán tạm giữ (Escrow) theo quy định], [Có],
)

== Bối Cảnh Hệ Thống (DOC 1.3-A)

ShopNexus đóng vai trò là trung tâm trung gian kết nối mọi giao dịch C2C trực tiếp giữa các User, 
được hỗ trợ bởi đội ngũ Moderator đảm nhiệm hai nhiệm vụ chính — phân xử tranh chấp và chăm sóc 
khách hàng (CSKH) — dưới sự quản lý của Admin tối cao.

#fig(
  [Sơ đồ ngữ cảnh hệ thống ShopNexus C2C (Context Diagram)],
  spacing: (100mm, 15mm),
  ncore((1, 1), [ShopNexus\ C2C Core]),
  np((0, 0), [Người dùng\ (User)]),
  np((0, 1), [Điều phối viên\ (Moderator)]),
  np((0, 2), [Quản trị viên\ (Admin)]),
  ng((2, 0.5), [Cổng thanh toán\ VNPay / SePay]),
  ng((2, 1.5), [Đối tác vận chuyển\ GHN / GHTK]),
  edge((0, 0), (1, 1), "<->", text(size: 8pt)[Đăng ký · Đặt mua · Đăng bán · Chat · Hoàn tiền · Tranh chấp],
  label-angle: auto, label-pos: 50%),
edge((0, 1), (1, 1), "<->", text(size: 8pt)[Xử lý khiếu nại · Phân xử · CSKH],
  label-angle: auto, label-pos: 50%),
edge((0, 2), (1, 1), "-|>", text(size: 8pt)[Cấp tài khoản Moderator · Đối soát],
  label-angle: auto, label-pos: 50%),
edge((1, 1), (2, 0.5), "<->", text(size: 8pt)[Thanh toán · Hoàn tiền],
  label-angle: auto, label-pos: 50%),
edge((1, 1), (2, 1.5), "<->", text(size: 8pt)[Vận đơn · Hành trình],
  label-angle: auto, label-pos: 50%),
)

*Mô tả các thực thể bên ngoài:*
- *User:* Khách hàng đăng ký tài khoản trực tuyến để thực hiện cả việc mua và bán. Thực hiện chat thương lượng giá, đặt hàng, thanh toán trực tuyến tạm giữ, gửi yêu cầu trả hàng/hoàn tiền, tranh chấp và viết đánh giá.
- *Moderator:* Điều phối viên đăng nhập bằng tài khoản được cấp phát. Tiếp nhận yêu cầu tranh chấp từ User, đánh giá chứng cứ và ra quyết định xử lý dòng tiền đóng băng; hỗ trợ chăm sóc khách hàng.
- *Admin:* Super Admin duy nhất của hệ thống, quản lý tài khoản Moderator và đối soát dòng tiền Escrow tổng thể.
- *Cổng thanh toán (VNPay/SePay):* Tiếp nhận yêu cầu giao dịch thanh toán trực tuyến và chuyển tiền vào tài khoản Escrow của sàn; thực hiện lệnh hoàn tiền khi có yêu cầu từ hệ thống.
- *Hệ thống Vận chuyển (GHN/GHTK):* Tính toán phí giao nhận động thời gian thực; tiếp nhận vận đơn; cập nhật hành trình đơn hàng để làm cơ sở tính thời hạn escrow.

#pagebreak()

// ============================================================
= BÁO CÁO TIẾN ĐỘ TUẦN 2: THU THẬP YÊU CẦU & THIẾT KẾ CHI TIẾT

== Mô Hình Hóa Trường Hợp Sử Dụng (DOC 2.1-B)

=== Sơ đồ Use Case tổng quan

#fig(
  [Sơ đồ Use Case tổng quan hệ thống ShopNexus C2C],
  spacing: (28mm, 12mm),
  node(enclose: (<u1>, <u1b>, <u2>, <u3>, <u4>, <u5>, <u6>, <u7>, <u8>, <u9>), inset: 15pt,
    stroke: (paint: blue, dash: "dashed", thickness: 1pt), fill: none, corner-radius: 8pt),
  node((2, -0.9), text(size: 9pt, fill: blue, weight: 700)[Ranh giới hệ thống ShopNexus C2C],
    fill: white, stroke: none),
  np((2, -0.15), [UC-001 · Đăng ký tài khoản], name: <u1>),
  np((2, 0.65), [UC-002 · Đăng nhập], name: <u1b>),
  np((2, 1.5), [UC-010 · Cấp phát tài khoản Moderator], name: <u9>),
  np((2, 2.3), [UC-003 · Đăng bán sản phẩm C2C], name: <u2>),
  np((2, 3.3), [UC-004 · Nhắn tin trực tuyến (Chat)], name: <u3>),
  np((2, 4.3), [UC-005 · Đặt hàng & Thanh toán Escrow], name: <u4>),
  np((2, 5.3), [UC-006 · Yêu cầu Trả hàng / Hoàn tiền], name: <u5>),
  np((2, 6.3), [UC-007 · Khiếu nại và Tranh chấp], name: <u6>),
  np((2, 7.3), [UC-008 · Phân xử tranh chấp], name: <u7>),
  np((2, 8.3), [UC-009 · Đánh giá & Phản hồi], name: <u8>),

  nact((0, 2.5), [Người dùng\ (User)]),
  nact((4, 5.5), [Điều phối viên\ (Moderator)]),
  nact((4, 1.5), [Quản trị viên\ (Admin)]),

  // User edges — chỉ User mới có thể Đăng ký; cả 3 vai trò đều Đăng nhập
  edge((0, 2.5), <u1>, stroke: 0.7pt + blue-s),
  edge((0, 2.5), <u1b>, stroke: 0.7pt + blue-s),
  edge((0, 2.5), <u2>, stroke: 0.7pt + blue-s),
  edge((0, 2.5), <u3>, stroke: 0.7pt + blue-s),
  edge((0, 2.5), <u4>, stroke: 0.7pt + blue-s),
  edge((0, 2.5), <u5>, stroke: 0.7pt + blue-s),
  edge((0, 2.5), <u6>, stroke: 0.7pt + blue-s),
  edge((0, 2.5), <u8>, stroke: 0.7pt + blue-s),

  // Moderator edges — chỉ Đăng nhập, không Đăng ký
  edge((4, 5.5), <u1b>, stroke: 0.7pt + teal),
  edge((4, 5.5), <u7>, stroke: 0.7pt + teal),

  // Admin edges — chỉ Đăng nhập, không Đăng ký
  edge((4, 1.5), <u1b>, stroke: 0.7pt + red),
  edge((4, 1.5), <u9>, stroke: 0.7pt + red),
)

=== Danh mục Trường hợp sử dụng
#table(
  columns: (0.8fr, 1.6fr, 1.1fr, 2fr, 0.7fr),
  align: (center, left, center, left, center),
  [ID], [Tên Use Case], [Tác nhân chính], [Mô tả ngắn gọn], [Ưu tiên],
  [UC-001], [Đăng ký tài khoản], [User], [User tự tạo tài khoản trực tuyến công khai với vai trò User], [Cao],
  [UC-002], [Đăng nhập], [User, Moderator, Admin], [Xác thực tài khoản và điều hướng vào đúng phân hệ theo vai trò], [Cao],
  [UC-003], [Đăng bán sản phẩm C2C], [User], [User đăng tải sản phẩm cá nhân bán lên sàn, thiết lập Giá cố định hoặc Thương lượng], [Cao],
  [UC-004], [Nhắn tin trực tuyến (Chat)], [User], [User trò chuyện, gửi ảnh/video và thương lượng qua Offer Card kèm lý do giảm giá cụ thể], [Cao],
  [UC-005], [Đặt hàng & Thanh toán Escrow], [User], [Mua sản phẩm (mua trực tiếp nếu giá cố định, hoặc thông qua phê duyệt Offer Card trong Chat)], [Cao],
  [UC-006], [Yêu cầu Trả hàng / Hoàn tiền], [User], [User mua khiếu nại hàng lỗi kèm video mở hộp trong 3 ngày], [Cao],
  [UC-007], [Khiếu nại và Tranh chấp], [User], [User bán từ chối hoàn tiền, chuyển hồ sơ lên Moderator], [Cao],
  [UC-008], [Phân xử tranh chấp], [Moderator], [Moderator thẩm định bằng chứng, quyết định hoàn tiền/giải ngân], [Cao],
  [UC-009], [Đánh giá & Phản hồi], [User], [User đánh giá chất lượng sản phẩm & độ uy tín User bán], [Trung bình],
  [UC-010], [Cấp phát tài khoản Moderator], [Admin], [Admin tối cao trực tiếp tạo tài khoản cấp cho Moderator], [Cao],
)

=== Đặc tả chi tiết từng Use Case trọng tâm

*UC-001: Đăng ký tài khoản*
- *Diễn viên:* User
- *Mô tả:* Cho phép người dùng mới tự đăng ký tài khoản trực tuyến công khai với vai trò `User`. Moderator và Admin không có chức năng đăng ký công khai.
- *Điều kiện trước:* Người dùng truy cập hệ thống và chưa có tài khoản.
- *Luồng chính:*
  1. Người dùng chọn chức năng "Đăng ký".
  2. Hệ thống hiển thị biểu mẫu Đăng ký dành riêng cho đối tượng khách hàng (User).
  3. Người dùng điền Email, Mật khẩu, Số điện thoại và nhấn xác nhận.
  4. Hệ thống kiểm tra Email chưa tồn tại, băm mật khẩu theo thuật toán bảo mật cao (BR-010) và tạo tài khoản mới với vai trò `User` ở trạng thái hoạt động.
  5. Hệ thống chuyển hướng người dùng sang trang đăng nhập hoặc tự động đăng nhập vào trang chủ sàn C2C.
- *Luồng ngoại lệ [3a]:* Email đã tồn tại trên hệ thống:
  - Hệ thống báo lỗi và yêu cầu người dùng nhập lại thông tin hoặc chọn "Đăng nhập" nếu đã có tài khoản.
- *Luồng ngoại lệ [4a]:* Moderator hoặc Admin cố gắng đăng ký qua biểu mẫu công khai:
  - Giao diện đăng ký công khai không có chức năng chọn phân quyền Moderator hay Admin; hệ thống mặc định chỉ tạo vai trò `User`.
- *Điều kiện sau:* Tài khoản `User` mới được tạo thành công, sẵn sàng để đăng nhập (UC-002).

*UC-002: Đăng nhập*
- *Diễn viên:* User, Moderator, Admin
- *Mô tả:* Xác thực tài khoản đã tồn tại trong hệ thống (tự đăng ký đối với User, hoặc được cấu hình/cấp phát sẵn đối với Moderator và Admin) và điều hướng vào đúng phân hệ tương ứng với vai trò.
- *Điều kiện trước:* Người dùng đã sở hữu tài khoản hợp lệ và chưa đăng nhập.
- *Luồng chính:*
  1. Người dùng chọn chức năng "Đăng nhập" và nhập Email, Mật khẩu.
  2. Hệ thống kiểm tra và xác thực thông tin đăng nhập.
  3. Hệ thống xác định vai trò của tài khoản và chuyển hướng tương ứng:
     - Nếu là tài khoản `User`: Chuyển về trang chủ sàn mua bán C2C.
     - Nếu là tài khoản `Moderator`: Chuyển về phân hệ xử lý tranh chấp và hỗ trợ CSKH.
     - Nếu là tài khoản `Admin`: Chuyển về phân hệ quản trị tối cao (System Admin).
- *Luồng ngoại lệ [2a]:* Sai Email hoặc Mật khẩu:
  - Hệ thống hiển thị thông báo lỗi xác thực, không tạo session và cho phép người dùng thử lại.
- *Điều kiện sau:* Người dùng đăng nhập thành công vào một session an toàn, đúng với phân hệ vai trò của mình.

*UC-004: Nhắn tin trực tuyến (Chat)*
- *Diễn viên:* User
- *Mô tả:* Hai User trao đổi tin nhắn trực tiếp về sản phẩm, gửi hình ảnh/video thực tế. Đối với sản phẩm Giá thương lượng, User mua có thể gửi yêu cầu đề xuất giá, User bán tạo và gửi Offer Card (kèm giá mới và lý do cụ thể), User mua chấp nhận thẻ này để thanh toán.
- *Điều kiện trước:* Cả hai User đã đăng nhập thành công (UC-002).
- *Luồng chính:*
  1. User mua truy cập trang chi tiết sản phẩm Giá thương lượng và chọn "Mua ngay/Thương lượng".
  2. Hệ thống tự động chuyển hướng và khởi tạo khung chat kết nối trực tiếp với sản phẩm tương ứng.
  3. User mua gửi tin nhắn trao đổi hoặc yêu cầu ảnh thực tế.
  4. User bán phản hồi lại tin nhắn.
  5. User mua nhấn vào tính năng "Yêu cầu Đề xuất giá" (Offer).
  6. Khung chat hiển thị thông báo yêu cầu gửi đề xuất đến User bán.
  7. User bán nhấn "Tạo Offer Card", nhập mức giá đề xuất mới và nhập lý do giảm giá cụ thể (ví dụ: "Hỗ trợ phí vận chuyển do nhà xa - giảm 50k", "Sản phẩm có vết trầy xước nhẹ - giảm 100k").
  8. User bán nhấn "Gửi". Khung chat hiển thị một Offer Card đặc biệt chứa thông tin: Giá mới, Lý do giảm giá, Trạng thái (Chờ duyệt), kèm hai nút "Chấp nhận" và "Từ chối" phía User mua.
  9. User mua xem xét và nhấn "Chấp nhận".
  10. Hệ thống cập nhật trạng thái Offer Card thành "Đã chấp nhận", tự động khởi tạo đơn đặt hàng tạm thời với mức giá đã thương lượng thành công và chuyển hướng User mua sang trang xác nhận thanh toán (Xem UC-005).
- *Luồng thay thế [9a]:* User mua nhấn "Từ chối":
  - Hệ thống cập nhật trạng thái Offer Card thành "Đã từ chối". Hai bên tiếp tục trao đổi qua tin nhắn thường hoặc gửi yêu cầu đề xuất giá mới.
- *Điều kiện sau:* Cuộc trò chuyện được lưu trữ trực tuyến; giá khuyến mãi được áp dụng nếu có sự đồng thuận.

*UC-005: Đặt hàng & Thanh toán Escrow*
- *Diễn viên:* User
- *Mô tả:* User mua đặt mua sản phẩm và thanh toán trực tuyến qua cổng VNPay/SePay, số tiền được chuyển vào ví tạm giữ Escrow. Hệ thống phân tách luồng thanh toán tùy theo sản phẩm là giá cố định (chuyển thẳng từ trang sản phẩm) hay giá thương lượng (chuyển qua Offer Card trong Chat).
- *Điều kiện trước:* User mua đã đăng nhập, đã chọn sản phẩm hoặc đã thương lượng giá thành công qua Chat (UC-004).
- *Luồng chính:*
  1. Lựa chọn luồng đặt hàng tùy theo chế độ giá của sản phẩm:
     - *Trường hợp A (Giá cố định X\$):* User mua nhấn nút "Mua ngay" trên trang chi tiết sản phẩm. Hệ thống chuyển hướng thẳng sang trang thông tin đặt hàng & thanh toán.
     - *Trường hợp B (Giá thương lượng ~X\$):* User mua nhận được Offer Card trong Chat và nhấn "Chấp nhận" (UC-004). Hệ thống tạo đơn hàng tạm và chuyển hướng sang trang xác nhận thanh toán.
  2. Hệ thống hiển thị giao diện đặt hàng, yêu cầu User mua nhập/xác nhận địa chỉ giao nhận.
  3. Hệ thống gọi API của đối tác vận chuyển (GHN/GHTK) tính phí ship động và tổng tiền cần thanh toán.
  4. User mua chọn phương thức "Thanh toán tạm giữ trực tuyến".
  5. User mua nhấn nút "Xác nhận thanh toán".
  6. Hệ thống chuyển hướng User mua sang cổng thanh toán đối tác để thực hiện giao dịch chuyển khoản/quét QR.
  7. Giao dịch thành công, cổng thanh toán phản hồi trạng thái hoàn tất về hệ thống.
  8. Hệ thống tạo đơn hàng mới ở trạng thái "Đã thanh toán (Tạm giữ/Escrow)" và khóa dòng tiền này trong tài khoản Escrow.
  9. Hệ thống gửi thông báo cho User bán để chuẩn bị giao hàng.
- *Luồng ngoại lệ [7a]:* Giao dịch thanh toán trực tuyến thất bại hoặc bị hủy bỏ giữa chừng:
  - Hệ thống hiển thị thông báo lỗi, chuyển trạng thái đơn hàng thành "Chờ thanh toán" trong 24 giờ. Quá 24 giờ sẽ tự động hủy đơn.
- *Điều kiện sau:* Số tiền giao dịch của User mua được khóa an toàn trong ví Escrow trung gian.

*UC-006: Yêu cầu Trả hàng / Hoàn tiền (Refund)*
- *Diễn viên:* User
- *Mô tả:* User mua gửi khiếu nại yêu cầu trả lại hàng và hoàn lại số tiền đang bị tạm giữ trong ví Escrow khi nhận hàng lỗi hoặc sai mô tả.
- *Điều kiện trước:* Đơn hàng ở trạng thái "Đã giao thành công" và vẫn trong thời hạn 3 ngày (72 giờ).
- *Luồng chính:*
  1. User mua truy cập trang lịch sử đơn hàng, chọn đơn hàng và nhấn "Trả hàng / Hoàn tiền".
  2. Hệ thống hiển thị biểu mẫu yêu cầu chọn lý do trả hàng (Lỗi sản phẩm, Không đúng mô tả...) và bắt buộc tải lên video mở hộp cùng hình ảnh chứng minh lỗi.
  3. User mua gửi yêu cầu; hệ thống chuyển trạng thái đơn hàng sang "Yêu cầu Trả hàng" và tạm dừng bộ đếm ngược Escrow.
  4. Hệ thống gửi thông báo yêu cầu cho User bán để phản hồi trong vòng 48 giờ.
  5. User bán kiểm tra bằng chứng và nhấn nút "Đồng ý hoàn tiền".
  6. Hệ thống cung cấp mã vận đơn trả hàng miễn phí cho User mua qua đối tác vận chuyển.
  7. User mua gửi hàng trả lại; sau khi User bán nhận được hàng trả về và xác nhận nguyên vẹn, hệ thống tự động hoàn 100% số tiền tạm giữ từ ví Escrow về tài khoản ngân hàng của User mua.
- *Luồng thay thế [5a]:* User bán không đồng ý với yêu cầu trả hàng:
  - User bán chọn nút "Từ chối trả hàng" và khởi động tranh chấp (Xem UC-007).
- *Điều kiện sau:* Tiền hàng tạm giữ bị khóa cứng hoặc đã hoàn trả một phần/toàn phần tùy thuộc vào phản hồi của User bán.

*UC-008: Phân xử tranh chấp (Moderator)*
- *Diễn viên:* Moderator
- *Mô tả:* Moderator kiểm tra bằng chứng của cả User mua và User bán để đưa ra quyết định giải ngân tiền cho User bán hay hoàn tiền cho User mua.
- *Điều kiện trước:* Đơn hàng ở trạng thái "Đang tranh chấp" (UC-007).
- *Luồng chính:*
  1. Moderator đăng nhập vào phân hệ quản lý, truy cập danh mục "Tranh chấp cần xử lý".
  2. Moderator chọn vụ tranh chấp để xem chi tiết thông tin đơn hàng, lý do khiếu nại của User mua (kèm video/ảnh mở hộp) và lý do phản đối của User bán (kèm video/ảnh đóng gói đối chứng).
  3. Moderator tiến hành đối soát, thẩm định tính xác thực của các bằng chứng.
  4. Moderator đưa ra phán quyết:
     - *Phương án A (Quyết định hoàn tiền cho User mua):* Moderator nhấn nút "Hoàn tiền cho Buyer". Hệ thống giải phóng ví Escrow chuyển hoàn tiền về tài khoản User mua.
     - *Phương án B (Quyết định giải ngân cho User bán):* Moderator nhấn nút "Giải ngân cho Seller". Hệ thống tự động chuyển tiền tạm giữ vào ví khả dụng của User bán.
  5. Hệ thống gửi thông báo kết quả chi tiết kèm lý do phân xử của Moderator cho cả hai bên và đóng vụ tranh chấp.
- *Điều kiện sau:* Dòng tiền Escrow được giải quyết dứt điểm, trạng thái tranh chấp hoàn thành.

*UC-010: Cấp phát tài khoản Moderator*
- *Diễn viên:* Admin
- *Mô tả:* Admin tối cao tạo tài khoản và phân quyền cho một Moderator mới để hỗ trợ xử lý khiếu nại tranh chấp và CSKH trên sàn.
- *Điều kiện trước:* Admin đã đăng nhập vào hệ thống quản trị Super Admin (UC-002).
- *Luồng chính:*
  1. Admin truy cập vào menu "Quản lý nhân sự" và chọn "Thêm Moderator".
  2. Admin nhập các thông tin cá nhân bắt buộc của nhân sự (Họ tên, Email, Số điện thoại).
  3. Admin nhấn nút "Cấp phát tài khoản".
  4. Hệ thống khởi tạo tài khoản mới với vai trò `Moderator`, tạo mật khẩu tạm thời ngẫu nhiên.
  5. Hệ thống gửi email tự động chứa liên kết đăng nhập và thông tin tài khoản đến Email của Moderator.
  6. Moderator truy cập liên kết, thực hiện đăng nhập (UC-002) và bắt buộc đổi mật khẩu ở lần truy cập đầu tiên.
- *Điều kiện sau:* Tài khoản Moderator mới được tạo thành công ở trạng thái hoạt động trong hệ thống.

== Mô Hình Hóa Quy Trình (DOC 2.2-A)

Các quy trình nghiệp vụ phức tạp của ShopNexus được tối ưu hóa trực quan thông qua các sơ đồ hoạt động dưới đây.

=== Quy trình thanh toán tạm giữ (Escrow Payment Flow)

#note[Quy trình mô tả cách hệ thống tự động bóc tách và tạm khóa số tiền thanh toán của người mua vào ví Escrow trung gian nhằm bảo vệ giao dịch, chỉ giải ngân cho người bán khi hết thời gian 3 ngày mà không có khiếu nại. Luồng được phân nhánh ngay từ đầu tùy theo Chế độ giá của sản phẩm.]

#fig(
  [Quy trình thanh toán tạm giữ phân nhánh theo chế độ giá (Escrow Payment Flow)],
  spacing: (20mm, 10mm),
  nt((0, 0), [Bắt đầu]),
  edge((0, 0), (0, 1), "-|>"),
  nd((0, 1), [Chế độ giá?]),
  // Fixed Price Branch (left)
  edge((0, 1), (-1.3, 2), "-|>", text(size: 8pt)[Cố định], label-side: left),
  np((-1.3, 2), [Bấm "Mua ngay" tại trang sản phẩm]),
  edge((-1.3, 2), (-1.3, 6), "-|>"),
  // Negotiable Price Branch (right)
  edge((0, 1), (1.3, 2), "-|>", text(size: 8pt)[Thương lượng], label-side: right),
  np((1.3, 2), [Chuyển hướng vào Khung Chat]),
  edge((1.3, 2), (1.3, 3), "-|>"),
  np((1.3, 3), [Thương lượng & Yêu cầu đề xuất]),
  edge((1.3, 3), (1.3, 4), "-|>"),
  np((1.3, 4), [Seller gửi Offer Card + Lý do]),
  edge((1.3, 4), (1.3, 5), "-|>"),
  nd((1.3, 5), [Buyer chấp nhận?]),
  edge((1.3, 5), (2.5, 5), "-|>", text(size: 8pt)[Không]),
  nr((2.5, 5), [Hủy / Chat tiếp]),
  edge((1.3, 5), (1.3, 6), "-|>", text(size: 8pt)[Có]),

  // Merge at payment page
  np((0, 6), [Xác nhận đặt hàng & Thanh toán]),
  edge((-1.3, 6), (0, 6), "-|>"),
  edge((1.3, 6), (0, 6), "-|>"),

  edge((0, 6), (0, 7), "-|>"),
  np((0, 7), [Ví Escrow trung gian khóa tiền]),
  edge((0, 7), (0, 8), "-|>"),
  np((0, 8), [Giao hàng thành công & Đếm ngược 3 ngày]),
  edge((0, 8), (0, 9), "-|>"),
  nd((0, 9), [Có khiếu nại?]),
  edge((0, 9), (-1.3, 10), "-|>", text(size: 8pt)[Có], label-side: left),
  np((-1.3, 10), [Kích hoạt Quy trình Tranh chấp (Dispute)]),
  edge((0, 9), (1.3, 10), "-|>", text(size: 8pt)[Không], label-side: right),
  ng((1.3, 10), [Giải ngân tiền cho User bán]),

  edge((-1.3, 10), (0, 11), "-|>"),
  edge((1.3, 10), (0, 11), "-|>"),
  nt((0, 11), [Kết thúc]),
  edge((2.5, 5), (0, 11), "-|>"),
)

=== Quy trình xử lý trả hàng, hoàn tiền và tranh chấp (Refund & Dispute Flow)

#note[Quy trình thể hiện điểm cốt lõi của ShopNexus: Nếu xảy ra lỗi sản phẩm, tiền tạm giữ sẽ bị khóa lập tức. Khi hai bên không tự thống nhất được, Điều phối viên (Moderator) được cấp quyền bởi Admin sẽ can thiệp phân xử.]

#fig(
  [Quy trình xử lý trả hàng, hoàn tiền và tranh chấp (Refund & Dispute Flow)],
  spacing: (22mm, 11mm),
  nt((0, 0), [Bắt đầu]),
  edge((0, 0), (0, 1), "-|>"),
  np((0, 1), [User mua gửi Yêu cầu Hoàn tiền]),
  edge((0, 1), (0, 2), "-|>"),
  np((0, 2), [Cung cấp video/hình ảnh mở hộp]),
  edge((0, 2), (0, 3), "-|>"),
  np((0, 3), [Hệ thống khóa tiền tạm giữ (Escrow)]),
  edge((0, 3), (0, 4), "-|>"),
  nd((0, 4), [User bán đồng ý?]),
  edge((0, 4), (-1.3, 5), "-|>", text(size: 8pt)[Có]),
  ng((-1.3, 5), [Hoàn tiền tự động cho User mua]),
  edge((0, 4), (1.3, 5), "-|>", text(size: 8pt)[Không]),
  np((1.3, 5), [Mở Tranh chấp (Dispute) - Moderator phân xử]),
  edge((1.3, 5), (1.3, 6), "-|>"),
  np((1.3, 6), [Moderator thu thập bằng chứng 2 bên]),
  edge((1.3, 6), (1.3, 7), "-|>"),
  nd((1.3, 7), [Phán quyết của Moderator?]),
  edge((1.3, 7), (0, 8), "-|>", text(size: 8pt)[Mua thắng]),
  edge((1.3, 7), (2.5, 8), "-|>", text(size: 8pt)[Bán thắng]),
  ng((2.5, 8), [Giải ngân tiền cho User bán]),
  ng((0, 8), [Hoàn tiền cho User mua]),
  edge((-1.3, 5), (-1.3, 9), "-|>"),
  edge((0, 8), (0, 9), "-|>"),
  edge((2.5, 8), (2.5, 9), "-|>"),
  nt((1.3, 9), [Kết thúc]),
  edge((-1.3, 9), (1.3, 9), "-|>"),
  edge((0, 9), (1.3, 9), "-|>"),
  edge((2.5, 9), (1.3, 9), "-|>"),
)

=== Quy trình nhắn tin trực tuyến và thương lượng giá (Chat & Negotiation Flow)

#note[Quy trình cho phép các User trao đổi trực tiếp để đi đến sự đồng thuận về giá bán. Đối với sản phẩm Giá thương lượng, User mua bắt buộc phải gửi yêu cầu và được User bán gửi Offer Card ghi rõ số tiền đề xuất và lý do giảm giá cụ thể để chấp nhận thanh toán.]

#fig(
  [Quy trình nhắn tin trực tuyến và thương lượng giá qua Offer Card (Chat & Negotiation Flow)],
  spacing: (20mm, 10mm),
  nt((0, 0), [Bắt đầu]),
  edge((0, 0), (0, 1), "-|>"),
  np((0, 1), [User mua bấm "Mua ngay" của sản phẩm thương lượng]),
  edge((0, 1), (0, 2), "-|>"),
  np((0, 2), [Hệ thống tự động mở khung Chat]),
  edge((0, 2), (0, 3), "-|>"),
  np((0, 3), [Hai bên chat trao đổi thông tin thực tế]),
  edge((0, 3), (0, 4), "-|>"),
  np((0, 4), [User mua nhấn "Yêu cầu Đề xuất giá"]),
  edge((0, 4), (0, 5), "-|>"),
  np((0, 5), [User bán tạo và gửi Offer Card (Giá mới + Lý do)]),
  edge((0, 5), (0, 6), "-|>"),
  nd((0, 6), [User mua chấp nhận Offer Card?]),
  edge((0, 6), (1.3, 6), "-|>", text(size: 8pt)[Không], label-side: right),
  nr((1.3, 6), [Từ chối & tiếp tục chat thương lượng lại]),
  edge((0, 6), (0, 7), "-|>", text(size: 8pt)[Có]),
  ng((0, 7), [Hệ thống tự động tạo đơn hàng với giá đề xuất]),
  edge((0, 7), (0, 8), "-|>"),
  nt((0, 8), [Kết thúc]),
  edge((1.3, 6), (0, 8), "-|>"),
)

=== Quy trình cấp phát tài khoản Moderator (Moderator Provisioning Flow)

#note[Quy trình chỉ cho phép Super Admin tối cao thao tác trong phân hệ quản trị để tạo và cấp phát tài khoản hoạt động cho các Moderator, không hỗ trợ đăng ký tự do.]

#fig(
  [Quy trình cấp phát tài khoản Moderator (Moderator Provisioning Flow)],
  spacing: (20mm, 10mm),
  nt((0, 0), [Bắt đầu]),
  edge((0, 0), (0, 1), "-|>"),
  np((0, 1), [Admin truy cập quản lý nhân sự]),
  edge((0, 1), (0, 2), "-|>"),
  np((0, 2), [Admin nhập thông tin Moderator mới]),
  edge((0, 2), (0, 3), "-|>"),
  nd((0, 3), [Email đã tồn tại?]),
  edge((0, 3), (1.2, 3), "-|>", text(size: 8pt)[Có]),
  nr((1.2, 3), [Báo lỗi & yêu cầu nhập lại]),
  edge((0, 3), (0, 4), "-|>", text(size: 8pt)[Không]),
  np((0, 4), [Hệ thống tạo tài khoản vai trò Moderator và cấp quyền]),
  edge((0, 4), (0, 5), "-|>"),
  ng((0, 5), [Gửi mật khẩu tạm thời qua Email]),
  edge((0, 5), (0, 6), "-|>"),
  nt((0, 6), [Kết thúc]),
  edge((1.2, 3), (0, 2), "-|>"),
)

== Mô Hình Dữ Liệu Ban Đầu (DOC 2.3-A)

=== Sơ đồ ERD module Order (Conceptual ERD)

Dưới đây là sơ đồ thực thể liên kết (bản rút gọn) biểu diễn cấu trúc dữ liệu của #emph[module Order] (schema `"order"`) bằng ký hiệu chân quạ (Crow's Foot Notation). Sơ đồ chỉ hiển thị các thực thể và thuộc tính khóa tiêu biểu; các module khác (`account`, `catalog`, ...) được tham chiếu logic qua các cột `*_id` mà không khai báo khóa ngoại ở tầng CSDL để giữ các module tách rời.

// ---- entity helper (bubble-style node) ----
#let entity(p, nm, title) = node(p,
  text(weight: 700, size: 8.5pt, title),
  shape: pill,
  fill: blue-l,
  stroke: 1pt + blue-s,
  name: nm
)

#fig(
  [Sơ đồ ERD module Order (schema `order`) — ký hiệu chân quạ (Crow's Foot)],
  spacing: (16mm, 12mm), edge-stroke: 1pt + blue-s,

  entity((0, 0.7), <e-trans>, [TRANSPORT]),
  entity((1.5, 0), <e-pay>, [PAYMENT\_SESSION]),
  entity((3, 0), <e-tx>, [TRANSACTION]),
  entity((1.5, 1.7), <e-order>, [ORDER]),
  entity((3, 1.8), <e-refund>, [REFUND]),
  entity((0, 2.2), <e-cart>, [CART\_ITEM]),
  entity((1.5, 3.3), <e-item>, [ITEM]),
  entity((3, 3.4), <e-disp>, [REFUND\_DISPUTE]),

  edge(<e-pay>, <e-tx>, "1-n?", text(size: 7.5pt)[gồm]),
  edge(<e-tx>, <e-tx>, "1-1?", text(size: 7pt)[đảo ứng], bend: 130deg),
  edge(<e-order>, <e-pay>, "1-1", text(size: 7.5pt)[phí xác nhận]),
  edge(<e-order>, <e-trans>, "1-1", text(size: 7.5pt)[vận chuyển]),
  edge(<e-item>, <e-order>, "n-1?", text(size: 7.5pt)[thuộc]),
  edge(<e-item>, <e-pay>, "n-1", text(size: 7.5pt)[trả trước], bend: 42deg, label-pos: 0.13, label-side: left),
  edge(<e-refund>, <e-order>, "n-1", text(size: 7.5pt)[khiếu nại]),
  edge(<e-refund>, <e-tx>, "1-1?", text(size: 7.5pt)[hoàn tiền]),
  edge(<e-disp>, <e-refund>, "n-1", text(size: 7.5pt)[tranh chấp]),
)

=== Danh mục Thực thể (Entity Catalog)
#table(
  columns: (1.2fr, 2fr, 1.3fr, 1.5fr),
  align: (center, left, center, left),
  [Tên thực thể], [Định nghĩa nghiệp vụ], [Loại thực thể], [Ví dụ thuộc tính khóa & mô tả],
  [CartItem], [Giỏ hàng phẳng: mỗi dòng là một cặp (account, SKU) đang chờ thanh toán], [Associative (Kết hợp)], [id (PK), account_id, sku_id, quantity],
  [PaymentSession], [Một luồng tiền logic (buyer-checkout / phí xác nhận / payout) với trạng thái thay đổi được và 0..N bút toán con], [Core (Cốt lõi)], [id (PK), kind, status, from_id, to_id, currency, total_amount],
  [Transaction], [Sổ cái chỉ-thêm (append-only): mỗi dòng là một chặng chuyển tiền (ví, thẻ, chặng hoàn); đảo ứng là dòng mới amount âm trỏ reverses_id], [Core (Sổ cái)], [id (PK), session_id (FK), status, amount, currency, reverses_id (FK)],
  [Transport], [Bản ghi vận chuyển / giao hàng (cả chặng giao đi và chặng trả hàng)], [Core (Cốt lõi)], [id (PK), option, status, data],
  [Order], [Đơn hàng được tạo khi người bán xác nhận các item đã thanh toán; buyer và seller đều là account], [Core (Cốt lõi)], [id (PK), buyer_id, seller_id, transport_id (FK), confirm_session_id (FK), address],
  [Item], [Dòng hàng checkout; order_id NULL cho đến khi người bán xác nhận. Lưu snapshot giá/tiền tại thời điểm mua], [Associative (Kết hợp)], [id (PK), order_id (FK), sku_id, quantity, total_amount, payment_session_id (FK)],
  [Refund], [Yêu cầu hoàn tiền do người mua tạo; người mua ship hàng trả lại ngay khi tạo (return_transport bắt buộc)], [Core (Cốt lõi)], [id (PK), account_id, order_id (FK), status, return_transport_id (FK), refund_tx_id (FK)],
  [RefundDispute], [Người bán khiếu nại từ chối hoàn tiền sau khi kiểm hàng; Admin phân xử (SellerWins / BuyerWins)], [Core (Cốt lõi)], [id (PK), refund_id (FK), account_id (seller), status, resolved_by_id (admin)],
)

=== Danh mục Mối quan hệ (Relationship Catalog)
#table(
  columns: (1fr, 1fr, 1.2fr, 1fr, 1.8fr),
  align: (center, center, center, center, left),
  [Thực thể A], [Thực thể B], [Tên mối quan hệ], [Bản số], [Ý nghĩa nghiệp vụ],
  [PaymentSession], [Transaction], [Gồm (Has)], [1 : 0..N], [Một phiên thanh toán gồm nhiều bút toán sổ cái (chia theo rail: ví, thẻ, chặng hoàn...).],
  [Transaction], [Transaction], [Đảo ứng (Reverses)], [1 : 0..1], [Một bút toán gốc có thể bị đúng một bút toán đảo ứng (amount âm) trỏ tới qua reverses_id.],
  [Order], [Transport], [Vận chuyển (Ships via)], [1 : 1], [Mỗi đơn hàng gắn duy nhất một bản ghi vận chuyển (transport_id UNIQUE).],
  [Order], [PaymentSession], [Phí xác nhận (Confirms via)], [1 : 1], [Mỗi đơn tham chiếu đúng một phiên phí xác nhận của người bán (confirm_session_id).],
  [Item], [Order], [Thuộc (Belongs to)], [N : 0..1], [Nhiều item thuộc một đơn; item chưa được xác nhận có order_id = NULL.],
  [Item], [PaymentSession], [Trả trước (Paid in)], [N : 1], [Nhiều item được thanh toán trong cùng một phiên (mô hình pay-first).],
  [Refund], [Order], [Khiếu nại (Refunds)], [N : 1], [Một đơn có thể phát sinh nhiều yêu cầu hoàn tiền theo thời gian (chỉ một cái ở trạng thái active).],
  [Refund], [Transport], [Trả hàng (Returns via)], [1 : 1], [Người mua ship hàng trả lại ngay khi tạo refund (return_transport_id bắt buộc).],
  [Refund], [Transaction], [Hoàn tiền (Settles via)], [1 : 0..1], [Khi được chấp nhận, refund tạo một bút toán đảo ứng (refund_tx_id); NULL khi chưa/không hoàn.],
  [RefundDispute], [Refund], [Tranh chấp (Disputes)], [N : 1], [Một yêu cầu hoàn tiền có thể bị người bán khiếu nại (chỉ một cái ở trạng thái Open).],
)

=== Quy tắc kinh doanh (Business Rules)
- *BR-001:* Hệ thống phân quyền chặt chẽ 3 vai trò: Admin tối cao (chỉ duy nhất 1 tài khoản được tạo sẵn, không tự đăng ký), Moderator (kiểm duyệt viên xử lý tranh chấp, do Admin cấp phát, không tự đăng ký) và User (người dùng, được đăng ký công khai).
- *BR-002:* Tài khoản vai trò User sau khi tự đăng ký thành công sẽ có đầy đủ hai chức năng mua và bán.
- *BR-003:* Tiền thanh toán đơn hàng C2C qua cổng thanh toán trực tuyến bắt buộc phải được chuyển vào ví tạm giữ (Escrow) dưới dạng "EscrowBalance" (Số dư đóng băng) của User bán.
- *BR-004:* Bộ đếm ngược tạm giữ 3 ngày (72 giờ) sẽ tự động kích hoạt ngay khi đơn vị vận chuyển đối tác cập nhật trạng thái đơn hàng là "Giao hàng thành công" qua API.
- *BR-005:* Nếu quá thời hạn 3 ngày mà User mua không xác nhận hài lòng hay gửi yêu cầu Trả hàng / Hoàn tiền, hệ thống tự động giải ngân tiền sang số dư khả dụng (Balance) cho User bán.
- *BR-006:* User mua khi yêu cầu hoàn tiền bắt buộc phải cung cấp video mở hộp rõ nét không cắt ghép và hình ảnh chứng minh lỗi sản phẩm để khiếu nại hợp lệ.
- *BR-007:* Khi User mua yêu cầu hoàn tiền, User bán có 48 giờ để phản hồi. Nếu đồng ý hoặc không phản hồi sau 48 giờ, hệ thống tự động hoàn tiền 100% từ ví Escrow về tài khoản của User mua.
- *BR-008:* Nếu User bán bấm từ chối hoàn tiền và gửi bằng chứng (như video đóng gói hàng đối chứng), vụ việc lập tức chuyển sang trạng thái "Đang tranh chấp" để hệ thống chuyển giao cho một Moderator vào phân xử.
- *BR-009:* Moderator trực tiếp xem xét, thẩm định các bằng chứng của cả hai bên và ra phán quyết giải ngân cho User bán hoặc hoàn tiền cho User mua. Phán quyết của Moderator là quyết định cuối cùng.
- *BR-010:* Chỉ duy nhất 1 tài khoản Admin tối cao được phép thực hiện chức năng cấp phát tài khoản (tạo Email, Số điện thoại và gửi mật khẩu tạm thời) cho các Moderator hoặc khóa tài khoản của họ.
- *BR-011:* Hệ thống sẽ trích xuất một khoản phí sàn (Transaction Fee) từ tổng số tiền giao dịch khi giải ngân thành công cho User bán để duy trì hoạt động.
- *BR-012:* Mọi sự thay đổi về số dư ví khả dụng hoặc ví tạm giữ của người dùng bắt buộc phải được ghi lịch sử đầy đủ trong thực thể giao dịch ví (WalletTransaction) để đối soát tài chính độc lập.
- *BR-013:* Đối với sản phẩm có chế độ giá cố định (Fixed Price), hệ thống cho phép User mua thanh toán trực tiếp từ trang chi tiết sản phẩm.
- *BR-014:* Đối với sản phẩm có chế độ giá thương lượng (Negotiable Price), chức năng thanh toán trực tiếp bị khóa từ trang chi tiết sản phẩm; User mua bắt buộc phải bấm nút chuyển hướng vào khung chat để gửi yêu cầu và nhận Offer Card từ User bán.
- *BR-015:* Offer Card được tạo và gửi bởi User bán trong chat bắt buộc phải hiển thị rõ giá mới và lý do cụ thể (ví dụ: bớt 50k do xa nhà, bớt 100k do lỗi nhẹ). Khi User mua bấm "Chấp nhận" trên Offer Card, hệ thống mới tự động tạo đơn đặt hàng và áp dụng giá ưu đãi đó.
