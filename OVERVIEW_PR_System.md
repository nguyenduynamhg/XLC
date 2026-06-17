# PR Online Form System — Business & Technical Overview
> **Scope:** SY2024–2025 | Platform: Power Apps Canvas App + SharePoint Online + Workato  
> **Document type:** Senior BA/Dev Analysis | Date: June 2026

---

## 1. System Architecture

```
┌─────────────────────────────────────────────────────────┐
│               POWER APPS CANVAS APP                     │
│  ┌──────────────────┐  ┌────────────────────────────┐   │
│  │ PR_OnlineForm_New│  │  PR_OnlineForm_PR_Detail   │   │
│  │  (Tạo mới đơn)   │  │  (Chi tiết + Duyệt/Từ chối│   │
│  └──────────────────┘  └────────────────────────────┘   │
│           ▲                          ▲                   │
│           │            ┌────────────────────────────┐   │
│           │            │  PR_OnlineForm_YourPR      │   │
│           │            │  (Danh sách chờ duyệt)     │   │
│           │            └────────────────────────────┘   │
└───────────┼──────────────────────┼──────────────────────┘
            │                      │
            ▼                      ▼
┌───────────────────────────────────────────────────────────┐
│                  SHAREPOINT ONLINE LISTS                  │
│  SY2425-PR-GeneralInfo   SY2425-PR_Item                   │
│  SY2425-Approval_log     SY2425_PR_Comments               │
│  ApprovalMatrix_SY2425   DOA_Matrix_SY2425                │
│  SY2425-ExchangeRate      NS_Master_Subsidiary            │
└─────────────────────────────┬─────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────┐
              │        WORKATO            │
              │  (Integration / Notify)   │
              │  NetSuite PO Creation     │
              │  Email notification flows │
              └───────────────────────────┘
```

---

## 2. SharePoint Data Model

### 2.1 `SY2425-PR-GeneralInfo` — Header đơn mua hàng
| Column | Mô tả |
|---|---|
| `PR_No` | Mã đơn, format `RF{mmyy}-{0001}` — auto-generate |
| `Status` | Trạng thái hiện tại: `Draft` → `Reviewer` → `Reviewer2` → `BudgetOwner` → `Level5..10` → `Final Approved` / `Rejected` |
| `LatestStatus` | Stage vừa qua (dùng cho audit trail) |
| `Total Amount` | Tổng tiền nguyên tệ |
| `TotalAmount_MYR` | Tổng tiền quy đổi sang MYR (dùng so sánh với DOA) |
| `Currency` | Đơn tệ của đơn |
| `RouteType` | `RealKids` hoặc `0` — quyết định nhánh phê duyệt |
| `Item_Subsidiary`, `Item_Campus`, `Item_Dept`, `Item_Curriculum` | Khóa tra cứu Approval Matrix & DOA Matrix |
| `FinalApprovedDate` | Timestamp khi đơn được duyệt hoàn toàn |
| `RejectComment` | Lý do từ chối gần nhất |
| `NSVendorFullName`, `NSVendorExternalID` | Thông tin nhà cung cấp NetSuite |
| `NS_PO_No`, `NSInternalID` | Số PO và ID trên NetSuite (ghi lại sau khi Workato xử lý) |

### 2.2 `SY2425-PR_Item` — Chi tiết từng dòng hàng
| Column | Mô tả |
|---|---|
| `PR_No0` | FK → GeneralInfo.PR_No |
| `ItemName`, `ItemID`, `GLNumber`, `GLDescription` | Thông tin mặt hàng + tài khoản GL |
| `Quantity`, `UnitPrice`, `Total Amount` | Số lượng, đơn giá, thành tiền nguyên tệ |
| `Item_TotalAmt_MYR` | Thành tiền quy đổi MYR |
| `itemTaxCode`, `itemTaxPercentage`, `itemGrossAmount` | Thông tin thuế |
| `itemSubsidiary`, `itemSubsidiaryNSID` | Công ty pháp nhân + NS ID |
| `Campus`, `CampusNSID`, `CurYearGroup`, `CurriculumnNSID` | Phân bổ cơ sở, chương trình |
| `NSDepartmentID`, `Dept_NSID` | ID phòng ban NetSuite |

### 2.3 `SY2425-Approval_log` — Nhật ký phê duyệt (audit trail)
| Column | Mô tả |
|---|---|
| `PR_No` | FK → GeneralInfo |
| `field_7` (Approved By) | Email người được chỉ định duyệt |
| `ApprovedByWho` | Email người đã thực sự bấm duyệt |
| `Stage` / `StageCheck` | Tên stage (Reviewer, Reviewer2, BudgetOwner, Level5..Level10) |
| `LogType` | Loại log (dùng để dedup) |
| `Status` | `Pending` → `Approved` / `Rejected` / `Returned` / `Final Approved` |
| `Returned` | Flag `1` nếu log này là "trả về" |
| `RejectComment` | Nội dung lý do trả về |

### 2.4 `ApprovalMatrix_SY2425` — Ma trận phê duyệt cơ bản
**Khóa tra cứu:** `Subsidiary + Dept + Campus + Curriculumn_YearGroup`

| Column | Mô tả |
|---|---|
| `Reviewer` | JSON array email: `["a@co.my","b@co.my"]` |
| `Reviewer2` | JSON array email cấp 2 |
| `Budget Owner` | Email Budget Owner thông thường |
| `RKManager` | Email manager RealKids (≤ 2,500 MYR) |
| `RKManager2` | Email manager RealKids (> 2,500 MYR) |
| `Level5..Level10` | Email người duyệt DOA từng cấp |

### 2.5 `DOA_Matrix_SY2425` — Ma trận uỷ quyền tài chính (DOA)
**Khóa tra cứu:** `Subsidiary + Campus`, lọc theo `Threshold_Min <= TotalAmount_MYR`

| StageOrder | StageName | Ngưỡng MYR (ví dụ Sri KDU) |
|---|---|---|
| 5 | School FBP | 1 – 20,000 |
| 6 | XMCO CBSO | 20,001 – 50,000 |
| 7 | XMCO CFO | 50,001 – 100,000 |
| 8 | XMCO CEO | 100,001 – 500,000 |
| 9 | Group CFO | 500,001 – 1,800,000 |
| 10 | Group CEO | 1,800,001 – 20,000,000 |

> **Quy tắc:** Tất cả các stage DOA có `Threshold_Min <= TotalAmount_MYR` đều phải duyệt lần lượt từ thấp đến cao.

### 2.6 `SY2425_PR_Comments` — Bình luận trên đơn
Lưu các comment người dùng gửi qua nút "Send" trong PR Detail. Có `Status` = `Posted` hoặc `Rejected`.

---

## 3. Canvas App — Màn hình & Buttons

### 3.1 Screen: `PR_OnlineForm_New` — Tạo đơn mới

#### Button: `btnSubmit`
**Mục đích:** Validate, sinh mã PR, lưu GeneralInfo + tất cả PR_Item, tạo Approval Log Pending cho Reviewer.

**Luồng xử lý chi tiết:**

```
[1] Validate Fields (checkFields)
    ├── ToggleVendor OFF (One-time vendor): kiểm tra Title, Date, Description, Attachments, 
    │   OneTimeVendor NSInternalID, Currency, PaymentTerm, itemGrid không rỗng
    │   + CountIf dòng hàng thiếu: Dept, Qty, UnitPrice, ItemDesc, TaxCode, Campus
    └── ToggleVendor ON (existing vendor): tương tự, thay bằng DataCardValue6

[2] Validate Approval Matrix (checkMatrix)
    └── LookUp(ApprovalMatrix, Subsidiary+Dept+Campus+Curriculum của dòng hàng FIRST)
        → Không tìm thấy → Set(checkMatrix, false); Set(varSpinner, false); DỪNG

[3] Nếu checkFields && checkMatrix:

    [3.1] Sinh mã PR
        currentMonthYear = Text(Today(), "mmyy")   // "0626"
        lastPRRecord = MAX IncrementingNumber trong tháng này
        nextIncrementingNumber = lastPRRecord.IncrementingNumber + 1
        prNumber = "RF" & monthYear & "-" & Text(seq,"0000")  // "RF0626-0001"
        → Check trùng lần 2, nếu trùng thì +1 thêm

    [3.2] SubmitForm(GeneralInforForm) — lưu các trường Form cơ bản

    [3.3] Xác định RouteType
        Campus.RealKids = "Yes" → PRRouteType = "RealKids", ngược lại = "0"

    [3.4] Patch bổ sung vào GeneralInfo
        PR_No, MonthYear, IncrementingNumber
        Total Amount (sum grid), TotalAmount_MYR (sum grid MYR)
        Status = "Reviewer", LatestStatus = "Pending"
        Item_* fields (từ FIRST dòng hàng của grid)
        RouteType, Department, Campus (từ Office365Users.MyProfileV2)

    [3.5] ForAll(itemGrid) → Patch từng dòng vào SY2425-PR_Item

    [3.6] Lấy Reviewer JSON từ ApprovalMatrix
        → ParseJSON → ForAll → Patch Approval_log
        {Stage: "Reviewer", StageCheck: "Reviewer", Status: "Pending", LogType: "Reviewer"}

    [3.7] Notify thành công → ResetForm
```

---

### 3.2 Screen: `PR_OnlineForm_PR_Detail` — Chi tiết đơn hàng

#### Button: `btnEdit`
```
EditForm(GeneralInforForm_2)
UpdateContext({editMode: true})
Disable btnSubmit
```

#### Button: `btnSave`
**Mục đích:** Lưu thay đổi khi đang ở editMode. Xóa toàn bộ PR_Item cũ → insert lại từ grid.

```
[1] Validate checkFields + checkMatrix (giống btnSubmit_New, dùng itemGrid_2)

[2] Nếu hợp lệ:
    ClearCollect(itemsToRemove, Filter(PR_Item, PR_No = SelectedPR.PR_No))
    ForAll(itemsToRemove) → Remove(PR_Item, ThisRecord)   // xóa hết items cũ
    ForAll(itemGrid_2) → Patch(PR_Item) với dữ liệu mới

    Patch(GeneralInfo, ...{
        Purpose, PR_Type, Total Amount, TotalAmount_MYR,
        NSVendorFullName, Item_Subsidiary, Item_Campus, ...
    })
    UpdateContext({editMode: false})

[3] Notify success
```

#### Button: `btnSubmit` (trong PR_Detail)
**Mục đích:** Re-submit đơn đang ở trạng thái `Draft` (đã bị Return) lên lại `Reviewer`.

```
[1] Validate checkFields2
[2] Patch(GeneralInfo) → Status: "Reviewer", LatestStatus: "Pending"
[3] Lấy Reviewer JSON → ParseJSON → ForAll → Patch Approval_log (Pending)
[4] Dedup Approval_log (xóa log Pending trùng)
[5] Notify success
```

#### Button: `btnApprove` (trong PR_Detail)
*(Xem chi tiết ở mục 4 — Approval Engine)*

#### Button: `btnReject`
**Mục đích:** Hiện modal confirm từ chối.  
*(Code hiện tại đang bị comment ra `/* ... */`)*  
Active logic: `UpdateContext({ showModalReject: true })`  
→ Modal hiện, người dùng nhập lý do → thực sự xử lý reject trong modal handler.

**Logic dự kiến (từ code comment):**
```
Patch(GeneralInfo) → Status: "Rejected", LatestStatus: "Rejected", RejectComment: txtRejectComment
Patch(Approval_log, log Pending của user này) → Status: "Rejected"
```

#### Button: `btnReturn`
**Mục đích:** Trả đơn về cho người tạo để sửa.  
*(Code hiện tại đang bị comment ra `/* ... */`)*  
Active logic: `UpdateContext({ showModal: true })`

**Logic dự kiến (từ code comment):**
```
Patch(Approval_log, log Pending của user) → {Status: "Returned", RejectComment: reason, Returned: "1"}
Patch(GeneralInfo) → {Status: "Draft", LatestStatus: "Returned"}
```
> Lưu ý: `txtRejectComment.fx` (Default Value của ô nhập) tổng hợp lịch sử "Returned" từ Approval_log theo format `dd/mm/yyyy by <ApproverName>: <comment>`.

#### Button: `btnSend`
**Mục đích:** Gửi comment/bình luận vào danh sách `SY2425_PR_Comments`.
```
Patch(SY2425_PR_Comments, Defaults(...), {
    PR_No, Comments: txtComment.Value,
    CreatedEmail: User().Email, Status: "Posted"
})
Reset(txtComment)
Refresh(SY2425_PR_Comments)
```

---

### 3.3 Screen: `PR_OnlineForm_YourPR` — Danh sách chờ duyệt của tôi

#### Button: `btnApprove`
*(Xem chi tiết ở mục 4 — Approval Engine)*

---

## 4. Approval Engine — Luồng Phê Duyệt Chi Tiết

> Được dùng ở cả `PR_OnlineForm_YourPR/btnApprove.fx` lẫn `PR_OnlineForm_PR_Detail/btnApprove.fx`.  
> Logic gần như giống nhau, chỉ khác nguồn dữ liệu (`Gallery1.Selected` vs `SelectedPR`).

### 4.1 Bản đồ Stage (Stage Map)

| StageCheck | varCurrentStage | varCurrentDOAOrder | Ý nghĩa |
|---|---|---|---|
| `Reviewer` | 1 | Blank | Cấp soát xét 1 |
| `Reviewer2` | 2 | Blank | Cấp soát xét 2 |
| `BudgetOwner` | 3 | Blank | Chủ ngân sách |
| `Level5` | 4 | 5 | FBP (School Finance) |
| `Level6` | 5 | 6 | CBSO |
| `Level7` | 6 | 7 | CFO |
| `Level8` | 7 | 8 | CEO |
| `Level9` | 8 | 9 | Group CFO |
| `Level10` | 9 | 10 | Group CEO |

### 4.2 Luồng xử lý Approve (từng bước)

```
[Pre] Set(varSpinner, true)
      UpdateContext({isApproving: true})

[0] Tính TotalAmount_MYR nếu đang = 0/Blank
    calTotalAmoutMYR = TotalAmount × ExchangeRate(Currency)
    → Patch(GeneralInfo, TotalAmount_MYR: calTotalAmoutMYR)

[0b] Xác định PRRouteType
    RouteType = "RealKids" → PRRouteType = "RealKids", ngược lại "0"

[1] Lấy latestPendingRecord
    Filter(Approval_log, PR_No=X && field_7=User().Email && Status="Pending")
    SortByColumns("Created", Descending) → First()
    → IsBlank → Notify Error, Set(varSpinner, false), DỪNG

[2] Map stage sang số
    varCurrentStage  = Switch(StageCheck, Reviewer=1 ... Level10=9)
    varCurrentDOAOrder = Switch(StageCheck, Level5=5 ... Level10=10, Blank)
    varRFStage = Switch(GeneralInfo.Status, Reviewer=1 ... FinalApproved=10)

[3] Build DOA collection cho đơn này
    ClearCollect(colDOAForRF,
        Filter(DOA_Matrix, Subsidiary=X && Campus=X && Threshold_Min <= TotalAmount_MYR))
    varDOAFinalStageOrder = Last(Sort(colDOAForRF, StageOrder Asc)).StageOrder

[4] Patch log hiện tại → Status: "Approved"

[4b] GUARD: Nếu varCurrentStage < varRFStage (log cũ/nhảy cóc)
    → Chỉ mark Approved + Dedup Pending logs → DỪNG ở đây

[5] PHÂN NHÁNH CHÍNH:

    ┌─ NHÁNH A: varCurrentStage <= 3 (Reviewer / Reviewer2 / BudgetOwner)
    │
    │   ┌─ A1: StageCheck = "BudgetOwner"
    │   │   ├─ colDOAForRF KHÔNG RỖNG:
    │   │   │   → Tìm _firstDOARec: Min StageOrder >= 5 trong colDOAForRF
    │   │   │   → Patch(GeneralInfo) Status = _firstStageName
    │   │   │   → Patch(Approval_log) tạo Pending mới cho _firstDOARec.ApproverEmail
    │   │   │
    │   │   └─ colDOAForRF RỖNG: (BudgetOwner là cấp cuối)
    │   │       → Patch(GeneralInfo) Status = "Final Approved", FinalApprovedDate = Now()
    │   │       → Patch(log) Status = "Final Approved"
    │   │
    │   └─ A2: StageCheck = "Reviewer" hoặc "Reviewer2"
    │       varNextStage = varCurrentStage + 1
    │       → Patch(GeneralInfo) Status = Switch(varNextStage, 2→"Reviewer2", 3→"BudgetOwner")
    │       → Build varNextApproverList:
    │           - Stage 2 (Reviewer2): ParseJSON(Matrix.Reviewer2) → Table of {Email}
    │           - Stage 3 (BudgetOwner):
    │               ┌─ PRRouteType = "RealKids" AND Dept ≠ "Operations : Facility":
    │               │   TotalAmount_MYR <= 2500 → RKManager
    │               │   TotalAmount_MYR >  2500 → RKManager2
    │               └─ Ngược lại: Budget Owner
    │       → ForAll(varNextApproverList) → Patch Approval_log (Pending)
    │
    └─ NHÁNH B: varCurrentStage >= 4 (Level5 → Level10, DOA stages)
        With({_finalOrder: varDOAFinalStageOrder, _currentOrder: varCurrentDOAOrder})
        ├─ _currentOrder = _finalOrder (đây là cấp DOA cao nhất cần duyệt):
        │   → Patch(GeneralInfo) Status = "Final Approved", FinalApprovedDate = Now()
        │   → Patch(log) Status = "Final Approved"
        │
        └─ _currentOrder < _finalOrder (còn cấp DOA cao hơn):
            _nextDOARec = First(Filter(colDOAForRF, StageOrder > _currentOrder && <= _finalOrder))
            → Patch(GeneralInfo) Status = _nextStageName
            → Patch(Approval_log) tạo Pending cho _nextDOARec.ApproverEmail

[6] DEDUP: Quét và xóa Pending log trùng (cùng PR_No + ApprovedBy + LogType)
    ClearCollect(colDuplicateKeys, Distinct(...))
    ForAll(colDuplicateKeys) → Collect(colToDelete, các dòng thừa)
    RemoveIf(Approval_log, ID in colToDelete.ID)

[7] Set(varSpinner, false)
    Notify("Approval completed successfully.", Success)
```

### 4.3 Sơ đồ trạng thái đơn hàng (State Machine)

```
                        ┌──────────────────────────────────────────────┐
                        │              SUBMIT (New)                    │
                        ▼                                              │
[Draft/New] ──────► [Reviewer] ──Approved──► [Reviewer2] ──Approved──► [BudgetOwner]
    ▲                   │                        │                          │
    │                   │ Return/Reject           │ Return/Reject            │
    │◄──────────────────┘◄───────────────────────┘                          │
    │                                                                       │ No DOA
    │                                                                       ▼
    │                                                              [Final Approved] ✓
    │                                                                       │
    │                                                               Has DOA?│
    │                                                                       ▼
    │                                         ┌─────────────────────────────────────┐
    │                                         │  [Level5] → [Level6] → ... → [Level10]│
    │                                         │   (theo DOA Matrix, tuỳ TotalMYR)   │
    │                                         └─────────────────────────┬───────────┘
    │                                                                    │
    │                                                                    ▼
    │                                                          [Final Approved] ✓
    │
    └───────────────── Return (btnReturn) ◄──── bất kỳ stage nào
```

---

## 5. Logic Đặc Biệt — RealKids Route

RealKids là nhánh phê duyệt đặc biệt cho trường mầm non thuộc group. Được kích hoạt khi `Campus.RealKids = "Yes"`.

| Điều kiện | Budget Owner được chọn |
|---|---|
| `Dept = "Operations : Facility"` | `Budget Owner` thông thường (bất kể amount) |
| `TotalAmount_MYR <= 2,500` | `RKManager` |
| `TotalAmount_MYR > 2,500` | `RKManager2` |

> Lý do thiết kế: RealKids có cơ cấu quản lý khác, không dùng Budget Owner chuẩn cho hoạt động vận hành.

---

## 6. Logic Sinh Mã PR (`PR_No`)

```
Format: RF{mmyy}-{0000}
Ví dụ:  RF0626-0023

Thuật toán:
1. currentMonthYear = Text(Today(), "mmyy")              // "0626"
2. lastPRRecord = First(SortByColumns(
       Filter(GeneralInfo, MonthYear = currentMonthYear),
       "LastNumber", Descending))
3. nextSeq = lastPRRecord.IncrementingNumber + 1         // hoặc 1 nếu tháng đầu tiên
4. prNumber = "RF" & currentMonthYear & "-" & Text(nextSeq,"0000")
5. GUARD: LookUp(GeneralInfo, PR_No = prNumber)          // kiểm tra trùng
   → Nếu trùng: nextSeq += 1, tính lại
```

> **Rủi ro thiết kế (to note):** Logic anti-duplicate chỉ chạy 1 lần retry. Trong trường hợp nhiều user submit đồng thời, vẫn có thể xảy ra race condition. Cần consider dùng sequence từ Flow hoặc SharePoint server-side.

---

## 7. Currency & Exchange Rate

- Mỗi đơn có thể nhập bằng bất kỳ loại tiền nào (MYR, SGD, USD, ...).
- `TotalAmount_MYR` = `TotalAmount × ExchangeRate(Currency)` từ bảng `SY2425-ExchangeRate`.
- `TotalAmount_MYR` là giá trị được so sánh với `DOA_Matrix.Threshold_Min` để xác định cấp duyệt.
- Nếu `TotalAmount_MYR` trống hoặc = 0 ở thời điểm approve → hệ thống tự tính lại và patch.

---

## 8. Vendor Selection — Hai mode

| Toggle | Mode | Dữ liệu |
|---|---|---|
| `ToggleVendor = OFF` | **One-time Vendor** | Chọn từ `cmbOneTimeVendor` → lấy `NSInternalID`, `VendorFullName` |
| `ToggleVendor = ON` | **Existing Vendor** | Nhập `DataCardValue6` (NS Vendor ID manual) |

---

## 9. Deduplication Logic (Cleanup Pending Logs)

Cơ chế này chạy ở:
- Bước 4b (sau khi approve log cũ)
- Bước 6 (sau mỗi lần approve thành công)
- Khi re-submit đơn

**Thuật toán:**
```
Key = PR_No & "|" & ApprovedBy & "|" & LogType

1. ClearCollect(colDuplicateKeys,
       RenameColumns(Distinct(Filter(Approval_log, PR_No=X && Status="Pending"), Key), Value, dupKey))

2. ClearCollect(colToDelete, {ID: Blank()})

3. ForAll(colDuplicateKeys):
       rows = Filter(Approval_log, ... && key = dupKey)  // các bản ghi trùng
       Collect(colToDelete, FirstN(Sort(rows, Modified, Asc), CountRows(rows) - 1))
       // giữ lại 1 bản ghi mới nhất, xóa các bản cũ hơn

4. RemoveIf(Approval_log, ID in colToDelete.ID)
```

---

## 10. Workato Integration (Phân tích từ context)

Folder `Workato/` hiện trống trong workspace — các flow được cấu hình trực tiếp trên Workato cloud.

**Dựa trên code Power Apps, các Flow dự kiến bao gồm:**

| Flow | Trigger | Mô tả |
|---|---|---|
| `SY2425_Rejected_Notify` | Gọi từ Power Apps (đang comment) | Gửi email thông báo bị reject cho requestor |
| NetSuite PO Creation | Trigger từ SharePoint (Final Approved) | Tạo PO trên NetSuite, ghi lại `NS_PO_No`, `NSInternalID` |
| Approval Notification | Trigger từ Approval_log (Pending mới) | Gửi email cho approver về đơn chờ duyệt |

> Tham số gọi flow (trong code comment): `PR_No`, `ApproverName`, `Stage`, `RequestorEmail`

---

## 11. Known Issues & Technical Debt

| # | Vấn đề | Mức độ | Ghi chú |
|---|---|---|---|
| 1 | `btnReject` và `btnReturn` đang **bị comment toàn bộ** | 🔴 Critical | Active code chỉ show modal, không thực sự xử lý reject/return logic |
| 2 | Race condition khi sinh PR_No | 🟡 Medium | Nhiều user cùng submit trong cùng giây có thể bị trùng mã |
| 3 | Dedup chỉ giữ 1 bản cuối nhất — nếu có approver được thêm 2 lần thủ công sẽ mất dữ liệu | 🟡 Medium | |
| 4 | `varCurrentStage < varRFStage` guard (bước 4b) dừng hoàn toàn — không trigger email | 🟡 Medium | Approver duyệt xong không thấy bước tiếp theo được tạo |
| 5 | `ParseJSON(Reviewer)` không có try/catch | 🟠 Low | Nếu JSON malformed → app crash silently |
| 6 | Approval Matrix lookup chỉ dựa vào FIRST item trong grid | 🟠 Low | Đơn có nhiều item thuộc Dept/Campus khác nhau → sai matrix |
| 7 | Email notification flows đang được comment (`/* ... */`) | 🔴 Critical | Approver không nhận email sau mỗi stage |

---

## 12. File Structure Summary

```
fower fx/
│
├── PR_OnlineForm_New/
│   └── btnSubmit.fx          # Tạo đơn mới, sinh PR_No, tạo Approval Log
│
├── PR_OnlineForm_PR_Detail/
│   ├── btnApprove.fx          # Approve từ màn chi tiết
│   ├── btnEdit.fx             # Kích hoạt edit mode
│   ├── btnSave.fx             # Lưu chỉnh sửa (replace toàn bộ PR_Item)
│   ├── btnSubmit.fx           # Re-submit đơn Draft
│   ├── btnSend.fx             # Gửi comment
│   ├── btnReject.fx           # Từ chối (đang comment, chỉ show modal)
│   ├── btnReturn.fx           # Trả về (đang comment, chỉ show modal)
│   └── txtRejectComment.fx    # DefaultText: tổng hợp lịch sử Returned comments
│
├── PR_OnlineForm_YourPR/
│   └── btnApprove.fx          # Approve từ danh sách "đơn của tôi"
│
├── SharePoint/
│   ├── ApprovalMatrix_SY2425.csv   # Ma trận người duyệt theo Subsidiary/Dept/Campus/Curriculum
│   ├── DOA_Matrix_SY2425.csv       # Ma trận uỷ quyền tài chính theo amount
│   ├── SY2425-PR-GeneralInfo.csv   # Header đơn mua hàng
│   ├── SY2425-PR_Item.csv          # Chi tiết dòng hàng
│   ├── SY2425-Approval_log.csv     # Audit log từng bước duyệt
│   ├── SY2425_PR_Comments.csv      # Bình luận trên đơn
│   └── NS_Master_Subsidiary.csv    # Danh mục công ty pháp nhân
│
└── Workato/                        # (Trống — flows cấu hình trực tiếp trên cloud)
```

---

## 13. Glossary

| Thuật ngữ | Ý nghĩa |
|---|---|
| RF | Request Form — tên gọi đơn mua hàng trong hệ thống |
| PR | Purchase Request |
| DOA | Delegation of Authority — uỷ quyền phê duyệt tài chính |
| FBP | Finance Business Partner (School level) |
| CBSO | Chief Business Strategy Officer (XMCO group level) |
| XMCO | Tên tắt của công ty mẹ quản lý các trường |
| RealKids | Nhánh trường mầm non, có quy tắc approver riêng |
| MYR | Malaysian Ringgit — đơn tệ chuẩn để so sánh DOA |
| NS / NetSuite | Hệ thống ERP tích hợp (Oracle NetSuite) |
| Workato | Nền tảng iPaaS dùng để kết nối Power Apps ↔ NetSuite |
| StageCheck | Tên stage ghi trong Approval_log, dùng để map logic |
| LogType | Loại log, dùng để tạo key dedup (`PR_No|ApprovedBy|LogType`) |
| varRFStage | Số thứ tự của stage hiện tại trên Header đơn |
| varCurrentStage | Số thứ tự của stage trong log đang xử lý |
