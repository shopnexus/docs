#import "../../common/tokens.typ": *

= KIỂM THỬ VÀ ĐÁNH GIÁ

Chương này trình bày phương pháp và kết quả kiểm thử hệ thống. Do thời gian thực hiện có hạn, công tác kiểm thử được tập trung vào cấp độ kiểm thử đơn vị (Unit Test) cho dịch vụ nền với 627 ca kiểm thử. Các ca kiểm thử trọng tâm được đặc tả chi tiết, các ca còn lại được thống kê trong danh mục tổng hợp kèm kết quả thực thi ở lần chạy gần nhất.

== Mục tiêu và phạm vi kiểm thử

Phạm vi kiểm thử tự động tập trung vào cấp độ kiểm thử đơn vị của tầng nghiệp vụ (Domain Layer). Thay vì tập trung độ phủ giao diện người dùng, nhóm ưu tiên kiểm chứng tính đúng đắn của các quy tắc điều khiển dòng tiền, tài khoản ký quỹ và trạng thái đơn hàng nhằm giảm thiểu rủi ro giao dịch thực tế.

Theo ưu tiên đó, 4 tình huống sau được xác định là rủi ro cao và buộc phải kiểm chứng tự động:

- Một lần trả tiền sinh ra hai đơn hàng, hoặc một thông báo của cổng thanh toán bị gửi lặp làm người mua bị ghi nợ hai lần.
- Một khoản tiền ký quỹ được giải ngân cho người bán trong khi hồ sơ hoàn tiền của người mua còn treo, hoặc ngược lại.
- Một chuỗi thao tác dừng giữa chừng do mất kết nối mạng, cổng thanh toán hết hạn chờ, hoặc hãng vận chuyển từ chối nhận kiện.
- Hai thao tác tranh chấp cập nhật cùng một dữ liệu đồng thời, dẫn tới ghi đè trạng thái.

Ngoài luồng tiền, hai nhóm phụ trợ được ưu tiên kiểm chứng là cơ chế kiểm soát truy cập (phiên, phân quyền) và tính nhất quán của hợp đồng giao tiếp (API Specification) giữa máy chủ và các ứng dụng khách.

== Môi trường và cách thực thi kiểm thử

Kiến trúc hệ thống được thiết kế nhằm cô lập tầng nghiệp vụ khỏi tầng dữ liệu và mạng lưới vật lý. Nhờ vậy, kiểm thử đơn vị có thể bao phủ các kịch bản tương tác phức tạp mà không đòi hỏi hạ tầng thật.

Mỗi phân hệ sở hữu một bản triển khai kho lưu trữ tạm trong bộ nhớ (In-memory Repository) dành riêng cho môi trường kiểm thử. Ca kiểm thử thiết lập các bối cảnh như ví tiền, phiên thanh toán và đơn hàng hoàn toàn trên bộ nhớ. Các nhà cung cấp bên ngoài (cổng thanh toán, vận chuyển) được thay thế bằng hệ thống giả lập (Mocking) chạy trực tiếp trong tiến trình kiểm thử.

Môi trường giả lập cho phép truyền tham số để kích hoạt các tình huống ngoại lệ: cổng thanh toán gửi lặp thông báo, hãng vận chuyển từ chối nhận kiện, hay hãng phản hồi chậm quá thời gian chờ.
#pagebreak()
== Đặc tả các ca kiểm thử trọng tâm

3 ca dưới đây tương ứng với các tình huống rủi ro đã nêu ở mục 6.1.

#tcspec(
  "TC-01", "Cổng thanh toán gửi lặp một thông báo đã xử lý",
  [Yêu cầu liên quan], [Thanh toán qua cổng và ký gửi tiền ký quỹ (REQ-23); chống nhân đôi thu tiền (NFR-11)],
  [Mức / loại / ưu tiên], [Thành phần; nghịch (kiểm tính lũy đẳng); chặn],
  [Điều kiện tiên quyết], [Một phiên thanh toán đã mở cho cặp người mua và người bán với tổng tiền 300.000 đồng; một lượt trả tiền đã được khởi tạo trên cổng giả lập; ví người mua rỗng, đúng như trường hợp thông thường],
  [Dữ liệu thử], [Thông báo của cổng được dựng lại đúng như cổng gửi về: mã tham chiếu của lượt trả tiền do nền tảng phát ra, kèm trạng thái thành công. Lần gửi thứ hai dùng đúng cùng một thông báo],
  [Các bước], [
    1. Gửi thông báo thành công lần thứ nhất.
    2. Đọc ví người mua, rồi cho phân hệ đơn hàng giữ tiền ký quỹ trên số tiền đó.
    3. Gửi lại đúng thông báo ấy lần thứ hai.
    4. Đọc lại ví người mua.
  ],
  [Kết quả mong đợi], [
    Lần thứ nhất ghi có 300.000 đồng vào ví người mua, nhờ đó lệnh giữ tiền thành công và số dư
    bị giữ của người bán bằng 300.000 đồng. \
    Lần thứ hai trả về thành công để cổng ngừng gửi lại, nhưng không phát sinh bút toán nào:
    lượt trả tiền đã kết thúc nên mọi lần xử lý sau được nhận ra và bỏ qua thay vì báo lỗi. \
    Ví người mua đọc lại có số dư khả dụng và số dư bị giữ đều bằng không: tiền đã chuyển đúng
    một lần và hiện nằm trong tài khoản tạm giữ.
  ],
  [Kết quả thực tế], [*Đạt.* Ca này đồng thời phủ luôn nhánh thuận của cả đường thanh toán, từ lúc mở phiên tới khi tiền được giữ lại],
)

#tcspec(
  "TC-02", "Khôi phục chuỗi quyết toán sau gián đoạn",
  [Yêu cầu liên quan], [Sinh đơn hàng từ phiên thanh toán đã trả (REQ-23); tính lũy đẳng của các chuyển đổi (NFR-10); chống nhân đôi đơn hàng (NFR-11)],
  [Mức / loại / ưu tiên], [Thành phần; nghịch (phục hồi sau lỗi); chặn],
  [Điều kiện tiên quyết], [Một phiên thanh toán một dòng hàng đã được trả tiền; phân hệ tài chính được đặt ở chế độ lệnh giữ tiền thất bại. Đây là tình huống khó nhất của luồng, vì đơn hàng đã được ghi trước khi lệnh giữ tiền chạy],
  [Dữ liệu thử], [Đơn 100.000 đồng, một dòng hàng đã được giữ tồn kho từ lúc mở phiên],
  [Các bước], [
    1. Gọi quyết toán phiên lần thứ nhất, với lệnh giữ tiền đang thất bại.
    2. Kiểm tra số tiền đã giữ và trạng thái tồn kho.
    3. Bỏ chế độ thất bại, gọi quyết toán lần thứ hai.
    4. Gọi quyết toán lần thứ ba.
    5. Đếm số đơn hàng và kiểm tra mọi dòng hàng của phiên.
  ],
  [Kết quả mong đợi], [
    Lần thứ nhất báo lỗi thay vì báo thành công, và không hiệu ứng nào sau bước ghi đơn xảy ra:
    tiền ký quỹ bằng 0 đồng, tồn kho chưa chuyển sang đã bán. \
    Lần thứ hai hoàn tất phần còn lại: giữ đúng 100.000 đồng, tồn kho chuyển từ trạng thái đang
    giữ sang đã bán. \
    Lần thứ ba không làm gì thêm: mỗi hiệu ứng được áp dụng đúng một lần, vì lệnh giữ tiền được
    khoá theo đơn hàng và lệnh trừ tồn kho được khoá theo dòng hàng. \
    Suốt cả 3 lần chỉ tồn tại một đơn hàng, và mọi dòng hàng của phiên đều đã gắn vào đơn đó.
  ],
  [Kết quả thực tế], [*Đạt.* Kết hợp với TC-01, 2 ca này khẳng định một lần trả tiền chỉ sinh một đơn hàng, dù thông báo bị gửi lặp hay chuỗi quyết toán bị chạy lại],
)

#tcspec(
  "TC-03", "Xử lý giải ngân khi phát sinh yêu cầu hoàn tiền",
  [Yêu cầu liên quan], [Giải ngân sau thời hạn khiếu nại (REQ-26); hồ sơ hoàn tiền (REQ-27); ghi có kiểm soát trạng thái (NFR-12)],
  [Mức / loại / ưu tiên], [Thành phần; nghịch (tranh chấp đồng thời); chặn],
  [Điều kiện tiên quyết], [Một đơn hàng đã được người mua xác nhận nhận hàng; thời điểm nhận hàng bị đẩy về quá khứ để thời hạn giải ngân đã trôi qua, nhờ đó đơn nằm trong danh sách đến hạn của tác vụ quét],
  [Dữ liệu thử], [Đơn 100.000 đồng đang được tạm giữ; hồ sơ hoàn tiền do người mua mở với lý do "không đúng như mô tả"],
  [Các bước], [
    1. Tác vụ quét đọc danh sách đơn đến hạn giải ngân, thu được đúng một đơn.
    2. Trước khi tác vụ giành đơn đó, người mua mở một hồ sơ hoàn tiền trên chính đơn ấy.
    3. Tác vụ giành đơn rồi gọi lệnh giải ngân.
    4. Trường hợp ngược lại: trên một đơn khác, để tác vụ giải ngân xong trước, rồi người mua mới mở hồ sơ hoàn tiền.
  ],
  [Kết quả mong đợi], [
    Phép giành đơn thất bại, vì câu hỏi "đơn này còn đến hạn giải ngân không" được hỏi lại dưới
    khoá của đơn thay vì tin vào danh sách đã đọc từ trước. \
    Lệnh giải ngân sau đó không báo lỗi nhưng cũng không chạm vào tiền: khoản tạm giữ vẫn là
    100.000 đồng, số tiền đã giải ngân bằng 0. \
    Ở trường hợp ngược lại, việc mở hồ sơ hoàn tiền bị từ chối: khoản tiền mà hồ sơ nhắm tới
    không còn được tạm giữ nữa.
  ],
  [Kết quả thực tế], [*Đạt.* Ca này bắt đúng lớp lỗi mà một tác vụ quét theo lô thường mắc: đọc danh sách ứng viên ở một thời điểm rồi hành động ở một thời điểm khác],
)

== Danh mục ca kiểm thử chính

Bảng dưới đây liệt kê các ca kiểm thử chính còn lại, nhóm theo miền nghiệp vụ. Cột loại phân
biệt ca thuận (kiểm chứng hệ thống làm đúng việc được yêu cầu), ca nghịch (kiểm chứng hệ
thống từ chối đúng chỗ), và ca biên (kiểm chứng hành vi ở ranh giới của một quy tắc).

#figure(
  kind: table,
  caption: [Danh mục các ca kiểm thử chính và kết quả thực thi],
  table(
    columns: (0.09fr, 0.63fr, 0.14fr, 0.14fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([Mã], [Ca kiểm thử và kết quả mong đợi], [Loại], [Kết quả]),

    table.cell(colspan: 4, fill: rgb("#F7F7F7"))[*Dòng tiền, ký quỹ và hoàn tiền*],
    [TC-04], [Từ chối mọi bút toán làm số dư ví âm], [Nghịch], [Đạt],
    [TC-05], [Mỗi điều chỉnh số dư ví của quản trị viên phải kèm khóa idempotency; yêu cầu lặp lại cùng khóa không được ghi nhận thêm, còn yêu cầu thiếu khóa phải bị từ chối], [Nghịch], [Đạt],
    [TC-06], [Khoản ký quỹ chỉ được giữ và giải ngân một lần; yêu cầu giữ lặp lại phải bị từ chối], [Biên], [Đạt],
    [TC-07], [Khoản hoàn tiền phải được xử lý thành công trước khi hồ sơ chuyển sang trạng thái kết thúc], [Nghịch], [Đạt],
    [TC-08], [Khi hai điều hành viên đồng thời phân xử một hồ sơ, chỉ một quyết định được ghi nhận], [Nghịch], [Đạt],
    [TC-09], [Hồ sơ hoàn tiền quá hạn được tự động chuyển xử lý, nhưng bỏ qua hồ sơ đã có nhân viên tiếp nhận hoặc vừa phát sinh khiếu nại chưa được đồng bộ], [Nghịch], [Đạt],

    table.cell(colspan: 4, fill: rgb("#F7F7F7"))[*Đặt hàng, tồn kho và thương lượng giá*],
    [TC-10], [Yêu cầu đặt hàng vượt tồn kho phải bị từ chối trước khi phát sinh thanh toán], [Nghịch], [Đạt],
    [TC-11], [Phiếu mua tạm phải được khóa trước khi thanh toán để ngăn hai yêu cầu đồng thời tạo thành hai giao dịch], [Biên], [Đạt],
    [TC-12], [Người bán không được phép hủy dòng hàng đã thanh toán, kể cả khi vận đơn đang chờ tạo lại], [Nghịch], [Đạt],
    [TC-13], [Mỗi biến thể sản phẩm chỉ được tồn tại một đề nghị thương lượng đang hiệu lực; thao tác chấp nhận đồng thời chỉ ghi nhận một kết quả], [Nghịch], [Đạt],
    [TC-14], [Phiếu mua tạm chưa thanh toán phải hết hạn và giải phóng phần tồn kho đã giữ], [Biên], [Đạt],
    [TC-15], [Khi hủy đơn đã thanh toán, hệ thống hoàn tác lượt bán thay vì hoàn tác thao tác giữ tồn kho ban đầu], [Nghịch], [Đạt],

    table.cell(colspan: 4, fill: rgb("#F7F7F7"))[*Vận chuyển*],
    [TC-16], [Đơn vị vận chuyển không hỗ trợ tuyến phải bị loại khỏi danh sách báo giá, trong khi các đơn vị còn lại vẫn được xử lý bình thường], [Biên], [Đạt],
    [TC-17], [Phản hồi vượt quá thời hạn từ đơn vị vận chuyển phải bị ngắt theo timeout đã cấu hình], [Nghịch], [Đạt],
    [TC-18], [Mã trạng thái vận chuyển không được hệ thống hỗ trợ phải bị từ chối thay vì tự ánh xạ sang trạng thái gần nhất], [Nghịch], [Đạt],
    [TC-19], [Người mua và người bán không được phép tự cập nhật mốc hành trình; trạng thái vận đơn chỉ thay đổi theo dữ liệu hợp lệ từ đơn vị vận chuyển], [Nghịch], [Đạt],

    table.cell(colspan: 4, fill: rgb("#F7F7F7"))[*Xác thực, phân quyền và bảo vệ dữ liệu*],
    [TC-20], [Access token còn hiệu lực nhưng thuộc phiên đã bị thu hồi phải bị từ chối], [Nghịch], [Đạt],
    [TC-21], [Đổi mật khẩu giữ lại phiên hiện tại và thu hồi toàn bộ các phiên còn lại], [Thuận], [Đạt],
    [TC-22], [Khi tài khoản bị đình chỉ, toàn bộ phiên đăng nhập phải bị thu hồi và thao tác được ghi vào nhật ký kiểm toán], [Thuận], [Đạt],
    [TC-23], [Người dùng không có quyền truy cập nhận phản hồi "không tìm thấy" đối với phiên thanh toán, hội thoại và bản nháp của người khác], [Nghịch], [Đạt],
    [TC-24], [Webhook thanh toán có chữ ký không hợp lệ phải bị từ chối], [Nghịch], [Đạt],
    [TC-25], [Địa chỉ chuyển hướng ngoài miền được cho phép phải bị từ chối để ngăn lỗ hổng open redirect], [Nghịch], [Đạt],

    table.cell(colspan: 4, fill: rgb("#F7F7F7"))[*Cấu hình và hợp đồng đặc tả*],
    [TC-26], [Cấu hình thiếu trường bắt buộc hoặc chứa khóa không hợp lệ phải khiến tiến trình khởi động thất bại và chỉ rõ vị trí cấu hình cần sửa], [Nghịch], [Đạt],
    [TC-27], [Cổng thanh toán đã được khai báo nhưng thiếu thông tin xác thực phải khiến hệ thống khởi động thất bại], [Biên], [Đạt],
    [TC-28], [Mọi đường dẫn được công bố trong đặc tả phải có tuyến xử lý tương ứng và mọi tham chiếu lược đồ phải phân giải thành công], [Thuận], [Đạt],
    [TC-29], [Các đối tượng truyền dữ liệu phải giữ nguyên các trường có giá trị rỗng hoặc bằng không theo hợp đồng đặc tả, tránh sai lệch dữ liệu phía ứng dụng khách], [Thuận], [Đạt],
    [TC-30], [Kênh thời gian thực phải khai báo đầy đủ các loại thông điệp và sử dụng thống nhất một cấu trúc phong bì], [Thuận], [Đạt],
    [TC-31], [Đặc tả đã lưu phải trùng khớp với đặc tả được sinh lại từ hệ thống], [Thuận], [Đạt],
  ),
)

== Đối chiếu với các yêu cầu phi chức năng chính

Bảng dưới đây đối chiếu các yêu cầu phi chức năng quan trọng nhất với bằng chứng hiện có. Cột
kết luận dùng 3 mức: Đạt nghĩa là có ca kiểm thử đã chạy và đạt, khẳng định đúng điều mà yêu
cầu phát biểu; Đạt một phần nghĩa là phần chính đã được kiểm chứng nhưng còn một nhánh chưa
kiểm chứng được; Ngoài phạm vi nghĩa là điều kiện để kiểm chứng thuộc về môi trường triển
khai, không thuộc về sản phẩm mà đề tài xây dựng.

#figure(
  kind: table,
  caption: [Đối chiếu các yêu cầu phi chức năng chính với bằng chứng kiểm thử],
  table(
    columns: (0.25fr, 0.24fr, 0.43fr, 0.15fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([Mã], [Nội dung], [Bằng chứng], [Kết luận]),

    [NFR-01 → NFR-03],
    [Mật khẩu, vòng đời phiên và thu hồi phiên],
    [Mật khẩu được băm kèm muối riêng, độ dài 8–72 ký tự do bộ kiểm tra dữ liệu vào cưỡng chế; thẻ truy cập sống 15 phút, phiên sống 30 ngày, và mọi yêu cầu đã xác thực đều tra lại phiên. TC-20, TC-21, TC-22 cùng nhóm ca kiểm thử vòng đời phiên đều đạt],
    [Đạt],

    [NFR-04],
    [Định danh thực thể ở dạng mờ],
    [Phép hoán vị có khoá giữ nguyên miền giá trị, mỗi loại thực thể một biến thể; có ca kiểm thử vòng mã hoá rồi giải mã, ca kiểm không va chạm, và một bộ giá trị đối chiếu khoá chặt chuỗi định danh đã phát ra],
    [Đạt],

    [NFR-05],
    [Phân quyền theo vai trò ở tầng dịch vụ],
    [Cổng vào chỉ xử lý xác thực, nguồn gốc yêu cầu và nhật ký, không nơi nào đọc vai trò; phép kiểm vai trò nằm ở tầng dịch vụ, xuất hiện ở hơn 40 điểm trên 6 phân hệ, và có ca kiểm thử gọi chéo vai trò],
    [Đạt],

    [NFR-06],
    [Che sự tồn tại bản ghi với người ngoài cuộc],
    [TC-23 đạt trên 4 phân hệ. Vẫn còn vài chỗ trả về "bị cấm" thay vì "không tìm thấy", và quy tắc này chưa được cưỡng chế bằng một cơ chế dùng chung],
    [Đạt một phần],

    [NFR-10],
    [Tính lũy đẳng của các chuyển đổi theo thời hạn],
    [Định nghĩa "đến hạn" nằm ở đúng một chỗ, dùng chung cho cả tác vụ quét lẫn luồng thực thi bền; TC-02, TC-03 và TC-09 đều khẳng định gọi lại không sinh thêm bút toán],
    [Đạt],

    [NFR-11],
    [Chống nhân đôi đơn hàng và nhân đôi thu tiền],
    [TC-01, TC-02, TC-05 và TC-11 phủ nhóm này ở tầng dịch vụ. 4 ràng buộc duy nhất ở tầng dữ liệu trên phiếu mua tạm, trên thương lượng, trên mã tham chiếu của nhà cung cấp và trên khoá chống lặp của bút toán ví là lớp phòng vệ thứ hai, chỉ kiểm chứng được khi có cơ sở dữ liệu thật],
    [Đạt một phần],

    [NFR-12, NFR-13],
    [Toàn vẹn số dư và ghi có kiểm soát trạng thái],
    [TC-04 và TC-03 đạt ở tầng dịch vụ; ràng buộc kiểm tra số dư không âm có mặt trên cả bảng ví lẫn từng dòng sổ bút toán. Nhánh xung đột phiên bản khi hai giao dịch ghi đồng thời thuộc nhóm cần cơ sở dữ liệu thật],
    [Đạt một phần],

    [NFR-15],
    [Hạn chờ cho lời gọi ra nhà cung cấp],
    [Hạn chờ là trường bắt buộc trong cấu hình nên thiếu thì bị chặn ngay lúc khởi động (TC-26); TC-17 khẳng định một hãng trả lời chậm vẫn bị cắt theo hạn chờ. Bộ khách dùng chung chưa đặt hạn chờ mặc định, và chỉ hai mối nối tách hạn chờ theo loại thao tác],
    [Đạt một phần],

    [NFR-16],
    [Nạp và kiểm tra cấu hình],
    [TC-26 và TC-27 đạt, cùng 8 ca kiểm thử riêng cho việc nạp cấu hình; chế độ đọc nghiêm ngặt được bật nên một khoá không được khai báo bị từ chối thay vì bỏ qua trong im lặng],
    [Đạt],

    [NFR-17],
    [Đặc tả là nguồn duy nhất của hợp đồng],
    [TC-28 đến TC-31 đều đạt, và quy trình tích hợp liên tục sinh lại đặc tả rồi so với bản đã lưu trên mỗi lần đẩy mã, đây là cổng kiểm tra tự động thực sự đang chạy của dịch vụ nền],
    [Đạt],

    [NFR-08],
    [Mã hoá đường truyền (TLS 1.2 trở lên)],
    [Việc kết thúc kết nối mã hoá thuộc về lớp biên khi triển khai; 3 thành phần của hệ thống không chứa cấu hình lớp biên nên không có gì trong hồ sơ chứng minh hay bác bỏ ngưỡng này],
    [Ngoài phạm vi],
  ),
)