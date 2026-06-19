# Phân tích yêu cầu — vai Provider

- Cặp đàm phán: Pair 03 (Core Business -> Access Gate)
- Product: A
- Provider service: Access Gate
- Consumer service: Core Business
- Người viết: Đặng Văn Thanh, Lương Duy Chiến, Đặng Thành Đạt
- Ngày: 13/05/2026

---

## 1. Resource chính

| Resource | Mô tả | Thuộc tính bắt buộc | Thuộc tính tùy chọn |
|---|---|---|---|
| `GateStatus` | Trạng thái vận hành vật lý của thiết bị cổng xoay/đầu đọc | `gateId` (UUID), `status` (Enum: ACTIVE, INACTIVE, MAINTENANCE) | `updatedAt` (date-time) |
| `AccessLog` | Nhật ký chi tiết của một lượt quẹt thẻ được lưu giữ tại biên trước khi đồng bộ | `logId` (UUID), `cardId` (string), `gateId` (UUID), `direction` (Enum: IN, OUT), `timestamp` (date-time), `status` (Enum: ALLOWED, DENIED) | `operatorNote` (string), `reasonCode` (string) |

---

## 2. Action/API dự kiến

| Method | Path | Mục đích | Consumer gọi khi nào? |
|---|---|---|---|
| GET | `/access/logs/recent` | Lấy danh sách nhật ký quẹt thẻ mới nhất hỗ trợ Cursor-based pagination | Core Business định kỳ chạy worker để đồng bộ dữ liệu audit log lên Cloud |
| GET | `/gates/{gateId}/status` | Kiểm tra trạng thái kết nối và vận hành của một cổng cụ thể | Khi ban quản lý hệ thống yêu cầu giám sát hoặc kiểm tra thiết bị từ xa |

---

## 3. Error case

Tối thiểu 5 case.

| Status | Tình huống | Response body dự kiến |
|---:|---|---|
| 400 | Query param `cursor` bị hỏng cấu trúc Base64 hoặc `limit` sai kiểu dữ liệu | `{"type": "https://api.smartcampus.dnu/errors/bad-request", "title": "Bad Request", "status": 400, "detail": "Invalid pagination cursor format"}` |
| 401 | Core Business gọi API nhưng token cấu hình bị sai hoặc thiếu header Authorization | `{"type": "https://api.smartcampus.dnu/errors/unauthorized", "title": "Unauthorized", "status": 401, "detail": "Missing or expired bearer token"}` |
| 403 | Token hợp lệ nhưng không được gán quyền `scope: logs:read` | `{"type": "https://api.smartcampus.dnu/errors/forbidden", "title": "Forbidden", "status": 403, "detail": "Insufficient privileges to read gate logs"}` |
| 404 | Truy vấn trạng thái `/gates/{gateId}/status` với ID không nằm trong hệ thống | `{"type": "https://api.smartcampus.dnu/errors/not-found", "title": "Not Found", "status": 404, "detail": "Gate identifier not found"}` |
| 422 | Tham số hợp lệ về cú pháp nhưng `limit` vượt quá giới hạn tối đa cho phép (vd: 1000 bản ghi) | `{"type": "https://api.smartcampus.dnu/errors/unprocessable", "title": "Unprocessable Entity", "status": 422, "detail": "Requested page size exceeds maximum limit of 100"}` |

---

## 4. Giả định bổ sung

Ghi rõ những điểm user story chưa nói nhưng Provider cần giả định.

- Giả định 1: Dữ liệu log tại endpoint `/access/logs/recent` sẽ được giữ lại trong bộ nhớ Edge của Access Gate tối thiểu 48 tiếng sau khi Consumer đã kéo thành công để phục vụ đối soát khi cần.
- Giả định 2: Trường `direction` (IN/OUT) được cấu hình cứng theo địa chỉ IP/đầu kết nối vật lý của từng thiết bị đọc thẻ tại cổng xoay.
- Giả định 3: Nếu một lượt quẹt thẻ bị lỗi phần cứng (không đọc rõ chip), Access Gate vẫn ghi nhận log với trạng thái `DENIED` và kèm `operatorNote: "Hardware read error"`.

---

## 5. Câu hỏi cho Consumer

1. Tần suất tối đa các bạn thực hiện gọi `/access/logs/recent` là bao nhiêu để chúng tôi thiết lập ngưỡng chặn Rate Limiting?
2. Khi các bạn kéo log về và xử lý, nếu gặp bản ghi trùng lặp `logId` (do lỗi network retry phía các bạn), Core Business có cơ chế tự động loại bỏ (idempotent parsing) chưa?
3. Có cần bổ sung thêm trường thông tin phân loại thiết bị (mã vạch, QR, RFID) vào cấu trúc log trả về không?

---

## 6. Rủi ro tích hợp

| Rủi ro | Tác động | Đề xuất xử lý |
|---|---|---|
| Đồng bộ lệch trạng thái nghiệp vụ (Ví dụ: Trạng thái bên Gate là `DENIED` nhưng Core phân tích là hợp lệ) | Dữ liệu đối soát hệ thống bị bất đồng nhất, khó khăn cho công tác Audit | Đồng bộ bảng mã trạng thái `status` thành bộ Enum nghiêm ngặt cố định trong OpenAPI file. |
| Khối lượng log dồn ứ quá lớn tại cổng Edge gây tràn bộ nhớ | Mock server hoặc thiết bị vật lý bị treo, phản hồi API chậm | Bắt buộc Consumer phải tuân thủ nghiêm ngặt Cursor-based pagination và tối ưu kích thước payload của mỗi bản ghi. |
