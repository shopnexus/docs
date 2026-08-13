#import "../../common/tokens.typ": *

// Tên bảng và tên cột là chuỗi dài, cột bảng thì hẹp: thu nhỏ mã nội dòng cho vừa ô.
#show raw.where(block: false): set text(size: 8.5pt)

== Mô hình dữ liệu mức khái niệm

Mức khái niệm trả lời câu hỏi hệ thống nói về những thứ gì và chúng liên hệ với nhau ra sao,
tách hẳn khỏi câu hỏi lưu trữ thế nào. Vì vậy 3 sơ đồ dưới đây không có khoá ngoại, không có cột,
không có kiểu dữ liệu và cũng không có bảng nối: một quan hệ nhiều-nhiều được vẽ thẳng thành
một đường nối mang tên quan hệ, thay vì tách ra thành một thực thể trung gian như khi hiện thực.
Bản số đọc theo quy ước chân quạ ở cả hai đầu. Khung nét đứt gom các thực thể thuộc cùng một miền nghiệp vụ. Lưu ý miền ở đây là ranh giới nghiệp vụ chứ không phải lược đồ cơ sở dữ liệu: một miền có thể về sau được hiện thực thành một lược đồ, nhưng ở mức khái niệm thì cách lưu trữ chưa được quyết định. Toàn bộ tên thực thể viết bằng tiếng Việt theo
đúng cách người dùng nghiệp vụ gọi chúng, chứ không dùng tên bảng.

So với 42 bảng ở mức vật lý, mức khái niệm rút còn 27 thực thể. Phần chênh lệch gồm 3 nhóm.
Nhóm thứ nhất là các bảng nối sinh ra chỉ để hiện thực quan hệ nhiều-nhiều, gồm bảng nối tin
đăng với nhãn, bảng lưu quan tâm, bảng theo dõi người bán và bảng bình chọn nhận xét; ở mức
khái niệm chúng là đường nối chứ không phải thực thể. Nhóm thứ hai là các bảng kỹ thuật hoặc
dẫn xuất, gồm bảng vector ngữ nghĩa của tin đăng, bảng tổng hợp uy tín, bảng chống lặp kết cục
đơn, bảng tuỳ chọn nhận thông báo và các bảng tra cứu dùng chung; chúng tồn tại vì hiệu năng
hoặc vì ràng buộc kỹ thuật chứ không phải vì nghiệp vụ. Nhóm thứ ba là bảng nhật ký kiểm toán,
vốn ghi lại mọi quyết định nghiệp vụ nên không thuộc riêng thực thể nào và được mô tả bằng lời
thay vì vẽ thành một ô rời không nối với ai.

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

Giữa mô hình khái niệm và thiết kế lưu trữ có một bước trung gian quyết định: chia hệ thống
thành các ngữ cảnh giới hạn, và gán mỗi thực thể cho đúng một ngữ cảnh làm chủ nó. Đây là quyết
định khó đảo ngược nhất của toàn bộ thiết kế, vì ranh giới thành phần ở mục kiến trúc và ranh
giới lược đồ ở mục sau đều đọc từ bản đồ này mà ra.

Ranh giới được tìm bằng chỗ một danh từ đổi nghĩa. Rõ nhất là từ "tin đăng": trong miền hàng
hoá, tin đăng là một mặt hàng có mô tả, có giá và sửa được; nhưng trong miền đặt hàng, thứ mà
một đơn hàng nắm giữ là bản chụp bất biến của tin đăng tại thời điểm chốt mua, và nó không được
đổi theo tin đăng gốc nữa. Hai nghĩa khác nhau của cùng một từ, nên đó là chỗ một mô hình nhất
quán phải dừng lại. Tương tự, "tài khoản" trong miền định danh là hồ sơ người dùng với giấy tờ
và thiết bị, còn trong miền tài chính nó chỉ là chủ sở hữu của một cặp ví và một dòng tiền.

Bên trong mỗi ngữ cảnh, dữ liệu lại được gom thành các aggregate, tức cụm nhỏ nhất buộc phải
nhất quán với nhau trong cùng một giao dịch. Đơn hàng cùng các dòng hàng của nó là một
aggregate vì một dòng hàng không thể tồn tại mà thiếu đơn; ví cùng sổ cái ví là một aggregate
vì số dư và lượt dịch chuyển sinh ra số dư ấy phải được ghi cùng nhau, nếu không thì tổng tiền
của hệ thống sai. Ngược lại, tồn kho không nằm trong aggregate đơn hàng dù đặt hàng có trừ tồn
kho, vì tồn kho thuộc quyền của miền hàng hoá.

#fig(
  [Bản đồ ngữ cảnh giới hạn: 7 ngữ cảnh, các aggregate và quan hệ nhất quán giữa chúng],
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

Quy ước đọc bản đồ: đường liền nét là lời gọi đồng bộ, bên gọi chờ kết quả trước khi đi tiếp;
đường nét đứt là sự kiện bất đồng bộ, bên nhận xử lý sau và trong khoảng thời gian ấy hai bên
được phép lệch nhau. Bên trong một ngữ cảnh, dữ liệu luôn nhất quán mạnh vì mọi thay đổi nằm
trong cùng một giao dịch cơ sở dữ liệu. Bắc qua hai ngữ cảnh thì chỉ còn nhất quán dần, kể cả
khi đường nối là lời gọi đồng bộ, vì hai bên ghi vào hai giao dịch khác nhau và không có giao
dịch phân tán nào ràng chúng lại. Chính vì vậy các luồng dài như ký quỹ hay hoàn tiền phải được
điều phối bằng thực thi bền thay vì bằng một giao dịch duy nhất.

Vài cụm trong bản đồ không xuất hiện ở sơ đồ khái niệm, ví dụ sổ cái ví hay bản tổng hợp uy tín. Đó là các cụm dẫn xuất: chúng không phải khái niệm nghiệp vụ mới mà là dữ liệu được tính ra rồi giữ sẵn, và chúng thuộc quyền của chính ngữ cảnh đã tính ra chúng. Bản đồ phải nêu chúng vì mục đích của bản đồ là phân định quyền ghi, mà quyền ghi thì áp cho mọi thứ được lưu chứ không riêng khái niệm nghiệp vụ.

Bản đồ này ràng buộc hai thứ ở phía sau. Thứ nhất là ranh giới thành phần: 7 ngữ cảnh chính là
7 module đã trình bày ở mục kiến trúc, không hơn không kém. Thứ hai là ranh giới lưu trữ: mỗi
ngữ cảnh làm chủ đúng một lược đồ và chỉ được ghi vào lược đồ của mình, nên trong các sơ đồ cơ
sở dữ liệu ở mục sau không có khoá ngoại nào bắc qua hai lược đồ.

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

*3 bảng dùng chung, 18 hiện thân.* Nhật ký kiểm toán, bảng tài nguyên tệp và bảng tuỳ chọn được định nghĩa đúng một lần rồi áp vào 6 lược đồ nghiệp vụ, vì một bảng nhật ký kiểm toán toàn cục sẽ không thể đi theo một module khi module ấy tách sang cơ sở dữ liệu riêng; trước khi hợp nhất, 7 module đều tự chép một bản và 4 trong số đó đã trôi khác nhau.

=== Sơ đồ cơ sở dữ liệu

Sơ đồ cơ sở dữ liệu khác sơ đồ quan hệ thực thể ở mục trước cả về nội dung lẫn mục đích. Sơ đồ
thực thể trả lời hệ thống nói về những khái niệm gì; sơ đồ dưới đây trả lời các khái niệm ấy
được lưu thành bảng nào, khoá ra sao và ràng buộc gì giữ cho dữ liệu không sai. Vì vậy ở đây có
đủ tên bảng thật, khoá chính, khoá ngoại kèm hành vi khi bản ghi cha bị xoá, và các ràng buộc
duy nhất; đồng thời xuất hiện cả những bảng không phải khái niệm nghiệp vụ như bảng nối và bảng
dẫn xuất.

Năm hình dưới đây gom theo lược đồ sở hữu, đúng ranh giới đã chốt ở mục kiến trúc: mỗi module
làm chủ một lược đồ và chỉ ghi vào lược đồ của mình. Ký hiệu trong ô đọc như sau. PK là khoá
chính, có thể gồm nhiều cột. FK là khoá ngoại, ghi kèm bảng đích và hành vi khi bản ghi bên
bảng đích bị xoá: xoá lan nghĩa là bản ghi con bị xoá theo, gán rỗng nghĩa là cột khoá được đặt
về rỗng, chặn xoá nghĩa là không cho xoá chừng nào còn bản ghi con, còn không đổi nghĩa là cơ
sở dữ liệu để nguyên và tầng dịch vụ tự chịu trách nhiệm. UQ là ràng buộc duy nhất, và một ràng
buộc gồm nhiều cột nghĩa là bộ giá trị của các cột đó phải duy nhất chứ không phải từng cột
riêng lẻ.

Toàn hệ thống có 45 bảng nghiệp vụ với 36 khoá ngoại và 21 ràng buộc duy nhất. Đáng chú ý là
khoá ngoại chỉ tồn tại bên trong một lược đồ, không có khoá ngoại nào bắc qua hai lược đồ. Đây
là hệ quả trực tiếp của nguyên lý mỗi dịch vụ một cơ sở dữ liệu: một tham chiếu chéo lược đồ,
ví dụ dòng hàng trỏ tới tin đăng, được giữ đúng bởi tầng dịch vụ chứ không bởi cơ sở dữ liệu,
vì nếu ràng buộc bằng khoá ngoại thì 2 module sẽ không bao giờ tách rời được. Trong lược đồ `finance`, phần lớn bảng đứng rời nhau vì chúng gắn với tài khoản chứ
không gắn với nhau, mà tài khoản lại nằm ở lược đồ khác nên quan hệ ấy không thể là khoá
ngoại; ví và sổ cái ví liên hệ qua cặp cột tài khoản và loại tiền do tầng dịch vụ giữ đúng.
Các bảng quan
trắc không có trong 5 hình này vì chúng là dữ liệu ghi theo thời gian, được mô tả riêng ở phần
hạ tầng quan trắc.

#fig(
  [Sơ đồ cơ sở dữ liệu, lược đồ `account`],
  spacing: (48mm, 21mm),
  edge-stroke: 0.9pt + blue-s,
  label-wrapper: wlabel,

  nbang((1, 1), <b-account>, "account", [PK id], [UQ phone], [UQ email], [UQ username]),
  nbang((0, 1), <b-identity_document>, "identity_document", [PK id], [FK account_id #sym.arrow.r account · xoá lan], [FK front_resource_id #sym.arrow.r resource · gán rỗng], [FK back_resource_id #sym.arrow.r resource · gán rỗng], [FK selfie_resource_id #sym.arrow.r resource · gán rỗng], [UQ provider, provider_ref]),
  nbang((2, 1), <b-follow>, "follow", [PK follower_id, followee_id], [FK follower_id #sym.arrow.r account · xoá lan], [FK followee_id #sym.arrow.r account · xoá lan]),
  nbang((1, 0), <b-oauth_identity>, "oauth_identity", [PK id], [FK account_id #sym.arrow.r account · xoá lan], [UQ provider, provider_uid], [UQ account_id, provider]),
  nbang((1, 2), <b-device>, "device", [PK id], [FK account_id #sym.arrow.r account · xoá lan], [UQ push_token]),
  nbang((0, 0), <b-contact>, "contact", [PK id], [FK account_id #sym.arrow.r account · xoá lan]),
  nbang((2, 0), <b-notification>, "notification", [PK id, created_at], [FK account_id #sym.arrow.r account · xoá lan]),
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

  nbang((0, 0), <b-category_embedding>, "category_embedding", [PK category_id], [FK category_id #sym.arrow.r category · xoá lan]),
  nbang((2, 0), <b-listing_embedding>, "listing_embedding", [PK listing_id], [FK listing_id #sym.arrow.r listing · xoá lan]),
  nbang((3, 0), <b-account_interest>, "account_interest", [PK account_id, slot]),
  nbang((0, 1), <b-category>, "category", [PK id], [FK parent_id #sym.arrow.r category · gán rỗng], [UQ name]),
  nbang((1, 1), <b-listing>, "listing", [PK id], [FK category_id #sym.arrow.r category · chặn xoá], [UQ slug]),
  nbang((2, 1), <b-variant>, "variant", [PK id], [FK listing_id #sym.arrow.r listing · xoá lan]),
  nbang((3, 1), <b-stock>, "stock", [PK variant_id], [FK variant_id #sym.arrow.r variant · xoá lan]),
  nbang((0, 2), <b-tag>, "tag", [PK id]),
  nbang((1, 2), <b-listing_tag>, "listing_tag", [PK id], [FK listing_id #sym.arrow.r listing · xoá lan], [FK tag #sym.arrow.r tag · xoá lan], [UQ listing_id, tag]),
  nbang((2, 2), <b-favorite>, "favorite", [PK account_id, listing_id], [FK listing_id #sym.arrow.r listing · xoá lan]),
  nbang((3, 2), <b-stock_movement>, "stock_movement", [PK key], [FK variant_id #sym.arrow.r variant · xoá lan]),
  nbang((0, 3), <b-tag_embedding>, "tag_embedding", [PK tag_id], [FK tag_id #sym.arrow.r tag · xoá lan]),

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

  nbang((1, 1), <b-order>, "order", [PK id], [FK transport_id #sym.arrow.r transport · không đổi], [FK draft_id #sym.arrow.r draft_order · không đổi], [FK offer_id #sym.arrow.r offer · không đổi], [UQ transport_id], [UQ draft_id], [UQ offer_id]),
  nbang((0, 1), <b-transport>, "transport", [PK id]),
  nbang((2, 1), <b-draft_order>, "draft_order", [PK id]),
  nbang((1, 0), <b-offer>, "offer", [PK id]),
  nbang((1, 2), <b-item>, "item", [PK id], [FK order_id #sym.arrow.r order · không đổi], [FK draft_id #sym.arrow.r draft_order · không đổi], [FK offer_id #sym.arrow.r offer · không đổi]),
  nbang((0, 0), <b-refund>, "refund", [PK id], [FK order_id #sym.arrow.r order · không đổi], [FK return_transport_id #sym.arrow.r transport · không đổi], [UQ return_transport_id]),
  nbang((2, 0), <b-cart_item>, "cart_item", [PK id], [UQ account_id, variant_id]),

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

  nbang((0, 0), <b-payment_session>, "payment_session", [PK id]),
  nbang((1, 0), <b-transaction>, "transaction", [PK id], [FK session_id #sym.arrow.r payment_session · không đổi], [FK reverses_id #sym.arrow.r transaction · không đổi]),
  nbang((2, 0), <b-wallet>, "wallet", [PK account_id, currency]),
  nbang((0, 1), <b-wallet_transaction>, "wallet_transaction", [PK id], [UQ account_id, currency, seq]),
  nbang((1, 1), <b-bank_account>, "bank_account", [PK id]),
  nbang((2, 1), <b-tax_info>, "tax_info", [PK account_id]),

  edge(<b-transaction>, <b-payment_session>, "n-1"),
)
#fig(
  [Sơ đồ cơ sở dữ liệu, lược đồ `trust`, `chat` và các bảng dùng chung],
  spacing: (48mm, 21mm),
  edge-stroke: 0.9pt + blue-s,
  label-wrapper: wlabel,

  nbang((1, 1), <b-review>, "review", [PK id], [UQ listing_id, author_id, order_id]),
  nbang((0, 1), <b-conversation>, "conversation", [PK id]),
  nbang((2, 1), <b-resource>, "resource", [PK id], [UQ provider, object_key]),
  nbang((1, 0), <b-message>, "message", [PK id, created_at], [FK conversation_id #sym.arrow.r conversation · xoá lan]),
  nbang((1, 2), <b-option>, "option", [PK id], [FK logo_resource_id #sym.arrow.r resource · gán rỗng]),
  nbang((0, 0), <b-review_reply>, "review_reply", [PK id], [FK review_id #sym.arrow.r review · xoá lan]),
  nbang((2, 0), <b-review_vote>, "review_vote", [PK review_id, account_id], [FK review_id #sym.arrow.r review · xoá lan]),
  nbang((0, 2), <b-audit_log>, "audit_log", [PK id], [UQ table_name, record_id, version]),
  nbang((2, 2), <b-feedback>, "feedback", [PK id], [UQ order_id, direction]),
  nbang((1, 3), <b-reputation>, "reputation", [PK account_id, role]),
  nbang((0, 3), <b-order_outcome>, "order_outcome", [PK order_id]),
  nbang((2, 3), <b-ticket>, "ticket", [PK id], [UQ conversation_id]),

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

Thiết kế bảo mật không phải một lớp màng lọc độc lập, mà là chuỗi các quyết định kỹ thuật được nhúng sâu vào toàn bộ mô hình dữ liệu và các tầng kiến trúc. Các nguyên tắc này được phân loại và cưỡng chế qua 3 khía cạnh cốt lõi.

=== Xác thực và phân quyền

- Cơ chế xác thực kép: Ứng dụng kết hợp Access Token tĩnh (JWT sống 15 phút, mang định danh mờ) và Trạng thái phiên động (Session lưu tại bộ nhớ đệm, sống 30 ngày). Mọi yêu cầu API bắt buộc phải tra cứu phiên song song với việc xác thực chữ ký JWT, đảm bảo thao tác thu hồi quyền (đăng xuất, đình chỉ) có hiệu lực tức thời.
- Bảo mật phiên và mã thông báo (Token Rotation): Refresh Token được thiết lập xoay vòng ở mỗi lần cấp đổi.

=== Bảo vệ dữ liệu và kiểm soát đầu vào

Nguyên tắc Tối thiểu hóa dữ liệu (Data Minimization) được tuân thủ xuyên suốt hệ thống. Các trường dữ liệu định danh như số Căn cước không được lưu ở dạng bản rõ; hồ sơ eKYC chỉ giữ kết luận phê duyệt và mã đối chiếu (Reference ID) của nhà cung cấp, qua đó vô hiệu hóa hoàn toàn giá trị của dữ liệu nếu xảy ra lộ lọt. Tương tự, thông tin định danh của nhà cung cấp bên ngoài (API Keys) không nằm dưới dạng bản rõ trong cơ sở dữ liệu mà chỉ được giữ ở dạng đường dẫn tham chiếu, còn tệp tĩnh tải lên được cô lập bảo mật thông qua cơ chế Đường dẫn ký có thời hạn (Presigned URLs). Ở tầng nhật ký, cơ chế lọc được cưỡng chế nhằm bảo đảm mật khẩu, Access Token hoặc nội dung bí mật một lần không bị ghi lại dưới mọi hình thức.

=== Giới hạn tần suất, quản lý bí mật và vòng đời dữ liệu

- *Miễn trừ tiết lưu Webhook (Webhook Exemption):* Các tuyến API nhận lời gọi lại (Callback) từ đối tác ngoài được loại trừ khỏi giới hạn tần suất, bảo mật hoàn toàn bằng cơ chế xác minh chữ ký (Signature Verification).
- *Hạn chế hiện tại ở lớp biên:* Giới hạn lưu lượng theo định tuyến IP và tài khoản (Rate Limiting) tại lớp biên (API Gateway) hiện đóng vai trò quy chuẩn thiết kế, chưa được thực thi bằng mã nguồn.
