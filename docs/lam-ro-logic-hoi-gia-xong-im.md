# Lam Ro Logic Hoi Gia Xong Im

Tai lieu nay lam ro rule cho tinh huong:

```text
khach hoi gia / hoi ton kho / hoi san pham xong roi im lang
```

Day la phan `async qualification`, khong nen giai trong cung execution webhook.

## 1. Khong Danh Dau `not_interested` Ngay

Khach hoi gia xong im:

- khong dong nghia voi `khong co nhu cau`
- cung khong nen giu mai la `qualified`

Vi vay khong duoc:

- chuyen ngay sang `not_interested`
- handoff ngay

## 2. Rule Toi Gian

### Sau 30 phut - 2 gio

- van giu nguyen `lead_status`
- chua doi state

### Sau 24 gio khong phan hoi

Neu:

- da bao gia hoac da check ton kho
- chua co so dien thoai
- khong co tin nhan moi

Thi:

- `customer_stage = cold`
- `lead_status = inactive`

### Neu khach tung noi ro "tham khao thoi"

Thi co the doi nhanh hon sang:

- `lead_status = inactive`

## 3. Field Can Dung

- `quoted_at`
- `last_customer_message_at`
- `last_bot_reply_at`
- `phone_capture_status`
- `handoff_ready`

## 4. Workflow Async De Xuat

```text
Cron moi 30 phut
-> Load customer_phase_state
-> Loc lead_status in (interested, qualified)
-> Loc handoff_ready = false
-> Loc last_customer_message_at < now() - interval '24 hours'
-> Neu quoted_at is not null va phone rong
   -> update customer_stage = cold
   -> update lead_status = inactive
```

## 5. Ket Luan

Cho phase 1, rule don gian nhat la:

- hoi gia xong im khong phai `not_interested`
- nhung sau nguong thoi gian thi nen chuyen `inactive`

Nhu vay se:

- khong bo sot lead qua som
- nhung van do luong duoc lead da nguoi
