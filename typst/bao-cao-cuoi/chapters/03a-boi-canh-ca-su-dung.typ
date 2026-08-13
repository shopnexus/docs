#import "../../common/tokens.typ": *

== Phân tích và so sánh các công trình liên quan

Thị trường mua bán đồ cũ, hàng thanh lý và đồ thủ công cá nhân (C2C - Consumer-to-Consumer) tại Việt Nam đang phát triển mạnh mẽ nhờ sự gia tăng của xu hướng tiêu dùng bền vững và nhu cầu tối ưu tài chính cá nhân. Tuy nhiên, hoạt động giao dịch giữa các cá nhân không chuyên hiện nay vẫn phân mảnh trên nhiều nền tảng với những hạn chế lớn về an toàn tài chính, cơ chế giải quyết tranh chấp và công nghệ hỗ trợ tìm kiếm. Ba nền tảng dưới đây được chọn để đối chiếu vì chúng chiếm phần lớn lưu lượng giao dịch trực tuyến trong nước theo khảo sát thường niên của Hiệp hội Thương mại điện tử Việt Nam [1].

=== Phân tích các mô hình sàn giao dịch phổ biến
*Chợ Tốt (chotot.com) - Mô hình sàn rao vặt (Classified Ads):*
- *Ưu điểm:* Là nền tảng rao vặt đồ cũ lớn nhất Việt Nam với lưu lượng người dùng khổng lồ. Quy trình đăng tin bán rất nhanh chóng, giao diện đơn giản, phân loại tốt theo khu vực địa lý giúp người mua/bán dễ dàng kết nối trong bán kính gần.
- *Hạn chế:* Bản chất của Chợ Tốt chủ yếu chỉ là bảng tin kết nối người mua và người bán tự liên hệ với nhau (qua số điện thoại hoặc khung chat đơn giản). Nền tảng thiếu một cơ chế bảo lãnh tài chính ký quỹ tích hợp sâu cho các giao dịch từ xa; hầu hết người mua phải thanh toán chuyển khoản trước (dễ bị lừa đảo lừa cọc) hoặc hẹn gặp mặt trực tiếp/ship COD tự phát (dễ gặp rủi ro "boom hàng", tốn phí vận chuyển). Khi sản phẩm nhận được không đúng mô tả hoặc hư hỏng, người mua hoàn toàn không có công cụ pháp lý hay đội ngũ điều phối viên nội bộ nào của sàn đứng ra phân xử và bảo vệ dòng tiền.

*Facebook Marketplace & Các hội nhóm xã hội (Social C2C):*
- *Ưu điểm:* Tận dụng mạng lưới xã hội khổng lồ có sẵn, tốc độ tương tác cực nhanh qua Messenger, thao tác đăng bán tiện lợi không tốn phí sàn.
- *Hạn chế:* Hoàn toàn thiếu các chuẩn mực của một nền tảng TMĐT chuyên nghiệp: không có hệ thống quản lý đơn hàng, không có tích hợp cổng thanh toán an toàn, không có cơ chế giữ cọc hay chính sách hoàn tiền. Các hành vi gian lận, tài khoản ảo (clone) lừa đảo chuyển khoản diễn ra rất phổ biến mà không có cơ chế kiểm duyệt hay hạn chế.

*Shopee / Lazada - Mô hình B2C bán chuyên (Managed Marketplace):*
- *Ưu điểm:* Hệ sinh thái logistics, cổng thanh toán và chính sách bảo vệ người mua cực kỳ hoàn thiện (như Shopee Đảm Bảo).
- *Hạn chế:* Được thiết kế tối ưu cho mô hình B2C hoặc nhà bán hàng chuyên nghiệp. Quy trình đăng ký gian hàng và đăng bán sản phẩm rất rườm rà (đòi hỏi cấu hình mã SKU, thông tin doanh nghiệp/thuế, thiết lập kho hàng chuyên sâu), kèm theo mức phí sàn và phí hoa hồng cao (thường từ 8–15%). Mô hình này không hề phù hợp cho một cá nhân thông thường chỉ muốn thanh lý nhanh 1–2 món đồ cũ cá nhân. Bên cạnh đó, cơ chế trả giá thường bị ràng buộc bởi các mã giảm giá/voucher cố định, thiếu sự linh hoạt thương lượng giá trực tiếp từng đơn hàng trong khung chat giữa hai cá nhân.

=== Phân tích các vai trò người dùng (Persona)
Hệ thống được thiết kế phục vụ cho 3 nhóm đối tác nhân chính, với các mục tiêu nghiệp vụ, đặc tính hành vi và ranh giới phân quyền rõ rệt:

*1. Người dùng phổ thông (User)*
- *Mục tiêu:* Có thể vừa tìm mua đồ cũ chất lượng giá tốt vừa đăng thanh lý nhanh chóng các món đồ cá nhân không dùng đến; giao dịch an toàn và có thể thương lượng giá dễ dàng với người bán qua chat; được hoàn tiền nếu sản phẩm bị hỏng/lỗi.
- *Điểm khó khăn:* E ngại hàng nhận được khác hoàn toàn so với ảnh quảng cáo của người bán; rất sợ chuyển tiền trước nhưng bị người bán bùng hàng; sợ người mua tráo đổi hàng lỗi khác rồi khiếu nại vô lý.
- *Cách tham gia hệ thống:* Tự đăng ký tài khoản trực tuyến công khai, đóng vai trò là người mua, được cấp quyền bán khi và chỉ khi xác minh danh tính trên hệ thống.

*2. Điều phối viên (Moderator)*
- *Mục tiêu:* Vận hành, tiếp nhận nhanh chóng các đơn khiếu nại trả hàng/hoàn tiền bị từ chối; xem xét chứng cứ trực quan để giải quyết tranh chấp công bằng giữa các User; hỗ trợ chăm sóc khách hàng (CSKH) kịp thời.
- *Điểm khó khăn:* Các bên tranh chấp không cung cấp đủ video mở hộp/đóng gói hàng rõ nét; gặp khó khăn khi số lượng tranh chấp tăng cao đột biến.
- *Cách tham gia hệ thống:* Được Quản trị viên tối cao (Super Admin) cấp phát tài khoản trực tiếp, không có quyền tự đăng ký.

*3. Quản trị viên tối cao (Super Admin)*
- *Mục tiêu:* Theo dõi và đối soát luồng tiền ký quỹ tổng thể; quản trị nhân sự Moderator (cấp phát, khóa tài khoản); cấu hình các quy định và tham số hệ thống của sàn.
- *Điểm khó khăn:* Phải đảm bảo tính bảo mật tuyệt đối của dòng tiền ký quỹ; kiểm soát hoạt động của các Moderator để tránh hành vi thiên vị hoặc lạm quyền.
- *Cách tham gia hệ thống:* Cấu hình sẵn từ đầu, là duy nhất và có quyền hạn cao nhất.

=== Các hệ thống ngoại vi và đối tác tích hợp
Để bảo đảm tính trọn vẹn của quy trình thương mại điện tử C2C, hệ thống thiết lập tích hợp liên thông với hai nhóm đối tác hạ tầng công nghệ ngoại vi. Cổng thanh toán ngoại vi (SePay / Stripe) tiếp nhận yêu cầu khởi tạo link thanh toán, xử lý giao dịch nạp tiền và thanh toán chuyển khoản ngân hàng từ người mua, rồi gửi phản hồi trạng thái giao dịch qua webhook bảo mật về sàn. Đối tác vận chuyển (GHN / GHTK) tiếp nhận thông tin địa chỉ lấy hàng và giao hàng để tính toán phí ship động (real-time quotation), khởi tạo mã vận đơn (shipping order) và liên tục đẩy sự kiện hành trình giao nhận về hệ thống để kích hoạt các mốc nghiệp vụ.

=== Sơ đồ ngữ cảnh hệ thống (System Context Diagram)

Sơ đồ ngữ cảnh đặt hệ thống vào giữa và chỉ vẽ những gì đi qua đường biên của nó. Bên trái là
3 vai trò người dùng đã mô tả ở trên: người dùng gửi vào các yêu cầu đăng ký, đặt mua, đăng
bán, trò chuyện, hoàn tiền và tranh chấp; điều phối viên gửi vào các thao tác xử lý khiếu nại,
phân xử và chăm sóc khách hàng; quản trị viên gửi vào việc quản lý tài khoản và đối soát. Bên
phải là 2 nhóm đối tác ngoại vi: cổng thanh toán trao đổi luồng thanh toán và hoàn tiền, đối
tác vận chuyển trao đổi vận đơn và các mốc hành trình. Điều đáng chú ý ở mức ngữ cảnh là mọi
đường tiền và mọi đường hàng đều đi qua hệ thống chứ không nối trực tiếp giữa 2 cá nhân, và
đó chính là điều kiện kỹ thuật để cơ chế ký quỹ tồn tại.

#fig(
  [Sơ đồ ngữ cảnh hệ thống (System Context Diagram)],
  spacing: (40mm, 16mm),

  // Cột trái: tác nhân người dùng — dùng cùng 1 dạng node (nt) cho cả 3
  nt((0, 0), [Người dùng\ (User)]),
  nt((0, 1), [Điều phối viên\ (Moderator)]),
  nt((0, 2), [Quản trị viên\ (Admin)]),

  // Cột giữa: hệ thống trung tâm
  ncore((1, 1), [Hệ thống]),

  // Cột phải: hệ thống ngoại vi — cùng dạng ng
  ng((2, 0), [Cổng thanh toán]),
  ng((2, 2), [Đối tác vận chuyển]),

  // Đường nối actor trái ↔ Core — nhãn căn giữa sát line
  edge((0, 0), (1, 1), "<|-|>",
    text(size: 8pt)[Đăng ký · Đặt mua · Đăng bán \ Chat · Hoàn tiền · Tranh chấp],
    label-pos: 0.4, label-side: left),
  edge((0, 1), (1, 1), "<|-|>",
    text(size: 7pt)[Xử lý khiếu nại · Phân xử · CSKH],
    label-pos: 0.5, label-side: right),
  edge((0, 2), (1, 1), "<|-|>",
    text(size: 8pt)[Quản lý tài khoản · Đối soát],
    label-pos: 0.4, label-side: right),

  // Đường nối Core ↔ hệ thống phải
  edge((1, 1), (2, 0), "<|-|>",
    text(size: 8pt)[Thanh toán · Hoàn tiền],
    label-pos: 0.5, label-side: left),
  edge((1, 1), (2, 2), "<|-|>",
    text(size: 8pt)[Vận đơn · Hành trình],
    label-pos: 0.5, label-side: left),
)


== Danh mục ca sử dụng

Mỗi ca sử dụng trong tài liệu đại diện cho một mục tiêu nghiệp vụ hoàn chỉnh của tác nhân, thay vì chỉ mô tả các thao tác hệ thống riêng lẻ. Danh mục gồm 30 ca sử dụng nghiệp vụ, được định danh từ UC-01 đến UC-30 và phân thành sáu nhóm chức năng, cùng với hai ca sử dụng dùng chung được tái sử dụng thông qua quan hệ bao hàm. Để bảo đảm tính rõ ràng và thuận tiện trong việc theo dõi phạm vi hệ thống, danh mục ca sử dụng và các sơ đồ liên quan được tổ chức theo từng phân hệ.

Do nền tảng hoạt động theo mô hình C2C, hệ thống không tách biệt vai trò người mua và người bán thành các loại tài khoản riêng. Mỗi tài khoản có thể đồng thời thực hiện cả hoạt động mua và bán trên cùng một định danh. Vì vậy, chức năng quản lý hoạt động bán hàng được thể hiện thông qua việc quản lý các tin đăng của chính tài khoản, bao gồm UC-06 Đăng bán sản phẩm, UC-08 Chỉnh sửa tin đăng, cùng các chức năng theo dõi đơn hàng và quản lý ví ở các nhóm chức năng tương ứng, thay vì xây dựng một phân hệ quản trị gian hàng riêng biệt.

#figure(
  kind: table,
  caption: [Danh mục ca sử dụng của hệ thống ShopNexus],
  table(
    columns: (0.8fr, 2fr, 1.5fr, 3.2fr),
    align: (center + horizon, left + top, left + top, left + top),
    table.header([Mã], [Tên ca sử dụng], [Tác nhân chính], [Mô tả]),

    table.cell(colspan: 4, align: left)[*Nhóm A. Định danh, tài khoản và phân quyền*],
    [UC-01], [Đăng ký tài khoản], [Người dùng], [Tạo tài khoản bằng địa chỉ thư điện tử hoặc một thẻ định danh liên kết.],
    [UC-02], [Đăng nhập và quản lý phiên], [Mọi vai trò], [Xác thực và mở một phiên được tra cứu ở mỗi yêu cầu; đổi mật khẩu thu hồi mọi phiên còn lại.],
    [UC-03], [Xác minh danh tính điện tử], [Người dùng], [Gửi ảnh giấy tờ và ảnh chân dung để được cấp quyền đăng bán và quyền rút tiền.],
    [UC-04], [Quản lý hồ sơ, sổ địa chỉ và thiết bị], [Người dùng], [Sửa thông tin hiển thị, khai địa chỉ giao và địa chỉ lấy hàng, đăng ký thiết bị nhận thông báo.],
    [UC-05], [Cấp phát tài khoản điều phối viên], [Quản trị viên], [Tạo hoặc thu hồi tài khoản điều phối viên; vai trò này không tự đăng ký được.],

    table.cell(colspan: 4, align: left)[*Nhóm B. Đăng bán và khám phá*],
    [UC-06], [Đăng bán sản phẩm], [Người bán], [Soạn tin đăng, chọn chế độ giá, khai tồn kho theo phiên bản và gửi tin vào hàng đợi duyệt.],
    [UC-07], [Gợi ý điền tin đăng bằng trí tuệ nhân tạo], [Người bán], [Từ ảnh sản phẩm cùng ghi chú gõ tay hoặc ghi âm, nhận về một biểu mẫu tin đăng đã điền sẵn.],
    [UC-08], [Chỉnh sửa tin đăng đang hiển thị], [Người bán], [Gửi một bản sửa; bản sửa chờ duyệt trong khi bản đang hiển thị giữ nguyên.],
    [UC-09], [Tìm kiếm và duyệt sản phẩm], [Người mua], [Truy vấn bằng từ khoá kết hợp tìm kiếm ngữ nghĩa, lọc và sắp xếp theo nhiều tiêu chí.],
    [UC-10], [Theo dõi người bán và lưu sản phẩm quan tâm], [Người mua], [Theo dõi một người bán, đánh dấu sản phẩm để xem lại.],

    table.cell(colspan: 4, align: left)[*Nhóm C. Trao đổi và thương lượng*],
    [UC-11], [Nhắn tin thời gian thực], [Người dùng], [Trao đổi trực tiếp kèm ảnh và tệp, nhận tin tức thời, theo dõi dấu đã đọc và số tin chưa đọc.],
    [UC-12], [Thương lượng giá], [Người mua], [Mở thương lượng trên tin cho phép trả giá; hai bên luân phiên đề xuất tới khi một bên chấp thuận.],

    table.cell(colspan: 4, align: left)[*Nhóm D. Giao dịch, ký quỹ và vận chuyển*],
    [UC-13], [Quản lý giỏ hàng], [Người mua], [Thêm, sửa số lượng và bỏ bớt các dòng hàng đang quan tâm; giỏ giữ tham chiếu tới tin đăng và tuỳ chọn chứ không giữ giá, nên giá luôn được đọc lại tại thời điểm chốt mua.],
    [UC-14], [Chuẩn bị đơn mua và lấy báo giá vận chuyển], [Người mua], [Chọn hàng và địa chỉ nhận, xin báo giá của từng hãng và chốt một phương án.],
    [UC-15], [Thanh toán và ký quỹ], [Người mua], [Mở phiên trả tiền tại cổng thanh toán; khi cổng báo về, tiền vào ký quỹ và đơn hàng ra đời.],
    [UC-16], [Xác nhận đơn hàng đã thanh toán], [Người bán], [Xác nhận đơn trong 48 giờ để mở đường đặt vận đơn, hoặc từ chối kèm lý do.],
    [UC-17], [Theo dõi hành trình kiện hàng], [Người mua], [Xem các mốc hành trình do hãng vận chuyển báo về theo thứ tự tiến tới.],
    [UC-18], [Xác nhận đã nhận hàng], [Người mua], [Xác nhận kèm bằng chứng, khởi động cửa sổ 72 giờ trước khi tiền về người bán.],
    [UC-19], [Quản lý ví và rút tiền], [Người dùng], [Theo dõi số dư khả dụng và đang giữ, xem sổ bút toán, gửi yêu cầu rút về tài khoản ngân hàng.],

    table.cell(colspan: 4, align: left)[*Nhóm E. Hậu giao dịch và uy tín*],
    [UC-20], [Yêu cầu trả hàng và hoàn tiền], [Người mua], [Mở yêu cầu kèm lý do và bằng chứng bất kỳ lúc nào trước khi đơn kết thúc.],
    [UC-21], [Xử lý yêu cầu hoàn tiền], [Người bán], [Chấp nhận cho trả hàng, hoặc chuyển hồ sơ cho sàn phân xử; không có lựa chọn từ chối.],
    [UC-22], [Đánh giá sản phẩm và bình chọn hữu ích], [Người mua], [Viết nhận xét cho sản phẩm đã mua; đánh dấu một nhận xét là hữu ích.],

    table.cell(colspan: 4, align: left)[*Nhóm F. Hỗ trợ, kiểm duyệt và quản trị*],
    [UC-23], [Gửi phiếu hỗ trợ], [Người dùng], [Gửi mọi loại yêu cầu lên sàn: tố cáo, hồ sơ hoàn tiền, sự cố đơn, vướng mắc thanh toán, đề xuất.],
    [UC-24], [Tiếp nhận và trả lời phiếu hỗ trợ], [Điều phối viên], [Trả lời trong hội thoại của phiếu, ghi kết luận xử lý.],
    [UC-25], [Kiểm duyệt tin đăng và bản sửa], [Điều phối viên], [Duyệt hoặc từ chối tin đăng mới và bản sửa; gỡ một tin đang hiển thị khi có vi phạm.],
    [UC-26], [Phân xử yêu cầu hoàn tiền], [Điều phối viên], [Ra phán quyết cho hồ sơ đã chuyển lên sàn khi có tranh chấp liên quan.],
    [UC-27], [Duyệt hồ sơ xác minh danh tính], [Điều phối viên], [Xem lại phán quyết của nhà cung cấp, chấp nhận hoặc từ chối kèm lý do.],
    [UC-28], [Quản lý cây danh mục và sổ tuỳ chọn], [Quản trị viên], [Sắp lại cây danh mục; bật, tắt cho từng dòng của sổ tuỳ chọn.],
    [UC-29], [Đối soát ví và điều chỉnh số dư], [Quản trị viên], [Xem ví của một tài khoản, ghi bút toán điều chỉnh kèm lý do, duyệt hoặc từ chối yêu cầu rút.],
    [UC-30], [Giám sát vận hành qua dữ liệu quan trắc], [Quản trị viên], [Theo dõi lưu lượng, độ trễ, lỗi và các sự kiện nghiệp vụ.],

    table.cell(colspan: 4, align: left)[*Nhóm G. Ca sử dụng con dùng chung (quan hệ «include»)*],
    [UC-S1], [Tải lên và xác nhận tệp đính kèm], [Người dùng], [Xin đường tải lên có chữ ký, đẩy tệp lên kho lưu trữ và xác nhận để tệp gắn được vào nghiệp vụ.],
    [UC-S2], [Ghi nhật ký kiểm toán], [Hệ thống], [Ghi một bản ghi chỉ-thêm-mới cho mọi quyết định nghiệp vụ, kèm tác nhân và thời điểm gắn với thay đổi đó.],
  )
)

Danh mục ca sử dụng được phân tách thành hai lược đồ thay vì biểu diễn toàn bộ 30 ca nghiệp vụ trên cùng một hình, nhằm tránh tình trạng các đường liên kết giữa tác nhân và ca sử dụng chồng chéo, làm giảm khả năng đọc. Lược đồ thứ nhất bao gồm các nhóm A, B và C, tập trung vào các chức năng diễn ra trước giai đoạn giao dịch tài chính như định danh, đăng bán, khám phá sản phẩm và trao đổi giữa người dùng. Lược đồ thứ hai bao gồm các nhóm D, E và F, thể hiện các chức năng liên quan đến giao dịch, hậu giao dịch và quản trị hệ thống. Cách tổ chức này giúp giới hạn số lượng tác nhân xuất hiện trong mỗi lược đồ và giữ cấu trúc biểu diễn rõ ràng hơn.

Hai loại quan hệ giữa các ca sử dụng được thể hiện bằng đường nét đứt kèm nhãn `«include»` và `«extend»`. Quan hệ `«include»` được sử dụng khi một ca sử dụng bắt buộc phải gọi tới một ca sử dụng khác như một phần của luồng xử lý, chẳng hạn xác minh danh tính và đăng bán đều sử dụng chức năng tải lên tệp đính kèm, trong khi các thao tác ra quyết định của điều phối viên và quản trị viên đều bao gồm bước ghi nhật ký kiểm toán. Ngược lại, quan hệ `«extend»` biểu diễn các hành vi chỉ phát sinh trong những điều kiện cụ thể mà không làm ảnh hưởng đến tính hoàn chỉnh của luồng chính.

#fig(
  [Sơ đồ ca sử dụng phân hệ định danh, đăng bán, khám phá và trao đổi],
  spacing: (34mm, 10.5mm),
  node(enclose: (<a1>, <a2>, <a3>, <a4>, <a5>, <a6>, <a7>, <a8>, <a9>, <a10>, <a11>, <a12>, <as1>),
    inset: 15pt, stroke: (paint: ink, dash: "dashed", thickness: 0.9pt),
    fill: none, corner-radius: 8pt),
  node((2, -1.15), text(size: 9pt, weight: 700)[Ranh giới hệ thống: Phân hệ Định danh, Đăng bán và Trao đổi],
    fill: white, stroke: none),

  nt((2, -0.4), [UC-01 · Đăng ký tài khoản], name: <a1>),
  nt((2, 0.4), [UC-02 · Đăng nhập và quản lý phiên], name: <a2>),
  nt((2, 1.2), [UC-03 · Xác minh danh tính điện tử], name: <a3>),
  nt((2, 2.0), [UC-04 · Quản lý hồ sơ và sổ địa chỉ], name: <a4>),
  nt((2, 2.8), [UC-07 · Gợi ý điền tin đăng], name: <a5>),
  nt((2, 3.6), [UC-06 · Đăng bán sản phẩm], name: <a6>),
  nt((2, 4.4), [UC-08 · Chỉnh sửa tin đăng đang hiển thị], name: <a7>),
  nt((2, 5.2), [UC-09 · Tìm kiếm và duyệt sản phẩm], name: <a8>),
  nt((2, 6.0), [UC-10 · Theo dõi và lưu quan tâm], name: <a9>),
  nt((2, 6.8), [UC-11 · Nhắn tin thời gian thực], name: <a11>),
  nt((2, 7.6), [UC-12 · Thương lượng giá], name: <a12>),
  nt((2, 8.4), [UC-05 · Cấp phát tài khoản điều phối viên], name: <a10>),
  nt((3.25, 1.9), text(size: 8pt)[UC-S1 · Tải lên\ tệp đính kèm], name: <as1>),

  nact((0, 3.4), [Người dùng]),
  nact((0, 8.4), [Quản trị viên]),
  nact((4.4, 0.9), text(size: 7pt)[Định danh\ liên kết]),
  nact((4.4, 2.9), text(size: 7pt)[Dịch vụ xác minh\ danh tính]),
  nact((4.4, 4.6), text(size: 7pt)[Mô hình\ ngôn ngữ]),

  edge((0, 3.4), <a1>, stroke: 0.7pt + blue-s),
  edge((0, 3.4), <a2>, stroke: 0.7pt + blue-s),
  edge((0, 3.4), <a3>, stroke: 0.7pt + blue-s),
  edge((0, 3.4), <a4>, stroke: 0.7pt + blue-s),
  edge((0, 3.4), <a5>, stroke: 0.7pt + blue-s),
  edge((0, 3.4), <a6>, stroke: 0.7pt + blue-s),
  edge((0, 3.4), <a7>, stroke: 0.7pt + blue-s),
  edge((0, 3.4), <a8>, stroke: 0.7pt + blue-s),
  edge((0, 3.4), <a9>, stroke: 0.7pt + blue-s),
  edge((0, 3.4), <a11>, stroke: 0.7pt + blue-s),
  edge((0, 3.4), <a12>, stroke: 0.7pt + blue-s),
  edge((0, 8.4), <a10>, stroke: 0.7pt + red),

  edge((4.4, 0.9), <a1>, stroke: 0.7pt + teal),
  edge((4.4, 2.9), <a3>, stroke: 0.7pt + teal),
  edge((4.4, 4.6), <a5>, stroke: 0.7pt + teal),

  // UC-07 chỉ chạy khi người bán chọn nhờ máy gợi ý, nên là quan hệ mở rộng chứ
  // không phải bao hàm. Uốn cong sang phải để không đè lên cột ca sử dụng.
  edge(<a5>, <a6>, "-|>", stroke: (dash: "dashed"), bend: -40deg,
    text(size: 7pt)[«extend»]),
  edge(<a3>, <as1>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«include»]),
  edge(<a6>, <as1>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«include»]),
)

#fig(
  [Sơ đồ ca sử dụng phân hệ giao dịch, hậu giao dịch và quản trị],
  spacing: (35mm, 10.5mm),
  node(enclose: (<b0>, <b1>, <b2>, <b3>, <b4>, <b5>, <b6>, <b7>, <b8>, <b10>, <b11>, <b12>, <b13>, <b14>, <b15>, <b16>, <b17>, <b18>, <bs2>),
    inset: 15pt, stroke: (paint: ink, dash: "dashed", thickness: 0.9pt),
    fill: none, corner-radius: 8pt),
  node((2, -1.55), text(size: 9pt, weight: 700)[Ranh giới hệ thống: Phân hệ Giao dịch, Hậu giao dịch và Quản trị],
    fill: white, stroke: none),

  nt((2, -0.72), [UC-13 · Quản lý giỏ hàng], name: <b0>),
  nt((2, 0), [UC-14 · Chuẩn bị đơn mua và báo giá], name: <b1>),
  nt((2, 0.72), [UC-15 · Thanh toán và ký quỹ], name: <b2>),
  nt((2, 1.44), [UC-16 · Xác nhận đơn đã thanh toán], name: <b3>),
  nt((2, 2.16), [UC-17 · Theo dõi hành trình kiện hàng], name: <b4>),
  nt((2, 2.88), [UC-18 · Xác nhận đã nhận hàng], name: <b5>),
  nt((2, 3.6), [UC-19 · Quản lý ví và rút tiền], name: <b6>),
  nt((2, 4.32), [UC-20 · Yêu cầu trả hàng và hoàn tiền], name: <b7>),
  nt((2, 5.04), [UC-21 · Xử lý yêu cầu hoàn tiền], name: <b8>),
  nt((2, 6.48), [UC-22 · Đánh giá sản phẩm], name: <b10>),
  nt((2, 7.2), [UC-23 · Gửi phiếu hỗ trợ], name: <b11>),
  nt((2, 7.92), [UC-24 · Tiếp nhận và trả lời phiếu], name: <b12>),
  nt((2, 8.64), [UC-25 · Kiểm duyệt tin đăng và bản sửa], name: <b13>),
  nt((2, 9.36), [UC-26 · Phân xử yêu cầu hoàn tiền], name: <b14>),
  nt((2, 10.08), [UC-27 · Duyệt hồ sơ xác minh danh tính], name: <b15>),
  nt((2, 10.8), [UC-28 · Quản lý danh mục và sổ tuỳ chọn], name: <b16>),
  nt((2, 11.52), [UC-29 · Đối soát ví và điều chỉnh số dư], name: <b17>),
  nt((2, 12.24), [UC-30 · Giám sát vận hành], name: <b18>),
  nt((3.35, 9.9), text(size: 8pt)[UC-S2 · Ghi nhật ký\ kiểm toán], name: <bs2>),

  nact((0, 2.5), [Người mua]),
  nact((0, 6.2), [Người bán]),
  nact((4.5, 0.6), text(size: 7pt)[Cổng\ thanh toán]),
  nact((4.5, 2.4), text(size: 7pt)[Đối tác\ vận chuyển]),
  nact((4.5, 8.6), [Điều phối viên]),
  nact((4.5, 11.7), [Quản trị viên]),

  edge((0, 2.5), <b0>, stroke: 0.7pt + blue-s),
  edge((0, 2.5), <b1>, stroke: 0.7pt + blue-s),
  edge((0, 2.5), <b2>, stroke: 0.7pt + blue-s),
  edge((0, 2.5), <b4>, stroke: 0.7pt + blue-s),
  edge((0, 2.5), <b5>, stroke: 0.7pt + blue-s),
  edge((0, 2.5), <b6>, stroke: 0.7pt + blue-s),
  edge((0, 2.5), <b7>, stroke: 0.7pt + blue-s),
  
  edge((0, 2.5), <b10>, stroke: 0.7pt + blue-s),
  edge((0, 2.5), <b11>, stroke: 0.7pt + blue-s),
  edge((0, 6.2), <b3>, stroke: 0.7pt + teal),
  edge((0, 6.2), <b6>, stroke: 0.7pt + teal),
  edge((0, 6.2), <b8>, stroke: 0.7pt + teal),
  edge((0, 6.2), <b11>, stroke: 0.7pt + teal),

  edge((4.5, 0.6), <b2>, stroke: 0.7pt + teal),
  edge((4.5, 0.6), <b6>, stroke: 0.7pt + teal, text(size: 7pt)[chi trả lệnh rút], label-side: right),
  edge((4.5, 2.4), <b1>, stroke: 0.7pt + teal),
  edge((4.5, 2.4), <b4>, stroke: 0.7pt + teal),
  edge((4.5, 8.6), <b12>, stroke: 0.7pt + teal),
  edge((4.5, 8.6), <b13>, stroke: 0.7pt + teal),
  edge((4.5, 8.6), <b14>, stroke: 0.7pt + teal),
  edge((4.5, 8.6), <b15>, stroke: 0.7pt + teal),
  edge((4.5, 11.7), <b16>, stroke: 0.7pt + red),
  edge((4.5, 11.7), <b17>, stroke: 0.7pt + red),
  edge((4.5, 11.7), <b18>, stroke: 0.7pt + red),

  // Phân xử chỉ diễn ra khi người bán từ chối hoặc hết hạn trả lời, tức một
  // nhánh có điều kiện của việc xử lý hoàn tiền.
  edge(<b14>, <b8>, "-|>", stroke: (dash: "dashed"), bend: -58deg,
    text(size: 7pt)[«extend»]),
  edge(<b14>, <bs2>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«include»]),
  edge(<b13>, <bs2>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«include»]),
  edge(<b17>, <bs2>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«include»]),
)

== Đặc tả chi tiết các ca sử dụng trọng yếu

Hai ca sử dụng dưới đây được lựa chọn để đặc tả chi tiết theo mẫu UML vì đồng thời đáp ứng ba tiêu chí: tác động trực tiếp đến dòng tiền, có nhiều hơn một nhánh kết thúc và thể hiện đặc trưng nghiệp vụ riêng của nền tảng. 28 ca sử dụng còn lại chủ yếu có luồng xử lý tuyến tính hoặc lặp lại các mẫu nghiệp vụ tương tự, vì vậy được mô tả ở mức danh mục nhằm tránh trùng lặp và giữ tài liệu cô đọng.

#ucspec("UC-15", "Thanh toán và ký quỹ",
  [Tác nhân], [Chính: người mua. Phụ: cổng thanh toán, đối tác vận chuyển (báo giá đã chốt ở UC-14).],
  [Mô tả], [Người mua trả tiền hàng cộng phí giao hàng qua một cổng thanh toán; tiền vào tài khoản giữ hộ của sàn chứ không tới người bán, và đơn hàng ra đời ngay khi cổng báo về.],
  [Điều kiện trước], [Đã đăng nhập; có một phiếu mua tạm còn hiệu lực (UC-14) hoặc một thương lượng đã chấp thuận còn hiệu lực (UC-12); phương án vận chuyển đã chốt kèm mức phí.],
  [Sự kiện kích hoạt], [Người mua bấm trả tiền trên màn hình xác nhận đơn mua.],
  [Luồng chính], [(1) Người mua xem lại đơn rồi chọn một cổng thanh toán đang bật. (2) Hệ thống giành quyền mua trước, đánh dấu phiếu mua tạm hoặc thương lượng là đã dùng. (3) Hệ thống mở phiên thanh toán hạn 15 phút gồm 2 khoản tách bạch là tiền hàng và phí giao hàng, rồi chuyển người mua sang trang của cổng. (4) Người mua trả tiền; cổng gửi thông báo kết quả về. (5) Hệ thống ghi nhận phiên đã trả, giữ tiền hàng vào ký quỹ và tách phí giao hàng thành khoản riêng. (6) Hệ thống tạo đơn chờ người bán xác nhận, tạo kiện hàng, giảm tồn kho và báo cho người bán (UC-16).],
  [Luồng thay thế và ngoại lệ], [*[1a]* Người mua huỷ giữa chừng: phiên bị huỷ, phần đã giành được trả lại. [3a] Hết 15 phút mà chưa trả tiền: phiên không còn trả được và phần đã giành được trả lại (BR-23). [4a] Người mua quay về trang kết quả trước khi thông báo tới: hệ thống hiển thị phiên đang chờ, vì trang đáp xuống ai cũng mở được nên không phải bằng chứng. [4b] Cổng gửi lặp thông báo: xử lý bất biến với lặp lại nên chỉ một đơn được tạo. [5a] Xử lý thông báo thất bại: trả lỗi để cổng gửi lại.],
  [Điều kiện sau], [Tiền hàng nằm trong ký quỹ, phí giao hàng ở khoản riêng, tồn tại đúng một đơn chờ người bán xác nhận, và đơn ghi rõ nó sinh ra từ phiếu mua tạm hay từ thương lượng.],
  [Quy tắc nghiệp vụ], [BR-21, BR-22, BR-23, BR-24, BR-25, BR-26, BR-54],
  [Yêu cầu đặc biệt], [Quyền mua phải được giành trước khi phiên thanh toán được mở. Nếu giành sau, 2 lần bấm sẽ mở hai phiên, và một lần bán có thể thu tiền 2 lần.],
  [Giả định và vấn đề còn để mở], [Giả định: cổng thanh toán gửi lại thông báo cho tới khi hệ thống nhận thành công. Còn để mở: một phiên quá hạn tuy đã trả lại mọi phần đã giành nhưng vẫn nằm ở trạng thái chờ trong sổ sách, làm danh sách phiên dài ra vô ích.],
  [Tần suất], [Rất cao, là ca sử dụng trung tâm của toàn hệ thống.],
)

#ucspec("UC-20", "Yêu cầu trả hàng và hoàn tiền",
  [Tác nhân], [Chính: người mua. Phụ: người bán (bên phải trả lời).],
  [Mô tả], [Người mua khiếu nại hàng lỗi hoặc không đúng mô tả; yêu cầu luôn toàn phần và khoá đơn khỏi việc giải ngân cho tới khi có kết luận.],
  [Điều kiện trước], [Đơn hàng chưa kết thúc; người mua là chủ đơn; đơn chưa có yêu cầu hoàn tiền nào đang sống.],
  [Sự kiện kích hoạt], [Người mua bấm yêu cầu trả hàng trên màn hình chi tiết đơn.],
  [Luồng chính], [(1) Người mua mở đơn, chọn yêu cầu trả hàng, nêu lý do và đính kèm bằng chứng (bao hàm UC-S1). (2) Hệ thống tạo hồ sơ chờ người bán trả lời, đặt hạn 48 giờ, loại đơn khỏi danh sách chờ giải ngân và báo cho người bán. (3) Người bán chấp nhận cho trả hàng (UC-21); hệ thống mở một chặng vận chuyển trả hàng phí bằng không. (4) Người bán nhận hàng và xác nhận, rồi có 48 giờ để kiểm hàng. (5) Hết cửa sổ đó mà người bán không có ý kiến, hệ thống hoàn tiền hàng cho người mua và đóng hồ sơ.],
  [Luồng thay thế và ngoại lệ], [*[1a]* Đơn đã kết thúc hoặc đã có một hồ sơ đang sống: hệ thống từ chối. [2a] Người mua rút yêu cầu trước khi người bán trả lời: hồ sơ sang trạng thái đã rút, khác hẳn bị bác bỏ, và đơn quay lại danh sách chờ giải ngân. [3a] Người bán chuyển hồ sơ cho sàn: hồ sơ sang chờ phân xử và hệ thống tự mở một phiếu đứng tên người mua (UC-26). [3b] Người bán im lặng quá hạn: hồ sơ tự chuyển sang chờ phân xử và cũng tự mở phiếu, vì im lặng không phải đồng ý cũng không phải từ chối (BR-40). [4a] Người mua tự khai đã gửi trả hàng: đây là tuyên bố về kho của người khác, nên hồ sơ đi thẳng lên sàn phân xử. [4b] Người bán thấy thứ nhận về không khớp: chuyển hồ sơ lên sàn trong cửa sổ đó.],
  [Điều kiện sau], [Hồ sơ ở một trạng thái xác định và luôn có một bên đang phải hành động, hoặc đã kết thúc bằng một trong 4 kết cục: hoàn tiền, bị bác bỏ, được rút, hoặc chờ phán quyết của sàn.],
  [Quy tắc nghiệp vụ], [BR-27, BR-37, BR-38, BR-39, BR-40, BR-41, BR-42],
  [Yêu cầu đặc biệt], [Chấp nhận không phải là trả tiền: hàng phải quay về trước. Ngược lại, người bán vừa mất hàng vừa mất tiền chỉ vì một yêu cầu và 48 giờ không đọc thông báo.],
  [Giả định và vấn đề còn để mở], [Giả định: hoàn tiền luôn toàn phần, vì hàng đã qua sử dụng khó chia thành mức bồi thường một phần. Còn để mở: chặng trả hàng không được đặt với hãng nào, nên không có bên thứ ba xác nhận hàng đã lên đường.],
  [Tần suất], [Thấp so với các ca giao dịch, vì chỉ phát sinh khi có khiếu nại.],
)

== Bộ quy tắc nghiệp vụ

#figure(
  kind: table,
  caption: [Bộ quy tắc nghiệp vụ ràng buộc hệ thống],
  table(
    columns: (0.5fr, 0.8fr, 4.2fr),
    align: (center + horizon, center + horizon, left + top),
    table.header([Mã], [Loại], [Phát biểu]),

    table.cell(colspan: 3, align: left)[*a) Định danh, phân quyền và phiên làm việc*],
    [BR-01], [Cấu trúc], [3 vai trò: người dùng đăng ký công khai, điều phối viên do quản trị viên cấp phát, quản trị viên.],
    [BR-02], [Cấu trúc], [Một tài khoản đều có khả năng mua và bán, cá nhân muốn bán phải xác minh danh tính người dùng.],
    [BR-03], [Cấu trúc], [Bàn hỗ trợ là một tài khoản kỹ thuật duy nhất do hệ thống khởi tạo; tên đó bị cấm đăng ký, và một triển khai chưa khởi tạo được nó báo lỗi ngay ở phiếu đầu tiên.],
    [BR-04], [Kiểm tra], [Chỉ tài khoản có vai trò phù hợp mới được thao tác các quyền quản trị/kiểm duyệt tương ứng],
    [BR-05], [Thủ tục], [Mật khẩu luôn được mã hoá một chiều trước khi lưu; không có khả năng truy xuất được bản gốc.],
    [BR-06], [Thủ tục], [Mọi yêu cầu đã xác thực đều tra cứu lại phiên tương ứng, nhờ đó thao tác đăng xuất, đổi mật khẩu hay khoá tài khoản có hiệu lực ngay lập tức với các mã định danh người dùng đang lưu hành.],
    [BR-07], [Kiểm tra], [Chỉ tài khoản đã xác minh danh tính mới tạo được tin đăng và rút được tiền; cổng kiểm tra đặt ở bước tạo tin, không ở bước công bố.],
    [BR-08], [Thủ tục], [Phán quyết xác minh danh tính chỉ do điều phối viên đưa ra, đi qua đúng các bước chuyển trạng thái đã định: từ chối bắt buộc kèm lý do, và giấy tờ có thời hạn bắt buộc phải ghi ngày hết hạn.],
    [BR-09], [Suy dẫn], [Mọi định danh công bố ra ngoài đều ở dạng mờ, không lộ số thứ tự bản ghi và không dò được bằng cách cộng trừ một đơn vị.],
    [BR-55], [Kiểm tra], [Mỗi loại địa chỉ có tối đa một bản ghi mặc định; quy tắc này trải trên tập địa chỉ chứ không phải một trường của tài khoản.],

    table.cell(colspan: 3, align: left)[*b) Tin đăng và kiểm duyệt*],
    [BR-10], [Thủ tục], [Mọi tin đăng khi công bố đều vào hàng đợi duyệt của người thật theo thứ tự gửi; không bộ lọc tự động nào thay thế bước này.],
    [BR-11], [Kiểm tra], [Chưa khai địa chỉ lấy hàng thì không công bố được tin; địa chỉ được gắn cứng vào tin lúc công bố, độc lập hoàn toàn với sổ địa chỉ về sau.],
    [BR-12], [Thủ tục], [Sửa một tin đang hiển thị không có hiệu lực ngay: bản sửa chờ duyệt trong khi bản đang hiển thị vẫn phục vụ người mua.],
    [BR-13], [Cấu trúc], [Tin bị điều phối viên gỡ khác tin do người bán tự ẩn: tin bị gỡ khi gửi lại phải quay về hàng đợi duyệt.],
    [BR-14], [Kiểm tra], [Chế độ giá chỉ quyết định tin có nhận trả giá hay không: tin giá cố định từ chối bị thương lượng, tin cho phép thương lượng vẫn mua thẳng theo giá niêm yết.],
    [BR-15], [Kiểm tra], [Tồn kho theo từng phiên bản với 3 bộ đếm tổng số, đang giữ và đã bán.],

    table.cell(colspan: 3, align: left)[*c) Thương lượng giá*],
    [BR-16], [Thủ tục], [Người mua là bên mở thương lượng; hai bên luân phiên đề xuất, và bên được quyền chấp thuận luôn là bên không giữ đề xuất hiện hành.],
    [BR-17], [Thủ tục], [Một đề xuất đang chờ có hiệu lực 12 giờ; quá hạn thì thương lượng hết hiệu lực và phải mở lại từ đầu.],
    [BR-18], [Thủ tục], [Chấp thuận một mức giá không tạo đơn và không thu khoản nào; nó chỉ đóng băng mức giá đó trong 30 phút.],
    [BR-19], [Kiểm tra], [Mỗi cặp người mua và phiên bản sản phẩm chỉ có đúng một thương lượng đang mở tại một thời điểm.],
    [BR-20], [Cấu trúc], [Mức giá đang thương lượng không bao giờ được sao chép vào nội dung tin nhắn; hội thoại chỉ mang một tham chiếu tới bản ghi thương lượng.],

    table.cell(colspan: 3, align: left)[*d) Thanh toán, ký quỹ và vận chuyển*],
    [BR-21], [Thủ tục], [Tiền thanh toán bắt buộc vào ký quỹ của sàn trước khi về người bán; không có đường đi nào chuyển thẳng từ người mua sang người bán.],
    [BR-22], [Thủ tục], [Đơn hàng ra đời khi cổng thanh toán báo kết quả về, không phải khi ai đó nhấn nút; trang đích (landing page) không phải bằng chứng.],
    [BR-23], [Thủ tục], [Phiên thanh toán chưa trả có hiệu lực 15 phút; quá hạn thì không còn trả được và mọi phần đã giành được trả lại.],
    [BR-54], [Thủ tục], [Phiếu mua tạm có hiệu lực 30 phút, đúng bằng thời gian đóng băng của một mức giá đã chấp thuận; quá hạn thì tồn kho đang giữ được trả lại.],
    [BR-24], [Kiểm tra], [Quyền mua phải được giành trước khi phiên thanh toán được mở; một phiếu mua tạm hoặc một thương lượng đã chấp thuận chỉ sinh ra đúng một đơn hàng.],
    [BR-25], [Suy dẫn], [Người mua luôn trả toàn bộ phí giao hàng; sàn không thu hoa hồng trên giá trị hàng hoá và không có phương án chia phí giữa hai bên.],
    [BR-26], [Thủ tục], [Phí giao hàng không bao giờ vào ví người bán: ngay khi tiền vào ký quỹ nó đã được tách thành một khoản riêng.],
    [BR-27], [Suy dẫn], [Phí giao hàng chỉ được trả lại khi kiện hàng chưa từng rời kho; một yêu cầu hoàn tiền được chấp thuận không hoàn phí, vì chặng vận chuyển đó đã diễn ra.],
    [BR-28], [Thủ tục], [Người bán có 48 giờ để xác nhận một đơn đã thanh toán, và xác nhận chỉ mở đường đặt vận đơn. Quá hạn thì hệ thống nhắc bộ phận vận hành, không tự huỷ đơn và không tự hoàn tiền.],
    [BR-29], [Thủ tục], [Từ chối một đơn bắt buộc phải nêu lý do; khi đó tiền hàng cộng phí giao hàng được hoàn cho người mua và tồn kho được trả lại.],
    [BR-30], [Thủ tục], [Đặt vận đơn là nghĩa vụ đi kèm khoản phí đã thu; lần đặt đầu thất bại thì thử lại, và mã vận đơn đã có là dấu hiệu đã đặt.],
    [BR-31], [Kiểm tra], [Trạng thái hành trình chỉ tiến chứ không lùi: một mốc tới muộn nhưng ở phía sau vị trí hiện tại bị bỏ qua, và một trạng thái không được mô hình hoá cũng bị bỏ qua.],

    table.cell(colspan: 3, align: left)[*e) Ví, giải ngân và rút tiền*],
    [BR-32], [Thủ tục], [Đồng hồ 72 giờ chỉ chạy từ lúc người mua chủ động xác nhận đã nhận hàng; hệ thống không tự xác nhận thay người mua trong bất kỳ hoàn cảnh nào.],
    [BR-33], [Kiểm tra], [Xác nhận đã nhận hàng bắt buộc kèm ít nhất một tệp bằng chứng.],
    [BR-34], [Thủ tục], [Hết 72 giờ mà không có yêu cầu hoàn tiền đang xử lý, tiền hàng chuyển từ ký quỹ sang số dư khả dụng của người bán.],
    [BR-35], [Kiểm tra], [Mọi biến động số dư đều có một bút toán trong sổ ví; sổ chỉ được thêm mới và không số dư nào được âm.],
    [BR-36], [Kiểm tra], [Chỉ phần khả dụng mới rút được; số tiền rút bị trừ ngay khi yêu cầu được tạo và được hoàn lại nếu yêu cầu bị từ chối.],

    table.cell(colspan: 3, align: left)[*f) Hoàn tiền và phân xử*],
    [BR-37], [Kiểm tra], [Người mua mở được yêu cầu hoàn tiền bất kỳ lúc nào trước khi đơn kết thúc; đơn có yêu cầu đang xử lý thì không được giải ngân.],
    [BR-38], [Suy dẫn], [Hoàn tiền luôn là toàn phần; không có hoàn tiền một phần ở bất kỳ nhánh nào.],
    [BR-39], [Cấu trúc], [Người bán chỉ có hai lựa chọn xử lý: chấp nhận cho trả hàng, hoặc chuyển hồ sơ cho sàn phân xử. Không có lựa chọn tự từ chối.],
    [BR-40], [Thủ tục], [Người bán im lặng quá 48 giờ thì hồ sơ tự chuyển lên sàn phân xử; im lặng không phải là đồng ý, cũng không phải một phán quyết.],
    [BR-41], [Cấu trúc], [Người mua không bao giờ là bên chuyển hồ sơ lên sàn: bắt bên đang mất tiền phải khiếu nại lần thứ hai chính là bước làm họ mất luôn vụ việc.],
    [BR-42], [Thủ tục], [Chấp nhận hoàn tiền chưa phải là trả tiền: hàng phải quay về trước. Người bán xác nhận đã nhận hàng thì có 48 giờ kiểm hàng, hết hạn mà không có ý kiến thì tiền về người mua; người mua tự khai đã trả hàng thì hồ sơ đi thẳng lên sàn phân xử.],
    [BR-43], [Thủ tục], [Một phán quyết đóng mọi phiếu đang mở nhắm vào cùng đối tượng, vì cả 2 bên đều có thể đã mở phiếu về cùng một hồ sơ.],

    table.cell(colspan: 3, align: left)[*g) Phiếu hỗ trợ, đánh giá và vận hành*],
    [BR-44], [Cấu trúc], [Mọi thứ người dùng gửi lên bộ phận hỗ trợ đều là một phiếu trong một hàng đợi duy nhất; loại phiếu là thứ duy nhất phân biệt chúng.],
    [BR-45], [Cấu trúc], [Mỗi phiếu có một hội thoại giữa người gửi và bàn hỗ trợ; nội dung và tệp đính kèm của phiếu chính là tin nhắn đầu tiên của hội thoại.],
    [BR-46], [Thủ tục], [Điều phối viên trả lời với tư cách bàn hỗ trợ; danh tính cá nhân của họ bị ẩn với người gửi ở mọi nơi hiển thị tin nhắn, kể cả dòng tin nhắn cuối của danh sách hội thoại.],
    [BR-47], [Kiểm tra], [Không nhắn tin trực tiếp cho bàn hỗ trợ được; muốn liên hệ thì mở phiếu, vì một hội thoại riêng với bàn hỗ trợ là hội thoại không ai đọc.],
    [BR-56], [Kiểm tra], [Mỗi cặp tài khoản có tối đa một hội thoại trực tiếp, mở ở lần nhắn đầu tiên và dùng lại về sau. Hội thoại của phiếu nằm ngoài quy tắc này.],
    [BR-48], [Kiểm tra], [Một người gửi chỉ có một phiếu đang mở về cùng một đối tượng.],
    [BR-49], [Cấu trúc], [Không ngưỡng số lượt tố cáo nào tự động ẩn một tin đăng; hệ thống chỉ cho điều phối viên thấy số phiếu đang mở về cùng đối tượng.],
    [BR-50], [Kiểm tra], [Phiếu hồ sơ hoàn tiền không được kết luận bằng tay ở màn hình phiếu; nó chỉ đóng theo phán quyết ra ở nơi giữ tiền.],
    [BR-51], [Kiểm tra], [Chỉ người đã mua mới viết được nhận xét về sản phẩm, và mỗi người chỉ bình chọn một nhận xét là hữu ích một lần.],
    [BR-52], [Cấu trúc], [Cổng thanh toán và hãng vận chuyển được chọn theo từng dòng của sổ tuỳ chọn, không theo một tham số chung; một dòng bị tắt vẫn đọc được vì bản ghi cũ đã ghi tên nó.],
    [BR-53], [Thủ tục], [Mọi quyết định nghiệp vụ và mọi biến động tiền để lại một bản ghi kiểm toán chỉ-thêm-mới, ghi cùng giao dịch với chính thay đổi đó.],
  )
)
