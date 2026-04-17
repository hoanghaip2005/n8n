# Huong Dan Trien Khai Lead Qualification Phase 1

Tai lieu nay chot cach trien khai phan:

- `Xac dinh khach co nhu cau`
- `Xac dinh khach co trien vong`
- `Khi nao xin so dien thoai`
- `Khi nao handoff cho tu van vien`

Tai lieu business rule goc:

- [lam-ro-logic-nhu-cau-va-trien-vong-khach-hang.md](/Users/phamhoanghai/n8n/docs/lam-ro-logic-nhu-cau-va-trien-vong-khach-hang.md)

Schema Postgres:

- [customer_phase_state.sql](/Users/phamhoanghai/n8n/supabase/customer_phase_state.sql)

## 1. Muc Tieu Trien Khai

Sau khi xong phan nay, workflow se lam duoc:

- biet khach dang o `stage` nao
- biet lead dang `unknown / interested / qualified / inactive / not_interested`
- biet da den luc xin `phone` chua
- biet luc nao du dieu kien `handoff_ready`

## 2. Luong Khuyen Dung V2

Ban `khuyen dung` cho phase 1 nen la:

```text
Set Buffered Conversation Context
-> PG Get Lead State
-> Edit Fields Prev Lead State
-> Merge Context + Prev Lead State
-> If Has Image Attachment
   -> false -> Edit Fields Agent Input Text
   -> true
      -> Set Customer Image Payload
      -> HTTP Embed Customer Image
      -> If Customer Embedding Valid
         -> false
            -> Edit Fields Agent Input Image Failed
            -> AI Agent Phase 1
         -> true
            -> Set Customer Query Vector (tam thoi neu PG Search Top K Products dang can query_vector)
            -> PG Search Top K Products
            -> Aggregate Image Candidates (chi can neu PG Search Top K Products tra nhieu row)
            -> Edit Fields Agent Input Image Search
            -> AI Agent Phase 1
-> AI Agent Phase 1
   -> nhanh reply:
      -> HTTP Reply Facebook Text
      -> If Has Carousel Elements
         -> true -> Set Facebook Product Carousel -> HTTP Reply Facebook Carousel
   -> nhanh state:
      -> Edit Fields Prepare Lead State Row
      -> PG Upsert Lead State
      -> If Handoff Ready
         -> true -> Insert Lead Handoff Queue -> Update handoff_created
```

## 2.1. Vi sao luong nay tot hon

- bo `PG Get Lead State -> AI Agent` kieu noi thang de tranh trigger lech item
- bo `Code Merge Lead Qualification` de tranh regex cung va rule cung
- dung `Merge` node de ghep `context hien tai + state truoc do`
- dung `Aggregate` node de gom `image candidates` thanh 1 item cho AI
- de `AI Agent` tu suy luan `lead_status`, `customer_stage`, `intent_score`, `has_clear_need`, `ask_for_phone_now`, `handoff_ready`
- workflow phia n8n chi con lam viec no manh nhat:
  - doc du lieu
  - ghep du lieu
  - re nhanh
  - luu state

## 2.2. Nguyen tac trien khai

- `AI Agent Phase 1` van la `node AI Agent hien tai`, nen ban chi can doi ten node cho de quan sat
- `PG Get Lead State` khong duoc noi thang vao `AI Agent`
- nhanh anh khong duoc reply truc tiep nhu cu neu muon phase 1 dong bo
- thay vao do, nhanh anh can dua `image_candidates` quay lai `AI Agent`
- `AI Agent` la noi duy nhat ra quyet dinh phan hoi cho khach va qualification
- bo khoi nhanh anh cu:
  - `If Has Good Match`
  - `Set Product Match Reply`
  - `Set No Match Reply`
  - `HTTP Reply Facebook Text` cua nhanh anh cu
- `Set Customer Query Vector` co the giu tam trong giai doan chuyen tiep neu query Postgres hien tai van can field `query_vector`
- `Aggregate Image Candidates` la node tuy chon, chi can khi query Postgres tra ra nhieu row thay vi 1 row co san mang `candidates`

## 3. Node 1. PG Get Lead State

Node:

```text
PG Get Lead State
```

### Thiet lap

- `Operation`: `Select`
- `Schema`: `public`
- `Table`: `customer_phase_state`
- `Limit`: `1`

`Where`:

1. `channel`

```js
={{ $('Set Buffered Conversation Context').first().json.channel || 'facebook' }}
```

2. `page_id`

```js
={{ $('Set Buffered Conversation Context').first().json.page_id || '' }}
```

3. `sender_id`

```js
={{ $('Set Buffered Conversation Context').first().json.sender_id }}
```

### Settings

- bat `Always Output Data`

Ly do:

- neu khach moi, Postgres co the tra `0 row`
- `Merge Context + Prev Lead State` van can `1 item`
- bat option nay de Merge khong bi gay luong

## 4. Node 2. Edit Fields Prev Lead State

Node:

```text
Edit Fields Prev Lead State
```

Muc dich:

- chuan hoa du lieu tu Postgres
- doi ten cac field cu thanh dang `prev_*`
- de merge voi context hien tai ma khong de field bi de len nhau

Khuyen nghi:

- `Keep Only Set`: `ON`

Field quan trong:

- `prev_customer_stage`

```js
={{ $json.customer_stage || 'new' }}
```

- `prev_lead_status`

```js
={{ $json.lead_status || 'unknown' }}
```

- `prev_intent_score`

```js
={{ Number($json.intent_score || 0) }}
```

- `prev_has_clear_need`

```js
={{ Boolean($json.has_clear_need) }}
```

- `prev_ask_for_phone_now`

```js
={{ Boolean($json.ask_for_phone_now) }}
```

- `prev_handoff_ready`

```js
={{ Boolean($json.handoff_ready) }}
```

- `prev_handoff_created`

```js
={{ Boolean($json.handoff_created) }}
```

- `prev_phone_capture_status`

```js
={{ $json.phone_capture_status || 'unknown' }}
```

- `prev_handoff_reason`

```js
={{ $json.handoff_reason || '' }}
```

- `prev_need_summary`

```js
={{ $json.need_summary || '' }}
```

- `prev_products_interested`

```js
={{ $json.products_interested || '' }}
```

- `prev_fullname`

```js
={{ $json.fullname || '' }}
```

- `prev_phone`

```js
={{ $json.phone || '' }}
```

- `prev_address`

```js
={{ $json.address || '' }}
```

- `prev_customer_city`

```js
={{ $json.customer_city || '' }}
```

- `prev_customer_district`

```js
={{ $json.customer_district || '' }}
```

- `prev_quoted_at`

```js
={{ $json.quoted_at || null }}
```

- `prev_asked_phone_at`

```js
={{ $json.asked_phone_at || null }}
```

- `prev_first_seen_at`

```js
={{ $json.first_seen_at || null }}
```

## 5. Node 3. Merge Context + Prev Lead State

Node:

```text
Merge Context + Prev Lead State
```

### Thiet lap

- `Mode`: `Combine`
- `Combine By`: `Position`

Noi day:

- `Input 1`: tu `Set Buffered Conversation Context`
- `Input 2`: tu `Edit Fields Prev Lead State`

Ket qua mong doi:

- 1 item duy nhat
- co ca:
  - `message_text`, `sender_id`, `image_url`, `channel`, `page_id`
  - va bo `prev_*`

## 6. Node 4. Chuan bi input cho AI Agent

Tu `Merge Context + Prev Lead State` tach 2 nhanh:

### 6.1. Node `If Has Image Attachment`

Giu node nay, nhung chi dung de re nhanh:

- `false`: vao nhanh text
- `true`: vao nhanh anh

### 6.2. Nhanh text

Them node:

```text
Edit Fields Agent Input Text
```

Khuyen nghi:

- `Keep Only Set`: `OFF`

Them field:

- `image_analysis_status`

```js
=none
```

- `agent_prompt`

```js
={{
[
  `Current message: ${$json.message_text || ''}`,
  `Previous customer stage: ${$json.prev_customer_stage || 'new'}`,
  `Previous lead status: ${$json.prev_lead_status || 'unknown'}`,
  `Previous need summary: ${$json.prev_need_summary || ''}`,
  `Known fullname: ${$json.prev_fullname || ''}`,
  `Known phone: ${$json.prev_phone || ''}`,
  `Known address: ${$json.prev_address || ''}`,
  `Image analysis status: none`,
].join('\\n')
}}
```

### 6.3. Nhanh anh

Giu cac node san co, nhung doi muc dich cua nhanh anh:

```text
Set Customer Image Payload
-> HTTP Embed Customer Image
-> If Customer Embedding Valid
   -> false -> Edit Fields Agent Input Image Failed -> AI Agent Phase 1
   -> true  -> Set Customer Query Vector (tam thoi)
            -> PG Search Top K Products
            -> Aggregate Image Candidates (neu can)
            -> Edit Fields Agent Input Image Search
            -> AI Agent Phase 1
```

### 6.3.0. Node nao bo ngay, node nao giu tam

Bo ngay trong nhanh anh cu:

- `If Has Good Match`
- `Set Product Match Reply`
- `Set No Match Reply`
- `HTTP Reply Facebook Text` o nhanh anh cu

Giu tam neu workflow hien tai van phu thuoc:

- `Set Customer Query Vector`

Chi giu neu ban van can rerank bang code:

- `Code Rerank Candidates`

Neu `PG Search Top K Products` da tra ve 1 item co san field `candidates` va `AI Agent` se tu quyet dinh tu danh sach do, thi `Code Rerank Candidates` nen bo.

#### 6.3.1. `HTTP Embed Customer Image`

Giu nhu cu.

#### 6.3.2. `If Customer Embedding Valid`

Giu nhu cu.

#### 6.3.3. `PG Search Top K Products`

Giu nhu cu neu query da sort theo similarity giam dan.

Khuyen nghi:

- `top_k`: `5`

Luu y:

- neu node nay hien dang can `query_vector`, ban giu tam `Set Customer Query Vector`
- neu ban sua query de doc truc tiep `embedding` tu `HTTP Embed Customer Image`, luc do co the bo `Set Customer Query Vector`

#### 6.3.4. `Aggregate Image Candidates`

Node:

```text
Aggregate Image Candidates
```

Muc dich:

- gom nhieu row candidate thanh `1 item`
- dua ve cho `AI Agent` tu quyet dinh

Thiet lap:

- aggregate to `1 item`
- gom cac field thanh mang `image_candidates`

Luu y:

- neu `PG Search Top K Products` da tra san 1 row co field `candidates` dang array/json thi co the bo node nay
- khi do, `Edit Fields Agent Input Image Search` doc truc tiep tu `$json.candidates`

Moi candidate nen co:

- `title`
- `brand`
- `category`
- `image_url`
- `website_url`
- `score`

#### 6.3.5. `Edit Fields Agent Input Image Failed`

Them field:

- `image_analysis_status`

```js
=failed
```

- `agent_prompt`

```js
={{
[
  `Current message: ${$json.message_text || ''}`,
  `Previous customer stage: ${$json.prev_customer_stage || 'new'}`,
  `Previous lead status: ${$json.prev_lead_status || 'unknown'}`,
  `Previous need summary: ${$json.prev_need_summary || ''}`,
  `Known phone: ${$json.prev_phone || ''}`,
  `Image analysis status: failed`,
  `The uploaded image could not be embedded or read.`,
].join('\\n')
}}
```

#### 6.3.6. `Edit Fields Agent Input Image Search`

Them field:

- `image_analysis_status`

```js
=matched_candidates
```

- `agent_prompt`

```js
={{
[
  `Current message: ${$json.message_text || ''}`,
  `Previous customer stage: ${$json.prev_customer_stage || 'new'}`,
  `Previous lead status: ${$json.prev_lead_status || 'unknown'}`,
  `Previous need summary: ${$json.prev_need_summary || ''}`,
  `Known fullname: ${$json.prev_fullname || ''}`,
  `Known phone: ${$json.prev_phone || ''}`,
  `Image analysis status: matched_candidates`,
  `Image candidates JSON: ${JSON.stringify($json.image_candidates || $json.candidates || [])}`,
].join('\\n')
}}
```

### 6.4. Noi vao `AI Agent Phase 1`

Noi ca 3 node sau vao `AI Agent Phase 1`:

- `Edit Fields Agent Input Text`
- `Edit Fields Agent Input Image Failed`
- `Edit Fields Agent Input Image Search`

No khong gay trigger trung vi 3 nhanh nay `mutually exclusive`.

## 7. Node 5. AI Agent Phase 1

Node:

```text
AI Agent Phase 1
```

Luu y:

- day van la `node AI Agent hien tai`
- chi can doi ten node

### Prompt User Message

Khong dung:

```js
={{ $json.message_text }}
```

Ma dung:

```js
={{ $json.agent_prompt }}
```

### Structured output moi

Can them cac field sau vao output parser:

```json
{
  "fullname": "",
  "phone": "",
  "address": "",
  "age": "",
  "height": "",
  "weight": "",
  "products_interested": "",
  "need_summary": "",
  "customer_stage": "new|discovering|quoted|qualified|waiting_phone|handoff_ready|cold",
  "lead_status": "unknown|interested|qualified|not_interested|inactive",
  "intent_score": 0,
  "ask_for_phone_now": false,
  "has_clear_need": false,
  "handoff_ready": false,
  "handoff_reason": "",
  "need_more_info_from_customer": false,
  "note": "",
  "message": "",
  "product": []
}
```

### Rule moi cho prompt

Them vao `SystemMessage`:

```text
- Khong duoc phu thuoc vao 1 danh sach tu khoa co dinh nhu "gia", "bao nhieu", "bn", "bao gia"
- Phai suy luan theo y nghia tong the cua cau, ngu canh hoi thoai, lich su chat, du lieu image_candidates va tool inventory
- Neu khach viet tat, sai chinh ta, dung slang, tron Viet/Anh thi van phai co gang hieu dung nhu cau
- Khi chua chac, hoi 1 cau ngan de lam ro thay vi tu y gan qualified
```

### Ket luan quan trong

Tu diem nay tro di:

- bo han `Code Merge Lead Qualification`
- khong cham diem bang regex nua
- cho `AI Agent` la noi du nhat suy luan phase 1

## 8. Node 6. Edit Fields Prepare Lead State Row

Node:

```text
Edit Fields Prepare Lead State Row
```

Node nay dung de chuan bi row luu Postgres bang `node co san`, khong dung code.

Khuyen nghi:

- `Keep Only Set`: `ON`

Field quan trong:

- `channel`

```js
={{ $('Set Buffered Conversation Context').first().json.channel || 'facebook' }}
```

- `page_id`

```js
={{ $('Set Buffered Conversation Context').first().json.page_id || '' }}
```

- `sender_id`

```js
={{ $('Set Buffered Conversation Context').first().json.sender_id || '' }}
```

- `customer_stage`

```js
={{ $json.output.customer_stage || $('Edit Fields Prev Lead State').first().json.prev_customer_stage || 'new' }}
```

- `lead_status`

```js
={{ $json.output.lead_status || $('Edit Fields Prev Lead State').first().json.prev_lead_status || 'unknown' }}
```

- `intent_score`

```js
={{ Number($json.output.intent_score || $('Edit Fields Prev Lead State').first().json.prev_intent_score || 0) }}
```

- `has_clear_need`

```js
={{ Boolean($json.output.has_clear_need) }}
```

- `ask_for_phone_now`

```js
={{ Boolean($json.output.ask_for_phone_now) }}
```

- `handoff_ready`

```js
={{ Boolean($json.output.handoff_ready) }}
```

- `handoff_created`

```js
={{ $('Edit Fields Prev Lead State').first().json.prev_handoff_created || false }}
```

- `phone_capture_status`

```js
={{
  String($json.output.phone || '').trim()
    ? 'provided'
    : ($json.output.ask_for_phone_now === true
        ? 'requested'
        : $('Edit Fields Prev Lead State').first().json.prev_phone_capture_status || 'unknown')
}}
```

- `handoff_reason`

```js
={{ $json.output.handoff_reason || $('Edit Fields Prev Lead State').first().json.prev_handoff_reason || '' }}
```

- `need_summary`

```js
={{ $json.output.need_summary || $('Edit Fields Prev Lead State').first().json.prev_need_summary || '' }}
```

- `products_interested`

```js
={{ $json.output.products_interested || $('Edit Fields Prev Lead State').first().json.prev_products_interested || '' }}
```

- `fullname`

```js
={{ $json.output.fullname || $('Edit Fields Prev Lead State').first().json.prev_fullname || '' }}
```

- `phone`

```js
={{ $json.output.phone || $('Edit Fields Prev Lead State').first().json.prev_phone || '' }}
```

- `address`

```js
={{ $json.output.address || $('Edit Fields Prev Lead State').first().json.prev_address || '' }}
```

- `customer_city`

```js
={{ $('Edit Fields Prev Lead State').first().json.prev_customer_city || '' }}
```

- `customer_district`

```js
={{ $('Edit Fields Prev Lead State').first().json.prev_customer_district || '' }}
```

- `quoted_at`

```js
={{
  $json.output.customer_stage === 'quoted'
    ? new Date().toISOString()
    : $('Edit Fields Prev Lead State').first().json.prev_quoted_at || null
}}
```

- `asked_phone_at`

```js
={{
  $json.output.ask_for_phone_now === true
    ? new Date().toISOString()
    : $('Edit Fields Prev Lead State').first().json.prev_asked_phone_at || null
}}
```

- `last_customer_message_at`

```js
={{ $('Set Buffered Conversation Context').first().json.event_timestamp_iso || new Date().toISOString() }}
```

- `last_bot_reply_at`

```js
={{ new Date().toISOString() }}
```

- `last_customer_message_excerpt`

```js
={{ String($('Set Buffered Conversation Context').first().json.message_text || '').slice(0, 500) }}
```

- `last_bot_reply_excerpt`

```js
={{ String($json.output.message || '').slice(0, 500) }}
```

- `first_seen_at`

```js
={{ $('Edit Fields Prev Lead State').first().json.prev_first_seen_at || new Date().toISOString() }}
```

## 9. Node 7. PG Upsert Lead State

Node:

```text
PG Upsert Lead State
```

Khuyen nghi dung:

```text
Operation: Execute Query
```

Query:

```sql
insert into public.customer_phase_state (
  channel,
  page_id,
  sender_id,
  customer_stage,
  lead_status,
  intent_score,
  has_clear_need,
  ask_for_phone_now,
  handoff_ready,
  handoff_created,
  phone_capture_status,
  handoff_reason,
  need_summary,
  products_interested,
  fullname,
  phone,
  address,
  customer_city,
  customer_district,
  quoted_at,
  asked_phone_at,
  last_customer_message_at,
  last_bot_reply_at,
  last_customer_message_excerpt,
  last_bot_reply_excerpt,
  first_seen_at
)
values (
  $1::text,
  nullif($2::text, ''),
  $3::text,
  $4::text,
  $5::text,
  $6::integer,
  $7::boolean,
  $8::boolean,
  $9::boolean,
  $10::boolean,
  $11::text,
  nullif($12::text, ''),
  nullif($13::text, ''),
  nullif($14::text, ''),
  nullif($15::text, ''),
  nullif($16::text, ''),
  nullif($17::text, ''),
  nullif($18::text, ''),
  nullif($19::text, ''),
  $20::timestamptz,
  $21::timestamptz,
  $22::timestamptz,
  $23::timestamptz,
  nullif($24::text, ''),
  nullif($25::text, ''),
  $26::timestamptz
)
on conflict (channel, page_id, sender_id)
do update set
  customer_stage = excluded.customer_stage,
  lead_status = excluded.lead_status,
  intent_score = excluded.intent_score,
  has_clear_need = excluded.has_clear_need,
  ask_for_phone_now = excluded.ask_for_phone_now,
  handoff_ready = excluded.handoff_ready,
  handoff_reason = excluded.handoff_reason,
  need_summary = coalesce(excluded.need_summary, public.customer_phase_state.need_summary),
  products_interested = coalesce(excluded.products_interested, public.customer_phase_state.products_interested),
  fullname = coalesce(excluded.fullname, public.customer_phase_state.fullname),
  phone = coalesce(excluded.phone, public.customer_phase_state.phone),
  address = coalesce(excluded.address, public.customer_phase_state.address),
  customer_city = coalesce(excluded.customer_city, public.customer_phase_state.customer_city),
  customer_district = coalesce(excluded.customer_district, public.customer_phase_state.customer_district),
  quoted_at = coalesce(excluded.quoted_at, public.customer_phase_state.quoted_at),
  asked_phone_at = coalesce(excluded.asked_phone_at, public.customer_phase_state.asked_phone_at),
  last_customer_message_at = excluded.last_customer_message_at,
  last_bot_reply_at = excluded.last_bot_reply_at,
  last_customer_message_excerpt = excluded.last_customer_message_excerpt,
  last_bot_reply_excerpt = excluded.last_bot_reply_excerpt,
  first_seen_at = coalesce(public.customer_phase_state.first_seen_at, excluded.first_seen_at)
returning *;
```

`Query Parameters`:

```js
={{ [
  $json.channel,
  $json.page_id,
  $json.sender_id,
  $json.customer_stage,
  $json.lead_status,
  Number($json.intent_score || 0),
  Boolean($json.has_clear_need),
  Boolean($json.ask_for_phone_now),
  Boolean($json.handoff_ready),
  Boolean($json.handoff_created),
  $json.phone_capture_status,
  $json.handoff_reason || '',
  $json.need_summary || '',
  $json.products_interested || '',
  $json.fullname || '',
  $json.phone || '',
  $json.address || '',
  $json.customer_city || '',
  $json.customer_district || '',
  $json.quoted_at || null,
  $json.asked_phone_at || null,
  $json.last_customer_message_at || null,
  $json.last_bot_reply_at || null,
  $json.last_customer_message_excerpt || '',
  $json.last_bot_reply_excerpt || '',
  $json.first_seen_at || null,
] }}
```

## 10. Node 8. If Handoff Ready

Node:

```text
If Handoff Ready
```

Condition:

```js
={{ $json.handoff_ready === true && $json.handoff_created !== true }}
```

So sanh:

- `is true`

## 11. Node 9A. Insert Lead Handoff Queue

Node:

```text
Insert Lead Handoff Queue
```

Table:

```text
lead_handoff_queue
```

Columns:

- `channel`
```js
={{ $json.channel }}
```

- `page_id`
```js
={{ $json.page_id }}
```

- `sender_id`
```js
={{ $json.sender_id }}
```

- `phone`
```js
={{ $json.phone }}
```

- `fullname`
```js
={{ $json.fullname }}
```

- `products_interested`
```js
={{ $json.products_interested }}
```

- `need_summary`
```js
={{ $json.need_summary }}
```

- `handoff_reason`
```js
={{ $json.handoff_reason }}
```

## 12. Node 9B. Update `handoff_created`

Sau khi insert queue thanh cong, them 1 node Postgres `Execute Query`:

```sql
update public.customer_phase_state
set handoff_created = true
where channel = $1::text
  and page_id is not distinct from nullif($2::text, '')
  and sender_id = $3::text
returning *;
```

`Query Parameters`:

```js
={{ [
  $json.channel,
  $json.page_id || '',
  $json.sender_id,
] }}
```

## 13. Node Tam Thoi Neu Chua Muon Dung Queue

Neu chua muon them `lead_handoff_queue`, co the tan dung `HTTP Request10` nhu ke hoach cu.

Nhung van nen giu `customer_phase_state` vi day moi la lop state chinh.

## 14. Thu Tu Trien Khai Khuyen Nghi

De lam an toan va it vo luong cu:

1. Chay SQL [customer_phase_state.sql](/Users/phamhoanghai/n8n/supabase/customer_phase_state.sql)
2. Them `PG Get Lead State`
3. Bat `Always Output Data` cho `PG Get Lead State`
4. Them `Edit Fields Prev Lead State`
5. Them `Merge Context + Prev Lead State`
6. Them `Edit Fields Agent Input Text`
7. Nang cap nhanh anh thanh `Aggregate Image Candidates` + `Edit Fields Agent Input Image Search`
8. Doi `AI Agent` thanh `AI Agent Phase 1` va sua prompt thanh `{{$json.agent_prompt}}`
9. Nang cap structured output parser
10. Them `Edit Fields Prepare Lead State Row`
11. Them `PG Upsert Lead State`
12. Sau cung moi them `If Handoff Ready`

## 15. Ket Qua Mong Doi

Sau khi xong, moi execution se luu duoc:

- khach dang o `stage` nao
- da co nhu cau ro chua
- da den luc xin phone chua
- da du dieu kien handoff chua

Day la phan nen tang quan trong nhat de tu:

- "tra loi duoc"
- sang "quan ly duoc lead"
