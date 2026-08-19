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

== Nội dung trình bày

#cot(ti: (1fr, 1fr))[
  #the([1 · Đặt vấn đề])[
    Bài toán niềm tin trong giao dịch C2C.
  ]
  #v(9pt)
  #the([2 · Phân tích và thiết kế])[
    Cơ sở lý thuyết, tác nhân, luồng nghiệp vụ, kiến trúc.
  ]
][
  #the([3 · Hiện thực và kiểm thử])[
    Các dịch vụ nền và hành vi được khoá.
  ]
  #v(9pt)
  #the([4 · Kết luận])[
    Kết quả, hạn chế, hướng phát triển.
  ]
]

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
  #the([Hoàn tiền · tranh chấp])[
    Có bằng chứng; không tự thoả thuận được thì điều phối viên phân xử.
  ]
]
= Phân tích và thiết kế

== Giao dịch phân tán: mẫu Saga và hàm bù trừ

#cot(ti: (1fr, 1fr))[
  #text(size: 0.8em)[
    Một luồng ký quỹ đi qua nhiều dịch vụ và kéo dài nhiều ngày — không giao dịch
    ACID nào bao trọn được.

    #v(4pt)
    *Mẫu Saga:* chuỗi giao dịch cục bộ, mỗi bước kèm một *hàm bù trừ*.

    #v(4pt)
    *Giá phải trả*
    - nhiều thao tác *không hoàn tác được*;
    - mã xử lý lỗi phình hơn mã nghiệp vụ.
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
    edge(<s3>, <s2>, "-|>", bend: 40deg,
         stroke: (paint: do-ptit, thickness: 1pt, dash: "dashed"),
         label: nhan(text(fill: do-ptit)[bù trừ 2]), label-side: right),
    edge(<s2>, <s1>, "-|>", bend: 40deg,
         stroke: (paint: do-ptit, thickness: 1pt, dash: "dashed"),
         label: nhan(text(fill: do-ptit)[bù trừ 1]), label-side: right),
  )
  #v(8pt)
  #std.align(center, ghi[Saga xử lý lỗi bằng cách *quay lui*: \ mỗi bước xuôi phải có một bước ngược tương ứng.])
]

== Durable Execution: Recover and Continue

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
  #std.align(center, ghi[Quy trình bền xử lý lỗi bằng cách *chạy tiếp*: \ nhật ký giữ chỗ, không cần bước ngược.])
]

== Tìm kiếm lai: từ khoá và ngữ nghĩa

#cot(ti: (1fr, 1fr))[
  #text(size: 0.8em)[
    Người bán cá nhân mô tả hàng rất tự do — _"tl ip 15 prm 256 gb zin keng"_.

    #v(4pt)
    Khớp từ khoá thuần bỏ lọt: "điện thoại Apple cũ" không khớp
    "iPhone 13 thanh lý lên đời".

    #v(4pt)
    *Tìm kiếm ngữ nghĩa* đưa các cách nói cùng nghĩa về gần nhau.
  ]
][
  #the([Vì sao phải lai])[
    Ngữ nghĩa hiểu ý định nhưng *làm nhoè thông số* — "RTX 4090" dễ bị hoà tan.
    Từ khoá giữ độ nét đó.
  ]
  #v(8pt)
  #the([Xếp hạng dung hợp])[
    Tổ hợp có trọng số của *khớp từ khoá*, *khoảng cách ngữ nghĩa* và *uy tín
    người bán*.
  ]
]

== Tác nhân và ngữ cảnh hệ thống

#cot(ti: (1fr, 1.1fr))[
  #the([Người dùng])[
    Vừa mua vừa bán trên một định danh; muốn bán thì phải xác minh danh tính.
  ]
  #v(8pt)
  #the([Điều phối viên])[
    Thẩm định khiếu nại, phân xử tranh chấp, kiểm duyệt tin đăng.
  ]
  #v(8pt)
  #the([Quản trị viên])[
    Đối soát dòng tiền ký quỹ, quản lý nhân sự điều phối.
  ]
][
  #sodo(
    co: 0.92em,
    spacing: (26mm, 15mm),
    on((1, 1), [ShopNexus], name: <sn>, width: 30mm),
    o((0, 0), [Cổng \ thanh toán], name: <p>),
    o((2, 0), [Đơn vị \ vận chuyển], name: <s>),
    o((0, 2), [Định danh \ và thư], name: <o>),
    o((2, 2), [Dịch vụ \ trí tuệ nhân tạo], name: <l>),
    edge(<sn>, <p>, "<|-|>", label: nhan[], label-side: left),
    edge(<sn>, <s>, "<|-|>", label: nhan[hành trình], label-side: right),
    edge(<sn>, <o>, "-|>"),
    edge(<sn>, <l>, "-|>"),
  )
  #v(6pt)
  #std.align(center, ghi[Bốn nhóm hệ thống ngoại vi là ranh giới tích hợp của nền tảng.])
]

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
  on((3, 0), [Ghi có ví \ và giữ ký quỹ], name: <d>),
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
  edge(<j>, <i>, "-|>", bend: -22deg, label: nhan[phán quyết], label-side: left),
)

#v(0.3cm)
#ghi[Đơn hàng sinh ra từ sự kiện xác nhận thanh toán, không từ yêu cầu của người mua: đơn chỉ tồn tại khi tiền đã nằm trong ký quỹ.]

== Vòng đời đơn hàng và các mốc hẹn giờ

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

#v(0.4cm)
#std.align(center, ghi[
  Mỗi đơn hàng là một quy trình bền. Nhật ký ghi cả bộ đếm thời gian,
  nên khởi động lại máy chủ không làm mất đồng hồ hẹn.
])


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


== Bản đồ ngữ cảnh giới hạn

// Ranh giới đặt ở chỗ một khái niệm đổi nghĩa: tin đăng ở Hàng hoá là bản ghi sửa
// được, còn trong Đặt hàng chỉ là bản chụp bất biến lúc chốt mua. Bản đầy đủ kèm
// hợp đồng liên ngữ cảnh nằm trong quyển, mục 4.2.
#sodo(
  co: 0.95em,
  spacing: (54mm, 19mm),
  ovung((0, 0), <dd>, [Định danh], [Tài khoản · địa chỉ], [Thông báo]),
  ovung((1, 0), <hh>, [Hàng hoá], [Tin đăng · tồn kho], [Danh mục]),
  ovung((2, 0), <td>, [Trao đổi], [Hội thoại · tin nhắn]),
  ovung((0, 1), <tc>, [Tài chính], [Phiên thanh toán], [Ví · sổ cái]),
  ovung((1, 1), <dh>, [Đặt hàng], [Đơn · dòng hàng · vận đơn], [Thương lượng], [Hoàn tiền]),
  ovung((2, 1), <tn>, [Tín nhiệm], [Nhận xét · uy tín], [Phiếu hỗ trợ]),
  ovung((1, 2), <qt>, [Quan trắc], [Nhật ký · độ đo]),
  edge(<dh>, <tc>, "-|>", label: nhan[mở phiên], label-side: right),
  // Bẻ XUỐNG (bend âm): bẻ lên thì cung này chạy đúng vào cạnh Đặt hàng → Định danh.
  edge(<tc>, <dh>, "-|>", bend: -34deg, stroke: (dash: "dashed"),
       label: nhan[tiền vào ký quỹ], label-side: right),
  edge(<dh>, <hh>, "-|>", label: nhan[giữ tồn kho], label-side: right),
  edge(<dh>, <tn>, "-|>", stroke: (dash: "dashed"),
       label: nhan[đơn hoàn tất], label-side: right),
  edge(<tn>, <hh>, "-|>", stroke: (dash: "dashed")),
  edge(<tn>, <td>, "-|>"),
  edge(<dh>, <dd>, "-|>"),
  edge(<dh>, <qt>, "-|>", stroke: (dash: "dashed")),
)

#v(0.3cm)
#std.align(center, ghi[
  Nét liền: lời gọi đồng bộ, bên gọi chờ kết quả mới đi tiếp. \
  Nét đứt: sự kiện bất đồng bộ, hai ngữ cảnh được phép lệch nhau một lúc.
])

== Kiến trúc microservices

// Mỗi ngữ cảnh giới hạn ở slide trước thành đúng một dịch vụ — cùng tên, cùng thứ
// tự, để hội đồng thấy ngay quan hệ một–một. Hạ tầng dùng chung vẽ gộp thành hàng
// dưới vì cả bảy dịch vụ đều chạm tới; vẽ từng cạnh riêng sẽ thành mạng nhện.
#sodo(
  co: 0.9em,
  spacing: (25mm, 17mm),
  o((0, 0), [Máy khách \ web · di động], name: <mk>),
  on((1, 0), [Cổng vào \ HTTP · WebSocket], name: <cv>),
  node(
    (2, 0),
    align(left, stack(
      dir: ttb, spacing: 4pt,
      text(size: 0.58em, weight: 700, fill: nav)[Bảy dịch vụ nghiệp vụ],
      line(length: 100%, stroke: 0.5pt + nav-nhat),
      grid(
        columns: (auto, auto), column-gutter: 10pt, row-gutter: 3.5pt,
        text(size: 0.52em)[Định danh], text(size: 0.52em)[Tài chính],
        text(size: 0.52em)[Hàng hoá], text(size: 0.52em)[Tín nhiệm],
        text(size: 0.52em)[Đặt hàng], text(size: 0.52em)[Trao đổi],
        text(size: 0.52em)[Quan trắc], [],
      ),
    )),
    fill: nav-nen, stroke: 1.2pt + nav, corner-radius: 3pt, inset: 7pt, name: <sv>,
  ),
  o((3, 0), [Cổng ra \ thanh toán · vận chuyển \ định danh · trí tuệ nhân tạo], name: <cr>),
  o((1, 1), [Nền tảng \ thực thi bền], name: <tb>),
  o((2, 1), [Cơ sở dữ liệu \ một lược đồ mỗi dịch vụ], name: <db>),
  o((3, 1), [Trục sự kiện], name: <ts>),
  edge(<mk>, <cv>, "-|>"),
  edge(<cv>, <sv>, "-|>", label: nhan[hợp đồng], label-side: left),
  edge(<sv>, <cr>, "-|>", label: nhan[bộ điều hợp], label-side: left),
  edge(<sv>, <tb>, "-|>"),
  edge(<sv>, <db>, "-|>"),
  edge(<sv>, <ts>, "-|>", stroke: (dash: "dashed"),
       label: nhan[sự kiện], label-side: right),
)

#v(0.35cm)
#cot(ti: (1fr, 1fr, 1fr))[
  #the([Ranh giới cưỡng chế])[
    Dịch vụ khác chỉ thấy hợp đồng công bố; *không khoá ngoại nào bắc qua hai lược đồ*.
  ]
][
  #the([Cổng vào không giữ quy tắc])[
    Đọc yêu cầu, gọi hợp đồng, ghi kết quả; kiểm vai trò nằm trong dịch vụ.
  ]
][
  #the([Một đơn vị triển khai])[
    Bảy dịch vụ phát hành chung; ranh giới đã dựng nên *tách ra chạy riêng được*.
  ]
]

= Hiện thực và kiểm thử



== Hiện thực dịch vụ nền

#cot(ti: (1fr, 1fr))[
  #the([Tài khoản])[
    Nhật ký kiểm toán ghi *trong cùng giao dịch* với bản ghi.
  ]
  #v(8pt)
  #the([Danh mục])[
    Vector sinh ở tiến trình nền; chưa có thì lui về khớp từ khoá.
  ]
  #v(8pt)
  #the([Đơn hàng])[
    Vòng đời chạy trên quy trình bền; người bán chậm thì leo thang thông báo,
    *không tự huỷ đơn*.
  ]
][
  #the([Tài chính])[
    Mỗi biến động là một bút toán có khoá lũy đẳng, chỉ ghi *từ lời gọi lại của
    cổng thanh toán*.
  ]
  #v(8pt)
  #the([Hội thoại · Tín nhiệm])[
    Phiếu hỗ trợ dùng chung luồng tin nhắn; điều phối viên luôn ẩn danh.
  ]
  #v(8pt)
  #the([Quan trắc])[
    Đường ghi số liệu tách khỏi đường xử lý yêu cầu.
  ]
]

// == Ứng dụng web

// #cot(ti: (1.5fr, 1fr))[
//   #std.align(center, assets("web/web-01-tim-kiem.png", width: 100%))
// ][
//   #text(size: 0.76em)[
//     Tuyến đường chia thành vùng công khai, vùng xác thực, vùng người dùng đã đăng
//     nhập và vùng quản trị.

//     Bảo vệ tuyến ở phía trình duyệt chỉ nhằm trải nghiệm điều hướng; *hàng rào
//     bảo mật thật vẫn nằm ở dịch vụ nền*, kiểm thẻ truy cập trên từng yêu cầu.

//     Mua theo giá niêm yết và mua sau khi đàm phán thành công cùng đổ về *một
//     trang thanh toán*, cước tính động theo địa chỉ.
//   ]
// ]

// == Ứng dụng di động

// #cot(ti: (1fr, 1fr))[
//   #std.align(center, stack(
//     dir: ltr, spacing: 6mm,
//     image("../common/assets/mobile/mobile-01-trang-chu.png", height: 8cm),
//     image("../common/assets/mobile/mobile-03-dang-ban-tren.png", height: 8cm),
//     image("../common/assets/mobile/mobile-12-checkout-thanh-toan.png", height: 8cm),
//   ))
// ][
//   #text(size: 0.76em)[
//     Kiến trúc *hướng tính năng*: mỗi module đóng gói giao diện và truy cập dữ
//     liệu của riêng nó, thay vì cắt hệ thống theo tầng kỹ thuật.

//     - Biểu mẫu đăng bán có lối *nhờ mô hình ngôn ngữ điền giúp* từ ảnh và lời mô tả.
//     - Màn hình thanh toán nhúng trang của cổng thanh toán, dữ liệu thẻ không đi
//       qua máy khách.
//     - Dùng chung *một bản đặc tả API* với ứng dụng web.
//   ]
// ]

// == Tích hợp bên ngoài và triển khai liên tục

// #cot(ti: (1fr, 1fr))[
//   #bang(
//     (auto, 1fr),
//     [Nhóm cổng], [Vai trò trong luồng nghiệp vụ],
//     [Thanh toán], [Thu tiền vào ký quỹ, báo kết quả về],
//     [Vận chuyển], [Báo giá cước, tạo vận đơn, đẩy hành trình],
//     [Sinh vector], [Biểu diễn ngữ nghĩa cho tin đăng],
//     [Mô hình ngôn ngữ], [Gợi ý điền biểu mẫu đăng bán],
//     [Lưu trữ đối tượng], [Giữ ảnh, video bằng chứng],
//     [Định danh], [Đăng nhập liên kết, xác minh danh tính],
//   )
// ][
//   #text(size: 0.76em)[
//     Mỗi nhóm là một cổng giao tiếp hẹp kèm bộ điều hợp riêng, nạp động lúc khởi
//     động qua sổ đăng ký. Hầu hết đều có sẵn bản giả lập nên chạy được toàn luồng
//     mà không cần tài khoản đối tác.
//   ]
//   #v(8pt)
//   #the([Tích hợp liên tục])[
//     *Đóng gói và phát hành* khi mã vào nhánh chính · *Kiểm định đặc tả API* trên
//     mỗi yêu cầu gộp: sinh lại đặc tả từ mã nguồn rồi so với bản đã cam kết, lệch
//     là gãy tiến trình.
//   ]
// ]

== Kiểm thử: khoá hành vi của luồng tiền

#text(size: 0.78em)[
  Kiểm thử ở đây để *khoá hành vi* tại những chỗ một thay đổi về sau dễ làm sai
  lệch dòng tiền.
]

#v(0.35cm)
#bang(
  (1.15fr, 1fr),
  [Hành vi được khoá], [Tình huống dựng ra để ép nó lộ],
  [Một lần trả tiền sinh đúng một đơn hàng],
  [Cổng thanh toán gửi lặp thông báo đã xử lý],

  [Chuỗi quyết toán chạy lại không nhân đôi hiệu ứng],
  [Ép lệnh giữ tiền gãy giữa chừng rồi gọi lại],

  [Còn hồ sơ hoàn tiền treo thì không giải ngân],
  [Mở hồ sơ ngay trước lúc tác vụ quét giành đơn],

  [Người ngoài cuộc không biết bản ghi có tồn tại],
  [Gọi chéo vai trò trên từng phân hệ],

  [Máy khách và máy chủ không lệch hợp đồng],
  [Sinh lại đặc tả từ mã nguồn rồi so bản đã cam kết],
)

#v(0.3cm)
#ghi[Ràng buộc chỉ tồn tại ở tầng dữ liệu — số dư không âm, hai giao dịch ghi đồng thời — cần cơ sở dữ liệu thật mới kiểm được.]

= Kết luận

== Kết quả, hạn chế và hướng phát triển

#cot(ti: (1fr, 1fr, 1fr))[
  #the([Kết quả đạt được], mau: do-ptit)[
    - Thiết kế trọn hệ thống, từ nghiệp vụ đến kiến trúc và dữ liệu.

    - Dịch vụ nền, ứng dụng web và di động trên cùng một đặc tả API.

    - Luồng ký quỹ — giao nhận — hoàn tiền — phân xử chạy được đầu cuối.
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