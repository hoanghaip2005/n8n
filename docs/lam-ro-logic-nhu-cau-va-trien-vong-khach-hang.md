# Lam Ro Logic Nhu Cau Va Trien Vong Khach Hang

Tai lieu nay chot business rule cho phan:

- `Xac dinh khach co nhu cau khong`
- `Xac dinh khach co trien vong khong`
- `Khi nao nen xin so dien thoai`
- `Khi nao du dieu kien handoff cho tu van vien`

Muc tieu:

- khong de AI chi "cam thay" khach co nhu cau
- bien phan nay thanh state co the luu duoc trong Postgres
- de workflow phase 1 co the do luong va tu dong hoa on dinh

## 1. Dinh Nghia 4 Muc

### 1.1. Khach co nhu cau

Khach duoc coi la `co nhu cau` khi co it nhat 1 trong cac dau hieu:

- hoi gia 1 san pham / nhom san pham
- hoi ton kho / size / mau / bien the
- gui anh san pham can tim
- noi ro muc dich mua, vi du:
  - chay trail
  - di tap
  - phuc hoi
  - di bo
- hoi ve giao hang, doi tra, ship, thoi gian nhan

Khach `chua duoc coi la co nhu cau` neu chi:

- chao hoi chung chung
- hoi "shop co gi"
- xem cho biet
- khong nhac den san pham, nhu cau, muc dich mua hay dieu kien mua

### 1.2. Khach co nhu cau ro

Khach duoc coi la `co nhu cau ro` khi da xac dinh duoc it nhat:

- san pham / dong san pham can quan tam

va them it nhat 1 trong cac thong tin:

- size
- gia tam quan tam
- muc dich su dung
- thanh pho / khu vuc giao hang
- so luong
- yeu cau "con hang khong", "co size nay khong"

Noi ngan gon:

```text
Co product + co it nhat 1 thong tin thu hep
```

### 1.3. Khach co trien vong

Khach duoc coi la `co trien vong` khi:

- da co nhu cau ro
- va tiep tuc tuong tac de dua quyet dinh mua

Dau hieu cua `co trien vong`:

- hoi them sau khi da duoc bao gia
- hoi ton kho, size, giao hang
- hoi san pham nao hop hon
- hoi cach dat hang
- dong y cho shop tu van them
- de lai ho ten / so dien thoai / dia chi

Khach `khong duoc coi la co trien vong cao` neu:

- hoi gia xong roi dung
- chi xem tham khao, chua co huong mua
- noi ro "em xem cho vui thoi"

### 1.4. Khach san sang handoff

Khach du dieu kien `handoff_ready` khi co mot trong 2 nhom sau:

#### Nhom A

- co nhu cau ro
- co `intent_score` cao
- da cung cap `phone`

#### Nhom B

- khach chu dong yeu cau nguoi that lien he
- hoac khach muon chot don / len don
- va da co toi thieu `phone`

## 2. Field Nghiep Vu Can Luu

Day la bo field toi thieu can co:

- `customer_stage`
- `lead_status`
- `intent_score`
- `has_clear_need`
- `need_summary`
- `products_interested`
- `phone`
- `phone_capture_status`
- `ask_for_phone_now`
- `handoff_ready`
- `handoff_reason`
- `last_customer_message_at`
- `last_bot_reply_at`
- `quoted_at`
- `asked_phone_at`

## 3. State Machine De Xuat

### 3.1. `customer_stage`

Gia tri:

```text
new
discovering
quoted
qualified
waiting_phone
handoff_ready
cold
```

Y nghia:

- `new`: vua vao hoi thoai, chua biet nhu cau
- `discovering`: dang thu hep nhu cau
- `quoted`: da bao gia / da tra ton kho / da tra thong tin san pham
- `qualified`: da xac dinh nhu cau ro, co trien vong
- `waiting_phone`: da co trien vong nhung chua co so dien thoai
- `handoff_ready`: da du dieu kien chuyen cho tu van vien
- `cold`: da nguoi dung im lang lau hoac the hien khong con quan tam

### 3.2. `lead_status`

Gia tri:

```text
unknown
interested
qualified
not_interested
inactive
```

Y nghia:

- `unknown`: chua du du lieu
- `interested`: co dau hieu quan tam
- `qualified`: co nhu cau ro va co trien vong cao
- `not_interested`: khach noi ro khong can nua / khong mua nua
- `inactive`: hoi gia / tham khao roi im trong nguong thoi gian quy dinh

## 4. Rule Score Toi Gian

Khuyen nghi dung `intent_score` tu `0 -> 100`.

### Cong diem

- hoi gia 1 san pham cu the: `+10`
- hoi ton kho / size / con hang: `+15`
- noi ten model / ma san pham ro rang: `+15`
- gui anh san pham can tim: `+10`
- hoi giao hang / ship / dia chi nhan: `+10`
- hoi cach dat hang / muon len don: `+20`
- de lai so dien thoai: `+20`
- yeu cau tu van vien lien he: `+25`

### Tru diem

- chi chao hoi chung chung: `0`
- noi "tham khao thoi", "xem cho biet": `-10`
- noi ro "khong can nua", "thoi khoi": `-40`

### Nguong goi y

- `0 - 9`: `unknown`
- `10 - 24`: `interested`
- `25 - 49`: `interested` co xu huong cao
- `50+`: `qualified`

Ghi chu:

- `intent_score` la tin hieu ho tro
- khong dung score mot minh
- van phai ket hop `has_clear_need`, `phone`, `explicit_buy_signal`

## 5. Rule Nghiep Vu Quyet Dinh

### Rule 1. `has_clear_need`

Gan `true` khi:

- `products_interested` khong rong
- va co it nhat 1 thong tin thu hep:
  - size
  - quantity
  - customer_city / district
  - muc dich su dung
  - cau hoi ton kho / gia / giao hang

### Rule 2. `ask_for_phone_now`

Gan `true` khi:

- `has_clear_need = true`
- `phone` dang rong
- va co mot trong cac dau hieu:
  - da bao gia
  - da check ton kho
  - khach hoi tiep sau khi duoc tu van
  - `intent_score >= 25`

### Rule 3. `lead_status = qualified`

Gan `qualified` khi:

- `has_clear_need = true`
- va `intent_score >= 50`

hoac:

- khach chu dong muon dat / len don
- hoac muon nguoi that lien he

### Rule 4. `handoff_ready = true`

Gan `true` khi:

- `lead_status = qualified`
- va `phone_capture_status = provided`

hoac:

- khach noi ro muon tu van vien lien he
- va co `phone`

### Rule 5. `customer_stage`

Map nhanh:

- chua co nhu cau -> `new` / `discovering`
- da bao gia / tra ton kho -> `quoted`
- da co nhu cau ro -> `qualified`
- da co nhu cau ro nhung chua co phone -> `waiting_phone`
- du dieu kien handoff -> `handoff_ready`
- no-reply lau -> `cold`

## 6. Mapping Tinh Huong Thuc Te

### Tinh huong A

Khach:

```text
Gia doi Norda 001 nay bao nhieu em?
```

Ket luan:

- `co nhu cau`: co
- `co nhu cau ro`: chua chac
- `lead_status`: `interested`
- `customer_stage`: `discovering`
- `ask_for_phone_now`: `false`

### Tinh huong B

Khach:

```text
Mau Parhelion size 44 con o HCM khong em?
```

Ket luan:

- `co nhu cau`: co
- `co nhu cau ro`: co
- `lead_status`: `interested` hoac `qualified`
- `customer_stage`: `quoted`
- `ask_for_phone_now`: `true` neu da tu van xong 1-2 luot

### Tinh huong C

Khach:

```text
Neu con hang thi em goi cho chi nhe, sdt 09xxxx
```

Ket luan:

- `lead_status`: `qualified`
- `phone_capture_status`: `provided`
- `handoff_ready`: `true`
- `customer_stage`: `handoff_ready`

### Tinh huong D

Khach:

```text
Thoi de chi xem them da em
```

Ket luan:

- khong chot `not_interested` ngay
- van co the giu `interested`
- doi workflow async no-reply de danh gia tiep

### Tinh huong E

Khach:

```text
Khong can nua em nha
```

Ket luan:

- `lead_status = not_interested`
- `customer_stage = cold`
- `handoff_ready = false`

## 7. Quy Tac Khong Lam

Khong duoc:

- coi moi khach hoi gia la `qualified`
- doi xin so dien thoai qua som
- handoff khi chua co nhu cau ro
- handoff khi chua co phone
- danh dau `not_interested` chi vi khach tam dung 1 lan

## 8. Ket Luan Chot

Cho phase 1, de don gian va on dinh, can coi 3 muc sau la cot song:

1. `has_clear_need`
2. `lead_status`
3. `handoff_ready`

Neu chi trien khai duoc 3 muc nay, workflow da co the:

- biet khach dang o dau trong funnel
- xin sdt dung luc hon
- khong bo sot lead co tiem nang
- handoff cho nguoi that dung thoi diem hon
