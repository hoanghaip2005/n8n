# Ke Hoach Chuyen Pinecone Sang PostgreSQL

Tai lieu nay chot huong chuyen nhanh text-product retrieval tu `Pinecone Vector Store1` sang PostgreSQL de dong bo hon voi he thong hien tai.

Muc tieu:

- de `product_images` tro thanh nguon du lieu san pham chinh
- giu `product_image_vectors` cho nhan dien anh
- bo `Pinecone Vector Store1` o nhanh khach hoi san pham bang text
- giam lap san pham va giam tinh trang goi sai nhu cau

## 1. Ket Luan Kien Truc

Kien truc nen tach ro:

```text
Khach hoi bang text ve san pham
-> AI Agent
   -> Tool PG_Search_Products
-> tra ve san pham tu PostgreSQL

Khach gui anh san pham
-> HTTP embed image
-> PG Search Top K Products
-> AI Agent
-> tra ve san pham gan nhat theo image vector
```

Y nghia:

- text search san pham: dung Postgres catalog search
- image search san pham: dung `product_image_vectors`
- khong dung Pinecone nua cho product text retrieval

## 2. Bang Nen Giu

Nen giu:

- `product_images`
- `product_image_vectors`
- `fb_raw_events`
- `fb_conversation_buffer`
- `customer_phase_state`
- `lead_handoff_queue`
- `zalo_oa_tokens`
- `nhanh_api_tokens`

Can ra soat them truoc khi xoa:

- `order_tickets`

Ly do:

- hien tai trong `Workflow.json` khong thay luong chinh dang goi `order_tickets`
- nhung neu van con workflow khac dung, khong nen xoa voi vang

## 3. Vi Sao Pinecone Gay Lap San Pham

`Pinecone Vector Store1` hien dang gap 4 van de:

1. `toolDescription` qua chung chung, khong ep AI tim dung san pham can tra loi
2. retrieval semantic rat de tra lai nhom san pham top dau lap di lap lai
3. khong co buoc `dedupe` theo `product_id` hoac `website_url`
4. khong co input loai tru cac san pham da goi y o cac luot truoc

Vi vay du prompt co noi "khong gui lai hinh anh da chia se", tool van co the tra lai cung mot nhom san pham.

## 4. Giai Phap Toi Uu

Khuyen nghi dung 2 lop:

### Lop 1. Search chinh xac bang PostgreSQL

Dung function:

```text
public.search_product_catalog(...)
```

Function nay:

- doc tu `product_images`
- search theo `title`, `brand`, `category`, `size`, `status`
- score theo:
  - exact title
  - contains
  - trigram similarity
- `dedupe` theo `website_url`, fallback ve `product_id`
- tra toi da 10 ket qua

### Lop 2. Vector chi dung cho nhan dien anh

Giu:

- `product_image_vectors`

Khong dung no de search text san pham.

Ly do:

- bang nay la vector cua anh
- khach hoi bang text thi dung image vector se khong chuan

## 5. SQL Can Chay

Chay 2 file:

- [product_image_vectors.sql](/Users/phamhoanghai/n8n/supabase/product_image_vectors.sql)
- [product_catalog_search.sql](/Users/phamhoanghai/n8n/supabase/product_catalog_search.sql)

Y nghia:

- `product_image_vectors.sql`: chuan hoa lai schema anh vector dang duoc workflow dung
- `product_catalog_search.sql`: tao function search catalog va index trigram cho text search

## 6. Workflow Moi De Xuat

### 6.1 Bo tool Pinecone khoi AI Agent

Trong main workflow:

- ngat `Pinecone Vector Store1` khoi `AI Agent`
- khong de agent dung Pinecone cho text product retrieval nua

Neu ban can huong dan chi tiet cach tao tung node trong n8n, xem them:

- [huong-dan-tool-pg-search-products.md](/Users/phamhoanghai/n8n/docs/huong-dan-tool-pg-search-products.md)

### 6.2 Tao sub-workflow moi

Ten goi y:

```text
PG_Search_Products
```

Luong:

```text
Execute Workflow Trigger
-> PG Search Product Catalog
-> Set Normalize Product Result
```

Input:

- `product_query`
- `max_results`
- `exclude_product_ids_json`
- `exclude_website_urls_json`

Output:

```json
{
  "ok": true,
  "product_query": "norda 001",
  "total": 3,
  "items": [
    {
      "product_id": 39109709,
      "title": "Giay Chay Dia Hinh Nam Norda 001A - Horizon",
      "image_url": "https://...",
      "website_url": "https://...",
      "brand": "NORDA",
      "category": "Giay Chay Dia Hinh Nam",
      "size": "42",
      "search_score": 100,
      "match_type": "exact_title"
    }
  ]
}
```

### 6.3 SQL cho node `PG Search Product Catalog`

Node:

```text
PG Search Product Catalog
```

`Operation`:

```text
Execute Query
```

`Query`:

```sql
select *
from public.search_product_catalog(
  $1::text,
  $2::integer,
  coalesce($3::bigint[], '{}'::bigint[]),
  coalesce($4::text[], '{}'::text[])
);
```

`Query Replacement`:

```js
={{
[
  $json.product_query || '',
  Number($json.max_results || 5),
  Array.isArray($json.exclude_product_ids) ? $json.exclude_product_ids : [],
  Array.isArray($json.exclude_website_urls) ? $json.exclude_website_urls : [],
]
}}
```

## 7. Description Cho Tool `PG_Search_Products`

Description de AI dung dung:

```text
Dung tool nay khi khach hoi ve san pham, muon xem mau, muon goi y san pham, hoi form giay, hoi giay nao phu hop, hoi san pham theo nhu cau, hoac can tim san pham theo ten / loai / thuong hieu / size. Tool nay tim san pham truc tiep tu PostgreSQL catalog va tra ve danh sach san pham da duoc dedupe. Khong dung tool nay de kiem tra ton kho. Neu da tung goi y san pham truoc do, hay truyen exclude_product_ids hoac exclude_website_urls de tranh lap lai.
```

## 8. Cach Giam Lap San Pham

Can lam 2 lop:

### Lop 1. Dedupe ngay trong SQL

Da co trong function:

- `dedupe` theo `website_url`
- fallback theo `product_id`

### Lop 2. Exclude cac san pham vua goi y

Nen truyen them:

- `exclude_product_ids`
- `exclude_website_urls`

Ban co 2 cach:

1. Nhanh gon:
- parse tu `output.product[].website_url`
- dung trong 1-2 luot hoi dap lien tiep

2. Ben vung hon:
- them vao `customer_phase_state` 2 cot:
  - `last_suggested_product_ids jsonb`
  - `last_suggested_website_urls jsonb`

Khuyen nghi:

- phase 1: lam cach 1 cho nhanh
- phase 2: moi them 2 cot state neu can

## 9. Co Nen Dung PG Vector Store Khong

Co, nhung khong phai buoc dau tien.

Thu tu hop ly:

### Giai doan 1. Dung PostgreSQL text search thuong

Nen lam truoc vi:

- de debug
- dung ngay voi `product_images`
- giam lap san pham nhanh nhat
- khong can them bang vector text moi

### Giai doan 2. Neu van can semantic search cho text

Moi tao them:

- `product_text_vectors`

Luc do moi can nhac:

- `PG Vector Store`
- hoac query `pgvector` trong Postgres

Khong nen dung `product_image_vectors` de thay the text search.

## 10. Trinh Tu Trien Khai Khuyen Nghi

1. Chay SQL:
- `product_image_vectors.sql`
- `product_catalog_search.sql`

2. Tao sub-workflow:
- `PG_Search_Products`

3. Noi tool moi vao `AI Agent`

4. Tat ket noi:
- `Pinecone Vector Store1 -> AI Agent`

5. Sua prompt:
- khi khach hoi san pham / mau / form / giay phu hop -> uu tien goi `PG_Search_Products`
- khi khach hoi ton kho -> goi `Nhanh_Check_Inventory_By_Location`

6. Test 5 case:
- hoi ten san pham cu the
- hoi theo thuong hieu
- hoi theo nhu cau chung
- hoi tiep lan 2 de xem co lap san pham khong
- hoi ton kho sau khi da co san pham

## 11. Ket Luan Chot

Voi he thong hien tai, giai phap tot nhat la:

- `product_images` = catalog chinh
- `product_image_vectors` = chi cho nhan dien anh
- `PostgreSQL text search` = thay `Pinecone Vector Store1`

Huong nay gon hon, dong bo hon, va de kiem soat hon so voi tiep tuc giu Pinecone cho nhom text query san pham.
