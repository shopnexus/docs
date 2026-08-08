#import "../../common/tokens.typ": *

// Định danh trong bảng từ điển là chuỗi dài, cột thì hẹp: thu nhỏ mã nội dòng
// cho vừa ô. Khối mã SQL không bị ảnh hưởng.
#show raw.where(block: false): set text(size: 8.5pt)

== Thiết kế cơ sở dữ liệu vật lý

Mô hình dữ liệu ý niệm được hiện thực trên một hệ quản trị cơ sở dữ liệu quan hệ duy nhất là
PostgreSQL 18, chạy trên bản phân phối TimescaleDB nhằm có sẵn khả năng phân mảnh theo thời
gian. Bộ ký tự là UTF-8 cho toàn bộ cơ sở dữ liệu, vì dữ liệu người dùng là tiếng Việt có dấu
và cả tên riêng nước ngoài. Ngoài phần lõi quan hệ, thiết kế còn dựa vào năm phần mở rộng của
PostgreSQL, mỗi phần mở rộng phục vụ một nhóm truy vấn mà nếu thiếu nó thì phải giải quyết
bằng một hệ lưu trữ thứ hai: TimescaleDB cho các bảng ghi theo thời gian, PostGIS cho toạ độ
địa lý của địa chỉ và của bài đăng, pgvector cho véc-tơ ngữ nghĩa phục vụ tìm kiếm lai,
`pg_trgm` cùng `unaccent` cho tìm kiếm gần đúng không dấu, và bộ công cụ thống kê của
TimescaleDB cho phân vị trễ trong dữ liệu giám sát.

Toàn bộ dữ liệu nghiệp vụ được tổ chức thành *bảy lược đồ (schema)* trong PostgreSQL, mỗi lược
đồ mang đúng tên của mô-đun sở hữu nó. Ranh giới này không phải là ranh giới triển khai — hệ
thống chạy như một tiến trình duy nhất — mà là ranh giới quyền ghi và ranh giới di chuyển; cơ
chế giữ cho nó đúng được trình bày ở nguyên tắc *cô lập theo lược đồ* ngay dưới đây.

#figure(
  kind: table,
  caption: [Bảy lược đồ vật lý, số bảng và phạm vi dữ liệu của từng lược đồ],
  table(
    columns: (0.85fr, 0.62fr, 0.62fr, 0.5fr, 2.5fr),
    align: (left + horizon, center + horizon, center + horizon, center + horizon, left + horizon),
    table.header([Lược đồ], [Bảng riêng], [Bảng dùng chung], [Tổng], [Phạm vi dữ liệu]),
    [`account`], [8], [3], [11],
      [Định danh, đăng nhập liên kết, hồ sơ hiển thị, sổ địa chỉ, thiết bị nhận đẩy, thông báo và tuỳ chọn kênh, đồ thị theo dõi, giấy tờ định danh.],
    [`catalog`], [12], [3], [15],
      [Danh mục, bài đăng, biến thể, thẻ, tồn kho và bút toán tồn kho, danh sách yêu thích, véc-tơ ngữ nghĩa của bài đăng, danh mục và thẻ.],
    [`order`], [7], [3], [10],
      [Giỏ hàng, phiên mua hàng giá cố định, thương lượng giá, đơn hàng, mục hàng, vận đơn và hồ sơ hoàn tiền.],
    [`finance`], [6], [3], [9],
      [Phiên thanh toán, sổ cái giao dịch trên kênh thanh toán ngoài, ví theo tài khoản và loại tiền, sổ cái ví, tài khoản ngân hàng nhận tiền, thông tin thuế.],
    [`trust`], [7], [3], [10],
      [Phản hồi giao dịch hai chiều, đánh giá sản phẩm cùng trả lời và bình chọn hữu ích, điểm uy tín, phiếu hỗ trợ và khoá chống ghi trùng kết cục đơn hàng.],
    [`chat`], [2], [3], [5],
      [Luồng hội thoại một-một giữa hai tài khoản và tin nhắn trong luồng.],
    [`observability`], [4], [0], [4],
      [Bốn tín hiệu giám sát vận hành, kèm hai khung nhìn kết tụ liên tục. Không nhận phần định nghĩa dùng chung.],
    [*Tổng cộng*], [*46*], [*18*], [*64*],
      [Cùng hai khung nhìn kết tụ liên tục `http_requests_1m` và `provider_calls_1m`.],
  ),
)

Hai điểm trong bảng trên cần được nói rõ ngay, vì chúng thường bị hiểu sai. Thứ nhất, *không có
lược đồ nào tên là `common`*: phần định nghĩa dùng chung — nhật ký kiểm toán, bảng tài nguyên
tệp và bảng tuỳ chọn — được công cụ di trú áp vào *sáu* lược đồ nghiệp vụ, nên câu lệnh tạo
bảng tồn tại một lần trong mã nguồn còn bảng thì tồn tại một bản trong mỗi lược đồ, tổng cộng
mười tám hiện thân vật lý. Thứ hai, lược đồ `observability` cố ý không nhận ba bảng đó: nó chỉ
chứa dữ liệu đo đạc, không có gì để kiểm toán và không nhận tệp tải lên. Cách diễn đạt chính
xác về quy mô, vì vậy, là *bốn mươi sáu bảng nghiệp vụ, cộng ba bảng dùng chung nhân thành
mười tám hiện thân, tổng cộng sáu mươi tư bảng vật lý mang dữ liệu*. Ngoài số đó, mỗi lược đồ
còn một bảng ghi vết các tệp di trú đã áp; bảng này thuộc về công cụ di trú chứ không thuộc mô
hình dữ liệu, nên không được tính vào và cũng không xuất hiện trong các bảng từ điển dưới đây.

Cũng cần nói rõ những gì *không* có trong thiết kế này, vì bản mô tả ở các tài liệu trước còn
nhắc tới chúng. Không có lược đồ `inventory`: tồn kho là hai bộ đếm `reserved` và `sold` trên
bảng `stock` của `catalog`. Không có lược đồ `analytic`: véc-tơ ngữ nghĩa nằm trong `catalog`,
uy tín và đánh giá nằm trong `trust`, còn số liệu sản phẩm và hành vi người dùng được thu thập
bên ngoài phần hậu kiểm này. Không có bảng hồ sơ tách rời: các cột hiển thị đã được gộp thẳng
vào bảng tài khoản. Và không có bảng tranh chấp: mọi khiếu nại hoàn tiền nay là một hàng trong
bảng phiếu hỗ trợ của lược đồ `trust`.

=== Nguyên tắc thiết kế dữ liệu

Bốn nguyên tắc dưới đây chi phối gần như mọi quyết định ở phần còn lại của mục này, nên chúng
được trình bày trước bản đặc tả của từng lược đồ.

*Cô lập theo lược đồ.* Mỗi mô-đun sở hữu một lược đồ mang đúng tên của nó và là thành phần duy
nhất được phép ghi vào lược đồ đó. Nguồn kết nối của mô-đun đặt đường tìm kiếm về lược đồ của
mình cộng với `public`, nhờ vậy toàn bộ câu lệnh SQL — cả câu lệnh định nghĩa lẫn câu lệnh truy
vấn — được viết không kèm tên lược đồ. Việc đặt tên lược đồ chỉ xuất hiện đúng một chỗ là công
cụ di trú, nơi lược đồ được tạo trước khi các tệp di trú của mô-đun được áp. `public` vẫn nằm
trong đường tìm kiếm để các phần mở rộng dùng chung như pgvector hay `pg_trgm` vẫn phân giải
được. Hệ quả thực tiễn của quy tắc này là một mô-đun có thể chuyển sang một cơ sở dữ liệu khác
mà không phải sửa một dòng SQL nào; hệ quả về phía thiết kế là mọi ràng buộc toàn vẹn tham
chiếu chỉ tồn tại *bên trong* một lược đồ.

*Khoá thay thế là số nguyên 64 bit.* Mọi khoá thay thế đều là `BIGINT GENERATED ALWAYS AS
IDENTITY` và mọi cột tham chiếu tới nó đều là `BIGINT`. Không có khoá `UUID` ở bất kỳ đâu trong
thiết kế: khoá tuần tự cho chỉ mục dày đặc hơn, cho phép chèn ở cuối cây B thay vì rải rác, và
giữ kích thước hàng nhỏ hơn — trong khi lý do thường được viện dẫn cho `UUID`, là không để lộ
số lượng bản ghi, đã được giải quyết ở tầng khác bằng định danh mờ trình bày dưới đây. Quy tắc
này có đúng hai ngoại lệ, cả hai nằm trong lược đồ `finance`: `payment_session` và `transaction`
dùng `GENERATED BY DEFAULT AS IDENTITY`, vì ứng dụng phải biết định danh *trước* khi chèn hàng
— nó cấp phát định danh từ chuỗi sinh rồi trao cho cổng thanh toán, để lời gọi lại của cổng
này luôn tìm được hàng tương ứng kể cả khi lời gọi ấy về trước khi giao dịch cục bộ kịp kết
thúc. Ba khoá còn lại là *khoá tự nhiên* kiểu chuỗi và giữ nguyên bản chất chuỗi của chúng:
định danh thẻ trong `catalog`, định danh tuỳ chọn trong bảng dùng chung, và khoá chống ghi
trùng của bút toán tồn kho.

*Tham chiếu chéo lược đồ không dùng khoá ngoại.* Khoá ngoại chỉ được khai báo khi cả hai bảng
nằm trong cùng một lược đồ. Khi một bảng cần trỏ sang lược đồ khác, cột tham chiếu là một
`BIGINT` trần, không ràng buộc, kèm chú thích nói rõ nó trỏ đi đâu. Đây là cái giá bắt buộc của
nguyên tắc thứ nhất: một khoá ngoại xuyên lược đồ sẽ chính là thứ duy nhất không thể đi theo
mô-đun khi mô-đun đó tách ra. Tính toàn vẹn ở những chỗ ấy được giữ bằng ba cơ chế thay thế —
xoá mềm ở bảng bị trỏ tới, để lịch sử vẫn phân giải được; sao chép có chủ đích những giá trị
mà phía kia có thể thay đổi, chẳng hạn ảnh chụp địa chỉ giao hàng trong đơn hoặc điểm đánh giá
trung bình được đẩy sang bảng bài đăng; và khoá chống ghi trùng cho những thao tác đi qua hàng
đợi sự kiện vốn bảo đảm giao ít nhất một lần.

*Định danh mờ trên đường truyền.* Ở tầng miền, tầng cổng và tầng bộ điều hợp cơ sở dữ liệu,
định danh là số nguyên 64 bit trần. Nhưng trường định danh trong đối tượng truyền dữ liệu công
bố ra ngoài lại được mã hoá thành chuỗi dạng `lst_2h9qk4mfx7bd3`: một hoán vị Feistel có khoá
trên toàn dải số nguyên 64 bit, mã hoá base32 Crockford, kèm tiền tố riêng cho từng loại thực
thể. Cần nhấn mạnh rằng *đây không phải là kiểu của cột* — không có cột nào trong cơ sở dữ liệu
lưu chuỗi này. Việc chuyển đổi chỉ diễn ra ở đúng biên đối tượng truyền dữ liệu. Cơ chế này
phục vụ hai mục đích: người ngoài không dò được số lượng và tốc độ tăng bản ghi bằng cách đếm
số thứ tự, và tiền tố khiến một định danh dùng nhầm loại bị từ chối ngay ở khâu phân tích cú
pháp thay vì trở thành một truy vấn hợp lệ trên nhầm bảng. Vì mọi định danh đã công bố đều
phải phân giải được vĩnh viễn, tiền tố và khoá mã hoá là hằng số không bao giờ được đổi.

Bên cạnh bốn nguyên tắc trên, thiết kế còn tuân thủ một số quy ước hình thức được áp dụng nhất
quán trên cả 64 bảng.

#figure(
  kind: table,
  caption: [Quy ước đặt tên và quy ước hình thức áp dụng cho toàn bộ lược đồ],
  table(
    columns: (1fr, 2.6fr),
    align: (left + horizon, left + horizon),
    table.header([Đối tượng], [Quy ước và ví dụ]),
    [Tên bảng],
      [Danh từ số ít, `snake_case`, không mang tiền tố lược đồ: `listing`, `payment_session`, `wallet_transaction`.],
    [Tên cột],
      [`snake_case`. Cột thời điểm kết thúc bằng `_at` và luôn kiểu `TIMESTAMPTZ`; cột khoá tham chiếu kết thúc bằng `_id`; cột luận lý mang tiền tố `is_`.],
    [Tên ràng buộc],
      [`<bảng>_pkey` cho khoá chính, `<bảng>_<cột>_key` cho ràng buộc duy nhất, `<bảng>_<cột>_fkey` cho khoá ngoại, và một tên mô tả quy tắc cho ràng buộc kiểm tra: `order_payout_needs_receipt`, `stock_committed_within_quantity`.],
    [Tên chỉ mục],
      [`<bảng>_<các cột>_idx`, hoặc một tên mô tả truy vấn mà chỉ mục phục vụ khi chỉ mục là chỉ mục bộ phận: `refund_overdue_idx`, `order_payout_due_idx`.],
    [Định danh trong câu lệnh định nghĩa],
      [Mọi định danh do lược đồ sở hữu đều được đặt trong dấu nháy kép. Từ khoá SQL, tên kiểu dựng sẵn và tên phần mở rộng thì không.],
    [Giá trị kiểu liệt kê],
      [`kebab-case` viết thường, cả với kiểu liệt kê của PostgreSQL lẫn với cột chuỗi dùng như kiểu liệt kê: `awaiting-seller-review`, `buyer-checkout`, `escrow-hold`.],
    [Tiền tệ],
      [Số tiền là `BIGINT` tính theo đơn vị nhỏ nhất của loại tiền, không dùng số thực. Mã tiền tệ là `VARCHAR(3)` theo ISO 4217, kèm ràng buộc kiểm tra dạng ba chữ hoa.],
    [Cột tuỳ chọn],
      [Một cột cho phép rỗng tương ứng một con trỏ ở tầng miền, và giá trị rỗng là cách duy nhất biểu diễn "chưa có". Không dùng giá trị mặc định giả để thay cho rỗng.],
  ),
)

Một quy ước cuối cùng, và là quy ước tốn nhiều dòng định nghĩa nhất, là *ràng buộc ở tầng cơ sở
dữ liệu được giữ lại kể cả khi tầng dịch vụ đã kiểm tra cùng điều đó*. Lý do rất đơn giản:
ràng buộc vẫn đúng khi dịch vụ sai. Thiết kế sử dụng bốn dạng ràng buộc theo tinh thần này.
Ràng buộc kiểm tra diễn đạt những quy tắc liên cột mà một trạng thái sai lẽ ra không được phép
tồn tại, chẳng hạn tiền chỉ được giải ngân khi người mua đã xác nhận nhận hàng. Chỉ mục duy
nhất bộ phận diễn đạt những quy tắc "nhiều nhất một" có điều kiện, chẳng hạn mỗi tài khoản chỉ
có một địa chỉ giao hàng mặc định, mỗi đơn chỉ có một hồ sơ hoàn tiền đang mở, mỗi bài đăng chỉ
có một biến thể hiển thị. Cột phiên bản trên các thể tổng hợp thực hiện khoá lạc quan: mỗi lần
ghi đều kèm điều kiện phiên bản phải khớp với phiên bản đã đọc, nên một lệnh dựng trên bản đọc
cũ bị từ chối thay vì ghi đè lên thay đổi mà nó chưa từng thấy. Cuối cùng, những chỗ không có
thể tổng hợp để gắn phiên bản thì dùng ghi có điều kiện: câu lệnh cập nhật nêu đích danh trạng
thái mà nó chấp nhận chuyển đi, và số hàng bị tác động chính là câu trả lời cho việc lệnh có
thành công hay không.

=== Ước lượng khối lượng dữ liệu

Yếu tố dẫn dắt `AD-10` đặt khối lượng mục tiêu ở năm trăm người dùng đồng thời và năm nghìn đơn
mỗi ngày. Từ hai con số ấy suy ra được tốc độ sinh hàng của từng bảng, và chính phép suy ra này
— chứ không phải cảm tính — quyết định bảng nào cần phân mảnh theo thời gian, bảng nào cần
chính sách xoá, và bảng nào cứ để nguyên là đủ. Cần nói rõ rằng đây là *ước lượng thiết kế* suy
ra từ mục tiêu, không phải số đo trên hệ thống đang chạy; giá trị của chúng nằm ở bậc độ lớn.

Các hệ số quy đổi được dùng nhất quán: một đơn hàng trung bình có khoảng 1,3 mục hàng và đúng
một chặng vận chuyển; khoảng một phần tư số lượt thanh toán không được trả tiền và hết hạn, nên
mỗi đơn thành công tương ứng khoảng 1,3 phiên thanh toán; một đơn sinh ra bốn bút toán ví (ba
chân lúc giữ ký quỹ, một chân lúc giải ngân); và khoảng bốn phần trăm số đơn phát sinh hồ sơ
hoàn tiền.

#figure(
  kind: table,
  caption: [Ước lượng tốc độ sinh hàng và khối lượng sau một năm ở khối lượng mục tiêu `AD-10`],
  table(
    columns: (1.05fr, 1.15fr, 0.75fr, 1.5fr),
    align: (left + top, left + top, right + top, left + top),
    table.header([Bảng], [Cách suy ra], [Sau 1 năm], [Hệ quả thiết kế]),

    [`order.order`], [5.000 hàng mỗi ngày], [\~1,8 triệu],
    [Bảng thường; các truy vấn nền đều đi qua chỉ mục bộ phận nên chi phí tỉ lệ với phần việc còn lại chứ không với kích thước bảng.],
    [`order.item`], [1,3 mục cho mỗi đơn], [\~2,4 triệu], [Bảng thường.],
    [`order.transport`], [1 chặng mỗi đơn, cộng chặng trả hàng], [\~1,9 triệu], [Bảng thường.],
    [`order.refund`], [4% số đơn], [\~73 nghìn], [Nhỏ; chỉ mục bộ phận trên hạn chót đủ cho vòng quét.],
    [`finance.payment_session`], [1,3 phiên mỗi đơn], [\~2,4 triệu],
    [Bảng thường; chỉ mục bộ phận chỉ phủ các phiên chưa kết thúc.],
    [`finance.transaction`], [\~1,1 chặng mỗi phiên], [\~2,6 triệu], [Bảng thường.],
    [`finance.wallet_transaction`], [4 bút toán mỗi đơn], [\~7,3 triệu],
    [Bảng chỉ-thêm-mới, không bao giờ xoá; đây là bảng nghiệp vụ lớn nhất và là lý do sổ cái mang sẵn số dư trước và sau, để đối soát không phải cộng dồn từ đầu.],
    [`chat.message`], [\~15 tin mỗi đơn, cộng phiếu hỗ trợ], [\~28 triệu],
    [*Bảng phân mảnh theo thời gian*, cố ý không có chính sách xoá vì tin nhắn là bằng chứng trong tranh chấp.],
    [`account.notification`], [\~10 thông báo mỗi đơn], [\~9 triệu ở trạng thái ổn định],
    [*Bảng phân mảnh theo thời gian*, giữ 180 ngày, nên khối lượng hội tụ chứ không tăng mãi.],
    [`trust.feedback`], [2 đánh giá mỗi đơn], [\~3,6 triệu], [Bảng thường.],
    [`catalog.listing`], [Tăng theo số người bán, không theo số đơn], [\~200 nghìn],
    [Nhỏ so với phần còn lại, nhưng là bảng bị *đọc* nhiều nhất; ba chỉ mục tìm kiếm nằm ở đây.],
    [`catalog.listing_embedding`], [1 hàng mỗi bài đăng], [\~200 nghìn],
    [Véc-tơ 1024 chiều chiếm khoảng 4 KB mỗi hàng, nên bảng này lớn hơn bảng bài đăng về dung lượng dù bằng nhau về số hàng.],
    [`account.account`], [500 người đồng thời tương ứng vài chục nghìn tài khoản], [\~100 nghìn], [Bảng thường.],
    [Nhật ký kiểm toán (18 hiện thân)], [\~8 sự việc mỗi đơn, cộng thao tác ngoài đơn], [\~15 triệu],
    [Chỉ-thêm-mới; nằm trong lược đồ của từng mô-đun nên chính sách lưu trữ đặt được riêng cho từng nhóm.],
    [`observability.http_requests`], [\~50 yêu cầu mỗi giây], [\~130 triệu ở trạng thái ổn định],
    [*Bảng phân mảnh theo thời gian*, mảnh một ngày, nén sau bảy ngày, giữ 30 ngày; đây là lý do các bảng điều khiển đọc khung nhìn kết tụ theo phút chứ không đọc dữ liệu thô.],
  ),
)

Ba kết luận rút ra từ bảng trên và đều đã được phản ánh vào thiết kế. Thứ nhất, *các bảng lớn
nhất đều không phải bảng nghiệp vụ*: bốn bảng đứng đầu về số hàng là dữ liệu giám sát, tin
nhắn, nhật ký kiểm toán và sổ cái ví — và đúng ba trong bốn thứ đó hoặc được phân mảnh theo
thời gian, hoặc chỉ được ghi thêm và không bao giờ sửa. Thứ hai, *khối lượng ở quy mô này không
đòi hỏi phân mảnh ngang theo khoá*, nên thiết kế không trả giá cho một cơ chế mà giai đoạn này
chưa cần; ranh giới lược đồ giữ sẵn đường tách theo mô-đun cho lúc con số thay đổi. Thứ ba,
*mọi vòng quét nền đều phải đi qua chỉ mục bộ phận*, vì một lượt quét toàn bảng trên bảng đơn
hàng sẽ chấp nhận được ở tháng đầu và không chấp nhận được ở năm thứ hai — đây chính là lý do
dấu hiệu "đã xong" được ưa hơn một cửa sổ thời gian ở khắp thiết kế.

=== Sơ đồ quan hệ thực thể mức vật lý

Vì tổng số bảng lớn, sơ đồ quan hệ thực thể được tách thành ba lát cắt theo cụm nghiệp vụ. Ký
hiệu thống nhất trên cả ba lát cắt: đường liền nét là khoá ngoại thật, được cơ sở dữ liệu bảo
đảm, và do đó hai đầu của nó luôn nằm trong cùng một lược đồ; đường nét đứt là tham chiếu logic
chéo lược đồ, chỉ là một cột `BIGINT` mà tầng dịch vụ chịu trách nhiệm giữ đúng. Nhãn bản số
đọc theo quy ước chân quạ, trong đó dấu hỏi biểu thị đầu tuỳ chọn.

#fig(
  [Sơ đồ quan hệ thực thể mức vật lý — lát cắt `account` và `catalog`],
  spacing: (24mm, 11mm),
  edge-stroke: 1pt + blue-s,
  nent((0, 0.6), <p1-oauth>, [OAUTH\_IDENTITY]),
  nent((0, 1.5), <p1-dev>, [DEVICE]),
  nent((0.9, 2.2), <p1-acc>, [ACCOUNT]),
  nent((0, 3.2), <p1-contact>, [CONTACT]),
  nent((0, 4.1), <p1-idoc>, [IDENTITY\_DOCUMENT]),
  nent((1.8, 0.6), <p1-noti>, [NOTIFICATION]),
  nent((1.8, 1.5), <p1-npref>, [NOTIFICATION\_PREFERENCE]),
  nent((1.8, 3.2), <p1-follow>, [FOLLOW]),
  nent((3.1, 0), <p1-cat>, [CATEGORY]),
  nent((3.1, 1.2), <p1-lst>, [LISTING]),
  nent((3.1, 2.4), <p1-var>, [VARIANT]),
  nent((3.1, 3.5), <p1-stock>, [STOCK]),
  nent((3.1, 4.4), <p1-smv>, [STOCK\_MOVEMENT]),
  nent((4.4, 0.4), <p1-tag>, [TAG]),
  nent((4.4, 1.2), <p1-ltag>, [LISTING\_TAG]),
  nent((4.4, 2.4), <p1-fav>, [FAVORITE]),
  nent((4.4, 3.5), <p1-emb>, [LISTING\_EMBEDDING]),
  edge(<p1-oauth>, <p1-acc>, "n-1", text(size: 7pt)[liên kết]),
  edge(<p1-dev>, <p1-acc>, "n-1", text(size: 7pt)[thiết bị]),
  edge(<p1-contact>, <p1-acc>, "n-1", text(size: 7pt)[địa chỉ]),
  edge(<p1-idoc>, <p1-acc>, "n-1", text(size: 7pt)[giấy tờ]),
  edge(<p1-noti>, <p1-acc>, "n-1", text(size: 7pt)[thông báo]),
  edge(<p1-npref>, <p1-acc>, "n-1", text(size: 7pt)[tuỳ chọn kênh]),
  edge(<p1-follow>, <p1-acc>, "n-1", text(size: 7pt)[theo dõi hai đầu]),
  edge(<p1-cat>, <p1-cat>, "n-1?", bend: 130deg, text(size: 7pt)[danh mục cha]),
  edge(<p1-lst>, <p1-cat>, "n-1", text(size: 7pt)[thuộc]),
  edge(<p1-var>, <p1-lst>, "n-1", text(size: 7pt)[biến thể]),
  edge(<p1-stock>, <p1-var>, "1-1", text(size: 7pt)[tồn kho]),
  edge(<p1-smv>, <p1-var>, "n-1", text(size: 7pt)[bút toán kho]),
  edge(<p1-ltag>, <p1-lst>, "n-1", text(size: 7pt)[gắn thẻ]),
  edge(<p1-ltag>, <p1-tag>, "n-1", text(size: 7pt)[thẻ]),
  edge(<p1-fav>, <p1-lst>, "n-1", text(size: 7pt)[yêu thích]),
  edge(<p1-emb>, <p1-lst>, "1-1", text(size: 7pt)[véc-tơ]),
  edge(<p1-lst>, <p1-acc>, "n-1", stroke: (dash: "dashed"), text(size: 7pt)[người bán]),
  edge(<p1-fav>, <p1-acc>, "n-1", stroke: (dash: "dashed"), bend: 22deg, text(size: 7pt)[người lưu]),
)

#fig(
  [Sơ đồ quan hệ thực thể mức vật lý — lát cắt `order` và `finance`],
  spacing: (26mm, 12mm),
  edge-stroke: 1pt + blue-s,
  nent((0, 0), <p2-cart>, [CART\_ITEM]),
  nent((0, 1.1), <p2-draft>, [DRAFT\_ORDER]),
  nent((0, 2.2), <p2-offer>, [OFFER]),
  nent((0, 3.9), <p2-refund>, [REFUND]),
  nent((1.4, 1.1), <p2-item>, [ITEM]),
  nent((1.4, 2.5), <p2-order>, [ORDER]),
  nent((1.4, 3.9), <p2-trans>, [TRANSPORT]),
  nent((2.9, 0.4), <p2-sess>, [PAYMENT\_SESSION]),
  nent((2.9, 1.6), <p2-tx>, [TRANSACTION]),
  nent((2.9, 2.9), <p2-wallet>, [WALLET]),
  nent((2.9, 4.1), <p2-wtx>, [WALLET\_TRANSACTION]),
  nent((4.3, 2.9), <p2-bank>, [BANK\_ACCOUNT]),
  nent((4.3, 4.1), <p2-tax>, [TAX\_INFO]),
  nr((4.3, 1.1), [ACCOUNT \ #text(size: 7pt)[(lược đồ `account`)]], name: <p2-acc>),
  edge(<p2-item>, <p2-draft>, "n-1?", text(size: 7pt)[chốt từ phiên]),
  edge(<p2-item>, <p2-offer>, "1-1?", text(size: 7pt)[chốt từ thương lượng]),
  edge(<p2-item>, <p2-order>, "n-1?", text(size: 7pt)[thuộc đơn]),
  edge(<p2-order>, <p2-draft>, "1-1?", text(size: 7pt)[nguồn]),
  edge(<p2-order>, <p2-offer>, "1-1?", bend: -20deg, text(size: 7pt)[nguồn]),
  edge(<p2-order>, <p2-trans>, "1-1", text(size: 7pt)[vận đơn giao]),
  edge(<p2-refund>, <p2-order>, "n-1", text(size: 7pt)[hoàn tiền]),
  edge(<p2-refund>, <p2-trans>, "1-1?", text(size: 7pt)[chặng trả hàng]),
  edge(<p2-tx>, <p2-sess>, "n-1", text(size: 7pt)[bút toán của]),
  edge(<p2-tx>, <p2-tx>, "1-1?", bend: 130deg, text(size: 7pt)[đảo ứng]),
  edge(<p2-wtx>, <p2-wallet>, "n-1", text(size: 7pt)[biến động ví]),
  edge(<p2-item>, <p2-sess>, "n-1", stroke: (dash: "dashed"), text(size: 7pt)[phiên thanh toán]),
  edge(<p2-offer>, <p2-sess>, "1-1?", stroke: (dash: "dashed"), text(size: 7pt)[phiên thanh toán]),
  edge(<p2-cart>, <p2-acc>, "n-1", stroke: (dash: "dashed"), bend: -28deg, text(size: 7pt)[chủ giỏ]),
  edge(<p2-order>, <p2-acc>, "n-1", stroke: (dash: "dashed"), text(size: 7pt)[mua / bán]),
  edge(<p2-wallet>, <p2-acc>, "n-1", stroke: (dash: "dashed"), text(size: 7pt)[chủ ví]),
  edge(<p2-bank>, <p2-acc>, "n-1", stroke: (dash: "dashed"), text(size: 7pt)[chủ tài khoản]),
  edge(<p2-tax>, <p2-acc>, "1-1", stroke: (dash: "dashed"), text(size: 7pt)[thông tin thuế]),
)

#fig(
  [Sơ đồ quan hệ thực thể mức vật lý — lát cắt `trust`, `chat`, `observability` và các bảng dùng chung],
  spacing: (26mm, 12mm),
  edge-stroke: 1pt + blue-s,
  nent((0, 0), <p3-ticket>, [TICKET]),
  nent((0, 1.3), <p3-fb>, [FEEDBACK]),
  nent((0, 2.5), <p3-rev>, [REVIEW]),
  nent((0, 3.9), <p3-vote>, [REVIEW\_VOTE]),
  nent((1.4, 3.2), <p3-reply>, [REVIEW\_REPLY]),
  nent((1.4, 1.9), <p3-rep>, [REPUTATION]),
  nent((1.4, 0.7), <p3-oo>, [ORDER\_OUTCOME]),
  nent((2.8, 0), <p3-conv>, [CONVERSATION]),
  nent((2.8, 1.2), <p3-msg>, [MESSAGE]),
  nent((4.2, 0.2), <p3-audit>, [AUDIT\_LOG]),
  nent((4.2, 1.4), <p3-res>, [RESOURCE]),
  nent((4.2, 2.5), <p3-opt>, [OPTION]),
  nent((2.8, 3.4), <p3-http>, [HTTP\_REQUESTS]),
  nent((2.8, 4.3), <p3-prov>, [PROVIDER\_CALLS]),
  nent((4.2, 3.7), <p3-biz>, [BUSINESS\_EVENTS]),
  nent((4.2, 4.6), <p3-rt>, [RUNTIME\_METRICS]),
  edge(<p3-reply>, <p3-rev>, "n-1", text(size: 7pt)[trả lời]),
  edge(<p3-vote>, <p3-rev>, "n-1", text(size: 7pt)[bình chọn]),
  edge(<p3-msg>, <p3-conv>, "n-1", text(size: 7pt)[tin nhắn]),
  edge(<p3-opt>, <p3-res>, "n-1?", text(size: 7pt)[biểu trưng]),
  edge(<p3-ticket>, <p3-conv>, "1-1?", stroke: (dash: "dashed"), text(size: 7pt)[luồng phiếu]),
  edge(<p3-fb>, <p3-rep>, "n-1", stroke: (dash: "dashed"), text(size: 7pt)[cộng dồn]),
  edge(<p3-rev>, <p3-rep>, "n-1", stroke: (dash: "dashed"), text(size: 7pt)[cộng dồn]),
  edge(<p3-oo>, <p3-rep>, "n-1", stroke: (dash: "dashed"), text(size: 7pt)[đếm kết cục]),
)

Bảng dưới đây liệt kê các tham chiếu logic chéo lược đồ quan trọng nhất, tức những chỗ mà cơ sở
dữ liệu *không* bảo đảm toàn vẹn và tầng dịch vụ phải tự giữ.

#figure(
  kind: table,
  caption: [Các tham chiếu logic chéo lược đồ và cơ chế giữ toàn vẹn thay cho khoá ngoại],
  table(
    columns: (1.1fr, 0.8fr, 2.6fr),
    align: (left + horizon, left + horizon, left + horizon),
    inset: (x: 5pt, y: 5pt),
    table.header([Bảng và cột tham chiếu], [Lược đồ sở hữu], [Cơ chế giữ toàn vẹn]),
    [`order.item` \ `listing_id`, `variant_id`], [`catalog`],
      [Bài đăng và biến thể xoá mềm, nên lịch sử đơn hàng vẫn phân giải được tên và ảnh sau khi người bán gỡ tin.],
    [`order.item` \ `payment_session_id`], [`finance`],
      [Phiên thanh toán được cấp định danh trước khi chèn, nên mục hàng luôn trỏ tới một phiên đã tồn tại.],
    [`order.item` \ `transport_option`], [Bảng dùng chung],
      [Lưu chuỗi định danh tuỳ chọn bất biến; hàng tuỳ chọn chỉ được xoá mềm, nên đơn cũ vẫn đọc được tên hãng vận chuyển.],
    [`finance.transaction` \ `payment_option`], [Bảng dùng chung],
      [Tương tự trên, cho kênh thanh toán đã quyết toán.],
    [`catalog.listing` \ `cached_rating`, \ `cached_review_count`], [`trust`],
      [Giá trị sao chép, do `trust` tính lại và đẩy sang mỗi khi một đánh giá được ghi, vì hai bảng nằm ở hai lược đồ nên không thể kết nối.],
    [`trust.review` \ `listing_id`, `seller_id`], [`catalog`, `account`],
      [`seller_id` được đóng băng từ đơn hàng tại thời điểm viết đánh giá, để điểm uy tín không phụ thuộc việc bài đăng còn đọc được hay không.],
    [`trust.ticket` \ `conversation_id`], [`chat`],
      [Cho phép rỗng và mang ràng buộc duy nhất: phiếu được ghi trước, luồng hội thoại được mở ngay sau đó, và nếu thất bại thì lần đọc phiếu kế tiếp sẽ mở lại đúng luồng ấy.],
    [`chat.conversation` \ `ticket_id`], [`trust`],
      [Nửa đối xứng của quan hệ trên; chỉ mục duy nhất bộ phận trên cột này là thứ khiến thao tác mở luồng trở nên có thể thử lại.],
    [`finance.wallet` \ `account_id`], [`account`],
      [Ví được tạo theo yêu cầu ở lần chuyển tiền đầu tiên; sổ cái ví có khoá ngoại thật trỏ về ví vì cùng lược đồ.],
    [Mọi bảng tài nguyên \ `uploaded_by_id`], [`account`],
      [Bảng tài nguyên tồn tại một bản trong mỗi lược đồ, nên tệp thuộc về mô-đun đã nhận nó và không có đường dẫn tải lên dùng chung nào cần đồng bộ.],
  ),
)

Từ đây tới hết mục, mỗi lược đồ được trình bày theo cùng một khuôn: một đoạn nói về vai trò và
những quyết định thiết kế đáng chú ý của lược đồ đó, một bảng từ điển dữ liệu cho các bảng
chính, rồi toàn bộ mã định nghĩa dữ liệu của lược đồ. Mã định nghĩa được trích nguyên văn từ
các tệp di trú trong mã nguồn, chỉ lược bỏ phần chú thích tiếng Anh giải thích lý do — vì phần
lý do ấy đã được diễn đạt bằng tiếng Việt trong văn xuôi — và ngắt dòng những câu quá dài cho
vừa khổ giấy. Dòng chú thích duy nhất còn giữ lại là dòng nêu tên tệp di trú, để đối chiếu
được với mã nguồn. Bảng từ điển chỉ liệt kê những cột mang ý nghĩa nghiệp vụ hoặc tham gia vào
một quy tắc; đặc tả đầy đủ tới từng cột, từng ràng buộc và từng chỉ mục nằm ở chính khối mã
bên dưới nó.

=== Lược đồ `account`

Lược đồ `account` giữ mọi thứ trả lời câu hỏi "người này là ai": định danh đăng nhập, các liên
kết đăng nhập qua nhà cung cấp bên thứ ba, phần hồ sơ hiển thị công khai, sổ địa chỉ, thiết bị
nhận thông báo đẩy, dòng thông báo trong ứng dụng cùng tuỳ chọn kênh nhận, đồ thị theo dõi
người bán, và hồ sơ xác minh giấy tờ tuỳ thân phục vụ rút tiền. Trong mô hình chợ ngang hàng,
một tài khoản vừa là người mua vừa là người bán, nên lược đồ này không phân biệt hai vai ở mức
bảng.

Quyết định đáng chú ý nhất ở đây là *hợp nhất bảng hồ sơ vào bảng tài khoản*. Tên hiển thị là
bắt buộc, được chèn trong cùng một câu lệnh với hàng tài khoản, được đọc bởi hầu như mọi lệnh
và được ghi bởi cùng một câu lệnh cập nhật; tách nó ra một bảng một-một chỉ mua thêm một phép
kết nối và một lần ghi thứ hai. Ngược lại, sổ địa chỉ *không* được gộp: quy tắc "mỗi loại chỉ
có một địa chỉ mặc định" chỉ trải trên tập địa chỉ chứ không liên quan tới hàng tài khoản, nên
gộp vào sẽ khiến mỗi lần đổi tên hiển thị phải nạp thêm hàng chục cột địa chỉ.

Bảng tài khoản mang cột `version` để khoá lạc quan, và ràng buộc `account_has_identifier` bảo
đảm mỗi tài khoản luôn còn ít nhất một cách để đăng nhập — điều này quan trọng vì mật khẩu được
phép rỗng đối với tài khoản chỉ đăng nhập bằng liên kết. Vai `support` được thêm bằng một tệp
di trú riêng cùng một chỉ mục duy nhất bộ phận, để câu hỏi "tài khoản hỗ trợ là tài khoản nào"
có đúng một câu trả lời và không phụ thuộc vào một tên đăng nhập mà bất kỳ ai cũng có thể đăng
ký trước. Bảng thông báo là một bảng phân mảnh theo thời gian với chính sách giữ 180 ngày, nên
khoá chính của nó phải chứa cột phân mảnh.

#figure(
  kind: table,
  caption: [Từ điển dữ liệu rút gọn của lược đồ `account`],
  table(
    columns: (1.2fr, 1.05fr, 1.6fr, 1.5fr),
    align: (left + horizon, left + horizon, left + horizon, left + horizon),
    inset: (x: 5pt, y: 5pt),
    table.header([Cột], [Kiểu], [Ý nghĩa], [Ràng buộc]),

    table.cell(colspan: 4)[*Bảng* `account`],
    [`id`], [`BIGINT`], [Khoá thay thế], [Khoá chính, sinh tự động],
    [`version`], [`BIGINT`], [Số hiệu phiên bản của thể tổng hợp], [Mặc định 1, dùng cho khoá lạc quan],
    [`status`], [`account_status`], [Trạng thái vòng đời], [`active` hoặc `suspended`, mặc định `active`],
    [`role`], [`account_role`], [Vai phân quyền], [`user`, `moderator`, `admin`, `support`],
    [`phone`], [`VARCHAR(16)`], [Số điện thoại chuẩn E.164], [Duy nhất, kiểm tra dạng],
    [`email`], [`VARCHAR(255)`], [Địa chỉ thư điện tử], [Duy nhất, bắt buộc viết thường],
    [`username`], [`VARCHAR(100)`], [Tên đăng nhập], [Duy nhất, bắt buộc viết thường],
    [`password_hash`], [`VARCHAR(255)`], [Giá trị băm bcrypt], [Rỗng khi tài khoản chỉ đăng nhập liên kết],
    [`name`], [`VARCHAR(100)`], [Tên hiển thị, cũng là tên gian hàng], [Bắt buộc, có chỉ mục trigram],
    [`country`, `locale`], [`VARCHAR(2)`, `VARCHAR(10)`], [Quốc gia theo ISO 3166-1 và ngôn ngữ theo BCP 47], [Bắt buộc; mỗi cột có một ràng buộc kiểm tra dạng riêng],
    [`timezone`], [`VARCHAR(64)`], [Tên múi giờ theo danh mục IANA], [Bắt buộc; không có ràng buộc kiểm tra dạng, vì danh mục IANA thay đổi theo thời gian],
    [`suspended_until`, `suspension_reason`], [`TIMESTAMPTZ`, `TEXT`], [Chi tiết đình chỉ], [Chỉ tồn tại khi trạng thái là `suspended`],

    table.cell(colspan: 4)[*Bảng* `oauth_identity`],
    [`provider`, `provider_uid`], [`VARCHAR`], [Nhà cung cấp và định danh chủ thể bên đó], [Duy nhất theo cặp],
    [`account_id`], [`BIGINT`], [Tài khoản được liên kết], [Khoá ngoại, xoá lan truyền; duy nhất theo cặp với `provider`],

    table.cell(colspan: 4)[*Bảng* `device`],
    [`push_token`], [`TEXT`], [Mã đăng ký nhận đẩy của một lần cài đặt], [Duy nhất toàn cục],
    [`platform`], [`device_`\ `platform`], [Nền tảng thiết bị], [`ios`, `android`, `web`],
    [`last_seen_at`], [`TIMESTAMPTZ`], [Lần cuối thiết bị hoạt động], [Dùng để dọn mã cũ],

    table.cell(colspan: 4)[*Bảng* `contact`],
    [`full_name`, `phone`], [`VARCHAR`], [Người nhận và số liên hệ], [Số điện thoại kiểm tra dạng E.164],
    [`is_default_`\ `delivery`, `is_default_pickup`], [`BOOLEAN`], [Mặc định nhận hàng và mặc định lấy hàng], [Chỉ mục duy nhất bộ phận: mỗi tài khoản một mặc định mỗi loại],
    [`province_code`, `district_code`, `ward_code`], [`VARCHAR(20)`], [Mã đơn vị hành chính, dùng gọi hãng vận chuyển], [Mã quận huyện có thể rỗng, nhưng phải rỗng cùng tên quận huyện],
    [`provider_codes`], [`JSONB`], [Mã địa bàn riêng của từng hãng vận chuyển], [Mặc định đối tượng rỗng],
    [`location`], [`geography`], [Toạ độ điểm, dùng cho truy vấn khoảng cách], [Chỉ mục GiST],

    table.cell(colspan: 4)[*Bảng* `notification`],
    [`id`, `created_at`], [`BIGINT`, `TIMESTAMPTZ`], [Khoá chính ghép], [Cột thời gian phải nằm trong khoá vì bảng phân mảnh theo thời gian],
    [`category`], [`notification_`\ `category`], [Chủ đề, cũng là khoá tra tuỳ chọn], [Kiểu liệt kê năm giá trị],
    [`read_at`], [`TIMESTAMPTZ`], [Thời điểm đọc], [Rỗng nghĩa là chưa đọc; có chỉ mục bộ phận cho huy hiệu chưa đọc],
    [`scheduled_at`], [`TIMESTAMPTZ`], [Thời điểm gửi hẹn trước], [Rỗng nghĩa là gửi ngay],

    table.cell(colspan: 4)[*Bảng* `notification_preference`],
    [`account_id`, `category`, `channel`], [Bộ ba], [Khoá chính], [Bảng thưa: không có hàng nghĩa là dùng mặc định của miền],

    table.cell(colspan: 4)[*Bảng* `follow`],
    [`follower_id`, `followee_id`], [`BIGINT`], [Người theo dõi và người được theo dõi], [Khoá chính ghép, cấm tự theo dõi],

    table.cell(colspan: 4)[*Bảng* `identity_document`],
    [`doc_type`], [`identity_`\ `document_type`], [Loại giấy tờ], [Căn cước, hộ chiếu hoặc giấy phép lái xe],
    [`provider`, `provider_ref`], [`VARCHAR`, `TEXT`], [Nhà cung cấp xác minh và mã hồ sơ bên đó], [Duy nhất theo cặp],
    [`front_resource_id`, `back_resource_id`, `selfie_`\ `resource_id`], [`BIGINT`], [Ba ảnh chụp, lưu bằng tham chiếu tài nguyên], [Khoá ngoại, đặt rỗng khi tài nguyên bị dọn],
    [`status`], [`identity_`\ `status`], [Kết luận xác minh], [Ngày xác minh và lý do từ chối phải khớp trạng thái],
    [`expires_at`], [`TIMESTAMPTZ`], [Hạn của giấy tờ], [Có chỉ mục bộ phận cho công việc xác minh lại],
  ),
)

```sql
-- account/migrations/001_init.sql

CREATE EXTENSION IF NOT EXISTS postgis
WITH
  SCHEMA public;

CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE EXTENSION IF NOT EXISTS pg_trgm
WITH
  SCHEMA public;

CREATE TYPE "account_status" AS ENUM ('active', 'suspended');
CREATE TYPE "account_role" AS ENUM ('user', 'moderator', 'admin');
CREATE TYPE "profile_gender" AS ENUM ('male', 'female', 'other');
CREATE TYPE "contact_address_type" AS ENUM ('home', 'work');
CREATE TYPE "device_platform" AS ENUM ('ios', 'android', 'web');

CREATE TYPE "identity_document_type" AS ENUM ('national-id', 'passport',
    'driver-license');
CREATE TYPE "identity_status" AS ENUM ('pending', 'verified', 'rejected');

CREATE TYPE "notification_type" AS ENUM ('in-app', 'push', 'email', 'sms');
CREATE TYPE "notification_category" AS ENUM ('order', 'promotion', 'system', 'chat',
    'social');

CREATE TABLE IF NOT EXISTS "account" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "version" BIGINT NOT NULL DEFAULT 1,
    "status" "account_status" NOT NULL DEFAULT 'active',
    "role" "account_role" NOT NULL DEFAULT 'user',
    "phone" VARCHAR(16),
    "email" VARCHAR(255),
    "username" VARCHAR(100),
    "password_hash" VARCHAR(255),

    "email_verified" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    "suspended_until" TIMESTAMPTZ,
    "suspension_reason" TEXT,

    "name" VARCHAR(100) NOT NULL,
    "description" TEXT,
    "gender" "profile_gender",
    "date_of_birth" DATE,
    "avatar_resource_id" BIGINT,
    "country" VARCHAR(2) NOT NULL,
    "locale" VARCHAR(10) NOT NULL,
    "timezone" VARCHAR(64) NOT NULL,

    CONSTRAINT "account_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "account_phone_key" UNIQUE ("phone"),
    CONSTRAINT "account_email_key" UNIQUE ("email"),
    CONSTRAINT "account_username_key" UNIQUE ("username"),
    CONSTRAINT "account_has_identifier" CHECK (
        COALESCE("phone", "email", "username") IS NOT NULL
    ),
    CONSTRAINT "account_phone_e164" CHECK ("phone" ~ '^\+[1-9][0-9]{7,14}$'),
    CONSTRAINT "account_email_lowercase" CHECK ("email" = lower("email")),
    CONSTRAINT "account_username_lowercase" CHECK ("username" = lower("username")),
    CONSTRAINT "account_suspension_requires_suspended" CHECK (
        "status" = 'suspended'
        OR ("suspended_until" IS NULL AND "suspension_reason" IS NULL)
    ),
    CONSTRAINT "account_country_format" CHECK ("country" ~ '^[A-Z]{2}$'),
    CONSTRAINT "account_locale_format" CHECK ("locale" ~ '^[a-z]{2}(-[A-Z]{2})?$'),
    CONSTRAINT "account_date_of_birth_sane" CHECK ("date_of_birth" > DATE
        '1900-01-01')
);
CREATE INDEX IF NOT EXISTS "account_name_trgm_idx" ON "account" USING gin ("name"
    gin_trgm_ops);
CREATE INDEX IF NOT EXISTS "account_suspension_expiring_idx"
    ON "account" ("suspended_until")
    WHERE "status" = 'suspended' AND "suspended_until" IS NOT NULL;

CREATE TABLE IF NOT EXISTS "oauth_identity" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "account_id" BIGINT NOT NULL,
    "provider" VARCHAR(30) NOT NULL,
    "provider_uid" VARCHAR(255) NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "oauth_identity_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "oauth_identity_provider_provider_uid_key" UNIQUE ("provider",
        "provider_uid"),
    CONSTRAINT "oauth_identity_account_id_provider_key" UNIQUE ("account_id",
        "provider"),

    CONSTRAINT "oauth_identity_account_id_fkey" FOREIGN KEY ("account_id")
        REFERENCES "account" ("id") ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS "device" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "account_id" BIGINT NOT NULL,
    "platform" "device_platform" NOT NULL,
    "push_token" TEXT NOT NULL,
    "last_seen_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "device_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "device_push_token_key" UNIQUE ("push_token"),

    CONSTRAINT "device_account_id_fkey" FOREIGN KEY ("account_id")
        REFERENCES "account" ("id") ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS "device_account_id_idx" ON "device" ("account_id");

CREATE TABLE IF NOT EXISTS "contact" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "account_id" BIGINT NOT NULL,
    "full_name" VARCHAR(100) NOT NULL,
    "phone" VARCHAR(16) NOT NULL,
    "phone_verified" BOOLEAN NOT NULL DEFAULT false,
    "address_type" "contact_address_type" NOT NULL,
    "is_default_delivery" BOOLEAN NOT NULL DEFAULT false,
    "is_default_pickup" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    "country" VARCHAR(2) NOT NULL,
    "province_code" VARCHAR(20) NOT NULL,
    "province_name" VARCHAR(100) NOT NULL,
    "district_code" VARCHAR(20),
    "district_name" VARCHAR(100),
    "ward_code" VARCHAR(20) NOT NULL,
    "ward_name" VARCHAR(100) NOT NULL,
    "postal_code" VARCHAR(20),
    "provider_codes" JSONB NOT NULL DEFAULT '{}',

    "address" VARCHAR(255) NOT NULL,
    "address_detail" VARCHAR(255),
    "location" geography(Point, 4326),

    CONSTRAINT "contact_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "contact_country_format" CHECK ("country" ~ '^[A-Z]{2}$'),
    CONSTRAINT "contact_phone_e164" CHECK ("phone" ~ '^\+[1-9][0-9]{7,14}$'),
    CONSTRAINT "contact_district_code_name_together" CHECK (
        ("district_code" IS NULL) = ("district_name" IS NULL)
    ),

    CONSTRAINT "contact_account_id_fkey" FOREIGN KEY ("account_id")
        REFERENCES "account" ("id") ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS "contact_account_id_idx" ON "contact" ("account_id");
CREATE UNIQUE INDEX IF NOT EXISTS "contact_one_default_delivery_per_account"
    ON "contact" ("account_id")
    WHERE "is_default_delivery";
CREATE UNIQUE INDEX IF NOT EXISTS "contact_one_default_pickup_per_account"
    ON "contact" ("account_id")
    WHERE "is_default_pickup";
CREATE INDEX IF NOT EXISTS "contact_location_idx" ON "contact" USING GIST
    ("location");

CREATE TABLE IF NOT EXISTS "notification" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "account_id" BIGINT NOT NULL,
    "category" "notification_category" NOT NULL,
    "title" VARCHAR(200) NOT NULL,
    "payload" JSONB NOT NULL,

    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "read_at" TIMESTAMPTZ,
    "scheduled_at" TIMESTAMPTZ,

    CONSTRAINT "notification_pkey" PRIMARY KEY ("id", "created_at"),

    CONSTRAINT "notification_account_id_fkey" FOREIGN KEY ("account_id")
        REFERENCES "account" ("id") ON DELETE CASCADE
);
SELECT create_hypertable('notification', 'created_at', chunk_time_interval =>
    INTERVAL '7 days', if_not_exists => TRUE);
SELECT add_retention_policy('notification', INTERVAL '180 days', if_not_exists =>
    TRUE);

CREATE INDEX IF NOT EXISTS "notification_account_id_created_at_idx"
    ON "notification" ("account_id", "created_at" DESC);
CREATE INDEX IF NOT EXISTS "notification_account_id_unread_idx"
    ON "notification" ("account_id", "created_at" DESC)
    WHERE "read_at" IS NULL;

CREATE TABLE IF NOT EXISTS "notification_preference" (
    "account_id" BIGINT NOT NULL,
    "category" "notification_category" NOT NULL,
    "channel" "notification_type" NOT NULL,
    "is_enabled" BOOLEAN NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notification_preference_pkey" PRIMARY KEY ("account_id", "category",
        "channel"),

    CONSTRAINT "notification_preference_account_id_fkey" FOREIGN KEY ("account_id")
        REFERENCES "account" ("id") ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS "follow" (
    "follower_id" BIGINT NOT NULL,
    "followee_id" BIGINT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "follow_pkey" PRIMARY KEY ("follower_id", "followee_id"),
    CONSTRAINT "follow_no_self_follow" CHECK ("follower_id" <> "followee_id"),

    CONSTRAINT "follow_follower_id_fkey" FOREIGN KEY ("follower_id")
        REFERENCES "account" ("id") ON DELETE CASCADE,
    CONSTRAINT "follow_followee_id_fkey" FOREIGN KEY ("followee_id")
        REFERENCES "account" ("id") ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS "follow_followee_id_idx" ON "follow" ("followee_id",
    "created_at" DESC);
CREATE INDEX IF NOT EXISTS "follow_follower_id_created_at_idx" ON "follow"
    ("follower_id", "created_at" DESC);

CREATE TABLE IF NOT EXISTS "identity_document" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "account_id" BIGINT NOT NULL,
    "doc_type" "identity_document_type" NOT NULL,
    "provider" VARCHAR(30) NOT NULL,
    "provider_ref" TEXT NOT NULL,
    "front_resource_id" BIGINT,
    "back_resource_id" BIGINT,
    "selfie_resource_id" BIGINT,
    "status" "identity_status" NOT NULL DEFAULT 'pending',
    "rejection_reason" TEXT,
    "verified_at" TIMESTAMPTZ,
    "expires_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "identity_document_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "identity_document_provider_ref_key" UNIQUE ("provider",
        "provider_ref"),
    CONSTRAINT "identity_document_provider_format" CHECK ("provider" ~
        '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT "identity_document_verified_at_matches_status" CHECK (
        ("status" = 'verified') = ("verified_at" IS NOT NULL)
    ),
    CONSTRAINT "identity_document_rejection_requires_rejected" CHECK (
        "status" = 'rejected' OR "rejection_reason" IS NULL
    ),

    CONSTRAINT "identity_document_account_id_fkey" FOREIGN KEY ("account_id")
        REFERENCES "account" ("id") ON DELETE CASCADE,
    CONSTRAINT "identity_document_front_resource_id_fkey" FOREIGN KEY
        ("front_resource_id")
        REFERENCES "resource" ("id") ON DELETE SET NULL,
    CONSTRAINT "identity_document_back_resource_id_fkey" FOREIGN KEY
        ("back_resource_id")
        REFERENCES "resource" ("id") ON DELETE SET NULL,
    CONSTRAINT "identity_document_selfie_resource_id_fkey" FOREIGN KEY
        ("selfie_resource_id")
        REFERENCES "resource" ("id") ON DELETE SET NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS "identity_document_one_verified_per_account"
    ON "identity_document" ("account_id")
    WHERE "status" = 'verified';
CREATE INDEX IF NOT EXISTS "identity_document_pending_idx"
    ON "identity_document" ("created_at")
    WHERE "status" = 'pending';
CREATE INDEX IF NOT EXISTS "identity_document_expiring_idx"
    ON "identity_document" ("expires_at")
    WHERE "status" = 'verified' AND "expires_at" IS NOT NULL;

-- account/migrations/002_support_account.sql

INSERT INTO "account" ("username", "name", "country", "locale", "timezone", "role")
VALUES ('support', 'Hỗ trợ ShopNexus', 'VN', 'vi-VN', 'Asia/Ho_Chi_Minh', 'user')
ON CONFLICT ("username") DO NOTHING;

-- account/migrations/003_support_role.sql

ALTER TYPE "account_role" ADD VALUE IF NOT EXISTS 'support';

-- account/migrations/004_support_desk_row.sql

CREATE UNIQUE INDEX IF NOT EXISTS "account_support_role_key"
    ON "account" ("role")
    WHERE "role" = 'support';

UPDATE "account" SET "role" = 'support'
WHERE "username" = 'support'
  AND "password_hash" IS NULL
  AND NOT EXISTS (SELECT 1 FROM "oauth_identity" WHERE "account_id" =
      "account"."id");

INSERT INTO "account" ("username", "name", "country", "locale", "timezone", "role")
SELECT 'support', 'Hỗ trợ ShopNexus', 'VN', 'vi-VN', 'Asia/Ho_Chi_Minh', 'support'
WHERE NOT EXISTS (SELECT 1 FROM "account" WHERE "role" = 'support');
```

=== Lược đồ `catalog`

Lược đồ `catalog` là lược đồ nhiều bảng nhất. Nó giữ cây danh mục, bài đăng và các biến thể mua
được của bài đăng, từ điển thẻ, tồn kho, danh sách yêu thích, và toàn bộ trạng thái phục vụ tìm
kiếm. Điểm cần nhấn mạnh về mặt mô hình hoá là *bài đăng không phải một mục trong danh mục sản
phẩm dùng chung*: hai người bán rao cùng một mẫu điện thoại là hai hàng độc lập, vì tình trạng
món hàng, giá và người bán đều là thuộc tính của lời rao chứ không của sản phẩm. Đó là lý do
cột người bán và cột tình trạng nằm ngay trên bảng bài đăng.

Tồn kho được tách thành bảng riêng dù quan hệ với biến thể là một-một, vì hai nửa được ghi với
nhịp hoàn toàn khác nhau: số lượng giữ chỗ thay đổi theo từng lượt thanh toán, còn hàng biến
thể chỉ thay đổi khi người bán sửa tin. Nếu gộp, mỗi lượt giữ chỗ sẽ chạm vào đúng hàng đang
phục vụ chỉ mục sắp xếp theo giá. Bảng tồn kho dùng hai bộ đếm thay vì một: số đang giữ chỗ có
thể giảm khi phiên mua bị huỷ, còn số đã bán thì không bao giờ giảm, và ràng buộc kiểm tra bảo
đảm tổng hai bộ đếm không vượt quá số lượng thực có.

Ba bảng véc-tơ lưu song song một véc-tơ dày 1024 chiều và một véc-tơ thưa, phục vụ tìm kiếm
lai giữa ngữ nghĩa và từ khoá. Chúng được đánh chỉ mục HNSW. Hàng đợi cần tính lại véc-tơ không
phải một hàng đợi thông điệp mà là *một thuộc tính của chính dữ liệu*: cột `embedding_stale_at`
trên ba bảng bài đăng, danh mục và thẻ được đặt bởi bất kỳ thao tác ghi nào làm thay đổi nội
dung mô tả, và chỉ tiến trình sinh véc-tơ mới được xoá dấu ấy. Cách này khiến một hàng bị sửa
trong lúc triển khai vẫn còn nguyên dấu sau khi triển khai xong, và một lượt chạy trùng lặp thì
không tìm thấy việc gì để làm.

Vị trí địa lý của bài đăng được sao chép từ địa chỉ lấy hàng của người bán tại thời điểm đăng
tin, vì địa chỉ nằm ở lược đồ khác nên không kết nối được, và vì bộ lọc theo tỉnh là bộ lọc
được người mua dùng nhiều nhất trong mô hình chợ ngang hàng. Cuối cùng, bài đăng dùng xoá mềm
chứ không xoá cứng: mục hàng trong đơn cũ giữ định danh bài đăng không kèm khoá ngoại, nên lịch
sử mua bán phải tiếp tục phân giải được.

#figure(
  kind: table,
  caption: [Từ điển dữ liệu rút gọn của lược đồ `catalog`],
  table(
    columns: (1.2fr, 1.05fr, 1.6fr, 1.5fr),
    align: (left + horizon, left + horizon, left + horizon, left + horizon),
    inset: (x: 5pt, y: 5pt),
    table.header([Cột], [Kiểu], [Ý nghĩa], [Ràng buộc]),

    table.cell(colspan: 4)[*Bảng* `category`],
    [`parent_id`], [`BIGINT`], [Danh mục cha], [Khoá ngoại tự trỏ; xoá cha thì con thành gốc],
    [`name`], [`VARCHAR(100)`], [Tên danh mục], [Duy nhất],
    [`embedding_`\ `stale_at`], [`TIMESTAMPTZ`], [Dấu cần tính lại véc-tơ], [Rỗng nghĩa là còn mới],

    table.cell(colspan: 4)[*Bảng* `listing`],
    [`slug`], [`VARCHAR(100)`], [Chuỗi định danh thân thiện trên đường dẫn], [Duy nhất toàn cục],
    [`account_id`], [`BIGINT`], [Người bán sở hữu bài đăng], [Tham chiếu chéo lược đồ, không khoá ngoại],
    [`status`], [`listing_status`], [Trạng thái vòng đời và kiểm duyệt], [`draft`, `pending`, `active`, `hidden`],
    [`price_mode`], [`price_mode`], [Chế độ giá], [`fixed` hoặc `negotiable`],
    [`condition`], [`listing_`\ `condition`], [Tình trạng món hàng], [`new`, `used`, `damaged`],
    [`attachments`], [`BIGINT[]`], [Thư viện ảnh theo thứ tự, phần tử đầu là ảnh bìa], [Mảng tham chiếu tài nguyên, lưu nội tuyến],
    [`pending_edit`], [`JSONB`], [Bản sửa đang chờ kiểm duyệt], [Rỗng nghĩa là không có],
    [`cached_rating`, `cached_`\ `review_count`, `cached_sold`], [`DOUBLE`\ `PRECISION`, `BIGINT`], [Giá trị sao chép phục vụ sắp xếp], [Số đã bán không âm; nguồn thật nằm ở `trust` và ở bảng tồn kho],
    [`version`], [`BIGINT`], [Khoá lạc quan của thể tổng hợp bài đăng], [Thêm bởi tệp di trú 002],
    [`province_code` … `ward_name`, `location`], [`VARCHAR`, `geography`], [Đơn vị hành chính và toạ độ nơi có hàng], [Sao chép từ địa chỉ lấy hàng; chỉ mục GiST cho truy vấn bán kính],
    [`taken_down_at`, `takedown_reason`], [`TIMESTAMPTZ`, `TEXT`], [Dấu và lý do bị kiểm duyệt gỡ], [Lý do phải đi kèm việc gỡ; việc gỡ chỉ tồn tại khi đang ẩn],
    [`deleted_at`], [`TIMESTAMPTZ`], [Xoá mềm], [Khác với trạng thái ẩn do người bán tự đặt],

    table.cell(colspan: 4)[*Bảng* `variant`],
    [`price`], [`BIGINT`], [Giá theo đơn vị tiền nhỏ nhất], [Không âm],
    [`attributes`], [`JSONB`], [Bộ thuộc tính phân biệt biến thể], [Duy nhất theo cặp với bài đăng, trên các hàng chưa xoá],
    [`package_details`], [`JSONB`], [Kích thước và khối lượng gói hàng], [Dùng để báo giá vận chuyển],
    [`is_featured`], [`BOOLEAN`], [Biến thể hiển thị trên thẻ sản phẩm], [Chỉ mục duy nhất bộ phận: mỗi bài đăng một biến thể],

    table.cell(colspan: 4)[*Bảng* `tag`],
    [`id`], [`VARCHAR(100)`], [Chuỗi định danh thẻ], [Khoá tự nhiên, kiểm tra dạng kebab-case],
    table.cell(colspan: 4)[*Bảng* `listing_tag`],
    [`listing_id`, `tag`], [`BIGINT`, `VARCHAR`], [Bảng nối nhiều-nhiều], [Duy nhất theo cặp; xoá lan truyền cả hai phía],

    table.cell(colspan: 4)[*Bảng* `listing_embedding`],
    [`dense`, `sparse`], [`vector(1024)`, `sparsevec(250048)`], [Véc-tơ ngữ nghĩa và véc-tơ từ vựng], [Chỉ mục HNSW; rỗng cho tới lượt sinh véc-tơ đầu tiên],
    table.cell(colspan: 4)[*Bảng* `category_embedding`],
    [`category_id`], [`BIGINT`], [Danh mục được mô tả], [Khoá chính, đồng thời là khoá ngoại xoá lan truyền],
    [`dense`, `sparse`], [`vector(1024)`, `sparsevec(250048)`], [Véc-tơ của danh mục], [Cùng cặp cột như bảng trên, nhưng không đánh chỉ mục véc-tơ],
    table.cell(colspan: 4)[*Bảng* `tag_embedding`],
    [`tag_id`], [`VARCHAR(100)`], [Thẻ được mô tả], [Khoá chính; khoá ngoại xoá *và sửa* lan truyền, vì khoá của thẻ là một chuỗi định danh có thể được đổi],
    [`dense`, `sparse`], [`vector(1024)`, `sparsevec(250048)`], [Véc-tơ của thẻ], [Như trên],

    table.cell(colspan: 4)[*Bảng* `account_interest`],
    [`account_id`, `slot`], [`BIGINT`, `SMALLINT`], [Ô sở thích của một tài khoản], [Khoá chính ghép; không đánh chỉ mục véc-tơ],
    table.cell(colspan: 4)[*Bảng* `favorite`],
    [`account_id`, `listing_id`], [`BIGINT`], [Danh sách yêu thích], [Khoá chính ghép; khoá ngoại thật về bài đăng],

    table.cell(colspan: 4)[*Bảng* `stock`],
    [`variant_id`], [`BIGINT`], [Khoá chính, cũng là khoá ngoại], [Hàng không có định danh riêng, nên không thể có hai hàng cho một biến thể],
    [`quantity`, `reserved`, `sold`], [`BIGINT`], [Tổng số, số đang giữ chỗ, số đã bán], [Cả ba không âm; tổng giữ chỗ và đã bán không vượt tổng số],
    table.cell(colspan: 4)[*Bảng* `stock_movement`],
    [`key`], [`VARCHAR(200)`], [Khoá chống ghi trùng do bên gọi cung cấp], [Khoá tự nhiên, là khoá chính; số đơn vị phải dương],
  ),
)

```sql
-- catalog/migrations/001_init.sql

CREATE EXTENSION IF NOT EXISTS vector
WITH
  SCHEMA public;

CREATE EXTENSION IF NOT EXISTS unaccent
WITH
  SCHEMA public;

CREATE EXTENSION IF NOT EXISTS pg_trgm
WITH
  SCHEMA public;

CREATE FUNCTION "f_unaccent"(text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT
    AS $$ SELECT translate(public.unaccent('public.unaccent', $1), 'đĐ', 'dD') $$;

CREATE TYPE "listing_status" AS ENUM ('draft', 'pending', 'active', 'hidden');

CREATE TYPE "listing_condition" AS ENUM ('new', 'used', 'damaged');

CREATE TYPE "price_mode" AS ENUM ('fixed', 'negotiable');

CREATE TABLE
  IF NOT EXISTS "category" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "parent_id" BIGINT,
    "name" VARCHAR(100) NOT NULL,
    "description" TEXT NOT NULL,
    "embedding_stale_at" TIMESTAMPTZ,

    CONSTRAINT "category_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "category_name_key" UNIQUE ("name"),
    CONSTRAINT "category_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES
        "category" ("id") ON DELETE SET NULL
  );

CREATE INDEX IF NOT EXISTS "category_parent_id_idx" ON "category" ("parent_id");

CREATE TABLE
  IF NOT EXISTS "listing" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "slug" VARCHAR(100) NOT NULL,
    "account_id" BIGINT NOT NULL,
    "category_id" BIGINT NOT NULL,
    "status" "listing_status" NOT NULL DEFAULT 'draft',
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "specifications" JSONB NOT NULL,
    "attachments" BIGINT[] NOT NULL DEFAULT '{}',
    "price_mode" "price_mode" NOT NULL,
    "condition" "listing_condition" NOT NULL,
    "currency" VARCHAR(3) NOT NULL,

    "pending_edit" JSONB,
    "cached_rating" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "cached_review_count" BIGINT NOT NULL DEFAULT 0,
    "cached_sold" BIGINT NOT NULL DEFAULT 0,

    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMPTZ,
    "embedding_stale_at" TIMESTAMPTZ,

    CONSTRAINT "listing_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "listing_slug_key" UNIQUE ("slug"),
    CONSTRAINT "listing_currency_format" CHECK ("currency" ~ '^[A-Z]{3}$'),
    CONSTRAINT "listing_cached_sold_non_negative" CHECK ("cached_sold" >= 0),
    CONSTRAINT "listing_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES
        "category" ("id") ON DELETE RESTRICT
  );

CREATE INDEX IF NOT EXISTS "listing_account_id_idx" ON "listing" ("account_id");

CREATE INDEX IF NOT EXISTS "listing_category_id_idx" ON "listing" ("category_id");

CREATE INDEX IF NOT EXISTS "listing_name_unaccent_trgm_idx" ON "listing" USING gin
    ("f_unaccent" ("name") gin_trgm_ops);

CREATE INDEX IF NOT EXISTS "listing_active_created_at_idx"
    ON "listing" ("created_at" DESC)
    WHERE "status" = 'active' AND "deleted_at" IS NULL;
CREATE INDEX IF NOT EXISTS "listing_active_cached_rating_idx"
    ON "listing" ("cached_rating" DESC)
    WHERE "status" = 'active' AND "deleted_at" IS NULL;
CREATE INDEX IF NOT EXISTS "listing_active_cached_sold_idx"
    ON "listing" ("cached_sold" DESC)
    WHERE "status" = 'active' AND "deleted_at" IS NULL;
CREATE INDEX IF NOT EXISTS "listing_pending_created_at_idx"
    ON "listing" ("created_at")
    WHERE "status" = 'pending' AND "deleted_at" IS NULL;

CREATE TABLE
  IF NOT EXISTS "variant" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "listing_id" BIGINT NOT NULL,
    "price" BIGINT NOT NULL,
    "attributes" JSONB NOT NULL,
    "package_details" JSONB NOT NULL,
    "attachments" BIGINT[] NOT NULL DEFAULT '{}',
    "is_featured" BOOLEAN NOT NULL DEFAULT false,

    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMPTZ,
    CONSTRAINT "variant_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "variant_price_positive_check" CHECK ("price" >= 0),
    CONSTRAINT "variant_listing_id_fkey" FOREIGN KEY ("listing_id") REFERENCES
        "listing" ("id") ON DELETE CASCADE
  );

CREATE INDEX IF NOT EXISTS "variant_listing_id_idx" ON "variant" ("listing_id");
CREATE INDEX IF NOT EXISTS "variant_price_idx"
    ON "variant" ("price")
    WHERE "deleted_at" IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "variant_one_featured_per_listing"
    ON "variant" ("listing_id")
    WHERE "is_featured" AND "deleted_at" IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "variant_listing_id_attributes_key"
    ON "variant" ("listing_id", "attributes")
    WHERE "deleted_at" IS NULL;

CREATE TABLE
  IF NOT EXISTS "tag" (
    "id" VARCHAR(100) NOT NULL,
    "description" VARCHAR(255),
    "embedding_stale_at" TIMESTAMPTZ,
    CONSTRAINT "tag_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "tag_id_slug_check" CHECK ("id" ~ '^[a-z0-9]+(-[a-z0-9]+)*$')
  );

CREATE INDEX IF NOT EXISTS "tag_id_prefix_idx" ON "tag" ("id" text_pattern_ops);

CREATE TABLE
  IF NOT EXISTS "listing_tag" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "listing_id" BIGINT NOT NULL,
    "tag" VARCHAR(100) NOT NULL,
    CONSTRAINT "listing_tag_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "listing_tag_listing_id_tag_key" UNIQUE ("listing_id", "tag"),
    CONSTRAINT "listing_tag_listing_id_fkey" FOREIGN KEY ("listing_id") REFERENCES
        "listing" ("id") ON DELETE CASCADE,
    CONSTRAINT "listing_tag_tag_fkey" FOREIGN KEY ("tag") REFERENCES "tag" ("id") ON
        DELETE CASCADE ON UPDATE CASCADE
  );

CREATE TABLE
  IF NOT EXISTS "listing_embedding" (
    "listing_id" BIGINT NOT NULL,
    "dense" vector (1024),
    "sparse" sparsevec (250048),
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "listing_embedding_pkey" PRIMARY KEY ("listing_id"),
    CONSTRAINT "listing_embedding_listing_id_fkey" FOREIGN KEY ("listing_id")
        REFERENCES "listing" ("id") ON DELETE CASCADE
  );

CREATE INDEX IF NOT EXISTS "listing_embedding_dense_idx" ON "listing_embedding"
    USING hnsw ("dense" vector_cosine_ops);

CREATE INDEX IF NOT EXISTS "listing_embedding_sparse_idx" ON "listing_embedding"
    USING hnsw ("sparse" sparsevec_ip_ops);

CREATE TABLE
  IF NOT EXISTS "category_embedding" (
    "category_id" BIGINT NOT NULL,
    "dense" vector (1024),
    "sparse" sparsevec (250048),
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "category_embedding_pkey" PRIMARY KEY ("category_id"),
    CONSTRAINT "category_embedding_category_id_fkey" FOREIGN KEY ("category_id")
        REFERENCES "category" ("id") ON DELETE CASCADE
  );

CREATE INDEX IF NOT EXISTS "category_embedding_dense_idx" ON "category_embedding"
    USING hnsw ("dense" vector_cosine_ops);

CREATE INDEX IF NOT EXISTS "category_embedding_sparse_idx" ON "category_embedding"
    USING hnsw ("sparse" sparsevec_ip_ops);

CREATE TABLE
  IF NOT EXISTS "tag_embedding" (
    "tag_id" VARCHAR(100) NOT NULL,
    "dense" vector (1024),
    "sparse" sparsevec (250048),
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "tag_embedding_pkey" PRIMARY KEY ("tag_id"),
    CONSTRAINT "tag_embedding_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "tag"
        ("id") ON DELETE CASCADE ON UPDATE CASCADE
  );

CREATE INDEX IF NOT EXISTS "tag_embedding_dense_idx" ON "tag_embedding" USING hnsw
    ("dense" vector_cosine_ops);

CREATE INDEX IF NOT EXISTS "tag_embedding_sparse_idx" ON "tag_embedding" USING hnsw
    ("sparse" sparsevec_ip_ops);

CREATE TABLE
  IF NOT EXISTS "account_interest" (
    "account_id" BIGINT NOT NULL,
    "slot" SMALLINT NOT NULL,
    "dense" vector (1024) NOT NULL,
    "strength" REAL NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "account_interest_pkey" PRIMARY KEY ("account_id", "slot")
  );

CREATE TABLE IF NOT EXISTS "favorite" (
    "account_id" BIGINT NOT NULL,
    "listing_id" BIGINT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "favorite_pkey" PRIMARY KEY ("account_id", "listing_id"),
    CONSTRAINT "favorite_listing_id_fkey" FOREIGN KEY ("listing_id")
        REFERENCES "listing" ("id") ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS "favorite_listing_id_idx" ON "favorite" ("listing_id");
CREATE INDEX IF NOT EXISTS "favorite_account_id_created_at_idx"
    ON "favorite" ("account_id", "created_at" DESC);

CREATE TABLE IF NOT EXISTS "stock" (
    "variant_id" BIGINT NOT NULL,
    "quantity" BIGINT NOT NULL,
    "reserved" BIGINT NOT NULL DEFAULT 0,
    "sold" BIGINT NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "stock_pkey" PRIMARY KEY ("variant_id"),
    CONSTRAINT "stock_quantity_non_negative" CHECK ("quantity" >= 0),
    CONSTRAINT "stock_reserved_non_negative" CHECK ("reserved" >= 0),
    CONSTRAINT "stock_sold_non_negative" CHECK ("sold" >= 0),
    CONSTRAINT "stock_committed_within_quantity" CHECK ("reserved" + "sold" <=
        "quantity"),

    CONSTRAINT "stock_variant_id_fkey" FOREIGN KEY ("variant_id")
        REFERENCES "variant" ("id") ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS "stock_sold_idx" ON "stock" ("sold" DESC);

CREATE TABLE IF NOT EXISTS "stock_movement" (
    "key" VARCHAR(200) NOT NULL,
    "variant_id" BIGINT NOT NULL,
    "units" BIGINT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "stock_movement_pkey" PRIMARY KEY ("key"),
    CONSTRAINT "stock_movement_units_positive" CHECK ("units" > 0),

    CONSTRAINT "stock_movement_variant_id_fkey" FOREIGN KEY ("variant_id")
        REFERENCES "variant" ("id") ON DELETE CASCADE
);

-- catalog/migrations/002_listing_version.sql

ALTER TABLE "listing" ADD COLUMN IF NOT EXISTS "version" BIGINT NOT NULL DEFAULT 1;

CREATE INDEX IF NOT EXISTS "listing_moderation_queue_idx"
    ON "listing" ("created_at")
    WHERE "deleted_at" IS NULL
      AND ("status" = 'pending' OR "pending_edit" IS NOT NULL);

-- catalog/migrations/003_embedding_queue.sql

CREATE INDEX IF NOT EXISTS "listing_embedding_stale_idx"
    ON "listing" ("embedding_stale_at", "id")
    WHERE "embedding_stale_at" IS NOT NULL AND "deleted_at" IS NULL;

CREATE INDEX IF NOT EXISTS "category_embedding_stale_idx"
    ON "category" ("embedding_stale_at", "id")
    WHERE "embedding_stale_at" IS NOT NULL;

CREATE INDEX IF NOT EXISTS "tag_embedding_stale_idx"
    ON "tag" ("embedding_stale_at", "id")
    WHERE "embedding_stale_at" IS NOT NULL;

-- catalog/migrations/004_listing_location.sql

CREATE EXTENSION IF NOT EXISTS postgis;

ALTER TABLE "listing"
    ADD COLUMN IF NOT EXISTS "province_code" VARCHAR(20),
    ADD COLUMN IF NOT EXISTS "province_name" VARCHAR(100),
    ADD COLUMN IF NOT EXISTS "district_code" VARCHAR(20),
    ADD COLUMN IF NOT EXISTS "district_name" VARCHAR(100),
    ADD COLUMN IF NOT EXISTS "ward_code" VARCHAR(20),
    ADD COLUMN IF NOT EXISTS "ward_name" VARCHAR(100),
    ADD COLUMN IF NOT EXISTS "location" geography (Point, 4326);

ALTER TABLE "listing"
    DROP CONSTRAINT IF EXISTS "listing_district_code_name_together";

ALTER TABLE "listing"
    ADD CONSTRAINT "listing_district_code_name_together" CHECK (
        ("district_code" IS NULL) = ("district_name" IS NULL)
    );

CREATE INDEX IF NOT EXISTS "listing_area_idx"
    ON "listing" ("province_code", "district_code")
    WHERE "status" = 'active' AND "deleted_at" IS NULL;

CREATE INDEX IF NOT EXISTS "listing_location_gist"
    ON "listing" USING gist ("location")
    WHERE "status" = 'active' AND "deleted_at" IS NULL;

-- catalog/migrations/005_listing_takedown.sql

ALTER TABLE "listing"
    ADD COLUMN IF NOT EXISTS "taken_down_at" TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS "takedown_reason" TEXT;

ALTER TABLE "listing"
    DROP CONSTRAINT IF EXISTS "listing_takedown_reason_needs_takedown";
ALTER TABLE "listing"
    ADD CONSTRAINT "listing_takedown_reason_needs_takedown"
    CHECK ("takedown_reason" IS NULL OR "taken_down_at" IS NOT NULL);

ALTER TABLE "listing"
    DROP CONSTRAINT IF EXISTS "listing_takedown_only_while_hidden";
ALTER TABLE "listing"
    ADD CONSTRAINT "listing_takedown_only_while_hidden"
    CHECK ("taken_down_at" IS NULL OR "status" = 'hidden');
```

=== Lược đồ `order`

Lược đồ `order` mô tả toàn bộ hành trình từ lúc người mua bấm mua tới lúc hàng được nhận hoặc
được trả lại. Nó gồm giỏ hàng, phiên mua hàng giá cố định, phiên thương lượng giá, vận đơn, đơn
hàng, mục hàng và hồ sơ hoàn tiền.

Quyết định trung tâm của lược đồ này là *người bán không duyệt đơn; chính dòng tiền tạo ra đơn*.
Mọi bài đăng đều mua được ngay từ trang của nó: người mua mở một phiên mua hàng đóng băng giá
người bán đang hỏi, trả tiền hàng cộng cước vận chuyển đã báo giá, và đơn hàng cùng vận đơn ra
đời ngay khi phiên thanh toán hoàn tất. Đây là lý do cột `order_id` trên mục hàng cho phép
rỗng: nó rỗng trong khoảng thời gian giữa lúc mục hàng được tạo và lúc lời gọi lại của cổng
thanh toán ghi ra đơn, chứ không phải trong lúc chờ người bán đồng ý. Chế độ giá thương lượng
thêm một lối đi chứ không thay thế lối đi trên: hai bên luân phiên sửa điều khoản, bên không
giữ đề xuất hiện hành có quyền chấp nhận, và việc chấp nhận chỉ đóng băng giá trong một cửa sổ
ngắn — người mua vẫn phải bấm thanh toán thì đơn mới hình thành.

Vì có hai nguồn hình thành đơn như vậy, cả bảng đơn hàng lẫn bảng mục hàng đều mang hai cột cho
phép rỗng là `draft_id` và `offer_id`, kèm ràng buộc kiểm tra buộc đúng một trong hai phải có
giá trị. Tính duy nhất thì *không* đối xứng giữa hai bảng, và sự bất đối xứng ấy có lý do. Trên
bảng đơn hàng, cả hai cột đều mang ràng buộc duy nhất, vì mỗi phiếu mua tạm và mỗi cuộc thương
lượng chỉ được sinh ra đúng một đơn: đó là thứ khiến một lời gọi lại của cổng thanh toán bị gửi
hai lần, hoặc một cú nhấn đúp vào nút chấp nhận, không thể sinh ra đơn thứ hai. Trên bảng mục
hàng thì chỉ `offer_id` là duy nhất, còn `draft_id` chỉ có một chỉ mục thường — bởi một phiếu
mua tạm có thể chứa nhiều dòng hàng và mỗi dòng thành một mục, trong khi một cuộc thương lượng
luôn nói về đúng một biến thể nên chỉ sinh ra đúng một mục.

Bảng đơn hàng còn mang bốn ràng buộc kiểm tra diễn đạt trật tự bắt buộc của các sự kiện: bằng
chứng nhận hàng và thời điểm nhận hàng là một hành động nên phải cùng có hoặc cùng không; tiền
chỉ được giải ngân khi đã có xác nhận nhận hàng; không thể nhận hàng khi người bán chưa xác
nhận, vì trước đó chưa có gì được giao; và lý do từ chối chỉ tồn tại trên một đơn đã huỷ và
chưa từng được xác nhận. Cột `payout_released_at` đóng vai trò dấu hiệu "đã xong" cho công việc
giải ngân chạy nền: nhờ nó, danh sách cần thử lại đúng bằng tập đơn còn kẹt, thay vì là một cửa
sổ thời gian mà chi phí quét sẽ lớn dần theo lịch sử.

Hồ sơ hoàn tiền được thiết kế quanh nguyên tắc *người bán không thể từ chối bằng lời của mình*.
Người bán chỉ có hai nước đi là chấp nhận hoặc chuyển hồ sơ cho bộ phận hỗ trợ; để quá hạn thì
hệ thống tự chuyển thay họ. Vì thế bảng này không có cột lý do từ chối, và cũng không có chặng
vận chuyển trả ngược về người mua. Mỗi trạng thái chưa kết thúc được đặt tên theo bên đang phải
hành động. Trong bốn trạng thái chưa kết thúc, chỉ *hai* trạng thái mang hạn chót, và ràng buộc
kiểm tra `refund_deadline_matches_status` diễn đạt đúng điều đó bằng một phép tương đương: hạn
chót tồn tại khi và chỉ khi hồ sơ đang chờ người bán xem xét, hoặc đang trong bốn mươi tám giờ
kiểm hàng sau khi hàng trả đã về. Hai trạng thái còn lại — đang trả hàng và đang tranh chấp —
cố ý không có hạn chót, vì thứ chúng đang chờ là một hãng vận chuyển và một con người, chứ
không phải một đồng hồ mà hệ thống có quyền đặt.

#figure(
  kind: table,
  caption: [Từ điển dữ liệu rút gọn của lược đồ `order`],
  table(
    columns: (1.2fr, 1.05fr, 1.6fr, 1.5fr),
    align: (left + horizon, left + horizon, left + horizon, left + horizon),
    inset: (x: 5pt, y: 5pt),
    table.header([Cột], [Kiểu], [Ý nghĩa], [Ràng buộc]),

    table.cell(colspan: 4)[*Bảng* `cart_item`],
    [`account_id`, `variant_id`], [`BIGINT`], [Chủ giỏ và biến thể], [Duy nhất theo cặp],
    [`listing_id`], [`BIGINT`], [Bài đăng gốc, sao chép khi chèn], [Cần để hiển thị giỏ mà không phải gọi chéo mô-đun],
    [`quantity`], [`BIGINT`], [Số lượng], [Phải dương],

    table.cell(colspan: 4)[*Bảng* `transport`],
    [`option`], [`VARCHAR(100)`], [Hãng vận chuyển, tham chiếu bảng tuỳ chọn], [Kiểm tra dạng kebab-case],
    [`status`], [`transport_`\ `status`], [Trạng thái vận đơn theo báo cáo của hãng], [Bảy giá trị, mặc định `pending`],
    [`fee`], [`BIGINT`], [Cước người mua đã trả, đóng băng tại thanh toán], [Không âm],
    [`data`], [`JSONB`], [Dữ liệu riêng của hãng: mã vận đơn, nhãn, sự kiện], [Mặc định đối tượng rỗng],

    table.cell(colspan: 4)[*Bảng* `draft_order`],
    [`buyer_id`, `listing_id`], [`BIGINT`], [Người mua và bài đăng của phiên], [],
    [`spu_snapshot`], [`JSONB`], [Ảnh chụp bài đăng và các biến thể lúc mở phiên], [Đóng băng giá và khối lượng gói],
    [`valid_until`, `cancelled_at`], [`TIMESTAMPTZ`], [Hạn phiên và dấu đã huỷ], [Chỉ mục bộ phận cho công việc hết hạn],

    table.cell(colspan: 4)[*Bảng* `offer`],
    [`buyer_id`, `variant_id`], [`BIGINT`], [Cặp xác định một cuộc thương lượng], [Chỉ mục duy nhất bộ phận: một cuộc đang mở cho mỗi cặp],
    [`author_id`], [`BIGINT`], [Bên tạo đề xuất hiện hành], [Có thể là người mua hoặc người bán],
    [`status`], [`offer_status`], [Trạng thái thương lượng], [`active`, `accepted`, `checked-out`, `cancelled`],
    [`total`, `quantity`], [`BIGINT`], [Giá đề xuất và số lượng], [Cả hai phải dương],
    [`expires_at`], [`TIMESTAMPTZ`], [Hạn của đề xuất hoặc của giá đã đóng băng], [Chỉ mục bộ phận cho công việc hết hạn],

    table.cell(colspan: 4)[*Bảng* `order`],
    [`draft_id`, `offer_id`], [`BIGINT`], [Nguồn hình thành đơn], [Mỗi cột duy nhất; ràng buộc buộc đúng một trong hai có giá trị],
    [`buyer_id`, `seller_id`], [`BIGINT`], [Hai bên của giao dịch], [Tham chiếu chéo lược đồ],
    [`transport_id`], [`BIGINT`], [Vận đơn giao đi], [Khoá ngoại, duy nhất],
    [`address`, `pickup_address`], [`JSONB`], [Ảnh chụp địa chỉ giao và địa chỉ lấy hàng], [Lưu dạng cấu trúc vì mã hành chính là thứ gọi hãng vận chuyển],
    [`confirmed_at`], [`TIMESTAMPTZ`], [Thời điểm người bán đồng ý bán], [Trước đó vận đơn nằm ở trạng thái chưa bàn giao],
    [`confirmation_`\ `escalated_at`], [`TIMESTAMPTZ`], [Dấu đã chuyển bộ phận hỗ trợ đôn đốc], [Ngăn công việc nền nhắc lại cùng một đơn],
    [`received_at`, `receipt_`\ `attachments`], [`TIMESTAMPTZ`, `BIGINT[]`], [Xác nhận nhận hàng và ảnh mở hộp], [Phải cùng có hoặc cùng không],
    [`payout_`\ `released_at`], [`TIMESTAMPTZ`], [Thời điểm tiền tạm giữ về tay người bán], [Chỉ được đặt khi đã có xác nhận nhận hàng],
    [`decline_reason`], [`TEXT`], [Lý do người bán từ chối bán], [Chỉ tồn tại trên đơn đã huỷ và chưa từng xác nhận],
    [`completed_at`, `cancelled_at`], [`TIMESTAMPTZ`], [Kết cục của đơn], [Là sự kiện, không phải cột trạng thái],

    table.cell(colspan: 4)[*Bảng* `item`],
    [`draft_id`, `offer_id`], [`BIGINT`], [Nguồn hình thành mục hàng], [Cùng ràng buộc như bảng đơn; mục hàng từ thương lượng là duy nhất],
    [`order_id`], [`BIGINT`], [Đơn chứa mục hàng], [Rỗng cho tới khi phiên thanh toán hoàn tất],
    [`listing_id`, `variant_id`], [`BIGINT`], [Món hàng đã mua], [Tham chiếu chéo lược đồ],
    [`transport_option`], [`VARCHAR(100)`], [Hãng vận chuyển do người mua chọn], [Kiểm tra dạng kebab-case],
    [`total_amount`, `currency`], [`BIGINT`, `VARCHAR(3)`], [Số tiền đã trả và loại tiền], [Số tiền không âm, mã tiền ba chữ hoa],
    [`payment_`\ `session_id`], [`BIGINT`], [Phiên thanh toán đã thu tiền mục hàng này], [Bắt buộc; tham chiếu chéo lược đồ],
    [`cancelled_at`, `cancelled_by_id`], [`TIMESTAMPTZ`, `BIGINT`], [Dấu huỷ và bên huỷ], [Bên huỷ rỗng nghĩa là hệ thống huỷ],

    table.cell(colspan: 4)[*Bảng* `refund`],
    [`order_id`, `buyer_id`], [`BIGINT`], [Đơn bị khiếu nại và người khiếu nại], [Chỉ mục duy nhất bộ phận: một hồ sơ đang mở cho mỗi đơn],
    [`status`], [`refund_status`], [Trạng thái xử lý], [Bảy giá trị; mỗi trạng thái chưa kết thúc mang tên bên đang phải hành động],
    [`deadline_at`], [`TIMESTAMPTZ`], [Hạn của bên đang phải hành động], [Phải có đúng ở hai trạng thái chờ người bán và chờ kiểm hàng trả về],
    [`attachments`], [`BIGINT[]`], [Bằng chứng của người mua], [Tham chiếu tài nguyên, lưu nội tuyến],
    [`return_`\ `transport_id`, `returned_at`], [`BIGINT`, `TIMESTAMPTZ`], [Chặng trả hàng và thời điểm hàng về], [Chỉ tạo khi hoàn tiền được chấp nhận; có thời điểm về thì phải có vận đơn],
  ),
)

```sql
-- order/migrations/001_init.sql

CREATE TYPE "transport_status" AS ENUM (
    'pending',
    'picked-up',
    'in-transit',
    'delivered',
    'returned',
    'failed',
    'cancelled'
);

CREATE TYPE "refund_status" AS ENUM (
    'awaiting-seller-review',
    'disputed',
    'returning',
    'returned',
    'accepted',
    'rejected',
    'cancelled'
);

CREATE TYPE "offer_status" AS ENUM ('active', 'accepted', 'checked-out',
    'cancelled');

CREATE TABLE IF NOT EXISTS "cart_item" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "account_id" BIGINT NOT NULL,
    "listing_id" BIGINT NOT NULL,
    "variant_id" BIGINT NOT NULL,
    "quantity" BIGINT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cart_item_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "cart_item_account_id_variant_id_key" UNIQUE ("account_id",
        "variant_id"),
    CONSTRAINT "cart_item_quantity_positive" CHECK ("quantity" > 0)
);

CREATE TABLE IF NOT EXISTS "transport" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "option" VARCHAR(100) NOT NULL,
    "status" "transport_status" NOT NULL DEFAULT 'pending',
    "fee" BIGINT NOT NULL DEFAULT 0,
    "data" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "transport_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "transport_option_format" CHECK ("option" ~
        '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT "transport_fee_non_negative" CHECK ("fee" >= 0)
);

CREATE TABLE IF NOT EXISTS "draft_order" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "buyer_id" BIGINT NOT NULL,
    "listing_id" BIGINT NOT NULL,
    "spu_snapshot" JSONB NOT NULL,

    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "cancelled_at" TIMESTAMPTZ,
    "valid_until" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "draft_order_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "draft_order_expiring_idx"
    ON "draft_order" ("valid_until")
    WHERE "cancelled_at" IS NULL;
CREATE INDEX IF NOT EXISTS "draft_order_buyer_id_idx" ON "draft_order" ("buyer_id",
    "created_at" DESC);

CREATE TABLE IF NOT EXISTS "offer" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "listing_id" BIGINT NOT NULL,
    "variant_id" BIGINT NOT NULL,
    "author_id" BIGINT NOT NULL,
    "buyer_id" BIGINT NOT NULL,
    "seller_id" BIGINT NOT NULL,
    "status" "offer_status" NOT NULL DEFAULT 'active',
    "quantity" BIGINT NOT NULL,
    "total" BIGINT NOT NULL,
    "reason" TEXT NOT NULL DEFAULT '',
    "payment_session_id" BIGINT,

    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "offer_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "offer_total_positive" CHECK ("total" > 0),
    CONSTRAINT "offer_quantity_positive" CHECK ("quantity" > 0)
);
CREATE UNIQUE INDEX IF NOT EXISTS "offer_one_active_per_buyer_sku" ON "offer"
    ("buyer_id", "variant_id") WHERE "status" = 'active';
CREATE INDEX IF NOT EXISTS "offer_expiring_idx"
    ON "offer" ("expires_at")
    WHERE "status" IN ('active', 'accepted');
CREATE INDEX IF NOT EXISTS "offer_seller_id_status_idx" ON "offer" ("seller_id",
    "status");
CREATE INDEX IF NOT EXISTS "offer_buyer_id_status_idx" ON "offer" ("buyer_id",
    "status");
CREATE INDEX IF NOT EXISTS "offer_variant_id_idx" ON "offer" ("variant_id");

CREATE TABLE IF NOT EXISTS "order" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "draft_id" BIGINT,
    "offer_id" BIGINT,
    "buyer_id" BIGINT NOT NULL,
    "transport_id" BIGINT NOT NULL,
    "address" JSONB NOT NULL,
    "pickup_address" JSONB NOT NULL,

    "confirmed_at" TIMESTAMPTZ,
    "confirmation_escalated_at" TIMESTAMPTZ,
    "decline_reason" TEXT,

    "received_at" TIMESTAMPTZ,
    "receipt_attachments" BIGINT[] NOT NULL DEFAULT '{}',
    "payout_released_at" TIMESTAMPTZ,

    "seller_id" BIGINT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMPTZ,
    "cancelled_at" TIMESTAMPTZ,

    CONSTRAINT "order_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "order_transport_id_key" UNIQUE ("transport_id"),
    CONSTRAINT "order_draft_id_key" UNIQUE ("draft_id"),
    CONSTRAINT "order_offer_id_key" UNIQUE ("offer_id"),
    CONSTRAINT "order_origin_exactly_one" CHECK (
        ("draft_id" IS NOT NULL) <> ("offer_id" IS NOT NULL)
    ),
    CONSTRAINT "order_receipt_attachments_match_received" CHECK (
        ("received_at" IS NOT NULL) = (cardinality("receipt_attachments") > 0)
    ),
    CONSTRAINT "order_payout_needs_receipt" CHECK (
        "payout_released_at" IS NULL OR "received_at" IS NOT NULL
    ),
    CONSTRAINT "order_receipt_needs_confirmation" CHECK (
        "received_at" IS NULL OR "confirmed_at" IS NOT NULL
    ),
    CONSTRAINT "order_decline_is_a_cancellation" CHECK (
        "decline_reason" IS NULL
        OR ("cancelled_at" IS NOT NULL AND "confirmed_at" IS NULL)
    ),

    CONSTRAINT "order_transport_id_fkey" FOREIGN KEY ("transport_id")
        REFERENCES "transport" ("id") ON DELETE NO ACTION,
    CONSTRAINT "order_draft_id_fkey" FOREIGN KEY ("draft_id")
        REFERENCES "draft_order" ("id") ON DELETE NO ACTION,
    CONSTRAINT "order_offer_id_fkey" FOREIGN KEY ("offer_id")
        REFERENCES "offer" ("id") ON DELETE NO ACTION
);
CREATE INDEX IF NOT EXISTS "order_transport_id_idx" ON "order" ("transport_id");
CREATE INDEX IF NOT EXISTS "order_awaiting_confirmation_idx"
    ON "order" ("created_at")
    WHERE "confirmed_at" IS NULL AND "completed_at" IS NULL AND "cancelled_at" IS
        NULL
      AND "confirmation_escalated_at" IS NULL;
CREATE INDEX IF NOT EXISTS "order_buyer_id_open_idx"
    ON "order" ("buyer_id", "created_at" DESC)
    WHERE "completed_at" IS NULL AND "cancelled_at" IS NULL;
CREATE INDEX IF NOT EXISTS "order_seller_id_open_idx"
    ON "order" ("seller_id", "created_at" DESC)
    WHERE "completed_at" IS NULL AND "cancelled_at" IS NULL;
CREATE INDEX IF NOT EXISTS "order_buyer_id_idx" ON "order" ("buyer_id", "created_at"
    DESC);
CREATE INDEX IF NOT EXISTS "order_seller_id_idx" ON "order" ("seller_id",
    "created_at" DESC);
CREATE INDEX IF NOT EXISTS "order_payout_due_idx"
    ON "order" ("received_at")
    WHERE "payout_released_at" IS NULL AND "received_at" IS NOT NULL AND
        "cancelled_at" IS NULL;

CREATE TABLE IF NOT EXISTS "item" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "draft_id" BIGINT,
    "offer_id" BIGINT,
    "order_id" BIGINT,
    "buyer_id" BIGINT NOT NULL,
    "seller_id" BIGINT NOT NULL,
    "listing_id" BIGINT NOT NULL,
    "variant_id" BIGINT NOT NULL,
    "address" JSONB NOT NULL,
    "note" TEXT,
    "currency" VARCHAR(3) NOT NULL,

    "quantity" BIGINT NOT NULL,
    "transport_option" VARCHAR(100) NOT NULL,
    "total_amount" BIGINT NOT NULL,
    "payment_session_id" BIGINT NOT NULL,

    "cancelled_at" TIMESTAMPTZ,
    "cancelled_by_id" BIGINT,

    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "item_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "item_quantity_positive" CHECK ("quantity" > 0),
    CONSTRAINT "item_total_amount_non_negative" CHECK ("total_amount" >= 0),
    CONSTRAINT "item_currency_format" CHECK ("currency" ~ '^[A-Z]{3}$'),
    CONSTRAINT "item_transport_option_format" CHECK ("transport_option" ~
        '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT "item_origin_exactly_one" CHECK (
        ("draft_id" IS NOT NULL) <> ("offer_id" IS NOT NULL)
    ),

    CONSTRAINT "item_order_id_fkey" FOREIGN KEY ("order_id")
        REFERENCES "order" ("id") ON DELETE NO ACTION,
    CONSTRAINT "item_draft_id_fkey" FOREIGN KEY ("draft_id")
        REFERENCES "draft_order" ("id") ON DELETE NO ACTION,
    CONSTRAINT "item_offer_id_fkey" FOREIGN KEY ("offer_id")
        REFERENCES "offer" ("id") ON DELETE NO ACTION
);
CREATE INDEX IF NOT EXISTS "item_order_id_idx" ON "item" ("order_id");
CREATE INDEX IF NOT EXISTS "item_variant_id_idx" ON "item" ("variant_id");
CREATE INDEX IF NOT EXISTS "item_draft_id_idx" ON "item" ("draft_id");
CREATE UNIQUE INDEX IF NOT EXISTS "item_offer_id_key" ON "item" ("offer_id") WHERE
    "offer_id" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "item_payment_session_id_idx" ON "item"
    ("payment_session_id");
CREATE INDEX IF NOT EXISTS "item_buyer_id_idx" ON "item" ("buyer_id", "created_at"
    DESC);
CREATE INDEX IF NOT EXISTS "item_seller_pending_idx"
    ON "item" ("seller_id", "created_at" DESC)
    WHERE "order_id" IS NULL AND "cancelled_at" IS NULL;

CREATE TABLE IF NOT EXISTS "refund" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "buyer_id" BIGINT NOT NULL,
    "order_id" BIGINT NOT NULL,
    "reason" TEXT NOT NULL,
    "attachments" BIGINT[] NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    "status" "refund_status" NOT NULL DEFAULT 'awaiting-seller-review',
    "deadline_at" TIMESTAMPTZ,

    "seller_decided_at" TIMESTAMPTZ,

    "return_transport_id" BIGINT,
    "returned_at" TIMESTAMPTZ,

    CONSTRAINT "refund_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "refund_return_transport_id_key" UNIQUE ("return_transport_id"),
    CONSTRAINT "refund_returned_needs_transport" CHECK (
        "returned_at" IS NULL OR "return_transport_id" IS NOT NULL
    ),
    CONSTRAINT "refund_deadline_matches_status" CHECK (
        ("deadline_at" IS NOT NULL) =
        ("status" IN ('awaiting-seller-review', 'returned'))
    ),

    CONSTRAINT "refund_order_id_fkey" FOREIGN KEY ("order_id")
        REFERENCES "order" ("id") ON DELETE NO ACTION,
    CONSTRAINT "refund_return_transport_id_fkey" FOREIGN KEY ("return_transport_id")
        REFERENCES "transport" ("id") ON DELETE NO ACTION
);
CREATE INDEX IF NOT EXISTS "refund_buyer_id_idx" ON "refund" ("buyer_id",
    "created_at" DESC);
CREATE INDEX IF NOT EXISTS "refund_order_id_idx" ON "refund" ("order_id");
CREATE UNIQUE INDEX IF NOT EXISTS "refund_one_active_per_order"
    ON "refund" ("order_id")
    WHERE "status" IN ('awaiting-seller-review', 'disputed', 'returning',
        'returned');
CREATE INDEX IF NOT EXISTS "refund_overdue_idx"
    ON "refund" ("deadline_at")
    WHERE "deadline_at" IS NOT NULL;

-- order/migrations/002_transport_option.sql

INSERT INTO "option" ("id", "is_enabled", "name", "description", "priority", "type",
    "provider")
VALUES (
    'standard-delivery',
    TRUE,
    'Standard delivery',
    'Door-to-door delivery, priced by the platform''s carrier at checkout and paid
        by the buyer.',
    100,
    'transport',
    'platform'
)
ON CONFLICT ("id") DO NOTHING;

-- order/migrations/003_drop_platform_carrier.sql

DELETE FROM "option" WHERE "type" = 'transport' AND "provider" = 'platform';
```

=== Lược đồ `finance`

Lược đồ `finance` giữ toàn bộ nguyên thể tiền tệ trong một chỗ, và đó là một quyết định có chủ
đích: giữ tiền tạm và giải ngân phải là những thao tác nguyên tử, nên phiên thanh toán, sổ cái
giao dịch, ví, sổ cái ví, tài khoản ngân hàng và thông tin thuế đều phải ở cùng một ranh giới
giao dịch. Các mô-đun khác chỉ tham chiếu tới lược đồ này bằng định danh.

Điểm cần hiểu đúng nhất ở đây là *hai sổ cái với một ranh giới rõ ràng*. Bảng `transaction` chỉ
ghi những chặng tiền đi qua kênh thanh toán *bên ngoài* — thẻ, cổng chuyển khoản, chặng hoàn
tiền của cổng. Tiền chỉ di chuyển bên trong ví thì chỉ được ghi vào `wallet_transaction`.
Không bao giờ ghi cùng một chuyển động vào cả hai. Cả hai sổ đều chỉ ghi thêm: hoàn tiền không
sửa bút toán gốc mà tạo bút toán mới mang dấu âm và trỏ về bút toán bị đảo, và ràng buộc kiểm
tra buộc dấu của số tiền phải khớp với việc có hay không có tham chiếu đảo ứng.

Ví được khoá theo *cặp tài khoản và loại tiền* chứ không phải theo tài khoản, nên một tài khoản
có thể có nhiều ví. Mọi thay đổi số dư đều lấy khoá ghi trên hàng ví, và chính dưới khoá đó mà
số thứ tự của bút toán ví được cấp phát — vì dấu thời gian có thể trùng nhau nên nó không đủ để
sắp thứ tự tuyệt đối trong một sổ cái. Bút toán ví lưu cả biến động lẫn số dư sau biến động,
mang khoá chống ghi trùng do bên gọi cung cấp, và mang mã nhóm để các chặng của cùng một chuyển
động logic — chẳng hạn trừ tiền người mua, giữ tiền tạm và thu phí — có thể được đối soát cùng
nhau.

Đây cũng là lược đồ chứa hai ngoại lệ về khoá đã nói ở phần nguyên tắc: `payment_session` và
`transaction` sinh định danh theo kiểu cho phép ứng dụng chỉ định, vì ứng dụng phải trao định
danh cho cổng thanh toán trước khi hàng dữ liệu tồn tại. Chỉ mục duy nhất trên cặp kênh thanh
toán và mã tham chiếu của cổng là thứ khiến một thông báo lời gọi lại được gửi lại lần thứ hai
va vào ràng buộc thay vì được ghi thành một lần thu tiền thứ hai.

#figure(
  kind: table,
  caption: [Từ điển dữ liệu rút gọn của lược đồ `finance`],
  table(
    columns: (1.2fr, 1.05fr, 1.6fr, 1.5fr),
    align: (left + horizon, left + horizon, left + horizon, left + horizon),
    inset: (x: 5pt, y: 5pt),
    table.header([Cột], [Kiểu], [Ý nghĩa], [Ràng buộc]),

    table.cell(colspan: 4)[*Bảng* `payment_session`],
    [`id`], [`BIGINT`], [Khoá chính], [Sinh theo kiểu cho phép ứng dụng chỉ định giá trị],
    [`kind`], [`session_kind`], [Mục đích của phiên], [`buyer-checkout`, `seller-payout`, `withdrawal`],
    [`status`], [`session_status`], [Trạng thái phiên], [Năm giá trị từ chờ tới thành công hoặc thất bại],
    [`from_id`, `to_id`], [`BIGINT`], [Bên khởi tạo và bên đối ứng], [Rỗng nghĩa là hệ thống],
    [`currency`, `total_amount`], [`VARCHAR(3)`, `BIGINT`], [Loại tiền và tổng tiền phía người mua], [Tổng tiền phải dương; mã tiền ba chữ hoa],
    [`fx_snapshot`], [`JSONB`], [Tỷ giá đóng băng lúc mở phiên], [Rỗng khi không cần quy đổi],
    [`data`], [`JSONB`], [Ngữ cảnh theo loại phiên], [Với phiên rút tiền còn chứa tài khoản nhận và quyết định của quản trị],
    [`expired_at`, `paid_at`], [`TIMESTAMPTZ`], [Hạn tự huỷ và thời điểm thanh toán xong], [Chỉ mục bộ phận cho công việc tự huỷ],

    table.cell(colspan: 4)[*Bảng* `transaction`],
    [`session_id`], [`BIGINT`], [Phiên chứa chặng tiền này], [Khoá ngoại, không cho xoá],
    [`payment_option`], [`VARCHAR(100)`], [Kênh thanh toán cụ thể], [Kiểm tra dạng kebab-case],
    [`provider_ref`], [`TEXT`], [Mã của cổng cho chặng này], [Duy nhất theo cặp với kênh; là khoá chống ghi trùng của lời gọi lại],
    [`amount`], [`BIGINT`], [Số tiền có dấu], [Dương là thu, âm là đảo ứng và bắt buộc có tham chiếu đảo],
    [`reverses_id`], [`BIGINT`], [Bút toán bị đảo], [Khoá ngoại tự trỏ, duy nhất, không được trỏ chính nó],
    [`status`], [`transaction_`\ `status`], [Trạng thái chặng], [`pending`, `success`, `failed`; thành công là trạng thái kết thúc],

    table.cell(colspan: 4)[*Bảng* `wallet`],
    [`account_id`, `currency`], [`BIGINT`, `VARCHAR(3)`], [Khoá chính ghép], [Một tài khoản có thể có nhiều ví theo loại tiền],
    [`available_balance`, `held_balance`], [`BIGINT`], [Số dư khả dụng và số dư tạm giữ], [Cả hai không âm],

    table.cell(colspan: 4)[*Bảng* `wallet_transaction`],
    [`account_id`, `currency`, `seq`], [`BIGINT`, `VARCHAR(3)`, `BIGINT`], [Vị trí tuyệt đối trong sổ cái của một ví], [Duy nhất theo bộ ba; số thứ tự được cấp dưới khoá ghi trên hàng ví],
    [`kind`], [`wallet_`\ `txn_kind`], [Loại chuyển động], [Tám giá trị, gồm giữ tạm, giải toả, hoàn tiền, phí],
    [`available_delta`, `held_delta`], [`BIGINT`], [Biến động có dấu của hai số dư], [Ít nhất một trong hai phải khác không],
    [`available_after`, `held_after`], [`BIGINT`], [Số dư sau chuyển động], [Cả hai không âm],
    [`group_id`], [`BIGINT`], [Nhóm các chặng của cùng một chuyển động logic], [Dùng cho đối soát],
    [`idempotency_key`], [`TEXT`], [Khoá chống ghi trùng do bên gọi cung cấp], [Duy nhất khi khác rỗng],
    [`ref_type`, `ref_id`], [`TEXT`, `BIGINT`], [Đối tượng liên quan ở mô-đun khác], [Rỗng với bút toán điều chỉnh],

    table.cell(colspan: 4)[*Bảng* `bank_account`],
    [`bank_code`, `account_number`], [`VARCHAR(20)`, `VARCHAR(50)`], [Ngân hàng và số tài khoản nhận tiền], [Có chỉ mục để phát hiện một tài khoản dùng cho nhiều người],
    [`is_default`], [`BOOLEAN`], [Tài khoản nhận mặc định], [Chỉ mục duy nhất bộ phận: mỗi tài khoản một mặc định],
    [`deleted_at`], [`TIMESTAMPTZ`], [Xoá mềm], [Lịch sử rút tiền phải giữ được nơi tiền đã đi],

    table.cell(colspan: 4)[*Bảng* `tax_info`],
    [`account_id`], [`BIGINT`], [Khoá chính], [Mỗi tài khoản một bản đăng ký],
    [`tax_code`], [`VARCHAR(14)`], [Mã số thuế], [Kiểm tra dạng mười chữ số, có thể kèm ba chữ số chi nhánh],
    [`verification_`\ `status`], [`verification_`\ `status`], [Kết quả xác minh], [Chỉ mục duy nhất bộ phận: một mã số thuế đã xác minh là duy nhất toàn hệ thống],
  ),
)

```sql
-- finance/migrations/001_init.sql

CREATE TYPE "session_kind" AS ENUM ('buyer-checkout', 'seller-payout',
    'withdrawal');
CREATE TYPE "session_status" AS ENUM ('pending', 'processing', 'success',
    'cancelled', 'failed');
CREATE TYPE "transaction_status" AS ENUM ('pending', 'success', 'failed');
CREATE TYPE "verification_status" AS ENUM ('pending', 'verified', 'rejected');
CREATE TYPE "wallet_txn_kind" AS ENUM ('topup', 'escrow-hold', 'escrow-release',
    'payout', 'refund', 'withdrawal', 'fee', 'adjustment');

CREATE TABLE IF NOT EXISTS "payment_session" (
    "id" BIGINT GENERATED BY DEFAULT AS IDENTITY,
    "kind" "session_kind" NOT NULL,
    "status" "session_status" NOT NULL,
    "from_id" BIGINT,
    "to_id" BIGINT,
    "note" TEXT NOT NULL,

    "currency" VARCHAR(3) NOT NULL,
    "total_amount" BIGINT NOT NULL,

    "fx_snapshot" JSONB,

    "data" JSONB NOT NULL,

    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "paid_at" TIMESTAMPTZ,
    "expired_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "payment_session_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "payment_session_currency_format" CHECK ("currency" ~ '^[A-Z]{3}$'),
    CONSTRAINT "payment_session_total_amount_positive" CHECK ("total_amount" > 0)
);
CREATE INDEX IF NOT EXISTS "payment_session_kind_idx" ON "payment_session" ("kind");
CREATE INDEX IF NOT EXISTS "payment_session_from_id_idx" ON "payment_session"
    ("from_id");
CREATE INDEX IF NOT EXISTS "payment_session_to_id_idx" ON "payment_session"
    ("to_id");
CREATE INDEX IF NOT EXISTS "payment_session_expiring_idx"
    ON "payment_session" ("expired_at")
    WHERE "status" IN ('pending', 'processing');
CREATE INDEX IF NOT EXISTS "payment_session_withdrawal_queue_idx"
    ON "payment_session" ("created_at")
    WHERE "kind" = 'withdrawal' AND "status" IN ('pending', 'processing');

CREATE TABLE IF NOT EXISTS "transaction" (
    "id" BIGINT GENERATED BY DEFAULT AS IDENTITY,
    "session_id" BIGINT NOT NULL,
    "status" "transaction_status" NOT NULL,
    "note" TEXT NOT NULL,
    "error" TEXT,

    "payment_option" VARCHAR(100) NOT NULL,

    "provider_ref" TEXT,

    "data" JSONB NOT NULL,

    "amount" BIGINT NOT NULL,
    "currency" VARCHAR(3) NOT NULL,

    "reverses_id" BIGINT,

    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "settled_at" TIMESTAMPTZ,
    "expired_at" TIMESTAMPTZ,

    CONSTRAINT "transaction_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "transaction_sign_matches_reverses_chk" CHECK (("amount" > 0 AND
        "reverses_id" IS NULL) OR ("amount" < 0 AND "reverses_id" IS NOT NULL)),
    CONSTRAINT "transaction_no_self_reverse_chk" CHECK ("reverses_id" IS NULL OR
        "reverses_id" != "id"),
    CONSTRAINT "transaction_currency_format" CHECK ("currency" ~ '^[A-Z]{3}$'),
    CONSTRAINT "transaction_payment_option_format" CHECK ("payment_option" ~
        '^[a-z0-9]+(-[a-z0-9]+)*$'),

    CONSTRAINT "transaction_session_id_fkey" FOREIGN KEY ("session_id")
        REFERENCES "payment_session" ("id") ON DELETE NO ACTION,
    CONSTRAINT "transaction_reverses_id_fkey" FOREIGN KEY ("reverses_id")
        REFERENCES "transaction" ("id") ON DELETE NO ACTION
);
CREATE INDEX IF NOT EXISTS "transaction_session_id_idx" ON "transaction"
    ("session_id");
CREATE UNIQUE INDEX IF NOT EXISTS "transaction_provider_ref_unique"
    ON "transaction" ("payment_option", "provider_ref")
    WHERE "provider_ref" IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "transaction_reverses_id_unique" ON "transaction"
    ("reverses_id") WHERE "reverses_id" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "transaction_settled_idx" ON "transaction" ("created_at"
    DESC) WHERE "status" = 'success';

CREATE TABLE IF NOT EXISTS "wallet" (
    "account_id" BIGINT NOT NULL,
    "currency" VARCHAR(3) NOT NULL,
    "available_balance" BIGINT NOT NULL DEFAULT 0,
    "held_balance" BIGINT NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "wallet_pkey" PRIMARY KEY ("account_id", "currency"),
    CONSTRAINT "wallet_currency_format" CHECK ("currency" ~ '^[A-Z]{3}$'),
    CONSTRAINT "wallet_available_balance_non_negative" CHECK ("available_balance" >=
        0),
    CONSTRAINT "wallet_held_balance_non_negative" CHECK ("held_balance" >= 0)
);

CREATE TABLE IF NOT EXISTS "wallet_transaction" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "account_id" BIGINT NOT NULL,
    "currency" VARCHAR(3) NOT NULL,
    "seq" BIGINT NOT NULL,
    "kind" "wallet_txn_kind" NOT NULL,
    "available_delta" BIGINT NOT NULL DEFAULT 0,
    "held_delta" BIGINT NOT NULL DEFAULT 0,
    "available_after" BIGINT NOT NULL,
    "held_after" BIGINT NOT NULL,
    "group_id" BIGINT,
    "ref_type" TEXT,
    "ref_id" BIGINT,
    "idempotency_key" TEXT,
    "note" TEXT NOT NULL DEFAULT '',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "wallet_transaction_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "wallet_transaction_wallet_seq_key" UNIQUE ("account_id", "currency",
        "seq"),
    CONSTRAINT "wallet_transaction_currency_format" CHECK ("currency" ~
        '^[A-Z]{3}$'),
    CONSTRAINT "wallet_transaction_after_non_negative" CHECK (
        "available_after" >= 0 AND "held_after" >= 0
    ),
    CONSTRAINT "wallet_transaction_moves_something" CHECK (
        "available_delta" <> 0 OR "held_delta" <> 0
    ),
    CONSTRAINT "wallet_transaction_wallet_fkey" FOREIGN KEY ("account_id",
        "currency")
        REFERENCES "wallet" ("account_id", "currency")
);
CREATE INDEX IF NOT EXISTS "wallet_transaction_ref_idx" ON "wallet_transaction"
    ("ref_type", "ref_id");
CREATE UNIQUE INDEX IF NOT EXISTS "wallet_transaction_idempotency_key_unique"
    ON "wallet_transaction" ("idempotency_key")
    WHERE "idempotency_key" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "wallet_transaction_group_id_idx"
    ON "wallet_transaction" ("group_id")
    WHERE "group_id" IS NOT NULL;

CREATE TABLE IF NOT EXISTS "bank_account" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "account_id" BIGINT NOT NULL,
    "bank_code" VARCHAR(20) NOT NULL,
    "account_number" VARCHAR(50) NOT NULL,
    "account_holder" VARCHAR(100) NOT NULL,
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "bank_account_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "bank_account_account_id_idx" ON "bank_account"
    ("account_id");
CREATE UNIQUE INDEX IF NOT EXISTS "bank_account_one_default_per_account"
    ON "bank_account" ("account_id")
    WHERE "is_default" AND "deleted_at" IS NULL;
CREATE INDEX IF NOT EXISTS "bank_account_bank_code_account_number_idx"
    ON "bank_account" ("bank_code", "account_number");

CREATE TABLE IF NOT EXISTS "tax_info" (
    "account_id"          BIGINT       NOT NULL,
    "tax_code"            VARCHAR(14)  NOT NULL,
    "tax_code_type"       VARCHAR(20)  NOT NULL,
    "legal_name"          TEXT         NOT NULL,
    "verification_status" "verification_status" NOT NULL DEFAULT 'pending',
    "verified_at"         TIMESTAMPTZ,
    "verification_source" TEXT,

    "created_at"          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at"          TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "tax_info_pkey" PRIMARY KEY ("account_id"),
    CONSTRAINT "tax_info_tax_code_format" CHECK ("tax_code" ~ '^\d{10}(-\d{3})?$')
);

CREATE UNIQUE INDEX IF NOT EXISTS "tax_info_tax_code_verified_uq"
    ON "tax_info" ("tax_code")
    WHERE "verification_status" = 'verified';

-- finance/migrations/002_payment_option.sql

INSERT INTO "option" ("id", "is_enabled", "name", "description", "priority", "type",
    "provider")
VALUES (
    'platform-checkout',
    TRUE,
    'Card or bank transfer',
    'The platform''s configured payment provider. Whether it redirects or charges
        directly is the provider''s business.',
    100,
    'payment',
    'platform'
)
ON CONFLICT ("id") DO NOTHING;

-- finance/migrations/003_drop_platform_rail.sql

DELETE FROM "option" WHERE "type" = 'payment' AND "provider" = 'platform';
```

=== Lược đồ `trust`

Lược đồ `trust` giữ ba nhóm dữ liệu hình thành nên uy tín trên chợ: phản hồi giao dịch hai
chiều, đánh giá sản phẩm cùng trả lời và bình chọn hữu ích, và hàng đợi phiếu hỗ trợ.

Phản hồi giao dịch là *mù*: một hàng phản hồi không hiển thị cho tới khi cả hai bên cùng gửi
hoặc cửa sổ mù trôi qua, để một điểm số không thể là đòn trả đũa. Chiều của phản hồi được suy
ra từ việc người gửi đứng ở phía nào của đơn hàng, không bao giờ do bên gửi khai. Chính hành
động công bố mới là hành động cộng điểm vào bảng uy tín, và cả hai diễn ra trong cùng một giao
dịch, nên một điểm đã hiển thị luôn là một điểm đã được tính, và điều kiện "chưa công bố" là
thứ ngăn việc cộng lần thứ hai.

Bảng uy tín tách *hai loại điểm thành hai cặp cột riêng*: điểm từ phản hồi giao dịch nói về
cách đối tác thực hiện giao dịch, còn điểm từ đánh giá sản phẩm nói về món hàng. Một đơn hàng
có thể sinh ra cả hai, nên cộng gộp chúng lại sẽ đếm đơn ấy hai lần. Điểm đánh giá sản phẩm chỉ
áp dụng cho vai người bán, và ràng buộc kiểm tra diễn đạt đúng điều đó.

Thay đổi mô hình hoá lớn nhất của lược đồ này là *mọi thứ người dùng gửi lên đều là một phiếu,
và một bảng duy nhất chứa tất cả*. Bảng `ticket` phủ báo cáo vi phạm, khiếu nại hoàn tiền, sự
cố đơn hàng, vướng mắc thanh toán và đề xuất tính năng, vì tất cả đều là cùng một hình dạng dữ
liệu: có người gửi, có thứ được nhắc tới, có người tiếp nhận và có một phán quyết. Cột `kind`
là điểm khác biệt duy nhất, và nó quyết định phiếu có nói về một đối tượng hay không cũng như
có được phép mang lý do báo cáo hay không. Hệ quả là *không còn bảng tranh chấp riêng và không
còn bảng báo cáo vi phạm riêng*: trước đây ba bảng với bảy trạng thái là cùng một vòng đời được
viết ba lần, và người dùng phải tìm yêu cầu của mình ở ba nơi.

Nội dung trao đổi của phiếu không nằm trong bảng phiếu. Cột `conversation_id` trỏ sang luồng
hội thoại ở lược đồ `chat`, trong đó tin nhắn đầu tiên chính là điều người gửi viết và các tệp
đính kèm của tin nhắn ấy chính là ảnh họ gửi kèm. Nhờ vậy phiếu không cần cột nội dung, không
cần mảng đính kèm và không cần một đường dẫn tải tệp thứ hai. Cột này cho phép rỗng vì hai hàng
nằm ở hai lược đồ khác nhau: phiếu được ghi trước, luồng được mở ngay sau, và nếu bước sau thất
bại thì lần đọc phiếu kế tiếp sẽ mở lại — mất luồng hội thoại không bao giờ được phép làm mất
khiếu nại.

Bảng `order_outcome` chỉ có một nhiệm vụ: ghi nhớ những đơn nào đã được cộng vào bộ đếm kết
cục. Sự kiện đơn hàng đi qua một hàng đợi bảo đảm giao ít nhất một lần, nên một lần giao lại sẽ
cộng bộ đếm hai lần; khoá này được ghi trong cùng giao dịch với lần cộng, khiến lần thử thứ hai
trở thành thao tác rỗng thay vì một tác dụng thứ hai.

#figure(
  kind: table,
  caption: [Từ điển dữ liệu rút gọn của lược đồ `trust`],
  table(
    columns: (1.2fr, 1.05fr, 1.6fr, 1.5fr),
    align: (left + horizon, left + horizon, left + horizon, left + horizon),
    inset: (x: 5pt, y: 5pt),
    table.header([Cột], [Kiểu], [Ý nghĩa], [Ràng buộc]),

    table.cell(colspan: 4)[*Bảng* `feedback`],
    [`order_id`, `direction`], [`BIGINT`, `feedback_`\ `direction`], [Đơn hàng và chiều đánh giá], [Duy nhất theo cặp: mỗi chiều một lần cho mỗi đơn],
    [`rater_id`, `ratee_id`], [`BIGINT`], [Bên chấm và bên được chấm], [Tham chiếu chéo lược đồ],
    [`rating`], [`SMALLINT`], [Điểm số], [Trong khoảng 1 đến 5],
    [`published_at`], [`TIMESTAMPTZ`], [Thời điểm hết mù], [Rỗng nghĩa là chưa hiển thị và chưa được tính],

    table.cell(colspan: 4)[*Bảng* `review`],
    [`listing_id`, `author_id`, `order_id`], [`BIGINT`], [Bài đăng, người viết và đơn hàng], [Duy nhất theo bộ ba: mua hai lần thì được viết hai lần],
    [`seller_id`], [`BIGINT`], [Người bán được tính điểm], [Đóng băng từ đơn hàng lúc viết],
    [`rating`], [`SMALLINT`], [Điểm số], [Trong khoảng 1 đến 5],
    [`attachments`], [`BIGINT[]`], [Ảnh món hàng khi nhận], [Tham chiếu tài nguyên, lưu nội tuyến],
    [`helpful_count`, `not_helpful_count`, `reply_count`], [`BIGINT`], [Bộ đếm sao chép để sắp xếp], [Cả ba không âm],
    [`updated_at`], [`TIMESTAMPTZ`], [Thời điểm người viết sửa lại], [Rỗng cho tới lần sửa đầu tiên],

    table.cell(colspan: 4)[*Bảng* `review_reply`],
    [`review_id`, `author_id`], [`BIGINT`], [Trả lời dưới một đánh giá], [Khoá ngoại xoá lan truyền; không giới hạn số lần],
    table.cell(colspan: 4)[*Bảng* `review_vote`],
    [`review_id`, `account_id`], [`BIGINT`], [Khoá chính ghép], [Mỗi người một phiếu cho mỗi đánh giá],
    [`vote`], [`SMALLINT`], [Giá trị phiếu], [Chỉ nhận -1 hoặc 1; rút phiếu là xoá hàng],

    table.cell(colspan: 4)[*Bảng* `reputation`],
    [`account_id`, `role`], [`BIGINT`, `reputation_`\ `role`], [Khoá chính ghép], [Uy tín tính riêng cho vai người bán và vai người mua],
    [`rating_sum`, `rating_count`], [`BIGINT`], [Tổng và số lượt điểm từ phản hồi giao dịch], [Không âm],
    [`review_rating_sum`, `review_`\ `rating_count`], [`BIGINT`], [Tổng và số lượt điểm từ đánh giá sản phẩm], [Không âm; bắt buộc bằng không ở vai người mua],
    [`completed_orders`, `cancelled_orders`], [`BIGINT`], [Số đơn hoàn tất và số đơn huỷ], [Không âm],

    table.cell(colspan: 4)[*Bảng* `order_outcome`],
    [`order_id`], [`BIGINT`], [Khoá chính], [Khoá chống cộng trùng bộ đếm kết cục],

    table.cell(colspan: 4)[*Bảng* `ticket`],
    [`requester_id`], [`BIGINT`], [Người gửi phiếu], [Tham chiếu chéo lược đồ],
    [`kind`], [`ticket_kind`], [Loại việc được gửi lên], [Mười một giá trị, gồm năm loại báo cáo, khiếu nại hoàn tiền, sự cố đơn hàng, thanh toán, tài khoản, đề xuất tính năng và loại khác],
    [`ref_type`, `ref_id`], [`ticket_`\ `ref_type`, `BIGINT`], [Đối tượng mà phiếu nói tới], [Ràng buộc kiểm tra buộc hai cột cùng có hoặc cùng rỗng; việc loại đối tượng phải khớp loại phiếu là quy tắc của tầng miền, không phải của lược đồ],
    [`reason`], [`ticket_reason`], [Điều bị cho là sai], [Chỉ các loại báo cáo mới được mang giá trị — cũng là quy tắc của tầng miền],
    [`status`], [`ticket_status`], [Trạng thái xử lý], [`open`, `reviewing`, `resolved`],
    [`assignee_id`], [`BIGINT`], [Kiểm duyệt viên đã nhận phiếu], [Bắt buộc khi trạng thái là đang xem xét; không bao giờ công bố cho người gửi],
    [`conversation_id`], [`BIGINT`], [Luồng hội thoại của phiếu], [Duy nhất; tham chiếu chéo lược đồ, cho phép rỗng],
    [`action_taken`, `resolved_by_id`, `resolved_at`], [`ticket_action`, `BIGINT`, `TIMESTAMPTZ`], [Phán quyết, người quyết và thời điểm], [Ba giá trị phải cùng có hoặc cùng rỗng, và phải khớp trạng thái đã giải quyết],
  ),
)

```sql
-- trust/migrations/001_init.sql

CREATE TYPE "feedback_direction" AS ENUM ('buyer-to-seller', 'seller-to-buyer');
CREATE TYPE "reputation_role" AS ENUM ('seller', 'buyer');
CREATE TYPE "ticket_kind" AS ENUM (
    'report-listing', 'report-account', 'report-message', 'report-review',
        'report-review-reply',
    'refund-dispute', 'order-issue', 'payment', 'account', 'feature-request',
        'other'
);
CREATE TYPE "ticket_ref_type" AS ENUM (
    'listing', 'account', 'message', 'review', 'review-reply', 'order', 'refund'
);
CREATE TYPE "ticket_reason" AS ENUM ('scam', 'counterfeit', 'prohibited',
    'harassment', 'spam', 'inappropriate', 'other');
CREATE TYPE "ticket_status" AS ENUM ('open', 'reviewing', 'resolved');
CREATE TYPE "ticket_action" AS ENUM ('none', 'listing-removed', 'message-removed',
    'account-suspended', 'warning', 'refund-granted', 'refund-refused');

CREATE TABLE IF NOT EXISTS "feedback" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "order_id" BIGINT NOT NULL,
    "rater_id" BIGINT NOT NULL,
    "ratee_id" BIGINT NOT NULL,
    "direction" "feedback_direction" NOT NULL,
    "rating" SMALLINT NOT NULL,
    "comment" TEXT NOT NULL DEFAULT '',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "published_at" TIMESTAMPTZ,

    CONSTRAINT "feedback_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "feedback_order_direction_key" UNIQUE ("order_id", "direction"),
    CONSTRAINT "feedback_rating_range_chk" CHECK ("rating" BETWEEN 1 AND 5)
);
CREATE INDEX IF NOT EXISTS "feedback_ratee_id_idx" ON "feedback" ("ratee_id",
    "created_at" DESC, "id" DESC) WHERE "published_at" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "feedback_rater_id_idx" ON "feedback" ("rater_id");
CREATE INDEX IF NOT EXISTS "feedback_unpublished_idx"
    ON "feedback" ("created_at")
    WHERE "published_at" IS NULL;

CREATE TABLE IF NOT EXISTS "review" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "listing_id" BIGINT NOT NULL,
    "order_id" BIGINT NOT NULL,
    "author_id" BIGINT NOT NULL,
    "seller_id" BIGINT NOT NULL,
    "rating" SMALLINT NOT NULL,
    "body" TEXT NOT NULL DEFAULT '',
    "attachments" BIGINT[] NOT NULL DEFAULT '{}',
    "helpful_count" BIGINT NOT NULL DEFAULT 0,
    "not_helpful_count" BIGINT NOT NULL DEFAULT 0,
    "reply_count" BIGINT NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ,

    CONSTRAINT "review_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "review_spu_author_order_key" UNIQUE ("listing_id", "author_id",
        "order_id"),
    CONSTRAINT "review_rating_range_chk" CHECK ("rating" BETWEEN 1 AND 5),
    CONSTRAINT "review_counts_non_negative_chk" CHECK (
        "helpful_count" >= 0 AND "not_helpful_count" >= 0 AND "reply_count" >= 0
    )
);
CREATE INDEX IF NOT EXISTS "review_listing_id_idx" ON "review" ("listing_id",
    "created_at" DESC, "id" DESC);
CREATE INDEX IF NOT EXISTS "review_listing_id_helpful_idx" ON "review"
    ("listing_id", "helpful_count" DESC, "id" DESC);

CREATE TABLE IF NOT EXISTS "review_reply" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "review_id" BIGINT NOT NULL,
    "author_id" BIGINT NOT NULL,
    "body" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "review_reply_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "review_reply_review_id_fkey" FOREIGN KEY ("review_id")
        REFERENCES "review" ("id") ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS "review_reply_review_id_idx" ON "review_reply"
    ("review_id", "created_at");

CREATE TABLE IF NOT EXISTS "review_vote" (
    "review_id" BIGINT NOT NULL,
    "account_id" BIGINT NOT NULL,
    "vote" SMALLINT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "review_vote_pkey" PRIMARY KEY ("review_id", "account_id"),
    CONSTRAINT "review_vote_value" CHECK ("vote" IN (-1, 1)),
    CONSTRAINT "review_vote_review_id_fkey" FOREIGN KEY ("review_id")
        REFERENCES "review" ("id") ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS "reputation" (
    "account_id" BIGINT NOT NULL,
    "role" "reputation_role" NOT NULL,
    "rating_sum" BIGINT NOT NULL DEFAULT 0,
    "rating_count" BIGINT NOT NULL DEFAULT 0,
    "review_rating_sum" BIGINT NOT NULL DEFAULT 0,
    "review_rating_count" BIGINT NOT NULL DEFAULT 0,
    "completed_orders" BIGINT NOT NULL DEFAULT 0,
    "cancelled_orders" BIGINT NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "reputation_pkey" PRIMARY KEY ("account_id", "role"),
    CONSTRAINT "reputation_reviews_are_seller_only" CHECK (
        "role" = 'seller'
        OR ("review_rating_sum" = 0 AND "review_rating_count" = 0)
    ),
    CONSTRAINT "reputation_counters_non_negative" CHECK (
        "rating_sum" >= 0 AND "rating_count" >= 0
        AND "review_rating_sum" >= 0 AND "review_rating_count" >= 0
        AND "completed_orders" >= 0 AND "cancelled_orders" >= 0
    )
);

CREATE TABLE IF NOT EXISTS "order_outcome" (
    "order_id" BIGINT NOT NULL,
    "completed" BOOLEAN NOT NULL,
    "recorded_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "order_outcome_pkey" PRIMARY KEY ("order_id")
);

CREATE TABLE IF NOT EXISTS "ticket" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "requester_id" BIGINT NOT NULL,
    "kind" "ticket_kind" NOT NULL,
    "subject" TEXT NOT NULL,
    "ref_type" "ticket_ref_type",
    "ref_id" BIGINT,
    "reason" "ticket_reason",
    "status" "ticket_status" NOT NULL DEFAULT 'open',
    "assignee_id" BIGINT,
    "conversation_id" BIGINT,

    "action_taken" "ticket_action",
    "resolved_by_id" BIGINT,
    "resolved_at" TIMESTAMPTZ,
    "resolution_note" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ticket_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ticket_subject_present" CHECK (length(btrim("subject")) > 0),
    CONSTRAINT "ticket_ref_together" CHECK (("ref_type" IS NULL) = ("ref_id" IS
        NULL)),
    CONSTRAINT "ticket_resolution_together" CHECK (
        (("status" = 'resolved') = ("resolved_at" IS NOT NULL))
        AND (("resolved_at" IS NULL) = ("resolved_by_id" IS NULL))
        AND (("resolved_at" IS NULL) = ("action_taken" IS NULL))
    ),
    CONSTRAINT "ticket_assignee_when_reviewing" CHECK (
        "status" <> 'reviewing' OR "assignee_id" IS NOT NULL
    ),
    CONSTRAINT "ticket_conversation_id_key" UNIQUE ("conversation_id")
);
CREATE INDEX IF NOT EXISTS "ticket_ref_idx" ON "ticket" ("ref_type", "ref_id");
CREATE INDEX IF NOT EXISTS "ticket_requester_idx" ON "ticket" ("requester_id",
    "created_at" DESC, "id" DESC);
CREATE INDEX IF NOT EXISTS "ticket_queue_idx"
    ON "ticket" ("created_at", "id")
    WHERE "status" IN ('open', 'reviewing');
CREATE UNIQUE INDEX IF NOT EXISTS "ticket_one_open_per_target"
    ON "ticket" ("requester_id", "ref_type", "ref_id")
    WHERE "status" IN ('open', 'reviewing') AND "ref_type" IS NOT NULL;
```

=== Lược đồ `chat`

Lược đồ `chat` chỉ có hai bảng, nhưng cả hai đều mang những quyết định thiết kế đáng nói.

Một luồng hội thoại là *một luồng cho mỗi cặp tài khoản*, bất kể ai mua ai bán và bất kể đang
nói về món hàng nào. Cặp tài khoản được lưu theo thứ tự tăng dần cùng một ràng buộc kiểm tra,
nên chỉ mục duy nhất không thể bị lách bằng cách đổi chỗ hai đầu, và cùng ràng buộc ấy loại trừ
luôn trường hợp một tài khoản tự mở luồng với chính mình. Ngữ cảnh sản phẩm không nằm ở luồng
mà nằm ở từng tin nhắn. Riêng với thương lượng giá, tin nhắn chỉ mang định danh cuộc thương
lượng trong phần siêu dữ liệu chứ tuyệt đối không chép giá vào: nếu chép, một lần sửa đề xuất
sẽ để lại trong luồng một mức giá không còn trên bàn đàm phán.

Cột `kind` phân biệt luồng trực tiếp với luồng phiếu hỗ trợ. Ở luồng phiếu, phía bên kia không
phải một con người mà là *tài khoản riêng của bộ phận hỗ trợ*, nhờ đó kiểm duyệt viên trả lời
vẫn ẩn danh với người gửi, người tiếp nhận kế tiếp thừa hưởng đúng luồng cũ, và không cần một
đầu tham gia cho phép rỗng nào cả. Vì một người dùng có thể mở nhiều phiếu và cả chúng đều ghép
cùng một cặp tài khoản, ràng buộc một-luồng-cho-mỗi-cặp phải trở thành *chỉ mục duy nhất bộ
phận* chỉ áp cho luồng trực tiếp.

Trạng thái đọc *không* được lưu trên từng tin nhắn mà là hai dấu thời gian trên hàng hội thoại.
Đây là lựa chọn bắt buộc bởi việc bảng tin nhắn là bảng phân mảnh theo thời gian: một cờ đã đọc
trên từng tin sẽ biến mọi câu hỏi về tin chưa đọc thành một phép đếm không có cận thời gian,
nghĩa là không thể loại bỏ mảnh dữ liệu cũ, và việc đánh dấu đã đọc một luồng sẽ phải cập nhật
mọi hàng chưa đọc trong luồng, tức là làm bẩn những mảnh cũ để ghi lại một sự việc của hiện
tại. Hai dấu thời gian trả lời được cả ba câu hỏi — số tin chưa đọc, danh sách hộp thư, và biên
nhận đã xem — chỉ từ một hàng. Bảng tin nhắn *không* có chính sách xoá theo thời gian, khác với
bảng thông báo, vì tin nhắn là bằng chứng trong tranh chấp hoàn tiền.

#figure(
  kind: table,
  caption: [Từ điển dữ liệu rút gọn của lược đồ `chat`],
  table(
    columns: (1.2fr, 1.05fr, 1.6fr, 1.5fr),
    align: (left + horizon, left + horizon, left + horizon, left + horizon),
    inset: (x: 5pt, y: 5pt),
    table.header([Cột], [Kiểu], [Ý nghĩa], [Ràng buộc]),

    table.cell(colspan: 4)[*Bảng* `conversation`],
    [`kind`], [`conversation_`\ `kind`], [Loại luồng], [`direct` hoặc `ticket`, mặc định trực tiếp],
    [`ticket_id`], [`BIGINT`], [Phiếu hỗ trợ mà luồng phục vụ], [Phải có đúng khi loại là phiếu; chỉ mục duy nhất bộ phận khiến việc mở luồng có thể thử lại],
    [`account_a_id`, `account_b_id`], [`BIGINT`], [Hai bên tham gia], [Bắt buộc lưu theo thứ tự tăng dần; duy nhất theo cặp với luồng trực tiếp],
    [`last_message_at`], [`TIMESTAMPTZ`], [Mốc sắp xếp hộp thư], [Sao chép, do dịch vụ duy trì],
    [`account_a_read_at`, `account_b_read_at`], [`TIMESTAMPTZ`], [Mốc đã đọc của từng bên], [Thay cho trạng thái đọc trên từng tin nhắn],

    table.cell(colspan: 4)[*Bảng* `message`],
    [`id`, `created_at`], [`BIGINT`, `TIMESTAMPTZ`], [Khoá chính ghép], [Cột thời gian phải nằm trong khoá vì bảng phân mảnh theo thời gian],
    [`conversation_id`], [`BIGINT`], [Luồng chứa tin nhắn], [Khoá ngoại, xoá lan truyền],
    [`sender_id`], [`BIGINT`], [Người gửi], [Rỗng đúng khi và chỉ khi tin nhắn do hệ thống sinh],
    [`type`], [`message_type`], [Nguồn gốc tin nhắn], [`user` hoặc `system`],
    [`attachments`], [`BIGINT[]`], [Tệp đính kèm], [Tham chiếu tài nguyên, lưu nội tuyến],
    [`metadata`], [`JSONB`], [Định danh đối tượng được nhắc tới], [Chỉ chứa định danh, không chép điều khoản giá],
    [`edited_at`, `deleted_at`], [`TIMESTAMPTZ`], [Sửa và thu hồi], [Thu hồi là xoá mềm, phục vụ cả kiểm duyệt],
  ),
)

```sql
-- chat/migrations/001_init.sql

CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE TYPE "conversation_kind" AS ENUM ('direct', 'ticket');
CREATE TYPE "message_type" AS ENUM ('user', 'system');

CREATE TABLE IF NOT EXISTS "conversation" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "kind" "conversation_kind" NOT NULL DEFAULT 'direct',
    "ticket_id" BIGINT,
    "account_a_id" BIGINT NOT NULL,
    "account_b_id" BIGINT NOT NULL,
    "last_message_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "account_a_read_at" TIMESTAMPTZ,
    "account_b_read_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "conversation_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "conversation_pair_ordered" CHECK ("account_a_id" < "account_b_id"),
    CONSTRAINT "conversation_ticket_matches_kind" CHECK (("kind" = 'ticket') =
        ("ticket_id" IS NOT NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS "conversation_pair_key"
    ON "conversation" ("account_a_id", "account_b_id")
    WHERE "kind" = 'direct';
CREATE UNIQUE INDEX IF NOT EXISTS "conversation_ticket_id_key"
    ON "conversation" ("ticket_id")
    WHERE "ticket_id" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "conversation_account_a_id_idx"
    ON "conversation" ("account_a_id", "last_message_at" DESC);
CREATE INDEX IF NOT EXISTS "conversation_account_b_id_idx"
    ON "conversation" ("account_b_id", "last_message_at" DESC);

CREATE TABLE IF NOT EXISTS "message" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "conversation_id" BIGINT NOT NULL,
    "sender_id" BIGINT,
    "type" "message_type" NOT NULL DEFAULT 'user',
    "body" TEXT NOT NULL,
    "attachments" BIGINT[] NOT NULL DEFAULT '{}',
    "metadata" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "edited_at" TIMESTAMPTZ,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "message_pkey" PRIMARY KEY ("id", "created_at"),
    CONSTRAINT "message_sender_matches_type" CHECK (
        ("type" = 'system') = ("sender_id" IS NULL)
    ),

    CONSTRAINT "message_conversation_id_fkey" FOREIGN KEY ("conversation_id")
        REFERENCES "conversation" ("id") ON DELETE CASCADE
);
SELECT create_hypertable('message', 'created_at', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS "message_conversation_id_created_at_idx"
    ON "message" ("conversation_id", "created_at" DESC);
CREATE INDEX IF NOT EXISTS "message_sender_id_idx"
    ON "message" ("sender_id", "created_at" DESC);
```

=== Lược đồ `observability`

Lược đồ `observability` không chứa dữ liệu nghiệp vụ mà chứa dữ liệu đo đạc vận hành. Nó là
lược đồ duy nhất không nhận phần định nghĩa dùng chung, vì ở đây không có gì để kiểm toán và
không có tệp nào được tải lên.

Bốn bảng ứng với bốn tín hiệu: yêu cầu HTTP vào hệ thống, lời gọi ra tới nhà cung cấp bên thứ
ba, sự kiện nghiệp vụ được phản chiếu từ hàng đợi sự kiện, và số đo thời gian chạy của tiến
trình. Mọi hàng đều mang cột `instance` định danh tiến trình đã ghi nó, nếu không nhiều bản sao
của cùng một dịch vụ sẽ trộn lẫn thành một chuỗi số liệu vô nghĩa. Đường dẫn trong bảng lời gọi
ra được lưu ở dạng mẫu chứ không phải đường dẫn thật, và không kèm chuỗi truy vấn — vì chuỗi
truy vấn có thể chứa thông tin xác thực, còn một định danh nhúng trong đường dẫn sẽ làm số
lượng giá trị phân biệt bùng nổ. Tương tự, bảng sự kiện nghiệp vụ chỉ phản chiếu định danh, số
tiền và trạng thái chứ không phản chiếu dữ liệu cá nhân, vì bảng điều khiển giám sát có phạm vi
người đọc rộng hơn nhiều so với bảng dữ liệu gốc.

Cả bốn bảng đều là bảng phân mảnh theo thời gian, đều được chuyển sang lưu trữ theo cột sau
bảy ngày và đều có chính sách xoá theo thời gian: ba mươi ngày cho hai tín hiệu tần suất cao,
chín mươi ngày cho số đo thời gian chạy, một trăm tám mươi ngày cho sự kiện nghiệp vụ. Dữ liệu
giám sát giữ mãi mãi sẽ làm sập chính cơ sở dữ liệu mà nó đang giám sát.

Hai khung nhìn kết tụ liên tục tính sẵn số liệu theo từng phút để bảng điều khiển không phải
quét dữ liệu thô. Điểm kỹ thuật đáng chú ý là *phân vị trễ được lưu dưới dạng phác thảo dữ liệu
chứ không phải một con số*: trung bình che mất phần đuôi của phân bố, còn một phân vị tính trực
tiếp thì không thể kết tụ dần vì cần toàn bộ dữ liệu. Kiểu phác thảo của bộ công cụ TimescaleDB
kết tụ được từng phần, nhờ đó phân vị 95 được vật chất hoá như mọi số liệu khác và vẫn đúng khi
gộp nhiều khoảng thời gian — trong khi lấy trung bình của các phân vị 95 thì không. Bản thân
hai khung nhìn này cũng có chính sách xoá theo thời gian là một năm, vì chúng cũng là bảng phân
mảnh và là bảng duy nhất ở đây có thể lớn lên vô hạn nếu bị bỏ quên.

#figure(
  kind: table,
  caption: [Từ điển dữ liệu rút gọn của lược đồ `observability`],
  table(
    columns: (1.2fr, 1.05fr, 1.6fr, 1.5fr),
    align: (left + horizon, left + horizon, left + horizon, left + horizon),
    inset: (x: 5pt, y: 5pt),
    table.header([Cột], [Kiểu], [Ý nghĩa], [Ràng buộc]),

    table.cell(colspan: 4)[*Bảng* `http_requests`],
    [`ts`], [`TIMESTAMPTZ`], [Thời điểm ghi, cũng là cột phân mảnh], [Mảnh một ngày, giữ 30 ngày],
    [`instance`], [`TEXT`], [Tiến trình đã phục vụ yêu cầu], [Bắt buộc, để nhiều bản sao không trộn lẫn],
    [`route`], [`TEXT`], [Mẫu tuyến đã khớp, không phải đường dẫn thật], [Giữ số giá trị phân biệt bằng số tuyến đã đăng ký],
    [`status`, `duration_ms`], [`INT`, `DOUBLE`\ `PRECISION`], [Mã trạng thái và thời lượng], [Có chỉ mục bộ phận riêng cho nhóm lỗi máy chủ],

    table.cell(colspan: 4)[*Bảng* `provider_calls`],
    [`provider`, `path`], [`TEXT`], [Nhà cung cấp và đường dẫn dạng mẫu], [Không kèm chuỗi truy vấn],
    [`status`], [`INT`], [Mã trạng thái], [Giá trị 0 nghĩa là không có phản hồi nào tới],
    [`failed`], [`BOOLEAN`], [Lỗi truyền tải hoặc lỗi máy chủ], [Mã lỗi phía người gọi được coi là câu trả lời hợp lệ],
    [`duration_ms`], [`DOUBLE`\ `PRECISION`], [Thời gian tới khi nhận đầu phản hồi], [Với luồng dữ liệu, đây là thời gian tới byte đầu tiên],

    table.cell(colspan: 4)[*Bảng* `business_events`],
    [`topic`, `payload`], [`TEXT`, `JSONB`], [Chủ đề và nội dung sự kiện], [Chỉ phản chiếu định danh, số tiền và trạng thái; giữ 180 ngày],

    table.cell(colspan: 4)[*Bảng* `runtime_metrics`],
    [`goroutines`, `heap_alloc_bytes`, `heap_inuse_bytes`], [`INT`, `BIGINT`], [Số luồng nhẹ và bộ nhớ đống], [Lấy mẫu định kỳ; giữ 90 ngày],
    [`gc_pause_ms`, `num_gc`], [`DOUBLE`\ `PRECISION`, `BIGINT`], [Thời gian dừng thu gom rác và số lần thu gom], [],
    [`websocket_conns`], [`INTEGER`], [Số kết nối thời gian thực đang mở], [Thêm bởi tệp di trú 002, vì tuyến kết nối dài không được ghi vào bảng yêu cầu HTTP],

    table.cell(colspan: 4)[*Khung nhìn kết tụ liên tục* `http_requests_1m`],
    [`bucket`, `calls`, `avg_ms`, `max_ms`], [Khung nhìn kết tụ], [Số liệu theo từng phút], [Giữ 365 ngày],
    [`latency`], [Phác thảo phân vị], [Cấu trúc cho phép kết tụ dần], [Đọc phân vị 95 bằng hàm xấp xỉ, không bao giờ bằng cách lấy trung bình các phân vị],
    table.cell(colspan: 4)[*Khung nhìn kết tụ liên tục* `provider_calls_1m`],
    [`failures`], [`BIGINT`], [Số lời gọi thất bại theo từng phút], [Vật chất hoá sẵn để định nghĩa "thất bại" chỉ tồn tại ở một chỗ],
  ),
)

```sql
-- observability/migrations/001_init.sql

CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit
WITH
  SCHEMA public;

CREATE TABLE IF NOT EXISTS "http_requests" (
    "ts"          TIMESTAMPTZ      NOT NULL DEFAULT now(),
    "instance"    TEXT             NOT NULL,
    "method"      TEXT             NOT NULL,
    "route"       TEXT             NOT NULL,
    "status"      INT              NOT NULL,
    "duration_ms" DOUBLE PRECISION NOT NULL
);
SELECT create_hypertable('http_requests', 'ts', chunk_time_interval => INTERVAL '1
    day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS "http_requests_route_ts_idx" ON "http_requests" ("route",
    "ts" DESC);
CREATE INDEX IF NOT EXISTS "http_requests_errors_ts_idx" ON "http_requests" ("ts"
    DESC) WHERE "status" >= 500;
ALTER TABLE "http_requests" SET (
    timescaledb.enable_columnstore = true,
    timescaledb.segmentby = 'route',
    timescaledb.orderby = 'ts DESC'
);
CALL add_columnstore_policy('http_requests', after => INTERVAL '7 days',
    if_not_exists => TRUE);
SELECT add_retention_policy('http_requests', INTERVAL '30 days', if_not_exists =>
    TRUE);

CREATE TABLE IF NOT EXISTS "provider_calls" (
    "ts"          TIMESTAMPTZ      NOT NULL DEFAULT now(),
    "instance"    TEXT             NOT NULL,
    "provider"    TEXT             NOT NULL,
    "method"      TEXT             NOT NULL,
    "path"        TEXT             NOT NULL,
    "status"      INT              NOT NULL,
    "duration_ms" DOUBLE PRECISION NOT NULL,
    "failed"      BOOLEAN          NOT NULL,
    "error"       TEXT             NOT NULL DEFAULT ''
);
SELECT create_hypertable('provider_calls', 'ts', chunk_time_interval => INTERVAL '1
    day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS "provider_calls_provider_ts_idx" ON "provider_calls"
    ("provider", "ts" DESC);
ALTER TABLE "provider_calls" SET (
    timescaledb.enable_columnstore = true,
    timescaledb.segmentby = 'provider',
    timescaledb.orderby = 'ts DESC'
);
CALL add_columnstore_policy('provider_calls', after => INTERVAL '7 days',
    if_not_exists => TRUE);
SELECT add_retention_policy('provider_calls', INTERVAL '30 days', if_not_exists =>
    TRUE);

CREATE TABLE IF NOT EXISTS "business_events" (
    "ts"       TIMESTAMPTZ NOT NULL DEFAULT now(),
    "instance" TEXT        NOT NULL,
    "topic"    TEXT        NOT NULL,
    "payload"  JSONB       NOT NULL
);
SELECT create_hypertable('business_events', 'ts', chunk_time_interval => INTERVAL '1
    day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS "business_events_topic_ts_idx" ON "business_events"
    ("topic", "ts" DESC);
ALTER TABLE "business_events" SET (
    timescaledb.enable_columnstore = true,
    timescaledb.segmentby = 'topic',
    timescaledb.orderby = 'ts DESC'
);
CALL add_columnstore_policy('business_events', after => INTERVAL '7 days',
    if_not_exists => TRUE);
SELECT add_retention_policy('business_events', INTERVAL '180 days', if_not_exists =>
    TRUE);

CREATE TABLE IF NOT EXISTS "runtime_metrics" (
    "ts"               TIMESTAMPTZ      NOT NULL DEFAULT now(),
    "instance"         TEXT             NOT NULL,
    "goroutines"       INT              NOT NULL,
    "heap_alloc_bytes" BIGINT           NOT NULL,
    "heap_inuse_bytes" BIGINT           NOT NULL,
    "gc_pause_ms"      DOUBLE PRECISION NOT NULL,
    "num_gc"           BIGINT           NOT NULL
);
SELECT create_hypertable('runtime_metrics', 'ts', chunk_time_interval => INTERVAL '7
    days', if_not_exists => TRUE);
ALTER TABLE "runtime_metrics" SET (
    timescaledb.enable_columnstore = true,
    timescaledb.segmentby = 'instance',
    timescaledb.orderby = 'ts DESC'
);
CALL add_columnstore_policy('runtime_metrics', after => INTERVAL '7 days',
    if_not_exists => TRUE);
SELECT add_retention_policy('runtime_metrics', INTERVAL '90 days', if_not_exists =>
    TRUE);

CREATE MATERIALIZED VIEW IF NOT EXISTS "http_requests_1m"
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT time_bucket(INTERVAL '1 minute', "ts") AS "bucket",
       "instance",
       "route",
       "status",
       count(*)             AS "calls",
       avg("duration_ms")   AS "avg_ms",
       max("duration_ms")   AS "max_ms",
       percentile_agg("duration_ms") AS "latency"
FROM "http_requests"
GROUP BY "bucket", "instance", "route", "status"
WITH NO DATA;
SELECT add_continuous_aggregate_policy('http_requests_1m',
    start_offset      => INTERVAL '1 day',
    end_offset        => INTERVAL '1 minute',
    schedule_interval => INTERVAL '1 minute',
    if_not_exists     => TRUE);
ALTER MATERIALIZED VIEW "http_requests_1m" SET (
    timescaledb.enable_columnstore = true,
    timescaledb.segmentby = 'route'
);
CALL add_columnstore_policy('http_requests_1m', after => INTERVAL '30 days',
    if_not_exists => TRUE);
SELECT add_retention_policy('http_requests_1m', INTERVAL '365 days', if_not_exists
    => TRUE);

CREATE MATERIALIZED VIEW IF NOT EXISTS "provider_calls_1m"
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT time_bucket(INTERVAL '1 minute', "ts") AS "bucket",
       "instance",
       "provider",
       "status",
       count(*)                          AS "calls",
       count(*) FILTER (WHERE "failed")  AS "failures",
       avg("duration_ms")                AS "avg_ms",
       max("duration_ms")                AS "max_ms",
       percentile_agg("duration_ms")     AS "latency"
FROM "provider_calls"
GROUP BY "bucket", "instance", "provider", "status"
WITH NO DATA;
SELECT add_continuous_aggregate_policy('provider_calls_1m',
    start_offset      => INTERVAL '1 day',
    end_offset        => INTERVAL '1 minute',
    schedule_interval => INTERVAL '1 minute',
    if_not_exists     => TRUE);
ALTER MATERIALIZED VIEW "provider_calls_1m" SET (
    timescaledb.enable_columnstore = true,
    timescaledb.segmentby = 'provider'
);
CALL add_columnstore_policy('provider_calls_1m', after => INTERVAL '30 days',
    if_not_exists => TRUE);
SELECT add_retention_policy('provider_calls_1m', INTERVAL '365 days', if_not_exists
    => TRUE);

-- observability/migrations/002_websocket_conns.sql

ALTER TABLE "runtime_metrics" ADD COLUMN "websocket_conns" INTEGER NOT NULL DEFAULT
    0;
```

=== Các bảng dùng chung

Ba bảng cuối cùng cần được hiểu khác với bảy lược đồ ở trên, và đây là chỗ dễ mô tả sai nhất
của toàn bộ thiết kế. `common` *không phải một mô-đun và không phải một lược đồ*. Nó không có
giao diện dịch vụ, không có tiến trình nào gọi tới nó, và công cụ di trú không hề tạo ra một
lược đồ nào tên như vậy. Cái mà `common` cung cấp là *phần định nghĩa dữ liệu dùng chung*: ba
tệp định nghĩa được áp vào lược đồ của *từng* mô-đun nghiệp vụ, trước khi các tệp di trú riêng
của mô-đun đó được áp. Kết quả là câu lệnh tạo bảng chỉ tồn tại một lần trong mã nguồn, còn
bảng thì tồn tại một bản trong mỗi lược đồ — sáu lược đồ nghiệp vụ nhận ba bảng này, tổng cộng
mười tám bảng, và lược đồ `observability` không nhận.

Lý do không dùng một bảng toàn cục dùng chung chính là nguyên tắc cô lập theo lược đồ. Một bảng
nhật ký kiểm toán dùng chung cho mọi mô-đun sẽ là thứ *duy nhất* không thể đi theo một mô-đun
khi mô-đun ấy tách sang cơ sở dữ liệu riêng. Trước khi hợp nhất, bảy mô-đun đều tự chép một
bản nhật ký kiểm toán và bốn trong số các bản chép ấy đã trôi khác nhau; cách làm hiện tại giữ
được cả tính di động lẫn tính nhất quán của định nghĩa.

Bảng `audit_log` là nơi mọi thay đổi để lại dấu vết. Điều quan trọng về mặt thiết kế là *hàng
nhật ký được ghi trong cùng giao dịch với chính thay đổi ấy*, nên một lần ghi đã thành công thì
luôn có dấu vết, và nội dung dấu vết đến từ quyết định của tầng miền chứ không phải từ một phép
dựng lại. Cột `version` tăng dần theo từng bản ghi được sửa, cùng với ràng buộc duy nhất trên
bộ ba tên bảng, định danh bản ghi và phiên bản. Hai cột `diff` và `snapshot` lưu lần lượt sự
việc đã xảy ra và trạng thái bản ghi sau thay đổi.

Bảng `resource` giữ siêu dữ liệu của tệp đã tải lên. Ba chi tiết đáng chú ý. Thứ nhất, hàng
được tạo ở trạng thái *đặt chỗ*: cột `completed_at` chỉ được đặt khi tệp đã thực sự được đọc
ngược lại từ kho lưu trữ, và một tài nguyên chưa hoàn tất thì không được phép gắn vào bất cứ
thứ gì. Thứ hai, mã băm nội dung chỉ được ghi khi nó là mã băm *đọc lại từ kho*, và ràng buộc
kiểm tra diễn đạt đúng điều đó — mã băm do phía tải lên tự khai chỉ được dùng để tra xem đã có
tệp trùng hay chưa rồi bị bỏ đi, vì nếu lưu lại thì bất kỳ ai cũng có thể đặt chỗ, khai mã băm
của những byte họ không có, và khiến lần tải lên trung thực tiếp theo bị trỏ vào đối tượng của
họ. Thứ ba, tài nguyên chỉ xoá mềm, vì cặp nhà cung cấp và khoá đối tượng là đường duy nhất
tìm lại được tệp trong kho; xoá hàng trước khi tệp bị dọn sẽ làm rò rỉ tệp vĩnh viễn.

Bảng `option` là sổ đăng ký các tuỳ chọn mà mô-đun sở hữu nó tác động lên: `finance` sở hữu các
kênh thanh toán, `order` sở hữu các hãng vận chuyển. Định danh là một khoá tự nhiên dạng chuỗi
và là *bất biến*, vì một giao dịch đã quyết toán và một đơn đã giao đều lưu chuỗi ấy như văn
bản thuần không kèm khoá ngoại; do đó bảng cũng chỉ xoá mềm. Cột `vault_secret_path` chỉ lưu
*đường dẫn tới* nơi cất bí mật của tuỳ chọn đó, không bao giờ lưu chính bí mật, nên trong cơ sở
dữ liệu này, trong các bản sao lưu của nó, trong các bản sao đọc của nó và trong cả ảnh chụp
nhật ký kiểm toán đều không có vật liệu khoá nào.

#figure(
  kind: table,
  caption: [Từ điển dữ liệu rút gọn của ba bảng dùng chung, hiện diện trong mỗi lược đồ nghiệp vụ],
  table(
    columns: (1.2fr, 1.05fr, 1.6fr, 1.5fr),
    align: (left + horizon, left + horizon, left + horizon, left + horizon),
    inset: (x: 5pt, y: 5pt),
    table.header([Cột], [Kiểu], [Ý nghĩa], [Ràng buộc]),

    table.cell(colspan: 4)[*Bảng* `audit_log`],
    [`table_name`, `record_id`, `version`], [`VARCHAR(100)`, `BIGINT`, `BIGINT`], [Bản ghi bị thay đổi và phiên bản thay đổi], [Duy nhất theo bộ ba; định danh bản ghi là số nguyên chứ không phải chuỗi],
    [`change_type`], [`VARCHAR(10)`], [Loại thao tác], [`insert`, `update`, `delete`],
    [`code`], [`VARCHAR(100)`], [Mã nghiệp vụ mà mô-đun đã ghi nhận], [Ví dụ `listing.publish`, `account.suspend`],
    [`changed_by`], [`BIGINT`], [Tài khoản chịu trách nhiệm], [Rỗng với công việc nền hoặc lời gọi lại của nhà cung cấp],
    [`diff`, `snapshot`], [`JSONB`], [Sự việc đã ghi nhận và trạng thái sau thay đổi], [Cả hai bắt buộc],

    table.cell(colspan: 4)[*Bảng* `resource`],
    [`provider`, `object_key`], [`TEXT`, `VARCHAR(2048)`], [Kho lưu trữ và khoá đối tượng trong kho], [Duy nhất theo cặp; kiểm tra dạng kebab-case cho kho],
    [`mime`, `size`], [`VARCHAR(100)`, `BIGINT`], [Kiểu nội dung và kích thước], [Kích thước không âm],
    [`checksum`], [`TEXT`], [Mã băm nội dung], [Chỉ được có giá trị khi tải lên đã hoàn tất],
    [`completed_at`], [`TIMESTAMPTZ`], [Thời điểm xác nhận tải lên], [Rỗng nghĩa là hàng mới chỉ là một chỗ đặt trước],
    [`deleted_at`], [`TIMESTAMPTZ`], [Xoá mềm], [Hàng phải sống lâu hơn yêu cầu xoá cho tới khi tệp bị dọn khỏi kho],

    table.cell(colspan: 4)[*Bảng* `option`],
    [`id`], [`VARCHAR(100)`], [Chuỗi định danh ổn định], [Khoá chính tự nhiên, bất biến, kiểm tra dạng kebab-case],
    [`type`, `provider`], [`TEXT`], [Nhóm và nhà cung cấp thực thi], [Cùng kiểm tra dạng kebab-case],
    [`is_enabled`, `priority`], [`BOOLEAN`, `INTEGER`], [Còn phục vụ hay không và thứ tự hiển thị], [Chỉ mục bộ phận phục vụ danh sách lúc thanh toán],
    [`data`], [`JSONB`], [Cấu hình không bí mật], [Điểm cuối, loại tiền hỗ trợ, cờ tính năng],
    [`vault_secret_path`], [`TEXT`], [Đường dẫn tới nơi cất thông tin xác thực], [Không bao giờ lưu chính bí mật],
    [`deleted_at`], [`TIMESTAMPTZ`], [Xoá mềm], [Bản ghi cũ vẫn phải phân giải được tên kênh hoặc tên hãng],
  ),
)

```sql
-- common/migrations/000_shared_audit_log.sql

CREATE TABLE
  IF NOT EXISTS "audit_log" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "version" BIGINT NOT NULL DEFAULT 1,
    "table_name" VARCHAR(100) NOT NULL,
    "record_id" BIGINT NOT NULL,
    "change_type" VARCHAR(10) NOT NULL,
    "code" VARCHAR(100) NOT NULL,
    "changed_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "changed_by" BIGINT,
    "diff" JSONB NOT NULL,
    "snapshot" JSONB NOT NULL,
    CONSTRAINT "audit_log_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "audit_log_table_name_record_id_version_key" UNIQUE ("table_name",
        "record_id", "version")
  );

-- common/migrations/001_shared_resource.sql

CREATE TABLE IF NOT EXISTS "resource" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "uploaded_by_id" BIGINT,
    "provider" TEXT NOT NULL,
    "object_key" VARCHAR(2048) NOT NULL,
    "mime" VARCHAR(100) NOT NULL,
    "size" BIGINT NOT NULL,
    "metadata" JSONB NOT NULL DEFAULT '{}',
    "checksum" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMPTZ,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "resource_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "resource_provider_object_key_key" UNIQUE ("provider", "object_key"),
    CONSTRAINT "resource_provider_format" CHECK ("provider" ~
        '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT "resource_size_non_negative" CHECK ("size" >= 0),
    CONSTRAINT "resource_checksum_needs_completion" CHECK (
        "checksum" IS NULL OR "completed_at" IS NOT NULL
    )
);
CREATE INDEX IF NOT EXISTS "resource_pending_deletion_idx"
    ON "resource" ("deleted_at")
    WHERE "deleted_at" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "resource_abandoned_idx"
    ON "resource" ("created_at")
    WHERE "completed_at" IS NULL AND "deleted_at" IS NULL;
CREATE INDEX IF NOT EXISTS "resource_uploaded_by_id_idx" ON "resource"
    ("uploaded_by_id");
CREATE INDEX IF NOT EXISTS "resource_uploader_checksum_idx"
    ON "resource" ("uploaded_by_id", "checksum")
    WHERE "checksum" IS NOT NULL AND "deleted_at" IS NULL;

-- common/migrations/002_shared_option.sql

CREATE TABLE IF NOT EXISTS "option" (
    "id" VARCHAR(100) NOT NULL,
    "owner_id" BIGINT,
    "is_enabled" BOOLEAN NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "priority" INTEGER NOT NULL,
    "logo_resource_id" BIGINT,
    "data" JSONB NOT NULL DEFAULT '{}',
    "vault_secret_path" TEXT,

    "type" TEXT NOT NULL,
    "provider" TEXT NOT NULL,

    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMPTZ,

    CONSTRAINT "option_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "option_id_format" CHECK ("id" ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT "option_type_format" CHECK ("type" ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT "option_provider_format" CHECK ("provider" ~
        '^[a-z0-9]+(-[a-z0-9]+)*$'),

    CONSTRAINT "option_logo_resource_id_fkey" FOREIGN KEY ("logo_resource_id")
        REFERENCES "resource" ("id") ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS "option_enabled_type_priority_idx"
    ON "option" ("type", "priority")
    WHERE "is_enabled" AND "deleted_at" IS NULL;
CREATE INDEX IF NOT EXISTS "option_owner_id_idx" ON "option" ("owner_id");
```

=== Phân loại độ nhạy cảm theo trường

Các bảng từ điển ở trên trả lời câu hỏi một cột *là gì*; mục này trả lời câu hỏi ai được nhìn
thấy nó và điều gì xảy ra nếu nó lọt ra ngoài. Bốn mức được dùng nhất quán. *Công khai* là dữ
liệu vốn đã hiển thị cho mọi khách truy cập. *Nội bộ* là dữ liệu chỉ chủ sở hữu hàng dữ liệu và
bộ phận vận hành được đọc. *Nhạy cảm* là dữ liệu định danh cá nhân hoặc dữ liệu tài chính, nơi
một lượt lộ gây thiệt hại trực tiếp cho người dùng. *Bí mật* là vật liệu xác thực, thứ không bao
giờ được đọc ngược ra kể cả bởi quản trị viên.

#figure(
  kind: table,
  caption: [Danh mục trường nhạy cảm và biện pháp bảo vệ tương ứng],
  table(
    columns: (1.25fr, 0.5fr, 1.9fr),
    align: (left + top, left + top, left + top),
    table.header([Trường], [Mức], [Biện pháp bảo vệ và ghi chú]),

    [`account.password_hash`], [Bí mật],
    [Băm bcrypt một chiều; không bao giờ có mặt trong bất kỳ đối tượng truyền dữ liệu nào, không bao giờ được ghi nhật ký, và không có tuyến nào đọc ra.],
    [`option.vault_secret_path`], [Bí mật],
    [Chỉ là *đường dẫn* tới kho bí mật ngoài; bản thân khoá của nhà cung cấp không nằm trong cơ sở dữ liệu, nên bản sao lưu và ảnh chụp kiểm toán đều sạch.],
    [Mã một lần: xác minh thư, đặt lại mật khẩu, xác minh số điện thoại], [Bí mật],
    [*Không có cột nào* — chúng sống trong bộ nhớ đệm kèm thời gian sống và biến mất sau một lần đọc.],
    [`account.email`, `account.phone`], [Nhạy cảm],
    [Chỉ trả về cho chính chủ tài khoản; các phép chiếu công khai của một tài khoản chỉ mang tên hiển thị và ảnh đại diện.],
    [`account.date_of_birth`], [Nhạy cảm], [Chỉ dùng cho phép kiểm tra tuổi; không xuất hiện ở bất kỳ phép chiếu công khai nào.],
    [`identity_document.*`], [Nhạy cảm],
    [*Không lưu số giấy tờ*; chỉ lưu phán quyết của nhà cung cấp, mã hồ sơ bên đó và tham chiếu tới ba ảnh chụp. Ảnh nằm sau đường dẫn ký có thời hạn.],
    [`contact.full_name`, `phone`, `address`, `address_detail`, `location`], [Nhạy cảm],
    [Địa chỉ nhà riêng; chỉ lộ cho phía đối diện của một đơn *đã thanh toán*, và lộ dưới dạng ảnh chụp đóng băng trong đơn chứ không phải con trỏ tới sổ địa chỉ hiện tại.],
    [`bank_account.bank_code`, `account_number`], [Nhạy cảm],
    [Chỉ chủ tài khoản đọc được; xoá mềm để lịch sử rút tiền vẫn phân giải được nơi tiền đã đi. Chỉ mục trên cặp này phục vụ việc phát hiện gian lận, không phục vụ tra cứu của người dùng.],
    [`tax_info.tax_code`], [Nhạy cảm], [Chỉ chủ tài khoản và bộ phận vận hành; kiểm tra dạng ở tầng cơ sở dữ liệu.],
    [`wallet.available_balance`, `held_balance`, `wallet_transaction.*`], [Nhạy cảm],
    [Dữ liệu tài chính; chỉ-thêm-mới nên không thể bị viết lại, và chỉ chủ ví đọc được sổ cái của mình.],
    [`message.body`, `message.attachments`], [Nhạy cảm],
    [Nội dung riêng tư giữa hai bên. Một kiểm duyệt viên *không* đọc được luồng trực tiếp; luồng của phiếu hỗ trợ là ngoại lệ duy nhất và chỉ vì người gửi đã chủ động mở phiếu.],
    [`refund.attachments`, `order.receipt_attachments`], [Nhạy cảm],
    [Bằng chứng khiếu nại; chỉ hai bên của đơn và bộ phận vận hành đọc được.],
    [`ticket.assignee_id`], [Nội bộ],
    [Cố ý *không bao giờ* công bố cho người gửi phiếu — đó là điều giữ cho nhân viên trả lời được ẩn danh.],
    [`audit_log.diff`, `snapshot`], [Nội bộ],
    [Có thể chứa giá trị cũ của một trường nhạy cảm, nên bảng này chịu cùng mức bảo vệ như bảng mà nó ghi lại.],
    [`listing.*`, `category.*`, `tag.*`, `review.*`], [Công khai],
    [Vốn đã hiển thị cho khách chưa đăng nhập; điều duy nhất cần giữ là quy tắc không hiển thị bản nháp và bản chờ duyệt.],
    [`business_events.payload`], [Nội bộ],
    [Cố ý *chỉ* phản chiếu định danh, số tiền và trạng thái, vì bảng điều khiển giám sát được đọc bởi một tập người rộng hơn nhiều so với bảng dữ liệu gốc.],
  ),
)

=== Dữ liệu mẫu

Một hàng mẫu nói được điều mà đặc tả kiểu dữ liệu không nói: dạng thật của giá trị. Bảng dưới
đây cho một hàng đại diện của bảng chính thuộc mỗi lược đồ, với các trường nhạy cảm đã được che
đi theo đúng mức phân loại ở mục trên. Các định danh trong cột giá trị là *định danh mờ như máy
khách nhìn thấy*, còn trong cơ sở dữ liệu chúng là số nguyên 64 bit.

#figure(
  kind: table,
  caption: [Dữ liệu mẫu cho bảng chính của mỗi lược đồ],
  table(
    columns: (0.8fr, 2.6fr),
    align: (left + top, left + top),
    table.header([Bảng], [Hàng mẫu]),
    [`account.account`],
    [`id`=42 (`acc_7k2mq9xr4vb1`), `status`=`active`, `role`=`user`, `username`=`"minhanh"`, `email`=`"m•••@example.com"`, `phone`=`"+8490•••4417"`, `password_hash`=`"$2a$10$…"` (ẩn), `name`=`"Cửa hàng Minh Anh"`, `country`=`"VN"`, `locale`=`"vi-VN"`, `timezone`=`"Asia/Ho_Chi_Minh"`, `version`=7],
    [`catalog.listing`],
    [`id`=9137 (`lst_2h9qk4mfx7bd3`), `slug`=`"may-anh-canon-eos-200d-cu"`, `account_id`=42, `category_id`=311, `name`=`"Máy ảnh Canon EOS 200D cũ"`, `status`=`active`, `price_mode`=`negotiable`, `condition`=`used`, `currency`=`"VND"`, `cached_rating`=4,60, `cached_review_count`=15, `cached_sold`=3, `embedding_stale_at`=NULL],
    [`order.order`],
    [`id`=50231 (`ord_9wq3nz6ktr8h`), `buyer_id`=88, `seller_id`=42, `draft_id`=NULL, `offer_id`=7712, `confirmed_at`=`2026-05-04T09:12:33Z`, `received_at`=`2026-05-07T14:02:10Z`, `payout_released_at`=`2026-05-10T14:02:11Z`, `completed_at`=`2026-05-10T14:02:11Z`, `cancelled_at`=NULL],
    [`finance.payment_session`],
    [`id`=110455 (`pss_4rm8vc2xdq7n`), `kind`=`buyer-checkout`, `status`=`success`, `from_id`=88, `to_id`=42, `currency`=`"VND"`, `total_amount`=4 235 000, `paid_at`=`2026-05-04T08:41:52Z`, `expired_at`=`2026-05-04T08:56:04Z`],
    [`finance.wallet_transaction`],
    [`account_id`=42, `currency`=`"VND"`, `seq`=193, `kind`=`escrow-hold`, `available_delta`=0, `held_delta`=+4 000 000, `available_after`=1 250 000, `held_after`=4 000 000, `group_id`=6621, `idempotency_key`=`"order:50231:seller"`],
    [`trust.feedback`],
    [`order_id`=50231, `rater_id`=88, `ratee_id`=42, `direction`=`buyer-to-seller`, `rating`=5, `comment`=`"Hàng đúng mô tả, đóng gói kỹ."`, `created_at`=`2026-05-10T15:31:07Z`, `published_at`=`2026-05-12T03:00:00Z`],
    [`chat.message`],
    [`id`=884301, `created_at`=`2026-05-03T16:20:41Z`, `conversation_id`=1204, `sender_id`=0, `type`=`system`, `body`=`""`, `attachments`=`[]`, `metadata`=`{"offer_id": 7712}`],
    [`observability.http_requests`],
    [`ts`=`2026-05-04T08:41:52.318Z`, `instance`=`"gw-1"`, `method`=`"POST"`, `route`=`"/api/v1/drafts/{id}/checkout"`, `status`=201, `duration_ms`=143,7],
    [`<lược đồ>.audit_log`],
    [`table_name`=`"order"`, `record_id`=50231, `version`=3, `change_type`=`update`, `code`=`"order.confirmed"`, `changed_by`=42, `diff`=`{"confirmed_at": "2026-05-04T09:12:33Z"}`],
  ),
)

=== Biện luận chỉ mục theo mẫu truy vấn

Mỗi chỉ mục trong thiết kế đều phục vụ một mẫu truy vấn cụ thể, và những chỉ mục đắt nhất — chỉ
mục véc-tơ, chỉ mục ba ký tự, chỉ mục không gian — đều được thêm cho đúng một mẫu chứ không
thêm phòng xa. Bảng dưới đây ghép từng nhóm chỉ mục với truy vấn sinh ra nó.

#figure(
  kind: table,
  caption: [Chỉ mục chính và mẫu truy vấn mà mỗi chỉ mục phục vụ],
  table(
    columns: (1.05fr, 1.35fr, 1.35fr),
    align: (left + top, left + top, left + top),
    table.header([Chỉ mục], [Mẫu truy vấn được phục vụ], [Vì sao dạng chỉ mục này]),

    [`listing_name_unaccent_trgm_idx` (GIN, `gin_trgm_ops`, trên biểu thức bỏ dấu)],
    [Tìm kiếm bài đăng theo từ khoá tự do, có bỏ dấu.],
    [Người bán tự đặt tên hàng nên không có từ điển nào phủ hết; đối sánh ba ký tự chịu được lỗi chính tả và cách viết tắt. Chỉ mục đặt trên chính biểu thức bỏ dấu để truy vấn dùng lại được.],
    [`listing_embedding_dense_idx` và `listing_embedding_sparse_idx` (HNSW)],
    [Nhánh ngữ nghĩa của cùng một truy vấn tìm kiếm.],
    [Tìm láng giềng gần đúng ở độ trễ dưới ngưỡng đọc; hai chỉ mục vì véc-tơ dày và véc-tơ thưa dùng hai độ đo khác nhau — cô-sin và tích trong.],
    [`listing_location_gist` (GiST, bộ phận trên bài đăng đang hiển thị)],
    [Lọc "gần tôi" theo bán kính quanh vị trí người xem.],
    [Truy vấn là một phép chứa hình học, thứ mà chỉ mục cây B không phục vụ được. Cạnh nó, `listing_area_idx` phục vụ lọc theo đơn vị hành chính, vốn là một phép so bằng.],
    [`listing_embedding_stale_idx` (bộ phận, `WHERE embedding_stale_at IS NOT NULL`)],
    [Tiến trình làm giàu véc-tơ đọc lô kế tiếp của hàng đợi.],
    [Chỉ mục bộ phận khiến chi phí đọc tỉ lệ với phần việc *còn lại*, nên một lượt chạy trên hệ thống đã ổn định đọc ra tập rỗng gần như tức thì.],
    [`order_payout_due_idx` (bộ phận, `WHERE payout_released_at IS NULL`)],
    [Vòng quét tìm đơn đã đến hạn giải ngân, và tìm đơn đã chiếm lượt giải ngân mà chưa hoàn tất.],
    [Cùng lý do trên. Chính điều kiện bộ phận này là thứ làm cho dấu hiệu "đã xong" rẻ hơn hẳn một cửa sổ thời gian: hệ thống khoẻ mạnh thì chỉ mục gần như rỗng.],
    [`refund_overdue_idx` (bộ phận trên `deadline_at`)],
    [Vòng quét tìm hồ sơ hoàn tiền quá hạn.],
    [Chỉ hai trong bốn trạng thái chưa kết thúc mang hạn chót, nên chỉ mục bộ phận đúng bằng tập cần quét.],
    [`item_seller_pending_idx` (bộ phận, `WHERE order_id IS NULL`)],
    [Danh sách mục hàng đã trả tiền nhưng chưa được lời gọi lại kịp dựng thành đơn.],
    [Đây là một *danh sách thử lại* chứ không phải hộp thư đến, nên nó phải luôn ngắn và phải rẻ khi rỗng.],
    [`transaction_provider_ref_unique` (duy nhất bộ phận trên cặp kênh và mã tham chiếu)],
    [Không phục vụ truy vấn đọc nào; phục vụ *lượt ghi* của lời gọi lại.],
    [Chỉ mục duy nhất là cơ chế cưỡng chế: một thông báo được gửi lại va vào ràng buộc thay vì trở thành lần thu tiền thứ hai.],
    [`wallet_transaction` duy nhất trên bộ ba tài khoản, tiền tệ và số thứ tự],
    [Đọc sổ cái của một ví theo thứ tự, và cấp số thứ tự kế tiếp.],
    [Cùng một chỉ mục phục vụ cả phép đọc lẫn phép cưỡng chế tính duy nhất.],
    [`http_requests_errors_ts_idx` (bộ phận trên nhóm mã lỗi máy chủ)],
    [Cảnh báo tỉ lệ lỗi của bảng điều khiển giám sát.],
    [Phần lỗi là một phần rất nhỏ của bảng lớn nhất hệ thống, nên chỉ mục bộ phận biến một lượt quét thành một lượt tra.],
    [`bank_account_bank_code_account_number_idx`],
    [Phát hiện nhiều tài khoản nền tảng cùng trỏ về một tài khoản nhận tiền.],
    [Biến một dấu hiệu gian lận từ một lượt quét toàn bảng thành một phép tra khoá.],
  ),
)

=== Kịch bản hoàn tác di trú

Các tệp di trú được áp bằng một công cụ riêng chứ không bao giờ chạy lúc khởi động ứng dụng, và
mọi câu lệnh đều viết ở dạng lũy đẳng nhờ mệnh đề `IF NOT EXISTS`, nên áp lại một tệp đã áp là
vô hại. Điều đó xử lý được nửa dễ của bài toán; nửa còn lại là *lùi lại* một tệp đã áp, và ở
đây thiết kế chọn một lập trường rõ ràng thay vì viết máy móc một tệp lùi cho mỗi tệp tiến.

Lập trường ấy là: *một thay đổi phá huỷ dữ liệu thì không có đường lùi tự động*. Xoá một cột
hay xoá một bảng là thao tác làm mất dữ liệu, nên một tệp lùi chỉ dựng lại được cái vỏ rỗng và
sẽ tạo cảm giác an toàn giả. Thay vào đó, thiết kế phân các thay đổi thành ba nhóm và mỗi nhóm
có một cách lùi khác nhau.

Nhóm *thêm thuần tuý* — thêm bảng, thêm cột cho phép rỗng, thêm chỉ mục, thêm nhãn kiểu liệt
kê — chiếm phần lớn số tệp di trú và lùi được bằng đúng một câu lệnh nghịch đảo, chạy an toàn
trong khi hệ thống vẫn đang phục vụ, vì phiên bản mã nguồn cũ không hề biết tới thứ vừa được
thêm. Bảng dưới đây ghi câu lệnh nghịch đảo cho từng dạng.

#figure(
  kind: table,
  caption: [Câu lệnh hoàn tác cho các thay đổi thuộc nhóm thêm thuần tuý],
  table(
    columns: (1fr, 1.4fr, 1.1fr),
    align: (left + top, left + top, left + top),
    table.header([Thay đổi], [Câu lệnh hoàn tác], [Ghi chú]),
    [Thêm bảng], [`DROP TABLE IF EXISTS "<bảng>";`], [An toàn khi bảng chưa có dữ liệu nghiệp vụ.],
    [Thêm cột cho phép rỗng], [`ALTER TABLE "<bảng>" DROP COLUMN IF EXISTS "<cột>";`], [Mất dữ liệu trong cột đó; chỉ chấp nhận khi cột vừa được thêm và chưa được ghi.],
    [Thêm chỉ mục], [`DROP INDEX IF EXISTS "<chỉ mục>";`], [Hoàn toàn an toàn; chỉ mục là dữ liệu dẫn xuất.],
    [Thêm ràng buộc kiểm tra], [`ALTER TABLE "<bảng>" DROP CONSTRAINT IF EXISTS "<ràng buộc>";`], [Hoàn toàn an toàn.],
    [Thêm khung nhìn kết tụ], [`DROP MATERIALIZED VIEW IF EXISTS "<khung nhìn>";`], [Dữ liệu thô ở bảng nguồn không bị ảnh hưởng.],
    [Thêm nhãn kiểu liệt kê], [Không có câu lệnh nghịch đảo trực tiếp], [PostgreSQL không cho xoá một nhãn; phải dựng kiểu mới rồi chuyển cột sang.],
  ),
)

Nhóm *đổi hình dạng* — đổi kiểu một cột, tách một bảng, siết một cột từ cho phép rỗng thành bắt
buộc — được triển khai theo lối *mở rộng rồi thu hẹp*: một tệp thêm hình dạng mới và ghi song
song cả hai, mã nguồn chuyển sang đọc hình dạng mới, rồi một tệp sau đó mới bỏ hình dạng cũ đi.
Đường lùi ở đây không phải một tệp mà là *dừng lại giữa chừng*: chừng nào tệp thu hẹp chưa
chạy, quay về phiên bản mã nguồn trước đó vẫn hoạt động bình thường.

Nhóm *phá huỷ* — xoá cột, xoá bảng, đổi ý nghĩa của một giá trị đã lưu — chỉ có một đường lùi
là *khôi phục từ bản sao lưu tới một thời điểm*. Vì vậy quy trình triển khai bắt buộc chụp một
bản sao lưu ngay trước khi áp một tệp thuộc nhóm này, và ghi lại thời điểm ấy vào chính bản ghi
triển khai. Đổi lại, thiết kế cố gắng để nhóm này gần như trống: khoá mã hoá định danh mờ không
bao giờ đổi, các dòng tuỳ chọn đã tắt vẫn giữ lại để bản ghi cũ còn phân giải được, và những
bảng bị xoá tên thì được xoá mềm thay vì xoá thật.

== Thiết kế bảo mật

Thiết kế bảo mật của ShopNexus không phải một lớp phủ bên ngoài mà là một tập các quyết định
nằm rải trong chính mô hình dữ liệu và các tầng đã trình bày ở trên. Mục này tập hợp chúng lại
theo các nhóm dưới đây. Ở những chỗ thiết kế đặt ra một chính sách mà bản hiện thực hiện tại
chưa cưỡng chế đủ, mục này nói rõ ranh giới ấy thay vì mô tả chính sách như thể nó đã có hiệu
lực — một tài liệu bảo mật mô tả sai hiện trạng còn nguy hiểm hơn một tài liệu thiếu mục.

=== Xác thực

Cơ chế xác thực gồm *hai phần đi cùng nhau*: một vé truy cập ngắn hạn và một phiên lưu ở bộ nhớ
đệm. Vé truy cập là một chuỗi ký hiệu có chữ ký, sống mười lăm phút, mang định danh mờ của tài
khoản ở trường chủ thể và mang định danh phiên ở trường mã vé. Phiên là một khoá trong bộ nhớ
đệm có thời gian sống ba mươi ngày. Điểm mấu chốt là *mọi yêu cầu đã xác thực đều tra cứu phiên
này*, chứ không chỉ kiểm chữ ký của vé.

Chính một lần tra cứu ấy là thứ khiến việc đăng xuất, việc đổi mật khẩu hay việc đình chỉ tài
khoản có hiệu lực ngay lập tức đối với một vé đang lưu hành. Nếu chỉ kiểm chữ ký, một vé đã
phát ra sẽ tiếp tục hợp lệ cho tới khi hết hạn, và khoảng trống mười lăm phút ấy là khoảng
trống mà một tài khoản bị chiếm quyền vẫn tiếp tục hoạt động sau khi chủ nhân đã đổi mật khẩu.

Vé làm mới là một khoá thứ hai trỏ về cùng phiên và được *xoay vòng ở mỗi lần đổi vé*, nên một
vé làm mới bị lộ và bị dùng lại sẽ để lại dấu vết thay vì im lặng cấp quyền song song. Việc thu
hồi toàn bộ phiên của một tài khoản không được làm bằng cách duyệt danh sách mà bằng cách tăng
một số hiệu kỷ nguyên gắn với tài khoản; mỗi bản ghi phiên mang theo số hiệu kỷ nguyên lúc nó
ra đời, nên phép so sánh là hằng số thời gian và không cần tới kiểu tập hợp trong bộ nhớ đệm.

Mật khẩu được lưu dưới dạng băm bcrypt trong cột `password_hash`, không bao giờ lưu dạng rõ và
không dùng các hàm băm đã lỗi thời. Cột này cho phép rỗng, vì một tài khoản có thể chỉ đăng
nhập qua nhà cung cấp bên thứ ba; khi đó vé định danh do nhà cung cấp phát được xác minh theo
chuẩn OpenID Connect. Ràng buộc `account_has_identifier` bảo đảm không tồn tại tài khoản không
có cách nào để nhận diện. Đáng chú ý, tài khoản của bộ phận hỗ trợ được cố ý tạo ra *không có
mật khẩu và không có liên kết nhà cung cấp nào*, nghĩa là không ai có thể đăng nhập vào nó; nó
chỉ tồn tại để làm phía đối diện của mọi luồng phiếu hỗ trợ.

Các bí mật dùng một lần — mã xác minh thư điện tử, mã đặt lại mật khẩu, mã xác minh số điện
thoại — không được lưu thành hàng trong bảng mà lưu ở bộ nhớ đệm với thời gian sống. Lý do là
bản chất của chúng: đọc một lần rồi phải biến mất, tức là một thời gian sống chứ không phải một
hàng cần ai đó dọn. Khoá tiết chế tần suất gửi cũng nằm ở đó, và được đặt *trước* khi tra cứu
tài khoản, để mã lỗi quá tần suất không thể bị dùng như một cách phân biệt địa chỉ đã đăng ký
với địa chỉ chưa đăng ký.

=== Chính sách mật khẩu và yếu tố xác thực thứ hai

Chính sách mật khẩu của thiết kế này *ưu tiên độ dài hơn quy tắc thành phần*, theo đúng khuyến
nghị hiện hành của NIST trong tài liệu SP 800-63B. Cụ thể: tối thiểu tám ký tự, tối đa bảy mươi
hai ký tự, không có quy tắc bắt buộc phải có chữ hoa, chữ số hay ký tự đặc biệt, và không có
hạn dùng bắt buộc.

Ba lựa chọn trong đó cần được biện minh vì chúng đi ngược thói quen. *Giới hạn trên bảy mươi hai
ký tự* không phải một quyết định về an toàn mà là ràng buộc kỹ thuật của bcrypt: thuật toán này
chỉ đọc bảy mươi hai byte đầu, nên một mật khẩu dài hơn sẽ bị cắt âm thầm và người dùng sẽ tin
rằng phần đuôi có tác dụng. Từ chối thẳng ở tầng kiểm tra ràng buộc là cách duy nhất để sự thật
ấy không bị giấu đi. *Không có quy tắc thành phần*, vì các quy tắc ấy đã được chứng minh là đẩy
người dùng về những khuôn dạng đoán được — chữ cái đầu viết hoa, chữ số ở cuối — trong khi làm
giảm độ dài trung bình. *Không có hạn dùng bắt buộc*, vì việc bắt đổi mật khẩu định kỳ khiến
người dùng chọn các biến thể tăng dần của cùng một mật khẩu, và một mật khẩu đã lộ thì cần bị
thu hồi *ngay*, không phải chờ tới chu kỳ sau. Cơ chế thu hồi ngay ấy đã có sẵn và đã mô tả ở
trên: đổi mật khẩu làm tăng số hiệu kỷ nguyên của tài khoản, và mọi phiên sinh trước đó lập tức
mất hiệu lực.

Về *lịch sử mật khẩu*, thiết kế cố ý không lưu các giá trị băm cũ. Lưu lại chúng nghĩa là giữ
thêm một tập vật liệu xác thực chỉ để phục vụ một phép so sánh phòng ngừa, và lợi ích ấy không
tương xứng với việc mở rộng bề mặt lộ dữ liệu. Điều thay thế là quy tắc chỉ có đúng một giá trị
băm cho mỗi tài khoản tại mọi thời điểm.

Về *xác thực đa yếu tố*, cần nói thẳng ranh giới của bản hiện thực hiện tại. Hệ thống đã có sẵn
toàn bộ hạ tầng cho một yếu tố thứ hai — kênh gửi mã một lần qua thư điện tử và qua tin nhắn,
cơ chế lưu mã trong bộ nhớ đệm với thời gian sống, và cơ chế tiết chế tần suất gửi — và hạ tầng
ấy đang được dùng cho ba luồng: xác minh địa chỉ thư điện tử, đặt lại mật khẩu, và xác minh số
điện thoại của một liên hệ. Điều *chưa* có là bước yếu tố thứ hai tại chính thao tác đăng nhập.
Thiết kế xác định đây là phần mở rộng gần nhất và xác định luôn hình dạng của nó: một cột đánh
dấu tài khoản đã bật yếu tố thứ hai, một bước trung gian giữa việc kiểm mật khẩu và việc cấp
phiên, và bắt buộc với vai quản trị viên cùng kiểm duyệt viên trước khi bắt buộc với người dùng
thường. Việc đăng nhập qua nhà cung cấp bên thứ ba thì thừa hưởng yếu tố thứ hai của chính nhà
cung cấp đó, nên các tài khoản chỉ dùng đường ấy đã được bảo vệ ở mức tương đương.

=== Phân quyền

Mô hình phân quyền là kiểm soát truy cập theo vai, với bốn vai lưu ở cột `account.role`: người
dùng, kiểm duyệt viên, quản trị viên và bộ phận hỗ trợ. Quản trị viên thoả mãn mọi phép kiểm
tra dành cho kiểm duyệt viên. Bộ phận hỗ trợ được nhận diện *bằng vai chứ không bằng tên đăng
nhập*, và được bảo vệ bằng một chỉ mục duy nhất bộ phận cho phép tối đa một hàng mang vai ấy.
Đây không phải chi tiết vụn vặt: một tên đăng nhập là thứ bất kỳ người dùng nào cũng có thể
đăng ký, nên nếu định danh bộ phận hỗ trợ bằng tên, người chiếm được tên đó sẽ trở thành một
phía của mọi luồng phiếu trên toàn hệ thống và đọc được mọi khiếu nại.

Phép kiểm tra vai được đặt ở *tầng dịch vụ chứ không phải tầng xử lý yêu cầu*. Lý do rất thực
tế: vai của người gọi là một hàng trong bảng của mô-đun tài khoản, nên một bộ xử lý yêu cầu chỉ
có thể biết nó bằng cách hỏi chính dịch vụ ấy.

Vai chỉ quyết định *loại thao tác*; quyết định *hàng dữ liệu nào* là việc của phép kiểm tra
quyền sở hữu, và phép kiểm tra ấy dựa trên chính các cột đã có trong mô hình dữ liệu:
`account_id` với địa chỉ và thiết bị, `buyer_id` cùng `seller_id` với đơn hàng và hồ sơ hoàn
tiền, `requester_id` với phiếu hỗ trợ, hai cột tham gia của hội thoại với tin nhắn. Hai phép
kiểm tra này độc lập và đều bắt buộc: một kiểm duyệt viên không vì thế mà đọc được hộp thư
riêng của hai người dùng, và một người dùng dù sở hữu hàng dữ liệu vẫn không thực hiện được
thao tác dành cho quản trị.

Bảng dưới đây ánh xạ từng vai sang các nhóm điểm cuối mà vai ấy mở khoá. Cần đọc bảng này cùng
với hai lưu ý. Thứ nhất, quản trị viên thoả mãn mọi phép kiểm tra dành cho kiểm duyệt viên, nên
mọi dòng ghi "kiểm duyệt viên" cũng đúng với quản trị viên. Thứ hai, mọi dòng ghi "người dùng"
đều còn phải qua phép kiểm tra quyền sở hữu trên chính hàng dữ liệu; vai chỉ mở được *loại*
thao tác chứ không mở được *hàng nào*.

#figure(
  kind: table,
  caption: [Ma trận vai, quyền và nhóm điểm cuối tương ứng],
  table(
    columns: (0.62fr, 1.25fr, 1.55fr),
    align: (left + top, left + top, left + top),
    table.header([Vai], [Quyền được mở], [Nhóm điểm cuối tiêu biểu]),

    [Khách chưa đăng nhập], [Đọc dữ liệu vốn công khai.],
    [`GET /listings`, `GET /listings/{id}`, `GET /categories`, `GET /tags`, `GET /listings/{id}/reviews`, `GET /administrative-areas`, `GET /options`.],

    [Người dùng], [Mọi thao tác nghiệp vụ trên hàng dữ liệu của chính mình, ở cả hai vai mua và bán.],
    [Toàn bộ `/me/*`, `/listings` (ghi, trên bài đăng của mình), `/drafts/*`, `/offers/*`, `/orders/*`, `/refunds/*`, `/payment-sessions/*`, `/wallets/*`, `/withdrawals`, `/conversations/*`, `/tickets/*`, `/feedback`, `/reviews`.],

    [Kiểm duyệt viên], [Kiểm duyệt nội dung, phán quyết khiếu nại, và đọc dữ liệu của người khác *trong phạm vi vụ việc*.],
    [`/admin/listings` cùng phê duyệt và gỡ bài; `/admin/accounts` cùng đình chỉ và bỏ đình chỉ; `/admin/identity-documents` cùng phán quyết giấy tờ; `/admin/tickets` cùng nhận và giải quyết phiếu; `/admin/refunds/{id}/verdict`; xem hồ sơ vụ việc của một đơn và đẩy mốc vận đơn.],

    [Quản trị viên], [Toàn bộ quyền của kiểm duyệt viên, cộng các thao tác *cấu hình nền tảng* và các thao tác *chạm vào tiền*.],
    [Cấp và thu hồi tài khoản kiểm duyệt viên; sửa cây danh mục và từ điển thẻ; `/admin/options` (bật, tắt, đổi nhà cung cấp); `/admin/withdrawals` cùng duyệt và từ chối; `/admin/wallets/{accountID}` cùng bút toán điều chỉnh; `/admin/payment-sessions`; xác minh mã số thuế.],

    [Bộ phận hỗ trợ], [Không phải một vai đăng nhập được: nó là *phía đối diện* của mọi luồng phiếu hỗ trợ.],
    [Không có điểm cuối nào. Hàng dữ liệu mang vai này cố ý không có mật khẩu và không có liên kết nhà cung cấp, nên không ai đăng nhập vào nó được; nhân viên trả lời phiếu vẫn dùng tài khoản kiểm duyệt viên của chính mình.],
  ),
)

Ranh giới giữa hai vai nhân viên đáng được nói rõ, vì nó là một quyết định chứ không phải một
sự tình cờ: *kiểm duyệt viên quyết định về nội dung và về vụ việc, quản trị viên quyết định về
cấu hình và về tiền*. Vì thế việc gỡ một bài đăng hay ra phán quyết cho một hồ sơ hoàn tiền
thuộc về kiểm duyệt viên, còn việc duyệt một lệnh rút tiền, ghi một bút toán điều chỉnh vào ví
hay đổi nhà cung cấp phục vụ một kênh thanh toán thì đòi hỏi quản trị viên. Phán quyết hoàn
tiền nằm ở phía kiểm duyệt viên dù nó làm dịch chuyển tiền, bởi thứ nó quyết định là *ai đúng*,
còn số tiền thì đã được xác định từ trước bởi chính đơn hàng.

Định danh mờ, đã mô tả ở phần nguyên tắc thiết kế, đóng vai trò lớp phòng thủ bổ sung ở đây.
Điều duy nhất cần nói thêm về mặt bảo mật là ranh giới của nó: đây là *phòng thủ theo chiều sâu
chứ không thay thế* phép kiểm tra quyền sở hữu, nên một định danh mờ đoán trúng vẫn phải qua
đúng phép kiểm tra ấy.

=== Bảo vệ dữ liệu

Về phân loại dữ liệu, thiết kế xác định bốn nhóm nhạy cảm: dữ liệu định danh cá nhân trong lược
đồ `account`, dữ liệu tài chính trong lược đồ `finance`, nội dung riêng tư trong lược đồ `chat`
và bằng chứng khiếu nại trong lược đồ `order` cùng `trust`. Nguyên tắc chung là *không lưu thứ
không cần lưu*.

Ví dụ rõ nhất là hồ sơ xác minh giấy tờ. Bảng `identity_document` *không lưu số giấy tờ*: nhà
cung cấp dịch vụ xác minh thực hiện việc đối chiếu, và hệ thống chỉ giữ lại kết luận cùng mã hồ
sơ bên đó. Nhờ vậy, dù toàn bộ bảng này bị lộ thì cũng không thể tái tạo được một giấy tờ tuỳ
thân nào. Ba ảnh chụp vẫn được giữ nhưng chỉ ở dạng *tham chiếu tài nguyên*, nghĩa là các byte
ảnh nằm sau đường dẫn ký của kho lưu trữ chứ không nằm trong hàng dữ liệu; chúng được giữ vì
một kiểm duyệt viên bác bỏ kết luận của nhà cung cấp cần có cơ sở để quyết định.

Bí mật của các nhà cung cấp bên ngoài không nằm trong cơ sở dữ liệu. Bảng `option` chỉ lưu
đường dẫn tới nơi cất bí mật, còn ứng dụng phân giải đường dẫn ấy tại thời điểm chạy. Hệ quả là
bản sao lưu, bản sao đọc và cả ảnh chụp trong nhật ký kiểm toán của hàng đó đều không chứa vật
liệu khoá.

Tệp tải lên không bao giờ được phục vụ trực tiếp mà qua đường dẫn ký có thời hạn, và một tài
nguyên chưa được xác nhận thì không được phép gắn vào bất cứ thứ gì — đây chính là ý nghĩa an
toàn của cột `completed_at` đã mô tả ở phần trên. Quy tắc ghi mã băm chỉ khi đã đọc lại từ kho
cũng là một quyết định bảo mật chứ không phải một quyết định về tính đúng đắn: nó chặn hẳn kiểu
tấn công khai khống mã băm để chiếm quyền trên tệp của người khác qua cơ chế khử trùng lặp.

Về mặt đo đạc, bảng sự kiện nghiệp vụ trong lược đồ `observability` cố ý *chỉ phản chiếu định
danh, số tiền và trạng thái*, không phản chiếu dữ liệu cá nhân, vì bảng điều khiển giám sát
được đọc bởi một tập người rộng hơn nhiều so với bảng dữ liệu gốc. Cùng tinh thần đó, đường dẫn
trong bảng lời gọi ra được lưu ở dạng mẫu và bị cắt bỏ chuỗi truy vấn, vì chuỗi truy vấn là chỗ
thông tin xác thực hay lọt ra.

Mã hoá đường truyền được áp ở biên hệ thống cho toàn bộ giao diện lập trình công khai; mã hoá
khi lưu trữ được áp ở mức ổ đĩa của cơ sở dữ liệu và của kho đối tượng. Nhật ký ứng dụng được
ghi dưới dạng JSON có cấu trúc ra đầu ra chuẩn và không bao giờ ghi mật khẩu, vé truy cập hay
nội dung bí mật một lần.

=== Kiểm soát đầu vào và chống chèn mã

Toàn bộ truy cập cơ sở dữ liệu đi qua *câu lệnh tham số hoá với tham số đặt tên*; không có chỗ
nào trong hệ thống dựng câu lệnh SQL bằng cách nối chuỗi từ dữ liệu người dùng. Điều này được
giữ bằng một quy ước mạnh hơn thói quen: câu lệnh ghi trong bộ điều hợp là *hằng chuỗi tĩnh*,
kể cả khi phải áp một bản vá từng phần — trường hợp đó dùng biểu thức điều kiện trong chính câu
lệnh chứ không ghép câu lệnh theo các trường có mặt. Một vài chỗ có xây câu lệnh từ hằng số ở
thời điểm biên dịch, nhưng đó là ghép các hằng trạng thái đã khai báo, không phải ghép dữ liệu.

Dữ liệu vào được kiểm tra hai lớp. Lớp thứ nhất ở biên đối tượng truyền dữ liệu, bằng thẻ kiểm
tra khai báo ngay trên trường: bắt buộc, khoảng giá trị, độ dài, tập giá trị cho phép. Lớp thứ
hai ở tầng miền, nơi thực thể được kiểm tra *toàn vẹn sau khi đã áp bản vá*, chứ không kiểm
từng trường rời rạc — nhờ vậy những quy tắc liên trường như "phải còn ít nhất một cách đăng
nhập" hay "ngày sinh không được ở tương lai" được kiểm trên kết quả cuối cùng.

Bộ giải mã JSON dùng cho các tuyến của hệ thống là bộ giải mã *nghiêm ngặt*: sai tên trường thì
báo lỗi. Riêng dữ liệu do nhà cung cấp bên ngoài gửi tới được giải mã bằng bộ giải mã khoan
dung về chữ hoa chữ thường, vì các nhà cung cấp không nhất quán về cách viết tên trường và một
trường bị đọc nhầm thành giá trị rỗng chính là cách một khoản thanh toán đã quyết toán trở
thành một khoản chưa quyết toán.

Với lời gọi lại từ cổng thanh toán và hãng vận chuyển, nguyên tắc là *trang mà người dùng được
chuyển tới không phải bằng chứng*. Cả hai loại nhà cung cấp đều nhận một địa chỉ trả về và đều
trỏ mọi kết cục — thành công, lỗi, huỷ — về cùng một trang, vì nơi người dùng dừng chân là điều
bất kỳ ai cũng giả mạo được. Chỉ lời gọi lại phía máy chủ mới quyết toán một chặng tiền, và chỉ
sau khi chữ ký của nó được xác minh. Một lần quyết toán thất bại trả về mã lỗi máy chủ để nhà
cung cấp gửi lại, vì đó là thứ duy nhất sẽ báo cho hệ thống lần nữa.

=== Chống giả mạo yêu cầu liên trang, chính sách nguồn gốc và tiêu đề bảo mật

Điểm khởi đầu của nhóm này là một quyết định đã được nêu ở phần xác thực và có hệ quả trực tiếp
ở đây: *hệ thống xác thực bằng vé mang trong tiêu đề uỷ quyền, và không đặt bất kỳ cookie nào*.
Từ đó suy ra ngay rằng lớp tấn công giả mạo yêu cầu liên trang, vốn dựa hoàn toàn vào việc trình
duyệt tự động đính kèm chứng thực vào một yêu cầu do trang khác khởi xướng, *không tồn tại* với
giao diện lập trình này: một trang thù địch có thể gửi yêu cầu, nhưng nó không có cách nào lấy
được vé của người dùng để đính kèm. Vì vậy thiết kế không dùng phiếu chống giả mạo, và điều quan
trọng cần ghi lại là *điều kiện* để kết luận ấy còn đúng — ngày nào hệ thống bắt đầu đặt vé vào
cookie, dù chỉ cho một luồng, thì phiếu chống giả mạo trở thành bắt buộc và chính sách nguồn gốc
chéo phải được siết lại cùng lúc.

Chính sách nguồn gốc chéo được cấu hình bằng một danh sách nguồn cho phép, so khớp *đúng nguyên
văn* toàn bộ nguồn gốc chứ không so tiền tố. Yêu cầu thăm dò được trả lời ở lớp trung gian ngoài
cùng và không bao giờ đi tới bộ xử lý, để một yêu cầu thăm dò không kèm vé không trở thành một
lượt gọi chưa xác thực trên mọi tuyến. Đáng chú ý là hệ thống *không bao giờ* gửi tiêu đề cho
phép kèm chứng thực, và chính điều đó khiến giá trị `*` trong danh sách nguồn trở nên chấp nhận
được ở đây — trình duyệt từ chối thẳng cặp `*` cộng chứng thực, nên nếu về sau có cookie thì cấu
hình này sẽ hỏng ồn ào thay vì mở rộng âm thầm. Danh sách nguồn cho kênh thời gian thực là một
danh sách riêng và so theo mẫu tên máy, vì thư viện kết nối dài so khớp theo cách khác.

Về tiêu đề bảo mật, thiết kế phân biệt rõ *nơi đặt* chúng. Bộ giao diện lập trình trả về JSON và
không phục vụ trang HTML nào ngoài trang tài liệu đặc tả, nên các tiêu đề mang tính bảo vệ trình
duyệt được đặt ở tầng biên — bộ định tuyến ngược đứng trước hệ thống — chứ không rải trong mã
ứng dụng. Bảng dưới đây ghi tập tiêu đề bắt buộc cùng giá trị của chúng.

#figure(
  kind: table,
  caption: [Tiêu đề bảo mật bắt buộc ở tầng biên],
  table(
    columns: (0.95fr, 1.2fr, 1.5fr),
    align: (left + top, left + top, left + top),
    table.header([Tiêu đề], [Giá trị], [Điều nó ngăn chặn]),
    [`Strict-Transport-Security`], [`max-age=31536000; includeSubDomains`],
    [Hạ cấp về giao thức không mã hoá, kể cả khi người dùng gõ địa chỉ không kèm lược đồ.],
    [`Content-Security-Policy`], [`default-src 'none'; frame-ancestors 'none'`],
    [Bộ giao diện không trả về tài liệu nào cần nạp tài nguyên, nên chính sách chặt nhất là chính sách đúng; trang tài liệu đặc tả có một chính sách nới riêng.],
    [`X-Content-Type-Options`], [`nosniff`],
    [Trình duyệt tự đoán kiểu nội dung và diễn giải một tệp người dùng tải lên thành mã kịch bản.],
    [`X-Frame-Options`], [`DENY`],
    [Nhúng phản hồi vào khung của trang khác; trùng chức năng với `frame-ancestors` và giữ lại cho các trình duyệt cũ.],
    [`Referrer-Policy`], [`no-referrer`],
    [Rò đường dẫn có chứa định danh sang máy chủ của bên thứ ba khi người dùng đi tiếp.],
    [`Cache-Control`], [`no-store` trên mọi phản hồi đã xác thực],
    [Bộ đệm trung gian giữ lại dữ liệu riêng tư và trả cho người tiếp theo.],
  ),
)

Mã hoá đường truyền được kết thúc ở tầng biên với *phiên bản tối thiểu là TLS 1.2*, và các bộ mã
đã lỗi thời bị loại khỏi cấu hình. Bên trong ranh giới tin cậy, các kết nối tới cơ sở dữ liệu,
bộ nhớ đệm và hàng đợi cũng chạy trên kênh đã mã hoá, vì "bên trong" là một ranh giới quản trị
chứ không phải một bảo đảm về đường truyền vật lý.

=== Nhật ký kiểm toán

Nhật ký kiểm toán được ghi *trong cùng giao dịch với chính thay đổi mà nó ghi lại*. Đây là điểm
khác biệt căn bản so với việc ghi nhật ký sau khi thao tác thành công: một lần ghi đã thành
công thì luôn có dấu vết, và không tồn tại trạng thái mà dữ liệu đã đổi nhưng nhật ký thì
chưa. Phép thử để kiểm chứng thiết kế này rất gọn: xoá mọi lời ghi nhật ký khỏi mã nguồn thì
cơ sở dữ liệu vẫn đúng, chỉ mất dấu vết — nghĩa là việc lưu trữ dữ liệu được điều khiển bởi
trạng thái của thực thể chứ không bởi danh sách sự kiện.

Nội dung ghi lại không phải một phép so sánh dựng lại từ hai ảnh chụp mà là *sự việc mà tầng
miền đã ghi nhận*: một mã nghiệp vụ kèm một cấu trúc dữ liệu có kiểu. Mỗi bản ghi có một chuỗi
phiên bản tăng dần, được bảo vệ bởi ràng buộc duy nhất trên bộ ba tên bảng, định danh bản ghi
và phiên bản, nên hai lần ghi cùng phiên bản cho cùng bản ghi là không thể tồn tại.

Các sự kiện được ghi bao gồm: mọi thay đổi định danh và mật khẩu, đình chỉ và khôi phục tài
khoản, thay đổi vai, mọi chuyển trạng thái của đơn hàng và hồ sơ hoàn tiền, mọi phán quyết của
kiểm duyệt viên, mọi thay đổi cấu hình kênh thanh toán và hãng vận chuyển. Cột `changed_by` ghi
tài khoản chịu trách nhiệm và để rỗng khi tác nhân là công việc nền hoặc lời gọi lại của nhà
cung cấp — điều này quan trọng vì nó phân biệt được hành động của con người với hành động của
hệ thống. Vì nhật ký nằm trong lược đồ của mô-đun, nó đi theo mô-đun khi mô-đun tách ra, và
chính sách lưu trữ có thể đặt riêng cho từng nhóm dữ liệu.

Bên cạnh nhật ký kiểm toán còn có hai nguồn dấu vết khác. Sổ cái giao dịch và sổ cái ví đều chỉ
ghi thêm, không bao giờ sửa hàng cũ, nên lịch sử tiền tệ không thể bị viết lại. Và nhật ký ứng
dụng dạng JSON được chuyển ra hệ thống tập hợp nhật ký bên ngoài tiến trình, nên một tiến trình
bị chiếm quyền không thể xoá dấu vết của chính nó.

=== Kiểm soát tương tranh và chống lặp tác dụng

Nhóm kiểm soát này thường không được xếp vào phần bảo mật, nhưng trong một hệ thống có dòng
tiền thì nó chính là phần chống gian lận.

*Khoá lạc quan theo phiên bản.* Các thể tổng hợp mang cột `version`; mọi lệnh đều đọc thực thể,
thay đổi trong bộ nhớ, rồi ghi lại kèm điều kiện phiên bản phải khớp. Một bản đọc cũ luôn thua.
Đây là thứ ngăn hai thao tác đồng thời cùng đọc thấy một thế giới mà thao tác của riêng nó là
hợp lệ — chẳng hạn hai lệnh gỡ liên kết đăng nhập khác nhau cùng thấy "vẫn còn cách khác để
đăng nhập" và cùng thành công, để lại một tài khoản không ai vào được nữa.

*Ghi có điều kiện.* Ở những chỗ không có thể tổng hợp để gắn phiên bản, câu lệnh cập nhật nêu
đích danh tập trạng thái mà nó chấp nhận chuyển đi, và số hàng bị tác động là câu trả lời thành
bại. Điều quan trọng là tập trạng thái ấy phải nêu *đủ*: chỉ nêu các trạng thái kết thúc nghe
có vẻ đúng nhưng không đúng — một tiến trình quét nền đọc một lô hồ sơ rồi xử lý từng hồ sơ sẽ
có thể quyết toán một hồ sơ mà trong lúc đó ai đó vừa chuyển sang tranh chấp.

*Yêu sách được lấy trước dòng tiền.* Một phiên mua hàng bị đánh dấu đã dùng, và một đề xuất đã
chấp nhận bị chuyển sang trạng thái đã thanh toán, *trước* khi bất cứ thứ gì được giữ chỗ hay
bất cứ phiên thanh toán nào được mở. Nhờ vậy một cú nhấn đúp chỉ mở được một phiên thanh toán,
và bên thua bị từ chối. Nếu lấy yêu sách sau, cả hai lần nhấn đều mở phiên và khoản thanh toán
thứ hai sẽ là khoản tiền mà cơ chế tạm giữ không có chỗ để hạch toán. Đằng sau cả cơ chế này là
hai ràng buộc duy nhất trên `item.offer_id` và `item.draft_id`, vì ràng buộc vẫn đúng khi dịch
vụ sai.

*Khoá chống ghi trùng.* Mỗi chuyển động ví mang một khoá do bên gọi cung cấp và khoá ấy là duy
nhất; mỗi chặng tiền mang mã tham chiếu của cổng thanh toán và cặp kênh cùng mã ấy là duy nhất.
Nhờ vậy một thông báo được gửi lại lần thứ hai va vào ràng buộc thay vì trở thành lần thu tiền
thứ hai. Cùng tinh thần, bảng `order_outcome` là khoá chống cộng trùng bộ đếm uy tín, và bút
toán tồn kho có khoá tự nhiên do bên gọi đặt để một lệnh trừ kho được thử lại không trừ hai
lần.

*Khoá tư vấn cho phép kiểm tra đọc trước khi ghi.* Riêng thao tác đổi danh mục cha, việc kiểm
tra "không tạo thành chu trình" là một phép *đọc* nằm trong mệnh đề điều kiện của câu lệnh ghi,
và ở mức cô lập mặc định thì hai câu lệnh đồng thời đều thấy một thế giới mà thao tác của mình
là hợp lệ. Thao tác này vì thế lấy một khoá tư vấn ở phạm vi giao dịch trước, chỉ tuần tự hoá
các lần đổi cha với nhau chứ không ảnh hưởng gì khác.

=== Giới hạn tần suất, giám sát và quản lý bí mật

Giới hạn tần suất trong thiết kế này có *hai tầng*, và cần phân biệt rõ tầng nào đã có hiệu lực
trong bản hiện thực và tầng nào là chính sách phải cấu hình ở tầng biên.

Tầng đã có hiệu lực là *cơ chế tiết chế theo chủ thể* ở tầng dịch vụ, áp cho mọi thao tác gửi mã
một lần: gửi lại thư xác minh, gửi lại mã đặt lại mật khẩu, gửi lại mã xác minh số điện thoại.
Khoá tiết chế sống một phút và được đặt theo chính địa chỉ hoặc số điện thoại là đối tượng của
lượt gửi, nghĩa là *một lượt gửi cho mỗi chủ thể trong mỗi phút*. Như đã nói ở phần xác thực,
khoá này được đặt *trước* khi tra cứu tài khoản, để phản hồi quá tần suất không tiết lộ sự tồn
tại của một tài khoản. Đi cùng nó là thời gian sống của chính các bí mật một lần: mã xác minh
thư điện tử sống hai mươi bốn giờ, mã đặt lại mật khẩu sống một giờ, mã xác minh số điện thoại
sống mười phút — mỗi con số phản ánh khoảng thời gian hợp lý mà người dùng cần để hoàn tất đúng
luồng ấy, và luồng nào nguy hiểm hơn thì cửa sổ ngắn hơn.

Tầng thứ hai là *hạn mức theo địa chỉ mạng và theo tài khoản, đặt ở tầng biên*. Đây là chính
sách của thiết kế và chưa được cưỡng chế bằng mã trong bản hiện thực; nó được ghi ra ở đây với
các ngưỡng cụ thể để trở thành cấu hình triển khai chứ không phải một ý định.

#figure(
  kind: table,
  caption: [Hạn mức tần suất theo nhóm điểm cuối],
  table(
    columns: (1.1fr, 0.85fr, 0.75fr, 1.2fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([Nhóm điểm cuối], [Hạn mức], [Khoá đếm], [Lý do chọn ngưỡng]),
    [Đăng nhập, làm mới vé, đăng ký], [10 lượt mỗi phút], [Địa chỉ mạng],
    [Đủ rộng cho một người gõ sai vài lần, đủ hẹp để một lượt dò mật khẩu tự động trở nên vô nghĩa về thời gian.],
    [Gửi mã một lần], [1 lượt mỗi phút, 10 lượt mỗi giờ], [Chủ thể của lượt gửi],
    [Ngưỡng theo phút đã được cưỡng chế ở tầng dịch vụ; ngưỡng theo giờ chặn việc gọi tốn kém tin nhắn suốt cả ngày.],
    [Cấp đường tải lên có chữ ký], [60 lượt mỗi giờ], [Tài khoản],
    [Một bài đăng có tối đa vài chục ảnh, nên ngưỡng này rộng gấp nhiều lần nhu cầu thật và vẫn chặn được việc dùng kho lưu trữ làm nơi chứa dữ liệu miễn phí.],
    [Tìm kiếm bài đăng], [120 lượt mỗi phút], [Địa chỉ mạng],
    [Nhánh ngữ nghĩa của truy vấn gọi tới dịch vụ nhúng, nên đây vừa là biện pháp bảo mật vừa là biện pháp giữ chi phí.],
    [Mọi điểm cuối đã xác thực còn lại], [600 lượt mỗi phút], [Tài khoản],
    [Trần chung, đặt cao hơn hẳn mức dùng bình thường; nó tồn tại để chặn một máy khách hỏng chứ không để định hình hành vi.],
    [Lời gọi lại của nhà cung cấp], [Không giới hạn], [—],
    [Đây là các tuyến mà nhà cung cấp *phải* gọi lại được cho tới khi thành công; giới hạn chúng là tự đánh mất thông báo quyết toán. Chúng được bảo vệ bằng xác minh chữ ký, không bằng hạn mức.],
  ),
)

Mỗi phản hồi quá tần suất mang mã trạng thái 429 cùng tiêu đề nói rõ thời điểm được thử lại, để
máy khách chờ theo con số thay vì tự đoán bằng thời gian giãn tăng dần.

Giám sát an ninh dựa trên chính bốn tín hiệu của lược đồ `observability`. Bảng yêu cầu HTTP có
một chỉ mục bộ phận riêng cho nhóm mã trạng thái lỗi máy chủ, nên các cảnh báo về tỷ lệ lỗi
không phải quét dữ liệu thô. Bảng lời gọi ra tách riêng khái niệm thất bại — lỗi truyền tải
hoặc lỗi phía máy chủ của nhà cung cấp, còn mã lỗi phía người gọi được coi là một câu trả lời
hợp lệ — và khái niệm ấy được vật chất hoá sẵn trong khung nhìn kết tụ để nó chỉ tồn tại ở một
chỗ thay vì được diễn đạt lại trong từng truy vấn. Các mẫu đáng ngờ ở tầng nghiệp vụ cũng đã có
sẵn đường tra cứu trong mô hình dữ liệu: chỉ mục trên cặp mã ngân hàng và số tài khoản biến
việc phát hiện nhiều tài khoản nền tảng cùng dùng một tài khoản nhận tiền thành một phép tra
khoá thay vì một phép quét toàn bảng.

Về quản lý bí mật, hệ thống phân biệt rõ ba loại. Bí mật của hạ tầng — chuỗi kết nối cơ sở dữ
liệu, khoá ký vé, khoá mã hoá định danh mờ — nằm trong tài liệu cấu hình duy nhất, tài liệu này
không được đưa vào hệ quản lý mã nguồn và mọi trường trong đó đều bắt buộc, nên một triển khai
thiếu cấu hình sẽ *dừng ngay khi khởi động* kèm thông báo chỉ đúng đường dẫn cần sửa, thay vì
chạy với một giá trị mặc định mà không ai biết. Bí mật của nhà cung cấp nằm trong kho bí mật
bên ngoài và cơ sở dữ liệu chỉ giữ đường dẫn tới chúng. Còn bí mật một lần của người dùng nằm
trong bộ nhớ đệm kèm thời gian sống. Riêng khoá mã hoá định danh mờ là *vĩnh viễn không được
thay*, vì đổi nó sẽ làm vô hiệu mọi định danh đã từng công bố ra ngoài.

Cuối cùng, vòng đời dữ liệu cũng là một biện pháp bảo mật, vì dữ liệu không còn tồn tại thì
không thể bị lộ. Thông báo trong ứng dụng được xoá sau 180 ngày. Dữ liệu giám sát được xoá theo
các mốc đã nêu ở mục trước. Ngược lại, tin nhắn *cố ý không* có chính sách xoá theo thời gian,
vì chúng là bằng chứng trong tranh chấp hoàn tiền; đây là một quyết định có đánh đổi và được
ghi nhận như vậy, chứ không phải một thiếu sót.

=== Vùng an ninh và phân đoạn mạng

Hệ thống chạy như một tiến trình duy nhất, nhưng điều đó *không* có nghĩa là chỉ có một vùng
tin cậy. Thiết kế chia hạ tầng thành bốn vùng, và ranh giới giữa các vùng được cưỡng chế bằng
quy tắc mạng chứ không bằng thoả thuận.

#figure(
  kind: table,
  caption: [Bốn vùng an ninh và luồng được phép đi qua ranh giới],
  table(
    columns: (0.8fr, 1.1fr, 1.35fr),
    align: (left + top, left + top, left + top),
    table.header([Vùng], [Thành phần], [Luồng vào được phép]),
    [Vùng công cộng], [Trình duyệt, ứng dụng di động, máy chủ của nhà cung cấp bên ngoài.],
    [Không áp dụng — đây là vùng không kiểm soát được.],
    [Vùng biên], [Bộ định tuyến ngược, nơi kết thúc mã hoá đường truyền, nơi áp hạn mức tần suất và tiêu đề bảo mật.],
    [Từ vùng công cộng, chỉ cổng 443. Đây là *thành phần duy nhất* có địa chỉ công khai.],
    [Vùng ứng dụng], [Tiến trình cổng giao tiếp, tiến trình làm giàu véc-tơ, nền tảng thực thi bền.],
    [Chỉ từ vùng biên, chỉ trên cổng của ứng dụng. Không nhận kết nối trực tiếp từ vùng công cộng.],
    [Vùng dữ liệu], [PostgreSQL, bộ nhớ đệm, hàng đợi bền, kho đối tượng, kho bí mật.],
    [Chỉ từ vùng ứng dụng. Không có thành phần nào trong vùng này được phép có địa chỉ công khai — đó là quy tắc quan trọng nhất của toàn bộ bảng.],
  ),
)

Ba hệ quả của cách chia này đáng được nêu. Thứ nhất, *kho đối tượng nằm trong vùng dữ liệu*, nên
tệp không bao giờ được phục vụ trực tiếp từ kho mà luôn qua một đường dẫn ký có thời hạn do ứng
dụng cấp — điều này đã được nói ở phần bảo vệ dữ liệu và ở đây là lý do hạ tầng của nó. Thứ hai,
*chiều gọi ra ngoài là một ranh giới riêng*: mọi lời gọi tới nhà cung cấp bên ngoài đều đi ra từ
vùng ứng dụng, nên danh sách đích đến hợp lệ là một danh sách hữu hạn và kiểm soát được ở tường
lửa chiều ra. Thứ ba, *tệp cấu hình duy nhất là tài sản của vùng ứng dụng*: nó chứa chuỗi kết
nối và khoá ký, không nằm trong hệ quản lý mã nguồn, và được cấp cho tiến trình lúc triển khai.

Mô hình một tiến trình cũng đặt ra một giới hạn cần thừa nhận: *không có ranh giới mạng giữa các
mô-đun*. Một lỗ hổng cho phép thực thi mã trong tiến trình cổng giao tiếp sẽ tiếp cận được cả
bảy lược đồ, dù mỗi lược đồ có nguồn kết nối riêng. Ranh giới lược đồ ở đây là ranh giới *thiết
kế* — nó giữ cho mã nguồn không lệ thuộc chéo và giữ sẵn đường tách sau này — chứ chưa phải một
ranh giới bảo mật. Việc biến nó thành ranh giới bảo mật là một trong những lợi ích sẽ đến kèm
khi một mô-đun được tách ra tiến trình riêng, và đó là lý do khả năng tách ấy được giữ.

=== Quy trình ứng phó sự cố

Một sự cố bảo mật khác một sự cố vận hành ở chỗ nó có thể *đang tiếp diễn* trong lúc được xử lý,
nên quy trình dưới đây đặt việc chặn đứng trước việc tìm hiểu nguyên nhân. Bốn mức độ nghiêm
trọng được dùng, và mức quyết định thời hạn phản hồi.

#figure(
  kind: table,
  caption: [Phân mức sự cố bảo mật và thời hạn phản hồi],
  table(
    columns: (0.5fr, 1.35fr, 0.62fr, 0.8fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([Mức], [Ví dụ], [Bắt đầu xử lý], [Thông báo]),
    [Nghiêm trọng],
    [Lộ vật liệu xác thực (khoá ký vé, khoá mã hoá định danh, chuỗi kết nối); truy cập trái phép vào cơ sở dữ liệu; dòng tiền bị thao túng.],
    [Ngay lập tức], [Trong 24 giờ, tới mọi người dùng bị ảnh hưởng.],
    [Cao],
    [Chiếm quyền một tài khoản kiểm duyệt viên hoặc quản trị viên; lộ dữ liệu định danh cá nhân của nhiều tài khoản.],
    [Trong 1 giờ], [Trong 72 giờ.],
    [Trung bình],
    [Chiếm quyền một tài khoản người dùng; một lỗ hổng cho phép đọc dữ liệu vượt quyền nhưng chưa có dấu hiệu bị khai thác.],
    [Trong 8 giờ], [Tới người dùng liên quan.],
    [Thấp],
    [Dò quét tự động, thử mật khẩu ở mức bị hạn mức chặn, báo cáo lỗ hổng chưa khai thác được.],
    [Trong 3 ngày làm việc], [Không cần.],
  ),
)

Quy trình có năm bước và mỗi bước có một tiêu chí kết thúc rõ ràng. *Phát hiện* đến từ ba nguồn:
cảnh báo tỉ lệ lỗi và tỉ lệ 401/403 bất thường trên dữ liệu giám sát, một báo cáo từ người dùng
qua luồng phiếu hỗ trợ, hoặc một báo cáo từ bên ngoài. *Chặn đứng* là bước đầu tiên phải làm và
thiết kế đã chuẩn bị sẵn công cụ cho nó: thu hồi toàn bộ phiên của một tài khoản là một phép
tăng số hiệu kỷ nguyên, đình chỉ một tài khoản là một lượt ghi, và tắt một kênh thanh toán đang
bị lợi dụng là một lượt sửa dòng tuỳ chọn — cả ba đều có hiệu lực tức thì và không cần triển
khai lại. *Điều tra* dựa vào nhật ký kiểm toán, vì nó nằm cùng giao dịch với thay đổi nên trả
lời được câu hỏi ai đã làm gì vào lúc nào, và dựa vào bảng lời gọi ra để xác định phạm vi dữ
liệu có thể đã rời hệ thống. *Khôi phục* nghĩa là quay bí mật đã lộ, khôi phục dữ liệu từ bản
sao lưu nếu cần, và xác nhận đường tấn công đã đóng. *Rút kinh nghiệm* kết thúc bằng một biên
bản không quy trách nhiệm cá nhân, trong đó bắt buộc phải có ít nhất một thay đổi thiết kế hoặc
một cảnh báo mới — nếu không có, nghĩa là lần sau sự cố ấy vẫn xảy ra y như vậy.

Một ràng buộc phải nói rõ vì nó đã được cố định trong thiết kế và không thể thay đổi khi có sự
cố: *khoá mã hoá định danh mờ không quay được*. Đổi nó sẽ làm vô hiệu mọi định danh đã từng
công bố ra ngoài, kể cả những định danh nằm trong đường dẫn mà người dùng đã lưu và trong dữ
liệu của các máy khách. Vì vậy khoá này được xếp vào mức bảo vệ cao nhất trong kho bí mật, và
kịch bản ứng phó cho trường hợp nó bị lộ không phải là quay khoá mà là đánh giá lại toàn bộ mô
hình đe doạ — bởi thứ bị mất khi ấy chỉ là lớp phòng thủ theo chiều sâu, không phải phép kiểm
tra quyền sở hữu vốn vẫn đứng nguyên phía sau.
