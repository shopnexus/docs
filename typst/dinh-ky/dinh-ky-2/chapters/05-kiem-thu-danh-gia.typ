#import "../../../common/tokens.typ": *

= KIỂM THỬ VÀ ĐÁNH GIÁ

== Phương pháp kiểm thử

=== Phạm vi và nguyên tắc lựa chọn

Các kịch bản được lựa chọn dựa trên rủi ro nghiệp vụ, ưu tiên những tình huống có thể ảnh hưởng đến trạng thái giao dịch hoặc quyền lợi của người dùng:

+ Yêu cầu được gửi lại do gián đoạn kết nối, có nguy cơ tạo trùng đơn COD hoặc vận đơn.
+ Máy chủ gặp sự cố giữa quy trình nhiều bước, có nguy cơ gây sai lệch trạng thái giữa tin đăng, đơn COD và phiên trả giá.
+ Nhiều yêu cầu được xử lý đồng thời, có nguy cơ vượt hạn mức đơn COD hoặc số lần nhập sai mã OTP.
+ Các thời hạn nghiệp vụ không được thực thi đúng, chẳng hạn thời hạn tạo đơn hoặc lấy hàng trong 3 ngày.

=== Môi trường và cách thực hiện

Ở dịch vụ nền, các kiểm thử có truy cập dữ liệu được thực hiện trên PostgreSQL thực tế. Mỗi ca kiểm thử sử dụng một bản sao cơ sở dữ liệu riêng để tránh ảnh hưởng lẫn nhau. Môi trường kiểm thử cho phép điều chỉnh thời gian, phục vụ kiểm tra thời hạn 3 ngày của đơn COD, 7 ngày của đánh giá và 24 giờ của ảnh mà không phải chờ theo thời gian thực.

Cơ chế tiêm lỗi được sử dụng để mô phỏng tình huống một bước đã ghi dữ liệu nhưng trả về lỗi một lần. Khi quy trình được thực thi lại, kiểm thử xác nhận các tác động đã hoàn thành không bị lặp. Kiểm thử đầu cuối vận hành toàn bộ hệ thống với hộp thư giả lập để tiếp nhận mã OTP qua email và bộ ký giả lập cho thông tin xác minh số điện thoại, tài khoản Google. Tích hợp vận chuyển được kiểm tra bằng dịch vụ giả lập có định dạng phản hồi theo tài liệu GHTK và GHN [14], [15]; các phản hồi của hệ thống được đối chiếu với đặc tả API. Phạm vi này chưa thay thế việc kiểm chứng kết nối với hệ thống vận chuyển thực tế.

Đối với ứng dụng Android, các quy tắc nghiệp vụ và tầng xử lý màn hình được kiểm thử tự động. Sau mỗi bước tích hợp với dịch vụ nền, nhóm kiểm thử trực tiếp trên môi trường thử nghiệm bằng hai tài khoản với vai trò người bán và người mua. Các chức năng được kiểm tra gồm nhắn tin, trả giá, giao dịch COD, đăng tin, quản lý tài khoản và thông báo. Tài khoản tạm phục vụ kiểm thử xóa tài khoản được xóa sau mỗi lượt thực hiện.

Đối với website, các trang được kiểm tra ở kích thước màn hình máy tính và điện thoại, trong cả hai trạng thái chưa đăng nhập và đã đăng nhập. Việc kiểm tra tập trung vào lỗi hiển thị và lỗi khi gọi dịch vụ nền.

== Các kịch bản nghiệp vụ trọng tâm

@tab-test-shipping-recovery và @tab-test-login-concurrency đặc tả hai tình huống cần kiểm soát chặt chẽ: khôi phục quy trình tạo đơn sau sự cố và xử lý đồng thời nhiều yêu cầu xác thực. Các kịch bản còn lại được tổng hợp tại @tab-test-business-scenarios. Nội dung trong các bảng là điều kiện thực hiện và kết quả mong đợi, không phải bảng thống kê số ca đã đạt hoặc chưa đạt.

#tcspec(
  "TC-01", "Khôi phục quy trình tạo đơn gửi hàng sau sự cố",
  [Mục tiêu], [Kiểm tra quy trình tạo đơn có thể tiếp tục sau sự cố mà không tạo trùng vận đơn hoặc gây sai lệch trạng thái giữa tin đăng, đơn COD và phiên trả giá.],
  [Truy vết], [UC-DEAL-04, BR-DEAL-04; FR-DEAL-03; NFR-DUR-01, NFR-IDEM-01.],
  [Tiền điều kiện], [Người mua A đã chốt giá và gửi yêu cầu COD; người mua B cũng có yêu cầu COD trên cùng tin. Tin đang bán. Người bán đã liên kết tài khoản với hãng vận chuyển giả lập; dịch vụ giả lập có ghi nhận số vận đơn được tạo.],
  [Các bước], [
    #enum(
      [Cấu hình tiêm lỗi một lần ngay sau khi bước lưu đơn hoàn tất ghi dữ liệu.],
      [Người bán thực hiện thao tác tạo đơn cho người mua A.],
      [Cho quy trình thực thi lại sau lỗi; ứng dụng của người bán gửi lại cùng yêu cầu tạo đơn.],
      [Kiểm tra số vận đơn tại dịch vụ giả lập, trạng thái đơn, tin đăng, phiên trả giá và yêu cầu COD của người mua B.],
    )
  ],
  [Kết quả mong đợi], [Chỉ tạo một vận đơn. Đơn của A chuyển sang trạng thái đã gửi với phí vận chuyển do hãng trả về; tin chuyển sang đang giữ chỗ. Yêu cầu của B bị hủy với lý do “đã gửi cho người khác”. Yêu cầu gửi lại nhận kết quả của lần xử lý đầu tiên; mỗi bên chỉ nhận một thông báo tương ứng.],
) <tab-test-shipping-recovery>

#tcspec(
  "TC-02", "Kiểm soát 50 yêu cầu xác thực mã OTP đồng thời",
  [Mục tiêu], [Kiểm tra giới hạn số lần nhập sai vẫn được bảo đảm khi nhiều yêu cầu đến đồng thời; phản hồi của các yêu cầu xung đột không tiết lộ mã vừa nhập là đúng hay sai.],
  [Truy vết], [UC-ACC-01, BR-ACC-02; FR-ACC-01; NFR-CONC-01, NFR-SEC-01.],
  [Tiền điều kiện], [Một mã OTP qua email còn hiệu lực; mã đúng được lấy từ hộp thư giả lập.],
  [Các bước], [
    #enum(
      [Gửi đồng thời 50 yêu cầu xác thực, trong đó chỉ một yêu cầu chứa mã đúng.],
      [Ghi nhận phản hồi của từng yêu cầu.],
      [Kiểm tra trạng thái cuối cùng và số lần thử đã ghi nhận của mã OTP.],
    )
  ],
  [Kết quả mong đợi], [Số lần thử được ghi nhận không vượt giới hạn. Mã kết thúc ở một trong hai trạng thái hết lượt hoặc đã sử dụng, không đồng thời mang cả hai trạng thái. Nếu đã hết lượt trước khi yêu cầu chứa mã đúng được xử lý, yêu cầu này cũng bị từ chối. Các yêu cầu gặp xung đột xử lý nhận cùng thông báo “thử lại”, không tiết lộ tính đúng sai của mã.],
) <tab-test-login-concurrency>

#figure(
  kind: table,
  caption: [Các kịch bản nghiệp vụ từ TC-03 đến TC-16],
  table(
    columns: (0.55fr, 2.8fr, 1.15fr),
    inset: (x: 6pt, y: 4pt),
    align: left + top,
    table.header([Mã], [Tình huống và kết quả mong đợi], [Truy vết]),
    [TC-03], [Ứng dụng gửi lại yêu cầu COD do gián đoạn kết nối. Hệ thống chỉ tạo một đơn và trả về kết quả của lần xử lý đầu tiên.], [UC-DEAL-03, NFR-IDEM-01],
    [TC-04], [Hãng gửi trạng thái “đã giao” hai lần, sau đó gửi trạng thái “đã lấy hàng” đến muộn. Đơn không được cập nhật trùng hoặc chuyển về trạng thái trước đó.], [UC-DEAL-05, FR-DEAL-04, NFR-IDEM-01],
    [TC-05], [Người mua chấp nhận giá đồng thời với lúc người bán phản giá. Chỉ một thao tác được chấp nhận; thao tác còn lại nhận thông báo phiên trả giá đã thay đổi.], [UC-DEAL-02, NFR-CONC-01],
    [TC-06], [Người mua gửi đồng thời 5 yêu cầu COD trên 5 tin. Hệ thống chấp nhận đúng 3 yêu cầu và từ chối 2 yêu cầu vượt hạn mức.], [BR-DEAL-06, NFR-CONC-01],
    [TC-07], [Người bán không tạo đơn gửi hàng trong 3 ngày. Đơn tự động hủy; tin vẫn ở trạng thái đang bán.], [UC-DEAL-06, BR-DEAL-07],
    [TC-08], [Hãng không lấy hàng trong 3 ngày kể từ khi đơn chuyển sang đã gửi. Đơn và vận đơn bị hủy; tin được mở bán lại.], [UC-DEAL-06, BR-DEAL-07],
    [TC-09], [Hãng báo đã giao nhưng người mua chưa xác nhận nhận hàng. Sau 3 ngày, đơn tự động hoàn tất và tin chuyển sang đã bán.], [UC-DEAL-05, BR-DEAL-11],
    [TC-10], [Người mua từ chối nhận hàng khi đồng kiểm. Đơn chuyển sang giao không thành, tin được mở bán lại và số đơn giao không thành của người mua tăng một.], [UC-DEAL-05, UC-TRS-04, BR-DEAL-08],
    [TC-11], [Người bán nhập mã vận đơn không thuộc tài khoản hãng đã liên kết. Hệ thống từ chối mã; trạng thái đơn không thay đổi.], [UC-DEAL-04, BR-DEAL-12],
    [TC-12], [Cuộc trò chuyện có tin nhắn yêu cầu đặt cọc và chuyển sang Zalo. Hệ thống hiển thị cảnh báo. Sau khi người dùng tắt cảnh báo, tin nhắn mới yêu cầu cung cấp OTP làm cảnh báo xuất hiện lại.], [UC-DEAL-01, FR-TRS-04, BR-TRS-06],
    [TC-13], [Người bán đánh giá trước. Đánh giá được ẩn với người mua cho đến khi người mua đánh giá hoặc hết 7 ngày; sau khi có phản hồi, đánh giá không thể chỉnh sửa.], [UC-TRS-01, BR-TRS-04],
    [TC-14], [Mô hình diễn giải câu tìm kiếm phản hồi quá 4 giây. Hệ thống trả kết quả theo câu gốc, không kèm điều kiện lọc do AI đề xuất.], [UC-DSC-01, FR-DSC-01, NFR-PERF-01],
    [TC-15], [Người dùng chặn một người bán. Tin đăng giữa hai bên không còn xuất hiện trong kết quả tìm kiếm, trang chủ và mục Gần bạn.], [UC-DSC-01, UC-ACC-05, BR-ACC-01],
    [TC-16], [Người bán tải ảnh chứa tọa độ và thông tin thiết bị chụp. Các thông tin này được loại bỏ khỏi ảnh hiển thị trên tin đăng.], [UC-LST-01, FR-SHR-01, NFR-PRIV-01],
  ),
) <tab-test-business-scenarios>

== Đối chiếu yêu cầu phi chức năng

@tab-test-nfr-verification tổng hợp cách kiểm chứng các yêu cầu phi chức năng ở Chương 3. Mỗi yêu cầu được gắn với thao tác kiểm tra hoặc ca kiểm thử liên quan để làm căn cứ đánh giá.

#figure(
  kind: table,
  caption: [Phương pháp kiểm chứng yêu cầu phi chức năng],
  table(
    columns: (1.1fr, 4fr),
    inset: (x: 6pt, y: 4pt),
    align: left + top,
    table.header([Mã yêu cầu], [Cách kiểm chứng]),
    [NFR-DUR-01], [Tiêm lỗi sau bước ghi dữ liệu trong các quy trình đăng nhập, gửi mã, đăng tin, gửi hàng và xử lý thời hạn đơn. Kiểm tra quy trình tiếp tục thực thi mà không gửi trùng email hoặc tạo trùng vận đơn (TC-01).],
    [NFR-IDEM-01], [Gửi lại các yêu cầu ghi quan trọng; cho hãng giả lập gửi cập nhật trạng thái trùng lặp và sai thứ tự. Kiểm tra tác động nghiệp vụ không bị lặp (TC-03, TC-04).],
    [NFR-CONC-01], [Thực hiện đồng thời nhiều yêu cầu xác thực, cập nhật phiên trả giá, tạo đơn COD và đăng tin. Kiểm tra tính nhất quán và các hạn mức tương ứng (TC-02, TC-05, TC-06).],
    [NFR-MSG-01], [Tạm dừng dịch vụ điều phối khi phát sinh thay đổi nghiệp vụ. Kiểm tra dữ liệu vẫn được lưu, sự kiện được giữ lại và chuyển tiếp sau khi dịch vụ hoạt động trở lại; người dùng vẫn truy vấn được dữ liệu và duy trì phiên đăng nhập.],
    [NFR-PERF-01], [Đo thời gian phản hồi trên bộ dữ liệu thử nghiệm; kiểm tra cơ chế tìm bằng câu gốc khi mô hình vượt thời gian chờ (TC-14).],
    [NFR-SEC-01], [Thử sử dụng lại mã làm mới phiên, gửi mã vượt hạn mức và so sánh phản hồi giữa email đã có tài khoản với email chưa có tài khoản; kiểm tra giới hạn xác thực đồng thời (TC-02).],
    [NFR-PRIV-01], [Kiểm tra ảnh đã loại bỏ tọa độ (TC-16), vị trí tin đăng chỉ lưu ở mức cho phép, nhật ký không chứa số điện thoại hoặc email và khóa kết nối hãng không xuất hiện trong phản hồi hay nhật ký.],
    [NFR-OBS-01], [Đối chiếu lỗi người dùng nhận được với yêu cầu tương ứng trên hệ thống quan trắc để xác định khả năng truy vết.],
    [NFR-PERF-02], [Kiểm tra lượt hỏi trợ lý AI được dừng khi vượt 60 giây và có thể chuyển sang xử lý nền.],
    [NFR-PRIV-02], [Kiểm tra nhật ký truy cập dữ liệu cá nhân của trợ lý AI có ghi nhận nhân viên yêu cầu; khi xóa tài khoản, phần trích dữ liệu của tài khoản đó trong cuộc trò chuyện với trợ lý AI cũng được xóa.],
    [NFR-API-01], [Đối chiếu phản hồi của kiểm thử đầu cuối với đặc tả API; kiểm tra mỗi trường hợp phản hồi được khai báo đều xuất hiện ít nhất một lần.],
    [NFR-ARCH-01], [Sử dụng kiểm tra tự động để phát hiện và ngăn lời gọi vượt qua giao diện công bố của phân hệ.],
    [NFR-UX-01], [Kiểm tra ứng dụng trên phiên bản Android tối thiểu theo yêu cầu, với giao diện tối và cỡ chữ lớn; kiểm tra website ở kích thước màn hình điện thoại.],
  ),
) <tab-test-nfr-verification>

== Đánh giá chất lượng tìm kiếm

=== Bộ dữ liệu và độ đo

Thực nghiệm sử dụng bộ mẫu gồm 42 tin đăng có ảnh và 46 truy vấn được gán trước các tin liên quan, bao gồm 30 truy vấn văn bản, 10 truy vấn bằng ảnh và 6 lượt tìm tin tương tự. Các mô hình sử dụng trong thực nghiệm gồm mô hình diễn giải câu tìm kiếm, BGE-M3 cho văn bản và SigLIP 2 cho ảnh.

Chất lượng tìm kiếm được đánh giá bằng hai độ đo:

+ *Recall\@10:* tỉ lệ tin liên quan được tìm thấy trong 10 kết quả đầu.
+ *nDCG\@10:* mức độ phù hợp của thứ hạng trong 10 kết quả đầu, ưu tiên việc đưa tin liên quan lên các vị trí cao.

=== Kết quả thực nghiệm

@tab-test-search-quality trình bày kết quả với bộ trọng số ban đầu của hệ thống.

#figure(
  kind: table,
  caption: [Kết quả đánh giá tìm kiếm trên bộ mẫu 46 truy vấn],
  table(
    columns: (1.6fr, 0.8fr, 0.9fr, 0.9fr),
    inset: (x: 6pt, y: 4pt),
    align: (left, center, center, center),
    table.header([Loại truy vấn], [Số lượng], [Recall\@10], [nDCG\@10]),
    [Văn bản], [30], [1,000], [0,946],
    [Ảnh], [10], [1,000], [1,000],
    [Tin tương tự], [6], [1,000], [1,000],
    [Toàn bộ], [46], [1,000], [0,965],
  ),
) <tab-test-search-quality>

Trên bộ mẫu, Recall\@10 đạt 1,000 ở cả ba nhóm truy vấn. Nhóm truy vấn văn bản có nDCG\@10 đạt 0,946, cho thấy vẫn có trường hợp tin liên quan chưa được xếp ở vị trí cao nhất. Giá trị nDCG\@10 tổng hợp đạt 0,965.

Chức năng gợi ý danh mục khi đăng tin được đánh giá riêng trên 86 tin thuộc bộ mẫu và bộ dữ liệu trình diễn. Trong 77 tin không thuộc nhóm Khác, hệ thống xác định đúng danh mục con của 71 tin khi sử dụng cả tiêu đề và mô tả, và 69 tin khi chỉ sử dụng tiêu đề.

=== Nhận xét và hạn chế

Quy mô bộ mẫu còn nhỏ nên Recall\@10 dễ đạt giá trị tối đa. Hai độ đo đang sử dụng cũng chưa phản ánh đầy đủ các tin không liên quan xuất hiện sau những tin phù hợp. Chẳng hạn, truy vấn bằng ảnh một đôi giày trắng vẫn trả về tai nghe và máy giặt ở cuối danh sách. Vì vậy, kết quả trên chỉ phản ánh chất lượng trong phạm vi bộ mẫu, chưa đủ cơ sở để khái quát cho dữ liệu thực tế có quy mô lớn.

Hướng cải thiện gồm bổ sung độ đo độ chính xác, điều chỉnh ngưỡng tương đồng tối thiểu cho tìm kiếm ngữ nghĩa và ảnh, đồng thời mở rộng bộ truy vấn sang các trường hợp nhiều điều kiện, có phủ định và có yêu cầu về vị trí.

Đối với bước diễn giải bằng AI, hệ thống giữ câu truy vấn gốc làm một cụm từ tìm kiếm và sử dụng kết quả diễn giải để bổ sung điều kiện ưu tiên. Khi mô hình lỗi hoặc vượt thời gian chờ 4 giây, hệ thống tìm bằng câu gốc. Nếu một điều kiện được diễn giải chưa phù hợp, người dùng có thể tắt điều kiện đó trên giao diện và tìm lại mà không gọi lại mô hình. Các cơ chế này hỗ trợ duy trì khả năng tìm kiếm khi AI gặp lỗi; hiệu quả xếp hạng vẫn cần được kiểm chứng trên bộ dữ liệu rộng hơn.
