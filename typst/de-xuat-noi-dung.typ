// ============================================================
//  de-xuat-noi-dung.typ — thân nội dung đề xuất đề tài
//  Không áp template. Hai bản dùng chung tệp này:
//    de-xuat-de-tai.typ  bản nộp A4 (bìa + mục lục + header)
//    idea.typ            bản gọn để đọc/chia sẻ nhanh
// ============================================================
#import "common/tokens.typ": *

= Vấn đề

Tìm kiếm hiện gồm hai phần tách rời: ô truy vấn tự do chạy trên *hybrid search* (vector dày + thưa), và một tập bộ lọc có cấu trúc. Muốn thu hẹp kết quả, người mua phải tự phiên dịch nhu cầu của mình thành hơn mười tham số rời rạc.

Với một phát biểu như _"kiếm gì đó tặng sinh nhật bạn, tầm 500 nghìn, gần đây thôi"_, hybrid search nhúng nguyên văn cả chuỗi rồi tìm lân cận: nó không tách được đâu là mục tiêu, đâu là ràng buộc, không hỏi lại, không nhớ gì giữa các lượt. Hệ gợi ý cá nhân hoá cũng không giải thích được, nên người dùng không có cách phản hồi khi gợi ý sai.

= Ý tưởng cốt lõi

Đặt một *agent* dựa trên mô hình ngôn ngữ vào giữa người dùng và tầng truy xuất: agent suy luận, gọi công cụ của sàn để tra cứu, tự điều phối trọng số các tín hiệu tìm kiếm, rồi trả kết quả kèm giải thích. Đề tài dùng mô hình sẵn có qua API, không huấn luyện lại.

#fig(
  [Kiến trúc tổng thể. Đề tài xây dựng khối agent, bộ công cụ, trí nhớ hội thoại và phần đầu ra kèm theo kết quả; tầng hybrid search bên dưới được tái sử dụng nguyên trạng.],
  spacing: (10mm, 7mm),

  nt((0, 0), [Nhập văn bản], name: <in-text>),
  nt((2, 0), [Nhập giọng nói], name: <in-voice>),

  ncore((1, 1), [AGENT \ #text(size: 0.8em)[hoạch định → gọi công cụ → quan sát → suy luận → lặp]],
    width: 92mm, name: <agent>),
  np((3.1, 1), [#text(size: 0.85em)[Trí nhớ hội thoại \ ràng buộc đã chốt]], name: <mem>),

  np((1, 2), [#text(size: 0.85em)[Công cụ (chỉ đọc): tìm kiếm · sản phẩm tương tự · danh mục \ nhãn · sở thích · đơn đã mua · vị trí]],
    width: 92mm, name: <tools>),

  np((1, 3), [HYBRID SEARCH VÀ XẾP HẠNG #text(size: 0.8em)[(đã có, giữ nguyên)]],
    width: 92mm, name: <hs>),

  ng((1, 4), [#text(size: 0.85em)[Kết quả · chip ràng buộc sửa được · câu diễn giải]],
    width: 92mm, name: <out>),

  edge(<in-text>, <agent>, "-|>"),
  edge(<in-voice>, <agent>, "-|>"),
  edge(<agent>, <mem>, "<|-|>"),
  edge(<agent>, <tools>, "-|>"),
  edge(<tools>, <hs>, "-|>"),
  edge(<hs>, <out>, "-|>"),
)

Agent không thay thế hybrid search cũng không thay thế bộ lọc, mà *điền* vào bộ lọc; mọi ràng buộc nó đặt đều hiện thành chip sửa được. Agent chỉ đọc dữ liệu --- đặt hàng, thanh toán, thương lượng giá vẫn cần người dùng xác nhận.

= So sánh hybrid search và tìm kiếm có agent

#figure(
  table(
    columns: (0.9fr, 1.3fr, 1.4fr),
    align: (left, left, left),
    [], [Hybrid search], [Có agent],
    [Đầu vào], [một chuỗi truy vấn], [phát biểu nhu cầu, nhiều lượt, văn bản hoặc giọng nói],
    [Xử lý], [nhúng nguyên văn thành một vector, tìm lân cận], [phân tích thành tín hiệu có trọng số, tra cứu, rồi mới gọi hybrid search],
    [Ràng buộc giá, danh mục, khu vực], [người dùng tự đặt], [agent suy ra và đặt, hiện thành chip],
    [Phủ định (_"đừng ồn"_)], [kéo kết quả *về phía* cụm từ, ngược hướng], [thành trọng số âm, loại trừ],
    [Ngữ cảnh người dùng], [không dùng], [đọc sở thích, đơn đã mua, vị trí],
    [Nhiều lượt], [mỗi truy vấn độc lập], [giữ ràng buộc đã chốt],
    [Giải thích], [không], [mệnh đề căn cứ kèm chip],
  ),
  caption: [Khác biệt giữa hai cách tiếp cận.],
)

== Hai luồng xử lý trên cùng một phát biểu

#fig(
  [Cùng một phát biểu đi qua hai luồng. Bên trái chỉ có một kênh biểu đạt; bên phải câu được tách theo vai trò trước khi truy xuất.],
  spacing: (10mm, 7mm),

  np((1, 0), [#text(size: 0.9em)[Phát biểu: _"bàn phím cơ chơi game, gõ êm một chút, dưới 2 triệu"_]],
    width: 100mm, name: <q>),

  np((0, 1), [HYBRID SEARCH \ #text(size: 0.8em)[nhúng cả câu thành MỘT vector]],
    width: 50mm, name: <h1>),
  np((2, 1), [CÓ AGENT \ #text(size: 0.8em)[tách câu theo vai trò]],
    width: 56mm, name: <a1>),

  np((0, 2), [#text(size: 0.8em)[Tìm lân cận dày + thưa \ \ Chỉ một kênh là độ tương đồng: \ không có chiều âm, không phân \ biệt vai trò các thành phần]],
    width: 50mm, name: <h2>),
  np((2, 2), [#text(size: 0.78em)[
    "chơi game" → mục tiêu → #sym.plus danh mục, nhóm switch \
    "gõ êm" → loại trừ → #sym.minus switch clicky \
    "dưới 2 triệu" → ràng buộc → lọc giá \
    nguyên văn → luôn giữ → #sym.plus truy vấn gốc \
    #v(2pt) đưa xuống hybrid search kèm bộ lọc
  ]], width: 56mm, name: <a2>),

  ng((0, 3), [#text(size: 0.8em)[*Thiên hướng:* mọi thứ có mô tả gần giống cả câu --- phụ kiện bàn phím, bàn phím clicky quảng cáo là "gõ êm", hàng vượt ngân sách]],
    width: 50mm, name: <h3>),
  ng((2, 3), [#text(size: 0.8em)[*Thiên hướng:* bàn phím cơ switch êm trong ngân sách; phụ kiện và switch clicky bị đẩy xuống. Kèm chip sửa được và câu diễn giải]],
    width: 56mm, name: <a3>),

  edge(<q>, <h1>, "-|>"), edge(<q>, <a1>, "-|>"),
  edge(<h1>, <h2>, "-|>"), edge(<a1>, <a2>, "-|>"),
  edge(<h2>, <h3>, "-|>"), edge(<a2>, <a3>, "-|>"),
)

Khác biệt gốc nằm ở chỗ hybrid search chỉ có *một kênh* để diễn đạt mọi thứ: độ tương đồng với một vector. Mà độ tương đồng thì không có chiều âm và không phân biệt vai trò của từng thành phần trong câu, nên một yêu cầu loại trừ lại kéo kết quả về phía thứ cần loại.

Nguyên văn phát biểu luôn được giữ lại với trọng số dương, nên khi mô hình phân tích sai thì tập tín hiệu co về truy vấn gốc và luồng bên phải suy biến thành luồng bên trái: *cận dưới chất lượng của phương án đề xuất chính là hiện trạng.*

== Chủ động thu thập ngữ cảnh người dùng không nêu

Với _"cuối tuần này đi cắm trại, còn thiếu gì thì gợi ý giúp"_, agent phân rã mục tiêu thành các nhu cầu con, đọc đơn hàng cũ để loại thứ đã mua, đọc vị trí để giới hạn khu vực, rồi tìm cho từng nhu cầu còn lại --- chuỗi này không biểu diễn được bằng một truy vấn.

#fig(
  [Agent loop. Chặn trên số bước là bắt buộc, nếu không vòng lặp có thể không dừng.],
  spacing: (22mm, 9mm),

  np((0, 0), [HOẠCH ĐỊNH \ #text(size: 0.8em)[thiếu dữ kiện gì?]], name: <plan>),
  nd((0, 1), [#text(size: 0.85em)[Đủ căn cứ?]], name: <ck>),
  np((0, 2), [#text(size: 0.85em)[Gọi công cụ (chỉ đọc) \ quan sát kết quả]], name: <tool>),
  ng((2, 1), [#text(size: 0.85em)[Trả lời + chip \ + diễn giải]], name: <ans>),
  nr((2, 2.15), [#text(size: 0.78em)[Dừng khi: chạm ngưỡng số bước · \ hết thời gian · công cụ lỗi → \ quay về hybrid search]], name: <stop>),

  edge(<plan>, <ck>, "-|>"),
  edge(<ck>, <tool>, "-|>", rel[chưa]),
  edge(<ck>, <ans>, "-|>", rel[đủ]),
  edge(<tool>, <plan>, "-|>", bend: 55deg, rel[lặp]),
)

== Giải thích gợi ý cá nhân hoá

Hệ gợi ý hiện phân rã lịch sử tương tác thành bốn nhóm sở thích và sinh bốn dải sản phẩm. Thuật toán giữ nguyên; đề tài thêm cho mỗi dải một mệnh đề căn cứ --- _"vì bạn đã lưu bốn sản phẩm cùng danh mục trong hai tuần qua"_ --- kèm nút phản hồi, và phản hồi quay lại thành tín hiệu tiêu cực cho vòng sau. Giải thích được là tiền đề của hiệu chỉnh được.

= Kế hoạch đánh giá

Bộ dữ liệu khoảng 150--200 phát biểu nhu cầu tiếng Việt có gán nhãn mức độ liên quan. Ba cấu hình, mỗi cấu hình thêm đúng một thành phần, để tách bạch đóng góp của từng phần:

#figure(
  table(
    columns: (0.35fr, 1.5fr, 1fr),
    align: (center, left, left),
    [Cấu hình], [Nội dung], [Trả lời câu hỏi],
    [*A*], [Hybrid search --- hiện trạng], [mốc đối chứng],
    [*B*], [A + phân tích ý định bằng LLM, một lượt, chưa có công cụ và trí nhớ], [hiểu ý định giúp được bao nhiêu?],
    [*C*], [B + agent loop: gọi công cụ nhiều bước, trí nhớ, ngữ cảnh người dùng], [agent loop giúp thêm bao nhiêu?],
  ),
  caption: [Ba cấu hình đối chứng.],
)

Độ đo: nDCG\@10, MRR\@10, Recall\@50, tỉ lệ truy vấn rỗng. Kèm một đợt đánh giá theo nhiệm vụ (khoảng 20 người dùng): thời gian hoàn thành, số thao tác, và tỉ lệ chip bị chỉnh lại --- chỉ số cuối đo trực tiếp độ chính xác của bước phân tích nhu cầu.
