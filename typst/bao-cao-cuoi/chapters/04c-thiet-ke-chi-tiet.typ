#import "../../common/tokens.typ": *

// ------------------------------------------------------------
//  Hộp lớp UML 3 ngăn cho fletcher. Không phải design token nên không đưa
//  vào common/tokens.typ; đây là cùng một helper mà docs/typst/class_diagram.typ
//  dùng, giữ nguyên để hai tài liệu vẽ ra cùng một ký hiệu.
// ------------------------------------------------------------
//  Nội dung 2 ngăn dưới KHÔNG đặt bằng phông đơn cách. Không phông đơn cách nào có
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

Toàn bộ hệ thống có 45 bảng nghiệp vụ trải trên 7 lược đồ cơ sở dữ liệu, nên một sơ đồ lớp
duy nhất sẽ không đọc được. Phần này chia sơ đồ theo ranh giới module, cũng chính là ranh giới
lược đồ mà một module sẽ mang theo nếu về sau nó được tách sang cơ sở dữ liệu riêng. Bảy hình
dưới đây phủ 7 module nghiệp vụ, xếp theo thứ tự một lượt mua đi qua: định danh, hàng hoá, đơn
hàng, tiền, tín nhiệm, rồi tới 2 module hạ tầng là hội thoại và các thành phần dùng chung. Riêng module quan trắc không được vẽ ở đây: 4 kiểu dữ liệu của nó chỉ là dòng
mẫu ghi theo thời gian, không có quan hệ với nhau và cũng không có phương thức nghiệp vụ nào,
nên một sơ đồ lớp cho chúng không nói thêm được điều gì so với phần mô tả hạ tầng quan trắc.

Ký hiệu trong sơ đồ theo chuẩn UML. Khuôn chữ đặt giữa 2 dấu ngoặc nhọn kép là nhãn phân loại
lớp: «aggregate root» là gốc của một cụm phải nhất quán trong cùng một giao dịch, «value
object» là đối tượng không có định danh riêng và luôn sống kèm lớp chứa nó, «interface» là
giao diện mà tầng dưới phải hiện thực. Đường liền nét là quan hệ cấu trúc, ghi bản số ở hai
đầu; kèm thêm chữ «composition» khi phần con không thể tồn tại nếu thiếu phần cha. Đường nét
đứt là quan hệ phụ thuộc, tức bên này cần bên kia để làm việc nhưng không giữ tham chiếu bền
tới nó. Khung nét đứt bao quanh một nhóm lớp là ranh giới module, và các khối chữ nghiêng là
ghi chú thiết kế giải thích một quyết định không đọc được từ cấu trúc lớp.

#fig-xoay(
    [Sơ đồ lớp module `account`: định danh, hồ sơ và kênh thông báo],
    spacing: (9mm, 8mm),

    cls((0, 0), "accountapi.Service", stereo: "cổng vào module", name: <a-svc>,
      ops: (
        "+ đăng ký · đăng nhập · phiên",
        "+ hồ sơ · sổ địa chỉ · thiết bị",
        "+ xác minh danh tính",
        "+ thông báo · tuỳ chọn nhận",
      )),
    cls((0, 1), "port.Repository", stereo: "interface", name: <a-repo>,
      ops: ("+ đọc ghi mọi thực thể của lược đồ account",)),

    cls((1, 1), "Account", stereo: "aggregate root", name: <a-acc>,
      attrs: (
        "- id, version: int64",
        "- status: active | suspended | banned",
        "- role: user | moderator | admin",
        "- phone, email, username: *string",
        "  cả 3 đều tuỳ chọn, phải có ít nhất 1",
        "- passwordHash: *string  rỗng nếu chỉ",
        "  đăng nhập bằng định danh liên kết",
        "- suspendedUntil: *time",
      ),
      ops: (
        "+ HasIdentifier() / HasPassword() bool",
        "+ IsSuspended(now) bool",
        "+ Link(provider, uid) / MarkEmailVerified()",
      )),

    cls((1, 0), "Profile", stereo: "value object", name: <a-prof>,
      attrs: (
        "- name, country, locale, timezone",
        "- gender, dateOfBirth: *",
        "- avatarResourceID: *int64 -> common",
      )),

    cls((2, 0), "IdentityDocument", name: <a-id>,
      attrs: (
        "- docType, provider, providerRef",
        "- front/back/selfieResourceID: *int64",
        "- status: pending | verified | rejected",
        "- rejectionReason: *string",
        "- verifiedAt: *time",
      ),
      ops: ("+ Verify() / Reject(lý do)", "+ IsLive() bool", "+ Snapshot()")),

    cls((2, 1), "OAuthIdentity", name: <a-oa>,
      attrs: ("- provider, providerUID", "  MỘT tài khoản một nhà cung cấp")),

    cls((0, 2), "Contact", stereo: "sổ địa chỉ", name: <a-ct>,
      attrs: (
        "- fullName, phone, phoneVerified",
        "- addressType: giao hàng | lấy hàng",
        "- isDefaultDelivery, isDefaultPickup",
        "  mỗi loại nhiều nhất 1 mặc định",
        "- province/district/wardCode",
      )),

    cls((1, 2), "Device", name: <a-dv>,
      attrs: ("- platform, pushToken", "- lastSeenAt: time"),
      ops: ("+ Owns(accountID) bool",)),

    cls((2, 2), "Notification", name: <a-nt>,
      attrs: (
        "- category: đơn hàng | tiền | hệ thống",
        "- title, payload",
        "- readAt, scheduledAt: *time",
      )),

    cls((3, 2), "Preference", stereo: "khoá 3 cột", name: <a-pref>,
      attrs: ("- accountID, category, channel", "- isEnabled: bool")),

    edge(<a-svc>, <a-repo>, "-->", rel[dùng]),
    edge(<a-svc>, <a-acc>, "-->", rel[điều phối]),
    edge(<a-acc>, <a-prof>, "-", rel[1 -> 1  «composition»]),
    edge(<a-acc>, <a-id>, "-", rel[1 -> 0..\*]),
    edge(<a-acc>, <a-oa>, "-", rel[1 -> 0..\*]),
    edge(<a-acc>, <a-ct>, "-", rel[1 -> 0..\*]),
    edge(<a-acc>, <a-dv>, "-", rel[1 -> 0..\*]),
    edge(<a-acc>, <a-nt>, "-", rel[1 -> 0..\*]),
    edge(<a-nt>, <a-pref>, "-->", stroke: (dash: "dashed"), rel[lọc theo]),
  )

#fig-xoay(
    [Sơ đồ lớp module `catalog`: tin đăng, tuỳ chọn hàng và bản sửa chờ duyệt],
    spacing: (9mm, 8mm),

    cls((0, 0), "catalogapi.Service", stereo: "cổng vào module", name: <c-svc>,
      ops: (
        "+ đăng bán · sửa · gỡ tin",
        "+ tìm kiếm lai · gợi ý",
        "+ cây danh mục · nhãn",
        "+ giữ chỗ · nhả chỗ tồn kho",
      )),
    cls((0, 1), "port.Repository", stereo: "interface", name: <c-repo>,
      ops: ("+ đọc ghi mọi thực thể của lược đồ catalog",)),

    cls((1, 1), "Listing", stereo: "aggregate root", name: <c-lst>,
      attrs: (
        "- id, version: int64",
        "- sellerID, categoryID: int64",
        "- slug: string  duy nhất toàn sàn",
        "- status: draft | live | hidden |",
        "          pending | rejected",
        "- condition: mới | như mới | đã dùng",
        "- priceMode: giá cố định | trả giá",
        "- currency: mọi tuỳ chọn cùng loại tiền",
        "- cachedRating, cachedReviewCount",
        "  giá trị do module trust đẩy sang",
      ),
      ops: (
        "+ Publish() / Hide() / Approve()",
        "+ AddVariant() / RemoveVariant()",
        "+ ApplyPendingEdit()",
        "+ LiveVariants() []Variant",
      )),

    cls((1, 0), "Category", stereo: "cây tự quan hệ", name: <c-cat>,
      attrs: ("- parentID: *int64  rỗng là gốc", "- name duy nhất")),

    cls((2, 0), "PendingEdit", stereo: "value object", name: <c-edit>,
      attrs: (
        "- name, description, categoryID: *",
        "- condition, priceMode: *",
        "- specifications, attachments, tags",
        "  rỗng nghĩa là không có bản sửa chờ",
      ),
      ops: ("+ IsEmpty() bool", "+ Fields() []string")),

    cls((2, 1), "Variant", name: <c-var>,
      attrs: (
        "- price: int64",
        "- attributes, packageDetails",
        "- isFeatured: bool",
        "- deletedAt: *time  xoá mềm",
      ),
      ops: ("+ IsLive() bool",)),

    cls((3, 1), "Stock", stereo: "value object", name: <c-stk>,
      attrs: ("- quantity, reserved, sold: int64",),
      ops: ("+ Available() = quantity - reserved", "+ Committed() / SetQuantity()")),

    cls((0, 2), "Location", stereo: "value object", name: <c-loc>,
      attrs: ("- province/district/wardCode + Name", "- latitude, longitude: *float64"),
      ops: ("+ Geocoded() bool",)),

    cls((1, 2), "Tag", name: <c-tag>,
      attrs: ("- slug: string  khoá chính", "- description: *string")),

    cls((2, 2), "ListingSnapshot", stereo: "value object", name: <c-snap>,
      attrs: (
        "- bản chụp bất biến của tin đăng",
        "- module order giữ, không đọc ngược",
        "  về bảng của danh mục",
      )),

    edge(<c-svc>, <c-repo>, "-->", rel[dùng]),
    edge(<c-svc>, <c-lst>, "-->", rel[điều phối]),
    edge(<c-cat>, <c-lst>, "-", rel[1 -> 0..\*]),
    edge(<c-lst>, <c-edit>, "-", rel[1 -> 0..1  «composition»]),
    edge(<c-lst>, <c-var>, "-", rel[1 -> 1..\*  «composition»]),
    edge(<c-var>, <c-stk>, "-", rel[1 -> 1  «composition»]),
    edge(<c-lst>, <c-loc>, "-", rel[1 -> 0..1]),
    edge(<c-lst>, <c-tag>, "-", rel[0..\* -> 0..\*]),
    edge(<c-lst>, <c-snap>, "-->", stroke: (dash: "dashed"), rel[chụp lúc chốt mua]),
  )

#fig-xoay(
    [Sơ đồ lớp module `order`: từ giỏ hàng và thương lượng tới một đơn hàng],
    spacing: (8mm, 7mm),

    cls((0, 1), "orderapi.Service", stereo: "cổng vào module", name: <o-svc>,
      ops: (
        "+ giỏ hàng · phiếu mua · thương lượng",
        "+ đặt hàng · xác nhận · hủy",
        "+ hoàn tiền · phán quyết",
        "+ các phương thức đến hạn, đều idempotent",
      )),
    cls((0, 0), "port.Workflows", stereo: "interface", name: <o-wf>,
      ops: (
        "4 durable workflow: thanh toán, vòng đời",
        "đơn, hoàn tiền, thương lượng",
        "mọi lời gọi là best-effort",
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
      "Mỗi cặp người mua và biến thể chỉ có",
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
      "giờ cả 2 và không bao giờ không có.",
      "Ràng buộc duy nhất trên nguồn ấy chặn",
      "một lời gọi lại bị giao 2 lần sinh",
      "ra hai đơn, ngay tại tầng dữ liệu.",
    ), name: <o-n2>),

    edge(<o-cart>, <o-draft>, "-->", stroke: (dash: "dashed"), rel[nguồn để lập]),
    edge(<o-draft>, <o-snap>, "-->", rel[nội dung ảnh chụp]),
    edge(<o-draft>, <o-ord>, "-", rel[0..1 → 0..1]),
    edge(<o-offer>, <o-ord>, "-", rel[0..1 → 0..1]),
    edge(<o-ord>, <o-addr>, "-->", rel[đóng băng lúc mua]),
    edge(<o-ord>, <o-item>, "-", rel[1 → 1..\*]),
    edge(<o-offer>, <o-n1>, "-", stroke: (dash: "dashed")),
    edge(<o-item>, <o-n2>, "-", stroke: (dash: "dashed")),
  )

#fig-xoay(
    [Sơ đồ lớp module `finance`: phiên thanh toán, chặng tiền và sổ kép của ví],
    spacing: (8mm, 7mm),

    cls((0, 0), "financeapi.Service", stereo: "cổng vào module", name: <f-svc>,
      ops: (
        "+ phiên thanh toán · chặng · quyết toán",
        "+ ký quỹ: giữ · giải ngân · hoàn",
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
        "- heldBalance: int64       đang giữ ký quỹ",
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

#fig-xoay(
  [Sơ đồ lớp module `trust`: nhận xét tin đăng, điểm uy tín và phiếu hỗ trợ],
  spacing: (8mm, 7mm),

  cls((0, 0), "trustapi.Service", stereo: "cổng vào module", name: <t-svc>,
    ops: (
      "+ nhận xét tin đăng · trả lời · bình chọn",
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
    "5 loại tố cáo: tin đăng, tài khoản,",
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

  cls((1, 1), "Reputation", stereo: "bản tổng hợp", name: <t-rep>,
    attrs: (
      "- accountID: int64",
      "- role: seller | buyer",
      "- reviewRatingSum,",
      "  reviewRatingCount          từ Review",
    ),
    ops: (
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

  cnote((3, 0), "Đồng bộ ngược sang danh mục", (
    "Điểm trung bình và số nhận xét của một",
    "tin đăng được danh mục giữ sẵn ở dạng",
    "đã tính.",
    "2 lược đồ khác nhau nên không JOIN",
    "được; module trust tính lại rồi đẩy",
    "giá trị sang, chứ danh mục không đọc",
    "bảng của tín nhiệm.",
  ), name: <t-n2>),

  cls((3, 1), "ReviewReply", name: <t-rpl>,
    attrs: (
      "- reviewID: int64",
      "- authorID: int64",
      "- body: string",
    )),

  cnote((1, 0), "Phiếu nối ra ngoài module", (
    "-> chat     mỗi phiếu một luồng hội thoại",
    "-> account  người gửi và người xử lý",
    "<- order    leo thang hoàn tiền mở phiếu",
    "<- order    hết hạn xác nhận mở phiếu",
    "<- order    phán quyết ghi kết quả, đóng",
    "Ba mũi tên vào đều đi qua bus sự kiện,",
    "nên module order không biết gì về",
    "sự tồn tại của phiếu hỗ trợ.",
  ), name: <t-n4>),

  edge(<t-svc>, <t-tk>, "-->", rel[điều phối]),
  edge(<t-rev>, <t-rep>, "-->", rel[cộng dồn]),
  edge(<t-rev>, <t-rpl>, "-", rel[1 -> 0..\*  «composition»]),
  edge(<t-rev>, <t-vote>, "-", rel[1 -> 0..\*]),
  edge(<t-rep>, <t-out>, "-->", stroke: (dash: "dashed"), rel[chặn đếm 2 lần]),
  edge(<t-rev>, <t-n2>, "-", stroke: (dash: "dashed")),
  edge(<t-tk>, <t-n1>, "-", stroke: (dash: "dashed")),
  edge(<t-tk>, <t-n4>, "-", stroke: (dash: "dashed")),
)

#fig(
  [Sơ đồ lớp module `chat`: luồng trò chuyện và tin nhắn],
  spacing: (46mm, 15mm),

  cls((0, 0), "chatapi.Service", stereo: "cổng vào module", name: <k-svc>,
    ops: ("+ mở luồng · gửi tin · đánh dấu đã đọc", "+ sửa · thu hồi tin nhắn")),

  cls((1, 0), "Conversation", stereo: "aggregate root", name: <k-conv>,
    attrs: (
      "- kind: mua bán | phiếu hỗ trợ",
      "- ticketID: *int64 -> trust",
      "- accountAID, accountBID: int64",
      "- accountA/BReadAt: *time",
      "- lastMessageAt: time",
    ),
    ops: ("+ Involves(id) / Other(id)", "+ MarkRead(id, at)", "+ Counterparty(id)")),

  cls((2, 0), "Message", name: <k-msg>,
    attrs: (
      "- senderID: int64",
      "- type: chữ | ảnh | thẻ đề xuất giá",
      "- body, attachments, refs",
      "- card: nội dung thẻ đề xuất giá",
      "- editedAt, deletedAt: *time",
    ),
    ops: ("+ Edit() / Redact()", "+ IsLive() bool")),

  edge(<k-svc>, <k-conv>, "-->", rel[điều phối]),
  edge(<k-conv>, <k-msg>, "-", rel[1 -> 0..\*  «composition»]),
)

#fig(
  [Sơ đồ lớp module `common`: tệp tải lên, tuỳ chọn và nhật ký kiểm toán],
  spacing: (44mm, 14mm),

  cls((0, 1), "common.Service", stereo: "cổng vào dùng chung", name: <m-svc>,
    ops: ("+ xin chỗ tải lên · xác nhận tệp", "+ đọc sổ tuỳ chọn", "+ ghi nhật ký kiểm toán")),

  cls((1, 0), "Resource", stereo: "tệp tĩnh", name: <m-res>,
    attrs: (
      "- provider, objectKey, mime, size",
      "- checksum: *string",
      "- uploadedByID: *int64",
      "- url + urlExpiresAt  đường dẫn ký",
    )),

  cls((2, 0), "UploadSlot", stereo: "value object", name: <m-slot>,
    attrs: ("- resourceID, url, headers", "- expiresAt: time")),

  cls((1, 1), "Option", stereo: "sổ tra cứu", name: <m-opt>,
    attrs: (
      "- id: string  khoá chính dạng chữ",
      "- category: kênh tiền | hãng vận chuyển",
      "- ownerID: *int64  rỗng là của sàn",
      "- isEnabled, priority, provider, data",
    )),

  cls((1, 2), "AuditEntry", stereo: "chỉ thêm mới", name: <m-aud>,
    attrs: (
      "- table, recordID, changeType, code",
      "- changedBy: *int64",
      "- diff, snapshot",
    )),

  edge(<m-svc>, <m-res>, "-->", rel[quản lý]),
  edge(<m-res>, <m-slot>, "-->", rel[cấp chỗ ghi]),
  edge(<m-svc>, <m-opt>, "-->", rel[đọc]),
  edge(<m-svc>, <m-aud>, "-->", rel[ghi]),
)

=== Mô tả vắn tắt từng module

*Tài khoản.* Một tài khoản vừa mua vừa bán trên cùng một định danh, nên module không tách hai vai ở mức lớp. Cả 3 cách định danh gồm số điện thoại, thư điện tử và tên đăng nhập đều tuỳ chọn nhưng phải có ít nhất một, và mật khẩu được phép rỗng với tài khoản chỉ đăng nhập bằng định danh liên kết. Hồ sơ được gộp thẳng vào tài khoản thay vì tách bảng riêng vì hai thứ luôn được đọc cùng nhau.

*Danh mục.* Tin đăng là lời chào bán của một người bán chứ không phải một mục trong danh mục hàng chung, nên định danh người bán, tình trạng hàng và đường dẫn rút gọn đều nằm ngay trên nó. Bản sửa của người bán không ghi đè tin đang hiển thị mà nằm chờ ở một đối tượng giá trị riêng cho tới khi điều phối viên duyệt. Điểm trung bình và số nhận xét là giá trị do module tín nhiệm đẩy sang, danh mục chỉ đọc chứ không tự tính.

*Đơn hàng.* Đây là module dày quy tắc nhất và cũng là module duy nhất khai báo luồng bền. Đơn hàng ra đời khi tiền về chứ không do ai bấm nút phê duyệt, nên dòng hàng có thể tồn tại trước đơn. Người bán vẫn phải xác nhận, nhưng thứ họ xác nhận là việc gọi hãng vận chuyển chứ không phải tiền, vì tiền đã nằm trong ký quỹ từ trước. Trạng thái đơn được suy ra từ các mốc thời gian chứ không lưu thành cột riêng.

*Tài chính.* Mọi nguyên thuỷ tiền tệ nằm chung một module để các bước dịch chuyển ký quỹ giữ được tính nguyên tử. Ranh giới quan trọng nhất bên trong là hai sổ: một sổ ghi các chặng đi trên kênh thanh toán bên ngoài, sổ còn lại ghi mọi lần tiền dịch chuyển trong ví, và không bao giờ ghi cùng một lần dịch chuyển vào cả hai. Rút tiền không có bảng riêng mà là một phiên thanh toán mang loại khác, dùng lại đúng máy trạng thái đó.

*Hội thoại.* Một luồng chỉ có đúng hai bên, phân biệt bằng loại luồng là mua bán hay phiếu hỗ trợ. Mốc đã đọc lưu riêng cho từng bên nên số tin chưa đọc tính được mà không cần bảng phụ. Thẻ đề xuất giá là một loại tin nhắn chứ không phải một thực thể riêng, nhờ vậy lịch sử thương lượng nằm đúng trong dòng hội thoại.

*Tín nhiệm.* Điểm số trả lời câu hỏi món hàng có đúng mô tả không: một chiều, chỉ người đã mua mới viết được. Thay đổi lớn nhất so với giai đoạn trước là không còn lớp tố cáo riêng; mọi thứ người dùng gửi lên đều là một phiếu hỗ trợ, phân biệt bằng loại phiếu, và chính loại phiếu quyết định phiếu trỏ vào đối tượng nào.

*Dùng chung.* Ba nhóm phục vụ mọi module còn lại. Tệp tĩnh chỉ giữ đường dẫn tham chiếu và được cấp chỗ ghi qua đường dẫn ký có thời hạn. Sổ tuỳ chọn là bảng tra cứu cho các lựa chọn của một hạng mục như kênh tiền hay hãng vận chuyển. Nhật ký kiểm toán chỉ thêm mới, ghi lại mọi quyết định nghiệp vụ kèm người thực hiện.

== Sơ đồ trình tự

=== Quy ước ký hiệu

Mỗi cột là một bên tham gia: tác nhân là người thì ghi kèm dấu hai chấm ở đầu, còn lại là
module chịu trách nhiệm về phần nghiệp vụ ấy, trong đó module chủ đạo của kịch bản được tô
đậm. Activation bar (thanh kích hoạt) là đoạn dọc dày màu xám cho biết bên ấy đang giữ
quyền điều khiển.
Mũi tên nét liền là một lời gọi, mũi tên nét đứt là giá trị trả về hoặc một thông điệp bất
đồng bộ trên bus, hộp bo tròn là một mốc của durable workflow, hộp nền xám là một bước xử lý
bên trong một bên, hộp viền đứt là điều kiện của một nhánh, và luồng ngoại lệ được ghi ngay
trong nhãn hoặc trong khối ghi chú dưới hình. Nhãn được viết bằng lời chứ không bằng chữ ký
phương thức, để hình đọc được mà không phải mở mã nguồn.

=== TT-A: Đặt hàng và giữ ký quỹ

Kịch bản bắt đầu khi người mua bấm mua và dừng ở bước mở phiên thanh toán; phần thu tiền và
sinh đơn được mô tả bằng lời ngay sau hình. Ba quyết định thiết kế chi phối toàn bộ trình tự. Thứ nhất, quyền mua
được chiếm trước khi tiền được hỏi tới: lượt ghi hủy phiếu mua chính là hành động chiếm,
nên hai cú bấm liên tiếp chỉ mở được một phiên thanh toán; nếu chiếm sau, một thương vụ có
hai phiên đã trả tiền là khoản tiền mà ký quỹ không hạch toán nổi. Thứ hai, phí vận
chuyển do máy chủ hỏi hãng vận chuyển, không bao giờ do máy khách gửi lên, và một người
bán chưa khai điểm lấy hàng sẽ làm hỏng lượt mua trước khi tiền bị thu. Thứ ba, chỉ
thông báo từ cổng thanh toán mới kết toán một chặng tiền: trang mà người mua rơi vào sau
khi trả tiền là thứ bất kỳ ai cũng giả mạo được.


Hình vẽ dùng 5 đường sinh, lần lượt là người mua, module order, module finance, module
danh mục và hãng vận chuyển. Các bước có nền khác biệt là bước bền vững, tức bước được nền
tảng thực thi ghi vào nhật ký trước khi chạy, nên nếu máy chủ sập giữa trình tự thì lượt chạy
lại sẽ bỏ qua đúng những bước đã có kết quả. Thứ tự các bước trong hình vì thế không chỉ là
thứ tự thời gian mà còn là thứ tự phục hồi. Khung `alt` bao quanh bước 4 là chỗ duy nhất có hai
nhánh loại trừ nhau: giữ đủ chỗ thì lượt mua đi tiếp, thiếu chỗ ở bất kỳ dòng nào thì các chỗ
vừa giữ phải nhả lại hết, không có trạng thái giữ được một phần.

#fig-xoay(
    [Sơ đồ trình tự TT-A: đặt hàng và mở phiên thanh toán],
    spacing: (48mm, 11mm),
    np((0, 0), [:Người mua]),
    ncore((1, 0), [Module\ Đơn hàng]),
    np((2, 0), [Module\ Kho hàng]),
    np((3, 0), [Module\ Tài chính]),
    np((4, 0), [Hãng\ vận chuyển]),
    ..lifelines(5, y1: 11.7),
    act(1, 0.6, 11.6), act(2, 2.7, 5.4), act(4, 6.0, 7.6), act(3, 8.0, 9.6),

    msg(0, 1, 1, [1. Bấm mua: gửi địa chỉ nhận, hãng\ vận chuyển và các dòng hàng đã chọn]),
    step(1, 2, [2. Chiếm phiếu mua bằng cách hủy phiếu,\ và chỉ hủy nếu phiếu chưa từng bị hủy]),
    msg(1, 2, 3, [3. Giữ chỗ tồn kho, lần lượt\ cho từng dòng hàng]),
    // Khung alt: giữ chỗ tồn kho là chỗ duy nhất trong trình tự có nhánh loại trừ
    // nhau, và nhánh thiếu hàng phải nhả lại phần đã giữ nên không thể bỏ qua.
    ..khung("alt", 1, 2, 3.55, 5.75),
    dkien(1.5, 3.58, [giữ đủ chỗ cho mọi dòng hàng]),
    rmsg(2, 1, 4.05, [4a. Xác nhận đã giữ đủ chỗ]),
    ngan(1, 2, 4.75),
    dkien(1.5, 4.78, [thiếu chỗ ở ít nhất một dòng]),
    rmsg(2, 1, 5.3, [4b. Nhả lại các chỗ vừa giữ;\ lượt mua dừng tại đây]),
    msg(1, 4, 6.3, [5. Hỏi phí vận chuyển theo\ điểm lấy hàng và điểm giao]),
    rmsg(4, 1, 7.3, [6. Trả về phí vận chuyển\ và ngày giao dự kiến]),
    msg(1, 3, 8.3, [7. Mở phiên thanh toán cho tiền\ hàng cộng phí vận chuyển]),
    rmsg(3, 1, 9.3, [8. Trả về mã phiên và số tiền phải trả;\ mã phiên gắn vào từng dòng hàng]),
    durable(1, 10.3, [9. Đặt hạn trả tiền: phiên tự hết\ hiệu lực sau 15 phút]),
    rmsg(1, 0, 11.3, [10. Trả về phiên thanh toán,\ danh sách hàng và phí]),
  )
