# Kế Hoạch `/addorder` Từ Ticket Ảo Sang Đơn Nhanh

Tài liệu này chốt hướng thiết kế cho tính năng tạo đơn thật trên Nhanh dựa vào `ticket ảo` đang nằm trong Supabase, trước khi triển khai code/workflow.

## 1. Mục tiêu

Mục tiêu nghiệp vụ:

- không cho bot tự tạo đơn từ chat tự do
- chỉ cho tạo đơn qua cú pháp rõ ràng như `/addorder ...`
- lấy dữ liệu nền từ `ticket ảo` đã chốt ở Supabase
- cho phép user sửa dần draft đơn nhiều lần trước khi chốt
- khi chốt mới gọi `Nhanh /v3.0/order/add`
- toàn bộ quá trình phải có audit

Kết luận chốt:

- `ZaloWorkflow.json` chỉ nên route command `/addorder`
- phần xử lý tạo đơn phải là một sub-workflow riêng, chi tiết hơn
- AI chỉ dùng để parse patch từ câu lệnh `/addorder`, không được tự quyết tạo đơn từ chat bình thường

## 2. Dữ liệu hiện có trong hệ thống

### 2.1. Ticket ảo hiện tại

`public.lead_handoff_queue` hiện đang giữ:

- `id`
- `channel`
- `page_id`
- `sender_id`
- `phone`
- `fullname`
- `products_interested`
- `need_summary`
- `handoff_reason`
- `status`
- các field claim / close / group đã bổ sung qua patch

Ý nghĩa:

- đây là ticket handoff cho sale
- chưa phải object phù hợp để giữ draft đơn chi tiết

### 2.2. State khách hàng nền

`public.customer_phase_state` đang giữ thêm:

- `fullname`
- `phone`
- `address`
- `customer_city`
- `customer_district`
- `products_interested`
- `need_summary`

Ý nghĩa:

- có thể dùng làm nguồn điền sẵn cho draft đơn
- nhưng chưa đủ chuẩn để bắn thẳng `order/add`

### 2.3. Audit đang có

`public.lead_handoff_actions` đang phù hợp để log:

- ai tạo / sửa / chốt draft
- command gốc
- payload trước và sau merge
- kết quả gọi Nhanh

### 2.4. Bảng order hiện có

`public.order_tickets` đang là object order/ticket khác domain với `lead_handoff_queue`.

Kết luận:

- không nên nhét draft `/addorder` trực tiếp vào `lead_handoff_queue`
- cũng không nên tái dùng `order_tickets` làm draft store nếu chưa rõ toàn bộ downstream đang dùng nó ra sao
- an toàn nhất là tạo một bảng draft riêng

## 3. Kết quả đọc tài liệu Nhanh

Nguồn chính:

- `order/add`: https://apidocs.nhanh.vn/v3/order/add
- `order/edit`: https://apidocs.nhanh.vn/v3/order/edit
- `product/list`: https://apidocs.nhanh.vn/v3/product/list
- `shipping/location`: https://apidocs.nhanh.vn/v3/shipping/location
- `shipping/fee`: https://apidocs.nhanh.vn/v3/shipping/fee
- `business/depot`: https://apidocs.nhanh.vn/v3/business/depot
- `business/user`: https://apidocs.nhanh.vn/v3/business/user
- `shipping/carrier`: https://apidocs.nhanh.vn/v3/shipping/carrier
- `modelconstant`: https://apidocs.nhanh.vn/v3/modelconstant

### 3.1. Các field tối thiểu quan trọng của `order/add`

Từ docs:

- `channel.appOrderId` là bắt buộc và phải unique theo `appId + appOrderId`
- `shippingAddress.name` là bắt buộc
- `shippingAddress.mobile` là bắt buộc
- `products[].id` là bắt buộc
- `products[].price` là bắt buộc
- `products[].quantity` là bắt buộc

Hàm ý:

- không thể chỉ có `ticket T-3` rồi tạo đơn
- phải resolve được ít nhất khách + SĐT + sản phẩm cụ thể trên Nhanh + giá + số lượng

### 3.2. Địa chỉ giao hàng không nên để text thuần

Docs `shipping/location` cho thấy:

- nên map địa chỉ sang `cityId`, `districtId`, `wardId`
- `locationVersion = v1` vẫn là lựa chọn an toàn hơn hiện tại

Hàm ý:

- AI có thể hiểu text địa chỉ
- nhưng bước cuối phải resolve deterministically sang ID địa chỉ của Nhanh

### 3.3. Phần vận chuyển kéo theo nhiều dependency

Docs `order/add` và `shipping/fee` cho thấy:

- nếu dùng carrier ngay, cần biết kiểu kết nối vận chuyển
- có thể cần `depotId`
- có thể cần `serviceId` hoặc `serviceCode`, `accountId`, `shopId`
- có thể cần tính phí trước bằng `shipping/fee`

Kết luận thiết kế:

- pha đầu không nên auto ship
- tạo order nội bộ trên Nhanh trước, chưa `autoSend`
- carrier và shipping fee nên là pha sau

### 3.4. `order/edit` không phải API sửa mọi thứ

Docs `order/edit` hiện nêu rõ phần update chủ yếu cho:

- `info`
- `carrier`
- `payment`

Không thấy docs public cho phép sửa lại cả:

- `shippingAddress`
- `products`

Đây là suy luận từ trang docs hiện tại.

Hàm ý nghiệp vụ:

- user được sửa thoải mái khi order còn ở trạng thái draft nội bộ của hệ mình
- sau khi đã gọi `order/add`, việc sửa sản phẩm/địa chỉ nên coi là luồng khác
- pha đầu chỉ nên hỗ trợ “sửa draft trước khi confirm”

## 4. Quy tắc giao diện lệnh

### 4.1. Chỉ nhận slash command

Không cho tạo đơn từ chat tự nhiên kiểu:

- `chốt đơn này đi`
- `tạo đơn cho khách này`

Chỉ nhận dạng khi có command rõ:

- `/addorder ...`

Giai đoạn đầu chưa cần alias ngắn. Giữ đúng `/addorder` để giảm mơ hồ.

### 4.2. AI chỉ được chạy bên trong `/addorder`

AI được phép:

- đọc phần nội dung sau `/addorder`
- tách field thay đổi
- hiểu câu sửa kiểu tự nhiên

AI không được phép:

- tự biến chat thường thành lệnh tạo đơn
- tự bỏ qua bước confirm
- tự chọn sản phẩm nếu còn mơ hồ

### 4.3. Bộ command đề xuất

Giai đoạn đầu:

- `/addorder t-3 ...`
- `/addorder show t-3`
- `/addorder confirm t-3`
- `/addorder cancel t-3`
- `/addorder reset t-3`

Ý nghĩa:

- `t-3 + nội dung`: cập nhật draft
- `show`: xem draft hiện tại
- `confirm`: validate lần cuối và tạo đơn thật
- `cancel`: hủy draft
- `reset`: xoá phần draft đã nhập, quay về dữ liệu gốc từ ticket

### 4.4. Ví dụ command

```text
/addorder t-3 tên Phạm Hoàng Hải sđt 0387803007 sản phẩm norda 001 size 42 x1
/addorder t-3 đổi size 43, thêm địa chỉ 170 La Thành, Đống Đa, Hà Nội
/addorder t-3 thu khách 30k ship cod
/addorder show t-3
/addorder confirm t-3
```

## 5. State machine đề xuất

### 5.1. Ticket ảo

`lead_handoff_queue` vẫn giữ vai trò:

- ticket handoff
- trạng thái lead
- claim / reject / close

Không nhét toàn bộ order draft vào đây.

### 5.2. Order draft

Tạo state riêng cho order draft:

- `draft`
- `needs_clarification`
- `ready_to_confirm`
- `submitting`
- `created`
- `failed`
- `cancelled`

### 5.3. Luồng trạng thái

```text
/addorder t-3 ...
-> draft
-> needs_clarification (nếu thiếu / mơ hồ)
-> ready_to_confirm (đủ dữ liệu)
-> /addorder confirm t-3
-> submitting
-> created | failed
```

## 6. Schema đề xuất

### 6.1. Bảng `order_drafts`

Khuyến nghị tạo bảng mới:

```sql
create table public.order_drafts (
  id bigint generated always as identity primary key,
  handoff_queue_id bigint not null references public.lead_handoff_queue(id) on delete cascade,
  group_id text,
  source_command_text text,
  status text not null default 'draft',
  customer_name text,
  phone text,
  address_text text,
  city_name text,
  district_name text,
  ward_name text,
  city_id int,
  district_id int,
  ward_id int,
  location_version text default 'v1',
  note text,
  private_note text,
  products_json jsonb not null default '[]'::jsonb,
  payment_json jsonb not null default '{}'::jsonb,
  carrier_json jsonb not null default '{}'::jsonb,
  raw_ai_patch jsonb not null default '{}'::jsonb,
  merged_snapshot jsonb not null default '{}'::jsonb,
  app_order_id text,
  nhanh_order_id bigint,
  nhanh_tracking_url text,
  last_error text,
  confirmed_by_user_id text,
  confirmed_by_display_name text,
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

Ghi chú:

- `products_json` nên là mảng chuẩn hóa, không lưu text thô
- `merged_snapshot` là payload order-ready ở mức nội bộ
- `app_order_id` nên được sinh ổn định theo draft

### 6.2. Audit

Không cần bảng audit mới ngay.

Tận dụng `lead_handoff_actions`:

- `action_type = order_draft_upserted`
- `action_type = order_draft_confirm_requested`
- `action_type = order_created`
- `action_type = order_create_failed`

Payload nên giữ:

- command gốc
- patch AI extract
- merged draft snapshot
- payload gửi Nhanh
- response / error từ Nhanh

### 6.3. Cache / config phụ trợ

Nên có thêm cache hoặc config riêng cho Nhanh:

- kho mặc định `depotId`
- user Nhanh mặc định `saleId`, `createdById`
- sourceName mặc định
- cache địa chỉ
- cache carrier

Lý do:

- docs Nhanh cho biết depot / location / carrier là dữ liệu ít thay đổi, cache 24h là hợp lý

## 7. Thiết kế sub-workflow

Không đấu thẳng `order/add` vào `ZaloWorkflow.json`.

Kiến trúc đề xuất:

```text
ZaloWorkflow
-> route /addorder
-> Execute Workflow: Zalo_AddOrder_From_Ticket
-> reply + audit
```

### 7.1. Workflow chính: `Zalo_AddOrder_From_Ticket`

Nhiệm vụ:

- nhận command `/addorder`
- load ticket ảo
- load draft hiện tại nếu có
- dùng AI parse patch
- merge dữ liệu draft
- resolve product / address
- validate
- nếu `confirm` thì gọi sub-workflow tạo đơn thật
- trả summary ngắn gọn về Zalo

### 7.2. Flow chi tiết

```text
Input command
-> Normalize command mode (patch/show/confirm/cancel/reset)
-> Load handoff ticket
-> Load current order draft
-> AI parse patch into JSON schema
-> Deterministic merge patch vào draft
-> Resolve product IDs từ Nhanh
-> Resolve city/district/ward IDs từ Nhanh
-> Validate required fields
-> If mode = show: trả draft
-> If mode = patch/reset/cancel: lưu draft rồi trả summary
-> If mode = confirm:
   -> gọi Zalo_AddOrder_Submit_Nhanh
   -> persist nhanh_order_id / tracking_url
   -> trả kết quả
```

### 7.3. Workflow con: `Zalo_AddOrder_Submit_Nhanh`

Nhiệm vụ:

- chỉ nhận draft đã validate
- build payload deterministic cho `order/add`
- gọi `Nhanh /order/add`
- ghi kết quả về `order_drafts`
- log audit

Flow:

```text
Load Nhanh token + defaults
-> Build appOrderId
-> Build order payload
-> POST /v3.0/order/add
-> Save nhanh_order_id + tracking_url
-> Return concise result
```

### 7.4. Sub-step resolver cần có

#### A. Product resolver

Dùng `product/list` để search theo:

- tên
- mã
- barcode

Trả về:

- `product_id`
- `resolved_name`
- `retail_price`
- `weight`
- trạng thái match

Rule:

- nếu match > 1 hoặc không chắc biến thể size/màu, không cho confirm

#### B. Address resolver

Dùng `shipping/location` để map:

- `city_name -> city_id`
- `district_name -> district_id`
- `ward_name -> ward_id`

Rule:

- nếu user chưa đưa đủ địa chỉ, draft vẫn lưu được
- nhưng chưa được `confirm`

#### C. Shipping resolver

Pha đầu:

- chưa bắt buộc
- không `autoSend`

Pha sau:

- mới thêm `shipping/fee`
- mới tính carrier/service phù hợp

## 8. Schema AI parse đề xuất

AI chỉ parse phần sau `/addorder`.

Output schema:

```json
{
  "action": "patch|show|confirm|cancel|reset",
  "handoff_ticket_id": 3,
  "customer_name": "Phạm Hoàng Hải",
  "phone": "0387803007",
  "address_text": "170 La Thành",
  "city_name": "Hà Nội",
  "district_name": "Đống Đa",
  "ward_name": "",
  "note": "",
  "private_note": "",
  "products": [
    {
      "query": "norda 001 size 42",
      "quantity": 1,
      "price_override": null,
      "discount": null
    }
  ],
  "payment": {
    "customer_ship_fee": 30000,
    "deposit_amount": null,
    "transfer_amount": null
  }
}
```

Rule:

- AI chỉ extract patch
- merge, validate, resolve đều làm bằng code deterministic

## 9. Quy tắc merge draft

### 9.1. Nguồn ưu tiên

Thứ tự ưu tiên:

1. command `/addorder` mới nhất
2. draft hiện tại
3. `lead_handoff_queue`
4. `customer_phase_state`

### 9.2. Merge theo field

- `customer_name`, `phone`, `address`: ghi đè nếu command mới có
- `products`: mặc định thay toàn bộ nếu user nói “đổi sản phẩm”; còn nếu nói “thêm”, append có kiểm soát
- `payment`: patch theo từng key
- `carrier`: giai đoạn đầu chưa xử lý sâu

### 9.3. Reply sau mỗi lần patch

Không trả dài dòng. Chỉ trả:

```text
Đã cập nhật draft T-3.
Khách: Phạm Hoàng Hải | 0387803007
Sản phẩm: norda 001 size 42 x1
Địa chỉ: 170 La Thành, Đống Đa, Hà Nội
Thiếu: phường/xã
Dùng /addorder confirm t-3 để chốt.
```

## 10. Payload Nhanh giai đoạn đầu

Để giảm rủi ro, payload giai đoạn đầu nên tối giản:

- `info.type = 1`
- `info.status = 54` hoặc để mặc định đơn mới
- `channel.appOrderId = <id duy nhất nội bộ>`
- `channel.sourceName = "Zalo OA GMF"`
- `shippingAddress`
- `products`
- chưa truyền `carrier.autoSend = 1`

Chỉ thêm:

- `info.depotId`
- `info.saleId`
- `info.createdById`

nếu doanh nghiệp đã chốt được mapping mặc định.

## 11. Cách gắn với ticket ảo

### 11.1. Mapping đề xuất

- `/addorder t-3 ...` -> `lead_handoff_queue.id = 3`
- mỗi ticket ảo chỉ có 1 draft active tại một thời điểm
- khi đã tạo đơn thành công:
  - `order_drafts.status = created`
  - `order_drafts.nhanh_order_id` được lưu lại
  - `lead_handoff_queue` có thể được update thêm metadata `order_created_at`, `order_created_by`

### 11.2. Không tạo bừa từ ticket

Ticket ảo chỉ là nguồn nền.

Không đủ điều kiện để tạo đơn nếu:

- chưa resolve được sản phẩm
- thiếu tên hoặc SĐT
- thiếu địa chỉ tối thiểu cho giao hàng tận nơi
- AI extract còn mơ hồ

## 12. Phân quyền

Khuyến nghị:

- `manager`, `sales`: được `/addorder`
- `viewer`: không được confirm tạo đơn

Khi `confirm`:

- bắt buộc audit actor
- log đầy đủ payload và response

## 13. Rủi ro chính

### 13.1. Sản phẩm mơ hồ

Ví dụ:

- `norda 001`
- `áo altra`

không đủ để suy ra đúng biến thể bán.

Xử lý:

- resolver phải trả danh sách candidate
- bot yêu cầu user chỉ rõ

### 13.2. Địa chỉ thiếu cấp

Nếu chưa map được `city/district/ward`, không cho confirm.

### 13.3. Sửa sau khi đã tạo đơn

Do docs `order/edit` hiện không cho thấy sửa đầy đủ sản phẩm/địa chỉ, giai đoạn đầu nên chốt rule:

- chỉ sửa tự do khi còn draft
- sau khi tạo đơn thật, nếu cần sửa sâu thì đi nhánh riêng

### 13.4. Trùng order

`appOrderId` phải unique.

Xử lý:

- sinh `appOrderId` nội bộ ổn định
- ví dụ: `GMF-T3-D1` hoặc `GMF-HQ3-<draft_id>`

## 14. Kế hoạch triển khai đề xuất

### Pha 1

- tạo schema `order_drafts`
- làm sub-workflow `Zalo_AddOrder_From_Ticket`
- support:
  - `/addorder t-3 ...`
  - `/addorder show t-3`
  - `/addorder confirm t-3`
  - `/addorder cancel t-3`
- tạo order Nhanh chưa auto ship

### Pha 2

- thêm cache product / location / depot / carrier
- thêm tính phí ship
- thêm chọn carrier / service
- thêm `order/edit` cho các update được docs hỗ trợ

### Pha 3

- thêm alias ngắn nếu team cần
- thêm follow-up command:
  - `/order t-3`
  - `/tracking t-3`
  - `/shiporder t-3`

## 15. Checklist trước khi code

1. Chốt command canonical có phải chỉ dùng `/addorder` hay thêm alias.
2. Chốt có tạo bảng `order_drafts` mới hay không.
3. Chốt `depotId`, `saleId`, `createdById` mặc định của Nhanh.
4. Chốt rule địa chỉ tối thiểu để cho phép confirm.
5. Chốt rule giá:
   - lấy giá retail từ Nhanh
   - hay cho phép override trong command.
6. Chốt sau khi tạo đơn thành công thì có update `lead_handoff_queue` hay không.

## 16. Kết luận

Hướng đúng cho bài toán này là:

- không để Zalo workflow chính tự xử lý hết `order/add`
- tách `/addorder` thành một sub-workflow riêng
- chỉ nhận slash command rõ ràng
- AI chỉ parse patch từ command
- resolve và validate bằng code deterministic
- chỉ tạo đơn khi user `confirm`

Nếu đi theo hướng này, workflow sẽ bền hơn nhiều so với việc cho AI đọc chat tự do rồi tự bắn `order/add`.
