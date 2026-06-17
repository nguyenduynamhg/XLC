# Power Fx Giải Thích Chi Tiết — Luồng Approve (Mục 5.2)
> **Dành cho người mới** | Tài liệu bổ sung cho `OVERVIEW_PR_System.md` → Mục 5.2

---

## Mục lục
- [Tra cứu nhanh các hàm Power Fx](#tra-cứu-nhanh-các-hàm-power-fx)
- [Pre — Hiển thị loading spinner](#pre)
- [Bước 0 — Tính TotalAmount_MYR](#bước-0)
- [Bước 0b — Xác định RouteType](#bước-0b)
- [Bước 1 — Lấy latestPendingRecord](#bước-1)
- [Bước 2 — Map stage sang số](#bước-2)
- [Bước 3 — Build DOA collection](#bước-3)
- [Bước 4 — Đánh dấu Approved](#bước-4)
- [Bước 4b — GUARD kiểm tra log lỗi thời](#bước-4b)
- [Bước 5 — Phân nhánh chính](#bước-5)
- [Bước 6 — Dedup](#bước-6)
- [Bước 7 — Kết thúc](#bước-7)

---

## Tra cứu nhanh các hàm Power Fx

| Hàm | Công dụng | Trả về |
|---|---|---|
| `Set(biến, giá_trị)` | Gán biến **toàn cục** (dùng được ở mọi màn hình) | — |
| `UpdateContext({biến: giá_trị})` | Gán biến **cục bộ** (chỉ màn hình hiện tại) | — |
| `Filter(Bảng, điều_kiện)` | Lọc bảng, giữ các dòng thoả điều kiện | Bảng con (0 → N dòng) |
| `First(Bảng)` | Lấy dòng **đầu tiên** | 1 bản ghi hoặc `Blank` |
| `Last(Bảng)` | Lấy dòng **cuối cùng** | 1 bản ghi hoặc `Blank` |
| `SortByColumns(Bảng, "Cột", Desc)` | Sắp xếp bảng theo cột | Bảng đã sắp xếp |
| `Sort(Bảng, Cột, Ascending)` | Sắp xếp bảng (biểu thức linh hoạt hơn) | Bảng đã sắp xếp |
| `Switch(giá_trị, match1, kq1, match2, kq2, ...)` | So khớp giá trị → trả kết quả tương ứng (giống switch-case) | Giá trị tương ứng |
| `ClearCollect(tên, nguồn)` | **Xoá sạch** collection cũ rồi nạp dữ liệu mới | Collection (bảng tạm) |
| `Collect(tên, dữ_liệu)` | **Thêm vào** collection (nối đuôi, không xoá cũ) | Collection |
| `Patch(Bảng, bản_ghi, {cột: giá_trị})` | Cập nhật/tạo mới 1 dòng trên SharePoint List | Bản ghi đã cập nhật |
| `User().Email` | Lấy email người đang đăng nhập | Chuỗi VD: `"sk.lee@srikdu.edu.my"` |
| `IsBlank(giá_trị)` | Kiểm tra giá trị có rỗng/null không | `true` hoặc `false` |
| `Blank()` | Giá trị rỗng/null | Blank |
| `ParseJSON(chuỗi)` | Chuyển chuỗi JSON thành dữ liệu Power Fx | Untyped object |
| `ForAll(Bảng, hành_động)` | Lặp qua từng dòng, chạy hành động cho mỗi dòng | Bảng kết quả |
| `With({biến: giá_trị}, biểu_thức)` | Khai báo biến tạm dùng ngay (giống `let x = ...`) | Kết quả biểu thức |
| `Distinct(Bảng, biểu_thức)` | Trả về danh sách giá trị **duy nhất** | Bảng 1 cột |
| `RemoveIf(Bảng, điều_kiện)` | Xoá tất cả dòng thoả điều kiện khỏi SharePoint | — |
| `Now()` | Thời điểm hiện tại (ngày + giờ) | DateTime |
| `Notify(text, type)` | Hiện thông báo cho người dùng | — |

---

## [Pre]

**Code:**
```
Set(varSpinner, true)
UpdateContext({isApproving: true})
```

**Giải thích:**
- `Set(varSpinner, true)` → UI hiện vòng xoay "đang xử lý" để người dùng biết hệ thống đang chạy, tránh bấm nhiều lần.
- `UpdateContext({isApproving: true})` → biến cục bộ dùng để disable các nút khác trong lúc đang xử lý.

---

## Bước 0

**Code:**
```
calTotalAmoutMYR = TotalAmount × ExchangeRate(Currency)
→ Patch(GeneralInfo, TotalAmount_MYR: calTotalAmoutMYR)
```

**Tại sao:** Đơn PR có thể nhập bằng USD, SGD... nhưng DOA Matrix so sánh bằng MYR. Nếu `TotalAmount_MYR` chưa có giá trị (= 0 hoặc Blank), hệ thống tự tính `Tổng tiền gốc × Tỷ giá` rồi ghi lại vào SharePoint.

---

## Bước 0b

**Code:**
```
If(RouteType = "RealKids",
    Set(PRRouteType, "RealKids"),
    Set(PRRouteType, "0")
)
```

**Tại sao:** Quyết định đơn đi nhánh duyệt thường hay nhánh RealKids (mầm non) — ảnh hưởng đến việc chọn Budget Owner ở bước 5.

---

## Bước 1

### Mục đích: Tìm bản ghi "đang chờ duyệt" của người bấm Approve

**Code thực tế:**
```
Set(latestPendingRecord,
    First(
        SortByColumns(
            Filter(
                'SY2425-Approval_log',
                PR_No   = selectedPR_No        // chỉ đơn PR đang xem
                && field_7 = User().Email       // field_7 = cột "Approved By"
                && Status  = "Pending"          // chỉ lấy log chờ duyệt
            ),
            "Created", SortOrder.Descending     // mới nhất lên đầu
        )
    )
)
```

**Luồng dữ liệu từng bước:**
```
Approval_log (hàng trăm dòng tất cả đơn)
  │
  ├─ Filter → chỉ giữ dòng:
  │     PR_No = "RF0626-0001"
  │     VÀ field_7 = "sk.lee@srikdu.edu.my"
  │     VÀ Status = "Pending"
  │
  ├─ Kết quả: 1–2 dòng (thường chỉ 1)
  │
  ├─ SortByColumns("Created", Descending)
  │   → xếp dòng mới nhất lên đầu
  │
  └─ First() → lấy dòng đầu = dòng mới nhất
        → latestPendingRecord = {
              PR_No: "RF0626-0001",
              field_7: "sk.lee@srikdu.edu.my",
              Stage: "Level5",
              StageCheck: "Level5",
              Status: "Pending",
              Created: 2026-06-15 10:30:00, ...
          }
```

**Nếu `IsBlank(latestPendingRecord)` = true:**
→ Không tìm thấy bản ghi Pending nào cho user này → Hiện lỗi → DỪNG.

**Tại sao `First` + `Sort` thay vì `LookUp`?**
`LookUp` trả về **bất kỳ** 1 dòng đầu tiên khớp, không đảm bảo mới nhất. `Filter` + `Sort` + `First` đảm bảo lấy đúng bản ghi mới nhất (phòng trường hợp có nhiều bản Pending trùng do dedup chưa chạy).

---

## Bước 2

### Mục đích: Chuyển tên stage (text) thành số thứ tự để so sánh

**Code thực tế:**
```
// Từ bản ghi Pending vừa tìm ở bước 1:
Set(varCurrentStage,
    Switch(latestPendingRecord.StageCheck,
        "Reviewer",    1,
        "Reviewer2",   2,
        "BudgetOwner", 3,
        "Level5",      4,
        "Level6",      5,
        "Level7",      6,
        "Level8",      7,
        "Level9",      8,
        "Level10",     9
    )
)

Set(varCurrentDOAOrder,
    Switch(latestPendingRecord.StageCheck,
        "Level5",  5,
        "Level6",  6,
        "Level7",  7,
        "Level8",  8,
        "Level9",  9,
        "Level10", 10,
        Blank()           // Reviewer/Reviewer2/BudgetOwner → không phải DOA
    )
)

// Từ header đơn PR:
Set(varRFStage,
    Switch(selectedPR.Status,
        "Reviewer",       1,
        "Reviewer2",      2,
        "BudgetOwner",    3,
        "Level5",         4,
        "Level6",         5,
        "Level7",         6,
        "Level8",         7,
        "Level9",         8,
        "Level10",        9,
        "Final Approved", 10
    )
)
```

**3 biến này để làm gì?**

| Biến | Nguồn | Ý nghĩa | Ví dụ |
|---|---|---|---|
| `varCurrentStage` | Từ **Approval Log** (bản ghi Pending) | Số thứ tự stage của log đang xử lý | StageCheck = "Level5" → `4` |
| `varCurrentDOAOrder` | Từ **Approval Log** | Số StageOrder DOA (chỉ Level5–10 mới có) | StageCheck = "Level5" → `5` |
| `varRFStage` | Từ **header đơn PR** (GeneralInfo.Status) | Số thứ tự stage hiện tại trên đơn | Status = "Level5" → `4` |

**Tại sao cần cả `varCurrentStage` lẫn `varRFStage`?**

Để phát hiện **log lỗi thời**: nếu `varCurrentStage < varRFStage`, nghĩa là đơn đã tiến xa hơn log này.

VD: Đơn đang ở Level6 (`varRFStage = 5`) nhưng log Pending cũ của Level5 (`varCurrentStage = 4`) chưa bị xoá.
→ `4 < 5` → chỉ đánh dấu Approved rồi dừng, **không tạo stage mới**.

---

## Bước 3

### Mục đích: Xác định đơn này cần bao nhiêu cấp duyệt DOA

**Code thực tế:**
```
ClearCollect(colDOAForRF,
    Filter(
        'DOA_Matrix_SY2425',
        Subsidiary    = selectedPR.Item_Subsidiary
        && Campus     = selectedPR.Item_Campus
        && Threshold_Min <= calTotalAmoutMYR
    )
)

Set(varDOAFinalStageOrder,
    Last(
        Sort(colDOAForRF, StageOrder, SortOrder.Ascending)
    ).StageOrder
)
```

**Luồng dữ liệu** (đơn 80,000 MYR, campus SKKD):
```
DOA_Matrix_SY2425 (tất cả dòng, mọi campus)
  │
  ├─ Filter:
  │     Subsidiary = "Sri KDU Sdn Bhd"
  │     VÀ Campus  = "SKKD : Whole School"
  │     VÀ Threshold_Min ≤ 80,000
  │
  ├─ colDOAForRF = 3 dòng:
  │   ┌────────────┬──────────────┬───────────────┐
  │   │ StageOrder │ StageName    │ Threshold_Min │
  │   ├────────────┼──────────────┼───────────────┤
  │   │ 5          │ School FBP   │ 1             │
  │   │ 6          │ XMCO CBSO    │ 20,001        │
  │   │ 7          │ XMCO CFO     │ 50,001        │
  │   └────────────┴──────────────┴───────────────┘
  │   (Level8/9/10 bị loại vì Threshold_Min > 80,000)
  │
  ├─ Sort(StageOrder, Ascending) → 5, 6, 7
  │
  └─ Last() → dòng có StageOrder = 7
        → varDOAFinalStageOrder = 7
```

**`varDOAFinalStageOrder` dùng ở đâu?**

Khi mỗi cấp DOA duyệt xong, hệ thống so sánh `varCurrentDOAOrder` với `varDOAFinalStageOrder`:
- **Bằng nhau** → đơn `Final Approved` (xong!)
- **Nhỏ hơn** → tạo Pending cho cấp DOA kế tiếp

**Tại sao `ClearCollect` thay vì `Collect`?**

- `Collect` = **thêm vào** dữ liệu cũ (nối đuôi)
- `ClearCollect` = **xoá sạch rồi thêm mới**

Mỗi lần approve xử lý 1 đơn khác nhau → cần collection sạch để tránh lẫn dữ liệu đơn cũ.

---

## Bước 4

**Code:**
```
Patch('SY2425-Approval_log', latestPendingRecord, { Status: "Approved" })
```

Cập nhật bản ghi Pending tìm ở bước 1 thành `Approved`. Bản ghi này xong nhiệm vụ.

---

## Bước 4b

### GUARD — Kiểm tra log có bị lỗi thời không

**Code:**
```
If(varCurrentStage < varRFStage, ...)
```

**Tình huống:** Đơn đang ở Level6 (`varRFStage = 5`) nhưng log Pending cũ Level5 (`varCurrentStage = 4`) vẫn tồn tại.
→ `4 < 5` = true → chỉ mark Approved + Dedup → **DỪNG** (đơn đã đi xa hơn, không cần tạo stage mới).

---

## Bước 5

### Phân nhánh chính — Xác định bước tiếp theo

Đây là phần logic lớn nhất, chia 2 nhánh:

### Nhánh A: `varCurrentStage <= 3` (Reviewer / Reviewer2 / BudgetOwner)

**A1 — Vừa duyệt xong BudgetOwner:**
```
If(CountRows(colDOAForRF) > 0,
    // CÓ DOA → chuyển sang cấp DOA đầu tiên
    With({_firstDOARec: First(Sort(colDOAForRF, StageOrder, Ascending))},
        Patch(GeneralInfo, Status: _firstDOARec.StageName);
        Patch(Approval_log, tạo Pending cho _firstDOARec.ApproverEmail)
    ),
    // KHÔNG CÓ DOA → BudgetOwner là cấp cuối
    Patch(GeneralInfo, Status: "Final Approved", FinalApprovedDate: Now());
    Patch(log, Status: "Final Approved")
)
```

**A2 — Vừa duyệt xong Reviewer hoặc Reviewer2:**
```
varNextStage = varCurrentStage + 1    // 1+1=2 hoặc 2+1=3

// Cập nhật header đơn sang stage tiếp
Patch(GeneralInfo, Status: Switch(varNextStage,
    2, "Reviewer2",
    3, "BudgetOwner"
))

// Tìm email người duyệt tiếp:
// - Nếu stage 2 → ParseJSON(Matrix.Reviewer2) lấy danh sách email
// - Nếu stage 3 → lấy Budget Owner (hoặc RKManager cho RealKids)

ForAll(varNextApproverList,
    Patch(Approval_log, tạo Pending cho mỗi email)
)
```

> **`ParseJSON` là gì?** Cột Reviewer2 trong Approval Matrix lưu dạng chuỗi JSON: `'["a@co.my","b@co.my"]'`. `ParseJSON` chuyển chuỗi này thành bảng dữ liệu để `ForAll` duyệt qua từng email.

> **`ForAll` là gì?** Lặp qua từng dòng trong bảng, tạo 1 bản ghi Pending cho **mỗi** email. VD: Reviewer2 có 4 email → tạo 4 bản ghi Pending.

### Nhánh B: `varCurrentStage >= 4` (Level5 → Level10, các cấp DOA)

```
With({
    _finalOrder:   varDOAFinalStageOrder,    // cấp cao nhất cần duyệt (VD: 7)
    _currentOrder: varCurrentDOAOrder        // cấp vừa duyệt xong (VD: 5)
},
    If(_currentOrder = _finalOrder,
        // ĐÂY LÀ CẤP CUỐI → XONG!
        Patch(GeneralInfo, Status: "Final Approved", FinalApprovedDate: Now()),

        // CÒN CẤP CAO HƠN → tìm cấp kế tiếp
        With({_nextDOARec: First(Filter(colDOAForRF, StageOrder > _currentOrder))},
            Patch(GeneralInfo, Status: _nextDOARec.StageName);
            Patch(Approval_log, tạo Pending cho _nextDOARec.ApproverEmail)
        )
    )
)
```

> **`With` là gì?** Khai báo biến tạm rồi dùng ngay bên trong. Giống `let x = 5 in x + 1` trong các ngôn ngữ hàm. Ở đây tạo `_finalOrder` và `_currentOrder` để code bên trong gọn hơn.

---

## Bước 6

### DEDUP — Dọn dẹp bản ghi Pending trùng lặp

**Code:**
```
ClearCollect(colDuplicateKeys,
    Distinct(
        Filter('SY2425-Approval_log', PR_No = X && Status = "Pending"),
        PR_No & "|" & field_7 & "|" & LogType
    )
)

ForAll(colDuplicateKeys,
    // Với mỗi key trùng:
    // tìm tất cả bản ghi cùng key → Sort theo Modified → giữ bản mới nhất → xoá bản cũ
    Collect(colToDelete, các bản cũ hơn)
)

RemoveIf('SY2425-Approval_log', ID in colToDelete.ID)
```

**Giải thích:**
- `Distinct(Bảng, biểu_thức)` → tạo danh sách key duy nhất, VD: `"RF0626-0001|sk.lee@srikdu.edu.my|Level5"`
- `RemoveIf` → xoá tất cả dòng thừa khỏi SharePoint List
- **Mục đích:** Đảm bảo mỗi approver chỉ có **đúng 1** bản ghi Pending cho mỗi đơn

---

## Bước 7

**Code:**
```
Set(varSpinner, false)
Notify("Approval completed successfully.", NotificationType.Success)
```

Tắt spinner, hiện thông báo thành công.
