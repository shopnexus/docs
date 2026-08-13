#import "../../common/tokens.typ": *

= KIỂM THỬ VÀ ĐÁNH GIÁ
== Mục tiêu và phạm vi kiểm thử

Phạm vi kiểm thử tự động của hệ thống được thực hiện và dừng ở cấp độ đơn vị (Unit Test) cho tầng nghiệp vụ (Domain Layer).

Với chiến lược này, 4 tình huống sau được xác định là mục tiêu trọng tâm cần vét cạn bằng các ca kiểm thử:

- Một lần trả tiền sinh ra hai đơn hàng, hoặc một thông báo của cổng thanh toán được cổng gửi lặp lại và người mua bị ghi nợ 2 lần.
- Một khoản tiền ký quỹ được giải ngân cho người bán trong khi hồ sơ hoàn tiền của người mua còn treo, hoặc ngược lại.
- Một chuỗi thao tác bị dừng giữa đường do mất kết nối, cổng thanh toán hết hạn chờ, hoặc hãng vận chuyển từ chối nhận kiện.
- Hai thao tác đồng thời cùng thắng, dẫn tới tình trạng ghi đè trạng thái không hợp lệ.

Ngoài luồng tiền, hai nhóm hỗ trợ được ưu tiên kiểm thử là cơ chế kiểm soát truy cập (phiên, phân quyền) và tính nhất quán của hợp đồng giao tiếp (API Specification) giữa máy chủ với các ứng dụng khách.

== Đặc tả các ca kiểm thử trọng tâm

3 ca dưới đây tương ứng với các tình huống rủi ro đã nêu ở mục 6.1.

#tcspec(
  "TC-01", "Cổng thanh toán gửi lặp một thông báo đã được xử lý",
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
  "TC-02", "Chuỗi quyết toán dừng giữa đường rồi được chạy lại",
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
  "TC-03", "Giải ngân tiền ký quỹ gặp hồ sơ hoàn tiền chen vào giữa 2 bước",
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
  caption: [Danh mục ca kiểm thử chính và kết quả thực thi],
  table(
    columns: (0.09fr, 0.63fr, 0.14fr, 0.14fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([Mã], [Ca kiểm thử và kết quả mong đợi], [Loại], [Kết quả]),

    table.cell(colspan: 4, fill: rgb("#F7F7F7"))[*Dòng tiền, tiền ký quỹ và hồ sơ hoàn tiền*],
    [TC-04], [Ví từ chối mọi bút toán làm số dư âm, thay vì ghi rồi sửa sau], [Nghịch], [Đạt],
    [TC-05], [Điều chỉnh ví do quản trị viên thực hiện phải mang một khoá chống lặp: gọi lại cùng một khoá không ghi có thêm, và yêu cầu không có khoá thì bị từ chối thay vì ghi mà không được bảo vệ], [Nghịch], [Đạt],
    [TC-06], [Tiền ký quỹ đi đúng một vòng giữ rồi giải ngân; lệnh giữ lặp lại bị từ chối thay vì giữ 2 lần], [Biên], [Đạt],
    [TC-07], [Khi hồ sơ hoàn tiền được xử, tiền phải chuyển xong trước khi hồ sơ chuyển sang trạng thái kết thúc; làm ngược lại thì một lần chuyển tiền thất bại sẽ không có gì chạy lại], [Nghịch], [Đạt],
    [TC-08], [Hai điều hành viên cùng phân xử một hồ sơ thì chỉ một quyết định được ghi nhận], [Nghịch], [Đạt],
    [TC-09], [Hồ sơ hoàn tiền quá hạn được thúc tự động, nhưng bỏ qua hồ sơ đã có nhân viên xử lý và nhường một lần khiếu nại mà nó chưa thấy], [Nghịch], [Đạt],

    table.cell(colspan: 4, fill: rgb("#F7F7F7"))[*Đặt hàng, tồn kho và thương lượng giá*],
    [TC-10], [Đặt hàng vượt tồn kho bị từ chối trước khi thu tiền], [Nghịch], [Đạt],
    [TC-11], [Phiếu mua tạm phải được giành trước khi thu tiền, để 2 lần bấm thanh toán không thành hai giao dịch], [Biên], [Đạt],
    [TC-12], [Dòng hàng đã trả tiền không phải của người bán để huỷ, kể cả khi nó đang nằm trong danh sách chờ đặt vận đơn lại], [Nghịch], [Đạt],
    [TC-13], [Đề nghị đối ứng nhường một lần chấp nhận mà nó chưa thấy; mỗi biến thể hàng chỉ có một đề nghị đang hiệu lực], [Nghịch], [Đạt],
    [TC-14], [Phiếu mua tạm không được thanh toán thì hết hạn, và tồn kho đang giữ được trả lại], [Biên], [Đạt],
    [TC-15], [Huỷ một đơn đã thanh toán thì hoàn tác lượt bán, không phải hoàn tác lượt giữ tồn kho], [Nghịch], [Đạt],

    table.cell(colspan: 4, fill: rgb("#F7F7F7"))[*Vận chuyển*],
    [TC-16], [Hãng không phục vụ tuyến thì biến khỏi danh sách báo giá, các hãng còn lại vẫn báo giá bình thường], [Biên], [Đạt],
    [TC-17], [Hãng trả lời chậm vẫn bị cắt theo hạn chờ đã khai báo], [Nghịch], [Đạt],
    [TC-18], [Hãng gửi về một mã trạng thái mà nền tảng không mô hình hoá thì bị từ chối, thay vì suy đoán ra một trạng thái gần giống], [Nghịch], [Đạt],
    [TC-19], [Mốc hành trình do hãng báo không phải của người mua hay người bán để tự ghi: cả 2 bên đều bị từ chối và trạng thái vận đơn giữ nguyên nơi hãng để lại], [Nghịch], [Đạt],

    table.cell(colspan: 4, fill: rgb("#F7F7F7"))[*Xác thực, phân quyền và che dữ liệu*],
    [TC-20], [Thẻ truy cập còn hạn nhưng thuộc một phiên đã bị thu hồi thì bị từ chối], [Nghịch], [Đạt],
    [TC-21], [Đổi mật khẩu giữ lại phiên đang dùng và thu hồi mọi phiên còn lại], [Thuận], [Đạt],
    [TC-22], [Đình chỉ tài khoản thì mọi phiên của tài khoản đó bị thu hồi và một bản ghi kiểm toán được thêm vào], [Thuận], [Đạt],
    [TC-23], [Người ngoài cuộc nhận "không tìm thấy" thay vì "bị cấm", ở cả phiên thanh toán, hội thoại và bản nháp của người khác], [Nghịch], [Đạt],
    [TC-24], [Thông báo từ cổng thanh toán mang chữ ký của một bí mật khác thì bị từ chối], [Nghịch], [Đạt],
    [TC-25], [Địa chỉ trở về ngoài miền của nền tảng bị từ chối, để lối thanh toán không thành một phép chuyển hướng mở], [Nghịch], [Đạt],

    table.cell(colspan: 4, fill: rgb("#F7F7F7"))[*Cấu hình và hợp đồng đặc tả*],
    [TC-26], [Cấu hình thiếu một trường bắt buộc, hoặc chứa một khoá không được khai báo, đều làm tiến trình dừng khởi động kèm đúng đường dẫn cần sửa], [Nghịch], [Đạt],
    [TC-27], [Cổng thanh toán được nêu tên trong cấu hình mà thiếu thông tin xác thực thì khởi động thất bại], [Biên], [Đạt],
    [TC-28], [Mọi đường dẫn công bố trong đặc tả đều có một tuyến phục vụ thật, và mọi tham chiếu lược đồ đều phân giải được], [Thuận], [Đạt],
    [TC-29], [Không đối tượng truyền dữ liệu nào bỏ khoá khi giá trị bằng rỗng hoặc bằng không; nếu bỏ, ứng dụng khách sẽ lỗi ngay dòng dữ liệu thật đầu tiên], [Thuận], [Đạt],
    [TC-30], [Kênh thời gian thực tham chiếu đủ mọi loại thông điệp, và các thông điệp dùng chung một phong bì], [Thuận], [Đạt],
    [TC-31], [Đặc tả đã lưu trùng khớp với đặc tả sinh lại từ hệ thống], [Thuận], [Đạt],
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
    columns: (0.14fr, 0.24fr, 0.43fr, 0.15fr),
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