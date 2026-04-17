# Huong Dan Toi Uu Luong Nhan Dien Anh Va AI Agent

Tai lieu nay bam theo `Workflow.json` hien tai va tra loi 3 cau hoi:

1. co nen dua nhanh nhan dien anh vao `AI Agent` hay khong
2. co nen de `AI Agent` dieu phoi cac nhanh con lai hay khong
3. neu doi kien truc thi bo node nao, them node nao

## 1. Trang Thai Hien Tai Trong Workflow

Nhanh Facebook co anh hien dang la:

```text
Webhook
-> Code in JavaScript1
-> If Has Image Attachment
   -> true
      -> Set Customer Image Payload
      -> HTTP Embed Customer Image
      -> If Customer Embedding Valid
         -> true
            -> Set Customer Query Vector
            -> PG Search Top K Products
            -> Code Rerank Candidates
            -> If Has Good Match
               -> true
                  -> Set Product Match Reply
                  -> HTTP Reply Facebook Text
                  -> Set Facebook Product Carousel
                  -> HTTP Reply Facebook Carousel
               -> false
                  -> Set No Match Reply
                  -> HTTP Reply Facebook Text
         -> false
            -> Set Invalid Image Reply
            -> HTTP Reply Facebook Text
   -> false
      -> AI Agent
```

Nhan xet:

- phan nhan dien anh dang la 1 pipeline rieng
- `AI Agent` text branch va image branch dang tach nhau
- image branch dang rat tot o cho:
  - embedding co dinh
  - vector search co nguong
  - rerank co logic ro
  - carousel gui rieng

Nhung voi muc tieu `phase 1`, van de lon nhat la:

- nhanh anh dang `tu reply rieng`
- khong day du context vao `AI Agent`
- khong dong bo voi `lead qualification`
- khong luu state phase 1 mot cach nhat quan

## 2. Co Nen Dua Han Phan Nhan Dien Anh Vao AI Agent Khong

Cau tra loi ngan:

```text
Khong nen dua toan bo phan nhan dien anh vao AI Agent.
Nen de AI Agent dieu phoi o lop tren, con embedding + vector search van de ngoai.
```

Ly do:

### 2.1. Embedding va vector search la phan "deterministic"

Day la cac buoc rat hop voi node thuong:

- `HTTP Embed Customer Image`
- `PG Search Top K Products`
- `Code Rerank Candidates` neu ban van can trong giai doan chuyen tiep

Uu diem khi de ngoai `AI Agent`:

- nhanh hon
- re hon
- de debug hon
- de dat threshold hon
- de cache ket qua hon
- de retry tung buoc hon

### 2.2. `AI Agent` hop hon voi vai tro dieu phoi va soan hoi dap

`AI Agent` nen lam:

- hieu y dinh khach
- doc context text + image
- quyet dinh nen:
  - tra loi text
  - gui carousel
  - hoi them anh ro hon
  - goi tool ton kho
  - tao ticket

`AI Agent` khong nen la noi tu nhin anh goc roi tu do doan san pham chinh.

### 2.3. "Sub AI agent" cho nhan dien anh khong phai lua chon toi uu

Neu ban lam:

```text
AI Agent chinh
-> goi sub-AI agent nhan dien anh
-> sub-AI agent goi tiep vector search
```

thi van co 3 van de:

- tang latency
- tang chi phi
- giam do on dinh

Vi vay, `sub-AI agent` chi nen dung lam fallback khi do tin cay thap, khong nen thay the embedding search.

## 3. Kien Truc Toi Uu Nen Dung

Phuong an toi uu la:

```text
Webhook
-> parser + buffer
-> build unified customer context
-> neu co anh:
   -> image enrichment pipeline
      -> embed
      -> top-K search
      -> rerank neu can
      -> tao image context cho agent
-> merge lai vao main context
-> AI Agent Phase 1
   -> quyet dinh tra loi
   -> quyet dinh gui carousel
   -> quyet dinh goi ton kho / ticket
```

Tuc la:

- image pipeline khong bi bo
- nhung no khong tu tra loi nua
- no chi co vai tro lam giau context
- `AI Agent Phase 1` tro thanh bo nao trung tam

## 4. Feasibility

### 4.1. Muc do kha thi

```text
Rat kha thi
```

vi workflow cua ban da co san:

- parser text + image
- customer buffer
- image embedding service
- product vector db
- rerank logic
- AI Agent text
- carousel output

Ban khong can viet lai he thong tu dau.

### 4.2. Muc do rui ro

```text
Trung binh
```

Rui ro khong nam o mat ky thuat, ma nam o:

- merge context cho dep
- giu item data khong bi mat
- tranh cho `AI Agent` phan hoi dai dong
- tranh loop goi tool qua nhieu

## 5. Nen Bo Node Nao

Neu doi sang kien truc "AI Agent dieu phoi trung tam", nen bo cach de image branch tu tra loi rieng.

Ban nen bo hoac ngung dung cac node sau trong nhanh anh:

- `Set Product Match Reply`
- `Set No Match Reply`
- `Set Invalid Image Reply`
- `HTTP Reply Facebook Text` trong nhanh anh
- `If Has Good Match`

Ly do:

- cac node nay dang tu render response rieng cho image branch
- khi gom ve `AI Agent` thi response text nen do 1 noi duy nhat sinh ra

Neu can giai doan chuyen tiep, co the doi ten `Set Invalid Image Reply` thanh:

- `Edit Fields Agent Input Image Failed`

va noi vao `AI Agent`, khong noi vao `HTTP Reply Facebook Text` nua.

## 6. Nen Giu Node Nao

Ban nen giu nguyen cac node sau:

- `If Has Image Attachment`
- `Set Customer Image Payload`
- `HTTP Embed Customer Image`
- `If Customer Embedding Valid`
- `PG Search Top K Products`
- `Set Facebook Product Carousel`
- `HTTP Reply Facebook Carousel`

Ly do:

- day la phan enrichment + output chuan
- rat hop de agent dung lai

Luu y quan trong:

- `Set Customer Query Vector`: giu tam neu `PG Search Top K Products` cua ban hien van can field `query_vector`
- `Code Rerank Candidates`: chi giu tam neu ban van can rerank ngoai AI
- muc tieu cuoi cung la:
  - bo `Set Customer Query Vector` sau khi sua query Postgres doc truc tiep `embedding`
  - bo `Code Rerank Candidates` neu `AI Agent` se tu danh gia danh sach candidate

## 7. Nen Them Node Nao

Ban nen them cac node moi sau de dong bo nhanh anh voi `phase 1`.

### 7.1. Node `Edit Fields Agent Input Image Failed`

Node nay thay vai tro cua `Set Invalid Image Reply` cu.

Muc dich:

- khong reply ngay
- bien loi image thanh context cho `AI Agent`

Field nen co:

- `image_analysis_status = failed`
- `agent_prompt`
- va nen `Include Other Input Fields`

`agent_prompt` nen co:

```text
Current message: ...
Previous customer stage: ...
Previous lead status: ...
Image analysis status: failed
The uploaded image could not be embedded or read.
```

### 7.2. Node `Aggregate Image Candidates`

Node nay chi can khi `PG Search Top K Products` tra ra `nhieu row`.

Muc dich:

- gom nhieu candidate thanh `1 item`
- dua ve cho `AI Agent` doc 1 lan

Neu `PG Search Top K Products` da tra san 1 row co field `candidates`, co the bo node nay.

### 7.3. Node `Edit Fields Agent Input Image Search`

Node nay thay vai tro cua `Set Product Match Reply` va `Set No Match Reply`.

Muc dich:

- khong tu quyet dinh match/hay no match bang IF rieng
- dua toan bo candidate ve cho `AI Agent`

Field nen co:

- `image_analysis_status = matched_candidates`
- `agent_prompt`
- va nen `Include Other Input Fields`

`agent_prompt` nen co:

```text
Current message: ...
Previous customer stage: ...
Previous lead status: ...
Image analysis status: matched_candidates
Image candidates JSON: [...]
```

### 7.4. Node `AI Agent Phase 1`

Day la `AI Agent` trung tam.

Node nay se:

- doc text cua khach
- doc image context neu co
- suy luan san pham phu hop nhat
- quyet dinh co gui carousel khong
- quyet dinh co can hoi them anh ro hon khong
- cap nhat lead qualification trong structured output

Luu y:

- prompt cua node nay nen dung `={{ $json.agent_prompt }}`
- khong dung lai `={{ $json.message_text }}` nua

## 8. Kien Truc Moi De Xuat

Day la flow minh khuyen dung.

```text
Webhook
-> Code in JavaScript1
-> If Has Image Attachment
   -> false
      -> Edit Fields Agent Input Text
      -> AI Agent Phase 1
      -> HTTP Reply Facebook Text

   -> true
      -> Set Customer Image Payload
      -> HTTP Embed Customer Image
      -> If Customer Embedding Valid
         -> false
            -> Edit Fields Agent Input Image Failed
            -> AI Agent Phase 1
            -> HTTP Reply Facebook Text

         -> true
            -> Set Customer Query Vector (tam thoi neu query can)
            -> PG Search Top K Products
            -> Aggregate Image Candidates (neu can)
            -> Edit Fields Agent Input Image Search
            -> AI Agent Phase 1
            -> HTTP Reply Facebook Text
            -> If Has Carousel Elements
               -> true
                  -> Set Facebook Product Carousel
                  -> HTTP Reply Facebook Carousel
```

Luu y:

- neu `PG Search Top K Products` da tra san 1 row co field `candidates`, ban co the bo `Aggregate Image Candidates`
- trong kien truc moi, `AI Agent Phase 1` la noi duy nhat sinh reply text
- nhanh anh chi lam enrichment, khong tu tra loi

## 9. Trong Kien Truc Moi, AI Agent Se Nhan Gi

`AI Agent Phase 1` se nhan item co dang nhu sau:

```json
{
  "sender_id": "2664...",
  "message_text": "giay nay la gi vay",
  "has_image_attachment": true,
  "image_url": "https://lookaside.fbsbx.com/...",
  "image_analysis_status": "matched_candidates",
  "candidates": [
    {
      "product_id": 39110350,
      "image_url": "https://pos.nvncdn.com/...",
      "metadata": {
        "title": "Giay Chay Dia Hinh Nam Norda 001A",
        "brand": "Norda",
        "category": "Giay chay trail"
      },
      "vector_similarity": 0.82
    }
  ],
  "agent_prompt": "Current message: ...\nPrevious customer stage: ...\nImage analysis status: matched_candidates\nImage candidates JSON: [...]"
}
```

Nho vay, agent khong can tu lam embedding nua.

No chi can:

- doc ket qua
- suy luan
- quyet dinh

## 10. Co Nen Them Fallback Vision AI Khong

Co, nhung chi nen them khi `visual_confidence` thap.

Phuong an dung:

```text
If visual_confidence < 0.65
-> goi 1 node vision fallback
-> tra them goi y hoac xin anh ro hon
```

Fallback co the la:

- 1 `AI Agent` vision rieng
- hoac 1 HTTP node goi multimodal model

Day la cho phu hop de dung "sub-ai agent".

Khong nen de sub-ai agent thay the embedding search.

Nen de no lam:

- fallback
- giai thich
- hoi tiep thong minh

## 11. Chot Kien Nghi

Kien nghi cuoi cung:

```text
Khong doi sang mo hinh "AI Agent tu tuan tu goi tat ca buoc nhan dien anh".
Nen doi sang mo hinh "image pipeline lam enrichment, AI Agent lam orchestration".
```

Tuc la:

- giu `HTTP Embed Customer Image`
- giu `PG Search Top K Products`
- chi giu tam `Set Customer Query Vector` neu query chua doi
- chi giu tam `Code Rerank Candidates` neu chua muon bo ngay
- bo cach image branch tu reply rieng
- them `AI Agent Phase 1` o lop tren
- them `If Has Carousel Elements`
- dung `Set Facebook Product Carousel` + `HTTP Reply Facebook Carousel` nhu nhanh output

Day la cach can bang tot nhat giua:

- do chinh xac
- do on dinh
- chi phi
- toc do
- kha nang mo rong
