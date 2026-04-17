# Huong Dan Tool Nhanh_Check_Inventory

Tai lieu nay huong dan dung `Call n8n Workflow Tool` de cho `AI Agent` goi 1 sub-workflow chuyen check ton kho tren Nhanh.

Neu ban can check ton kho theo kho / khu vuc khach hang, xem them:

- [huong-dan-ton-kho-theo-khu-vuc-nhanh.md](/Users/phamhoanghai/n8n/docs/huong-dan-ton-kho-theo-khu-vuc-nhanh.md)

Muc tieu:

- bo `HTTP Request4` dang noi truc tiep vao `AI Agent`
- bo luong get Nhanh token cu trong main flow
- tai su dung node `PG Get Nhanh Token`
- de `AI Agent` chi goi 1 tool duy nhat: `Nhanh_Check_Inventory`
- sau nay co the copy mau nay cho cac tool khac nhu `Nhanh_Get_Order`, `Nhanh_Get_Product`, `Nhanh_Get_Customer`

## 1. Ket Luan Kien Truc

Khuyen nghi dung kien truc sau:

```text
Main workflow
Webhook / Buffer / Context
-> AI Agent
   -> Call n8n Workflow Tool: Nhanh_Check_Inventory

Sub-workflow: Nhanh_Check_Inventory
Execute Sub-workflow Trigger
-> PG Get Nhanh Token
-> If Has Nhanh Token
   -> true  -> HTTP Nhanh Product Inventory
            -> Code Normalize Inventory Result
   -> false -> Set Missing Token Result
```

Voi bai toan nay:

- khong can `sub AI Agent`
- khong can loop refresh token
- khong can `Set Active Nhanh Token` neu ban muon gon

`Set Active Nhanh Token` chi la node phu tro doc expression de hon. Neu muon gon workflow thi xoa duoc.

## 2. Vi Sao Nen Lam Theo Cach Nay

`AI Agent` nen quyet dinh:

- co can check ton kho khong
- can check san pham nao

Sub-workflow nen phu trach:

- lay token tu Postgres
- gan `appId`, `businessId`, `accessToken`
- goi API Nhanh
- tra output da duoc chuan hoa ve cho `AI Agent`

Loai bo duoc cac van de:

- workflow chinh bi dai va roi
- moi HTTP Nhanh lai phai tu viet lai auth
- `AI Agent` phai quan ly token

## 3. Workflow Con `Nhanh_Check_Inventory`

Tao workflow moi, dat ten:

```text
Nhanh_Check_Inventory
```

### Node 1. Execute Sub-workflow Trigger

Node:

```text
Execute Sub-workflow Trigger
```

Tim trong n8n co the hien thi ten:

```text
When Executed by Another Workflow
```

Thiet lap:

- `Input Data Mode`: `Define using fields below`

Them 2 input field:

1. `product_query`
- Type: `String`
- Required: `true`
- Mo ta: `Ten hoac ma san pham can kiem tra ton kho`

2. `max_results`
- Type: `Number`
- Required: `false`
- Default: `5`
- Mo ta: `So ket qua ton kho toi da can tra ve`

Output mong doi tu node nay:

```json
{
  "product_query": "Norda 001A",
  "max_results": 5
}
```

### Node 2. PG Get Nhanh Token

Tai su dung logic tu node hien tai.

Node:

```text
PG Get Nhanh Token
```

Thiet lap:

- `Operation`: `Select`
- `Schema`: `public`
- `Table`: `nhanh_api_tokens`
- `Limit`: `1`

`Where`:

- `column`: `token_key`
- `value`: `nhanh_main`

Node nay can tra ve 1 row co dang:

```json
{
  "token_key": "nhanh_main",
  "app_id": 77078,
  "business_id": 30923,
  "access_token": "....",
  "secret_key": "....",
  "expires_at": "2027-04-10T13:46:03.116Z"
}
```

### Node 3. If Has Nhanh Token

Node:

```text
If Has Nhanh Token
```

Dung 1 condition expression duy nhat:

```js
={{ !!String($json.access_token || '').trim() && !!String($json.app_id || '').trim() && !!String($json.business_id || '').trim() }}
```

So sanh:

- `is true`

Neu n8n bao loi kieu boolean/string:

- bat `Convert types where required`

Y nghia:

- `true`: co du auth context de goi API
- `false`: thieu token hoac thieu `app_id` hoac `business_id`

### Node 4A. Set Missing Token Result

Noi tu nhanh `false` cua `If Has Nhanh Token`.

Node:

```text
Set Missing Token Result
```

Mode:

```text
Manual Mapping
```

Them cac field:

1. `ok`
- Type: `Boolean`
- Value: `false`

2. `error_code`
- Type: `String`
- Value:

```text
NHANH_TOKEN_MISSING
```

3. `message`
- Type: `String`
- Value:

```text
Khong tim thay access token Nhanh hop le trong Postgres
```

4. `product_query`
- Type: `String`
- Value:

```js
={{ $('Execute Sub-workflow Trigger').first().json.product_query }}
```

5. `items`
- Type: `Array`
- Value:

```js
={{ [] }}
```

### Node 4B. HTTP Nhanh Product Inventory

Noi tu nhanh `true` cua `If Has Nhanh Token`.

Node:

```text
HTTP Nhanh Product Inventory
```

Thiet lap:

- `Method`: `POST`
- `URL`:

```js
={{ `https://pos.open.nhanh.vn/v3.0/product/inventory?appId=${$('PG Get Nhanh Token').first().json.app_id}&businessId=${$('PG Get Nhanh Token').first().json.business_id}` }}
```

- `Authentication`: `None`
- `Send Headers`: `true`

Headers:

1. `Authorization`

```js
={{ $('PG Get Nhanh Token').first().json.access_token }}
```

2. `Content-Type`

```text
application/json
```

- `Send Body`: `true`
- `Body Content Type`: `JSON`
- `Specify Body`: `Using JSON`

Co 2 cach nhap body.

#### Cach A. Entire field la expression

Neu o JSON editor cua ban dang bat `Expression` cho ca field, dung:

```js
={{ {
  filters: {
    name: String($('Execute Sub-workflow Trigger').first().json.product_query || '').trim(),
  },
  paginator: {
    size: Number($('Execute Sub-workflow Trigger').first().json.max_results || 5),
  },
  dataOptions: {},
} }}
```

#### Cach B. Raw JSON text

Neu o JSON editor cua ban dang la dang raw JSON text giong node `HTTP Request4` hien tai, dung dung mau nay:

```json
{
  "filters": {
    "name": "{{ String($('Execute Sub-workflow Trigger').first().json.product_query || '').trim() }}"
  },
  "paginator": {
    "size": 5
  },
  "dataOptions": {}
}
```

Cho phase 1, minh khuyen de `size` co dinh la `5` de on dinh hon.

`Settings`:

- `On Error`: `Continue`

Ly do:

- neu Nhanh tra loi 4xx/5xx, workflow van khong vo execution fail ngay
- ta se tu chuyen loi do thanh JSON co cau truc o node sau

### Node 5. Code Normalize Inventory Result

Noi sau `HTTP Nhanh Product Inventory`.

Node:

```text
Code Normalize Inventory Result
```

Mode:

```text
Run Once for Each Item
```

Code:

```javascript
const triggerInput = $('Execute Sub-workflow Trigger').first().json || {};
const productQuery = String(triggerInput.product_query || '').trim();

if ($json.error) {
  return [
    {
      json: {
        ok: false,
        error_code: 'NHANH_API_ERROR',
        message: String($json.error),
        product_query: productQuery,
        items: [],
      },
    },
  ];
}

const root = $json?.data ?? $json?.result ?? $json ?? {};
const rawItems = Array.isArray(root?.products)
  ? root.products
  : Array.isArray(root?.data)
    ? root.data
    : Array.isArray(root)
      ? root
      : [];

const items = rawItems.map((item) => {
  const inventory = item.inventory ?? {};

  return {
    id: item.id ?? item.productId ?? null,
    code: item.code ?? item.productCode ?? '',
    name: item.name ?? '',
    barcode: item.barcode ?? '',
    price: Number(item?.prices?.price ?? 0),
    remain: Number(inventory.remain ?? item.remain ?? 0),
    available: Number(inventory.available ?? item.available ?? 0),
    shipping: Number(inventory.shipping ?? item.shipping ?? 0),
    holding: Number(inventory.holding ?? item.holding ?? 0),
    damaged: Number(inventory.damaged ?? item.damaged ?? item.damage ?? 0),
    depots: inventory.depots ?? item.depots ?? [],
  };
});

return [
  {
    json: {
      ok: true,
      product_query: productQuery,
      total: items.length,
      items,
    },
  },
];
```

Output mong doi:

```json
{
  "ok": true,
  "product_query": "Norda 001A",
  "total": 2,
  "items": [
    {
      "id": 39110350,
      "code": "VH01",
      "name": "Giay Chay Dia Hinh Nam Norda 001A",
      "barcode": "",
      "price": 7500000,
      "remain": 3,
      "available": 2,
      "shipping": 1,
      "holding": 0,
      "damaged": 0,
      "depots": []
    }
  ]
}
```

## 4. Co Can `Set Active Nhanh Token` Khong

Khong bat buoc.

Ban co 2 lua chon:

### Lua chon A. Gon nhat

Khong dung `Set Active Nhanh Token`.

Node HTTP se doc truc tiep tu:

```text
$('PG Get Nhanh Token').first().json
```

Khuyen dung cho workflow con vi gon va de copy.

### Lua chon B. De doc hon

Them 1 node:

```text
Set Nhanh Auth Context
```

Fields:

- `nhanh_app_id`
- `nhanh_business_id`
- `nhanh_access_token`

Roi node HTTP doc tu node set nay.

Khuyen dung neu sau nay trong cung sub-workflow ban co nhieu HTTP Request.

Voi `Nhanh_Check_Inventory` hien tai, lua chon A la du.

## 5. Cai Tool Nay Vao AI Agent Cha

Sau khi tao xong sub-workflow, quay lai workflow chinh.

Xoa tool cu:

```text
HTTP Request4
```

Them node moi noi vao `AI Agent`:

```text
Call n8n Workflow Tool
```

Dat ten:

```text
Nhanh_Check_Inventory
```

### Cau hinh `Call n8n Workflow Tool`

`Description`:

```text
Dung tool nay khi khach hoi ton kho, con hang khong, con size khong, het hang chua, con bao nhieu, san pham nay co san khong. Dau vao la ten hoac ma san pham can kiem tra ton kho. Tool se tra ve danh sach ket qua voi cac truong remain, available, shipping, holding, damaged.
```

`Source`:

- `Database`

`Workflow`:

- chon workflow `Nhanh_Check_Inventory`

`Workflow Inputs`:

1. `product_query`

```js
={{ $fromAI('product_query', 'Ten hoac ma san pham can kiem tra ton kho tren Nhanh', 'string') }}
```

2. `max_results`

```js
={{ 5 }}
```

Neu muon AI duoc quyen tu doi so luong ket qua:

```js
={{ $fromAI('max_results', 'So ket qua toi da can tra ve, tu 1 den 10', 'number') }}
```

Nhung cho phase 1, de co dinh `5` la on dinh hon.

## 6. Cap Nhat Prompt Cho AI Agent

Trong `systemMessage` cua `AI Agent`, doi phan check ton kho thanh logic sau:

```text
Khi khach hoi ton kho, con hang khong, con size khong, het hang chua, con bao nhieu, bat buoc goi tool Nhanh_Check_Inventory.

Doc ket qua:
- available > 0: san pham con hang
- available = 0: san pham da het hoac tam het

Neu tool tra ve ok = false:
- khong duoc tu doan ton kho
- tra loi theo huong shop dang kiem tra he thong ton kho va se xac nhan lai
```

## 7. Truong Hop Nghiep Vu Can Cover

Tool nay can cover cac truong hop sau:

### Case 1. Token hop le, tim thay san pham

Tra ve:

- `ok = true`
- `items.length > 0`

### Case 2. Token hop le, khong tim thay san pham

Tra ve:

- `ok = true`
- `items = []`

AI Agent phai hieu day la:

- khong co ket qua phu hop tu Nhanh
- can hoi lai ten / ma san pham / gui anh

### Case 3. Thieu token

Tra ve:

- `ok = false`
- `error_code = NHANH_TOKEN_MISSING`

AI Agent khong duoc doan ton kho.

### Case 4. Nhanh API loi

Tra ve:

- `ok = false`
- `error_code = NHANH_API_ERROR`

AI Agent phai tra loi mem:

```text
Dạ em dang kiem tra ton kho tren he thong, em se xac nhan lai ngay cho anh/chi a.
```

## 8. Co Nen Them Retry Hoac Refresh Token Khong

Khong nen o phase hien tai.

Ly do:

- token Nhanh co han dai, theo docs la 1 nam
- Nhanh khong phai flow refresh token nhu Zalo
- runtime `401 -> lay token moi -> goi lai` se lam workflow roi hon rat nhieu

Khuyen nghi:

- coi token Nhanh la `long-lived config`
- luu san trong Postgres
- tool chi `select` token roi goi API

Sau nay neu muon an toan hon, them 1 workflow rieng:

```text
Cron -> PG Check Nhanh Token Expiry -> Alert truoc 30 ngay / 14 ngay / 7 ngay
```

## 9. Ban Toi Gian De Dung Ngay

Neu ban muon lam nhanh nhat, chi can 5 node trong workflow con:

```text
Execute Sub-workflow Trigger
-> PG Get Nhanh Token
-> If Has Nhanh Token
   -> false -> Set Missing Token Result
   -> true  -> HTTP Nhanh Product Inventory
            -> Code Normalize Inventory Result
```

Day la ban nen dung truoc.

## 10. Ban Nang Cao Cho Tuong Lai

Khi ban co them nhieu tool Nhanh, co the standard hoa output cua tat ca tool theo mau:

```json
{
  "ok": true,
  "error_code": "",
  "message": "",
  "data": {}
}
```

Luc do:

- `Nhanh_Check_Inventory`
- `Nhanh_Get_Product`
- `Nhanh_Get_Order`
- `Nhanh_Get_Customer`

deu co cung pattern:

```text
Trigger -> PG Token -> If Token -> HTTP -> Normalize
```

Rat de nhan ban va bao tri.

## 11. Tai Lieu Tham Khao

- n8n Call n8n Workflow Tool: https://docs.n8n.io/integrations/builtin/cluster-nodes/sub-nodes/n8n-nodes-langchain.toolworkflow/
- n8n Execute Sub-workflow Trigger: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.executeworkflowtrigger/
- n8n Sub-workflows: https://docs.n8n.io/flow-logic/subworkflows/
- Nhanh app auth: https://apidocs.nhanh.vn/app
- Nhanh product inventory: https://apidocs.nhanh.vn/v3/product/inventory
