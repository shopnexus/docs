// Glossary for <Term id="…"> hovercards and the Glossary page (EN + VI).

export type GlossaryCategory = "marketplace" | "architecture" | "api";

interface Entry {
  term: string;
  definition: string;
}

export interface GlossaryEntry {
  id: string;
  category: GlossaryCategory;
  en: Entry;
  vi: Entry;
  related?: string[];
}

const e = (
  id: string,
  category: GlossaryCategory,
  en: [string, string],
  vi: [string, string],
  related?: string[],
): GlossaryEntry => ({
  id,
  category,
  en: { term: en[0], definition: en[1] },
  vi: { term: vi[0], definition: vi[1] },
  ...(related ? { related } : {}),
});

export const glossary: GlossaryEntry[] = [
  e(
    "cod-inspection",
    "marketplace",
    [
      "COD with inspection",
      "The only in-app transaction path: the buyer looks at the item at the door and pays the shipper the price and shipping only if they accept it.",
    ],
    [
      "COD đồng kiểm",
      "Đường giao dịch duy nhất trong app: người mua xem hàng ở cửa, ưng mới trả shipper tiền hàng và phí ship.",
    ],
    ["waybill", "refusal-rate"],
  ),
  e(
    "waybill",
    "marketplace",
    [
      "Waybill",
      "The shipment the seller creates in their own carrier account; they type its carrier, code and fee into ShopNexus.",
    ],
    [
      "Vận đơn",
      "Đơn gửi hàng seller tạo trên tài khoản hãng vận chuyển của mình, rồi nhập hãng, mã và phí ship vào ShopNexus.",
    ],
    ["cod-inspection"],
  ),
  e(
    "listing-claims",
    "marketplace",
    [
      "Tin ghi",
      'The facts a seller states in a listing, such as battery level or "never repaired", which the buyer can check at the door.',
    ],
    [
      "Tin ghi",
      'Các thông tin seller ghi trong tin, như mức pin hay "máy zin, chưa sửa", để buyer kiểm khi đồng kiểm.',
    ],
    ["cod-inspection"],
  ),
  e(
    "reserved-listing",
    "marketplace",
    [
      "Reserved listing",
      "A listing held for one order while its parcel is on the way; it stays public and the seller cannot edit it.",
    ],
    [
      "Tin đang giữ chỗ",
      "Tin được giữ cho một đơn trong lúc bưu kiện đang đi; tin vẫn công khai và người bán không sửa được.",
    ],
  ),
  e(
    "issue-report",
    "marketplace",
    [
      "Issue report",
      "A record a buyer opens in the chat, with photos, about a problem found after paying; the seller refunds or declines, and the platform does not rule on it.",
    ],
    [
      "Ghi nhận sự cố",
      "Ghi nhận buyer mở trong chat, kèm ảnh, về vấn đề phát hiện sau khi trả tiền; seller tự hoàn hoặc từ chối, sàn không phân xử.",
    ],
  ),
  e(
    "refusal-rate",
    "marketplace",
    [
      "Refusal rate",
      "How often a buyer refuses parcels at the door, counted from the orders sellers report as returned.",
    ],
    ["Tỉ lệ từ chối nhận", "Tần suất buyer từ chối nhận hàng ở cửa, tính theo các đơn seller báo bị hoàn."],
    ["cod-inspection"],
  ),
  e(
    "nearby-feed",
    "marketplace",
    ["Nearby feed", "Active listings within 50 km of the viewer, ranked by distance and freshness."],
    ["Feed gần bạn", "Các tin đang bán trong vòng 50 km quanh người xem, xếp theo khoảng cách và độ mới."],
    ["boost"],
  ),
  e(
    "boost",
    "marketplace",
    ["Boost", "A paid placement that puts a listing at the top of the nearby feed for one or more days."],
    ["Đẩy tin", "Dịch vụ trả phí đưa tin lên đầu mục Gần bạn trong một hoặc vài ngày."],
    ["nearby-feed"],
  ),
  e(
    "modular-monolith",
    "architecture",
    [
      "Modular monolith",
      "One server binary split into modules that each own their tables and call each other only through services.",
    ],
    [
      "Modular monolith",
      "Một binary server chia thành các module, mỗi module giữ bảng riêng và chỉ gọi nhau qua service.",
    ],
  ),
  e(
    "durable-flow",
    "architecture",
    ["Durable flow", "A use case run as a Restate service, whose steps are journaled so it finishes after a crash."],
    [
      "Durable flow",
      "Use case chạy dưới dạng Restate service, các bước được ghi journal nên vẫn chạy xong sau khi server sập.",
    ],
    ["outbox", "sign-in-flow"],
  ),
  e(
    "outbox",
    "architecture",
    [
      "Outbox",
      "The events table that a module writes in the same transaction as the change, and that a bus drains into Restate.",
    ],
    ["Outbox", "Bảng events mà module ghi trong cùng transaction với thay đổi, rồi bus đẩy sang Restate."],
    ["durable-flow"],
  ),
  e(
    "aggregate",
    "architecture",
    ["Aggregate", "The unit a module reads and saves whole in one transaction, such as an account or a listing."],
    ["Aggregate", "Đơn vị mà module đọc và lưu nguyên khối trong một transaction, như một tài khoản hay một tin đăng."],
    ["write-id"],
  ),
  e(
    "write-id",
    "architecture",
    ["Write ID", "The ID of the last write to an aggregate, used to detect concurrent writes and recognise a retry."],
    ["Write ID", "ID của lần ghi gần nhất vào một aggregate, dùng để phát hiện ghi đồng thời và nhận ra lần thử lại."],
    ["aggregate"],
  ),
  e(
    "sign-in-flow",
    "architecture",
    [
      "SignIn flow",
      "The durable Restate flow that takes a verified phone number and finds or creates the account and its phone identity.",
    ],
    [
      "Flow SignIn",
      "Flow Restate bền vững nhận số điện thoại đã xác minh rồi tìm hoặc tạo tài khoản cùng identity số điện thoại.",
    ],
    ["durable-flow"],
  ),
  e(
    "screen-view",
    "architecture",
    [
      "Screen view",
      "One GET endpoint that returns everything one app screen shows, composed from other modules' services.",
    ],
    [
      "Màn (screen view)",
      "Một endpoint GET trả về mọi thứ một màn của app cần hiện, ghép từ service của các module khác.",
    ],
  ),
  e(
    "search-understanding",
    "architecture",
    [
      "Search understanding",
      "The language model's reading of a query into boosts and demotes, checked against real data and cached for 7 days.",
    ],
    [
      "Hiểu câu tìm",
      "Phần mô hình ngôn ngữ đọc câu tìm thành các tín hiệu tăng hoặc giảm điểm, đối chiếu với dữ liệu thật và cache 7 ngày.",
    ],
  ),
  e(
    "upload",
    "architecture",
    [
      "Upload",
      "A photo the app puts straight into the object store through a presigned URL, which the server then attaches and processes.",
    ],
    [
      "Lượt upload",
      "Một ảnh app đưa thẳng lên object store qua presigned URL, sau đó server gắn vào nơi dùng và xử lý.",
    ],
  ),
  e(
    "push-token",
    "architecture",
    ["Push token", "The FCM device token, tied to one sign-in session and deleted when that session ends."],
    ["Push token", "Device token FCM gắn với một phiên đăng nhập, bị xóa khi phiên đó kết thúc."],
  ),
  e(
    "otlp",
    "architecture",
    ["OTLP", "The OpenTelemetry protocol the server uses to export logs, traces and metrics to a collector."],
    ["OTLP", "Giao thức OpenTelemetry mà server dùng để gửi log, trace và metric tới collector."],
    ["trace-id"],
  ),
  e(
    "idempotency-key",
    "api",
    [
      "Idempotency-Key",
      "A UUID header, made once per user action and reused on retry, that makes a repeated request return the first run's result.",
    ],
    [
      "Idempotency-Key",
      "Header UUID tạo mới cho mỗi thao tác của người dùng và dùng lại khi gửi lại, để request lặp lại nhận đúng kết quả của lần chạy đầu.",
    ],
    ["durable-flow"],
  ),
  e(
    "cursor",
    "api",
    ["Cursor", "The next_cursor value of one page, passed back to fetch the next page of a list."],
    ["Cursor", "Giá trị next_cursor của một trang, gửi lại để lấy trang tiếp theo của danh sách."],
  ),
  e(
    "error-code",
    "api",
    ["Error code", "The stable snake_case code in an error body that the app maps to its own text."],
    ["Mã lỗi", "Trường code dạng snake_case cố định trong body lỗi, app map sang câu hiển thị của mình."],
    ["trace-id"],
  ),
  e(
    "trace-id",
    "api",
    ["Trace ID", "The ID in every error body and in the Trace-Id header that finds a request in logs and traces."],
    ["Trace ID", "ID có trong mọi body lỗi và header Trace-Id, dùng để tìm request trong log và trace."],
    ["otlp"],
  ),
  e(
    "stream-hint",
    "api",
    [
      "Stream event",
      "A server-sent event on /v1/stream that carries only IDs and tells the open app to reload what it shows.",
    ],
    [
      "Sự kiện stream",
      "Sự kiện server-sent trên /v1/stream, chỉ mang ID, báo app đang mở tải lại những gì đang hiển thị.",
    ],
  ),
];
