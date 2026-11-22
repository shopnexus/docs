#import "../../../common/tokens.typ": *
#import "../../../common/info.typ" as info

= GIỚI THIỆU ĐỀ TÀI

== Lý do chọn đề tài

Hiện nay mua bán hàng đã qua sử dụng giúp kéo dài vòng đời sản phẩm, hạn chế lãng phí và tạo điều kiện để người mua tiếp cận hàng hóa với chi phí phù hợp. Đối với người bán, đây là cách tận dụng giá trị còn lại của những vật dụng không còn nhu cầu sử dụng. Tuy nhiên, giao dịch hàng cũ giữa các cá nhân có những đặc thù khác với hoạt động bán lẻ thông thường. Mỗi sản phẩm có thể khác nhau về mức độ sử dụng, phụ kiện, lịch sử sửa chữa và tình trạng thực tế, ngay cả khi cùng tên gọi hoặc mẫu mã. Vì vậy, người mua cần nhiều thông tin hơn để so sánh và lựa chọn, còn người bán cần phương thức để người mua tiếp cận sản phẩm rõ ràng, thuận tiện.

Khi việc mua bán diễn ra qua các bài đăng và tin nhắn rời rạc, thông tin về sản phẩm, mức giá đã thỏa thuận và tiến độ giao nhận khó được theo dõi đồng nhất. Người mua sẽ phải liên hệ nhiều người bán để làm rõ thông tin; người bán cũng khó quản lý khi nhiều người cùng quan tâm đến một món hàng. Việc tổ chức các bước đăng tin, tìm kiếm, trao đổi, thương lượng và đặt hàng trong một hệ thống chung có thể giúp các bên theo dõi giao dịch thuận tiện hơn. Đồng thời, lịch sử trao đổi, trạng thái đơn hàng và đánh giá sau giao dịch cung cấp thêm cơ sở tham khảo cho những lần mua bán tiếp theo.

Khi xử lý yêu cầu hỗ trợ hoặc báo cáo vi phạm, nhân sự quản lý cần đối chiếu thông tin tài khoản, tin đăng, đơn hàng và lịch sử trao đổi. Việc tra cứu thủ công có thể tốn thời gian và bỏ sót chi tiết. AI agent có thể hỗ trợ truy xuất, tổng hợp thông tin và đề xuất hướng xử lý kèm dẫn chứng đến các bản ghi liên quan. Agent chỉ khai thác dữ liệu trong phạm vi quyền truy cập được cho phép; việc kiểm tra đề xuất và thực hiện thao tác quản lý vẫn do nhân sự phụ trách quyết định.

Từ những vấn đề trên, nhóm lựa chọn đề tài “#info.de-tai”, với hệ thống mang tên ShopNexus. Kết hợp nghiên cứu kiến trúc phần mềm và ứng dụng AI agent, đề tài hướng đến nền tảng mua bán hàng đã qua sử dụng giúp người dùng tiếp cận thông tin rõ ràng, theo dõi giao dịch thuận tiện và hỗ trợ nhân sự quản lý xử lý yêu cầu hiệu quả hơn.


== Mục tiêu của đề tài

Mục tiêu tổng quát của đề tài là xây dựng hệ thống hỗ trợ giao dịch hàng đã qua sử dụng giữa các cá nhân, đồng thời nghiên cứu cách tổ chức hệ thống theo định hướng kiến trúc microservice, tích hợp AI agent hỗ trợ tìm kiếm bằng ngôn ngữ tự nhiên cho người dùng và hỗ trợ nhân sự quản lý. Hệ thống hướng đến việc liên kết các bước từ đăng tin đến theo dõi giao nhận trong một quy trình thống nhất, giúp người dùng tìm kiếm, trao đổi và quản lý giao dịch thuận tiện hơn.

Trên cơ sở đó, đề tài xác định các mục tiêu cụ thể như sau:

- Phân tích và đặc tả yêu cầu: Xác định nhu cầu của người mua, người bán và nhân sự quản lý; mô tả các ca sử dụng, quy tắc nghiệp vụ và yêu cầu phi chức năng. Làm rõ quan hệ giữa tin đăng, thương lượng, đơn hàng và vận chuyển để bảo đảm các chức năng được xây dựng trên cùng một mô hình nghiệp vụ.

- Thiết kế kiến trúc và dữ liệu: Phân rã hệ thống thành các dịch vụ, xác định quyền quản lý dữ liệu của từng thành phần và thiết kế giao diện giao tiếp giữa các dịch vụ. Nghiên cứu cơ chế phối hợp các bước xử lý, kiểm soát thao tác đồng thời, xử lý yêu cầu trùng lặp và phục hồi khi tích hợp gặp lỗi.

- Xây dựng các chức năng giao dịch cốt lõi: Phát triển chức năng quản lý tài khoản, đăng tin và quản lý tin bán, xử lý hình ảnh, tìm kiếm, trò chuyện, thương lượng giá và tạo đơn hàng. Các thay đổi quan trọng cần được thể hiện bằng trạng thái và lịch sử phù hợp để người dùng có thể theo dõi.

- Tích hợp vận chuyển: Nghiên cứu kết nối với đơn vị vận chuyển để hỗ trợ liên kết tài khoản người bán, tra cứu phí, tạo hoặc hủy vận đơn và cập nhật tiến độ giao nhận. Việc tích hợp được triển khai dựa trên tài liệu API, quyền truy cập được cấp và môi trường thử nghiệm sẵn có.

- Ứng dụng AI agent: Hỗ trợ người dùng tìm kiếm sản phẩm bằng ngôn ngữ tự nhiên; hỗ trợ nhân sự quản lý truy xuất, tổng hợp thông tin, tóm tắt vụ việc và đề xuất hướng xử lý có dẫn chiếu dữ liệu. Agent hoạt động trong phạm vi quyền truy cập được cấp; người dùng quyết định lựa chọn sản phẩm, còn nhân sự quản lý kiểm tra đề xuất và thực hiện các thao tác xử lý.

- Hỗ trợ đánh giá và quản lý hoạt động: Xây dựng chức năng ghi nhận đánh giá, phản ánh và lịch sử giao dịch; tổng hợp thông tin phục vụ tham khảo uy tín và kiểm soát hành vi theo các quy tắc nghiệp vụ. Cung cấp chức năng quản lý tài khoản, nội dung và tiếp nhận yêu cầu hỗ trợ theo phân quyền.

- Kiểm thử và đánh giá hệ thống: Kiểm thử các chức năng và luồng nghiệp vụ, đánh giá mức độ đáp ứng yêu cầu và tính nhất quán trong quá trình xử lý. Ghi nhận kết quả, xác định hạn chế và đề xuất hướng hoàn thiện.

Kết quả kỳ vọng là một hệ thống thử nghiệm có tính thực tiễn, gồm ứng dụng mua bán hàng đã qua sử dụng, giao diện quản lý và AI agent hỗ trợ người dùng. Đề tài phục vụ việc học tập, nghiên cứu kiến trúc phần mềm và ứng dụng AI agent trong thương mại điện tử, đồng thời có thể làm tài liệu tham khảo cho các dự án tương tự trong tương lai.

== Đối tượng và phạm vi đề tài
Đề tài nghiên cứu và xây dựng hệ thống sàn giao dịch thương mại điện tử mặt hàng đã qua sử dụng giữa các cá nhân (C2C), hỗ trợ xuyên suốt từ đăng tin, tìm kiếm, trao đổi đến đặt hàng và theo dõi giao nhận đồng thời tích hợp AI Agent hỗ trợ người dùng trong quá trình sử dụng hệ thống.

Đối tượng sử dụng gồm người mua và người bán có nhu cầu giao dịch hàng đã qua sử dụng. Một tài khoản có thể tham gia cả hai vai trò tùy vào nhu cầu sử dụng của từng người.
#pagebreak()
Đề tài hướng đến việc kết hợp tìm kiếm từ khóa (Lexical Search) kết hợp tìm kiếm ngữ nghĩa (Semantic Search) và AI agent để hiểu nhu cầu của người dùng về công dụng, tình trạng, mức giá và khu vực. Nhờ đó, người mua tìm được các tin đăng phù hợp cho bản thân. Về kiến trúc, hệ thống được tổ chức theo hướng microservice, tập trung vào phân tách trách nhiệm giữa các dịch vụ, quản lý trạng thái giao dịch và tích hợp dịch vụ bên ngoài.

Về phạm vi, đề tài giới hạn ở quy mô thử nghiệm, chưa triển khai và vận hành thương mại. Các chức năng cốt lõi của sàn gồm quản lý tài khoản, đăng tin, tìm kiếm, trò chuyện, đặt hàng, giao hàng thu tiền hộ có đồng kiểm, đánh giá uy tín, và được xây dựng ở mức đủ để kiểm chứng qua các kịch bản sử dụng, nghiên cứu tập trung vào tích hợp AI Agent để phục vụ cho người sử dụng và nhân sự vận hành.



== Phương pháp nghiên cứu

Nhóm kết hợp nghiên cứu tài liệu, phân tích nghiệp vụ, mô hình hóa, xây dựng thực nghiệm và kiểm thử. Các phương pháp được tổ chức theo trình tự từ xác định yêu cầu đến lựa chọn giải pháp, hiện thực và đánh giá; kết quả của mỗi bước được dùng để rà soát và điều chỉnh bước tiếp theo.

- Nghiên cứu tài liệu và tham khảo hệ thống tương tự: Tìm hiểu các tài liệu liên quan, thiết kế hệ thống dữ liệu, xử lý quy trình nhiều bước, tìm kiếm thông tin và AI agent. Tham khảo cách tổ chức tin đăng, trao đổi và đặt hàng trên các nền tảng mua bán trực tuyến để nhận diện những đặc điểm phù hợp với giao dịch hàng đã qua sử dụng. Tài liệu chính thức của các công nghệ sử dụng và đơn vị bên thứ 3 được tích hợp vào hệ thống, dùng làm cơ sở xác định khả năng tích hợp, các ràng buộc và điều kiện sử dụng.

- Phân tích yêu cầu và mô hình hóa nghiệp vụ: Xác định tác nhân, mục đích sử dụng, luồng xử lý chính và các trường hợp ngoại lệ. Yêu cầu được mô tả bằng ca sử dụng, quy tắc nghiệp vụ và các mô hình UML phù hợp. Đối với tin đăng, thương lượng và đơn hàng, cần làm rõ điều kiện thực hiện thao tác và các chuyển trạng thái hợp lệ. Cách tiếp cận này giúp phát hiện sớm những điểm thiếu nhất quán giữa yêu cầu, thiết kế dữ liệu và giao diện.

- Thiết kế và xây dựng thực nghiệm: Phân chia rã hệ thống theo nghiệp vụ, xây dựng hợp đồng API và hiện thực từng luồng chức năng. Các thành phần được tích hợp theo từng bước để thuận tiện kiểm tra và xác định nguyên nhân khi xảy ra lỗi. Với thao tác có tác động đến nhiều thành phần hoặc dịch vụ bên ngoài, việc thiết kế chú trọng tính nhất quán, khả năng chịu lỗi và phục hồi.

- Thực nghiệm tìm kiếm và AI Agent: Xây dựng tập truy vấn gồm nhu cầu tìm theo tên sản phẩm, thông số và mô tả bằng ngôn ngữ tự nhiên. Đối chiếu kết quả của tìm kiếm từ khóa, tìm kiếm ngữ nghĩa và phương án kết hợp trên cùng dữ liệu thử nghiệm. Nội dung đánh giá bao gồm mức độ liên quan, thứ tự kết quả, khả năng đáp ứng điều kiện lọc và thời gian phản hồi. Với phần hỗ trợ bằng AI, việc kiểm tra tập trung vào khả năng hiểu đúng yêu cầu, giữ đúng điều kiện tìm kiếm, bám sát dữ liệu truy xuất và xử lý khi mô hình không phản hồi hoặc trả về nội dung không hợp lệ.

- Kiểm thử và đánh giá: Các ca kiểm thử được xây dựng từ yêu cầu chức năng và quy tắc nghiệp vụ, thực hiện ở ba mức: kiểm thử đơn vị, kiểm thử tích hợp và kiểm thử theo kịch bản sử dụng. Ngoài luồng thành công, hệ thống được kiểm tra với các tình huống bất thường gồm dữ liệu không hợp lệ, thao tác không đủ quyền, yêu cầu trùng lặp, thao tác đồng thời và lỗi kết nối giữa các dịch vụ. Với dịch vụ của bên thứ ba, các ca kiểm thử tập trung vào trường hợp cập nhật trạng thái được gửi nhiều lần hoặc không đúng thứ tự. Mỗi ca kiểm thử được ghi nhận gồm dữ liệu đầu vào, điều kiện thực hiện, kết quả mong đợi và kết quả thực tế để thuận tiện đối chiếu.

