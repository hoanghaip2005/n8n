# Ke Hoach Giai Doan 2 - Xac Nhan Nhu Cau Tam Thoi Va Chuyen Tiep Qua Tu Van Vien

Tai lieu nay mo ta ke hoach giai doan 2 theo huong:

- phase 1 ben Facebook / AI xac dinh nhu cau tam thoi
- khi du dieu kien thi chuyen lead qua team sale
- team sale van hanh tren `Zalo OA Group` de de quan ly, de audit va de kiem soat quyen
- uu tien co che command ro rang nhu `/getorders`, `/claim`, `/approve`

## 0. Chot Lai Scope Ban Toi Thieu

De tranh lam qua som phan van hanh phuc tap, giai doan 2 nen tach thanh 2 muc:

### Muc toi thieu can lam ngay

Chi can dat duoc 1 viec:

- khi khach dat nguong `handoff_ready`, workflow phase 1 se gui 1 tin nhan thong bao vao nhom GMF de member biet va xu ly thu cong

Luc nay chua can:

- command router
- `/claim`, `/close`, `/ticket`
- RBAC bang `zalo_group_members`
- audit bang `lead_handoff_actions`
- AI Agent trong group sale

### Muc nang cao lam sau

Sau khi luong notify vao GMF da chay on dinh moi lam tiep:

- slash command
- phan quyen member
- audit action
- dong / nhan / cap nhat lead tren group

Ket luan:

- buoc 1 cua giai doan 2 khong phai la "quan ly group"
- buoc 1 la "bao cho team sale biet co lead can xu ly"

Tai lieu duoc bam tren:

- [Workflow.json](/Users/phamhoanghai/n8n/Workflow.json)
- [Zalo Workflow.json](/Users/phamhoanghai/n8n/Zalo%20Workflow.json)
- [ke-hoach-giai-doan-1-chao-hoi-thu-hep-nhu-cau.md](/Users/phamhoanghai/n8n/docs/ke-hoach-giai-doan-1-chao-hoi-thu-hep-nhu-cau.md)
- Tai lieu chinh thuc ve Zalo OA OpenAPI va GMF:
  - [Zalo OA OpenAPI](https://oa.zalo.me/home/function/extension)
  - [Quản lý nhóm GMF](https://oa.zalo.me/home/function/interaction?type=quan-ly-nhom)
  - [Giới thiệu GMF](https://oa.zalo.me/home/resources/news/_4601792943864106455)
  - [Quản lý vận hành OA Manager](https://oa.zalo.me/home/function/management)

## 1. Muc Tieu Giai Doan 2

Giai doan 2 co 3 muc tieu nghiep vu:

1. xac nhan lai nhu cau tam thoi ma bot da thu hep o phase 1
2. xin va chot so dien thoai de chuyen sang sale that
3. tao 1 quy trinh handoff de team sale nhan lead, claim lead, xem ticket, tra cuu don va dong lead

Ket qua mong muon:

- khong de lead bi troi
- khong de 2 sale cung nhay vao 1 lead ma khong biet nhau
- co audit ro ai da nhan lead, ai da cap nhat lead, lead dang o trang thai nao
- bot van giup duoc, nhung khong de AI tu do dieu phoi tat ca trong group

Neu lam theo thu tu uu tien thuc dung, thi can chia lai:

1. gui thong bao lead vao GMF
2. dam bao moi lead chi gui 1 lan
3. sau do moi them co che thao tac tren group

## 2. Ket Luan Kien Truc

Khuyen nghi kien truc:

```text
Facebook / Zalo customer chat
-> Phase 1 AI workflow
-> customer_phase_state
-> lead_handoff_queue

Lead handoff service
-> Zalo OA Group notify
-> team sale thao tac bang command co cau truc

Zalo OA Group command workflow
Webhook group
-> Command Router
-> PG read / write ticket + order + member role
-> Zalo OA Group reply
```

Neu quay lai scope ban dau, can them mot kien truc toi gian hon de trien khai truoc:

```text
Facebook customer chat
-> Phase 1 AI workflow
-> PG Upsert customer_phase_state
-> If handoff_ready and handoff_created = false
-> Insert lead_handoff_queue
-> Ensure Zalo OA token
-> HTTP send message vao GMF
-> Update handoff_created = true
```

Y tuong cot loi:

- khong dung AI Agent de doc moi tin nhan trong group sale
- nhom sale dung command co cau truc de bot xu ly deterministic
- AI chi dung o nhung viec can tom tat / dien giai, khong dung de parse lenh van hanh

Cho moc dau tien, co the bo qua hoan toan nhom command workflow.

## 3. Vi Sao Nen Dung Zalo OA Group

Theo tai lieu chinh thuc:

- GMF la tinh nang de OA tuong tac voi mot nhom nguoi dung, nhom do do OA so huu va quan ly
- OA Group giup bao ve thong tin, khong that thoat du lieu khi doi nhan vien
- viec tham gia nhom qua link can Truong nhom hoac Pho nhom phe duyet
- OA Manager co co che quan ly admin / van hanh

Y nghia voi bai toan cua ban:

- dung `Zalo OA Group` la hop ly cho giai doan 2
- group nay khong chi la noi nhan thong bao, ma la noi thao tac handoff co kiem soat
- quyen thanh vien va quyen lenh nen tach 2 lop:
  - lop 1: quyen tham gia nhom theo OA Manager / GMF
  - lop 2: quyen thao tac lenh theo bang role noi bo trong Postgres

## 4. Danh Gia Hien Trang Workflow

### 4.1. Cai da co trong `Workflow.json`

Ben phase 1 da co:

- `PG Upsert Lead State`
- `If Handoff Ready`
- `Insert Lead Handoff Queue`
- `Update handoff_created`

Nghia la:

- he thong da co diem cat de nhan biet lead nao can chuyen qua sale
- da co queue co ban de lam handoff
- da gan nhu du dieu kien de gui thong bao vao group ngay lap tuc

### 4.2. Cai da co trong `Zalo Workflow.json`

Dang co:

- webhook nhan su kien Zalo
- AI Agent1
- cac HTTP goi group message / create group / get groups

Nhung hien trang chua on cho van hanh thuc te vi:

1. token dang hardcode
2. AI Agent dang parse tin group theo kieu tu do
3. chua co command router deterministic
4. chua co RBAC cho member trong group
5. chua co ticket state machine ro rang
6. chua co audit action cua sale

Ket luan:

- ha tang Zalo da co mam
- nhung chua the coi la da trien khai giai doan 2
- tuy vay, de dat moc MVP thi khong can doi router group hoan chinh

## 4.3. Muc MVP Nen Chot Ngay

Ban toi thieu cua giai doan 2 nen la:

```text
AI Agent Phase 1
-> PG Upsert Lead State
-> If Handoff Ready
-> Insert Lead Handoff Queue
-> HTTP Send GMF Notification
-> Update handoff_created
```

Noi dung tin nhan gui vao GMF chi can gom:

- ma ticket
- kenh nguon: Facebook hoac Zalo
- ten khach neu co
- so dien thoai neu co
- san pham quan tam
- tom tat nhu cau
- muc do uu tien neu co
- 1 dong huong dan de sale tu xu ly thu cong

Vi du:

```text
Lead moi can xu ly
Ticket: T-1024
Nguon: Facebook
Khach: Nguyen Van A
SDT: 09xxxxxxx
Nhu cau: giay trail Norda, size 42, hoi ton kho
Ghi chu: da xin sale lien he lai som
```

O muc nay, nhom GMF dong vai tro:

- kenh thong bao noi bo
- noi de sale thay lead moi
- chua phai noi van hanh bang command

## 5. De Xuat Mo Hinh Tuong Tac Tot Nhat Trong Group

Phan nay la buoc sau khi MVP notify da chay on dinh.

Khuyen nghi dung `slash command` lam chuan thao tac.

Ly do:

- de hoc cho team sale
- de parser don gian
- de kiem soat role
- de audit
- khong phu thuoc vao AI de hieu y lenh

### 5.1. Command can co

#### Nhom command ticket / lead

- `/help`
- `/queue`
- `/ticket <ticket_id>`
- `/claim <ticket_id>`
- `/assign <ticket_id> <member_code>`
- `/approve <ticket_id>`
- `/reject <ticket_id> <ly_do>`
- `/close <ticket_id>`
- `/note <ticket_id> <noi_dung>`
- `/customer <ticket_id>`

#### Nhom command order / inventory

- `/getorders <phone|ticket_id|order_code>`
- `/inventory <ten_san_pham>`
- `/status <ticket_id>`

#### Nhom command member / nhom

- `/whoami`
- `/members`
- `/role <member_code>`

### 5.2. Command nao nen uu tien lam truoc

Pha 1 cua group command nen lam 6 lenh:

1. `/help`
2. `/queue`
3. `/ticket <ticket_id>`
4. `/claim <ticket_id>`
5. `/getorders <ticket_id|phone>`
6. `/close <ticket_id>`

Day la bo command nho nhat de group van hanh duoc.

## 6. Co Nen Dung Command Hay Co Che Khac

Neu dang o moc dau tien, cau tra loi la:

- chua can command
- chua can AI trong group
- chi can thong bao deterministic vao GMF

Command chi nen them khi:

- so lead bat dau tang
- can tranh trung xu ly
- can audit ai da nhan lead
- can team sale tu thao tac ngay trong group

### Lua chon 1. Slash command

Uu diem:

- nhanh
- re
- deterministic
- it token
- de logging

Nhuoc diem:

- can train team sale 1 lan

### Lua chon 2. AI tu hieu tin nhan tu do trong group

Uu diem:

- tu nhien

Nhuoc diem:

- de sai
- ton token
- kho phan quyen
- kho audit

### Lua chon 3. Hybrid

Khuyen nghi cho ban:

- van hanh chinh bang slash command
- AI chi dung de:
  - tom tat lead
  - viet message goi y
  - dien giai ticket

Ket luan:

- voi group sale noi bo, `Hybrid` la tot nhat
- command de thao tac
- AI de ho tro doc va tom tat

## 7. State Machine Giai Doan 2

De team sale de nhin va de bot de xu ly, can co state machine ro rang cho lead handoff:

```text
new
-> pending_handoff
-> notified_to_group
-> claimed
-> contacted
-> waiting_customer
-> approved
-> rejected
-> closed
```

Y nghia:

- `pending_handoff`: bot phase 1 xac dinh da du dieu kien chuyen
- `notified_to_group`: da gui vao group Zalo
- `claimed`: sale da nhan lead
- `contacted`: sale da lien he khach
- `waiting_customer`: dang cho khach phan hoi
- `approved`: lead du dieu kien / chot tiep
- `rejected`: lead khong dat / sai nhu cau / khong lien lac duoc
- `closed`: dong quy trinh

## 8. Bang Du Lieu Can Them

### 8.1. `zalo_group_members`

Dung de kiem soat quyen lenh trong group.

Field de xuat:

- `id`
- `oa_id`
- `group_id`
- `user_id`
- `display_name`
- `member_code`
- `role`
- `is_active`
- `created_at`
- `updated_at`

`role` de xuat:

- `owner`
- `manager`
- `sales`
- `viewer`

Rule:

- `owner` / `manager`: duoc `/assign`, `/approve`, `/reject`, `/members`
- `sales`: duoc `/queue`, `/ticket`, `/claim`, `/getorders`, `/close`, `/note`
- `viewer`: chi duoc `/ticket`, `/status`

### 8.2. `lead_handoff_queue`

Bang nay da co, nhung nen bo sung them:

- `ticket_id`
- `ticket_status`
- `claimed_by`
- `claimed_at`
- `contacted_at`
- `approved_by`
- `approved_at`
- `rejected_by`
- `rejected_at`
- `closed_by`
- `closed_at`
- `group_id`
- `group_message_id`
- `last_command`
- `last_command_by`
- `last_command_at`

### 8.3. `lead_handoff_actions`

Bang audit moi.

Field de xuat:

- `id`
- `ticket_id`
- `channel`
- `group_id`
- `actor_user_id`
- `actor_name`
- `action`
- `payload_json`
- `created_at`

Bang nay rat quan trong vi giup:

- audit
- debug
- thong ke KPI

## 9. Workflow Giai Doan 2 De Xuat

### 9.1. Workflow A - `Lead_Handoff_Notifier`

Muc tieu:

- khi phase 1 dat dieu kien handoff, gui lead vao group sale

Luong:

```text
If Handoff Ready
-> Insert Lead Handoff Queue
-> Ensure Zalo OA Token Valid
-> Select Target Group
-> Format Ticket Message
-> Send Group Message
-> Save group_message_id / status = notified_to_group
-> Update handoff_created
```

Noi dung tin gui vao group nen co dang:

```text
[LEAD MOI] TICKET #1234
Khach: Nguyen Van A
SĐT: chua co
Nhu cau: đang hỏi giày trail NORDA size 42, muốn kiểm tra tồn kho tại HCM
Trang thai: waiting_phone

Lenh nhanh:
/ticket 1234
/claim 1234
/getorders 1234
/approve 1234
```

### 9.2. Workflow B - `Zalo_Group_Command_Router`

Muc tieu:

- nhan message tu Zalo group
- route theo command

Luong:

```text
Webhook Zalo Group
-> Ensure Zalo OA Token Valid
-> Normalize Group Event
-> If Group Message Valid
-> PG Load Member Role
-> Parse Command
-> Switch Command
   -> /help
   -> /queue
   -> /ticket
   -> /claim
   -> /getorders
   -> /approve
   -> /close
-> Zalo Group Reply
-> Insert lead_handoff_actions
```

### 9.3. Workflow C - `Zalo_Group_Member_Governance`

Muc tieu:

- kiem soat thanh vien duoc phep thao tac

Luong:

```text
Webhook event member / admin
-> Sync member info vao zalo_group_members
-> Update role / active state
```

Neu webhook member chua du hoac kho khai thac:

- quan ly join / remove bang OA Manager
- dong bo role thao tac bang tay trong Postgres o phase dau

## 10. Parse Command Nhu The Nao

Khuyen nghi parser command nhu sau:

### Tin nhan hop le

```text
/claim 1234
/ticket 1234
/getorders 1234
/getorders 0988123456
/note 1234 khách đã nghe máy, hẹn gọi lại 15h
```

### Rule parser

- command la tu dau tien
- phan sau tach theo khoang trang
- command khong hop le -> tra `/help`
- member khong co quyen -> tra `ban khong co quyen dung lenh nay`

### Khong khuyen nghi

- khong nen de sale go:
  - "lay don ticket 1234 di"
  - "duyet ticket nay"
- vi nhu vay lai phai dung AI de hieu command

## 11. Co Che Quan Ly Member Trong Group

Khuyen nghi 2 lop:

### Lop 1. Quan ly tham gia nhom bang GMF / OA Manager

Theo Zalo OA:

- moi bang link thi truong nhom hoac pho nhom phe duyet
- moi qua OA Manager voi user da quan tam OA thi user vao truc tiep

Day la lop control ve viec ai duoc vao group.

### Lop 2. Quan ly quyen lenh bang Postgres role map

Ngay ca khi user da vao group:

- khong co nghia la duoc dung tat ca lenh
- workflow phai check `zalo_group_members.role`

Vi du:

- nhan vien moi vao group chi duoc `/queue` va `/ticket`
- truong nhom moi duoc `/assign`, `/approve`, `/reject`

Day la lop control ve viec ai duoc lam gi.

## 12. Co Nên Tao 1 Group Hay Nhieu Group

Khuyen nghi:

### Giai doan dau

- 1 group duy nhat cho sale handoff

Ly do:

- don gian
- de test
- de train team
- de debug

### Giai doan sau

Neu luong lead tang:

- tach theo khu vuc:
  - `sale-hcm`
  - `sale-hn`
- hoac tach theo line:
  - `giay`
  - `quan-ao`

Rule route:

- dua vao `customer_city`
- dua vao `products_interested`
- dua vao `lead_type`

## 13. Co Nen Dung `/getorders`

Co.

Day la command rat hop ly vi:

- deterministic
- de tra cuu
- phu hop van hanh

Nhung khuyen nghi mo rong:

- `/getorders <ticket_id>`
- `/getorders <phone>`
- `/getorders <order_code>`

Neu chi lam `/getorders` khong tham so:

- bot tra huong dan cu phap

## 14. Co Nen Co Lenh Duyet Ticket

Co.

Khuyen nghi:

- `/approve <ticket_id>`
- `/reject <ticket_id> <reason>`

Y nghia:

- `approve`: lead du dieu kien chuyen tiep / xu ly tiep
- `reject`: lead khong hop le, sai so, spam, trung, khong lien lac duoc

Neu ban muon "duyet" theo nghia "sale da nhan xu ly":

- dung `/claim <ticket_id>` se ro nghia hon `/approve`

Khuyen nghi:

- `claim` = nhan xu ly
- `approve` = xac nhan dat dieu kien

## 15. Trien Khai Theo 3 Pha

### Pha A - Van Hanh Toi Thieu

Muc tieu:

- nhom sale nhan duoc lead
- co the claim lead
- co the xem thong tin lead

Can lam:

1. lead handoff notifier
2. command `/help`
3. command `/queue`
4. command `/ticket`
5. command `/claim`
6. command `/close`
7. bang `lead_handoff_actions`

### Pha B - Ho Tro Van Hanh Don Hang

Can lam:

1. command `/getorders`
2. command `/inventory`
3. command `/note`
4. role map `zalo_group_members`

### Pha C - Quan Tri Nhom Va Tu Dong Hoa

Can lam:

1. route group theo khu vuc
2. assign tu dong
3. dashboard thong ke
4. SLA nhac lead chua claim
5. nhac lead da claim nhung chua lien he

## 16. Backlog Task Cu The

### Task nhom du lieu

1. Rà soát schema `lead_handoff_queue`
2. Tao bang `lead_handoff_actions`
3. Tao bang `zalo_group_members`
4. Them index cho `ticket_status`, `claimed_by`, `group_id`

### Task nhom workflow

1. Tao workflow `Lead_Handoff_Notifier`
2. Tao workflow `Zalo_Group_Command_Router`
3. Tao node `Ensure Zalo OA Token Valid`
4. Tao node `Parse Command`
5. Tao node `Check Member Permission`
6. Tao node `Reply Group Message`

### Task nhom command

1. `/help`
2. `/queue`
3. `/ticket`
4. `/claim`
5. `/close`
6. `/getorders`
7. `/note`
8. `/approve`
9. `/reject`

### Task nhom governance

1. Chot quy tac role
2. Chot quy tac group join
3. Chot quy tac ai duoc approve / reject
4. Chot quy tac lead timeout

## 17. De Xuat Trien Khai Ngay

Neu muc tieu la "lam duoc nhanh, de kiem soat, it rui ro", toi khuyen nghi chot giai phap sau:

### Workflow nghiep vu

```text
Phase 1 AI
-> handoff_ready = true
-> Insert Lead Handoff Queue
-> Send vao 1 Zalo OA Group sale chung

Trong group:
- sale dung /queue de xem lead
- sale dung /claim <ticket_id> de nhan lead
- sale dung /ticket <ticket_id> de xem chi tiet
- sale dung /getorders <ticket_id> de tra cuu don
- sale dung /close <ticket_id> de dong lead
```

### Co che control

- control member vao nhom: bang OA Manager / GMF
- control quyen lenh: bang `zalo_group_members`
- control hanh dong: bang `lead_handoff_actions`

### Khong lam ngay

- khong dung AI de parse command group
- khong auto assign ngay
- khong tach nhieu group ngay tu dau

## 18. Ket Luan Chot

Giai doan 2 nen di theo huong:

- `Zalo OA Group` la kenh van hanh team sale
- `slash command` la giao dien thao tac chinh
- `Postgres` la noi luu state va audit
- `AI` chi ho tro tom tat va dien giai, khong dieu phoi command

Huong nay:

- de train team
- de kiem soat member
- de audit
- re hon va on dinh hon so voi viec cho AI Agent doc tu do moi tin nhan trong group

## 19. Thu Tu Uu Tien Tiep Theo

1. Chot state machine `lead_handoff_queue`
2. Tao bang `lead_handoff_actions`
3. Tao bang `zalo_group_members`
4. Lam workflow `Lead_Handoff_Notifier`
5. Lam workflow `Zalo_Group_Command_Router`
6. Trien khai 5 command dau tien:
   - `/help`
   - `/queue`
   - `/ticket`
   - `/claim`
   - `/close`
7. Sau do moi them `/getorders` va `/approve`
