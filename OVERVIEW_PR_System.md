# PR Online Form System — Business & Technical Overview
> **Scope:** SY2024–2025 | Platform: Power Apps Canvas App + SharePoint Online + Workato  
> **Document type:** Senior BA/Dev Analysis | Date: June 2026

---

## 0. Hướng dẫn đọc tài liệu (Dành cho người mới)

### Hệ thống này làm gì?
Đây là hệ thống **Đơn yêu cầu mua hàng (Purchase Request — PR)** dùng cho nhóm trường giáo dục (Sri KDU, R.E.A.L, XCL, RealKids...). Khi một nhân viên cần mua hàng hoá hoặc dịch vụ, họ sẽ:

1. **Tạo đơn PR** trên Power Apps → nhập thông tin nhà cung cấp, danh sách hàng hoá, số lượng, đơn giá
2. **Submit đơn** → hệ thống tự xác định ai cần duyệt (dựa trên phòng ban, campus, số tiền)
3. **Đơn đi qua nhiều cấp duyệt** (Reviewer → Budget Owner → các cấp lãnh đạo tuỳ theo số tiền)
4. **Sau khi duyệt xong** → hệ thống tự động tạo Purchase Order (PO) trên NetSuite (ERP)

### Các thành phần chính
| Thành phần | Vai trò | Ví von dễ hiểu |
|---|---|---|
| **Power Apps** | Giao diện người dùng (app) | Trang web để nhân viên tạo và duyệt đơn |
| **SharePoint Lists** | Cơ sở dữ liệu | Kho lưu trữ tất cả thông tin đơn hàng, log duyệt |
| **Approval Matrix** | Bảng cấu hình | "Bản đồ" cho hệ thống biết ai duyệt cho phòng ban/campus nào |
| **DOA Matrix** | Bảng cấu hình | "Thang tiền" — đơn bao nhiêu tiền thì phải ai duyệt |
| **Workato** | Nền tảng tích hợp | "Cầu nối" tự động giữa Power Apps và NetSuite |
| **NetSuite** | Hệ thống ERP | Hệ thống kế toán/tài chính chính thức của công ty |

### Nên đọc theo thứ tự
1. **Mục 0.1** — Luồng phê duyệt từ A đến Z (đọc trước để nắm toàn cảnh)
2. **Mục 1** — Glossary (Từ điển thuật ngữ) → hiểu các từ viết tắt
3. **Mục 2** — Kiến trúc tổng quan → hình dung hệ thống
4. **Mục 5** — Approval Engine → chi tiết kỹ thuật luồng duyệt
5. Sau đó đọc các mục còn lại tuỳ theo nhu cầu

### 0.1 Luồng phê duyệt từ A đến Z

> Đây là toàn bộ hành trình của một đơn mua hàng, từ lúc nhân viên tạo đơn cho đến khi hàng được đặt trên NetSuite.

**BƯỚC 1 — Nhân viên tạo đơn**
- Mở app Power Apps → màn hình "Tạo đơn mới"
- Nhập: tiêu đề, ngày cần hàng, mô tả, đính kèm báo giá
- Chọn nhà cung cấp, loại tiền, điều khoản thanh toán
- Thêm từng dòng hàng: tên hàng, số lượng, đơn giá, phòng ban, campus, mã thuế
- Bấm **Submit**

**BƯỚC 2 — Hệ thống xử lý khi Submit**
- Kiểm tra đã nhập đủ thông tin chưa → thiếu thì báo lỗi, dừng
- Kiểm tra phòng ban + campus có cấu hình người duyệt chưa (tra bảng Approval Matrix) → chưa có thì báo lỗi, dừng
- Tự sinh mã đơn: **RF0626-0001** (RF + tháng/năm + số tự tăng)
- Lưu thông tin đơn + danh sách hàng lên SharePoint
- Tra bảng **Approval Matrix** theo (Công ty con + Phòng ban + Campus + Chương trình) → tìm ra danh sách **Reviewer**
- Tạo bản ghi "Chờ duyệt" (Pending) cho từng Reviewer
- Trạng thái đơn: **Reviewer**

**BƯỚC 3 — Reviewer duyệt (cấp 1)**
- Reviewer mở app → thấy đơn trong danh sách chờ duyệt → bấm **Approve**
- Hệ thống tra Approval Matrix → tìm danh sách **Reviewer2**
- Tạo bản ghi Pending cho Reviewer2
- Trạng thái đơn: **Reviewer2**

**BƯỚC 4 — Reviewer2 duyệt (cấp 2)**
- Reviewer2 bấm **Approve**
- Hệ thống xác định **Budget Owner** (chủ ngân sách):
  - Trường thông thường → lấy từ cột "Budget Owner" trong Approval Matrix
  - Trường mầm non RealKids → lấy RKManager (≤ 2,500 MYR) hoặc RKManager2 (> 2,500 MYR)
- Tạo bản ghi Pending cho Budget Owner
- Trạng thái đơn: **BudgetOwner**

**BƯỚC 5 — Budget Owner duyệt (cấp 3)**
- Budget Owner bấm **Approve**
- Hệ thống quy đổi tổng tiền đơn sang **MYR**, rồi tra bảng **DOA Matrix**:
  - Tìm tất cả cấp duyệt có ngưỡng tiền ≤ tổng tiền đơn
  - Ví dụ: đơn 80,000 MYR → cần Level5 (FBP), Level6 (CBSO), Level7 (CFO)
- **Nếu không có cấp DOA nào** (đơn rất nhỏ hoặc không cấu hình) → đơn **Final Approved** luôn ✅
- **Nếu có** → chuyển sang cấp DOA đầu tiên (thường là Level5 — FBP)
- Trạng thái đơn: **Level5**

**BƯỚC 6 — Các cấp DOA duyệt lần lượt (cấp 5–10)**
- Mỗi cấp DOA bấm **Approve** → hệ thống tự chuyển sang cấp kế tiếp
- Thứ tự cố định: Level5 (FBP) → Level6 (CBSO) → Level7 (CFO) → Level8 (CEO) → Level9 (Group CFO) → Level10 (Group CEO)
- Không phải đơn nào cũng đi hết 6 cấp — **chỉ đi đến cấp cao nhất mà số tiền yêu cầu**
- Khi cấp DOA cuối cùng approve → đơn **Final Approved** ✅
- Trạng thái đơn: **Final Approved**

**BƯỚC 7 — Tạo PO trên NetSuite (tự động)**
- Workato phát hiện đơn vừa Final Approved
- Đọc thông tin đơn + danh sách hàng từ SharePoint (dùng mã PR làm khoá liên kết)
- Tạo Purchase Order (PO) trên NetSuite với đầy đủ: nhà cung cấp, dòng hàng, số lượng, đơn giá, thuế, phòng ban, campus
- Ghi số PO ngược lại SharePoint (cột NS_PO_No)

**CÁC TRƯỜNG HỢP NGOẠI LỆ**

| Hành động | Ai làm | Kết quả |
|---|---|---|
| **Return** (trả về) | Bất kỳ người duyệt nào | Đơn quay về Draft → nhân viên sửa → Submit lại từ đầu |
| **Reject** (từ chối) | Bất kỳ người duyệt nào | Đơn bị huỷ, ghi lý do từ chối |

> ⚠️ **Lưu ý:** Nút Return và Reject hiện đang **tắt trong code** — người duyệt chỉ có thể Approve. Email thông báo cho người duyệt kế tiếp cũng đang tắt.

**TÓM TẮT BẰNG SƠ ĐỒ**
```
Nhân viên tạo đơn
       │
       ▼
   [Submit] ── kiểm tra dữ liệu + tra Approval Matrix
       │
       ▼
   Reviewer (1 hoặc nhiều người) ── Approve
       │
       ▼
   Reviewer2 (1 hoặc nhiều người) ── Approve
       │
       ▼
   Budget Owner ── Approve
       │
       ├── Không cần DOA ──────────► Final Approved ✅
       │                                    │
       ▼                                    ▼
   Level5 (FBP) ── Approve            Workato tạo PO
       │                              trên NetSuite
       ▼
   Level6 (CBSO) ── Approve  ← chỉ nếu tiền đủ lớn
       │
       ▼
   Level7 (CFO) ── Approve   ← chỉ nếu tiền đủ lớn
       │
       ▼
   ...lên đến Level10 (Group CEO)
       │
       ▼
   Final Approved ✅ ──► Workato tạo PO trên NetSuite
```

---

## 1. Glossary — Từ điển thuật ngữ

### 1.1 Thuật ngữ nghiệp vụ (Business)
| Thuật ngữ | Viết tắt của | Giải thích chi tiết |
|---|---|---|
| **PR** | Purchase Request | Đơn yêu cầu mua hàng — tài liệu nhân viên gửi để xin phê duyệt chi tiêu |
| **RF** | Request Form | Tên gọi khác của PR trong hệ thống, dùng làm tiền tố mã đơn (VD: `RF0626-0001`) |
| **PO** | Purchase Order | Đơn đặt hàng — được tạo tự động trên NetSuite **sau khi** PR được duyệt hoàn toàn |
| **DOA** | Delegation of Authority | **Uỷ quyền phê duyệt tài chính** — bộ quy tắc xác định "đơn bao nhiêu tiền thì cần ai duyệt". VD: đơn ≤ 20,000 MYR chỉ cần FBP, nhưng đơn 500,000 MYR phải được duyệt lần lượt từ FBP → CBSO → CFO → CEO |
| **MYR** | Malaysian Ringgit | Đồng Ringgit Malaysia — **đơn vị tiền tệ chuẩn** dùng để so sánh với ngưỡng DOA. Dù đơn nhập bằng USD hay SGD, hệ thống sẽ quy đổi ra MYR để xác định cấp duyệt |
| **GL** | General Ledger | Tài khoản sổ cái — mã kế toán gắn với từng dòng hàng để phân bổ chi phí đúng tài khoản |
| **Subsidiary** | — | Công ty con / pháp nhân. VD: "Sri KDU Sdn Bhd", "R.E.A.L Education Group Sdn Bhd" |
| **Campus** | — | Cơ sở trường cụ thể. VD: "SKKD : Whole School", "Real Kids : Ampang" |

### 1.2 Vai trò trong luồng duyệt
| Vai trò | Viết tắt | Cấp (Stage) | Giải thích |
|---|---|---|---|
| **Reviewer** | — | 1 | Người soát xét cấp 1 — kiểm tra nội dung đơn (có thể là nhiều người, lưu dạng JSON array) |
| **Reviewer2** | — | 2 | Người soát xét cấp 2 — kiểm tra bổ sung |
| **Budget Owner** | — | 3 | Chủ ngân sách — người chịu trách nhiệm ngân sách cho phòng ban/bộ phận cụ thể |
| **FBP** | Finance Business Partner | 5 (Level5) | Kế toán tài chính cấp trường — cấp duyệt DOA thấp nhất |
| **CBSO** | Chief Business Strategy Officer | 6 (Level6) | Giám đốc chiến lược kinh doanh cấp XMCO |
| **XMCO CFO** | Chief Financial Officer | 7 (Level7) | Giám đốc tài chính cấp XMCO |
| **XMCO CEO** | Chief Executive Officer | 8 (Level8) | Giám đốc điều hành cấp XMCO |
| **Group CFO** | — | 9 (Level9) | Giám đốc tài chính cấp tập đoàn |
| **Group CEO** | — | 10 (Level10) | Giám đốc điều hành cấp tập đoàn — cấp duyệt cao nhất |
| **RKManager** | RealKids Manager | — | Quản lý nhánh RealKids (mầm non), duyệt đơn ≤ 2,500 MYR |
| **RKManager2** | — | — | Quản lý RealKids cấp cao hơn, duyệt đơn > 2,500 MYR |

### 1.3 Tên tổ chức
| Tên | Giải thích |
|---|---|
| **XMCO** | Tên tắt của công ty mẹ quản lý toàn bộ hệ thống trường (XCL Education group) |
| **RealKids** | Nhánh trường **mầm non** — có luồng duyệt đặc biệt, không dùng Budget Owner thông thường |
| **Sri KDU** | Hệ thống trường K-12 thuộc group |
| **R.E.A.L** | Hệ thống trường K-12 + mầm non thuộc group |

### 1.4 Thuật ngữ kỹ thuật
| Thuật ngữ | Giải thích |
|---|---|
| **Approval Matrix** | Bảng tra cứu trên SharePoint — xác định **ai là người duyệt** cho tổ hợp `Subsidiary + Dept + Campus + Curriculum`. Mỗi dòng chứa email Reviewer, Reviewer2, Budget Owner, Level5–10 |
| **DOA Matrix** | Bảng tra cứu trên SharePoint — xác định **cần bao nhiêu cấp duyệt tài chính** dựa trên `Subsidiary + Campus + Tổng tiền MYR` |
| **Threshold_Min** | Cột trong DOA Matrix — **ngưỡng tiền tối thiểu** (MYR). Nếu `TotalAmount_MYR >= Threshold_Min` của một cấp, thì cấp đó bắt buộc phải duyệt. VD: `Threshold_Min = 50,001` → đơn từ 50,001 MYR trở lên mới cần cấp này |
| **Threshold_Max** | Cột trong DOA Matrix — **ngưỡng tiền tối đa** (MYR) cho mỗi cấp duyệt |
| **StageOrder** | Số thứ tự cấp duyệt DOA (5 → 10). Dùng để sắp xếp thứ tự duyệt từ thấp lên cao |
| **StageCheck** | Tên stage ghi trong Approval Log (`Reviewer`, `BudgetOwner`, `Level5`...) — dùng để xác định đơn đang ở bước nào |
| **TotalAmount_MYR** | Tổng tiền đơn quy đổi sang MYR — giá trị dùng so sánh với `Threshold_Min` |
| **RouteType** | Phân loại luồng duyệt: `"RealKids"` (mầm non) hoặc `"0"` (thông thường) |
| **Approval Log** | Bảng nhật ký — ghi lại **từng hành động** duyệt/từ chối/trả về. Mỗi dòng = 1 bản ghi với trạng thái `Pending` → `Approved` / `Rejected` / `Returned` |
| **Dedup** (Deduplication) | Logic xoá bản ghi trùng lặp trong Approval Log — giữ lại bản mới nhất, xoá các bản cũ |
| **Patch** | Hàm Power Apps dùng để cập nhật/tạo mới dữ liệu vào SharePoint List |
| **NS / NetSuite** | Hệ thống ERP (Oracle NetSuite) — hệ thống kế toán/tài chính chính thức. Sau khi đơn "Final Approved", Workato tạo PO trên đây |
| **Workato** | Nền tảng tích hợp iPaaS — "cầu nối" tự động: nhận tín hiệu từ Power Apps → tạo PO trên NetSuite, gửi email thông báo |
| **varRFStage** | Biến nội bộ trong code — số thứ tự stage hiện tại của đơn trên bảng Header |
| **varCurrentStage** | Biến nội bộ — số thứ tự stage trong log đang được xử lý. So sánh với `varRFStage` để phát hiện log lỗi thời |
| **LogType** | Loại log — dùng để tạo key chống trùng: `PR_No \| ApprovedBy \| LogType` |

---

## 2. System Architecture

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

## 3. SharePoint Data Model

> **Ghi chú cho người mới:** SharePoint Lists ở đây đóng vai trò như các **bảng trong cơ sở dữ liệu**. Mỗi List là một bảng, mỗi dòng (item) là một bản ghi, mỗi cột (column) là một trường dữ liệu. Các bảng liên kết với nhau qua `PR_No` (giống khóa ngoại trong SQL).

### 3.1 `SY2425-PR-GeneralInfo` — Header đơn mua hàng
> *Mỗi dòng = 1 đơn PR. Chứa thông tin tổng quan: ai tạo, tổng tiền, trạng thái, nhà cung cấp.*
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

### 3.2 `SY2425-PR_Item` — Chi tiết từng dòng hàng
> *Mỗi dòng = 1 mặt hàng trong đơn PR. Một đơn PR có thể có nhiều dòng hàng. Liên kết với GeneralInfo qua `PR_No0`.*
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

### 3.3 `SY2425-Approval_log` — Nhật ký phê duyệt (audit trail)
> *Mỗi dòng = 1 hành động phê duyệt. Khi đơn chuyển sang stage mới, hệ thống tạo bản ghi `Pending` cho người duyệt tiếp theo. Khi họ duyệt xong, bản ghi được cập nhật thành `Approved`.*
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

### 3.4 `ApprovalMatrix_SY2425` — Ma trận phê duyệt cơ bản
> *Bảng cấu hình "ai duyệt cho ai". Khi nhân viên submit đơn, hệ thống dùng 4 thông tin (Subsidiary, Dept, Campus, Curriculum) từ dòng hàng đầu tiên để tra bảng này và tìm ra danh sách người duyệt.*

**Khóa tra cứu:** `Subsidiary + Dept + Campus + Curriculumn_YearGroup`

| Column | Mô tả |
|---|---|
| `Reviewer` | JSON array email: `["a@co.my","b@co.my"]` |
| `Reviewer2` | JSON array email cấp 2 |
| `Budget Owner` | Email Budget Owner thông thường |
| `RKManager` | Email manager RealKids (≤ 2,500 MYR) |
| `RKManager2` | Email manager RealKids (> 2,500 MYR) |
| `Level5..Level10` | Email người duyệt DOA từng cấp |

### 3.5 `DOA_Matrix_SY2425` — Ma trận uỷ quyền tài chính (DOA)
> *Bảng cấu hình "đơn bao nhiêu tiền thì cần ai duyệt". Hệ thống tìm tất cả các dòng có `Threshold_Min <= TotalAmount_MYR` rồi yêu cầu duyệt **lần lượt từ cấp thấp đến cao**.*

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

### 3.6 `SY2425_PR_Comments` — Bình luận trên đơn
> *Lưu các comment người dùng gửi qua nút "Send" trong PR Detail. Hoạt động giống phần bình luận dưới bài viết.*

Có `Status` = `Posted` hoặc `Rejected`.

### 3.7 Ví dụ minh hoạ: Cách DOA Matrix hoạt động

Giả sử một đơn PR có **TotalAmount_MYR = 80,000** tại campus "SKKD : Whole School":

```
Bước 1: Hệ thống lọc DOA Matrix: tìm tất cả dòng có Threshold_Min ≤ 80,000

   StageOrder | StageName      | Threshold_Min | Threshold_Max | Kết quả
   -----------|----------------|---------------|---------------|--------
   5          | School FBP     | 1             | 20,000        | ✅ 1 ≤ 80,000 → CẦN DUYỆT
   6          | XMCO CBSO      | 20,001        | 50,000        | ✅ 20,001 ≤ 80,000 → CẦN DUYỆT
   7          | XMCO CFO       | 50,001        | 100,000       | ✅ 50,001 ≤ 80,000 → CẦN DUYỆT
   8          | XMCO CEO       | 100,001       | 500,000       | ❌ 100,001 > 80,000 → KHÔNG CẦN
   9          | Group CFO      | 500,001       | 1,800,000     | ❌ Bỏ qua
   10         | Group CEO      | 1,800,001     | 20,000,000    | ❌ Bỏ qua

Bước 2: Luồng duyệt hoàn chỉnh:
   Reviewer → Reviewer2 → BudgetOwner → Level5 (FBP) → Level6 (CBSO) → Level7 (CFO) → Final Approved ✅

   (Không cần Level8/9/10 vì 80,000 MYR chưa đạt ngưỡng 100,001)
```

Một ví dụ khác với **TotalAmount_MYR = 5,000**:
```
   Chỉ có Level5 (FBP, Threshold_Min=1) thoả mãn → luồng duyệt ngắn:
   Reviewer → Reviewer2 → BudgetOwner → Level5 (FBP) → Final Approved ✅
```

---

## 4. Canvas App — Màn hình & Buttons

> **Ghi chú:** Mỗi file `.fx` trong workspace tương ứng với property `OnSelect` của một Button hoặc `Default` của một TextInput trên Power Apps. Khi người dùng bấm nút, code trong file `.fx` tương ứng sẽ chạy.

### 4.1 Screen: `PR_OnlineForm_New` — Tạo đơn mới

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

### 4.2 Screen: `PR_OnlineForm_PR_Detail` — Chi tiết đơn hàng

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
**Mục đích:** Người duyệt bấm nút này để **phê duyệt** đơn PR đang chờ mình.

**Tóm tắt nhanh những gì xảy ra khi bấm Approve:**
1. Tìm bản ghi `Pending` của người dùng hiện tại trong Approval Log
2. Đánh dấu bản ghi đó thành `Approved`
3. Xác định bước tiếp theo dựa trên stage hiện tại:
   - **Stage 1–3** (Reviewer → Reviewer2 → BudgetOwner): chuyển sang cấp Review/Budget kế tiếp
   - **Stage 4–9** (Level5 → Level10, DOA): chuyển sang cấp DOA kế tiếp theo `Threshold_Min`
   - Nếu đây đã là **cấp cuối cùng** → đánh dấu đơn `Final Approved`
4. Tạo bản ghi `Pending` mới cho người duyệt tiếp theo
5. Dọn dẹp bản ghi trùng lặp (dedup)

> **Logic chi tiết đầy đủ:** Xem **Mục 5 — Approval Engine** (bao gồm sơ đồ phân nhánh, xử lý RealKids, guard chống log lỗi thời...)

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

### 4.3 Screen: `PR_OnlineForm_YourPR` — Danh sách chờ duyệt của tôi
> *Màn hình hiển thị tất cả đơn PR đang chờ người dùng hiện tại duyệt.*

#### Button: `btnApprove`
**Mục đích:** Giống `btnApprove` ở PR_Detail — cho phép duyệt nhanh ngay từ danh sách, không cần mở chi tiết đơn.

**Khác biệt duy nhất:** Lấy dữ liệu đơn từ `Gallery1.Selected` (dòng đang chọn trên danh sách) thay vì `SelectedPR` (biến toàn cục khi mở chi tiết).

> **Logic chi tiết:** Xem **Mục 5 — Approval Engine**

---

## 5. Approval Engine — Luồng Phê Duyệt Chi Tiết

> Đây là **phần quan trọng nhất** của hệ thống — quyết định đơn đi đâu, ai duyệt, khi nào xong.

> Được dùng ở cả `PR_OnlineForm_YourPR/btnApprove.fx` lẫn `PR_OnlineForm_PR_Detail/btnApprove.fx`.  
> Logic gần như giống nhau, chỉ khác nguồn dữ liệu (`Gallery1.Selected` vs `SelectedPR`).

### 5.1 Bản đồ Stage (Stage Map)
> *Bảng dưới đây cho thấy mỗi stage tương ứng với số mấy và ý nghĩa gì. `varCurrentDOAOrder` chỉ có giá trị cho các cấp DOA (Level5–10), các cấp Review/BudgetOwner không phải DOA.*

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

### 5.2 Luồng xử lý Approve (từng bước)

> **Tóm tắt nhanh cho người mới:** Khi người duyệt bấm "Approve":
> 1. Hệ thống tìm bản ghi `Pending` của họ trong Approval Log
> 2. Đánh dấu bản ghi đó là `Approved`
> 3. Xác định bước tiếp theo (Reviewer2? BudgetOwner? Level5? hay Final Approved?)
> 4. Tạo bản ghi `Pending` mới cho người duyệt tiếp theo (hoặc kết thúc nếu đã là cấp cuối)
>
> 📖 **Giải thích chi tiết từng hàm Power Fx, luồng dữ liệu minh hoạ, tại sao dùng syntax này:** xem file [GUIDE_PowerFx_Explained.md](GUIDE_PowerFx_Explained.md)

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

### 5.3 Sơ đồ trạng thái đơn hàng (State Machine)

> **Cách đọc sơ đồ:** Mũi tên `→` nghĩa là "đơn chuyển sang trạng thái tiếp theo khi được Approved". Mũi tên `Return` đưa đơn về lại trạng thái Draft để người tạo sửa và gửi lại.

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

## 6. Logic Đặc Biệt — RealKids Route

> **Ngữ cảnh:** RealKids là hệ thống trường **mầm non** thuộc group. Vì cơ cấu quản lý khác với trường K-12, nên có luồng duyệt riêng: không dùng Budget Owner chuẩn mà dùng RKManager/RKManager2 tuỳ theo số tiền.

RealKids được kích hoạt khi `Campus.RealKids = "Yes"`.

| Điều kiện | Budget Owner được chọn |
|---|---|
| `Dept = "Operations : Facility"` | `Budget Owner` thông thường (bất kể amount) |
| `TotalAmount_MYR <= 2,500` | `RKManager` |
| `TotalAmount_MYR > 2,500` | `RKManager2` |

> Lý do thiết kế: RealKids có cơ cấu quản lý khác, không dùng Budget Owner chuẩn cho hoạt động vận hành.

---

## 7. Logic Sinh Mã PR (`PR_No`)

> **Tóm tắt:** Mỗi đơn PR được gán một mã duy nhất theo format `RF{tháng năm}-{số thứ tự}`. Hệ thống tự tăng số thứ tự trong mỗi tháng.

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

## 8. Currency & Exchange Rate

> **Tại sao cần quy đổi?** Vì đơn mua hàng có thể nhập bằng nhiều loại tiền (USD, SGD, VND...), nhưng bảng DOA chỉ định ngưỡng bằng MYR. Vì vậy hệ thống phải quy đổi tất cả về MYR để so sánh.

- Mỗi đơn có thể nhập bằng bất kỳ loại tiền nào (MYR, SGD, USD, ...).
- `TotalAmount_MYR` = `TotalAmount × ExchangeRate(Currency)` từ bảng `SY2425-ExchangeRate`.
- `TotalAmount_MYR` là giá trị được so sánh với `DOA_Matrix.Threshold_Min` để xác định cấp duyệt.
- Nếu `TotalAmount_MYR` trống hoặc = 0 ở thời điểm approve → hệ thống tự tính lại và patch.

---

## 9. Vendor Selection — Hai mode

> **Vendor là gì?** Là nhà cung cấp hàng hoá/dịch vụ. Hệ thống hỗ trợ 2 cách chọn vendor:

| Toggle | Mode | Dữ liệu |
|---|---|---|
| `ToggleVendor = OFF` | **One-time Vendor** | Chọn từ `cmbOneTimeVendor` → lấy `NSInternalID`, `VendorFullName` |
| `ToggleVendor = ON` | **Existing Vendor** | Nhập `DataCardValue6` (NS Vendor ID manual) |

---

## 10. Deduplication Logic (Dọn dẹp bản ghi trùng lặp)

> **Tại sao cần dedup?** Trong quá trình tạo Approval Log, đôi khi bản ghi Pending bị tạo trùng (do lỗi mạng, người dùng bấm nhiều lần, hoặc re-submit). Logic dedup đảm bảo mỗi người duyệt chỉ có đúng 1 bản ghi Pending.

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

## 11. Workato Integration (Tích hợp với hệ thống ngoài)

> **Workato là gì?** Là nền tảng tự động hoá (iPaaS). Khi đơn PR được "Final Approved" trên Power Apps, Workato sẽ tự động tạo Purchase Order (PO) trên NetSuite và gửi email thông báo.

Folder `Workato/` hiện trống trong workspace — các flow được cấu hình trực tiếp trên Workato cloud.

**Dựa trên code Power Apps, các Flow dự kiến bao gồm:**

| Flow | Trigger | Mô tả |
|---|---|---|
| `SY2425_Rejected_Notify` | Gọi từ Power Apps (đang comment) | Gửi email thông báo bị reject cho requestor |
| NetSuite PO Creation | Trigger từ SharePoint (Final Approved) | Tạo PO trên NetSuite, ghi lại `NS_PO_No`, `NSInternalID` |
| Approval Notification | Trigger từ Approval_log (Pending mới) | Gửi email cho approver về đơn chờ duyệt |

> Tham số gọi flow (trong code comment): `PR_No`, `ApproverName`, `Stage`, `RequestorEmail`

---

## 12. Known Issues & Technical Debt

> **Dành cho dev/BA:** Phần này liệt kê các vấn đề đã biết trong code hiện tại.

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

## 13. File Structure Summary

> **Hướng dẫn đọc:** Mỗi file `.fx` là code của một Button/TextInput trong Power Apps. Mỗi file `.csv` trong `SharePoint/` là xuất dữ liệu (schema + data) từ một SharePoint List.

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

## 14. Glossary — Bảng tra nhanh

> *Đây là bảng tóm tắt nhanh. Giải thích chi tiết xem Mục 1.*

| Thuật ngữ | Ý nghĩa ngắn gọn |
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
