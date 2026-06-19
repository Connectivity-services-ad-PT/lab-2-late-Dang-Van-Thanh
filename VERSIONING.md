# Chiến lược quản lý phiên bản API (API Versioning Strategy)

- Dịch vụ: Access Gate (Nhóm 3 — CNTT 17-11)
- Áp dụng cho: Cặp số 03 (Core Business -> Access Gate) và Cặp số 10 (Access Gate -> Core Business)
- Người viết: Đặng Văn Thanh, Lương Duy Chiến, Đặng Thành Đạt
- Ngày: 13/05/2026
- Phiên bản chiến lược: v1.0.0

Hệ thống **Smart Campus Operations Platform** áp dụng nguyên tắc **Semantic Versioning (SemVer 2.0.0)** để định danh phiên bản cho toàn bộ tài liệu hợp đồng `openapi.yaml`. Cấu trúc phiên bản tuân thủ định dạng: `MAJOR.MINOR.PATCH`.

---

## 1. Nguyên tắc tăng số phiên bản (SemVer Rules)

### 1.1. MAJOR Version (Thay đổi phá vỡ — Breaking Changes)
Tăng số **MAJOR** (Ví dụ: từ `1.0.0` lên `2.0.0`) khi có các thay đổi **không tương thích ngược (Backward-incompatible)** khiến Consumer (Core Business hoặc Access Gate) bị lỗi nếu không sửa đổi code.

**Các trường hợp cụ thể trong Access Gate Service:**
- **Xóa hoặc đổi tên một API Endpoint:** Thay đổi endpoint check quyền từ `POST /access/check` thành `POST /api/v2/policies/verify`.
- **Xóa hoặc đổi tên trường bắt buộc (Required Field) trong Payload:** Đổi tên trường dữ liệu thẻ `cardId` thành `studentCardUid` hoặc xóa trường `direction`.
- **Thay đổi kiểu dữ liệu (Data Type):** Thay đổi định dạng `gateId` từ chuỗi `string (format: uuid)` thành số nguyên `integer`.
- **Sửa đổi cấu trúc nghiêm ngặt của Enum:** Xóa bớt một giá trị hoặc thay đổi ký tự trong Enum phán quyết nghiệp vụ (ví dụ: đổi từ `ALLOW`/`DENY` sang `PERMITTED`/`FORBIDDEN`).
- **Thêm một trường dữ liệu bắt buộc (Required Field) vào Request Body:** Đòi hỏi Consumer phải gửi thêm trường mã xác thực sinh trắc học `biometricData` trong request `POST /access/check` thì mới xử lý.

### 1.2. MINOR Version (Thay đổi bổ sung — Backward-compatible Changes)
Tăng số **MINOR** (Ví dụ: từ `1.0.0` lên `1.1.0`) khi bổ sung thêm các tính năng, endpoint hoặc cấu trúc dữ liệu mới mang tính chất **tương thích ngược (Backward-compatible)**. Consumer cũ không cần cập nhật code vẫn hoạt động bình thường.

**Các trường hợp cụ thể trong Access Gate Service:**
- **Bổ sung API Endpoint mới:** Thêm endpoint lấy lịch sử bảo trì thiết bị `GET /gates/{gateId}/maintenance-logs` mà không làm ảnh hưởng các endpoint cũ.
- **Thêm trường dữ liệu tùy chọn (Optional Field) vào Response Body:** Trả về thêm trường thông tin `holderName` (Tên chủ thẻ) trong cấu trúc dữ liệu `PolicyDecision` của endpoint `/access/check`.
- **Thêm một query tham số tùy chọn (Optional Query Parameter):** Bổ sung tham số lọc theo thời gian `startTime`/`endTime` tại endpoint `GET /access/logs/recent`.

### 1.3. PATCH Version (Sửa lỗi tài liệu — Bug Fixes / Refactoring)
Tăng số **PATCH** (Ví dụ: từ `1.0.0` lên `1.0.1`) khi thực hiện các chỉnh sửa nhỏ liên quan đến văn bản, mô tả, sửa lỗi chính tả hoặc cập nhật ví dụ dữ liệu (Examples) mà không làm thay đổi cấu trúc schema hay logic vận hành.

**Các trường hợp cụ thể trong Access Gate Service:**
- Sửa lỗi chính tả trong trường `description` của API.
- Thay đổi nội dung chuỗi tin nhắn mẫu `example` của lỗi 400 Bad Request cho trực quan hơn.
- Cập nhật thông tin liên hệ (`info.contact`) trong tệp tin `openapi.yaml`.

---

## 2. Quy trình khai tử API cũ (Deprecation & Sunset Policy)

Nhằm đảm bảo hệ thống phần cứng tại các cổng xoay (Access Gate Edge) có đủ thời gian cập nhật firmware/software khi Core Business nâng cấp API, đội phát triển áp dụng quy trình khai tử API theo 3 bước chuẩn hóa:

### Bước 1: Đánh dấu `deprecated: true`
Khi một endpoint hoặc một trường dữ liệu chuẩn bị bị thay thế bởi một phiên bản thiết kế tốt hơn, Provider sẽ gắn thuộc tính `deprecated: true` trực tiếp vào tệp tin thiết kế `openapi.yaml`. Lúc này API cũ vẫn hoạt động bình thường nhưng các kỹ sư phía đối tác sẽ nhận được cảnh báo hệ thống khi đọc tài liệu.

### Bước 2: Trả về HTTP Headers cảnh báo (`Sunset` và `Deprecation`)
Trong tất cả các phản hồi HTTP (HTTP Response) từ Mock Server hoặc API Gateway của endpoint đã bị gắn cờ lỗi thời, hệ thống bắt buộc phải trả về hai Header tiêu chuẩn:
- `Deprecation`: Cho biết mốc thời gian API này chính thức bị coi là lỗi thời.
- `Sunset`: Cho biết mốc thời gian chính thức đóng hoàn toàn endpoint này (Ngắt kết nối).

*Ví dụ HTTP Response Headers từ Access Gate khi gọi API cũ:*
```http
HTTP/1.1 200 OK
Content-Type: application/json
Deprecation: Thu, 28 May 2026 00:00:00 GMT
Sunset: Thu, 28 May 2027 00:00:00 GMT