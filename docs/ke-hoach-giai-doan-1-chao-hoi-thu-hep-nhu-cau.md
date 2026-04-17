# Ke Hoach Giai Doan 1 - Chao Hoi, Thu Hep Nhu Cau Khach Hang

Tai lieu nay bam theo:

- anh mo ta "Giai doan 1"
- `Workflow.json` hien tai
- cac node, tool va nhanh da co san trong workflow

Muc tieu cua tai lieu:

1. danh gia workflow hien tai da du cho giai doan 1 chua
2. ve luong hien tai va luong de xuat
3. liet ke backlog task day du
4. check cac truong hop nghiep vu can cover
5. danh gia do kha thi khi them node moi vao workflow hien tai

## 1. Scope Giai Doan 1 Theo Yeu Cau

Tach tu anh mo ta, `Giai doan 1` gom 6 nhom nang luc:

1. chao hoi va dan nhap hoi thoai
2. bao gia va thu hep nhu cau
3. nhan dien san pham tu anh hoac tu text viet tat / noi gon
4. check ton kho
5. tra loi FAQ van hanh:
   - dia chi
   - gio lam viec
   - phuong thuc giao hang
6. chot lai nhu cau va kheo leo xin so dien thoai de tu van vien lien he ngay

Ngoai ra co 2 ket qua quan trong:

- xac dinh khach co nhu cau / co trien vong hay khong
- luu duoc tom tat nhu cau hien tai de sang giai doan 2

Tai lieu lam ro business rule:

- [lam-ro-logic-nhu-cau-va-trien-vong-khach-hang.md](/Users/phamhoanghai/n8n/docs/lam-ro-logic-nhu-cau-va-trien-vong-khach-hang.md)
- [lam-ro-logic-hoi-gia-xong-im.md](/Users/phamhoanghai/n8n/docs/lam-ro-logic-hoi-gia-xong-im.md)

## 2. Ket Luan Nhanh

`Workflow.json` hien tai:

- da du nen tang cho `tu van co ban`
- da co kha nhieu thanh phan cho `phase 1`
- nhung `chua day du` de coi la da hoan tat giai doan 1

Danh gia tong quan:

- manh o: buffer webhook, memory, AI text, check ton kho, nhan dien anh, luu CRM co ban
- thieu o: state machine phase 1, lead qualification ro rang, FAQ van hanh co cau truc, xin so dien thoai co logic, xu ly "khach hoi gia roi im", hop nhat text + image vao mot bo nao trung tam

Neu chi tinh cho `tu van dong bo co ban`, workflow da dat:

```text
Khoang 65-75%
```

Neu tinh dung theo yeu cau nghiep vu `phase 1`, workflow moi dat:

```text
Khoang 45-55%
```

Ly do:

- workflow da "tra loi duoc"
- nhung chua "quan tri duoc phase 1" mot cach on dinh va do luong duoc

## 3. Workflow Hien Tai Dang Co Gi

### 3.1. Luong Facebook chinh

```text
Webhook
-> Respond to Webhook POST 200 ngay
-> Code in JavaScript1
-> If2
-> PG Merge Facebook Conversation Buffer
-> If Facebook Buffer Updated
-> Wait Conversation Window
-> PG Load Facebook Conversation Buffer
-> If Latest Conversation Buffer
-> Set Buffered Conversation Context
-> If Has Image Attachment
   -> false -> AI Agent
   -> true
      -> Set Customer Image Payload
      -> HTTP Embed Customer Image
      -> If Customer Embedding Valid
         -> false -> Set Invalid Image Reply -> HTTP Reply Facebook Text1
         -> true
            -> Set Customer Query Vector
            -> PG Search Top K Products
            -> Code Rerank Candidates
            -> If Has Good Match
               -> false -> Set No Match Reply -> HTTP Reply Facebook Text
               -> true -> Set Product Match Reply -> HTTP Reply Facebook Text
```

### 3.2. Luong AI text branch

```text
Set Buffered Conversation Context
-> If Has Image Attachment false
-> AI Agent
   -> HTTP Request (reply text)
   -> Append or update row in sheet
   -> Insert rows in a table
   -> Select rows from a table
   -> If
      -> Code in JavaScript
      -> If Has Carousel Elements
      -> HTTP Reply Facebook Carousel
```

### 3.3. Tool dang noi vao AI Agent

`AI Agent` hien tai da co:

- `Postgres Chat Memory`
- `Pinecone Vector Store1` de retrieve product text
- `Get row(s) in sheet in Google Sheets` de lay "Kich ban"
- `HTTP Request4` de check ton kho Nhanh
- `HTTP Request10` de gui ticket ao sang Zalo group
- `Structured Output Parser`

## 4. Mapping Yeu Cau Phase 1 So Voi Workflow Hien Tai

| Nhom nang luc | Trang thai | Ghi chu |
|---|---|---|
| Chao hoi tu nhien | Da co | AI Agent da lam tot phan nay |
| Thu hep nhu cau | Co nhung chua on | Chu yeu dua vao prompt, chua co state node / slot tracking |
| Nhan dien anh khach gui | Da co | Co embedding + top-K + rerank |
| Phan tich text viet tat / noi gon | Mot phan | LLM tu doan, chua co dictionary / normalize layer |
| Check ton kho | Da co | Co tool Nhanh inventory |
| Check ton kho theo khu vuc / kho gan | Kha thi, dang co blueprint | Co the dung `business/depot` + `product/inventory` voi `depotIds` |
| Bao gia | Co nhung chua deterministic | Phu thuoc du lieu san pham ma AI retrieve duoc |
| Tra loi dia chi / gio lam viec / giao hang | Chua ro / chua chat | Chi dua vao sheet kich ban, chua co FAQ tool rieng |
| Xac dinh khach co nhu cau / co trien vong | Chua co ro rang | Chua co lead status, score, handoff flag |
| Chot nhu cau hien tai | Co nhung chua luu cau truc | AI co the hoi va tom tat, nhung chua co bang state ro |
| Xin so dien thoai de lien he | Co nhung chua dieu huong tot | Moi nam trong prompt, chua co logic khi nao can xin |
| Xac dinh "hoi gia xong im la khong co nhu cau" | Chua co | Can workflow async theo thoi gian |

## 5. Diem Manh Cua Workflow Hien Tai

### 5.1. Buffer webhook da lam rat dung

Ban da co:

- respond 200 ngay cho Facebook
- merge cac message fragment
- dung cua so cho 5 giay
- tranh bot tra loi tung manh

Day la nen tang rat tot cho giai doan 1.

### 5.2. Memory da co

`Postgres Chat Memory` da duoc noi vao `AI Agent`, nen bot co kha nang:

- nho ten
- nho san pham dang noi
- nho thong tin khach da tung cung cap

### 5.3. Check ton kho da co tool rieng

`HTTP Request4` da la 1 tool rat phu hop cho phase 1.

Day la diem cong lon vi ton kho la thong tin can deterministic.

### 5.4. Nhan dien anh da co pipeline rieng

Ban da co:

- `HTTP Embed Customer Image`
- `PG Search Top K Products`
- `Code Rerank Candidates`

Day la phan rat kho ma ban da di duoc kha xa.

### 5.5. Co luu thong tin khach va lich su chat

Ban da co:

- `Append or update row in sheet`
- `Insert rows in a table`
- `Select rows from a table`

Nghia la phase 1 da co du lieu de phuc vu CRM.

## 6. Khoang Trong Chinh Cua Workflow Hien Tai

### 6.1. Chua co 1 `phase state` ro rang

Hien tai workflow chua co node / bang du lieu de luu:

- `customer_stage`
- `lead_status`
- `need_summary`
- `intent_level`
- `phone_capture_status`
- `handoff_ready`

Vi vay bot co the tra loi hay, nhung he thong khong biet khach dang o dau trong funnel.

### 6.2. FAQ van hanh chua co nguon deterministic

Yeu cau phase 1 co:

- dia chi
- gio lam viec
- phuong thuc giao hang

Workflow hien tai chua co 1 node rieng cho:

- `store_info`
- `faq_shipping`
- `faq_contact`

Hien tai phan nay chi co the hy vong AI tu lay tu "Kich ban" sheet neu trong sheet co noi dung do.

Dieu nay dung duoc, nhung:

- kho kiem soat
- kho cap nhat
- kho dam bao AI luon lay dung

### 6.3. Nhanh image dang tach khoi AI Agent

Nhanh image hien tai van:

- tu rerank
- tu set reply
- tu gui text fallback

No chua duoc merge nguoc lai vao `AI Agent` de agent:

- doc ca text + image context
- quyet dinh cach reply thong nhat
- xin them size / nhu cau / sdt tren cung 1 bo nao

Day la 1 gap lon cua phase 1.

### 6.4. Xin so dien thoai moi o muc prompt

AI Agent da duoc prompt:

- sau 5-10 tin nhan thi xin sdt

Nhung he thong chua co:

- node detect phone da co hay chua
- validator sdt
- node quyet dinh "luc nao nen xin sdt"
- node danh dau "da xin sdt nhung khach chua tra loi"

### 6.5. Chua co logic "khach hoi gia xong im la khong co nhu cau"

Day la nghiep vu theo thoi gian.

Workflow webhook hien tai khong the tu ket luan duoc viec do trong cung 1 execution.

Tai lieu lam ro business rule:

- [lam-ro-logic-hoi-gia-xong-im.md](/Users/phamhoanghai/n8n/docs/lam-ro-logic-hoi-gia-xong-im.md)

Can workflow async rieng:

- cron
- query lead state
- check last_customer_message_at
- check da bao gia chua
- check khach co im qua nguong hay khong

### 6.6. Bao gia chua thuc su co node deterministic

Hien tai AI Agent co tool product retrieval va ton kho, nhung workflow chua co 1 tool rieng de lay:

- gia niem yet
- gia khuyen mai
- gia theo size / variant

Neu nguon product text khong co gia sach, phan bao gia se yeu.

## 7. Danh Gia Do Kha Thi Khi Them Node Moi

### 7.1. Them node FAQ van hanh

Do kha thi:

```text
Cao
```

Cach them:

- them `Google Sheets Tool` moi cho tab `Store FAQ`
- hoac them `Postgres Select` moi cho bang `store_faq`

Tac dong:

- it rui ro
- khong anh huong branch hien tai
- de chen vao AI Agent duoi dang tool

### 7.2. Them node lead state / phase state

Do kha thi:

```text
Cao
```

Cach them:

- them 1 bang Postgres moi
- hoac them cot moi vao sheet `Khach hang`

Khuyen nghi:

- Postgres tot hon cho automation

### 7.3. Them node normalize viet tat / text slang

Do kha thi:

```text
Cao
```

Cach them:

- chen 1 `Code` node sau `Set Buffered Conversation Context`
- output them `normalized_message_text`

Tac dung:

- AI Agent de doc hon
- rerank image cung huong loi hon

### 7.4. Gom image branch ve AI Agent

Do kha thi:

```text
Trung binh - Cao
```

Ly do:

- ky thuat khong kho vi da co san ket qua rerank
- nhung can sua connection de branch image khong tu reply rieng nua
- can them 1 node merge context truoc AI Agent

Day la nang cap rat nen lam trong phase 1.

### 7.5. Them no-reply qualification workflow

Do kha thi:

```text
Trung binh
```

Vi:

- khong nen giai trong webhook sync
- can workflow cron rieng
- can bang state / timestamp

Nhung day la bat buoc neu ban muon "khach hoi gia xong im" duoc do luong dung.

## 8. Kien Truc De Xuat Cho Giai Doan 1

### 8.1. Luong dong bo chinh

```text
Webhook
-> Respond 200 ngay
-> Parse event
-> Buffer conversation
-> Build buffered conversation context
-> Normalize customer text
-> If has image
   -> image enrichment pipeline
      -> embed
      -> top-K
      -> rerank
      -> set visual_context
-> Merge visual_context vao main context
-> Load customer phase state
-> AI Agent Phase 1
-> Reply text
-> Neu co product -> gui carousel
-> Upsert lead state
-> Update customer sheet / history
-> Neu da co sdt va high intent -> tao handoff task
```

### 8.2. Luong async bo sung

```text
Cron
-> Load open leads trong phase 1
-> Check last_customer_message_at
-> Check da bao gia chua
-> Check da xin sdt chua
-> Neu qua nguong khong phan hoi
   -> mark no_interest / cold / waiting_followup
   -> co the tao follow-up task
```

## 9. Node Moi Nen Them

## 9.1. Node `Code Normalize Customer Message`

Vi tri:

```text
Set Buffered Conversation Context -> Code Normalize Customer Message
```

Muc dich:

- chuan hoa viet tat
- don gian hoa slang
- tao `normalized_message_text`

Fields output de xuat:

- `message_text_original`
- `message_text_normalized`
- `detected_keywords`

## 9.2. Node `Set Visual Search Context`

Vi tri:

```text
Code Rerank Candidates -> Set Visual Search Context
```

Muc dich:

- dong goi ket qua image branch thanh context gon

Fields:

- `has_visual_context`
- `visual_best_match`
- `visual_candidates`
- `visual_confidence`
- `customer_image_url`
- `customer_message`
- `sender_id`

## 9.3. Node `Merge Visual Context To Main`

Vi tri:

```text
Code Normalize Customer Message
+ Set Visual Search Context
-> Merge Visual Context To Main
-> AI Agent Phase 1
```

Muc dich:

- hop nhat text + image vao cung 1 item

## 9.4. Node `PG Get Lead State`

Vi tri:

```text
truoc AI Agent Phase 1
```

Muc dich:

- doc xem khach dang o stage nao
- da co sdt chua
- da bao gia chua
- da duoc handoff chua

## 9.5. Node `Store FAQ Tool`

Muc dich:

- tra loi deterministically cho:
  - dia chi
  - gio lam viec
  - giao hang
  - COD / ship / doi tra

Khuyen nghi:

- them 1 Google Sheet tab `StoreFAQ`
- noi vao `AI Agent` duoi dang tool

## 9.6. Node `PG Upsert Lead State`

Vi tri:

```text
sau AI Agent
```

Muc dich:

- luu state phase 1

Fields nen luu:

- `channel`
- `sender_id`
- `customer_stage`
- `lead_status`
- `need_summary`
- `products_interested`
- `phone`
- `phone_status`
- `intent_score`
- `last_customer_message_at`
- `last_bot_reply_at`
- `quoted_at`
- `asked_phone_at`
- `handoff_ready`

## 9.7. Node `If Handoff Ready`

Vi tri:

```text
PG Upsert Lead State -> If Handoff Ready
```

Muc dich:

- neu co nhu cau + da co sdt
- thi tao task cho tu van vien lien he

Co the tan dung:

- `HTTP Request10` gui Zalo group
- hoac them bang `lead_handoff_queue`

## 9.8. Node `Cron Lead Qualification Review`

Workflow rieng.

Muc dich:

- xu ly case im lang sau khi hoi gia
- doi tag lead
- tao follow-up queue

## 10. Structured Output Moi De Xuat Cho AI Agent

Structured output hien tai van chua du cho phase 1.

Nen bo sung:

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
  "need_more_info_from_customer": false,
  "faq_topic": "",
  "note": "",
  "message": "",
  "product": [
    {
      "title": "",
      "variant": "",
      "size": "",
      "quantity": 1,
      "price": "",
      "image": ""
    }
  ]
}
```

Ghi chu:

- `customer_stage` va `lead_status` la 2 field quan trong nhat cho phase 1
- `ask_for_phone_now` giup he thong biet da den luc xin sdt chua
- `has_clear_need` giup xac dinh da thu hep nhu cau chua

## 11. Cac Truong Hop Nghiep Vu Bat Buoc Phai Cover

### Nhom A - Chao hoi va nhu cau co ban

1. khach chao hoi chung chung
2. khach hoi "shop co gi vay"
3. khach hoi san pham theo danh muc
4. khach noi nhu cau rat mo ho

Ky vong:

- bot chao hoi
- hoi 1-2 cau thu hep nhu cau
- khong nhay vao ticket qua som

### Nhom B - Bao gia va ton kho

5. khach hoi gia
6. khach hoi size / ton kho
7. khach hoi 1 ma san pham cu the
8. khach hoi nhieu san pham lien tiep

Ky vong:

- bot lay dung san pham
- ton kho di bang tool deterministic
- khong doan ton kho

### Nhom C - FAQ van hanh

9. khach hoi dia chi
10. khach hoi gio lam viec
11. khach hoi giao hang / COD / ship tinh

Ky vong:

- bot tra loi tu 1 nguon FAQ ro rang
- cau tra loi on dinh

### Nhom D - Anh + text

12. khach gui chi anh
13. khach gui anh + text cung luc
14. khach gui anh mo / loi / khong doc duoc
15. khach gui anh dung san pham nhung hoi them ton kho

Ky vong:

- image branch enrich context
- AI Agent phan hoi thong nhat
- neu can thi gui carousel

### Nhom E - Lead qualification

16. khach hoi gia roi tiep tuc hoi them
17. khach hoi gia roi im lang
18. khach da xac dinh nhu cau nhung chua cho sdt
19. khach da cho sdt va muon duoc tu van vien lien he

Ky vong:

- he thong doi stage dung
- khong bo sot lead co tiem nang
- khong goi handoff qua som

## 12. Backlog Task De Xuat

## Task Block A - Chot nen tang phase 1

1. Tao tai lieu business rule cho `customer_stage` va `lead_status`
2. Them bang Postgres `customer_phase_state`
3. Them node `PG Get Lead State`
4. Them node `PG Upsert Lead State`

## Task Block B - Chuan hoa input

5. Them node `Code Normalize Customer Message`
6. Tao dictionary viet tat / slang / size / shipping terms
7. Dua `normalized_message_text` vao AI Agent prompt

## Task Block C - FAQ van hanh

8. Tao tab `StoreFAQ` hoac bang `store_faq`
9. Tao node tool `Get Store FAQ`
10. Them rule cho AI Agent: FAQ van hanh uu tien doc tool nay

## Task Block D - Hop nhat image + AI

11. Tao node `Set Visual Search Context`
12. Tao node `Merge Visual Context To Main`
13. Doi image branch tu "tu reply" sang "enrich context"
14. Giu fallback text cho case anh loi / no match

## Task Block E - Structured output phase 1

15. Nang cap `Structured Output Parser`
16. Them cac field:
    - `need_summary`
    - `customer_stage`
    - `lead_status`
    - `intent_score`
    - `ask_for_phone_now`
    - `has_clear_need`

## Task Block F - Handoff va qualification

17. Them node `If Handoff Ready`
18. Them logic:
    - co nhu cau ro
    - da co sdt
    - chua tao handoff
19. Tai su dung `HTTP Request10` hoac tao queue rieng

## Task Block G - Async no-reply workflow

20. Tao workflow cron review lead
21. Set rule "hoi gia xong im bao lau thi coi la cold / no interest"
22. Them cot:
    - `quoted_at`
    - `last_customer_message_at`
    - `last_bot_reply_at`
    - `followup_due_at`

## 13. Thu Tu Trien Khai Kien Nghi

De tranh sua qua nhieu mot luc, nen lam theo thu tu:

### Dot 1 - Co the lam ngay, rui ro thap

1. Them `Store FAQ Tool`
2. Nang cap `Structured Output Parser`
3. Them `PG Upsert Lead State`

### Dot 2 - Gia tri cao nhat

4. Them `Set Visual Search Context`
5. Merge image branch vao AI Agent
6. Giu carousel cho output

### Dot 3 - Nghiep vu quan ly lead

7. Them `If Handoff Ready`
8. Tao queue / thong bao cho tu van vien

### Dot 4 - Do luong va toi uu

9. Tao workflow cron "khach hoi gia roi im"
10. Them dashboard / sheet view cho lead status

## 14. Muc Do Rui Ro Khi Tich Hop Node Moi

| Node / thay doi | Rui ro | Ghi chu |
|---|---|---|
| FAQ tool | Thap | Them tool vao AI Agent, it pha vo flow |
| PG Upsert Lead State | Thap | Chi la nhanh save state |
| Normalize message | Thap | Code node don gian |
| Structured output moi | Trung binh | Can chinh prompt va output parser |
| Merge image vao AI | Trung binh - cao | Can refactor connection va paired item |
| Cron no-reply workflow | Trung binh | Workflow moi, can bang state |
| Handoff ready automation | Trung binh | Can tranh tao thong bao lap lai |

## 15. Ket Luan Cuoi

Workflow hien tai `khong thieu nen tang`.

No da co:

- buffer chat
- memory
- image recognition
- stock tool
- CRM save
- carousel

Nhung de goi la `hoan tat Giai doan 1`, ban van can them 4 lop quan trong:

1. `FAQ layer` cho dia chi / gio lam viec / giao hang
2. `lead state layer` de biet khach dang o dau trong funnel
3. `image-to-AI merge layer` de phan hoi thong nhat
4. `async qualification layer` de xu ly case khach hoi gia roi im

Neu uu tien dung, thu tu nen la:

```text
FAQ -> lead state -> merge image vao AI -> handoff -> async no-reply
```

Day la cach toi uu de ban nang cap workflow hien tai ma khong can viet lai tu dau.
