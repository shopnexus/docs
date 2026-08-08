#import "../../common/tokens.typ": *

= KIỂM THỬ VÀ ĐÁNH GIÁ

Chương này trình bày cách hệ thống được kiểm chứng và kết quả thu được. Nội dung đi theo
trình tự của một hồ sơ kiểm thử đầy đủ: trước hết là chiến lược và các mức kiểm thử cùng
phạm vi của từng mức, tiếp đến là đặc tả ca kiểm thử kèm ma trận truy xuất tới yêu cầu,
sau đó là kết quả thực tế của bộ kiểm thử tự động và của phép đo hiệu năng thực nghiệm,
và sau cùng là đối chiếu với các yêu cầu phi chức năng cùng phần tự đánh giá hạn chế.

Một nguyên tắc được giữ xuyên suốt chương: mọi con số xuất hiện ở đây đều là con số đã đo
được, kèm theo cách đo và điều kiện đo. Nơi nào chưa có phép đo, chương này ghi rõ là chưa
có thay vì đưa ra một ước lượng nghe hợp lý. Cách trình bày đó khiến chương có nhiều mục
"chưa kiểm chứng được" hơn thông lệ, nhưng đổi lại mỗi phát biểu còn lại đều truy ngược
được về một lệnh đã chạy hoặc một tệp kết quả đã sinh ra.

== Chiến lược kiểm thử

Chiến lược kiểm thử của hệ thống xuất phát từ một nhận định về rủi ro chứ không từ mong
muốn phủ đều mọi thành phần. Đây là một sàn giao dịch giữa các cá nhân, nơi tiền của người
mua được giữ lại ở bên thứ ba cho tới khi giao dịch kết thúc; vì vậy nhóm rủi ro đắt nhất
không phải là giao diện hiển thị sai mà là các quy tắc quyết định dòng tiền: một phiên
thanh toán được quyết toán hai lần, một đơn hàng được sinh ra hai lần từ cùng một lần trả
tiền, một khoản ký quỹ được giải ngân trong khi tranh chấp còn treo, hay một yêu cầu ghi
đè lên trạng thái mà nó chưa từng đọc. Toàn bộ nỗ lực kiểm thử được ưu tiên cho nhóm này,
kế đó là hợp đồng giao tiếp giữa máy chủ và các ứng dụng khách, rồi mới đến phần còn lại.

Kiến trúc của hệ thống được chọn một phần vì nó làm cho việc kiểm thử trở nên rẻ. Ba quyết
định thiết kế có tác dụng trực tiếp ở đây. Thứ nhất, mỗi phân hệ công bố hợp đồng của mình
qua một gói chỉ phụ thuộc vào thư viện chuẩn, nên một phân hệ khác có thể được kiểm thử
với một bản giả lập của hợp đồng đó mà không cần dựng phân hệ thật. Thứ hai, tầng nghiệp
vụ thuần tuý không biết gì về cơ sở dữ liệu, giao thức hay khung tiêm phụ thuộc, nên các
quy tắc nghiệp vụ được kiểm chứng bằng những phép gọi hàm thông thường, không cần hạ tầng.
Thứ ba, mỗi phân hệ chỉ nói chuyện với kho dữ liệu qua một giao diện kho chứa, và mỗi phân
hệ đều có một bản hiện thực giao diện đó trong bộ nhớ dành riêng cho kiểm thử; nhờ vậy
toàn bộ tầng dịch vụ chạy được mà không cần một máy chủ cơ sở dữ liệu nào. Hệ quả đo được
là bộ kiểm thử mặc định của kho dịch vụ nền chạy trọn vẹn trong khoảng bốn mươi bảy giây
cộng dồn và không yêu cầu bất kỳ dịch vụ ngoài nào.

Về mức độ tự động hoá, chiến lược đặt ra là mọi kiểm chứng phải chạy được bằng một lệnh
duy nhất, không có bước thủ công nào nằm trên đường kiểm tra trước khi hợp nhất mã. Mục
tiêu đặt ra cho tỷ lệ tháp kiểm thử là bảy phần kiểm thử đơn vị, hai phần kiểm thử tích
hợp và một phần kiểm thử hệ thống, còn mục tiêu độ phủ mã là tám mươi phần trăm cho mức
đơn vị. Cần nói rõ ngay tại đây rằng đó là *mục tiêu đặt ra*, không phải kết quả đạt được:
hiện chưa có kho nào trong ba kho mã nguồn của đề tài thu thập số liệu độ phủ, nên chương
này không đưa ra bất kỳ con số phần trăm độ phủ nào. Mục 6.7 phân tích khoảng cách giữa
mục tiêu và hiện trạng.

Về môi trường và dữ liệu thử, đề tài dùng ba lớp dữ liệu tách bạch. Lớp thứ nhất là dữ
liệu dựng ngay trong bộ nhớ bởi từng ca kiểm thử, phục vụ các quy tắc nghiệp vụ thuần
tuý. Lớp thứ hai là một tập dữ liệu mồi dùng cho môi trường phát triển, nạp bằng một
chương trình riêng và từ chối chạy lần thứ hai để không nhân đôi dữ liệu. Lớp thứ ba là
các bản giả lập nhà cung cấp bên ngoài: cổng thanh toán giả có mười kịch bản và hãng vận
chuyển giả có mười một kịch bản, mỗi kịch bản tương ứng với một cách mà giao dịch hoặc
kiện hàng có thể hỏng trong thực tế. Các kịch bản này không phải là trang trí mà chính là
dữ liệu thử cho những ca kiểm thử nghịch quan trọng nhất của chương, chẳng hạn thông báo
thanh toán được giao hai lần, thông báo báo sai số tiền, hay mốc hành trình đến trễ so với
trạng thái mà kiện hàng đã đi qua.

Tiêu chí kết thúc kiểm thử được đặt ra gồm bốn điều kiện: bộ kiểm thử tự động của kho
dịch vụ nền phải xanh hoàn toàn; công cụ phân tích tĩnh không được phát ra cảnh báo nào;
đặc tả giao diện lập trình công bố không được lệch so với mã nguồn sinh ra nó; và mọi khiếm
khuyết ở mức chặn hoặc nghiêm trọng phải được xử lý xong. Ba điều kiện đầu hiện đã thoả
mãn và có bằng chứng chạy lệnh kèm theo trong mục 6.4.

== Các mức kiểm thử và phạm vi

Hệ thống được kiểm chứng ở bốn mức, xếp theo phạm vi tăng dần và chi phí chạy tăng dần.

Mức thấp nhất là *kiểm thử đơn vị và thành phần*. Phạm vi của mức này là toàn bộ quy tắc
nghiệp vụ thuần tuý, các bộ chuyển đổi và kiểm tra dữ liệu đầu vào, tầng dịch vụ của từng
phân hệ chạy trên kho dữ liệu giả trong bộ nhớ, các bộ xử lý yêu cầu HTTP, tầng trung gian
xác thực và kiểm soát nguồn gốc yêu cầu, cùng các trình tích hợp nhà cung cấp bên ngoài
chạy trên máy chủ HTTP giả dựng ngay trong ca kiểm thử. Đây là mức duy nhất hiện đang chạy
đầy đủ và xanh trên mỗi lần chạy lệnh.

Mức thứ hai là *kiểm thử hợp đồng*. Đây là nhóm ca kiểm thử đặc thù của đề tài, xuất phát
từ chỗ hệ thống có ba kho mã nguồn và hai ứng dụng khách sinh mã tự động từ đặc tả. Nhóm
này kiểm chứng rằng mọi tham chiếu trong đặc tả giao diện lập trình đều phân giải được,
rằng không có khoá lược đồ nào trùng nhau giữa các phân mảnh đặc tả của các phân hệ, rằng
mọi đường dẫn được công bố đều có một tuyến phục vụ thật ở bộ định tuyến, rằng kênh sự
kiện thời gian thực tham chiếu đủ tám loại thông điệp và tất cả dùng chung một phong bì,
và rằng không một đối tượng truyền dữ liệu nào bỏ khoá khi giá trị của nó bằng rỗng. Ca
kiểm thử cuối cùng đáng chú ý vì nó được viết dưới dạng duyệt cây cú pháp của mã nguồn:
một khoá bị bỏ khi giá trị rỗng sẽ khiến ứng dụng khách sinh mã không giải mã được phản
hồi, và lỗi đó chỉ lộ ra ở thiết bị người dùng chứ không lộ ra ở máy chủ.

Mức thứ ba là *kiểm thử tích hợp tầng dữ liệu và hạ tầng*. Phạm vi gồm các bộ điều hợp
truy cập cơ sở dữ liệu của sáu phân hệ, kho phiên đăng nhập trên bộ nhớ đệm, hai đường
truyền thông điệp và kho tệp tải lên. Nhóm này kiểm chứng đúng những gì tầng dịch vụ không
thể kiểm chứng được: các ràng buộc toàn vẹn của cơ sở dữ liệu, ghi có kiểm soát phiên bản,
khoá tư vấn khi sửa cây danh mục, và các câu lệnh ghi có điều kiện dựa trên trạng thái
hiện hành. Toàn bộ nhóm này được gắn nhãn biên dịch riêng và chỉ chạy khi biến chuỗi kết
nối cơ sở dữ liệu được thiết lập. Trong môi trường thực hiện phép đo của báo cáo này, biến
đó chưa được cấu hình, nên *toàn bộ nhóm bị bỏ qua*; đây là hạn chế lớn nhất của hồ sơ
kiểm thử và được phân tích ở mục 6.7.

Mức cao nhất là *kiểm thử hệ thống và đầu-cuối*, tức chạy một kịch bản nghiệp vụ trọn vẹn
từ giao diện người dùng qua máy chủ tới cơ sở dữ liệu. Mức này *chưa được xây dựng*. Bản
giả lập toàn bộ hợp đồng phục vụ bằng Prism cho phép viết ứng dụng khách trước khi bộ xử
lý phía máy chủ tồn tại, nhưng đó là giả lập hợp đồng, không phải kiểm thử đầu-cuối, và
không được tính vào bất kỳ con số nào của chương này.

#fig(
  [Tháp kiểm thử thực tế của hệ thống, đối chiếu với tỷ lệ mục tiêu bảy - hai - một],
  spacing: (0pt, 9pt),
  node(
    (0, 0),
    align(center)[
      Kiểm thử hệ thống / đầu-cuối \
      *0 ca* — chưa xây dựng
    ],
    width: 58mm,
    fill: white,
    stroke: (paint: ink, thickness: 0.9pt, dash: "dashed"),
  ),
  node(
    (0, 1),
    align(center)[
      Kiểm thử tích hợp tầng dữ liệu và hạ tầng \
      *93 hàm kiểm thử* — bị bỏ qua vì thiếu chuỗi kết nối
    ],
    width: 90mm,
    fill: amber-l,
    stroke: 1pt + amber,
  ),
  node(
    (0, 2),
    align(center)[
      Kiểm thử đơn vị, thành phần và hợp đồng \
      *616 hàm kiểm thử* trên dịch vụ nền (xanh hoàn toàn) \
      *247 ca kiểm thử* trên ứng dụng di động (đếm từ mã nguồn)
    ],
    width: 132mm,
    fill: teal-l,
    stroke: 1pt + teal,
  ),
)

Đặt cạnh nhau, ba tầng cho tỷ lệ khoảng chín mươi phần trăm ở đáy, mười phần trăm ở giữa
và không phần trăm ở đỉnh, tính trên chín trăm năm mươi sáu ca kiểm thử đã khai báo. So
với tỷ lệ mục tiêu, tháp này không bị lộn ngược — lỗi thường gặp nhất của một hồ sơ kiểm
thử — nhưng nó bị *cụt đỉnh* và tầng giữa thì có mà chưa chạy. Nói cách khác, hình dạng
đúng, còn bằng chứng thì chỉ đầy đủ ở tầng đáy.

#figure(
  kind: table,
  caption: [Các mức kiểm thử, phạm vi và trạng thái bằng chứng],
  table(
    columns: (0.20fr, 0.40fr, 0.20fr, 0.20fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([Mức], [Phạm vi], [Công cụ], [Trạng thái bằng chứng]),
    [Đơn vị và thành phần],
    [Quy tắc nghiệp vụ thuần tuý, tầng dịch vụ trên kho dữ liệu giả, bộ xử lý yêu cầu, tầng trung gian, trình tích hợp nhà cung cấp],
    [Bộ kiểm thử chuẩn của Go],
    [Đã chạy, xanh hoàn toàn],

    [Hợp đồng],
    [Đặc tả giao diện lập trình, đặc tả sự kiện thời gian thực, quy ước tuần tự hoá đối tượng truyền dữ liệu],
    [Bộ kiểm thử chuẩn của Go, duyệt cây cú pháp],
    [Đã chạy, xanh hoàn toàn],

    [Tích hợp tầng dữ liệu và hạ tầng],
    [Bộ điều hợp cơ sở dữ liệu của sáu phân hệ, kho phiên, hai đường truyền thông điệp, kho tệp tải lên],
    [Bộ kiểm thử chuẩn của Go với nhãn biên dịch riêng, PostgreSQL và Redis thật],
    [Chưa chạy — bị bỏ qua toàn bộ do thiếu chuỗi kết nối],

    [Giao diện ứng dụng di động],
    [Thành phần giao diện và luồng điều hướng, chạy trên một máy chủ giả ghi lại lời gọi],
    [Bộ kiểm thử của Flutter],
    [Có trong quy trình tích hợp liên tục; không chạy được trên máy đo do thiếu bộ công cụ],

    [Hệ thống và đầu-cuối],
    [Kịch bản nghiệp vụ trọn vẹn xuyên ba tầng],
    [Chưa chọn],
    [Chưa xây dựng],

    [Hiệu năng],
    [Sáu kịch bản đọc chính, hai mức đồng thời],
    [Bộ tạo tải viết riêng, mô hình vòng kín],
    [Đã đo, kết quả ở mục 6.5],

    [Bảo mật thâm nhập],
    [Xác thực, phân quyền, kiểm tra dữ liệu đầu vào],
    [Chưa chọn],
    [Chưa thực hiện],
  ),
)

Phân bố số lượng hàm kiểm thử của kho dịch vụ nền cho thấy trọng tâm rơi đúng vào nơi đã
dự tính. Ba nhóm đứng đầu là trình tích hợp nhà cung cấp bên ngoài, phân hệ tài khoản và
phân hệ danh mục hàng hoá; hai nhóm đầu tương ứng với ranh giới mà hệ thống không kiểm
soát được và với cửa vào của mọi phiên làm việc, còn nhóm thứ ba là nơi tập trung phần lớn
logic tìm kiếm và tồn kho.

#figure(
  kind: table,
  caption: [Phân bố hàm kiểm thử của kho dịch vụ nền theo phân hệ và theo tầng],
  table(
    columns: (0.5fr, 0.25fr, 0.25fr),
    align: (left, right, right),
    table.header([Nhóm], [Số hàm kiểm thử], [Tỷ lệ]),
    [Trình tích hợp nhà cung cấp bên ngoài], [115], [18,7 %],
    [Phân hệ tài khoản], [110], [17,9 %],
    [Phân hệ danh mục hàng hoá], [105], [17,0 %],
    [Tiện ích dùng chung], [67], [10,9 %],
    [Phân hệ đơn hàng], [55], [8,9 %],
    [Tầng cổng giao tiếp], [47], [7,6 %],
    [Phân hệ tín nhiệm], [36], [5,8 %],
    [Phân hệ hội thoại], [25], [4,1 %],
    [Phân hệ tài chính], [24], [3,9 %],
    [Tầng hạ tầng kỹ thuật], [11], [1,8 %],
    [Nạp và kiểm tra cấu hình], [8], [1,3 %],
    [Các chương trình dòng lệnh], [8], [1,3 %],
    [Phân hệ quan trắc], [5], [0,8 %],
    [*Tổng*], [*616*], [*100 %*],
  ),
)

== Đặc tả ca kiểm thử và truy xuất nguồn gốc

Mục này đặc tả các ca kiểm thử tiêu biểu và nối chúng về các yêu cầu chức năng đã ban hành
ở chương phân tích yêu cầu. Cần một ghi chú về cách đánh mã: các ca kiểm thử dưới đây mang
mã riêng của hồ sơ kiểm thử, còn cột yêu cầu ghi mã `REQ-xx` của chương phân tích, nên mỗi
dòng của ma trận truy xuất đối chiếu ngược được về phát biểu yêu cầu gốc.

Ba ca kiểm thử được đặc tả đầy đủ dưới đây là ba ca đại diện cho ba nhóm rủi ro khác nhau:
một ca bảo vệ hợp đồng giữa các kho mã nguồn, một ca bảo vệ tính đúng đắn của dòng tiền
trước một sự kiện lặp, và một ca bảo vệ trạng thái vận đơn trước một thông báo đến muộn.

#figure(
  kind: table,
  caption: [Đặc tả ca kiểm thử TC-04 — Đường dẫn công bố phải có tuyến phục vụ],
  table(
    columns: (0.28fr, 1fr),
    align: (left + top, left + top),
    fill: (x, y) => if y == 0 { headfill } else if x == 0 { rgb("#F7F7F7") } else { white },
    table.header([Mã ca kiểm thử], [TC-04 — Mọi đường dẫn công bố trong đặc tả đều có tuyến phục vụ thật]),
    [Yêu cầu liên quan], [Hợp đồng giao diện lập trình công bố; khả năng sinh mã ứng dụng khách],
    [Mức kiểm thử], [Hợp đồng],
    [Loại], [Thuận],
    [Mức ưu tiên], [Cao],
    [Điều kiện tiên quyết], [Đặc tả hợp nhất đã được sinh lại từ các phân mảnh của bảy phân hệ; bộ định tuyến đã đăng ký đầy đủ các tuyến],
    [Các bước], [1. Nạp đặc tả hợp nhất đang được phục vụ. \ 2. Lấy tập đường dẫn được công bố. \ 3. Với mỗi đường dẫn, đối chiếu với tập tuyến mà bộ định tuyến thực sự đăng ký, có tính tiền tố phiên bản.],
    [Dữ liệu thử], [Đặc tả hợp nhất gồm 135 đường dẫn và 171 thao tác],
    [Kết quả mong đợi], [Không có đường dẫn nào chỉ tồn tại trong đặc tả mà không có tuyến phục vụ; ca kiểm thử nêu đích danh đường dẫn lệch nếu có],
    [Kết quả thực tế], [Đạt — không phát hiện đường dẫn lệch],
  ),
)

#figure(
  kind: table,
  caption: [Đặc tả ca kiểm thử TC-11 — Thông báo thanh toán được giao hai lần],
  table(
    columns: (0.28fr, 1fr),
    align: (left + top, left + top),
    fill: (x, y) => if y == 0 { headfill } else if x == 0 { rgb("#F7F7F7") } else { white },
    table.header([Mã ca kiểm thử], [TC-11 — Cổng thanh toán giao cùng một thông báo thành công hai lần]),
    [Yêu cầu liên quan], [Thanh toán và bảo lãnh tạm giữ; sinh đơn hàng từ sự kiện thanh toán],
    [Mức kiểm thử], [Thành phần],
    [Loại], [Biên],
    [Mức ưu tiên], [Chặn],
    [Điều kiện tiên quyết], [Một phiên thanh toán đang chờ; cổng thanh toán giả được chọn kịch bản giao thông báo lặp],
    [Các bước], [1. Mở phiên thanh toán cho một bản nháp đơn hàng. \ 2. Kích hoạt thanh toán qua cổng giả. \ 3. Cổng giả gửi thông báo thành công lần thứ nhất. \ 4. Cổng giả gửi lại đúng thông báo đó lần thứ hai.],
    [Dữ liệu thử], [Kịch bản "báo thành công hai lần" của cổng thanh toán giả, cùng mã tham chiếu và cùng số tiền ở cả hai lần],
    [Kết quả mong đợi], [Chỉ một đơn hàng được sinh ra; lần giao thứ hai được ghi nhận nhưng không tạo thêm bản ghi tài chính nào; ràng buộc duy nhất trên bản nháp đơn hàng chặn bản ghi thứ hai kể cả khi tầng dịch vụ sai],
    [Kết quả thực tế], [Đạt ở mức thành phần. Nhánh do ràng buộc cơ sở dữ liệu chặn thuộc nhóm tích hợp nên hiện chưa được chứng minh],
  ),
)

#figure(
  kind: table,
  caption: [Đặc tả ca kiểm thử TC-13 — Mốc hành trình đến muộn so với trạng thái hiện hành],
  table(
    columns: (0.28fr, 1fr),
    align: (left + top, left + top),
    fill: (x, y) => if y == 0 { headfill } else if x == 0 { rgb("#F7F7F7") } else { white },
    table.header([Mã ca kiểm thử], [TC-13 — Hãng vận chuyển gửi mốc hành trình lùi so với trạng thái đã đạt]),
    [Yêu cầu liên quan], [Theo dõi vận đơn; xác nhận giao hàng và mở bộ đếm tạm giữ],
    [Mức kiểm thử], [Thành phần],
    [Loại], [Nghịch],
    [Mức ưu tiên], [Cao],
    [Điều kiện tiên quyết], [Một vận đơn đã được đặt và đã tiến tới trạng thái giao thành công],
    [Các bước], [1. Chọn kịch bản gửi mốc sai thứ tự ở hãng vận chuyển giả. \ 2. Nhận mốc "đang xử lý" sau khi trạng thái đã là "giao thành công". \ 3. Đọc lại trạng thái vận đơn.],
    [Dữ liệu thử], [Chuỗi mốc: đang xử lý, giao thành công, đang xử lý],
    [Kết quả mong đợi], [Trạng thái vận đơn không lùi; mốc đến muộn bị bỏ qua; bộ đếm thời gian tạm giữ đã mở không bị đặt lại],
    [Kết quả thực tế], [Đạt],
  ),
)

Danh mục ca kiểm thử đầy đủ ở dạng rút gọn được trình bày dưới đây. Cột trạng thái phản
ánh đúng mức bằng chứng hiện có: "Đạt" nghĩa là ca kiểm thử nằm trong bộ kiểm thử mặc định
đã chạy xanh; "Chưa chạy" nghĩa là ca kiểm thử đã được viết nhưng thuộc nhóm chỉ chạy khi
có cơ sở dữ liệu thật và hiện bị bỏ qua.

#figure(
  kind: table,
  caption: [Danh mục ca kiểm thử tiêu biểu và trạng thái thực thi],
  table(
    columns: (0.08fr, 0.52fr, 0.12fr, 0.14fr, 0.14fr),
    align: (left + top, left + top, left + top, left + top, left + top),
    table.header([Mã], [Tiêu đề và kết quả mong đợi], [Loại], [Mức], [Trạng thái]),

    [TC-01], [Tài liệu cấu hình thiếu một trường bắt buộc thì tiến trình dừng khi khởi động và thông báo nêu đúng đường dẫn cần sửa], [Nghịch], [Đơn vị], [Đạt],
    [TC-02], [Tài liệu cấu hình chứa một khoá không được khai báo thì bị từ chối thay vì bỏ qua trong im lặng], [Nghịch], [Đơn vị], [Đạt],
    [TC-03], [Danh sách cổng thanh toán nêu tên một nhà cung cấp nhưng thiếu thông tin xác thực của nhà cung cấp đó thì khởi động thất bại], [Biên], [Đơn vị], [Đạt],
    [TC-04], [Mọi đường dẫn công bố trong đặc tả đều có tuyến phục vụ thật], [Thuận], [Hợp đồng], [Đạt],
    [TC-05], [Mọi tham chiếu lược đồ phân giải được và không có khoá trùng giữa các phân mảnh đặc tả của bảy phân hệ], [Thuận], [Hợp đồng], [Đạt],
    [TC-06], [Không đối tượng truyền dữ liệu nào bỏ khoá khi giá trị bằng rỗng, không hoặc bằng số không], [Thuận], [Hợp đồng], [Đạt],
    [TC-07], [Kênh sự kiện thời gian thực tham chiếu đủ tám loại thông điệp và tất cả dùng chung một phong bì], [Thuận], [Hợp đồng], [Đạt],
    [TC-08], [Yêu cầu mang thẻ truy cập còn hạn nhưng thuộc một phiên đã bị thu hồi thì bị từ chối], [Nghịch], [Thành phần], [Đạt],
    [TC-09], [Đổi nút cha của một danh mục theo cách tạo thành chu trình thì bị từ chối, kể cả khi hai thao tác diễn ra đồng thời], [Nghịch], [Tích hợp], [Chưa chạy],
    [TC-10], [Ghi một tổng thể bằng số phiên bản đã cũ thì thất bại với xung đột phiên bản, dữ liệu không bị đè], [Nghịch], [Tích hợp], [Chưa chạy],
    [TC-11], [Cổng thanh toán giao cùng một thông báo thành công hai lần thì chỉ một đơn hàng được sinh ra], [Biên], [Thành phần], [Đạt],
    [TC-12], [Cổng thanh toán báo thành công với số tiền khác số tiền của phiên thì phiên không được quyết toán], [Nghịch], [Thành phần], [Đạt],
    [TC-13], [Mốc hành trình đến muộn so với trạng thái hiện hành thì bị bỏ qua, trạng thái chỉ tiến], [Nghịch], [Thành phần], [Đạt],
    [TC-14], [Hãng vận chuyển gửi trạng thái mà nền tảng không mô hình hoá thì hệ thống bỏ qua thay vì suy đoán], [Nghịch], [Thành phần], [Đạt],
    [TC-15], [Hãng vận chuyển không phục vụ tuyến thì biến khỏi danh sách báo giá, các hãng còn lại vẫn báo giá bình thường], [Biên], [Thành phần], [Đạt],
    [TC-16], [Đặt vận đơn thất bại sau khi phí đã được thu thì đơn hàng vẫn tồn tại và được xếp vào danh sách đặt lại], [Nghịch], [Thành phần], [Đạt],
    [TC-17], [Phân vị 95 của các đường đọc chính nằm trong ngưỡng của NFR-01, NFR-02 và NFR-04 ở cả hai mức đồng thời], [Hiệu năng], [Hệ thống], [Đạt],
    [TC-18], [Không có yêu cầu nào trả về mã lỗi trong suốt hai lượt đo tải], [Hiệu năng], [Hệ thống], [Đạt],
  ),
)

Ma trận truy xuất dưới đây đối chiếu từng nhóm yêu cầu chức năng với các ca kiểm thử phủ
nó và với mức phủ hiện có. Cột cuối cùng là phần đáng chú ý nhất của toàn mục: nó cho thấy
độ phủ hiện tại phân bố rất không đều, và nhóm được kiểm chứng yếu nhất lại là nhóm liên
quan tới toàn vẹn dữ liệu, vì đó chính là nhóm chỉ kiểm chứng được khi có cơ sở dữ liệu
thật.

#figure(
  kind: table,
  caption: [Ma trận truy xuất giữa nhóm yêu cầu chức năng và ca kiểm thử],
  table(
    columns: (0.24fr, 0.15fr, 0.14fr, 0.14fr, 0.33fr),
    align: (left + top, left + top, left + top, left + top, left + top),
    table.header([Nhóm yêu cầu chức năng], [Mã], [Ca kiểm thử đại diện], [Số hàm kiểm thử tự động], [Mức phủ hiện có]),

    [Tài khoản, phân quyền và phiên đăng nhập],
    [REQ-01…08, REQ-42],
    [TC-08],
    [110],
    [Phủ tốt ở mức đơn vị và thành phần; các ràng buộc duy nhất ở tầng lưu trữ chưa được chứng minh],

    [Danh mục hàng hoá và đăng bán],
    [REQ-09…13],
    [TC-09],
    [105],
    [Quy tắc nghiệp vụ phủ tốt; quy tắc cây danh mục và tồn kho phụ thuộc nhóm tích hợp chưa chạy],

    [Tìm kiếm và gợi ý sản phẩm],
    [REQ-14…17],
    [TC-17],
    [Nằm trong nhóm danh mục],
    [Phủ ở mức chức năng và mức hiệu năng; chưa có đánh giá chất lượng kết quả tìm kiếm],

    [Hội thoại và thương lượng giá],
    [REQ-18…21],
    [—],
    [25],
    [Phủ ở mức tầng dịch vụ; chưa có kiểm thử tải cho kênh thời gian thực],

    [Đặt hàng, vận chuyển và theo dõi vận đơn],
    [REQ-22, REQ-23, REQ-27…32],
    [TC-13, TC-14, TC-15, TC-16],
    [55],
    [Phủ tốt cho các nhánh nghịch nhờ mười một kịch bản của hãng vận chuyển giả],

    [Thanh toán và bảo lãnh tạm giữ],
    [REQ-24…26, REQ-40, REQ-41],
    [TC-11, TC-12],
    [24],
    [Phủ tốt cho các nhánh nghịch nhờ mười kịch bản của cổng thanh toán giả; luồng ghi sổ chưa đo hiệu năng],

    [Hoàn tiền, tranh chấp và phân xử],
    [REQ-33…37],
    [—],
    [36],
    [Phủ ở mức tầng dịch vụ; chưa có kịch bản đầu-cuối cho một vụ tranh chấp trọn vẹn],

    [Kiểm duyệt nội dung và điểm uy tín],
    [REQ-12, REQ-38, REQ-39],
    [—],
    [Nằm trong nhóm tín nhiệm],
    [Phủ ở mức tầng dịch vụ],

    [Hợp đồng giao diện lập trình và cấu hình vận hành],
    [REQ-43, REQ-44, REQ-46],
    [TC-01 đến TC-07],
    [55],
    [Phủ đầy đủ và có cổng tự động trong quy trình tích hợp liên tục],

    [Toàn vẹn dữ liệu và ghi có kiểm soát phiên bản],
    [REQ-45],
    [TC-10],
    [93 (nhóm tích hợp)],
    [*Chưa kiểm chứng* — toàn bộ nhóm bị bỏ qua],
  ),
)

== Kết quả kiểm thử tự động

Bộ kiểm thử của kho dịch vụ nền được chạy lại toàn bộ, không dùng bộ nhớ đệm kết quả, vào
ngày thực hiện phép đo. Kết quả là mã thoát bằng không, không một gói nào thất bại. Con số
đáng nói không nằm ở cột "đạt" mà ở cột "không có tệp kiểm thử": năm mươi trên tổng số
chín mươi chín gói không chứa một tệp kiểm thử nào. Nói cách khác, đúng một nửa số gói của
kho dịch vụ nền hiện không được kiểm chứng trực tiếp bởi bất kỳ ca kiểm thử nào của riêng
nó. Một phần trong đó là các gói chỉ khai báo kiểu dữ liệu hoặc chỉ khai báo cấu hình tiêm
phụ thuộc, tức là những gói mà một ca kiểm thử riêng sẽ chỉ lặp lại chính khai báo đó;
nhưng phần còn lại là khoảng trống thật, và không có số liệu độ phủ nào để phân định hai
phần đó với nhau.

#figure(
  kind: table,
  caption: [Kết quả chạy bộ kiểm thử tự động của kho dịch vụ nền],
  table(
    columns: (0.6fr, 0.4fr),
    align: (left, right),
    table.header([Chỉ số], [Giá trị]),
    [Mã thoát của lệnh chạy kiểm thử], [0],
    [Số gói đạt], [49],
    [Số gói thất bại], [0],
    [Số gói không có tệp kiểm thử], [50],
    [Tổng số gói], [99],
    [Tổng thời gian chạy cộng dồn], [46,685 s],
    [Số hàm kiểm thử ở bản dựng mặc định], [616],
    [Số hàm kiểm thử khi bật nhãn tích hợp], [709],
    [Số hàm chỉ chạy khi bật nhãn tích hợp], [93],
    [Số ca kiểm thử con], [32],
    [Số kiểm thử đo hiệu năng vi mô], [0],
    [Số kiểm thử sinh dữ liệu ngẫu nhiên], [0],
    [Cảnh báo của công cụ phân tích tĩnh tiêu chuẩn], [0],
  ),
)

Về phân tích tĩnh, công cụ tiêu chuẩn đi kèm bộ dịch chạy sạch, không phát ra cảnh báo
nào. Bộ công cụ kiểm tra chất lượng mã mở rộng thì *không chạy được* trên mã nguồn này:
phiên bản hiện hành của công cụ được dựng bằng một phiên bản ngôn ngữ cũ hơn phiên bản mà
mã nguồn nhắm tới, nên nó từ chối nạp cấu hình. Đây là một khoảng trống đã biết và đã được
ghi ngay trong tệp cấu hình của công cụ; hệ quả là cổng chất lượng tĩnh thực sự đang vận
hành chỉ còn công cụ tiêu chuẩn, và nó cũng đang được chạy bằng tay chứ không nằm trong
quy trình tự động.

Nhóm kiểm thử tích hợp tầng dữ liệu gồm mười bảy tệp và chín mươi ba hàm kiểm thử bổ sung
so với bản dựng mặc định. Khi chạy với nhãn tích hợp trong môi trường đo, chúng báo bỏ qua
thay vì chạy, vì biến chuỗi kết nối chưa được thiết lập; riêng nhóm bộ điều hợp của phân
hệ danh mục hàng hoá cho ba mươi dòng báo bỏ qua. Vì vậy phải phát biểu chính xác rằng
*chưa từng có bằng chứng nhóm kiểm thử tích hợp chạy đạt*, chứ không phải chúng đã chạy và
đạt ở một môi trường nào khác.

Về ứng dụng di động, bộ kiểm thử gồm bốn mươi hai tệp, hai trăm linh hai ca kiểm thử đơn
vị và bốn mươi lăm ca kiểm thử thành phần giao diện, tổng cộng hai trăm bốn mươi bảy ca,
tổ chức thành sáu mươi nhóm và chiếm hơn sáu nghìn dòng mã. Cần nhấn mạnh một điều: *các
con số này được đếm từ mã nguồn chứ không lấy từ một lần chạy*, bởi bộ công cụ Flutter
không có mặt trên máy thực hiện phép đo. Quy trình tích hợp liên tục của kho ứng dụng di
động có chạy phân tích tĩnh và chạy toàn bộ bộ kiểm thử này trên mỗi lần đẩy mã và mỗi yêu
cầu gộp mã, nhưng nhật ký của những lần chạy đó không được lưu trong kho, nên chương này
không dựa vào chúng để khẳng định kết quả.

#figure(
  kind: table,
  caption: [Quy mô bộ kiểm thử của ứng dụng di động (đếm từ mã nguồn)],
  table(
    columns: (0.6fr, 0.4fr),
    align: (left, right),
    table.header([Chỉ số], [Giá trị]),
    [Số tệp kiểm thử], [42],
    [Số ca kiểm thử đơn vị], [202],
    [Số ca kiểm thử thành phần giao diện], [45],
    [Tổng số ca kiểm thử], [247],
    [Số nhóm kiểm thử], [60],
    [Số dòng mã kiểm thử], [6 092],
    [Số thư mục kiểm thử trên thiết bị thật], [0],
  ),
)

Ứng dụng web là điểm yếu rõ rệt nhất của hồ sơ kiểm thử: kho này *không có một bài kiểm
thử nào*. Một khung kiểm thử đầu-cuối đã được cài vào danh sách phụ thuộc phát triển
nhưng chưa có tệp cấu hình, chưa có thư mục kịch bản và chưa có lệnh chạy trong tệp mô tả
gói. Những gì đang kiểm chứng phía web hiện chỉ gồm trình kiểm kiểu tĩnh và trình kiểm quy
tắc mã nguồn, cả hai đều được gọi bằng tay.

Bức tranh về cổng kiểm tra tự động cũng cần được nói thẳng. Trong ba kho mã nguồn, chỉ kho
ứng dụng di động thực sự chạy kiểm thử trong quy trình tích hợp liên tục. Kho dịch vụ nền
có hai quy trình, nhưng một quy trình chỉ dựng và đẩy ảnh chạy, còn quy trình kia chỉ kiểm
tra rằng đặc tả giao diện lập trình được sinh lại không lệch so với bản đã lưu — một cổng
hữu ích, song nó không chạy một ca kiểm thử nào. Kho ứng dụng web chỉ dựng ảnh chạy. Điều
đó có nghĩa là bộ kiểm thử sáu trăm mười sáu hàm của dịch vụ nền, dù xanh hoàn toàn, hiện
*phụ thuộc vào việc lập trình viên nhớ chạy nó*.

#figure(
  kind: table,
  caption: [Cổng kiểm tra tự động hiện có trong quy trình tích hợp liên tục của ba kho mã nguồn],
  table(
    columns: (0.22fr, 0.20fr, 0.30fr, 0.28fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([Kho mã nguồn], [Số quy trình], [Cổng kiểm tra thực sự chạy], [Kiểm thử có chạy không]),
    [Dịch vụ nền], [2], [Dựng và đẩy ảnh chạy; kiểm tra đặc tả giao diện lập trình không lệch], [Không],
    [Ứng dụng web], [1], [Dựng và đẩy ảnh chạy], [Không],
    [Ứng dụng di động], [3], [Phân tích tĩnh; chạy toàn bộ bộ kiểm thử; dựng gói cài đặt; phát hành và triển khai bản web], [Có],
  ),
)

== Kiểm thử hiệu năng

=== Phương pháp và môi trường đo

Phép đo hiệu năng được thực hiện bằng một bộ tạo tải viết riêng cho đề tài, là một chương
trình Go chỉ dùng thư viện chuẩn. Bộ tạo tải hoạt động theo *mô hình vòng kín*: mỗi luồng
phát một yêu cầu, chờ nhận trọn vẹn phản hồi rồi mới phát yêu cầu kế tiếp. Lựa chọn này có
lý do phương pháp luận. Mô hình vòng hở, tức phát yêu cầu theo một tốc độ cố định bất kể
hệ thống có kịp trả lời hay không, sẽ biến độ trễ quan sát được thành độ dài hàng đợi khi
hệ thống bắt đầu quá tải, và như vậy che mất chính điểm bão hoà — thứ mà phép đo này muốn
tìm. Mô hình vòng kín ngược lại đo đúng độ trễ mà một người dùng đang chờ phải chịu dưới
tải, và số luồng chính là số người dùng đang chờ đồng thời.

Mỗi kịch bản chạy theo hai pha. Pha khởi động kéo dài ba giây và kết quả bị loại bỏ, nhằm
để trình tối ưu hoá của Go và bộ nhớ đệm kế hoạch truy vấn của cơ sở dữ liệu đạt trạng
thái ổn định. Pha đo kéo dài hai mươi giây và là nguồn của mọi con số công bố dưới đây.
Các phân vị được tính theo phương pháp thứ hạng gần nhất, không nội suy, nên mỗi giá trị
phân vị là một mẫu quan sát thật chứ không phải một giá trị trung gian được suy ra. Phép
đo được lặp ở hai mức đồng thời là mười luồng và năm mươi luồng, để có thể quan sát hệ
thống thay đổi thế nào khi tải tăng gấp năm lần.

Sáu kịch bản được chọn là sáu đường đọc có lưu lượng cao nhất trong vận hành thực tế của
một sàn giao dịch: duyệt danh sách tin đăng, tìm kiếm lai kết hợp từ khoá với ngữ nghĩa,
tìm kiếm thuần từ khoá, lấy từ điển danh mục, đọc hồ sơ phiên đăng nhập, và liệt kê đơn
hàng của người dùng hiện tại. Ba kịch bản đầu chạm cơ sở dữ liệu và chỉ mục; kịch bản tìm
kiếm lai còn phải gọi ra một dịch vụ sinh vector nhúng bên ngoài; hai kịch bản cuối đại
diện cho các đường đọc gắn với phiên làm việc.

#fig(
  [Bố trí phép đo hiệu năng theo mô hình vòng kín],
  spacing: (30mm, 11mm),
  nt((0, 1), [Bộ tạo tải \ 10 hoặc 50 luồng]),
  np((1, 1), [Cổng giao tiếp HTTP \ (chạy trong vùng chứa)]),
  np((2, 0), [PostgreSQL 18 \ kèm TimescaleDB]),
  np((2, 1), [Redis 7 \ (bộ nhớ đệm, phiên)]),
  np((2, 2), [Dịch vụ sinh vector nhúng \ (chỉ ở kịch bản tìm kiếm lai)]),
  edge((0, 1), (1, 1), "-|>", text(size: 8pt)[vòng kín], label-side: left),
  edge((1, 1), (2, 0), "-|>"),
  edge((1, 1), (2, 1), "-|>"),
  edge((1, 1), (2, 2), "-|>"),
)

#figure(
  kind: table,
  caption: [Cấu hình môi trường thực hiện phép đo hiệu năng],
  table(
    columns: (0.35fr, 0.65fr),
    align: (left + top, left + top),
    table.header([Hạng mục], [Giá trị]),
    [Bộ xử lý], [Intel Xeon E-2286M, 8 nhân 16 luồng, 2,40 GHz],
    [Bộ nhớ trong], [19 GB],
    [Hệ điều hành], [Linux 7.1.5 (Arch)],
    [Dịch vụ nền], [Chạy trong vùng chứa, không đặt giới hạn bộ xử lý hay bộ nhớ],
    [Cơ sở dữ liệu], [TimescaleDB trên PostgreSQL 18, vùng chứa riêng],
    [Bộ nhớ đệm], [Redis 7, vùng chứa riêng],
    [Vị trí bộ tạo tải], [Cùng máy với dịch vụ, đi qua giao diện loopback],
    [Thời điểm đo], [Ngày 08 tháng 8 năm 2026],
  ),
)

#figure(
  kind: table,
  caption: [Quy mô dữ liệu trong cơ sở dữ liệu tại thời điểm đo],
  table(
    columns: (0.6fr, 0.4fr),
    align: (left, right),
    table.header([Bảng dữ liệu], [Số dòng]),
    [Tin đăng], [1 001],
    [Biến thể sản phẩm], [4 972],
    [Vector nhúng của tin đăng], [1 000],
    [Tài khoản], [56],
    [Đơn hàng], [15],
    [Dòng hàng], [33],
    [Giao dịch thanh toán], [38],
    [Tin nhắn], [67],
    [Đánh giá sản phẩm], [0],
  ),
)

=== Kết quả đo

Hai bảng dưới đây trình bày nguyên vẹn kết quả của hai lượt đo. Cột thông lượng tính bằng
số yêu cầu phục vụ được trong một giây; các cột phân vị và cột giá trị tối đa tính bằng
mili-giây.

#figure(
  kind: table,
  caption: [Kết quả đo hiệu năng ở mức mười luồng đồng thời],
  table(
    columns: (0.26fr, 0.12fr, 0.14fr, 0.10fr, 0.10fr, 0.10fr, 0.12fr, 0.06fr),
    align: (left, right, right, right, right, right, right, right),
    table.header([Kịch bản], [Số yêu cầu], [Thông lượng], [p50], [p95], [p99], [Tối đa], [Lỗi]),
    [Duyệt danh sách tin đăng], [19 155], [957,4], [10,4], [12,2], [13,4], [19,5], [0],
    [Tìm kiếm lai], [980], [48,9], [151,8], [171,5], [264,7], [5 153,4], [0],
    [Tìm kiếm từ khoá], [29 227], [1 461,0], [6,8], [7,9], [9,0], [49,4], [0],
    [Từ điển danh mục], [34 119], [1 705,8], [2,1], [65,1], [72,3], [94,0], [0],
    [Hồ sơ phiên đăng nhập], [67 604], [3 379,3], [1,0], [4,3], [52,7], [84,9], [0],
    [Danh sách đơn hàng của tôi], [63 185], [3 158,9], [3,0], [3,9], [4,8], [45,6], [0],
  ),
)

#figure(
  kind: table,
  caption: [Kết quả đo hiệu năng ở mức năm mươi luồng đồng thời],
  table(
    columns: (0.26fr, 0.12fr, 0.14fr, 0.10fr, 0.10fr, 0.10fr, 0.12fr, 0.06fr),
    align: (left, right, right, right, right, right, right, right),
    table.header([Kịch bản], [Số yêu cầu], [Thông lượng], [p50], [p95], [p99], [Tối đa], [Lỗi]),
    [Duyệt danh sách tin đăng], [20 939], [1 046,2], [48,5], [62,1], [68,3], [97,5], [0],
    [Tìm kiếm lai], [4 800], [238,9], [220,1], [246,2], [300,2], [354,9], [0],
    [Tìm kiếm từ khoá], [34 409], [1 718,9], [29,0], [38,5], [43,2], [62,3], [0],
    [Từ điển danh mục], [60 720], [3 035,4], [5,2], [74,2], [82,4], [168,5], [0],
    [Hồ sơ phiên đăng nhập], [63 952], [3 195,8], [6,5], [65,4], [75,5], [103,8], [0],
    [Danh sách đơn hàng của tôi], [71 196], [3 558,5], [13,6], [16,9], [21,5], [55,3], [0],
  ),
)

Cộng hai lượt đo, hệ thống đã phục vụ 470 286 yêu cầu và *không có một yêu cầu nào lỗi
hoặc trả về mã trạng thái từ 400 trở lên*. Đây là kết quả đáng kể về tính ổn định chức
năng dưới tải, tuy nhiên cần đặt nó trong đúng phạm vi: phép đo chỉ bao phủ đường đọc, nên
kết luận này nói về độ ổn định của các truy vấn đọc chứ không nói gì về đường ghi.

=== Phân tích kết quả

Bốn quan sát rút ra từ hai bảng trên đáng được bàn kỹ, vì mỗi quan sát dẫn tới một kết
luận kỹ thuật cụ thể chứ không chỉ là mô tả lại số liệu.

*Thứ nhất, tìm kiếm lai đắt hơn tìm kiếm thuần từ khoá khoảng hai mươi hai lần về độ trễ.*
Ở mười luồng, tìm kiếm từ khoá đạt 1 461,0 yêu cầu mỗi giây với p50 là 6,8 ms, trong khi
tìm kiếm lai chỉ đạt 48,9 yêu cầu mỗi giây với p50 là 151,8 ms. Điều quan trọng là khoảng
cách này *không* nằm ở thao tác dò vector trong cơ sở dữ liệu. Chỉ mục vector trên một
nghìn tin đăng là rất nhỏ và thao tác dò trên nó gần như không đáng kể. Chi phí nằm ở bước
trước đó: mỗi lượt tìm kiếm ngữ nghĩa phải gửi câu truy vấn của người dùng ra một dịch vụ
sinh vector nhúng bên ngoài và chờ vector trở về, trước khi có thể chạm tới cơ sở dữ liệu.
Nói cách khác, đây là chi phí của một lượt gọi mạng ra ngoài chứ không phải chi phí của
thuật toán tìm kiếm. Kết luận kỹ thuật rút ra là rất cụ thể: nên lưu đệm vector của những
câu truy vấn hay gặp, vì phân bố truy vấn tìm kiếm trên một sàn giao dịch vốn lệch mạnh về
một nhóm nhỏ các cụm từ phổ biến, và mỗi lần trúng đệm sẽ cắt bỏ trọn vẹn lượt gọi ra
ngoài. Ở mức năm mươi luồng, khi dịch vụ nhúng đã nóng, tỷ lệ này thu hẹp còn khoảng bảy
lần rưỡi (220,1 ms so với 29,0 ms) — điều đó củng cố chẩn đoán, vì nếu nguyên nhân là
thuật toán thì tỷ lệ sẽ không đổi theo trạng thái nóng lạnh của một dịch vụ bên ngoài.

*Thứ hai, giá trị tối đa 5 153,4 ms xuất hiện ở lượt đo đầu tiên là chi phí khởi động
nguội, không phải hành vi thường trực.* Giá trị này chỉ xuất hiện đúng một lần, ở kịch bản
đầu tiên có gọi ra dịch vụ bên ngoài, và ở lượt đo năm mươi luồng khi hệ thống đã nóng thì
giá trị tối đa của cùng kịch bản đó tụt xuống 354,9 ms, tức nhỏ hơn khoảng mười lăm lần.
Chương này nêu rõ con số ấy thay vì loại nó khỏi bảng, vì một giá trị tối đa bị cắt gọt sẽ
làm bảng đẹp hơn mà làm phép đo kém tin cậy hơn. Về mặt vận hành, quan sát này cũng có hệ
quả thực tế: nếu triển khai thật, người dùng đầu tiên chạm vào đường tìm kiếm ngữ nghĩa
sau mỗi lần khởi động lại tiến trình sẽ phải chờ vài giây, và đó là lý do nên có một lượt
làm nóng chủ động sau khi tiến trình sẵn sàng.

*Thứ ba, kịch bản từ điển danh mục có phân vị 95 lớn gấp hơn ba mươi lần phân vị 50* — 65,1
ms so với 2,1 ms ở mười luồng. Một phân bố lệch mạnh như vậy không phải là dấu hiệu của
một hệ thống chậm mà là dấu hiệu kinh điển của hiện tượng *dồn toa khi mục nhớ đệm hết
hạn*: tuyệt đại đa số yêu cầu được phục vụ ngay từ bộ nhớ đệm nên chỉ mất khoảng hai
mili-giây, nhưng vào đúng thời điểm mục đệm hết hạn thì mọi yêu cầu đang đến cùng lúc đều
trượt đệm và cùng rơi xuống cơ sở dữ liệu. Đây là một phát hiện thật của phép đo — nó
không nhìn thấy được từ mã nguồn — và nó dẫn thẳng tới một hướng cải thiện đã được xác
định: nạp lại mục đệm theo cơ chế chỉ cho một yêu cầu đi tiếp còn các yêu cầu còn lại chờ
kết quả của yêu cầu đó, hoặc làm mới mục đệm trước khi nó hết hạn. Ở năm mươi luồng, hiện
tượng vẫn còn nguyên (74,2 ms so với 5,2 ms), xác nhận rằng đây là đặc tính của cách nạp
đệm chứ không phải nhiễu của một lượt đo.

*Thứ tư, tăng đồng thời từ mười lên năm mươi luồng làm độ trễ tăng gần tuyến tính trong
khi thông lượng gần như đứng yên.* Đây là quan sát có ý nghĩa nhất về mặt kiến trúc. Ở
kịch bản duyệt danh sách tin đăng, thông lượng chỉ nhích từ 957,4 lên 1 046,2 yêu cầu mỗi
giây, tức tăng chín phần trăm, trong khi p50 nhảy từ 10,4 lên 48,5 ms, tức gấp gần bốn
lần rưỡi. Khi tải tăng gấp năm mà thông lượng không tăng còn độ trễ tăng gần đúng bằng hệ
số tải, điều đó có nghĩa là hệ thống đã *bão hoà*: các luồng thêm vào không được phục vụ
nhanh hơn mà chỉ xếp hàng lâu hơn. Bảng hệ số dưới đây cho thấy khuôn mẫu này lặp lại ở
mọi kịch bản đọc cơ sở dữ liệu.

#figure(
  kind: table,
  caption: [Hệ số thay đổi khi tăng số luồng đồng thời từ mười lên năm mươi],
  table(
    columns: (0.34fr, 0.22fr, 0.22fr, 0.22fr),
    align: (left, right, right, right),
    table.header([Kịch bản], [Hệ số p50], [Hệ số thông lượng], [Nhận định]),
    [Duyệt danh sách tin đăng], [4,66], [1,09], [Bão hoà],
    [Tìm kiếm từ khoá], [4,26], [1,18], [Bão hoà],
    [Danh sách đơn hàng của tôi], [4,53], [1,13], [Bão hoà],
    [Hồ sơ phiên đăng nhập], [6,50], [0,95], [Bão hoà, thông lượng giảm],
    [Từ điển danh mục], [2,48], [1,78], [Còn dư địa],
    [Tìm kiếm lai], [1,45], [4,89], [Ảnh hưởng bởi khởi động nguội],
  ),
)

Một hệ số trong bảng này là một kết luận nghiệm thu chứ không chỉ là một quan sát: hồ sơ
phiên đăng nhập có hệ số thông lượng 0,95, tức thông lượng *giảm* khi số luồng tăng, và
NFR-07 cấm đúng điều đó. Đây là yêu cầu phi chức năng duy nhất mà phép đo bác bỏ được, và
mục 6.6 kết luận thẳng là chưa đạt thay vì xếp chung vào diện chưa kiểm chứng.

Bảng hệ số làm rõ thêm hai điều mà hai bảng kết quả gốc không nói ra trực tiếp. Kịch bản
từ điển danh mục có hệ số thông lượng cao nhất trong nhóm còn dư địa (1,78) đúng vì nó
được phục vụ chủ yếu từ bộ nhớ đệm chứ không từ cơ sở dữ liệu — nó thoát khỏi nút thắt.
Kịch bản tìm kiếm lai có hệ số thông lượng dị thường (4,89) không phải vì nó mở rộng tốt
mà vì lượt đo mười luồng của nó bị kéo xuống bởi chi phí khởi động nguội đã phân tích ở
trên; con số này vì vậy không được dùng làm bằng chứng về khả năng mở rộng.

Kết luận chung của phần phân tích: điểm nghẽn của hệ thống ở quy mô đo được nằm ở *cơ sở
dữ liệu chứ không ở tầng ứng dụng*, và điểm bão hoà xuất hiện quanh mức mười luồng đồng
thời đối với các truy vấn đọc này. Điều đó cũng chỉ ra rằng biện pháp mở rộng đúng đắn ở
bước tiếp theo không phải là nhân thêm bản sao của tiến trình ứng dụng — vốn không giải
quyết được nút thắt nằm phía sau — mà là giảm số lượt chạm cơ sở dữ liệu trên mỗi yêu cầu,
mở rộng đọc bằng bản sao chỉ đọc, và mở rộng phạm vi phục vụ từ bộ nhớ đệm cho các đường
đọc có tỷ lệ đọc trên ghi cao.

=== Giới hạn của phép đo

Kết quả trên chỉ có giá trị trong đúng phạm vi mà cách đo cho phép, và phạm vi đó cần được
phát biểu rõ để không bị diễn giải quá tay.

Giới hạn thứ nhất là *vị trí của bộ tạo tải*. Bộ tạo tải chạy trên cùng một máy với dịch
vụ và đi qua giao diện loopback. Điều này gây ra hai sai lệch ngược chiều nhau: một mặt,
số đo không bao gồm độ trễ mạng thực tế, nên nó lạc quan hơn thực tế; mặt khác, bộ tạo tải
cạnh tranh bộ xử lý với chính dịch vụ mà nó đang đo, nên ở mức tải cao nó lấy đi một phần
năng lực xử lý của đối tượng đo. Tổng hợp lại, các con số tuyệt đối khi triển khai qua
mạng thật sẽ kém hơn những gì bảng trên thể hiện.

Giới hạn thứ hai là *bản dựng được đo*. Dịch vụ chạy trong phép đo là bản dựng dành cho
phát triển trong vùng chứa, không phải ảnh phát hành tối giản dùng khi triển khai.

Giới hạn thứ ba, và là giới hạn nghiêm trọng nhất về mặt suy rộng, là *quy mô dữ liệu*.
Một nghìn tin đăng và mười lăm đơn hàng là quy mô rất nhỏ so với một sàn giao dịch thật.
Các truy vấn đều có phân trang và đều đi qua chỉ mục, nên hình dạng của kết quả — thứ tự
đắt rẻ giữa các kịch bản, sự tồn tại của điểm bão hoà, hiện tượng dồn toa khi hết hạn
đệm — vẫn phản ánh đúng bản chất; nhưng các con số tuyệt đối chắc chắn sẽ khác trên tập dữ
liệu lớn. Riêng kịch bản liệt kê đơn hàng chạy trên một tài khoản chỉ có vài đơn, nên trên
thực tế nó đang đo chi phí cố định của toàn bộ đường đi một yêu cầu chứ chưa đo chi phí
ghép bảng; con số 3,0 ms của nó vì vậy nên được đọc như một cận dưới.

Giới hạn thứ tư là *phạm vi kịch bản*. Phép đo chỉ bao phủ đường đọc. Đường ghi — đặt hàng,
thanh toán, giữ tiền tạm giữ — không được đo, vì mỗi lượt ghi sinh ra dữ liệu nghiệp vụ
thật và kéo theo lời gọi tới nhà cung cấp bên ngoài, nên không thể lặp lại hàng chục nghìn
lần trong một phép đo tải mà không làm hỏng dữ liệu. Đây là khoảng trống đã biết và hướng
xử lý đã rõ: cần một môi trường thử riêng, dùng toàn bộ các bản giả lập nhà cung cấp, và
một quy trình khôi phục dữ liệu sau mỗi lượt đo.

Giới hạn thứ năm là *thời lượng và cường độ*. Mỗi kịch bản chỉ đo hai mươi giây, nên không
phát hiện được các vấn đề tích luỹ theo thời gian như rò rỉ bộ nhớ, rò rỉ kết nối hay suy
giảm hiệu năng do phân mảnh. Đề tài cũng chưa thực hiện kiểm thử điểm gãy, tức tăng dần
tải cho tới khi hệ thống thực sự hỏng, nên chưa xác định được ngưỡng chịu tải tối đa mà
chỉ xác định được điểm bắt đầu bão hoà.

== Đánh giá mức độ đáp ứng yêu cầu phi chức năng

Mục này đối chiếu từng nhóm yêu cầu phi chức năng với bằng chứng đo được và kết luận theo
ba trạng thái: đạt, chưa đạt, hoặc chưa kiểm chứng được. Trạng thái thứ ba không phải là
một cách nói giảm của "chưa đạt" mà là một kết luận khác hẳn: nó có nghĩa là hệ thống có
thể đang đáp ứng hoặc không, và hồ sơ hiện tại không đủ căn cứ để khẳng định theo hướng
nào.

Một ghi chú về cách đọc bảng: cột đầu ghi mã hiệu của bộ yêu cầu phi chức năng đã ban hành
ở chương phân tích và cả ba mươi hai mã đều có mặt, còn cột ngưỡng chép đúng tiêu chí định
lượng của mã đó chứ không phải một ngưỡng do chương này tự đặt. Đây là điểm đáng nhấn
mạnh, vì một ngưỡng tự đặt vừa có thể tô hồng vừa có thể kết luận nhầm là chưa đạt cho thứ
thực ra đã đạt. Dòng về khả năng quan trắc không mang mã, vì bộ yêu cầu không đặt ngưỡng
cho chính bộ máy đo.

#figure(
  kind: table,
  caption: [Đối chiếu yêu cầu phi chức năng với bằng chứng đo được],
  table(
    columns: (0.15fr, 0.18fr, 0.23fr, 0.32fr, 0.14fr),
    align: (left + top, left + top, left + top, left + top, left + top),
    table.header([Mã], [Nhóm yêu cầu], [Ngưỡng của chương phân tích], [Bằng chứng đo được], [Kết luận]),

    [NFR-01, NFR-02, NFR-04],
    [Thời gian đáp ứng của đường đọc chính],
    [p95 của danh sách tin đăng dưới 30 rồi 100 ms; của tìm kiếm từ khoá dưới 20 rồi 60 ms; của đường đọc đã xác thực dưới 10 rồi 80 ms, ở mười và năm mươi luồng],
    [Danh sách tin đăng 12,2 rồi 62,1 ms; tìm kiếm từ khoá 7,9 rồi 38,5 ms; hồ sơ phiên 4,3 rồi 65,4 ms và danh sách đơn hàng 3,9 rồi 16,9 ms — cả bốn đường đều trong ngưỡng ở hai mức tải],
    [Đạt],

    [NFR-03],
    [Thời gian đáp ứng của tìm kiếm lai],
    [p95 dưới 250 ms ở mười luồng và dưới 350 ms ở năm mươi luồng],
    [171,5 ms ở mười luồng và 246,2 ms ở năm mươi luồng, đã loại giá trị tối đa của lượt gọi khởi động nguội theo đúng cách kiểm chứng đã quy định],
    [Đạt ở cả hai mức],

    [NFR-05],
    [Thông lượng],
    [Tối thiểu 800 yêu cầu mỗi giây với danh sách tin đăng và 1 200 với tìm kiếm từ khoá, ở mười luồng],
    [957,4 và 1 461,0 yêu cầu mỗi giây ở mười luồng, cả hai đều vượt ngưỡng của mình],
    [Đạt],

    [NFR-06],
    [Tính đúng đắn dưới tải],
    [Không một yêu cầu nào lỗi hoặc trả mã từ 500 trở lên, ở cả hai mức đồng thời],
    [470 286 yêu cầu qua hai lượt đo, không một mã trạng thái lỗi nào],
    [Đạt (chỉ cho đường đọc)],

    [NFR-07],
    [Số phiên đồng thời trên một nút],
    [Phục vụ tối thiểu 50 phiên đồng thời; ở mức đó độ trễ được phép tăng gần tuyến tính nhưng thông lượng *không được giảm* so với mức mười luồng],
    [Mức năm mươi luồng được phục vụ trọn vẹn và không lỗi, nhưng kịch bản hồ sơ phiên đăng nhập có hệ số thông lượng 0,95 — giảm từ 3 379,3 xuống 3 195,8 yêu cầu mỗi giây],
    [Chưa đạt],

    [NFR-08],
    [Độ trễ kênh thời gian thực],
    [Dưới 1 giây kể từ khi sự kiện được ghi bền tới lúc thiết bị nhận được thông báo đẩy],
    [Cấu hình có giới hạn số kết nối trên mỗi tài khoản và kích thước bộ đệm gửi, nhưng chưa có phép đo mốc thời gian hai đầu nào],
    [Chưa kiểm chứng được],

    [NFR-09, NFR-10, NFR-11, NFR-13, NFR-15],
    [Băm mật khẩu, vòng đời phiên, thu hồi, phân quyền và truy vấn tham số hoá],
    [Băm thích ứng có muối; thẻ 15 phút và phiên 30 ngày, tra phiên ở mọi yêu cầu; thu hồi có chi phí không phụ thuộc số phiên; phân quyền ở tầng dịch vụ; mọi truy vấn tham số hoá],
    [Có kiểm thử tự động cho xác thực, thu hồi phiên (TC-08) và kiểm tra dữ liệu vào; không có kiểm thử thâm nhập, không có quét lỗ hổng phụ thuộc, không có phép đo chi phí thu hồi trên tài khoản nhiều phiên],
    [Đạt một phần],

    [NFR-12, NFR-14, NFR-16, NFR-17, NFR-18],
    [Định danh mờ, che sự tồn tại bản ghi, tiết lưu và bảo vệ dữ liệu cá nhân],
    [Không dò được bản ghi kế tiếp; trả "không tìm thấy" thay vì "bị cấm"; tiết lưu mã dùng một lần; TLS 1.2 trở lên; ẩn danh người trả lời phiếu],
    [Không có ca kiểm thử dò tuần tự, không có phép so sánh mã trả về giữa tài nguyên của người khác và tài nguyên không tồn tại, không có quét cấu hình lớp biên và không có kiểm thử che dữ liệu theo vai trò],
    [Chưa kiểm chứng được],

    [NFR-19, NFR-20],
    [Lũy đẳng của chuyển trạng thái và chống nhân đôi giao dịch],
    [Gọi lại không sinh hiệu ứng mới; không hai đơn hàng hay hai lần thu tiền cho một lần bán],
    [TC-11 và TC-12 đạt trên cổng thanh toán giả: thông báo lặp chỉ sinh một đơn hàng, thông báo sai số tiền không quyết toán phiên; nhưng chưa có ca kiểm thử nào cho nhấn đúp đồng thời hay cho việc gọi lặp một chuyển trạng thái theo thời hạn],
    [Đạt một phần],

    [NFR-21, NFR-22, NFR-24],
    [Toàn vẹn và khôi phục dữ liệu],
    [Số dư không âm và khớp sổ bút toán; ghi đồng thời thì một bên thất bại bằng lỗi xung đột; sao lưu hằng ngày với thời gian phục hồi dưới 4 giờ và điểm phục hồi dưới 24 giờ],
    [93 hàm kiểm thử tích hợp đã viết — trong đó có TC-10 cho xung đột phiên bản — nhưng bị bỏ qua toàn bộ; không có tệp quay lui cho các bước chuyển đổi lược đồ và không có diễn tập phục hồi],
    [Chưa kiểm chứng được],

    [NFR-23],
    [Tính sẵn sàng],
    [Tối thiểu 99,5% theo tháng],
    [Không có dữ liệu vận hành, không có nhật ký sự cố, không có luật cảnh báo nào được cấu hình],
    [Chưa kiểm chứng được],

    [NFR-25],
    [Cách ly lược đồ giữa các dịch vụ],
    [Không khoá ngoại xuyên lược đồ, mọi tham chiếu chéo là tham chiếu logic],
    [Cách ly được cưỡng chế bằng đường tìm kiếm riêng cho từng nhóm kết nối và bằng việc mọi câu lệnh đều không ghi tên lược đồ, nhưng không có phép rà soát tự động nào đối chiếu quyền của từng tài khoản kết nối],
    [Đạt về thiết kế, chưa kiểm chứng bằng phép rà soát],

    [NFR-26, NFR-27],
    [Giao diện đáp ứng và xác nhận thao tác không hoàn tác],
    [Bố cục đúng từ 360 px tới 1920 px; mọi thao tác không hoàn tác có bước xác nhận nêu rõ hệ quả],
    [Kho ứng dụng web không có một bài kiểm thử nào và chưa có lượt rà soát luồng giao diện nào được ghi lại],
    [Chưa kiểm chứng được],

    [NFR-28],
    [Hạn chờ của lời gọi ra nhà cung cấp],
    [Mỗi thao tác có hạn chờ riêng khai báo trong tệp cấu hình],
    [Hạn chờ là trường bắt buộc của tài liệu cấu hình nên một cấu hình thiếu bị chặn ngay lúc khởi động (TC-01), nhưng chưa có ca kiểm thử nào chạy với bộ giả lập treo hay bộ giả lập trả dữ liệu nhỏ giọt],
    [Đạt một phần],

    [NFR-29],
    [Nạp và kiểm tra cấu hình],
    [Một tài liệu duy nhất, mọi trường bắt buộc, khoá lạ làm dừng khởi động kèm đường dẫn tới trường sai],
    [TC-01, TC-02 và TC-03 đều đạt, cùng tám hàm kiểm thử riêng cho việc nạp và kiểm tra cấu hình],
    [Đạt],

    [NFR-30],
    [Đặc tả giao diện lập trình là nguồn duy nhất],
    [Đặc tả sinh tự động từ các mảnh của từng dịch vụ và dựng được thành máy chủ giả lập],
    [TC-04 tới TC-07 đều đạt; quy trình tự động sinh lại đặc tả và so với bản đã lưu; bản giả lập hợp đồng phục vụ được toàn bộ đặc tả],
    [Đạt],

    [NFR-31],
    [Khả năng bảo trì],
    [Bộ kiểm tra tĩnh không còn một cảnh báo nào, và bộ kiểm thử đơn vị chạy trọn vẹn mà không cần cơ sở dữ liệu],
    [Bộ kiểm thử xanh hoàn toàn với 616 hàm và không cần cơ sở dữ liệu; phân tích tĩnh tiêu chuẩn không cảnh báo, nhưng bộ kiểm tra chất lượng mã mở rộng chưa chạy được do lệch phiên bản ngôn ngữ, nên nửa còn lại của ngưỡng chưa được chứng minh],
    [Đạt một phần],

    [NFR-32],
    [Tuân thủ pháp luật],
    [Đối chiếu với quy định về thương mại điện tử và Nghị định 13/2023],
    [Chưa có lượt rà soát đối chiếu văn bản quy định nào được thực hiện và ghi lại],
    [Chưa kiểm chứng được],

    [NFR-33],
    [Khả năng tiếp cận],
    [Đạt mức AA của WCAG 2.1 trên các luồng nghiệp vụ chính],
    [Chưa chạy một lượt kiểm tra tiếp cận nào, tự động hay bằng tay; giao diện được dựng có nhãn cho trường nhập và văn bản thay thế cho ảnh, nhưng không có bằng chứng đo tương phản hay điều hướng bằng bàn phím],
    [Chưa kiểm chứng được],

    [NFR-34],
    [Phạm vi trình duyệt và thiết bị],
    [Bốn trình duyệt ở hai phiên bản gần nhất, cùng trình duyệt mặc định của hai nền tảng di động],
    [Chưa có ma trận thử trên nhiều trình duyệt; phát triển và thử nghiệm chỉ diễn ra trên một trình duyệt nhân Chromium],
    [Chưa kiểm chứng được],

    [NFR-35],
    [Ngôn ngữ giao diện],
    [Toàn bộ giao diện và thông điệp bằng tiếng Việt, mỗi lỗi mang một mã ổn định độc lập ngôn ngữ],
    [Giao diện và thông điệp đều bằng tiếng Việt; mọi lỗi trả về theo giao diện lập trình đều có mã ổn định bên cạnh phần văn bản, đúng như thiết kế phong bì lỗi ở Chương 4],
    [Đạt],

    [NFR-36],
    [Thời gian làm quen của người dùng mới],
    [Người bán đăng được tin đầu tiên trong 15 phút; người mua hoàn tất một giao dịch giá cố định trong 10 phút],
    [Chưa tổ chức được buổi thử nghiệm với người dùng thật nào],
    [Chưa kiểm chứng được],

    [NFR-37],
    [Cửa sổ bảo trì],
    [Bảo trì có kế hoạch nằm trong khung giờ thấp điểm, không quá hai lần mỗi tháng và báo trước 48 giờ],
    [Hệ thống chưa vận hành nên chưa phát sinh lần bảo trì nào; đây là cam kết vận hành, không phải thuộc tính đo được ở giai đoạn này],
    [Chưa áp dụng được],

    [NFR-38],
    [Thời hạn lưu trữ dữ liệu],
    [Nhật ký kiểm toán giữ tối thiểu 5 năm và không sửa xoá được; nhật ký ứng dụng 30 ngày; tín hiệu quan trắc 90 ngày],
    [Cơ chế đã có đúng như thiết kế: nhật ký kiểm toán là bảng chỉ thêm mới và tài khoản kết nối của ứng dụng không có quyền sửa hay xoá trên bảng đó; nhưng chính sách thời hạn chưa được cấu hình và chưa có dữ liệu đủ dài để kiểm chứng],
    [Đạt về cơ chế, chưa kiểm chứng thời hạn],

    [NFR-39],
    [Mức tải và mốc tăng trưởng dữ liệu nghiệm thu],
    [Mọi ngưỡng phải giữ được ở hai mức tải và trên ba mốc tăng trưởng dữ liệu dự kiến],
    [Hai mức tải đã được nghiệm thu đúng quy định. Ba mốc tăng trưởng dữ liệu thì chưa: phép đo chạy trên một nghìn tin đăng, thấp hơn mốc nhỏ nhất tới hai bậc độ lớn],
    [Đạt một phần],

    [—],
    [Khả năng quan trắc],
    [Có đủ chỉ số, nhật ký và bảng theo dõi],
    [Bốn tín hiệu đo được thu thập, hai bảng tổng hợp liên tục, một bảng theo dõi sáu khung hình, nhật ký chảy về hệ thống tập trung — nhưng chưa có dữ liệu vận hành thực tế nào],
    [Đạt về thiết kế, chưa kiểm chứng bằng dữ liệu],
  ),
)

Một dòng trong bảng cần được nói rõ thay vì để lẫn vào các kết luận khác, vì nó là yêu cầu
duy nhất mà phép đo *bác bỏ* chứ không phải bỏ ngỏ. NFR-07 cho phép độ trễ tăng khi số
luồng tăng, nhưng cấm thông lượng giảm; kịch bản hồ sơ phiên đăng nhập lại tụt từ 3 379,3
xuống 3 195,8 yêu cầu mỗi giây khi đi từ mười lên năm mươi luồng, tức hệ số 0,95. Đây
không phải một lỗi chức năng — không một yêu cầu nào trong lượt đo ấy trả về mã lỗi — mà
là dấu hiệu hệ thống đã vượt qua điểm bão hoà: các luồng thêm vào chỉ xếp hàng lâu hơn, và
phần chi phí điều phối thêm vào đã lớn hơn phần công việc làm được thêm. Hướng khắc phục
đi theo đúng chẩn đoán ở mục trước, rằng nút thắt nằm ở cơ sở dữ liệu chứ không ở tầng ứng
dụng: nới tham số nhóm kết nối và xem lại chỉ mục của chính đường đọc này trước, rồi mới đo
lại ở nhiều mức đồng thời để xác định điểm gãy — nhân thêm bản sao tiến trình ứng dụng
không giải quyết được một nút thắt nằm dưới nó.

Tổng hợp lại, hiệu năng đường đọc, tìm kiếm lai, thông lượng, tính đúng đắn dưới tải, việc
nạp cấu hình và hợp đồng đặc tả là những nhóm có kết luận dứt khoát *đạt* dựa trên bằng
chứng trực tiếp. Nhóm bảo trì, bảo mật và chống nhân đôi giao dịch đạt một phần: phần được
kiểm chứng là phần chạy tự động được, phần chưa được kiểm chứng đúng là phần cần công cụ
hoặc môi trường mà đề tài chưa dựng. Các nhóm còn lại chưa kiểm chứng được, và điểm chung
của chúng là chúng đòi hỏi thứ mà một đề tài thực tập khó có: dữ liệu vận hành thực tế
trong một khoảng thời gian đủ dài, một cơ sở dữ liệu thật trong quy trình tự động, hoặc
một lượt rà soát bằng công cụ chuyên dụng.

== Hạn chế và hướng cải thiện

Hồ sơ kiểm thử của đề tài có những khoảng trống cần được nêu thẳng, kèm theo hướng khắc
phục cụ thể chứ không phải một lời hứa chung chung.

*Một yêu cầu phi chức năng đã bị phép đo bác bỏ.* NFR-07 cho phép độ trễ tăng theo số
luồng nhưng cấm thông lượng giảm, và kịch bản hồ sơ phiên đăng nhập lại tụt từ 3 379,3
xuống 3 195,8 yêu cầu mỗi giây khi số luồng tăng gấp năm. Đây là hạn chế duy nhất trong
danh sách này được chứng minh bằng số đo thay vì bằng sự vắng mặt của số đo, nên nó đứng
trước cả những khoảng trống về công cụ. Hướng khắc phục bám theo chẩn đoán rằng nút thắt
nằm ở cơ sở dữ liệu: nới tham số nhóm kết nối và xem lại chỉ mục của chính đường đọc ấy,
rồi đo lại theo nhiều mức đồng thời để biết ngưỡng mới nằm ở đâu.

*Không có số đo độ phủ mã ở bất kỳ kho nào.* Đây là hạn chế đứng đầu nhóm khoảng trống về
công cụ vì nó làm
mất khả năng đánh giá mọi hạn chế còn lại một cách định lượng. Không có độ phủ thì con số
sáu trăm mười sáu hàm kiểm thử không cho biết chúng chạm tới bao nhiêu phần của mã nguồn,
và việc một nửa số gói không có tệp kiểm thử không phân biệt được đâu là gói khai báo
thuần tuý, đâu là khoảng trống thật. Hướng khắc phục rất rẻ và nên làm trước tiên: bật cờ
thu thập độ phủ ngay trong lệnh chạy kiểm thử sẵn có, xuất báo cáo theo gói, rồi đặt một
ngưỡng tối thiểu cho các gói thuộc tầng nghiệp vụ và tầng dịch vụ thay vì đặt một ngưỡng
duy nhất cho toàn kho — vì một ngưỡng chung sẽ khuyến khích viết kiểm thử cho những gói dễ
phủ nhất thay vì những gói rủi ro nhất.

*Nhóm kiểm thử tích hợp tầng dữ liệu chưa từng được chứng minh là đạt.* Chín mươi ba hàm
kiểm thử đã được viết cho đúng những quy tắc mà tầng dịch vụ không kiểm chứng được — ràng
buộc duy nhất, ghi có kiểm soát phiên bản, khoá tư vấn khi sửa cây danh mục, ghi có điều
kiện theo trạng thái — nhưng chúng chỉ chạy khi có chuỗi kết nối tới một cơ sở dữ liệu
thật, và chuỗi đó chưa được cấu hình, nên toàn bộ nhóm báo bỏ qua. Điều nghịch lý là chi
phí khắc phục thấp: mã kiểm thử đã có sẵn, hạ tầng đã được mô tả bằng tệp soạn thảo vùng
chứa, và việc còn lại chỉ là dựng cơ sở dữ liệu như một dịch vụ đi kèm trong quy trình
tích hợp liên tục rồi truyền chuỗi kết nối vào. Đây là hạng mục có tỷ lệ giá trị trên công
sức cao nhất trong toàn bộ danh sách này.

*Quy trình tích hợp liên tục của kho dịch vụ nền không chạy kiểm thử.* Hai quy trình hiện
có chỉ dựng ảnh chạy và kiểm tra rằng đặc tả giao diện lập trình không lệch. Một bộ kiểm
thử xanh mà không có cổng tự động thì chỉ xanh cho tới lần đầu tiên có người quên chạy nó.
Hướng khắc phục là thêm một công việc chạy phân tích tĩnh và toàn bộ bộ kiểm thử trên mỗi
yêu cầu gộp mã, và đặt nó thành điều kiện bắt buộc để gộp. Cùng lúc đó, bộ công cụ kiểm
tra chất lượng mã mở rộng hiện không chạy được do lệch phiên bản ngôn ngữ; hướng xử lý là
ghim phiên bản công cụ theo phiên bản ngôn ngữ khi bản tương thích được phát hành, và
trong thời gian chờ thì giữ công cụ phân tích tiêu chuẩn làm cổng bắt buộc.

*Kho ứng dụng web không có một bài kiểm thử nào.* Đây là khoảng trống lớn nhất tính theo
lượng mã không được kiểm chứng. Một khung kiểm thử đầu-cuối đã có trong danh sách phụ
thuộc nhưng chưa được cấu hình. Hướng khắc phục được đề xuất theo hai bước có thứ tự ưu
tiên: trước hết đưa trình kiểm kiểu tĩnh và trình kiểm quy tắc mã nguồn vào quy trình tự
động, vì hai công cụ này đã sẵn sàng và bắt được nhóm lỗi phổ biến nhất của một ứng dụng
sinh mã từ đặc tả; sau đó mới viết một số ít kịch bản đầu-cuối cho các luồng sinh tiền, cụ
thể là đăng nhập, đăng tin, thanh toán và khiếu nại hoàn tiền.

*Kết quả kiểm thử của ứng dụng di động chưa được xác nhận trên máy thực hiện phép đo.* Hai
trăm bốn mươi bảy ca kiểm thử là con số đếm từ mã nguồn, không phải từ một lần chạy xanh,
vì bộ công cụ Flutter không có mặt trên máy đo. Quy trình tích hợp liên tục của kho này có
chạy chúng, nhưng nhật ký không được lưu lại. Hướng khắc phục là lưu báo cáo kết quả kiểm
thử dưới dạng hiện vật của mỗi lần chạy, để một khẳng định về số ca kiểm thử đạt luôn có
tệp kết quả kèm theo.

*Chưa có kiểm thử đầu-cuối xuyên hệ thống.* Không có kịch bản nào chạy thật từ ứng dụng
khách qua máy chủ tới cơ sở dữ liệu. Hệ quả là các lỗi phát sinh ở chỗ nối giữa ba kho mã
nguồn chỉ có thể được phát hiện bằng tay. Bản giả lập hợp đồng hiện có làm giảm rủi ro này
nhưng không thay thế được nó, vì nó kiểm chứng hình dạng của thông điệp chứ không kiểm
chứng hành vi. Hướng khắc phục là chọn một số ít kịch bản nghiệp vụ trọn vẹn — không nên
nhiều, vì kiểm thử đầu-cuối đắt và dễ vỡ — và chạy chúng trên môi trường dựng bằng tệp
soạn thảo vùng chứa với toàn bộ nhà cung cấp bên ngoài thay bằng bản giả lập.

*Chưa có kiểm thử độ bền, kiểm thử điểm gãy và kiểm thử đường ghi.* Phép đo hiện tại kéo
dài hai mươi giây mỗi kịch bản và chỉ chạm đường đọc, nên nó không phát hiện được rò rỉ
tài nguyên, không xác định được ngưỡng hỏng, và không nói gì về chi phí của một giao dịch
mua bán trọn vẹn. Hướng khắc phục là dựng một môi trường thử riêng có khả năng khôi phục
dữ liệu sau mỗi lượt đo, rồi bổ sung ba phép đo: một lượt chạy kéo dài nhiều giờ ở mức tải
vừa để quan sát rò rỉ, một lượt tăng tải theo bậc cho tới khi tỷ lệ lỗi vượt ngưỡng để xác
định điểm gãy, và một lượt đo đường ghi dùng toàn bộ bản giả lập nhà cung cấp.

*Chưa có kiểm thử bảo mật thâm nhập và quét lỗ hổng.* Các cơ chế bảo mật đã được kiểm
chứng ở mức đơn vị — xác thực, thu hồi phiên, kiểm tra dữ liệu vào — nhưng chưa có bất kỳ
đánh giá bảo mật nào ở mức hệ thống, không có quét lỗ hổng của các thư viện phụ thuộc,
không có phân tích bảo mật tĩnh hay động trong quy trình tự động. Hướng khắc phục theo thứ
tự chi phí tăng dần là: bật quét lỗ hổng phụ thuộc, vì nó gần như miễn phí và bắt được
nhóm rủi ro phổ biến nhất; sau đó thêm phân tích bảo mật tĩnh; và cuối cùng mới là một
lượt kiểm thử thâm nhập theo danh mục rủi ro ứng dụng web tiêu chuẩn.

*Hạ tầng quan trắc đã dựng đầy đủ nhưng chưa có dữ liệu vận hành thực tế.* Hệ thống thu
thập bốn tín hiệu đo, giữ hai bảng tổng hợp liên tục có cấu trúc tính phân vị đúng cách,
và có một bảng theo dõi sáu khung hình cùng đường nhật ký tập trung. Tuy nhiên trong kho
mã nguồn chỉ có *định nghĩa* của việc đo chứ không có kết quả đo nào từ vận hành: không có
bản kết xuất bảng theo dõi, không có nhật ký sự cố, và không có luật cảnh báo nào được cấu
hình. Vì vậy mọi phát biểu về tính sẵn sàng đều không có căn cứ ở thời điểm này. Hướng
khắc phục là triển khai lên một môi trường thử nghiệm chạy liên tục trong một khoảng thời
gian đủ dài, rồi bổ sung các luật cảnh báo cho ba chỉ số đã có sẵn dữ liệu là tỷ lệ lỗi,
phân vị 95 của độ trễ và tỷ lệ lỗi của các lời gọi ra nhà cung cấp bên ngoài.

Cuối cùng, cần ghi nhận một hạn chế thuộc về phạm vi hiện thực chứ không thuộc về kiểm
thử, nhưng ảnh hưởng trực tiếp tới giá trị của các kết quả trên: *chưa có hãng vận chuyển
thật nào được tích hợp*. Toàn bộ mười một kịch bản vận chuyển được kiểm chứng đều chạy
trên bản giả lập. Bản giả lập được thiết kế để bao phủ đúng những cách một kiện hàng có
thể hỏng, nên nó có giá trị kiểm thử cao, nhưng nó không thay thế được việc đối chiếu với
từ vựng trạng thái và hành vi báo lỗi thật của một hãng vận chuyển thương mại.

#figure(
  kind: table,
  caption: [Tổng hợp hạn chế, mức ảnh hưởng và hướng khắc phục],
  table(
    columns: (0.34fr, 0.16fr, 0.50fr),
    align: (left + top, left + top, left + top),
    table.header([Hạn chế], [Mức ảnh hưởng], [Hướng khắc phục]),

    [NFR-07 chưa đạt: thông lượng của một đường đọc giảm ở mức năm mươi luồng], [Cao], [Nới tham số nhóm kết nối và xem lại chỉ mục của chính đường đọc ấy, rồi đo lại ở nhiều mức đồng thời để xác định điểm gãy],
    [Không có số đo độ phủ mã], [Cao], [Bật thu thập độ phủ trong lệnh chạy sẵn có; đặt ngưỡng riêng cho tầng nghiệp vụ và tầng dịch vụ],
    [Nhóm kiểm thử tích hợp bị bỏ qua toàn bộ], [Cao], [Dựng cơ sở dữ liệu như dịch vụ đi kèm trong quy trình tự động và truyền chuỗi kết nối vào],
    [Quy trình tự động của dịch vụ nền không chạy kiểm thử], [Cao], [Thêm công việc chạy phân tích tĩnh và toàn bộ bộ kiểm thử, đặt thành điều kiện bắt buộc để gộp mã],
    [Ứng dụng web không có bài kiểm thử nào], [Cao], [Đưa kiểm kiểu tĩnh và kiểm quy tắc mã vào quy trình tự động trước; sau đó viết kịch bản đầu-cuối cho các luồng sinh tiền],
    [Chưa có kiểm thử đầu-cuối xuyên hệ thống], [Trung bình], [Chọn một số ít kịch bản nghiệp vụ trọn vẹn, chạy trên môi trường vùng chứa với nhà cung cấp giả lập],
    [Kết quả kiểm thử di động chưa xác nhận được tại chỗ], [Trung bình], [Lưu báo cáo kết quả kiểm thử làm hiện vật của mỗi lần chạy tự động],
    [Chưa có kiểm thử độ bền, điểm gãy và đường ghi], [Trung bình], [Dựng môi trường thử có khôi phục dữ liệu; bổ sung một lượt chạy dài, một lượt tăng bậc và một lượt đo đường ghi],
    [Chưa có kiểm thử bảo mật thâm nhập], [Trung bình], [Bật quét lỗ hổng phụ thuộc, thêm phân tích bảo mật tĩnh, sau cùng là một lượt thâm nhập theo danh mục rủi ro tiêu chuẩn],
    [Bộ kiểm tra chất lượng mã mở rộng không chạy được], [Thấp], [Ghim phiên bản công cụ theo phiên bản ngôn ngữ khi bản tương thích được phát hành],
    [Chưa có dữ liệu quan trắc từ vận hành], [Thấp], [Triển khai môi trường thử nghiệm chạy liên tục và cấu hình luật cảnh báo cho ba chỉ số đã có dữ liệu],
  ),
)

== Tiểu kết chương

Chương này đã trình bày chiến lược kiểm thử theo rủi ro của hệ thống, bốn mức kiểm thử
cùng phạm vi từng mức, mười tám ca kiểm thử tiêu biểu kèm ma trận truy xuất tới các mã yêu
cầu chức năng, kết quả thực tế của bộ kiểm thử tự động, một phép đo hiệu năng thực
nghiệm trên sáu kịch bản ở hai mức đồng thời, và bảng đối chiếu toàn bộ bộ yêu cầu phi
chức năng với bằng chứng đo được.

Về mặt kết quả, có ba điều đứng vững. Thứ nhất, bộ kiểm thử tự động của kho dịch vụ nền
chạy xanh hoàn toàn với sáu trăm mười sáu hàm kiểm thử trên bốn mươi chín gói, không một
gói nào thất bại, và công cụ phân tích tĩnh tiêu chuẩn không phát ra cảnh báo nào. Thứ
hai, hệ thống phục vụ 470 286 yêu cầu qua hai lượt đo tải mà không có một mã trạng thái
lỗi nào, và mọi đường đọc được chương phân tích đặt ngưỡng — kể cả tìm kiếm lai — đều giữ
phân vị 95 trong ngưỡng ấy ở cả hai mức đồng thời. Thứ ba, phép đo đã phát hiện được ba
đặc tính không nhìn
thấy được từ mã nguồn: chi phí thật của tìm kiếm ngữ nghĩa nằm ở lượt gọi sinh vector nhúng
chứ không ở thao tác dò vector, hiện tượng dồn toa khi mục nhớ đệm hết hạn ở kịch bản từ
điển danh mục, và điểm bão hoà nằm ở cơ sở dữ liệu chứ không ở tầng ứng dụng. Mỗi phát
hiện đều dẫn tới một hướng cải thiện cụ thể và kiểm chứng lại được.

Về mặt khoảng trống, chương này cũng đã nêu thẳng những điều mà một báo cáo tô hồng thường
bỏ qua: NFR-07 *chưa đạt*, vì thông lượng của một đường đọc giảm khi số luồng tăng gấp
năm; chưa có bất kỳ số đo độ phủ mã nào nên mục tiêu tám mươi phần trăm vẫn chỉ là mục
tiêu; nhóm kiểm thử tích hợp tầng dữ liệu tuy đã viết đủ chín mươi ba hàm nhưng chưa từng
được chứng minh là chạy đạt; ứng dụng web chưa có một bài kiểm thử nào và quy trình tự
động của dịch vụ nền chưa chạy kiểm thử; và hệ thống chưa có kiểm thử đầu-cuối, kiểm thử
độ bền, kiểm thử điểm gãy hay kiểm thử bảo mật thâm nhập. Các khoảng trống này được xếp
theo thứ tự ưu tiên khắc phục ở bảng tổng hợp cuối mục 6.7, trong đó hai hạng mục có chi
phí thực hiện thấp nhất so với giá trị mang lại nên được xử lý trước.

Nhìn tổng thể, hồ sơ kiểm thử của đề tài mạnh ở tầng đáy của tháp — nơi các quy tắc quyết
định dòng tiền được kiểm chứng dày đặc và các nhánh nghịch được phủ tốt nhờ hệ thống bản
giả lập nhà cung cấp có chủ đích — và yếu dần khi đi lên các tầng cần hạ tầng thật. Hình
dạng đó là hệ quả trực tiếp của việc lựa chọn kiến trúc cho phép kiểm thử không cần hạ
tầng, và cũng là hệ quả của việc đề tài chưa có môi trường vận hành liên tục. Xác định
đúng hình dạng ấy là điều kiện để bước cải thiện tiếp theo nhắm vào chỗ thiếu thay vì làm
dày thêm chỗ đã đủ.
