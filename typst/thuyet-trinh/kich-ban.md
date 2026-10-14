# Kịch bản thuyết trình 20 phút + demo — ShopNexus

---

## 2. Demo ở đâu, và tại sao chia làm hai

Câu trả lời ngắn: **không demo dồn một cục ở cuối. Chẻ làm hai, mỗi khối đứng ngay sau
đúng slide đã giải thích nó.**

- **Demo A đặt ngay sau trang 8 (Vòng đời đơn hàng).** Hội đồng vừa nhìn xong sơ đồ máy
  trạng thái; cho họ thấy đúng máy trạng thái đó chạy thật thì hình vẽ chuyển thành bằng
  chứng. Nếu để đến cuối, đến lúc demo họ đã quên các nhãn `hết 72 giờ`, `theo phán quyết`.
- **Demo B đặt ngay sau trang 15 (Gợi ý cá nhân hoá).** Hai trang 13–15 là phần dễ bị hỏi
  "có thật không hay chỉ là sơ đồ" nhất. Gõ bốn câu tìm kiếm ngay tại chỗ dập được câu hỏi
  đó trước khi nó được nêu.
- Trang 9–12 (dữ liệu, Saga, durable execution, kiến trúc) nằm **sau** Demo A là có chủ ý:
  lúc đó hội đồng đã thấy đơn hàng đi hết vòng, nên "tại sao cần thực thi bền" là câu trả
  lời cho một thứ họ vừa xem, không phải một khái niệm trừu tượng.

Lý do thứ hai, thực dụng hơn: chẻ demo thành 4:30 + 2:30 thì một khối vỡ vẫn còn khối kia.
Một khối 7 phút mà tắc ở phút thứ hai là mất trắng

## 4. Script — phần người 1 (mở đầu, trang 1–4)

### Trang 1 · Bìa — 0:45

> Kính thưa quý thầy cô. Nhóm em gồm ba thành viên, thực hiện đề tài *Xây dựng ứng dụng
> thương mại điện tử sử dụng kiến trúc Microservices*, dưới sự hướng dẫn của thầy Nguyễn
> Đức Thịnh.
>
> Bài trình bày của nhóm chia ba phần: đặt vấn đề, phân tích thiết kế, và kết luận. Trong
> phần thứ hai và thứ ba, nhóm em có **hai lần demo trực tiếp trên hệ thống đang chạy** —
> một lần cho vòng giao dịch có ký quỹ, một lần cho tìm kiếm và gợi ý. Em xin phép bắt đầu.

### Trang 2 · § 1 Đặt vấn đề — 0:10

> Phần thứ nhất, đặt vấn đề.

### Trang 3 · Bối cảnh — 1:20

> Thương mại điện tử C2C ở Việt Nam hiện chủ yếu chạy trên các nền tảng rao vặt. Đặc điểm
> chung của các nền tảng này là **chúng kết nối thông tin, chứ không đứng ra bảo đảm giao
> dịch**. Người mua và người bán tìm thấy nhau trên nền tảng, rồi rời nền tảng để tự thoả
> thuận với nhau.
>
> Hệ quả chia đều cho hai bên, và không bên nào giải được một mình. *(chỉ thẻ 1)* Người mua
> nếu chuyển tiền trước thì không có gì bảo đảm sẽ nhận đúng hàng. *(chỉ thẻ 2)* Người bán
> nếu gửi hàng trước thì chịu rủi ro khách từ chối nhận. Ai đi trước cũng là người chịu rủi
> ro, nên cả hai đều muốn bên kia đi trước.
>
> *(chỉ thẻ 3)* Và vì phần thương lượng diễn ra ở kênh ngoài — tin nhắn riêng, gọi điện —
> nên khi có tranh chấp thì **không còn căn cứ nào để phân xử**. Giá đã chốt là bao nhiêu,
> hàng cam kết thế nào, không ai chứng minh được.
>
> Đây là bài toán nhóm em đặt ra: không phải bài toán thiếu chỗ để đăng tin, mà là bài toán
> **thiếu niềm tin**.

### Trang 4 · Mục tiêu và giải pháp — 1:15

> Giải pháp của nhóm em là **đưa nền tảng vào giữa hai bên** và giữ trọn vòng giao dịch bên
> trong hệ thống, từ lúc đăng bán đến lúc quyết toán hoặc phân xử. Cụ thể là ba trụ.
>
> *(thẻ 1)* **Ký quỹ.** Tiền người mua trả không đi thẳng cho người bán. Nền tảng giữ, và
> chỉ giải ngân khi giao dịch đã xong. Không ai phải đi trước nữa — cả hai đi trước với nền
> tảng.
>
> *(thẻ 2)* **Thương lượng trong hệ thống.** Giá được chốt bằng một đề xuất giá có hiệu lực
> mười hai giờ, và **giá đó gắn thẳng vào thanh toán**. Không có bước "nhớ lại xem hôm đó
> đã thoả thuận bao nhiêu".
>
> *(thẻ 3)* **Hoàn tiền và tranh chấp có bằng chứng.** Khiếu nại phải kèm bằng chứng; hai
> bên tự thoả thuận được thì kết thúc ở đó, không thì điều phối viên của sàn phân xử, và
> tiền trong ký quỹ đi theo phán quyết.
>
> Ba trụ này quyết định gần như toàn bộ kiến trúc phía sau, và đó là phần bạn em trình bày
> tiếp. *(quay sang người 2)*

---

## 5. Script — phần người 2 (trang 5–12) và người 3 (trang 13–15)

### Trang 5 · § 2 Phân tích và thiết kế — 0:10 · **người 2**

> Phần thứ hai, phân tích và thiết kế.

### Trang 6 · Tác nhân — 0:55

> Hệ thống có ba vai, xếp theo quyền tăng dần từ trái sang phải.
>
> **Người dùng** là *một* vai, không phải hai. Một tài khoản vừa mua vừa bán — và đây là
> lựa chọn thiết kế, không phải tiết kiệm công. Trong C2C, người bán hôm nay là người mua
> hôm sau; tách thành hai loại tài khoản thì phải đồng bộ hồ sơ, uy tín, ví giữa hai bên.
> Ràng buộc duy nhất: **muốn bán thì phải xác minh danh tính**.
>
> **Điều phối viên** là người của sàn: kiểm duyệt tin đăng, phân xử tranh chấp, trả lời hỗ
> trợ. **Quản trị viên** cấp và thu hồi tài khoản điều phối, cấu hình toàn sàn, đối soát
> dòng tiền.
>
> Hai vai vận hành **không tự đăng ký được** — không có đường nào từ ngoài vào; chỉ quản trị
> viên tạo ra điều phối viên.

### Trang 7 · Luồng ký quỹ — 1:15

> Đây là luồng trung tâm của hệ thống, và em xin nhấn một điểm ngược trực giác: **chính dòng
> tiền sinh ra đơn hàng, chứ không phải đơn hàng sinh ra dòng tiền.**
>
> Người mua chốt một **đơn nháp** — đơn nháp chưa phải đơn hàng. Hệ thống mở một **phiên
> thanh toán** với cổng thanh toán. Khi cổng **báo về** rằng tiền đã nhận, tiền vào **ký
> quỹ**, và *đến lúc đó* đơn hàng mới ra đời.
>
> Thứ tự này quan trọng: nghĩa là trong hệ thống **không tồn tại đơn hàng chưa trả tiền**.
> Không có trạng thái "chờ thanh toán" để rò rỉ, không có đơn treo phải đi dọn.
>
> Người bán xác nhận và gửi hàng, hàng giao thành công. Từ mốc giao thành công, hệ thống
> đếm **72 giờ**. Hết 72 giờ không có khiếu nại thì tự **giải ngân** cho người bán. Có
> khiếu nại thì vào **phân xử hoàn tiền**, và tiền vẫn nằm trong ký quỹ cho tới khi có
> phán quyết — rồi mới đi theo phán quyết đó.

### Trang 8 · Vòng đời đơn hàng — 0:45

> Cùng luồng đó, nhìn dưới dạng máy trạng thái. Bảy trạng thái, và mỗi mũi tên có một
> **tác nhân kích hoạt** ghi trên nhãn: người bán, hãng vận chuyển, hết 72 giờ, điều phối
> viên.
>
> Điểm cần nhấn: **mỗi đơn hàng là một quy trình bền**, sống nhiều ngày, và các bước chuyển
> trạng thái không do người dùng bấm mà do **thời hạn** hoặc **tín hiệu từ bên ngoài** đẩy.
> Một tiến trình khởi động lại giữa đường không được làm mất mốc 72 giờ của bất kỳ đơn nào.
> Ràng buộc đó là thứ quyết định kiến trúc, em sẽ quay lại ở trang durable execution.
>
> Nhưng trước đó, xin phép quý thầy cô cho nhóm em demo chính vòng này chạy thật.

→ **vào DEMO A** (mục 6)

### Trang 9 · Cơ sở dữ liệu — 0:30 · sau demo

> Đây là lược đồ dữ liệu của riêng ngữ cảnh đơn hàng — thứ vừa chạy trên màn hình.
>
> Điều đáng nói không nằm trong hình mà nằm ở ranh giới của nó: **mỗi module sở hữu một
> lược đồ riêng và là thành phần duy nhất được phép ghi vào đó, và không một khoá ngoại nào
> bắc qua ranh giới hai lược đồ.** Đó là thứ duy nhất không đi theo được khi tách module ra
> chạy riêng, nên nhóm em không dùng nó ngay từ đầu. Chi tiết đầy đủ ở mục 4 của quyển.

### Trang 10 · Saga và bù trừ — 0:45

> Vì một luồng nghiệp vụ đi qua nhiều dịch vụ và kéo dài, nó **không gói được trong một
> transaction**. Mẫu kinh điển cho việc này là **Saga**: chia quy trình thành nhiều giao
> dịch nhỏ, bước nào lỗi thì chạy thao tác **bù trừ** ngược lại các bước đã xong.
>
> Nhóm em có dùng Saga, nhưng phải nói rõ hai giới hạn của nó. *(chỉ)* Thứ nhất, **không
> phải thao tác nào cũng hoàn tác được** — đã gửi email thì không thu email về. Thứ hai,
> nó đẩy chi phí sang chỗ khác: mỗi bước phải viết thêm nhánh lỗi và nhánh bù trừ, nên số
> đường đi cần kiểm thử tăng nhanh.
>
> Đặc biệt, Saga xử lý **lỗi nghiệp vụ** rất tốt nhưng dùng cho **lỗi hạ tầng** thì sai:
> tiến trình chết ở bước 3 không có nghĩa là giao dịch nên bị huỷ.

### Trang 11 · Durable execution — 0:45

> Nên nhóm em đặt Saga lên trên một cơ chế **thực thi bền**.
>
> Cách hoạt động: **mỗi thao tác đi ra ngoài của hàm nghiệp vụ đều được ghi vào nhật ký
> thực thi trước.** Khi tiến trình gặp sự cố, hàm được **phát lại từ đầu**, nhưng những
> bước đã hoàn thành **lấy kết quả từ nhật ký** chứ không thực hiện lại.
>
> Kết quả là hai loại lỗi được tách đôi: **lỗi hạ tầng thì khôi phục và đi tiếp** — không
> bù trừ gì cả; **bù trừ chỉ dành cho lỗi nghiệp vụ**. Cái giá phải trả là điều kiện ở
> dòng cuối: **mọi thao tác phải lũy đẳng**, vì nó có thể được gọi lại. Trong hệ thống của
> nhóm em, điều đó hiện ra thành khoá lũy đẳng trên từng bút toán của ví.
>
> Và đây chính là câu trả lời cho mốc 72 giờ ở trang trước: mốc đó không nằm trong bộ nhớ
> của một tiến trình, nó nằm trong nhật ký bền.

### Trang 12 · Kiến trúc hệ thống — 0:45

> Toàn cảnh. Em xin chỉ ba đường nét chính chứ không đọc từng khối.
>
> Một, **một cổng vào duy nhất** cho cả web và di động; định danh được cổng dịch thành
> dạng mờ trước khi vào trong, và **việc kiểm vai trò nằm ở tầng dịch vụ chứ không ở cổng**
> — để một dịch vụ bị gọi trực tiếp vẫn không mất kiểm soát.
>
> Hai, **các module giao tiếp qua trục sự kiện**, trừ những chỗ buộc phải đồng bộ. Nhờ vậy
> ngữ cảnh đơn hàng và ngữ cảnh tài chính được phép lệch nhau trong khoảnh khắc mà không
> bên nào chặn bên nào.
>
> Ba, **nghiệp vụ tiền tệ bị cô lập vào một dịch vụ duy nhất**, và mọi dịch vụ khác bị tước
> quyền ghi vào sổ cái. Đây là ràng buộc kiến trúc trực tiếp sinh ra từ yêu cầu ký quỹ ở
> trang 4.
>
> Phần tìm kiếm và gợi ý xin nhường bạn em. *(quay sang người 3)*

### Trang 13 · Tìm kiếm lai — 0:45 · **người 3**

> Với một sàn C2C, tin đăng do người bán tự viết, nên câu chữ trong kho rất tuỳ tiện —
> viết tắt, sai chính tả, mất dấu. Tìm kiếm theo từ khoá thuần sẽ bỏ sót rất nhiều.
>
> Nhưng thay hẳn bằng tìm kiếm ngữ nghĩa cũng sai: *(chỉ thẻ 1)* **từ khoá là thứ duy nhất
> giữ được chính xác tên model, mã sản phẩm và thông số** — người tìm "iPhone 12" không
> muốn nhận iPhone 13.
>
> Nên nhóm em chạy **cả hai nhánh song song** trên cùng một truy vấn: *(chỉ)* nhánh từ khoá
> cho **độ chính xác**, nhánh ngữ nghĩa cho **độ bao phủ**, rồi hợp hai danh sách bằng
> **RRF** — xếp hạng theo nghịch đảo thứ hạng. Lý do chọn RRF là nó chỉ cần **thứ hạng**
> của hai nhánh, không cần điểm số của chúng cùng thang đo — mà điểm của một nhánh BM25 và
> một nhánh vector thì không cùng thang.
>
> *(chỉ thẻ 3)* Kết quả: giảm bỏ sót mà không mất độ chính xác.

### Trang 14–15 · Gợi ý cá nhân hoá — 0:45

> Phần gợi ý. Nhóm em không dùng lọc cộng tác, vì một sàn C2C phần lớn là hàng **độc bản** —
> mỗi tin đăng một cái, bán xong là hết, nên ma trận người-vật phẩm gần như không có ô nào
> lặp.
>
> Thay vào đó nhóm em dựng **chân dung sở thích từ hành vi**. *(trang 14)* Các tín hiệu —
> lưu sản phẩm, xem, click, mua — được cộng dồn với **suy giảm theo thời gian dạng lũy
> thừa**, để việc tuần này nặng hơn việc tháng trước. Rồi nhóm theo danh mục và giữ lại
> **bốn nhóm sở thích**, mỗi nhóm là một vector đại diện kèm mức độ quan tâm.
>
> Con số bốn là có lý do: nó vừa đủ để phủ bốn kiểu nhu cầu khác nhau *(đọc dòng dưới)* —
> nhu cầu thiết yếu, sở thích cá nhân, mua theo mùa, và xu hướng tức thời. Một vector duy
> nhất sẽ trộn bốn thứ này thành một điểm trung bình vô nghĩa.
>
> *(trang 15)* Từ bốn nhóm đó lấy ứng viên theo **cosine**, chèn thêm **20% sản phẩm mới**
> để feed không đóng băng quanh sở thích cũ, rồi **lấy mẫu ngẫu nhiên có trọng số** thay vì
> lấy top cứng — để hai lần vào không ra y một danh sách.
>
> Nhóm em xin demo hai phần này. *(vào DEMO B)*

### Trang 16–17–18 · Kết luận — 1:55 · **người 1**

**Trang 16** (0:10)
> Phần cuối, kết luận.

**Trang 17** (1:25)
> *(cột 1)* Về kết quả, nhóm em đã **thiết kế trọn hệ thống** từ nghiệp vụ đến kiến trúc và
> dữ liệu; xây **dịch vụ nền cùng hai ứng dụng khách — web và di động — sinh mã từ cùng một
> đặc tả API**; và các luồng ký quỹ, giao nhận, hoàn tiền, phân xử **chạy được đầu cuối**,
> như quý thầy cô vừa xem.
>
> *(cột 2)* Về hạn chế, nhóm em xin nói thẳng ba điểm. **Vận chuyển và xác minh danh tính
> còn ở mức giả lập** — phần giả lập nằm ở lớp nhà cung cấp, còn hợp đồng và luồng nghiệp
> vụ phía trên là thật. **Chưa có kiểm thử toàn trình tự động**; hiện mới có kiểm thử đơn vị
> và tích hợp theo module. Và **chưa đánh giá hiệu năng, chưa kiểm thử tải** — nhóm em chưa
> có số liệu nào để nói hệ thống chịu được bao nhiêu.
>
> *(cột 3)* Hướng phát triển đi đúng theo ba hạn chế đó: tích hợp thật với đối tác vận
> chuyển và định danh — mà nhờ lớp nhà cung cấp thì đây là thêm một bộ chuyển đổi, không
> phải sửa nghiệp vụ; bổ sung kiểm thử toàn trình và kiểm thử tải; và mở rộng sang các hình
> thức giao dịch khác.

**Trang 18** (0:20)
> Phần trình bày của nhóm em xin kết thúc ở đây. Cảm ơn quý thầy cô đã lắng nghe, và nhóm
> em xin sẵn sàng nhận câu hỏi.

---

## 6. DEMO A · 6:00 — vòng ký quỹ, rồi mặt vận hành

Người 2 thuật, người 1 bấm. Ba cửa sổ mở sẵn, **đã đăng nhập**, ba desktop ảo:
**A** `khoakomlem` → `/product/ipad-gen-9-64gb-wifi-kem-bao-da-va-but-cam-ung` ·
**B** `bob_store` → `/inbox` · **C** `admin` → `/admin`.
iPad Gen 9, niêm yết 4.632.000, `negotiable`.

### 6a · Vòng ký quỹ — 3:40

| # | | Bấm | Chốt bằng câu |
|---|---|---|---|
| 1 | A | Đề xuất giá → `4200000` → Gửi | hiệu lực 12 giờ |
| 2 | B | Thẻ đề xuất trong luồng chat → Chấp nhận | mặc cả nằm lại trong hệ thống làm bằng chứng |
| 3 | A | Thanh toán | chấp nhận rồi có 30 phút để trả |
| 4 | A | *Mock: express* + *Mock: pay now (succeeds)* → Thanh toán | giá lấy thẳng từ đề xuất, không ai gõ lại |
| 5 | A | *(tự nhảy sang danh sách đơn)* | đơn ra đời **sau** khi tiền vào ký quỹ |
| 6 | B | `/account/sales` → Xác nhận | cú bấm này mới là lúc đặt vận đơn |
| 7 | A | F5 sau ~5s, F5 lần nữa | hãng giả lập đẩy checkpoint qua webhook |
| 8 | A | Đã nhận hàng → **chọn ảnh** `01-unboxing-1.jpg` | ảnh **bắt buộc**, là bằng chứng cho khiếu nại sau. Từ đây đếm 72 giờ |
| 9 | A | mở đơn iPhone 12 (đã lùi 73h) | bộ quét 1 phút tự giải ngân, không ai bấm gì |

### 6b · Mặt vận hành — 2:20

| # | | Bấm | Chốt bằng câu |
|---|---|---|---|
| 10 | C | `/admin` — chỉ 4 thẻ hàng đợi | toàn bộ mặt vận hành của sàn là bốn hàng đợi: tin chờ duyệt, hồ sơ định danh, phiếu hỗ trợ, lệnh rút |
| 11 | C | `/admin/listings` → tin **"Khô gà"** của `bob_store` → Duyệt | duyệt là xuất bản ngay; gỡ thì tin ẩn khỏi mọi kết quả và **người bán nhận được lý do đã ghi**. Hàng đợi xếp cũ nhất trước |
| 12 | B→C | B `/account/products/{id}` → sửa giá → Lưu · C `/admin/listings` → bản sửa chờ duyệt → Duyệt | **sửa một tin đang bán không ghi thẳng lên tin đó** — bản sửa vào hàng đợi, tin cũ vẫn chạy trên sàn cho tới khi duyệt |
| 13 | B→C | B `/account/refunds/{id}` (vụ `disputed`) → C `/admin/tickets/{id}` → xem bằng chứng → Ra phán quyết | tiền trong ký quỹ **đi theo phán quyết**; điều phối viên ẩn danh với cả hai bên |

**Dial thời lượng.** Chạy hết 6b = 2:20. Về đúng 20 phút thì bỏ **12**, còn 1:35. Chỉ còn
1 phút thì giữ **10 + 13** (0:55) — bước 13 là nhánh khiếu nại trên slide vòng đời, không bỏ.
Trong 6a cắt theo thứ tự **9 → 8**; bước 1–4 không bỏ.

**Bẫy.** Bước 8 khai `required,min=1` — thiếu ảnh là lỗi xác thực. · Giỏ hàng chỉ thanh
toán 1 tin đăng mỗi lượt → đi từ trang sản phẩm. · Không có nút quyết toán ngay → bước 9
buộc phải chuẩn bị trước. · Thẻ đề xuất không tự hiện thì F5, đừng đứng chờ. ·
Bước 11 và 13 **dán sẵn URL**, đừng tìm trong hàng đợi 4.096 tin trên sân khấu.
**Bẫy.** Bước 8 khai `required,min=1` — thiếu ảnh là lỗi xác thực. · Giỏ hàng chỉ thanh
toán 1 tin đăng mỗi lượt → đi từ trang sản phẩm. · Không có nút quyết toán ngay → bước 9
buộc phải chuẩn bị trước. · Thẻ đề xuất không tự hiện thì F5, đừng đứng chờ.

---

## 7. DEMO B · 2:30 — tìm kiếm, feed, app

Người 3 thuật, người 2 bấm. Bốn câu chốt sẵn (`server/dev/demo-search.md`) —
**không ứng khẩu câu thứ năm.**

| # | Gõ ở `/search` | Chốt bằng câu |
|---|---|---|
| 1 | `ao thu unilo` | hiểu ra *áo thun uniqlo*; câu người dùng gõ **vẫn ở đó, đứng cuối** → hiểu sai thì chỉ hẹp lại, không bị thay thế |
| 2 | `dt cu duoi 5tr` | bốn từ → một truy vấn ngữ nghĩa + danh mục + ngưỡng giá + tình trạng |
| 3 | `qua tang sinh nhat re` | không có từ khoá nào để khớp; tìm kiếm từ khoá **không thể** trả về |
| 4 | `op lung iphone` | cùng cặp từ với câu 2, hướng ngược lại — do câu hỏi quyết định |
| 5 | `/` (vẫn `khoakomlem`) | kệ hàng dựng từ 4 nhóm sở thích + 20% hàng mới; đăng xuất thì lùi về *mới nhất* |
| 6 | điện thoại: app → tìm 1 câu | cùng tài khoản, cùng dữ liệu, mã máy khách **sinh từ cùng một đặc tả** |

**Đừng gõ:** `ao nam 300k-500k` (đo được 2/6 trong khoảng) · `máy ảnh Canon`, `nồi cơm điện`
(kho có 0 tin → trang như hỏng) · `ip moi` (kho có "Camera IP" và khớp thật) ·
**gõ lại y một câu lần hai** (thứ tự kết quả đổi).

Trễ thì cắt **4**, rồi **6**.

---

## 8. Checklist

### T − 1 ngày

```sql
-- 1. khoakomlem và admin hiện KHÔNG đăng nhập được. Gán cùng mật khẩu Bob@12345:
UPDATE account.account SET password_hash =
  (SELECT password_hash FROM account.account WHERE username='bob_store')
 WHERE username IN ('khoakomlem','admin');

-- 2. Checkout đang hiện 12 phương thức, gồm "Mock: rail is down", SePay, Stripe:
UPDATE finance.option SET is_enabled=false WHERE type='payment'   AND id NOT IN ('mock-success','mock-redirect');
UPDATE "order".option SET is_enabled=false WHERE type='transport' AND id NOT IN ('mock-express','mock-standard');

-- 3. Đơn "Đã quyết toán" cho bước 9 (bộ quét giải ngân trong vòng 1 phút):
UPDATE "order"."order" SET received_at = now() - interval '73 hours'
 WHERE id = 326 AND payout_released_at IS NULL;
```

`docker exec -i server-db-1 psql -U app -d shopnexus < fix.sql` rồi `docker restart server-gateway-dev-1`.

- [ ] Kiểm lại 3 lần đăng nhập; mở `/checkout` xem còn đúng 2 dòng thanh toán
- [ ] Sửa địa chỉ mặc định của `khoakomlem` (đang là `"asdasasdas"`, tên `"Dau"`) ở `/account/contacts`
- [ ] **2 ảnh unboxing iPad** → `~/demo-anh/01-unboxing-1.jpg`, `02-unboxing-2.jpg`, mỗi tấm ≤600 KB
- [ ] Chạy thử 4 câu Demo B — câu nào yếu thì đổi **hôm nay**, không đổi trên sân khấu
- [ ] **Bước 12 — chạy thử luồng sửa tin đăng một lần.** Kịch bản viết theo giả định *bản sửa vào hàng đợi kiểm duyệt, tin cũ vẫn chạy*. Nếu thực tế ghi thẳng lên tin thì đổi câu chốt, đừng nói sai trước hội đồng
- [ ] **Bước 11** — mở `/admin/listings` xem 2 tin "Khô gà" của `bob_store` có ở trang đầu không (hàng đợi 4.096 tin, xếp cũ nhất trước). Không thấy thì đổi sang tin bất kỳ ở trang đầu
- [ ] **Dán sẵn URL** của bước 11, 12, 13 vào bookmark hoặc file text — gồm `refund_id` và `ticket_id` của vụ `disputed`
- [ ] Điện thoại: build lại bản **debug** (release thiếu quyền INTERNET → app chết trắng), đăng nhập sẵn
- [ ] Commit/stash `server/` + `website/`, build lại, rồi **chạy Demo A một lượt trọn**
- [ ] Quay bản ghi màn hình Demo A làm dự phòng, để sẵn trên desktop

### T − 30 phút

- [ ] `curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3000/api/v1/categories` → 200
- [ ] 3 cửa sổ đúng trang trên 3 desktop ảo; nhớ phím chuyển
- [ ] Gõ trước một câu tìm kiếm bất kỳ (không phải 4 câu sẽ demo) để làm nóng model
- [ ] Zoom **125%**; tắt thông báo, ẩn bookmark, đóng tab lạ
- [ ] Mở hộp thoại chọn tệp một lần ở `~/demo-anh/` — trình duyệt nhớ thư mục cuối
- [ ] Điện thoại: hotspot + chiếu màn hình + tắt ngủ · máy cắm sạc

**Wi-Fi hội trường chết** → đổi `website/.env` sang `NEXT_PUBLIC_API_URL=http://localhost:5000/api/v1`
rồi khởi động lại `next start`. **Tập trước bước này.**
