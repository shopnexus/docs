// ============================================================
//  SLIDE THUYẾT TRÌNH — BẢO VỆ BÁO CÁO THỰC TẬP TỐT NGHIỆP
//  Biên dịch: make slide
//
//  QUY ƯỚC NỘI DUNG
//  1. Ở MỨC KHÁI NIỆM: không nêu tên sản phẩm hay thương hiệu công nghệ (nền
//     tảng thực thi bền, trục sự kiện, cổng thanh toán... đều gọi tên chung).
//     Danh sách công nghệ cụ thể nằm trong quyển, mục 2.5.
//  2. KHÔNG KHOE SỐ LƯỢNG: không đếm "bao nhiêu ca sử dụng, bao nhiêu bảng, bao
//     nhiêu ca kiểm thử". Slide nói hệ thống *giải quyết vấn đề gì và bằng
//     cách nào*; khối lượng công việc để hội đồng đọc trong quyển. Con số duy
//     nhất được phép xuất hiện là con số thuộc về chính thiết kế — thời hạn
//     khiếu nại 72 giờ, hiệu lực đề xuất giá 12 giờ, thẻ truy cập 15 phút.
//  3. ÍT CHỮ, NÔNG: hội đồng nghe qua loa chứ không đọc slide, nên slide chỉ là
//     chỗ dựa cho lời nói. Mỗi thẻ một câu, mỗi gạch đầu dòng một dòng, không
//     câu ghép, không mệnh đề phụ. Phần lập luận và chi tiết nói bằng miệng —
//     chỗ nào cần chiều sâu thì để trong quyển, đừng bê lên slide.
//
//  Thời lượng thiết kế: khoảng 15 phút.
// ============================================================
#import "../common/style-slide.typ": *

// Không dùng hiện dần từng bước (`#pause` / `#uncover`). PDF không có animation
// nên mỗi bước sẽ thành một trang riêng, và trang đầu — trang chưa có sơ đồ —
// bị đọc thành lỗi mất ảnh khi ai đó lật nhanh, in ra hay nhận lại file.
// Một slide đúng một trang.
#show: slide-ptit.with()

#bia-slide()

// == Nội dung trình bày

// #cot(ti: (1fr, 1fr))[
//   #the([1 · Đặt vấn đề])[
//     Bài toán niềm tin trong giao dịch C2C.
//   ]
//   #v(9pt)
//   #the([2 · Phân tích và thiết kế])[
//     Cơ sở lý thuyết, tác nhân, luồng nghiệp vụ, kiến trúc.
//   ]
// ][
//   #v(9pt)
//   #the([4 · Kết luận])[
//     Kết quả, hạn chế, hướng phát triển.
//   ]
// ]

= Đặt vấn đề

== Bối cảnh: bài toán niềm tin trong thương mại điện tử C2C

Các nền tảng rao vặt trong nước chủ yếu kết nối thông tin; phần giao dịch để hai bên tự thoả thuận.

#v(0.5cm)
#cot[
  #the([Người mua])[
    Trả tiền trước mà không có gì bảo đảm sẽ nhận đúng hàng.
  ]
][
  #the([Người bán])[
    Gửi hàng trước, chịu rủi ro khách từ chối nhận.
  ]
][
  #the([Quy trình phân mảnh])[
    Thương lượng ở kênh ngoài, tranh chấp không còn căn cứ.
  ]
]

== Mục tiêu và giải pháp đề xuất
#text(size: 0.82em)[
  Nền tảng đứng giữa hai bên, giữ trọn vòng giao dịch từ lúc đăng bán đến
  lúc quyết toán hoặc phân xử.
]

#v(1.4cm)

#cot(ti: (1fr, 1fr, 1fr))[
  #the([Ký quỹ])[
    Nền tảng giữ tiền, chỉ giải ngân khi giao dịch xong.
  ]
][
  #the([Thương lượng])[
    Chốt giá trong hệ thống, giá gắn thẳng vào thanh toán.
  ]
][
  #the([Hoàn tiền, tranh chấp])[
    Có bằng chứng, không tự thoả thuận được thì điều phối viên phân xử.
  ]
]
= Phân tích và thiết kế

== Tác nhân của hệ thống

// Ba vai trò xếp theo chiều quyền tăng dần từ trái sang phải, mỗi vai đúng ba
// việc. Hai cạnh giữa hai thẻ đầu chạy song song nhờ `shift` chứ không bẻ cong:
// khoảng cách giữa hai thẻ rộng nên cung cong sẽ phình chiếm gần hết chiều cao
// slide. Khe hở phải chứa được nhãn cạnh nằm giữa khe nên để rộng hơn nhãn kha khá.
#sodo(
  co: 1em,
  spacing: (24mm, 20mm),
  the-vai(
    (0, 0),
    <nd>,
    [Người dùng],
    [người mua & người bán],
    [Tìm kiếm và mua hàng],
    [Đăng bán và giao hàng],
    [Khiếu nại khi có sự cố],
  ),
  the-vai(
    (1, 0),
    <dp>,
    [Điều phối viên],
    [người của sàn],
    [Kiểm duyệt tin đăng],
    [Phân xử tranh chấp],
    [Hỗ trợ người dùng],
  ),
  the-vai(
    (2, 0),
    <qt>,
    [Quản trị viên],
    [quyền cao nhất],
    [Quản lý điều phối viên],
    [Cấu hình toàn sàn],
    [Đối soát dòng tiền],
  ),
  edge(<nd>, <dp>, "-|>", shift: 9pt, label: nhan[khiếu nại], label-side: left),
  edge(<dp>, <nd>, "-|>", shift: 9pt, label: nhan[phán quyết], label-side: left),
  edge(<qt>, <dp>, "-|>", label: nhan[cấp \ tài khoản], label-side: left),
)


// == Ca sử dụng và yêu cầu dẫn dắt kiến trúc

// #cot(ti: (1fr, 1fr))[
//   #the([Ca sử dụng trọng yếu])[
//     Đăng bán và kiểm duyệt tin · tìm kiếm lai · thương lượng qua thẻ đề xuất giá
//     · đặt hàng và ký quỹ · xác nhận nhận hàng · hoàn tiền và phân xử · rút tiền.
//   ]
//   #v(7pt)
//   #the([Truy vết])[
//     Yêu cầu chức năng, yêu cầu phi chức năng và quy tắc nghiệp vụ đều đánh mã và
//     *truy vết được hai chiều*: từ ca sử dụng tới yêu cầu, tới thành phần hiện
//     thực, rồi tới ca kiểm thử.
//   ]
// ][
//   #text(size: 0.76em)[*Yêu cầu có ý nghĩa kiến trúc*]
//   #v(3pt)
//   #text(size: 0.72em)[
//     - Giữ tiền ký quỹ và giải ngân theo phán quyết → cô lập toàn bộ nghiệp vụ
//       tiền tệ vào một dịch vụ, tước quyền ghi sổ cái của mọi dịch vụ khác.
//     - Chuyển trạng thái theo thời hạn dài ngày → buộc phải có cơ chế thực thi bền.
//     - Nhiều nhà cung cấp cùng loại → định tuyến bằng sổ đăng ký lúc chạy, không
//       cấu hình tĩnh.
//     - Bằng chứng đa phương tiện → tách hẳn đường tải tệp khỏi luồng nghiệp vụ.
//     - Một cửa tiếp nhận mọi khiếu nại → gộp về một vòng đời phiếu duy nhất.
//   ]
// ]

== Luồng ký quỹ: chính dòng tiền sinh ra đơn hàng

// Bố cục rắn bò: hàng dưới chạy ngược chiều hàng trên, nhờ đó mối nối giữa hai
// hàng chỉ là một cạnh thẳng đứng ở mép phải, không phải một cạnh vòng qua cả
// bề ngang slide.
#sodo(
  co: 0.9em,
  spacing: (20mm, 15mm),
  o((0, 0), [Người mua \ chốt đơn nháp], name: <a>),
  o((1, 0), [Mở phiên \ thanh toán], name: <b>),
  o((2, 0), [Cổng thanh toán \ báo về], name: <c>),
  on((3, 0), [Giữ ký quỹ], name: <d>),
  on((4, 0), [Đơn hàng \ ra đời], name: <e>),
  o((4, 1), [Người bán xác nhận \ và gửi hàng], name: <f>),
  o((3, 1), [Giao thành công], name: <g>),
  oq((2, 1), [Trong 72 giờ \ có khiếu nại?], name: <h>),
  on((1, 1), [Giải ngân \ cho người bán], name: <i>),
  o((2, 2), [Phân xử \ hoàn tiền], name: <j>),
  edge(<a>, <b>, "-|>"),
  edge(<b>, <c>, "-|>"),
  edge(<c>, <d>, "-|>"),
  edge(<d>, <e>, "-|>"),
  edge(<e>, <f>, "-|>"),
  edge(<f>, <g>, "-|>"),
  edge(<g>, <h>, "-|>"),
  edge(<h>, <i>, "-|>", label: nhan[không], label-side: left),
  edge(<h>, <j>, "-|>", label: nhan[có], label-side: right),
  edge(<j>, <i>, "-|>", bend: 0deg, label: nhan[phán quyết], label-side: left),
)

#v(0.3cm)
#ghi[Đơn hàng chỉ tồn tại khi tiền đã nằm trong ký quỹ.]

== Vòng đời đơn hàng

#sodo(
  co: 0.9em,
  spacing: (23mm, 15mm),
  o((0, 0), [Chờ người bán \ xác nhận], name: <a>),
  o((1, 0), [Đã xác nhận], name: <b>),
  o((2, 0), [Đang vận chuyển], name: <c>),
  on((3, 0), [Đã giao], name: <d>),
  on((4, 0), [Đã quyết toán], name: <e>),
  o((3, 1), [Hồ sơ hoàn tiền], name: <f>),
  o((4, 1), [Đã phân xử], name: <g>),
  edge(<a>, <b>, "-|>", label: nhan[người bán], label-side: left),
  edge(<b>, <c>, "-|>", label: nhan[tạo vận đơn], label-side: left),
  edge(<c>, <d>, "-|>", label: nhan[hãng báo về], label-side: left),
  edge(<d>, <e>, "-|>", label: nhan[hết 72 giờ], label-side: left),
  edge(<d>, <f>, "-|>", label: nhan[khiếu nại], label-side: right),
  edge(<f>, <g>, "-|>", label: nhan[điều phối viên], label-side: right),
  edge(<g>, <e>, "-|>", label: nhan[theo phán quyết], label-side: right),
)




== Cơ sở dữ liệu
#figure(
  assets("./database-order.png", width: 100%),
)


== Giao dịch phân tán và cơ chế bù trừ

#cot(ti: (1fr, 1fr))[
  #text(size: 0.8em)[
    Luồng nghiệp vụ có thể đi qua nhiều dịch vụ và kéo dài trong thời gian dài,
    nên không thể xử lý toàn bộ bằng một transaction duy nhất.

    #v(4pt)

    *Saga* chia quy trình thành nhiều giao dịch nhỏ. Nếu một bước thất bại,
    các bước đã thực hiện trước đó sẽ được xử lý bằng thao tác bù trừ.

    #v(4pt)

    *Hạn chế*
    - không phải thao tác nào cũng có thể hoàn tác được.
    - phải xử lý thêm nhiều trường hợp lỗi và bù trừ.
  ]
][
  #sodo(
    co: 0.92em,
    spacing: (23mm, 15mm),
    o((0, 0), [Bước 1], name: <s1>),
    o((1, 0), [Bước 2], name: <s2>),
    o((2, 0), [Bước 3 \ thất bại], name: <s3>, stroke: 1.2pt + do-ptit),
    edge(<s1>, <s2>, "-|>"),
    edge(<s2>, <s3>, "-|>"),
    edge(
      <s3>,
      <s2>,
      "-|>",
      bend: 40deg,
      stroke: (paint: do-ptit, thickness: 1pt, dash: "dashed"),
      label: nhan(text(fill: do-ptit)[bù trừ 2]),
      label-side: right,
    ),
    edge(
      <s2>,
      <s1>,
      "-|>",
      bend: 40deg,
      stroke: (paint: do-ptit, thickness: 1pt, dash: "dashed"),
      label: nhan(text(fill: do-ptit)[bù trừ 1]),
      label-side: right,
    ),
  )

  #v(8pt)

  #std.align(center, ghi[
    Khi một bước thất bại, Saga thực hiện các thao tác bù trừ
    cho những bước đã hoàn thành trước đó.
  ])
]

== Durable execution

#cot(ti: (1fr, 1fr))[
  #text(size: 0.8em)[
    Mỗi thao tác ra ngoài của hàm nghiệp vụ đều được ghi lại vào nhật ký thực thi.

    #v(4pt)
    Khi tiến trình gặp sự cố, hàm được phát lại. Những bước đã hoàn thành sẽ lấy
    kết quả từ nhật ký ghi trước thay vì thực hiện lại.

    #v(4pt)
    - Lỗi hạ tầng: khôi phục và tiếp tục xử lý.
    - Bù trừ chỉ dùng khi xảy ra lỗi nghiệp vụ.
    - Điều kiện: các thao tác phải đảm bảo tính lũy đẳng.
  ]
][
  #sodo(
    co: 0.92em,
    spacing: (18mm, 15mm),
    o((0, 0), [Bước 1], name: <t1>),
    o((1, 0), [Bước 2], name: <t2>),
    o((2, 0), [Bước 3 \ crash], name: <t3>, stroke: 1.2pt + do-ptit),
    o((1, 1), [Write-Ahead Log (WAL)], name: <j>, width: 44mm),
    on((2, 2), [Bước 3 \ Continue], name: <t4>),
    edge(<t1>, <t2>, "-|>"),
    edge(<t2>, <t3>, "-|>"),
    edge(<t1>, <j>, "-|>"),
    edge(<t2>, <j>, "-|>"),
    edge(<t3>, <t4>, "-|>", label: nhan[Replay], label-side: right),
    edge(<j>, <t4>, "-|>", label: nhan[Return recorded result], label-side: left),
  )
  #v(8pt)
]

// == Thiết kế dữ liệu, giao diện lập trình và bảo mật

// #cot(ti: (1fr, 1fr))[
//   #bang(
//     (auto, 1fr),
//     [Lược đồ], [Phạm vi dữ liệu],
//     [Tài khoản], [Định danh, hồ sơ, địa chỉ, thông báo],
//     [Danh mục], [Tin đăng, biến thể, tồn kho, vector ngữ nghĩa],
//     [Đơn hàng], [Giỏ hàng, thương lượng, đơn, vận đơn, hoàn tiền],
//     [Tài chính], [Phiên thanh toán, ví, sổ cái, tài khoản nhận tiền],
//     [Tín nhiệm], [Đánh giá, điểm uy tín, phiếu hỗ trợ],
//     [Hội thoại], [Luồng hội thoại và tin nhắn],
//     [Quan trắc], [Tín hiệu vận hành],
//   )
// ][
//   #text(size: 0.74em)[
//     Mỗi module sở hữu một lược đồ mang đúng tên nó và là thành phần duy nhất được
//     phép ghi vào đó. *Không một khoá ngoại nào bắc qua ranh giới hai lược đồ* —
//     đó là thứ duy nhất không đi theo được khi tách module ra chạy riêng.

//     - *Bản đặc tả API là hợp đồng duy nhất*: mã máy khách của cả hai ứng dụng đều
//       sinh từ nó, và tiến trình tích hợp so lại đặc tả trên mỗi lần đẩy mã.
//     - Thẻ truy cập sống *15 phút* nhưng phiên mới là nguồn sự thật, tra lại ở mọi
//       yêu cầu — khoá tài khoản có hiệu lực ngay.
//     - Kiểm vai trò nằm ở *tầng dịch vụ*, không ở cổng vào; định danh trên đường
//       truyền ở dạng mờ.
//   ]
// ]




// == Bản đồ ngữ cảnh giới hạn

// // Ranh giới đặt ở chỗ một khái niệm đổi nghĩa: tin đăng ở Hàng hoá là bản ghi sửa
// // được, còn trong Đặt hàng chỉ là bản chụp bất biến lúc chốt mua. Bản đầy đủ kèm
// // hợp đồng liên ngữ cảnh nằm trong quyển, mục 4.2.
// #sodo(
//   co: 0.95em,
//   spacing: (54mm, 19mm),
//   ovung((0, 0), <dd>, [Định danh], [Tài khoản · địa chỉ], [Thông báo]),
//   ovung((1, 0), <hh>, [Hàng hoá], [Tin đăng · tồn kho], [Danh mục]),
//   ovung((2, 0), <td>, [Trao đổi], [Hội thoại · tin nhắn]),
//   ovung((0, 1), <tc>, [Tài chính], [Phiên thanh toán], [Ví · sổ cái]),
//   ovung((1, 1), <dh>, [Đặt hàng], [Đơn · dòng hàng · vận đơn], [Thương lượng], [Hoàn tiền]),
//   ovung((2, 1), <tn>, [Tín nhiệm], [Nhận xét · uy tín], [Phiếu hỗ trợ]),
//   ovung((1, 2), <qt>, [Quan trắc], [Nhật ký · độ đo]),
//   edge(<dh>, <tc>, "-|>", label: nhan[mở phiên], label-side: right),
//   // Bẻ XUỐNG (bend âm): bẻ lên thì cung này chạy đúng vào cạnh Đặt hàng → Định danh.
//   edge(<tc>, <dh>, "-|>", bend: -34deg, stroke: (dash: "dashed"),
//        label: nhan[tiền vào ký quỹ], label-side: right),
//   edge(<dh>, <hh>, "-|>", label: nhan[giữ tồn kho], label-side: right),
//   edge(<dh>, <tn>, "-|>", stroke: (dash: "dashed"),
//        label: nhan[đơn hoàn tất], label-side: right),
//   edge(<tn>, <hh>, "-|>", stroke: (dash: "dashed")),
//   edge(<tn>, <td>, "-|>"),
//   edge(<dh>, <dd>, "-|>"),
//   edge(<dh>, <qt>, "-|>", stroke: (dash: "dashed")),
// )

// #v(0.3cm)
// #std.align(center, ghi[
//   Nét liền: lời gọi đồng bộ, bên gọi chờ kết quả mới đi tiếp. \
//   Nét đứt: sự kiện bất đồng bộ, hai ngữ cảnh được phép lệch nhau một lúc.
// ])



// == Hiện thực dịch vụ nền

// #cot(ti: (1fr, 1fr))[
//   #the([Tài khoản])[
//     Nhật ký kiểm toán ghi *trong cùng giao dịch* với bản ghi.
//   ]
//   #v(8pt)
//   #the([Danh mục])[
//     Vector sinh ở tiến trình nền; chưa có thì lui về khớp từ khoá.
//   ]
//   #v(8pt)
//   #the([Đơn hàng])[
//     Vòng đời chạy trên quy trình bền; người bán chậm thì leo thang thông báo,
//     *không tự huỷ đơn*.
//   ]
// ][
//   #the([Tài chính])[
//     Mỗi biến động là một bút toán có khoá lũy đẳng, chỉ ghi *từ lời gọi lại của
//     cổng thanh toán*.
//   ]
//   #v(8pt)
//   #the([Hội thoại · Tín nhiệm])[
//     Phiếu hỗ trợ dùng chung luồng tin nhắn; điều phối viên luôn ẩn danh.
//   ]
//   #v(8pt)
//   #the([Quan trắc])[
//     Đường ghi số liệu tách khỏi đường xử lý yêu cầu.
//   ]
// ]

== Tìm kiếm lai: từ khoá và ngữ nghĩa

#sodo(
  co: 0.88em,
  spacing: (23mm, 17mm),

  o((0, 0), [Truy vấn \ người dùng], name: <q>),

  o((1.5, -0.8), [Lexical Search], name: <kw>),
  o((1.5, 0.8), [Semantic Search], name: <sem>),

  on((3.0, 0), [Danh sách kết quả], name: <merge>),

  on((4.4, 0), [Kết quả], name: <result>),

  edge(<q>, <kw>, "-|>", label: nhan[Embedding], label-side: left),

  edge(<q>, <sem>, "-|>", label: nhan[Embedding], label-side: right),

  edge(<kw>, <merge>, "-|>", label: nhan[Precision], label-side: left),

  edge(<sem>, <merge>, "-|>", label: nhan[Recall], label-side: right),

  edge(<merge>, <result>, "-|>", label: nhan[RRF Ranking], label-side: left),
)

#v(0.4cm)

#cot(ti: (1fr, 1fr, 1fr))[
  #the([Từ khoá])[
    Giữ chính xác tên model,
    mã sản phẩm và thông số.
  ]
][
  #the([Ngữ nghĩa])[
    Tìm được các cách diễn đạt
    khác nhau nhưng cùng ý nghĩa.
  ]
][
  #the([Kết hợp])[
    Giảm bỏ sót nhưng vẫn giữ
    độ chính xác của kết quả.
  ]
]

== Gợi ý cá nhân hoá

#sodo(
  co: 0.88em,
  spacing: (22mm, 19mm),

  o((0, 0), [Lưu sản phẩm], name: <fav>),
  o((0, 1.5), [Xem, click, \ Mua hàng], name: <sig>),

  o((1.4, 0.75), [Hành vi \ người dùng], name: <signals>),

  o((2.8, 0.75), [Nhóm theo \ danh mục], name: <cluster>),

  on((4.2, 0.75), [4 nhóm \ sở thích], name: <buckets>),

  edge(<fav>, <signals>, "-|>", label: nhan[], label-side: left),

  edge(<sig>, <signals>, "-|>", label: nhan[], label-side: right),

  edge(<signals>, <cluster>, "-|>", label: nhan[Exponential \ time decay], label-side: left),

  edge(<cluster>, <buckets>, "-|>", label: nhan[Top-4 + \ normalize], label-side: left),
)

#v(0.45cm)

#cot(ti: (1fr, 1fr))[
  #the([Tín hiệu hành vi])[
    Favorite - Purchase - Search click
    Recommendation click - View
  ]
][
  #the([Mỗi nhóm sở thích])[
    là vector đại diện và mức độ quan tâm
  ]
]

#v(0.3cm)

#std.align(center, ghi[
  Nhu- cầu thiết yếu, sở thích cá nhân, mua sắm theo mùa/chu kỳ và xu hướng tức thời
])

#sodo(
  co: 0.86em,
  spacing: (22mm, 15mm),

  o((0, 0), [Sở thích 1], name: <i1>),
  o((0, 1), [Sở thích 2], name: <i2>),
  o((0, 2), [Sở thích 3], name: <i3>),
  o((0, 3), [Sở thích 4], name: <i4>),

  o((1.4, 3.8), [Sản phẩm mới], name: <fresh>),

  o((1.7, 1.5), [Ứng viên], name: <candidate>),

  on((3.1, 1.5), [Trộn kết quả], name: <mix>),

  on((4.4, 1.5), [Feed \ cá nhân hoá], name: <feed>),

  edge(<i1>, <candidate>, "-|>", label: nhan[Cosine], label-side: left),
  edge(<i2>, <candidate>, "-|>"),
  edge(<i3>, <candidate>, "-|>"),
  edge(<i4>, <candidate>, "-|>"),

  edge(<fresh>, <candidate>, "-|>", label: nhan[Fresh 20%], label-side: right),

  edge(<candidate>, <mix>, "-|>", label: nhan[Weighted random \ sampling], label-side: left),

  edge(<mix>, <feed>, "-|>", label: nhan[], label-side: left),
)


== Kiến trúc hệ thống
#figure(
  assets("./system-diagram-ngang.png", width: 105%),
)


= Kết luận

== Kết quả, hạn chế và hướng phát triển

#cot(ti: (1fr, 1fr, 1fr))[
  #the([Kết quả đạt được], mau: do-ptit)[
    - Thiết kế trọn hệ thống, từ nghiệp vụ đến kiến trúc và dữ liệu.

    - Dịch vụ nền, ứng dụng web và di động trên cùng một đặc tả API.

    - Luồng ký quỹ, giao nhận, hoàn tiền, phân xử chạy được đầu cuối.
  ]
][
  #the([Hạn chế])[
    - Vận chuyển và xác minh danh tính còn ở mức giả lập.

    - Chưa có kiểm thử toàn trình tự động.

    - Chưa đánh giá hiệu năng và kiểm thử tải.
  ]
][
  #the([Hướng phát triển])[
    - Tích hợp thật với đối tác vận chuyển, định danh.

    - Bổ sung kiểm thử toàn trình và kiểm thử tải.

    - Mở rộng sang các hình thức giao dịch khác.
  ]
]

#ket-slide[XIN CẢM ƠN QUÝ THẦY CÔ]
