# Thuật ngữ thống nhất

<!-- Sinh từ docs/i18n/glossary.yaml bằng `bun docs/i18n/glossary.ts render`; sửa file yaml, không sửa file này. -->

Bảng này áp dụng cho báo cáo định kỳ, báo cáo cuối, slide, `registry/requirements.yaml` và chữ trên giao diện: ứng dụng, website, email và thông báo. Cột "Không dùng" liệt kê các cách gọi đã gặp trong bản thảo. Cột "Tiếng Anh" là cách gọi trên giao diện tiếng Anh. Mã yêu cầu, tên repo (`shopnexus/console`, `shopnexus/agent`), tên công nghệ, mã nguồn và phần `en` của registry giữ nguyên.

`make i18n` (chạy `bun docs/i18n/glossary.ts check`) quét chữ trên giao diện của ứng dụng, website và máy chủ theo bảng này, mục "Giao diện" và mục "Câu dùng chung".

## Người và vai trò

| Dùng | Nghĩa | Không dùng | Tiếng Anh |
|---|---|---|---|
| người dùng | tài khoản mua bán trên ứng dụng hoặc website | khách hàng, user | user (không dùng: customer) |
| khách | người chưa đăng nhập (tác nhân Khách) |  | guest |
| người bán, người mua | vai trò của người dùng trong một giao dịch | seller, buyer | seller, buyer |
| nhân viên | gọi chung điều phối viên và quản trị viên | nhân sự quản lý, thành viên console, thành viên trang điều hành, thành viên | staff |
| điều phối viên | nhân viên xử lý báo cáo vi phạm và phiếu hỗ trợ | mod, moderator, kiểm duyệt viên | moderator |
| quản trị viên | nhân viên có thêm quyền quản lý nhân viên, nhật ký kiểm toán và cấu hình | admin | administrator |
| shipper | người của hãng vận chuyển giao hàng tới cửa | nhân viên giao hàng, người giao hàng | courier |

## Phần mềm

| Dùng | Nghĩa | Không dùng | Tiếng Anh |
|---|---|---|---|
| hệ thống | phần mềm của đề tài nói chung | sàn, nền tảng, ShopNexus (trong văn xuôi) | the system |
| nền tảng | chỉ dùng cho Chợ Tốt, Facebook Marketplace, Shopee… khi khảo sát, so sánh |  | platform |
| ứng dụng | ứng dụng Android cho người dùng | app | app |
| website | bản web cho người dùng | trang web | website |
| trang điều hành | trang web dành cho nhân viên | console, trang quản trị, bảng điều khiển, dashboard | console |
| trợ lý AI | trợ lý trên trang điều hành, đọc dữ liệu và đề xuất. Lần đầu trong chương 2 ghi "trợ lý AI (AI agent)" | agent, AI Agent, trợ lý (đứng một mình), chatbot | AI assistant |
| dịch vụ AI | tác nhân phụ trong đặc tả ca sử dụng |  | AI service |
| mô hình ngôn ngữ lớn (LLM) | lần đầu trong mỗi chương; các lần sau ghi "mô hình ngôn ngữ" | mô hình AI | large language model (LLM) |
| phân hệ | một phần nghiệp vụ trong máy chủ: Tài khoản, Tin đăng, Khám phá, Trò chuyện, Giao dịch, Vận chuyển, Uy tín, Thông báo, Vận hành và hỗ trợ, Media | module, mô-đun, dịch vụ nghiệp vụ | module |
| dịch vụ | chương trình chạy riêng hoặc bên ngoài máy chủ: trợ lý AI, LiteLLM, Restate, hãng vận chuyển, dịch vụ giả lập hãng | service | service |

## Tin đăng và hàng

| Dùng | Nghĩa | Không dùng | Tiếng Anh |
|---|---|---|---|
| tin đăng (viết tắt "tin" khi đã rõ) | bản ghi người bán đăng lên hệ thống: được đăng, sửa, ẩn, tìm thấy, giữ chỗ | bài đăng, tin rao, bài viết, listing, sản phẩm | listing (không dùng: ad, advert) |
| món hàng, hàng | đồ vật thật: có tình trạng, được chụp, gửi, giao, xem tại cửa | sản phẩm, mặt hàng | item (không dùng: product) |
| giá niêm yết | giá người bán ghi trên tin đăng | giá bán, giá đăng, giá gốc | listed price (không dùng: asking price) |
| tình trạng | thang Mới / Như mới / Đã dùng |  | condition |
| trạng thái tin đăng | đang xử lý, đang bán, đang ẩn, đang giữ chỗ, đã bán, bị từ chối, đã xóa |  | listing status |
| phường/xã | đơn vị vị trí của tin đăng | xã/phường | commune |
| ảnh | ảnh của tin đăng, tin nhắn, phiếu hỗ trợ | hình ảnh | photo (không dùng: picture) |
| ẩn tin, hiện tin |  | gỡ tin | hide, show |

## Trả giá

| Dùng | Nghĩa | Không dùng | Tiếng Anh |
|---|---|---|---|
| trả giá | hoạt động hai bên đưa giá qua lại (UC-DEAL-02) | thương lượng, đàm phán, mặc cả | make an offer (không dùng: haggle, bargain, negotiate) |
| phiên trả giá | bản ghi của một người mua trên một tin đăng | thương lượng (danh từ) | offer thread |
| lượt trả giá | một bước trong phiên: đề nghị, phản giá, chấp nhận, từ chối, rút giá | nước đi, offer | move |
| giá đề nghị | mức giá người mua đưa ra | đề nghị giá | offer |
| phản giá | mức giá người bán đưa lại |  | counter-offer |
| chấp nhận giá | hành động của một bên |  | accept |
| chốt giá, đã chốt giá | trạng thái sau khi một bên chấp nhận |  | agreed price |

## Đơn và giao nhận

| Dùng | Nghĩa | Không dùng | Tiếng Anh |
|---|---|---|---|
| đơn COD (viết tắt "đơn" khi đã rõ) | đơn giao COD đồng kiểm | đơn hàng, order | COD order ("order" once clear) |
| yêu cầu COD | thao tác người mua tạo đơn COD |  | cash on delivery |
| trạng thái đơn | chờ tạo đơn, đã gửi, hoàn tất, giao không thành, đã hủy | hoàn thành, giao không thành công, giao thất bại | order status |
| vận đơn, mã vận đơn | vận đơn trên tài khoản GHTK/GHN của người bán |  | waybill, tracking code |
| hãng vận chuyển (viết tắt "hãng") | GHTK, GHN | đơn vị vận chuyển, nhà vận chuyển, bên vận chuyển, carrier | carrier (không dùng: shipping company) |
| phí vận chuyển | phí hãng tính, người nhận trả khi nhận hàng | phí ship, phí giao hàng, cước | shipping fee |
| đồng kiểm | người mua xem hàng tại cửa rồi nhận hoặc từ chối |  | check at the door |

## Trò chuyện và hỗ trợ

| Dùng | Nghĩa | Không dùng | Tiếng Anh |
|---|---|---|---|
| cuộc trò chuyện | giữa hai người dùng, giữa người dùng và hệ thống trong phiếu hỗ trợ, giữa nhân viên và trợ lý AI | hội thoại, luồng hội thoại, chat, cuộc chat | conversation |
| tin nhắn, tin nhắn hệ thống |  |  | message, system message |
| hộp thư | danh sách cuộc trò chuyện của một người dùng |  | inbox |
| phiếu hỗ trợ | yêu cầu người dùng gửi cho hệ thống (UC-MOD-09) | ticket, yêu cầu hỗ trợ, khiếu nại | support ticket (không dùng: complaint) |
| khiếu nại | chỉ dùng khi khảo sát các nền tảng khác |  | complaint |
| báo cáo vi phạm | người dùng báo một tin đăng hoặc tài khoản | tố cáo, report | report |
| ca báo cáo | các báo cáo vi phạm về cùng một tài khoản, gom lại |  | report case |
| tạm khóa tài khoản |  | khóa tài khoản, bị khóa, cấm, ban | suspend the account (không dùng: ban, banned) |
| nhật ký kiểm toán | dòng ghi lại mỗi thao tác của nhân viên (UC-SHR-02, UC-MOD-05) | nhật ký thao tác, audit log | audit log |
| đánh giá, trả lời đánh giá |  | nhận xét, review | review, reply to a review |
| số liệu uy tín, hạn mức |  | điểm uy tín, bậc uy tín | reputation figures, limits (không dùng: reputation points, tier) |
| cảnh báo lừa đảo |  |  | scam warning |

## Đăng nhập và thông báo

| Dùng | Nghĩa | Không dùng | Tiếng Anh |
|---|---|---|---|
| mã OTP | mã dùng một lần khi đăng nhập hoặc thêm email | mã xác thực, mã đăng nhập, mã xác minh | code (không dùng: verification code, OTP) |
| phiên đăng nhập |  | session | session |
| thông báo đẩy | thông báo gửi tới điện thoại | push | push notification |

## Chính tả

| Dùng | Nghĩa | Không dùng | Tiếng Anh |
|---|---|---|---|
| hủy, khóa, thủy, hòa, lũy | dấu thanh đặt trên nguyên âm chính, như sách giáo khoa hiện hành | huỷ, khoá, thuỷ, hoà, luỹ |  |

## Giao diện

Cách gọi được phép trên giao diện dù cột "Không dùng" ở trên có liệt kê, vì nghĩa khác hoặc vì là tên riêng.

| Dùng trên giao diện | Thay cho | Lý do |
|---|---|---|
| ShopNexus | ShopNexus | tên thương hiệu trên logo, chân trang và câu như "ShopNexus không giữ tiền" |
| hàng cấm, chất cấm | cấm | hàng bị cấm bán |
| ban đêm | ban | từ tiếng Việt, không phải "ban" tài khoản |
| đã mod | mod | máy game đã độ |
| Uy tín của bạn |  | tên màn hình số liệu uy tín và hạn mức của người dùng |
| Nhắn tin, Nhắn tin với | chat | nút mở cuộc trò chuyện; trong câu vẫn viết "cuộc trò chuyện" |
| Đơn COD | đơn hàng | tên màn hình danh sách đơn và nhóm thông báo |

## Câu dùng chung

Câu mà các sản phẩm ở cột "Có ở" phải viết y nguyên, trong mọi ngôn ngữ sản phẩm đó có.

| Câu | Nói về | Có ở |
|---|---|---|
| Đồ cũ giá tốt, xem hàng rồi mới trả | khẩu hiệu | app, website, server |
| Hãng vận chuyển gửi tiền hàng cho bạn 1–2 ngày sau khi người mua nhận. | khi nào người bán nhận tiền | app, website, server |
| Người mua từ chối nhận thì bạn trả phí vận chuyển cả chiều đi và chiều về. | ai trả phí khi người mua từ chối nhận | app, website |
| Đã trả tiền cho shipper thì không đòi lại qua ứng dụng được. | không đòi lại tiền đã trả shipper | app, website |
| Hệ thống không phân xử giữa người mua và người bán. | hệ thống không phân xử | app, website |
| Shipper tới, bạn mở hàng xem rồi mới trả tiền. Không ưng thì từ chối nhận, hàng quay về người bán và bạn không mất tiền. | cách đồng kiểm | app, website |
| Giao tận nơi, xem hàng rồi mới trả | cách giao trong một câu | app, website |
| Không vết, hoặc vết rất nhỏ chỉ thấy khi soi gần | tình trạng Như mới | app, website |
