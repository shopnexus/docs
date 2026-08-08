#import "../../common/tokens.typ": *

// ------------------------------------------------------------
//  Hộp lớp UML ba ngăn cho fletcher. Không phải design token nên không đưa
//  vào common/tokens.typ; đây là cùng một helper mà docs/typst/class_diagram.typ
//  dùng, giữ nguyên để hai tài liệu vẽ ra cùng một ký hiệu.
// ------------------------------------------------------------
//  Nội dung hai ngăn dưới KHÔNG đặt bằng phông đơn cách. Không phông đơn cách nào có
//  sẵn ở đây phủ hết chữ Việt: một nguyên âm mang cả dấu phụ lẫn dấu thanh — ề, ộ, ặ,
//  ữ — bị tách thành hai ký hiệu rời khi dựng chữ. Vì các ngăn này mang chú thích tiếng
//  Việt, phông thân bài được dùng thay, và ký hiệu mã nguồn vẫn đọc được bình thường.
#let boxline(x) = text(size: 6.8pt, font: font-quyen, x)

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

// Nhãn quan hệ cỡ nhỏ trên cạnh sơ đồ lớp
#let rel(t) = text(size: 6.6pt, t)

// Thanh kích hoạt (activation bar) trên một đường sinh của sơ đồ trình tự: một đoạn
// dọc dày đè lên đường sinh nét đứt, cho biết đối tượng đang giữ quyền điều khiển.
#let act(a, y1, y2) = edge((a, y1), (a, y2), "-", stroke: 4.5pt + rgb("#C4C4C4"))

// Chữ ký phương thức trên mũi tên. Đơn cách được ở đây vì chữ ký chỉ gồm ký tự ASCII.
#let sig(t) = text(size: 6.4pt, font: font-mono, t)

== Sơ đồ lớp chi tiết

=== Phạm vi, quy ước ký hiệu và cách đọc

Toàn bộ hệ thống có bốn mươi sáu bảng nghiệp vụ trải trên bảy lược đồ cơ sở dữ liệu,
chưa kể ba bảng dùng chung được áp vào sáu trong bảy lược đồ ấy — lược đồ quan trắc không
nhận chúng, vì nó chỉ chứa dữ liệu đo đạc, không có gì để kiểm toán và không nhận tệp. Một sơ đồ lớp duy nhất cho ngần ấy
lớp sẽ không đọc được và cũng không phản ánh đúng cách hệ thống được tổ chức, nên phần
này chia sơ đồ theo *ranh giới module* — cũng chính là ranh giới lược đồ, và cũng chính
là ranh giới mà một module sẽ mang theo nếu về sau nó được tách sang cơ sở dữ liệu
riêng. Mỗi module được trình bày bằng một đoạn văn nêu quyết định mô hình hóa đáng chú ý
nhất của nó, rồi tới sơ đồ lớp, và ở những chỗ hình vẽ không nói hết thì có thêm một ghi
chú ngắn.

Sau bảy sơ đồ theo mô-đun là một sơ đồ thứ tám cho *tầng bộ xử lý tuyến và các lớp truyền
dữ liệu*, tức tầng đứng ở biên HTTP; nó được tách riêng vì tuân theo một quy tắc ngược
hẳn — mọi lớp ở đó cố ý mỏng và cố ý giống hệt nhau. Khép lại mục là bốn bảng đối chiếu:
đặc tả trách nhiệm và bất biến của từng lớp, ánh xạ lớp miền sang bảng dữ liệu, ánh xạ lớp
truyền dữ liệu sang điểm cuối, và khuôn lắp ráp phụ thuộc.

Ký hiệu thống nhất cho cả tám sơ đồ. Mỗi hộp lớp gồm ba ngăn: tên lớp kèm khuôn mẫu đặt
giữa hai dấu ngoặc kép nhọn, ngăn thuộc tính, ngăn phương thức; thuộc tính riêng tư ghi
dấu trừ ở đầu, phương thức công khai ghi dấu cộng. Khuôn mẫu «aggregate root» đánh dấu
lớp là gốc tập hợp, nghĩa là chỉ nó được nạp và ghi như một khối, và mọi bất biến trải
rộng qua nó cùng các lớp con đều thuộc trách nhiệm của nó. Nét liền giữa hai lớp là quan
hệ nội module, có ràng buộc khóa ngoại thật trong tập lệnh định nghĩa dữ liệu, và bội số
được ghi ở hai đầu cạnh. Nét đứt kèm nhãn liên module là tham chiếu vượt lược đồ: trên
cơ sở dữ liệu nó chỉ là một số nguyên trần, không có khóa ngoại nào kiểm tra hộ, nên
tầng nghiệp vụ phải tự giữ tính toàn vẹn ấy. Mũi tên nét đứt hướng ra ngoài là quan hệ
phụ thuộc hoặc lời gọi, không phải quan hệ sở hữu.

Một quy ước đặt tên cần nói trước để tránh hiểu nhầm khi đối chiếu hình vẽ với cơ sở dữ
liệu: tên trường trong lớp miền không phải lúc nào cũng trùng tên cột. Chỗ nào lệch, sơ
đồ ghi cả hai; chỗ nào một khái niệm chỉ tồn tại ở tầng cột chứ không có mặt trong lớp
miền, sơ đồ ghi vào ngăn ghi chú thay vì bịa ra một thuộc tính không có thật.

=== Module quản lý tài khoản

Gốc tập hợp duy nhất của module là tài khoản cùng tập danh tính liên kết của nó. Lý do
ranh giới nằm đúng ở đó là một bất biến cụ thể: người dùng phải luôn còn ít nhất một
cách đăng nhập, mà quy tắc ấy trải qua cả mật khẩu lẫn danh sách nhà cung cấp đã liên
kết, nên hai thứ phải được nạp, kiểm và ghi cùng nhau. Sổ liên hệ, thiết bị nhận thông
báo đẩy và giấy tờ tùy thân đều mang định danh tài khoản nhưng *không* phải lớp con: mỗi
thứ có bất biến riêng không đụng tới gốc, và gộp tất cả vào một gốc sẽ khiến một thao
tác đổi tên hiển thị phải nạp cả sổ địa chỉ lẫn một bảng phân mảnh theo thời gian.

Phần hiển thị của tài khoản là một đối tượng giá trị chứ không phải một bảng: tên hiển
thị là bắt buộc, được ghi trong cùng câu lệnh chèn với chính tài khoản và được đọc bởi
mọi câu lệnh đọc, nên tách ra bảng riêng chỉ mua thêm một phép nối và một lượt ghi thứ
hai. Đổi lại, lớp giá trị vẫn giữ nguyên hình dạng của dữ liệu trả về cho máy khách.

#fig(
  [Sơ đồ lớp module quản lý tài khoản],
  spacing: (10mm, 7mm),

  cls((0, 0), "accountapi.Service", stereo: "interface", name: <a-svc>,
    ops: (
      "+ Register / Login / LoginOAuth",
      "+ Refresh / Logout / LogoutAll",
      "+ GetMe / UpdateMe / UpdateProfile / FindProfile",
      "+ ListContacts / CreateContact / UpdateContact",
      "+ GetPickupContact / GetDeliveryContact",
      "+ ListAdministrativeAreas",
      "+ RegisterDevice / ListDevices",
      "+ ListNotifications / MarkNotificationsRead",
      "+ Follow / Unfollow / GetSupportAccount",
      "+ StartIdentityVerification",
      "+ CreateUpload / ConfirmUpload",
      "+ AdminSuspendAccount / AdminCreateModerator",
      "+ AdminRecordIdentityVerdict",
      "  ... 51 phương thức",
    )),
  cls((2, 0), "port.Repository", stereo: "interface", name: <a-repo>,
    ops: (
      "+ Create / Get / Save",
      "+ GetByIdentifier / GetByEmail / GetByOAuth",
      "+ GetSupportAccount",
      "+ SearchAccounts / FindProfile / FindProfiles",
      "+ InsertContact / ListContacts",
      "+ UpsertDevice / ListDevices",
      "+ ListNotifications / CountUnreadNotifications",
      "+ SavePreferences",
      "+ InsertFollow / DeleteFollow",
      "+ InsertIdentityDocument / UpdateIdentityVerdict",
      "+ HasLiveVerifiedDocument / LiveVerifiedDocuments",
      "+ InsertAuditLog",
    )),
  edge(<a-svc>, <a-repo>, "-->", rel[dùng]),

  cls((1, 1), "Account", stereo: "aggregate root", name: <a-acc>,
    attrs: (
      "- id: int64",
      "- version: int64        // khóa lạc quan",
      "- status: Status        // active | suspended",
      "- role: Role            // user | moderator |",
      "                        // admin | support",
      "- phone, email, username: *string",
      "- passwordHash: *string",
      "- emailVerified: bool",
      "- suspendedUntil: *time",
      "- suspensionReason: *string",
      "- country, locale, timezone: string",
      "+ Profile: Profile           // lớp con",
      "+ Identities: []*OAuthIdentity  // lớp con",
      "- events: []Event",
    ),
    ops: (
      "+ Validate() error",
      "+ HasIdentifier() / HasPassword() bool",
      "+ SignInMethods() int",
      "+ IsSuspended(now) bool",
      "+ SetEmail / ClearEmail  (...Phone, ...Username)",
      "+ SetPassword / MarkEmailVerified",
      "+ Suspend(reason, until) / Reinstate()",
      "+ SetRole(role)",
      "+ Link(provider, uid) / Unlink(provider)",
      "+ Happened(code) bool",
      "+ Snapshot() AccountSnapshot",
      "+ Events() / ClearEvents()",
    )),
  edge(<a-svc>, <a-acc>, "-->", rel[điều phối]),
  edge(<a-repo>, <a-acc>, "-->", rel[nạp / ghi]),

  cls((0, 2), "OAuthIdentity", name: <a-oauth>,
    attrs: (
      "- id, accountID: int64",
      "- provider: string     // google | facebook | ...",
      "- providerUID: string  // không bao giờ là e-mail",
      "- createdAt: time",
    )),
  edge(<a-acc>, <a-oauth>, "-", rel[1 → 0..\*  «composition»]),

  cls((2, 2), "Profile", stereo: "value object", name: <a-prof>,
    attrs: (
      "- name, description: string",
      "- gender: *Gender, dateOfBirth: *date",
      "- avatarResourceID: *int64",
    ),
    ops: ("+ Validate() error",)),
  edge(<a-acc>, <a-prof>, "-", rel[1 → 1  «composition»]),

  cls((1, 2), "Contact", name: <a-contact>,
    attrs: (
      "- id, accountID: int64",
      "- fullName, phone: string",
      "- phoneVerified: bool",
      "- addressType: AddressType",
      "- isDefaultDelivery, isDefaultPickup: bool",
      "- country: string",
      "- provinceCode, districtCode, wardCode",
      "- provinceName, districtName, wardName",
      "- postalCode: string",
      "- providerCodes: jsonb  // mã vùng theo hãng vận chuyển",
      "- address, addressDetail: string",
      "- latitude, longitude: *float64",
    ),
    ops: ("+ Validate() error", "+ SetPhone(phone)")),
  edge(<a-acc>, <a-contact>, "-", rel[1 → 0..\*]),

  cls((0, 3), "Device", name: <a-dev>,
    attrs: (
      "- id, accountID: int64",
      "- platform: Platform  // ios | android | web",
      "- pushToken: string   // UNIQUE toàn cục",
      "- lastSeenAt: time",
    ),
    ops: ("+ TokenSuffix() string", "+ Owns(accountID) bool")),
  edge(<a-acc>, <a-dev>, "-", rel[1 → 0..\*]),

  cls((1, 3), "IdentityDocument", name: <a-kyc>,
    attrs: (
      "- id, accountID: int64",
      "- docType: DocType",
      "- provider, providerRef: string",
      "- status: IdentityStatus",
      "- rejectionReason: *string",
      "- frontResourceID: *int64",
      "- backResourceID: *int64",
      "- selfieResourceID: *int64",
      "- verifiedAt, expiresAt: *time",
      "- createdAt: time",
    ),
    ops: (
      "+ IsLive(now) bool",
      "+ Verify(now, expiresAt)",
      "+ Reject(reason)",
      "+ Snapshot()",
    )),
  edge(<a-acc>, <a-kyc>, "-", rel[1 → 0..\*]),

  cls((2, 3), "Notification", stereo: "hypertable", name: <a-noti>,
    attrs: (
      "- id, accountID: int64",
      "- category: Category",
      "- title: string, payload: jsonb",
      "- createdAt: time  // khóa phân mảnh",
      "- readAt, scheduledAt: *time",
    )),
  edge(<a-acc>, <a-noti>, "-", rel[1 → 0..\*]),

  cls((0, 4), "Preference", name: <a-pref>,
    attrs: (
      "- accountID: int64   (khóa chính)",
      "- category: Category (khóa chính)",
      "- channel: Channel   (khóa chính)",
      "- isEnabled: bool",
    )),
  edge(<a-acc>, <a-pref>, "-", rel[1 → 0..\*  (thưa)]),

  cls((1, 4), "EffectivePreference", stereo: "value object", name: <a-eff>,
    attrs: (
      "- category: Category, channel: Channel",
      "- isEnabled: bool   // đã phân giải mặc định",
    )),
  edge(<a-pref>, <a-eff>, "-->", rel[phân giải mặc định]),

  cls((2, 4), "Follow", name: <a-follow>,
    attrs: ("- followerID, followeeID: int64  (khoa chinh)", "- createdAt: time")),
  edge(<a-acc>, <a-follow>, "-", rel[0..\* ↔ 0..\*]),

  cls((1, 5), "Event", stereo: "domain event", name: <a-evt>,
    attrs: ("- code: EventCode", "- payload: struct co the json"),
    ops: (
      "  EmailChanged  PhoneChanged  UsernameChanged",
      "  PasswordChanged  EmailVerified",
      "  Suspended  Reinstated",
      "  RoleGranted  RoleRevoked",
      "  IdentityLinked  IdentityUnlinked  IdentityVerdict",
    )),
  edge(<a-acc>, <a-evt>, "-->", rel[phát sinh, ghi cùng giao dịch]),
)

#note[
  Vai trò của tài khoản có bốn giá trị chứ không phải ba. Giá trị thứ tư là *bàn hỗ trợ*,
  và điều đáng chú ý ở tầng lớp là nó không phải một khái niệm riêng: bàn hỗ trợ là một
  thể hiện bình thường của chính lớp tài khoản, chỉ khác ở giá trị vai trò và ở chỗ nó cố
  ý không có mật khẩu lẫn liên kết nhà cung cấp. Nhờ vậy nó làm được phía đối diện của mọi
  cuộc hội thoại phiếu hỗ trợ mà không cần thêm một lớp nào, cũng không cần một cột tham
  gia cho phép rỗng trong lớp hội thoại. Lý do nhận diện bằng vai trò chứ không bằng tên
  đăng nhập đã được trình bày ở phần thiết kế bảo mật.
]

=== Module danh mục hàng hóa

Bài đăng là gốc tập hợp: biến thể, ảnh, từ khóa và bản sửa chờ duyệt được nạp và ghi
cùng nó dưới một khóa lạc quan. Điểm cần nhấn mạnh là tồn kho *không* phải một thực thể
có định danh riêng ở tầng miền — nó là một đối tượng giá trị nhúng ngay trong biến thể,
gồm ba bộ đếm số lượng, đang giữ chỗ và đã bán; ở tầng cột thì đó là một bảng khóa theo
biến thể, tách ra vì con số đang giữ chỗ biến động theo từng lượt thanh toán còn dòng
biến thể chỉ đổi khi người bán sửa bài.

Một bài đăng ở đây là *lời chào bán của một người bán cụ thể*, không phải một mục trong
danh mục sản phẩm dùng chung: hai người bán cùng một mẫu điện thoại là hai dòng độc lập.
Bên cạnh đó, ba lớp trong module mang bản sao véc-tơ phục vụ tìm kiếm; dấu hiệu cũ dữ
liệu của chúng chỉ tồn tại ở tầng cột, do một tiến trình riêng đọc và xóa, nên sơ đồ ghi
điều đó vào ngăn ghi chú thay vì gắn thành thuộc tính của lớp miền.

#fig(
  [Sơ đồ lớp module danh mục hàng hóa],
  spacing: (10mm, 7mm),

  cls((0, 0), "catalogapi.Service", stereo: "interface", name: <c-svc>,
    ops: (
      "+ ListListings / GetListing / CreateListing",
      "+ UpdateListing / DeleteListing",
      "+ PublishListing / HideListing",
      "+ SuggestListing   // AI điền sẵn một biểu mẫu",
      "+ CreateVariant / UpdateVariant / DeleteVariant",
      "+ ListCategories / ListTags",
      "+ AddFavorite / RemoveFavorite",
      "+ ReserveStock / ReleaseStock",
      "+ CommitStock / UncommitStock",
      "+ CreateUpload / ConfirmUpload",
      "+ AdminApproveListing / AdminTakedownListing",
      "+ AdminCreateCategory / AdminUpdateCategory",
      "+ AdminPutTag / AdminDeleteTag / AdminListListings",
      "+ SyncListingRating",
      "  ... 30 phương thức",
    )),
  cls((2, 0), "port.Repository", stereo: "interface", name: <c-repo>,
    ops: (
      "+ CreateListing / GetListing / SaveListing",
      "+ GetListingForSeller / SoftDeleteListing",
      "+ ListListings / ListModerationQueue",
      "+ SeedVectors / NearestCategories / NearestTags",
      "+ InterestVectors / FavoritedAmong",
      "+ ReserveStock / ReleaseStock",
      "+ CommitStock / UncommitStock / FindStock",
      "+ SetCachedRating",
    )),
  edge(<c-svc>, <c-repo>, "-->", rel[dùng]),

  cls((1, 1), "Listing", stereo: "aggregate root", name: <c-lst>,
    attrs: (
      "- id, version: int64",
      "- slug: string  // duy nhất toàn cục",
      "- sellerID: int64    // cột: account_id, cross-ref",
      "- categoryID: int64",
      "- status: Status  // draft|pending|active|hidden",
      "- name, description: string",
      "- specifications: jsonb",
      "- attachments: []int64  // ảnh đầu là ảnh bìa",
      "- priceMode: PriceMode, condition: Condition",
      "- currency: string  // ISO 4217",
      "- location: *Location",
      "- pendingEdit: *PendingEdit",
      "- cachedRating, cachedReviewCount, cachedSold",
      "- takenDownAt: *time, takedownReason: *string",
      "- deletedAt, embeddingStaleAt: *time",
      "+ Variants: []*Variant   // lớp con",
      "+ Tags: []string         // lớp con",
    ),
    ops: (
      "+ Validate() error",
      "+ LiveVariants() []*Variant",
      "+ Publish() / Approve(note) / Hide()",
      "+ Takedown(reason, notifySeller)",
      "+ SubmitEdit(edit) / ApplyPendingEdit()",
      "+ AddVariant(v) / RemoveVariant(id)",
      "+ SetFeatured(id) / Featured() *Variant",
      "+ Snapshot() ListingSnapshot",
      "+ Events() / ClearEvents()",
    )),
  edge(<c-svc>, <c-lst>, "-->", rel[điều phối]),
  edge(<c-repo>, <c-lst>, "-->", rel[nạp / ghi]),

  cls((0, 1), "Category", name: <c-cat>,
    attrs: (
      "- id: int64",
      "- parentID: *int64  // NULL = gốc; tự quan hệ",
      "                    // 0..1 cha -> 0..* con",
      "- name: string  // UNIQUE",
      "- description: string",
      "  (dấu hiệu cũ dữ liệu chỉ có ở cột)",
    ),
    ops: ("+ Validate() error",)),
  edge(<c-cat>, <c-lst>, "-", rel[1 → 0..\*]),

  cls((2, 1), "PendingEdit", stereo: "value object", name: <c-edit>,
    attrs: ("- (tap con cac truong sua duoc cua Listing)",),
    ops: ("+ Fields() []string", "+ IsEmpty() bool")),
  edge(<c-lst>, <c-edit>, "-->", rel[0..1]),

  cls((1, 2), "Variant", name: <c-var>,
    attrs: (
      "- id, listingID: int64",
      "- price: int64  // đơn vị tiền nhỏ nhất",
      "- attributes: jsonb  // {size, color, ...}",
      "- packageDetails: jsonb  // khối lượng, kích thước",
      "- attachments: []int64",
      "- isFeatured: bool  // <= 1 mỗi listing",
      "- deletedAt: *time",
      "+ Stock: Stock   // nhúng theo giá trị",
    ),
    ops: ("+ Validate() error", "+ IsLive() bool")),
  edge(<c-lst>, <c-var>, "-", rel[1 → 1..\*  «composition»]),

  cls((2, 2), "Stock", stereo: "value object", name: <c-stk>,
    attrs: (
      "- quantity: int64",
      "- reserved: int64  // đang giữ chỗ, trả lại khi hủy",
      "- sold: int64      // chỉ tăng",
      "  (cột: bảng stock khóa theo variant_id)",
    ),
    ops: (
      "+ Available() int64",
      "+ Committed() int64",
      "+ SetQuantity(q)",
      "  CHECK reserved + sold <= quantity",
    )),
  edge(<c-var>, <c-stk>, "-", rel[1 → 1  «composition»]),

  cls((0, 2), "Location", stereo: "value object", name: <c-loc>,
    attrs: (
      "- provinceCode, provinceName: string",
      "- districtCode, districtName: string",
      "- wardCode, wardName: string",
      "- latitude, longitude: *float64",
      "  (cột: location geography(Point,4326))",
    ),
    ops: ("+ Geocoded() bool",)),
  edge(<c-lst>, <c-loc>, "-", rel[0..1]),

  cls((0, 3), "Tag", name: <c-tag>,
    attrs: ("- slug: string  // khoa tu nhien, cot la tag.id", "- description: *string")),
  cls((0, 4), "ListingTag", stereo: "association", name: <c-ltag>,
    attrs: ("- listingID: int64", "- tag: string")),
  edge(<c-lst>, <c-ltag>, "-", bend: 30deg, rel[1 → 0..\*]),
  edge(<c-tag>, <c-ltag>, "-", rel[1 → 0..\*]),

  cls((1, 3), "StockMovement", stereo: "idempotency", name: <c-mov>,
    attrs: (
      "- key: string  // 'order:41:item:88:commit'",
      "- variantID: int64, units: int64",
    )),
  edge(<c-stk>, <c-mov>, "-->", rel[ghi cùng giao dịch]),

  cls((2, 3), "Favorite", stereo: "wishlist", name: <c-fav>,
    attrs: (
      "- accountID: int64  // cross-ref, không FK",
      "- listingID: int64  // khóa chính là cặp",
      "- createdAt: time",
    )),
  edge(<c-lst>, <c-fav>, "-", rel[1 → 0..\*]),

  cls((1, 4), "ListingEmbedding", stereo: "pgvector", name: <c-emb>,
    attrs: (
      "- listingID: int64",
      "- dense: vector(1024)       // BGE-M3, cosine",
      "- sparse: sparsevec(250048) // <= 1000 phần tử",
    )),
  edge(<c-lst>, <c-emb>, "-", rel[1 → 0..1]),

  cls((2, 4), "CategoryEmbedding / TagEmbedding", stereo: "pgvector", name: <c-emb2>,
    attrs: ("- dense: vector(1024)", "- sparse: sparsevec(250048)", "- chi muc HNSW")),
  edge(<c-cat>, <c-emb2>, "-", rel[1 → 0..1]),

  cls((1, 5), "Event", stereo: "domain event", name: <c-evt>,
    attrs: ("- code: EventCode", "- payload: struct co the json"),
    ops: (
      "  listing.publish  listing.approve",
      "  listing.takedown  listing.hide",
      "  listing.edit_submitted  listing.delete",
      "  listing.variant_added  listing.variant_removed",
    )),
  edge(<c-lst>, <c-evt>, "-->", rel[phát sinh]),

  cls((0, 5), "AccountInterest", name: <c-int>,
    attrs: (
      "- accountID: int64, slot: int16",
      "- dense: vector(1024)",
      "- strength: float32",
      "  không đánh chỉ mục véc-tơ ở đây",
    )),
)

#note[
  Ba lớp mang véc-tơ trong module này được nuôi bởi một *hàng đợi là thuộc tính của dữ
  liệu* chứ không phải một thông điệp ai đó phải giữ cho khỏi mất: mỗi lượt ghi làm thay
  đổi nội dung của một dòng sẽ đóng dấu thời gian cũ dữ liệu lên chính dòng ấy, và chỉ
  tiến trình làm giàu véc-tơ mới được xóa dấu. Nhờ vậy một dòng bị sửa đúng lúc đang
  triển khai phiên bản mới vẫn còn nằm trong hàng đợi sau khi triển khai xong, và một
  lượt chạy lặp lại thì không tìm thấy gì để làm. Thuật toán rút hàng đợi được đặc tả
  đầy đủ ở mục #ref(<tt-nhung>).
]

=== Module đơn hàng

Đây là module dày quy tắc nhất và cũng là module duy nhất có khai báo quy trình bền. Cần
nói rõ ngay hai điều, vì cả hai đều đảo ngược cách hiểu thông thường về một sàn giao
dịch. Thứ nhất, *đơn hàng ra đời khi tiền về*, do thông báo từ cổng thanh toán chứ không
do ai bấm nút phê duyệt; đó là lý do dòng hàng đã mua có thể tồn tại trước khi đơn hàng
tồn tại, và mối liên kết giữa chúng là một danh sách chờ ghép chứ không phải một hộp thư
chờ duyệt. Thứ hai, *người bán vẫn phải xác nhận*, nhưng thứ họ xác nhận không phải là
tiền: tiền đã nằm trong ký quỹ rồi, và cái mà lượt xác nhận ấy mở khóa là việc gọi hãng
vận chuyển. Một bài đăng có tồn kho sai, hay một người bán đã bỏ nghề, nếu không có bước
này thì chỉ bị phát hiện bởi người mua ngồi chờ một kiện hàng không ai gửi.

Trạng thái của đơn hàng có bốn giá trị và *được suy ra* từ các mốc thời gian kết quả chứ
không lưu thành một cột riêng, theo thứ tự xét: đã hủy, hoàn thành, chờ người bán xác
nhận, và đang mở. Cách này bỏ đi hẳn một dữ kiện phải giữ cho đồng bộ với các dữ kiện
khác, đổi lại câu hỏi "đơn nào đang mở của tôi" trở thành một lượt tra chỉ mục thay vì
một phép nối ba bảng. Người bán im lặng quá bốn mươi tám giờ thì bộ phận vận hành được
nhắc đi giục — nền tảng *không* tự hủy đơn và cũng *không* tự gửi hàng thay người bán,
vì cả hai đều là quyết định thay mặt một bên bằng tiền của bên kia.

#fig(
  [Sơ đồ lớp module đơn hàng: điều phối, vòng đời đơn và vận đơn],
  spacing: (10mm, 7mm),

  cls((0, 0), "orderapi.Service", stereo: "interface", name: <o-svc>,
    ops: (
      "+ ListCartItems / AddCartItem / ...",
      "+ CreateDraft / Checkout / CancelDraft",
      "+ ShippingQuotes / ListItems / CancelItem",
      "+ CreateOffer / CounterOffer / AcceptOffer",
      "+ CheckoutOffer",
      "+ ListOrders / GetOrder / GetOrderSummary",
      "+ ConfirmOrder / DeclineOrder / CancelOrder",
      "+ ConfirmReceipt / GetOrderTransport",
      "+ AdvanceShipment / RecordCarrierCheckpoint",
      "+ CreateRefund / WithdrawRefund / AcceptRefund",
      "+ AddRefundAttachments / AdvanceReturnShipment",
      "+ EscalateRefund / AdminResolveRefund",
      "+ GetOrderCase / SettlePaidSession",
      "+ ExpireDrafts / ExpireOffers / ExpireCheckouts",
      "+ ReleaseDuePayouts / RetryClaimedPayouts",
      "+ AdvanceOverdueRefunds",
      "+ EscalateUnconfirmedOrders",
    )),
  cls((1, 0), "port.Workflows", stereo: "interface", name: <o-wf>,
    ops: (
      "+ StartCheckout / CheckoutPaid",
      "+ CheckoutCancelled",
      "+ StartOffer",
      "+ StartOrder / OrderConfirmed",
      "+ OrderReceived / OrderCancelled",
      "+ RefundRaised / RefundResolved",
      "+ StartRefundWindow",
      "  4 quy trình bền:",
      "  OrderCheckout - OrderLifecycle",
      "  OrderRefund   - OrderOffer",
      "  mọi lời gọi đều là best-effort",
    )),
  cls((2, 0), "port.Repository", stereo: "interface", name: <o-repo>,
    ops: (
      "+ UpsertCartItem / ListCartItems",
      "+ InsertDraft / ExpiredDrafts",
      "+ InsertOffer / FindActiveOffer / ExpiredOffers",
      "+ ClaimOfferCheckout / ReleaseOfferCheckout",
      "+ InsertItems / ItemsByPaymentSession",
      "+ CreateOrder / LinkItems / FindOrderByOrigin",
      "+ UnconfirmedOrders",
      "+ InsertTransport / BookTransport",
      "+ UnbookedTransports / FindTransportByRef",
      "+ PayoutDue / ClaimPayout / ClaimedPayouts",
      "+ MarkPayoutReleased",
      "+ InsertRefund / LiveRefundOnOrder",
      "+ SaveRefund / SaveRefundOutcome / OverdueRefunds",
    )),
  edge(<o-svc>, <o-wf>, "-->", rel[khởi động]),
  edge(<o-svc>, <o-repo>, "-->", rel[dùng]),

  cls((0, 1), "CartItem", name: <o-cart>,
    attrs: (
      "- id, accountID: int64",
      "- listingID, variantID: int64  // cross-ref",
      "- quantity: int64",
    ),
    ops: ("+ SetQuantity(q)",)),

  cls((1, 1), "Draft", stereo: "đóng băng điều khoản", name: <o-draft>,
    attrs: (
      "- id, buyerID, listingID: int64",
      "+ Snapshot: ListingSnapshot",
      "- validUntil: time, cancelledAt: *time",
    ),
    ops: (
      "+ Live(now) bool",
      "+ Cancel()",
      "+ Variant(variantID) (VariantSnapshot, error)",
      "+ EncodeSnapshot() ([]byte, error)",
    )),

  cls((2, 1), "Offer", stereo: "thương lượng giá", name: <o-offer>,
    attrs: (
      "- id, listingID, variantID: int64",
      "- authorID  // bên đang giữ đề nghị",
      "- buyerID, sellerID: int64",
      "- status: active | accepted |",
      "          checked-out | cancelled",
      "- quantity, total: int64, reason: string",
      "- paymentSessionID: *int64",
      "- expiresAt: time",
    ),
    ops: (
      "+ Live(now) / Involves(accountID) bool",
      "+ Counter(actor, qty, total, reason, now, w)",
      "+ Accept(actorID, now, window)",
      "+ CheckoutBy(actorID, now) error",
      "+ CheckOut() / Cancel(actorID) / Expire()",
      "  UNIQUE 1 offer active / (buyer, variant)",
      "  12 giờ thương lượng - 30 phút sau khi chốt",
    )),

  cls((1, 2), "Order", stereo: "aggregate root", name: <o-ord>,
    attrs: (
      "- id: int64",
      "- draftID XOR offerID: *int64  // đúng một nguồn",
      "- buyerID, sellerID: int64",
      "- transportID: int64  // UNIQUE",
      "+ Address, PickupAddress: AddressSnapshot",
      "- confirmedAt: *time",
      "- confirmationEscalatedAt: *time",
      "- declineReason: *string",
      "- receivedAt: *time",
      "- receiptAttachments: []int64  // bằng chứng mở hộp",
      "- payoutReleasedAt: *time",
      "- createdAt, completedAt, cancelledAt: *time",
    ),
    ops: (
      "+ State() string  // awaiting-confirmation |",
      "                  // open | completed | cancelled",
      "+ Settled() bool",
      "+ Confirm() / Decline(reason)",
      "+ EscalateConfirmation()",
      "+ Confirmed() bool / ConfirmationDue() *time",
      "+ ConfirmReceipt(attachments)",
      "+ PayoutDue() *time  // +72h sau khi nhận",
      "+ MarkPayoutReleased() / Cancel(shipped bool)",
      "+ Involves(accountID) bool",
      "  cửa sổ xác nhận của người bán: 48 giờ",
    )),
  edge(<o-draft>, <o-ord>, "-", rel[0..1 → 0..1]),
  edge(<o-offer>, <o-ord>, "-", rel[0..1 → 0..1]),

  cls((0, 2), "Item", name: <o-item>,
    attrs: (
      "- id: int64, orderID: *int64  // NULL tới khi tiền về",
      "- draftID XOR offerID: *int64",
      "- buyerID, sellerID: int64",
      "- listingID, variantID: int64  // cross-ref",
      "+ Address: AddressSnapshot",
      "- note: string",
      "- quantity, totalAmount: int64",
      "- currency, transportOption: string",
      "- paymentSessionID: int64  // cross-ref finance",
      "- cancelledAt: *time, cancelledByID: *int64",
    ),
    ops: ("+ Live() bool", "+ Cancel(actorID)")),
  edge(<o-ord>, <o-item>, "-", rel[1 → 1..\*]),

  cls((2, 2), "Transport", name: <o-tr>,
    attrs: (
      "- id: int64",
      "- option: string  // slug hãng vận chuyển",
      "- fee: int64      // tiền của hãng, không vào ký quỹ",
      "- status: pending | picked-up | in-transit |",
      "          delivered | returned | failed",
      "- data: jsonb  // mã vận đơn của hãng",
    ),
    ops: (
      "+ Booked() bool   // đã có mã vận đơn",
      "+ Shipped() / Delivered() / Settled() bool",
      "+ Advance(status) error  // chỉ tiến, không lùi",
    )),
  edge(<o-ord>, <o-tr>, "-", rel[1 → 1]),

  cls((0, 3), "AddressSnapshot", stereo: "value object", name: <o-addr>,
    attrs: (
      "- fullName, phone, country: string",
      "- provinceCode, wardCode: string",
      "- districtCode: *string",
      "- addressDetail: *string",
    )),
  edge(<o-ord>, <o-addr>, "-->", rel[đóng băng lúc mua]),

  cls((1, 3), "Origin", stereo: "value object", name: <o-org>,
    attrs: ("- draftID: *int64", "- offerID: *int64"),
    ops: ("+ Valid() bool  // dung mot trong hai",)),
  edge(<o-ord>, <o-org>, "-->", rel[dùng]),

  cls((2, 3), "ListingSnapshot / VariantSnapshot", stereo: "value object", name: <o-snap>,
    attrs: (
      "- listingID, sellerID, name, currency",
      "- priceMode: string",
      "- variants: []VariantSnapshot",
      "    variantID, price",
      "    attributes, packageDetails",
    )),
  edge(<o-draft>, <o-snap>, "-->", rel[nội dung ảnh chụp]),
)

#fig(
  [Sơ đồ lớp module đơn hàng: hoàn tiền và đường dẫn tới phiếu hỗ trợ],
  spacing: (13mm, 8mm),

  cls((0, 0), "Refund", stereo: "state machine", name: <r-ref>,
    attrs: (
      "- id, buyerID, orderID: int64",
      "- reason: string, attachments: []int64",
      "- status: awaiting-seller-review | disputed |",
      "          returning | returned |",
      "          accepted | rejected | cancelled",
      "- deadlineAt: *time  // chỉ ở hai trạng thái có đồng hồ",
      "- sellerDecidedAt: *time",
      "- returnTransportID: *int64",
      "- returnedAt: *time",
      "- createdAt: time",
    ),
    ops: (
      "+ Settled() bool",
      "+ Withdraw()            // người mua rút",
      "+ Accept()              // người bán đồng ý",
      "+ EscalateUnanswered()  // hết 48 giờ, không trả lời",
      "+ Escalate()            // người bán đưa lên nhân viên",
      "+ StartReturn(transportID)",
      "+ MarkReturned()        // người bán xác nhận đã nhận",
      "+ ClaimReturned()       // người mua khai đã trả",
      "+ Settle()              // kết toán cho người mua",
      "+ Resolve(buyerWins)    // phán quyết của nhân viên",
      "+ AddAttachments(a)",
      "  48 giờ xem xét - 48 giờ kiểm hàng trả",
      "  luôn hoàn toàn bộ đơn, không có số tiền riêng",
    )),
  cls((1, 0), "Order", stereo: "aggregate root", name: <r-ord>,
    attrs: ("- id, buyerID, sellerID: int64", "- ... (xem so do truoc)"),
    ops: ("+ State() / Settled()",)),
  edge(<r-ord>, <r-ref>, "-", rel[1 → 0..\*  (≤ 1 đang mở)]),

  cls((2, 0), "Transport", name: <r-tr>,
    attrs: ("- id, option, status", "- fee: int64  // chang tra hang co phi bang 0")),
  edge(<r-ref>, <r-tr>, "-", rel[0..1 → 1  chặng trả hàng]),

  cls((1, 1), "Event", stereo: "domain event", name: <r-evt>,
    attrs: (
      "order.placed         order.settled",
      "order.refund_escalated",
      "order.refund_resolved",
      "order.confirmation_lapsed",
    ),
    ops: ("  phat qua eventbus.Client (Redis Streams)",)),
  edge(<r-ref>, <r-evt>, "-->", rel[phát sinh]),
  edge(<r-ord>, <r-evt>, "-->"),

  cls((0, 2), "trust.Ticket", stereo: "cross-module", name: <r-tk>,
    attrs: (
      "kind = 'refund-dispute' | 'order-issue'",
      "mở bởi trust khi nghe sự kiện trên bus;",
      "không còn bảng tranh chấp nào trong order.",
    )),
  edge(<r-evt>, <r-tk>, "-->", stroke: (dash: "dashed"), rel[qua bus, không khóa ngoại]),

  cls((2, 2), "(liên module)", stereo: "cross-ref", name: <r-x>,
    attrs: (
      "-> finance.payment_session  (paymentSessionID)",
      "-> finance: khóa 'order:N:hold' | ':release'",
      "                            | ':refund'",
      "-> catalog.listing / variant",
      "-> account.account          (buyerID, sellerID)",
      "-> common.resource          (attachments[])",
      "-> common.option            (transportOption)",
    )),
  edge(<r-ord>, <r-x>, "-->", stroke: (dash: "dashed"), rel[không có khóa ngoại]),
)

#note[
  Bảy trạng thái của một yêu cầu hoàn tiền, nhưng chỉ *hai* trạng thái mang thời hạn: chờ
  người bán xem xét và đã nhận hàng trả, mỗi trạng thái bốn mươi tám giờ. Hai trạng thái
  còn lại chưa kết thúc — đang trả hàng và đang tranh chấp — cố ý không có thời hạn, vì
  một bên chờ hãng vận chuyển và bên kia chờ nhân viên vận hành, mà cả hai đều không phải
  thứ một bộ đếm giờ được quyền quyết định. Người mua *không bao giờ* là bên chủ động leo
  thang: lối vào tranh chấp là người bán tự đưa lên, hoặc người bán im lặng hết hạn, hoặc
  người mua khai đã trả hàng mà người bán chưa xác nhận — trường hợp cuối là hệ quả của
  việc thiếu xác nhận chứ không phải một lời khiếu nại.
]

=== Module tài chính

Toàn bộ nguyên thủy tiền tệ nằm chung một module để các bước dịch chuyển ký quỹ giữ được
tính nguyên tử. Ranh giới quan trọng nhất bên trong module là *hai sổ cái, một đường
biên*: một sổ ghi các chặng đi trên kênh thanh toán bên ngoài, sổ còn lại ghi mọi lần
tiền dịch chuyển bên trong ví của nền tảng. Không bao giờ ghi cùng một lần dịch chuyển
vào cả hai, vì như thế thì tổng tiền của hệ thống sẽ được đếm hai lần và không phép đối
soát nào còn ý nghĩa.

Một chi tiết dễ bị bỏ qua nhưng quyết định cả cách rút tiền vận hành: *không có bảng
lệnh rút tiền*. Một lượt rút là một phiên thanh toán mang loại riêng, cùng bảng và cùng
vòng đời với một lượt thanh toán của người mua, chỉ khác chiều tiền. Nhờ vậy trạng thái
"đang xử lý", việc thử lại và bằng chứng đối soát với ngân hàng chỉ được viết một lần.

#fig(
  [Sơ đồ lớp module tài chính],
  spacing: (10mm, 7mm),

  cls((0, 0), "financeapi.Service", stereo: "interface", name: <f-svc>,
    ops: (
      "+ StartPayment / CancelSession",
      "+ ListSessions / GetSession",
      "+ ListSessionTransactions",
      "+ OpenCheckout",
      "+ HoldEscrow / ReleaseEscrow / RefundEscrow",
      "+ ListWallets / GetWallet / ListWalletMovements",
      "+ CreateWithdrawal / CancelWithdrawal",
      "+ ListWithdrawals / GetWithdrawal",
      "+ AdminApproveWithdrawal / AdminRejectWithdrawal",
      "+ AdminListWallets / AdminAdjustWallet",
      "+ ListBankAccounts / CreateBankAccount",
      "+ UpdateBankAccount / DeleteBankAccount",
      "+ GetTaxInfo / PutTaxInfo / AdminVerifyTaxInfo",
      "+ ListOptions / AdminSaveOption",
      "  ... 29 phương thức",
    )),
  cls((2, 0), "port.Repository", stereo: "interface", name: <f-repo>,
    ops: (
      "+ NextSessionID / NextTransactionID",
      "+ InsertSession / SaveSession / ListSessions",
      "+ InsertTransaction / SaveTransaction",
      "+ FindWallet / ListWallets / ListMovements",
      "+ Move(legs)  // ghi ví + sổ cái một giao dịch",
      "+ InsertBankAccount / SoftDeleteBankAccount",
      "+ PutTaxInfo / FindTaxInfo / SaveTaxInfo",
    )),
  edge(<f-svc>, <f-repo>, "-->", rel[dùng]),

  cls((0, 1), "Session", stereo: "payment intent", name: <f-ses>,
    attrs: (
      "- id: int64  // cấp phát trước khi INSERT",
      "- kind: buyer-checkout | seller-payout |",
      "        withdrawal",
      "- status: pending | processing | success |",
      "          cancelled | failed",
      "- fromID, toID: int64  // 0 = hệ thống",
      "- note: string",
      "- currency: string, totalAmount: int64",
      "- fxSnapshot: []byte  // tỉ giá đóng băng",
      "- data: jsonb",
      "- paidAt: *time, expiredAt: time",
    ),
    ops: (
      "+ Expired(now) / Settled() / RailPayable() bool",
      "+ Resumable(now) bool",
      "+ Charge(now) / MarkPaid(now) / MarkFailed()",
      "+ ReopenForRetry(now) / Cancel()",
      "+ Involves(accountID) bool",
    )),
  edge(<f-svc>, <f-ses>, "-->", rel[điều phối]),

  cls((2, 1), "Transaction", stereo: "append-only ledger", name: <f-tx>,
    attrs: (
      "- id, sessionID: int64",
      "- status: pending -> success | failed",
      "- note: string, error: *string",
      "- paymentOption: string  // slug kênh thanh toán",
      "- providerRef: *string   // khóa lũy đẳng webhook",
      "- checkoutURL: *string   // trang của nhà cung cấp",
      "- amount: int64  // dương = thu, âm = hoàn",
      "- currency: string",
      "- reversesID: *int64  // tự quan hệ: chặng gốc",
      "- data: jsonb, settledAt, expiredAt: *time",
    ),
    ops: (
      "+ NewReversal(id, amount) (Transaction, error)",
      "+ Resumable(now) bool",
      "+ Settle(status, providerRef, failure)",
      "  UNIQUE (paymentOption, providerRef)",
      "  UNIQUE reversesID  // 1 lần hoàn mỗi chặng",
    )),
  edge(<f-ses>, <f-tx>, "-", rel[1 → 0..\*  split-tender]),

  cls((0, 2), "Wallet", name: <f-wal>,
    attrs: (
      "- accountID: int64  (khóa chính)",
      "- currency: string  (khóa chính)",
      "- availableBalance: int64  // tiêu / rút được",
      "- heldBalance: int64       // đang ký quỹ",
    ),
    ops: (
      "+ Total() int64",
      "+ CanSpend(amount) bool",
      "+ Apply(t Transfer, seq) (Movement, error)",
      "  mọi thay đổi: SELECT ... FOR UPDATE",
    )),
  edge(<f-ses>, <f-wal>, "-->", stroke: (dash: "dashed"), rel[hai sổ cái, một đường biên]),

  cls((1, 2), "Movement", stereo: "append-only ledger", name: <f-mov>,
    attrs: (
      "- id, accountID: int64, currency: string",
      "- seq: int64  // thứ tự tuyệt đối trong ví",
      "- kind: topup | escrow-hold | escrow-release |",
      "        payout | refund | withdrawal | fee |",
      "        adjustment",
      "- availableDelta, heldDelta: int64",
      "- availableAfter, heldAfter: int64",
      "- groupID: *int64  // các chặng cùng một lần",
      "- refType: *string, refID: *int64",
      "- idempotencyKey: *string  // 'order:412:hold:buyer'",
      "- note: string",
    )),
  edge(<f-wal>, <f-mov>, "-", rel[1 → 0..\*]),

  cls((2, 2), "Transfer", stereo: "value object", name: <f-trf>,
    attrs: (
      "- kind: string",
      "- availableDelta, heldDelta: int64",
      "- groupID: *int64",
      "- refType: *string, refID: *int64",
      "- idempotencyKey: *string, note: string",
    ),
    ops: ("  Hold - Release - Credit - Debit - Adjust",)),
  edge(<f-wal>, <f-trf>, "-->", rel[tham số của Apply]),

  cls((0, 3), "Ref", stereo: "value object", name: <f-ref>,
    attrs: ("- kind: string  // 'order' | 'payment-session'", "- key: int64"),
    ops: ("+ Type() *string", "+ ID() *int64", "  OrderRef(id) - SessionRef(id)")),
  edge(<f-trf>, <f-ref>, "-->", rel[dựng bởi]),

  cls((1, 3), "BankAccount", name: <f-bank>,
    attrs: (
      "- id, accountID: int64",
      "- bankCode, accountNumber, accountHolder",
      "- isDefault: bool  // <= 1 mỗi tài khoản",
      "- deletedAt: *time  // xóa mềm",
    ),
    ops: ("+ IsLive() bool",)),

  cls((2, 3), "TaxInfo", name: <f-tax>,
    attrs: (
      "- accountID: int64  (khóa chính)",
      "- taxCode: string",
      "- taxCodeType: individual|business|household",
      "- legalName: string",
      "- verificationStatus: pending|verified|rejected",
      "- verifiedAt: *time, verificationSource: *string",
    ),
    ops: ("+ Verify(verified bool, source string)",)),

  cls((1, 4), "(liên module)", stereo: "cross-ref", name: <f-x>,
    attrs: (
      "-> account.account  (accountID, fromID, toID)",
      "-> order.order      (refID khi refType='order')",
      "-> common.option    (paymentOption)",
      "<- order.item.paymentSessionID",
      "Rút tiền = phiên kind='withdrawal',",
      "không có bảng riêng và không có lớp riêng.",
    )),
  edge(<f-ses>, <f-x>, "-->", stroke: (dash: "dashed"), rel[không có khóa ngoại]),
)

=== Module tín nhiệm

Module này tách hai loại điểm số vốn hay bị gộp làm một. Loại thứ nhất trả lời *giao
dịch đã diễn ra thế nào*: hai chiều, người mua chấm người bán và ngược lại, và ẩn cho
tới khi cả hai cùng nộp hoặc hết cửa sổ mười bốn ngày — cách duy nhất để một điểm số
không mang tính trả đũa. Loại thứ hai trả lời *món hàng có đúng như mô tả không*: một
chiều, chỉ người đã mua mới viết được. Một đơn hàng có thể sinh ra cả hai, nên nếu cộng
chung vào một cặp tổng thì chính đơn ấy đã bị đếm hai lần; vì vậy bản tổng hợp uy tín
giữ hai cặp tổng riêng biệt.

Thay đổi lớn nhất của module so với bản thiết kế ở giai đoạn trước là *không còn lớp tố
cáo riêng*. Mọi thứ người dùng gửi lên — tố cáo một bài đăng, khiếu nại một khoản hoàn
tiền, báo sự cố một đơn hàng, phản ánh vấn đề thanh toán, đề xuất tính năng — đều là một
*phiếu hỗ trợ*, phân biệt bằng loại phiếu. Bảy trạng thái trải trên ba bảng trước đây
thực chất là cùng một vòng đời được viết ba lần, và một người dùng hỏi "yêu cầu của tôi
đang ở đâu" thì có ba nơi phải tìm. Loại phiếu quyết định hai điều: phiếu có trỏ vào một
đối tượng nào không, và một lý do tố cáo có được phép đi kèm hay không.

#fig(
  [Sơ đồ lớp module tín nhiệm],
  spacing: (10mm, 7mm),

  cls((0, 0), "trustapi.Service", stereo: "interface", name: <t-svc>,
    ops: (
      "+ SubmitFeedback / GetOrderFeedback",
      "+ ListAccountFeedback / GetReputation",
      "+ RevealDueFeedback / RecordOrderOutcome",
      "+ SubmitReview / UpdateReview / DeleteReview",
      "+ ListReviews / GetReview",
      "+ SubmitReply / DeleteReply",
      "+ VoteReview / UnvoteReview",
      "+ OpenTicket / ListMyTickets / GetTicket",
      "+ AdminListTickets / AdminGetTicket",
      "+ AdminClaimTicket / AdminResolveTicket",
      "+ RecordRefundVerdict",
      "+ CreateUpload / ConfirmUpload",
    )),
  cls((2, 0), "port.Repository", stereo: "interface", name: <t-repo>,
    ops: (
      "+ InsertFeedback / OrderFeedback / ListFeedback",
      "+ DueFeedback / PublishFeedback",
      "+ FindReputation / AddOrderOutcome",
      "+ ReviewAverage",
      "+ InsertReview / ListReviews / SaveReview",
      "+ InsertReply / ListReplies",
      "+ PutVote / DeleteVote / MyVotes",
      "+ InsertTicket / FindTicket / SaveTicket",
      "+ ListTickets / OpenTicketsAgainst",
      "+ CountOpenAgainst",
    )),
  edge(<t-svc>, <t-repo>, "-->", rel[dùng]),

  cls((0, 1), "Feedback", stereo: "blind until revealed", name: <t-fb>,
    attrs: (
      "- id, orderID: int64  // cross-ref order",
      "- raterID, rateeID: int64",
      "- direction: buyer-to-seller | seller-to-buyer",
      "- rating: int16  // 1..5",
      "- comment: string",
      "- publishedAt: *time  // NULL = con an",
    ),
    ops: (
      "+ Published() bool / Publish(at)",
      "+ RevealAt() *time  // +14 ngày",
      "  chiều được SUY RA từ vai trên đơn hàng",
      "  UNIQUE (orderID, direction)",
    )),
  edge(<t-svc>, <t-fb>, "-->", rel[điều phối]),

  cls((1, 1), "Review", name: <t-rev>,
    attrs: (
      "- id: int64",
      "- listingID: int64  // cross-ref catalog",
      "- orderID: int64    // không mua thì không viết",
      "- authorID, sellerID: int64  // sellerID đóng băng",
      "- rating: int16  // 1..5",
      "- body: string, attachments: []int64",
      "- helpfulCount, notHelpfulCount: int64",
      "- replyCount: int64",
      "- updatedAt: *time",
    ),
    ops: (
      "+ SetRating(r) / SetBody(b)",
      "+ SetAttachments(a)",
      "+ MutableBy(accountID) bool",
      "  UNIQUE (listingID, authorID, orderID)",
    )),
  edge(<t-svc>, <t-rev>, "-->", rel[điều phối]),

  cls((2, 1), "Ticket", stereo: "aggregate root", name: <t-tk>,
    attrs: (
      "- id, requesterID: int64",
      "- kind: 11 giá trị",
      "    report-listing  report-account",
      "    report-message  report-review",
      "    report-review-reply  refund-dispute",
      "    order-issue  payment  account",
      "    feature-request  other",
      "- subject: string",
      "- refType: *string  // kiểu liệt kê 7 giá trị;",
      "        6 trong số đó SUY RA từ kind",
      "- refID: *int64",
      "- reason: *string   // chỉ với 5 loại tố cáo",
      "- status: open | reviewing | resolved",
      "- assigneeID: *int64",
      "- conversationID: *int64  // cross-ref chat",
      "- actionTaken: *string  // 7 giá trị",
      "- resolvedByID: *int64, resolvedAt: *time",
      "- resolutionNote: *string",
    ),
    ops: (
      "+ Resolved() bool",
      "+ Claim(moderatorID)",
      "+ Resolve(moderatorID, action, note)",
      "+ AttachThread(conversationID)",
      "  RefKindOf(kind) -> loại đối tượng",
      "  Reported(kind)  -> có được kèm lý do không",
      "  UNIQUE 1 phiếu mở / (người gửi, đối tượng)",
    )),

  cls((1, 2), "ReviewReply", name: <t-rpl>,
    attrs: ("- id, reviewID: int64", "- authorID: int64", "- body: string")),
  edge(<t-rev>, <t-rpl>, "-", rel[1 → 0..\*  «composition»]),

  cls((2, 2), "ReviewVote", name: <t-vote>,
    attrs: (
      "- reviewID, accountID: int64  (khóa chính)",
      "- vote: int16  // -1 hoặc 1, không có giá trị 0",
    )),
  edge(<t-rev>, <t-vote>, "-", rel[1 → 0..\*]),

  cls((0, 2), "Reputation", stereo: "aggregate", name: <t-rep>,
    attrs: (
      "- accountID: int64, role: seller | buyer",
      "- ratingSum, ratingCount        // từ Feedback",
      "- reviewRatingSum, reviewRatingCount  // từ Review",
      "- completedOrders, cancelledOrders",
      "- updatedAt: time",
    ),
    ops: (
      "+ AverageRating() float64",
      "+ AverageReviewRating() float64",
      "  CHECK: chỉ 'seller' mới có điểm review",
      "  không có dòng = toàn số 0, không phải 404",
    )),
  edge(<t-fb>, <t-rep>, "-->", rel[cộng dồn khi công bố]),
  edge(<t-rev>, <t-rep>, "-->", rel[cộng dồn]),

  cls((0, 3), "OrderOutcome", stereo: "idempotency", name: <t-out>,
    attrs: ("- orderID: int64  (khoa chinh)", "- completed: bool")),
  edge(<t-rep>, <t-out>, "-->", stroke: (dash: "dashed"), rel[chặn đếm hai lần]),

  cls((1, 3), "(đồng bộ ngược)", stereo: "cross-module", name: <t-sync>,
    attrs: (
      "trust.review  ==>  catalog.listing.cached_rating",
      "                   catalog.listing.cached_review_count",
      "hai lược đồ khác nhau nên không JOIN được;",
      "catalog nhận giá trị đã tính lại.",
    )),
  edge(<t-rev>, <t-sync>, "-->", stroke: (dash: "dashed"), rel[đẩy sang danh mục]),

  cls((2, 3), "(liên module của Ticket)", stereo: "cross-ref", name: <t-x>,
    attrs: (
      "-> chat.conversation (kind='ticket', UNIQUE ticket_id)",
      "-> account.account   (requesterID, assigneeID)",
      "<- order.refund_escalated   (mở phiếu tranh chấp)",
      "<- order.confirmation_lapsed (mở phiếu sự cố đơn)",
      "<- order.refund_resolved     (ghi phán quyết, đóng)",
    )),
  edge(<t-tk>, <t-x>, "-->", stroke: (dash: "dashed"), rel[qua bus và qua chat]),
)

#note[
  Phần hiển thị cho người gửi phiếu *là một cuộc hội thoại*, nên bản thân phiếu không lưu
  nội dung mô tả và không nhận tệp đính kèm. Nội dung người dùng viết khi mở phiếu trở
  thành *tin nhắn đầu tiên* của một luồng chat có loại riêng, và mọi thứ sau đó là chat
  bình thường — đường đính kèm, đường đẩy thời gian thực và huy hiệu chưa đọc đều đã có
  sẵn. Bên còn lại của luồng là tài khoản bàn hỗ trợ, nhờ đó người trả lời giữ được ẩn
  danh với người gửi, người trực ca sau kế thừa nguyên luồng, và không cần một bên tham
  gia có thể rỗng. Hai dòng nằm ở hai lược đồ khác nhau nên luồng chat được mở theo kiểu
  cố-gắng-hết-sức và được sửa lại khi đọc: mất cuộc hội thoại thì không bao giờ được phép
  làm mất luôn cái phiếu.
]

=== Module hội thoại

Module nhỏ nhất nhưng chứa một quyết định mô hình hóa đáng chú ý: *không có trạng thái
đã gửi hay đã đọc trên từng tin nhắn*. Vì bảng tin nhắn được phân mảnh theo thời gian,
một lá cờ trên mỗi dòng sẽ khiến mọi câu hỏi về "chưa đọc" sai hình dạng — huy hiệu đếm
không có cận thời gian nên không loại được mảnh nào, và một thao tác đánh dấu đã đọc sẽ
phải ghi lại mọi dòng chưa đọc, tức là làm bẩn các mảnh cũ chỉ để ghi một sự kiện của
hiện tại. Hai dấu thời gian đặt trên cuộc hội thoại trả lời được cả ba câu hỏi thường
gặp: chưa đọc bao nhiêu, đối phương đã đọc tới đâu, và sắp xếp hộp thư thế nào.

Cuộc hội thoại có hai loại. Loại thứ nhất là hội thoại trực tiếp giữa hai tài khoản, và
chỉ loại này chịu ràng buộc duy nhất một luồng cho mỗi cặp; loại thứ hai là luồng của
một phiếu hỗ trợ, gắn duy nhất với một phiếu. Cùng một lớp, cùng một bảng, khác nhau ở
đúng một trường và ở việc ai được đọc.

#fig(
  [Sơ đồ lớp module hội thoại],
  spacing: (12mm, 8mm),

  cls((0, 0), "chatapi.Service", stereo: "interface", name: <ch-svc>,
    ops: (
      "+ ListConversations / StartConversation",
      "+ GetConversation / GetUnreadCount",
      "+ ListMessages / SendMessage / GetMessage",
      "+ MarkConversationRead",
      "+ UpdateMessage / RedactMessage",
      "+ PostSystemMessage",
      "+ OpenTicketThread / PostTicketMessage",
      "+ CreateUpload / ConfirmUpload",
    )),
  cls((1, 0), "port.Repository", stereo: "interface", name: <ch-repo>,
    ops: (
      "+ EnsureConversation / EnsureTicketThread",
      "+ FindConversation / SaveConversation",
      "+ ListConversations",
      "+ InsertMessage / FindMessage / FindMessageAt",
      "+ SaveMessage / ListMessages / LastMessages",
      "+ UnreadCounts / UnreadTotal",
      "+ FindResources",
    )),
  edge(<ch-svc>, <ch-repo>, "-->", rel[dùng]),

  cls((0, 1), "Conversation", stereo: "aggregate root", name: <ch-conv>,
    attrs: (
      "- id: int64",
      "- kind: direct | ticket",
      "- ticketID: *int64  // cross-ref trust, UNIQUE",
      "- accountAID, accountBID: int64  // CHECK A < B",
      "- lastMessageAt: time  // sắp xếp hộp thư",
      "- accountAReadAt, accountBReadAt: *time",
      "- createdAt: time",
    ),
    ops: (
      "+ NewConversation(a, b) / NewTicketThread(...)",
      "+ Ticket() bool",
      "+ Involves(accountID) bool",
      "+ Counterparty(accountID) / Other(actorID)",
      "+ ReadMark(accountID) *time",
      "+ CounterpartyReadMark(accountID) *time",
      "+ MarkRead(accountID, at) error  // đơn điệu",
      "  UNIQUE (A, B) chỉ với kind='direct'",
    )),
  edge(<ch-svc>, <ch-conv>, "-->", rel[điều phối]),

  cls((1, 1), "Message", stereo: "hypertable", name: <ch-msg>,
    attrs: (
      "- id: int64, createdAt: time  // khóa (id, createdAt)",
      "- conversationID: int64",
      "- senderID: int64  // 0 = tin hệ thống",
      "- type: user | system",
      "- body: string",
      "- attachments: []int64  // cross-ref resource",
      "- refs: map    // con trỏ tới listing / order",
      "- card: map    // dữ liệu vẽ thẻ, do backend đặt",
      "- editedAt, deletedAt: *time",
    ),
    ops: (
      "+ IsLive() bool",
      "+ Edit(senderID, body) error",
      "+ Redact(actorID, moderator bool) error",
      "  CHECK (type='system') = (senderID = 0)",
    )),
  edge(<ch-conv>, <ch-msg>, "-", rel[1 → 0..\*]),

  cls((0, 2), "(liên module)", stereo: "cross-ref", name: <ch-x>,
    attrs: (
      "-> account.account (accountAID, accountBID, senderID)",
      "-> trust.ticket    (ticketID)",
      "-> order.offer     (refs.offer_id)",
      "-> catalog.listing / variant, order.order",
      "-> common.resource (attachments[])",
    )),
  edge(<ch-msg>, <ch-x>, "-->", stroke: (dash: "dashed")),

  cls((1, 2), "Quy tắc chiếu theo người xem", stereo: "ghi chú thiết kế", name: <ch-note>,
    attrs: (
      "Nhân viên trả lời phiếu đóng vai BÀN HỖ TRỢ ở mọi",
      "chỗ giá trị phụ thuộc người xem (đối phương, dấu đã",
      "đọc, số chưa đọc) - nhờ vậy dấu đã đọc là dùng chung",
      "và người trực ca sau kế thừa được.",
      "Người GỬI tin nhắn thì không bao giờ bị ánh xạ, nếu",
      "không lời lẽ của chính người gửi phiếu sẽ bị ẩn đi",
      "trước mắt nhân viên đang đọc.",
      "Ẩn danh phải áp lên MỌI phép chiếu của tin nhắn,",
      "kể cả dòng tin cuối trên hộp thư.",
      "Điều khoản thương lượng giá KHÔNG được chép vào tin",
      "nhắn: chỉ nói THẺ NÀO cần vẽ, nguồn sự thật ở order.",
    )),
  edge(<ch-msg>, <ch-note>, "-->", stroke: (dash: "dashed")),
)

=== Module quan trắc

Module này theo đúng hình dạng chuẩn của một module nhưng *không có* gói hợp đồng công
bố: không module nào gọi nó, nó được dẫn động bởi lớp trung gian của bộ định tuyến, bởi
bộ lấy mẫu và bởi bus. Đây là một đường ống hai chặng — bộ thu *phát* mỗi mẫu lên hàng
đợi bền, còn bộ ghi *tiêu thụ* theo lô và nạp cả lô vào bảng phân mảnh theo thời gian
bằng đường nạp khối. Việc phát là cố-gắng-hết-sức và không bao giờ được phép chặn hay
làm hỏng một yêu cầu; nhưng một khi mẫu đã nằm trong hàng đợi thì nó bền, một lô ghi
hỏng sẽ được giao lại chứ không mất.

Điểm dễ hiểu sai nhất nằm ở chỗ *hai bus được phân biệt bằng kiểu dữ liệu*, và ràng buộc
kiểu ấy xảy ra ở tầng lắp ráp phụ thuộc của module chứ không nằm trong chữ ký của bộ
thu: bản thân bộ thu chỉ nhận một giao diện bus, còn việc chọn đúng hàng đợi bền là do
tầng lắp ráp quyết định. Nếu chọn nhầm, bộ ghi sẽ được nối vào bus sự kiện miền mà không
báo bất kỳ lỗi nào — một hỏng hóc chỉ lộ ra khi bảng điều khiển trống trơn.

#fig(
  [Sơ đồ lớp module quan trắc],
  spacing: (12mm, 8mm),

  cls((0, 0), "Sink", stereo: "không có api.Service", name: <ob-sink>,
    attrs: (
      "- bus: eventbus.Client  // giao diện; việc CHỌN",
      "        hàng đợi bền xảy ra ở tầng lắp ráp",
      "- instance: string  // từ tệp cấu hình YAML,",
      "        đóng dấu một lần cho mỗi mẫu",
      "- dropped: bộ đếm nguyên tử",
    ),
    ops: (
      "+ Middleware(next) http.Handler  // RED vào",
      "+ OutboundObserver() Observer     // RED ra",
      "+ SampleLoop(ctx, conns ConnCounter)",
      "+ RecordHTTP / RecordProviderCall",
      "+ RecordEvent / RecordRuntime",
      "  best-effort: không bao giờ chặn request",
      "  mẫu không gửi được thì ĐẾM, không thử lại",
    )),
  cls((2, 0), "port.Repository", stereo: "interface", name: <ob-repo>,
    ops: (
      "+ InsertHTTPRequests(batch)",
      "+ InsertProviderCalls(batch)",
      "+ InsertBusinessEvents(batch)",
      "+ InsertRuntimeMetrics(batch)",
      "  hiện thực bằng đường nạp khối, ghi theo lô",
    )),
  cls((1, 0), "subscribeWriter", stereo: "consumer", name: <ob-w>,
    attrs: (
      "- 4 chủ đề telemetry.*",
      "- cỡ lô + thời gian gom (linger)",
    ),
    ops: ("  lo ghi hong -> tu choi -> duoc giao lai",)),
  edge(<ob-sink>, <ob-w>, "-->", rel[phát lên hàng đợi bền]),
  edge(<ob-w>, <ob-repo>, "-->", rel[giao cả lô]),

  cls((0, 1), "HTTPSample", name: <ob-http>,
    attrs: (
      "- ts: time, instance: string",
      "- method, route: string  // route = mẫu đường dẫn",
      "- status: int",
      "- durationMs: float64",
    )),
  cls((1, 1), "ProviderCall", name: <ob-prov>,
    attrs: (
      "- ts: time, instance, provider: string",
      "- method, path: string  // path đã mẫu hóa",
      "- status: int  // 0 = không có phản hồi",
      "- durationMs: float64, failed: bool, error: string",
    )),
  cls((2, 1), "BusinessEvent", name: <ob-biz>,
    attrs: (
      "- ts: time, instance: string",
      "- topic: string  // 'order.placed', ...",
      "- payload: giá trị JSON  // chỉ id, số tiền, trạng thái",
    )),
  cls((1, 2), "RuntimeSample", name: <ob-rt>,
    attrs: (
      "- ts: time, instance: string",
      "- goroutines: int",
      "- heapAllocBytes, heapInuseBytes: int64",
      "- gcPauseMs: float64, numGC: int64",
      "- webSocketConns: int",
    )),
  edge(<ob-sink>, <ob-http>, "-->"),
  edge(<ob-sink>, <ob-prov>, "-->"),
  edge(<ob-sink>, <ob-biz>, "-->"),
  edge(<ob-sink>, <ob-rt>, "-->"),

  cls((0, 2), "http_requests_1m", stereo: "continuous aggregate", name: <ob-agg>,
    attrs: (
      "- bucket: time (1 phút)",
      "- instance, route, status",
      "- calls, avgMs, maxMs",
      "- latency: phác đồ phân vị",
    ),
    ops: ("  doc p95 bang ham phan vi xap xi", "  KHONG BAO GIO lay trung binh cua p95")),
  edge(<ob-http>, <ob-agg>, "-->", rel[gộp mỗi phút]),

  cls((2, 2), "provider_calls_1m", stereo: "continuous aggregate", name: <ob-agg2>,
    attrs: (
      "- bucket, instance, provider, status",
      "- calls, failures, avgMs, maxMs",
      "- latency: phác đồ phân vị",
    )),
  edge(<ob-prov>, <ob-agg2>, "-->", rel[gộp mỗi phút]),
)

=== Tầng bộ xử lý tuyến và các lớp truyền dữ liệu

Bảy sơ đồ ở trên mô tả tầng miền. Phần này bổ sung tầng còn lại mà một bản thiết kế thi
công được phải có: các lớp *đứng ở biên HTTP*. Chúng được tách riêng chứ không vẽ chung,
vì chúng tuân theo một quy tắc trái ngược hẳn với tầng miền — *bộ xử lý tuyến cố ý mỏng và
cố ý giống hệt nhau*. Một bộ xử lý chỉ làm bốn việc theo đúng thứ tự: đọc yêu cầu, điền
những thứ chỉ tầng cổng biết (định danh người gọi, mã yêu cầu), gọi dịch vụ, và giao kết
quả hoặc lỗi cho nơi ghi phản hồi. Nó *không* kiểm tra vai trò, vì vai trò là một hàng
trong bảng của mô-đun tài khoản; nó *không* biến đổi lỗi; và nó không chứa một quy tắc
nghiệp vụ nào.

Chính vì mỏng như vậy nên điều đáng đặc tả không phải từng bộ xử lý mà là *tập hàm dựng
sẵn mà tất cả chúng dùng chung*. Nếu mỗi bộ xử lý tự đọc tham số phân trang, một giới hạn
sẽ có nghĩa hai mươi ở tuyến này và năm mươi ở tuyến kia, và đó là loại lỗi chỉ máy khách
phát hiện được khi đã chạy thật.

#fig(
  [Sơ đồ lớp tầng bộ xử lý tuyến và các lớp truyền dữ liệu],
  spacing: (13mm, 9mm),

  cls((0, 0), "Router", stereo: "transport", name: <h-r>,
    attrs: (
      "- mux: http.ServeMux  // mọi tuyến gắn KHÔNG kèm tiền tố",
      "- basePath: '/api/v1'  // gắn cả mux vào đây một lần",
    ),
    ops: (
      "+ Handler() http.Handler",
      "  chuỗi lớp trung gian: CORS → mã yêu cầu",
      "  → nhật ký → quan trắc → xác thực",
    )),
  cls((2, 0), "middleware.Auth", stereo: "middleware", name: <h-auth>,
    ops: (
      "+ Wrap(next) http.Handler",
      "  1. đọc vé, kiểm chữ ký",
      "  2. TRA CỨU PHIÊN ở bộ nhớ đệm — mọi yêu cầu",
      "  3. đặt định danh người gọi vào ngữ cảnh yêu cầu",
      "  thiếu / hỏng / phiên đã thu hồi → 401 có mã",
    )),
  edge(<h-r>, <h-auth>, "-->", rel[bọc các tuyến cần vé]),

  cls((1, 1), "params", stereo: "hàm dựng sẵn dùng chung", name: <h-p>,
    ops: (
      "+ actor(r) ID[Account]        // từ ngữ cảnh, KHÔNG từ thân",
      "+ pathID[K](r, tên) ID[K]     // giải mã định danh mờ",
      "+ pageParams(r) / limitParam(r) / cursorParam(r)",
      "+ boolParam / int64Param / floatParam / timeParam",
      "+ decodeBody(r, dst)          // bộ giải mã NGHIÊM NGẶT",
      "+ check(v, req)               // ràng buộc trên thẻ trường",
      "+ failed(w, log, err)         // giao lỗi cho nơi ghi",
    )),
  edge(<h-p>, <h-auth>, "-->", stroke: (dash: "dashed"), rel[đọc ngữ cảnh]),

  cls((0, 2), "handler.Order", stereo: "controller", name: <h-o>,
    attrs: (
      "- svc: orderapi.Service   // CHỈ phụ thuộc hợp đồng",
      "- v: validator, log: logger",
    ),
    ops: (
      "+ ListCartItems / AddCartItem / UpdateCartItem",
      "+ CreateDraft / Checkout / ShippingQuotes",
      "+ CreateOffer / CounterOffer / AcceptOffer",
      "+ ConfirmOrder / DeclineOrder / ConfirmReceipt",
      "+ CreateRefund / AcceptRefund / EscalateRefund",
      "+ AdminResolveRefund",
    )),
  cls((1, 2), "Bảy nhóm bộ xử lý", stereo: "cùng một hình dạng", name: <h-all>,
    attrs: (
      "handler.Account   handler.Catalog",
      "handler.Chat      handler.Finance",
      "handler.Order     handler.Trust",
      "handler.Options   // dùng chung, một tuyến /options",
      "ws.Handler        // kênh thời gian thực",
    ),
    ops: (
      "mỗi lớp: một trường api.Service + validator + logger",
      "module quan trắc KHÔNG có nhóm nào: nó không có",
      "bề mặt HTTP và cũng không có gói hợp đồng",
    )),
  edge(<h-r>, <h-all>, "-->", rel[gắn tuyến]),
  edge(<h-o>, <h-p>, "-->", stroke: (dash: "dashed")),
  edge(<h-all>, <h-p>, "-->", stroke: (dash: "dashed")),

  cls((2, 2), "orderapi.Service", stereo: "hợp đồng công bố", name: <h-svc>,
    attrs: ("gói api CHỈ nhập context và shared/id",),
    ops: ("+ Checkout(ctx, CheckoutRequest) (Session, error)", "  ...",)),
  edge(<h-o>, <h-svc>, "-|>", rel[gọi]),

  cls((0, 3), "CheckoutRequest", stereo: "DTO yêu cầu", name: <h-req>,
    attrs: (
      "+ ActorID: ID[Account]  `json:\"-\"  required`",
      "+ ID: ID[DraftOrder]    `json:\"-\"  required`",
      "+ Lines: []CheckoutLine `min=1,dive`",
      "+ ContactID: ID[Contact]  `required`",
      "+ TransportOption: string `required,max=100`",
      "+ Currency: string        `required,len=3`",
      "+ Note: string            `max=500`",
      "json:\"-\" = do tầng cổng điền, KHÔNG nhận từ máy khách",
    )),
  cls((1, 3), "Session", stereo: "DTO phản hồi", name: <h-res>,
    attrs: (
      "+ ID: ID[PaymentSession]  → 'pss_4rm8vc2xdq7n'",
      "+ Status, Kind, Currency: string",
      "+ TotalAmount, Outstanding: int64",
      "+ CheckoutURL: string",
      "+ ExpiredAt: time",
      "KHÔNG trường nào mang omitempty:",
      "khoá luôn có mặt, rỗng là [] {} 0 false null",
    )),
  cls((2, 3), "httpx", stereo: "phong bì phản hồi", name: <h-env>,
    ops: (
      "+ WriteData(w, dto)        → { \"data\": ... }",
      "+ WritePage(w, ds, meta)   → { \"data\": [], \"meta\": ... }",
      "+ WriteError(w, err)       → { \"error\": { code, message } }",
      "  NƠI DUY NHẤT ánh xạ lỗi sang mã trạng thái HTTP",
    )),
  edge(<h-o>, <h-req>, "-->", stroke: (dash: "dashed"), rel[dựng]),
  edge(<h-svc>, <h-res>, "-->", stroke: (dash: "dashed"), rel[trả về]),
  edge(<h-o>, <h-env>, "-->", rel[ghi]),
)

#note[
  Hai chi tiết trên hình quyết định nhiều thứ về sau. Thứ nhất, các trường mang thẻ
  `json:"-"` — định danh người gọi, định danh trên đường dẫn, tham số phân trang — nằm
  *trong cùng* một cấu trúc yêu cầu với các trường lấy từ thân, nhưng không bao giờ được
  đọc từ thân. Nhờ vậy dịch vụ nhận đúng một tham số và bộ kiểm tra ràng buộc chạy trên
  toàn bộ yêu cầu một lần; nếu tách đôi, sẽ có hai chỗ để quên kiểm. Một máy khách gửi lên
  `actor_id` của người khác thì trường ấy đơn giản là bị bỏ qua, chứ không phải bị từ chối
  — đó là lý do dùng `-` thay vì một tên trường khác. Thứ hai, không DTO nào bỏ khoá khi
  giá trị bằng rỗng: một danh sách rỗng là `[]` chứ không phải vắng mặt, vì "không có" và
  "chưa nạp" phải là hai câu trả lời khác nhau đối với máy khách.
]

=== Bảng đặc tả lớp

Sơ đồ nói được cấu trúc nhưng không nói được *trách nhiệm* và *bất biến*. Bảng dưới đây bổ
sung phần ấy cho các lớp mang nhiều quy tắc nhất; các lớp còn lại đã được mô tả đủ bằng
hình vẽ cùng đoạn văn đi kèm mỗi sơ đồ.

#figure(
  kind: table,
  caption: [Đặc tả trách nhiệm và bất biến của các lớp mang nhiều quy tắc nhất],
  table(
    columns: (0.52fr, 0.36fr, 1fr, 1.15fr),
    align: (left + top, left + top, left + top, left + top),
    inset: (x: 4.5pt, y: 4.5pt),
    table.header([Lớp], [Khuôn mẫu], [Trách nhiệm], [Bất biến mà nó gác]),

    [`Account`], [Gốc tập hợp],
    [Định danh đăng nhập, phần hiển thị, tập liên kết đăng nhập, vai trò và trạng thái đình chỉ.],
    [Luôn còn ít nhất một cách đăng nhập; đổi định danh thì xóa dấu đã xác minh của chính định danh ấy; ngày sinh không ở tương lai; đúng một hàng mang vai bàn hỗ trợ.],

    [`Listing`], [Gốc tập hợp],
    [Nội dung tin đăng, tập biến thể kèm tồn kho, tập thẻ, bản sửa chờ duyệt.],
    [Không công bố khi người bán chưa xác minh danh tính hoặc chưa khai địa chỉ lấy hàng; số đang giữ chỗ cộng số đã bán không vượt số lượng; nhiều nhất một biến thể hiển thị; bản sửa không bao giờ thay nội dung đang hiển thị trước khi được duyệt.],

    [`Order`], [Gốc tập hợp],
    [Vòng đời một thương vụ đã trả tiền, từ chờ xác nhận tới hoàn tất hoặc hủy.],
    [*Không có cột trạng thái* — bốn trạng thái suy ra từ các mốc thời gian; chỉ giải ngân khi đã có xác nhận nhận hàng; không nhận hàng khi người bán chưa xác nhận; lý do từ chối chỉ tồn tại trên đơn đã hủy và chưa từng xác nhận; đúng một trong hai nguồn hình thành.],

    [`Refund`], [Thực thể có máy trạng thái],
    [Bảy trạng thái của một hồ sơ hoàn tiền và tập hành động hợp lệ ở từng trạng thái.],
    [Người bán không có nước đi "từ chối"; hạn chót tồn tại đúng ở hai trong bốn trạng thái chưa kết thúc; mọi lượt ghi nêu đích danh tập trạng thái nguồn; một đơn có nhiều nhất một hồ sơ đang mở.],

    [`Offer`], [Thực thể có máy trạng thái],
    [Điều khoản đang đặt trên bàn của một cuộc thương lượng, và bên nào tới lượt.],
    [Chỉ bên *không* đang giữ đề nghị mới được chấp nhận; một cuộc đang mở cho mỗi cặp người mua và biến thể; chấp nhận chỉ đóng băng giá ba mươi phút và không tạo đơn; tin đăng giá cố định không thương lượng được.],

    [`Session`], [Gốc tập hợp],
    [Số tiền đang chờ được trả và tập chặng thanh toán của nó.],
    [Chỉ phiên ở trạng thái chờ trả mới tender được; mỗi kênh nhiều nhất một trang thanh toán còn sống; tổng các chặng thành công không vượt tổng tiền; chỉ chuyển "đã trả đủ" đúng một lần.],

    [`Wallet` và `Movement`], [Gốc tập hợp cùng đối tượng giá trị],
    [Hai loại số dư và sổ bút toán chỉ-thêm-mới của chúng.],
    [Cả hai số dư không âm sau mỗi chân; mỗi chân mang số dư trước và sau; số thứ tự trong ví liên tục và cấp dưới khóa ghi; một chân rỗng bị từ chối; khóa lũy đẳng là duy nhất.],

    [`Ticket`], [Gốc tập hợp],
    [Mọi loại việc người dùng gửi lên, từ tố cáo tới đề xuất tính năng.],
    [Loại đối tượng suy ra từ loại phiếu chứ không do máy khách gửi; một phiếu đang mở cho mỗi người gửi trên mỗi đối tượng; phiếu tranh chấp hoàn tiền không giải quyết bằng tay được; danh tính người trả lời không bao giờ lộ cho người gửi.],

    [`Conversation` và `Message`], [Gốc tập hợp cùng bảng phân mảnh],
    [Một luồng cho mỗi cặp tài khoản, hoặc một luồng cho mỗi phiếu hỗ trợ.],
    [Cặp tham gia luôn theo thứ tự tăng dần nên chỉ có một luồng trực tiếp cho mỗi cặp; tin hệ thống thì và chỉ thì không có người gửi; điều khoản thương lượng không bao giờ được chép vào tin nhắn; nhân viên đóng vai bàn hỗ trợ ở *mọi* phép chiếu phụ thuộc người xem.],

    [`Feedback` và `Reputation`], [Thực thể cùng gốc tập hợp],
    [Đánh giá giao dịch ẩn, và điểm uy tín cộng dồn từ nó.],
    [Chiều đánh giá suy ra từ vai trên đơn chứ không do máy khách gửi; ẩn cho tới khi cả hai bên gửi hoặc hết mười bốn ngày; công bố và cộng dồn nằm trong cùng một giao dịch; điểm giao dịch và điểm nhận xét sản phẩm đếm tách rời; không có hàng nghĩa là toàn số không, không phải không tìm thấy.],
  ),
)

=== Ma trận ánh xạ lớp miền và bảng dữ liệu

Lớp miền và bảng dữ liệu *không* tương ứng một-một, và những chỗ lệch mới là chỗ đáng ghi
lại. Bảng dưới đây liệt kê các chỗ lệch ấy; những lớp không có tên trong bảng thì ánh xạ
thẳng sang một bảng cùng tên.

#figure(
  kind: table,
  caption: [Những chỗ lớp miền không tương ứng một-một với bảng dữ liệu],
  table(
    columns: (0.62fr, 0.72fr, 1.5fr),
    align: (left + top, left + top, left + top),
    table.header([Lớp miền], [Bảng tương ứng], [Bản chất của chỗ lệch]),
    [`Profile`], [Các cột của `account.account`],
    [Đối tượng giá trị chứ không phải bảng: tên hiển thị là bắt buộc và được ghi trong cùng câu lệnh với tài khoản, nên tách ra chỉ mua thêm một phép kết nối.],
    [`Stock`], [`catalog.stock`],
    [Bảng có khóa riêng nhưng lớp miền *không* có định danh riêng: tồn kho là một đối tượng giá trị nhúng trong biến thể, gồm ba bộ đếm.],
    [`Order`], [`order.order` — bốn cột mốc thời gian],
    [Trạng thái của đơn không có cột nào cả; nó là một hàm thuần túy trên bốn mốc thời gian kết quả.],
    [`Movement`], [`finance.wallet_transaction`],
    [Một lượt dịch chuyển logic thành *nhiều* hàng — một hàng cho mỗi chân — và chúng được nối lại bằng cột nhóm.],
    [`Transaction`], [`finance.transaction`],
    [Tên trong mã nguồn là "chặng" của một phiên; tên bảng giữ theo từ vựng kế toán. Sơ đồ lớp ghi cả hai để đối chiếu được.],
    [`Ticket`], [`trust.ticket` cùng `chat.conversation`],
    [Một khái niệm trải trên *hai lược đồ*: phần trạng thái ở trust, phần nội dung trao đổi ở chat. Vì thế luồng hội thoại được mở theo kiểu cố-gắng-hết-sức và được sửa lại ở lần đọc kế tiếp.],
    [`AccountInterest`], [`catalog.account_interest`],
    [Bảng có đường đọc phục vụ tiêu chí "gợi ý cho tôi" nhưng *không có đường ghi nào* trong bản hiện thực hiện tại; nó được ghi lại ở đây như một khoảng trống đã biết, chứ không được vẽ như một phần đang hoạt động.],
    [`Event`], [`<lược đồ>.audit_log`],
    [Sự việc mà tầng miền ghi nhận thành một hàng nhật ký kiểm toán, trong cùng giao dịch với chính thay đổi. Mười tám hiện thân bảng, một lớp.],
    [`Resource`], [`<lược đồ>.resource`],
    [Cùng một lớp, mười tám hiện thân bảng: tệp thuộc về mô-đun đã nhận nó.],
    [Các lớp mẫu quan trắc], [Bốn bảng phân mảnh theo thời gian],
    [Không có gốc tập hợp và không có phương thức nghiệp vụ nào; chúng là bản ghi đo đạc, được nạp theo lô bằng đường nạp khối.],
  ),
)

=== Ánh xạ lớp truyền dữ liệu và điểm cuối

Bảng dưới đây lấy sáu điểm cuối tiêu biểu và chỉ ra chuỗi ánh xạ đầy đủ từ một yêu cầu HTTP
tới lớp miền rồi ngược lại. Điều đáng chú ý xuyên suốt là *không bao giờ có một lớp trung
gian nào giữa DTO và lớp miền*: bộ xử lý dựng DTO, dịch vụ đọc DTO và gọi thẳng phương
thức miền, rồi một hàm chiếu dựng DTO phản hồi từ thực thể.

#figure(
  kind: table,
  caption: [Ánh xạ điểm cuối, lớp truyền dữ liệu, phương thức dịch vụ và lớp miền],
  table(
    columns: (0.78fr, 0.72fr, 0.72fr, 0.72fr, 0.66fr),
    align: (left + top, left + top, left + top, left + top, left + top),
    inset: (x: 4pt, y: 4.5pt),
    table.header([Điểm cuối], [DTO yêu cầu], [Phương thức dịch vụ], [Lớp miền được gọi], [DTO phản hồi]),
    [`POST /drafts/{id}/checkout`], [`CheckoutRequest`], [`Checkout`],
    [`DraftOrder.Cancel`, `Item`, `Stock.Reserve`], [`Session`],
    [`POST /orders/{id}/confirmation`], [`ConfirmOrderRequest`], [`ConfirmOrder`],
    [`Order.Confirm`, `Transport.Book`], [`Order`],
    [`POST /orders/{id}/refunds`], [`CreateRefundRequest`], [`CreateRefund`],
    [`Refund` (hàm dựng), `Order`], [`Refund`],
    [`GET /listings`], [`ListListingsRequest`], [`ListListings`],
    [`Listing`, `ListingEmbedding`], [`ListingPage`],
    [`POST /payment-sessions/{id}/payments`], [`StartPaymentRequest`], [`StartPayment`],
    [`Session.Charge`, `Transaction`], [`Transaction`],
    [`POST /tickets`], [`OpenTicketRequest`], [`OpenTicket`],
    [`Ticket` (hàm dựng), `Conversation`], [`Ticket`],
  ),
)

Ba quy tắc chi phối toàn bộ bảng trên. *Định danh được chuyển đổi đúng ở biên DTO*: bên
trong dịch vụ, miền và bộ điều hợp cơ sở dữ liệu thì định danh là số nguyên 64 bit trần,
còn trường DTO là kiểu định danh mờ có gắn loại. *Ràng buộc đầu vào được kiểm hai lớp*:
lớp thẻ trường trên DTO bắt các lỗi hình thức, còn lớp tầng miền kiểm toàn vẹn thực thể
*sau khi* đã áp bản vá — nhờ vậy các quy tắc liên trường được kiểm trên kết quả cuối cùng
chứ không trên từng trường rời rạc. Và *một bản vá từng phần dùng con trỏ cộng một cờ
xóa*: vắng mặt thì giữ nguyên, có giá trị thì thay, cờ bật thì gỡ bỏ — ba trạng thái diễn
đạt bằng hai trường JSON thông thường, không cần giá trị `null` trên đường truyền.

=== Cấu hình tiêm phụ thuộc

Toàn bộ đồ thị đối tượng được lắp ráp bằng một khung tiêm phụ thuộc, và cách lắp ráp ấy là
một phần của thiết kế chứ không phải một chi tiết kỹ thuật: nó là thứ *cưỡng chế* các mũi
tên phụ thuộc đã vẽ trên bảy sơ đồ lớp. Mỗi mô-đun công bố đúng một khối lắp ráp, và khối
ấy đăng ký ba thứ theo cùng một khuôn.

#figure(
  kind: table,
  caption: [Khuôn lắp ráp phụ thuộc, giống nhau ở cả bảy mô-đun],
  table(
    columns: (0.62fr, 0.85fr, 1.5fr),
    align: (left + top, left + top, left + top),
    table.header([Thứ được đăng ký], [Kiểu được công bố], [Ghi chú thiết kế]),
    [Nguồn kết nối cơ sở dữ liệu], [*Riêng tư* trong phạm vi mô-đun],
    [Riêng tư là bắt buộc chứ không phải tuỳ chọn: hai mô-đun cùng công bố một nguồn kết nối trần ra đồ thị gốc sẽ thành xung đột kiểu, thay vì thành mỗi mô-đun một nguồn. Mỗi nguồn đặt đường tìm kiếm về lược đồ của chính nó và đăng ký một móc đóng lúc dừng.],
    [Kho chứa], [Giao diện `port.Repository`],
    [Được công bố *dưới dạng giao diện* chứ không dưới dạng lớp hiện thực, nên tầng dịch vụ không có cách nào chạm tới một phương thức nằm ngoài cổng.],
    [Dịch vụ], [Giao diện `<tên>api.Service`],
    [Đây là điều làm cho liên kết giữa các mô-đun tự động và một chiều: dịch vụ danh mục khai nhận một `accountapi.Service` và khung tiêm tự nối, mà gói danh mục không hề nhập gói tài khoản.],
    [Việc quét định kỳ], [Một nhóm có nhãn],
    [Các lượt quét được gom thành một nhóm và một bộ quét duy nhất chạy tất cả, nên thêm một lượt quét mới không phải sửa nơi khởi động.],
  ),
)

Ba hệ quả cần nói rõ. Thứ nhất, *nối ghép giữa các mô-đun là theo kiểu dữ liệu*, nên một
phụ thuộc vòng giữa hai mô-đun sẽ hiện ra thành lỗi lúc dựng đồ thị chứ không thành một
lỗi lúc chạy. Thứ hai, có *hai bus cùng nằm trong đồ thị và được phân biệt bằng kiểu*: bus
sự kiện miền được nhận qua giao diện, còn hàng đợi bền của dữ liệu quan trắc được nhận qua
kiểu cụ thể — nếu khai nhận nhầm giao diện cho phần quan trắc thì bộ ghi sẽ nối vào bus
sai mà *không* báo lỗi nào, và hỏng hóc chỉ lộ ra khi bảng điều khiển trống trơn. Thứ ba,
nơi khởi động chỉ làm đúng một việc: gộp các khối cấu hình nền — tệp cấu hình, bộ ghi nhật
ký, bộ cấp vé, bộ kiểm tra ràng buộc, bus, bộ nhớ đệm — với bảy khối mô-đun và một khối
tầng cổng, rồi chạy. Không có một lời gọi khởi tạo thủ công nào ở đó, và cũng không có
biến toàn cục nào — ngoại lệ duy nhất trong toàn hệ thống là bộ mã hoá định danh mờ, vì
giao diện tuần tự hoá JSON của ngôn ngữ không có chỗ để truyền một phụ thuộc vào.

=== Các mẫu thiết kế được áp dụng

Sáu mẫu thiết kế dưới đây không phải được chọn trước rồi đi tìm chỗ dùng; mỗi mẫu là câu
trả lời cho một vấn đề cụ thể đã xuất hiện trong quá trình hiện thực, và cả sáu đều để
lại dấu vết trực tiếp trong các sơ đồ lớp ở trên.

#figure(
  kind: table,
  caption: [Các mẫu thiết kế được áp dụng và vấn đề mà chúng giải quyết],
  table(
    columns: (0.9fr, 1.5fr, 1.7fr),
    align: (left + top, left + top, left + top),
    table.header([Mẫu], [Vấn đề được giải quyết], [Lớp tham gia]),

    [Cổng và bộ điều hợp (Ports and Adapters)],
    [Giữ quy tắc nghiệp vụ độc lập với công nghệ lưu trữ và giao thức, để bất biến của
     tầng miền kiểm thử được mà không cần cơ sở dữ liệu.],
    [Mỗi module: giao diện kho chứa ở tầng cổng, hiện thực PostgreSQL ở tầng điều hợp,
     hợp đồng công bố ở gói dịch vụ.],

    [Kho chứa (Repository)],
    [Một nơi duy nhất biết câu lệnh truy vấn; tầng điều phối không bao giờ tự viết SQL.],
    [Bảy giao diện kho chứa, mỗi module một cái.],

    [Gốc tập hợp kèm khóa lạc quan],
    [Một lượt đọc cũ không được phép ghi đè thứ nó chưa từng thấy; bất biến trải qua
     nhiều bảng phải được kiểm tại thời điểm ghi.],
    [Tài khoản, bài đăng, đơn hàng, phiếu hỗ trợ, cuộc hội thoại.],

    [Đối tượng giá trị (Value Object)],
    [Một khái niệm không có định danh riêng và không sống độc lập thì không đáng có bảng
     riêng, nhưng vẫn đáng có kiểu riêng để mang quy tắc của nó.],
    [Hồ sơ hiển thị, tồn kho, vị trí, ảnh chụp địa chỉ, ảnh chụp bài đăng, phiếu chuyển
     tiền, tham chiếu sổ cái.],

    [Sổ đăng ký nhà cung cấp (Registry)],
    [Một bản ghi trong quá khứ ghi tên nhà cung cấp đã phục vụ nó, nên không thể dùng một
     biến chọn duy nhất cho cả hệ thống; hai kênh thanh toán phải sống được cùng lúc.],
    [Sổ đăng ký chung dùng cho kênh thanh toán và hãng vận chuyển, tra theo trường nhà
     cung cấp của từng dòng tùy chọn.],

    [Xuất bản – đăng ký (Publish/Subscribe)],
    [Bên gửi không cần biết ai đang nghe, và một bên nghe vắng mặt không làm bên gửi
     hỏng; nhờ đó chuỗi phụ thuộc đồng bộ giữa các module vẫn phi chu trình.],
    [Bảy chủ đề sự kiện miền; các lớp sự kiện của từng module.],

    [Khóa lũy đẳng và ghi có bảo vệ],
    [Mọi kênh đều là ít-nhất-một-lần, nên một thông điệp giao lại phải trở thành vô hiệu
     chứ không thành hiệu ứng thứ hai.],
    [Chuyển động tồn kho, chuyển động ví, tham chiếu nhà cung cấp trên chặng thanh toán,
     bảng kết cục đơn hàng.],
  ),
)

== Sơ đồ trình tự

=== Quy ước ký hiệu và danh mục kịch bản

Sáu kịch bản dưới đây được chọn theo ba tiêu chí: có nhiều điểm rẽ nhánh, đi qua nhiều
module, và sai thì tốn tiền thật.

Ký hiệu thống nhất trên cả sáu sơ đồ, và cần nói rõ vì nó ở *mức đối tượng* chứ không ở
mức module. Mỗi cột là một đối tượng tham gia, đặt tên đúng bằng lớp của nó — `orderapi
.Service`, `financeapi.Service`, `port.Repository`, `payment.Client` — còn tác nhân là
người thì ghi kèm dấu hai chấm ở đầu theo quy ước UML, chẳng hạn `:Người mua`. Đường sinh
nét đứt chạy dọc bên dưới mỗi cột, và *thanh kích hoạt* — đoạn dọc dày màu xám đè lên
đường sinh — cho biết khoảng thời gian đối tượng ấy đang giữ quyền điều khiển. Mũi tên nét
liền là lời gọi và mang *chữ ký phương thức* đặt bằng phông đơn cách, kèm một câu tiếng
Việt giải thích ý nghĩa nghiệp vụ ngay bên dưới; mũi tên nét đứt là giá trị trả về, cũng
mang kiểu trả về thật, hoặc là một thông điệp bất đồng bộ trên bus. Hộp bo tròn đặt trên
đường sinh là một mốc của quy trình bền, còn hộp chữ nhật nền xám là một bước xử lý bên
trong đối tượng, ghi phương thức miền mà nó gọi. Nhánh thay thế được đánh số kèm chữ cái,
và luồng ngoại lệ được ghi ngay trong nhãn thay vì vẽ thành một sơ đồ riêng, để hai luồng
cùng nằm trong một tầm mắt.

Một lưu ý về cách đọc các đường sinh mang tên `...api.Service`: chúng là *giao diện hợp
đồng* của một mô-đun chứ không phải một lớp hiện thực cụ thể, và đó chính là điều sơ đồ
muốn nói — một mô-đun gọi sang mô-đun khác luôn luôn chỉ nhìn thấy hợp đồng ấy. Bộ xử lý
tuyến không xuất hiện trên các sơ đồ này vì nó không ra quyết định nào; nó đã được đặc tả
riêng ở sơ đồ lớp tầng biên.

Một quy ước về thời gian cần nói trước, vì nó xuất hiện trong bốn trên sáu sơ đồ. Mọi
lần chờ có kỳ hạn của hệ thống — một lượt thanh toán chưa trả tiền hết hạn, cửa sổ ký
quỹ đóng lại, hạn của một yêu cầu hoàn tiền đi qua, một đánh giá ẩn tới ngày công bố —
đều là *một phương thức dịch vụ lũy đẳng*, chứ không phải một tác vụ nền có logic riêng.
Nền tảng thực thi bền gọi phương thức ấy đúng lúc, và một vòng quét định kỳ gọi *cùng*
phương thức ấy như tấm lưới đỡ bên dưới. Không bên nào là một định nghĩa thứ hai về
"đến hạn", nên bật cả hai cùng lúc không tốn gì: vòng quét chỉ đơn giản là không tìm
thấy gì. Nền tảng thực thi bền vì thế là một trong hai lựa chọn cấu hình; tắt nó đi là
một cách triển khai hợp lệ, và khi đó vòng quét là đồng hồ duy nhất.

#figure(
  kind: table,
  caption: [Danh mục kịch bản được lập sơ đồ trình tự],
  table(
    columns: (0.42fr, 1.25fr, 1.5fr),
    align: (left + top, left + top, left + top),
    table.header([Mã], [Kịch bản], [Lý do được chọn]),
    [TT-A], [Đặt hàng và giữ tiền ký quỹ],
    [Đi qua năm module và hai nhà cung cấp ngoài; là chỗ tiền đổi chủ lần đầu và là chỗ
     đơn hàng ra đời.],
    [TT-B], [Người bán xác nhận hoặc từ chối đơn],
    [Ba nhánh kết cục khác nhau, một trong ba do hết giờ; quyết định việc gọi hãng vận
     chuyển.],
    [TT-C], [Xác nhận nhận hàng và giải ngân sau 72 giờ],
    [Có bộ đếm giờ dài nhất hệ thống, có hai bộ dẫn động song song và một dấu hiệu đã
     xong để chống chạy lại.],
    [TT-D], [Yêu cầu hoàn tiền và leo thang thành phiếu hỗ trợ],
    [Máy trạng thái dày nhất còn lại; cắt ngang ba module và kết thúc bằng một phán quyết
     làm dịch chuyển tiền.],
    [TT-E], [Thương lượng giá],
    [Hai bên luân phiên; việc đồng ý *không* phải lúc bán được hàng, và điều đó dễ bị
     hiện thực sai.],
    [TT-F], [Tìm kiếm lai giữa từ khóa và ngữ nghĩa],
    [Luồng đọc quan trọng nhất, có bộ nhớ đệm, có đường suy giảm khi mô hình không sẵn
     sàng.],
  ),
)

=== TT-A: Đặt hàng và giữ tiền ký quỹ

Kịch bản bắt đầu khi người mua bấm mua trên trang bài đăng và kết thúc khi đơn hàng tồn
tại ở trạng thái chờ người bán xác nhận. Ba quyết định thiết kế chi phối toàn bộ trình
tự này. Thứ nhất, *quyền mua được chiếm trước khi tiền được hỏi tới*: lượt ghi hủy phiếu
mua chính là hành động chiếm, nên hai cú bấm liên tiếp chỉ mở được một phiên thanh toán
và cú thua bị từ chối ngay. Nếu chiếm sau, cả hai cú bấm đều mở phiên, chỉ lượt ghi cuối
thua, và một thương vụ có hai phiên đã trả tiền là khoản tiền mà ký quỹ không hạch toán
nổi. Thứ hai, *phí vận chuyển do máy chủ hỏi hãng vận chuyển*, không bao giờ do máy
khách gửi lên — một mức phí mà máy khách đặt tên được là một mức phí máy khách đặt bằng
không được; và một người bán chưa khai điểm lấy hàng sẽ làm hỏng lượt mua *trước* khi
tiền bị thu, chứ không phải sau. Thứ ba, *chỉ thông báo từ cổng thanh toán mới kết toán
một chặng tiền*: trang mà người mua rơi vào sau khi trả tiền là thứ bất kỳ ai cũng giả
mạo được, nên nó chỉ dùng để hiển thị.

#fig(
  [Sơ đồ trình tự TT-A: đặt hàng, mở phiên thanh toán và giữ tiền ký quỹ],
  spacing: (30mm, 7mm),
  np((0, 0), [:Người mua]),
  ncore((1, 0), [orderapi\ .Service]),
  np((2, 0), [catalogapi\ .Service]),
  np((3, 0), [financeapi\ .Service]),
  np((4, 0), [transport\ .Client]),
  np((5, 0), [payment\ .Client]),
  ..lifelines(6, y1: 19.4),
  act(1, 0.9, 10.3), act(2, 2.9, 4.1), act(4, 4.9, 6.3), act(3, 7.4, 8.8),
  act(3, 12.9, 15.1), act(1, 15.4, 19), act(2, 17.9, 18.4),

  msg(0, 1, 1, [1. #sig[`Checkout(CheckoutRequest)`]\ địa chỉ, hãng vận chuyển, các dòng hàng]),
  step(1, 2, [2. #sig[`DraftOrder.Cancel()`] — chiếm phiếu mua\ bằng lượt ghi có điều kiện "chưa hủy"]),
  msg(1, 2, 3, [3. #sig[`ReserveStock(StockMovementRequest)`]\ một lời gọi cho mỗi dòng hàng]),
  rmsg(2, 1, 4, [4. #sig[`error`] — rỗng nghĩa là đã giữ chỗ\ (khác rỗng: nhả hết, dừng)]),
  msg(1, 4, 5.1, [5. #sig[`Quote(QuoteParams)`]\ điểm lấy hàng và điểm giao]),
  rmsg(4, 1, 6.3, [6. #sig[`QuoteResult{Fee, ETA}`]]),
  msg(1, 3, 7.5, [7. #sig[`OpenCheckout(OpenCheckoutRequest)`]\ tiền hàng + phí vận chuyển]),
  rmsg(3, 1, 8.7, [8. #sig[`Session{ID, TotalAmount}`]\ mã phiên gắn vào từng dòng hàng]),
  durable(1, 9.9, [9. #sig[`Workflows.StartCheckout(sessionID)`]\ hạn trả tiền 15 phút]),
  rmsg(1, 0, 11, [10. #sig[`CheckoutResult{Session, Goods, Fee}`]]),
  msg(0, 5, 12, [11. Trả tiền trên trang\ của nhà cung cấp]),
  msg(5, 3, 13, [12. #sig[`Settle(payment.Notification)`]\ lời gọi lại: đã thu đủ]),
  step(3, 14, [13. #sig[`Transaction.Settle()`] rồi #sig[`Session.MarkPaid()`]\ cộng ví người mua, ghi có điều kiện]),
  rmsg(3, 1, 15, [14. #sig[`SessionPaid`] trên bus\ → #sig[`SettlePaidSession(sessionID)`]]),
  step(1, 16, [15. #sig[`domain.NewOrder(NewLine{...})`]\ ràng buộc duy nhất chặn đơn thứ hai]),
  msg(1, 3, 17, [16. #sig[`HoldEscrow(EscrowRequest)`]\ giữ tiền hàng + tách chân phí]),
  msg(1, 2, 18, [17. #sig[`CommitStock(StockCommitRequest)`]\ khóa lũy đẳng theo đơn và dòng]),
  rmsg(1, 0, 19, [18. #sig[`Order{State: awaiting-confirmation}`]]),
)

#note[
  *Luồng ngoại lệ.* Ở bước 4, một dòng hàng hết tồn kho làm cả lượt mua thất bại và mọi
  chỗ đã giữ trước đó được nhả lại ngay trong cùng lời gọi. Ở bước 6, người bán chưa có
  điểm lấy hàng thì lượt mua dừng tại đây, trước khi có bất kỳ khoản tiền nào. Nếu người
  mua không trả tiền trong mười lăm phút, quy trình bền ở bước 9 sẽ hủy các dòng hàng và
  nhả tồn kho; cùng việc ấy cũng xảy ra khi phiên bị hủy chủ động, qua một sự kiện riêng.
  Ở bước 12, một thông báo được giao lại lần thứ hai không tạo ra cú tính tiền thứ hai vì
  tham chiếu của nhà cung cấp là duy nhất; và nếu bước 13 thất bại, hệ thống trả về lỗi
  máy chủ để nhà cung cấp giao lại, bởi thông báo ấy là thứ duy nhất sẽ nhắc lại chuyện
  này. Điều đáng chú ý nhất ở bước 17: hãng vận chuyển *chưa* được gọi ở đây.
]

=== TT-B: Người bán xác nhận hoặc từ chối đơn hàng

Đây là kịch bản mới nhất trong vòng đời tiền của hệ thống và cũng là kịch bản đảo lại một
giả định cũ. Trước đó, thiết kế cho rằng người bán không có gì để duyệt vì thứ duy nhất
họ từ chối được là giá. Thực tế vận hành cho thấy có một thứ nữa: chính khả năng giao
hàng. Tiền đã nằm trong ký quỹ và đơn hàng đã tồn tại từ lúc thanh toán, nhưng *không gì
được chuyển tới hãng vận chuyển trước khi người bán chấp nhận*. Người bán có bốn mươi
tám giờ. Chấp nhận thì hệ thống mới đặt vận đơn. Từ chối thì đơn bị hủy kèm lý do và
người mua được hoàn *toàn bộ*, kể cả phí vận chuyển, vì kiện hàng chưa từng rời đi. Im
lặng hết giờ thì bộ phận vận hành được nhắc đi giục — hệ thống không tự hủy, cũng không
tự gửi hàng thay người bán.

#fig(
  [Sơ đồ trình tự TT-B: ba kết cục của cửa sổ xác nhận 48 giờ],
  spacing: (29mm, 7mm),
  np((0, 0), [:Người bán]),
  ncore((1, 0), [orderapi\ .Service]),
  np((2, 0), [transport\ .Client]),
  np((3, 0), [financeapi\ .Service]),
  np((4, 0), [trustapi\ .Service]),
  np((5, 0), [:Vận hành /\ :Người mua]),
  ..lifelines(6, y1: 17.6),
  act(1, 2.9, 6.4), act(2, 4.9, 6.1), act(1, 8.3, 12.6), act(3, 10.3, 10.7),
  act(2, 11.3, 11.7), act(1, 14.7, 17), act(4, 16.7, 17.6),

  durable(1, 1, [#sig[`Workflows.StartOrder(orderID)`] — cửa sổ 48 giờ]),
  nr((0, 2), text(size: 7pt)[alt: nhánh 1a — chấp nhận]),
  msg(0, 1, 3, [1a. #sig[`ConfirmOrder(ConfirmOrderRequest)`]]),
  step(1, 4, [2a. #sig[`Order.Confirm(now)`] rồi #sig[`Save`]\ ghi mốc và cam kết TRƯỚC khi gọi ra ngoài]),
  msg(1, 2, 5, [3a. #sig[`Book(BookParams)`]\ cố gắng hết sức]),
  rmsg(2, 1, 6, [4a. #sig[`BookResult{ProviderRef}`] → #sig[`Transport.Booked()`]\ thiếu thì vòng quét #sig[`RetryUnbookedShipments`]]),

  nr((0, 7.4), text(size: 7pt)[alt: nhánh 1b — từ chối]),
  msg(0, 1, 8.4, [1b. #sig[`DeclineOrder(DeclineOrderRequest)`]\ lý do là trường bắt buộc]),
  step(1, 9.4, [2b. #sig[`Order.Decline(reason)`] — hủy đơn,\ ghi lý do từ chối]),
  msg(1, 3, 10.4, [3b. #sig[`RefundEscrow(EscrowRequest)`]\ hoàn toàn bộ, kể cả phí vận chuyển]),
  msg(1, 2, 11.4, [4b. #sig[`UncommitStock(StockCommitRequest)`]]),
  rmsg(1, 4, 12.4, [5b. #sig[`OrderCancelled`] trên bus\ → trừ vào uy tín người bán]),

  nr((0, 13.8), text(size: 7pt)[alt: nhánh 1c — hết 48 giờ, không trả lời]),
  durable(1, 14.8, [1c. #sig[`EscalateUnconfirmedOrders(limit)`]\ quy trình bền hoặc vòng quét, cùng một phương thức]),
  step(1, 15.8, [2c. Đóng dấu #sig[`confirmation_escalated_at`]\ (không đổi trạng thái đơn)]),
  rmsg(1, 4, 16.8, [3c. #sig[`OrderConfirmationLapsed`] trên bus\ → #sig[`OpenTicket(order-issue)`]]),
  msg(4, 5, 17.6, [4c. Vận hành đi giục người bán]),
)

#note[
  Ở nhánh 1a, thứ tự "ghi trước, gọi ra ngoài sau" là có chủ đích: mốc xác nhận được ghi
  và cam kết xong mới gọi hãng vận chuyển, và việc đặt vận đơn là cố-gắng-hết-sức. Tiền
  đã dịch chuyển rồi, nên một hãng vận chuyển không liên lạc được là *một vận đơn phải
  đặt lại*, chứ không phải một đơn hàng phải từ chối; chính mã vận đơn đã lưu là dấu hiệu
  ngăn lượt đặt lại tạo ra kiện hàng thứ hai. Ở nhánh 1c, việc đóng dấu đã leo thang chỉ
  là một dấu hiệu chứ không phải một trạng thái: đơn vẫn đang chờ người bán xác nhận sau
  đó, và dấu hiệu ấy chỉ để vòng quét không nêu lại cùng một đơn mãi mãi.
]

=== TT-C: Xác nhận nhận hàng và giải ngân sau 72 giờ

Sau khi kiện hàng tới nơi, người mua xác nhận đã nhận và *phải* kèm bằng chứng mở hộp;
bằng chứng ấy được chốt ngay tại thời điểm đó và không bổ sung về sau, vì một yêu cầu
hoàn tiền sẽ được phán xử trên đúng những gì người mua trưng ra lúc mở hộp — một danh
sách có thể lớn dần sẽ làm yếu chính cái vai trò làm bằng chứng của nó. Từ mốc ấy, tiền
nằm yên bảy mươi hai giờ, là cửa sổ để người mua kịp mở một yêu cầu hoàn tiền; hết cửa
sổ mà không có gì xảy ra thì ký quỹ chuyển sang phần khả dụng của người bán.

Điểm kỹ thuật đáng nói là *dấu hiệu đã xong*, chứ không phải một khung thời gian. Lượt
giải ngân ghi lại thời điểm nó hoàn tất, nên tập đơn cần thử lại là *đúng* tập đơn còn
mắc kẹt: một nền tảng khỏe mạnh thì vòng quét đọc được số không. Nếu thay bằng "quét mọi
đơn hoàn thành trong bảy ngày qua" thì chi phí thử lại sẽ tăng theo lịch sử, rồi im lặng
trong khi khoản nợ vẫn còn đó.

#fig(
  [Sơ đồ trình tự TT-C: xác nhận nhận hàng và giải ngân ký quỹ],
  spacing: (31mm, 7.4mm),
  np((0, 0), [:Người mua]),
  ncore((1, 0), [orderapi\ .Service]),
  np((2, 0), [uploads\ .Store]),
  np((3, 0), [financeapi\ .Service]),
  np((4, 0), [:Người bán]),
  ..lifelines(5, y1: 13.4),
  act(1, 0.9, 6.2), act(2, 1.9, 3.1), act(1, 8.3, 13.4), act(3, 9.4, 10.8),

  msg(0, 1, 1, [1. #sig[`ConfirmReceipt(ConfirmReceiptRequest)`]\ kèm ảnh hoặc video mở hộp]),
  msg(1, 2, 2, [2. #sig[`Resolve(attachmentIDs)`]\ tệp có thật và đã hoàn tất tải lên]),
  rmsg(2, 1, 3, [3. #sig[`[]ResourceDTO`]\ thiếu một mã: từ chối cả yêu cầu]),
  step(1, 4, [4. #sig[`Order.ConfirmReceipt(now, attachments)`]\ chỉ ghi một lần, không bổ sung về sau]),
  durable(1, 5, [5. #sig[`Workflows.OrderReceived(orderID)`] — cửa sổ 72 giờ]),
  msg(1, 4, 6, [6. Thông báo mốc giải ngân dự kiến]),
  durable(1, 7.4, [7. #sig[`ReleaseDuePayouts(limit)`]\ hết 72 giờ, không hồ sơ hoàn tiền nào được mở]),
  step(1, 8.6, [8. #sig[`Repository.ClaimPayout(orderID)`]\ ghi có điều kiện, chống chạy đôi]),
  msg(1, 3, 9.6, [9. #sig[`ReleaseEscrow(EscrowRequest)`]\ tạm giữ → khả dụng của người bán]),
  rmsg(3, 1, 10.6, [10. #sig[`error`] rỗng — bút toán đã ghi]),
  step(1, 11.6, [11. #sig[`MarkPayoutReleased(orderID, now)`]\ = dấu hiệu "đã xong"]),
  rmsg(1, 4, 12.6, [12. Thông báo tiền đã về ví]),
  msg(1, 0, 13.4, [13. #sig[`Order.State()`] → #sig[`completed`]]),
)

#note[
  Nếu người mua mở một yêu cầu hoàn tiền trước khi hết bảy mươi hai giờ, quy trình bền ở
  bước 7 dừng đếm và chờ phán quyết thay vì chờ hết giờ; phán quyết nghiêng về người mua
  thì không có lượt giải ngân nào, nghiêng về người bán thì lượt giải ngân tiếp tục. Nếu
  bước 9 thất bại vì hệ thống tài chính tạm không trả lời, đơn đã bị chiếm ở bước 8 sẽ
  nằm trong tập mắc kẹt và được một vòng quét riêng thử lại, với chiến lược ghi nhật ký
  được trình bày ở phần thiết kế xử lý lỗi.
]

=== TT-D: Yêu cầu hoàn tiền và leo thang thành phiếu hỗ trợ

Đây là kịch bản cắt ngang nhiều module nhất, và cũng là nơi thể hiện rõ nhất một nguyên
tắc phân chia trách nhiệm: *tranh chấp là một phiếu hỗ trợ do module tín nhiệm quản lý,
còn phán quyết làm dịch chuyển tiền thì được ra ở nơi giữ tiền*. Module đơn hàng không
còn bảng tranh chấp nào; nó chỉ giữ trạng thái của yêu cầu hoàn tiền và ra phán quyết
tiền. Khi một yêu cầu bị đưa lên nhân viên vận hành, module tín nhiệm nghe được sự kiện
ấy và mở một phiếu loại tranh chấp hoàn tiền, trên chính cuộc hội thoại giữa người gửi
và bàn hỗ trợ. Khi phán quyết được ra, module đơn hàng phát một sự kiện kèm danh tính
người phán quyết, và module tín nhiệm ghi kết quả lên phiếu rồi đóng nó lại.

Hai chi tiết chống lỗi cần nêu. Việc mở phiếu tranh chấp *gọi sang module đơn hàng để
leo thang trước khi dòng phiếu được ghi*, nên một yêu cầu hoàn tiền không đủ điều kiện
leo thang sẽ không để lại một phiếu vô nghĩa mà không ai trả lời được. Và một phán quyết
sẽ đóng *mọi* phiếu đang mở về cùng đối tượng, chứ không phải một phiếu: ràng buộc duy
nhất là một phiếu mở cho mỗi người gửi, mà cả hai bên đều có quyền leo thang, nên một
phép tra chỉ trả về một dòng sẽ bỏ lại phiếu của bên kia mở mãi mãi — và không cách nào
đóng, vì loại phiếu này không cho phép giải quyết bằng tay.

#fig(
  [Sơ đồ trình tự TT-D: hoàn tiền, leo thang thành phiếu hỗ trợ và phán quyết],
  spacing: (28mm, 6.8mm),
  np((0, 0), [:Người mua]),
  ncore((1, 0), [orderapi\ .Service]),
  np((2, 0), [:Người bán]),
  np((3, 0), [trustapi\ .Service]),
  np((4, 0), [chatapi\ .Service]),
  np((5, 0), [:Nhân viên\ vận hành]),
  ..lifelines(6, y1: 19.4),
  act(1, 0.9, 4.3), act(1, 6, 7.6), act(3, 9.1, 13.8), act(1, 10.1, 11.7),
  act(1, 14.5, 17.1), act(3, 16.5, 19),

  msg(0, 1, 1, [1. #sig[`CreateRefund(CreateRefundRequest)`]\ lý do + bằng chứng]),
  step(1, 2, [2. #sig[`domain.NewRefund(...)`]\ trạng thái "chờ người bán xem xét", hạn 48 giờ]),
  durable(1, 3, [3. #sig[`Workflows.StartRefundWindow(refundID, status)`]\ đồng thời dừng cửa sổ ký quỹ]),
  msg(1, 2, 4, [4. Thông báo người bán có yêu cầu mới]),

  nr((2, 5.2), text(size: 7pt)[alt: nhánh 5a — người bán đồng ý]),
  msg(2, 1, 6.2, [5a. #sig[`AcceptRefund(RefundRequest)`]]),
  step(1, 7.2, [6a. #sig[`Refund.StartReturn()`] — mở chặng trả\ với phí bằng 0]),

  nr((2, 8.4), text(size: 7pt)[alt: nhánh 5b — người bán đưa lên, hoặc im lặng hết 48 giờ]),
  msg(2, 3, 9.4, [5b. #sig[`OpenTicket(kind: refund-dispute)`]]),
  msg(3, 1, 10.4, [6b. #sig[`EscalateRefund(EscalateRefundRequest)`]\ lũy đẳng, gọi TRƯỚC khi ghi phiếu]),
  rmsg(1, 3, 11.4, [7b. #sig[`Refund{Status: disputed}`]]),
  step(3, 12.4, [8b. #sig[`Repository.InsertTicket(...)`]]),
  msg(3, 4, 13.4, [9b. #sig[`OpenTicketThread(ticketID)`]\ cố gắng hết sức, sửa lại khi đọc]),

  msg(5, 1, 14.8, [10. #sig[`AdminResolveRefund(ResolveRefundRequest)`]\ người mua thắng hoặc người bán thắng]),
  step(1, 15.8, [11. #sig[`Refund.Resolve(buyerWins)`]\ thắng mà đã trả hàng → kết toán;\ thắng mà chưa trả → đang trả hàng; thua → từ chối]),
  msg(1, 3, 16.8, [12. #sig[`RefundResolved`] trên bus\ kèm danh tính người phán quyết]),
  step(3, 17.8, [13. #sig[`OpenTicketsAgainst(refType, refID)`]\ rồi đóng MỌI phiếu trong tập ấy]),
  msg(3, 4, 18.6, [14. #sig[`PostTicketMessage(...)`]]),
  rmsg(4, 0, 19.4, [15. Người gửi nhận được kết quả]),
)

#note[
  Trong nhánh 5b, thứ tự gọi là điều đáng chú ý nhất: module tín nhiệm gọi sang module
  đơn hàng *trước*, vì module đơn hàng mới là nơi sở hữu trạng thái của yêu cầu hoàn
  tiền, lời gọi ấy lũy đẳng, và chính bộ kiểm tra của nó sẽ từ chối sai người hoặc sai
  thời điểm. Ở bước 9b, luồng chat được mở theo kiểu cố-gắng-hết-sức và không bao giờ làm
  hỏng việc ghi phiếu: hai dòng nằm ở hai lược đồ, nên một sự cố của module hội thoại chỉ
  để lại một phiếu câm — và lần đọc phiếu kế tiếp sẽ mở luồng bù. Mất cuộc hội thoại
  không bao giờ được phép làm mất lời khiếu nại.
]

=== TT-E: Thương lượng giá

Với bài đăng cho phép thương lượng, giá niêm yết vẫn mua được bình thường; thương lượng
chỉ *thêm* một con đường chứ không thay thế con đường cũ. Hai bên luân phiên sửa điều
khoản ngay tại chỗ trên một dòng duy nhất, thay vì xếp chồng thêm dòng mới, nhờ đó câu
hỏi "đang đặt gì trên bàn" là một dòng chứ không phải một lượt quét cả luồng chat. Luồng
chat chỉ mang một con trỏ tới cuộc thương lượng và tuyệt đối *không* chép giá vào tin
nhắn — nếu chép, một lượt trả giá sẽ để lại trong luồng một mức giá không còn hiệu lực.

Điều dễ hiện thực sai nhất nằm ở chỗ *đồng ý không phải là bán được hàng*. Bên nào không
đang giữ đề nghị thì bên ấy được đồng ý, và việc đồng ý chỉ đóng băng giá trong ba mươi
phút; người mua vẫn phải bấm mua để chọn hãng vận chuyển và trả tiền. Chính sự tách đôi
này làm cho việc *người bán* đồng ý trở nên an toàn: chưa có đơn hàng và chưa có đồng
tiền nào cho tới khi người mua tự quyết.

#fig(
  [Sơ đồ trình tự TT-E: thương lượng giá và lối vào thanh toán],
  spacing: (31mm, 7.2mm),
  np((0, 0), [:Người mua]),
  ncore((1, 0), [orderapi\ .Service]),
  np((2, 0), [chatapi\ .Service]),
  np((3, 0), [:Người bán]),
  np((4, 0), [financeapi\ .Service]),
  ..lifelines(5, y1: 14.4),
  act(1, 0.9, 4.4), act(2, 2.9, 3.4), act(1, 5, 7.7), act(1, 8.2, 12.8),
  act(4, 10.4, 11.8), act(1, 13.4, 14.4),

  msg(0, 1, 1, [1. #sig[`CreateOffer(CreateOfferRequest)`]\ số lượng, tổng tiền]),
  step(1, 2, [2. #sig[`domain.NewOffer(NewTerms{...}, 12h)`]\ một cuộc đang mở cho mỗi cặp (người mua, biến thể)]),
  msg(1, 2, 3, [3. #sig[`PostSystemMessage(metadata: {offer_id})`]\ chỉ con trỏ, KHÔNG chép giá]),
  durable(1, 4, [4. #sig[`Workflows.StartOffer(offerID)`] — hạn 12 giờ]),
  msg(3, 1, 5, [5. #sig[`CounterOffer(CounterOfferRequest)`]\ sửa điều khoản tại chỗ, đổi bên giữ đề nghị, hạn chạy lại]),
  msg(0, 1, 6.2, [6. #sig[`AcceptOffer(OfferRequest)`]\ chỉ bên KHÔNG đang giữ đề nghị mới gọi được]),
  step(1, 7.2, [7. #sig[`Offer.Accept(now, 30m)`]\ đóng băng giá — chưa có đơn, chưa có tiền]),
  msg(0, 1, 8.4, [8. #sig[`CheckoutOffer(CheckoutOfferRequest)`]]),
  step(1, 9.4, [9. #sig[`Repository.ClaimOfferCheckout(offerID)`]\ chuyển "đã vào thanh toán" TRƯỚC khi giữ tồn kho]),
  msg(1, 4, 10.6, [10. #sig[`OpenCheckout(OpenCheckoutRequest)`]\ tiền hàng + phí vận chuyển]),
  rmsg(4, 1, 11.6, [11. #sig[`Session{ID}`]]),
  rmsg(1, 0, 12.6, [12. #sig[`CheckoutResult`] — chuyển sang TT-A từ bước 11]),
  durable(1, 13.6, [13. #sig[`ExpireOffers(limit)`]\ hạn đi qua mà không ai chốt → cuộc bị hủy]),
  msg(1, 3, 14.4, [14. Báo hai bên cuộc đã hết hạn]),
)

#note[
  Bước 9 là chỗ dễ sai nhất trong toàn kịch bản. Việc chuyển trạng thái phải xảy ra
  *trước* khi giữ tồn kho và trước khi mở phiên thanh toán, và bản thân lượt ghi ấy nêu
  đích danh trạng thái mà nó chuyển ra khỏi. Nếu có bất kỳ bước nào phía sau thất bại,
  quyền mua được trả lại nguyên vẹn, vì một người mua gặp trục trặc kỹ thuật thì nên thử
  lại chứ không nên phải thương lượng lại từ đầu. Ràng buộc duy nhất trên dòng hàng đứng
  phía sau tất cả những điều đó, vì một ràng buộc vẫn giữ đúng ngay cả khi tầng dịch vụ
  sai.
]

=== TT-F: Tìm kiếm lai giữa từ khóa và ngữ nghĩa

Kịch bản cuối cùng là luồng đọc, nhưng nó được lập sơ đồ vì có ba đường đi khác nhau tùy
tình huống và vì đường suy giảm của nó phải hoàn toàn không nhìn thấy được từ phía người
dùng. Truy vấn được chuẩn hóa rồi tra bộ nhớ đệm; trúng thì dùng lại véc-tơ đã có, trượt
thì gọi dịch vụ nhúng. Nếu dịch vụ nhúng không sẵn sàng — nó nằm ở một tiến trình khác,
thậm chí có thể không được triển khai — thì hệ thống *ghi nhật ký mức cảnh báo và tìm
bằng từ khóa*, chứ không trả lỗi cho người dùng. Đó là lý do một triển khai không chạy
tiến trình làm giàu véc-tơ vẫn là một triển khai hợp lệ.

#fig(
  [Sơ đồ trình tự TT-F: tìm kiếm lai và đường suy giảm về từ khóa],
  spacing: (31mm, 7.2mm),
  np((0, 0), [:Người dùng]),
  ncore((1, 0), [catalogapi\ .Service]),
  np((2, 0), [cache\ .Client]),
  np((3, 0), [embedding\ .Client]),
  np((4, 0), [port\ .Repository]),
  ..lifelines(5, y1: 13.4),
  act(1, 0.9, 13.4), act(2, 2.9, 4.1), act(3, 4.9, 6.1), act(4, 8.9, 11.2),

  msg(0, 1, 1, [1. #sig[`ListListings(ListListingsRequest)`]\ từ khóa, bộ lọc, cách sắp xếp, trang]),
  step(1, 2, [2. Chuẩn hóa: hạ chữ thường,\ gộp khoảng trắng, băm SHA-256]),
  msg(1, 2, 3, [3. #sig[`Get(key: model|dim|hash)`]]),
  rmsg(2, 1, 4, [4a. #sig[`[]float32`] — trúng đệm]),
  msg(1, 3, 5, [4b. #sig[`Embed(ctx, []string)`] — trượt đệm]),
  rmsg(3, 1, 6, [5b. #sig[`[][]float32`] hoặc #sig[`error`]]),
  step(1, 7, [6. #sig[`error`] khác rỗng ⇒ ghi cảnh báo, bỏ véc-tơ dò,\ suy giảm về tìm bằng từ khóa]),
  msg(1, 2, 8, [7. #sig[`Set(key, vec, 24h)`] — lỗi đệm thì bỏ qua]),
  msg(1, 4, 9, [8. #sig[`ListListings(port.ListingFilter)`]\ một câu lệnh: điểm = từ vựng + ngữ nghĩa, kèm mọi bộ lọc]),
  step(4, 10, [9. Nếu tiêu chí khác độ liên quan: lấy 200 ứng viên đầu,\ giữ phần có điểm ≥ 0,6 lần điểm cao nhất]),
  rmsg(4, 1, 11.2, [10. #sig[`([]Listing, total)`]\ tổng bỏ trống khi xếp theo độ liên quan]),
  msg(1, 4, 12.2, [11. #sig[`FavoritedAmong(actorID, ids)`]]),
  rmsg(1, 0, 13.4, [12. #sig[`ListingPage{Data, Meta}`]]),
)

#note[
  Bước 9 giải thích vì sao hệ thống *không* trả tổng số khi kết quả được xếp theo độ liên
  quan: một tập K phần tử tốt nhất không phải một tập có thể phân trang tuyệt đối, nên
  một con số tổng ở đó sẽ là con số không đúng. Ngược lại, khi người dùng chọn xếp theo
  giá hay theo lượt bán mà vẫn có từ khóa, hệ thống phải xếp lại *bên trong vùng còn liên
  quan* thay vì trên toàn bảng — nếu không, "áo khoác, giá tăng dần" sẽ trả về món rẻ
  nhất của toàn sàn.
]

=== Ma trận đối chiếu kịch bản, lớp và phương thức

Bảng dưới đây là bước kiểm tra tính nhất quán giữa hai loại sơ đồ: mọi phương thức xuất
hiện trên sơ đồ trình tự đều phải có mặt trong sơ đồ lớp tương ứng. Quá trình lập bảng
này đã phát hiện và sửa ba chỗ lệch, được ghi lại ở cuối bảng.

#figure(
  kind: table,
  caption: [Ma trận đối chiếu kịch bản – lớp tham gia – phương thức chính],
  table(
    columns: (0.3fr, 1.05fr, 1.5fr),
    align: (left + top, left + top, left + top),
    table.header([Mã], [Lớp tham gia], [Phương thức chính được gọi]),
    [TT-A], [Draft, Item, Order, Transport, Session, Movement, Stock],
    [Cancel (chiếm phiếu), Variant, ReserveStock, OpenCheckout, StartPayment, Settle,
     NewOrder, HoldEscrow, CommitStock, StartCheckout, CheckoutPaid, StartOrder.],
    [TT-B], [Order, Transport, Movement, Ticket],
    [Confirm, Decline, EscalateConfirmation, Booked, BookTransport, RefundEscrow,
     UncommitStock, OrderConfirmed, OrderCancelled, OpenTicket.],
    [TT-C], [Order, Wallet, Movement],
    [ConfirmReceipt, PayoutDue, ClaimPayout, ReleaseEscrow, MarkPayoutReleased,
     OrderReceived, ReleaseDuePayouts, RetryClaimedPayouts.],
    [TT-D], [Refund, Order, Transport, Ticket, Conversation, Message],
    [NewRefund, Accept, Escalate, EscalateUnanswered, StartReturn, MarkReturned,
     ClaimReturned, Settle, Resolve, OpenTicket, OpenTicketThread, RecordRefundVerdict,
     OpenTicketsAgainst, PostTicketMessage.],
    [TT-E], [Offer, Item, Session, Message],
    [NewOffer, Counter, Accept, CheckoutBy, CheckOut, ClaimOfferCheckout,
     ReleaseOfferCheckout, Expire, PostSystemMessage, StartOffer.],
    [TT-F], [Listing, ListingEmbedding, AccountInterest],
    [ListListings (dịch vụ), ListListings (kho chứa), InterestVectors, FavoritedAmong.],
  ),
)

#note[
  *Ba chỗ lệch được phát hiện khi đối chiếu.* Thứ nhất, sơ đồ trình tự của kịch bản TT-B
  cần một phương thức hỏi "chặng vận chuyển này đã có mã vận đơn chưa" để lượt đặt lại
  không tạo kiện hàng thứ hai; phương thức ấy có trong mã nguồn nhưng đã thiếu trong bản
  vẽ lớp trước đó và nay được bổ sung. Thứ hai, kịch bản TT-D cần một phép tra trả về
  *tập* phiếu đang mở về cùng một đối tượng chứ không phải một dòng; giao diện kho chứa
  của module tín nhiệm được bổ sung tương ứng. Thứ ba, kịch bản TT-E cho thấy việc chiếm
  quyền mua và việc trả lại quyền ấy là hai thao tác riêng của tầng kho chứa chứ không
  phải hai lượt ghi thông thường, nên cả hai được đưa vào sơ đồ lớp thay vì để ẩn trong
  tầng dịch vụ.
]

== Đặc tả thuật toán nghiệp vụ

=== Phạm vi lựa chọn và danh mục thuật toán

Phần này chỉ đặc tả những đoạn logic *đủ phức tạp để đáng được viết ra trước khi lập
trình*: có nhiều điều kiện lồng nhau, có tính toán nhiều bước, có yêu cầu về hiệu năng,
hoặc dễ sai một cách âm thầm. Các thao tác tạo, đọc, sửa, xóa thông thường đã được mô tả
đủ bằng sơ đồ lớp và sơ đồ trình tự nên không lặp lại ở đây. Mã giả được viết bằng tiếng
Việt có cấu trúc, cố ý *không* dùng cú pháp của bất kỳ ngôn ngữ lập trình nào, để người
đọc không phải là lập trình viên vẫn kiểm tra được logic nghiệp vụ.

Năm thuật toán dưới đây được chọn từ bộ yêu cầu ở Chương 3 và từ các phương thức đã xuất
hiện trong sơ đồ lớp ở đầu chương này. Mỗi thuật toán được đặc tả theo cùng một khuôn: mục
đích, đầu vào và đầu ra, tiền đề, mã giả, hậu điều kiện, phân tích độ phức tạp cả về thời
gian lẫn về bộ nhớ, một ví dụ vào–ra cụ thể, và các trường hợp biên. Ba thuật toán có cây
quyết định nhiều nhánh — TT-01, TT-03 và TT-05 — có thêm lưu đồ, vì với chúng thì hình vẽ
kiểm tra tính đầy đủ nhanh hơn văn bản.

#figure(
  kind: table,
  caption: [Danh mục thuật toán được đặc tả],
  table(
    columns: (0.24fr, 0.86fr, 0.46fr, 0.92fr, 0.86fr),
    align: (left + top, left + top, left + top, left + top, left + top),
    inset: (x: 4.5pt, y: 4.5pt),
    table.header([Mã], [Tên và mục đích], [Yêu cầu], [Lớp và phương thức hiện thực], [Độ phức tạp]),

    [TT-01], [Xếp hạng tìm kiếm lai giữa từ khóa và ngữ nghĩa],
    [REQ-14, REQ-15], 
    [`catalogapi.Service.ListListings`; `port.Repository.ListListings`; `AccountInterest.InterestVectors`],
    [Thời gian $O(k log k)$ trên $k lt.eq 200$ ứng viên sau một lượt quét chỉ mục; \ bộ nhớ $O(k)$],

    [TT-02], [Giữ và giải ngân tiền ký quỹ theo hai chặng],
    [REQ-26, REQ-28, REQ-32, REQ-35],
    [`financeapi.Service.HoldEscrow` / `ReleaseEscrow` / `RefundEscrow`; `port.Repository.Move`; `Wallet`, `Movement`],
    [Thời gian $O(1)$ — nhiều nhất ba chân bút toán; \ bộ nhớ $O(1)$],

    [TT-03], [Quyết định tập hành động hợp lệ trên một yêu cầu hoàn tiền],
    [REQ-33, REQ-34, REQ-35, REQ-36],
    [`Refund.Accept` / `Escalate` / `StartReturn` / `MarkReturned` / `Settle` / `Resolve`; `orderapi.Service.AdminResolveRefund`],
    [Thời gian $O(1)$; \ bộ nhớ $O(1)$ — tập hành động có kích thước chặn trên là ba],

    [TT-04], [Hàng đợi làm mới véc-tơ nhúng dựa trên dấu hiệu cũ dữ liệu],
    [REQ-16],
    [Tiến trình làm giàu véc-tơ; `port.Embeddings.ListStale` / `SaveEmbedding`],
    [Thời gian $O(n)$ theo số dòng còn trong hàng đợi, mỗi lô một lượt gọi mô hình; \ bộ nhớ $O(b)$ theo cỡ lô],

    [TT-05], [Mở hoặc nối lại một chặng thanh toán, và quyết toán phiên],
    [REQ-24, REQ-25, REQ-26],
    [`financeapi.Service.StartPayment` / `Settle`; `Session.Resumable` / `Charge` / `MarkPaid`; `Transaction.Resumable` / `Settle`; `port.Repository.SaveTransaction` / `SaveSession`],
    [Thời gian $O(L)$ theo số chặng của phiên, $L$ nhỏ theo cấu tạo; \ bộ nhớ $O(L)$],
  ),
)

Ba thuật toán trong bảng được đánh dấu là *nhạy hiệu năng* và được đối chiếu lại với các
yêu cầu phi chức năng ở cuối mục: TT-01 vì nó nằm trên luồng đọc bận nhất, TT-02 vì nó
tuần tự hóa các lượt ghi ví, và TT-04 vì nó là lượt xử lý theo lô nặng nhất hệ thống. Hai
thuật toán còn lại được chọn không vì hiệu năng mà vì *sai một cách âm thầm*: TT-03 quyết
định ai được làm gì trên một hồ sơ đang giữ tiền, còn TT-05 đứng đúng giữa người trả tiền
và cổng thanh toán.

=== TT-01: Xếp hạng tìm kiếm lai giữa từ khóa và ngữ nghĩa

*Mục đích.* Trả về danh sách bài đăng phù hợp nhất với một truy vấn của người dùng, kết
hợp *khớp từ vựng* — bắt đúng tên gọi, mã sản phẩm, cách viết tắt mà người bán dùng — với
*khớp ngữ nghĩa* — bắt được ý định khi người dùng mô tả món hàng bằng lời của mình. Hai
tín hiệu này bù cho nhau: khớp từ vựng vô dụng khi người dùng không biết tên sản phẩm,
còn khớp ngữ nghĩa hay bỏ sót khi truy vấn chính là một mã ký tự.

*Đầu vào.* Truy vấn văn bản (có thể rỗng), tập bộ lọc, cách sắp xếp, định danh người
xem, số trang và cỡ trang. *Đầu ra.* Một trang thẻ bài đăng đã xếp hạng, kèm tổng số khi
tổng ấy có nghĩa. *Tiền đề.* Ứng viên là bài đăng đang hoạt động và chưa bị xóa mềm;
riêng chủ sở hữu thì thấy được cả bản nháp của chính mình.

```
THUẬT TOÁN XếpHạngTìmKiếmLai

BẮT ĐẦU
    // --- Bước 1: xác định véc-tơ dò ---
    NẾU cách sắp xếp = "gợi ý cho tôi" THÌ
        véc_tơ_dò  ← véc-tơ sở thích mạnh nhất của người xem
        NẾU không có véc-tơ nào THÌ
            cách sắp xếp ← "mới nhất";  véc_tơ_dò ← rỗng
        dò_từ_truy_vấn ← SAI
    NGƯỢC LẠI NẾU truy vấn rỗng HOẶC chế độ = "chỉ từ khóa" THÌ
        véc_tơ_dò ← rỗng;  dò_từ_truy_vấn ← SAI
    NGƯỢC LẠI
        chuẩn ← hạ chữ thường và gộp khoảng trắng của truy vấn
        véc_tơ_dò ← đọc bộ nhớ đệm theo (tên mô hình, độ dài, băm SHA-256 của chuẩn)
        NẾU trượt đệm THÌ
            THỬ
                véc_tơ_dò ← gọi dịch vụ nhúng(chuẩn)
                ghi bộ nhớ đệm, thời hạn 24 giờ    // lỗi ghi đệm: bỏ qua
            NẾU THẤT BẠI
                ghi nhật ký mức cảnh báo
                véc_tơ_dò ← rỗng                   // suy giảm, KHÔNG trả lỗi
        dò_từ_truy_vấn ← ĐÚNG

    // --- Bước 2: định nghĩa điểm khớp của một bài đăng L ---
    từ_vựng(L)   = độ tương tự từ nghiêm ngặt giữa truy vấn và tên bài đăng,
                   cả hai đã bỏ dấu tiếng Việt
    ngữ_nghĩa(L) = 1 trừ khoảng cách cô-sin giữa véc_tơ_dò và véc-tơ dày của L,
                   bằng 0 nếu bài đăng chưa có véc-tơ

    điểm(L) = NẾU có véc_tơ_dò VÀ truy vấn khác rỗng  THÌ  từ_vựng(L) + ngữ_nghĩa(L)
              NGƯỢC LẠI NẾU có véc_tơ_dò              THÌ  ngữ_nghĩa(L)
              NGƯỢC LẠI NẾU truy vấn khác rỗng        THÌ  từ_vựng(L)
              NGƯỢC LẠI                                     không xác định

    // --- Bước 3: lọc ---
    ứng_viên ← mọi bài đăng thỏa toàn bộ bộ lọc
               (danh mục, người bán, tình trạng, đơn vị hành chính, bán kính,
                từ khóa, khoảng giá trên biến thể còn sống, đã thích)
    NẾU KHÔNG (có véc_tơ_dò VÀ dò_từ_truy_vấn) THÌ
        ứng_viên ← ứng_viên lọc thêm bằng cổng ba-ký-tự trên tên bài đăng
        // Có véc-tơ thật thì KHÔNG chặn bằng cổng này: kết quả được XẾP HẠNG,
        // không bị loại; chặn ở đây sẽ giết mọi kết quả ngữ nghĩa.

    // --- Bước 4: xếp hạng và phân trang ---
    NẾU dò_từ_truy_vấn VÀ cách sắp xếp không phải tiêu chí liên quan THÌ
        // Người dùng muốn xếp theo giá hoặc lượt bán, nhưng chỉ trong vùng còn liên quan
        vùng   ← 200 ứng viên có điểm cao nhất
        ngưỡng ← 0,6 × điểm cao nhất trong vùng
        vùng   ← các phần tử của vùng có điểm ≥ ngưỡng
        kết_quả ← sắp xếp vùng theo tiêu chí người dùng chọn; lấy trang yêu cầu
        tổng_số ← số phần tử của vùng
    NGƯỢC LẠI
        kết_quả ← sắp xếp ứng_viên theo tiêu chí (mặc định: điểm giảm dần,
                  đồng điểm thì bài mới hơn đứng trước); lấy trang yêu cầu
        tổng_số ← số phần tử của ứng_viên NẾU tiêu chí không phải độ liên quan
                  NGƯỢC LẠI không xác định

    // --- Bước 5: làm giàu ---
    đánh dấu những bài đăng mà người xem đã thích
    TRẢ VỀ kết_quả, tổng_số
KẾT THÚC
```

#fig(
  [Lưu đồ TT-01: ba đường đi của một lượt tìm kiếm và điểm suy giảm],
  spacing: (40mm, 10mm),

  nt((1, 0), [Bắt đầu: truy vấn,\ bộ lọc, cách sắp xếp]),
  edge((1, 0), (1, 1), "-|>"),
  nd((1, 1), [Cách sắp xếp là\ "gợi ý cho tôi"?]),
  edge((1, 1), (0, 2), "-|>", text(size: 8pt)[Có], label-side: left),
  nd((0, 2), [Người xem có\ véc-tơ sở thích?]),
  edge((0, 2), (0, 3), "-|>", text(size: 8pt)[Có], label-side: left),
  np((0, 3), [Véc-tơ dò ← véc-tơ\ sở thích mạnh nhất]),
  edge((0, 2), (1, 4), "-|>", text(size: 8pt)[Không: hạ về "mới nhất"]),

  edge((1, 1), (1, 2), "-|>", text(size: 8pt)[Không]),
  nd((1, 2), [Truy vấn rỗng hoặc\ chế độ chỉ-từ-khóa?]),
  edge((1, 2), (1, 4), "-|>", text(size: 8pt)[Có: không có véc-tơ dò]),
  edge((1, 2), (2, 2), "-|>", text(size: 8pt)[Không]),
  np((2, 2), [Chuẩn hóa truy vấn,\ tra bộ nhớ đệm véc-tơ]),
  edge((2, 2), (2, 3), "-|>"),
  nd((2, 3), [Trúng đệm?]),
  edge((2, 3), (2, 4), "-|>", text(size: 8pt)[Không: gọi dịch vụ nhúng]),
  nd((2, 4), [Dịch vụ nhúng\ trả lời được?]),
  edge((2, 4), (1, 4), "-|>", text(size: 8pt)[Không: ghi cảnh báo,\ bỏ véc-tơ dò], label-side: left),
  edge((2, 4), (2, 5), "-|>", text(size: 8pt)[Có: ghi đệm 24 giờ]),
  edge((2, 3), (2, 5), "-|>", bend: -40deg, text(size: 8pt)[Có]),
  np((2, 5), [Có véc-tơ dò\ từ truy vấn]),

  np((1, 4), [Không có véc-tơ dò\ từ truy vấn]),
  edge((1, 4), (1, 6), "-|>"),
  edge((0, 3), (1, 6), "-|>"),
  edge((2, 5), (1, 6), "-|>"),

  nd((1, 6), [Có véc-tơ dò lấy\ từ chính truy vấn?]),
  edge((1, 6), (0, 7), "-|>", text(size: 8pt)[Không], label-side: left),
  np((0, 7), [Lọc thêm bằng\ cổng ba-ký-tự trên tên]),
  edge((1, 6), (1, 7), "-|>", text(size: 8pt)[Có: KHÔNG chặn,\ chỉ xếp hạng]),
  np((1, 7), [Chấm điểm:\ từ vựng + ngữ nghĩa]),
  edge((0, 7), (1, 8), "-|>"),
  edge((1, 7), (1, 8), "-|>"),

  nd((1, 8), [Người dùng chọn tiêu chí\ khác độ liên quan?]),
  edge((1, 8), (2, 9), "-|>", text(size: 8pt)[Có]),
  np((2, 9), [Lấy 200 ứng viên đầu,\ giữ phần có điểm ≥ 0,6 lần\ điểm cao nhất, xếp lại\ theo tiêu chí ấy]),
  edge((1, 8), (0, 9), "-|>", text(size: 8pt)[Không], label-side: left),
  np((0, 9), [Xếp theo điểm giảm dần;\ tổng số không xác định]),
  edge((0, 9), (1, 10), "-|>"),
  edge((2, 9), (1, 10), "-|>"),
  ng((1, 10), [Đánh dấu mục đã thích]),
  edge((1, 10), (1, 11), "-|>"),
  nt((1, 11), [Trả về trang kết quả]),
)

*Hậu điều kiện.* Kết quả chỉ chứa bài đăng thỏa mọi bộ lọc; thứ tự đơn điệu theo tiêu chí
đã chọn; tổng số hoặc là con số đúng của một tập phân trang được, hoặc là không xác định
— không bao giờ là một con số gần đúng.

*Ví dụ vào–ra.* Với đầu vào là truy vấn `"canon 200d"`, bộ lọc `{danh mục: máy ảnh, giá
từ 3.000.000 tới 8.000.000}`, cách sắp xếp `giá tăng dần`, trang 1 cỡ 20: bước 1 chuẩn hóa
thành `canon 200d`, trượt đệm, gọi dịch vụ nhúng và nhận về một véc-tơ 1024 chiều. Bước 3
cho 47 ứng viên qua bộ lọc, và vì đã có véc-tơ dò nên cổng ba-ký-tự *không* được áp — nhờ
đó một tin đăng tên `"Máy ảnh Canon EOS 200D thân máy"` và một tin tên `"Body EOS 200 D
kèm lens kit"` đều còn trong tập, dù tin thứ hai không khớp ba ký tự nào với chuỗi truy
vấn. Điểm cao nhất trong vùng là 1,84 nên ngưỡng là 1,10; 12 trong 47 ứng viên vượt
ngưỡng. Đầu ra là 12 thẻ bài đăng xếp theo giá tăng dần, với tổng số bằng 12 — chứ *không*
phải 47, vì 47 là số ứng viên còn 12 mới là tập mà người dùng đang phân trang. Cùng truy
vấn ấy khi dịch vụ nhúng không trả lời: véc-tơ dò rỗng, cổng ba-ký-tự được áp, tập ứng
viên rút còn 9 tin, và người dùng nhận về 9 kết quả cùng một dòng nhật ký mức cảnh báo ở
phía máy chủ — không có lỗi nào hiển thị.

*Phân tích độ phức tạp.* Về *thời gian*: bước lọc là một lượt quét chỉ mục, chi phí tỉ lệ
với số ứng viên khớp chứ không với kích thước bảng; bước xếp hạng lại chạy trên vùng đã bị
chặn ở $k = 200$ phần tử nên tốn $O(k log k)$, tức là hằng số theo kích thước dữ liệu.
Ngưỡng liên quan lấy theo *tỉ lệ với điểm cao nhất* chứ không phải một ngưỡng tuyệt đối,
vì thang điểm của một truy vấn hẹp và một truy vấn rộng khác hẳn nhau; số liệu đo được cho
thấy các kết quả đúng của một truy vấn hẹp nằm trong khoảng từ 0,93 đến 1,00 lần điểm cao
nhất, còn kết quả sai đầu tiên rơi xuống quanh 0,47. Việc chọn *độ tương tự từ nghiêm
ngặt* thay vì độ tương tự toàn chuỗi là bắt buộc chứ không phải tinh chỉnh: đo trên dữ
liệu thật, một truy vấn hai từ so với một tên dài bốn mươi ký tự chỉ đạt khoảng 0,05
điểm, tức không kết quả nào vượt nổi ngưỡng.

Về *bộ nhớ*: phía ứng dụng giữ nhiều nhất $O(k)$ thẻ bài đăng cùng một véc-tơ dò 1024
chiều, tức khoảng 4 KB cho véc-tơ và vài chục KB cho vùng ứng viên — không phụ thuộc kích
thước bảng, vì việc chặn ở hai trăm phần tử xảy ra *trong* câu lệnh truy vấn chứ không
phải sau khi đã nạp hết. Chi phí bộ nhớ đáng kể nằm ở phía cơ sở dữ liệu chứ không ở tiến
trình: chỉ mục HNSW được nạp vào bộ đệm và với hai trăm nghìn bài đăng thì phần véc-tơ dày
chiếm khoảng 800 MB. Đây là ràng buộc thật khi định cỡ máy chủ, và cũng là lý do véc-tơ
thưa bị cắt còn một nghìn phần tử nặng nhất ở TT-04.

*Các trường hợp biên.* Truy vấn rỗng và không có véc-tơ sở thích: điểm không xác định,
danh sách xếp theo thời gian tạo. Bài đăng chưa có véc-tơ: phần ngữ nghĩa bằng không
nhưng bài đăng vẫn tìm được bằng từ khóa, nên một lượt làm giàu véc-tơ chậm không làm
hàng biến mất. Dịch vụ nhúng lỗi hoặc không được triển khai: suy giảm hoàn toàn về từ
khóa và người dùng không thấy lỗi. Người xem chưa đăng nhập và chọn "gợi ý cho tôi":
không có véc-tơ sở thích nên tiêu chí tự hạ xuống "mới nhất". Truy vấn có dấu và dữ liệu
không dấu, hoặc ngược lại: cả hai vế đều được bỏ dấu trước khi so.

=== TT-02: Giữ và giải ngân tiền ký quỹ theo hai chặng

*Mục đích.* Dịch chuyển tiền giữa các ví sao cho mọi chân bút toán của cùng một sự kiện
hoặc cùng thành công hoặc cùng không xảy ra, và sao cho một thông điệp được giao lại lần
thứ hai trở thành vô hiệu thay vì thành hiệu ứng thứ hai. Ba thủ tục cùng chia nhau một
hàm ghi ví duy nhất, và chính hàm ấy giữ toàn bộ tính nguyên tử.

*Đầu vào.* Định danh đơn hàng, số tiền hàng, phí vận chuyển, khóa lũy đẳng nền do bên
gọi cung cấp. *Đầu ra.* Tập bút toán đã ghi, hoặc dấu hiệu "đã ghi trước đó". *Tiền đề.*
Số tiền hàng dương; phí vận chuyển không âm; đơn hàng đã tồn tại.

```
THỦ TỤC ÁpDụngMộtLầnDịchChuyển(danh sách chân bút toán)
BẮT ĐẦU
    MỞ giao dịch cơ sở dữ liệu
    cấp một mã nhóm dùng chung cho mọi chân trong lần này
    khóa các ví liên quan theo THỨ TỰ CỐ ĐỊNH (định danh tài khoản, rồi tiền tệ)
        // Thứ tự cố định là thứ ngăn hai lần dịch chuyển ngược chiều khóa chéo nhau
    VỚI MỖI chân TRONG danh sách
        NẾU khóa lũy đẳng của chân đã tồn tại THÌ
            HỦY giao dịch;  TRẢ VỀ "đã ghi trước đó"
        cấp số thứ tự kế tiếp của ví ấy
        số dư mới ← số dư hiện tại + biến thiên của chân
        NẾU số dư khả dụng mới < 0 HOẶC số dư tạm giữ mới < 0 THÌ
            HỦY giao dịch;  BÁO LỖI "số dư không đủ"
        NẾU cả hai biến thiên đều bằng 0 THÌ
            HỦY giao dịch;  BÁO LỖI "bút toán rỗng"
        ghi dòng sổ cái: biến thiên, số dư TRƯỚC và SAU, mã nhóm, tham chiếu, khóa
        cập nhật số dư của ví
    CAM KẾT giao dịch
KẾT THÚC

THỦ TỤC GiữKýQuỹ(đơn, tiền_hàng, phí_vận_chuyển, khóa_nền)
    // Gọi ngay khi phiên thanh toán báo đã thu đủ
    chân_1 ← ví người mua : khả dụng −tiền_hàng, tạm giữ 0,
             loại "giữ ký quỹ", khóa = khóa_nền + ":người mua"
    chân_2 ← ví người bán : khả dụng 0, tạm giữ +tiền_hàng,
             loại "giữ ký quỹ", khóa = khóa_nền + ":người bán"
    NẾU phí_vận_chuyển > 0 THÌ
        chân_3 ← ví người mua : khả dụng −phí_vận_chuyển,
                 loại "phí", khóa = khóa_nền + ":vận chuyển"
        // Phí đi thành CHÂN RIÊNG chứ không cộng vào ký quỹ: đó là tiền của hãng
        // vận chuyển, và một lượt giải ngân không bao giờ được trao nó cho người bán.
    ÁpDụngMộtLầnDịchChuyển(các chân trên)

THỦ TỤC GiảiNgân(đơn, tiền_hàng, khóa_nền)
    // Gọi khi cửa sổ 72 giờ đóng lại mà không có yêu cầu hoàn tiền
    chân_1 ← ví người bán : tạm giữ −tiền_hàng, khả dụng +tiền_hàng,
             loại "giải ngân ký quỹ", khóa = khóa_nền
    ÁpDụngMộtLầnDịchChuyển(chân_1)

THỦ TỤC HoànKýQuỹ(đơn, tiền_hàng, phí_hoàn_lại, khóa_nền)
    // phí_hoàn_lại = toàn bộ phí NẾU kiện hàng chưa từng rời đi (người bán từ chối,
    //                hoặc đơn bị hủy trước khi giao)
    // phí_hoàn_lại = 0    NẾU phán quyết hoàn tiền sau khi hàng đã đi:
    //                cước đã phát sinh thì vẫn là cước đã mua
    chân_1 ← ví người bán : tạm giữ −tiền_hàng, loại "hoàn tiền",
             khóa = khóa_nền + ":người bán"
    chân_2 ← ví người mua : khả dụng +tiền_hàng, loại "hoàn tiền",
             khóa = khóa_nền + ":người mua"
    NẾU phí_hoàn_lại > 0 THÌ
        chân_3 ← ví người mua : khả dụng +phí_hoàn_lại, loại "hoàn tiền",
                 khóa = khóa_nền + ":vận chuyển"
    ÁpDụngMộtLầnDịchChuyển(các chân trên)
```

*Hậu điều kiện.* Sau khi giữ ký quỹ, tổng tài sản của hệ thống không đổi; phần tạm giữ
của người bán tăng đúng bằng phần khả dụng bị trừ của người mua; phí vận chuyển rời khỏi
ví người mua nhưng không bao giờ nhập vào phần tạm giữ của người bán. Mọi dòng sổ cái
đều mang số dư trước và sau, nên một lượt đối soát chỉ cần đọc dòng cuối của mỗi ví.

*Ví dụ vào–ra.* Đơn `ord_9wq3nz6ktr8h`, tiền hàng 4.000.000, phí vận chuyển 235.000, khóa
lũy đẳng nền `order:50231`. Trước lượt dịch chuyển, ví người mua có khả dụng 5.000.000 và
tạm giữ 0; ví người bán có khả dụng 1.250.000 và tạm giữ 0. Thủ tục *GiữKýQuỹ* sinh ba
chân: người mua khả dụng −4.000.000 loại "giữ ký quỹ"; người bán tạm giữ +4.000.000 loại
"giữ ký quỹ"; người mua khả dụng −235.000 loại "phí". Sau khi cam kết, ví người mua còn
khả dụng 765.000 và tạm giữ 0, ví người bán còn khả dụng 1.250.000 và tạm giữ 4.000.000.
Tổng tài sản trong hệ thống giảm đúng 235.000 — bằng đúng khoản đã rời sang hãng vận
chuyển — và phần tạm giữ của người bán *không* chứa một đồng phí nào. Ba ngày sau, thủ tục
*GiảiNgân* với cùng khóa nền sinh đúng một chân: người bán tạm giữ −4.000.000 và khả dụng
+4.000.000, để lại khả dụng 5.250.000 và tạm giữ 0. Nếu lời gọi *GiữKýQuỹ* được lặp lại
với cùng khóa nền, chân đầu tiên va vào khóa lũy đẳng đã tồn tại, toàn bộ giao dịch bị
hủy, và bên gọi nhận dấu hiệu "đã ghi trước đó" — không có dòng sổ cái thứ tư nào.

*Phân tích độ phức tạp.* Về *thời gian*, chi phí là $O(1)$ theo số chân — nhiều nhất ba
chân cho một lần dịch chuyển — cộng chi phí khóa hàng của các ví liên quan. Điểm cần lưu ý
về hiệu năng không nằm ở số phép tính mà ở *tranh chấp khóa*: mọi thay đổi số dư đều đi
qua một lượt khóa hàng, nên hai đơn hàng của cùng một người bán bị tuần tự hóa. Đây là
đánh đổi có chủ đích, vì số thứ tự tuyệt đối trong ví phải được cấp dưới cùng lượt khóa
với chính lần đổi số dư. Ở khối lượng mục tiêu — năm nghìn đơn mỗi ngày, tức trung bình
dưới một lượt giữ ký quỹ mỗi mười giây — hàng đợi khóa trên một ví là rỗng gần như luôn
luôn; ngưỡng đáng lo là một người bán xử lý nhiều đơn mỗi giây, và khi tới ngưỡng ấy thì
cách gỡ là gộp bút toán theo lô chứ không phải bỏ khóa.

Về *bộ nhớ*, chi phí là $O(1)$: thủ tục giữ đúng một danh sách nhiều nhất ba chân bút toán
và hai hàng ví, không nạp lịch sử sổ cái. Đây chính là lý do mỗi dòng sổ cái mang sẵn số
dư *trước* và *sau* — nhờ vậy một lượt đối soát chỉ đọc dòng cuối của mỗi ví, thay vì phải
cộng dồn toàn bộ lịch sử vào bộ nhớ.

*Các trường hợp biên.* Khóa lũy đẳng trùng: toàn bộ lần dịch chuyển bị hủy và bên gọi
nhận dấu hiệu "đã ghi trước đó", được coi là thành công. Phí vận chuyển bằng không:
không sinh chân thứ ba, vì một bút toán rỗng là một dòng không nói lên điều gì và vẫn
phải bị loại khỏi mọi phép đếm về sau. Số dư âm sau khi áp dụng: cả lần dịch chuyển bị
từ chối, kể cả khi chỉ một chân vi phạm. Người mua và người bán trùng nhau: bị chặn từ
tầng trên, vì một cuộc thương lượng với chính mình đã bị từ chối lúc khởi tạo.

=== TT-03: Quyết định tập hành động hợp lệ trên một yêu cầu hoàn tiền

*Mục đích.* Với một yêu cầu hoàn tiền, một người gọi và một thời điểm, trả lời câu hỏi
"người này được làm gì lúc này". Thuật toán được đặc tả riêng vì cùng một bộ quy tắc
được dùng ở ba nơi: quyết định nút nào hiển thị trên giao diện, quyết định một lời gọi
có được chấp nhận không, và quyết định bộ đếm giờ đến hạn thì làm gì.

*Đầu vào.* Yêu cầu hoàn tiền, đơn hàng của nó, định danh và vai của người gọi, thời điểm
hiện tại. *Đầu ra.* Tập hành động hợp lệ, có thể rỗng.

```
THUẬT TOÁN TậpHànhĐộngHợpLệ(hồ_sơ, đơn, người_gọi, bây_giờ)
BẮT ĐẦU
    NẾU người_gọi không phải người mua, không phải người bán của đơn,
        và không phải nhân viên vận hành THÌ
        TRẢ VỀ tập rỗng
        // Và phép tra cứu trả 404 chứ không phải 403: mã hồ sơ là thứ đoán được,
        // nên 403 sẽ xác nhận cho người lạ rằng hồ sơ ấy có thật.

    NẾU hồ_sơ ở trạng thái kết thúc (đã chấp nhận | đã từ chối | đã rút) THÌ
        TRẢ VỀ tập rỗng
    NẾU đơn đã kết thúc THÌ
        TRẢ VỀ tập rỗng

    vai ← vai của người_gọi trên đơn
    hành_động ← tập rỗng

    TRƯỜNG HỢP hồ_sơ.trạng_thái LÀ

        "chờ người bán xem xét":        // có thời hạn: mở hồ sơ + 48 giờ
            NẾU vai = người mua THÌ
                thêm {rút yêu cầu, bổ sung bằng chứng}
            NẾU vai = người bán THÌ
                thêm {đồng ý hoàn tiền, đưa lên nhân viên vận hành, bổ sung bằng chứng}
            NẾU bây_giờ đã quá thời hạn THÌ
                hành động của HỆ THỐNG: {leo thang vì không trả lời}
                // Chuyển sang tranh chấp, KHÔNG ghi mốc "người bán đã quyết"

        "đang trả hàng":                // KHÔNG có thời hạn: đang chờ hãng vận chuyển
            NẾU vai = người bán THÌ
                thêm {xác nhận đã nhận hàng trả}      // → "đã nhận hàng trả", +48 giờ
            NẾU vai = người mua THÌ
                thêm {khai đã trả hàng}               // → "đang tranh chấp"
            thêm {bổ sung bằng chứng} cho cả hai bên

        "đã nhận hàng trả":             // có thời hạn: xác nhận + 48 giờ
            NẾU vai = người bán THÌ
                thêm {đưa lên nhân viên vận hành, bổ sung bằng chứng}
            NẾU vai = người mua THÌ
                thêm {bổ sung bằng chứng}
            NẾU bây_giờ đã quá thời hạn THÌ
                hành động của HỆ THỐNG: {kết toán cho người mua}

        "đang tranh chấp":              // KHÔNG có thời hạn: đang chờ con người
            NẾU vai = nhân viên vận hành THÌ
                thêm {phán quyết người mua thắng, phán quyết người bán thắng}
            NGƯỢC LẠI
                thêm {bổ sung bằng chứng}

    TRẢ VỀ hành_động
KẾT THÚC

THỦ TỤC ÁpDụngPhánQuyết(hồ_sơ, người_mua_thắng)
    ĐIỀU KIỆN TRƯỚC: hồ_sơ đang ở "đang tranh chấp", nếu không thì từ chối
    NẾU người_mua_thắng VÀ hồ_sơ đã có mốc "đã trả hàng"  THÌ
        kết toán cho người mua               // → "đã chấp nhận", tiền chạy
    NẾU người_mua_thắng VÀ hồ_sơ CHƯA có mốc "đã trả hàng" THÌ
        chuyển "đang trả hàng"               // thắng nhưng vẫn phải trả hàng trước
    NẾU KHÔNG người_mua_thắng THÌ
        chuyển "đã từ chối"                  // tiền ở lại ký quỹ, đơn đi tiếp
```

#fig(
  [Lưu đồ TT-03: cây quyết định của một yêu cầu hoàn tiền],
  spacing: (37mm, 9.5mm),

  nt((1, 0), [Bắt đầu: hồ sơ, đơn,\ người gọi, thời điểm]),
  edge((1, 0), (1, 1), "-|>"),
  nd((1, 1), [Người gọi là một bên\ của đơn, hoặc là\ nhân viên vận hành?]),
  edge((1, 1), (0, 1), "-|>", text(size: 8pt)[Không], label-side: left),
  nr((0, 1), [Trả 404, không phải 403:\ mã hồ sơ là thứ đoán được]),
  edge((1, 1), (1, 2), "-|>", text(size: 8pt)[Có]),
  nd((1, 2), [Hồ sơ đã kết thúc,\ hoặc đơn đã kết thúc?]),
  edge((1, 2), (0, 2), "-|>", text(size: 8pt)[Có], label-side: left),
  nr((0, 2), [Tập hành động rỗng]),
  edge((1, 2), (1, 3), "-|>", text(size: 8pt)[Không]),
  nd((1, 3), [Trạng thái hiện tại\ của hồ sơ?]),

  edge((1, 3), (0, 4), "-|>", text(size: 7.5pt)[chờ người bán\ xem xét], label-side: left),
  np((0, 4), [Mua: rút, bổ sung bằng chứng\ Bán: đồng ý, đưa lên vận hành,\ bổ sung bằng chứng]),
  edge((0, 4), (0, 5), "-|>"),
  nd((0, 5), [Quá hạn 48 giờ?]),
  edge((0, 5), (0, 6), "-|>", text(size: 8pt)[Có]),
  ng((0, 6), [Hệ thống leo thang\ vì không trả lời]),

  edge((1, 3), (1, 4), "-|>", text(size: 7.5pt)[đang trả hàng]),
  np((1, 4), [Mua: khai đã trả hàng\ Bán: xác nhận đã nhận hàng trả\ Cả hai: bổ sung bằng chứng\ KHÔNG có hạn chót]),

  edge((1, 3), (2, 4), "-|>", text(size: 7.5pt)[đã nhận hàng trả]),
  np((2, 4), [Bán: đưa lên vận hành\ Cả hai: bổ sung bằng chứng]),
  edge((2, 4), (2, 5), "-|>"),
  nd((2, 5), [Quá hạn 48 giờ\ kiểm hàng?]),
  edge((2, 5), (2, 6), "-|>", text(size: 8pt)[Có]),
  ng((2, 6), [Hệ thống kết toán\ cho người mua]),

  edge((1, 3), (1, 7), "-|>", bend: -32deg, text(size: 7.5pt)[đang tranh chấp]),
  nd((1, 7), [Người gọi là nhân viên\ vận hành?]),
  edge((1, 7), (2, 8), "-|>", text(size: 8pt)[Có]),
  np((2, 8), [Hai phán quyết:\ người mua thắng\ hoặc người bán thắng]),
  edge((1, 7), (0, 8), "-|>", text(size: 8pt)[Không], label-side: left),
  np((0, 8), [Chỉ bổ sung bằng chứng]),
  edge((2, 8), (2, 9), "-|>"),
  nd((2, 9), [Người mua thắng\ và đã trả hàng?]),
  edge((2, 9), (1, 10), "-|>", text(size: 8pt)[Có: kết toán], label-side: left),
  edge((2, 9), (2, 10), "-|>", text(size: 8pt)[Thắng mà chưa trả:\ chuyển "đang trả hàng"]),
  ng((1, 10), [Tiền chạy về\ người mua]),
  ng((2, 10), [Quay lại nhánh\ trả hàng]),
)

*Hậu điều kiện.* Mỗi lượt ghi nêu đích danh trạng thái mà nó chuyển ra khỏi, nên hai lượt
ghi đồng thời thì lượt đọc cũ thua chứ không ghi đè. Một hồ sơ đã kết thúc không bao giờ
quay lại trạng thái chưa kết thúc.

*Ví dụ vào–ra.* Hồ sơ ở trạng thái "chờ người bán xem xét", mở lúc 09:00 ngày 4 tháng 5
nên hạn chót là 09:00 ngày 6. Gọi thuật toán lúc 10:00 ngày 4 với người gọi là *người
mua*: đầu ra là `{rút yêu cầu, bổ sung bằng chứng}`. Cùng thời điểm ấy với người gọi là
*người bán*: đầu ra là `{đồng ý hoàn tiền, đưa lên nhân viên vận hành, bổ sung bằng
chứng}` — chú ý rằng "từ chối" không có trong tập này ở bất kỳ trạng thái nào. Với người
gọi là một tài khoản thứ ba: đầu ra là tập rỗng và phép tra cứu trả 404. Gọi lại lúc 09:01
ngày 6, tức sau hạn: tập hành động của hai bên vẫn như cũ, nhưng thêm một hành động *của
hệ thống* là `{leo thang vì không trả lời}`, và vòng quét sẽ chuyển hồ sơ sang "đang tranh
chấp" mà không ghi mốc "người bán đã quyết". Nếu trong khoảng thời gian ấy người bán đã
kịp tự đưa hồ sơ lên vận hành, lượt ghi có bảo vệ của vòng quét nêu đích danh trạng thái
"chờ người bán xem xét" nên nó không khớp hàng nào và không có gì xảy ra.

*Phân tích độ phức tạp.* Cả thời gian lẫn bộ nhớ đều là $O(1)$: thuật toán đọc đúng hai
hàng đã có sẵn trong bộ nhớ — hồ sơ và đơn — rồi tra một bảng phân nhánh cố định, và tập
kết quả có kích thước chặn trên là ba phần tử. Điều đáng phân tích ở đây không phải chi
phí tính toán mà là *tính đầy đủ của bảng trạng thái*: bảy trạng thái nhân ba vai là hai
mươi mốt ô, và mỗi ô hoặc có hành động hoặc rỗng một cách có chủ ý. Lưu đồ ở trên tồn tại
chính vì mục đích ấy — với một cây quyết định nhiều nhánh thì hình vẽ kiểm tra được tính
đầy đủ nhanh hơn hẳn văn bản, và một ô bị bỏ quên sẽ hiện ra thành một nhánh cụt.

*Các trường hợp biên và lý do tồn tại của chúng.* Người bán *không* có hành động từ chối
hoàn tiền — đó là lý do không có trường "lý do từ chối" ở đâu cả; thứ họ làm được là đưa
lên nhân viên vận hành. Một hồ sơ ở "đang trả hàng" hay "đang tranh chấp" không mang thời
hạn, nên vòng quét đọc chúng ra sẽ không tìm thấy gì để đẩy — đó là hành vi đúng chứ
không phải một hồ sơ bị kẹt. Việc quét quá hạn đọc theo lô một trăm hồ sơ rồi xử lý từng
hồ sơ một, nên một bản sao cũ của một hồ sơ vừa bị người khác leo thang trong lúc đó phải
thua ở lượt ghi có bảo vệ; nếu lượt ghi ấy chỉ chặn các trạng thái kết thúc, hồ sơ vừa
leo thang sẽ bị kết toán mất — trả tiền cho ký quỹ mà không có phán quyết nào, và để lại
một phiếu hỗ trợ không gì đóng được.

=== TT-04: Hàng đợi làm mới véc-tơ nhúng <tt-nhung>

*Mục đích.* Giữ cho các véc-tơ phục vụ tìm kiếm luôn phản ánh nội dung hiện tại của dữ
liệu, bằng một hàng đợi là *thuộc tính của chính dữ liệu* chứ không phải một thông điệp
ai đó phải giữ cho khỏi mất.

*Đầu vào.* Cỡ lô, giới hạn độ dài văn bản, chu kỳ chạy. *Đầu ra.* Số dòng đã làm mới.
*Tiền đề.* Cột véc-tơ có bề rộng khớp với bề rộng mô hình đang dùng.

```
THUẬT TOÁN LàmMớiVécTơNhúng

// Bên GHI (mọi lượt ghi làm đổi nội dung của một dòng)
KHI một bài đăng được tạo, hoặc bản sửa chờ duyệt được áp dụng,
   hoặc một danh mục hay từ khóa được ghi:
    đóng dấu thời gian cũ dữ liệu lên chính dòng ấy, trong CÙNG lượt ghi

// Bên ĐỌC (tiến trình làm giàu véc-tơ, chạy riêng)
THỦ TỤC MộtLượtChạy
BẮT ĐẦU
    VỚI MỖI loại TRONG [danh mục, từ khóa, bài đăng]   // từ điển trước, hàng hóa sau
        LẶP
            lô ← các dòng của loại ấy có dấu cũ dữ liệu,
                 sắp theo (dấu thời gian, định danh), lấy tối đa cỡ_lô
            NẾU lô rỗng THÌ THOÁT LẶP

            VỚI MỖI dòng TRONG lô
                văn_bản ← ghép các trường mô tả dòng, theo thứ tự quan trọng giảm dần
                          (bài đăng: tên, danh mục, từ khóa, thông số, rồi mô tả)
                văn_bản ← cắt tại giới hạn ký tự, cắt theo ranh giới ký tự đầy đủ
                          // Thứ tự ghép quyết định thứ bị cắt bỏ là phần ít quan trọng

            véc_tơ ← gọi dịch vụ nhúng(toàn bộ văn bản trong lô)
            NẾU số véc-tơ trả về khác số dòng đã gửi THÌ
                BÁO LỖI và dừng lượt chạy của loại này
            NẾU bề rộng một véc-tơ dày khác bề rộng đã khai báo THÌ
                BÁO LỖI     // mô hình sai bề rộng KHÔNG suy giảm được:
                            // mọi dòng sẽ hỏng cho tới khi cột được đổi

            MỞ một giao dịch
            VỚI MỖI (dòng, véc_tơ) TRONG lô
                thưa ← bỏ các trọng số bằng 0
                NẾU một chỉ số của thưa vượt bề rộng cột THÌ BÁO LỖI
                NẾU số phần tử khác 0 > 1000 THÌ
                    giữ 1000 phần tử có trọng số lớn nhất, rồi sắp lại theo chỉ số
                ghi đè véc-tơ dày và véc-tơ thưa của dòng
                xóa dấu cũ dữ liệu VỚI ĐIỀU KIỆN dấu ấy vẫn đúng bằng giá trị đã đọc
                    // Dòng bị sửa trong lúc mô hình đang chạy sẽ mang dấu MỚI hơn,
                    // không khớp, nên nó Ở LẠI hàng đợi thay vì bị tuyên bố là mới.
            CAM KẾT giao dịch      // véc-tơ và việc rời hàng đợi cùng một lần ghi

            NẾU số dòng của lô nhỏ hơn cỡ_lô THÌ THOÁT LẶP   // đã vét cạn
KẾT THÚC

THỦ TỤC ChạyĐịnhKỳ(chu_kỳ)
    chạy một lượt ngay lập tức
    LẶP mãi:  chờ hết chu_kỳ;  chạy một lượt;  chỉ ghi nhật ký khi có dòng được làm mới
```

*Hậu điều kiện.* Một dòng đã rời hàng đợi thì luôn có véc-tơ; một dòng bị sửa trong lúc
đang được xử lý thì vẫn còn trong hàng đợi. Hai điều này giữ được vì véc-tơ và việc xóa
dấu nằm trong cùng một giao dịch.

*Ví dụ vào–ra.* Cỡ lô 64, giới hạn văn bản 2000 ký tự. Hàng đợi có 150 bài đăng, 2 danh
mục và 0 từ khóa. Lượt chạy xử lý từ điển trước: 2 danh mục trong một lô, một lượt gọi mô
hình, một giao dịch, rồi lô kế tiếp rỗng nên thoát. Sang bài đăng: lô 1 lấy 64 dòng cũ
nhất, lô 2 lấy 64 dòng, lô 3 lấy 22 dòng — vì 22 nhỏ hơn cỡ lô nên vòng lặp kết thúc mà
không cần một lượt đọc rỗng. Đầu ra là 152 dòng đã được làm mới sau ba lượt gọi mô hình
cho bài đăng cộng một lượt cho danh mục. Trường hợp đáng chú ý: giả sử bài đăng số 9137
được người bán sửa mô tả lúc mô hình đang chạy lô 2, dấu cũ dữ liệu của nó bị ghi đè bằng
một dấu mới hơn; khi giao dịch của lô 2 chạy tới nó, phép xóa dấu *có điều kiện bằng giá
trị đã đọc* không khớp, nên véc-tơ mới vẫn được ghi nhưng dòng ấy *ở lại hàng đợi* và sẽ
được làm lại ở lượt chạy sau với nội dung đúng. Nếu dịch vụ nhúng trả về véc-tơ 768 chiều
thay vì 1024, lượt chạy dừng ngay ở lô đầu tiên với một lỗi nêu rõ bề rộng nhận được và bề
rộng mong đợi — và *không dòng nào* bị ghi véc-tơ sai.

*Phân tích độ phức tạp.* Về *thời gian*, tổng chi phí là $O(n)$ theo số dòng còn trong
hàng đợi, chia thành $ceil(n \/ b)$ lô với $b$ là cỡ lô, mỗi lô tốn đúng một lượt gọi mô
hình và đúng một giao dịch cơ sở dữ liệu. Chi phí thật nằm ở suy diễn của mô hình chứ
không ở cơ sở dữ liệu, và đó chính là lý do việc này là *một tiến trình riêng*: tiến trình
đang phục vụ yêu cầu của người dùng không nên gánh một lô suy diễn. Chỉ mục bộ phận trên
dấu cũ dữ liệu khiến lượt đọc hàng đợi có chi phí tỉ lệ với phần việc còn lại chứ không tỉ
lệ với kích thước bảng, nên một lượt chạy trên hệ thống đã ổn định đọc ra tập rỗng gần như
tức thì.

Về *bộ nhớ*, chi phí là $O(b)$ chứ không phải $O(n)$, và đó là lý do tồn tại của việc chia
lô: tiến trình giữ đồng thời nhiều nhất $b$ đoạn văn bản đã cắt cùng $b$ cặp véc-tơ. Với
cỡ lô 64 và véc-tơ dày 1024 chiều thì phần véc-tơ chiếm khoảng 256 KB, phần văn bản khoảng
128 KB — nghĩa là một hàng đợi hai trăm nghìn dòng vẫn được xử lý trong một lượng bộ nhớ
cố định. Việc cắt véc-tơ thưa còn một nghìn phần tử nặng nhất phục vụ cùng mục tiêu ấy ở
phía lưu trữ: nó đặt một chặn trên cho kích thước mỗi hàng, nên dung lượng bảng véc-tơ tỉ
lệ tuyến tính với số bài đăng và dự đoán được khi định cỡ máy chủ.

*Các trường hợp biên.* Hàng đợi rỗng: một lượt chạy không ghi nhật ký gì, đúng như mong
đợi. Mô hình trả về sai bề rộng: dừng ngay và báo lỗi, vì đây là loại hỏng hóc *không*
suy giảm được. Véc-tơ thưa quá dày: cắt còn một nghìn phần tử nặng nhất — một véc-tơ dày
đặc vừa làm chậm chỉ mục vừa không thêm thông tin. Không chạy tiến trình này chút nào:
đây vẫn là một cách triển khai hợp lệ, tìm kiếm khi ấy suy giảm về khớp từ khóa như đã
đặc tả ở TT-01.

=== TT-05: Mở hoặc nối lại một chặng thanh toán, và quyết toán phiên

*Mục đích.* Một phiên thanh toán là số tiền hệ thống đang chờ người mua trả; nó có thể
được trả qua nhiều *chặng*, mỗi chặng là một lượt tính tiền trên một kênh thanh toán bên
ngoài. Thuật toán này trả lời hai câu hỏi tách rời nhau nhưng phải nhất quán với nhau.
Câu hỏi thứ nhất: khi người mua bấm trả tiền lần nữa trên cùng một kênh, hệ thống mở một
chặng mới hay đưa họ về đúng trang thanh toán đang chờ sẵn? Câu hỏi thứ hai: khi thông báo
của cổng thanh toán tới — có thể tới nhiều lần — làm sao để đúng *một* lần quyết toán xảy
ra, và khi nào thì phiên được coi là đã trả đủ?

Hai câu hỏi ấy chung một nguy cơ: *một khoản tiền được thu hai lần*. Một trang thanh toán
thứ hai còn sống là khoản tiền mà cơ chế tạm giữ không có chỗ để hạch toán, bởi lượt trả
tiền tới sau sẽ không còn số dư nào để đối ứng.

*Đầu vào.* Với nhánh mở chặng: định danh phiên, kênh thanh toán được chọn, số tiền tuỳ
chọn khi muốn chia nhỏ, địa chỉ trang trả về, và định danh người gọi. Với nhánh quyết
toán: một thông báo của cổng gồm tham chiếu chặng, trạng thái và mã giao dịch bên đó.
*Đầu ra.* Một chặng kèm địa chỉ trang thanh toán; hoặc kết quả rỗng nghĩa là "đã quyết
toán, kể cả khi đó là lần thông báo thứ hai". *Tiền đề.* Phiên tồn tại; người gọi chính là
người phải trả; kênh được chọn là một dòng tuỳ chọn đang bật và có nhà cung cấp đã đăng ký.

```
THUẬT TOÁN MởHoặcNốiLạiChặng(phiên, kênh, số_tiền_tuỳ_chọn)
BẮT ĐẦU
    NẾU người gọi không phải người trả tiền THÌ BÁO LỖI "phiên không trả được"
    NẾU kênh không phân giải được về một nhà cung cấp đã đăng ký THÌ
        BÁO LỖI  // KHÔNG thay bằng nhà cung cấp nào khác đang có mặt

    // --- Bước 1: NỐI LẠI, đặt TRƯỚC mọi phép tính tiền ---
    NẾU phiên chưa kết thúc VÀ chưa quá hạn THÌ
        VỚI MỖI chặng của phiên
            NẾU chặng.kênh = kênh VÀ chặng đang chờ
               VÀ chặng có địa chỉ trang thanh toán VÀ chặng chưa quá hạn riêng THÌ
                TRẢ VỀ chặng ấy        // Đưa người mua về đúng trang cũ
    // Thứ tự bắt buộc: một lượt nối lại trả tiền đúng phần nó đã nhận, còn số dư
    // còn phải trả chỉ đếm các chặng ĐÃ thành công. Tính lại số tiền ở đây sẽ
    // chào lại một chặng chia nhỏ với nguyên số dư của cả phiên.

    // --- Bước 2: số dư còn phải trả ---
    đã_thu ← 0
    VỚI MỖI chặng của phiên
        NẾU chặng đã thành công THÌ đã_thu ← đã_thu + chặng.số_tiền
            // Số tiền CÓ DẤU, nên một bút toán đảo tự trừ chính nó.
            // Chặng đang chờ và chặng thất bại KHÔNG được tính.
    còn_phải_trả ← LỚN HƠN(0, phiên.tổng_tiền − đã_thu)

    số_tiền ← số_tiền_tuỳ_chọn NẾU có, NGƯỢC LẠI còn_phải_trả
    NẾU số_tiền ≤ 0 HOẶC số_tiền > còn_phải_trả THÌ BÁO LỖI "số tiền không hợp lệ"

    // --- Bước 3: chiếm quyền trả tiền của phiên ---
    NẾU phiên không ở trạng thái "chờ trả" THÌ BÁO LỖI "phiên không trả được"
    chuyển phiên sang "đang xử lý" trong bộ nhớ

    // --- Bước 4: cấp định danh TRƯỚC khi gọi ra ngoài ---
    mã_chặng ← xin số kế tiếp của chuỗi sinh
        // Cổng thanh toán phải được trao đúng cái mã mà lời gọi lại sẽ nêu tên,
        // kể cả khi lời gọi ấy về trước lúc giao dịch cục bộ kịp kết thúc.
    kết_quả ← gọi cổng thanh toán(mã_chặng, kênh, số_tiền, địa chỉ trả về)
    NẾU thất bại THÌ BÁO LỖI    // chưa có hàng nào được ghi

    ghi hàng chặng, LƯU LẠI địa chỉ trang thanh toán
        // Lưu chứ không chỉ trả về: phản hồi này chỉ được nhìn một lần
    ghi phiên VỚI ĐIỀU KIỆN trạng thái vẫn là "chờ trả"

    NẾU kênh trả lời dứt khoát ngay (ghi nợ trực tiếp) THÌ
        QuyếtToán(chặng, kết quả)     // không có lời gọi lại nào để chờ
    TRẢ VỀ chặng
KẾT THÚC


THỦ TỤC QuyếtToán(thông_báo)
BẮT ĐẦU
    chặng ← tra theo ĐỊNH DANH CỦA TA lấy từ thông báo
        // KHÔNG tra theo mã của nhà cung cấp: mã ấy chỉ duy nhất trong phạm vi
        // một kênh, nên một chuỗi mà hai nhà cung cấp cùng dùng sẽ quyết toán
        // nhầm chặng của người khác.

    // Chốt chặn 1: trạng thái trong bộ nhớ
    NẾU chặng không còn đang chờ THÌ TRẢ VỀ "đã xong"   // thông báo giao lại

    đặt trạng thái chặng theo thông báo, ghi mã tham chiếu của nhà cung cấp

    // Chốt chặn 2: lượt ghi có bảo vệ
    ghi chặng VỚI ĐIỀU KIỆN trạng thái vẫn là "đang chờ"
    NẾU không hàng nào bị tác động THÌ TRẢ VỀ "đã xong"
    // Chốt chặn 3: chỉ mục duy nhất trên cặp (kênh, mã tham chiếu) đứng phía sau

    phiên ← đọc lại phiên của chặng
    NẾU chặng thất bại THÌ
        mở lại phiên về "chờ trả" để người mua thử kênh khác
        TRẢ VỀ

    tính lại còn_phải_trả như Bước 2
    NẾU còn_phải_trả > 0 THÌ TRẢ VỀ      // mới trả một phần, phiên chưa xong

    // Chốt chặn 4: khóa lũy đẳng của bút toán ví
    cộng tiền vào ví người mua với khóa "phiên:<mã>:nạp"
    NẾU khóa đã tồn tại THÌ TRẢ VỀ

    đánh dấu phiên đã trả đủ
    // Chốt chặn 5: ghi phiên VỚI ĐIỀU KIỆN trạng thái thuộc {chờ trả, đang xử lý}
    NẾU không hàng nào bị tác động THÌ TRẢ VỀ "đã xong"

    phát sự kiện "phiên đã thanh toán"    // cố gắng hết sức, sau khi cam kết
KẾT THÚC
```

#fig(
  [Lưu đồ TT-05: nối lại một chặng, và năm chốt chặn của lượt quyết toán],
  spacing: (38mm, 9.5mm),

  nt((0, 0), [Người mua bấm\ trả tiền trên kênh K]),
  edge((0, 0), (0, 1), "-|>"),
  nd((0, 1), [Phiên chưa kết thúc\ và chưa quá hạn?]),
  edge((0, 1), (0, 2), "-|>", text(size: 8pt)[Không: từ chối], label-side: left),
  nr((0, 2), [Lỗi 409:\ phiên đã hết hạn]),
  edge((0, 1), (1, 1), "-|>", text(size: 8pt)[Có]),
  nd((1, 1), [Kênh K đã có một chặng\ đang chờ, còn trang\ thanh toán sống?]),
  edge((1, 1), (2, 1), "-|>", text(size: 8pt)[Có]),
  ng((2, 1), [Trả lại ĐÚNG trang cũ.\ Không mở chặng mới,\ không tính lại tiền]),
  edge((1, 1), (1, 2), "-|>", text(size: 8pt)[Không]),
  np((1, 2), [Còn phải trả = tổng tiền\ − tổng các chặng ĐÃ thành công\ (số tiền có dấu)]),
  edge((1, 2), (1, 3), "-|>"),
  nd((1, 3), [Phiên đang ở\ trạng thái "chờ trả"?]),
  edge((1, 3), (0, 3), "-|>", text(size: 8pt)[Không], label-side: left),
  nr((0, 3), [Lỗi 409: đã có một\ chặng đang bay]),
  edge((1, 3), (1, 4), "-|>", text(size: 8pt)[Có]),
  np((1, 4), [Cấp mã chặng, gọi cổng,\ ghi hàng chặng, ghi phiên\ có điều kiện]),
  edge((1, 4), (1, 5), "-|>"),
  nt((1, 5), [Trả về trang thanh toán]),

  nt((1, 6.6), [Thông báo của cổng\ (có thể tới nhiều lần)]),
  edge((1, 6.6), (1, 7.6), "-|>"),
  nd((1, 7.6), [Chặng còn đang chờ?\ (chốt 1 và chốt 2)]),
  edge((1, 7.6), (2, 7.6), "-|>", text(size: 8pt)[Không]),
  ng((2, 7.6), [Trả "đã xong":\ đây là bản giao lại]),
  edge((1, 7.6), (1, 8.6), "-|>", text(size: 8pt)[Có]),
  nd((1, 8.6), [Chặng thành công?]),
  edge((1, 8.6), (0, 8.6), "-|>", text(size: 8pt)[Không], label-side: left),
  np((0, 8.6), [Mở lại phiên về "chờ trả"\ để thử kênh khác]),
  edge((1, 8.6), (1, 9.6), "-|>", text(size: 8pt)[Có]),
  nd((1, 9.6), [Còn phải trả > 0?]),
  edge((1, 9.6), (2, 9.6), "-|>", text(size: 8pt)[Có: mới trả một phần]),
  ng((2, 9.6), [Dừng; phiên chưa xong]),
  edge((1, 9.6), (1, 10.6), "-|>", text(size: 8pt)[Không]),
  np((1, 10.6), [Cộng ví theo khóa lũy đẳng (chốt 4),\ ghi phiên có điều kiện (chốt 5)]),
  edge((1, 10.6), (1, 11.6), "-|>"),
  nt((1, 11.6), [Phát sự kiện "đã thanh toán"\ → module đơn hàng dựng đơn]),
)

*Hậu điều kiện.* Trên mỗi kênh, một phiên chưa kết thúc có nhiều nhất *một* trang thanh
toán còn sống. Tổng các chặng đã thành công không bao giờ vượt tổng tiền của phiên. Một
thông báo được giao lại lần thứ hai không sinh thêm bút toán nào và vẫn nhận về mã thành
công. Và phiên chỉ chuyển sang "đã trả đủ" đúng một lần, nên sự kiện dựng đơn cũng chỉ
được phát đúng một lần.

*Ví dụ vào–ra.* Phiên `pss_4rm8vc2xdq7n`, tổng 4.235.000 đồng, mở lúc 08:41 với hạn 08:56.
Người mua chọn kênh `sepay-bank-transfer` và nhận về chặng số 1 kèm địa chỉ trang thanh
toán. Họ đóng nhầm tab và bấm trả tiền lại lúc 08:44 trên *cùng* kênh: bước 1 tìm thấy
chặng 1 vẫn đang chờ và vẫn còn trang sống, nên đầu ra là *chính chặng 1* — không có chặng
2, và số dư còn phải trả thậm chí không được tính tới. Lúc 08:47 cổng thanh toán gọi lại
báo thành công cho chặng 1: chốt 1 và chốt 2 đều qua, đã_thu thành 4.235.000, còn phải trả
bằng 0, ví người mua được cộng theo khóa `phiên:110455:nạp`, phiên chuyển "đã trả đủ" và
sự kiện được phát. Lúc 08:47 cổng gọi lại lần thứ hai với đúng nội dung ấy: chốt 1 thấy
chặng không còn đang chờ và trả về "đã xong" ngay, nên không có bút toán thứ hai, không có
đơn hàng thứ hai, và cổng nhận mã 200 nên thôi gửi lại. Trường hợp khác: nếu lần gọi lại
đầu tiên báo *thất bại*, chặng 1 thành thất bại, phiên được mở lại về "chờ trả", và người
mua chọn được kênh khác trong phần thời gian còn lại của cửa sổ mười lăm phút.

*Phân tích độ phức tạp.* Về *thời gian*, chi phí tính toán là $O(L)$ với $L$ là số chặng
của một phiên — hai lượt duyệt tuyến tính, một để tìm chặng nối lại được và một để cộng số
dư — và $L$ nhỏ theo cấu tạo, vì mỗi kênh nhiều nhất một chặng đang chờ và cửa sổ phiên chỉ
mười lăm phút. Chi phí thật là số lượt đi lại với cơ sở dữ liệu: nhánh mở chặng tốn bảy
lượt cộng đúng một lời gọi ra cổng thanh toán, còn nhánh nối lại chỉ tốn ba lượt và *không*
lời gọi ra nào — đó chính là phần thưởng của việc đặt bước nối lại lên trước. Nhánh quyết
toán thành công tốn sáu lượt, trong đó một lượt là giao dịch ghi ví. Về *bộ nhớ*, chi phí
là $O(L)$: thủ tục giữ danh sách chặng của đúng một phiên, không bao giờ nạp nhiều phiên
cùng lúc.

*Các trường hợp biên.* Bấm trả tiền hai lần thật nhanh trên cùng một kênh: lần sau nối lại
đúng trang cũ. Đổi sang kênh khác khi chặng cũ vẫn đang chờ: bước 3 từ chối, vì phiên đang
ở "đang xử lý" — muốn đổi kênh thì phải đợi chặng cũ thất bại hoặc đợi phiên hết hạn. Phiên
đã quá hạn: không nối lại được và cũng không mở chặng mới được, người mua phải bắt đầu lại
lượt mua. Thông báo báo một số tiền khác với số tiền của chặng: số tiền được lấy từ *hàng
chặng* chứ không từ thông báo, nên một thông báo bị chế tác không đổi được số tiền. Thông
báo trỏ tới một chặng không tồn tại: bị từ chối ở bước tra cứu. Kênh bị gỡ khỏi danh sách
nhà cung cấp đã đăng ký giữa lúc phiên còn sống: lượt mở chặng bị từ chối thay vì bị thay
bằng kênh khác, còn chặng cũ vẫn quyết toán được vì lời gọi lại tra theo định danh của
chính hệ thống.

*Một rủi ro còn lại, được ghi nhận.* Trong nhánh mở chặng, hàng chặng được ghi *trước* lượt
ghi có bảo vệ lên phiên, và hai lượt ghi ấy không nằm trong cùng một giao dịch. Vì thế tồn
tại một cửa sổ hẹp — giữa hai lượt ghi — trong đó hai lời gọi đồng thời đều có thể chèn
được một chặng, dù chỉ một trong hai thắng lượt ghi phiên. Chặng của bên thua khi ấy là
một hàng đang chờ kèm một trang thanh toán còn sống mà không phiên nào công nhận. Ba lớp
phía sau khiến hậu quả tệ nhất vẫn là một khoản tiền *treo* chứ không phải một khoản tiền
*mất*: khóa lũy đẳng của bút toán ví chặn lượt cộng thứ hai, lượt ghi có bảo vệ lên phiên
chặn lượt đánh dấu "đã trả đủ" thứ hai, và sự kiện dựng đơn vì thế cũng chỉ phát một lần.
Cách đóng hẳn cửa sổ này là đưa hai lượt ghi vào chung một giao dịch, và đó là thay đổi
được ghi lại như việc phải làm chứ không phải một điều đã làm.

=== Đối chiếu với các yêu cầu phi chức năng

Ba trong năm thuật toán nằm trên đường đi của một yêu cầu người dùng, nên chúng phải được
đối chiếu với các mục tiêu hiệu năng đã đặt ở Chương 3. Cần nhắc lại điều đã nói ở đầu
chương: đây là *mục tiêu thiết kế* cùng lập luận cho thấy thuật toán không mâu thuẫn với
mục tiêu ấy, chứ chưa phải kết quả đo — phép đo thực nghiệm nằm ở Chương 6.

#figure(
  kind: table,
  caption: [Đối chiếu từng thuật toán với yêu cầu phi chức năng liên quan],
  table(
    columns: (0.26fr, 0.4fr, 1.6fr),
    align: (left + top, left + top, left + top),
    table.header([Mã], [Yêu cầu], [Lập luận đối chiếu]),
    [TT-01], [NFR-02, NFR-03, NFR-05],
    [Ngân sách của NFR-03 là 250 ms cho phân vị 95 của tìm kiếm lai, và phần lớn ngân sách ấy *không* thuộc về thuật toán mà thuộc về lượt gọi dịch vụ nhúng — chính vì thế lượt gọi ấy có bộ nhớ đệm hai mươi bốn giờ, và một lần trúng đệm đưa truy vấn về đúng hình dạng chi phí của NFR-02. Phần thuật toán là một lượt quét chỉ mục cộng một lượt tìm láng giềng gần đúng, còn phần xếp hạng lại bị chặn cứng ở hai trăm phần tử nên *không* tăng theo số bài đăng; đó là điều làm cho ngưỡng thông lượng của NFR-05 độc lập với kích thước dữ liệu.],
    [TT-02], [NFR-20, NFR-21, NFR-22],
    [Yêu cầu "số dư không bao giờ âm và tổng biến động luôn khớp số dư" được bảo đảm ngay trong thuật toán chứ không bằng một lượt đối soát định kỳ: phép kiểm tra số dư âm nằm trên từng chân, và cả lượt dịch chuyển bị hủy nếu chỉ một chân vi phạm. Khóa lũy đẳng do bên gọi đặt tên là cơ chế đáp ứng NFR-20. Việc khóa hàng ví theo thứ tự cố định là cơ chế đáp ứng NFR-22 mà không mở đường cho khóa chéo.],
    [TT-05], [NFR-19, NFR-20, NFR-28],
    [NFR-20 đòi không tình huống lỗi nào tạo ra hai lần thu tiền cho một lần bán; năm chốt chặn trong thủ tục quyết toán tồn tại đúng vì điều đó, và bước nối lại chặng là thứ ngăn ngay từ đầu việc có hai trang thanh toán cùng sống. Tính lũy đẳng của lượt quyết toán là dạng cụ thể của NFR-19 ở phía tiền. Thời hạn chờ riêng cho lời gọi ra cổng thanh toán là yêu cầu NFR-28, và chính nó — chứ không phải phần tính toán — quyết định độ trễ đuôi của tuyến này.],
    [TT-03], [NFR-19, NFR-22],
    [Không nằm trên đường nóng và chi phí là hằng số, nên không có ngân sách độ trễ nào để đối chiếu. Điều nó phải bảo đảm là tính lũy đẳng của các chuyển đổi theo thời hạn và tính đúng đắn dưới tương tranh; cơ chế cho cả hai là lượt ghi có bảo vệ nêu đích danh *tập* trạng thái nguồn, kể cả các trạng thái chưa kết thúc.],
    [TT-04], [NFR-03, NFR-05],
    [Cố ý *không* nằm trong tiến trình phục vụ yêu cầu, nên nó không tiêu thụ ngân sách độ trễ của bất kỳ yêu cầu nào; bộ nhớ tiêu thụ bị chặn theo cỡ lô chứ không theo kích thước hàng đợi. Quan hệ của nó với NFR-03 là quan hệ về *chất lượng kết quả* chứ không về tốc độ: một hàng đợi tồn đọng lâu làm nhánh ngữ nghĩa nghèo đi, và không chạy nó chút nào vẫn là một cách triển khai hợp lệ, khi ấy tìm kiếm suy giảm về khớp từ khóa và về đúng ngân sách của NFR-02.],
  ),
)

== Thiết kế xử lý lỗi

=== Triết lý: lỗi là một giá trị có mã, không phải một ngoại lệ được ném

Toàn bộ hệ thống dùng *một* mô hình lỗi duy nhất, và mô hình ấy có ba tính chất cần nêu
trước khi đi vào chi tiết. Thứ nhất, một lỗi là *một giá trị được trả về*, không phải
một ngoại lệ được ném rồi bắt ở đâu đó; nhờ vậy mọi đường thoát của một hàm đều nhìn
thấy được ngay trong chữ ký của nó, và không có lối ra ẩn nào. Thứ hai, mỗi lỗi mang ba
thứ đi cùng: *mã trạng thái HTTP*, *một mã định danh ổn định* và một thông điệp; máy
khách được lập trình theo mã định danh chứ không theo thông điệp, nên thông điệp có thể
sửa lại cho dễ hiểu hơn mà không phá vỡ máy khách nào. Thứ ba, *chỉ có đúng một nơi*
trong toàn hệ thống ánh xạ lỗi sang phản hồi HTTP; mọi tầng khác chỉ việc để lỗi truyền
lên kèm ngữ cảnh.

Việc phân bổ *quyền sở hữu* lỗi cũng là một quyết định thiết kế chứ không phải một chi
tiết tổ chức mã. Gói lỗi dùng chung chỉ giữ những lỗi cắt ngang thật sự — thân yêu cầu
hỏng, chưa xác thực, phiếu xác thực không hợp lệ, mã định danh sai dạng, chức năng chưa
hiện thực — còn *mọi lỗi mang tính nghiệp vụ đều thuộc về module sinh ra nó*, kể cả lỗi
"không tìm thấy". Nhờ ranh giới ấy, tầng điều hợp cơ sở dữ liệu có thể trả thẳng một lỗi
miền mà chiều phụ thuộc vẫn một chiều, và số lượng lỗi của một module trở thành một chỉ
dấu khá trung thực về độ dày quy tắc của nó.

#figure(
  kind: table,
  caption: [Số lượng lỗi nghiệp vụ được khai báo trong từng module],
  table(
    columns: (1fr, 0.5fr, 2fr),
    align: (left + horizon, center + horizon, left + top),
    table.header([Module], [Số lỗi], [Ghi chú]),
    [Đơn hàng], [53],
    [Dày nhất, đúng như dự đoán: bốn máy trạng thái, hai đường tiền và một loạt bộ kiểm
     tra về vai của người gọi.],
    [Tài khoản], [35], [Xác thực, phân quyền, giới hạn tần suất, xác minh giấy tờ.],
    [Tài chính], [32], [Vòng đời phiên, vòng đời chặng thanh toán, số dư, ví, mã số thuế.],
    [Danh mục], [31], [Vòng đời bài đăng, tồn kho, cây danh mục, gợi ý bằng mô hình ngôn ngữ.],
    [Tín nhiệm], [29], [Đánh giá ẩn, nhận xét, phiếu hỗ trợ và quy trình phán quyết.],
    [Hội thoại], [10], [Module nhỏ nhất; quy tắc chủ yếu là ai được đọc và ai được sửa.],
    [*Tổng cộng*], [*190*],
    [Cộng năm lỗi cắt ngang ở gói dùng chung, thành *195 khai báo*.],
  ),
)

Con số khai báo không trùng với con số mã, và chỗ lệch ấy nói lên chính ranh giới quyền sở hữu
vừa mô tả. Một trăm chín mươi lăm khai báo phủ *185 mã phân biệt*, vì bốn mã được khai báo ở
nhiều module cùng lúc: `moderator_required`, `admin_required` và `attachment_not_found` mỗi mã
xuất hiện ở bốn module, còn `version_conflict` ở hai. Đây không phải trùng lặp cần dọn mà là hệ
quả trực tiếp của quy tắc "mỗi module sở hữu lỗi của chính nó": nếu một module phải nhập lỗi
`moderator_required` từ module khác thì chiều phụ thuộc giữa hai module sẽ đảo ngược, chỉ để
dùng lại một chuỗi ký tự. Về phía máy khách, cùng một mã ở hai module vẫn mang đúng một ý nghĩa
và đúng một mã trạng thái, nên việc lập trình theo mã không hề bị ảnh hưởng. Ngoài 185 mã ấy còn
một mã nữa mà máy khách gặp được là `validation`, sinh tự động từ bộ kiểm tra ràng buộc chứ
không khai báo ở đâu cả.

=== Phân cấp lỗi và ánh xạ sang mã trạng thái

#fig(
  [Phân cấp lỗi: một kiểu lỗi có mã, ba nguồn sinh ra nó],
  spacing: (34mm, 11mm),

  cls((1, 0), "Lỗi có mã", stereo: "kiểu nền tảng", name: <e-base>,
    attrs: (
      "- httpStatus: uint16  // bắt buộc 400..599",
      "- code: string        // định danh ổn định",
      "- err: error          // thông điệp, bọc lỗi gốc",
      "- fields: []Field     // chỉ với lỗi ràng buộc",
    ),
    ops: (
      "+ Error() string   // '<thông điệp> [<mã>]'",
      "+ Unwrap() error   // giữ nguyên chuỗi bọc",
      "+ Code() / Fields()",
      "  được bọc thêm một lỗi kết thúc của nền tảng",
      "  thực thi bền, để một lỗi nghiệp vụ KHÔNG bị",
      "  thử lại sau khi vượt một chặng bền",
    )),

  cls((0, 1), "Lỗi cắt ngang", stereo: "gói dùng chung", name: <e-x>,
    attrs: (
      "bad_request_body    400",
      "validation          400",
      "invalid_id          400",
      "unauthorized        401",
      "invalid_token       401",
      "not_implemented     501",
    )),
  cls((1, 1), "Lỗi nghiệp vụ của module", stereo: "domain/errors.go", name: <e-d>,
    attrs: (
      "không tìm thấy      404",
      "sai vai / không đủ quyền  403",
      "xung đột trạng thái 409",
      "vi phạm quy tắc     422",
      "quá tần suất        429",
      "nhà cung cấp ngoài  502",
    )),
  cls((2, 1), "Lỗi ràng buộc đầu vào", stereo: "sinh tự động", name: <e-v>,
    attrs: (
      "được dịch từ bộ kiểm tra ràng buộc",
      "mỗi trường hỏng -> một phần tử Field:",
      "  { field, rule, message }",
      "ví dụ: 'skus[0].price', 'gt', ...",
    )),
  edge(<e-base>, <e-x>, "<|-"),
  edge(<e-base>, <e-d>, "<|-"),
  edge(<e-base>, <e-v>, "<|-"),

  cls((1, 2), "Bộ ghi phản hồi lỗi", stereo: "nơi DUY NHẤT ánh xạ HTTP", name: <e-w>,
    attrs: (
      "1. Phân rã lỗi để lấy (trạng thái, mã, thông điệp)",
      "2. Đọc mã yêu cầu từ tiêu đề phản hồi",
      "3. Ghi phong bì lỗi",
      "4. Không phân rã được -> ghi nhật ký mức ERROR",
      "   và trả 500 'internal' — KHÔNG lộ chi tiết",
    )),
  edge(<e-x>, <e-w>, "-->"),
  edge(<e-d>, <e-w>, "-->"),
  edge(<e-v>, <e-w>, "-->"),
)

Ánh xạ giữa loại lỗi và mã trạng thái được giữ nhất quán trên toàn hệ thống theo bảng
dưới đây. Ranh giới hay bị nhầm nhất là giữa 409 và 422: *409 là xung đột trạng thái* —
yêu cầu hợp lệ nhưng đối tượng đang ở trạng thái không cho phép, và thử lại sau có thể
thành công; *422 là vi phạm quy tắc nghiệp vụ* — yêu cầu sẽ không bao giờ hợp lệ dưới
dạng hiện tại, thử lại vô ích.

#figure(
  kind: table,
  caption: [Phân loại lỗi, mã trạng thái và hành vi mong đợi ở phía máy khách],
  table(
    columns: (0.85fr, 0.32fr, 1.05fr, 0.95fr),
    align: (left + top, center + horizon, left + top, left + top),
    table.header([Loại lỗi], [Mã], [Ý nghĩa], [Máy khách nên làm gì]),
    [Ràng buộc đầu vào], [400],
    [Thân yêu cầu sai dạng, thiếu trường, sai kiểu, hoặc mã định danh không giải mã được.],
    [Hiển thị lỗi ngay tại trường tương ứng; không thử lại.],
    [Chưa xác thực], [401],
    [Không có phiếu xác thực, phiếu hết hạn, hoặc phiên đã bị thu hồi.],
    [Làm mới phiếu một lần; thất bại thì đưa về màn hình đăng nhập.],
    [Không đủ quyền], [403],
    [Đã xác thực nhưng không phải vai được phép, hoặc không phải một bên của đối tượng.],
    [Không thử lại; ẩn thao tác khỏi giao diện.],
    [Không tìm thấy], [404],
    [Đối tượng không tồn tại, *hoặc* tồn tại nhưng người gọi không được biết là nó tồn tại.],
    [Không thử lại.],
    [Xung đột trạng thái], [409],
    [Đối tượng đang ở trạng thái không cho phép thao tác, hoặc một lượt ghi khác đã thắng.],
    [Đọc lại đối tượng rồi để người dùng quyết định.],
    [Vi phạm quy tắc], [422],
    [Yêu cầu hợp lệ về hình thức nhưng trái một quy tắc nghiệp vụ.],
    [Không thử lại; giải thích quy tắc cho người dùng.],
    [Quá tần suất], [429],
    [Vượt hạn mức gửi lại của một thao tác có chi phí bên ngoài.],
    [Chờ rồi thử lại với thời gian giãn tăng dần.],
    [Lỗi hệ thống], [500],
    [Bất kỳ lỗi nào không phân ra được thành một lỗi có mã.],
    [Thử lại nếu thao tác lũy đẳng; báo mã yêu cầu cho hỗ trợ.],
    [Nhà cung cấp ngoài], [502],
    [Cổng thanh toán, hãng vận chuyển hoặc dịch vụ xác minh trả lời sai hoặc không trả lời.],
    [Thử lại sau; không giả định thao tác đã thất bại.],
  ),
)

=== Định dạng phản hồi lỗi và trích lục danh mục mã lỗi

Mọi phản hồi lỗi có đúng một hình dạng, và phần dữ liệu không bao giờ nằm cạnh phần lỗi
trong cùng một phản hồi. Trường mã yêu cầu luôn có mặt để nối một khiếu nại của người
dùng với đúng một dòng nhật ký; trường danh sách trường chỉ có nội dung với lỗi ràng
buộc đầu vào.

```json
{
  "error": {
    "code": "insufficient_stock",
    "message": "not enough stock for this variant",
    "request_id": "m7k2x9q4",
    "fields": []
  }
}
```

```json
{
  "error": {
    "code": "validation",
    "message": "2 fields are invalid",
    "request_id": "m7k2xa11",
    "fields": [
      { "field": "skus[0].price", "rule": "gt",       "message": "phải lớn hơn 0" },
      { "field": "name",          "rule": "required", "message": "bắt buộc" }
    ]
  }
}
```

Danh mục đầy đủ gồm 185 mã như đã tính ở trên; bảng dưới đây trích lục hai mươi bốn mã đại diện,
chọn sao cho phủ hết các loại lỗi và cả bảy module. Bảng phân biệt rõ *hai loại thông điệp*, vì
chúng phục vụ hai người đọc khác nhau: thông điệp người dùng là câu mà giao diện hiển thị, đã
được viết cho người không biết hệ thống hoạt động thế nào; thông điệp lập trình viên là câu nằm
trong phản hồi và trong nhật ký, mang đủ ngữ cảnh để lần ra nguyên nhân. Cột cuối ghi giá trị
lỗi trong mã nguồn, để một mã trên đường truyền tra ngược được về đúng một chỗ khai báo.

Về *quốc tế hoá*, ranh giới nằm đúng ở chỗ phân đôi này: thông điệp lập trình viên luôn là tiếng
Anh và không bao giờ dịch, vì nó là dữ liệu cho công cụ; còn thông điệp người dùng được máy khách
tra từ chính *mã lỗi* trong bảng từ vựng ngôn ngữ của nó, chứ không hiển thị lại chuỗi máy chủ
gửi về. Nhờ vậy việc thêm một ngôn ngữ không đụng tới máy chủ, và việc sửa lại một câu cho dễ
hiểu hơn không phá vỡ máy khách nào. Ngoại lệ duy nhất là danh sách trường của lỗi ràng buộc đầu
vào, nơi thông điệp đi kèm từng trường được sinh ra từ chính quy tắc bị vi phạm.

#figure(
  kind: table,
  caption: [Trích lục danh mục mã lỗi (24 trên 185 mã)],
  table(
    columns: (0.78fr, 0.18fr, 0.9fr, 0.95fr, 0.85fr),
    align: (left + top, center + horizon, left + top, left + top, left + top),
    inset: (x: 4pt, y: 4.5pt),
    table.header([Mã lỗi và giá trị lỗi], [HTTP], [Thông điệp cho người dùng], [Thông điệp cho lập trình viên], [Hành động gợi ý]),

    [`bad_request_body` \ `errx.ErrBadRequestBody`], [400],
    [Yêu cầu không hợp lệ. Hãy thử lại hoặc cập nhật ứng dụng.],
    [`invalid request body` — thân yêu cầu không giải mã được hoặc chứa khoá lạ (bộ giải mã nghiêm ngặt).],
    [Kiểm tra lại phiên bản máy khách.],

    [`validation` \ (sinh bởi `errx.NewValidationError`)], [400],
    [Một vài ô nhập chưa đúng.],
    [`N fields are invalid` kèm danh sách trường, quy tắc bị vi phạm và đường dẫn trường.],
    [Đánh dấu từng ô theo danh sách trả về.],

    [`invalid_id` \ `errx.ErrInvalidID`], [400],
    [Không tìm thấy nội dung bạn đang mở.],
    [`invalid id` — sai tiền tố loại, sai độ dài, hoặc ký tự ngoài bảng chữ cái của bộ mã hoá.],
    [Không thử lại; nhiều khả năng đường dẫn bị sửa tay.],

    [`unauthorized` \ `errx.ErrUnauthorized`], [401],
    [Vui lòng đăng nhập để tiếp tục.],
    [`authentication required` — không có tiêu đề uỷ quyền trên một tuyến cần xác thực.],
    [Đăng nhập lại.],

    [`invalid_token` \ `errx.ErrInvalidToken`], [401],
    [Phiên làm việc đã kết thúc. Vui lòng đăng nhập lại.],
    [`invalid or expired token` — chữ ký sai, vé hết hạn, hoặc phiên không còn trong bộ nhớ đệm.],
    [Làm mới vé một lần; thất bại thì đăng nhập lại.],

    [`account_suspended` \ `account.ErrAccountSuspended`], [403],
    [Tài khoản của bạn đang bị tạm khoá.],
    [`this account is suspended` — kèm thời hạn và lý do đình chỉ trên hàng tài khoản.],
    [Hiển thị lý do và thời hạn đình chỉ.],

    [`moderator_required` \ `<module>.ErrModeratorRequired`], [403],
    [Bạn không có quyền thực hiện thao tác này.],
    [`moderator role required` — được khai báo ở bốn module, mỗi module một giá trị riêng.],
    [Ẩn thao tác khỏi giao diện người dùng thường.],

    [`not_the_buyer` \ `order.ErrNotTheBuyer`], [403],
    [Chỉ người mua của đơn này mới thực hiện được.],
    [`only the buyer of this order may do that` — phép kiểm tra quyền sở hữu trên `order.buyer_id`.],
    [Không thử lại.],

    [`not_the_seller` \ `order.ErrNotTheSeller`], [403],
    [Chỉ người bán của đơn này mới thực hiện được.],
    [`only the seller of this order may do that` — phép kiểm tra quyền sở hữu trên `order.seller_id`.],
    [Không thử lại.],

    [`listing_not_found` \ `catalog.ErrListingNotFound`], [404],
    [Tin đăng này không còn nữa.],
    [`listing not found` — không tồn tại, đã xoá mềm, đã bị gỡ, hoặc là bản nháp của người khác.],
    [Quay lại danh sách.],

    [`ticket_not_found` \ `trust.ErrTicketNotFound`], [404],
    [Không tìm thấy yêu cầu hỗ trợ này.],
    [`ticket not found` — không tồn tại *hoặc* người gọi không phải người gửi; cố ý không phải 403.],
    [Không thử lại.],

    [`order_not_found` \ `order.ErrOrderNotFound`], [404],
    [Không tìm thấy đơn hàng này.],
    [`order not found` — không tồn tại hoặc người gọi không phải một bên của đơn.],
    [Không thử lại.],

    [`insufficient_stock` \ `catalog.ErrInsufficientStock`], [409],
    [Số lượng bạn chọn vượt quá hàng còn lại.],
    [`not enough stock for this variant` — tồn kho khả dụng nhỏ hơn số lượng yêu cầu tại thời điểm giữ chỗ.],
    [Đọc lại tồn kho và đề nghị giảm số lượng.],

    [`invalid_transition` \ `catalog.ErrInvalidTransition`], [409],
    [Tin đăng vừa thay đổi. Hãy tải lại trang.],
    [`already live or already under moderation` — trạng thái hiện tại không nằm trong tập trạng thái nguồn của lượt ghi.],
    [Tải lại bài đăng.],

    [`order_settled` \ `order.ErrOrderSettled`], [409],
    [Đơn hàng này đã kết thúc.],
    [`this order is already completed or cancelled` — mốc hoàn tất hoặc mốc huỷ đã có giá trị.],
    [Tải lại đơn.],

    [`refund_not_disputed` \ `order.ErrRefundNotDisputed`], [409],
    [Yêu cầu hoàn tiền này chưa ở bước chờ sàn quyết định.],
    [`this refund is not with staff for a decision` — phán quyết chỉ ra được từ trạng thái tranh chấp.],
    [Tải lại hồ sơ.],

    [`offer_expired` \ `order.ErrOfferExpired`], [409],
    [Thương lượng này đã hết hạn.],
    [`this negotiation has expired` — quá cửa sổ mười hai giờ, hoặc quá ba mươi phút kể từ khi chốt giá.],
    [Mời người dùng mở một cuộc mới.],

    [`ticket_decided_elsewhere` \ `trust.ErrTicketDecidedElsewhere`], [409],
    [Yêu cầu này được giải quyết cùng với phán quyết hoàn tiền.],
    [`this ticket is resolved by deciding the refund it is about` — phiếu loại tranh chấp hoàn tiền không có đường giải quyết bằng tay.],
    [Chuyển kiểm duyệt viên sang màn hình phán quyết hoàn tiền.],

    [`payment_session_expired` \ `finance.ErrSessionExpired`], [409],
    [Lượt thanh toán đã hết hạn. Vui lòng mua lại.],
    [`this payment session has expired` — quá cửa sổ mười lăm phút kể từ khi phiên được mở.],
    [Mở lại lượt mua từ đầu.],

    [`insufficient_balance` \ `finance.ErrInsufficientBalance`], [409],
    [Số dư khả dụng không đủ.],
    [`wallet balance is too low` — một chân bút toán làm số dư khả dụng hoặc số dư tạm giữ âm.],
    [Hiển thị số dư và phần còn thiếu.],

    [`decline_needs_reason` \ `order.ErrDeclineNeedsReason`], [422],
    [Vui lòng nhập lý do từ chối.],
    [`refusing an order needs a reason` — trường lý do rỗng trên lượt từ chối đơn.],
    [Bắt buộc nhập lý do trước khi gửi.],

    [`conversation_with_support` \ `chat.ErrConversationWithSupport`], [422],
    [Hãy gửi yêu cầu hỗ trợ để liên hệ với chúng tôi.],
    [`raise a ticket to reach support` — luồng trực tiếp với tài khoản bàn hỗ trợ bị từ chối vì không kiểm duyệt viên nào đọc được nó.],
    [Hướng người dùng sang luồng mở phiếu hỗ trợ.],

    [`too_many_requests` \ `account.ErrTooManyRequests`], [429],
    [Bạn vừa yêu cầu gửi lại. Vui lòng chờ một phút.],
    [`a message was already sent recently; try again later` — khoá tiết chế còn sống; khoá được đặt trước khi tra cứu tài khoản.],
    [Chờ và thử lại theo tiêu đề thời điểm được thử lại.],

    [`shipping_quote_invalid` \ `order.ErrShippingQuoteInvalid`], [502],
    [Hãng vận chuyển này hiện chưa báo được giá. Hãy chọn hãng khác.],
    [`the carrier did not return a usable delivery price` — mức cước bằng 0, âm, hoặc thân phản hồi sai dạng.],
    [Mời chọn hãng khác; không thu tiền.],
  ),
)

=== Xử lý lỗi theo tầng

Nguyên tắc bao trùm: *không bao giờ trả về nguyên một lỗi vừa nhận được từ lời gọi bên
dưới*. Mỗi tầng bọc thêm một câu mô tả *việc mà bên được gọi đang làm* — chứ không phải
việc mà bên gọi đang làm — nên một chuỗi lỗi đọc lên thành một câu kể mạch lạc, chẳng
hạn "tạo tài khoản: chèn dòng tài khoản: vi phạm ràng buộc duy nhất". Ở tầng điều hợp cơ
sở dữ liệu, câu mô tả còn mang thêm một tiền tố đánh dấu tầng, để nhìn chuỗi là biết ngay
lỗi phát sinh ở đâu. Việc bọc dùng cơ chế giữ nguyên lỗi gốc bên trong, nên mã trạng thái
và mã định danh vẫn đi xuyên qua toàn bộ chuỗi mà không bị mất.

Có đúng hai ngoại lệ cho quy tắc bọc: trả thẳng một lỗi có mã đã dựng sẵn, và truyền lại
một lỗi mà bên được gọi *đã* tự mô tả. Cả hai đều là những trường hợp mà việc bọc thêm
chỉ tạo ra một câu thừa.

#figure(
  kind: table,
  caption: [Trách nhiệm xử lý lỗi của từng tầng],
  table(
    columns: (0.72fr, 1.15fr, 1.15fr),
    align: (left + top, left + top, left + top),
    table.header([Tầng], [Bắt và biến đổi gì], [Ghi nhật ký gì]),
    [Lớp trung gian ngoài cùng],
    [Sinh mã yêu cầu và đặt vào tiêu đề phản hồi *trước khi* chạy bộ xử lý, để nơi ghi
     lỗi đọc lại được.],
    [Một dòng cho mỗi yêu cầu: mã yêu cầu, phương thức, đường dẫn, mã trạng thái, độ trễ.],
    [Lớp xác thực],
    [Thiếu phiếu, phiếu hỏng, hoặc phiên không còn tồn tại đều thành lỗi 401 có mã.],
    [Cảnh báo khi chủ thể của phiếu không khớp với phiên — dấu hiệu của phiếu bị chế tác.],
    [Bộ xử lý yêu cầu],
    [Không biến đổi gì; chỉ đọc yêu cầu, gọi dịch vụ, và giao lỗi cho nơi ghi phản hồi.],
    [Không ghi gì; việc ghi thuộc về nơi ghi phản hồi.],
    [Tầng dịch vụ],
    [Bọc lỗi kèm ngữ cảnh; đổi một lỗi kỹ thuật thành lỗi nghiệp vụ khi nó có nghĩa
     nghiệp vụ; quyết định lỗi nào là cố-gắng-hết-sức và được nuốt.],
    [Cảnh báo cho các lời gọi cố-gắng-hết-sức thất bại; lỗi cho những gì làm hỏng dữ liệu.],
    [Tầng điều hợp cơ sở dữ liệu],
    [Dịch mã lỗi của cơ sở dữ liệu thành lỗi miền: vi phạm duy nhất thành xung đột,
     không có dòng nào thành không tìm thấy.],
    [Không ghi; để lỗi truyền lên kèm tiền tố đánh dấu tầng.],
    [Bộ điều hợp nhà cung cấp ngoài],
    [Hết thời gian chờ, mã trạng thái lạ hoặc thân phản hồi sai dạng đều thành lỗi 502 có
     mã; phản hồi của nhà cung cấp được đọc bằng bộ giải mã khoan dung về chữ hoa chữ thường.],
    [Ghi lại nhà cung cấp, thao tác và độ trễ; số đo đi thẳng vào đường ống quan trắc.],
    [Nơi ghi phản hồi lỗi],
    [Phân rã lỗi thành mã trạng thái, mã định danh và thông điệp; không phân rã được thì
     trả 500 với thông điệp chung.],
    [Ghi mức lỗi *chỉ* cho trường hợp không phân rã được — đó mới là lỗi bất ngờ.],
  ),
)

=== Nhật ký, dữ liệu nhạy cảm và giám sát

Nhật ký ứng dụng có cấu trúc, ở định dạng JSON, và ghi ra dòng chuẩn — không ghi ra tệp,
không tự gửi qua mạng. Đó là một hợp đồng vận hành chứ không phải một tiện lợi: một tác
tử thu thập bên ngoài đọc nhật ký của container và đẩy vào kho nhật ký, nên ứng dụng
không cần biết kho ấy ở đâu và một sự cố của kho không kéo theo sự cố của ứng dụng. Bộ
ghi nhật ký được tiêm qua hàm khởi tạo, không bao giờ là một biến toàn cục, nên mọi thành
phần đều kiểm thử được mà không phải chuyển hướng đầu ra chuẩn.

Ba quy tắc về mức ghi. *Mức lỗi* chỉ dành cho những gì bất ngờ và đáng để ai đó thức
dậy — tiêu biểu là một lỗi không phân rã được thành lỗi có mã. *Mức cảnh báo* dành cho
những gì đã suy giảm nhưng vẫn phục vụ được: một lời gọi cố-gắng-hết-sức thất bại, một
lượt đặt vận đơn phải để lại cho vòng quét, một dịch vụ nhúng không trả lời khiến tìm
kiếm lùi về từ khóa. Lỗi nghiệp vụ thông thường — sai vai, xung đột trạng thái, ràng buộc
đầu vào — *không* được ghi ở mức lỗi, vì chúng là hành vi đúng của hệ thống chứ không
phải sự cố; chúng đã hiện diện trong dòng nhật ký của yêu cầu qua mã trạng thái.

Về dữ liệu nhạy cảm, quy tắc là *không bao giờ ghi* mật khẩu, phiếu xác thực, mã một
lần, số thẻ hay số giấy tờ tùy thân. Điều này được đỡ thêm từ tầng thiết kế dữ liệu chứ
không chỉ từ kỷ luật viết mã: hệ thống không lưu số giấy tờ tùy thân ở đâu cả, mà chỉ lưu
phán quyết của nhà cung cấp xác minh cùng tham chiếu tới ảnh chụp, nên một lượt rò rỉ
bảng ấy không mạo danh được ai. Tương tự, các bí mật dùng một lần sống trong bộ nhớ đệm
có thời hạn chứ không nằm trong bảng, vì thứ phải biến mất sau một lần đọc thì đúng bản
chất là một thời hạn chứ không phải một dòng ai đó phải nhớ đi dọn.

Về giám sát, mỗi phản hồi lỗi mang mã yêu cầu và mỗi dòng nhật ký cũng vậy, nên một
khiếu nại của người dùng nối được tới đúng một dòng. Số đo tỉ lệ lỗi được đọc từ bảng
quan trắc theo tuyến đường và mã trạng thái, và độ trễ đuôi được đọc bằng hàm phân vị xấp
xỉ trên phác đồ đã gộp — *không bao giờ* bằng cách lấy trung bình của các phân vị, vì
trung bình của p95 không phải một đại lượng có nghĩa. Một điểm về khối lượng nhật ký cũng
thuộc về thiết kế xử lý lỗi: một thao tác được vòng quét thử lại và có thể thất bại lâu
dài thì ghi *một dòng tổng kết cho mỗi lượt quét*, chứ không phải một dòng cho mỗi đối
tượng — một nghìn hai trăm dòng lỗi giống hệt nhau mỗi giờ sẽ chôn vùi mọi thứ khác đã
xảy ra.

Số đo chỉ có ích khi có ngưỡng đi kèm, nên bảng dưới đây ghi các ngưỡng cảnh báo cùng
nguồn dữ liệu của từng ngưỡng. Nguyên tắc chọn ngưỡng là *cảnh báo theo triệu chứng người
dùng cảm thấy được, không cảnh báo theo nguyên nhân*: một nhà cung cấp chậm mà hệ thống
vẫn suy giảm êm thì không đánh thức ai, còn một tuyến trả 500 thì có.

#figure(
  kind: table,
  caption: [Ngưỡng cảnh báo, nguồn số đo và mức độ khẩn],
  table(
    columns: (1fr, 0.95fr, 0.55fr, 1.15fr),
    align: (left + top, left + top, left + top, left + top),
    inset: (x: 4.5pt, y: 4.5pt),
    table.header([Điều được theo dõi], [Ngưỡng], [Mức], [Nguồn số đo]),
    [Tỉ lệ lỗi máy chủ trên toàn bộ lưu lượng vào],
    [Vượt 1% trong 5 phút liên tiếp], [Khẩn],
    [Khung nhìn kết tụ theo phút của bảng yêu cầu HTTP, nhóm theo mã trạng thái.],
    [Tỉ lệ lỗi máy chủ trên một tuyến đơn lẻ],
    [Vượt 5% trong 10 phút, với ít nhất 20 lời gọi], [Cảnh báo],
    [Cùng khung nhìn, nhóm thêm theo mẫu đường dẫn.],
    [Độ trễ đuôi của các tuyến đọc],
    [Phân vị 95 vượt 500 ms trong 10 phút], [Cảnh báo],
    [Hàm phân vị xấp xỉ trên phác đồ đã gộp — không bao giờ bằng trung bình của các phân vị.],
    [Tỉ lệ thất bại của một nhà cung cấp ngoài],
    [Vượt 20% trong 10 phút], [Cảnh báo],
    [Khung nhìn kết tụ của bảng lời gọi ra, nơi khái niệm "thất bại" đã được vật chất hoá sẵn.],
    [Cổng thanh toán không quyết toán được],
    [Bất kỳ lời gọi lại nào thất bại hai lần liên tiếp trên cùng một chặng], [Khẩn],
    [Bảng lời gọi ra cộng dòng nhật ký của tuyến gọi lại; đây là con đường tiền đi vào, nên ngưỡng đặt ở mức thấp nhất trong bảng.],
    [Đơn hàng kẹt ở lượt giải ngân],
    [Dòng tổng kết của vòng quét báo khác không trong 3 lượt liên tiếp], [Cảnh báo],
    [Một dòng nhật ký cho mỗi lượt quét, đúng như quy tắc vừa nêu ở trên.],
    [Mẫu quan trắc bị bỏ],
    [Bộ đếm mẫu bị bỏ tăng liên tục trong 15 phút], [Thông tin],
    [Bộ đếm nguyên tử trong bộ thu; đây là số đo về chính hệ thống giám sát, nên nó không được phép đánh thức ai.],
    [Tỉ lệ 401 và 403 bất thường],
    [Gấp 5 lần trung vị của bảy ngày trước, trong 15 phút], [Cảnh báo],
    [Cùng khung nhìn theo phút; đây vừa là tín hiệu vận hành vừa là tín hiệu an ninh.],
  ),
)

=== Thử lại, tính lũy đẳng và suy giảm có kiểm soát

Hệ thống phân biệt rõ ba nhóm hỏng hóc và đối xử với chúng hoàn toàn khác nhau.

*Nhóm thứ nhất: hỏng hóc nhất thời của một phụ thuộc.* Mỗi bộ điều hợp nhà cung cấp
ngoài tự đặt thời hạn chờ cho từng thao tác, vì độ dài hợp lý của thời hạn là kiến thức
của chính nhà cung cấp ấy. Thời hạn *không* được đặt ở mức toàn cục cho máy khách HTTP,
bởi mức ấy tính cả thời gian đọc thân phản hồi và sẽ cắt cụt một luồng dữ liệu đang chảy;
luồng dữ liệu được cấp một ngân sách riêng, dài hơn, phủ trọn lượt đọc. Các mối quan tâm
cắt ngang của chiều gọi ra — số đo, và thử lại hay ngắt mạch khi cần — nằm ở tầng vận
chuyển dưới dạng các lớp bọc, chứ không phải ở từng phương thức: một lớp bọc phủ mọi
phương thức của mọi nhà cung cấp, và nó trả kết quả ngay tại *tiêu đề* phản hồi, vốn là
tín hiệu sức khỏe đúng cho một luồng dữ liệu.

Các con số cụ thể được liệt kê dưới đây. Cần đọc chúng cùng một nguyên tắc chi phối cả
bảng: *chỉ thao tác lũy đẳng mới được thử lại tự động*. Một lượt hỏi giá cước hay một
lượt tra cứu là an toàn để gọi lại; một lượt tính tiền thì không, và một thao tác tính
tiền có vẻ như đã hỏng vẫn phải được coi là *có thể đã xảy ra* cho tới khi lời gọi lại
của nhà cung cấp nói khác đi.

#figure(
  kind: table,
  caption: [Thời hạn chờ, chính sách thử lại và ngưỡng ngắt mạch theo từng phụ thuộc],
  table(
    columns: (0.82fr, 0.5fr, 0.95fr, 1.15fr),
    align: (left + top, left + top, left + top, left + top),
    inset: (x: 4.5pt, y: 4.5pt),
    table.header([Phụ thuộc và thao tác], [Thời hạn], [Thử lại], [Ngắt mạch và ghi chú]),

    [Cổng thanh toán — mở một lượt tính tiền], [20 giây], [*Không tự động thử lại*],
    [Không ngắt mạch. Một lượt mở có thể đã tới nơi, nên thử lại là rủi ro tính tiền hai lần; người mua được mời thử lại và cơ chế nối lại phiên sẽ trả về đúng trang cũ.],

    [Cổng thanh toán — lời gọi lại đi vào hệ thống], [—],
    [Do *nhà cung cấp* thử lại, không giới hạn số lần],
    [Xử lý thất bại trả về mã 500 để nhà cung cấp gửi lại; tính lũy đẳng của lượt xử lý là thứ khiến việc gửi lại vô hại.],

    [Hãng vận chuyển — hỏi giá cước], [10 giây], [2 lần, giãn 200 ms rồi 400 ms],
    [Ngắt mạch mở khi tỉ lệ lỗi vượt 50% trên cửa sổ 20 lời gọi gần nhất; mở trong 30 giây rồi cho một lời gọi thăm dò. Hãng bị ngắt mạch *bị loại khỏi danh sách chọn* thay vì làm hỏng lượt mua.],

    [Hãng vận chuyển — đặt vận đơn], [10 giây], [Không thử lại trong yêu cầu],
    [Không ngắt mạch. Thất bại được để lại cho vòng quét đặt lại, chạy mỗi phút, và mã vận đơn đã lưu là dấu hiệu ngăn kiện hàng thứ hai.],

    [Dịch vụ nhúng véc-tơ — một truy vấn], [10 giây], [Không thử lại],
    [Ngắt mạch mở khi tỉ lệ lỗi vượt 50% trên 20 lời gọi gần nhất, mở 30 giây. Trong lúc mở, tìm kiếm suy giảm về khớp từ khóa, và người dùng không thấy lỗi.],

    [Dịch vụ nhúng véc-tơ — một lô của tiến trình làm giàu], [5 phút], [Lô hỏng để lại hàng đợi cho lượt chạy sau],
    [Không ngắt mạch: đây là tiến trình riêng, một lượt chạy hỏng chỉ tốn một chu kỳ.],

    [Nhà cung cấp xác minh giấy tờ], [30 giây một lời gọi, 30 giây cho lượt tải ảnh], [Không thử lại],
    [Trả 502 cho người gọi; hồ sơ nằm lại hàng đợi duyệt tay, đó là đường lùi có sẵn.],

    [Nhà cung cấp thư điện tử và tin nhắn], [10 giây], [Không thử lại],
    [Cố-gắng-hết-sức: bí mật một lần đã được lưu trước, nên một lượt gửi hỏng chỉ khiến người dùng bấm gửi lại.],

    [Nền tảng thực thi bền], [5 giây], [Không thử lại],
    [Mọi lời gọi tới nó là cố-gắng-hết-sức; hỏng thì vòng quét mỗi phút trở thành đồng hồ duy nhất.],

    [PostgreSQL, bộ nhớ đệm, hàng đợi], [Theo thời hạn của yêu cầu đang phục vụ],
    [Chỉ thử lại ở đúng một chỗ: một va chạm ràng buộc duy nhất khi hai lượt ghi đầu tiên đua nhau],
    [Đây là phụ thuộc *bên trong* ranh giới tin cậy; hỏng ở đây là hỏng thật và phải nổi lên thành lỗi, không phải suy giảm.],
  ),
)

Ba con số trong bảng lặp lại có chủ đích và nên được hiểu như một cặp tham số duy nhất:
*ngưỡng 50% trên cửa sổ 20 lời gọi, mở 30 giây*. Cửa sổ hai mươi lời gọi đủ ngắn để phản
ứng trong vài giây ở mức tải mục tiêu, và đủ dài để một lỗi lẻ không làm mở mạch. Ba mươi
giây là khoảng thời gian ngắn hơn mọi cửa sổ nghiệp vụ của hệ thống, nên một lần ngắt
mạch không bao giờ tự nó làm lỡ một hạn chót.

*Nhóm thứ hai: thông điệp được giao lại.* Mọi kênh bất đồng bộ của hệ thống đều là
ít-nhất-một-lần, nên tính lũy đẳng không phải một tính năng mà là một điều kiện tồn tại.
Có bốn cơ chế được dùng và mỗi cơ chế hợp với một tình huống khác nhau: *khóa lũy đẳng do
bên gọi đặt tên* cho chuyển động tồn kho và chuyển động ví; *chỉ mục duy nhất trên tham
chiếu của nhà cung cấp* để một thông báo giao lại không thành cú tính tiền thứ hai; *bảng
ghi nhận đã-xử-lý* để một lượt cộng dồn uy tín không bị đếm hai lần; và *lượt ghi có bảo
vệ nêu đích danh trạng thái nguồn* để một lượt đọc cũ luôn thua. Riêng các bảng quan trắc
thì *chấp nhận* trùng lặp: khử trùng trên đường ghi nóng đắt hơn cái giá của một mẫu bị
đếm hai lần.

*Nhóm thứ ba: hỏng hóc của một thành phần không nằm trên đường tiền.* Với nhóm này, hệ
thống *suy giảm* chứ không thất bại, và mỗi lần suy giảm đều được ghi cảnh báo để không
âm thầm. Dịch vụ nhúng không trả lời thì tìm kiếm lùi về khớp từ khóa. Module hội thoại
không mở được luồng cho một phiếu hỗ trợ thì phiếu vẫn được ghi và luồng được mở bù ở lần
đọc kế tiếp. Hãng vận chuyển không đặt được vận đơn thì đơn hàng vẫn tồn tại và vòng quét
đặt lại. Nền tảng thực thi bền không sẵn sàng thì mọi lời gọi tới nó là cố-gắng-hết-sức,
và vòng quét định kỳ trở thành đồng hồ duy nhất — điều này đúng cả khi nền tảng ấy bị tắt
hẳn bằng cấu hình, vốn là một cách triển khai hợp lệ.

Ngược lại với ba nhóm trên, có những chỗ hệ thống *cố ý thất bại ồn ào* thay vì suy giảm.
Một triển khai chưa gieo dòng tài khoản bàn hỗ trợ sẽ hỏng ngay ở phiếu đầu tiên chứ
không âm thầm chọn một tài khoản nào đó. Một mô hình nhúng trả về sai bề rộng véc-tơ sẽ
làm dừng lượt làm giàu chứ không ghi bừa. Một nhà cung cấp thanh toán không có trong sổ
đăng ký sẽ bị từ chối chứ không bị thay bằng nhà cung cấp nào khác đang có mặt — tính
tiền qua một kênh tình cờ nằm trong bộ nhớ còn tệ hơn là thất bại. Và một thông báo kết
toán từ cổng thanh toán mà xử lý không thành công sẽ nhận về mã lỗi máy chủ thay vì một
mã thành công lịch sự, vì lý do đã nêu ở TT-A.

== Tiểu kết chương

Chương này đã chuyển bộ yêu cầu ở Chương 3 thành một hồ sơ thiết kế thi công được, đi từ
kiến trúc và mô hình dữ liệu ở hai phần trước tới thiết kế chi tiết ở phần này. Bảy sơ đồ
lớp mô tả toàn bộ bốn mươi sáu bảng nghiệp vụ theo ranh giới module, một sơ đồ thứ tám mô
tả tầng bộ xử lý tuyến cùng các lớp truyền dữ liệu, kèm bốn bảng đối chiếu về trách nhiệm,
về ánh xạ lớp sang bảng, về ánh xạ đối tượng truyền dữ liệu sang điểm cuối và về khuôn lắp
ráp phụ thuộc, cộng sáu mẫu thiết kế được áp dụng và lý do áp dụng từng mẫu. Sáu sơ đồ
trình tự mô tả các kịch bản phức tạp
nhất, và quá trình đối chiếu chúng với sơ đồ lớp đã phát hiện ba chỗ thiếu, đều được bổ
sung ngược trở lại. Năm thuật toán nghiệp vụ được đặc tả bằng mã giả kèm lưu đồ cho các cây
quyết định nhiều nhánh, ví dụ vào–ra cụ thể, phân tích độ phức tạp cả về thời gian lẫn bộ
nhớ, các trường hợp biên, và một mục đối chiếu ngược với những yêu cầu phi chức năng mà
chúng phải phục vụ. Cuối cùng, mô hình xử lý lỗi được trình bày trọn vẹn từ
phân cấp lỗi, danh mục mã, cách xử lý theo tầng, tới chiến lược nhật ký và các nhóm suy
giảm.

Ba kết luận thiết kế đáng được nhắc lại vì chúng chi phối cả phần hiện thực ở chương sau.

Thứ nhất, *trạng thái nên được suy ra thay vì được lưu* ở những chỗ nó có thể suy ra
được. Đơn hàng không có cột trạng thái; bốn giá trị của nó đến từ các mốc thời gian kết
quả. Nhờ vậy hệ thống bớt đi một dữ kiện phải giữ cho đồng bộ với các dữ kiện khác, và
loại bỏ hẳn một lớp lỗi mà không lượng kiểm thử nào phát hiện hết được.

Thứ hai, *một quy tắc chỉ nên có một định nghĩa, dù có bao nhiêu thứ dẫn động nó*. Mọi
lần chờ có kỳ hạn đều là một phương thức lũy đẳng duy nhất, được gọi bởi nền tảng thực
thi bền và bởi vòng quét định kỳ. Chính vì cả hai gọi cùng một định nghĩa mà việc bật cả
hai không gây xung đột, và việc tắt hẳn nền tảng thực thi bền vẫn là một cách triển khai
đúng đắn chứ không phải một chế độ suy giảm.

Thứ ba, *ranh giới quyền sở hữu quan trọng hơn vị trí đặt mã*. Tranh chấp được đưa ra
khỏi module đơn hàng và trở thành một phiếu hỗ trợ, nhưng phán quyết làm dịch chuyển tiền
vẫn ở lại nơi giữ tiền; bàn hỗ trợ được nhận diện bằng vai trò chứ không bằng tên; và một
bản ghi trong quá khứ tự nêu tên nhà cung cấp đã phục vụ nó thay vì phụ thuộc vào một
biến cấu hình hiện tại. Ba quyết định ấy khác nhau về chủ đề nhưng cùng một hình dạng:
đặt mỗi sự thật ở nơi duy nhất có thẩm quyền khẳng định nó.
