#import "../../common/tokens.typ": *

// Tên bảng và tên cột là chuỗi dài, cột bảng thì hẹp: thu nhỏ mã nội dòng cho vừa ô.
#show raw.where(block: false): set text(size: 8.5pt)

== Thiết kế cơ sở dữ liệu vật lý

Mô hình dữ liệu được hiện thực trên PostgreSQL chạy trên bản phân phối TimescaleDB, bộ ký tự UTF-8. Ngoài phần lõi quan hệ, thiết kế dựa vào 6 phần mở rộng, mỗi phần phục vụ một nhóm truy vấn mà nếu thiếu nó thì phải giải quyết bằng một hệ lưu trữ thứ hai: TimescaleDB cho bảng ghi theo thời gian, PostGIS cho toạ độ địa lý, pgvector cho vector ngữ nghĩa, `pg_trgm` cùng `unaccent` cho tìm kiếm gần đúng không dấu, và bộ công cụ thống kê của TimescaleDB cho phép tính phân vị. Cả sáu đều được cài vào lược đồ `public` chứ không vào lược đồ của mô-đun, vì một phần mở rộng chỉ thuộc về đúng một lược đồ trong mỗi cơ sở dữ liệu; đổi lại, mỗi mô-đun vẫn tự khai báo phần mở rộng mà nó cần, để khi tách sang cơ sở dữ liệu riêng nó mang theo đủ điều kiện tiên quyết của mình. Dữ liệu nghiệp vụ tổ chức thành 7 lược đồ (schema), mỗi lược đồ mang đúng tên mô-đun sở hữu nó; đây không phải ranh giới triển khai — hệ thống chạy như một tiến trình duy nhất — mà là ranh giới quyền ghi và ranh giới di chuyển.

#figure(
  kind: table,
  caption: [7 lược đồ vật lý và phạm vi dữ liệu của từng lược đồ],
  table(
    columns: (0.85fr, 3.5fr),
    align: (left + horizon, left + horizon),
    table.header([Lược đồ], [Phạm vi dữ liệu]),
    [`account`], [Định danh, đăng nhập liên kết, hồ sơ hiển thị, sổ địa chỉ, thiết bị nhận đẩy, thông báo và tuỳ chọn kênh, đồ thị theo dõi, giấy tờ định danh.],
    [`catalog`], [Danh mục, bài đăng, biến thể, thẻ, tồn kho và bút toán tồn kho, danh sách yêu thích, véc-tơ ngữ nghĩa của bài đăng, danh mục và thẻ.],
    [`order`], [Giỏ hàng, phiên mua hàng giá cố định, thương lượng giá, đơn hàng, mục hàng, vận đơn và hồ sơ hoàn tiền.],
    [`finance`], [Phiên thanh toán, sổ cái giao dịch trên kênh thanh toán ngoài, ví theo tài khoản và loại tiền, sổ cái ví, tài khoản ngân hàng nhận tiền, thông tin thuế.],
    [`trust`], [Phản hồi giao dịch hai chiều, đánh giá sản phẩm cùng trả lời và bình chọn hữu ích, điểm uy tín, phiếu hỗ trợ và idempotency key cho kết cục đơn hàng.],
    [`chat`], [Luồng hội thoại một-một giữa hai tài khoản và tin nhắn trong luồng.],
    [`observability`], [4 bảng tín hiệu vận hành. Không nhận phần định nghĩa dùng chung.],
  ),
)

=== Nguyên tắc thiết kế dữ liệu

*Cô lập theo lược đồ.* Mỗi mô-đun sở hữu một lược đồ mang đúng tên nó và là thành phần duy nhất được phép ghi vào đó; không truy vấn nào nối bảng của 2 lược đồ khác nhau. Nguồn kết nối đặt đường tìm kiếm về lược đồ của mình cộng `public`, nên toàn bộ SQL viết không kèm tên lược đồ và một mô-đun có thể chuyển sang cơ sở dữ liệu khác mà không sửa một dòng SQL; hệ quả là mọi ràng buộc toàn vẹn tham chiếu chỉ tồn tại bên trong một lược đồ.

*Khoá thay thế là số nguyên 64 bit.* Mọi khoá thay thế đều là `BIGINT` sinh tự động, không có `UUID` ở bất kỳ đâu: khoá tuần tự cho chỉ mục dày đặc hơn và hàng nhỏ hơn, còn lý do thường viện dẫn cho `UUID` — không để lộ số lượng bản ghi — đã được giải quyết bằng định danh mờ. Đúng hai ngoại lệ, cả hai trong `finance`: phiên thanh toán và giao dịch cho phép ứng dụng chỉ định định danh, vì định danh phải được trao cho cổng thanh toán trước khi chèn hàng.

*Tham chiếu chéo lược đồ không dùng khoá ngoại.* Khoá ngoại chỉ khai báo khi cả 2 bảng cùng lược đồ; trỏ sang lược đồ khác thì cột tham chiếu là `BIGINT` trần, vì một khoá ngoại xuyên lược đồ là thứ duy nhất không thể đi theo mô-đun khi mô-đun đó tách ra. Toàn vẹn ở đó được giữ bằng 3 cơ chế: xoá mềm ở bảng bị trỏ tới, để một mục hàng cũ vẫn phân giải được tên bài đăng sau khi người bán gỡ tin; sao chép có chủ đích những giá trị phía kia có thể đổi; và idempotency key cho thao tác đi qua hàng đợi sự kiện vốn chỉ bảo đảm giao ít nhất một lần.

*3 bảng dùng chung, 18 hiện thân.* Nhật ký kiểm toán, bảng tài nguyên tệp và bảng tuỳ chọn được định nghĩa đúng một lần rồi áp vào 6 lược đồ nghiệp vụ, vì một bảng nhật ký kiểm toán toàn cục sẽ không thể đi theo một mô-đun khi mô-đun ấy tách sang cơ sở dữ liệu riêng; trước khi hợp nhất, 7 mô-đun đều tự chép một bản và bốn trong số đó đã trôi khác nhau.

=== Sơ đồ quan hệ thực thể mức vật lý

Sơ đồ được tách thành ba lát cắt theo cụm nghiệp vụ, ký hiệu thống nhất: đường liền nét là khoá ngoại thật nên hai đầu luôn cùng một lược đồ, đường nét đứt là tham chiếu logic chéo lược đồ do tầng dịch vụ giữ đúng. Nhãn bản số đọc theo quy ước chân quạ, dấu hỏi biểu thị đầu tuỳ chọn.

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
    edge(<p1-emb>, <p1-lst>, "1-1", text(size: 7pt)[véc-tơ]),

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
  nent((0, 1.3), <p3-fb>, [FEEDBACK]),
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
  edge(<p3-fb>, <p3-rep>, "n-1", stroke: (dash: "dashed"), text(size: 7pt)[cộng dồn]),
  edge(<p3-rev>, <p3-rep>, "n-1", stroke: (dash: "dashed"), text(size: 7pt)[cộng dồn]),
  edge(<p3-oo>, <p3-rep>, "n-1", stroke: (dash: "dashed"), text(size: 7pt)[đếm kết cục]),

  ngroup((<p3-ticket>, <p3-fb>, <p3-rev>, <p3-vote>, <p3-reply>, <p3-rep>, <p3-oo>)),
  gtitle((0.7, -0.65), [lược đồ `trust`]),
  ngroup((<p3-conv>, <p3-msg>)),
  gtitle((3.1, -0.65), [lược đồ `chat`]),
  ngroup((<p3-audit>, <p3-res>, <p3-opt>)),
  gtitle((4.6, -0.65), [bảng dùng chung]),
)
=== Lược đồ `account`

Một tài khoản vừa là người mua vừa là người bán, nên lược đồ này không phân biệt hai vai ở mức bảng. Quyết định đáng chú ý nhất là hợp nhất bảng hồ sơ vào bảng tài khoản: tên hiển thị là bắt buộc và được ghi bởi cùng câu lệnh với hàng tài khoản, nên tách ra một bảng một-một chỉ mua thêm một phép kết nối và một lần ghi thứ hai. Ngược lại, sổ địa chỉ không được gộp, vì gộp vào sẽ khiến mỗi lần đổi tên hiển thị phải nạp thêm hàng chục cột địa chỉ.


=== Lược đồ `catalog`

Về mô hình hoá, bài đăng không phải một mục trong danh mục sản phẩm dùng chung: hai người bán rao cùng một mẫu điện thoại là hai hàng độc lập, vì tình trạng món hàng, giá và người bán đều là thuộc tính của lời rao. Tồn kho tách thành bảng riêng dù quan hệ với biến thể là một-một, vì số giữ chỗ đổi theo từng lượt thanh toán còn hàng biến thể chỉ đổi khi người bán sửa tin. Hàng đợi tính lại véc-tơ ngữ nghĩa là một thuộc tính của chính dữ liệu chứ không phải một hàng đợi thông điệp, nhờ đó một hàng bị sửa trong lúc triển khai vẫn còn nguyên dấu sau đó.


=== Lược đồ `order`

Quyết định trung tâm: người bán không duyệt đơn; chính dòng tiền tạo ra đơn. Người mua mở một phiên mua hàng đóng băng giá người bán đang hỏi, trả tiền hàng cộng cước, và đơn hàng cùng vận đơn ra đời ngay khi phiên thanh toán hoàn tất — đó là lý do cột đơn hàng trên mục hàng cho phép rỗng. Vì có 2 nguồn hình thành đơn, cả bảng đơn lẫn bảng mục hàng đều mang 2 cột cho phép rỗng trỏ về phiếu mua tạm và về cuộc thương lượng, kèm ràng buộc buộc đúng một trong hai có giá trị.


Hồ sơ hoàn tiền còn được thiết kế quanh nguyên tắc người bán không thể từ chối bằng lời của mình: người bán chỉ có hai lựa chọn xử lý là chấp nhận hoặc chuyển hồ sơ cho bộ phận hỗ trợ, nên bảng này không có cột lý do từ chối.

=== Lược đồ `finance`

Lược đồ này giữ toàn bộ nguyên thể tiền tệ trong một chỗ, vì giữ tiền tạm và giải ngân phải nguyên tử nên phiên thanh toán, sổ cái giao dịch, ví, sổ cái ví và tài khoản ngân hàng đều phải ở cùng một ranh giới giao dịch. Điểm cần hiểu đúng nhất là 2 sổ cái với một ranh giới rõ ràng: bảng giao dịch chỉ ghi những chặng tiền đi qua kênh thanh toán bên ngoài, còn tiền chỉ di chuyển bên trong ví thì chỉ ghi vào sổ cái ví. Cả 2 sổ đều chỉ ghi thêm, nên hoàn tiền tạo bút toán mới mang dấu âm trỏ về bút toán bị đảo.


=== Lược đồ `trust`

Phản hồi giao dịch ở đây là mù: một hàng phản hồi không hiển thị cho tới khi cả hai bên cùng gửi hoặc cửa sổ mù trôi qua, để một điểm số không thể là đòn trả đũa; chiều của phản hồi suy ra từ việc người gửi đứng ở phía nào của đơn hàng. Chính hành động công bố mới là hành động cộng điểm vào bảng uy tín, và cả hai diễn ra trong cùng một giao dịch, nên một điểm đã hiển thị luôn là một điểm đã được tính. Thay đổi mô hình hoá lớn nhất: mọi thứ người dùng gửi lên đều là một phiếu, và một bảng duy nhất chứa tất cả, nên không còn bảng tranh chấp riêng và bảng báo cáo vi phạm riêng.



=== Lược đồ `chat`

Một luồng hội thoại là một luồng cho mỗi cặp tài khoản, bất kể ai mua ai bán; ngữ cảnh sản phẩm không nằm ở luồng mà ở từng tin nhắn. Với thương lượng giá, tin nhắn chỉ mang định danh cuộc thương lượng trong siêu dữ liệu chứ tuyệt đối không chép giá vào, vì nếu chép thì một lần sửa đề xuất sẽ để lại trong luồng một mức giá không còn trên bàn đàm phán. Trạng thái đọc không lưu trên từng tin nhắn mà là hai dấu thời gian trên hàng hội thoại, vì bảng tin nhắn phân mảnh theo thời gian nên một cờ đã đọc trên từng tin sẽ biến mọi câu hỏi về tin chưa đọc thành phép đếm không có cận thời gian.


Ở luồng phiếu hỗ trợ, phía bên kia là tài khoản riêng của bộ phận hỗ trợ, nhờ đó kiểm duyệt viên trả lời vẫn ẩn danh với người gửi và người tiếp nhận kế tiếp thừa hưởng đúng luồng cũ.

=== Các bảng dùng chung

3 bảng cuối cần hiểu khác với 7 lược đồ trên: `common` không phải một mô-đun và không phải một lược đồ, nó không có giao diện dịch vụ và công cụ di trú không tạo ra lược đồ nào tên như vậy; cái nó cung cấp là phần định nghĩa dữ liệu được áp vào lược đồ của từng mô-đun nghiệp vụ.


== Thiết kế bảo mật

Thiết kế bảo mật không phải một lớp màng lọc độc lập, mà là chuỗi các quyết định kỹ thuật được nhúng sâu vào toàn bộ mô hình dữ liệu và các tầng kiến trúc. Các nguyên tắc này được phân loại và cưỡng chế qua 3 khía cạnh cốt lõi.

=== Xác thực và phân quyền

- *Cơ chế xác thực kép:* Ứng dụng kết hợp Access Token tĩnh (JWT sống 15 phút, mang định danh mờ) và Trạng thái phiên động (Session lưu tại bộ nhớ đệm, sống 30 ngày). Mọi yêu cầu API bắt buộc phải tra cứu phiên song song với việc xác thực chữ ký JWT, đảm bảo thao tác thu hồi quyền (đăng xuất, đình chỉ) có hiệu lực tức thời.
- *Bảo mật phiên và mã thông báo (Token Rotation):* Refresh Token được thiết lập xoay vòng ở mỗi lần cấp đổi.
- *Chiến lược mật khẩu:* Ưu tiên độ dài thay vì độ phức tạp (tối thiểu 8, tối đa 72 ký tự do giới hạn của bcrypt). Cột mật khẩu cho phép Null để hỗ trợ luồng đăng nhập một lần (SSO). Trạng thái không mật khẩu được cố ý áp dụng cho tài khoản Điều phối viên, ngăn chặn rò rỉ qua các kênh thông thường.

=== Bảo vệ dữ liệu và kiểm soát đầu vào

Tuân thủ nguyên tắc Tối thiểu hóa dữ liệu (Data Minimization):
- *Ngăn ngừa rò rỉ dữ liệu nhạy cảm:* Hệ thống không lưu trữ bản rõ các trường dữ liệu định danh như số Căn cước. Hồ sơ eKYC chỉ giữ kết luận phê duyệt và mã đối chiếu (Reference ID) của nhà cung cấp, vô hiệu hóa hoàn toàn giá trị của dữ liệu nếu xảy ra lộ lọt.
- *Bảo mật tài sản số (Digital Assets):* Thông tin định danh của nhà cung cấp bên ngoài (API Keys) không lưu bản rõ trong CSDL mà chỉ giữ đường dẫn tham chiếu. Tệp tĩnh tải lên được cô lập bảo mật thông qua cơ chế Đường dẫn ký có thời hạn (Presigned URLs).
- *Che giấu nhật ký (Log Masking):* Cưỡng chế cơ chế lọc nhật ký hệ thống, đảm bảo không ghi lại mật khẩu, Access Token hoặc nội dung bí mật một lần dưới mọi hình thức.

=== Giới hạn tần suất, quản lý bí mật và vòng đời dữ liệu

- *Miễn trừ tiết lưu Webhook (Webhook Exemption):* Các tuyến API nhận lời gọi lại (Callback) từ đối tác ngoài được loại trừ khỏi giới hạn tần suất, bảo mật hoàn toàn bằng cơ chế xác minh chữ ký (Signature Verification).
- *Hạn chế hiện tại ở lớp biên:* Giới hạn lưu lượng theo định tuyến IP và tài khoản (Rate Limiting) tại lớp biên (API Gateway) hiện đóng vai trò quy chuẩn thiết kế, chưa được thực thi bằng mã nguồn.
