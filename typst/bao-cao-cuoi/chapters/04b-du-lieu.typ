#import "../../common/tokens.typ": *

// Tên bảng và tên cột là chuỗi dài, cột bảng thì hẹp: thu nhỏ mã nội dòng cho vừa ô.
#show raw.where(block: false): set text(size: 8.5pt)

== Mô hình dữ liệu mức khái niệm

Mức khái niệm trả lời câu hỏi hệ thống nói về những thứ gì và chúng liên hệ với nhau ra sao,
tách hẳn khỏi câu hỏi lưu trữ thế nào. Vì vậy 3 sơ đồ dưới đây không có khoá ngoại, không có cột,
không có kiểu dữ liệu và cũng không có bảng nối: một quan hệ nhiều-nhiều được vẽ thẳng thành
một đường nối mang tên quan hệ, thay vì tách ra thành một thực thể trung gian như khi hiện thực.
Bản số đọc theo quy ước chân quạ ở cả hai đầu. Toàn bộ tên thực thể viết bằng tiếng Việt theo
đúng cách người dùng nghiệp vụ gọi chúng, chứ không dùng tên bảng.

So với 42 bảng ở mức vật lý, mức khái niệm rút còn 26 thực thể. Phần chênh lệch gồm 3 nhóm.
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

  nent((0, 0), <d-pm>, [PHIẾU MUA TẠM]),
  nent((0, 2), <d-tl>, [THƯƠNG LƯỢNG]),
  nent((1, 1), <d-dh>, [DÒNG HÀNG]),
  nent((2, 1), <d-don>, [ĐƠN HÀNG]),
  nent((3, 0), <d-vd>, [VẬN ĐƠN]),
  nent((3, 2), <d-ht>, [YÊU CẦU HOÀN TIỀN]),

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

  nent((0, 0), <e-nh>, [TÀI KHOẢN NGÂN HÀNG]),
  nent((0, 1), <e-thue>, [HỒ SƠ THUẾ]),
  nent((0, 2), <e-phieu>, [PHIẾU HỖ TRỢ]),
  nent((1, 1), <e-tk>, [TÀI KHOẢN]),
  nent((1, 2.4), <e-nx>, [NHẬN XÉT]),
  nent((2, 0), <e-vi>, [VÍ]),
  nent((2, 1.5), <e-don>, [ĐƠN HÀNG]),
  nent((2, 2.4), <e-tra>, [TRẢ LỜI NHẬN XÉT]),
  nent((3, 0.6), <e-ptt>, [PHIÊN THANH TOÁN]),
  nent((3, 2.1), <e-ctt>, [CHẶNG THANH TOÁN]),

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

=== Sơ đồ quan hệ thực thể mức vật lý

Sơ đồ được tách thành 3 lát cắt theo cụm nghiệp vụ, ký hiệu thống nhất: đường liền nét là khoá ngoại thật nên hai đầu luôn cùng một lược đồ, đường nét đứt là tham chiếu logic chéo lược đồ do tầng dịch vụ giữ đúng. Nhãn bản số đọc theo quy ước chân quạ, dấu hỏi biểu thị đầu tuỳ chọn.

 #fig(
    [Sơ đồ quan hệ thực thể mức vật lý, lát cắt `account` và `catalog`],
    spacing: (24mm, 11mm),
    edge-stroke: 1pt + blue-s,
    label-wrapper: wlabel,

    // ===== lược đồ account =====
    nent((0, 0.6), <p1-oauth>, [OAUTH\_IDENTITY]),
    nent((0, 1.5), <p1-dev>, [DEVICE]),
    nent((0.9, 2.2), <p1-acc>, [ACCOUNT]),
    nent((0, 3.2), <p1-contact>, [CONTACT]),
    nent((0, 4.1), <p1-idoc>, [IDENTITY\_DOCUMENT]),
    nent((1.8, 0.6), <p1-noti>, [NOTIFICATION]),
    nent((1.8, 1.5), <p1-npref>, [NOTIFICATION\_PREFERENCE]),
    nent((1.8, 3.2), <p1-follow>, [FOLLOW]),

    // ===== lược đồ catalog =====
    nent((3.6, 0), <p1-cat>, [CATEGORY]),
    nent((3.6, 1.2), <p1-lst>, [LISTING]),
    nent((3.6, 2.4), <p1-var>, [VARIANT]),
    nent((3.6, 3.5), <p1-stock>, [STOCK]),
    nent((4.9, 0.2), <p1-tag>, [TAG]),
    nent((4.9, 1.0), <p1-ltag>, [LISTING\_TAG]),
    nent((4.9, 1.7), <p1-fav>, [FAVORITE]),
    nent((4.9, 2.5), <p1-emb>, [LISTING\_EMBEDDING]),
    nent((4.9, 4.0), <p1-smv>, [STOCK\_MOVEMENT]),

    // ===== quan hệ trong account =====
    edge(<p1-oauth>, <p1-acc>, "n-1", text(size: 7pt)[liên kết]),
    edge(<p1-dev>, <p1-acc>, "n-1", text(size: 7pt)[thiết bị]),
    edge(<p1-contact>, <p1-acc>, "n-1", text(size: 7pt)[địa chỉ]),
    edge(<p1-idoc>, <p1-acc>, "n-1", text(size: 7pt)[giấy tờ]),
    edge(<p1-noti>, <p1-acc>, "n-1", text(size: 7pt)[thông báo]),
    edge(<p1-npref>, <p1-acc>, "n-1", text(size: 7pt)[tuỳ chọn kênh]),
    edge(<p1-follow>, <p1-acc>, "n-1", text(size: 7pt)[theo dõi hai đầu]),

    // ===== quan hệ trong catalog =====
    edge(<p1-cat>, <p1-cat>, "n-1?", bend: 130deg, text(size: 7pt)[danh mục cha]),
    edge(<p1-lst>, <p1-cat>, "n-1", text(size: 7pt)[thuộc]),
    edge(<p1-var>, <p1-lst>, "n-1", text(size: 7pt)[biến thể]),
    edge(<p1-stock>, <p1-var>, "1-1", text(size: 7pt)[tồn kho]),
    edge(<p1-smv>, <p1-var>, "n-1", text(size: 7pt)[bút toán kho]),
    edge(<p1-ltag>, <p1-lst>, "n-1", text(size: 7pt)[gắn thẻ]),
    edge(<p1-ltag>, <p1-tag>, "n-1", text(size: 7pt)[thẻ]),
    edge(<p1-fav>, <p1-lst>, "n-1", text(size: 7pt)[yêu thích]),
    edge(<p1-emb>, <p1-lst>, "1-1", text(size: 7pt)[vector]),

    // ===== khoá ngoại xuyên lược đồ =====
    // luồn qua khoảng trống giữa NOTIFICATION_PREFERENCE và FOLLOW
    edge(<p1-lst>, (2.95, 2.5), <p1-acc>, "n-1", stroke: (dash: "dashed"),
      text(size: 7pt)[người bán]),
    // đi vòng dưới cả 2 nhóm, không cắt qua nút nào
    edge(<p1-fav>, (5.9, 1.7), (5.9, 4.8), (0.9, 4.8), <p1-acc>, "n-1",
      stroke: (dash: "dashed"), corner-radius: 4pt,
      text(size: 7pt)[người lưu], label-pos: 0.62),

    ngroup((<p1-oauth>, <p1-dev>, <p1-acc>, <p1-contact>, <p1-idoc>, <p1-noti>, <p1-npref>, <p1-follow>)),
    gtitle((0.9, -0.5), [lược đồ `account`]),
    ngroup((<p1-cat>, <p1-lst>, <p1-var>, <p1-stock>, <p1-smv>, <p1-tag>, <p1-ltag>, <p1-fav>, <p1-emb>)),
    gtitle((4.2, -0.5), [lược đồ `catalog`]),
  )

#fig(
  [Sơ đồ quan hệ thực thể mức vật lý, lát cắt `order` và `finance`],
  spacing: (26mm, 12mm),
  edge-stroke: 1pt + blue-s,
  label-wrapper: wlabel,

  // ===== NHÓM ORDER =====
  nent((0.75, -0.5), <p2-cart>, [CART_ITEM]),
  nent((0, 0.5), <p2-draft>, [DRAFT_ORDER]),
  nent((0, 1.5), <p2-offer>, [OFFER]),
  nent((0, 3.5), <p2-refund>, [REFUND]),
  nent((1.5, 1.0), <p2-item>, [ITEM]),
  nent((1.5, 2.5), <p2-order>, [ORDER]),
  nent((1.5, 3.5), <p2-trans>, [TRANSPORT]),

  // ===== NHÓM FINANCE =====
  nent((3.4, 1.0), <p2-sess>, [PAYMENT_SESSION]),
  nent((3.4, 2.0), <p2-tx>, [TRANSACTION]),
  nent((3.4, 3.0), <p2-wtx>, [WALLET_TRANSACTION]),
  nent((4.9, 2.5), <p2-wallet>, [WALLET]),
  nent((4.9, 3.5), <p2-bank>, [BANK_ACCOUNT]),
  nent((4.9, 4.5), <p2-tax>, [TAX_INFO]),

  nent((5.9, 3.5), <p2-acc>, [ACCOUNT \ #text(size: 7pt)[(lược đồ `account`)]]),

  // ===== Trong order =====
  edge(<p2-item>, <p2-draft>, "n-1?", text(size: 7pt)[chốt từ phiên]),
  edge(<p2-item>, <p2-offer>, "1-1?", text(size: 7pt)[chốt từ thương lượng]),
  edge(<p2-item>, <p2-order>, "n-1?", text(size: 7pt)[thuộc đơn]),
  edge(<p2-order>, <p2-draft>, "1-1?", bend: 15deg, crossing: true, text(size: 7pt)[nguồn]),
  edge(<p2-order>, <p2-trans>, "1-1", text(size: 7pt)[vận đơn giao]),
  edge(<p2-refund>, <p2-order>, "n-1", bend: -10deg, text(size: 7pt)[hoàn tiền]),
  edge(<p2-refund>, <p2-trans>, "1-1?", bend: -15deg, text(size: 7pt)[chặng trả hàng]),

  // ===== Trong finance =====
  edge(<p2-tx>, <p2-sess>, "n-1", text(size: 7pt)[bút toán của]),
  edge(<p2-tx>, <p2-tx>, "1-1?", bend: 130deg, text(size: 7pt)[đảo ứng]),
  edge(<p2-wtx>, <p2-wallet>, "n-1", text(size: 7pt)[biến động ví]),

  // ===== order – finance =====
  edge(<p2-item>, <p2-sess>, "n-1", stroke: (dash: "dashed"), text(size: 7pt)[phiên thanh toán]),
  // luồn dưới ITEM rồi chếch vào sườn dưới trái PAYMENT_SESSION
  edge(<p2-offer>, (2.7, 1.5), <p2-sess>, "1-1?", stroke: (dash: "dashed"), crossing: true,
    text(size: 7pt)[phiên thanh toán], label-pos: 0.35),

  // ===== với ACCOUNT =====
  edge(<p2-cart>, (5.9, -0.5), <p2-acc>, "n-1", stroke: (dash: "dashed"),
    corner-radius: 4pt, text(size: 7pt)[chủ giỏ], label-pos: 0.35),
  // vòng dưới khối finance, vào ACCOUNT từ đáy
  edge(<p2-order>, (2.25, 2.5), (2.25, 5.4), (5.9, 5.4), <p2-acc>, "n-1",
    stroke: (dash: "dashed"), corner-radius: 4pt,
    text(size: 7pt)[mua / bán], label-pos: 0.55),
  edge(<p2-wallet>, <p2-acc>, "n-1", stroke: (dash: "dashed"), text(size: 7pt)[chủ ví]),
  edge(<p2-bank>, <p2-acc>, "n-1", stroke: (dash: "dashed"), text(size: 7pt)[chủ tài khoản]),
  edge(<p2-tax>, <p2-acc>, "1-1", stroke: (dash: "dashed"), text(size: 7pt)[thông tin thuế]),

  ngroup((<p2-cart>, <p2-draft>, <p2-offer>, <p2-refund>, <p2-item>, <p2-order>, <p2-trans>)),
  gtitle((0.75, -1.15), [lược đồ `order`]),
  ngroup((<p2-sess>, <p2-tx>, <p2-wtx>, <p2-wallet>, <p2-bank>, <p2-tax>)),
  gtitle((4.15, 0.15), [lược đồ `finance`]),
)

#fig(
  [Sơ đồ quan hệ thực thể mức vật lý, lát cắt `trust`, `chat` và các bảng dùng chung],
  spacing: (26mm, 12mm),
  edge-stroke: 1pt + blue-s,
  label-wrapper: wlabel,

  nent((0, 0), <p3-ticket>, [TICKET]),
  nent((0, 2.5), <p3-rev>, [REVIEW]),
  nent((0, 3.7), <p3-vote>, [REVIEW\_VOTE]),
  nent((1.4, 3.1), <p3-reply>, [REVIEW\_REPLY]),
  nent((1.4, 1.9), <p3-rep>, [REPUTATION]),
  nent((1.4, 0.7), <p3-oo>, [ORDER\_OUTCOME]),

  nent((3.1, 0), <p3-conv>, [CONVERSATION]),
  nent((3.1, 1.2), <p3-msg>, [MESSAGE]),

  nent((4.6, 0.2), <p3-audit>, [AUDIT\_LOG]),
  nent((4.6, 1.4), <p3-res>, [RESOURCE]),
  nent((4.6, 2.5), <p3-opt>, [OPTION]),

  edge(<p3-reply>, <p3-rev>, "n-1", text(size: 7pt)[trả lời]),
  edge(<p3-vote>, <p3-rev>, "n-1", text(size: 7pt)[bình chọn]),
  edge(<p3-msg>, <p3-conv>, "n-1", text(size: 7pt)[tin nhắn]),
  edge(<p3-opt>, <p3-res>, "n-1?", text(size: 7pt)[biểu trưng]),
  edge(<p3-ticket>, <p3-conv>, "1-1?", stroke: (dash: "dashed"), text(size: 7pt)[luồng phiếu]),
  edge(<p3-rev>, <p3-rep>, "n-1", stroke: (dash: "dashed"), text(size: 7pt)[cộng dồn]),
  edge(<p3-oo>, <p3-rep>, "n-1", stroke: (dash: "dashed"), text(size: 7pt)[đếm kết cục]),

  ngroup((<p3-ticket>, <p3-rev>, <p3-vote>, <p3-reply>, <p3-rep>, <p3-oo>)),
  gtitle((0.7, -0.65), [lược đồ `trust`]),
  ngroup((<p3-conv>, <p3-msg>)),
  gtitle((3.1, -0.65), [lược đồ `chat`]),
  ngroup((<p3-audit>, <p3-res>, <p3-opt>)),
  gtitle((4.6, -0.65), [bảng dùng chung]),
)
=== Lược đồ `account`

Một tài khoản vừa là người mua vừa là người bán, nên lược đồ này không phân biệt hai vai ở mức bảng. Quyết định đáng chú ý nhất là hợp nhất bảng hồ sơ vào bảng tài khoản: tên hiển thị là bắt buộc và được ghi bởi cùng câu lệnh với hàng tài khoản, nên tách ra một bảng một-một chỉ mua thêm một phép kết nối và một lần ghi thứ hai. Ngược lại, sổ địa chỉ không được gộp, vì gộp vào sẽ khiến mỗi lần đổi tên hiển thị phải nạp thêm hàng chục cột địa chỉ.


=== Lược đồ `catalog`

Về mô hình hoá, tin đăng không phải một mục trong danh mục sản phẩm dùng chung: hai người bán rao cùng một mẫu điện thoại là hai hàng độc lập, vì tình trạng món hàng, giá và người bán đều là thuộc tính của lời rao. Tồn kho tách thành bảng riêng dù quan hệ với biến thể là một-một, vì số giữ chỗ đổi theo từng lượt thanh toán còn hàng biến thể chỉ đổi khi người bán sửa tin. Hàng đợi tính lại vector ngữ nghĩa là một thuộc tính của chính dữ liệu chứ không phải một hàng đợi thông điệp, nhờ đó một hàng bị sửa trong lúc triển khai vẫn còn nguyên dấu sau đó.


=== Lược đồ `order`

Quyết định trung tâm: người bán không duyệt đơn; chính dòng tiền tạo ra đơn. Người mua mở một phiên mua hàng đóng băng giá người bán đang hỏi, trả tiền hàng cộng cước, và đơn hàng cùng vận đơn ra đời ngay khi phiên thanh toán hoàn tất, đó là lý do cột đơn hàng trên mục hàng cho phép rỗng. Vì có 2 nguồn hình thành đơn, cả bảng đơn lẫn bảng mục hàng đều mang 2 cột cho phép rỗng trỏ về phiếu mua tạm và về cuộc thương lượng, kèm ràng buộc buộc đúng một trong hai có giá trị.


Hồ sơ hoàn tiền còn được thiết kế quanh nguyên tắc người bán không thể từ chối bằng lời của mình: người bán chỉ có hai lựa chọn xử lý là chấp nhận hoặc chuyển hồ sơ cho bộ phận hỗ trợ, nên bảng này không có cột lý do từ chối.

=== Lược đồ `finance`

Lược đồ này giữ toàn bộ nguyên thể tiền tệ trong một chỗ, vì giữ tiền tạm và giải ngân phải nguyên tử nên phiên thanh toán, sổ cái giao dịch, ví, sổ cái ví và tài khoản ngân hàng đều phải ở cùng một ranh giới giao dịch. Điểm cần hiểu đúng nhất là 2 sổ cái với một ranh giới rõ ràng: bảng giao dịch chỉ ghi những chặng tiền đi qua kênh thanh toán bên ngoài, còn tiền chỉ di chuyển bên trong ví thì chỉ ghi vào sổ cái ví. Cả 2 sổ đều chỉ ghi thêm, nên hoàn tiền tạo bút toán mới mang dấu âm trỏ về bút toán bị đảo.


=== Lược đồ `trust`

Thay đổi mô hình hoá lớn nhất: mọi thứ người dùng gửi lên đều là một phiếu, và một bảng duy nhất chứa tất cả, nên không còn bảng tranh chấp riêng và bảng báo cáo vi phạm riêng.



=== Lược đồ `chat`

Một luồng hội thoại là một luồng cho mỗi cặp tài khoản, bất kể ai mua ai bán; ngữ cảnh sản phẩm không nằm ở luồng mà ở từng tin nhắn. Với thương lượng giá, tin nhắn chỉ mang định danh cuộc thương lượng trong siêu dữ liệu chứ tuyệt đối không chép giá vào, vì nếu chép thì một lần sửa đề xuất sẽ để lại trong luồng một mức giá không còn trên bàn đàm phán. Trạng thái đọc không lưu trên từng tin nhắn mà là hai dấu thời gian trên hàng hội thoại, vì bảng tin nhắn phân mảnh theo thời gian nên một cờ đã đọc trên từng tin sẽ biến mọi câu hỏi về tin chưa đọc thành phép đếm không có cận thời gian.


Ở luồng phiếu hỗ trợ, phía bên kia là tài khoản riêng của bộ phận hỗ trợ, nhờ đó điều phối viên trả lời vẫn ẩn danh với người gửi và người tiếp nhận kế tiếp thừa hưởng đúng luồng cũ.

=== Các bảng dùng chung

3 bảng cuối cần hiểu khác với 7 lược đồ trên: `common` không phải một module và không phải một lược đồ, nó không có giao diện dịch vụ và công cụ di trú không tạo ra lược đồ nào tên như vậy; cái nó cung cấp là phần định nghĩa dữ liệu được áp vào lược đồ của từng module nghiệp vụ.


== Thiết kế bảo mật

Thiết kế bảo mật không phải một lớp màng lọc độc lập, mà là chuỗi các quyết định kỹ thuật được nhúng sâu vào toàn bộ mô hình dữ liệu và các tầng kiến trúc. Các nguyên tắc này được phân loại và cưỡng chế qua 3 khía cạnh cốt lõi.

=== Xác thực và phân quyền

- Cơ chế xác thực kép: Ứng dụng kết hợp Access Token tĩnh (JWT sống 15 phút, mang định danh mờ) và Trạng thái phiên động (Session lưu tại bộ nhớ đệm, sống 30 ngày). Mọi yêu cầu API bắt buộc phải tra cứu phiên song song với việc xác thực chữ ký JWT, đảm bảo thao tác thu hồi quyền (đăng xuất, đình chỉ) có hiệu lực tức thời.
- Bảo mật phiên và mã thông báo (Token Rotation): Refresh Token được thiết lập xoay vòng ở mỗi lần cấp đổi.
- Chiến lược mật khẩu: Ưu tiên độ dài thay vì độ phức tạp (tối thiểu 8, tối đa 72 ký tự do giới hạn của bcrypt). Cột mật khẩu cho phép Null để hỗ trợ luồng đăng nhập một lần (SSO). Trạng thái không mật khẩu được cố ý áp dụng cho tài khoản Điều phối viên, ngăn chặn rò rỉ qua các kênh thông thường.

=== Bảo vệ dữ liệu và kiểm soát đầu vào

Nguyên tắc Tối thiểu hóa dữ liệu (Data Minimization) được tuân thủ xuyên suốt hệ thống. Các trường dữ liệu định danh như số Căn cước không được lưu ở dạng bản rõ; hồ sơ eKYC chỉ giữ kết luận phê duyệt và mã đối chiếu (Reference ID) của nhà cung cấp, qua đó vô hiệu hóa hoàn toàn giá trị của dữ liệu nếu xảy ra lộ lọt. Tương tự, thông tin định danh của nhà cung cấp bên ngoài (API Keys) không nằm dưới dạng bản rõ trong cơ sở dữ liệu mà chỉ được giữ ở dạng đường dẫn tham chiếu, còn tệp tĩnh tải lên được cô lập bảo mật thông qua cơ chế Đường dẫn ký có thời hạn (Presigned URLs). Ở tầng nhật ký, cơ chế lọc được cưỡng chế nhằm bảo đảm mật khẩu, Access Token hoặc nội dung bí mật một lần không bị ghi lại dưới mọi hình thức.

=== Giới hạn tần suất, quản lý bí mật và vòng đời dữ liệu

- *Miễn trừ tiết lưu Webhook (Webhook Exemption):* Các tuyến API nhận lời gọi lại (Callback) từ đối tác ngoài được loại trừ khỏi giới hạn tần suất, bảo mật hoàn toàn bằng cơ chế xác minh chữ ký (Signature Verification).
- *Hạn chế hiện tại ở lớp biên:* Giới hạn lưu lượng theo định tuyến IP và tài khoản (Rate Limiting) tại lớp biên (API Gateway) hiện đóng vai trò quy chuẩn thiết kế, chưa được thực thi bằng mã nguồn.
