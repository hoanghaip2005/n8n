# Huong Dan Ton Kho Theo Khu Vuc Tren Nhanh

Tai lieu nay mo rong tu `Nhanh_Check_Inventory` de chatbot co the:

- hoi khu vuc khach hang
- tim kho phu hop theo thanh pho / quan huyen
- check ton kho theo `depotIds`
- uu tien kho gan khu vuc khach thay vi lay tong ton kho toan he thong

File workflow export di kem:

- [Nhanh_Check_Inventory.json](/Users/phamhoanghai/n8n/Nhanh_Check_Inventory.json)
- [Nhanh_Get_Depots.json](/Users/phamhoanghai/n8n/Nhanh_Get_Depots.json)
- [Nhanh_Check_Inventory_By_Location.json](/Users/phamhoanghai/n8n/Nhanh_Check_Inventory_By_Location.json)

## 0. Khuyen Nghi Quan Trong

Neu de `AI Agent` tu dieu phoi 2 tool rieng:

- `Nhanh_Get_Depots`
- `Nhanh_Check_Inventory`

thi tren thuc te agent co the:

- luc chi goi depots
- luc chi goi inventory
- luc khong goi tool nao

do day van la bai toan planning cua agent.

Khuyen nghi thuc chien hon la:

```text
AI Agent
-> chi goi 1 tool: Nhanh_Check_Inventory_By_Location
```

Tool nay tu ben trong se:

1. lay danh sach kho
2. match kho theo khu vuc
3. goi inventory voi `depotIds` neu co
4. tra 1 ket qua tong hop ve cho agent

Neu uu tien on dinh cho production, nen dung tool gop nay.

## 1. Kien Truc De Xuat

```text
AI Agent cha
-> Tool 1: Nhanh_Get_Depots
-> Tool 2: Nhanh_Check_Inventory
```

Trinh tu hoi thoai:

```text
Khach hoi ton kho
-> neu chua biet khu vuc: hoi khach dang o thanh pho / quan nao
-> goi Nhanh_Get_Depots de lay depot phu hop
-> goi Nhanh_Check_Inventory voi depot_ids_json
-> tra loi ton kho theo kho phu hop
-> neu kho gan khong con hang, moi de xuat kiem tra kho khac
```

## 2. Nhanh Get Depots

Workflow con:

```text
Nhanh_Get_Depots
```

Input:

- `city_query`: ten thanh pho, vi du `Ho Chi Minh`
- `district_query`: ten quan huyen, vi du `Binh Thanh`

Output:

```json
{
  "ok": true,
  "city_query": "Ho Chi Minh",
  "district_query": "Binh Thanh",
  "total": 8,
  "matched_total": 2,
  "matched_depot_ids": [121858, 131439],
  "items": [
    {
      "id": 121858,
      "code": "HCM-01",
      "name": "Kho HCM Trung Tam",
      "city_name": "Ho Chi Minh",
      "district_name": "Binh Thanh",
      "address": "....",
      "match_score": 3
    }
  ]
}
```

Logic:

- API `business/depot` cua Nhanh chi filter theo `ids`
- vi vay workflow se goi toan bo danh sach kho
- sau do code node tu loc theo `city_query` va `district_query`
- ket qua da duoc sort theo `match_score`

## 3. Nhanh Check Inventory

Workflow con:

```text
Nhanh_Check_Inventory
```

Input moi:

- `product_query`
- `max_results`
- `depot_ids_json`
- `customer_city`
- `customer_district`

Vi du input:

```json
{
  "product_query": "Norda 001 - Parhelion",
  "max_results": 5,
  "depot_ids_json": "[121858,131439]",
  "customer_city": "Ho Chi Minh",
  "customer_district": "Binh Thanh"
}
```

Neu `depot_ids_json` co gia tri, workflow se them vao body Nhanh:

```json
{
  "filters": {
    "name": "Norda 001 - Parhelion",
    "depotIds": [121858, 131439]
  },
  "paginator": {
    "size": 5
  },
  "dataOptions": {}
}
```

Neu `depot_ids_json` rong:

- workflow van chay
- luc do se check ton kho toan he thong

## 4. Cach Noi Vao AI Agent

Them 2 node `Call n8n Workflow Tool` vao `AI Agent`.

### Tool 1. `Nhanh_Get_Depots`

`Description`:

```text
Dung tool nay khi can xac dinh kho phu hop theo khu vuc khach hang. Dau vao la city_query va district_query. Tool tra ve matched_depot_ids va danh sach kho phu hop. Goi tool nay truoc khi check ton kho neu khach da cho biet thanh pho hoac quan huyen.
```

`Workflow Inputs`:

1. `city_query`

```js
={{ $fromAI('city_query', 'Thanh pho cua khach hang, vi du Ho Chi Minh, Ha Noi, Da Nang', 'string') }}
```

2. `district_query`

```js
={{ $fromAI('district_query', 'Quan huyen cua khach hang neu co, vi du Binh Thanh, Cau Giay', 'string') }}
```

### Tool 2. `Nhanh_Check_Inventory`

`Description`:

```text
Dung tool nay de kiem tra ton kho tren Nhanh. Dau vao la product_query va co the kem depot_ids_json neu muon check theo kho phu hop voi khu vuc khach. Tool tra ve total, available_count, available_items va items.
```

`Workflow Inputs`:

1. `product_query`

```js
={{ $fromAI('product_query', 'Ten hoac ma san pham can kiem tra ton kho', 'string') }}
```

2. `max_results`

```js
={{ 5 }}
```

3. `depot_ids_json`

Neu muon agent chu dong tu tool `Nhanh_Get_Depots` qua buoc sau, hay cho agent tra chuoi JSON array. Vi du:

```text
[121858,131439]
```

Expression:

```js
={{ $fromAI('depot_ids_json', 'JSON array depot ids neu can loc theo kho, vi du [121858,131439]. Neu khong co thi de rong', 'string') }}
```

4. `customer_city`

```js
={{ $fromAI('customer_city', 'Thanh pho cua khach neu co', 'string') }}
```

5. `customer_district`

```js
={{ $fromAI('customer_district', 'Quan huyen cua khach neu co', 'string') }}
```

## 5. Prompt Goi Y Cho AI Agent

Them vao `systemMessage` cua agent:

```text
Khi khach hoi ton kho:

1. Neu chua biet khu vuc cua khach, hoi thanh pho hoac quan huyen truoc neu thong tin nay quan trong cho viec kiem tra kho gan.
2. Neu da biet khu vuc, goi tool Nhanh_Get_Depots de lay matched_depot_ids.
3. Sau do goi Nhanh_Check_Inventory voi product_query va depot_ids_json.
4. Uu tien tra loi theo kho phu hop khu vuc khach.
5. Neu kho gan khong con hang nhung kho khac con, noi ro rang la kho gan tam het nhung shop con the kiem tra dieu chuyen tu kho khac.
6. Khong duoc tu doan ton kho neu tool tra ve ok = false.
```

## 6. Chien Luoc Hoi Thoai Khuyen Nghi

### Truong hop 1. Khach chua cho biet khu vuc

Bot hoi:

```text
Dạ anh/chị đang ở khu vực nào để em kiểm tra kho gần mình trước ạ? Nếu tiện anh/chị cho em xin quận/huyện luôn để em check sát hơn.
```

### Truong hop 2. Khach chi noi thanh pho

- goi `Nhanh_Get_Depots` voi `city_query`
- lay tat ca kho trong thanh pho do
- goi `Nhanh_Check_Inventory`

### Truong hop 3. Khach noi ro quan huyen

- goi `Nhanh_Get_Depots` voi `city_query` + `district_query`
- uu tien kho cung quan huyen

### Truong hop 4. Kho gan khong con hang

Bot noi:

```text
Dạ mẫu này ở kho gần khu vực anh/chị hiện đang tạm hết, nhưng em thấy shop còn ở kho khác. Nếu anh/chị muốn em kiểm tra phương án chuyển kho hoặc thời gian giao dự kiến giúp mình ạ.
```

## 7. Luu Y Quan Trong

- `Nhanh_Get_Depots` hien tai la logic map theo text, chua phai tinh khoang cach GPS
- `matched_depot_ids` la danh sach kho phu hop nhat theo ten thanh pho / quan huyen
- neu doanh nghiep doi ten kho hoac mo kho moi, nen test lai map
- docs Nhanh khuyen co the cache danh sach kho 24h, nhung ban co the de goi truc tiep truoc roi toi uu sau

## 8. Buoc Tiep Theo Nen Lam

Neu muon day du hon cho phase 1, buoc tiep theo nen them:

1. tool `Nhanh_Get_Depots_Cached` dung Postgres de cache danh sach kho 24h
2. bang map dong nghia dia danh:
   - `tphcm`, `tp hcm`, `sai gon` -> `Ho Chi Minh`
   - `hn` -> `Ha Noi`
3. fallback logic trong agent:
   - kho cung quan
   - kho cung thanh pho
   - toan he thong
