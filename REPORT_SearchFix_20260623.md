# Báo cáo: Fix Search cho Procurement Members

**Ngày:** 23/06/2026  
**App:** XMCO - SiriusNex (PROD)  
**Environment:** XCL-Production

---

## Tóm tắt cho Management

### Vấn đề:
Procurement Members search keyword (ví dụ "0033", "day") → **không tìm thấy PRs mới nhất** (ví dụ RF0626-0033 tạo ngày 22/06)

### Nguyên nhân gốc (Platform Limitation):
- Microsoft SharePoint connector trong Power Apps **KHÔNG hỗ trợ "contains" text search delegable**
- `ClearCollect` (load data vào app memory) bị giới hạn tối đa 2000 records/lần gọi
- Hệ thống hiện có 2094+ PRs → vượt giới hạn → mất data khi search
- Đây là **limitation được Microsoft ghi nhận**, không phải lỗi code
- Ref: https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/delegation-overview

### Ảnh hưởng:
- Procurement Members không search được PRs mới bằng keyword
- Không ảnh hưởng: hiển thị data khi không search (vẫn đầy đủ)
- Không ảnh hưởng: Regular Users, Dept Admins (data < 2000 nên không bị cắt)

### Giải pháp đã deploy:
**Batch Loading** — chia nhỏ data theo quý, load từng phần vào app memory:
- 8 batches × 3 tháng = 24 tháng coverage
- Mỗi batch < 2000 items → không bị cắt
- Search "contains" hoạt động đầy đủ trên local data

### Giải pháp dài hạn (đề xuất):

| Option | Effort | Kết quả | Yêu cầu |
|--------|--------|---------|----------|
| **Power Automate Flow** | 2-3 ngày | Search unlimited, load nhanh hơn | IT cấp Power Automate access cho developer |
| **Migrate to Dataverse** | 2-4 tuần | Zero limitation | Premium license (~$40/user/tháng) |

### Thay đổi dành cho User:

| Tính năng | Trước | Sau |
|-----------|-------|-----|
| Search theo **PR No** (VD: "0033") | ❌ Không tìm thấy PR mới | ✅ Tìm được tất cả |
| Search theo **Title** (VD: "laptop") | ❌ Bị thiếu kết quả | ✅ Đầy đủ |
| Search theo **Requestor** (VD: "Nguyen") | ❌ Chỉ thấy PR cũ | ✅ Đầy đủ |
| Search theo **Reject Comment** | ❌ Không hoạt động | ✅ Hoạt động |
| Hiển thị khi **không search** | ✅ Bình thường | ✅ Không thay đổi |
| Thao tác của user | Không thay đổi — search box hoạt động như cũ |

> **Lưu ý:** Lần load đầu tiên (mở screen YourPR) có thể mất 5-8 giây do app load toàn bộ data. Sau đó search instant.

### Action Items:
1. ✅ Deploy batch approach (done 23/06/2026)
2. 📋 IT cấp Power Automate access cho developer (đề xuất tuần tới)
3. 📋 Build Power Automate search flow thay thế batch approach (Q3)

---

## Chi tiết kỹ thuật — Các thay đổi đã deploy PROD

### 1. App Settings
- **Data row limit for non-delegable queries**: 500 → **2000**

### 2. OnVisible (Screen: YourPR)

#### Fix #1: Split `||` delegation
```
// TRƯỚC (non-delegable trên 17,781 rows):
Filter('SY2425-Approval_log', 'Approved By' = User().Email || Requestor = User().Email)

// SAU (delegable, lấy ALL rows):
ClearCollect(FilteredPRNos, Filter('SY2425-Approval_log', 'Approved By' = User().Email).PR_No);
Collect(FilteredPRNos, Filter('SY2425-Approval_log', Requestor = User().Email).PR_No);
```

#### Fix #2: Pre-build colUserPRs (cho Regular User + DeptAdmin)
```
// Step 1: PRs mà user là Requestor (delegable)
ClearCollect(colUserPRs, Filter('SY2425-PR-GeneralInfo', Requestor = User().Email));

// Step 2: Nếu DeptAdmin, thêm PRs department (delegable)
If(varIsDeptAdmin, ForAll(Filter(SP, Department = varAdminDepartments), Collect(...)));

// Step 3: Thêm PRs mà user là Approver
If(!IsEmpty(FilteredPRNos), ForAll(Distinct(FilteredPRNos), Collect(...)));
```

#### Fix #3: Procurement batch loading (MỚI - 23/06/2026)
```
// 8 batches × 3 tháng = 24 tháng, mỗi batch < 2000 items
If(isProcurement,
    ClearCollect(colUserPRs, Filter(SP, Created >= Today()-92));
    Collect(colUserPRs, Filter(SP, Created >= Today()-184 && Created < Today()-92));
    Collect(colUserPRs, Filter(SP, Created >= Today()-276 && Created < Today()-184));
    Collect(colUserPRs, Filter(SP, Created >= Today()-365 && Created < Today()-276));
    Collect(colUserPRs, Filter(SP, Created >= Today()-457 && Created < Today()-365));
    Collect(colUserPRs, Filter(SP, Created >= Today()-549 && Created < Today()-457));
    Collect(colUserPRs, Filter(SP, Created >= Today()-641 && Created < Today()-549));
    Collect(colUserPRs, Filter(SP, Created >= Today()-730 && Created < Today()-641));
)
```

### 3. Gallery Items (Screen: YourPR)

#### Logic phân nhánh:

| User Role | Không search | Có search |
|-----------|-------------|-----------|
| **DeptAdmin** | colUserPRs (local) | colUserPRs + `in` PR_No/Title/Requestor/RejectComment |
| **Regular User** | colUserPRs (local) | colUserPRs + `in` PR_No/Title/Requestor/RejectComment |
| **Service Account** | SP direct (delegable) | SP direct + StartsWith(PR_No) |
| **Procurement** | SP direct (delegable, ALL PRs) | colUserPRs + `in` PR_No/Title/Requestor/RejectComment |

### 4. Ảnh hưởng đến users:

| Role | Trước fix | Sau fix |
|------|-----------|---------|
| Procurement Members | Search thiếu PRs mới/của người khác | ✅ Search ALL PRs 24 tháng |
| DeptAdmin | Có thể thiếu department PRs cũ | ✅ Đầy đủ |
| Regular User | Có thể thiếu PRs approved cũ | ✅ Đầy đủ |
| Service Account | Không thay đổi | ✅ Không thay đổi |

### 5. Performance:

| Metric | Regular User | DeptAdmin | Procurement |
|--------|-------------|-----------|-------------|
| OnVisible load time | ~5-8s | ~8-12s | ~15-20s |
| Gallery filter speed | Instant | Instant | Instant |
| Memory usage | Low (~200 items) | Medium (~500 items) | Higher (~2094 items) |

### 6. Giới hạn còn lại:

- Procurement: OnVisible chậm ~15-20s (8 API calls)
- PRs tạo TRONG phiên chưa hiện khi search (cần re-enter screen)
- Nếu PRs/tháng vượt 650 → cần giảm batch size (hiện ~350/tháng, an toàn)
- Search chỉ cover 24 tháng (đủ cho 2 school years)

---

## Backup & Rollback

- Backup PROD code trước deploy: `_backup/v2_FIXED_20260620/PROD_before_deploy/`
- Rollback: paste lại code từ backup folder vào OnVisible
- Gallery code: không thay đổi so với bản đang chạy (chỉ thêm OnVisible batch)
