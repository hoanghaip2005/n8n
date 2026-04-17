# Huong Dan Tool PG_Search_Products

Tai lieu nay huong dan chi tiet tung node de thay `Pinecone Vector Store1` bang sub-workflow PostgreSQL cho bai toan khach hoi san pham bang text.

Muc tieu:

- bo `Pinecone Vector Store1` khoi nhanh hoi san pham bang text
- tim san pham truc tiep trong `public.product_images`
- dedupe ket qua theo `website_url`, fallback theo `product_id`
- de `AI Agent` goi 1 tool duy nhat cho product text search: `PG_Search_Products`

Neu ban chua chay SQL, chay truoc:

- [product_catalog_search.sql](/Users/phamhoanghai/n8n/supabase/product_catalog_search.sql)

## 1. Kien Truc Chot

```text
Main workflow
Webhook / Buffer / Context
-> AI Agent
   -> Call n8n Workflow Tool: PG_Search_Products

Sub-workflow: PG_Search_Products
Execute Sub-workflow Trigger
-> Edit Fields Normalize Search Input
-> If Has Product Query
   -> false -> Set Missing Query Result
   -> true  -> PG Search Product Catalog
            -> Edit Fields Final Product Search Result
```

Voi bai toan nay:

- khong can Code node
- khong can Pinecone
- khong can PG Vector Store cho text search o giai doan dau

## 2. Truoc Khi Tao Workflow

Ban can dam bao SQL sau da ton tai:

- function `public.search_product_catalog(...)`
- function `public.vi_normalize(...)`
- cac trigram index tren `product_images`

Neu query nay chay duoc trong Postgres thi workflow se dung duoc:

```sql
select *
from public.search_product_catalog('norda 001', 5, '{}'::bigint[], '{}'::text[]);
```

## 3. Tao Sub-workflow `PG_Search_Products`

Tao workflow moi, dat ten:

```text
PG_Search_Products
```

### Node 1. Execute Sub-workflow Trigger

Node:

```text
Execute Sub-workflow Trigger
```

Trong mot so ban n8n, node nay hien thi la:

```text
When Executed by Another Workflow
```

Thiet lap:

- `Input Data Mode`: `Define using fields below`

Them 4 input field:

1. `product_query`
- Type: `String`
- Required: `true`
- Description: `Ten, loai, thuong hieu, size hoac cum tu mo ta san pham khach dang hoi`

2. `max_results`
- Type: `Number`
- Required: `false`
- Default: `5`
- Description: `So ket qua toi da can tra ve`

3. `exclude_product_ids_json`
- Type: `String`
- Required: `false`
- Default:

```text
[]
```

- Description: `JSON array cac product_id can loai tru de tranh lap lai`

4. `exclude_website_urls_json`
- Type: `String`
- Required: `false`
- Default:

```text
[]
```

- Description: `JSON array cac website_url can loai tru de tranh lap lai`

Output test mong doi:

```json
{
  "product_query": "giay norda 001",
  "max_results": 5,
  "exclude_product_ids_json": "[]",
  "exclude_website_urls_json": "[]"
}
```

### Node 2. Edit Fields Normalize Search Input

Node:

```text
Edit Fields Normalize Search Input
```

Mode:

```text
Manual Mapping
```

`Include Other Input Fields`:

- `off`

Them cac field sau:

1. `product_query`
- Type: `String`
- Value:

```js
={{ String($json.product_query || '').trim() }}
```

2. `max_results`
- Type: `Number`
- Value:

```js
={{ Math.max(1, Math.min(Number($json.max_results || 5), 10)) }}
```

3. `exclude_product_ids`
- Type: `Array`
- Value:

```js
={{
(() => {
  const raw = $json.exclude_product_ids_json;

  if (Array.isArray(raw)) {
    return raw.map((v) => Number(v)).filter((v) => Number.isFinite(v));
  }

  try {
    const parsed = JSON.parse(String(raw || '[]'));
    return Array.isArray(parsed)
      ? parsed.map((v) => Number(v)).filter((v) => Number.isFinite(v))
      : [];
  } catch {
    return [];
  }
})()
}}
```

4. `exclude_website_urls`
- Type: `Array`
- Value:

```js
={{
(() => {
  const raw = $json.exclude_website_urls_json;

  if (Array.isArray(raw)) {
    return raw.map((v) => String(v || '').trim()).filter(Boolean);
  }

  try {
    const parsed = JSON.parse(String(raw || '[]'));
    return Array.isArray(parsed)
      ? parsed.map((v) => String(v || '').trim()).filter(Boolean)
      : [];
  } catch {
    return [];
  }
})()
}}
```

Node nay co vai tro:

- lam sach `product_query`
- ep `max_results` vao khoang 1-10
- parse 2 field JSON string thanh array that su

Output mong doi:

```json
{
  "product_query": "giay norda 001",
  "max_results": 5,
  "exclude_product_ids": [],
  "exclude_website_urls": []
}
```

### Node 3. If Has Product Query

Node:

```text
If Has Product Query
```

Them 1 condition expression:

```js
={{ !!String($json.product_query || '').trim() }}
```

So sanh:

- `is true`

Neu n8n bao loi boolean/string:

- bat `Convert types where required`

Y nghia:

- `true`: co query hop le -> cho phep tim san pham
- `false`: query rong -> tra ket qua rong co thong bao loi nhe

### Node 4A. Set Missing Query Result

Noi tu nhanh `false` cua `If Has Product Query`.

Node:

```text
Set Missing Query Result
```

Mode:

```text
Manual Mapping
```

Them cac field sau:

1. `ok`
- Type: `Boolean`
- Value: `false`

2. `error_code`
- Type: `String`
- Value:

```text
PRODUCT_QUERY_MISSING
```

3. `message`
- Type: `String`
- Value:

```text
Chua co product_query de tim san pham trong PostgreSQL
```

4. `product_query`
- Type: `String`
- Value:

```js
={{ $('Edit Fields Normalize Search Input').first().json.product_query }}
```

5. `total`
- Type: `Number`
- Value:

```js
={{ 0 }}
```

6. `items`
- Type: `Array`
- Value:

```js
={{ [] }}
```

Output mong doi:

```json
{
  "ok": false,
  "error_code": "PRODUCT_QUERY_MISSING",
  "message": "Chua co product_query de tim san pham trong PostgreSQL",
  "product_query": "",
  "total": 0,
  "items": []
}
```

### Node 4B. PG Search Product Catalog

Noi tu nhanh `true` cua `If Has Product Query`.

Node:

```text
PG Search Product Catalog
```

Thiet lap:

- `Credential`: Postgres account cua ban
- `Operation`: `Execute Query`

`Query`:

```sql
with result as (
  select *
  from public.search_product_catalog(
    $1::text,
    $2::integer,
    coalesce($3::bigint[], '{}'::bigint[]),
    coalesce($4::text[], '{}'::text[])
  )
)
select
  $1::text as product_query,
  count(*)::int as total,
  coalesce(
    jsonb_agg(
      jsonb_build_object(
        'product_id', product_id,
        'title', title,
        'image_url', image_url,
        'website_url', website_url,
        'status', status,
        'brand', brand,
        'category', category,
        'size', size,
        'search_score', search_score,
        'match_type', match_type
      )
      order by search_score desc, title asc
    ),
    '[]'::jsonb
  ) as items
from result;
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

Node nay se tra ve 1 row duy nhat, vi query da `jsonb_agg` san danh sach san pham.

Output mong doi:

```json
{
  "product_query": "giay norda 001",
  "total": 3,
  "items": [
    {
      "product_id": 39109709,
      "title": "Giay Chay Dia Hinh Nam Norda 001A - Horizon",
      "image_url": "https://...",
      "website_url": "https://...",
      "status": "Dang ban",
      "brand": "NORDA",
      "category": "Giay Chay Dia Hinh Nam",
      "size": "42",
      "search_score": 100,
      "match_type": "contains"
    }
  ]
}
```

### Node 5. Edit Fields Final Product Search Result

Node:

```text
Edit Fields Final Product Search Result
```

Mode:

```text
Manual Mapping
```

`Include Other Input Fields`:

- `off`

Them cac field:

1. `ok`
- Type: `Boolean`
- Value: `true`

2. `product_query`
- Type: `String`
- Value:

```js
={{ String($json.product_query || '').trim() }}
```

3. `total`
- Type: `Number`
- Value:

```js
={{ Number($json.total || 0) }}
```

4. `items`
- Type: `Array`
- Value:

```js
={{
(() => {
  if (Array.isArray($json.items)) {
    return $json.items;
  }

  if (typeof $json.items === 'string') {
    try {
      const parsed = JSON.parse($json.items);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }

  return [];
})()
}}
```

5. `message`
- Type: `String`
- Value:

```js
={{ Number($json.total || 0) > 0 ? '' : 'Khong tim thay san pham phu hop trong catalog PostgreSQL' }}
```

Output chot mong doi:

```json
{
  "ok": true,
  "product_query": "giay norda 001",
  "total": 3,
  "items": [
    {
      "product_id": 39109709,
      "title": "Giay Chay Dia Hinh Nam Norda 001A - Horizon",
      "image_url": "https://...",
      "website_url": "https://...",
      "status": "Dang ban",
      "brand": "NORDA",
      "category": "Giay Chay Dia Hinh Nam",
      "size": "42",
      "search_score": 100,
      "match_type": "contains"
    }
  ],
  "message": ""
}
```

Node cuoi cung cua sub-workflow phai la:

```text
Edit Fields Final Product Search Result
```

vi `Call n8n Workflow Tool` se doc output tu node cuoi.

## 4. Noi Vao Main Workflow

Sau khi tao xong `PG_Search_Products`, vao workflow chinh va lam 3 viec:

### Viec 1. Ngat Pinecone khoi AI Agent

Trong canvas chinh:

- ngat `Pinecone Vector Store1` khoi `AI Agent`

Tam thoi ban co the:

- de node do lai de rollback neu can
- nhung khong noi vao AI Agent nua

### Viec 2. Tao node `Call 'PG_Search_Products'`

Node:

```text
Call n8n Workflow Tool
```

Dat ten:

```text
Call 'PG_Search_Products'
```

Thiet lap:

- `Source`: `Database`
- `Workflow`: `PG_Search_Products`

`Description`:

```text
Dung tool nay khi khach hoi ve san pham, muon xem mau, muon goi y san pham, hoi form giay, hoi giay nao phu hop, hoi san pham theo ten / loai / thuong hieu / size, hoac can tim san pham de tu van. Tool nay tim san pham truc tiep tu PostgreSQL catalog va tra ve danh sach san pham da duoc dedupe. Khong dung tool nay de kiem tra ton kho. Neu khach hoi con hang, con size, ton kho theo khu vuc thi dung tool check inventory.
```

### Viec 3. Them Workflow Inputs cho tool

Trong phan `Workflow Inputs`, them 4 field:

1. `product_query`
- Value:

```js
{{ $fromAI('product_query', 'Ten / loai / thuong hieu / size / cum tu mo ta san pham khach dang hoi', 'string') }}
```

2. `max_results`
- Value:

```js
{{ 5 }}
```

3. `exclude_product_ids_json`
- Value:

```js
{{ '[]' }}
```

4. `exclude_website_urls_json`
- Value:

```js
{{ '[]' }}
```

## 5. Luu Y Rat Quan Trong Khi Test

### Truong hop 1. Test trong `From AI` thay `undefined`

Day la binh thuong.

Ly do:

- `$fromAI(...)` chi co gia tri khi `AI Agent` thuc su goi tool
- neu ban mo node tool va bam preview truc tiep, n8n chua co context AI nen thuong hien `undefined`

Neu muon test tay:

- chuyen sang tab `Mapping`
- tu dien gia tri thu cong

Vi du:

```json
{
  "product_query": "giay norda 001",
  "max_results": 5,
  "exclude_product_ids_json": "[]",
  "exclude_website_urls_json": "[]"
}
```

### Truong hop 2. Tool goi duoc nhung tra rong

Check lan luot:

1. SQL `product_catalog_search.sql` da chay chua
2. Bang `product_images` co du lieu chua
3. `is_active` cua san pham co dang la `true` khong
4. `title` va `image_url` co bi rong khong

### Truong hop 3. Van bi lap san pham

Ban lam theo thu tu sau:

1. Trien khai `PG_Search_Products` truoc
2. Test lai
3. Neu van lap, moi them exclude list vao state

Giai doan dau chua can lam phuc tap.

## 6. Test Mau Cho Sub-workflow

### Test 1. Tim theo ten san pham

Input:

```json
{
  "product_query": "Giay Chay Dia Hinh Nam Norda 001A",
  "max_results": 5,
  "exclude_product_ids_json": "[]",
  "exclude_website_urls_json": "[]"
}
```

### Test 2. Tim theo thuong hieu

Input:

```json
{
  "product_query": "norda",
  "max_results": 5,
  "exclude_product_ids_json": "[]",
  "exclude_website_urls_json": "[]"
}
```

### Test 3. Tim theo nhu cau mo ta

Input:

```json
{
  "product_query": "giay trail norda size 42",
  "max_results": 5,
  "exclude_product_ids_json": "[]",
  "exclude_website_urls_json": "[]"
}
```

### Test 4. Loai tru san pham da goi y

Input:

```json
{
  "product_query": "norda",
  "max_results": 5,
  "exclude_product_ids_json": "[39109709,39109710]",
  "exclude_website_urls_json": "[\"https://activstore.vn/giay-chay-dia-hinh-nam-norda-001a-horizon-p39109709.html\"]"
}
```

## 7. Sau Khi Chuyen Xong

Khi da test on dinh, ban co the lam gon:

1. tat hoac go `Pinecone Vector Store1` khoi `AI Agent`
2. giu `product_image_vectors` cho nhanh nhan dien anh
3. tiep tuc dung `PG Search Top K Products` cho image search
4. de text product retrieval chay bang `PG_Search_Products`

## 8. Ket Luan Chot

Cho he thong hien tai, luong gon va ben nhat la:

- `product_images` = catalog san pham chinh
- `product_image_vectors` = chi dung cho nhan dien anh
- `PG_Search_Products` = tool text search thay Pinecone

Neu ban muon, buoc tiep theo toi co the viet tiep cho ban phan:

- cach sua `AI Agent` prompt de bat buoc uu tien `PG_Search_Products`
- cach luu `exclude_product_ids` va `exclude_website_urls` vao Postgres state de tranh lap san pham giua nhieu turn
