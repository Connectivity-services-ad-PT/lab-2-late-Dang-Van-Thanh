# Biên bản đàm phán hợp đồng API

- Cặp đàm phán: Pair 03, Pair 09, Pair 10 
- Product: A
- Provider: Access Gate, Core Business
- Consumer: Core Business, Access Gate, Analytics
- Phiên: v1.0
- Ngày: 13/05/2026

---

## Issue #1: Cơ chế Phân trang cho Endpoint `/access/logs/recent` (Pair 03)

- Raised by: Consumer (Core Business)
- Endpoint: `GET /access/logs/recent`
- Concern: Lượng sinh viên quẹt thẻ ra vào Campus hàng ngày là cực kỳ lớn. Nếu dùng phân trang truyền thống bằng Offset (`page`/`limit`), hệ thống sẽ bị chậm (vấn đề Performance) ở các trang phía sau và có nguy cơ bỏ sót hoặc lặp log nếu có bản ghi mới chèn vào liên tục.
- Proposal: Áp dụng cơ chế phân trang dựa trên con trỏ (Cursor-based pagination) bằng một chuỗi mã hóa an toàn.
- Resolution: Accepted. Hai bên thống nhất sử dụng query parameter `cursor` (kiểu chuỗi mã hóa Base64 chứa ID của bản ghi cuối cùng và mốc thời gian) và tham số giới hạn `limit` (tối đa 100 bản ghi/request). Response trả về bắt buộc bao gồm mảng `data` và trường `nextCursor`.
- Rationale: Cursor-based pagination giúp tối ưu hóa truy vấn cơ sở dữ liệu ở biên (Edge), tốc độ phản hồi ổn định $O(1)$ bất kể độ sâu của trang dữ liệu, đồng thời tránh trùng lặp bản ghi khi kéo stream log liên tục.
- Impact: Phía Access Gate phải cấu hình logic sinh con trỏ Base64 từ bản ghi cuối cùng. Core Business phải lưu lại `nextCursor` nhận được từ request trước để truyền vào query param cho request kế tiếp.

---

## Issue #2: Cấu trúc Dữ liệu Định danh Thẻ và Ràng buộc Định dạng (Pair 03 & 10)

- Raised by: Provider (Access Gate)
- Endpoint: `GET /cards/{cardId}`, `POST /access/check`, `GET /access/logs/recent`
- Concern: Thiết bị phần cứng (Đầu đọc RFID, máy quét QR) thu thập dữ liệu thẻ dưới dạng chuỗi ký tự Alphanumeric hoặc mã Hex (ví dụ: RFID88776655). Nếu hệ thống Core Business thiết kế trường này dạng số nguyên tự tăng (Integer ID) hoặc chuỗi tự do không kiểm soát sẽ gây lỗi phân rã dữ liệu (Parse error) tại biên.
- Proposal: Thống nhất kiểu dữ liệu của `cardId` là `string` cố định kèm theo định nghĩa biểu thức chính quy (Regex Pattern) nghiêm ngặt trong JSON Schema.
- Resolution: Accepted. Trường `cardId` được chốt là kiểu chuỗi (`type: string`) với ràng buộc Pattern: `^[A-Z0-9]{8,16}$`.
- Rationale: Giúp sàng lọc dữ liệu lỗi ngay từ tầng API Gateway (bằng Spectral/Prism hoặc Validator) trước khi truyền sâu vào hệ thống Core xử lý, bao quát được nhiều loại thẻ vật lý (Mã QR, chip RFID, Barcode).
- Impact: Cả hai đội phát triển phải cập nhật cấu trúc cơ sở dữ liệu để lưu trữ mã thẻ dưới dạng String trường độ từ 8 đến 16 ký tự viết hoa/số.

---

## Issue #3: Quy định Thời gian Phản hồi (SLA Timeout) và Cơ chế Dự phòng khi Mất kết nối (Pair 10)

- Raised by: Consumer (Access Gate)
- Endpoint: `POST /access/check`
- Concern: Luồng kiểm tra Policy ra vào diễn ra theo thời gian thực (Realtime). Nếu API `/access/check` của Core Business phản hồi chậm hoặc bị mất kết nối mạng lên Cloud, sinh viên sẽ bị kẹt lại tại cổng xoay vật lý, gây ùn tắc nghiêm trọng tại sảnh Campus vào giờ cao điểm.
- Proposal: Đặt ngưỡng Timeout kết nối cực ngắn và thống nhất kịch bản dự phòng ngoại tuyến (Offline Fallback Scenario).
- Resolution: Modified. Thời gian timeout tối đa của request được giới hạn nghiêm ngặt ở mức 300ms. Khi gặp lỗi kết nối (Timeout) hoặc Core Business trả về mã lỗi `5xx`, Access Gate tự động chuyển sang cơ chế **Fail-Closed** đối với khu vực bảo mật cao (Phòng Server, Phòng thi), nhưng áp dụng **Fail-Open kết hợp Local Whitelist** (Cho phép mở cổng dựa trên danh sách trắng đồng bộ sẵn tại biên) đối với cổng sảnh chính và ghi nhận cờ `operatorNote: "Offline Fallback Operation"`.
- Rationale: Đảm bảo cân bằng giữa tính an ninh hệ thống và trải nghiệm thông suốt, giảm thiểu rủi ro tắc nghẽn hạ tầng Campus.
- Impact: Access Gate phải lập trình thêm module Circuit Breaker và Local Cache lưu giữ Whitelist tạm thời. Core Business chấp nhận việc log có thể được đồng bộ bù muộn sau khi mạng phục hồi.

---

## Issue #4: Định nghĩa Bộ Mã lỗi Chuẩn hóa cho Quyết định Từ chối Ra vào (Pair 10)

- Raised by: Consumer (Access Gate)
- Endpoint: `POST /access/check`
- Concern: Khi một lượt quẹt thẻ bị từ chối (`status: DENY`), phần cứng của Access Gate cần lý do cụ thể để hiển thị lên màn hình LCD điều khiển tại cổng (ví dụ: thông báo cho sinh viên biết thẻ hết hạn hay đi sai khu vực) thay vì chỉ báo một lỗi từ chối chung chung.
- Proposal: Chuẩn hóa trường `reasonCode` thành một danh mục mã Enum cố định trong Response.
- Resolution: Accepted. Hai bên chốt danh sách bộ mã Enum cho trường `reasonCode` bao gồm: `[VALID_MEMBER, CARD_EXPIRED, SUSPENDED, WRONG_ZONE, UNKNOWN_CARD]`. Đồng thời, cấu trúc dữ liệu trả về bắt buộc bọc theo chuẩn RFC 9457 `application/problem+json` khi xuất hiện lỗi HTTP 4xx/5xx.
- Rationale: Giúp lập trình viên biên dịch UI/UX chính xác mà không cần tự suy diễn chuỗi văn bản (String text), nâng cao tính chuyên nghiệp của hệ thống Smart Campus.
- Impact: Core Business phải phân loại chính xác các rule nghiệp vụ để map đúng mã code trả về. Access Gate lập trình sẵn bộ từ điển map từ mã code sang câu thông báo Tiếng Việt hiển thị trên màn hình cổng xoay.

---

## Issue #5: Chuẩn hóa Tên và Hướng Sự kiện đẩy vào Message Queue (Pair 09 - Async)

- Raised by: Consumer (Analytics)
- Event: `access.log.created`, `access.denied`
- Concern: Phía Analytics cần thu thập dữ liệu stream sự kiện từ Access Gate để tính toán mật độ phòng máy, lưu lượng theo giờ cao điểm. Nếu tên sự kiện đặt lung tung hoặc trường dữ liệu hướng di chuyển không thống nhất sẽ gây gãy luồng xử lý luồng (Stream processing logic).
- Proposal: Thống nhất tên Event theo cấu trúc danh từ.hành động (`access.log.created`, `access.denied`) và trường hướng di chuyển dùng Enum nghiêm ngặt.
- Resolution: Accepted. Tên 2 sự kiện được khóa cứng. Trường biểu diễn hướng di chuyển trong payload bắt buộc đặt tên là `direction` với kiểu Enum `["IN", "OUT"]` (thay vì `ENTER/EXIT` hoặc số `1/2`).
- Rationale: Giúp hệ thống Analytics dễ dàng filter, phân tách dữ liệu luồng vào (IN) và luồng ra (OUT) tức thì bằng các công cụ như Kafka Stream/Flink mà không cần tốn tài nguyên chuẩn hóa dữ liệu thô.
- Impact: Access Gate phải cấu hình phần cứng đầu đọc map đúng cổng vật lý sang chuỗi kí tự `IN` hoặc `OUT` trước khi push vào Broker.

---

## Issue #6: Bảo vệ Dữ liệu Cá nhân và Cơ chế Chống Trùng lặp Message (Cặp 09 - Async)

- Raised by: Provider/Producer (Access Gate)
- Event: Luồng sự kiện Cặp 09 đẩy vào Broker
- Concern: Hệ thống Message Queue (RabbitMQ/Kafka) hoạt động theo cơ chế "At-least-once" nên tin nhắn có thể bị gửi lặp lại khi mạng chập chờn, làm sai lệch biểu đồ thống kê lưu lượng của nhà trường. Đồng thời, việc truyền mã thẻ thô (`cardId`) lên Queue tăng rủi ro rò rỉ dữ liệu riêng tư (Privacy data).
- Proposal: Áp dụng mã hóa băm ẩn danh mã thẻ và bổ sung Idempotency Key bọc ở tầng Metadata của Message.
- Resolution: Accepted. Phía Access Gate sẽ băm mã thẻ bằng thuật toán SHA-256 kèm chuỗi Salt cố định trước khi push, chuyển tên trường thành `hashedCardId`. Đồng thời cấu trúc Message bọc ngoài sẽ bao gồm phần Metadata chứa `eventId` (UUIDv4 đóng vai trò làm Idempotency Key) và `correlationId`.
- Rationale: Đảm bảo Analytics vẫn phân biệt được hành vi di chuyển lặp lại của cùng một đối tượng (nhờ chuỗi hash cố định) mà không cần biết danh tính thật, đồng thời loại bỏ được dữ liệu trùng lặp (Deduplication) dựa trên `eventId`.
- Impact: Analytics phải xây dựng một bộ lọc trùng dữ liệu (Deduplication filter) lưu giữ `eventId` trong cửa sổ thời gian trượt (Sliding window) 5 phút.

---

# Chốt hợp đồng v1.0

Provider sign-off:  Đặng Văn Thanh (Access Gate)
Consumer sign-off:  Nguyễn Văn Hưởng (Core Business)
Consumer sign-off:  Nguyễn Hữu Tuấn Minh (Analytics)
Witness (GV/TA):    
Date:               13/05/2026

---

## Ghi chú warning nếu Spectral còn cảnh báo

| Warning | Lý do chấp nhận tạm thời | Kế hoạch sửa |
|---|---|---|
|  |  |  |
