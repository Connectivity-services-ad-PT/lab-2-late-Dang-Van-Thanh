# Phân tích yêu cầu — vai Consumer

- Cặp đàm phán: Pair 10 (Access Gate -> Core Business)
- Product: A
- Consumer service: Access Gate
- Provider service: Core Business
- Người viết: Đặng Văn Thanh, Lương Duy Chiến, Đặng Thành Đạt
- Ngày: 13/05/2026

---

## 1. Resource Consumer cần nhận/gửi

| Resource | Consumer dùng để làm gì? | Field bắt buộc với Consumer | Field có thể tùy chọn |
|---|---|---|---|
| `AccessCheckRequest` | Gửi thông tin quẹt thẻ thô lên hệ thống trung tâm để xin lệnh điều khiển đóng/mở | `cardId` (string), `gateId` (UUID), `timestamp` (date-time) | `idempotencyKey` (UUID) |
| `PolicyDecision` | Nhận kết quả phán quyết từ Core Business để thực thi điều khiển rơ-le vật lý | `status` (Enum: ALLOW, DENY), `reasonCode` (string), `policyId` (UUID), `expiresAt` (date-time) | `message` (string) |

---

## 2. API Consumer cần gọi

| Method | Path | Lúc nào gọi? | Kỳ vọng response |
|---|---|---|---|
| POST | `/access/check` | Ngay khi có hành động quẹt thẻ/quét mã tại đầu đọc vật lý của cổng | Status `200 OK` chứa đối tượng `PolicyDecision` với tốc độ phản hồi cực nhanh (<200ms) |

---

## 3. Error case Consumer cần xử lý

Tối thiểu 5 case.

| Status | Consumer hiểu là gì? | Consumer sẽ xử lý thế nào? |
|---:|---|---|
| 400 | Payload request sai định dạng, cấu trúc JSON hoặc Regex của `cardId` bị hỏng | Không mở cổng, phát tín hiệu âm thanh cảnh báo ngắn (3 bíp), ghi nhận log lỗi hệ thống |
| 401 | Đăng nhập hệ thống lỗi, API Key/Token của Access Gate gửi lên Core Business hết hạn | Từ chối xử lý, chuyển sang trạng thái Lock toàn bộ gate và báo về trung tâm điều hành qua luồng giám sát |
| 403 | Cổng vật lý này (`gateId`) bị cấu hình sai hoặc đang bị khóa quyền kết nối trên Core | Giữ nguyên trạng thái khóa cửa, hiển thị thông báo "Thiết bị chưa kích hoạt" trên màn hình LED |
| 404 | Mã `cardId` hoặc mã `policyId` không tồn tại trên dữ liệu đám mây | Phát loa cảnh báo "Thẻ không hợp lệ", hiển thị đèn LED đỏ và giữ trạng thái đóng cổng |
| 422 | Thẻ đúng định dạng, nhận dạng được sinh viên nhưng vi phạm quy định (Ví dụ: Thẻ bị khóa do chưa đóng học phí) | Giữ đóng cổng, đọc mã `reasonCode` nhận được để hiển thị thông báo lý do cụ thể lên màn hình điều khiển tại gate |

---

## 4. Giả định bổ sung

- Giả định 1: Giá trị `expiresAt` trả về trong kịch bản `ALLOW` sẽ được Access Gate dùng để tối ưu việc mở giữ cổng trong một khoảng thời gian ngắn cố định (Ví dụ: 5 giây).
- Giả định 2: Để tránh kẹt cổng xoay vật lý, thời gian quy định kết nối timeout (Network SLA timeout) tối đa của endpoint `/access/check` được giới hạn nghiêm ngặt ở mức 300ms.
- Giả định 3: Phía Core Business chịu trách nhiệm đảm bảo tính toàn vẹn dữ liệu và phân tách logic của các `policyId` khác nhau.

---

## 5. Câu hỏi cho Provider

1. Nếu chúng tôi gửi kèm `idempotencyKey` trong trường hợp sinh viên bấm quẹt thẻ liên tục (Double tap), các bạn sẽ trả về kết quả cũ trong bộ nhớ đệm (Cache response) hay tính toán lại từ đầu?
2. Trong tình huống hệ thống của các bạn bị lỗi `500` hoặc xảy ra sự cố mất kết nối mạng (Timeout), chúng tôi nên áp dụng cơ chế Fail-open (Mở tự do để thoát hiểm) hay Fail-closed (Khóa chặt bảo an)?
3. Bộ danh sách các mã `reasonCode` (Ví dụ: `CARD_EXPIRED`, `BLACKLISTED`, `WRONG_ZONE`) gồm những mã nào để chúng tôi lập trình sẵn UI tương ứng trên màn hình LCD của cổng?

---

## 6. Rủi ro tích hợp

| Rủi ro | Tác động | Đề xuất xử lý |
|---|---|---|
| Thời gian phản hồi của API `/access/check` vượt quá 500ms do nghẽn DB ở Core | Gây ùn tắc nghiêm trọng tại các cổng ra vào Campus vào giờ cao điểm đi học/đi làm | Thiết lập cơ chế Circuit Breaker tại biên; nếu quá thời gian timeout tự động ngắt và chuyển sang check Local Whitelist tạm thời. |
| Thay đổi cấu trúc Enum của trường dữ liệu phán quyết (Ví dụ: Đổi từ `ALLOW` sang `PERMITTED`) | Access Gate không parse được dữ liệu, thiết bị biên bị crash hoặc không thể kích hoạt rơ-le mở cổng | Khóa chặt schema định nghĩa Enum trong tệp tin hợp đồng `openapi.yaml` của Lab 02. |
