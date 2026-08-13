#import "../../common/tokens.typ": *

// ------------------------------------------------------------
//  Hộp lớp UML ba ngăn cho fletcher. Không phải design token nên không đưa
//  vào common/tokens.typ; đây là cùng một helper mà docs/typst/class_diagram.typ
//  dùng, giữ nguyên để hai tài liệu vẽ ra cùng một ký hiệu.
// ------------------------------------------------------------
//  Nội dung hai ngăn dưới KHÔNG đặt bằng phông đơn cách. Không phông đơn cách nào có
//  sẵn ở đây phủ hết chữ Việt: một nguyên âm mang cả dấu phụ lẫn dấu thanh (ề, ộ, ặ, ữ)
//  bị tách thành hai ký hiệu rời khi dựng chữ. Vì các ngăn này mang chú thích tiếng
//  Việt, phông thân bài được dùng thay, và ký hiệu mã nguồn vẫn đọc được bình thường.
#let boxline(x) = text(size: 6.8pt, font: font-quyen, x)

// Ghi chú UML: hộp viền đứt mang bất biến, danh sách giá trị hoặc dữ kiện liên
  // module. Dùng chung cỡ chữ với ngăn thuộc tính của `cls` nên 2 loại hộp đọc
  // như cùng một hệ ký hiệu, chỉ khác nhau ở nét viền.
  #let cnote(p, title, lines, ..a) = nr(
    p,
    table(
      columns: 1, inset: (x: 6pt, y: 4pt), align: left, fill: none,
      stroke: (x, y) => (top: if y == 0 { 0pt } else { 0.5pt + hairline }),
      align(center, text(size: 7.4pt, style: "italic", fill: muted, title)),
      stack(spacing: 2.4pt, ..lines.map(boxline)),
    ),
    shape: rect, inset: 0pt, ..a,
  )

#let cls(p, ten, attrs: (), ops: (), stereo: none, ..a) = {
  let dau = if stereo == none {
    align(center, text(size: 8.4pt, weight: 700, ten))
  } else {
    align(center, stack(
      spacing: 1.5pt,
      text(size: 6.4pt, style: "italic", fill: muted, "«" + stereo + "»"),
      text(size: 8.4pt, weight: 700, ten),
    ))
  }
  let o = (dau,)
  if attrs.len() > 0 {
    o.push(stack(spacing: 2.4pt, ..attrs.map(boxline)))
  }
  if ops.len() > 0 {
    o.push(stack(spacing: 2.4pt, ..ops.map(boxline)))
  }
  node(
    p,
    table(
      columns: 1,
      inset: (x: 6pt, y: 4pt),
      align: left,
      fill: none,
      stroke: (x, y) => (top: if y == 0 { 0pt } else { 0.5pt + hairline }),
      ..o,
    ),
    shape: rect, fill: white, stroke: 0.9pt + ink, inset: 0pt, ..a,
  )
}

// Nhãn quan hệ cỡ nhỏ trên cạnh sơ đồ: đã chuyển sang common/tokens.typ vì
// sơ đồ kiến trúc ở chương trước cũng dùng, và hai chỗ phải cùng một cỡ chữ.

// Activation bar trên một lifeline của sơ đồ trình tự: một đoạn
// dọc dày đè lên lifeline nét đứt, cho biết đối tượng đang giữ quyền điều khiển.
#let act(a, y1, y2) = edge((a, y1), (a, y2), "-", stroke: 4.5pt + rgb("#C4C4C4"))

// Chữ ký phương thức trên mũi tên. Đơn cách được ở đây vì chữ ký chỉ gồm ký tự ASCII.
#let sig(t) = text(size: 6.4pt, font: font-mono, t)

== Sơ đồ lớp chi tiết

=== Phạm vi và quy ước ký hiệu

Toàn bộ hệ thống có 46 bảng nghiệp vụ trải trên 7 lược đồ cơ sở dữ liệu, nên
một sơ đồ lớp duy nhất sẽ không đọc được; phần này chia sơ đồ theo ranh giới module,
cũng chính là ranh giới lược đồ mà một module sẽ mang theo nếu về sau nó được tách sang cơ
sở dữ liệu riêng. 3 module được vẽ đầy đủ vì cấu trúc lớp của chúng nói lên điều mà văn
xuôi không nói nổi: đơn hàng; tài chính, với phiên thanh toán, chặng thanh toán, ví và 2 sổ cái; và tín
nhiệm, nơi một bảng phiếu duy nhất gánh mọi loại khiếu nại.

Ký hiệu thống nhất cho cả ba sơ đồ lớp. Mỗi hộp lớp gồm ba ngăn: tên lớp kèm khuôn mẫu, ngăn
thuộc tính và ngăn phương thức. Nét liền là quan hệ nội module, có khóa ngoại thật và bội
số ghi ở hai đầu cạnh; nét đứt kèm nhãn liên module là tham chiếu vượt lược đồ, trên cơ sở
dữ liệu chỉ là một số nguyên trần không có khóa ngoại nào kiểm tra hộ, nên tầng nghiệp vụ
phải tự giữ tính toàn vẹn ấy.

=== Module order

Đây là module dày quy tắc nhất và cũng là module duy nhất có khai báo durable workflow. Hai
điều cần nói ngay vì cả hai đảo ngược cách hiểu thông thường về một sàn giao dịch. Thứ
nhất, đơn hàng ra đời khi tiền về, do thông báo từ cổng thanh toán chứ không do ai bấm
nút phê duyệt; vì thế dòng hàng đã mua có thể tồn tại trước đơn hàng, và chỉ mục các dòng
chưa gắn đơn là một danh sách chờ ghép chứ không phải hộp thư chờ duyệt. Thứ hai, người
bán vẫn phải xác nhận, nhưng thứ họ xác nhận không phải là tiền: tiền đã nằm trong escrow
rồi, và lượt xác nhận ấy chỉ mở khóa việc gọi hãng vận chuyển, để một bài đăng có tồn kho
sai hay một người bán đã bỏ nghề không bị phát hiện bởi chính người mua ngồi chờ một kiện
hàng không ai gửi. Trạng thái đơn hàng có 4 giá trị và được suy ra từ các mốc thời
gian kết quả chứ không lưu thành cột riêng, theo thứ tự xét: đã hủy, hoàn thành, chờ người
bán xác nhận, đang mở; nhờ vậy hệ thống bớt một dữ kiện phải giữ cho đồng bộ. Người bán im
lặng quá 48 giờ thì bộ phận vận hành được nhắc đi giục, chứ nền tảng không tự
hủy đơn và cũng không tự gửi hàng thay người bán.
#fig-xoay(
    [Sơ đồ lớp module đơn hàng: từ giỏ hàng và thương lượng tới một đơn hàng],
    spacing: (8mm, 7mm),

    cls((0, 0), "orderapi.Service", stereo: "cổng vào module", name: <o-svc>,
      ops: (
        "+ giỏ hàng · phiếu mua · thương lượng",
        "+ đặt hàng · xác nhận · hủy",
        "+ hoàn tiền · phán quyết",
        "+ các phương thức đến hạn, đều idempotent",
      )),
    cls((0, 1), "port.Workflows", stereo: "interface", name: <o-wf>,
      ops: (
        "4 durable workflow: thanh toán, vòng đời",
        "đơn, hoàn tiền, thương lượng",
        "mọi lời gọi là cố-gắng-hết-sức",
      )),
    cls((0, 2), "port.Repository", stereo: "interface", name: <o-repo>,
      ops: (
        "SQL viết tay, tham số đặt tên",
        "mọi lượt ghi đều là guarded write",
        "7 module cùng một hình dạng này",
      )),
    edge(<o-svc>, <o-wf>, "-->", rel[khởi động]),
    edge(<o-svc>, <o-repo>, "-->", rel[dùng]),

    cls((1, 0), "CartItem", name: <o-cart>,
      attrs: (
        "- accountID: int64",
        "- listingID, variantID → catalog",
        "- quantity: int64",
      ),
      ops: ("+ SetQuantity(q)",)),

    cls((1, 1), "Draft", stereo: "đóng băng điều khoản", name: <o-draft>,
      attrs: (
        "- buyerID, listingID: int64",
        "+ Snapshot: ListingSnapshot",
        "- validUntil: time",
        "- cancelledAt: *time",
      ),
      ops: (
        "+ Live(now) bool",
        "+ Cancel()",
        "+ Variant(variantID)",
      )),

    cls((1, 2), "Offer", stereo: "thương lượng giá", name: <o-offer>,
      attrs: (
        "- listingID, variantID: int64",
        "- authorID → bên đang giữ đề nghị",
        "- status: active | accepted |",
        "          checked-out | cancelled",
        "- paymentSessionID: *int64",
        "- expiresAt: time",
      ),
      ops: (
        "+ Counter(actor, qty, total, lý do)",
        "+ Accept(actorID, now, window)",
      )),

    cls((2, 0), "ListingSnapshot", stereo: "value object", name: <o-snap>,
      attrs: (
        "- listingID, sellerID, name, currency",
        "- priceMode: string",
        "- variants: []VariantSnapshot",
        "     variantID, price,",
        "     attributes, packageDetails",
      )),

    cls((2, 1), "Order", stereo: "aggregate root", name: <o-ord>,
      attrs: (
        "- draftID XOR offerID: *int64",
        "- buyerID, sellerID: int64",
        "- createdAt: time",
      )),

    cnote((2, 2), "Cuộc thương lượng", (
      "Mỗi cặp người mua – biến thể chỉ có",
      "MỘT cuộc đang thương lượng.",
      "Bên đang giữ đề nghị không được tự",
      "đồng ý với chính mình.",
      "Đồng ý chỉ đóng băng giá, chưa bán",
      "được hàng: người mua vẫn phải bấm mua.",
    ), name: <o-n1>),

    cls((3, 0), "AddressSnapshot", stereo: "value object", name: <o-addr>,
      attrs: (
        "- fullName, phone, country",
        "- provinceCode, wardCode",
        "- districtCode, addressDetail: *string",
      )),

    cls((3, 1), "Item", name: <o-item>,
      attrs: (
        "- orderID: *int64 → NULL tới khi trả tiền",
        "- draftID XOR offerID: *int64",
        "- buyerID, sellerID: int64",
        "- listingID, variantID → catalog",
        "- quantity, totalAmount: int64",
        "- paymentSessionID: int64 → finance",
      ),
      ops: ("+ Live() bool", "+ Cancel(actorID)")),

    cnote((3, 2), "Một đơn, một nguồn gốc", (
      "Đơn ra đời từ ĐÚNG MỘT nguồn: phiếu",
      "mua hoặc cuộc thương lượng, không bao",
      "giờ cả hai và không bao giờ không có.",
      "Ràng buộc duy nhất trên nguồn ấy chặn",
      "một lời gọi lại bị giao hai lần sinh",
      "ra hai đơn, ngay tại tầng dữ liệu.",
    ), name: <o-n2>),

    edge(<o-draft>, <o-snap>, "-->", rel[nội dung ảnh chụp]),
    edge(<o-draft>, <o-ord>, "-", rel[0..1 → 0..1]),
    edge(<o-offer>, <o-ord>, "-", rel[0..1 → 0..1]),
    edge(<o-ord>, <o-addr>, "-->", rel[đóng băng lúc mua]),
    edge(<o-ord>, <o-item>, "-", rel[1 → 1..\*]),
    edge(<o-offer>, <o-n1>, "-", stroke: (dash: "dashed")),
    edge(<o-item>, <o-n2>, "-", stroke: (dash: "dashed")),
  )


=== Module finance

Toàn bộ nguyên thủy tiền tệ nằm chung một module để các bước dịch chuyển escrow giữ được
tính nguyên tử. Ranh giới quan trọng nhất bên trong module là 2 sổ cái, một đường
biên: một sổ ghi các chặng đi trên kênh thanh toán bên ngoài, sổ còn lại ghi mọi lần tiền
dịch chuyển bên trong ví của nền tảng, và không bao giờ ghi cùng một lần dịch chuyển vào
cả hai, vì như thế tổng tiền của hệ thống sẽ được đếm hai lần. Một chi tiết quyết định cả
cách rút tiền vận hành: không có bảng lệnh rút tiền. Một lượt rút là một phiên thanh
toán mang loại riêng, cùng bảng và cùng vòng đời với một lượt thanh toán của người mua,
chỉ khác chiều tiền; nhờ vậy trạng thái "đang xử lý", việc thử lại và bằng chứng đối soát
với ngân hàng chỉ được viết một lần.
#fig-xoay(
    [Sơ đồ lớp module tài chính: phiên thanh toán, chặng tiền và sổ kép của ví],
    spacing: (8mm, 7mm),

    cls((0, 0), "financeapi.Service", stereo: "cổng vào module", name: <f-svc>,
      ops: (
        "+ phiên thanh toán · chặng · quyết toán",
        "+ escrow: giữ · giải ngân · hoàn",
        "+ ví · sao kê · rút tiền",
        "+ hồ sơ thuế · tài khoản ngân hàng",
      )),
    cls((0, 1), "port.Repository", stereo: "interface", name: <f-repo>,
      ops: (
        "+ Move(legs)",
        "  ghi ví và sổ cái trong CÙNG một",
        "  giao dịch; đây là điểm khác biệt",
        "  duy nhất so với 6 module kia",
      )),
    cnote((0, 2), "Rút tiền không có bảng riêng", (
      "Rút tiền là một phiên kind='withdrawal',",
      "dùng lại đúng máy trạng thái của phiên",
      "thanh toán. Không lớp riêng, không bảng",
      "riêng, nên không có đường mã thứ hai để",
      "quên cập nhật.",
    ), name: <f-n1>),

    cls((1, 0), "Session", stereo: "payment intent", name: <f-ses>,
      attrs: (
        "- id: int64  cấp phát TRƯỚC khi ghi",
        "- kind: buyer-checkout | seller-payout |",
        "        withdrawal",
        "- status: pending | processing |",
        "          success | cancelled | failed",
        "- fromID, toID: int64  (0 = hệ thống)",
        "- currency, totalAmount",
        "- paidAt: *time, expiredAt: time",
      ),
      ops: (
        "+ Expired(now) / Settled() / RailPayable()",
        "+ Charge(now) / MarkPaid(now) / MarkFailed()",
      )),

    cls((1, 1), "Wallet", name: <f-wal>,
      attrs: (
        "- accountID, currency  (khóa chính)",
        "- availableBalance: int64  tiêu / rút được",
        "- heldBalance: int64       đang giữ escrow",
      ),
      ops: (
        "+ Total() int64",
        "+ CanSpend(amount) bool",
        "+ Apply(t Transfer, seq) (Movement, error)",
      )),

    cls((1, 2), "Transfer", stereo: "value object", name: <f-trf>,
      attrs: (
        "- kind: string",
        "- availableDelta, heldDelta: int64",
      ),
      ops: ("Hold · Release · Credit · Debit · Adjust",)),

    cls((2, 0), "Transaction", stereo: "append-only", name: <f-tx>,
      attrs: (
        "- sessionID: int64",
        "- status: pending → success | failed",
        "- paymentOption: string  kênh thanh toán",
        "- providerRef: *string   idempotency key",
        "- checkoutURL: *string",
        "- amount: int64  dương thu, âm hoàn",
        "- reversesID: *int64  tự quan hệ",
      ),
      ops: (
        "+ NewReversal(id, amount)",
        "+ Resumable(now) bool",
        "+ Settle(status, providerRef, failure)",
      )),

    cls((2, 1), "Movement", stereo: "append-only", name: <f-mov>,
      attrs: (
        "- accountID, currency",
        "- seq: int64  thứ tự tuyệt đối trong ví",
        "- kind: topup | escrow-hold |",
        "        escrow-release | payout | refund |",
        "        withdrawal | fee | adjustment",
        "- availableAfter, heldAfter: int64",
        "- groupID: *int64  các chân cùng một lần",
        "- idempotencyKey: *string",
      )),

    cnote((2, 2), "2 sổ, một đường biên", (
      "Ví giữ số dư hiện thời, sổ giữ từng",
      "lượt dịch chuyển kèm số dư sau lượt ấy.",
      "Chúng chỉ được sửa cùng nhau, trong một",
      "giao dịch, sau khi đã khóa hàng ví theo",
      "THỨ TỰ CỐ ĐỊNH để hai lượt ngược chiều",
      "không khóa chéo nhau.",
      "Đối soát là phép so 2 sổ ấy.",
    ), name: <f-n2>),

    cnote((3, 0), "Bất biến của đường tiền", (
      "Mỗi kênh, mỗi tham chiếu nhà cung cấp",
      "chỉ tính tiền MỘT lần.",
      "Mỗi chặng chỉ hoàn được một lần.",
      "Một phiên chưa kết thúc có nhiều nhất",
      "một trang thanh toán còn sống trên",
      "mỗi kênh.",
      "Số tiền lấy từ hàng chặng, không bao",
      "giờ lấy từ nội dung thông báo gửi tới.",
    ), name: <f-n3>),

    cls((3, 1), "BankAccount", name: <f-bank>,
      attrs: (
        "- accountID: int64",
        "- bankCode, accountNumber, accountHolder",
        "- isDefault: bool  ≤ 1 mỗi tài khoản",
        "- deletedAt: *time  xóa mềm",
      ),
      ops: ("+ IsLive() bool",)),

    cls((3, 2), "TaxInfo", name: <f-tax>,
      attrs: (
        "- accountID: int64  (khóa chính)",
        "- taxCode: string",
        "- taxCodeType: individual | business |",
        "               household",
        "- verificationStatus: pending |",
        "               verified | rejected",
        "- verifiedAt, verificationSource: *",
      ),
      ops: ("+ Verify(verified, source)",)),

    edge(<f-svc>, <f-repo>, "-->", rel[dùng]),
    edge(<f-svc>, <f-ses>, "-->", rel[điều phối]),
    edge(<f-ses>, <f-tx>, "-", rel[1 → 0..\*]),
    edge(<f-ses>, <f-wal>, "-->", stroke: (dash: "dashed"), rel[quyết toán thì ghi ví]),
    edge(<f-wal>, <f-mov>, "-", rel[1 → 0..\*]),
    edge(<f-wal>, <f-trf>, "-->", rel[tham số của Apply]),
    edge(<f-tx>, <f-n3>, "-", stroke: (dash: "dashed")),
    edge(<f-mov>, <f-n2>, "-", stroke: (dash: "dashed")),
    edge(<f-repo>, <f-n1>, "-", stroke: (dash: "dashed")),
  )
=== Module trust

Module này tách 2 loại điểm số vốn hay bị gộp làm một. Loại thứ nhất trả lời giao dịch
đã diễn ra thế nào: hai chiều, người mua chấm người bán và ngược lại, và ẩn cho tới khi
cả hai cùng nộp hoặc hết cửa sổ 14 ngày, cách duy nhất để một điểm số không mang
tính trả đũa. Loại thứ hai trả lời món hàng có đúng như mô tả không: một chiều, chỉ
người đã mua mới viết được. Một đơn hàng có thể sinh ra cả hai, nên nếu cộng chung vào một
cặp tổng thì chính đơn ấy đã bị đếm hai lần; vì vậy bản tổng hợp uy tín giữ hai cặp tổng
riêng biệt.

Thay đổi lớn nhất của module so với giai đoạn trước là không còn lớp tố cáo riêng. Mọi
thứ người dùng gửi lên, từ tố cáo một bài đăng cho tới đề xuất tính năng, đều là một
*phiếu hỗ trợ*, phân biệt bằng loại phiếu, vốn quyết định phiếu có trỏ vào một đối tượng
nào không và một lý do tố cáo có được phép đi kèm hay không. 7 trạng thái trải trên 3
bảng trước đây thực chất là cùng một vòng đời được viết ba lần, và một người dùng hỏi "yêu
cầu của tôi đang ở đâu" thì có ba nơi phải tìm.

#fig-xoay(
  [Sơ đồ lớp module tín nhiệm: đánh giá hai chiều, nhận xét bài đăng và phiếu hỗ trợ],
  spacing: (8mm, 7mm),

  cls((0, 0), "trustapi.Service", stereo: "cổng vào module", name: <t-svc>,
    ops: (
      "+ đánh giá hai chiều · công bố đến hạn",
      "+ nhận xét bài đăng · trả lời · bình chọn",
      "+ điểm uy tín · ghi kết cục đơn hàng",
      "+ phiếu hỗ trợ · nhận xử lý · giải quyết",
    )),

  cls((0, 1), "Ticket", stereo: "một bảng cho mọi loại", name: <t-tk>,
    attrs: (
      "- requesterID, assigneeID: *int64",
      "- kind: 11 giá trị, xem ghi chú",
      "- subject: string",
      "- refType: *string  7 giá trị,",
      "       6 trong số đó SUY RA từ kind",
      "- refID: *int64",
      "- reason: *string  chỉ với loại tố cáo",
      "- status: open | reviewing | resolved",
      "- conversationID: *int64 -> chat",
    ),
    ops: (
      "+ Resolved() bool",
      "+ Claim(moderatorID)",
      "+ Resolve(moderatorID, action, note)",
    )),

  cnote((0, 2), "11 loại phiếu, một bảng", (
    "5 loại tố cáo: bài đăng, tài khoản,",
    "tin nhắn, nhận xét, trả lời.",
    "6 loại còn lại: tranh chấp hoàn tiền,",
    "sự cố đơn, thanh toán, tài khoản,",
    "đề nghị tính năng, khác.",
    "Loại phiếu suy ra kiểu đối tượng bị",
    "nhắc tới, nên không thể khai lệch nhau.",
    "MỘT phiếu mở cho mỗi cặp người gửi và",
    "đối tượng; loại này không giải quyết",
    "bằng tay được, nên một phán quyết phải",
    "đóng MỌI phiếu về cùng đối tượng.",
  ), name: <t-n1>),

  cls((1, 0), "Feedback", stereo: "giấu kín tới ngày công bố", name: <t-fb>,
    attrs: (
      "- orderID: int64 -> order",
      "- raterID, rateeID: int64",
      "- direction: buyer-to-seller |",
      "             seller-to-buyer",
      "- rating: int16  (1..5)",
      "- comment: string",
      "- publishedAt: *time  NULL = còn ẩn",
    ),
    ops: (
      "+ Published() bool / Publish(at)",
      "+ RevealAt() *time",
    )),

  cls((1, 1), "Reputation", stereo: "bản tổng hợp", name: <t-rep>,
    attrs: (
      "- accountID: int64",
      "- role: seller | buyer",
      "- ratingSum, ratingCount     từ Feedback",
      "- reviewRatingSum,",
      "  reviewRatingCount          từ Review",
    ),
    ops: (
      "+ AverageRating() float64",
      "+ AverageReviewRating() float64",
    )),

  cls((1, 2), "OrderOutcome", stereo: "idempotency", name: <t-out>,
    attrs: (
      "- orderID: int64  (khóa chính)",
      "- completed: bool",
    )),

  cls((2, 0), "Review", name: <t-rev>,
    attrs: (
      "- listingID: int64 -> catalog",
      "- orderID: int64",
      "     không mua thì không viết được",
      "- authorID: int64",
      "- sellerID: int64  đóng băng lúc viết",
      "- rating: int16  (1..5)",
      "- body: string, attachments: []int64",
    ),
    ops: (
      "+ SetRating(r) / SetBody(b)",
      "+ MutableBy(accountID) bool",
    )),

  cls((2, 1), "ReviewVote", name: <t-vote>,
    attrs: (
      "- reviewID, accountID  (khóa chính)",
      "- vote: int16  âm một hoặc một,",
      "        không có giá trị không",
    )),

  cnote((2, 2), "Đồng bộ ngược sang danh mục", (
    "Điểm trung bình và số nhận xét của một",
    "bài đăng được danh mục giữ sẵn ở dạng",
    "đã tính.",
    "2 lược đồ khác nhau nên không JOIN",
    "được; module tín nhiệm tính lại rồi đẩy",
    "giá trị sang, chứ danh mục không đọc",
    "bảng của tín nhiệm.",
  ), name: <t-n2>),

  cnote((3, 0), "Ba luật của đánh giá", (
    "Chiều đánh giá SUY RA từ vai của người",
    "gửi trên chính đơn hàng ấy, không phải",
    "một trường máy khách gửi lên.",
    "Mỗi đơn, mỗi chiều đúng một đánh giá.",
    "Hai bên đều không thấy gì cho tới ngày",
    "công bố, nên không ai trả đũa được",
    "điểm của người kia.",
  ), name: <t-n3>),

  cls((3, 1), "ReviewReply", name: <t-rpl>,
    attrs: (
      "- reviewID: int64",
      "- authorID: int64",
      "- body: string",
    )),

  cnote((3, 2), "Phiếu nối ra ngoài module", (
    "-> chat     mỗi phiếu một luồng hội thoại",
    "-> account  người gửi và người xử lý",
    "<- order    leo thang hoàn tiền mở phiếu",
    "<- order    hết hạn xác nhận mở phiếu",
    "<- order    phán quyết ghi kết quả, đóng",
    "Ba mũi tên vào đều đi qua bus sự kiện,",
    "nên module đơn hàng không biết gì về",
    "sự tồn tại của phiếu hỗ trợ.",
  ), name: <t-n4>),

  edge(<t-svc>, <t-fb>, "-->", rel[điều phối]),
  edge(<t-svc>, <t-tk>, "-->", rel[điều phối]),
  edge(<t-fb>, <t-rep>, "-->", rel[cộng dồn khi công bố]),
  edge(<t-rev>, <t-rep>, "-->", rel[cộng dồn]),
  edge(<t-rev>, <t-rpl>, "-", rel[1 -> 0..\*  «composition»]),
  edge(<t-rev>, <t-vote>, "-", rel[1 -> 0..\*]),
  edge(<t-rep>, <t-out>, "-->", stroke: (dash: "dashed"), rel[chặn đếm hai lần]),
  edge(<t-fb>, <t-n3>, "-", stroke: (dash: "dashed")),
  edge(<t-rev>, <t-n2>, "-", stroke: (dash: "dashed")),
  edge(<t-tk>, <t-n1>, "-", stroke: (dash: "dashed")),
  edge(<t-tk>, <t-n4>, "-", stroke: (dash: "dashed")),
)

== Sơ đồ trình tự

=== Quy ước ký hiệu

Kịch bản được lập sơ đồ là kịch bản mà thiếu hình vẽ thì không theo dõi nổi: đặt hàng
và giữ escrow.

Mỗi cột là một bên tham gia: tác nhân là người thì ghi kèm dấu hai chấm ở đầu, còn lại là
module chịu trách nhiệm về phần nghiệp vụ ấy, trong đó module chủ đạo của kịch bản được tô
đậm. Activation bar (thanh kích hoạt) là đoạn dọc dày màu xám cho biết bên ấy đang giữ
quyền điều khiển.
Mũi tên nét liền là một lời gọi, mũi tên nét đứt là giá trị trả về hoặc một thông điệp bất
đồng bộ trên bus, hộp bo tròn là một mốc của durable workflow, hộp nền xám là một bước xử lý
bên trong một bên, hộp viền đứt là điều kiện của một nhánh, và luồng ngoại lệ được ghi ngay
trong nhãn hoặc trong khối ghi chú dưới hình. Nhãn được viết bằng lời chứ không bằng chữ ký
phương thức, để hình đọc được mà không phải mở mã nguồn.

=== TT-A: Đặt hàng và giữ escrow

Kịch bản bắt đầu khi người mua bấm mua và kết thúc khi đơn hàng tồn tại ở trạng thái chờ
người bán xác nhận. Ba quyết định thiết kế chi phối toàn bộ trình tự. Thứ nhất, quyền mua
được chiếm trước khi tiền được hỏi tới: lượt ghi hủy phiếu mua chính là hành động chiếm,
nên hai cú bấm liên tiếp chỉ mở được một phiên thanh toán; nếu chiếm sau, một thương vụ có
hai phiên đã trả tiền là khoản tiền mà escrow không hạch toán nổi. Thứ hai, phí vận
chuyển do máy chủ hỏi hãng vận chuyển, không bao giờ do máy khách gửi lên, và một người
bán chưa khai điểm lấy hàng sẽ làm hỏng lượt mua trước khi tiền bị thu. Thứ ba, chỉ
thông báo từ cổng thanh toán mới kết toán một chặng tiền: trang mà người mua rơi vào sau
khi trả tiền là thứ bất kỳ ai cũng giả mạo được.


#fig-xoay(
    [Sơ đồ trình tự TT-A: đặt hàng và mở phiên thanh toán],
    spacing: (48mm, 11mm),
    np((0, 0), [:Người mua]),
    ncore((1, 0), [Module\ Đơn hàng]),
    np((2, 0), [Module\ Kho hàng]),
    np((3, 0), [Module\ Tài chính]),
    np((4, 0), [Hãng\ vận chuyển]),
    ..lifelines(5, y1: 10.4),
    act(1, 0.6, 10.3), act(2, 2.7, 4.3), act(4, 4.7, 6.3), act(3, 6.7, 8.3),

    msg(0, 1, 1, [1. Bấm mua: gửi địa chỉ nhận, hãng\ vận chuyển và các dòng hàng đã chọn]),
    step(1, 2, [2. Chiếm phiếu mua bằng cách hủy phiếu,\ và chỉ hủy nếu phiếu chưa từng bị hủy]),
    msg(1, 2, 3, [3. Giữ chỗ tồn kho, lần lượt\ cho từng dòng hàng]),
    rmsg(2, 1, 4, [4. Đã giữ đủ chỗ (thiếu:\ nhả hết, dừng lượt mua)]),
    msg(1, 4, 5, [5. Hỏi phí vận chuyển theo\ điểm lấy hàng và điểm giao]),
    rmsg(4, 1, 6, [6. Trả về phí vận chuyển\ và ngày giao dự kiến]),
    msg(1, 3, 7, [7. Mở phiên thanh toán cho tiền\ hàng cộng phí vận chuyển]),
    rmsg(3, 1, 8, [8. Trả về mã phiên và số tiền phải trả;\ mã phiên gắn vào từng dòng hàng]),
    durable(1, 9, [9. Đặt hạn trả tiền: phiên tự hết\ hiệu lực sau 15 phút]),
    rmsg(1, 0, 10, [10. Trả về phiên thanh toán,\ danh sách hàng và phí]),
  )


2 kịch bản tiếp nối TT-A được mô tả bằng lời vì trình tự của chúng tuyến tính. Khi đơn
đã tồn tại, người bán có 48h để xác nhận, và cửa sổ ấy có 3 kết cục. Chấp
nhận thì mốc xác nhận được ghi và cam kết trước, rồi hãng vận chuyển mới được gọi theo
kiểu cố-gắng-hết-sức: tiền đã dịch chuyển rồi, nên một hãng không liên lạc được là một vận
đơn phải đặt lại chứ không phải một đơn hàng phải từ chối. Từ chối thì đơn bị hủy kèm lý
do bắt buộc và escrow được hoàn toàn bộ, kể cả phí vận chuyển. Im lặng hết giờ thì hệ
thống chỉ đóng một dấu hiệu đã leo thang và phát sự kiện để module tín nhiệm mở một phiếu
sự cố đơn. Sau khi kiện hàng tới nơi, người mua xác nhận đã nhận kèm bằng chứng mở hộp
được chốt ngay tại thời điểm đó chứ không bổ sung về sau, vì một yêu cầu hoàn tiền sẽ được
phán xử trên đúng những gì người mua trưng ra lúc mở hộp. Từ mốc ấy tiền nằm yên 72 giờ, rồi escrow chuyển sang phần khả dụng của người bán và thời điểm hoàn tất được ghi
lại như một dấu hiệu đã xong, khiến tập đơn cần thử lại đúng bằng tập đơn còn mắc kẹt.

nhà cung cấp khác, vì tính tiền qua một kênh tình cờ nằm trong bộ nhớ còn tệ hơn thất bại.