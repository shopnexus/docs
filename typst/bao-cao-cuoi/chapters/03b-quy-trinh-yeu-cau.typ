#import "../../common/tokens.typ": *

== Mô hình hóa quy trình nghiệp vụ

Danh mục ca sử dụng ở mục trước mô tả *mục tiêu* mà mỗi tác nhân theo đuổi; mục này mô
hình hóa *trình tự thực thi* của những mục tiêu đó. Sáu quy trình được chọn để vẽ sơ đồ
hoạt động, kèm hai sơ đồ trạng thái cho hai thực thể có vòng đời phức tạp nhất. Tiêu chí
chọn là ba dấu hiệu quen thuộc của một quy trình đáng được mô hình hóa: có nhiều điểm
quyết định, cắt ngang nhiều tác nhân, hoặc trực tiếp quyết định dòng tiền.

#figure(
  caption: [Các quy trình được chọn mô hình hóa và lý do chọn],
  table(
    columns: (1.5fr, 1.1fr, 2.9fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Quy trình], [Tác nhân tham gia], [Lý do cần mô hình hóa trực quan]),
    [Đăng bán và kiểm duyệt],
    [Người bán, hệ thống, điều phối viên],
    [Cắt ngang ba tác nhân; có hai điều kiện tiền đề dễ bị bỏ sót (đã xác minh danh tính, đã khai địa chỉ lấy hàng) và một nhánh riêng cho bản sửa của tin đang hiển thị.],

    [Thương lượng giá],
    [Người mua, người bán, hệ thống],
    [Vòng lặp luân phiên giữa hai bên, quyền chấp nhận đổi chủ sau mỗi lượt, và hai mốc thời gian lồng nhau (12 giờ và 30 phút).],

    [Thanh toán ký quỹ và sinh đơn hàng],
    [Người mua, hệ thống, nhà cung cấp thanh toán],
    [Quy trình quyết định dòng tiền; có một tác nhân ngoài, một mốc hết hạn, và một bước chiếm quyền phải xảy ra *trước* khi tiền được thu.],

    [Người bán xác nhận đơn],
    [Người bán, hệ thống, bộ phận vận hành],
    [Bước duy nhất mà người bán còn quyền dừng giao dịch, và là nơi dễ hiểu sai nhất: hết hạn không dẫn tới huỷ tự động.],

    [Trả hàng và hoàn tiền],
    [Người mua, người bán, hệ thống, bộ phận vận hành],
    [Quy trình nhiều nhánh nhất, hai cửa sổ 48 giờ nối tiếp, và một nhánh leo thang sinh ra phiếu hỗ trợ do bộ phận vận hành phân xử.],

    [Xác minh danh tính],
    [Người dùng, hệ thống, nhà cung cấp xác minh, điều phối viên],
    [Có hai đường ra khác nhau tuỳ nhà cung cấp kết luận được ngay hay không, và là điều kiện chặn của hai quyền quan trọng: đăng bán và rút tiền.],
  )
)

Ký hiệu dùng thống nhất trong cả sáu sơ đồ: hình viên thuốc là điểm bắt đầu hoặc kết
thúc, hình chữ nhật là một hoạt động, hình thoi là một điểm quyết định, khối viền đứt là
một nhánh kết thúc bất thường, khối nền xám là một hoạt động làm thay đổi dòng tiền hoặc
trạng thái công bố. Các cột dọc là làn trách nhiệm: mọi hoạt động nằm trong một làn đều
do tác nhân ghi ở đầu làn thực hiện.

Kỳ vọng khối lượng của cả sáu quy trình lấy từ cùng bộ ngưỡng ở mục yêu cầu phi chức năng
chứ không được phát biểu lại tại từng sơ đồ: mức tải trung bình là 10 phiên đồng thời và
mức tải đỉnh là 50 phiên trên một nút (NFR-07), với thông lượng tối thiểu 800 tới 1200 yêu
cầu mỗi giây trên các đường đọc (NFR-05). Riêng hàng đợi kiểm duyệt không đo bằng những con
số đó, vì thông lượng của nó bị chặn bởi số điều phối viên chứ không bởi tài nguyên máy.

*Ghi chú thẩm định.* Cách thẩm định được dùng ở đây là đối chiếu ngược từng phép chuyển của
sáu quy trình và hai sơ đồ trạng thái với phần đã hiện thực, rồi soát cùng giảng viên hướng
dẫn theo lịch báo cáo tuần; đây là hình thức thẩm định khả thi trong khuôn khổ một đề tài
thực tập chưa có người dùng thật. Hai điểm được sửa nhờ lượt soát đó: mốc bốn mươi tám giờ
của người bán ban đầu được mô tả là dẫn tới huỷ đơn tự động, và trạng thái "đang phân xử"
cùng "đang trả hàng" ban đầu được đặt hạn chót. Cả hai đều đã được sửa theo hành vi đúng và
được ghi lại ở chú giải tương ứng. Điều còn thiếu, và được ghi ra thay vì bỏ qua, là một lượt
thẩm định với người dùng cuối thật: nó chưa diễn ra, nên các quy trình dưới đây đúng với thứ
hệ thống làm chứ chưa được chứng minh là khớp với thứ người dùng mong đợi.

=== Sơ đồ hoạt động: Đăng bán tin và kiểm duyệt

#fig(
  [Sơ đồ hoạt động quy trình đăng bán tin và kiểm duyệt thủ công],
  spacing: (44mm, 11mm),
  ncore((0, 0), [NGƯỜI BÁN]),
  ncore((1, 0), [HỆ THỐNG]),
  ncore((2, 0), [ĐIỀU PHỐI VIÊN]),

  nt((0, 1), [Bắt đầu]),
  edge((0, 1), (0, 2), "-|>"),
  np((0, 2), [Soạn tin: ảnh, mô tả,\ danh mục, chế độ giá,\ biến thể và tồn]),
  edge((0, 2), (1, 3), "-|>"),
  nd((1, 3), [Đủ điều kiện\ đăng bán?]),
  edge((1, 3), (0, 4), "-|>", text(size: 8pt)[Không], label-side: left),
  nr((0, 4), [Nhận lý do: chưa xác minh\ danh tính hoặc chưa có\ địa chỉ lấy hàng]),
  edge((0, 4), (0, 2), "-|>", bend: 45deg, text(size: 8pt)[bổ sung rồi gửi lại]),
  edge((1, 3), (1, 5), "-|>", text(size: 8pt)[Có]),
  np((1, 5), [Chốt ảnh địa chỉ lấy hàng,\ xếp tin vào hàng đợi duyệt\ theo thứ tự gửi]),
  edge((1, 5), (2, 6), "-|>"),
  np((2, 6), [Đối chiếu tin với\ chính sách hàng cấm]),
  edge((2, 6), (2, 7), "-|>"),
  nd((2, 7), [Đạt chính sách?]),
  edge((2, 7), (1, 8), "-|>", text(size: 8pt)[Có], label-side: left),
  ng((1, 8), [Công bố tin, đánh dấu\ cần sinh lại vector nhúng]),
  edge((2, 7), (2, 8), "-|>", text(size: 8pt)[Không]),
  ng((2, 8), [Từ chối kèm lý do\ hoặc gỡ tin, ghi\ nhật ký quyết định]),
  edge((1, 8), (1, 9), "-|>"),
  edge((2, 8), (1, 9), "-|>"),
  nt((1, 9), [Kết thúc]),
)

#note[*Chú giải quy trình.* Dữ liệu vào của bước soạn tin là tập ảnh đã tải lên, danh mục
chọn từ cây danh mục và ít nhất một biến thể kèm số lượng tồn; dữ liệu ra là một tin ở
trạng thái chờ duyệt. Không có bước quét nội dung tự động nào trong quy trình này: *mọi*
tin công bố đều vào hàng đợi của người, xếp theo thứ tự gửi chứ không theo điểm rủi ro, nên
thông lượng kiểm duyệt bị chặn bởi số điều phối viên chứ không bởi tài nguyên máy. Một tin
đang hiển thị được sửa cũng đi lại đúng nhánh này: bản sửa được giữ riêng và chỉ thay thế
nội dung đang hiển thị khi được duyệt, nên nội dung công khai không bao giờ đổi giữa hai
lần duyệt. Đây là điểm nghẽn đã biết của quy trình và là căn cứ cho yêu cầu về hàng đợi
kiểm duyệt ở mục sau. *Quy tắc chi phối các điểm quyết định:* BR-07, BR-10, BR-11, BR-12,
BR-13.]

=== Sơ đồ hoạt động: Thương lượng giá

#fig(
  [Sơ đồ hoạt động quy trình thương lượng giá trên tin ở chế độ thương lượng],
  spacing: (44mm, 11mm),
  ncore((0, 0), [NGƯỜI MUA]),
  ncore((1, 0), [HỆ THỐNG]),
  ncore((2, 0), [NGƯỜI BÁN]),

  nt((0, 1), [Bắt đầu]),
  edge((0, 1), (0, 2), "-|>"),
  np((0, 2), [Đưa mức giá đề xuất\ cho một biến thể]),
  edge((0, 2), (1, 3), "-|>"),
  nd((1, 3), [Tin cho phép\ thương lượng?]),
  edge((1, 3), (0, 4), "-|>", text(size: 8pt)[Không], label-side: left),
  nr((0, 4), [Bị từ chối: tin giá cố định,\ chỉ mua theo giá niêm yết]),
  edge((1, 3), (1, 5), "-|>", text(size: 8pt)[Có]),
  np((1, 5), [Ghi đề xuất, hẹn hạn 12 giờ,\ đăng tin nhắn hệ thống\ vào luồng trao đổi]),
  edge((1, 5), (2, 6), "-|>"),
  nd((2, 6), [Bên không giữ đề xuất\ phản hồi thế nào?]),
  edge((2, 6), (2, 7), "-|>", text(size: 8pt)[Trả giá ngược]),
  np((2, 7), [Đưa mức giá mới,\ lượt đổi sang bên còn lại]),
  edge((2, 7), (1, 5), "-|>", bend: 42deg),
  edge((2, 6), (1, 7), "-|>", text(size: 8pt)[Không phản hồi], label-side: left),
  nr((1, 7), [Hết 12 giờ:\ đề xuất mất hiệu lực]),
  edge((2, 6), (1, 8), "-|>", text(size: 8pt)[Chấp nhận], label-side: right),
  ng((1, 8), [Đóng băng điều khoản\ trong 30 phút]),
  edge((1, 8), (0, 9), "-|>"),
  nd((0, 9), [Người mua mở thanh toán\ kịp 30 phút?]),
  edge((0, 9), (1, 10), "-|>", text(size: 8pt)[Có], label-side: right),
  ng((1, 10), [Chuyển sang quy trình\ thanh toán ký quỹ]),
  edge((0, 9), (0, 10), "-|>", text(size: 8pt)[Không]),
  nr((0, 10), [Chấp nhận hết hạn,\ hai bên thương lượng lại]),
  nt((1, 11), [Kết thúc]),
  edge((1, 10), (1, 11), "-|>"),
  edge((0, 10), (1, 11), "-|>"),
  edge((1, 7), (1, 11), "-|>", bend: -35deg),
  edge((0, 4), (1, 11), "-|>", bend: -50deg),
)

#note[*Chú giải quy trình.* Thương lượng là một *đường mua thêm*, không phải đường bắt
buộc: giá niêm yết của một tin ở chế độ thương lượng vẫn mua thẳng được, và chế độ giá chỉ
quyết định đúng một việc là tin đó có chấp nhận bị trả giá hay không. Hai bên luân phiên
giữ đề xuất; quyền chấp nhận luôn thuộc về bên *không* đang giữ đề xuất hiện hành, nên
người bán cũng chấp nhận được. Chấp nhận chưa phải là bán: nó chỉ đóng băng điều khoản
trong 30 phút, và chính lần thanh toán của người mua mới tạo ra giao dịch — đó là điều
khiến việc người bán chấp nhận trở nên vô hại, vì chưa có đơn và chưa có đồng nào bị thu.
Hai mốc thời gian lồng nhau: 12 giờ cho một đề xuất đang chờ, 30 phút cho điều khoản đã
chấp nhận. Luồng trao đổi chỉ mang một tin nhắn hệ thống trỏ về đề xuất, không sao chép
mức giá, để một lần trả giá ngược không để lại trong hội thoại một mức giá đã hết hiệu lực.
*Quy tắc chi phối các điểm quyết định:* BR-14, BR-16, BR-17, BR-18, BR-19, BR-20.]

=== Sơ đồ hoạt động: Thanh toán ký quỹ và sinh đơn hàng

#fig(
  [Sơ đồ hoạt động quy trình thanh toán ký quỹ và sinh đơn hàng],
  spacing: (44mm, 11mm),
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
  edge((1, 4), (0, 4), "-|>", text(size: 8pt)[Không], label-side: left),
  nr((0, 4), [Báo không giao được\ tới địa chỉ này]),
  edge((1, 4), (0, 5), "-|>", text(size: 8pt)[Có]),
  np((0, 5), [Chọn hãng vận chuyển\ và phương thức trả tiền]),
  edge((0, 5), (1, 6), "-|>"),
  np((1, 6), [Chiếm quyền dùng bản chốt\ giá hoặc đề xuất đã chấp nhận,\ rồi mở phiên 15 phút]),
  edge((1, 6), (0, 7), "-|>"),
  np((0, 7), [Trả tiền trên trang\ của nhà cung cấp]),
  edge((0, 7), (2, 8), "-|>"),
  np((2, 8), [Thu tiền và gọi lại\ kết quả cho sàn]),
  edge((2, 8), (1, 9), "-|>"),
  nd((1, 9), [Nhận báo đã trả\ trong 15 phút?]),
  edge((1, 9), (0, 10), "-|>", text(size: 8pt)[Không], label-side: left),
  nr((0, 10), [Phiên hết hạn, quyền dùng\ bản chốt giá được trả lại]),
  edge((1, 9), (1, 10), "-|>", text(size: 8pt)[Có]),
  ng((1, 10), [Giữ tiền hàng vào ký quỹ,\ phí vận chuyển thành\ một chặng riêng]),
  edge((1, 10), (1, 11), "-|>"),
  ng((1, 11), [Sinh đơn hàng ở trạng thái\ chờ người bán xác nhận,\ khởi động đồng hồ 48 giờ]),
  edge((1, 11), (1, 12), "-|>"),
  nt((1, 12), [Kết thúc]),
  edge((0, 10), (1, 12), "-|>", bend: -30deg),
  edge((0, 4), (1, 12), "-|>", bend: -55deg),
)

#note[*Chú giải quy trình.* Ba đặc điểm của quy trình này quyết định phần lớn tính đúng
đắn của dòng tiền. *Thứ nhất*, phí giao hàng luôn do người mua trả và được hỏi từ hãng vận
chuyển ngay tại bước thanh toán, nên một khách hàng không thể tự khai cước phí và một người
bán chưa có địa chỉ lấy hàng bị phát hiện *trước* khi tiền được thu; hãng nào không báo giá
được thì bị loại khỏi danh sách chọn, không có bảng phí dự phòng. *Thứ hai*, quyền dùng bản
chốt giá hoặc đề xuất đã chấp nhận được chiếm *trước* khi phiên thanh toán mở ra, nên hai
lần nhấn liên tiếp chỉ mở được một phiên và lần sau bị từ chối; nếu làm ngược lại thì cả
hai phiên đều mở và một lần bán có hai lần thu tiền. *Thứ ba*, trang mà người trả tiền được
chuyển tới sau khi thanh toán không phải bằng chứng — chỉ thông báo gọi lại của nhà cung
cấp mới quyết định phiên có thành công hay không, và một thông báo bị gửi lại lần hai không
tạo thêm bút toán. Ràng buộc thời gian: phiên thanh toán sống 15 phút, và bản chốt giá mà nó
tiêu đi cũng chỉ sống 30 phút. Đơn hàng và *bản ghi kiện hàng* ra đời ngay khi tiền vào ký
quỹ, chứ không chờ người bán duyệt; nhưng vận đơn thì chưa — hãng vận chuyển chỉ được gọi
sau khi người bán xác nhận, nên bản ghi kiện hàng lúc này còn rỗng mã vận đơn. *Quy tắc chi
phối các điểm quyết định:* BR-21, BR-22, BR-23, BR-24, BR-25, BR-26, BR-56.]

=== Sơ đồ hoạt động: Người bán xác nhận đơn hàng

#fig(
  [Sơ đồ hoạt động quy trình người bán xác nhận đơn hàng đã thanh toán],
  spacing: (44mm, 11mm),
  ncore((0, 0), [NGƯỜI BÁN]),
  ncore((1, 0), [HỆ THỐNG]),
  ncore((2, 0), [BỘ PHẬN VẬN HÀNH]),

  nt((1, 1), [Bắt đầu — tiền\ đã ở ký quỹ]),
  edge((1, 1), (1, 2), "-|>"),
  np((1, 2), [Xếp đơn vào danh sách chờ\ xác nhận, đếm 48 giờ]),
  edge((1, 2), (0, 3), "-|>"),
  nd((0, 3), [Người bán\ quyết định gì?]),
  edge((0, 3), (1, 4), "-|>", text(size: 8pt)[Từ chối, nêu lý do], label-side: right),
  ng((1, 4), [Huỷ đơn, hoàn cả tiền hàng\ lẫn phí vận chuyển]),
  edge((0, 3), (2, 4), "-|>", text(size: 8pt)[Quá 48 giờ]),
  np((2, 4), [Nhận cảnh báo\ đơn quá hạn xác nhận]),
  edge((2, 4), (2, 5), "-|>"),
  np((2, 5), [Liên hệ giục người bán;\ đơn giữ nguyên trạng thái]),
  edge((2, 5), (0, 3), "-|>", bend: 45deg),
  edge((0, 3), (1, 6), "-|>", text(size: 8pt)[Xác nhận]),
  np((1, 6), [Đặt vận đơn với hãng\ người mua đã chọn]),
  edge((1, 6), (0, 7), "-|>"),
  np((0, 7), [Bàn giao kiện hàng\ cho hãng vận chuyển]),
  edge((0, 7), (1, 8), "-|>"),
  np((1, 8), [Cập nhật mốc hành trình\ theo báo của hãng,\ chỉ tiến không lùi]),
  edge((1, 8), (1, 9), "-|>"),
  nt((1, 9), [Kết thúc — chuyển sang\ bước xác nhận nhận hàng]),
  edge((1, 4), (1, 9), "-|>", bend: -45deg),
)

#note[*Chú giải quy trình.* Người bán vẫn có một bước xác nhận, nhưng bước đó nằm *sau*
tiền chứ không phải trước: khi người bán mở danh sách chờ, đơn hàng đã tồn tại và tiền đã
nằm trong ký quỹ. Đây là điểm dễ hiểu sai nhất của quy trình, vì hết 48 giờ hệ thống *không*
tự huỷ đơn và *không* tự hoàn tiền — nó chỉ báo cho bộ phận vận hành đi giục, còn đơn vẫn
chờ. Lý do là nền tảng không thể vừa huỷ một giao dịch hợp lệ thay người bán, vừa gửi hàng
thay họ; việc duy nhất còn lại là để người can thiệp. Từ chối thì bắt buộc phải nêu lý do,
và vì kiện hàng chưa rời kho nên người mua được hoàn cả tiền hàng lẫn phí vận chuyển. Vận
đơn chỉ được đặt với hãng *sau* khi đơn được xác nhận; nếu hãng chưa nhận, việc đặt lại là
một tác vụ chạy nền chứ không phải lý do từ chối đơn. *Quy tắc chi phối các điểm quyết
định:* BR-27, BR-28, BR-29, BR-30, BR-31.]

=== Sơ đồ hoạt động: Trả hàng, hoàn tiền và leo thang thành phiếu hỗ trợ

#fig(
  [Sơ đồ hoạt động quy trình trả hàng, hoàn tiền và nhánh leo thang phân xử],
  spacing: (37mm, 10.5mm),
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
  edge((2, 4), (1, 5), "-|>", text(size: 8pt)[Chấp nhận], label-side: left),
  np((1, 5), [Mở chặng trả hàng,\ không tính phí]),
  edge((1, 5), (0, 6), "-|>"),
  np((0, 6), [Gửi hàng trả lại]),
  edge((0, 6), (2, 7), "-|>"),
  np((2, 7), [Xác nhận đã nhận hàng,\ bắt đầu 48 giờ kiểm hàng]),
  edge((2, 7), (2, 8), "-|>"),
  nd((2, 8), [Kết luận kiểm hàng?]),
  edge((2, 8), (1, 9), "-|>", text(size: 8pt)[Đồng ý hoặc hết 48 giờ], label-side: left),
  ng((1, 9), [Hoàn tiền hàng cho người mua;\ phí vận chuyển đã dùng\ không được hoàn]),
  edge((2, 4), (1, 10), "-|>", text(size: 8pt)[Nhờ phân xử\ hoặc im lặng hết hạn], label-side: right),
  edge((2, 8), (1, 10), "-|>", text(size: 8pt)[Phản đối hàng trả về], label-side: right),
  edge((0, 6), (1, 10), "-|>", text(size: 8pt)[người mua tự khai đã trả], label-side: left, bend: -20deg),
  np((1, 10), [Chuyển hồ sơ sang phân xử,\ mở phiếu hỗ trợ gắn với hồ sơ]),
  edge((1, 10), (3, 11), "-|>"),
  np((3, 11), [Đối soát bằng chứng hai phía\ qua luồng trao đổi của phiếu]),
  edge((3, 11), (3, 12), "-|>"),
  nd((3, 12), [Phán quyết?]),
  edge((3, 12), (1, 13), "-|>", text(size: 8pt)[Người mua thắng], label-side: left),
  ng((1, 13), [Hoàn tiền hàng\ cho người mua]),
  edge((3, 12), (3, 13), "-|>", text(size: 8pt)[Người bán thắng]),
  ng((3, 13), [Hồ sơ bị bác;\ tiền tiếp tục về người bán]),
  edge((1, 13), (1, 14), "-|>"),
  edge((3, 13), (1, 14), "-|>"),
  np((1, 14), [Đóng mọi phiếu hỗ trợ đang mở\ về hồ sơ, ghi phán quyết\ vào luồng trao đổi]),
  edge((1, 14), (1, 15), "-|>"),
  nt((1, 15), [Kết thúc]),
  edge((1, 9), (1, 15), "-|>", bend: -55deg),
)

#note[*Chú giải quy trình.* Bốn quy tắc định hình quy trình này. Một, người bán chỉ có hai
nước đi: chấp nhận cho trả hàng, hoặc nhờ sàn phân xử — không có nút từ chối, vì lời từ
chối của một bên không thể là phán quyết trong tranh chấp của chính bên đó. Hai, im lặng
hết 48 giờ có cùng hệ quả với nhờ phân xử, chứ không phải là mặc nhiên đồng ý cũng không
phải mặc nhiên bác bỏ: sự im lặng của người bán không phải một phán quyết. Ba, người mua
*không bao giờ* là bên leo thang; họ đã mở hồ sơ một lần, bắt họ mở lần thứ hai chính là
bước làm mất tiền của bên vốn đã chịu thiệt. Bốn, không có thực thể tranh chấp riêng: mọi
hồ sơ leo thang trở thành một phiếu hỗ trợ trong cùng một bảng phiếu phục vụ mọi loại yêu
cầu người dùng gửi lên, và phán quyết đóng mọi phiếu đang mở về hồ sơ đó — cả hai bên đều
có quyền mở phiếu, nên một phán quyết chỉ đóng một phiếu sẽ để lại phiếu còn lại mở vĩnh
viễn. Phiếu ấy đến từ hai đường và đó là điều dễ đọc nhầm nhất ở sơ đồ: hệ thống tự mở phiếu
ngay khi hồ sơ leo thang, còn người dùng vẫn gửi được một phiếu cùng loại của riêng mình, và
chính hành động gửi đó cũng leo thang hồ sơ trước khi phiếu được ghi. Hai cửa sổ 48 giờ nối
tiếp nhau: cửa sổ người bán xem xét và cửa sổ người bán kiểm hàng đã trả về. Hoàn tiền luôn
là toàn phần đối với tiền hàng, nhưng cước vận chuyển đã thực sự phát sinh thì không được
hoàn. *Quy tắc chi phối các điểm quyết định:* BR-27,
BR-37, BR-38, BR-39, BR-40, BR-41, BR-42, BR-43, BR-50.]

=== Sơ đồ hoạt động: Xác minh danh tính

#fig(
  [Sơ đồ hoạt động quy trình xác minh danh tính người dùng],
  spacing: (37mm, 11mm),
  ncore((0, 0), [NGƯỜI DÙNG]),
  ncore((1, 0), [HỆ THỐNG]),
  ncore((2, 0), [NHÀ CUNG CẤP\ XÁC MINH]),
  ncore((3, 0), [ĐIỀU PHỐI VIÊN]),

  nt((0, 1), [Bắt đầu]),
  edge((0, 1), (0, 2), "-|>"),
  np((0, 2), [Nộp ảnh giấy tờ\ và thông tin định danh]),
  edge((0, 2), (1, 3), "-|>"),
  np((1, 3), [Ghi hồ sơ ở trạng thái chờ,\ chuyển sang nhà cung cấp]),
  edge((1, 3), (2, 4), "-|>"),
  np((2, 4), [Đọc giấy tờ, trả kết luận\ hoặc trả liên kết phiên\ xác minh riêng]),
  edge((2, 4), (1, 5), "-|>"),
  nd((1, 5), [Có kết luận\ tự động?]),
  edge((1, 5), (3, 6), "-|>", text(size: 8pt)[Không]),
  np((3, 6), [Đối chiếu ảnh giấy tờ\ trong hàng đợi duyệt]),
  edge((3, 6), (1, 7), "-|>"),
  edge((1, 5), (1, 7), "-|>", text(size: 8pt)[Có]),
  nd((1, 7), [Kết quả?]),
  edge((1, 7), (0, 8), "-|>", text(size: 8pt)[Không đạt], label-side: left),
  nr((0, 8), [Nhận lý do,\ nộp lại hồ sơ]),
  edge((0, 8), (0, 2), "-|>", bend: 50deg),
  edge((1, 7), (1, 8), "-|>", text(size: 8pt)[Đạt]),
  ng((1, 8), [Đánh dấu tài khoản đã xác minh:\ mở quyền đăng bán và rút tiền]),
  edge((1, 8), (1, 9), "-|>"),
  nt((1, 9), [Kết thúc]),
)

#note[*Chú giải quy trình.* Điểm đáng chú ý là hai đường ra hợp lại thành một: dù kết luận
đến từ nhà cung cấp hay từ điều phối viên, hồ sơ vẫn đi qua đúng một tập quy tắc chuyển
trạng thái, nên một kết luận máy không thể bỏ qua ràng buộc mà một kết luận người phải tuân
thủ. Sự khác nhau giữa các nhà cung cấp — bên đọc ảnh và trả lời ngay, bên chạy phiên xác
minh riêng rồi báo về sau — được giấu sau một ranh giới chung, phía gọi chỉ lưu kết quả nào
quay về. Xác minh danh tính là điều kiện chặn của cả đăng bán lẫn rút tiền, nên đây là quy
trình nằm trên đường tới hạn của một người bán mới. *Quy tắc chi phối các điểm quyết định:*
BR-07, BR-08.]

=== Sơ đồ trạng thái vòng đời đơn hàng

Đơn hàng có bốn trạng thái, và cả bốn đều được *suy ra* từ các mốc thời gian kết quả chứ
không lưu thành một trường trạng thái riêng — nhờ vậy không tồn tại khả năng trường trạng
thái lệch với các mốc thời gian sinh ra nó. Sơ đồ dưới đây là hợp đồng mà tầng nghiệp vụ
phải tuân thủ: mọi phép chuyển không xuất hiện trên sơ đồ đều bị từ chối.

#fig(
  [Sơ đồ trạng thái vòng đời đơn hàng],
  spacing: (52mm, 14mm),
  nt((0, 0), [Khởi tạo]),
  edge((0, 0), (0, 1), "-|>", text(size: 7.5pt)[phiên thanh toán hoàn tất —\ tiền vào ký quỹ]),
  np((0, 1), [CHỜ NGƯỜI BÁN\ XÁC NHẬN]),
  edge((0, 1), (0, 1), "-|>", bend: 130deg,
    text(size: 7.5pt)[quá 48 giờ: cảnh báo bộ phận vận hành —\ trạng thái không đổi]),
  edge((0, 1), (1.35, 1), "-|>", text(size: 7.5pt)[người bán từ chối kèm lý do —\ hoàn tiền hàng và phí vận chuyển]),
  ng((1.35, 1), [ĐÃ HUỶ]),
  edge((0, 1), (0, 2), "-|>", text(size: 7.5pt)[người bán xác nhận —\ vận đơn được đặt với hãng]),
  np((0, 2), [ĐANG MỞ]),
  edge((0, 2), (1.35, 1), "-|>", stroke: (dash: "dashed"), bend: -22deg,
    text(size: 7.5pt)[hồ sơ hoàn tiền được chấp thuận\ hoặc phán quyết cho người mua]),
  edge((0, 2), (0, 3), "-|>",
    text(size: 7.5pt)[người mua xác nhận nhận hàng, qua 72 giờ\ mà không có hồ sơ hoàn tiền đang mở — giải ngân]),
  ng((0, 3), [HOÀN THÀNH]),
  edge((0, 3), (0.7, 4), "-|>"),
  edge((1.35, 1), (0.7, 4), "-|>", bend: -30deg),
  nt((0.7, 4), [Kết thúc]),
)

#note[*Chú giải trạng thái.* Không tồn tại trạng thái "đang tranh chấp" của đơn hàng: tranh
chấp là trạng thái của *hồ sơ hoàn tiền*, và đơn hàng chỉ nhận hệ quả cuối cùng của nó. Vòng
lặp tại trạng thái chờ xác nhận là điểm đáng chú ý nhất của sơ đồ — hết 48 giờ, hệ thống ghi
một dấu mốc đã cảnh báo và chuyển việc cho người, chứ không chuyển trạng thái. Đồng hồ 72
giờ chỉ khởi động khi *người mua chủ động* xác nhận đã nhận hàng kèm bằng chứng; hệ thống
không suy ra việc nhận hàng từ thông báo của hãng vận chuyển và không có cơ chế tự động xác
nhận hộ, nên một đơn không được xác nhận sẽ nằm ở trạng thái đang mở thay vì tự giải ngân.
*Quy tắc chi phối các phép chuyển:* BR-22, BR-28, BR-29, BR-32, BR-34, BR-37.]

=== Sơ đồ trạng thái vòng đời yêu cầu hoàn tiền

#fig(
  [Sơ đồ trạng thái vòng đời yêu cầu hoàn tiền],
  spacing: (48mm, 15mm),
  nt((0, 0), [Khởi tạo]),
  edge((0, 0), (0, 1), "-|>", text(size: 7.5pt)[người mua mở hồ sơ\ kèm lý do và bằng chứng]),
  np((0, 1), [CHỜ NGƯỜI BÁN\ XEM XÉT\ (hạn 48 giờ)]),
  edge((0, 1), (-1.25, 1), "-|>", text(size: 7.5pt)[người mua\ rút hồ sơ], label-side: left),
  ng((-1.25, 1), [ĐÃ RÚT]),
  edge((0, 1), (0, 2), "-|>", text(size: 7.5pt)[người bán chấp nhận cho trả hàng]),
  np((0, 2), [ĐANG TRẢ HÀNG]),
  edge((0, 1), (1.35, 2), "-|>", text(size: 7.5pt)[người bán nhờ phân xử,\ hoặc im lặng hết 48 giờ], label-side: right),
  np((1.35, 2), [ĐANG PHÂN XỬ]),
  edge((0, 2), (1.35, 2), "-|>", text(size: 7.5pt)[người mua tự khai\ đã trả hàng]),
  edge((0, 2), (0, 3), "-|>", text(size: 7.5pt)[người bán xác nhận đã nhận hàng]),
  np((0, 3), [ĐÃ TRẢ VỀ\ (hạn kiểm hàng 48 giờ)]),
  edge((0, 3), (1.35, 2), "-|>", stroke: (dash: "dashed"), bend: 38deg,
    text(size: 7.5pt)[người bán phản đối\ hàng trả về], label-side: right),
  edge((0, 3), (0, 4), "-|>", text(size: 7.5pt)[hết 48 giờ kiểm hàng mà người bán không phản đối]),
  ng((0, 4), [ĐƯỢC CHẤP THUẬN]),
  edge((1.35, 2), (0, 2), "-|>", stroke: (dash: "dashed"), bend: 28deg,
    text(size: 7.5pt)[phán quyết cho người mua\ khi hàng chưa trả về]),
  edge((1.35, 2), (0, 4), "-|>", stroke: (dash: "dashed"),
    text(size: 7.5pt)[phán quyết cho người mua\ khi hàng đã trả về]),
  edge((1.35, 2), (1.35, 4), "-|>", text(size: 7.5pt)[phán quyết\ cho người bán]),
  ng((1.35, 4), [BỊ TỪ CHỐI]),
)

#note[*Chú giải trạng thái.* Bảy trạng thái, ba trong đó là kết thúc: được chấp thuận, bị từ
chối và đã rút. Việc tách "đã rút" thành một kết thúc riêng thay vì xếp chung với "bị từ
chối" là có chủ đích — một người mua tự rút hồ sơ và một người bán thắng cuộc là hai câu
chuyện khác nhau về uy tín, gộp lại thì không còn phân biệt được. Bốn trạng thái không kết
thúc đều được đặt tên theo *bên đang bị chờ*, nên câu hỏi "ai đang giữ hồ sơ này" trả lời
được ngay từ trạng thái. Chỉ hai trong bốn trạng thái đó có hạn chót: chờ người bán xem xét
và đã trả về, mỗi bên bốn mươi tám giờ. Hai trạng thái còn lại cố ý không có hạn: đang phân
xử thì chờ một con người ra phán quyết, còn đang trả hàng thì chờ một hãng vận chuyển, và
không thứ nào trong hai thứ đó là điều một chiếc đồng hồ nên tự quyết định thay. Nếu đặt hạn
cho chúng, hệ thống sẽ tự kết luận một vụ việc mà nó không có căn cứ để kết luận.
Việc người mua tự khai đã trả hàng đi thẳng sang phân xử chứ không mở cửa sổ
kiểm hàng của người bán: nếu không, chỉ cần một lời khai cộng với 48 giờ người bán không đọc
thông báo là người mua giữ được cả tiền lẫn hàng, mà chặng trả hàng lại không được đặt với
hãng nào nên không có bên thứ ba nào phản bác được lời khai đó. *Quy tắc chi phối các phép
chuyển:* BR-38, BR-39, BR-40, BR-41, BR-42, BR-43.]

== Mô hình dữ liệu ý niệm

Mục này trả lời câu hỏi *hệ thống phải nhớ những gì*, ở mức ý niệm: thực thể nghiệp vụ,
quan hệ giữa chúng và lực lượng của các quan hệ đó. Đây chưa phải mô hình vật lý — kiểu dữ
liệu, chỉ mục, ràng buộc khoá và câu lệnh định nghĩa bảng thuộc về chương thiết kế hệ
thống. Nguyên tắc phân biệt được áp dụng nhất quán: một khái niệm chỉ trở thành thực thể
khi nó *tồn tại độc lập* và *có vòng đời riêng*; ngược lại nó là thuộc tính của thực thể
khác. Chẳng hạn tên hiển thị của người dùng là thuộc tính chứ không phải thực thể, vì nó
bắt buộc phải có, luôn được đọc cùng tài khoản và không bao giờ được sửa một mình; còn địa
chỉ lấy hàng là thực thể riêng, vì một tài khoản có nhiều địa chỉ, mỗi loại có một địa chỉ
mặc định riêng, và quy tắc "một mặc định cho mỗi loại" là một quy tắc chỉ trải trên tập địa
chỉ chứ không đụng tới tài khoản.

Hai mươi lăm thực thể được nhận diện từ các ca sử dụng và sáu quy trình vừa mô hình hóa.
Vì số lượng lớn, mô hình được tách thành hai lát cắt theo cụm nghiệp vụ; hai thực thể xuất
hiện ở cả hai lát cắt — *tài khoản* và *tệp đính kèm* — chính là điểm nối logic giữa chúng.
Lực lượng được ghi bằng nhãn chữ đặt trên đường nối chứ không bằng ký hiệu chân quạ, vì nhãn
chữ đọc được ở cỡ chữ của trang in trong khi ba gạch chân quạ ở cùng cỡ đó thì không: `1-1`
là một-một, `n-1` là nhiều-một bắt buộc, `n-n` là nhiều-nhiều, và dấu chấm hỏi đánh dấu phía
tuỳ chọn, ví dụ `n-1?` đọc là "nhiều bản ghi phía này, tối đa một bản ghi phía kia". Mô hình
chỉ còn đúng một quan hệ nhiều-nhiều, và nó được phân giải ở bảng danh mục quan hệ ngay sau
đây chứ không bằng một thực thể trung gian, vì phía kia của nó có lực lượng cố định bằng hai.
Hộp thực thể chỉ mang tên, còn định danh và các thuộc tính then chốt nằm ở bảng danh mục
ngay sau hai hình. Cách trình bày đó là có chủ ý: hai lát cắt này có hai mươi lăm hộp, và
nhét bốn dòng thuộc tính vào mỗi hộp sẽ làm hình mất hẳn giá trị vốn có của nó là cho thấy
hình dạng các quan hệ.

#fig(
  [Mô hình thực thể ý niệm — cụm người dùng, tin đăng và trao đổi],
  spacing: (30mm, 13mm),
  edge-stroke: 1pt + blue-s,
  nent((0, 0), <u-acc>, [TÀI KHOẢN]),
  nent((0, 1.2), <u-ctc>, [ĐỊA CHỈ LIÊN HỆ]),
  nent((0, 2.4), <u-idn>, [GIẤY TỜ ĐỊNH DANH]),
  nent((1.55, 0), <u-cat>, [DANH MỤC]),
  nent((1.55, 1.2), <u-lst>, [TIN ĐĂNG]),
  nent((1.55, 2.4), <u-var>, [PHIÊN BẢN SẢN PHẨM]),
  nent((1.55, 3.6), <u-stk>, [TỒN KHO]),
  nent((3.1, 0), <u-cnv>, [HỘI THOẠI]),
  nent((3.1, 1.2), <u-msg>, [TIN NHẮN]),
  nent((3.1, 2.4), <u-tkt>, [PHIẾU HỖ TRỢ]),
  nent((3.1, 3.6), <u-res>, [TỆP ĐÍNH KÈM]),
  edge(<u-ctc>, <u-acc>, "n-1", text(size: 7.5pt)[sổ địa chỉ]),
  edge(<u-idn>, <u-acc>, "n-1", text(size: 7.5pt)[hồ sơ xác minh]),
  edge(<u-lst>, <u-acc>, "n-1", text(size: 7.5pt)[người bán]),
  edge(<u-lst>, <u-cat>, "n-1", text(size: 7.5pt)[thuộc danh mục]),
  edge(<u-cat>, <u-cat>, "n-1?", bend: 130deg, text(size: 7pt)[danh mục cha]),
  edge(<u-var>, <u-lst>, "n-1", text(size: 7.5pt)[phiên bản]),
  edge(<u-stk>, <u-var>, "1-1", text(size: 7.5pt)[tồn kho]),
  edge(<u-cnv>, <u-acc>, "n-n", bend: 24deg, text(size: 7.5pt)[đúng hai bên tham gia]),
  edge(<u-msg>, <u-cnv>, "n-1", text(size: 7.5pt)[thuộc hội thoại]),
  edge(<u-tkt>, <u-acc>, "n-1", text(size: 7.5pt)[người gửi]),
  edge(<u-tkt>, <u-cnv>, "1-1?", text(size: 7.5pt)[hội thoại của phiếu]),
  edge(<u-res>, <u-lst>, "n-1?", text(size: 7.5pt)[ảnh tin đăng]),
  edge(<u-res>, <u-msg>, "n-1?", text(size: 7.5pt)[tệp gửi kèm]),
)

#fig(
  [Mô hình thực thể ý niệm — cụm đơn hàng, dòng tiền và tín nhiệm],
  spacing: (30mm, 12mm),
  edge-stroke: 1pt + blue-s,
  nent((0, 0), <o-drf>, [PHIẾU MUA TẠM]),
  nent((0, 1.15), <o-off>, [THƯƠNG LƯỢNG GIÁ]),
  nent((0, 2.3), <o-pay>, [PHIÊN THANH TOÁN]),
  nent((0, 3.45), <o-tx>, [BÚT TOÁN THANH TOÁN]),
  nent((1.5, 0.4), <o-itm>, [DÒNG HÀNG]),
  nent((1.5, 1.6), <o-ord>, [ĐƠN HÀNG]),
  nent((1.5, 2.8), <o-trp>, [KIỆN HÀNG]),
  nent((1.5, 4.0), <o-ref>, [HỒ SƠ HOÀN TIỀN]),
  nent((2.95, 0.4), <o-fbk>, [ĐÁNH GIÁ GIAO DỊCH]),
  nent((2.95, 1.6), <o-rvw>, [NHẬN XÉT SẢN PHẨM]),
  nent((2.95, 2.8), <o-acc>, [TÀI KHOẢN]),
  nent((2.95, 4.0), <o-rep>, [ĐIỂM UY TÍN]),
  nent((4.4, 1.6), <o-wal>, [VÍ]),
  nent((4.4, 2.8), <o-wtx>, [BÚT TOÁN VÍ]),
  nent((4.4, 4.0), <o-wdr>, [YÊU CẦU RÚT TIỀN]),
  edge(<o-itm>, <o-drf>, "n-1?", text(size: 7.5pt)[chốt từ phiếu mua tạm]),
  edge(<o-itm>, <o-off>, "1-1?", text(size: 7.5pt)[chốt từ thương lượng]),
  edge(<o-itm>, <o-pay>, "n-1", text(size: 7.5pt)[được trả trong]),
  edge(<o-itm>, <o-ord>, "n-1?", text(size: 7.5pt)[thuộc đơn]),
  edge(<o-tx>, <o-pay>, "n-1", text(size: 7.5pt)[chặng tiền của]),
  edge(<o-ord>, <o-trp>, "1-1", text(size: 7.5pt)[kiện giao đi]),
  edge(<o-ref>, <o-ord>, "n-1", text(size: 7.5pt)[khiếu nại về đơn]),
  edge(<o-ref>, <o-trp>, "1-1?", text(size: 7.5pt)[chặng trả hàng]),
  edge(<o-ord>, <o-acc>, "n-1", bend: 18deg, text(size: 7.5pt)[người mua và người bán]),
  edge(<o-fbk>, <o-ord>, "n-1", text(size: 7.5pt)[đánh giá giao dịch]),
  edge(<o-rvw>, <o-ord>, "n-1", text(size: 7.5pt)[nhận xét sản phẩm]),
  edge(<o-rep>, <o-acc>, "n-1", text(size: 7.5pt)[điểm uy tín theo vai]),
  edge(<o-wal>, <o-acc>, "1-1", text(size: 7.5pt)[ví]),
  edge(<o-wtx>, <o-wal>, "n-1", text(size: 7.5pt)[biến động số dư]),
  edge(<o-wdr>, <o-wal>, "n-1", text(size: 7.5pt)[yêu cầu rút]),
)

=== Danh mục thực thể

#figure(
  kind: table,
  caption: [Danh mục thực thể ý niệm, định danh và thuộc tính then chốt],
  table(
    columns: (1.15fr, 0.62fr, 1.75fr, 2.35fr),
    align: (left + top, center + top, left + top, left + top),
    table.header([Thực thể], [Loại], [Định danh và thuộc tính then chốt], [Vai trò nghiệp vụ — dịch vụ chủ quản]),

    [Tài khoản], [Cốt lõi], [Mã tài khoản; tên đăng nhập, tên hiển thị, vai trò, trạng thái khoá, cờ đã xác minh danh tính], [Một chủ thể vừa mua vừa bán; vai trò quyết định quyền vận hành — dịch vụ tài khoản],
    [Địa chỉ liên hệ], [Cốt lõi], [Mã địa chỉ; loại địa chỉ, người nhận, số điện thoại, mã hành chính, cờ mặc định], [Tách riêng vì quy tắc một mặc định cho mỗi loại chỉ trải trên tập địa chỉ — dịch vụ tài khoản],
    [Giấy tờ định danh], [Cốt lõi], [Mã hồ sơ; loại giấy tờ, ngày hết hạn, trạng thái, lý do từ chối, các ảnh đã gửi], [Điều kiện chặn của quyền đăng bán và quyền rút tiền — dịch vụ tài khoản],
    [Danh mục], [Tham chiếu], [Mã danh mục; tên, danh mục cha], [Cây phân loại tự tham chiếu; một tin đăng thuộc đúng một danh mục lá — dịch vụ danh mục],
    [Tin đăng], [Cốt lõi], [Mã tin; tên, mô tả, chế độ giá, trạng thái công bố, ảnh địa chỉ lấy hàng, bản sửa chờ duyệt], [Đơn vị được tìm kiếm và kiểm duyệt — dịch vụ danh mục],
    [Phiên bản sản phẩm], [Cốt lõi], [Mã phiên bản; tổ hợp thuộc tính, giá niêm yết], [Đơn vị thực sự được mua và được thương lượng — dịch vụ danh mục],
    [Tồn kho], [Liên kết], [Mã phiên bản; tổng số, số đang giữ, số đã bán], [Ba bộ đếm tách bạch, không bộ nào được âm; số còn lại là hiệu của chúng chứ không được lưu — dịch vụ danh mục],
    [Tệp đính kèm], [Cốt lõi], [Mã tệp; nhà cung cấp lưu trữ, khoá đối tượng, kiểu nội dung, kích thước], [Ảnh tin đăng, tệp trong tin nhắn và bằng chứng khiếu nại đều là thực thể này — mỗi dịch vụ tự quản kho tệp của mình chứ không có một dịch vụ nhận tệp dùng chung],
    [Hội thoại], [Cốt lõi], [Mã hội thoại; loại, hai bên tham gia, dấu đã đọc của mỗi bên], [Một hội thoại cho mỗi cặp tài khoản, cộng một hội thoại cho mỗi phiếu hỗ trợ — dịch vụ trò chuyện],
    [Tin nhắn], [Cốt lõi], [Mã tin nhắn; người gửi, nội dung, thời điểm, dữ liệu kèm theo], [Cũng là nơi mang tin nhắn hệ thống trỏ về một thương lượng — dịch vụ trò chuyện],
    [Phiếu hỗ trợ], [Cốt lõi], [Mã phiếu; loại, đối tượng bị nhắc tới, lý do, trạng thái, kết luận xử lý], [Một bảng duy nhất cho mọi loại yêu cầu người dùng gửi lên — dịch vụ tín nhiệm],
    [Phiếu mua tạm], [Cốt lõi], [Mã phiếu; danh sách phiên bản và số lượng, giá đã đóng băng, thời điểm hết hạn], [Đóng băng giá niêm yết trong ba mươi phút để thanh toán diễn ra trên một mức giá cố định — dịch vụ đơn hàng],
    [Thương lượng giá], [Cốt lõi], [Mã thương lượng; phiên bản, mức giá hiện hành, bên đang giữ đề xuất, trạng thái, hạn hiệu lực], [Giữ điều khoản và trạng thái luân phiên; hội thoại chỉ trỏ tới nó — dịch vụ đơn hàng],
    [Dòng hàng], [Liên kết], [Mã dòng; phiên bản, số lượng, đơn giá đã chốt, phí giao hàng], [Nối một lần mua với đơn hàng và phiên thanh toán sinh ra nó — dịch vụ đơn hàng],
    [Đơn hàng], [Cốt lõi], [Mã đơn; người mua, người bán, ảnh hai địa chỉ, các mốc xác nhận, nhận hàng, hoàn tất, huỷ], [Bốn trạng thái suy ra từ các mốc thời gian, không lưu trường trạng thái — dịch vụ đơn hàng],
    [Kiện hàng], [Cốt lõi], [Mã kiện; hãng vận chuyển, mã vận đơn của hãng, trạng thái hành trình, phí], [Dùng cho cả chặng giao đi lẫn chặng trả hàng — dịch vụ đơn hàng],
    [Hồ sơ hoàn tiền], [Cốt lõi], [Mã hồ sơ; lý do, bằng chứng, trạng thái, hạn hiện hành, mốc người bán quyết, mốc hàng về], [Bảy trạng thái, hai cửa sổ bốn mươi tám giờ — dịch vụ đơn hàng],
    [Phiên thanh toán], [Cốt lõi], [Mã phiên; loại, tổng tiền, tuỳ chọn thanh toán, trạng thái, hạn mười lăm phút], [Ranh giới giữa tiền của người mua và sổ sách của sàn — dịch vụ tài chính],
    [Bút toán thanh toán], [Cốt lõi], [Mã bút toán; chặng, số tiền, tuỳ chọn thanh toán, tham chiếu của nhà cung cấp], [Sổ cái đối ngoại, ghi từng chặng tiền qua cổng thanh toán — dịch vụ tài chính],
    [Ví], [Cốt lõi], [Mã ví; chủ ví, đơn vị tiền, số dư khả dụng, số dư đang giữ], [Hai loại số dư tách bạch; ký quỹ nằm ở phần đang giữ — dịch vụ tài chính],
    [Bút toán ví], [Cốt lõi], [Mã bút toán; số thứ tự trong ví, biến động, số dư sau, lý do], [Sổ cái nội bộ chỉ-thêm-mới, ghi số dư sau mỗi biến động — dịch vụ tài chính],
    [Yêu cầu rút tiền], [Cốt lõi], [Mã yêu cầu; số tiền, tài khoản ngân hàng nhận, trạng thái duyệt], [Trừ ví ngay khi tạo, hoàn lại khi bị từ chối — dịch vụ tài chính],
    [Đánh giá giao dịch], [Cốt lõi], [Mã đánh giá; đơn hàng, chiều đánh giá, số sao, nhận xét, mốc công bố], [Ẩn cho tới khi cả hai bên gửi hoặc hết mười bốn ngày — dịch vụ tín nhiệm],
    [Nhận xét sản phẩm], [Cốt lõi], [Mã nhận xét; tin đăng, số sao, nội dung, phản hồi của người bán, số lượt bình chọn hữu ích], [Đếm tách rời với đánh giá giao dịch — dịch vụ tín nhiệm],
    [Điểm uy tín], [Liên kết], [Mã tài khoản cộng vai (mua hay bán); tổng sao và số lượt của hai loại đánh giá, số đơn hoàn tất, số đơn bị huỷ], [Một bản ghi cho mỗi vai, nên uy tín bán không lẫn với uy tín mua; không có công thức điểm tổng hợp, trung bình được tính khi đọc — dịch vụ tín nhiệm],
  )
)

=== Danh mục quan hệ

#figure(
  kind: table,
  caption: [Danh mục quan hệ ý niệm, lực lượng và ràng buộc nghiệp vụ],
  table(
    columns: (1.05fr, 1.05fr, 0.95fr, 0.7fr, 2.35fr),
    align: (left + top, left + top, left + top, center + horizon, left + top),
    table.header([Thực thể A], [Thực thể B], [Tên quan hệ], [Lực lượng], [Ràng buộc nghiệp vụ]),
    [Địa chỉ liên hệ], [Tài khoản], [Sổ địa chỉ], [N : 1], [Mỗi loại địa chỉ có tối đa một bản ghi mặc định trong cùng một sổ (BR-57).],
    [Tin đăng], [Tài khoản], [Người bán], [N : 1], [Chỉ tài khoản đã xác minh danh tính mới xuất hiện ở phía một (BR-07).],
    [Phiên bản sản phẩm], [Tin đăng], [Phiên bản], [N : 1], [Một tin bắt buộc có ít nhất một phiên bản; phiên bản là đơn vị được mua (BR-15).],
    [Tồn kho], [Phiên bản sản phẩm], [Tồn kho], [1 : 1], [Ba bộ đếm tổng số, đang giữ và đã bán không bao giờ âm, và phần đang giữ cộng phần đã bán không vượt tổng số; số còn lại là hiệu (BR-15).],
    [Danh mục], [Danh mục], [Danh mục cha], [N : 0..1], [Cây tự tham chiếu, không được phép có chu trình.],
    [Hội thoại], [Tài khoản], [Hai bên tham gia], [N : 2], [Quan hệ nhiều-nhiều này không cần thực thể trung gian vì phía kia có lực lượng cố định bằng hai: hội thoại giữ thẳng hai bên tham gia dưới dạng một cặp có thứ tự, nên "tối đa một hội thoại trực tiếp cho mỗi cặp" là một ràng buộc trên chính bản ghi hội thoại (BR-58).],
    [Phiếu hỗ trợ], [Hội thoại], [Hội thoại của phiếu], [1 : 0..1], [Phiếu là bên chủ; hội thoại có thể mở sau, và được mở lại ở lần đọc kế tiếp nếu lần đầu thất bại (BR-45).],
    [Phiếu hỗ trợ], [Tài khoản], [Người gửi], [N : 1], [Một người gửi chỉ có một phiếu đang mở về cùng một đối tượng (BR-48).],
    [Dòng hàng], [Phiếu mua tạm], [Chốt từ phiếu mua tạm], [N : 0..1], [Một phiếu mua tạm gồm nhiều mục nên sinh ra nhiều dòng hàng, nhưng vẫn chỉ sinh ra đúng một đơn hàng (BR-24, BR-56).],
    [Dòng hàng], [Thương lượng giá], [Chốt từ thương lượng], [1 : 0..1], [Một thương lượng chỉ trải trên một phiên bản sản phẩm nên sinh ra đúng một dòng hàng. Đúng một trong hai nguồn gốc phải có mặt, không được có cả hai (BR-24).],
    [Dòng hàng], [Đơn hàng], [Thuộc đơn], [N : 0..1], [Dòng hàng tồn tại từ lúc thanh toán; đơn hàng chỉ ra đời khi cổng thanh toán báo về (BR-22).],
    [Bút toán thanh toán], [Phiên thanh toán], [Chặng tiền của], [N : 1], [Một phiên gồm nhiều chặng: tiền hàng, phí giao hàng, và chặng hoàn nếu có (BR-26).],
    [Đơn hàng], [Kiện hàng], [Kiện giao đi], [1 : 1], [Bản ghi kiện hàng ra đời cùng đơn, ngay khi tiền vào ký quỹ; vận đơn thì chỉ được đặt với hãng sau khi người bán xác nhận, nên một kiện chưa có mã vận đơn là một kiện chưa đặt (BR-28, BR-30).],
    [Hồ sơ hoàn tiền], [Đơn hàng], [Khiếu nại về đơn], [N : 1], [Một đơn có thể có nhiều hồ sơ theo thời gian nhưng tối đa một hồ sơ đang sống (BR-37).],
    [Hồ sơ hoàn tiền], [Kiện hàng], [Chặng trả hàng], [1 : 0..1], [Chặng trả hàng có phí bằng không và không được đặt với hãng vận chuyển nào (BR-42).],
    [Đánh giá giao dịch], [Đơn hàng], [Đánh giá], [N : 1], [Tối đa hai bản ghi cho mỗi đơn, mỗi bên một chiều, chiều được suy ra chứ không do người dùng khai (BR-51).],
    [Nhận xét sản phẩm], [Đơn hàng], [Nhận xét], [N : 1], [Chỉ người đã mua mới viết được, và được đếm tách rời với đánh giá giao dịch (BR-52, BR-53).],
    [Ví], [Tài khoản], [Ví], [1 : 1], [Số dư khả dụng và số dư đang giữ tách bạch, không số dư nào được âm (BR-35).],
    [Bút toán ví], [Ví], [Biến động số dư], [N : 1], [Sổ chỉ-thêm-mới; số thứ tự trong một ví là duy nhất. Tính liên tục của dãy số ấy là hệ quả của việc cấp số và ghi bút toán nằm trong cùng một giao dịch, không phải một ràng buộc được khai báo (BR-35).],
    [Yêu cầu rút tiền], [Ví], [Yêu cầu rút], [N : 1], [Chỉ rút được phần khả dụng, và số tiền bị trừ ngay khi yêu cầu được tạo (BR-36).],
    [Điểm uy tín], [Tài khoản], [Điểm uy tín], [N : 1], [Tối đa hai bản ghi cho mỗi tài khoản, một cho vai người bán và một cho vai người mua, vì uy tín bán và uy tín mua là hai câu chuyện khác nhau; nhận xét sản phẩm chỉ được đếm vào bản ghi vai người bán. Bản ghi của một tài khoản chưa ai đánh giá là các số không, không phải là không tồn tại.],
  )
)

#note[*Giả định và điểm còn để mở của mô hình.* Ba giả định được ghi lại để chương thiết kế
đối chiếu. *Một*, mô hình này giả định tồn kho thuộc về cụm tin đăng chứ không phải một cụm
riêng: một phiên bản sản phẩm và bộ đếm tồn của nó luôn được đọc cùng nhau và không bao giờ
được sửa một mình, nên tách ra chỉ tạo thêm một phép ghép. *Hai*, thực thể *kiện hàng* phục
vụ cả chặng giao đi lẫn chặng trả hàng vì hai chặng có cùng thuộc tính và cùng vòng đời;
điều phân biệt chúng là bên nào tham chiếu tới, chứ không phải một trường loại. *Ba*, không
tồn tại thực thể tranh chấp: hồ sơ hoàn tiền giữ trạng thái và số tiền, còn phiếu hỗ trợ giữ
phần trao đổi với sàn, nên hai thứ vốn từng bị gộp làm một nay có hai vòng đời tách bạch.
Điểm còn để mở là bảng quan tâm dùng cho gợi ý cá nhân hóa: mô hình đọc đã có, nhưng chưa
xác định được nguồn ghi dữ liệu tương tác, nên thực thể đó chưa được đưa vào mô hình chính
thức.]

== Yêu cầu chức năng

=== Nguyên tắc đặc tả

Mỗi yêu cầu chức năng được viết theo cấu trúc nguyên tử *"Hệ thống phải + hành động + đối
tượng + điều kiện hoặc tiêu chí"*, và phải giữ được bốn tính chất: *rõ nghĩa*, tức chỉ có
một cách hiểu; *kiểm chứng được*, tức gắn được một tiêu chí chấp nhận; *nguyên tử*, tức mô
tả một hành vi chứ không gộp nhiều hành vi bằng liên từ; và *độc lập với thiết kế*, tức nói
hệ thống làm gì chứ không nói làm bằng cách nào. Bốn tính chất này loại bỏ hai kiểu phát
biểu thường gặp: phát biểu định tính không đo được, và phát biểu thực chất là một quyết
định thiết kế được viết dưới dạng yêu cầu.

Năm mươi yêu cầu được trích xuất có hệ thống từ luồng chính, luồng thay thế và luồng
ngoại lệ của ba mươi hai ca sử dụng ở mục trước, nên mỗi yêu cầu đều truy vết được về ca
sử dụng nguồn. Con số này cao hơn khung tham chiếu mười lăm tới ba mươi yêu cầu mà một quy
trình phân tích chuẩn khuyến nghị; lý do là phạm vi ở đây trải trên bảy dịch vụ độc lập —
tài khoản, danh mục, đơn hàng, tài chính, trò chuyện, tín nhiệm và quan trắc — và việc hạ
số lượng xuống trong khung đó chỉ có thể đạt được bằng cách gộp nhiều hành vi vào một phát
biểu, tức là đánh đổi chính tính nguyên tử vừa nêu. Mức ưu tiên dùng thang ba bậc: *Bắt
buộc* là điều kiện để hệ thống chạy được một giao dịch trọn vẹn, *Nên có* là phần làm cho
hệ thống dùng được trong thực tế, *Có thể lùi* là phần không chặn bất kỳ luồng nào khác.

Cột cuối cùng nối mỗi yêu cầu về các quy tắc nghiệp vụ ràng buộc nó, để năm mươi tám quy tắc
ở mục trước không dừng lại ở một danh sách mà thực sự chạm được vào tầng yêu cầu. Ô để trống
là ô không có quy tắc nào chi phối, chứ không phải ô chưa tra: các yêu cầu về tìm kiếm, về
gợi ý điền tin đăng và về quan trắc thuộc loại đó, vì chúng bị ràng buộc bởi ngưỡng chất
lượng ở mục sau chứ không bởi một luật nghiệp vụ. Cũng như bộ mã quy tắc, mã yêu cầu được cấp
theo thứ tự bổ sung và không bao giờ được đánh số lại, nên bốn yêu cầu thêm vào ở lượt rà
soát cuối nằm trong nhóm chức năng của mình nhưng mang mã cao hơn các yêu cầu bên cạnh.

=== Danh mục yêu cầu chức năng

#figure(
  kind: table,
  caption: [Danh mục yêu cầu chức năng của hệ thống ShopNexus],
  table(
    columns: (0.4fr, 3.05fr, 0.7fr, 0.85fr, 0.85fr, 0.55fr),
    align: (center + horizon, left + top, left + top, left + top, left + top, center + horizon),
    table.header([Mã], [Phát biểu — "Hệ thống phải…"], [UC nguồn], [Dịch vụ], [Quy tắc], [Ư. tiên]),

    table.cell(colspan: 6, align: left)[*Nhóm 1 — Định danh, phiên làm việc và phân quyền*],
    [REQ-01], [khởi tạo một tài khoản mới ở vai trò người dùng từ tên đăng nhập, mật khẩu và tên hiển thị.], [UC-01], [tài khoản], [BR-02], [Bắt buộc],
    [REQ-02], [băm mật khẩu một chiều trước khi lưu, và không ghi mật khẩu nguyên bản vào bất kỳ bản ghi hay nhật ký nào.], [UC-01], [tài khoản], [BR-05], [Bắt buộc],
    [REQ-03], [mở một phiên đăng nhập và cấp một thẻ truy cập có thời hạn khi thông tin xác thực hợp lệ, kể cả khi người dùng vào bằng thẻ định danh liên kết.], [UC-01, UC-02], [tài khoản], [BR-06], [Bắt buộc],
    [REQ-04], [tra cứu phiên đăng nhập tương ứng ở mọi yêu cầu đã xác thực, và từ chối thẻ truy cập thuộc một phiên đã bị thu hồi.], [UC-02], [tài khoản], [BR-06], [Bắt buộc],
    [REQ-05], [kiểm tra vai trò của người gọi tại tầng dịch vụ trước mọi thao tác quản trị và kiểm duyệt.], [UC-02, UC-05], [cả bảy], [BR-01, BR-04], [Bắt buộc],
    [REQ-06], [cho phép người dùng sửa thông tin hiển thị, quản lý sổ địa chỉ với một địa chỉ mặc định cho mỗi loại, và đăng ký thiết bị nhận thông báo.], [UC-04], [tài khoản], [BR-57], [Nên có],
    [REQ-50], [thu hồi phiên đăng nhập hiện tại khi người dùng đăng xuất, và thu hồi mọi phiên còn lại của tài khoản khi mật khẩu đổi hoặc khi tài khoản bị khoá.], [UC-02], [tài khoản], [BR-06], [Bắt buộc],

    table.cell(colspan: 6, align: left)[*Nhóm 2 — Xác minh danh tính*],
    [REQ-07], [tiếp nhận hồ sơ giấy tờ tuỳ thân, chuyển sang nhà cung cấp xác minh, và đưa hồ sơ chưa có kết luận tự động vào hàng đợi duyệt của điều phối viên.], [UC-03, UC-27], [tài khoản], [BR-08], [Bắt buộc],
    [REQ-08], [từ chối tạo tin đăng và từ chối yêu cầu rút tiền của tài khoản chưa được xác minh danh tính.], [UC-03], [tài khoản, danh mục, tài chính], [BR-07], [Bắt buộc],

    table.cell(colspan: 6, align: left)[*Nhóm 3 — Tin đăng và kiểm duyệt*],
    [REQ-09], [cho phép người bán soạn tin đăng gồm ảnh, tên, mô tả, danh mục, chế độ giá và ít nhất một phiên bản sản phẩm kèm số lượng tồn.], [UC-06], [danh mục], [BR-14, BR-15], [Bắt buộc],
    [REQ-10], [từ chối công bố tin đăng khi người bán chưa khai báo địa chỉ lấy hàng, và chụp lại địa chỉ đó vào tin ngay tại thời điểm công bố.], [UC-06], [danh mục, tài khoản], [BR-11], [Bắt buộc],
    [REQ-11], [giữ mọi tin đăng mới công bố và mọi bản sửa của tin đang hiển thị ở trạng thái chờ duyệt theo thứ tự gửi, và không hiển thị chúng công khai trước khi được duyệt.], [UC-06, UC-08, UC-25], [danh mục], [BR-10, BR-12], [Bắt buộc],
    [REQ-12], [cho phép điều phối viên duyệt, từ chối kèm lý do hoặc gỡ một tin đăng, và phân biệt tin bị gỡ với tin do chính người bán ẩn đi.], [UC-25], [danh mục], [BR-13, BR-49], [Bắt buộc],
    [REQ-13], [sinh một biểu mẫu tin đăng điền sẵn từ ảnh và ghi chú của người bán, mà không tạo bất kỳ bản ghi nghiệp vụ nào.], [UC-07], [danh mục], [—], [Có thể lùi],

    table.cell(colspan: 6, align: left)[*Nhóm 4 — Tìm kiếm, duyệt và quan tâm*],
    [REQ-14], [trả kết quả tìm kiếm theo từ khoá tự nhiên, kết hợp đối sánh chuỗi với đối sánh ngữ nghĩa khi tin đăng đã có vector nhúng.], [UC-09], [danh mục], [—], [Bắt buộc],
    [REQ-15], [cho phép lọc kết quả theo danh mục, khoảng giá, tình trạng và khoảng cách, và sắp xếp theo mới nhất, giá, lượt bán hoặc điểm đánh giá.], [UC-09], [danh mục], [—], [Bắt buộc],
    [REQ-16], [đánh dấu tin đăng, danh mục và thẻ là cần sinh lại vector nhúng mỗi khi phần nội dung mô tả của chúng thay đổi.], [UC-06, UC-08], [danh mục], [—], [Nên có],
    [REQ-17], [cho phép người mua theo dõi một người bán và đánh dấu một tin đăng để xem lại về sau.], [UC-10], [danh mục, tài khoản], [—], [Có thể lùi],

    table.cell(colspan: 6, align: left)[*Nhóm 5 — Hội thoại và thương lượng giá*],
    [REQ-18], [duy trì đúng một hội thoại trực tiếp cho mỗi cặp tài khoản, và đẩy tin nhắn mới tới thiết bị đang kết nối.], [UC-11], [trò chuyện], [BR-58], [Bắt buộc],
    [REQ-19], [cho phép người mua mở thương lượng và hai bên luân phiên đưa đề xuất trên tin ở chế độ thương lượng, và từ chối mọi đề xuất nhắm vào tin giá cố định.], [UC-12], [đơn hàng, danh mục], [BR-14, BR-16, BR-19, BR-20], [Bắt buộc],
    [REQ-20], [cho phép bên không đang giữ đề xuất hiện hành chấp thuận điều khoản, đóng băng mức giá đó trong ba mươi phút mà không thu bất kỳ khoản nào.], [UC-12], [đơn hàng], [BR-16, BR-18], [Bắt buộc],
    [REQ-21], [đánh dấu hết hiệu lực cho đề xuất không được phản hồi trong mười hai giờ, và cho điều khoản đã chấp thuận không được tạo đơn trong ba mươi phút.], [UC-12], [đơn hàng], [BR-17, BR-18], [Bắt buộc],

    table.cell(colspan: 6, align: left)[*Nhóm 6 — Đặt hàng và thanh toán ký quỹ*],
    [REQ-22], [lập một phiếu mua tạm đóng băng giá niêm yết trong ba mươi phút từ các mục người mua đã chọn.], [UC-13], [đơn hàng], [BR-56], [Bắt buộc],
    [REQ-23], [hỏi giá vận chuyển từ mọi hãng đang bật cho một phiếu mua tạm hoặc một thương lượng đã chấp thuận, và loại khỏi danh sách chọn hãng nào không báo giá được.], [UC-13], [đơn hàng], [BR-25, BR-54], [Bắt buộc],
    [REQ-24], [giành quyền dùng phiếu mua tạm hoặc thương lượng đã chấp thuận trước khi mở phiên thanh toán mười lăm phút, và trả lại quyền đó khi phiên hết hạn.], [UC-14], [đơn hàng, tài chính], [BR-23, BR-24], [Bắt buộc],
    [REQ-25], [chỉ ghi nhận kết quả thanh toán từ thông báo gọi lại của nhà cung cấp, và không phát sinh bút toán mới khi cùng một thông báo được gửi lại.], [UC-14], [tài chính], [BR-22], [Bắt buộc],
    [REQ-26], [giữ tiền hàng vào ký quỹ, tách phí giao hàng thành một chặng riêng, rồi tạo đơn hàng và bản ghi kiện hàng ở trạng thái chờ người bán xác nhận.], [UC-14, UC-15], [tài chính, đơn hàng], [BR-21, BR-26], [Bắt buộc],

    table.cell(colspan: 6, align: left)[*Nhóm 7 — Vòng đời đơn hàng và giải ngân*],
    [REQ-27], [cho phép người bán xác nhận đơn trong bốn mươi tám giờ, và chỉ đặt vận đơn với hãng sau khi đơn đã được xác nhận.], [UC-15], [đơn hàng], [BR-28, BR-30], [Bắt buộc],
    [REQ-28], [cho phép người bán từ chối đơn kèm lý do bắt buộc, hoàn cho người mua cả tiền hàng lẫn phí giao hàng, và trả lại tồn kho.], [UC-15], [đơn hàng, tài chính, danh mục], [BR-27, BR-29], [Bắt buộc],
    [REQ-29], [cảnh báo bộ phận vận hành khi hết bốn mươi tám giờ mà đơn chưa được xác nhận, và giữ nguyên trạng thái của đơn.], [UC-15], [đơn hàng, tín nhiệm], [BR-28], [Nên có],
    [REQ-30], [cập nhật mốc hành trình của kiện hàng theo thông báo của hãng, bỏ qua mốc lùi và mốc không thuộc từ vựng hệ thống.], [UC-16], [đơn hàng], [BR-31], [Bắt buộc],
    [REQ-31], [bắt buộc người mua đính kèm ít nhất một tệp bằng chứng khi xác nhận đã nhận hàng.], [UC-17], [đơn hàng], [BR-33], [Bắt buộc],
    [REQ-32], [chuyển tiền hàng từ ký quỹ sang số dư khả dụng của người bán sau bảy mươi hai giờ kể từ khi người mua xác nhận nhận hàng, nếu không có hồ sơ hoàn tiền nào đang sống.], [UC-17], [đơn hàng, tài chính], [BR-32, BR-34], [Bắt buộc],

    table.cell(colspan: 6, align: left)[*Nhóm 8 — Trả hàng, hoàn tiền và phiếu hỗ trợ*],
    [REQ-33], [cho phép người mua mở hồ sơ hoàn tiền kèm lý do và bằng chứng vào bất kỳ lúc nào trước khi đơn kết thúc, và loại đơn đó khỏi danh sách chờ giải ngân.], [UC-19], [đơn hàng], [BR-37], [Bắt buộc],
    [REQ-34], [giới hạn nước đi của người bán trong bốn mươi tám giờ ở hai lựa chọn là chấp nhận cho trả hàng hoặc chuyển hồ sơ cho sàn, và tự chuyển hồ sơ lên sàn khi hết hạn.], [UC-20], [đơn hàng], [BR-39, BR-40], [Bắt buộc],
    [REQ-35], [mở chặng trả hàng với phí bằng không khi hồ sơ được chấp nhận, mở bốn mươi tám giờ kiểm hàng khi người bán xác nhận đã nhận hàng về, và hoàn tiền hàng cho người mua khi hết cửa sổ đó.], [UC-20], [đơn hàng, tài chính], [BR-38, BR-42], [Bắt buộc],
    [REQ-36], [cho phép điều phối viên ra phán quyết với đúng hai kết cục cho một hồ sơ đang chờ phân xử, và đóng mọi phiếu hỗ trợ đang mở nhắm vào hồ sơ đó.], [UC-26], [đơn hàng, tín nhiệm], [BR-41, BR-43, BR-50], [Bắt buộc],
    [REQ-37], [tiếp nhận mọi loại yêu cầu người dùng gửi lên dưới dạng một phiếu hỗ trợ có hội thoại riêng với bàn hỗ trợ, và ẩn danh tính cá nhân của người trả lời với người gửi.], [UC-23, UC-24], [tín nhiệm, trò chuyện], [BR-03, BR-44, BR-45, BR-46, BR-47, BR-48], [Bắt buộc],
    [REQ-48], [cho phép người mua rút hồ sơ hoàn tiền của mình khi người bán chưa trả lời, đưa hồ sơ về một trạng thái kết thúc riêng khác với bị bác bỏ, và trả đơn về danh sách chờ giải ngân.], [UC-19], [đơn hàng], [BR-37], [Bắt buộc],

    table.cell(colspan: 6, align: left)[*Nhóm 9 — Đánh giá, uy tín và ví*],
    [REQ-38], [giữ đánh giá giao dịch ở dạng ẩn cho tới khi cả hai bên đã gửi hoặc hết mười bốn ngày, rồi công bố và cộng nó vào điểm uy tín trong cùng một giao dịch ghi.], [UC-21], [tín nhiệm], [BR-51, BR-52], [Nên có],
    [REQ-39], [cho phép người đã mua viết nhận xét sản phẩm, người bán phản hồi và người dùng bình chọn hữu ích, và đếm chúng tách rời với đánh giá giao dịch.], [UC-22], [tín nhiệm, danh mục], [BR-52, BR-53], [Có thể lùi],
    [REQ-40], [hiển thị số dư khả dụng, số dư đang giữ và sổ bút toán chỉ-thêm-mới của ví.], [UC-18], [tài chính], [BR-35], [Bắt buộc],
    [REQ-41], [cho phép rút phần số dư khả dụng về tài khoản ngân hàng đã đăng ký, trừ ví ngay khi yêu cầu được tạo và hoàn lại khi yêu cầu bị từ chối.], [UC-18, UC-29], [tài chính], [BR-07, BR-36], [Bắt buộc],
    [REQ-49], [cho phép quản trị viên ghi một bút toán điều chỉnh số dư bằng tay kèm lý do bắt buộc, theo đúng ràng buộc không âm và cùng đường ghi sổ như mọi biến động khác.], [UC-29], [tài chính], [BR-35, BR-55], [Nên có],

    table.cell(colspan: 6, align: left)[*Nhóm 10 — Quản trị, tệp đính kèm và vận hành*],
    [REQ-42], [cho phép duy nhất quản trị viên cấp phát và thu hồi tài khoản điều phối viên.], [UC-05], [tài khoản], [BR-04], [Bắt buộc],
    [REQ-43], [cho phép quản trị viên bật, tắt hoặc đổi nhà cung cấp phục vụ cho từng dòng của sổ tuỳ chọn, và giữ dòng đã tắt ở dạng đọc được cho các bản ghi cũ tham chiếu tới nó.], [UC-28], [tài chính, đơn hàng], [BR-54], [Nên có],
    [REQ-47], [cho phép quản trị viên tạo, đổi tên và sắp lại cây danh mục sản phẩm, từ chối một phép sắp lại tạo ra chu trình, và từ chối xoá một danh mục đang có tin đăng.], [UC-28], [danh mục], [—], [Nên có],
    [REQ-44], [cấp một đường tải lên có chữ ký cho mỗi tệp, và chỉ gắn tệp vào nghiệp vụ gọi tới sau khi người dùng xác nhận đã tải xong.], [UC-S1], [mọi dịch vụ có nghiệp vụ nhận tệp], [—], [Bắt buộc],
    [REQ-45], [ghi một bản ghi kiểm toán chỉ-thêm-mới trong cùng giao dịch cơ sở dữ liệu với mỗi quyết định nghiệp vụ và mỗi biến động tiền.], [UC-S2], [cả bảy], [BR-55], [Bắt buộc],
    [REQ-46], [thu thập bốn tín hiệu vận hành gồm lưu lượng vào, lời gọi ra ngoài, sự kiện nghiệp vụ và số đo thời gian chạy, mà không làm chậm hay làm hỏng yêu cầu đang phục vụ.], [UC-30], [quan trắc], [—], [Nên có],
  )
)

Việc lập cột này trả lời được một câu hỏi mà bản thân danh sách quy tắc không trả lời được:
quy tắc nào chưa có yêu cầu nào thực thi. Kết quả là năm mươi bảy trên năm mươi tám quy tắc
có ít nhất một yêu cầu chi phối; quy tắc duy nhất còn lại là BR-09 về định danh dạng mờ, và
nó không thiếu chỗ mà nằm nhầm tầng — đó là một ràng buộc chất lượng chứ không phải một hành
vi nghiệp vụ, nên nó được nghiệm thu qua NFR-12. Chiều ngược lại cũng đáng ghi: BR-02, về
việc một tài khoản mang cả năng lực mua lẫn năng lực bán, được thực thi chủ yếu bằng sự vắng
mặt — trong cả bảng không có yêu cầu nào mở gian hàng, và đó chính là hình dạng của nó.

=== Tiêu chí chấp nhận của các yêu cầu trọng yếu

Tiêu chí chấp nhận được viết theo cấu trúc *Bối cảnh — Hành động — Kết quả mong đợi*, và
ưu tiên trường hợp lỗi hơn trường hợp thuận lợi: một tiêu chí chỉ mô tả đường đi suôn sẻ
không kiểm chứng được gì, vì phần lớn sai sót của một sàn giao dịch nằm ở các nhánh ngoại
lệ. Bốn mươi bốn trong năm mươi yêu cầu có tiêu chí chấp nhận ở bảng dưới. Sáu yêu cầu còn
lại — tìm kiếm theo từ khoá, lọc và sắp xếp, đánh dấu cần sinh lại vector nhúng, theo dõi và
lưu quan tâm, nhận xét sản phẩm, và thu thập tín hiệu quan trắc — được nghiệm thu bằng ngưỡng
đo ở mục yêu cầu phi chức năng chứ không bằng một tiêu chí hành vi, nên viết thêm một tiêu
chí cho chúng chỉ là chép lại phát biểu dưới một dạng khác.

#figure(
  kind: table,
  caption: [Tiêu chí chấp nhận của các yêu cầu chức năng trọng yếu],
  table(
    columns: (0.46fr, 2.05fr, 1.85fr, 2.3fr),
    align: (center + horizon, left + top, left + top, left + top),
    table.header([Mã], [Bối cảnh], [Hành động], [Kết quả mong đợi]),
    [REQ-01], [Một địa chỉ thư điện tử đã được một tài khoản khác dùng], [Gửi biểu mẫu đăng ký với đúng địa chỉ đó], [Hệ thống từ chối và nêu rõ địa chỉ đã được dùng; không tài khoản thứ hai nào được tạo],
    [REQ-02], [Một tài khoản vừa được tạo], [Đọc trực tiếp bản ghi tài khoản và toàn bộ nhật ký sinh ra trong lượt đăng ký], [Không nơi nào chứa chuỗi mật khẩu nguyên bản; trường mật khẩu là một chuỗi băm có muối],
    [REQ-03], [Người dùng nhập đúng tên đăng nhập nhưng sai mật khẩu], [Gửi yêu cầu đăng nhập], [Không phiên nào được mở, không thẻ nào được cấp, và thông báo lỗi không cho biết tên đăng nhập có tồn tại hay không],
    [REQ-04], [Người dùng đăng xuất trên một thiết bị nhưng thẻ truy cập cũ chưa hết hạn], [Gửi một yêu cầu đã xác thực bằng thẻ cũ đó], [Yêu cầu bị từ chối ngay, không phải chờ tới lúc thẻ hết hạn],
    [REQ-05], [Một tài khoản người dùng thường đã đăng nhập hợp lệ], [Gọi thẳng một chức năng kiểm duyệt tin đăng], [Bị từ chối ở tầng dịch vụ; kết quả không phụ thuộc vào việc yêu cầu đi qua cổng vào nào],
    [REQ-06], [Sổ địa chỉ đã có một địa chỉ giao hàng được đánh dấu mặc định], [Đánh dấu một địa chỉ giao hàng khác là mặc định], [Đúng một địa chỉ giao hàng mang dấu mặc định; dấu cũ được gỡ trong cùng một lần ghi],
    [REQ-07], [Nhà cung cấp xác minh trả về trạng thái chưa kết luận], [Hệ thống nhận phản hồi], [Hồ sơ nằm ở trạng thái chờ và xuất hiện trong hàng đợi duyệt của điều phối viên, không bị coi là đã đạt cũng không bị coi là bị từ chối],
    [REQ-08], [Người bán chưa nộp giấy tờ tuỳ thân], [Bấm tạo một tin đăng mới], [Hệ thống từ chối ngay ở bước tạo, nêu rõ điều kiện còn thiếu, và không bản nháp nào được ghi],
    [REQ-09], [Người bán khai một phiên bản sản phẩm với giá bằng không], [Lưu tin đăng], [Hệ thống từ chối và chỉ rõ trường sai; không phần nào của tin được ghi],
    [REQ-10], [Người bán chưa có địa chỉ lấy hàng nào trong sổ địa chỉ], [Bấm công bố một tin đăng đã soạn đủ trường], [Hệ thống từ chối và hướng người bán khai địa chỉ lấy hàng; tin vẫn ở dạng nháp],
    [REQ-11], [Một tin đang hiển thị được người bán sửa mô tả và giá], [Gửi bản sửa], [Bản đang hiển thị giữ nguyên cho người mua; bản sửa nằm chờ duyệt và chỉ thay thế nội dung khi được duyệt],
    [REQ-11], [Hàng đợi duyệt đang có ba tin gửi lần lượt lúc 9 giờ, 10 giờ và 11 giờ], [Điều phối viên mở hàng đợi], [Ba tin xuất hiện đúng theo thứ tự thời gian gửi, không có tin nào bị đẩy lên trước vì bất kỳ điểm rủi ro nào],
    [REQ-12], [Một tin đã bị điều phối viên gỡ], [Người bán bấm gửi lại chính tin đó], [Tin quay về hàng đợi chờ duyệt chứ không trở lại hiển thị; chỉ một lần duyệt của điều phối viên mới đưa nó ra công khai],
    [REQ-13], [Người bán tải ba ảnh và đọc một ghi chú không nhắc tới giá], [Yêu cầu gợi ý điền tin đăng], [Biểu mẫu trả về có tên và mô tả, trường giá để trống, và không có tin đăng hay bản nháp nào được tạo],
    [REQ-11], [Một tin đang hiển thị được người bán sửa mô tả và giá], [Gửi bản sửa], [Bản đang hiển thị giữ nguyên cho người mua; bản sửa nằm chờ duyệt và chỉ thay thế nội dung khi được duyệt],
    [REQ-11], [Hàng đợi duyệt đang có ba tin gửi lần lượt lúc 9 giờ, 10 giờ và 11 giờ], [Điều phối viên mở hàng đợi], [Ba tin xuất hiện đúng theo thứ tự thời gian gửi, không có tin nào bị đẩy lên trước vì bất kỳ điểm rủi ro nào],
    [REQ-13], [Người bán tải ba ảnh và đọc một ghi chú không nhắc tới giá], [Yêu cầu gợi ý điền tin đăng], [Biểu mẫu trả về có tên và mô tả, trường giá để trống, và không có tin đăng hay bản nháp nào được tạo],
    [REQ-18], [Hai tài khoản đã từng trao đổi với nhau], [Một trong hai bấm nhắn tin lần nữa từ một trang khác], [Hệ thống mở lại đúng hội thoại cũ kèm toàn bộ lịch sử, không tạo hội thoại thứ hai cho cùng cặp],
    [REQ-19], [Tin đăng ở chế độ giá cố định], [Người mua gửi một đề xuất giá], [Hệ thống từ chối và hướng người mua sang mua theo giá niêm yết],
    [REQ-20], [Người mua đang giữ đề xuất hiện hành], [Chính người mua bấm chấp thuận], [Hệ thống từ chối, vì quyền chấp thuận thuộc về bên không đang giữ đề xuất],
    [REQ-21], [Một điều khoản được chấp thuận cách đây ba mươi mốt phút], [Người mua bấm tạo đơn], [Hệ thống từ chối, không mở phiên thanh toán, và hai bên phải thương lượng lại],
    [REQ-22], [Một phiếu mua tạm được lập cách đây ba mươi mốt phút], [Người mua bấm thanh toán trên phiếu đó], [Hệ thống từ chối, trả lại phần tồn kho đang giữ và yêu cầu lập phiếu mới theo giá niêm yết hiện hành],
    [REQ-23], [Không hãng vận chuyển nào phục vụ được tuyến tới địa chỉ người mua chọn], [Xin báo giá vận chuyển], [Danh sách phương án trả về rỗng, hệ thống báo không giao được tới địa chỉ này, và không phiên thanh toán nào mở ra với một mức phí tự đoán],
    [REQ-24], [Người mua bấm nút thanh toán hai lần liên tiếp trên cùng một phiếu mua tạm], [Hai yêu cầu tới gần như đồng thời], [Đúng một phiên thanh toán được mở; yêu cầu còn lại bị từ chối vì phiếu đã bị giành],
    [REQ-25], [Cổng thanh toán gửi lại đúng thông báo đã xử lý trước đó], [Hệ thống nhận thông báo lần thứ hai], [Không bút toán nào được thêm, số dư ký quỹ không tăng gấp đôi, và hệ thống vẫn trả về mã thành công],
    [REQ-26], [Phiên thanh toán vừa được cổng báo là đã trả đủ], [Hệ thống xử lý thông báo], [Tiền hàng nằm ở phần số dư đang giữ, phí giao hàng là một chặng riêng, và đơn hàng xuất hiện ở trạng thái chờ người bán xác nhận],
    [REQ-27], [Một đơn vừa được thanh toán và người bán chưa xác nhận], [Đọc bản ghi kiện hàng của đơn], [Bản ghi kiện tồn tại nhưng chưa có mã vận đơn; hãng vận chuyển chưa hề được gọi],
    [REQ-27], [Người bán bấm xác nhận nhưng hãng vận chuyển không trả lời], [Hệ thống gọi đặt vận đơn], [Đơn vẫn được xác nhận và tiền vẫn nằm đúng chỗ; kiện hàng vào danh sách đặt lại và không đơn nào bị từ chối vì lý do này],
    [REQ-28], [Một đơn đã thanh toán, chưa xác nhận], [Người bán bấm từ chối mà không nhập lý do], [Hệ thống từ chối thao tác; đơn không bị huỷ và không khoản nào được hoàn cho tới khi có lý do],
    [REQ-29], [Một đơn đã thanh toán và người bán không thao tác gì suốt bốn mươi chín giờ], [Tác vụ định kỳ chạy], [Bộ phận vận hành nhận cảnh báo; đơn vẫn ở trạng thái chờ xác nhận, tiền vẫn nằm trong ký quỹ, không có khoản hoàn nào],
    [REQ-30], [Kiện hàng đã ở mốc đang giao], [Hãng vận chuyển báo về một mốc cũ hơn là đã lấy hàng], [Mốc bị bỏ qua; trạng thái hành trình giữ nguyên ở đang giao],
    [REQ-31], [Người mua mở màn hình xác nhận đã nhận hàng], [Bấm xác nhận mà không đính kèm tệp nào], [Hệ thống từ chối; đồng hồ bảy mươi hai giờ không khởi động và tiền vẫn nằm trong ký quỹ],
    [REQ-32], [Người mua đã xác nhận nhận hàng cách đây bảy mươi ba giờ và không mở hồ sơ hoàn tiền], [Tác vụ định kỳ chạy], [Toàn bộ tiền hàng chuyển sang số dư khả dụng của người bán, không bị trừ bất kỳ khoản nào],
    [REQ-32], [Người mua đã xác nhận nhận hàng và đang có một hồ sơ hoàn tiền chờ phân xử], [Bảy mươi hai giờ trôi qua], [Đơn không được giải ngân; nó chỉ trở lại danh sách chờ khi hồ sơ hoàn tiền kết thúc],
    [REQ-33], [Một đơn đang có một hồ sơ hoàn tiền chưa kết thúc], [Người mua mở thêm một hồ sơ hoàn tiền nữa trên chính đơn đó], [Hệ thống từ chối và trỏ về hồ sơ đang sống; không hồ sơ thứ hai nào được tạo],
    [REQ-34], [Hồ sơ hoàn tiền đã mở bốn mươi chín giờ và người bán chưa mở ứng dụng], [Tác vụ định kỳ chạy], [Hồ sơ chuyển sang chờ phân xử và một phiếu hỗ trợ được mở; không có khoản tiền nào được hoàn tự động cho bên nào],
    [REQ-35], [Người bán đã chấp nhận cho trả hàng nhưng hàng chưa quay về], [Người mua kiểm tra ví của mình], [Chưa khoản nào được hoàn; tiền chỉ rời ký quỹ sau khi người bán xác nhận đã nhận hàng và hết cửa sổ kiểm hàng],
    [REQ-36], [Cả người mua và người bán đều đã mở phiếu về cùng một hồ sơ hoàn tiền], [Điều phối viên ra phán quyết], [Cả hai phiếu đều đóng và cùng mang kết luận; tiền được giải quyết đúng một lần theo chiều của phán quyết],
    [REQ-37], [Một điều phối viên đã trả lời trong hội thoại của phiếu], [Người gửi mở hộp thư và mở chính phiếu đó], [Cả dòng tin nhắn cuối trong danh sách lẫn nội dung trong hội thoại đều hiện dưới danh nghĩa bàn hỗ trợ; không nơi nào lộ tài khoản của người trả lời],
    [REQ-48], [Người bán đã chấp nhận cho trả hàng], [Người mua bấm rút hồ sơ], [Hệ thống từ chối vì hồ sơ đã rời trạng thái chờ người bán trả lời; hồ sơ tiếp tục theo luồng trả hàng],
    [REQ-38], [Người mua đã gửi đánh giá, người bán chưa gửi và mới qua hai ngày], [Một người thứ ba mở trang người bán], [Đánh giá chưa hiện ra và điểm uy tín chưa đổi; cả hai chỉ xảy ra cùng lúc, khi bên kia gửi hoặc khi hết mười bốn ngày],
    [REQ-40], [Một tài khoản chưa từng có biến động tiền nào], [Mở màn hình ví], [Hệ thống hiển thị số dư khả dụng và số dư đang giữ đều bằng không cùng một sổ bút toán rỗng, chứ không báo lỗi không tìm thấy ví],
    [REQ-41], [Ví có một triệu đồng khả dụng và hai triệu đồng đang bị giữ trong ký quỹ], [Gửi yêu cầu rút hai triệu đồng], [Hệ thống từ chối vì vượt phần khả dụng; số dư không đổi và không yêu cầu rút nào được tạo],
    [REQ-49], [Quản trị viên mở màn hình đối soát một ví], [Ghi một bút toán điều chỉnh mà không nhập lý do], [Hệ thống từ chối; số dư không đổi và không dòng nào được thêm vào sổ],
    [REQ-42], [Một tài khoản mang vai điều phối viên], [Gọi chức năng cấp phát một tài khoản điều phối viên khác], [Bị từ chối; chỉ vai quản trị viên gọi được chức năng này],
    [REQ-43], [Một cổng thanh toán đang bị tắt trong sổ tuỳ chọn], [Người mua mở danh sách phương thức trả tiền, rồi mở một giao dịch cũ đã thanh toán qua cổng đó], [Cổng không xuất hiện trong danh sách chọn, nhưng giao dịch cũ vẫn hiển thị đúng tên cổng đã dùng],
    [REQ-47], [Cây danh mục đang có một danh mục lá gắn với ba tin đăng], [Quản trị viên bấm xoá danh mục đó], [Hệ thống từ chối và nêu số tin đăng đang gắn; cây danh mục không đổi],
    [REQ-47], [Quản trị viên kéo một danh mục cha vào làm con của chính một danh mục con của nó], [Lưu thay đổi], [Hệ thống từ chối vì phép sắp lại này tạo ra chu trình; cây danh mục không đổi],
    [REQ-44], [Người dùng xin một đường tải lên rồi không tải tệp nào], [Gọi bước xác nhận đã tải xong], [Hệ thống từ chối và không gắn tệp nào vào nghiệp vụ gọi tới],
    [REQ-45], [Một điều phối viên gỡ một tin đăng], [Đọc nhật ký kiểm toán của tin đó], [Có đúng một bản ghi ghi rõ ai quyết, quyết gì và khi nào; bản ghi tồn tại khi và chỉ khi việc gỡ tin đã thực sự được ghi],
    [REQ-50], [Người dùng đang đăng nhập trên ba thiết bị], [Đổi mật khẩu trên một thiết bị], [Hai thẻ truy cập còn lại bị từ chối ở yêu cầu kế tiếp, không phải chờ tới lúc chúng hết hạn],
  )
)

=== Ma trận CRUD kiểm tra độ đầy đủ

Ma trận dưới đây đối chiếu từng thực thể của mô hình ý niệm với bốn thao tác tạo, đọc, sửa
và xoá, nhằm phát hiện khoảng trống — một thực thể được tạo mà không đọc được, hoặc được sửa
mà không có đường đọc để biết cần sửa gì. Dấu gạch ngang là khoảng trống *có chủ ý*, và lý
do được ghi ở cột cuối. Một quy ước xuyên suốt hệ thống: không thực thể nghiệp vụ nào bị xoá
vật lý, vì mọi bản ghi đều có thể trở thành bằng chứng của một khiếu nại về sau. Cột "Xoá" vì
vậy được đọc theo nghĩa nghiệp vụ: một mã yêu cầu ở đó là một thao tác mà người dùng gọi ra
và gọi là xoá — gỡ tin, huỷ phiên, rút hồ sơ — được hiện thực bằng một phép chuyển trạng
thái. Dấu gạch ngang ở cột đó nghĩa là ngay cả một thao tác như vậy cũng không tồn tại.

#figure(
  kind: table,
  caption: [Ma trận CRUD đối chiếu thực thể ý niệm với các yêu cầu chức năng],
  table(
    columns: (1.05fr, 0.95fr, 1.05fr, 1.15fr, 0.72fr, 1.6fr),
    align: (left + top, left + top, left + top, left + top, left + top, left + top),
    table.header([Thực thể], [Tạo], [Đọc], [Sửa], [Xoá], [Ghi chú khoảng trống]),
    [Tài khoản], [REQ-01, REQ-42], [REQ-03, REQ-04], [REQ-06, REQ-08, REQ-50], [—], [Khoá tài khoản thay cho xoá, để dấu vết giao dịch còn nguyên.],
    [Địa chỉ liên hệ], [REQ-06], [REQ-10, REQ-23], [REQ-06], [REQ-06], [Xoá được vì địa chỉ đã dùng đã được chụp lại vào tin đăng và vào đơn.],
    [Giấy tờ định danh], [REQ-07], [REQ-07], [REQ-07, REQ-08], [—], [Hồ sơ bị từ chối được giữ lại kèm lý do để lần nộp sau đối chiếu.],
    [Danh mục], [REQ-47], [REQ-15], [REQ-16, REQ-47], [REQ-47], [Do quản trị viên quản lý; xoá một danh mục đang có tin đăng bị chặn.],
    [Tin đăng], [REQ-09], [REQ-14, REQ-15], [REQ-11, REQ-12], [REQ-12], [Gỡ tin là chuyển trạng thái, và chỉ điều phối viên khôi phục được.],
    [Phiên bản sản phẩm], [REQ-09], [REQ-14, REQ-22], [REQ-11], [REQ-12], [Đi theo vòng đời của tin đăng chứa nó.],
    [Tồn kho], [REQ-09], [REQ-22], [REQ-26, REQ-28], [—], [Giữ chỗ và trả lại đều là cập nhật bộ đếm, không phải tạo hay xoá bản ghi.],
    [Tệp đính kèm], [REQ-44], [REQ-12, REQ-36], [—], [—], [Bất biến sau khi xác nhận tải lên, để giữ giá trị đối chứng.],
    [Hội thoại], [REQ-18, REQ-37], [REQ-18], [REQ-18], [—], [Dấu đã đọc là phần duy nhất bị sửa; nội dung không bị sửa.],
    [Tin nhắn], [REQ-18], [REQ-18], [—], [—], [Tin nhắn là bằng chứng trao đổi, không cho sửa và không cho xoá.],
    [Phiếu hỗ trợ], [REQ-37], [REQ-37], [REQ-36, REQ-37], [—], [Phiếu chỉ đóng, không xoá; phiếu khiếu nại hoàn tiền chỉ đóng theo phán quyết.],
    [Phiếu mua tạm], [REQ-22], [REQ-23], [REQ-24], [REQ-24], [Huỷ là đánh dấu đã dùng hoặc đã hết hạn, không xoá bản ghi.],
    [Thương lượng giá], [REQ-19], [REQ-19], [REQ-19, REQ-20, REQ-21], [—], [Lịch sử luân phiên là căn cứ đối chiếu khi có tranh cãi về giá.],
    [Dòng hàng], [REQ-26], [REQ-27], [REQ-26], [—], [Sinh ra cùng phiên thanh toán, không tồn tại đường xoá.],
    [Đơn hàng], [REQ-26], [REQ-27, REQ-30], [REQ-27, REQ-31, REQ-32], [REQ-28], [Huỷ đơn là ghi mốc huỷ, một trong bốn trạng thái suy ra.],
    [Kiện hàng], [REQ-26, REQ-35], [REQ-30], [REQ-27, REQ-30], [—], [Dùng cho cả chặng giao đi lẫn chặng trả hàng.],
    [Hồ sơ hoàn tiền], [REQ-33], [REQ-34, REQ-36], [REQ-34, REQ-35, REQ-36], [REQ-48], [Người mua rút hồ sơ là một trạng thái kết thúc riêng, phân biệt với bị bác bỏ; bản ghi được giữ nguyên.],
    [Phiên thanh toán], [REQ-24], [REQ-25], [REQ-25], [REQ-24], [Người mua huỷ phiên và phiên hết hạn đều là chuyển trạng thái kèm trả lại quyền đã giành.],
    [Bút toán thanh toán], [REQ-25], [REQ-40], [—], [—], [Sổ cái chỉ-thêm-mới; điều chỉnh bằng một bút toán đảo ứng.],
    [Ví], [REQ-26], [REQ-40], [REQ-26, REQ-32, REQ-41, REQ-49], [—], [Một tài khoản đúng một ví cho mỗi đơn vị tiền; ví được mở ở lần biến động tiền đầu tiên chứ không lúc đăng ký.],
    [Bút toán ví], [REQ-26, REQ-32, REQ-49], [REQ-40], [—], [—], [Chỉ-thêm-mới, mỗi bút toán ghi kèm số dư sau.],
    [Yêu cầu rút tiền], [REQ-41], [REQ-41], [REQ-41], [—], [Từ chối là chuyển trạng thái kèm hoàn lại số dư.],
    [Đánh giá giao dịch], [REQ-38], [REQ-38], [REQ-38], [—], [Chỉ sửa được mốc công bố; nội dung đã công bố là bất biến.],
    [Nhận xét sản phẩm], [REQ-39], [REQ-39], [REQ-39], [REQ-39], [Người viết xoá được nhận xét của mình; điểm trung bình được tính lại.],
    [Điểm uy tín], [REQ-38], [REQ-38, REQ-39], [REQ-38, REQ-39], [—], [Bản ghi rỗng là các số không chứ không phải là không tồn tại.],
  )
)

== Yêu cầu phi chức năng

Yêu cầu phi chức năng quy định hệ thống phải *tốt tới mức nào*, chứ không phải phải làm
gì. Ba mươi chín yêu cầu dưới đây được chia thành bốn nhóm thuộc tính chất lượng, và mỗi
yêu cầu bắt buộc mang hai thứ: một *tiêu chí định lượng* và một *cách kiểm chứng*. Ràng
buộc này là có chủ ý — chương kiểm thử và đánh giá sẽ đối chiếu ngược lại bằng số đo thật,
nên một phát biểu kiểu "hệ thống phải nhanh" hay "hệ thống phải an toàn" không những vô
dụng lúc thiết kế mà còn không nghiệm thu được lúc bàn giao.

Các ngưỡng hiệu năng được đặt sau khi đã có một lượt đo thăm dò trên máy phát triển, theo
nguyên tắc *thách thức nhưng đạt được*: ngưỡng nằm cao hơn số đo hiện tại đủ để còn chỗ cho
tập dữ liệu lớn lên và cho độ trễ mạng thật, nhưng không cao tới mức biến việc nghiệm thu
thành một thủ tục hình thức. Mọi ngưỡng đều gắn với một mức đồng thời cụ thể, vì một con số
phân vị không kèm mức tải là một con số không so sánh được.

Bộ mã phi chức năng cũng theo đúng quy ước của hai bộ mã trước: cấp theo thứ tự bổ sung và
không đánh số lại, nên bảy yêu cầu thêm vào ở lượt rà soát cuối — bốn yêu cầu về khả năng
tiếp cận, trình duyệt, ngôn ngữ và thời gian làm quen, cùng ba yêu cầu về cửa sổ bảo trì,
thời hạn lưu nhật ký và mức tải đỉnh — nằm trong nhóm thuộc tính của mình nhưng mang mã cao
hơn các yêu cầu bên cạnh.

#figure(
  kind: table,
  caption: [Yêu cầu phi chức năng — nhóm hiệu năng và khả năng chịu tải],
  table(
    columns: (0.5fr, 3.35fr, 1.55fr, 0.62fr),
    align: (center + horizon, left + top, left + top, center + horizon),
    table.header([Mã], [Phát biểu và tiêu chí định lượng], [Cách kiểm chứng], [Ư. tiên]),
    [NFR-01], [Đường đọc danh sách tin đăng có phân vị 95 của thời gian phản hồi không vượt quá 30 ms ở mức 10 luồng đồng thời và không vượt quá 100 ms ở mức 50 luồng, đo tại tầng cổng vào.], [Bộ tạo tải vòng kín, ba giây khởi động rồi hai mươi giây đo, phân vị tính theo thứ hạng gần nhất], [Bắt buộc],
    [NFR-02], [Tìm kiếm theo từ khoá có phân vị 95 không vượt quá 20 ms ở mức 10 luồng đồng thời và không vượt quá 60 ms ở mức 50 luồng.], [Cùng bộ tạo tải, kịch bản truy vấn từ khoá lấy từ tập từ khoá thật], [Bắt buộc],
    [NFR-03], [Tìm kiếm lai kết hợp từ khoá với ngữ nghĩa có phân vị 95 không vượt quá 250 ms ở mức 10 luồng đồng thời và không vượt quá 350 ms ở mức 50 luồng, tính cả thời gian sinh vector cho câu truy vấn.], [Cùng bộ tạo tải; giá trị tối đa của lượt gọi đầu tiên sau khởi động nguội được loại khỏi phép so sánh và phải được nêu riêng], [Bắt buộc],
    [NFR-04], [Các đường đọc đã xác thực gồm hồ sơ phiên và danh sách đơn hàng của chính người gọi có phân vị 95 không vượt quá 10 ms ở mức 10 luồng đồng thời và không vượt quá 80 ms ở mức 50 luồng.], [Cùng bộ tạo tải, chạy với một thẻ truy cập hợp lệ. Ngưỡng chặt hơn NFR-01 dù có thêm một lượt tra cứu phiên là có chủ ý: lượt tra cứu đó nằm trong bộ nhớ ngoài cơ sở dữ liệu và trả lời dưới một phần nghìn giây, trong khi danh sách tin đăng phải ghép nhiều bảng và lọc trên tập lớn hơn nhiều lần], [Bắt buộc],
    [NFR-05], [Thông lượng đạt tối thiểu 800 yêu cầu mỗi giây với đường đọc danh sách tin đăng và tối thiểu 1200 yêu cầu mỗi giây với tìm kiếm từ khoá, ở mức 10 luồng đồng thời.], [Đọc trực tiếp số yêu cầu chia thời lượng đo của cùng lượt đo trên], [Nên có],
    [NFR-06], [Không một yêu cầu nào trong toàn bộ thời lượng đo được phép lỗi hoặc trả về mã trạng thái từ 500 trở lên, ở cả hai mức đồng thời.], [Đếm mã trạng thái theo nhóm trong báo cáo của bộ tạo tải], [Bắt buộc],
    [NFR-07], [Hệ thống phục vụ được tối thiểu 50 phiên đồng thời trên một nút; ở mức đó độ trễ được phép tăng gần tuyến tính theo số luồng, nhưng thông lượng không được giảm so với mức 10 luồng.], [So sánh cặp số đo giữa hai mức đồng thời trong cùng một lượt đo], [Nên có],
    [NFR-08], [Độ trễ từ lúc một sự kiện được ghi bền tới lúc thiết bị đang kết nối nhận được thông báo đẩy không vượt quá 1 giây.], [Đo mốc thời gian hai đầu trên kênh đẩy thời gian thực], [Nên có],
    [NFR-39], [Mọi ngưỡng ở bảng này được nghiệm thu ở hai mức tải phân biệt: tải trung bình là 10 luồng đồng thời, tải đỉnh là 50 luồng, tức gấp năm lần. Ngoài ra bộ ngưỡng phải giữ được trên ba mốc tăng trưởng dữ liệu dự kiến: 50 nghìn tin đăng và 200 nghìn đơn hàng sau một năm, 250 nghìn tin đăng và một triệu đơn hàng sau ba năm, 600 nghìn tin đăng và ba triệu đơn hàng sau năm năm.], [Sinh tập dữ liệu tổng hợp theo từng mốc rồi chạy lại toàn bộ bộ đo của nhóm này ở cả hai mức tải, và ghi cả ba lượt cạnh nhau để thấy hình dạng suy giảm], [Nên có],
  )
)

#note[*Điểm yếu đã biết của đường đọc và cách xử lý trong bộ ngưỡng.* Lượt đo thăm dò cho
thấy một đường đọc có phân vị 95 cao gấp hơn ba mươi lần phân vị 50 — dấu hiệu kinh điển của
hiện tượng dồn toa khi mục nhớ đệm hết hạn: phần lớn yêu cầu được phục vụ từ bộ nhớ đệm nên
rất nhanh, nhưng đúng thời điểm mục đó hết hạn thì nhiều yêu cầu cùng lúc rơi xuống cơ sở dữ
liệu. Đường đọc này cố ý *không* được đặt một ngưỡng riêng trong bảng trên, vì đặt ngưỡng
theo hành vi hiện tại là hợp thức hoá một khiếm khuyết; nó được ghi nhận là một hạng mục cải
thiện và sẽ được đo lại sau khi có cơ chế chống dồn toa. Ngoài ra, mọi ngưỡng trong bảng đều
được hiểu kèm ba giới hạn của phép đo: bộ tạo tải chạy cùng máy với dịch vụ nên không tính
độ trễ mạng thật và có cạnh tranh tài nguyên với chính dịch vụ; bản dựng đem đo là bản phát
triển chứ không phải ảnh phát hành; và quy mô dữ liệu lúc đo còn nhỏ, nên các con số tuyệt
đối sẽ đổi trên tập dữ liệu lớn dù hình dạng của chúng vẫn đúng.]

#figure(
  kind: table,
  caption: [Yêu cầu phi chức năng — nhóm bảo mật và kiểm toán],
  table(
    columns: (0.5fr, 3.35fr, 1.55fr, 0.62fr),
    align: (center + horizon, left + top, left + top, center + horizon),
    table.header([Mã], [Phát biểu và tiêu chí định lượng], [Cách kiểm chứng], [Ư. tiên]),
    [NFR-09], [Mật khẩu dài tối thiểu 8 và tối đa 72 ký tự, được kiểm tra ở mọi đường đặt mật khẩu gồm đăng ký, đổi mật khẩu và đặt lại mật khẩu; mật khẩu được băm bằng một hàm băm thích ứng có muối với hệ số công việc từ 10 trở lên, và không tồn tại đường đi nào trong hệ thống đọc lại được mật khẩu nguyên bản. Không đặt thêm ràng buộc bắt buộc phải có chữ hoa, chữ số hay ký tự đặc biệt, vì những luật đó đẩy người dùng tới các biến thể đoán được của cùng một mật khẩu ngắn.], [Rà soát mã nguồn, kiểm thử ba đường đặt mật khẩu với chuỗi 7 ký tự và chuỗi 73 ký tự, và quét toàn bộ bản ghi nhật ký tìm chuỗi mật khẩu], [Bắt buộc],
    [NFR-10], [Thẻ truy cập sống tối đa 15 phút và phiên đăng nhập sống tối đa 30 ngày; mọi yêu cầu đã xác thực đều tra cứu phiên tương ứng trước khi được phục vụ.], [Kiểm thử vòng đời thẻ và phiên, gồm cả trường hợp thẻ còn hạn nhưng phiên đã bị thu hồi], [Bắt buộc],
    [NFR-11], [Thu hồi toàn bộ phiên của một tài khoản phải có chi phí không phụ thuộc vào số phiên đang mở.], [Đo thời gian thu hồi trên tài khoản có 1 phiên và tài khoản có 100 phiên], [Nên có],
    [NFR-12], [Mọi định danh công bố ra ngoài đều ở dạng mờ: không suy ra được số thứ tự của bản ghi và không dò được bản ghi kế tiếp bằng cách cộng trừ một đơn vị.], [Kiểm thử dò tuần tự trên một dải mã đã biết và kiểm tra tỉ lệ trúng], [Bắt buộc],
    [NFR-13], [Kiểm soát truy cập theo vai trò được đặt tại tầng dịch vụ chứ không tại tầng cổng vào, vì vai trò là một thuộc tính do dịch vụ tài khoản sở hữu.], [Kiểm thử gọi chéo vai trò trên toàn bộ nhóm chức năng quản trị và kiểm duyệt], [Bắt buộc],
    [NFR-14], [Một tài nguyên không thuộc về người gọi phải trả về kết quả "không tìm thấy" chứ không phải "bị cấm", để câu trả lời không tiết lộ sự tồn tại của bản ghi.], [Kiểm thử truy cập tài nguyên của tài khoản khác và so sánh mã trả về], [Bắt buộc],
    [NFR-15], [Toàn bộ truy vấn cơ sở dữ liệu dùng tham số hoá; không tồn tại câu lệnh nào được ghép bằng nối chuỗi từ dữ liệu người dùng.], [Rà soát mã nguồn kết hợp quét lỗ hổng tự động trong quy trình tích hợp], [Bắt buộc],
    [NFR-16], [Ba luồng phát mã dùng một lần chịu giới hạn tần suất một phút, và khoá tiết lưu được đặt trước khi tra cứu tài khoản, để mã trả về không phân biệt được địa chỉ đã đăng ký với địa chỉ chưa đăng ký.], [So sánh mã trả về và thời gian phản hồi giữa một địa chỉ có thật và một địa chỉ không tồn tại], [Bắt buộc],
    [NFR-17], [Toàn bộ giao tiếp giữa thiết bị người dùng và hệ thống được mã hoá bằng TLS phiên bản 1.2 trở lên; không phục vụ nội dung qua kênh không mã hoá.], [Quét cấu hình lớp biên], [Bắt buộc],
    [NFR-18], [Thông tin định danh cá nhân chỉ trả về cho chính chủ sở hữu; danh tính cá nhân của điều phối viên trả lời phiếu bị ẩn với người gửi ở *mọi* nơi hiển thị tin nhắn, kể cả dòng tin nhắn cuối trong danh sách hội thoại.], [Kiểm thử che dữ liệu theo vai trò trên cả đường đọc chi tiết lẫn đường đọc danh sách], [Bắt buộc],
    [NFR-38], [Bản ghi kiểm toán được giữ tối thiểu 5 năm và không sửa, không xoá được trong thời hạn đó, kể cả bằng tài khoản kết nối của ứng dụng; nhật ký ứng dụng dạng có cấu trúc giữ 30 ngày và bốn tín hiệu quan trắc giữ 90 ngày.], [Kiểm tra chính sách lưu trữ đã cấu hình của kho nhật ký, và thử một lệnh sửa cùng một lệnh xoá trên bảng kiểm toán bằng chính tài khoản kết nối của ứng dụng], [Bắt buộc],
  )
)

#figure(
  kind: table,
  caption: [Yêu cầu phi chức năng — nhóm tin cậy, khả dụng và toàn vẹn dữ liệu],
  table(
    columns: (0.5fr, 3.35fr, 1.55fr, 0.62fr),
    align: (center + horizon, left + top, left + top, center + horizon),
    table.header([Mã], [Phát biểu và tiêu chí định lượng], [Cách kiểm chứng], [Ư. tiên]),
    [NFR-19], [Mỗi chuyển đổi theo thời hạn là một thao tác lũy đẳng: gọi lại nhiều lần cho cùng một đối tượng không được sinh thêm hiệu ứng nào. Khi thành phần điều phối tiến trình bền được bật, mỗi chuyển đổi có hai nguồn kích hoạt độc lập dùng chung một định nghĩa "đến hạn"; khi tắt, tác vụ quét định kỳ là nguồn duy nhất và hệ thống vẫn phải đúng.], [Kiểm thử gọi lặp cùng một chuyển đổi và đối chiếu số bút toán phát sinh, chạy hai lượt với thành phần điều phối bật và tắt], [Bắt buộc],
    [NFR-20], [Không tình huống lỗi nào được phép tạo ra hai đơn hàng từ một lần mua, hoặc hai lần thu tiền cho một lần bán.], [Kiểm thử nhấn đúp đồng thời và gửi trùng thông báo của cổng thanh toán], [Bắt buộc],
    [NFR-21], [Số dư ví không bao giờ âm, và tổng biến động trong sổ bút toán luôn khớp với số dư hiện tại của ví.], [Đối soát tổng số dư sau khi chạy kịch bản lỗi có tiêm gián đoạn], [Bắt buộc],
    [NFR-22], [Hai lần ghi đồng thời lên cùng một bản ghi phải khiến một bên thất bại bằng lỗi xung đột, chứ không được ghi đè âm thầm lên thay đổi mà bên đó chưa nhìn thấy.], [Kiểm thử hai yêu cầu song song trên cùng bản ghi và kiểm tra mã trả về của bên thua], [Bắt buộc],
    [NFR-23], [Mức khả dụng đạt tối thiểu 99,5% theo tháng, tương đương gián đoạn không quá khoảng 3,6 giờ mỗi tháng.], [Theo dõi qua dữ liệu quan trắc và bảng điều khiển giám sát], [Nên có],
    [NFR-24], [Cơ sở dữ liệu được sao lưu tự động hằng ngày, với mục tiêu thời gian phục hồi không quá 4 giờ và mục tiêu điểm phục hồi không quá 24 giờ.], [Diễn tập phục hồi từ bản sao lưu và bấm giờ], [Nên có],
    [NFR-25], [Mỗi dịch vụ dùng một lược đồ cơ sở dữ liệu riêng; không tồn tại khoá ngoại xuyên lược đồ, và mọi tham chiếu chéo dịch vụ là tham chiếu logic.], [Rà soát định nghĩa lược đồ và quyền truy cập của từng tài khoản kết nối], [Bắt buộc],
    [NFR-37], [Bảo trì có kế hoạch nằm trong cửa sổ từ 2 giờ tới 5 giờ sáng giờ Việt Nam, không quá hai lần mỗi tháng và không quá 60 phút mỗi lần, được báo trước ít nhất 48 giờ. Thời lượng trong cửa sổ này được trừ khỏi phép tính mức khả dụng của NFR-23; mọi gián đoạn ngoài cửa sổ thì không.], [Đối chiếu nhật ký triển khai với lịch bảo trì đã công bố, và kiểm tra công thức tính mức khả dụng có trừ đúng phần đã báo trước], [Nên có],
  )
)

#figure(
  kind: table,
  caption: [Yêu cầu phi chức năng — nhóm khả năng sử dụng, khả năng tiếp cận, bảo trì và ràng buộc],
  table(
    columns: (0.5fr, 3.35fr, 1.55fr, 0.62fr),
    align: (center + horizon, left + top, left + top, center + horizon),
    table.header([Mã], [Phát biểu và tiêu chí định lượng], [Cách kiểm chứng], [Ư. tiên]),
    [NFR-26], [Giao diện hiển thị đúng bố cục trên dải bề ngang từ 360 px tới 1920 px theo nguyên tắc ưu tiên thiết bị di động.], [Kiểm thử giao diện ở ba mốc kích thước màn hình tiêu biểu], [Bắt buộc],
    [NFR-27], [Mọi thao tác không thể hoàn tác — xác nhận nhận hàng, chấp thuận một mức giá, từ chối một đơn, ra phán quyết — phải có một bước xác nhận nêu rõ hệ quả.], [Rà soát luồng giao diện theo danh sách thao tác không hoàn tác được], [Bắt buộc],
    [NFR-33], [Giao diện đạt mức AA của WCAG 2.1 trên toàn bộ các luồng nghiệp vụ chính: mọi ảnh mang thông tin có văn bản thay thế, mọi trường nhập có nhãn gắn với nó, tỉ lệ tương phản tối thiểu 4,5 : 1 cho văn bản thường và 3 : 1 cho văn bản lớn, mọi thông tin không được truyền tải chỉ bằng màu, và mọi luồng hoàn tất được chỉ bằng bàn phím với dấu tiêu điểm luôn nhìn thấy.], [Bộ kiểm tra tiếp cận tự động chạy trong quy trình tích hợp với ngưỡng không còn lỗi mức A và AA, cộng một lượt đi hết luồng tìm — mua — thanh toán — khiếu nại bằng bàn phím và bằng trình đọc màn hình], [Bắt buộc],
    [NFR-34], [Ứng dụng khách chạy đúng trên bốn trình duyệt Chrome, Firefox, Safari và Edge ở phiên bản hiện hành cùng phiên bản liền trước, và trên trình duyệt mặc định của Android từ phiên bản 10 cùng iOS từ phiên bản 15 trở lên.], [Chạy bộ kiểm thử giao diện đầu-cuối trên đúng ma trận trình duyệt nêu trên trước mỗi lần phát hành], [Bắt buộc],
    [NFR-35], [Tiếng Việt là ngôn ngữ duy nhất của giao diện và của mọi thông điệp gửi tới người dùng ở giai đoạn này. Mỗi lỗi trả về theo giao diện lập trình mang một mã ổn định không phụ thuộc ngôn ngữ bên cạnh phần văn bản, để một ngôn ngữ thứ hai về sau chỉ phải bổ sung bản dịch chứ không phải sửa tầng xử lý.], [Duyệt toàn bộ màn hình cùng mẫu thư và tin nhắn hệ thống; kiểm tra mọi phản hồi lỗi của đặc tả giao diện lập trình đều có trường mã bên cạnh trường thông điệp], [Bắt buộc],
    [NFR-36], [Một người bán chưa từng dùng hệ thống, sau không quá 10 phút hướng dẫn, đăng được tin đầu tiên trong không quá 15 phút; một người mua chưa từng dùng hệ thống hoàn tất được một giao dịch giá cố định trong không quá 10 phút mà không cần hỏi ai.], [Kiểm thử với năm người chưa từng tiếp xúc hệ thống cho mỗi vai, bấm giờ từ lúc đăng nhập tới lúc thao tác hoàn tất và lấy trung vị], [Nên có],
    [NFR-28], [Mỗi lời gọi ra nhà cung cấp bên ngoài có hạn chờ riêng cho từng thao tác, khai báo trong tệp cấu hình; luồng đọc dữ liệu liên tục có hạn chờ riêng bao trọn thời gian đọc.], [Kiểm thử với bộ giả lập treo và bộ giả lập trả dữ liệu nhỏ giọt], [Bắt buộc],
    [NFR-29], [Toàn bộ cấu hình nằm trong một tệp duy nhất; mọi trường đều bắt buộc, và một khoá lạ hoặc một trường sai định dạng làm tiến trình dừng ngay lúc khởi động kèm đường dẫn tới trường sai.], [Kiểm thử khởi động với tệp thiếu trường, tệp thừa khoá và tệp sai định dạng], [Bắt buộc],
    [NFR-30], [Bản đặc tả giao diện lập trình là nguồn duy nhất, được sinh tự động từ các mảnh đặc tả của từng dịch vụ, và dựng được thành một máy chủ giả lập phục vụ toàn bộ hợp đồng.], [Kiểm thử hợp đồng trong quy trình tích hợp: sinh lại đặc tả và so với bản đã lưu], [Nên có],
    [NFR-31], [Mã nguồn phải qua bộ kiểm tra tĩnh với không một cảnh báo nào còn lại, và bộ kiểm thử đơn vị phải chạy được trọn vẹn mà không cần cơ sở dữ liệu.], [Chạy bộ kiểm tra tĩnh và bộ kiểm thử trong quy trình tích hợp liên tục], [Nên có],
    [NFR-32], [Hệ thống tuân thủ pháp luật Việt Nam về thương mại điện tử và Nghị định 13/2023 về bảo vệ dữ liệu cá nhân đối với thông tin định danh, số điện thoại và địa chỉ thu thập từ người dùng.], [Rà soát đối chiếu với văn bản quy định], [Bắt buộc],
  )
)

== Ma trận ưu tiên và truy xuất nguồn gốc yêu cầu

=== Ma trận ưu tiên

Mức ưu tiên được gán theo một tiêu chí duy nhất và nhất quán: một yêu cầu là *bắt buộc* khi
thiếu nó thì không thể chạy trọn vẹn một giao dịch từ lúc đăng bán tới lúc tiền về người
bán, hoặc không thể bảo vệ được tiền của người dùng. Cách gán này tránh được khuyết điểm
thường gặp là đánh dấu mọi thứ ở mức cao nhất, và cho thấy rõ phần nào của hệ thống có thể
cắt bớt nếu quỹ thời gian eo hẹp.

#figure(
  kind: table,
  caption: [Phân bố mức ưu tiên của các yêu cầu chức năng theo nhóm],
  table(
    columns: (2.2fr, 0.72fr, 0.72fr, 0.85fr, 0.6fr),
    align: (left + horizon, center + horizon, center + horizon, center + horizon, center + horizon),
    table.header([Nhóm chức năng], [Bắt buộc], [Nên có], [Có thể lùi], [Tổng]),
    [1 — Định danh, phiên làm việc và phân quyền], [6], [1], [0], [7],
    [2 — Xác minh danh tính], [2], [0], [0], [2],
    [3 — Tin đăng và kiểm duyệt], [4], [0], [1], [5],
    [4 — Tìm kiếm, duyệt và quan tâm], [2], [1], [1], [4],
    [5 — Hội thoại và thương lượng giá], [4], [0], [0], [4],
    [6 — Đặt hàng và thanh toán ký quỹ], [5], [0], [0], [5],
    [7 — Vòng đời đơn hàng và giải ngân], [5], [1], [0], [6],
    [8 — Trả hàng, hoàn tiền và phiếu hỗ trợ], [6], [0], [0], [6],
    [9 — Đánh giá, uy tín và ví], [2], [2], [1], [5],
    [10 — Quản trị, tệp đính kèm và vận hành], [3], [3], [0], [6],
    [*Tổng cộng*], [*39*], [*8*], [*3*], [*50*],
  )
)

Phân bố này nói lên hình dạng của bài toán. Ba nhóm liên quan trực tiếp tới dòng tiền —
đặt hàng và thanh toán ký quỹ, vòng đời đơn hàng, trả hàng và hoàn tiền — gộp lại có mười
sáu yêu cầu bắt buộc và không có yêu cầu nào lùi được, vì một luồng tiền thiếu bất kỳ mắt
xích nào đều dẫn tới tiền kẹt hoặc tiền chi sai. Ngược lại, ba yêu cầu duy nhất có thể lùi
đều nằm ở phần làm giàu trải nghiệm chứ không nằm trên đường tới hạn của một giao dịch: gợi
ý điền tin đăng bằng trí tuệ nhân tạo, theo dõi người bán và lưu sản phẩm quan tâm, nhận xét
sản phẩm.

=== Ma trận truy xuất nguồn gốc

Ma trận dưới đây nối bốn tầng tài liệu — ca sử dụng nguồn, yêu cầu chức năng, thực thể dữ
liệu bị tác động và dịch vụ chủ quản — để khi phạm vi thay đổi thì tác động hai chiều tra ra
được ngay. Ba thực thể mang tính vận hành gồm nhật ký kiểm toán, sổ tuỳ chọn nhà cung cấp và
các tín hiệu quan trắc được ghi trong ma trận nhưng cố ý nằm ngoài mô hình dữ liệu ý niệm ở
mục trước, vì chúng phục vụ việc vận hành hệ thống chứ không phải một khái niệm nghiệp vụ mà
người dùng nhận biết được.

#figure(
  kind: table,
  caption: [Ma trận truy xuất nguồn gốc: ca sử dụng — yêu cầu — thực thể — dịch vụ],
  table(
    columns: (1.45fr, 1.15fr, 2.05fr, 1.1fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([Ca sử dụng nguồn], [Yêu cầu], [Thực thể bị tác động], [Dịch vụ chủ quản]),
    [UC-01 Đăng ký tài khoản], [REQ-01…03], [Tài khoản], [tài khoản],
    [UC-02 Đăng nhập và quản lý phiên], [REQ-03…05, REQ-50], [Tài khoản], [tài khoản],
    [UC-03 Xác minh danh tính], [REQ-07, REQ-08], [Giấy tờ định danh, Tài khoản], [tài khoản],
    [UC-04 Quản lý hồ sơ và sổ địa chỉ], [REQ-06], [Tài khoản, Địa chỉ liên hệ], [tài khoản],
    [UC-05 Cấp phát điều phối viên], [REQ-05, REQ-42], [Tài khoản, Nhật ký kiểm toán], [tài khoản],
    [UC-06 Đăng bán sản phẩm], [REQ-09…11, REQ-16], [Tin đăng, Phiên bản sản phẩm, Tồn kho, Tệp đính kèm], [danh mục],
    [UC-07 Gợi ý điền tin đăng], [REQ-13], [Không ghi bản ghi nào], [danh mục],
    [UC-08 Chỉnh sửa tin đăng], [REQ-11, REQ-16], [Tin đăng], [danh mục],
    [UC-09 Tìm kiếm và duyệt], [REQ-14, REQ-15], [Tin đăng, Danh mục], [danh mục],
    [UC-10 Theo dõi và lưu quan tâm], [REQ-17], [Tin đăng, Tài khoản], [danh mục, tài khoản],
    [UC-11 Nhắn tin thời gian thực], [REQ-18], [Hội thoại, Tin nhắn, Tệp đính kèm], [trò chuyện],
    [UC-12 Thương lượng giá], [REQ-19…21], [Thương lượng giá, Tin nhắn], [đơn hàng, trò chuyện],
    [UC-13 Chuẩn bị đơn và báo giá], [REQ-22, REQ-23], [Phiếu mua tạm, Kiện hàng, Địa chỉ liên hệ], [đơn hàng],
    [UC-14 Thanh toán và ký quỹ], [REQ-24…26], [Phiên thanh toán, Bút toán thanh toán, Dòng hàng, Đơn hàng, Ví], [tài chính, đơn hàng],
    [UC-15 Xác nhận đơn đã thanh toán], [REQ-26…29], [Đơn hàng, Kiện hàng, Tồn kho], [đơn hàng],
    [UC-16 Theo dõi hành trình kiện hàng], [REQ-30], [Kiện hàng], [đơn hàng],
    [UC-17 Xác nhận đã nhận hàng], [REQ-31, REQ-32], [Đơn hàng, Tệp đính kèm, Ví, Bút toán ví], [đơn hàng, tài chính],
    [UC-18 Quản lý ví và rút tiền], [REQ-40, REQ-41], [Ví, Bút toán ví, Yêu cầu rút tiền], [tài chính],
    [UC-19 Yêu cầu trả hàng và hoàn tiền], [REQ-33, REQ-48], [Hồ sơ hoàn tiền, Tệp đính kèm, Đơn hàng], [đơn hàng],
    [UC-20 Xử lý yêu cầu hoàn tiền], [REQ-34, REQ-35], [Hồ sơ hoàn tiền, Kiện hàng, Ví], [đơn hàng, tài chính],
    [UC-21 Đánh giá hai chiều theo cơ chế ẩn], [REQ-38], [Đánh giá giao dịch, Điểm uy tín], [tín nhiệm],
    [UC-22 Đánh giá sản phẩm], [REQ-39], [Nhận xét sản phẩm, Điểm uy tín, Tin đăng], [tín nhiệm, danh mục],
    [UC-23 Gửi phiếu hỗ trợ], [REQ-37], [Phiếu hỗ trợ, Hội thoại, Tệp đính kèm], [tín nhiệm, trò chuyện],
    [UC-24 Tiếp nhận và trả lời phiếu], [REQ-37], [Phiếu hỗ trợ, Tin nhắn], [tín nhiệm, trò chuyện],
    [UC-25 Kiểm duyệt tin đăng và bản sửa], [REQ-11, REQ-12], [Tin đăng, Nhật ký kiểm toán], [danh mục],
    [UC-26 Phân xử yêu cầu hoàn tiền], [REQ-36], [Hồ sơ hoàn tiền, Phiếu hỗ trợ, Ví], [đơn hàng, tín nhiệm, tài chính],
    [UC-27 Duyệt hồ sơ xác minh danh tính], [REQ-07], [Giấy tờ định danh], [tài khoản],
    [UC-28 Quản lý danh mục và sổ tuỳ chọn], [REQ-43, REQ-47], [Danh mục, Sổ tuỳ chọn nhà cung cấp], [danh mục, tài chính, đơn hàng],
    [UC-29 Đối soát ví và điều chỉnh số dư], [REQ-41, REQ-49], [Ví, Bút toán ví, Yêu cầu rút tiền], [tài chính],
    [UC-30 Giám sát vận hành], [REQ-46], [Tín hiệu quan trắc], [quan trắc],
    [UC-S1 Tải lên tệp đính kèm], [REQ-44], [Tệp đính kèm], [mọi dịch vụ có nghiệp vụ nhận tệp],
    [UC-S2 Ghi nhật ký kiểm toán], [REQ-45], [Nhật ký kiểm toán], [cả bảy dịch vụ],
  )
)

=== Truy xuất yêu cầu phi chức năng tới cơ chế hiện thực

Yêu cầu phi chức năng không truy vết về ca sử dụng mà truy vết về *cơ chế* đảm bảo chúng.
Bảng dưới đây ghi lại mối nối đó, để chương thiết kế hệ thống biết mỗi lựa chọn kiến trúc
đang phục vụ ràng buộc chất lượng nào, và để chương kiểm thử biết đo cái gì thì kết luận
được cái gì.

#figure(
  kind: table,
  caption: [Truy xuất yêu cầu phi chức năng tới cơ chế hiện thực tương ứng],
  table(
    columns: (1.05fr, 1.45fr, 2.5fr),
    align: (left + top, left + top, left + top),
    table.header([Yêu cầu], [Cơ chế hiện thực], [Vì sao cơ chế đó đáp ứng được yêu cầu]),
    [NFR-01…07], [Phân trang theo con trỏ và chỉ mục phù hợp trên mọi đường đọc danh sách], [Chi phí một trang không tăng theo tổng số bản ghi, nên ngưỡng phân vị giữ được khi dữ liệu lớn lên.],
    [NFR-03], [Chỉ mục vector nằm ngay trong cơ sở dữ liệu quan hệ], [Lọc thuộc tính và xếp hạng theo khoảng cách thực hiện trong một truy vấn, không phải lấy về rồi lọc lại ở tầng ứng dụng.],
    [NFR-08], [Kênh đẩy thời gian thực hai chiều kết hợp trục sự kiện phát tán theo tài khoản], [Sự kiện đã ghi bền được phát ngay tới đúng các kết nối của tài khoản liên quan, không cần thiết bị hỏi lại theo chu kỳ.],
    [NFR-10, NFR-11], [Phiên đăng nhập lưu ngoài cơ sở dữ liệu, thu hồi hàng loạt bằng cách nâng một số thế hệ], [Một lần nâng số làm mọi phiên cũ mất hiệu lực, nên chi phí thu hồi không phụ thuộc số phiên.],
    [NFR-12, NFR-14], [Định danh công bố ra ngoài ở dạng mờ, có tiền tố theo loại thực thể], [Mã ngoài không mang thông tin thứ tự, nên dò tuần tự không tìm được bản ghi kế tiếp.],
    [NFR-19, NFR-20], [Mỗi chuyển đổi theo thời hạn là một thao tác lũy đẳng có hai nguồn kích hoạt độc lập], [Hai nguồn dùng chung một định nghĩa "đến hạn", nên nguồn này hỏng thì nguồn kia vẫn đúng và gọi trùng không sinh hiệu ứng mới.],
    [NFR-20, NFR-22], [Giành quyền trước khi thu tiền, ràng buộc duy nhất ở tầng dữ liệu, khoá lạc quan theo số phiên bản], [Ràng buộc vẫn giữ ngay cả khi tầng dịch vụ sai, và một lần đọc cũ luôn là bên thua khi ghi.],
    [NFR-21], [Hai loại số dư tách bạch và sổ bút toán chỉ-thêm-mới có ghi số dư sau], [Mọi biến động đều truy lại được, và ràng buộc không âm nằm ngay trong định nghĩa bảng.],
    [NFR-25], [Mỗi dịch vụ một lược đồ riêng với chuỗi kết nối riêng], [Một dịch vụ có thể tách sang cơ sở dữ liệu khác mà không phải gỡ bất kỳ khoá ngoại nào.],
    [NFR-01…07, NFR-23], [Bốn tín hiệu quan trắc ghi vào kho dữ liệu chuỗi thời gian, cộng nhật ký dạng có cấu trúc], [Cùng một hệ đo dùng cho cả lúc nghiệm thu lẫn lúc vận hành, nên ngưỡng trong hợp đồng và số liệu giám sát là cùng một thước.],
    [NFR-28, NFR-29], [Hạn chờ khai báo theo từng thao tác trong một tệp cấu hình bắt buộc đủ trường], [Một cấu hình sai bị phát hiện lúc khởi động thay vì lúc có người dùng gặp lỗi.],
    [NFR-30], [Bản đặc tả sinh tự động từ các mảnh của từng dịch vụ và dựng được thành máy chủ giả lập], [Ứng dụng khách viết được trước khi phần xử lý tồn tại, và đặc tả lệch với mã nguồn thì kiểm thử hợp đồng báo lỗi.],
    [NFR-33, NFR-34], [Bộ kiểm tra tiếp cận tự động và bộ kiểm thử giao diện đầu-cuối cùng chạy trong quy trình tích hợp], [Một vi phạm mức AA hay một trình duyệt hỏng bị chặn ngay tại lần đưa mã lên, chứ không đợi tới lượt rà soát bằng tay trước khi phát hành.],
    [NFR-35], [Mọi lỗi trả về mang một mã ổn định bên cạnh phần văn bản, và văn bản hiển thị tách khỏi tầng xử lý], [Thêm một ngôn ngữ chỉ là thêm một bảng dịch cho tập mã lỗi đã có, nên phần quyết định nghiệp vụ không phải sửa.],
    [NFR-38], [Nhật ký kiểm toán là bảng chỉ-thêm-mới, tài khoản kết nối của ứng dụng không có quyền sửa hay xoá trên bảng đó], [Thời hạn lưu không phụ thuộc vào kỷ luật của mã nguồn, vì ngay cả một lỗi lập trình cũng không xoá được một dòng đã ghi.],
  )
)

#figure(
  kind: table,
  caption: [Thống kê độ bao phủ của bộ yêu cầu],
  table(
    columns: (2.3fr, 0.75fr, 2.5fr),
    align: (left + horizon, center + horizon, left + top),
    table.header([Chỉ số], [Giá trị], [Ghi chú]),
    [Tổng số yêu cầu chức năng], [50], [Mã liên tục từ REQ-01 tới REQ-50, không trùng và không nhảy số.],
    [Yêu cầu bắt buộc], [39], [Điều kiện để chạy trọn một giao dịch và bảo vệ tiền người dùng.],
    [Yêu cầu nên có], [8], [Làm hệ thống dùng được trong thực tế nhưng không chặn luồng nào.],
    [Yêu cầu có thể lùi], [3], [Nằm ngoài đường tới hạn của một giao dịch.],
    [Tổng số yêu cầu phi chức năng], [39], [Mã liên tục từ NFR-01 tới NFR-39, mỗi yêu cầu kèm tiêu chí đo được và cách kiểm chứng.],
    [Ca sử dụng được bao phủ], [32 / 32], [Ba mươi ca nghiệp vụ cộng hai ca dùng chung; mỗi ca có ít nhất một yêu cầu dẫn xuất, và các luồng thay thế sinh ra yêu cầu riêng cũng đã được tách ra thành yêu cầu.],
    [Thực thể được bao phủ], [25 / 25], [Theo ma trận CRUD; không thực thể nào thiếu thao tác tạo hoặc thao tác đọc.],
    [Quy tắc nghiệp vụ được nối vào yêu cầu], [57 / 58], [Chỉ BR-09 không có yêu cầu chức năng nào chi phối, vì nó là một ràng buộc chất lượng và được nghiệm thu qua NFR-12.],
    [Yêu cầu có tiêu chí chấp nhận chi tiết], [44 / 50], [Sáu yêu cầu còn lại được nghiệm thu bằng ngưỡng đo phi chức năng.],
    [Dịch vụ được ánh xạ], [7 / 7], [Tài khoản, danh mục, đơn hàng, tài chính, trò chuyện, tín nhiệm và quan trắc.],
  )
)

== Tiểu kết chương

Chương này đã đi trọn một chu trình phân tích yêu cầu: từ tầm nhìn và phạm vi, qua chân
dung các bên liên quan và ranh giới hệ thống, tới ba mươi hai ca sử dụng cùng năm mươi tám
quy tắc nghiệp vụ, rồi sáu sơ đồ hoạt động và hai sơ đồ trạng thái, một mô hình dữ liệu ý
niệm hai mươi lăm thực thể, và sau cùng là năm mươi yêu cầu chức năng cùng ba mươi chín
yêu cầu phi chức năng, tất cả được nối lại bằng bốn ma trận kiểm tra độ đầy đủ.

Ba kết luận đáng giữ lại cho các chương sau. *Thứ nhất, trật tự của dòng tiền là thứ định
hình toàn bộ phần còn lại.* Việc tiền vào ký quỹ *trước* rồi người bán mới xác nhận — chứ
không phải ngược lại — kéo theo hàng loạt hệ quả: đơn hàng ra đời từ một thông báo của cổng
thanh toán chứ không từ một nút bấm, quyền mua phải được giành trước khi thu tiền, hết bốn
mươi tám giờ thì việc được chuyển cho người chứ không cho một bộ định thời, và sơ đồ trạng
thái đơn hàng chỉ còn bốn trạng thái thay vì bảy. Một mô tả nghiệp vụ đảo trật tự này lại sẽ
kéo theo một thiết kế sai ở cả bảy dịch vụ.

*Thứ hai, những gì hệ thống cố ý không làm cũng là một phần của đặc tả.* Không có bộ lọc nội
dung tự động, không có ngưỡng tố cáo tự động ẩn tin, không có hoa hồng sàn, không có phương
án chia phí giao hàng, không có tự động xác nhận nhận hàng, và không có thực thể tranh chấp
riêng. Mỗi khoảng trống ấy đều có lý do nghiệp vụ chứ không phải là hạng mục chưa kịp làm,
và chúng được ghi thành quy tắc để một lần bổ sung tính năng về sau là một quyết định có ý
thức chứ không phải một sự vá lấp.

*Thứ ba, mọi yêu cầu phi chức năng ở đây đều được viết để có thể bị bác bỏ bằng một phép
đo.* Ngưỡng hiệu năng gắn với mức đồng thời cụ thể và có phương pháp đo kèm theo; ràng buộc
bảo mật và toàn vẹn đều chỉ ra một kịch bản kiểm thử có thể làm chúng thất bại. Bộ mã
REQ-01…50 và NFR-01…39 ban hành ở chương này là bộ mã chuẩn của toàn quyển: chương thiết kế
hệ thống sẽ chỉ ra cơ chế đáp ứng từng yêu cầu, và chương kiểm thử và đánh giá sẽ đối chiếu
ngược lại bằng số liệu đo thật trên hệ thống đã chạy.
