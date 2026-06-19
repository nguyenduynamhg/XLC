# Luồng Gen Approval Log — Tra điều kiện gì, nguồn nào?

> Tài liệu này mô tả chi tiết từng bước hệ thống tạo bản ghi Approval Log, dựa vào bảng nào, key nào, lấy email từ đâu.

---

## Tổng quan

Hệ thống tạo Approval Log (bản ghi "Chờ duyệt") tại **5 thời điểm** khác nhau:

| # | Thời điểm | Nút bấm | Bảng tra | Kết quả |
|---|---|---|---|---|
| 1 | Nhân viên submit đơn mới | `btnSubmit` (PR_OnlineForm_New) | ApprovalMatrix | Tạo log Reviewer Pending |
| 2 | Reviewer approve | `btnApprove` (PR_Detail / YourPR) | ApprovalMatrix | Tạo log Reviewer2 Pending |
| 3 | Reviewer2 approve | `btnApprove` | ApprovalMatrix | Tạo log BudgetOwner Pending |
| 4 | BudgetOwner approve | `btnApprove` | DOA_Matrix | Tạo log Level5 Pending (hoặc Final Approved) |
| 5 | Level5–9 approve | `btnApprove` | DOA_Matrix (collection) | Tạo log Level kế tiếp Pending (hoặc Final Approved) |

---

## Bước 1: Submit đơn mới → Gen Reviewer Pending

**File:** `PR_OnlineForm_New/btnSubmit.fx` (bước 3.11–3.13)

### Bảng tra cứu
`ApprovalMatrix_SY2425`

### Key tra cứu (4 cột)
| Key | Nguồn giá trị | Code |
|---|---|---|
| Subsidiary | Form grid — dòng hàng đầu tiên | `First(itemGrid.AllItems).txtItemSubsidiary.Selected.Name` |
| Dept | Form grid — dòng hàng đầu tiên | `First(itemGrid.AllItems).txtItemDepartment.Selected.DepartmentName` |
| Campus | Form grid — dòng hàng đầu tiên | `First(itemGrid.AllItems).drpCampuNew.Selected.CampusName` |
| Curriculum | Form grid — dòng hàng đầu tiên | `First(itemGrid.AllItems).cmbCurriculum.Selected.CurriculumName` |

### Cột lấy email
`.Reviewer` → JSON array, ví dụ: `["naqib@srikdu.edu.my","hamizah@xcledu.my"]`

### Xử lý
```
ParseJSON(Reviewer) → ForAll → Patch Approval_log
{
    'Approved By': R.Email,
    Stage: "Reviewer",
    StageCheck: "Reviewer",
    Status: "Pending",
    LogType: "Reviewer"
}
```

### Đặc điểm
- Có thể tạo **NHIỀU** log Pending (1 cho mỗi email trong JSON array)
- Key lấy từ **form đang mở** (chưa lưu lên SharePoint)

---

## Bước 2: Reviewer approve → Gen Reviewer2 Pending

**File:** `PR_OnlineForm_PR_Detail/btnApprove.fx` (bước 5, nhánh A2, varNextStage=2)

### Bảng tra cứu
`ApprovalMatrix_SY2425`

### Key tra cứu (4 cột)
| Key | Nguồn giá trị | Code |
|---|---|---|
| Subsidiary | GeneralInfo header đã lưu | `SelectedPR.Item_Subsidiary` |
| Dept | GeneralInfo header đã lưu | `SelectedPR.Item_Dept` |
| Campus | GeneralInfo header đã lưu | `SelectedPR.Item_Campus` |
| Curriculum | GeneralInfo header đã lưu | `SelectedPR.Item_Curriculum` |

### Cột lấy email
`.Reviewer2` → JSON array

### Xử lý
```
LookUp(ApprovalMatrix_SY2425, Subsidiary=X && Dept=X && Campus=X && Curriculum=X).Reviewer2
→ ParseJSON → ForAll → Patch Approval_log
{
    'Approved By': NextAppr.Email,
    'Approver Name': Office365Users.UserProfileV2(Email).displayName,
    Stage: "Reviewer2",
    StageCheck: "Reviewer2",
    Status: "Pending",
    LogType: "Reviewer2"
}
```

### Đặc điểm
- Có thể tạo **NHIỀU** log Pending
- Key lấy từ **header GeneralInfo** (đã lưu trên SharePoint khi submit)

---

## Bước 3: Reviewer2 approve → Gen BudgetOwner Pending

**File:** `PR_OnlineForm_PR_Detail/btnApprove.fx` (bước 5, nhánh A2, varNextStage=3)

### Bảng tra cứu
`ApprovalMatrix_SY2425`

### Key tra cứu (4 cột) — giống bước 2
| Key | Nguồn giá trị | Code |
|---|---|---|
| Subsidiary | GeneralInfo header | `SelectedPR.Item_Subsidiary` |
| Dept | GeneralInfo header | `SelectedPR.Item_Dept` |
| Campus | GeneralInfo header | `SelectedPR.Item_Campus` |
| Curriculum | GeneralInfo header | `SelectedPR.Item_Curriculum` |

### Cột lấy email — phụ thuộc điều kiện
```
Nếu PRRouteType = "RealKids":
    Nếu Dept = "Operations : Facility"  → .Budget Owner
    Nếu TotalAmount_MYR ≤ 2,500        → .RKManager
    Nếu TotalAmount_MYR > 2,500         → .RKManager2
Ngược lại (K12 thường):
    → .Budget Owner
```

### Xử lý
```
LookUp(ApprovalMatrix_SY2425, ...) → lấy 1 email → Table({ Email: _FinalEmail })
→ ForAll → Patch Approval_log
{
    'Approved By': NextAppr.Email,
    Stage: "BudgetOwner",
    StageCheck: "BudgetOwner",
    Status: "Pending",
    LogType: "BudgetOwner"
}
```

### Đặc điểm
- Luôn tạo **1** log Pending (Budget Owner là 1 người duy nhất)
- Có logic đặc biệt cho RealKids (mầm non)

---

## Bước 4: BudgetOwner approve → Gen Level5 Pending (hoặc Final Approved)

**File:** `PR_OnlineForm_PR_Detail/btnApprove.fx` (bước 5, nhánh A1)

### Bảng tra cứu
`DOA_Matrix_SY2425`

### Key tra cứu (3 cột) ⚠️ KHÁC với bước 1–3
| Key | Nguồn giá trị | Code |
|---|---|---|
| Subsidiary | GeneralInfo header | `SelectedPR.Item_Subsidiary` |
| Campus | GeneralInfo header | `SelectedPR.Item_Campus` |
| TotalAmount_MYR | GeneralInfo header | `SelectedPR.TotalAmount_MYR` |

> ⚠️ **KHÔNG dùng Dept và Curriculum** — DOA chỉ phân biệt theo Subsidiary + Campus + số tiền

### Logic
```
// Build collection DOA cho đơn này
ClearCollect(colDOAForRF,
    Filter(DOA_Matrix_SY2425,
        Subsidiary    = varRFSubsidiary &&
        Campus        = varRFCampus &&
        Threshold_Min <= varRFTotalMYR))

// Tìm DOA record đầu tiên (StageOrder nhỏ nhất ≥ 5)
_firstDOARec = First(Sort(Filter(colDOAForRF, StageOrder >= 5), StageOrder, Asc))
```

### Phân nhánh
```
colDOAForRF RỖNG (không có DOA nào match):
    → Patch GeneralInfo Status = "Final Approved"
    → Patch log hiện tại Status = "Final Approved"
    → KHÔNG tạo log mới

colDOAForRF CÓ dữ liệu:
    → Patch GeneralInfo Status = "Level5" (hoặc Level cao hơn nếu Threshold không có 5)
    → Patch Approval_log mới:
    {
        'Approved By': _firstDOARec.ApproverEmail,
        'Approver Name': _firstDOARec.ApproverName,
        Stage: "Level5",
        StageCheck: "Level5",
        Status: "Pending",
        LogType: _firstDOARec.StageName     ← ví dụ: "School FBP"
    }
```

### Đặc điểm
- Luôn tạo **1** log Pending (DOA là 1 người/cấp)
- Email lấy trực tiếp từ DOA_Matrix (không phải JSON array)
- **2 Patch liên tiếp bằng dấu `;`** — nếu Patch #2 fail thì GeneralInfo đã chuyển Level5 nhưng log không tồn tại (bug đã gặp ở RF0526-0106)

---

## Bước 5: Level5–9 approve → Gen Level kế tiếp Pending (hoặc Final Approved)

**File:** `PR_OnlineForm_PR_Detail/btnApprove.fx` (bước 5, nhánh B)

### Bảng tra cứu
`colDOAForRF` — collection đã build sẵn ở đầu hàm (giống bước 4)

### Key tra cứu
Không tra lại DOA_Matrix. Dùng collection đã có, lọc tiếp:
```
_nextDOARec = First(
    Sort(
        Filter(colDOAForRF, StageOrder > _currentOrder && StageOrder <= _finalOrder),
        StageOrder, Asc
    )
)
```

### Phân nhánh
```
_currentOrder = _finalOrder (đây là cấp DOA cuối cùng):
    → Patch GeneralInfo Status = "Final Approved", FinalApprovedDate = Now()
    → Patch log hiện tại Status = "Final Approved"
    → KHÔNG tạo log mới

_currentOrder < _finalOrder (còn cấp DOA cao hơn):
    → Patch GeneralInfo Status = _nextStageName (ví dụ "Level6")
    → Patch Approval_log mới:
    {
        'Approved By': _nextDOARec.ApproverEmail,
        'Approver Name': _nextDOARec.ApproverName,
        Stage: _nextStageName,
        StageCheck: _nextStageName,
        Status: "Pending",
        LogType: _nextDOARec.StageName    ← ví dụ: "XMCO CBSO"
    }
```

### Đặc điểm
- Luôn tạo **1** log Pending
- Dùng collection build từ đầu hàm, KHÔNG query lại DOA_Matrix
- Cùng pattern 2 Patch liên tiếp → cùng rủi ro silent failure

---

## So sánh các lần Gen — Có giống nhau không?

### Khác biệt 1: Nguồn gốc Key

| Lần | Nguồn key | Rủi ro |
|---|---|---|
| Bước 1 (Submit) | **Form grid đang mở** — chưa lưu SP | Key đúng tại thời điểm user chọn |
| Bước 2–5 (Approve) | **GeneralInfo header đã lưu** — `SelectedPR.Item_*` | Nếu ai đó dùng btnSave sửa grid nhưng không cập nhật `Item_*` → key lệch |

### Khác biệt 2: Bảng tra + số cột key

| Lần | Bảng | Số key | Dept? | Curriculum? |
|---|---|---|---|---|
| Bước 1–3 | ApprovalMatrix | **4 cột** | ✅ Có | ✅ Có |
| Bước 4–5 | DOA_Matrix | **3 cột** | ❌ Không | ❌ Không |

→ 2 bảng dùng bộ key **KHÁC NHAU**. DOA không quan tâm phòng ban/chương trình, chỉ quan tâm công ty + campus + số tiền.

### Khác biệt 3: Format email

| Bảng | Format | Số người |
|---|---|---|
| ApprovalMatrix.Reviewer | JSON array `["a@x","b@x"]` | Nhiều người |
| ApprovalMatrix.Reviewer2 | JSON array | Nhiều người |
| ApprovalMatrix.Budget Owner | Text đơn | 1 người |
| DOA_Matrix.ApproverEmail | Text đơn | 1 người |

### Khác biệt 4: Cơ chế Patch

| Lần | Số Patch trước đó | Rủi ro throttle |
|---|---|---|
| Bước 1 (Submit) | ~3 Patch (GeneralInfo + Items) | Trung bình |
| Bước 4 (BudgetOwner→Level5) | ~2 Patch (mark Approved + GeneralInfo) | **Cao** — đây là lúc hay bị fail |
| Bước 5 (Level→Level) | ~2 Patch | Cao |

---

## Case study: RF0526-0106 — Level5 log bị mất

```
Timeline:
1. BudgetOwner (lili.a) bấm Approve
2. Code build colDOAForRF → match campus "Real Schools : RSSA : NATL : Secondary"
3. Tìm _firstDOARec → StageOrder=5, nazar.helmi@xcledu.my
4. Patch #1: GeneralInfo.Status = "Level5"     ✅ THÀNH CÔNG
5. Patch #2: Approval_log Level5 Pending       ❌ THẤT BẠI (silent)

Kết quả:
- GeneralInfo hiện Level5 nhưng không có log Pending
- Nazar không thấy đơn trong app
- Phải thêm thủ công bản ghi Approval_log

Nguyên nhân: Power Apps không có transaction, Patch fail silent
```

---

## Sơ đồ tổng hợp

```
 SUBMIT (New)                    APPROVE (Detail/YourPR)
 ─────────────                   ───────────────────────
      │                                    │
      ▼                                    ▼
 ┌──────────────┐              ┌──────────────────────┐
 │ ApprovalMatrix│              │ Xác định stage hiện tại│
 │ Key: 4 cột   │              │ từ latestPendingRecord│
 │ Nguồn: FORM  │              └──────────┬───────────┘
 └──────┬───────┘                         │
        │                     ┌───────────┴───────────┐
        ▼                     ▼                       ▼
 Lấy .Reviewer         Stage ≤ 3               Stage ≥ 4
 (JSON array)           (Reviewer/R2/BO)        (DOA Levels)
        │                     │                       │
        ▼                     ▼                       ▼
 ParseJSON            ┌──────────────┐        ┌──────────────┐
 → ForAll             │ApprovalMatrix│        │ colDOAForRF  │
 → Patch log          │Key: 4 cột   │        │(đã build đầu)│
 (Reviewer Pending)   │Nguồn: HEADER│        │Key: 3 cột   │
                      └──────┬───────┘        │Nguồn: HEADER│
                             │                └──────┬───────┘
                             ▼                       ▼
                      Lấy .Reviewer2          Lấy .ApproverEmail
                      hoặc .Budget Owner      từ _firstDOARec
                      hoặc .RKManager         hoặc _nextDOARec
                             │                       │
                             ▼                       ▼
                      Patch log                Patch log
                      (R2/BO Pending)          (Level5+ Pending)
```
