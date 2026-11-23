# Thuật ngữ thống nhất

Bảng này áp dụng cho báo cáo định kỳ, báo cáo cuối, slide, `registry/requirements.yaml` và chữ trên giao diện: ứng dụng, website, email và thông báo. Cột "Không dùng" liệt kê các cách gọi đã gặp trong bản thảo. Mã yêu cầu, tên repo (`shopnexus/console`, `shopnexus/agent`), tên công nghệ, mã nguồn và phần `en` của registry giữ nguyên.

`bun docs/i18n/check-terms.ts` quét chữ trên giao diện của ứng dụng, website và máy chủ theo cột "Không dùng" và mục "Giao diện" ở cuối bảng.

## Người và vai trò

| Dùng | Nghĩa | Không dùng |
|---|---|---|
| người dùng | tài khoản mua bán trên ứng dụng hoặc website | khách hàng, user |
| khách | người chưa đăng nhập (tác nhân Khách) | |
| người bán, người mua | vai trò của người dùng trong một giao dịch | seller, buyer |
| nhân viên | gọi chung điều phối viên và quản trị viên | nhân sự quản lý, thành viên console, thành viên trang điều hành, thành viên |
| điều phối viên | nhân viên xử lý báo cáo vi phạm và phiếu hỗ trợ | mod, moderator, kiểm duyệt viên |
| quản trị viên | nhân viên có thêm quyền quản lý nhân viên, nhật ký kiểm toán và cấu hình | admin |
| shipper | người của hãng vận chuyển giao hàng tới cửa | nhân viên giao hàng, người giao hàng |

## Phần mềm

| Dùng | Nghĩa | Không dùng |
|---|---|---|
| hệ thống | phần mềm của đề tài nói chung | sàn, nền tảng, ShopNexus (trong văn xuôi) |
| nền tảng | chỉ dùng cho Chợ Tốt, Facebook Marketplace, Shopee… khi khảo sát, so sánh | |
| ứng dụng | ứng dụng Android cho người dùng | app |
| website | bản web cho người dùng | trang web |
| trang điều hành | trang web dành cho nhân viên | console, trang quản trị, bảng điều khiển, dashboard |
| trợ lý AI | trợ lý trên trang điều hành, đọc dữ liệu và đề xuất. Lần đầu trong chương 2 ghi "trợ lý AI (AI agent)" | agent, AI Agent, trợ lý (đứng một mình), chatbot |
| dịch vụ AI | tác nhân phụ trong đặc tả ca sử dụng | |
| mô hình ngôn ngữ lớn (LLM) | lần đầu trong mỗi chương; các lần sau ghi "mô hình ngôn ngữ" | mô hình AI |
| phân hệ | một phần nghiệp vụ trong máy chủ: Tài khoản, Tin đăng, Khám phá, Trò chuyện, Giao dịch, Vận chuyển, Uy tín, Thông báo, Vận hành và hỗ trợ, Media | module, mô-đun, dịch vụ nghiệp vụ |
| dịch vụ | chương trình chạy riêng hoặc bên ngoài máy chủ: trợ lý AI, LiteLLM, Restate, hãng vận chuyển, dịch vụ giả lập hãng | service |

## Tin đăng và hàng

| Dùng | Nghĩa | Không dùng |
|---|---|---|
| tin đăng (viết tắt "tin" khi đã rõ) | bản ghi người bán đăng lên hệ thống: được đăng, sửa, ẩn, tìm thấy, giữ chỗ | bài đăng, tin rao, bài viết, listing, sản phẩm |
| món hàng, hàng | đồ vật thật: có tình trạng, được chụp, gửi, giao, xem tại cửa | sản phẩm, mặt hàng |
| giá niêm yết | giá người bán ghi trên tin đăng | giá bán, giá đăng, giá gốc |
| tình trạng | thang Mới / Như mới / Đã dùng | |
| trạng thái tin đăng | đang xử lý, đang bán, đang ẩn, đang giữ chỗ, đã bán, bị từ chối, đã xóa | |
| phường/xã | đơn vị vị trí của tin đăng | xã/phường |
| ảnh | ảnh của tin đăng, tin nhắn, phiếu hỗ trợ | hình ảnh |
| ẩn tin, hiện tin | | gỡ tin |

## Trả giá

| Dùng | Nghĩa | Không dùng |
|---|---|---|
| trả giá | hoạt động hai bên đưa giá qua lại (UC-DEAL-02) | thương lượng, đàm phán, mặc cả |
| phiên trả giá | bản ghi của một người mua trên một tin đăng | thương lượng (danh từ) |
| lượt trả giá | một bước trong phiên: đề nghị, phản giá, chấp nhận, từ chối, rút giá | nước đi, offer |
| giá đề nghị | mức giá người mua đưa ra | đề nghị giá |
| phản giá | mức giá người bán đưa lại | |
| chấp nhận giá | hành động của một bên | |
| chốt giá, đã chốt giá | trạng thái sau khi một bên chấp nhận | |

## Đơn và giao nhận

| Dùng | Nghĩa | Không dùng |
|---|---|---|
| đơn COD (viết tắt "đơn" khi đã rõ) | đơn giao COD đồng kiểm | đơn hàng, order |
| yêu cầu COD | thao tác người mua tạo đơn COD | |
| trạng thái đơn | chờ tạo đơn, đã gửi, hoàn tất, giao không thành, đã hủy | hoàn thành, giao không thành công, giao thất bại |
| vận đơn, mã vận đơn | vận đơn trên tài khoản GHTK/GHN của người bán | |
| hãng vận chuyển (viết tắt "hãng") | GHTK, GHN | đơn vị vận chuyển, nhà vận chuyển, bên vận chuyển, carrier |
| phí vận chuyển | phí hãng tính, người nhận trả khi nhận hàng | phí ship, phí giao hàng, cước |
| đồng kiểm | người mua xem hàng tại cửa rồi nhận hoặc từ chối | |

## Trò chuyện và hỗ trợ

| Dùng | Nghĩa | Không dùng |
|---|---|---|
| cuộc trò chuyện | giữa hai người dùng, giữa người dùng và hệ thống trong phiếu hỗ trợ, giữa nhân viên và trợ lý AI | hội thoại, luồng hội thoại, chat, cuộc chat |
| tin nhắn, tin nhắn hệ thống | | |
| hộp thư | danh sách cuộc trò chuyện của một người dùng | |
| phiếu hỗ trợ | yêu cầu người dùng gửi cho hệ thống (UC-MOD-09) | ticket, yêu cầu hỗ trợ, khiếu nại |
| khiếu nại | chỉ dùng khi khảo sát các nền tảng khác | |
| báo cáo vi phạm | người dùng báo một tin đăng hoặc tài khoản | tố cáo, report |
| ca báo cáo | các báo cáo vi phạm về cùng một tài khoản, gom lại | |
| tạm khóa tài khoản | | khóa tài khoản, bị khóa, cấm, ban |
| nhật ký kiểm toán | dòng ghi lại mỗi thao tác của nhân viên (UC-SHR-02, UC-MOD-05) | nhật ký thao tác, audit log |
| đánh giá, trả lời đánh giá | | nhận xét, review |
| số liệu uy tín, hạn mức | | điểm uy tín, bậc uy tín |
| cảnh báo lừa đảo | | |

## Đăng nhập và thông báo

| Dùng | Nghĩa | Không dùng |
|---|---|---|
| mã OTP | mã dùng một lần khi đăng nhập hoặc thêm email | mã xác thực, mã đăng nhập, mã xác minh |
| phiên đăng nhập | | session |
| thông báo đẩy | thông báo gửi tới điện thoại | push |

## Chính tả

| Dùng | Nghĩa | Không dùng |
|---|---|---|
| hủy, khóa, thủy, hòa, lũy | dấu thanh đặt trên nguyên âm chính, như sách giáo khoa hiện hành | huỷ, khoá, thuỷ, hoà, luỹ |

## Giao diện

Cách gọi được phép trên giao diện dù cột "Không dùng" ở trên có liệt kê, vì nghĩa khác hoặc vì là tên riêng.

| Dùng trên giao diện | Thay cho | Lý do |
|---|---|---|
| ShopNexus | ShopNexus | tên thương hiệu trên logo, chân trang và câu như "ShopNexus không giữ tiền" |
| hàng cấm, chất cấm | cấm | hàng bị cấm bán, không phải tạm khóa tài khoản |
| ban đêm | ban | từ tiếng Việt, không phải "ban" tài khoản |
| đã mod | mod | máy game đã độ, không phải điều phối viên |
| Uy tín của bạn | | tên màn hình số liệu uy tín và hạn mức của người dùng |
| Nhắn tin, Nhắn tin với … | chat | nút mở cuộc trò chuyện; trong câu vẫn viết "cuộc trò chuyện" |
| Đơn COD | đơn hàng | tên màn hình danh sách đơn và nhóm thông báo, email |
