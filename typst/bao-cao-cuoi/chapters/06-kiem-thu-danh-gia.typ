#import "../../common/tokens.typ": *

= KIỂM THỬ VÀ ĐÁNH GIÁ

Chương này trình bày các ca kiểm thử chính của hệ thống và kết quả thu được. Trọng tâm đặt vào
những ca quyết định tính đúng đắn của nghiệp vụ dòng tiền, tài khoản tạm giữ, tồn kho, trạng
thái vận đơn, xác thực và phân quyền vì đó là nhóm mà một lỗi gây thiệt hại thật cho người
dùng. Các ca còn lại được trình bày dưới dạng danh mục, kèm kết quả thực thi trung thực theo
lượt chạy gần nhất.

== Mục tiêu và cách chọn ca kiểm thử

Việc chọn ca kiểm thử xuất phát từ đặc thù nghiệp vụ của hệ thống chứ không từ mong muốn phủ
đều mọi thành phần. ShopNexus là sàn giao dịch giữa các cá nhân, nơi tiền của người mua được
giữ lại ở bên thứ ba cho tới khi giao dịch kết thúc. Vì vậy nhóm rủi ro đắt nhất không phải là
giao diện hiển thị sai mà là các quy tắc điều khiển dòng tiền và trạng thái đơn hàng. Cụ thể,
bốn tình huống sau được xác định là phải có ca kiểm thử trước mọi tình huống khác:

- Một lần trả tiền sinh ra hai đơn hàng, hoặc một thông báo của cổng thanh toán được cổng gửi
  lặp lại và người mua bị ghi nợ hai lần.
- Một khoản tiền tạm giữ được giải ngân cho người bán trong khi hồ sơ hoàn tiền của người mua
  còn treo, hoặc ngược lại.
- Một chuỗi thao tác bị dừng giữa đường mất kết nối, cổng thanh toán hết hạn chờ, hãng vận
  chuyển từ chối nhận kiện để lại hệ thống ở trạng thái nửa vời không ai dọn.
- Hai thao tác đồng thời cùng thắng, tức một yêu cầu ghi đè lên trạng thái mà nó chưa từng đọc.

Kế đó là 2 nhóm hỗ trợ.
Nhóm thứ nhất là kiểm soát truy cập: ai được đọc, ai được ghi, và một phiên đã bị thu hồi thì
còn dùng được nữa hay không. Nhóm thứ hai là hợp đồng giao tiếp giữa máy chủ với 2 ứng dụng
khách, nhóm này đặc biệt quan trọng vì cả ứng dụng web và ứng dụng di động đều sinh mã tự động
từ đặc tả giao diện lập trình, nên một đặc tả lệch sẽ làm hỏng ứng dụng khách trong khi máy chủ
vẫn chạy đúng.

Có 3 loại kiểm thử nằm ngoài phạm vi đề tài, và chương không đưa ra bất kỳ con số nào về chúng:
*đo hiệu năng*, cần dữ liệu đúng quy mô và một môi trường tách biệt, kiểm thử bảo mật thâm
nhập, và kiểm thử đầu-cuối chạy thật qua cả 3 thành phần của hệ thống. Bộ yêu cầu phi chức
năng vì thế cố ý không đặt ngưỡng hiệu năng định lượng nào: đặt một con số mà không có cách đo
lại thì chỉ tạo ra một mục "đạt" không ai kiểm chứng được.

== Môi trường và cách thực thi kiểm thử

Kiến trúc của hệ thống được thiết kế để việc kiểm thử nghiệp vụ không cần tới hạ tầng thật. Mỗi
phân hệ công bố hợp đồng của mình qua một giao diện hẹp, tầng nghiệp vụ thuần tuý không biết gì
về cơ sở dữ liệu hay giao thức, và mỗi phân hệ đều có một bản lưu trữ dữ liệu trong bộ nhớ dành
riêng cho kiểm thử. Nhờ đó một ca kiểm thử ở tầng dịch vụ dựng được trọn vẹn bối cảnh nghiệp vụ người mua, người bán, ví, phiên thanh toán, đơn hàng ngay trong bộ nhớ, rồi khẳng định trên
kết quả thật của nghiệp vụ thay vì trên các lời gọi giả.

Các nhà cung cấp bên ngoài được thay bằng bản giả lập chạy ngay trong tiến trình kiểm thử. Bản
giả lập cổng thanh toán và bản giả lập hãng vận chuyển đều nhận một tham số kịch bản, nhờ đó
ca kiểm thử chủ động dựng được các tình huống hỏng mà một nhà cung cấp thật không cho phép tạo
ra theo yêu cầu: cổng thanh toán gửi lặp thông báo, hãng vận chuyển từ chối nhận kiện, hãng
không phục vụ tuyến, hãng trả lời chậm quá hạn chờ, hoặc hãng báo về một mã trạng thái mà nền
tảng không mô hình hoá. Đây là điểm mấu chốt cho phép các ca ở mục 6.3 kiểm chứng được nhánh
nghịch chứ không chỉ nhánh thuận.

== Đặc tả các ca kiểm thử trọng tâm

3 ca dưới đây tương ứng với các tình huống rủi ro đã nêu ở mục 6.1. Cả ba đều nằm trong lượt
chạy mặc định và đều đạt.

#tcspec(
  "TC-01", "Cổng thanh toán gửi lặp một thông báo đã được xử lý",
  [Yêu cầu liên quan], [Thanh toán qua cổng và ký gửi tiền tạm giữ (REQ-22); chống nhân đôi thu tiền (NFR-11)],
  [Mức / loại / ưu tiên], [Thành phần; nghịch — kiểm tính lũy đẳng; chặn],
  [Điều kiện tiên quyết], [Một phiên thanh toán đã mở cho cặp người mua và người bán với tổng tiền 300 000 đồng; một lượt trả tiền đã được khởi tạo trên cổng giả lập; ví người mua rỗng, đúng như trường hợp thông thường],
  [Dữ liệu thử], [Thông báo của cổng được dựng lại đúng như cổng gửi về: mã tham chiếu của lượt trả tiền do nền tảng phát ra, kèm trạng thái thành công. Lần gửi thứ hai dùng đúng cùng một thông báo],
  [Các bước], [
    1. Gửi thông báo thành công lần thứ nhất.
    2. Đọc ví người mua, rồi cho phân hệ đơn hàng giữ tiền tạm giữ trên số tiền đó.
    3. Gửi lại đúng thông báo ấy lần thứ hai.
    4. Đọc lại ví người mua.
  ],
  [Kết quả mong đợi], [
    Lần thứ nhất ghi có 300 000 đồng vào ví người mua, nhờ đó lệnh giữ tiền thành công và số dư
    bị giữ của người bán bằng 300 000 đồng. \
    Lần thứ hai trả về thành công để cổng ngừng gửi lại, nhưng không phát sinh bút toán nào:
    lượt trả tiền đã kết thúc nên mọi lần xử lý sau được nhận ra và bỏ qua thay vì báo lỗi. \
    Ví người mua đọc lại có số dư khả dụng và số dư bị giữ đều bằng không — tiền đã chuyển đúng
    một lần và hiện nằm trong tài khoản tạm giữ.
  ],
  [Kết quả thực tế], [*Đạt.* Ca này đồng thời phủ luôn nhánh thuận của cả đường thanh toán, từ lúc mở phiên tới khi tiền được giữ lại],
)

#tcspec(
  "TC-02", "Chuỗi quyết toán dừng giữa đường rồi được chạy lại",
  [Yêu cầu liên quan], [Sinh đơn hàng từ phiên thanh toán đã trả (REQ-22); tính lũy đẳng của các chuyển đổi (NFR-10); chống nhân đôi đơn hàng (NFR-11)],
  [Mức / loại / ưu tiên], [Thành phần; nghịch — phục hồi sau lỗi; chặn],
  [Điều kiện tiên quyết], [Một phiên thanh toán một dòng hàng đã được trả tiền; phân hệ tài chính được đặt ở chế độ lệnh giữ tiền thất bại. Đây là tình huống khó nhất của luồng, vì đơn hàng đã được ghi trước khi lệnh giữ tiền chạy],
  [Dữ liệu thử], [Đơn 100 000 đồng, một dòng hàng đã được giữ tồn kho từ lúc mở phiên],
  [Các bước], [
    1. Gọi quyết toán phiên lần thứ nhất, với lệnh giữ tiền đang thất bại.
    2. Kiểm tra số tiền đã giữ và trạng thái tồn kho.
    3. Bỏ chế độ thất bại, gọi quyết toán lần thứ hai.
    4. Gọi quyết toán lần thứ ba.
    5. Đếm số đơn hàng và kiểm tra mọi dòng hàng của phiên.
  ],
  [Kết quả mong đợi], [
    Lần thứ nhất báo lỗi thay vì báo thành công, và không hiệu ứng nào sau bước ghi đơn xảy ra:
    tiền tạm giữ bằng 0 đồng, tồn kho chưa chuyển sang đã bán. \
    Lần thứ hai hoàn tất phần còn lại: giữ đúng 100 000 đồng, tồn kho chuyển từ trạng thái đang
    giữ sang đã bán. \
    Lần thứ ba không làm gì thêm — mỗi hiệu ứng được áp dụng đúng một lần, vì lệnh giữ tiền được
    khoá theo đơn hàng và lệnh trừ tồn kho được khoá theo dòng hàng. \
    Suốt cả ba lần chỉ tồn tại một đơn hàng, và mọi dòng hàng của phiên đều đã gắn vào đơn đó.
  ],
  [Kết quả thực tế], [*Đạt.* Kết hợp với TC-01, 2 ca này khẳng định một lần trả tiền chỉ sinh một đơn hàng, dù thông báo bị gửi lặp hay chuỗi quyết toán bị chạy lại],
)

#tcspec(
  "TC-03", "Giải ngân tiền tạm giữ gặp hồ sơ hoàn tiền chen vào giữa 2 bước",
  [Yêu cầu liên quan], [Giải ngân sau thời hạn khiếu nại (REQ-25); hồ sơ hoàn tiền (REQ-26); ghi có kiểm soát trạng thái (NFR-12)],
  [Mức / loại / ưu tiên], [Thành phần; nghịch — tranh chấp đồng thời; chặn],
  [Điều kiện tiên quyết], [Một đơn hàng đã được người mua xác nhận nhận hàng; thời điểm nhận hàng bị đẩy về quá khứ để thời hạn giải ngân đã trôi qua, nhờ đó đơn nằm trong danh sách đến hạn của tác vụ quét],
  [Dữ liệu thử], [Đơn 100 000 đồng đang được tạm giữ; hồ sơ hoàn tiền do người mua mở với lý do "không đúng như mô tả"],
  [Các bước], [
    1. Tác vụ quét đọc danh sách đơn đến hạn giải ngân, thu được đúng một đơn.
    2. *Trước khi* tác vụ giành đơn đó, người mua mở một hồ sơ hoàn tiền trên chính đơn ấy.
    3. Tác vụ giành đơn rồi gọi lệnh giải ngân.
    4. Trường hợp ngược lại: trên một đơn khác, để tác vụ giải ngân xong trước, rồi người mua mới mở hồ sơ hoàn tiền.
  ],
  [Kết quả mong đợi], [
    Phép giành đơn thất bại, vì câu hỏi "đơn này còn đến hạn giải ngân không" được hỏi lại dưới
    khoá của đơn thay vì tin vào danh sách đã đọc từ trước. \
    Lệnh giải ngân sau đó không báo lỗi nhưng cũng không chạm vào tiền: khoản tạm giữ vẫn là
    100 000 đồng, số tiền đã giải ngân bằng 0. \
    Ở trường hợp ngược lại, việc mở hồ sơ hoàn tiền bị từ chối — khoản tiền mà hồ sơ nhắm tới
    không còn được tạm giữ nữa.
  ],
  [Kết quả thực tế], [*Đạt.* Ca này bắt đúng lớp lỗi mà một tác vụ quét theo lô thường mắc: đọc danh sách ứng viên ở một thời điểm rồi hành động ở một thời điểm khác],
)

== Danh mục ca kiểm thử chính

Bảng dưới đây liệt kê các ca kiểm thử chính còn lại, nhóm theo miền nghiệp vụ. Cột loại phân
biệt ca thuận — kiểm chứng hệ thống làm đúng việc được yêu cầu, ca nghịch — kiểm chứng hệ
thống từ chối đúng chỗ, và ca biên — kiểm chứng hành vi ở ranh giới của một quy tắc.

#figure(
  kind: table,
  caption: [Danh mục ca kiểm thử chính và kết quả thực thi],
  table(
    columns: (0.09fr, 0.63fr, 0.14fr, 0.14fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([Mã], [Ca kiểm thử và kết quả mong đợi], [Loại], [Kết quả]),

    table.cell(colspan: 4, fill: rgb("#F7F7F7"))[*Dòng tiền, tiền tạm giữ và hồ sơ hoàn tiền*],
    [TC-04], [Ví từ chối mọi bút toán làm số dư âm, thay vì ghi rồi sửa sau], [Nghịch], [Đạt],
    [TC-05], [Điều chỉnh ví do quản trị viên thực hiện phải mang một khoá chống lặp: gọi lại cùng một khoá không ghi có thêm, và yêu cầu không có khoá thì bị từ chối thay vì ghi mà không được bảo vệ], [Nghịch], [Đạt],
    [TC-06], [Tiền tạm giữ đi đúng một vòng giữ rồi giải ngân; lệnh giữ lặp lại bị từ chối thay vì giữ hai lần], [Biên], [Đạt],
    [TC-07], [Khi hồ sơ hoàn tiền được xử, tiền phải chuyển xong trước khi hồ sơ chuyển sang trạng thái kết thúc — làm ngược lại thì một lần chuyển tiền thất bại sẽ không có gì chạy lại], [Nghịch], [Đạt],
    [TC-08], [Hai điều hành viên cùng phân xử một hồ sơ thì chỉ một quyết định được ghi nhận], [Nghịch], [Đạt],
    [TC-09], [Hồ sơ hoàn tiền quá hạn được thúc tự động, nhưng bỏ qua hồ sơ đã có nhân viên xử lý và nhường một lần khiếu nại mà nó chưa thấy], [Nghịch], [Đạt],

    table.cell(colspan: 4, fill: rgb("#F7F7F7"))[*Đặt hàng, tồn kho và thương lượng giá*],
    [TC-10], [Đặt hàng vượt tồn kho bị từ chối trước khi thu tiền], [Nghịch], [Đạt],
    [TC-11], [Phiếu mua tạm phải được giành trước khi thu tiền, để hai lần bấm thanh toán không thành hai giao dịch], [Biên], [Đạt],
    [TC-12], [Dòng hàng đã trả tiền không phải của người bán để huỷ, kể cả khi nó đang nằm trong danh sách chờ đặt vận đơn lại], [Nghịch], [Đạt],
    [TC-13], [Đề nghị đối ứng nhường một lần chấp nhận mà nó chưa thấy; mỗi biến thể hàng chỉ có một đề nghị đang hiệu lực], [Nghịch], [Đạt],
    [TC-14], [Phiếu mua tạm không được thanh toán thì hết hạn, và tồn kho đang giữ được trả lại], [Biên], [Đạt],
    [TC-15], [Huỷ một đơn đã thanh toán thì hoàn tác lượt bán, không phải hoàn tác lượt giữ tồn kho], [Nghịch], [Đạt],

    table.cell(colspan: 4, fill: rgb("#F7F7F7"))[*Vận chuyển*],
    [TC-16], [Hãng không phục vụ tuyến thì biến khỏi danh sách báo giá, các hãng còn lại vẫn báo giá bình thường], [Biên], [Đạt],
    [TC-17], [Hãng trả lời chậm vẫn bị cắt theo hạn chờ đã khai báo], [Nghịch], [Đạt],
    [TC-18], [Hãng gửi về một mã trạng thái mà nền tảng không mô hình hoá thì bị từ chối, thay vì suy đoán ra một trạng thái gần giống], [Nghịch], [Đạt],
    [TC-19], [Mốc hành trình do hãng báo không phải của người mua hay người bán để tự ghi: cả hai bên đều bị từ chối và trạng thái vận đơn giữ nguyên nơi hãng để lại], [Nghịch], [Đạt],

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
    [TC-29], [Không đối tượng truyền dữ liệu nào bỏ khoá khi giá trị bằng rỗng hoặc bằng không — nếu bỏ, ứng dụng khách sẽ lỗi ngay dòng dữ liệu thật đầu tiên], [Thuận], [Đạt],
    [TC-30], [Kênh thời gian thực tham chiếu đủ mọi loại thông điệp, và các thông điệp dùng chung một phong bì], [Thuận], [Đạt],
    [TC-31], [Đặc tả đã lưu trùng khớp với đặc tả sinh lại từ hệ thống], [Thuận], [Đạt],
  ),
)

Hai nhận xét về danh mục này. Thứ nhất, phần lớn các ca là ca nghịch, điều được kiểm chứng là
hệ thống từ chối đúng chỗ, chứ không phải hệ thống chạy được nhánh thuận. Đó là chủ ý: nhánh
thuận của một luồng nghiệp vụ hầu như luôn được chạy qua khi dựng bối cảnh cho một ca nghịch,
còn nhánh nghịch thì chỉ được chạy khi có người viết riêng cho nó. Thứ hai, nhóm cấu hình và hợp
đồng đặc tả, tức TC-26 đến TC-31, là nhóm duy nhất đã được đưa vào quy trình tích hợp liên tục,
nên cũng là nhóm duy nhất tự bảo vệ mình mà không cần ai nhớ chạy lệnh.

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
    [Phép hoán vị có khoá giữ nguyên miền giá trị, mỗi loại thực thể một biến thể; có ca kiểm thử vòng mã hoá – giải mã, ca kiểm không va chạm, và một bộ giá trị đối chiếu khoá chặt chuỗi định danh đã phát ra],
    [Đạt],

    [NFR-05],
    [Phân quyền theo vai trò ở tầng dịch vụ],
    [Cổng vào chỉ xử lý xác thực, nguồn gốc yêu cầu và nhật ký, không nơi nào đọc vai trò; phép kiểm vai trò nằm ở tầng dịch vụ, xuất hiện ở hơn 40 điểm trên sáu phân hệ, và có ca kiểm thử gọi chéo vai trò],
    [Đạt],

    [NFR-06],
    [Che sự tồn tại bản ghi với người ngoài cuộc],
    [TC-23 đạt trên bốn phân hệ. Vẫn còn vài chỗ trả về "bị cấm" thay vì "không tìm thấy", và quy tắc này chưa được cưỡng chế bằng một cơ chế dùng chung],
    [Đạt một phần],

    [NFR-10],
    [Tính lũy đẳng của các chuyển đổi theo thời hạn],
    [Định nghĩa "đến hạn" nằm ở đúng một chỗ, dùng chung cho cả tác vụ quét lẫn luồng thực thi bền bỉ; TC-02, TC-03 và TC-09 đều khẳng định gọi lại không sinh thêm bút toán],
    [Đạt],

    [NFR-11],
    [Chống nhân đôi đơn hàng và nhân đôi thu tiền],
    [TC-01, TC-02, TC-05 và TC-11 phủ nhóm này ở tầng dịch vụ. Bốn ràng buộc duy nhất ở tầng dữ liệu trên phiếu mua tạm, trên thương lượng, trên mã tham chiếu của nhà cung cấp và trên khoá chống lặp của bút toán ví là lớp phòng vệ thứ hai, chỉ kiểm chứng được khi có cơ sở dữ liệu thật],
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

== Hạn chế và hướng phát triển

Đánh giá trên góc độ hoàn thiện của sản phẩm thực tế thay vì các phép đo kỹ thuật kiểm thử, hệ thống hiện tồn đọng 4 hạn chế cốt lõi:

- *Chưa tích hợp dịch vụ đối tác ở môi trường thực tế:* Dù hệ thống đã xử lý hoàn chỉnh luồng tiền và luồng giao nhận, toàn bộ tương tác hiện chỉ chạy trên bộ giả lập. Ứng dụng chưa đối mặt với các kịch bản ngoại lệ vật lý từ hãng vận chuyển thật (như sai khối lượng, không liên lạc được khách) và các rào cản biến động độ trễ từ cổng thanh toán thực tế.

- *Dữ liệu quan trắc vận hành chưa được khai thác:* Hạ tầng quan trắc (nhật ký, độ đo, dấu vết) đã được thiết lập đầy đủ ở tầng nền tảng, nhưng do hệ thống chưa có lưu lượng người dùng thật, các ngưỡng cảnh báo độ sẵn sàng và nút thắt cổ chai hiệu năng của ứng dụng chưa được định chuẩn.

- *Thiếu cơ chế tự động nhận diện rủi ro gian lận:* Phân hệ tín nhiệm và hội thoại đã gom đủ dữ liệu lịch sử giao dịch, nhưng ứng dụng hiện chỉ phản ứng thụ động khi có người dùng khiếu nại, thay vì chủ động nhận diện sớm các mẫu hành vi bất thường (như rửa uy tín qua đơn hàng ảo, bơm thổi giá).

- *Ranh giới triển khai chưa tách rời thành vi dịch vụ (Microservices):* Dù 7 phân hệ nghiệp vụ đã hoàn toàn cô lập về cơ sở dữ liệu và hợp đồng mã nguồn, chúng vẫn đang được đóng gói và chạy chung trong một khối nguyên khối (Modular Monolith) để tiết kiệm tài nguyên.