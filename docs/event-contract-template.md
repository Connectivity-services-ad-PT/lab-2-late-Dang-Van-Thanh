# Event Contract sơ bộ — dùng cho dependency Queue async

> File này chỉ dùng cho các cặp Queue async ở Lab 02 để ghi nhận thỏa thuận ban đầu. Đặc tả chi tiết bằng AsyncAPI sẽ chuyển sang Lab 03.

## 1. Thông tin dependency

- Dependency số: Pair 09
- Producer: Access Gate
- Consumer: Analytics
- Cơ chế: Queue async
- Event/topic dự kiến: `smartcampus.access.events`
- Người ghi: Đặng Văn Thanh
- Ngày: 13/05/2026

## 2. Mục đích nghiệp vụ

Hệ thống hạ tầng vật lý **Access Gate** thực hiện phát (feed) liên tục các luồng log sự kiện ra/vào hoặc các lượt quẹt thẻ bị từ chối lên hàng đợi Message Queue. Hệ thống **Analytics** sẽ tiêu thụ (consume) luồng dữ liệu stream này để xử lý thời gian thực, phục vụ bài toán thống kê mật độ phòng máy, lưu lượng Campus theo giờ cao điểm và tính toán tỷ lệ từ chối phục vụ (deny rate) toàn trường.

## 3. Event name / topic

| Mục | Giá trị |
|---|---|
| Event 1 | `access.log.created` |
| Event 2 | `access.denied` |
| Topic/queue | `smartcampus.access.events` |
| Producer | Access Gate |
| Consumer | Analytics |

## 4. Payload tối thiểu

Để đảm bảo an toàn thông tin (Privacy) và phòng chống gửi lặp dữ liệu (Idempotency), cấu trúc payload được bọc thành hai phần gồm: **Metadata** (Chứa khóa chống trùng lặp, định danh luồng) và **Data** (Chứa dữ liệu nghiệp vụ đã băm ẩn danh mã thẻ).

### 4.1. Sự kiện quẹt thẻ thành công: `access.log.created`
```json
{
  "eventId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "eventType": "access.log.created",
  "occurredAt": "2026-05-28T10:28:43Z",
  "correlationId": "check-in-cntt-17-11-allow",
  "source": "access-gate-edge",
  "data": {
    "logId": "1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d",
    "hashedCardId": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "gateId": "5ebb8022-f33e-f71a-7a06-cab650c82a13",
    "direction": "IN",
    "operatorNote": "Normal standard check-in"
  }
}
```

### 4.2. Sự kiện quẹt thẻ bị từ chối: `access.denied`
```json
{
  "eventId": "3c9b1deb-4bad-9bdd-2b0d-7b3dcb6d9bdd",
  "eventType": "access.denied",
  "occurredAt": "2026-05-28T10:28:45Z",
  "correlationId": "check-in-cntt-17-11-deny",
  "source": "access-gate-edge",
  "data": {
    "logId": "8f7e6d5c-4b3a-2f1e-0d9c-8b7a6f5e4d3c",
    "hashedCardId": "8f4388e3328e3b33fc003d162a0dd85c57b54a390e1819d44c9b207eb443f111",
    "gateId": "5ebb8022-f33e-f71a-7a06-cab650c82a13",
    "direction": "IN",
    "reasonCode": "CARD_EXPIRED",
    "operatorNote": "Tuition fees outstanding or Card validation expired."
  }
}
```

## 5. Ràng buộc cần thống nhất

| Vấn đề | Quyết định tạm thời |
|---|---|
| Event id có bắt buộc không? | Có |
| Có cần correlationId không? | Có |
| Có cho phép gửi trùng event không? | Có thể, consumer phải idempotent |
| Retry khi lỗi | Ghi rõ ở Lab 03 |
| Dead-letter queue | Ghi rõ ở Lab 03 |

## 6. Issue chuyển sang Lab 03

1. Cấu hình hàng đợi: Xác định cấu hình Partition Key chi tiết cho Topic sự kiện để đảm bảo thứ tự thời gian (occurredAt) của các sự kiện quẹt thẻ phát ra từ cùng một cổng luôn chính xác.
2. Cơ chế xử lý lỗi tầng Consumer: Thống nhất chính sách thiết lập hàng đợi thư rác (Dead-Letter Queue - DLQ) và chiến lược cấu hình Retry (Back-off interval) khi Analytics bị quá tải hoặc nghẽn cơ sở dữ liệu.
3. Đặc tả AsyncAPI hoàn chỉnh: Chuyển đổi toàn bộ tài liệu Markdown này sang đặc tả kỹ thuật YAML chuẩn AsyncAPI 2.x/3.x, bao gồm định nghĩa tường minh các Components Message và Channel chi tiết.
