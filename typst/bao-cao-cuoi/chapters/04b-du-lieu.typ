#import "../../common/tokens.typ": *

// Tên bảng và tên cột là chuỗi dài, cột bảng thì hẹp: thu nhỏ mã nội dòng cho vừa ô.
#show raw.where(block: false): set text(size: 8.5pt)

== Mô hình dữ liệu mức khái niệm

#fig(
  [Sơ đồ quan hệ thực thể mức khái niệm, phần người dùng, tin đăng và trao đổi],
  spacing: (30mm, 12mm),
  edge-stroke: 1pt + blue-s,
  label-wrapper: wlabel,

  nent((0, 0), <c-hs>, [HỒ SƠ ĐỊNH DANH]),
  nent((0, 1), <c-dc>, [ĐỊA CHỈ]),
  nent((0, 2), <c-tb>, [THIẾT BỊ]),
  nent((0, 3), <c-tbao>, [THÔNG BÁO]),
  nent((1, 1.5), <c-tk>, [TÀI KHOẢN]),
  nent((2, 0), <c-dm>, [DANH MỤC]),
  nent((2, 1.15), <c-td>, [TIN ĐĂNG]),
  nent((2, 2.3), <c-nhan>, [NHÃN]),
  nent((2, 3.5), <c-ht>, [HỘI THOẠI]),
  nent((3, 1.15), <c-tc>, [TUỲ CHỌN HÀNG]),
  nent((3, 2.3), <c-tkho>, [TỒN KHO]),
  nent((3, 3.5), <c-tn>, [TIN NHẮN]),

  ngroup((<c-hs>, <c-dc>, <c-tb>, <c-tbao>, <c-tk>)),
  gtitle((0.5, -0.62), [Miền định danh và tài khoản]),
  ngroup((<c-dm>, <c-td>, <c-nhan>, <c-tc>, <c-tkho>)),
  gtitle((2.5, -0.62), [Miền hàng hoá]),
  ngroup((<c-ht>, <c-tn>)),
  gtitle((2.5, 2.95), [Miền trao đổi]),

  edge(<c-tk>, <c-hs>, "1-n", [nộp]),
  edge(<c-tk>, <c-dc>, "1-n", [khai]),
  edge(<c-tk>, <c-tb>, "1-n", [đăng ký]),
  edge(<c-tk>, <c-tbao>, "1-n", [nhận]),
  edge(<c-tk>, <c-td>, "1-n", [đăng bán]),
  edge(<c-tk>, <c-td>, "n-n", bend: -28deg, [quan tâm]),
  edge(<c-tk>, <c-tk>, "n-n", bend: 130deg, [theo dõi]),
  edge(<c-dm>, <c-td>, "1-n", [phân loại]),
  edge(<c-td>, <c-nhan>, "n-n", [gắn]),
  edge(<c-td>, <c-tc>, "1-n", [có]),
  edge(<c-tc>, <c-tkho>, "1-1", [giữ]),
  edge(<c-tk>, <c-ht>, "n-n", [tham gia]),
  edge(<c-ht>, <c-tn>, "1-n", [chứa]),
)

#fig(
  [Sơ đồ quan hệ thực thể mức khái niệm, phần đặt hàng và giao nhận],
  spacing: (32mm, 13mm),
  edge-stroke: 1pt + blue-s,
  label-wrapper: wlabel,

  nent((0, -1), <d-gio>, [GIỎ HÀNG]),
  nent((0, 0), <d-pm>, [PHIẾU MUA TẠM]),
  nent((0, 2), <d-tl>, [THƯƠNG LƯỢNG]),
  nent((1, 1), <d-dh>, [DÒNG HÀNG]),
  nent((2, 1), <d-don>, [ĐƠN HÀNG]),
  nent((3, 0), <d-vd>, [VẬN ĐƠN]),
  nent((3, 2), <d-ht>, [YÊU CẦU HOÀN TIỀN]),

  ngroup((<d-gio>, <d-pm>, <d-tl>, <d-dh>)),
  gtitle((0.5, -1.72), [Trước khi có đơn]),
  ngroup((<d-don>, <d-vd>, <d-ht>)),
  gtitle((2.5, -1.72), [Sau khi có đơn]),

  edge(<d-gio>, <d-pm>, "1-n", [chốt từ]),
  edge(<d-pm>, <d-dh>, "1-n", [chốt thành]),
  edge(<d-tl>, <d-dh>, "1-n", [chốt thành]),
  edge(<d-don>, <d-dh>, "1-n", [gồm]),
  edge(<d-don>, <d-vd>, "1-n", [giao bằng]),
  edge(<d-don>, <d-ht>, "1-n", [phát sinh]),
)

#fig(
  [Sơ đồ quan hệ thực thể mức khái niệm, phần dòng tiền và hậu giao dịch],
  spacing: (34mm, 14mm),
  edge-stroke: 1pt + blue-s,
  label-wrapper: wlabel,

  nent((0, 1), <e-phieu>, [PHIẾU HỖ TRỢ]),
  nent((0, 2), <e-nx>, [NHẬN XÉT]),
  nent((0, 3), <e-tra>, [TRẢ LỜI NHẬN XÉT]),
  nent((1, 1), <e-tk>, [TÀI KHOẢN]),
  nent((1, 2.6), <e-don>, [ĐƠN HÀNG]),
  nent((2, 0), <e-nh>, [TÀI KHOẢN NGÂN HÀNG]),
  nent((2, 1), <e-thue>, [HỒ SƠ THUẾ]),
  nent((3, 1.8), <e-vi>, [VÍ]),
  nent((2, 2), <e-ptt>, [PHIÊN THANH TOÁN]),
  nent((3, 2.9), <e-ctt>, [CHẶNG THANH TOÁN]),

  ngroup((<e-phieu>, <e-nx>, <e-tra>)),
  gtitle((0, 0.35), [Miền tín nhiệm và hỗ trợ]),
  ngroup((<e-nh>, <e-thue>, <e-vi>, <e-ptt>, <e-ctt>)),
  gtitle((2.5, -0.45), [Miền tài chính]),

  edge(<e-tk>, <e-nh>, "1-n", [khai]),
  edge(<e-tk>, <e-thue>, "1-1", [khai]),
  edge(<e-tk>, <e-phieu>, "1-n", [gửi]),
  edge(<e-tk>, <e-nx>, "1-n", [viết]),
  edge(<e-tk>, <e-vi>, "1-n", [sở hữu]),
  edge(<e-nx>, <e-tra>, "1-n", [được trả lời]),
  edge(<e-don>, <e-nx>, "1-1", [làm cơ sở cho]),
  edge(<e-ptt>, <e-vi>, "n-1", [quyết toán vào]),
  edge(<e-ptt>, <e-ctt>, "1-n", [đi qua]),
  edge(<e-ptt>, <e-don>, "1-1", [sinh ra]),
)

== Bản đồ ngữ cảnh giới hạn

Giữa mô hình khái niệm và thiết kế lưu trữ, hệ thống cần xác định các bounded context và gán mỗi thực thể cho đúng miền sở hữu. Quyết định này chi phối trực tiếp ranh giới giữa các thành phần kiến trúc và lược đồ dữ liệu ở các phần sau.

Ranh giới giữa các ngữ cảnh được xác định tại những điểm một khái niệm thay đổi ý nghĩa. Chẳng hạn, trong miền hàng hóa, tin đăng là thực thể có mô tả, giá và có thể chỉnh sửa; trong miền đặt hàng, đơn hàng chỉ lưu một bản chụp bất biến của tin đăng tại thời điểm chốt mua. Tương tự, tài khoản trong miền định danh là hồ sơ người dùng, trong khi ở miền tài chính chỉ đóng vai trò chủ sở hữu ví và các giao dịch liên quan.

Trong mỗi ngữ cảnh, dữ liệu tiếp tục được tổ chức thành các aggregate, tức nhóm thực thể phải duy trì tính nhất quán trong cùng một giao dịch. Đơn hàng và các dòng hàng thuộc cùng một aggregate; tương tự, ví và sổ cái ví cần được cập nhật đồng thời để bảo đảm tính chính xác của số dư. Ngược lại, tồn kho thuộc miền hàng hóa nên không nằm trong aggregate của đơn hàng dù quy trình đặt hàng có tác động đến số lượng tồn.

Cuối cùng, thiết kế cần xác định rõ dữ liệu nào được phép nhất quán sau (eventual consistency), mức độ chậm trễ chấp nhận được và thành phần chịu trách nhiệm đồng bộ lại trạng thái. Bảng dưới đây mô tả hợp đồng trao đổi dữ liệu giữa các ngữ cảnh của hệ thống.


#figure(
  caption: [Hợp đồng liên ngữ cảnh: mức độ sai lệch dữ liệu và cơ chế hội tụ],
  table(
    columns: (1.5fr, 1.2fr, 1fr, 2fr),
    align: (left, left, left, left),
    table.header([Dữ liệu], [Miền sở hữu], [Độ lệch cho phép], [Cơ chế hội tụ]),

    [Điểm trung bình và số lượng nhận xét của tin đăng], [Tín nhiệm], [Vài giây],
      [Miền Tín nhiệm tính toán lại dữ liệu và phát sự kiện cập nhật; miền Danh mục lưu kết quả đã tổng hợp để phục vụ truy vấn.],

    [Điểm uy tín của người bán], [Tín nhiệm], [Vài giây],
      [Điểm uy tín được cập nhật khi tiếp nhận sự kiện đơn hàng hoàn tất; các sự kiện trùng lặp được loại bỏ dựa trên kết quả xử lý của đơn hàng.],

    [Số dư ví hiển thị trên giao diện], [Tài chính], [Không cho phép],
      [Số dư được đọc trực tiếp từ ví; mọi thay đổi số dư và bút toán tương ứng được ghi nhận trong cùng một giao dịch.],

    [Lượng tồn kho đã được giữ], [Hàng hóa], [Không cho phép],
      [Miền Đặt hàng thực hiện yêu cầu đồng bộ tới miền Hàng hóa và chỉ tiếp tục khi việc giữ tồn kho thành công.],

    [Trạng thái vận đơn], [Đối tác vận chuyển], [Đến lần cập nhật kế tiếp],
      [Trạng thái được cập nhật theo các mốc hành trình do đối tác vận chuyển gửi về; giữa hai lần cập nhật, hệ thống giữ nguyên trạng thái gần nhất.],

    [Thông báo tới người dùng], [Đơn hàng và Tài chính], [Vài giây],
      [Thông báo được phân phối bất đồng bộ qua trục sự kiện; việc chậm hoặc mất thông báo không ảnh hưởng đến trạng thái nghiệp vụ gốc.],
  ),
)

#fig(
  [Bản đồ ngữ cảnh giới hạn, các aggregate và quan hệ nhất quán giữa chúng],
  spacing: (44mm, 26mm),
  edge-stroke: 1pt + blue-s,
  label-wrapper: wlabel,

  nvung((0, 0), <v-dd>, [Định danh], [Tài khoản · địa chỉ · thiết bị], [Hồ sơ định danh], [Thông báo]),
  nvung((1, 0), <v-hh>, [Hàng hoá], [Tin đăng · tuỳ chọn · tồn kho], [Danh mục], [Nhãn]),
  nvung((2, 0), <v-td>, [Trao đổi], [Hội thoại · tin nhắn]),
  nvung((0, 1), <v-tc>, [Tài chính], [Phiên thanh toán · chặng], [Ví · sổ cái ví], [Tài khoản ngân hàng], [Hồ sơ thuế]),
  nvung((1, 1), <v-dh>, [Đặt hàng], [Đơn hàng · dòng hàng · vận đơn], [Phiếu mua tạm], [Thương lượng], [Giỏ hàng], [Yêu cầu hoàn tiền]),
  nvung((2, 1), <v-tn>, [Tín nhiệm], [Nhận xét · trả lời · bình chọn], [Uy tín], [Phiếu hỗ trợ]),
  nvung((1, 2), <v-qt>, [Quan trắc], [Nhật ký · độ đo · dấu vết]),

  edge(<v-dh>, <v-tc>, "-|>", [mở phiên · đồng bộ]),
  edge(<v-tc>, <v-dh>, "-|>", stroke: (dash: "dashed"), bend: 32deg, [tiền vào ký quỹ · dần]),
  edge(<v-dh>, <v-hh>, "-|>", [giữ tồn kho · đồng bộ]),
  edge(<v-dh>, <v-tn>, "-|>", stroke: (dash: "dashed"), [đơn hoàn tất · dần]),
  edge(<v-tn>, <v-hh>, "-|>", stroke: (dash: "dashed"), [điểm trung bình · dần]),
  edge(<v-tn>, <v-td>, "-|>", [luồng phiếu · đồng bộ]),
  edge(<v-dh>, <v-dd>, "-|>", [tra tài khoản · đồng bộ]),
  edge(<v-dh>, <v-qt>, "-|>", stroke: (dash: "dashed"), [sự kiện nghiệp vụ · dần]),
)

Quy ước đọc bản đồ: 
- Đường liền nét biểu thị lời gọi đồng bộ, trong đó bên gọi chờ kết quả trước khi tiếp tục xử lý
- Đường nét đứt biểu thị sự kiện bất đồng bộ, cho phép bên nhận xử lý sau và dữ liệu giữa hai ngữ cảnh có thể tạm thời chưa đồng nhất. 


== Thiết kế cơ sở dữ liệu vật lý

Mô hình dữ liệu được hiện thực trên PostgreSQL chạy trên bản phân phối TimescaleDB, bộ ký tự UTF-8. Ngoài phần lõi quan hệ, thiết kế dựa vào 6 phần mở rộng, mỗi phần phục vụ một nhóm truy vấn mà nếu thiếu nó thì phải giải quyết bằng một hệ lưu trữ thứ hai: TimescaleDB cho bảng ghi theo thời gian, PostGIS cho toạ độ địa lý, pgvector cho vector ngữ nghĩa, `pg_trgm` cùng `unaccent` cho tìm kiếm gần đúng không dấu, và bộ công cụ thống kê của TimescaleDB cho phép tính phân vị. Cả 6 đều được cài vào lược đồ `public` chứ không vào lược đồ của module, vì một phần mở rộng chỉ thuộc về đúng một lược đồ trong mỗi cơ sở dữ liệu; đổi lại, mỗi module vẫn tự khai báo phần mở rộng mà nó cần, để khi tách sang cơ sở dữ liệu riêng nó mang theo đủ điều kiện tiên quyết của mình. Dữ liệu nghiệp vụ tổ chức thành 7 lược đồ (schema), mỗi lược đồ mang đúng tên module sở hữu nó; đây không phải ranh giới triển khai (hệ thống chạy như một tiến trình duy nhất) mà là ranh giới quyền ghi và ranh giới di chuyển.

#figure(
  kind: table,
  caption: [7 lược đồ vật lý và phạm vi dữ liệu của từng lược đồ],
  table(
    columns: (0.85fr, 3.5fr),
    align: (left + horizon, left + horizon),
    table.header([Lược đồ], [Phạm vi dữ liệu]),
    [`account`], [Định danh, đăng nhập liên kết, hồ sơ hiển thị, sổ địa chỉ, thiết bị nhận đẩy, thông báo và tuỳ chọn kênh, đồ thị theo dõi, giấy tờ định danh.],
    [`catalog`], [Danh mục, tin đăng, biến thể, thẻ, tồn kho và bút toán tồn kho, danh sách yêu thích, vector ngữ nghĩa của tin đăng, danh mục và thẻ.],
    [`order`], [Giỏ hàng, phiên mua hàng giá cố định, thương lượng giá, đơn hàng, mục hàng, vận đơn và hồ sơ hoàn tiền.],
    [`finance`], [Phiên thanh toán, sổ cái giao dịch trên kênh thanh toán ngoài, ví theo tài khoản và loại tiền, sổ cái ví, tài khoản ngân hàng nhận tiền, thông tin thuế.],
    [`trust`], [Đánh giá sản phẩm cùng trả lời và bình chọn hữu ích, điểm uy tín, phiếu hỗ trợ và idempotency key cho kết cục đơn hàng.],
    [`chat`], [Luồng hội thoại một-một giữa hai tài khoản và tin nhắn trong luồng.],
    [`observability`], [4 bảng tín hiệu vận hành. Không nhận phần định nghĩa dùng chung.],
  ),
)

=== Nguyên tắc thiết kế dữ liệu

*Cô lập theo lược đồ.* Mỗi module sở hữu một lược đồ mang đúng tên nó và là thành phần duy nhất được phép ghi vào đó; không truy vấn nào nối bảng của 2 lược đồ khác nhau. Nguồn kết nối đặt đường tìm kiếm về lược đồ của mình cộng `public`, nên toàn bộ SQL viết không kèm tên lược đồ và một module có thể chuyển sang cơ sở dữ liệu khác mà không sửa một dòng SQL; hệ quả là mọi ràng buộc toàn vẹn tham chiếu chỉ tồn tại bên trong một lược đồ.

*Khoá thay thế là số nguyên 64 bit.* Mọi khoá thay thế đều là `BIGINT` sinh tự động, không có `UUID` ở bất kỳ đâu: khoá tuần tự cho chỉ mục dày đặc hơn và hàng nhỏ hơn, còn lý do thường viện dẫn cho `UUID` (không để lộ số lượng bản ghi) đã được giải quyết bằng định danh mờ. Đúng 2 ngoại lệ, cả 2 trong `finance`: phiên thanh toán và giao dịch cho phép ứng dụng chỉ định định danh, vì định danh phải được trao cho cổng thanh toán trước khi chèn hàng.

*Tham chiếu chéo lược đồ không dùng khoá ngoại.* Khoá ngoại chỉ khai báo khi cả 2 bảng cùng lược đồ; trỏ sang lược đồ khác thì cột tham chiếu là `BIGINT` trần, vì một khoá ngoại xuyên lược đồ là thứ duy nhất không thể đi theo module khi module đó tách ra. Toàn vẹn ở đó được giữ bằng 3 cơ chế: xoá mềm ở bảng bị trỏ tới, để một mục hàng cũ vẫn phân giải được tên tin đăng sau khi người bán gỡ tin; sao chép có chủ đích những giá trị phía kia có thể đổi; và idempotency key cho thao tác đi qua hàng đợi sự kiện vốn chỉ bảo đảm giao ít nhất một lần.


=== Sơ đồ cơ sở dữ liệu

Sơ đồ cơ sở dữ liệu khác sơ đồ quan hệ thực thể ở mục trước cả về nội dung lẫn mục đích. Sơ đồ
thực thể trả lời hệ thống nói về những khái niệm gì; sơ đồ dưới đây trả lời các khái niệm ấy
được lưu thành bảng nào, khoá ra sao và ràng buộc gì giữ cho dữ liệu không sai. Vì vậy ở đây có
đủ tên bảng thật, khoá chính, khoá ngoại kèm hành vi khi bản ghi cha bị xoá, và các ràng buộc
duy nhất; đồng thời xuất hiện cả những bảng không phải khái niệm nghiệp vụ như bảng nối và bảng
dẫn xuất.


#fig(
  [Sơ đồ cơ sở dữ liệu, lược đồ `account`],
  spacing: (48mm, 21mm),
  edge-stroke: 0.9pt + blue-s,
  label-wrapper: wlabel,

  nbang((1, 1), <b-account>, "account", [PK id], [UQ phone], [UQ email], [UQ username], [status: account_status], [role: account_role], [gender: profile_gender], [date_of_birth: date]),
  nbang((0, 1), <b-identity_document>, "identity_document", [PK id], [FK account_id #sym.arrow.r account · xoá lan], [FK front_resource_id #sym.arrow.r resource · gán rỗng], [FK back_resource_id #sym.arrow.r resource · gán rỗng], [FK selfie_resource_id #sym.arrow.r resource · gán rỗng], [UQ provider, provider_ref], [doc_type: identity_document_type], [status: identity_status], [rejection_reason: text], [verified_at: timestamptz]),
  nbang((2, 1), <b-follow>, "follow", [PK follower_id, followee_id], [FK follower_id #sym.arrow.r account · xoá lan], [FK followee_id #sym.arrow.r account · xoá lan]),
  nbang((1, 0), <b-oauth_identity>, "oauth_identity", [PK id], [FK account_id #sym.arrow.r account · xoá lan], [UQ provider, provider_uid], [UQ account_id, provider]),
  nbang((1, 2), <b-device>, "device", [PK id], [FK account_id #sym.arrow.r account · xoá lan], [UQ push_token], [platform: device_platform], [last_seen_at: timestamptz]),
  nbang((0, 0), <b-contact>, "contact", [PK id], [FK account_id #sym.arrow.r account · xoá lan], [address_type: contact_address_type], [location: geography], [country: varchar(2)], [full_name: varchar(100)]),
  nbang((2, 0), <b-notification>, "notification", [PK id, created_at], [FK account_id #sym.arrow.r account · xoá lan], [category: notification_category], [title: varchar(200)], [read_at: timestamptz], [scheduled_at: timestamptz]),
  nbang((0, 2), <b-notification_preference>, "notification_preference", [PK account_id, category, channel], [FK account_id #sym.arrow.r account · xoá lan]),

  edge(<b-identity_document>, <b-account>, "n-1"),
  edge(<b-follow>, <b-account>, "n-1"),
  edge(<b-follow>, <b-account>, "n-1"),
  edge(<b-oauth_identity>, <b-account>, "n-1"),
  edge(<b-device>, <b-account>, "n-1"),
  edge(<b-contact>, <b-account>, "n-1"),
  edge(<b-notification>, <b-account>, "n-1"),
  edge(<b-notification_preference>, <b-account>, "n-1"),
)
#fig(
  [Sơ đồ cơ sở dữ liệu, lược đồ `catalog`],
  spacing: (48mm, 21mm),
  edge-stroke: 0.9pt + blue-s,
  label-wrapper: wlabel,

  nbang((0, 0), <b-category_embedding>, "category_embedding", [PK category_id], [FK category_id #sym.arrow.r category · xoá lan], [sparse: sparsevec]),
  nbang((2, 0), <b-listing_embedding>, "listing_embedding", [PK listing_id], [FK listing_id #sym.arrow.r listing · xoá lan], [sparse: sparsevec]),
  nbang((3, 0), <b-account_interest>, "account_interest", [PK account_id, slot], [strength: real]),
  nbang((0, 1), <b-category>, "category", [PK id], [FK parent_id #sym.arrow.r category · gán rỗng], [UQ name], [embedding_stale_at: timestamptz]),
  nbang((1, 1), <b-listing>, "listing", [PK id], [FK category_id #sym.arrow.r category · chặn xoá], [UQ slug], [status: listing_status], [price_mode: price_mode], [condition: listing_condition], [account_id: int8]),
  nbang((2, 1), <b-variant>, "variant", [PK id], [FK listing_id #sym.arrow.r listing · xoá lan], [price: int8], [deleted_at: timestamptz]),
  nbang((3, 1), <b-stock>, "stock", [PK variant_id], [FK variant_id #sym.arrow.r variant · xoá lan], [quantity: int8]),
  nbang((0, 2), <b-tag>, "tag", [PK id], [embedding_stale_at: timestamptz]),
  nbang((1, 2), <b-listing_tag>, "listing_tag", [PK id], [FK listing_id #sym.arrow.r listing · xoá lan], [FK tag #sym.arrow.r tag · xoá lan], [UQ listing_id, tag]),
  nbang((2, 2), <b-favorite>, "favorite", [PK account_id, listing_id], [FK listing_id #sym.arrow.r listing · xoá lan]),
  nbang((3, 2), <b-stock_movement>, "stock_movement", [PK key], [FK variant_id #sym.arrow.r variant · xoá lan]),
  nbang((0, 3), <b-tag_embedding>, "tag_embedding", [PK tag_id], [FK tag_id #sym.arrow.r tag · xoá lan], [sparse: sparsevec]),

  edge(<b-listing>, <b-category>, "n-1"),
  edge(<b-variant>, <b-listing>, "n-1"),
  edge(<b-listing_tag>, <b-listing>, "n-1"),
  edge(<b-listing_tag>, <b-tag>, "n-1"),
  edge(<b-listing_embedding>, <b-listing>, "n-1"),
  edge(<b-category_embedding>, <b-category>, "n-1"),
  edge(<b-tag_embedding>, <b-tag>, "n-1"),
  edge(<b-favorite>, <b-listing>, "n-1"),
  edge(<b-stock>, <b-variant>, "n-1"),
  edge(<b-stock_movement>, <b-variant>, "n-1"),
)
#fig(
  [Sơ đồ cơ sở dữ liệu, lược đồ `order`],
  spacing: (48mm, 21mm),
  edge-stroke: 0.9pt + blue-s,
  label-wrapper: wlabel,

  nbang((1, 1), <b-order>, "order", [PK id], [FK transport_id #sym.arrow.r transport · không đổi], [FK draft_id #sym.arrow.r draft_order · không đổi], [FK offer_id #sym.arrow.r offer · không đổi], [UQ transport_id], [UQ draft_id], [UQ offer_id], [payout_released_at: is], [received_at: is], [decline_reason: is], [decline_reason: text]),
  nbang((0, 1), <b-transport>, "transport", [PK id], [status: transport_status], [fee: int8]),
  nbang((2, 1), <b-draft_order>, "draft_order", [PK id], [cancelled_at: timestamptz]),
  nbang((1, 0), <b-offer>, "offer", [PK id], [status: offer_status], [quantity: int8], [total: int8], [reason: text]),
  nbang((1, 2), <b-item>, "item", [PK id], [FK order_id #sym.arrow.r order · không đổi], [FK draft_id #sym.arrow.r draft_order · không đổi], [FK offer_id #sym.arrow.r offer · không đổi], [quantity: int8], [total_amount: int8], [note: text], [cancelled_at: timestamptz]),
  nbang((0, 0), <b-refund>, "refund", [PK id], [FK order_id #sym.arrow.r order · không đổi], [FK return_transport_id #sym.arrow.r transport · không đổi], [UQ return_transport_id], [status: refund_status], [returned_at: is], [reason: text], [deadline_at: timestamptz]),
  nbang((2, 0), <b-cart_item>, "cart_item", [PK id], [UQ account_id, variant_id], [quantity: int8]),

  edge(<b-order>, <b-transport>, "n-1"),
  edge(<b-order>, <b-draft_order>, "n-1"),
  edge(<b-order>, <b-offer>, "n-1"),
  edge(<b-item>, <b-order>, "n-1"),
  edge(<b-item>, <b-draft_order>, "n-1"),
  edge(<b-item>, <b-offer>, "n-1"),
  edge(<b-refund>, <b-order>, "n-1"),
  edge(<b-refund>, <b-transport>, "n-1"),
)
#fig(
  [Sơ đồ cơ sở dữ liệu, lược đồ `finance`],
  spacing: (52mm, 21mm),
  edge-stroke: 0.9pt + blue-s,
  label-wrapper: wlabel,

  nbang((0, 0), <b-payment_session>, "payment_session", [PK id], [kind: session_kind], [status: session_status], [total_amount: int8], [note: text]),
  nbang((1, 0), <b-transaction>, "transaction", [PK id], [FK session_id #sym.arrow.r payment_session · không đổi], [FK reverses_id #sym.arrow.r transaction · không đổi], [status: transaction_status], [amount: int8], [note: text], [settled_at: timestamptz]),
  nbang((2, 0), <b-wallet>, "wallet", [PK account_id, currency], [available_balance: int8], [held_balance: int8]),
  nbang((0, 1), <b-wallet_transaction>, "wallet_transaction", [PK id], [UQ account_id, currency, seq], [kind: wallet_txn_kind], [note: text]),
  nbang((1, 1), <b-bank_account>, "bank_account", [PK id], [account_id: int8], [account_number: varchar(50)], [account_holder: varchar(100)], [bank_code: varchar(20)]),
  nbang((2, 1), <b-tax_info>, "tax_info", [PK account_id], [verification_status: verification_status], [tax_code: varchar(14)], [tax_code_type: varchar(20)], [legal_name: text]),

  edge(<b-transaction>, <b-payment_session>, "n-1"),
)
#fig(
  [Sơ đồ cơ sở dữ liệu, lược đồ `trust`, `chat` và các bảng dùng chung],
  spacing: (48mm, 21mm),
  edge-stroke: 0.9pt + blue-s,
  label-wrapper: wlabel,

  nbang((1, 1), <b-review>, "review", [PK id], [UQ listing_id, author_id, order_id], [rating: int2], [helpful_count: int8], [not_helpful_count: int8], [reply_count: int8]),
  nbang((0, 1), <b-conversation>, "conversation", [PK id], [kind: conversation_kind], [account_a_id: int8], [account_b_id: int8], [account_a_read_at: timestamptz]),
  nbang((2, 1), <b-resource>, "resource", [PK id], [UQ provider, object_key], [checksum: is], [completed_at: timestamptz], [deleted_at: timestamptz]),
  nbang((1, 0), <b-message>, "message", [PK id, created_at], [FK conversation_id #sym.arrow.r conversation · xoá lan], [type: message_type], [body: text], [edited_at: timestamptz], [deleted_at: timestamptz]),
  nbang((1, 2), <b-option>, "option", [PK id], [FK logo_resource_id #sym.arrow.r resource · gán rỗng], [name: text], [deleted_at: timestamptz]),
  nbang((0, 0), <b-review_reply>, "review_reply", [PK id], [FK review_id #sym.arrow.r review · xoá lan], [body: text]),
  nbang((2, 0), <b-review_vote>, "review_vote", [PK review_id, account_id], [FK review_id #sym.arrow.r review · xoá lan]),
  nbang((0, 2), <b-audit_log>, "audit_log", [PK id], [UQ table_name, record_id, version], [code: varchar(100)], [changed_at: timestamptz]),
  nbang((2, 2), <b-feedback>, "feedback", [PK id], [UQ order_id, direction], [rating: int2], [published_at: timestamptz]),
  nbang((1, 3), <b-reputation>, "reputation", [PK account_id, role], [rating_sum: int8], [rating_count: int8], [review_rating_sum: int8], [review_rating_count: int8]),
  nbang((0, 3), <b-order_outcome>, "order_outcome", [PK order_id], [recorded_at: timestamptz]),
  nbang((2, 3), <b-ticket>, "ticket", [PK id], [UQ conversation_id], [kind: ticket_kind], [ref_type: ticket_ref_type], [reason: ticket_reason], [status: ticket_status]),

  edge(<b-message>, <b-conversation>, "n-1"),
  edge(<b-option>, <b-resource>, "n-1"),
  edge(<b-review_reply>, <b-review>, "n-1"),
  edge(<b-review_vote>, <b-review>, "n-1"),
)
=== Lược đồ `account`

Một tài khoản vừa là người mua vừa là người bán, nên lược đồ này không phân biệt hai vai ở mức bảng. Quyết định đáng chú ý nhất là hợp nhất bảng hồ sơ vào bảng tài khoản: tên hiển thị là bắt buộc và được ghi bởi cùng câu lệnh với hàng tài khoản, nên tách ra một bảng một-một chỉ mua thêm một phép kết nối và một lần ghi thứ hai. Ngược lại, sổ địa chỉ không được gộp, vì gộp vào sẽ khiến mỗi lần đổi tên hiển thị phải nạp thêm hàng chục cột địa chỉ.


=== Lược đồ `catalog`

Về mô hình hoá, tin đăng không phải một mục trong danh mục sản phẩm dùng chung: hai người bán rao cùng một mẫu điện thoại là hai hàng độc lập, vì tình trạng món hàng, giá và người bán đều là thuộc tính của lời rao. Tồn kho tách thành bảng riêng dù quan hệ với biến thể là một-một, vì số giữ chỗ đổi theo từng lượt thanh toán còn hàng biến thể chỉ đổi khi người bán sửa tin. Hàng đợi tính lại vector ngữ nghĩa là một thuộc tính của chính dữ liệu chứ không phải một hàng đợi thông điệp, nhờ đó một hàng bị sửa trong lúc triển khai vẫn còn nguyên dấu sau đó.


=== Lược đồ `order`

Quyết định trung tâm: người bán không duyệt đơn; chính dòng tiền tạo ra đơn. Người mua mở một phiên mua hàng đóng băng giá người bán đang hỏi, trả tiền hàng cộng cước, và đơn hàng cùng vận đơn ra đời ngay khi phiên thanh toán hoàn tất, đó là lý do cột đơn hàng trên mục hàng cho phép rỗng. Vì có 2 nguồn hình thành đơn, cả bảng đơn lẫn bảng mục hàng đều mang 2 cột cho phép rỗng trỏ về phiếu mua tạm và về cuộc thương lượng, kèm ràng buộc buộc đúng một trong hai có giá trị.


=== Lược đồ `finance`

Lược đồ này giữ toàn bộ nguyên thể tiền tệ trong một chỗ, vì giữ tiền tạm và giải ngân phải nguyên tử nên phiên thanh toán, sổ cái giao dịch, ví, sổ cái ví và tài khoản ngân hàng đều phải ở cùng một ranh giới giao dịch. Điểm cần hiểu đúng nhất là 2 sổ cái với một ranh giới rõ ràng: bảng giao dịch chỉ ghi những chặng tiền đi qua kênh thanh toán bên ngoài, còn tiền chỉ di chuyển bên trong ví thì chỉ ghi vào sổ cái ví. Cả 2 sổ đều chỉ ghi thêm, nên hoàn tiền tạo bút toán mới mang dấu âm trỏ về bút toán bị đảo.


=== Lược đồ `trust`

Thay đổi mô hình hoá lớn nhất: mọi thứ người dùng gửi lên đều là một phiếu, và một bảng duy nhất chứa tất cả, nên không còn bảng tranh chấp riêng và bảng báo cáo vi phạm riêng.



=== Lược đồ `chat`

Một luồng hội thoại là một luồng cho mỗi cặp tài khoản, bất kể ai mua ai bán; ngữ cảnh sản phẩm không nằm ở luồng mà ở từng tin nhắn. Với thương lượng giá, tin nhắn chỉ mang định danh cuộc thương lượng trong siêu dữ liệu chứ tuyệt đối không chép giá vào, vì nếu chép thì một lần sửa đề xuất sẽ để lại trong luồng một mức giá không còn trên bàn đàm phán. Trạng thái đọc không lưu trên từng tin nhắn mà là hai dấu thời gian trên hàng hội thoại, vì bảng tin nhắn phân mảnh theo thời gian nên một cờ đã đọc trên từng tin sẽ biến mọi câu hỏi về tin chưa đọc thành phép đếm không có cận thời gian.

=== Các bảng dùng chung

3 bảng cuối cần hiểu khác với 7 lược đồ trên: `common` không phải một module và không phải một lược đồ, nó không có giao diện dịch vụ và công cụ di trú không tạo ra lược đồ nào tên như vậy; cái nó cung cấp là phần định nghĩa dữ liệu được áp vào lược đồ của từng module nghiệp vụ.


== Thiết kế bảo mật

=== Xác thực và phân quyền

- Cơ chế xác thực kép: Ứng dụng kết hợp Access Token tĩnh (JWT sống 15 phút, mang định danh mờ) và Trạng thái phiên động (Session lưu tại bộ nhớ đệm, sống 30 ngày). Mọi yêu cầu API bắt buộc phải tra cứu phiên song song với việc xác thực chữ ký JWT, đảm bảo thao tác thu hồi quyền (đăng xuất, đình chỉ) có hiệu lực tức thời.
- Bảo mật phiên và mã thông báo (Token Rotation): Refresh Token được thiết lập xoay vòng ở mỗi lần cấp đổi.

=== Bảo vệ dữ liệu và kiểm soát đầu vào

Nguyên tắc Tối thiểu hóa dữ liệu (Data Minimization) được tuân thủ xuyên suốt hệ thống. Các trường dữ liệu định danh như số Căn cước không được lưu ở dạng bản rõ; hồ sơ eKYC chỉ giữ kết luận phê duyệt và mã đối chiếu (Reference ID) của nhà cung cấp, qua đó vô hiệu hóa hoàn toàn giá trị của dữ liệu nếu xảy ra lộ lọt. Tương tự, thông tin định danh của nhà cung cấp bên ngoài (API Keys) không nằm dưới dạng bản rõ trong cơ sở dữ liệu mà chỉ được giữ ở dạng đường dẫn tham chiếu, còn tệp tĩnh tải lên được cô lập bảo mật thông qua cơ chế Đường dẫn ký có thời hạn (Presigned URLs). Ở tầng nhật ký, cơ chế lọc được cưỡng chế nhằm bảo đảm mật khẩu, Access Token hoặc nội dung bí mật một lần không bị ghi lại dưới mọi hình thức.

=== Giới hạn tần suất, quản lý bí mật và vòng đời dữ liệu

- *Miễn trừ tiết lưu Webhook (Webhook Exemption):* Các tuyến API nhận lời gọi lại (Callback) từ đối tác ngoài được loại trừ khỏi giới hạn tần suất, bảo mật hoàn toàn bằng cơ chế xác minh chữ ký (Signature Verification).
- *Hạn chế hiện tại ở lớp biên:* Giới hạn lưu lượng theo định tuyến IP và tài khoản (Rate Limiting) tại lớp biên (API Gateway) hiện đóng vai trò quy chuẩn thiết kế, chưa được thực thi bằng mã nguồn.
