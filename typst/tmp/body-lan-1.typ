// AUTO-GENERATED body — do not edit by hand.
#import "style-report.typ": *

= Khảo sát hiện trạng và xác định tầm nhìn dự án

== Tầm Nhìn Dự Án

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

== Người Dùng và Bên Liên Quan

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
#figure(kind: table, caption: [Sổ Đăng Ký Bên Liên Quan])[
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
]

== Bối Cảnh Hệ Thống

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


// ============================================================
= Phân tích yêu cầu và thiết kế sơ bộ hệ thống

== Mô Hình Hóa Trường Hợp Sử Dụng

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
#figure(kind: table, caption: [Danh mục Trường hợp sử dụng])[
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
]

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

== Mô Hình Hóa Quy Trình

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

== Mô Hình Dữ Liệu Ban Đầu

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
#figure(kind: table, caption: [Danh mục Thực thể (Entity Catalog)])[
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
]

=== Danh mục Mối quan hệ (Relationship Catalog)
#figure(kind: table, caption: [Danh mục Mối quan hệ (Relationship Catalog)])[
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
]

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

= Đặc tả yêu cầu và mô phỏng giao diện

== Yêu Cầu Chức Năng

=== Trích xuất yêu cầu từ trường hợp sử dụng
Mỗi yêu cầu chức năng (Functional Requirement) được thiết kế theo cấu trúc nguyên tử: *“Hệ thống phải [hành động] [đối tượng] [điều kiện]”*, đảm bảo tính rõ ràng và có thể kiểm chứng. Dưới đây là danh sách các yêu cầu được trích xuất từ 13 trường hợp sử dụng cốt lõi của hệ thống ShopNexus C2C:

*UC-001: Đăng ký tài khoản*
- *REQ-001:* Hệ thống phải hiển thị biểu mẫu đăng ký dành riêng cho khách hàng (User) khi được yêu cầu.
- *REQ-002:* Hệ thống phải xác thực định dạng địa chỉ Email đăng ký của người dùng.
- *REQ-003:* Hệ thống phải từ chối đăng ký và báo lỗi nếu Email nhập vào đã tồn tại trong cơ sở dữ liệu.
- *REQ-004:* Hệ thống phải mã hoá mật khẩu của người dùng bằng thuật toán BCrypt trước khi lưu vào cơ sở dữ liệu.
- *REQ-005:* Hệ thống phải khởi tạo tài khoản mới ở trạng thái hoạt động với vai trò mặc định là `User`.

*UC-002: Đăng nhập*
- *REQ-006:* Hệ thống phải xác thực thông tin Email và Mật khẩu của tài khoản khi người dùng thực hiện đăng nhập.
- *REQ-007:* Hệ thống phải điều hướng người dùng có vai trò `User` về giao diện sàn C2C sau khi đăng nhập thành công.
- *REQ-008:* Hệ thống phải điều hướng nhân viên có vai trò `Moderator` về giao diện quản lý khiếu nại tranh chấp sau khi đăng nhập thành công.
- *REQ-009:* Hệ thống phải điều hướng người quản trị có vai trò `Admin` về giao diện quản trị hệ thống sau khi đăng nhập thành công.

*UC-003: Đăng bán sản phẩm (C2C)*
- *REQ-010:* Hệ thống phải cho phép User tải lên tối thiểu 1 hình ảnh và nhập tên sản phẩm, giá bán, tình trạng, danh mục và mô tả sản phẩm.
- *REQ-011:* Hệ thống phải bắt buộc User lựa chọn một trong hai chế độ đặt giá: "Giá cố định" hoặc "Giá thương lượng".
- *REQ-012:* Hệ thống phải kiểm tra và từ chối đăng bài bán nếu thiếu thông tin bắt buộc hoặc giá bán nhỏ hơn hoặc bằng 0.

*UC-004: Nhắn tin trực tuyến (Chat)*
- *REQ-013:* Hệ thống phải thiết lập kết nối thời gian thực (SSE/HTTP streamable) giữa hai User trong khung chat.
- *REQ-014:* Hệ thống phải cho phép User gửi tin nhắn văn bản, hình ảnh và video thực tế của sản phẩm qua giao diện chat.
- *REQ-015:* Hệ thống phải hỗ trợ User bán tạo và gửi "Offer Card" (Thẻ Đề xuất giá) ghi rõ mức giá đề xuất mới và lý do giảm giá cụ thể trong khung chat.
- *REQ-016:* Hệ thống phải tự động tạo đơn hàng tạm thời và cập nhật giá mới khi User mua nhấn nút "Chấp nhận" trên Offer Card.

*UC-005: Đặt hàng & Thanh toán Escrow*
- *REQ-017:* Hệ thống phải tích hợp API của đối tác vận chuyển để tính phí vận chuyển động dựa trên địa chỉ giao nhận của User mua.
- *REQ-018:* Hệ thống phải kết nối với cổng thanh toán (SePay/Stripe) để tạo mã giao dịch và kiểm tra trạng thái thanh toán trực tuyến.
- *REQ-019:* Hệ thống phải tự động khóa số tiền thanh toán của User mua trong ví tạm giữ Escrow của hệ thống sau khi giao dịch thành công.
- *REQ-020:* Hệ thống phải tự động hủy đơn đặt hàng nếu User mua không hoàn tất thanh toán trực tuyến trong vòng 24 giờ kể từ khi tạo đơn.

*UC-006: Yêu cầu Trả hàng / Hoàn tiền*
- *REQ-021:* Hệ thống phải cho phép User mua gửi yêu cầu hoàn tiền trong vòng tối đa 3 ngày (72 giờ) kể từ khi đơn hàng giao thành công.
- *REQ-022:* Hệ thống phải bắt buộc User mua tải lên video mở hộp và hình ảnh bằng chứng khi gửi yêu cầu hoàn tiền.
- *REQ-023:* Hệ thống phải tạm khóa bộ đếm ngược Escrow của đơn hàng và chuyển trạng thái đơn hàng sang "Yêu cầu Trả hàng".

*UC-007: Khiếu nại và Tranh chấp & UC-008: Phân xử tranh chấp*
- *REQ-024:* Hệ thống phải cho phép User bán bấm "Từ chối trả hàng" để chuyển đơn hàng sang trạng thái "Đang tranh chấp" trong vòng 48 giờ kể từ khi có khiếu nại.
- *REQ-025:* Hệ thống phải hiển thị toàn bộ hồ sơ tranh chấp (bao gồm video/hình ảnh mở hộp của Buyer và đóng gói của Seller) cho Moderator.
- *REQ-026:* Hệ thống phải tự động giải phóng dòng tiền từ ví Escrow (hoàn trả cho Buyer hoặc giải ngân cho Seller) dựa trên phán quyết của Moderator.

*UC-009: Đánh giá & Phản hồi*
- *REQ-027:* Hệ thống phải cho phép User mua đánh giá sao và viết phản hồi cho User bán sau khi đơn hàng được hoàn tất.

*UC-010: Cấp phát tài khoản Moderator*
- *REQ-028:* Hệ thống phải cho phép duy nhất Admin tối cao tạo tài khoản Moderator bằng cách nhập Email và thông tin nhân sự.
- *REQ-029:* Hệ thống phải tự động gửi mật khẩu tạm thời ngẫu nhiên và liên kết kích hoạt tài khoản qua Email cho Moderator mới.

*UC-011: Tìm kiếm & Duyệt sản phẩm*
- *REQ-030:* Hệ thống phải cho phép User tìm kiếm sản phẩm bằng từ khóa ngôn ngữ tự nhiên và trả về kết quả xếp hạng theo độ liên quan.
- *REQ-031:* Hệ thống phải cho phép lọc kết quả theo danh mục, khoảng giá, tình trạng sản phẩm và sắp xếp theo mới nhất / giá / độ phổ biến.
- *REQ-032:* Hệ thống phải hiển thị danh sách "Gợi ý cho bạn" dựa trên lịch sử tương tác của User.

*UC-012: Người bán xử lý đơn hàng đến*
- *REQ-033:* Hệ thống phải hiển thị cho User bán danh sách các mục chờ (pending item) mà người mua đã đặt, kèm thông tin sản phẩm và địa chỉ giao.
- *REQ-034:* Hệ thống phải cho phép User bán xem trước phí vận chuyển (quote) rồi *xác nhận* để tạo đơn hàng + vận đơn, hoặc *từ chối* để giải phóng tồn kho đã giữ.
- *REQ-035:* Hệ thống phải tự động giải phóng tồn kho đã reserve nếu User bán không xác nhận mục chờ trong thời hạn quy định.

*UC-013: Ví điện tử & Rút tiền*
- *REQ-036:* Hệ thống phải hiển thị số dư ví của User gồm *số dư khả dụng* và *số dư đang tạm giữ (Escrow)*, kèm lịch sử biến động số dư (income history).
- *REQ-037:* Hệ thống phải cho phép User bán gửi yêu cầu rút phần *số dư khả dụng* về tài khoản ngân hàng đã đăng ký; không cho phép rút phần đang tạm giữ trong Escrow.
- *REQ-038:* Hệ thống phải ghi log bất biến (append-only) mọi yêu cầu rút tiền và chỉ trừ số dư khả dụng *sau khi* lệnh chi được xác nhận thành công.

=== Ma trận CRUD
Ma trận dưới đây xác định các yêu cầu chức năng bao phủ toàn bộ các thao tác Create, Read, Update, Delete đối với các thực thể cốt lõi trong hệ thống ShopNexus C2C:

#figure(kind: table, caption: [Ma trận CRUD])[
#table(
  columns: (1.6fr, 1.15fr, 1fr, 1.35fr, 0.9fr),
  align: (center, center, center, center, center),
  [Thực Thể], [Create (Tạo)], [Read (Đọc)], [Update (Cập Nhật)], [Delete (Xóa)],
  [Account (Tài khoản)], [REQ-001, REQ-005], [REQ-006], [REQ-029 (Đổi MK)], [N/A (Chỉ Khóa)],
  [Product (Sản phẩm)], [REQ-010, REQ-011], [REQ-012], [REQ-012], [REQ-012],
  [Order (Đơn hàng)], [REQ-016], [REQ-017], [REQ-019 (Khóa Escrow)], [REQ-020 (Hủy đơn)],
  [Chat / Offer Card], [REQ-013, REQ-015], [REQ-014], [REQ-016 (Chấp nhận)], [N/A],
  [Dispute / Refund], [REQ-021, REQ-022], [REQ-025], [REQ-024, REQ-026], [N/A],
  [Moderator Account], [REQ-028], [REQ-008], [REQ-029], [N/A (Chỉ Khóa)],
  [Pending / Xử lý đơn (Seller)], [REQ-033 (checkout)], [REQ-033], [REQ-034 (Xác nhận)], [REQ-035 (Từ chối)],
  [Ví (Wallet)], [REQ-001 (khởi tạo)], [REQ-036], [REQ-037, REQ-038 (Rút)], [N/A],
  [Tìm kiếm / Gợi ý], [Tự động (embedding)], [REQ-030, REQ-031, REQ-032], [REQ-032 (re-embed)], [N/A],
)
]

=== Ma Trận Truy Xuất Nguồn Gốc (Traceability Matrix)
Ma trận truy xuất nguồn gốc giúp theo dõi mối quan hệ giữa Yêu cầu chức năng, Use Case nguồn và thực thể CSDL bị ảnh hưởng:

#figure(kind: table, caption: [Ma Trận Truy Xuất Nguồn Gốc (Traceability Matrix)])[
#table(
  columns: (1fr, 1.4fr, 1.9fr),
  align: (center, center, left),
  [ID Yêu Cầu], [Trường Hợp Sử Dụng Nguồn], [Thực Thể Ảnh Hưởng],
  [REQ-001 - REQ-005], [UC-001: Đăng ký tài khoản], [Account, Wallet],
  [REQ-006 - REQ-009], [UC-002: Đăng nhập], [Account],
  [REQ-010 - REQ-012], [UC-003: Đăng bán sản phẩm C2C], [Product, Category],
  [REQ-013 - REQ-016], [UC-004: Nhắn tin trực tuyến], [ChatMessage, OfferCard, Order],
  [REQ-017 - REQ-020], [UC-005: Đặt hàng & Thanh toán], [Order, EscrowWallet, PaymentSession],
  [REQ-021 - REQ-023], [UC-006: Yêu cầu Trả hàng], [Order, RefundRequest, Transport],
  [REQ-024], [UC-007: Khiếu nại và Tranh chấp], [Order, DisputeCase],
  [REQ-025 - REQ-026], [UC-008: Phân xử tranh chấp], [DisputeCase, WalletTransaction],
  [REQ-027], [UC-009: Đánh giá & Phản hồi], [ProductReview],
  [REQ-028 - REQ-029], [UC-010: Cấp phát tài khoản], [Account, AuditLog],
  [REQ-030 - REQ-032], [UC-011: Tìm kiếm & Duyệt], [ProductEmbedding (catalog), Interaction (analytic)],
  [REQ-033 - REQ-035], [UC-012: Người bán xử lý đơn], [Item, Order (order), Stock (inventory)],
  [REQ-036 - REQ-038], [UC-013: Ví & Rút tiền], [Profile.internal_balance, IncomeHistory, Transaction],
)
]

== Yêu Cầu Phi Chức Năng

Các thuộc tính chất lượng và ràng buộc kỹ thuật của hệ thống ShopNexus C2C được mô tả bằng các yêu cầu phi chức năng (Non-Functional Requirements, NFR) đo lường được dưới đây:

=== Hiệu năng (Performance)
- *NFR-001:* API gọi dịch vụ bên thứ ba (cổng thanh toán, đối tác vận chuyển) phải có timeout và cơ chế retry trước khi báo lỗi cho người dùng.

=== Bảo mật (Security)

*a) Xác thực & Quản lý phiên*
- *NFR-002:* Mật khẩu tài khoản người dùng phải được băm bằng thuật toán Bcrypt trước khi lưu vào cơ sở dữ liệu; hệ thống không bao giờ lưu trữ hoặc log mật khẩu dạng plaintext.
- *NFR-003:* Access token (JWT) phải có thời gian sống ngắn (tối đa 15-30 phút), ký bằng thuật toán HMAC-SHA256 (HS256) hoặc RSA (RS256); kèm Refresh token có thời gian sống dài hơn (tối đa 7 ngày), lưu dưới dạng hash trong CSDL và có thể thu hồi (revoke) khi cần.
- *NFR-004:* Hệ thống phải khóa tạm thời tài khoản (account lockout) sau tối đa 5 lần đăng nhập sai liên tiếp trong 15 phút, kèm cơ chế rate-limit theo IP để chống tấn công brute-force.

*b) Kiểm soát truy cập*
- *NFR-005:* Áp dụng kiểm soát truy cập dựa trên vai trò (RBAC) ở tầng API Gateway/Ingress: mọi endpoint quản trị và phân xử tranh chấp chỉ chấp nhận token có claim vai trò `Moderator` tương ứng.
- *NFR-006:* Áp dụng kiểm soát truy cập cấp đối tượng (Object-level Authorization): người dùng chỉ được đọc/sửa tài nguyên thuộc sở hữu của mình (VD: đơn hàng, ví, bài đăng); mọi request phải được xác minh quyền sở hữu ở tầng service, không chỉ dựa vào role.

*c) Chống tấn công tầng ứng dụng*
- *NFR-007:* Toàn bộ input từ người dùng phải được validate và sanitize ở tầng API để chống SQL Injection, XSS và Command Injection; sử dụng prepared statement/ORM cho mọi truy vấn CSDL, không nối chuỗi SQL thủ công.
- *NFR-008:* Áp dụng rate-limiting theo IP/tài khoản cho các API nhạy cảm (đăng ký, đăng nhập, tạo Offer Card, gửi yêu cầu Refund) để chống tấn công DoS/spam ở tầng ứng dụng.

*d) Kiểm toán & Bảo mật dòng tiền*
- *NFR-009:* Mọi thao tác làm thay đổi số dư ví (khóa Escrow, giải ngân, hoàn tiền) phải được ghi log bất biến (append-only audit log) kèm timestamp, actor thực hiện và trạng thái trước/sau, phục vụ đối soát và điều tra khi có tranh chấp.
- *NFR-010:* Các thao tác nhạy cảm của Admin/Moderator (cấp phát tài khoản, phán quyết tranh chấp, gỡ bài đăng) phải được ghi log riêng và không thể chỉnh sửa/xóa sau khi đã tạo.

=== Khả năng sử dụng (Usability)
- *NFR-011:* Giao diện Web phải responsive, hiển thị đúng bố cục trên độ phân giải từ 360px (mobile) đến 1920px (desktop), theo nguyên tắc mobile-first.
- *NFR-012:* Giao diện phải tuân thủ nguyên tắc accessibility cơ bản (WCAG 2.1 mức A tối thiểu): độ tương phản màu chữ/nền đạt chuẩn, mọi hình ảnh có alt-text, có thể thao tác bằng bàn phím cho các luồng chính.
- *NFR-013:* Mọi thao tác quan trọng có thể gây hậu quả không thể hoàn tác (xác nhận nhận hàng, chấp nhận Offer Card, xác nhận thanh toán) phải có bước xác nhận rõ ràng (confirmation dialog) kèm cảnh báo nội dung tương ứng.

=== Ràng buộc (Constraints)
- *NFR-014:* Việc tính phí và theo dõi vận chuyển phụ thuộc vào API của đối tác vận chuyển bên thứ ba (GHN/GHTK); độ chính xác và thời gian phản hồi bị giới hạn bởi SLA của đối tác, không hoàn toàn nằm trong tầm kiểm soát của hệ thống.
- *NFR-015:* Việc xác nhận giao dịch thanh toán phụ thuộc vào cơ chế IPN/webhook của cổng thanh toán bên thứ ba (SePay/Stripe); hệ thống phải xử lý được các trường hợp webhook đến trễ hoặc không đến (cần cơ chế đối soát/polling dự phòng).
- *NFR-016:* Hệ thống phải tuân thủ quy định pháp luật Việt Nam hiện hành về giao dịch thương mại điện tử và bảo vệ dữ liệu cá nhân (VD: Nghị định 13/2023/NĐ-CP) đối với thông tin định danh, số điện thoại, địa chỉ giao hàng thu thập từ người dùng.

== Mô Phỏng UI

=== Danh sách màn hình chính
Để hỗ trợ toàn bộ các luồng nghiệp vụ C2C an toàn, hệ thống ShopNexus thiết kế 10 giao diện màn hình chính:
1. *Screen-01: Giao diện Đăng nhập & Đăng ký* (Xác thực người dùng).
2. *Screen-02: Trang chi tiết sản phẩm C2C* (Hỗ trợ nút phân luồng "Mua ngay" hoặc "Mua ngay / Thương lượng").
3. *Screen-03: Khung Chat & Đàm phán giá* (Tích hợp Offer Card trực quan và lý do giảm giá).
4. *Screen-04: Trang xác nhận Đặt hàng & Thanh toán Escrow* (Tích hợp API phí ship động).
5. *Screen-05: Trang gửi yêu cầu Trả hàng / Hoàn tiền* (Yêu cầu tải lên video mở hộp).
6. *Screen-06: Bảng điều khiển phân xử tranh chấp của Moderator* (Thẩm định bằng chứng và ra phán quyết).
7. *Screen-07: Giao diện quản lý cấp phát tài khoản Moderator của Admin* (Tạo tài khoản không qua đăng ký công khai).
8. *Screen-08: Trang kết quả tìm kiếm & bộ lọc* (Tìm kiếm hybrid bge-m3, lọc danh mục/giá/tình trạng).
9. *Screen-09: Bảng điều khiển Người bán* (Danh sách mục chờ xác nhận + listing đang bán).
10. *Screen-10: Ví điện tử & Rút tiền* (Số dư khả dụng / tạm giữ Escrow và yêu cầu rút tiền).

=== Bản vẽ Wireframe UI
#grid(
  columns: (1fr, 1fr),
  column-gutter: 15pt,
  row-gutter: 15pt,

  wireframe("Screen-01: Đăng nhập & Đăng ký")[
    #v(5pt)
    #align(center)[
      #block(width: 85%)[
        [ LOGO SHOPNEXUS ] \
        #v(10pt)
        #rect(width: 100%, height: 16pt, stroke: 0.5pt + ink, radius: 2pt, align(center + horizon, text(size: 8pt)[Tab: Đăng nhập | Tab: Đăng ký (User)]))
        #v(8pt)
        #grid(
          columns: (50pt, 1fr),
          row-gutter: 8pt,
          [Email:], rect(width: 100%, height: 12pt, stroke: 0.5pt + ink),
          [Mật khẩu:], rect(width: 100%, height: 12pt, stroke: 0.5pt + ink),
        )
        #v(10pt)
        #grid(
          columns: (1fr, 1fr),
          column-gutter: 10pt,
          rect(width: 100%, height: 15pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 8pt)[Đăng nhập])),
          rect(width: 100%, height: 15pt, stroke: 0.5pt + ink, radius: 2pt, align(center + horizon, text(size: 8pt)[Quên mật khẩu]))
        )
      ]
    ]
  ],
  wireframe("Screen-02: Chi tiết sản phẩm C2C")[
    #v(3pt)
    #grid(
      columns: (1fr, 1.2fr),
      column-gutter: 8pt,
      rect(width: 100%, height: 60pt, stroke: 0.5pt + ink, align(center + horizon, text(size: 7.5pt)[Ảnh thực tế sản phẩm])),
      stack(spacing: 4pt,
        text(weight: 700, size: 9pt)[iPhone 13 Pro Max cũ],
        text(fill: red, weight: 700, size: 8.5pt)[Giá: 12.500.000 đ],
        text(size: 7.5pt)[Chế độ: Thương lượng (~)],
        text(size: 7pt, fill: muted)[Mô tả: Máy đẹp 98%, pin 85%, giao dịch trực tiếp hoặc COD tạm giữ Escrow.],
      )
    )
    #v(8pt)
    #grid(
      columns: (1fr, 1.2fr),
      column-gutter: 10pt,
      rect(width: 100%, height: 18pt, stroke: 0.5pt + ink, radius: 2pt, align(center + horizon, text(size: 7.5pt)[Chat với Người bán])),
      rect(width: 100%, height: 18pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 7.5pt, weight: 700)[Mua ngay / Thương lượng]))
    )
  ],

  wireframe("Screen-03: Khung Chat & Offer Card")[
    #rect(width: 100%, height: 15pt, fill: headfill, align(center + horizon, text(size: 8pt, weight: 700)[Chat: Nguyễn Văn A (Seller)]) )
    #v(4pt)
    #rect(width: 80%, height: 25pt, stroke: 0.5pt + ink, radius: 4pt, inset: 4pt, align(left)[
      #text(size: 7pt)[Buyer: Chào bạn, máy pin còn bao nhiêu phần trăm vậy?]
    ])
    #v(4pt)
    // Offer Card
    #align(right)[
      #block(width: 85%, stroke: 1pt + ink, fill: headfill, inset: 5pt, radius: 4pt)[
        #align(center)[#text(size: 7.5pt, weight: 700)[OFFER CARD (ĐỀ XUẤT GIÁ)]]
        #line(length: 100%, stroke: 0.3pt + hairline)
        #align(left)[
          #text(size: 7pt)[- Giá cũ: 12.500.000 đ] \
          #text(size: 7pt)[- Giá mới đề xuất: *12.200.000 đ*] \
          #text(size: 7pt)[- Lý do: Bớt 300k hỗ trợ phí ship & mua phụ kiện]
        ]
        #v(3pt)
        #grid(
          columns: (1fr, 1fr),
          column-gutter: 5pt,
          rect(width: 100%, height: 12pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 6.5pt)[Chấp nhận])),
          rect(width: 100%, height: 12pt, stroke: 0.5pt + ink, radius: 2pt, align(center + horizon, text(size: 6.5pt)[Từ chối]))
        )
      ]
    ]
    #v(4pt)
    #grid(
      columns: (1fr, 45pt),
      column-gutter: 5pt,
      rect(width: 100%, height: 15pt, stroke: 0.5pt + ink, align(left + horizon, text(size: 7pt, fill: muted)[ Nhập tin nhắn...])),
      rect(width: 100%, height: 15pt, fill: ink, align(center + horizon, text(fill: white, size: 7pt)[Gửi]))
    )
  ],

  wireframe("Screen-04: Đặt hàng & Thanh toán Escrow")[
    #v(3pt)
    #text(weight: 700, size: 9pt)[THÔNG TIN ĐƠN HÀNG \#1092]
    #line(length: 100%, stroke: 0.5pt + hairline)
    #grid(
      columns: (50pt, 1fr),
      row-gutter: 6pt,
      [Sản phẩm:], [iPhone 13 Pro Max (Thương lượng)],
      [Giá hàng:], [12.200.000 đ],
      [Địa chỉ:], [97 Man Thiện, Quận 9, TP. HCM],
      [Phí ship:], [35.000 đ (Tính tự động qua GHN API)],
      [Tổng thanh toán:], text(fill: red, weight: 700)[12.235.000 đ],
    )
    #line(length: 100%, stroke: 0.5pt + hairline)
    #text(size: 7.5pt, style: "italic", fill: muted)[*Lưu ý:* Tiền của bạn sẽ được khóa an toàn trong ví Escrow trung gian trong 3 ngày để bảo vệ quyền lợi của bạn.]
    #v(4pt)
    #rect(width: 100%, height: 18pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 8pt, weight: 700)[Thanh toán tạm giữ (SePay/Stripe)]))
  ],

  wireframe("Screen-05: Yêu cầu Trả hàng / Hoàn tiền")[
    #v(3pt)
    #text(weight: 700, size: 9pt)[GỬI KHIẾU NẠI TRẢ HÀNG / HOÀN TIỀN]
    #v(5pt)
    #grid(
      columns: (50pt, 1fr),
      row-gutter: 8pt,
      [Lý do khiếu nại:], rect(width: 100%, height: 12pt, stroke: 0.5pt + ink, align(left + horizon, text(size: 7pt)[ Hàng lỗi, không đúng mô tả])),
      [Mô tả chi tiết:], rect(width: 100%, height: 25pt, stroke: 0.5pt + ink, align(left, text(size: 7pt)[ Máy bị sọc màn hình khi nhận, không giống ảnh])),
    )
    #v(6pt)
    #rect(width: 100%, height: 35pt, stroke: (paint: ink, dash: "dashed"), align(center + horizon)[
      #text(size: 7.5pt, weight: 700)[+ Tải lên Video mở hộp & ảnh lỗi (Bắt buộc)] \
      #text(size: 6.5pt, fill: muted)[(Định dạng MP4, JPG, PNG tối đa 50MB)]
    ])
    #v(6pt)
    #rect(width: 100%, height: 18pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 8pt)[Xác nhận gửi yêu cầu hoàn tiền]))
  ],

  wireframe("Screen-06: Bảng điều khiển tranh chấp (Mod)")[
    #rect(width: 100%, height: 15pt, fill: headfill, align(center + horizon, text(size: 8pt, weight: 700)[PHÂN HỆ ĐIỀU PHỐI VIÊN (MODERATOR)]) )
    #v(4pt)
    #text(weight: 700, size: 8.5pt)[Vụ tranh chấp \#DS-8821 (Đơn hàng \#1092)]
    #grid(
      columns: (1fr, 1fr),
      column-gutter: 8pt,
      rect(width: 100%, height: 45pt, stroke: 0.5pt + ink, inset: 3pt, align(left)[
        #text(size: 6.5pt, weight: 700)[Bằng chứng Buyer:] \
        #text(size: 6.5pt)[- Video: [unboxing.mp4]] \
        #text(size: 6.5pt)[- Lý do: Màn hình bị sọc]
      ]),
      rect(width: 100%, height: 45pt, stroke: 0.5pt + ink, inset: 3pt, align(left)[
        #text(size: 6.5pt, weight: 700)[Bằng chứng Seller:] \
        #text(size: 6.5pt)[- Video: [packaging.mp4]] \
        #text(size: 6.5pt)[- Lý do: Đóng gói máy nguyên vẹn]
      ])
    )
    #v(5pt)
    #grid(
      columns: (1fr, 1fr),
      column-gutter: 8pt,
      rect(width: 100%, height: 15pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 7pt)[Hoàn tiền cho Buyer])),
      rect(width: 100%, height: 15pt, fill: headfill, stroke: 0.5pt + ink, radius: 2pt, align(center + horizon, text(size: 7pt)[Giải ngân cho Seller]))
    )
  ],

  wireframe("Screen-07: Admin cấp phát tài khoản Mod")[
    #rect(width: 100%, height: 15pt, fill: headfill, align(center + horizon, text(size: 8pt, weight: 700)[PHÂN HỆ QUẢN TRỊ VIÊN TỐI CAO (ADMIN)]) )
    #v(5pt)
    #text(weight: 700, size: 8.5pt)[CẤP PHÁT TÀI KHOẢN MODERATOR MỚI]
    #v(5pt)
    #grid(
      columns: (50pt, 1fr),
      row-gutter: 8pt,
      [Họ và tên:], rect(width: 100%, height: 12pt, stroke: 0.5pt + ink),
      [Email:], rect(width: 100%, height: 12pt, stroke: 0.5pt + ink),
      [Số ĐT:], rect(width: 100%, height: 12pt, stroke: 0.5pt + ink),
    )
    #v(8pt)
    #rect(width: 100%, height: 18pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 8pt, weight: 700)[Cấp phát & Gửi Email kích hoạt]))
  ],

  wireframe("Screen-08: Kết quả tìm kiếm & bộ lọc")[
    #rect(width: 100%, height: 15pt, stroke: 0.5pt + ink, radius: 2pt, align(left + horizon, text(size: 7.5pt, fill: muted)[ Tìm: iphone 13 pro max cũ ...]))
    #v(5pt)
    #grid(
      columns: (0.9fr, 1.6fr),
      column-gutter: 8pt,
      stack(spacing: 5pt,
        text(size: 7pt, weight: 700)[Bộ lọc],
        text(size: 6.5pt)[[ ] Danh mục: Điện thoại],
        text(size: 6.5pt)[[ ] Giá: 5–15 triệu],
        text(size: 6.5pt)[[ ] Tình trạng: Đã dùng],
        text(size: 6.5pt, fill: muted)[Sắp xếp: Liên quan (v)],
      ),
      stack(spacing: 5pt,
        rect(width: 100%, height: 20pt, stroke: 0.5pt + ink, inset: 3pt, align(horizon, text(size: 6.5pt)[[ảnh] iPhone 13 Pro Max, 12.500.000đ · ~thương lượng])),
        rect(width: 100%, height: 20pt, stroke: 0.5pt + ink, inset: 3pt, align(horizon, text(size: 6.5pt)[[ảnh] iPhone 13 Pro, 9.800.000đ · giá cố định])),
        rect(width: 100%, height: 20pt, stroke: 0.5pt + ink, inset: 3pt, align(horizon, text(size: 6.5pt)[[ảnh] iPhone 13, 7.200.000đ · giá cố định])),
      )
    )
    #v(4pt)
    #text(size: 6.5pt, style: "italic", fill: muted)[Xếp hạng theo độ liên quan (bge-m3 hybrid: dense + sparse).]
  ],

  wireframe("Screen-09: Bảng điều khiển Người bán")[
    #rect(width: 100%, height: 15pt, fill: headfill, align(center + horizon, text(size: 8pt, weight: 700)[NGƯỜI BÁN, ĐƠN ĐẾN CHỜ XÁC NHẬN]))
    #v(4pt)
    #rect(width: 100%, height: 34pt, stroke: 0.5pt + ink, inset: 4pt, align(left)[
      #text(size: 6.5pt, weight: 700)[Mục chờ \#PI-3310] \
      #text(size: 6.5pt)[iPhone 13 Pro Max ×1 → 97 Man Thiện, Q9] \
      #text(size: 6.5pt, fill: muted)[Phí ship (quote GHN): 35.000đ · Tổng: 12.235.000đ]
    ])
    #v(5pt)
    #grid(
      columns: (1fr, 1fr),
      column-gutter: 8pt,
      rect(width: 100%, height: 15pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 7pt)[Xác nhận & Tạo đơn])),
      rect(width: 100%, height: 15pt, stroke: 0.5pt + ink, radius: 2pt, align(center + horizon, text(size: 7pt)[Từ chối (nhả kho)]))
    )
    #v(4pt)
    #text(size: 6.5pt, fill: muted)[Listing đang bán: 4 · Đã bán: 12 · Đánh giá: 4.8/5]
  ],

  wireframe("Screen-10: Ví điện tử & Rút tiền")[
    #v(3pt)
    #grid(
      columns: (1fr, 1fr),
      column-gutter: 8pt,
      rect(width: 100%, height: 30pt, stroke: 0.5pt + ink, inset: 4pt, align(left)[
        #text(size: 6.5pt, fill: muted)[Số dư khả dụng] \
        #text(size: 10pt, weight: 700)[8.450.000 đ]
      ]),
      rect(width: 100%, height: 30pt, stroke: (paint: ink, dash: "dashed"), inset: 4pt, align(left)[
        #text(size: 6.5pt, fill: muted)[Đang tạm giữ (Escrow)] \
        #text(size: 10pt, weight: 700)[12.235.000 đ]
      ])
    )
    #v(5pt)
    #text(size: 6.5pt, weight: 700)[Lịch sử gần đây]
    #text(size: 6.5pt)[+ Giải ngân đơn \#1080 · − Rút về Vietcombank (VCB)]
    #v(5pt)
    #rect(width: 100%, height: 18pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 8pt, weight: 700)[Yêu cầu rút (chỉ số dư khả dụng)]))
  ]
)

=== Sơ đồ luồng điều hướng
Sơ đồ dưới đây biểu diễn luồng di chuyển của người dùng qua các giao diện màn hình chính từ bước đăng nhập, phân luồng mua sản phẩm cố định hay thương lượng, cho đến thanh toán Escrow, hoàn tiền và phân xử tranh chấp:

#fig(
  [Sơ đồ luồng điều hướng màn hình hệ thống ShopNexus C2C (Navigation Flow Diagram)],
  spacing: (40mm, 9mm),
  // main spine đi dọc trên cột x = 0; các nhánh rẽ sang phải (x = 2)
  nt((0, 0), [Login / Register\ (Screen-01)]),
  np((2, 0), [Admin Provisioning\ (Screen-07)]),
  edge((2, 0), (0, 0), "-|>", stroke: (paint: ink, thickness: 1pt, dash: "dashed"), text(size: 7.5pt)[Tạo & Email mật khẩu]),

  edge((0, 0), (0, 1), "-|>"),
  np((0, 1), [Trang chủ / Sản phẩm]),
  edge((0, 1), (0, 2), "-|>"),
  np((0, 2), [Chi tiết sản phẩm\ (Screen-02)]),

  edge((0, 2), (0, 3), "-|>", text(size: 8pt)[Giá cố định]),
  edge((0, 2), (2, 3), "-|>", text(size: 8pt)[Giá thương lượng]),
  np((2, 3), [Khung Chat & Offer Card\ (Screen-03)]),
  edge((2, 3), (0, 3), "-|>", text(size: 8pt)[Chấp nhận Offer]),

  np((0, 3), [Xác nhận & Thanh toán\ (Screen-04)]),
  edge((0, 3), (0, 4), "-|>", text(size: 8pt)[Thành công]),
  ng((0, 4), [Ví Escrow khóa tiền]),
  edge((0, 4), (0, 5), "-|>"),
  np((0, 5), [Đơn hàng đã giao]),
  edge((0, 5), (0, 6), "-|>"),

  nd((0, 6), [Hết 3 ngày?]),
  edge((0, 6), (2, 6), "-|>", text(size: 8pt)[Có]),
  ng((2, 6), [Giải ngân Seller]),
  edge((0, 6), (0, 7), "-|>", text(size: 8pt)[Khiếu nại]),
  np((0, 7), [Yêu cầu Trả hàng\ (Screen-05)]),
  edge((0, 7), (0, 8), "-|>"),

  nd((0, 8), [Seller đồng ý?]),
  edge((0, 8), (2, 8), "-|>", text(size: 8pt)[Có]),
  ng((2, 8), [Hoàn tiền Buyer]),
  edge((0, 8), (0, 9), "-|>", text(size: 8pt)[Không]),
  np((0, 9), [Tranh chấp (Dispute)]),
  edge((0, 9), (0, 10), "-|>"),
  np((0, 10), [Moderator phân xử\ (Screen-06)]),
  edge((0, 10), (2, 10), "-|>"),
  ng((2, 10), [Quyết định cuối cùng]),
)


// ============================================================
= Thiết kế kiến trúc hệ thống

== Trích Xuất Các Yếu Tố Kiến Trúc

Kiến trúc của hệ thống ShopNexus C2C được định hình trực tiếp bởi các thuộc tính chất lượng (Quality Attributes) trọng yếu và các ràng buộc (Constraints) được trích xuất dưới đây:

=== Các thuộc tính chất lượng quan trọng (Quality Attributes)

- *Tính đúng đắn & khả năng phục hồi của luồng tài chính dài hạn (Durability & Reliability):*
  Các luồng nghiệp vụ Escrow (khóa tiền → đếm ngược 3 ngày → giải ngân/hoàn tiền/dispute)
  kéo dài qua nhiều bước và nhiều ngày, có thể bị gián đoạn bởi crash service, restart
  pod, hoặc lỗi mạng giữa chừng. Kiến trúc phải đảm bảo trạng thái không bị mất và
  không xử lý trùng lặp khi phục hồi sau lỗi.

- *Bảo mật dòng tiền & khả năng đối soát (Escrow Security & Auditability):*
  Dòng tiền tạm giữ là cốt lõi xây dựng lòng tin trên sàn. Mọi biến động số dư ví
  Escrow/ví khả dụng phải được ghi log bất biến (audit trail), có thể truy vết đầy đủ
  ai/khi nào/thay đổi gì, phục vụ đối soát và xử lý tranh chấp. *(Liên hệ: NFR-009, NFR-010)*

- *Khả năng mở rộng độc lập theo dịch vụ (Independent Scalability):*
  Lượng truy cập dao động mạnh theo giờ cao điểm đặc
  biệt ở Chat Service (realtime) và Catalog Service (đọc nhiều). Kiến trúc phải cho
  phép scale từng service độc lập mà không cần nhân bản toàn hệ thống.

- *Tính độc lập & cô lập lỗi giữa các dịch vụ (Modularity & Fault Isolation):*
  Các nghiệp vụ Thanh toán/Escrow (order), Nhắn tin (chat), Quản lý sản phẩm & Tìm kiếm
  (catalog), Tồn kho (inventory) và Phân tích hành vi (analytic) có logic nghiệp vụ và chu
  kỳ thay đổi khác nhau. Việc tách module giúp lỗi ở một service (VD: Chat) không lan sang
  luồng đặt hàng/thanh toán. Lưu ý: *kiểm duyệt và phân xử tranh chấp không phải một service
  riêng* mà là hành động của vai trò Moderator/Admin thao tác trên hồ sơ tranh chấp trong
  module `order` (`order.refund_dispute`) và trên listing trong module `catalog`.

- *Tính nhất quán dữ liệu (Data Consistency):*
  Dùng mô hình CSDL riêng theo từng service để tối ưu hiệu năng, nhưng vẫn phải đảm
  bảo tính nhất quán cuối cùng (eventual consistency) khi trạng thái đơn hàng chuyển
  đổi (VD: Đã giao → Tranh chấp → Hoàn tiền), không để tiền và trạng thái đơn hàng
  lệch pha nhau.

- *Khả năng quan sát hệ thống (Observability):*
  Với kiến trúc phân tán nhiều service giao tiếp qua Ingress và message bus, cần khả
  năng theo dõi end-to-end một giao dịch (trace) đi qua các service để debug và phục
  vụ đối soát khi có khiếu nại. *(Liên hệ: NFR-009)*

=== Các ràng buộc chính (Key Constraints)

- *Ràng buộc tích hợp bên thứ ba (Third-party Integration Constraints):* Hệ thống
  bắt buộc phải tích hợp với cổng thanh toán SePay/Stripe và đối tác vận chuyển
  GHN/GHTK theo yêu cầu nghiệp vụ; kiến trúc phải chấp nhận các giới hạn về API,
  độ trễ phản hồi và cơ chế xác nhận (IPN/webhook) do các bên thứ ba này quy định,
  không thể tự thay đổi.
- *Ràng buộc nguồn lực (Resource Constraints):* Dự án được phát triển và hoàn thiện
  bởi nhóm 3 sinh viên trong thời gian thực tập 8 tuần. Kiến trúc thiết kế phải
  cân bằng giữa tính hiện đại và tính khả thi trong thực thi thực tế.
- *Ràng buộc kỹ năng (Skill Constraints):* Nhóm cần thời gian làm quen với công
  nghệ mới lựa chọn để triển khai, ít tài liệu/cộng đồng tiếng
  Việt hỗ trợ, cần cân nhắc rủi ro tiến độ khi áp dụng công nghệ chưa quen thuộc
  cho toàn bộ hệ thống thay vì chỉ các luồng thực sự cần thiết.


== Chọn Stack Công Nghệ

Dựa trên các yếu tố kiến trúc và ràng buộc đã trích xuất ở DOC 4.1-A, nhóm chốt stack công nghệ chi tiết cho hệ thống ShopNexus C2C như sau:

=== Tổng quan công nghệ
#figure(kind: table, caption: [Tổng quan công nghệ])[
#table(
  columns: (1.15fr, 1.35fr, 1.1fr, 2.4fr),
  align: (center, center, center, left),
  [Tầng / Lớp], [Công Nghệ], [Phiên Bản], [Mục Đích Sử Dụng],
  [Frontend Web], [Next.js, TypeScript], [14.x / React 18], [Xây dựng giao diện web cho User, Moderator, Admin, hỗ trợ SSR/SSG cho trang sản phẩm.],
  [Frontend Mobile], [Flutter, Dart], [3.x], [Ứng dụng di động cho User: mua/bán, chat, thanh toán, dùng chung API backend với Web.],
  [Backend Services], [Go], [1.22+], [Phát triển các dịch vụ nghiệp vụ cốt lõi, tận dụng concurrency mạnh và hiệu năng cao của Go.],
  [Database (Relational)], [PostgreSQL], [16.x], [Lưu trữ dữ liệu có tính toàn vẹn cao (Account, Order, Payment/Escrow, Refund, Dispute), tách schema theo từng service.],
  [Tìm kiếm ngữ nghĩa (Vector)], [pgvector + bge-m3], [pgvector 0.7 / bge-m3], [Tìm kiếm sản phẩm hybrid (dense + sparse) ngay trong PostgreSQL; embedding văn bản sinh bằng model bge-m3, không cần vận hành vector DB riêng.],
  [In-Memory Caching], [Redis], [7.x], [Lưu trữ phiên đăng nhập, bộ đệm dữ liệu truy vấn nóng (sản phẩm hot, trạng thái chat).],
  [Event Bus], [NATS JetStream], [2.10.x], [Giao tiếp bất đồng bộ nhẹ giữa các service (sự kiện đơn hàng, thanh toán, thông báo), đủ persistence/replay mà không nặng như Kafka.],
  [Containerization & Orchestration], [Docker, Kubernetes (k8s)], [N/A], [Đóng gói và điều phối triển khai toàn bộ hệ thống, tự động scale và health-check từng service.],
)
]

=== Lý giải lựa chọn stack công nghệ

Mỗi công nghệ trong stack đều có lựa chọn thay thế phổ biến hơn. Thay vì so sánh từng tiêu chí một, phần này tập trung nêu *lý do chính* khiến nhóm chọn từng công nghệ cho bối cảnh dự án (nhóm 3 người, 8 tuần, luồng tài chính Escrow dài hạn).

*Go cho Backend.* Lý do quyết định là sự kết hợp Go + Restate. Nhóm cần durable execution cho luồng Escrow/Dispute kéo dài nhiều ngày, mà SDK Go của Restate là SDK trưởng thành và được ưu tiên bảo trì nhất; khi đã chọn Restate làm nền tảng, Go là ngôn ngữ khai thác SDK đó tốt nhất. Ngoài ra Go biên dịch ra binary tĩnh nhỏ (~10-30MB RAM mỗi service), khởi động nhanh và có mô hình goroutine nhẹ, rất hợp khi Kubernetes scale-out thêm pod. So với NestJS (Node.js) hay Spring Boot (Java), Go có ít thư viện dựng sẵn hơn (không có ORM kiểu Hibernate hay DI container như Spring), nên nhóm chấp nhận viết thêm code ở lớp truy cập dữ liệu (SQLC + pgx). Đây là đánh đổi có chủ ý để đổi lấy binary gọn và tích hợp Restate mượt.

*Next.js cho Frontend Web.* Trang danh mục và chi tiết sản phẩm cần SEO để bot tìm kiếm index được, nên phải render phía server. Một SPA thuần (React + Vite) chỉ render phía client, bot sẽ thấy HTML trống và mất khả năng index; đây là lý do loại SPA thuần. Next.js có sẵn SSR/SSG, file-based routing và tự code-split theo route, lại dựa trên React mà nhóm đã quen, nên chi phí học chỉ là App Router chứ không phải một framework hoàn toàn mới. Nuxt (Vue) cũng có SSR nhưng hệ sinh thái UI nhỏ hơn và nhóm chưa quen Vue.

*Flutter cho Mobile.* Với 3 người trong 8 tuần, nhóm không thể duy trì hai codebase native (Swift + Kotlin), nên cần giải pháp một codebase. Flutter biên dịch ra mã native, tự vẽ UI qua Skia nên hiệu năng gần native và giao diện nhất quán trên cả iOS lẫn Android, ít gặp lỗi cầu nối (bridge) như React Native. Đánh đổi là phải học Dart, nhưng cú pháp Dart gần Java/Kotlin nên thời gian làm quen ngắn.

*PostgreSQL làm CSDL chính.* Order/Escrow/Wallet có quan hệ chặt và yêu cầu ACID thực sự, nên nhóm loại MongoDB (document-native, yếu về JOIN quan hệ và transaction đa bảng). PostgreSQL có ACID đầy đủ, transaction đa bảng mạnh, đồng thời hỗ trợ JSONB cho các trường cần schema linh hoạt (thuộc tính sản phẩm, dữ liệu khuyến mãi) nên không cần thêm một CSDL document riêng. Các tính năng như partial unique index và row-level locking cũng cần thiết cho Escrow và phương thức thanh toán.

*pgvector + bge-m3 cho tìm kiếm.* Hệ thống không phải sàn search-heavy: lượng truy vấn tìm kiếm không đủ lớn để bù chi phí vận hành một vector DB riêng như Milvus (thêm service, thêm pipeline đồng bộ dữ liệu, thêm điểm lỗi). pgvector giữ toàn bộ vector ngay trong PostgreSQL, dùng chung transaction/backup và cho phép lọc theo danh mục/giá/tồn kho trong cùng một truy vấn. Model bge-m3 sinh đồng thời vector dense và sparse nên một model duy nhất phủ cả tìm kiếm ngữ nghĩa lẫn từ khóa. Đánh đổi: khi dataset lên tới hàng chục triệu vector, ANN thuần của pgvector sẽ chậm hơn Milvus, nhưng ở quy mô dự án đây là đánh đổi hợp lý để bớt một hệ thống phải vận hành.

*NATS JetStream làm Event Bus.* Event bus của hệ thống chủ yếu để fan-out thông báo và đồng bộ trạng thái giữa vài service, không phải hệ event-streaming khối lượng lớn. Vì vậy Kafka (nặng, chạy trên JVM, cấu hình partition/retention phức tạp) là chi phí không tương xứng, còn RabbitMQ thì không replay được message sau khi đã ACK. NATS JetStream chỉ là một binary Go nhẹ, latency thấp, nhưng vẫn có persistence và replay theo stream khi một consumer khởi động lại. Riêng bộ đếm ngược Escrow 3 ngày không giao cho message broker mà giao cho durable timer của Restate.

*Redis cho caching/session.* Redis được chọn thay vì Memcached vì hỗ trợ nhiều kiểu dữ liệu (Sorted Set cho feed xếp hạng, Pub/Sub cho thông báo SSE, String cho session token) trong khi Memcached chỉ có key-value. Redis cũng có tùy chọn persistence (AOF/RDB) giảm mất session khi restart. Không dùng in-process cache vì nó không chia sẻ được giữa nhiều pod khi Kubernetes scale-out.

*Kubernetes cho triển khai.* Docker Compose đủ cho môi trường dev local nhưng không đáp ứng production vì thiếu auto-scaling, self-healing và rolling update. Kubernetes giải quyết cả ba qua HPA, liveness/readiness probe và rolling deployment. Đánh đổi là Kubernetes phức tạp hơn đáng kể; nhóm chấp nhận thời gian cấu hình để có hạ tầng ổn định cho bản demo cuối thực tập (và dùng k3s nhẹ cho môi trường demo, xem rủi ro R-01).

=== Rủi ro công nghệ và giải pháp giảm thiểu

Bảng dưới đây liệt kê các rủi ro kỹ thuật đã được nhận diện từ stack công nghệ đã chọn, đánh giá mức độ xác suất và tác động, kèm giải pháp giảm thiểu cụ thể. Các rủi ro được sắp xếp theo thứ tự ưu tiên xử lý (cao → thấp).

#figure(kind: table, caption: [Rủi ro công nghệ và giải pháp giảm thiểu])[
#table(
  columns: (0.4fr, 1.6fr, 0.5fr, 0.5fr, 2fr),
  align: (center, left, center, center, left),
  [*ID*], [*Rủi ro*], [*Xác suất*], [*Tác động*], [*Giải pháp giảm thiểu*],
  [R-01],
  [*Kubernetes, chi phí vận hành vượt dự kiến:* Kubernetes yêu cầu cấu hình không nhỏ (networking, probe, HPA, secret). Vận hành cụm k8s có thể chiếm 20-30% thời gian DevOps của nhóm, ít thời gian cho nghiệp vụ.],
  [Trung bình], [Cao],
  [Dùng *k3s* (Kubernetes nhẹ, single-node) thay vì k8s full cluster trong môi trường demo. Ưu tiên Docker Compose cho môi trường dev, chỉ dùng k3s cho staging/demo cuối. Event bus dùng *NATS JetStream* (một binary Go, cấu hình tối thiểu) nên gần như không thêm gánh nặng vận hành so với Kafka.],

  [R-02],
  [*Tích hợp bên thứ ba (SePay/Stripe, GHN/GHTK) không ổn định:* Cổng thanh toán và đối tác vận chuyển có thể trả lỗi hoặc timeout, webhook IPN đến trễ hoặc không đến. Nhóm không kiểm soát được SLA của bên thứ ba nên lỗi ngoài ý muốn có thể phá vỡ luồng checkout hoặc Escrow.],
  [Trung bình], [Cao],
  [Triển khai *Circuit Breaker* (timeout + retry có giới hạn) cho mọi lời gọi ra ngoài. Xây dựng *mock server* cho SePay/GHN ngay từ đầu để toàn bộ luồng có thể kiểm thử không phụ thuộc bên thứ ba. Cơ chế *polling dự phòng* để đối soát trạng thái giao dịch nếu webhook không đến (NFR-015).],
  [R-03],
  [*Dữ liệu không nhất quán giữa service trong kiến trúc distributed:* Khi gọi chéo qua Restate (VD: Order Service → Account Service để cập nhật ví), nếu bước thứ hai thất bại sau khi bước đầu đã commit, dữ liệu có thể lệch nhau, tuy nhiên Restate đã xử lý phần lớn thông qua journal replay.],
  [Thấp], [Cao],
  [Restate tự động đảm bảo idempotency và retry cho mọi bước trong durable handler; đây là lý do chính chọn Restate thay vì tự xây Saga. Thêm vào đó, áp dụng *append-only audit log* cho mọi biến động ví (NFR-009) để có thể phát hiện và đối soát thủ công nếu có drift dữ liệu bất thường.],
)
]

== Xác Định Kiến Trúc Hệ Thống

=== Sơ đồ kiến trúc hệ thống
Sơ đồ dưới đây thể hiện kiến trúc Durable Microservices trên nền Restate của hệ thống ShopNexus C2C. Các yêu cầu *mutation* (đặt hàng, gửi Offer, thanh toán, phán quyết tranh chấp) đi qua Restate Ingress (Proxy) để được journal hóa, idempotent và phục hồi được sau lỗi. Ngược lại, các yêu cầu *query* (xem sản phẩm, tìm kiếm, lịch sử đơn) gọi thẳng service qua HTTP/2 RPC, bỏ qua Ingress, vì mỗi hop qua Ingress tốn thêm ~50ms (kể cả trên localhost), không đáng cho luồng đọc nhiều:

#fig(
  [Sơ đồ Kiến trúc Durable Microservices hệ thống ShopNexus C2C (System Architecture Diagram)],
  spacing: (24mm, 15mm),
  np((0, 3), [Client\ (Next.js Web / Flutter Mobile)]),
  edge((0, 3), (2, 3), "-|>", text(size: 8pt)[HTTPS]),
  ncore((2, 3), [Restate Ingress\ (Proxy, Mutation)]),

  edge((2, 3), (4.5, 0), "-|>"),
  edge((2, 3), (4.5, 1), "-|>"),
  edge((2, 3), (4.5, 2), "-|>"),
  edge((2, 3), (4.5, 3), "-|>"),
  edge((2, 3), (4.5, 4), "-|>"),
  edge((2, 3), (4.5, 5), "-|>"),
  edge((2, 3), (4.5, 6), "-|>"),

  // query path bỏ qua Ingress, gọi thẳng service qua HTTP/2
  edge((0, 3), (4.5, 1), "-|>", stroke: (paint: ink, thickness: 1pt, dash: "dashed"), text(size: 7pt)[Query: HTTP/2 trực tiếp]),

  np((4.5, 0), [Account\ Service]),
  np((4.5, 1), [Catalog\ Service]),
  np((4.5, 2), [Chat & Offer\ Service]),
  np((4.5, 3), [Order Service #text(size: 7pt)[(Durable)]]),
  np((4.5, 4), [Inventory\ Service]),
  np((4.5, 5), [Analytic\ Service]),
  np((4.5, 6), [Common Service #text(size: 7pt)[(SSE/Storage)]]),

  edge((4.5, 0), (7, 0), "-|>"),
  edge((4.5, 1), (7, 1), "-|>", text(size: 7pt)[bge-m3 hybrid]),
  edge((4.5, 2), (7, 2), "-|>"),
  edge((4.5, 3), (7, 3), "-|>"),
  edge((4.5, 4), (7, 4), "-|>"),
  edge((4.5, 5), (7, 5), "-|>"),
  edge((4.5, 6), (7, 6), "-|>"),

  ng((7, 0), [PostgreSQL\ (account)]),
  ng((7, 1), [PostgreSQL\ (catalog + pgvector)]),
  ng((7, 2), [PostgreSQL\ (chat)]),
  ng((7, 3), [PostgreSQL\ (order, incl. refund/dispute)]),
  ng((7, 4), [PostgreSQL\ (inventory)]),
  ng((7, 5), [PostgreSQL\ (analytic)]),
  ng((7, 6), [Redis + Object Storage]),

  // NATS JetStream event bus
  ncore((4.5, 7.5), [NATS JetStream\ (Event Bus, Async Communication)]),
  edge((4.5, 2), (4.5, 7.5), "<->"),
  edge((4.5, 3), (4.5, 7.5), "<->"),
  edge((4.5, 5), (4.5, 7.5), "<->"),
  edge((4.5, 6), (4.5, 7.5), "<->"),

  // External systems
  ng((2, 5.5), [SePay / Stripe\ Gateway]),
  edge((4.5, 3), (2, 5.5), "<->", [API Payment]),
  ng((7, 8.5), [GHN / GHTK\ API]),
  edge((4.5, 3), (7, 8.5), "<->", [Delivery tracking]),

  // Moderator/Admin console
  np((2, 0), [Moderator/Admin\ Console]),
  edge((2, 0), (2, 3), "<->", text(size: 8pt)[REST qua Ingress]),
)


=== Mô tả thành phần hệ thống
Dưới đây là chi tiết trách nhiệm và công nghệ của từng thành phần trong sơ đồ kiến trúc:

#figure(kind: table, caption: [Mô tả thành phần hệ thống])[
#table(
  columns: (1.4fr, 2.5fr, 1.5fr),
  align: (center, left, center),
  [Tên Thành Phần], [Trách Nhiệm / Nhiệm Vụ], [Công Nghệ Sử Dụng],
  [Restate Ingress], [Nhận yêu cầu *mutation* từ client, xác thực token, định tuyến vào durable function của service tương ứng; đảm bảo idempotency. Yêu cầu *query* gọi thẳng service qua HTTP/2, không qua Ingress.], [Restate],
  [Account Service], [Quản lý đăng ký, đăng nhập, phân quyền User/Moderator/Admin, và số dư ví (khả dụng/tạm giữ Escrow).], [Go + PostgreSQL],
  [Catalog Service], [Quản lý đăng bán, cập nhật trạng thái hiển thị sản phẩm, tìm kiếm hybrid (dense + sparse) và gợi ý.], [Go + PostgreSQL (pgvector) + bge-m3],
  [Chat Service], [Xử lý tin nhắn thời gian thực, lưu lịch sử chat, quản lý trạng thái Offer Card thương lượng giá.], [Go + PostgreSQL],
  [Order Service #text(fill: rgb("#1E3F8F"))[(Durable)]], [Xử lý đặt hàng, kết nối cổng thanh toán, khóa/giải ngân Escrow theo mốc thời gian (durable function), phân bổ phí vận chuyển buyer/seller; quản lý hồ sơ hoàn tiền & tranh chấp và ghi nhận phán quyết Moderator.], [Go + Restate + PostgreSQL + SePay/Stripe API],
  [Inventory Service], [Quản lý tồn kho theo serial, reserve/release khi checkout hoặc hủy đơn, lưu audit trail biến động kho.], [Go + PostgreSQL],
  [Analytic Service], [Ghi nhận tương tác người dùng, tính điểm phổ biến sản phẩm theo thời gian thực, cập nhật gợi ý cho Catalog.], [Go + PostgreSQL + NATS],
  [Common Service #text(fill: rgb("#1E3F8F"))[(SSE/Storage)]], [Object storage (bằng chứng ảnh/video, ảnh sản phẩm), server-sent events cho realtime chat/thông báo, geocoding, registry cấu hình service.], [Go + Redis + NATS],
)
]

=== Ma trận giao tiếp giữa các thành phần
Ma trận này mô tả cách các thành phần trong hệ thống trao đổi thông tin với nhau để hoàn tất các nghiệp vụ liên quan:

#figure(kind: table, caption: [Ma trận giao tiếp giữa các thành phần])[
#table(
  columns: (1.2fr, 1.2fr, 0.9fr, 2fr),
  align: (center, center, center, left),
  [Từ Thành Phần], [Đến Thành Phần], [Giao Thức], [Mục Đích Trao Đổi],
  [Client], [Restate Ingress], [HTTPS], [Gửi yêu cầu *mutation* (ghi), đặt hàng, gửi Offer, thanh toán.],
  [Client], [Các Service], [HTTP/2 RPC], [Gửi yêu cầu *query* (đọc) trực tiếp, bỏ qua Ingress để tránh ~50ms mỗi hop.],
  [Restate Ingress], [Các Service], [Durable RPC], [Định tuyến mutation vào durable function/handler tương ứng sau khi xác thực.],
  [Order Service], [Account Service], [Durable RPC], [Kiểm tra và cập nhật số dư ví người mua/người bán khi khóa/giải ngân Escrow.],
  [Order Service], [Catalog Service], [Durable RPC], [Xác nhận thông tin sản phẩm và cấu hình phí ship (buyer/seller trả) khi checkout.],
  [Order Service], [Inventory Service], [Durable RPC], [Reserve/release tồn kho khi checkout hoặc hủy đơn.],
  [Order Service], [Common Service], [HTTP/2 RPC], [Lưu bằng chứng video/ảnh (mở hộp, đóng gói) cho hồ sơ hoàn tiền/tranh chấp.],
  [Order Service], [NATS JetStream], [Async Event], [Publish sự kiện "Đơn đã thanh toán" / "Đã nhận hàng" / "Hoàn tiền" cho các service khác.],
  [Chat Service], [NATS JetStream], [Async Event], [Publish sự kiện "Tin nhắn mới" / "Offer mới".],
  [NATS JetStream], [Common Service], [Async Event], [Nhận sự kiện đơn hàng/chat để đẩy thông báo realtime (SSE)/email.],
  [NATS JetStream], [Analytic Service], [Async Event], [Nhận sự kiện tương tác/đơn hàng để tính điểm phổ biến sản phẩm.],
  [Order Service], [SePay/Stripe Gateway], [HTTPS], [Tạo liên kết thanh toán và nhận phản hồi IPN giao dịch.],
  [Order Service], [GHN/GHTK API], [HTTPS], [Tính phí vận chuyển động và cập nhật hành trình đơn hàng.],
)
]

=== Mô hình dữ liệu tổng hợp & tham chiếu chéo module (Cross-module Data Model)
Theo mô hình Database-per-service (ADR-02), mỗi module sở hữu một schema PostgreSQL riêng và *không* khai báo khóa ngoại vật lý xuyên schema. Các liên kết giữa module chỉ là *tham chiếu logic* (VD: `order` lưu `buyer_id` trỏ tới `account`), được giải quyết qua RPC (query đọc thẳng HTTP/2, mutation qua Restate) chứ không bằng SQL JOIN chéo schema. Sơ đồ và bảng dưới đây tổng hợp các khóa tham chiếu chéo chính:

#fig(
  [Mô hình tham chiếu chéo module (Cross-module Logical References)],
  spacing: (32mm, 16mm),
  ncore((1.5, 1), [order]),
  np((0, 0), [account]),
  np((3, 0), [catalog]),
  np((0, 2), [inventory]),
  np((3, 2), [chat]),
  np((1.5, 2.3), [analytic]),
  np((1.5, -0.3), [common]),
  edge((1.5, 1), (0, 0), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[buyer_id / seller_id]),
  edge((1.5, 1), (3, 0), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[sku_id / spu_id]),
  edge((1.5, 1), (0, 2), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[serial_ids]),
  edge((3, 2), (0, 0), "-|>", stroke: (dash: "dashed"), bend: 20deg, text(size: 7pt)[buyer_id / seller_id]),
  edge((1.5, 2.3), (3, 0), "-|>", stroke: (dash: "dashed"), bend: -12deg, text(size: 7pt)[interaction -> spu]),
  edge((0, 0), (1.5, -0.3), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[avatar_rs_id]),
  edge((3, 0), (1.5, -0.3), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[image rs_id]),
)

#figure(kind: table, caption: [Mô hình dữ liệu tổng hợp & tham chiếu chéo module (Cross-module Data Model)])[
#table(
  columns: (1.7fr, 1fr, 1.6fr, 1.9fr),
  align: (left, left, left, left),
  [Khóa tham chiếu], [Từ schema], [Trỏ tới (logic)], [Ghi chú],
  [account_id / buyer_id / seller_id], [order, chat, analytic], [account.account], [Không FK vật lý xuyên schema, chỉ tham chiếu logic, resolve qua RPC.],
  [sku_id / spu_id], [order], [catalog.product_sku / product_spu], [Snapshot `sku_name` được lưu tại thời điểm giao dịch, không JOIN runtime.],
  [serial_ids], [order], [inventory.serial], [Reserve khi checkout, release khi hủy/từ chối mục chờ.],
  [rs_id (avatar, ảnh SP, bằng chứng)], [account, catalog, order], [common.resource], [Trỏ tới object storage (ảnh sản phẩm, video/ảnh mở hộp).],
  [payment_option], [order], [Registry provider (SePay/Stripe)], [Là map key runtime chọn provider, không phải FK.],
)
]


=== Sơ đồ tuần tự các luồng nghiệp vụ durable (Sequence Diagrams)
Hai luồng tài chính dài hạn quan trọng nhất được triển khai như *durable function* trên Restate. Sơ đồ tuần tự dưới đây thể hiện thứ tự các bước và điểm phục hồi: mỗi bước ghi (mutation) đều được Restate journal hóa, nên khi service crash/restart luồng tiếp tục đúng từ bước dừng gần nhất, không xử lý trùng.

#fig(
  [Luồng Đặt hàng -> Khóa Escrow -> Giải ngân (durable trên Restate)],
  spacing: (30mm, 8mm),
  np((0, 0), [Buyer]),
  ncore((1, 0), [Order Svc\ (Restate)]),
  np((2, 0), [Inventory]),
  np((3, 0), [Payment GW]),
  np((4, 0), [Seller]),
  edge((0, 0.4), (0, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((1, 0.4), (1, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((2, 0.4), (2, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((3, 0.4), (3, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((4, 0.4), (4, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((0, 1), (1, 1), "-|>", text(size: 7pt)[1. Checkout (SKU, địa chỉ)]),
  edge((1, 2), (2, 2), "-|>", text(size: 7pt)[2. Reserve tồn kho]),
  edge((2, 3), (1, 3), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[3. serial_ids đã giữ]),
  edge((1, 4), (4, 4), "-|>", text(size: 7pt)[4. Thông báo mục chờ (NATS)]),
  edge((4, 5), (1, 5), "-|>", text(size: 7pt)[5. Xác nhận + chọn ship -> tạo Order]),
  edge((0, 6), (1, 6), "-|>", text(size: 7pt)[6. PayBuyerOrders]),
  edge((1, 7), (3, 7), "-|>", text(size: 7pt)[7. Tạo phiên thanh toán]),
  edge((3, 8), (1, 8), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[8. Webhook ConfirmPayment (OK)]),
  ng((1, 9), text(size: 7pt)[execution: khóa tiền -> Escrow]),
  nt((1, 10.3), text(size: 7pt)[Restate timer: đếm ngược 3 ngày]),
  edge((1, 11.4), (4, 11.4), "-|>", text(size: 7pt)[Hết hạn, không khiếu nại -> Giải ngân Seller]),
)

#note[Ba pha theo quy ước `decision` -> `execution` -> `tail`: *decision* đọc & validate (fail-fast, chưa commit); *execution* các commit durable (reserve kho, khóa Escrow); *tail* fan-out sau commit (thông báo qua NATS). Bù trừ (compensation): nếu thanh toán thất bại/timeout, bước reserve tồn kho được release tự động qua saga, không để kho bị giữ treo.]

#fig(
  [Luồng Hoàn tiền & Tranh chấp (RefundWorkflow, durable, keyed theo refund_id)],
  spacing: (30mm, 8mm),
  np((0, 0), [Buyer]),
  ncore((1, 0), [Order Svc\ (Restate)]),
  np((2, 0), [Seller]),
  np((3, 0), [Moderator]),
  np((4, 0), [Ví / Escrow]),
  edge((0, 0.4), (0, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((1, 0.4), (1, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((2, 0.4), (2, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((3, 0.4), (3, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((4, 0.4), (4, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((0, 1), (1, 1), "-|>", text(size: 7pt)[1. CreateBuyerRefund (lý do, video, vận đơn trả)]),
  nt((1, 2), text(size: 7pt)[RefundWorkflow bắt đầu (key = refund_id)]),
  nt((1, 3), text(size: 7pt)[Chờ hàng trả về (fallback 14 ngày)]),
  edge((1, 4), (2, 4), "-|>", text(size: 7pt)[2. Chờ Seller review (3 ngày, auto-accept)]),
  edge((2, 5), (1, 5), "-|>", text(size: 7pt)[3a. SellerApproveRefund]),
  edge((1, 6), (4, 6), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[4a. Hoàn tiền Buyer (reversal tx)]),
  edge((2, 7), (1, 7), "-|>", text(size: 7pt)[3b. SellerDisputeRefund]),
  edge((1, 8), (3, 8), "-|>", text(size: 7pt)[4b. Chờ Moderator phân xử]),
  edge((3, 9), (1, 9), "-|>", text(size: 7pt)[5b. Dismiss (BuyerWins) / Uphold (SellerWins)]),
  edge((1, 10.4), (4, 10.4), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[6b. Dismiss -> hoàn Buyer; Uphold -> giải ngân Seller + ship trả]),
)

=== Bản Ghi Quyết Định Kiến Trúc (Architectural Decision Records - ADR)
Nhóm đã thông qua 4 quyết định kiến trúc cốt lõi dưới đây cho dự án ShopNexus C2C:

==== ADR-01: Lựa chọn Durable Microservices trên Restate thay vì Microservices truyền thống
- *Bối cảnh:* Các luồng liên quan đến tiền (giữ tiền Escrow, hoàn tiền, tranh chấp) diễn ra qua nhiều bước và kéo dài nhiều ngày. Nếu một service bị lỗi hoặc khởi động lại giữa chừng, hệ thống dễ rơi vào trạng thái nửa vời: tiền đã trừ nhưng đơn hàng chưa cập nhật, hoặc một bước bị chạy lại hai lần. Với microservices truyền thống, nhóm phải tự viết thêm nhiều cơ chế phức tạp để chống các lỗi này, rất dễ sai với đội ngũ nhỏ.
- *Quyết định:* Dùng Restate làm nền tảng "thực thi bền" (durable execution) cho các thao tác ghi (thay đổi dữ liệu). Restate ghi lại tiến trình của từng bước, nên khi service phục hồi sau lỗi, luồng sẽ chạy tiếp đúng từ chỗ dừng thay vì làm lại từ đầu. Các thao tác chỉ đọc (xem sản phẩm, tìm kiếm) gọi thẳng service, không đi qua Restate.
- *Lý do:* Restate lo sẵn hai việc khó nhất là không chạy trùng một bước và tự khôi phục sau lỗi, nên nhóm không phải tự viết cơ chế xử lý lỗi thủ công. Điều này giảm nhiều rủi ro và khối lượng code cho nhóm 3 người trong 8 tuần. Đổi lại, mỗi lần đi qua Restate tốn thêm khoảng 50ms, nên nhóm chỉ dùng cho thao tác ghi; thao tác đọc gọi trực tiếp để giữ tốc độ.
- *Hệ quả:* Nhóm cần thời gian học Restate vì đây là công nghệ mới; đồng thời phải phân biệt rõ ngay từ khi thiết kế API đâu là thao tác ghi (đi qua Restate) và đâu là thao tác đọc (gọi thẳng service).

==== ADR-02: Áp dụng mô hình Database-per-service (schema-per-module)
- *Bối cảnh:* Tránh việc các service chia sẻ chung cơ sở dữ liệu dẫn đến phụ thuộc chặt chẽ (tight coupling) và nghẽn kết nối.
- *Quyết định:* Mỗi service sở hữu schema PostgreSQL riêng (`account`, `catalog`, `chat`, `order`...); không service nào truy cập trực tiếp CSDL của service khác, mọi tham chiếu chéo (VD: `account_id` trong schema `order`) là tham chiếu logic, không khai báo khóa ngoại vật lý xuyên schema.
- *Lý do:* Đảm bảo tính độc lập của các dịch vụ, cho phép mỗi module tiến hóa schema độc lập mà không ảnh hưởng module khác.
- *Hệ quả:* Phải gọi qua HTTP/2 (RPC) để lấy thông tin liên quan thay vì SQL JOIN chéo schema; cần đồng bộ dữ liệu tham chiếu (VD: tên sản phẩm hiển thị trong Order) bằng snapshot tại thời điểm giao dịch.

==== ADR-03: Sử dụng NATS JetStream cho giao tiếp bất đồng bộ, Restate xử lý đếm ngược Escrow
- *Bối cảnh:* Luồng thanh toán tạm giữ Escrow cần xử lý nhiều tác vụ bất đồng bộ (thông báo, cập nhật vận đơn) và cần cơ chế đếm ngược tự động giải ngân sau 3 ngày kể từ khi người mua xác nhận nhận hàng.
- *Quyết định:* Dùng NATS JetStream làm Event Bus cho giao tiếp bất đồng bộ giữa các service (thông báo, đồng bộ trạng thái); dùng cơ chế *durable timer* có sẵn của Restate (không phải Delay Message của message broker) để triển khai đếm ngược 3 ngày cho Escrow.
- *Lý do:* Hệ thống không phải sàn event-streaming khối lượng lớn, event bus chủ yếu fan-out thông báo và đồng bộ trạng thái, nên Kafka (nặng, JVM, cấu hình partition/retention phức tạp) là chi phí không tương xứng. NATS JetStream nhẹ (một binary Go), latency thấp nhưng vẫn có persistence + replay theo stream, đủ cho nhu cầu. Đếm ngược Escrow là một phần của luồng nghiệp vụ có trạng thái (stateful) nên giao cho Restate quản lý trực tiếp sẽ đảm bảo tính đúng đắn cao hơn tính năng delay của message broker.
- *Hệ quả:* Vận hành thêm NATS JetStream bên cạnh Restate, nhưng NATS rất nhẹ nên gánh nặng vận hành thấp; tách bạch rõ trách nhiệm: NATS cho "thông báo việc gì đã xảy ra", Restate cho "đảm bảo việc gì chắc chắn sẽ xảy ra đúng lúc".

==== ADR-04: Tìm kiếm ngữ nghĩa bằng pgvector + bge-m3
- *Bối cảnh:* Sàn cần tìm kiếm sản phẩm theo ngữ nghĩa lẫn từ khóa. Một vector DB chuyên biệt (Milvus) cho throughput ANN cao nhất nhưng phải vận hành như một hệ thống riêng, kèm pipeline đồng bộ dữ liệu với PostgreSQL.
- *Quyết định:* Lưu embedding ngay trong PostgreSQL qua extension *pgvector*; sinh embedding bằng model *bge-m3* (dense + sparse) và thực hiện hybrid search + rerank trong một truy vấn SQL.
- *Lý do:* Hệ thống không phải sàn search-heavy, lượng truy vấn không đủ lớn để bù chi phí vận hành một vector DB riêng. pgvector dùng chung transaction, backup và cho phép lọc scalar (danh mục, giá, tồn kho) trong cùng truy vấn, không cần round-trip re-filter. Model bge-m3 sinh cả dense lẫn sparse nên một model duy nhất phủ cả ngữ nghĩa và từ khóa.
- *Hệ quả:* Khi dataset lên tới hàng chục triệu vector, ANN thuần của pgvector sẽ chậm hơn Milvus; nhóm chấp nhận đánh đổi này ở quy mô dự án để bớt một hệ thống phải vận hành. Đổi chiều dim embedding (VD: chuyển sang model khác) là một ALTER migration + re-embed.
= Thiết kế cấp cao (High-level Design)

Các chương trước đã định nghĩa kiến trúc tổng thể; chương này chuyển sang thiết kế cấp cao: chia hệ thống thành các thành phần có trách nhiệm rõ ràng, đặc tả giao diện API giữa frontend và backend, thiết kế cơ sở dữ liệu vật lý và các biện pháp bảo mật. Toàn bộ thiết kế bám theo kiến trúc Durable Microservices trên Restate và mô hình Database-per-service đã chốt ở Chương 4.

== Thiết Kế Thành Phần

=== Sơ đồ thành phần phân lớp
Mỗi service trong hệ thống được tổ chức theo ba lớp: *Presentation* (giao diện & handler nhận request), *Business Logic* (service nghiệp vụ, validator) và *Data Access* (repository truy cập CSDL). Nguyên tắc phụ thuộc một chiều: lớp trên phụ thuộc lớp dưới, không có phụ thuộc vòng. Sơ đồ dưới đây minh họa lát cắt tiêu biểu (Account, Catalog, Order); các service còn lại (Chat, Inventory, Analytic, Common) tuân theo cùng khuôn mẫu.

=== Danh mục thành phần
Bảng dưới đây liệt kê các thành phần chính trên cả ba lớp, kèm trách nhiệm, yêu cầu chức năng triển khai và phụ thuộc.

#figure(kind: table, caption: [Danh mục thành phần])[
#table(
  columns: (1.1fr, 0.7fr, 1.5fr, 0.6fr, 1.1fr),
  align: (left, center, left, center, left),
  [Thành phần], [Lớp], [Trách nhiệm], [REQ], [Phụ thuộc],
  [`AuthHandler`], [Presentation], [Nhận request đăng ký/đăng nhập, xác thực token, định tuyến vào service.], [REQ-001…009], [`AccountService`],
  [`OrderHandler`], [Presentation], [Nhận request đặt hàng/thanh toán/hoàn tiền, kiểm tra quyền sở hữu.], [REQ-016…026], [`OrderService`],
  [`AccountService`], [Business], [Đăng ký, đăng nhập, phân quyền, quản lý hồ sơ và số dư ví (khả dụng/Escrow).], [REQ-001…009, 036…038], [`AccountRepository`],
  [`CatalogService`], [Business], [Đăng bán, cập nhật trạng thái listing, tìm kiếm hybrid, gợi ý.], [REQ-010…012, 030…032], [`CatalogRepository`],
  [`ChatOfferService`], [Business], [Tin nhắn thời gian thực, tạo/chấp nhận Offer Card, tạo đơn tạm.], [REQ-013…016], [`ChatRepository`, `OrderService`],
  [`OrderService` (Durable)], [Business], [Checkout, kết nối cổng thanh toán, khóa/giải ngân Escrow, hồ sơ hoàn tiền & tranh chấp.], [REQ-016…026], [`AccountService`, `CatalogService`, `InventoryService`],
  [`InventoryService`], [Business], [Reserve/release tồn kho theo serial, audit biến động kho.], [REQ-033…035], [`InventoryRepository`],
  [`AnalyticService`], [Business], [Ghi nhận tương tác, tính điểm phổ biến, cập nhật gợi ý.], [REQ-032], [`AnalyticRepository`],
  [`Validators`], [Business], [Kiểm tra dữ liệu đầu vào (giá > 0, đủ trường bắt buộc, định dạng email…).], [REQ-002…003, 012], [(không)],
  [`AccountRepository`], [Data Access], [Truy vấn/ghi bảng `account`, `profile`, `transaction` bằng SQLC + pgx.], [(không)], [PostgreSQL (account)],
  [`CatalogRepository`], [Data Access], [Truy vấn `product_spu/sku`, `category`; hybrid search qua pgvector.], [(không)], [PostgreSQL (catalog)],
  [`OrderRepository`], [Data Access], [Truy vấn/ghi `order`, `refund_request`, `dispute_case`, `payment_session`.], [(không)], [PostgreSQL (order)],
)
]

=== Ma trận trách nhiệm
Ma trận dưới đây đối chiếu thành phần Business với nhóm yêu cầu chức năng (dấu ✓ = thành phần triển khai nhóm REQ đó).

#figure(kind: table, caption: [Ma trận trách nhiệm])[
#table(
  columns: (1.5fr, 0.7fr, 0.8fr, 0.7fr, 0.9fr, 0.9fr, 0.8fr, 0.7fr),
  align: (left, center, center, center, center, center, center, center),
  [Thành phần \ (Business)], [Auth], [Listing], [Chat/ Offer], [Order/ Escrow], [Refund/ Dispute], [Search], [Ví],
  [`AccountService`], [✓], [], [], [], [], [], [✓],
  [`CatalogService`], [], [✓], [], [], [], [✓], [],
  [`ChatOfferService`], [], [], [✓], [✓], [], [], [],
  [`OrderService`], [], [], [], [✓], [✓], [], [✓],
  [`InventoryService`], [], [], [], [✓], [], [], [],
  [`AnalyticService`], [], [], [], [], [], [✓], [],
)
]

== Thiết Kế API

=== Tổng quan API
- *Base URL:* `/api` (qua Ingress cho lệnh ghi; các endpoint đọc gọi thẳng service qua HTTP/2).
- *Xác thực:* JWT Bearer trong header `Authorization: Bearer <token>` (xem 5.4).
- *Định dạng:* toàn bộ request/response dùng JSON (UTF-8).
- *Phân loại:* mỗi endpoint được đánh dấu *M* (mutation, đi qua Restate Ingress, idempotent) hoặc *Q* (query, đọc trực tiếp).
- *Mã lỗi chung:* `400` dữ liệu không hợp lệ, `401` chưa xác thực, `403` không đủ quyền, `404` không tìm thấy, `409` xung đột trạng thái, `422` vi phạm ràng buộc nghiệp vụ, `5xx` lỗi hệ thống/bên thứ ba (chi tiết ở 7.2).

=== Đặc tả endpoint
Bảng dưới liệt kê các endpoint chính, nhóm theo tài nguyên.

#figure(kind: table, caption: [Đặc tả endpoint])[
#table(
  columns: (0.5fr, 2fr, 0.4fr, 2.2fr, 0.9fr),
  align: (center, left, center, left, center),
  [PT], [Đường dẫn], [Loại], [Mô tả], [Quyền],
  [POST], [`/api/auth/register`], [M], [Đăng ký tài khoản User mới.], [Công khai],
  [POST], [`/api/auth/login`], [M], [Đăng nhập, trả access + refresh token.], [Công khai],
  [POST], [`/api/auth/refresh`], [M], [Cấp lại access token từ refresh token.], [Công khai],
  [POST], [`/api/auth/logout`], [M], [Thu hồi refresh token hiện tại.], [User],
  [GET], [`/api/products`], [Q], [Danh sách/duyệt sản phẩm, phân trang.], [Công khai],
  [GET], [`/api/products/{id}`], [Q], [Chi tiết một sản phẩm (SPU/SKU).], [Công khai],
  [GET], [`/api/search`], [Q], [Tìm kiếm hybrid + lọc danh mục/giá/tình trạng.], [Công khai],
  [POST], [`/api/products`], [M], [Đăng bán sản phẩm C2C (giá cố định / thương lượng).], [User],
  [GET], [`/api/chats/{id}/messages`], [Q], [Lịch sử tin nhắn của một hội thoại.], [User],
  [POST], [`/api/chats/{id}/messages`], [M], [Gửi tin nhắn văn bản/ảnh/video.], [User],
  [POST], [`/api/chats/{id}/offers`], [M], [Người bán tạo Offer Card (giá mới + lý do).], [User (seller)],
  [POST], [`/api/offers/{id}/accept`], [M], [Người mua chấp nhận Offer, tạo đơn tạm.], [User (buyer)],
  [POST], [`/api/orders/checkout`], [M], [Tạo đơn từ mục chờ, tính phí ship (quote).], [User (buyer)],
  [POST], [`/api/orders/{id}/pay`], [M], [Khởi tạo phiên thanh toán tạm giữ Escrow.], [User (buyer)],
  [GET], [`/api/orders/{id}`], [Q], [Chi tiết & trạng thái một đơn hàng.], [Chủ sở hữu],
  [POST], [`/api/orders/{id}/confirm-received`], [M], [Xác nhận đã nhận hàng (khởi động đếm ngược).], [User (buyer)],
  [POST], [`/api/orders/{id}/refunds`], [M], [Gửi yêu cầu hoàn tiền (kèm video/ảnh).], [User (buyer)],
  [POST], [`/api/refunds/{id}/seller-decision`], [M], [Người bán chấp nhận / từ chối hoàn tiền.], [User (seller)],
  [POST], [`/api/disputes/{id}/resolve`], [M], [Moderator ra phán quyết tranh chấp.], [Moderator],
  [POST], [`/api/seller/pending/{id}/confirm`], [M], [Người bán xác nhận mục chờ, tạo vận đơn.], [User (seller)],
  [GET], [`/api/wallet`], [Q], [Số dư khả dụng / tạm giữ + lịch sử biến động.], [User],
  [POST], [`/api/wallet/withdrawals`], [M], [Yêu cầu rút số dư khả dụng về ngân hàng.], [User],
  [POST], [`/api/admin/moderators`], [M], [Admin cấp phát tài khoản Moderator.], [Admin],
)
]

=== Ví dụ request / response
*Đăng bán sản phẩm (REQ-010…012):*
```json
POST /api/products
{
  "name": "iPhone 13 Pro Max cũ",
  "category_id": 12,
  "price": 12500000,
  "condition": "USED",
  "pricing_mode": "NEGOTIABLE",
  "images": ["rs_9f1c", "rs_9f1d"],
  "description": "Máy đẹp 98%, pin 85%."
}

201 Created
{ "spu_id": 4821, "sku_id": 9310, "status": "ACTIVE" }
```

*Gửi Offer Card (REQ-015):*
```json
POST /api/chats/771/offers
{ "sku_id": 9310, "new_price": 12200000, "reason": "Bớt 300k hỗ trợ phí ship" }

201 Created
{ "offer_id": 5567, "status": "PENDING", "expires_at": "..." }
```

*Thanh toán tạm giữ Escrow (REQ-017…019):*
```json
POST /api/orders/1092/pay
{ "payment_option": "SEPAY" }

200 OK
{ "payment_url": "https://.../pay/abc", "session_id": "ps_77c2", "amount": 12235000 }
```

Endpoint xác thực gồm ba thao tác chính: đăng nhập (`/api/auth/login`) trả về cặp *access token* (ngắn hạn) + *refresh token* (dài hạn); làm mới (`/api/auth/refresh`) cấp lại access token; đăng xuất (`/api/auth/logout`) thu hồi refresh token trong CSDL.

== Kiến Trúc Dữ Liệu Vật Lý

=== Quy ước & tổng quan
Nền tảng: *PostgreSQL 16*, mô hình *Database-per-service* (mỗi module một schema riêng: `account`, `catalog`, `chat`, `order`, `inventory`, `analytic`, `common`). Quy ước: tên bảng chữ thường số ít theo domain, khóa chính `<bảng>_id` kiểu `BIGINT` (`BIGSERIAL`/định danh ứng dụng), thời điểm dùng `TIMESTAMPTZ`. Không khai báo khóa ngoại vật lý xuyên schema; liên kết giữa module là tham chiếu logic, resolve qua RPC (xem ADR-02, Chương 4).

=== Sơ đồ ERD vật lý (lát cắt module `order` + tham chiếu)
#fig(
  [Sơ đồ ERD vật lý lát cắt module `order` và các tham chiếu logic (Physical ERD)],
  spacing: (34mm, 15mm),
  ncore((1.5, 1), [order\ PK order_id]),
  np((0, 0), [account\ PK account_id]),
  np((3, 0), [product_sku\ PK sku_id]),
  np((0, 2), [refund_request\ PK refund_id\ FK order_id]),
  np((3, 2), [payment_session\ PK session_id\ FK order_id]),
  np((1.5, 2.4), [serial\ PK serial_id]),
  edge((1.5, 1), (0, 0), "-|>", stroke: (dash: "dashed"), text(size: 7.5pt)[buyer_id/seller_id]),
  edge((1.5, 1), (3, 0), "-|>", stroke: (dash: "dashed"), text(size: 7.5pt)[sku_id (snapshot)]),
  edge((0, 2), (1.5, 1), "-|>", text(size: 7.5pt)[order_id]),
  edge((3, 2), (1.5, 1), "-|>", text(size: 7.5pt)[order_id]),
  edge((1.5, 1), (1.5, 2.4), "-|>", stroke: (dash: "dashed"), text(size: 7.5pt)[serial_ids]),
)

=== Đặc tả bảng (chọn lọc)
*Bảng `account.account`:*
#figure(kind: table, caption: [Bảng `account.account`])[
#table(
  columns: (1.3fr, 1.3fr, 0.6fr, 2fr),
  align: (left, left, center, left),
  [Cột], [Kiểu], [Null], [Ràng buộc / ghi chú],
  [`account_id`], [`BIGSERIAL`], [No], [PRIMARY KEY],
  [`email`], [`VARCHAR(255)`], [No], [UNIQUE, CHECK định dạng email],
  [`password_hash`], [`VARCHAR(72)`], [No], [Bcrypt, không lưu plaintext],
  [`role`], [`VARCHAR(16)`], [No], [CHECK IN (`USER`,`MODERATOR`,`ADMIN`), DEFAULT `USER`],
  [`status`], [`VARCHAR(16)`], [No], [DEFAULT `ACTIVE`],
  [`created_at`], [`TIMESTAMPTZ`], [No], [DEFAULT `now()`],
)
]

*Bảng `catalog.product_sku`:*
#figure(kind: table, caption: [Bảng `catalog.product_sku`])[
#table(
  columns: (1.3fr, 1.3fr, 0.6fr, 2fr),
  align: (left, left, center, left),
  [Cột], [Kiểu], [Null], [Ràng buộc / ghi chú],
  [`sku_id`], [`BIGSERIAL`], [No], [PRIMARY KEY],
  [`spu_id`], [`BIGINT`], [No], [FK → `product_spu` (trong schema)],
  [`price`], [`DECIMAL(14,2)`], [No], [CHECK `price > 0`],
  [`pricing_mode`], [`VARCHAR(12)`], [No], [CHECK IN (`FIXED`,`NEGOTIABLE`)],
  [`condition`], [`VARCHAR(12)`], [No], [CHECK IN (`NEW`,`USED`)],
  [`embedding`], [`vector(1024)`], [Yes], [pgvector, sinh bằng bge-m3],
  [`status`], [`VARCHAR(12)`], [No], [DEFAULT `ACTIVE`],
)
]

*Bảng `order.order`:*
#figure(kind: table, caption: [Bảng `order.order`])[
#table(
  columns: (1.3fr, 1.3fr, 0.6fr, 2fr),
  align: (left, left, center, left),
  [Cột], [Kiểu], [Null], [Ràng buộc / ghi chú],
  [`order_id`], [`BIGSERIAL`], [No], [PRIMARY KEY],
  [`buyer_id`], [`BIGINT`], [No], [Tham chiếu logic → `account`],
  [`seller_id`], [`BIGINT`], [No], [Tham chiếu logic → `account`],
  [`sku_id`], [`BIGINT`], [No], [Tham chiếu logic → `catalog`],
  [`sku_name`], [`VARCHAR(255)`], [No], [Snapshot tại thời điểm đặt],
  [`total_amount`], [`DECIMAL(14,2)`], [No], [CHECK `total_amount >= 0`],
  [`status`], [`VARCHAR(24)`], [No], [CHECK IN các trạng thái đơn hợp lệ],
  [`created_at`], [`TIMESTAMPTZ`], [No], [DEFAULT `now()`],
)
]

*Bảng `order.refund_request`:*
#figure(kind: table, caption: [Bảng `order.refund_request`])[
#table(
  columns: (1.3fr, 1.3fr, 0.6fr, 2fr),
  align: (left, left, center, left),
  [Cột], [Kiểu], [Null], [Ràng buộc / ghi chú],
  [`refund_id`], [`BIGSERIAL`], [No], [PRIMARY KEY],
  [`order_id`], [`BIGINT`], [No], [FK → `order` (cùng schema)],
  [`reason`], [`TEXT`], [No], [Lý do khiếu nại],
  [`evidence_rs_ids`], [`BIGINT[]`], [No], [Trỏ tới `common.resource` (video/ảnh)],
  [`status`], [`VARCHAR(24)`], [No], [`REQUESTED`/`SELLER_APPROVED`/`DISPUTED`/`RESOLVED`],
  [`created_at`], [`TIMESTAMPTZ`], [No], [DEFAULT `now()`],
)
]

=== Ràng buộc & chỉ mục tiêu biểu
- *Ràng buộc:* `UNIQUE(email)` trên `account`; `CHECK(price > 0)` trên `product_sku`; `CHECK(total_amount >= 0)` và `CHECK(status IN …)` trên `order`; `UNIQUE` một phần (partial unique index) cho phương thức thanh toán mặc định của mỗi ví.
- *Chỉ mục:* index trên các cột tham chiếu logic (`order.buyer_id`, `order.seller_id`) phục vụ truy vấn "đơn của tôi"; index `order.created_at DESC` cho danh sách đơn gần đây; HNSW index trên `product_sku.embedding` cho tìm kiếm ANN; index `refund_request.order_id`.

== Thiết Kế Bảo Mật

=== Thiết kế xác thực
- *Đăng nhập:* Email + mật khẩu. Mật khẩu được băm bằng *Bcrypt* trước khi lưu, không bao giờ lưu/log plaintext (NFR-002).
- *Token:* Đăng nhập thành công trả về *access token* (JWT, sống 15-30 phút, ký HS256/RS256) và *refresh token* (sống tối đa 7 ngày, lưu dạng hash trong CSDL, có thể thu hồi), NFR-003.
- *Chống dò mật khẩu:* khóa tạm tài khoản sau 5 lần sai liên tiếp trong 15 phút, kèm rate-limit theo IP (NFR-004).

=== Thiết kế ủy quyền
Áp dụng RBAC ở tầng Ingress kết hợp kiểm tra quyền sở hữu cấp đối tượng ở tầng service (NFR-005, NFR-006).

#figure(kind: table, caption: [Thiết kế ủy quyền])[
#table(
  columns: (0.9fr, 2.6fr),
  align: (left, left),
  [Vai trò], [Quyền tiêu biểu],
  [`User`], [Đăng bán, chat, đặt hàng/thanh toán, gửi hoàn tiền, xem/rút ví, chỉ trên tài nguyên thuộc sở hữu của mình.],
  [`Moderator`], [Xem hồ sơ tranh chấp, ra phán quyết; không truy cập chức năng quản trị hệ thống.],
  [`Admin`], [Cấp phát tài khoản Moderator, quản trị nền tảng; không tự ý can thiệp dòng tiền ngoài quy trình.],
)
]

Mọi request ghi được xác minh hai lớp: (1) Ingress kiểm claim vai trò trong JWT; (2) service kiểm quyền sở hữu đối tượng (VD: `order.buyer_id` phải khớp chủ thể gọi) trước khi thực thi.

=== Bảo vệ dữ liệu
- *Trên đường truyền:* toàn bộ giao tiếp Client–Server và nội bộ qua TLS.
- *Dữ liệu nhạy cảm:* mật khẩu (luôn hash), thông tin định danh (PII), số dư ví, lịch sử giao dịch, xử lý theo nguyên tắc tối thiểu hóa lộ dữ liệu.
- *Không bao giờ ghi log:* mật khẩu, token, thông tin thanh toán thô.

=== Điều khiển bảo mật cơ bản
- *Validate & sanitize* toàn bộ input ở tầng API để chống SQL Injection/XSS/Command Injection (NFR-007).
- *Truy vấn an toàn:* dùng prepared statement qua SQLC + pgx, không nối chuỗi SQL thủ công.
- *Rate-limiting* theo IP/tài khoản cho các API nhạy cảm (đăng ký, đăng nhập, tạo Offer, gửi hoàn tiền), NFR-008.
- *Audit log bất biến* (append-only) cho mọi biến động ví và thao tác nhạy cảm của Admin/Moderator (NFR-009, NFR-010).

// ============================================================
= Thiết kế chi tiết (Detailed Design)

Chương này chi tiết hóa thiết kế cấp cao thành bản vẽ mà lập trình viên trực tiếp làm theo: cấu trúc lớp (thuộc tính, phương thức), sơ đồ trình tự ở mức lời gọi phương thức, thiết kế UI độ trung thực cao và tập lệnh DDL hoàn chỉnh.

== Thiết Kế Lớp

=== Tổ chức package
Mã nguồn tổ chức theo service, mỗi service chia lớp theo khuôn mẫu: `handler` (nhận request) → `service` (nghiệp vụ) → `repository` (truy cập CSDL) → `model` (entity) và `dto` (đối tượng request/response). Quy ước phụ thuộc một chiều trùng với sơ đồ thành phần 5.1.

=== Sơ đồ lớp cụm Order
#fig(
  [Sơ đồ lớp cụm nghiệp vụ Order (Class Diagram)],
  spacing: (34mm, 17mm),
  np((0, 0), [*OrderHandler*\ + Checkout(req)\ + Pay(req)\ + CreateRefund(req)]),
  np((0, 1), [*OrderService*\ + Checkout()\ + Pay()\ + ConfirmReceived()\ + CreateRefund()]),
  np((2, 1), [*OrderValidator*\ + Validate(req)]),
  np((0, 2), [*OrderRepository*\ + Save(o)\ + FindById(id)\ + UpdateStatus()]),
  np((2, 2), [*Order* (entity)\ - order_id\ - total_amount\ - status\ + CanRefund()]),
  np((2, 0), [*RefundWorkflow*\ (durable)\ + Run(refund_id)]),
  edge((0, 0), (0, 1), "-|>", text(size: 7.5pt)[dùng]),
  edge((0, 1), (2, 1), "-|>", text(size: 7.5pt)[dùng]),
  edge((0, 1), (0, 2), "-|>", text(size: 7.5pt)[dùng]),
  edge((0, 2), (2, 2), "-|>", text(size: 7.5pt)[trả về]),
  edge((0, 1), (2, 0), "-|>", stroke: (dash: "dashed"), text(size: 7.5pt)[khởi động]),
)

=== Đặc tả lớp (cụm Order)
#figure(kind: table, caption: [Đặc tả lớp (cụm Order)])[
#table(
  columns: (1fr, 1.5fr, 2.2fr),
  align: (left, left, left),
  [Lớp], [Thuộc tính chính], [Phương thức chính],
  [`Order` (entity)], [`order_id`, `buyer_id`, `seller_id`, `total_amount`, `status`], [`CanRefund() bool`, `CanCancel() bool`, `MarkPaid()`],
  [`OrderService`], [`repo: OrderRepository`, `account: AccountService`, `inventory: InventoryService`], [`Checkout(req) Order`, `Pay(id, opt) Session`, `ConfirmReceived(id)`, `CreateRefund(req) Refund`],
  [`OrderRepository`], [`db: *pgx.Pool`], [`Save(o Order) error`, `FindById(id) (Order,error)`, `UpdateStatus(id, s) error`],
  [`RefundWorkflow`], [`ctx: restate.Context`, `refund_id`], [`Run(refund_id)`: chờ hàng về, chờ seller review, phân xử],
  [`OrderValidator`], [(không)], [`Validate(req) error`: kiểm tra quyền sở hữu, trạng thái hợp lệ],
)
]

== Sơ Đồ Trình Tự

Ở Chương 4 đã có sơ đồ trình tự mức nghiệp vụ durable (Escrow, Refund). Phần này bổ sung ba sơ đồ ở mức *lời gọi phương thức* giữa các lớp (Handler → Service → Repository → DB), xác thực rằng thiết kế lớp 6.1 thực sự chạy được, gồm một luồng Create, một Query và một Update có xử lý lỗi.

#fig(
  [Trình tự Đăng bán sản phẩm (Create, REQ-010…012],
  spacing: (26mm, 8mm),
  np((0, 0), [User]),
  np((1, 0), [Catalog\ Handler]),
  np((2, 0), [Catalog\ Service]),
  np((3, 0), [Validator]),
  np((4, 0), [Catalog\ Repo]),
  edge((0, 0.4), (0, 8), stroke: (paint: hairline, dash: "dashed")),
  edge((1, 0.4), (1, 8), stroke: (paint: hairline, dash: "dashed")),
  edge((2, 0.4), (2, 8), stroke: (paint: hairline, dash: "dashed")),
  edge((3, 0.4), (3, 8), stroke: (paint: hairline, dash: "dashed")),
  edge((4, 0.4), (4, 8), stroke: (paint: hairline, dash: "dashed")),
  edge((0, 1), (1, 1), "-|>", text(size: 7pt)[POST /api/products]),
  edge((1, 2), (2, 2), "-|>", text(size: 7pt)[CreateListing(req)]),
  edge((2, 3), (3, 3), "-|>", text(size: 7pt)[Validate(req)]),
  edge((3, 4), (2, 4), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[ok / lỗi 400]),
  edge((2, 5), (4, 5), "-|>", text(size: 7pt)[Save(sku) + embed bge-m3]),
  edge((4, 6), (2, 6), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[sku_id]),
  edge((1, 7), (0, 7), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[201 Created]),
)

#fig(
  [Trình tự Tìm kiếm sản phẩm (Query, REQ-030…031],
  spacing: (30mm, 8mm),
  np((0, 0), [User]),
  np((1, 0), [Catalog Handler]),
  np((2, 0), [Catalog Service]),
  np((3, 0), [PostgreSQL\ + pgvector]),
  edge((0, 0.4), (0, 6), stroke: (paint: hairline, dash: "dashed")),
  edge((1, 0.4), (1, 6), stroke: (paint: hairline, dash: "dashed")),
  edge((2, 0.4), (2, 6), stroke: (paint: hairline, dash: "dashed")),
  edge((3, 0.4), (3, 6), stroke: (paint: hairline, dash: "dashed")),
  edge((0, 1), (1, 1), "-|>", text(size: 7pt)[GET /api/search?q=... (HTTP/2 trực tiếp)]),
  edge((1, 2), (2, 2), "-|>", text(size: 7pt)[Search(q, filters)]),
  edge((2, 3), (3, 3), "-|>", text(size: 7pt)[hybrid query (dense+sparse) + lọc scalar]),
  edge((3, 4), (2, 4), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[rows xếp theo độ liên quan]),
  edge((1, 5), (0, 5), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[200 OK (danh sách)]),
)

#fig(
  [Trình tự Checkout → Thanh toán (Update, có xử lý lỗi, REQ-017…019],
  spacing: (24mm, 8mm),
  np((0, 0), [Buyer]),
  ncore((1, 0), [Order\ Service]),
  np((2, 0), [Inventory\ Service]),
  np((3, 0), [Payment GW]),
  np((4, 0), [Order Repo]),
  edge((0, 0.4), (0, 9), stroke: (paint: hairline, dash: "dashed")),
  edge((1, 0.4), (1, 9), stroke: (paint: hairline, dash: "dashed")),
  edge((2, 0.4), (2, 9), stroke: (paint: hairline, dash: "dashed")),
  edge((3, 0.4), (3, 9), stroke: (paint: hairline, dash: "dashed")),
  edge((4, 0.4), (4, 9), stroke: (paint: hairline, dash: "dashed")),
  edge((0, 1), (1, 1), "-|>", text(size: 7pt)[Checkout / Pay]),
  edge((1, 2), (2, 2), "-|>", text(size: 7pt)[Reserve(serial)]),
  edge((2, 3), (1, 3), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[ok]),
  edge((1, 4), (3, 4), "-|>", text(size: 7pt)[CreateSession(amount)]),
  edge((3, 5), (1, 5), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[webhook OK / timeout]),
  ng((1, 6), text(size: 7pt)[OK: khóa Escrow]),
  edge((1, 6.9), (4, 6.9), "-|>", text(size: 7pt)[UpdateStatus(PAID)]),
  nr((1, 7.8), text(size: 7pt)[Lỗi/timeout: release kho (saga) → 4xx]),
)

== Thiết Kế UI Độ Trung Thực Cao

=== Hệ thống thiết kế
Kế thừa bố cục từ wireframe (Chương 3), bổ sung màu sắc, typography và thang khoảng cách cụ thể để hướng dẫn triển khai frontend.

#figure(kind: table, caption: [Hệ thống thiết kế])[
#table(
  columns: (1fr, 2.5fr),
  align: (left, left),
  [Hạng mục], [Đặc tả],
  [Màu chính], [`#1A1A1A` (nút chính, nhấn mạnh) trên nền trắng `#FFFFFF`],
  [Màu phụ / nhấn], [PTIT-red `#B3122B` cho cảnh báo/hành động quan trọng],
  [Trung tính], [`#4D4D4D` (chữ phụ), `#ECECEC` (nền khối), `#C9C9C9` (đường kẻ)],
  [Trạng thái], [Thành công `#2E7D32`, Lỗi `#C62828`],
  [Typography], [Tiêu đề: sans (Heros/Inter) 20–32px; thân: 16px; chú thích 12–14px],
  [Thang khoảng cách], [Bội số 8px: 8 / 16 / 24 / 32 / 48],
  [Nút], [Cao 40px, bo góc 4px, padding ngang 16px; nút chính nền đậm chữ trắng],
  [Trường nhập], [Cao 40px, viền 1px `#C9C9C9`, focus đổi viền màu chính],
)
]

=== Thư viện thành phần
#grid(
  columns: (1fr, 1fr),
  column-gutter: 12pt, row-gutter: 12pt,
  wireframe("Nút (Button)")[
    #v(3pt)
    #grid(columns: (1fr, 1fr), column-gutter: 8pt,
      rect(width: 100%, height: 18pt, fill: ink, radius: 4pt, align(center + horizon, text(fill: white, size: 8pt)[Primary])),
      rect(width: 100%, height: 18pt, stroke: 0.8pt + ink, radius: 4pt, align(center + horizon, text(size: 8pt)[Secondary])),
    )
    #v(4pt)
    #text(size: 7pt, fill: muted)[Cao 40px · bo 4px · padding 16px]
  ],
  wireframe("Trường nhập (Input)")[
    #v(3pt)
    #rect(width: 100%, height: 16pt, stroke: 0.8pt + hairline, radius: 3pt, align(left + horizon, text(size: 7.5pt, fill: muted)[ Nhập nội dung...]))
    #v(4pt)
    #text(size: 7pt, fill: muted)[Viền 1px `#C9C9C9`, focus đổi viền `#1A1A1A`]
  ],
  wireframe("Thẻ sản phẩm (Card)")[
    #v(3pt)
    #grid(columns: (auto, 1fr), column-gutter: 6pt,
      rect(width: 30pt, height: 30pt, stroke: 0.6pt + hairline, align(center + horizon, text(size: 6.5pt)[ảnh])),
      stack(spacing: 3pt,
        text(size: 7.5pt, weight: 700)[Tên sản phẩm],
        text(size: 8pt, fill: rgb("#B3122B"), weight: 700)[12.500.000đ],
        text(size: 6.5pt, fill: muted)[~thương lượng]))
  ],
  wireframe("Nhãn trạng thái (Badge)")[
    #v(3pt)
    #grid(columns: (1fr, 1fr), column-gutter: 6pt,
      rect(width: 100%, height: 14pt, fill: rgb("#E8F5E9"), radius: 8pt, align(center + horizon, text(size: 7pt, fill: rgb("#2E7D32"))[Đã giao])),
      rect(width: 100%, height: 14pt, fill: rgb("#FFEBEE"), radius: 8pt, align(center + horizon, text(size: 7pt, fill: rgb("#C62828"))[Tranh chấp])),
    )
  ],
)

Ba màn hình quan trọng nhất (Chi tiết sản phẩm C2C, Khung Chat & Offer Card, Thanh toán Escrow) được thiết kế độ trung thực cao dựa trên wireframe (Chương 3), áp dụng palette và typography ở trên; mỗi màn hình kèm chú thích khoảng cách (8px scale) và ghi chú cho lập trình viên. Bản mockup chi tiết được trình bày ở mục 2.3.3 dưới đây.

=== Mockup độ trung thực cao (Hi-fidelity Mockups)
Từ hệ thống thiết kế và thư viện thành phần ở trên, nhóm dựng bản mockup độ trung thực cao cho các màn hình chính của sàn ShopNexus, thống nhất màu chủ đạo xanh mòng két (`#004E47`) và bộ chữ Manrope/Inter. Ba màn hình cốt lõi của luồng giao dịch C2C được trình bày trước, tiếp theo là các màn hình bổ sung trong hành trình người dùng.

#figure(
  image("../images/shopnexus_product_detail/screen.png", height: 14cm),
  caption: [Màn hình Chi tiết sản phẩm C2C: giá và mức giảm, uy tín người bán, nút "Chat ngay" / "Mua ngay".],
)

#figure(
  image("../images/shopnexus_inbox_chat/screen.png", width: 95%),
  caption: [Màn hình Nhắn tin & Đề nghị giá (Offer): trao đổi, gửi ảnh thực tế, thông tin giao dịch và nút "Đề nghị giá".],
)

#figure(
  image("../images/shopnexus_checkout/screen.png", height: 15cm),
  caption: [Màn hình Thanh toán: địa chỉ nhận hàng, phí vận chuyển động, phương thức thanh toán và tổng thanh toán.],
)

Ngoài ba màn hình cốt lõi, nhóm hoàn thiện mockup cho các màn hình còn lại của hành trình người dùng (trang chủ, tìm kiếm, đăng bán, quản lý bán hàng...). Toàn bộ bộ mockup được lưu trong thư mục `images/`.

#figure(
  grid(
    columns: (1fr, 1fr), column-gutter: 10pt, row-gutter: 12pt,
    align: center + horizon,
    image("../images/shopnexus_home_comprehensive_merged_layout/screen.png", height: 5cm),
    image("../images/shopnexus_search_results/screen.png", height: 5cm),
    image("../images/shopnexus_seller_dashboard/screen.png", height: 5cm),
    image("../images/shopnexus_list_an_item/screen.png", height: 5cm),
  ),
  caption: [Các màn hình bổ sung (từ trái sang, trên xuống): Trang chủ, Kết quả tìm kiếm, Bảng điều khiển người bán, Đăng bán sản phẩm.],
)

// == Chi Tiết Thiết Kế Cơ Sở Dữ Liệu (DDL) (DOC 6.4-A)

// Tập lệnh DDL cụ thể hóa thiết kế vật lý 5.3 thành mã SQL chạy được, tổ chức thành các tệp theo thứ tự phụ thuộc.

// === Tạo bảng (`01_create_tables.sql`)
// ```sql
// CREATE TABLE account.account (
//     account_id     BIGSERIAL PRIMARY KEY,
//     email          VARCHAR(255) NOT NULL UNIQUE,
//     password_hash  VARCHAR(72)  NOT NULL,
//     role           VARCHAR(16)  NOT NULL DEFAULT 'USER',
//     status         VARCHAR(16)  NOT NULL DEFAULT 'ACTIVE',
//     created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
//     CONSTRAINT email_format CHECK (email LIKE '%@%'),
//     CONSTRAINT valid_role   CHECK (role IN ('USER','MODERATOR','ADMIN'))
// );

// CREATE TABLE "order"."order" (
//     order_id      BIGSERIAL PRIMARY KEY,
//     buyer_id      BIGINT NOT NULL,          -- tham chiếu logic -> account
//     seller_id     BIGINT NOT NULL,          -- tham chiếu logic -> account
//     sku_id        BIGINT NOT NULL,          -- tham chiếu logic -> catalog
//     sku_name      VARCHAR(255) NOT NULL,    -- snapshot lúc đặt
//     total_amount  DECIMAL(14,2) NOT NULL,
//     status        VARCHAR(24) NOT NULL DEFAULT 'PENDING',
//     created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
//     CONSTRAINT positive_amount CHECK (total_amount >= 0),
//     CONSTRAINT valid_status CHECK (status IN
//         ('PENDING','PAID','SHIPPED','DELIVERED',
//          'REFUND_REQUESTED','DISPUTED','COMPLETED','CANCELLED'))
// );

// CREATE TABLE "order".refund_request (
//     refund_id         BIGSERIAL PRIMARY KEY,
//     order_id          BIGINT NOT NULL,
//     reason            TEXT   NOT NULL,
//     evidence_rs_ids   BIGINT[] NOT NULL,
//     status            VARCHAR(24) NOT NULL DEFAULT 'REQUESTED',
//     created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
//     CONSTRAINT fk_order FOREIGN KEY (order_id)
//         REFERENCES "order"."order"(order_id)
// );
// ```

// === Tạo chỉ mục (`02_create_indexes.sql`)
// ```sql
// -- Truy vấn "đơn hàng của tôi" (buyer/seller)
// CREATE INDEX idx_order_buyer  ON "order"."order"(buyer_id);
// CREATE INDEX idx_order_seller ON "order"."order"(seller_id);
// -- Danh sách đơn gần đây
// CREATE INDEX idx_order_created ON "order"."order"(created_at DESC);
// -- Tìm kiếm vector ANN (pgvector HNSW)
// CREATE INDEX idx_sku_embedding ON catalog.product_sku
//     USING hnsw (embedding vector_cosine_ops);
// ```

// === Dữ liệu tham chiếu (`03_insert_reference_data.sql`)
// ```sql
// INSERT INTO "order".order_status (code, label) VALUES
//     ('PENDING','Chờ xử lý'), ('PAID','Đã thanh toán (Escrow)'),
//     ('DELIVERED','Đã giao'), ('REFUND_REQUESTED','Yêu cầu trả hàng'),
//     ('DISPUTED','Đang tranh chấp'), ('COMPLETED','Hoàn tất'),
//     ('CANCELLED','Đã hủy');
// ```

// === Tổ chức & thứ tự chạy
// Các tệp chạy theo thứ tự: `01_create_tables.sql` (bảng không phụ thuộc trước, bảng có FK sau) → `02_create_indexes.sql` (sau khi bảng tồn tại) → `03_insert_reference_data.sql`. Kèm `README.md` mô tả điều kiện tiên quyết (mỗi schema module phải tồn tại) và lệnh chạy migration.

// #pagebreak()
// ============================================================
= Lập kế hoạch triển khai

Chương này khép lại giai đoạn thiết kế: đặc tả các thuật toán nghiệp vụ phức tạp, chiến lược xử lý lỗi, kế hoạch kiểm thử, chuẩn phát triển và lịch triển khai chi tiết cho giai đoạn code.

== Thiết Kế Thuật Toán

Ba phần logic phức tạp nhất được đặc tả bằng mã giả trước khi triển khai.

=== Thuật toán 1: Xếp hạng tìm kiếm hybrid (bge-m3)
Lớp/phương thức: `CatalogService.Search()`. Đầu vào: truy vấn `q`, bộ lọc `filters`. Đầu ra: danh sách SKU xếp theo độ liên quan.
```
Thuật toán: HybridSearchRank
Đầu vào: q (chuỗi), filters (danh mục, giá, tình trạng)

sinh (dense_vec, sparse_vec) = bge_m3.embed(q)
ứng viên = SQL:
    SELECT sku, (0.5 * cosine(embedding, dense_vec)
               + 0.5 * sparse_score(sparse_vec)) AS score
    FROM product_sku
    WHERE status = 'ACTIVE' AND thỏa(filters)
    ORDER BY score DESC
    LIMIT 100

VỚI MỖI item TRONG ứng viên:
    item.final = 0.7 * item.score + 0.3 * popularity(item.sku)

Trả về sắp_xếp_giảm_dần(ứng viên theo final)[0:20]
```

=== Thuật toán 2: Tính tổng thanh toán & khóa Escrow
Lớp/phương thức: `OrderService.Pay()`.
```
Thuật toán: ComputeAndLockEscrow
Đầu vào: order, ship_quote, payer

item_total = order.sku_price
NẾU order.pricing_mode = 'NEGOTIABLE' VÀ có offer đã chấp nhận THÌ
    item_total = offer.new_price
KẾT THÚC NẾU

ship_fee = ship_quote.fee
total = item_total + ship_fee

NẾU balance_khả_dụng(payer) < total VÀ không dùng cổng ngoài THÌ
    NÉM LỖI 422 (không đủ số dư)
KẾT THÚC NẾU

session = payment_gateway.create_session(total)   -- durable step
CHỜ webhook xác nhận (Restate journal)
KHI OK: chuyển total vào ví Escrow (khóa), order.status = 'PAID'
Trả về session
```

=== Thuật toán 3: Đếm ngược Escrow & tự giải ngân
Lớp/phương thức: `OrderService.ConfirmReceived()` + Restate durable timer.
```
Thuật toán: EscrowCountdown
Đầu vào: order (đã 'DELIVERED')

hẹn_giờ durable = 3 ngày   -- Restate timer, bền qua crash/restart

CHỜ (hết_giờ HOẶC có_khiếu_nại):
    NẾU có_khiếu_nại TRƯỚC KHI hết_giờ THÌ
        khởi động RefundWorkflow(refund_id); DỪNG
    KHÁC NẾU hết_giờ THÌ
        giải ngân Escrow -> ví khả dụng của seller
        order.status = 'COMPLETED'
    KẾT THÚC NẾU
```

== Thiết Kế Xử Lý Lỗi

=== Định dạng phản hồi lỗi
Mọi lỗi trả về theo cấu trúc JSON thống nhất, thông báo bằng tiếng Việt dễ hiểu, không lộ stack trace:
```json
{ "error": "Thông báo lỗi ngắn gọn", "details": "Chi tiết cụ thể (tùy chọn)" }
```

=== Các tình huống lỗi phổ biến
#figure(kind: table, caption: [Các tình huống lỗi phổ biến])[
#table(
  columns: (0.5fr, 1.6fr, 2fr),
  align: (center, left, left),
  [Mã], [Tình huống], [Thông báo mẫu],
  [400], [Dữ liệu đầu vào không hợp lệ (thiếu trường, sai định dạng).], ["Dữ liệu không hợp lệ"],
  [401], [Chưa đăng nhập / token hết hạn.], ["Vui lòng đăng nhập lại"],
  [403], [Không đủ quyền / không sở hữu tài nguyên.], ["Bạn không có quyền thực hiện"],
  [404], [Không tìm thấy tài nguyên (đơn, sản phẩm).], ["Không tìm thấy đối tượng"],
  [409], [Xung đột trạng thái / gửi trùng (idempotency).], ["Thao tác đã được xử lý"],
  [422], [Vi phạm ràng buộc nghiệp vụ (giá ≤ 0, không đủ số dư).], ["Không thể thực hiện: (lý do cụ thể)"],
  [500], [Lỗi hệ thống nội bộ.], ["Có lỗi xảy ra, vui lòng thử lại"],
  [502/504], [Cổng thanh toán / vận chuyển lỗi hoặc timeout.], ["Dịch vụ tạm thời gián đoạn"],
)
]

=== Hướng dẫn nơi bắt lỗi
- *Biên handler:* mọi lỗi được chuyển thành mã HTTP + JSON chuẩn ở tầng handler; service chỉ trả `error` có phân loại.
- *Restate:* phân biệt *lỗi tạm thời* (mạng, cổng thanh toán) để Restate tự retry, và *lỗi vĩnh viễn* (`TerminalError`, VD vi phạm nghiệp vụ) để dừng và bù trừ (saga) thay vì retry vô hạn.

== Chiến Lược Kiểm Thử

=== Cách tiếp cận
Áp dụng ba mức: *Unit* (logic service, thuật toán), *Integration* (endpoint API + luồng Restate), *Manual* (UI end-to-end). Mục tiêu bao phủ code ≥ 70% cho các service cốt lõi (order, account, catalog).

=== Tình huống kiểm thử (chọn lọc)
#figure(kind: table, caption: [Tình huống kiểm thử (chọn lọc)])[
#table(
  columns: (0.8fr, 1.4fr, 2fr),
  align: (center, left, left),
  [Mức], [Đối tượng], [Kịch bản tiêu biểu],
  [Unit], [`ComputeAndLockEscrow`], [Giá thương lượng, cộng phí ship, số dư không đủ → 422.],
  [Unit], [`Order.CanRefund()`], [Trong hạn 3 ngày → true; quá hạn → false.],
  [Unit], [`HybridSearchRank`], [Kết hợp dense+sparse+popularity, xếp hạng đúng thứ tự.],
  [Integration], [`POST /api/products`], [Đăng bán hợp lệ → 201; thiếu ảnh/giá ≤ 0 → 400.],
  [Integration], [`POST /api/orders/{id}/pay`], [Webhook OK → khóa Escrow; timeout → release kho.],
  [Integration], [Refund idempotency], [Gửi trùng `CreateRefund` → chỉ tạo một workflow.],
  [Manual], [Luồng C2C end-to-end], [Đăng bán → chat → Offer → checkout → Escrow → nhận hàng → giải ngân.],
  [Manual], [Luồng tranh chấp], [Buyer khiếu nại → seller từ chối → Moderator phán quyết.],
)
]

=== Công cụ
- *Unit/Integration:* Go `testing` + `testify`; mock repository qua interface.
- *Bên thứ ba:* mock server SePay/Stripe và GHN/GHTK để kiểm thử không phụ thuộc SLA ngoài (xem R-02, Chương 4).
- *API thủ công:* REST client / Postman; *tải:* k6 cho kịch bản đọc nhiều.

=== Ví dụ trường hợp kiểm thử
```
Test: Pay_InsufficientBalance_Returns422
Đầu vào: order total = 12.235.000đ; ví khả dụng = 5.000.000đ; không dùng cổng ngoài
Kỳ vọng: ném lỗi 422, kho được release, order giữ trạng thái PENDING
```

== Tiêu Chuẩn Phát Triển

=== Quy ước đặt tên
#figure(kind: table, caption: [Quy ước đặt tên])[
#table(
  columns: (1fr, 2.5fr),
  align: (left, left),
  [Ngữ cảnh], [Quy ước],
  [Go: kiểu/struct], [PascalCase (`OrderService`, `RefundRequest`)],
  [Go: hàm/biến], [PascalCase nếu export, camelCase nếu nội bộ],
  [SQL: bảng/cột], [snake_case số ít (`order`, `refund_id`, `total_amount`)],
  [REST: đường dẫn], [danh từ số nhiều, chữ thường (`/api/orders`, `/api/products`)],
  [Frontend: component], [PascalCase (`ProductCard`, `OfferCard`)],
)
]

=== Định dạng & tổ chức
- *Go:* `gofmt` + `golangci-lint`; tab thụt lề; dòng ≤ 100 ký tự.
- *Web (Next.js/TS):* Prettier + ESLint; *Mobile (Flutter):* `dart format`.
- *Comment:* giải thích *tại sao* (quyết định nghiệp vụ, bù trừ saga), không diễn giải lại code hiển nhiên.
- *Tổ chức repo:* monorepo, mỗi service một thư mục chia `handler/service/repository/model/dto`; tài liệu thiết kế trong `docs/`.

== Lập Kế Hoạch Triển Khai

=== Danh sách tác vụ chính
#figure(kind: table, caption: [Danh sách tác vụ chính])[
#table(
  columns: (0.5fr, 1.5fr, 2fr, 0.8fr),
  align: (center, left, left, center),
  [ID], [Hạng mục], [Tác vụ], [Ước tính],
  [T1], [Database], [Tạo schema, chạy DDL, seed dữ liệu tham chiếu.], [2 ngày],
  [T2], [Backend cốt lõi], [Model + Repository (SQLC/pgx) cho 7 service.], [5 ngày],
  [T3], [Backend nghiệp vụ], [Service + Validator; tích hợp Restate cho order.], [7 ngày],
  [T4], [API], [Handler + định tuyến Ingress/HTTP2; xác thực JWT.], [5 ngày],
  [T5], [Tích hợp ngoài], [Cổng thanh toán SePay/Stripe, vận chuyển GHN/GHTK (+ mock).], [4 ngày],
  [T6], [Frontend Web], [Next.js: các màn hình chính + gọi API.], [7 ngày],
  [T7], [Frontend Mobile], [Flutter: mua/bán, chat, thanh toán.], [6 ngày],
  [T8], [Kiểm thử], [Unit + integration + manual E2E; mock bên thứ ba.], [5 ngày],
  [T9], [Triển khai], [Docker hóa, k3s, health check, CI/CD.], [3 ngày],
)
]

=== Lịch biểu 8 tuần triển khai
#figure(kind: table, caption: [Lịch biểu 8 tuần triển khai])[
#table(
  columns: (0.7fr, 2.6fr, 1.3fr),
  align: (center, left, left),
  [Tuần], [Công việc], [Mốc quan trọng],
  [1], [Database setup, khung dự án, CI cơ bản (T1).], [DB sẵn sàng],
  [2–3], [Model, Repository; service nền (account, catalog) (T2, một phần T3).], [Backend cốt lõi chạy],
  [3–4], [Service nghiệp vụ + Restate cho Order/Escrow (T3).], [Luồng Escrow durable],
  [4–5], [API handler + xác thực + tích hợp ngoài (T4, T5).], [API hoàn chỉnh],
  [5–6], [Frontend Web + Mobile (T6, T7).], [Giao diện gọi được API],
  [6–7], [Tích hợp toàn hệ thống + kiểm thử (T8).], [E2E xanh],
  [8], [Sửa lỗi, đánh bóng, triển khai & tài liệu (T9).], [Bản demo bàn giao],
)
]

=== Đăng ký rủi ro
#figure(kind: table, caption: [Đăng ký rủi ro])[
#table(
  columns: (0.5fr, 1.8fr, 0.6fr, 0.6fr, 1.8fr),
  align: (center, left, center, center, left),
  [ID], [Rủi ro], [Xác suất], [Tác động], [Giảm thiểu],
  [RR-1], [Đường cong học Restate/Go làm chậm tiến độ.], [Trung bình], [Cao], [Học sớm qua prototype luồng Escrow; giới hạn durable cho luồng thật sự cần.],
  [RR-2], [Tích hợp SePay/Stripe & GHN/GHTK không ổn định.], [Trung bình], [Cao], [Mock server từ đầu; circuit breaker + polling dự phòng (NFR-015).],
  [RR-3], [Dữ liệu lệch giữa các service (distributed).], [Thấp], [Cao], [Restate journal + append-only audit log (NFR-009) để đối soát.],
  [RR-4], [Chi phí vận hành Kubernetes vượt dự kiến.], [Trung bình], [Trung bình], [Dùng k3s nhẹ cho demo; Docker Compose cho dev.],
  [RR-5], [Quản lý thời gian nhóm 3 người / 8 tuần.], [Trung bình], [Cao], [Bám lịch tuần, ưu tiên luồng cốt lõi, cắt tính năng phụ.],
  [RR-6], [Mở rộng phạm vi (scope creep).], [Trung bình], [Trung bình], [Khóa phạm vi theo 13 use case + 38 REQ đã chốt.],
)
]

Kết thúc giai đoạn thiết kế, toàn bộ tài liệu thiết kế cấp cao (thành phần, API, CSDL vật lý, bảo mật) và cấp thấp (lớp, trình tự, UI, DDL) cùng kế hoạch triển khai đã hoàn tất, sẵn sàng cho giai đoạn hiện thực hóa hệ thống ShopNexus C2C.
