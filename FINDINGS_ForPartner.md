# FINDINGS & CÂU HỎI CẦN LÀM RÕ VỚI ĐỐI TÁC
> **Mục đích:** Tổng hợp các điểm chưa rõ từ Figma + cross-check với code thực tế  
> **Dùng để:** Trình bày cho đối tác ngày thứ 6  
> **Ngày phân tích:** 17/06/2026  
> **Sample data tham chiếu:** RF0526-0307

---

## PHẦN A — BẢNG CÂU HỎI TỪ FIGMA (Q1–Q11) + PHÂN TÍCH TỪ CODE

### Q1. Approval_log và PR_Comments không có cột ID rõ ràng — cần Composite Unique Key?

| | Nội dung |
|---|---|
| **Giả định Figma** | SharePoint List có auto ID ẩn. Nhưng không có composite unique constraint ở tầng nghiệp vụ |
| **Phân tích từ code** | ✅ **Xác nhận đúng.** Code dedup (bước 6 trong btnApprove) dùng key ghép `PR_No + field_7 + LogType` để phát hiện trùng, nhưng chỉ **phát hiện + xoá** chứ không **ngăn chặn** từ đầu. Logic dedup là reactive, không phải constraint |
| **4 case study trên Figma** | |
| CS1 | Double-click / retry → tạo 2 log trùng. Code hiện tại **có xử lý** bằng dedup (giữ bản mới nhất) |
| CS2 | RF0526-0307 có 6 lần Re-assign ở Reviewer stage cùng approver → không rõ bug hay design |
| CS3 | Sync sang NetSuite cần ID ổn định. SharePoint ID sẽ thay đổi nếu migrate list |
| CS4 | Power Automate/Workato retry → tạo trùng dòng. Không có idempotency key |
| **Đề xuất trên Figma** | Thêm Composite Unique Constraint: `Approval_log: (PR_No + Stage + ApproverEmail + Created)`, `PR_Comments: (PR_No + CreatedEmail + Comments hash)` |
| **Ý kiến phân tích** | 🟢 **Đồng ý** — Code hiện tại dùng dedup hậu kỳ, nhưng nếu app crash trước bước dedup thì vẫn để lại dữ liệu bẩn. Nên có constraint ở tầng data |

---

### Q2. PR_No có luôn unique không?

| | Nội dung |
|---|---|
| **Giả định Figma** | PR_No unique trên toàn bảng GeneralInfo (1 PR = 1 row header) |
| **Phân tích từ code** | ⚠️ **Gần đúng nhưng có rủi ro.** Code sinh PR_No bằng: `MAX(IncrementingNumber) + 1` rồi check trùng 1 lần. Nếu 2 user submit **cùng mili-giây** → vẫn có thể trùng (race condition). Code chỉ retry 1 lần |
| **Câu hỏi cần xác nhận** | Có cơ chế chặn PR_No luôn unique? Đã từng xảy ra duplicate khi resubmit chưa? |
| **Ý kiến phân tích** | 🟡 Nên xác nhận với đối tác: có fallback mechanism nào khác (VD: Flow/Workato tạo sequence) hay chỉ dựa vào logic Power Apps? |

---

### Q3. Add_Item_No trong PR_Item — cột trống, không phải là khóa?

| | Nội dung |
|---|---|
| **Giả định Figma** | Cột này không phải khóa, chỉ là cột phụ (data đều null) |
| **Phân tích từ code** | ✅ **Xác nhận.** Code PR_Item chỉ dùng `PR_No0` (FK) + GridID (số thứ tự dòng item 0,1,2...). Không thấy reference đến `Add_Item_No` ở bất kỳ đâu |
| **Câu hỏi** | Cột này có ý nghĩa gì khác không? Hay là artifact cũ? |

---

### Q4. Title — cột metadata mặc định SharePoint, không phải khóa nghiệp vụ?

| | Nội dung |
|---|---|
| **Giả định Figma** | Title ở các sheet là cột mặc định SharePoint (không phải khóa nghiệp vụ) |
| **Phân tích từ code** | ✅ **Đúng.** Trong data export, Title phần lớn null hoặc trùng PR_No. Code không bao giờ reference cột `Title` để tra cứu logic |
| **Câu hỏi** | Có dùng Title cho mục đích nào không? (VD: hiển thị trên SharePoint views?) |

---

### Q5. Campus_ApprovalMatrix_SY2425 chỉ áp dụng cho campus XWA (Singapore)?

| | Nội dung |
|---|---|
| **Giả định Figma** | Bảng `Campus_ApprovalMatrix` có cấu trúc khác, chỉ dùng cho XWA (Singapore). Là layer override hoặc biến thể cho campus đặc biệt |
| **Phân tích từ code** | ⚠️ **Không thấy trong code.** Các file `.fx` trong workspace chỉ reference `ApprovalMatrix_SY2425` và `DOA_Matrix_SY2425`. Không thấy logic nào tra cứu `Campus_ApprovalMatrix_SY2425` |
| **Câu hỏi** | Đúng không? Nếu đúng, logic xử lý XWA nằm ở đâu (code khác? hoặc chưa implement)? |
| **Ý kiến phân tích** | 🟡 Đây có thể là feature riêng cho Singapore chưa được đưa vào codebase hiện tại |

---

### Q6. 6 lần Re-assign ở RF0526-0307 — đúng thiết kế hay bug?

| | Nội dung |
|---|---|
| **Giả định Figma** | Mỗi lần Return → tạo log mới. 6 lần Re-assign = đơn bị return 6 lần → đúng thiết kế |
| **Phân tích từ code** | ✅ **Logic cho phép điều này.** `btnReturn` set Status → "Draft", tạo log `Returned`. Khi re-submit (`btnSubmit` trong PR_Detail), tạo lại Pending mới cho Reviewer. Mỗi vòng Return–Resubmit tạo thêm log mới → 6 lần return = 6 cặp log. **Tuy nhiên** dedup có thể xoá nhầm nếu cùng approver + cùng LogType |
| **Câu hỏi** | Xác nhận là thiết kế? Nếu đúng, có cần thêm `ReturnCycleNo` để phân biệt các vòng return? |
| **Ý kiến phân tích** | 🟡 Nên thêm ReturnCycleNo hoặc sequence number để audit trail rõ ràng hơn |

---

### Q7. ApprovalMatrix và DOA_Matrix chỉ là READ-ONLY lookup tại runtime?

| | Nội dung |
|---|---|
| **Giả định Figma** | Không có FK ngược từ PR → Matrix. Matrix chỉ được đọc khi cần xác định approver |
| **Phân tích từ code** | ✅ **Xác nhận đúng 100%.** Code chỉ dùng `LookUp()` và `Filter()` để đọc Matrix. Kết quả được copy vào Approval_log (email approver). Sau khi tạo log, PR **không còn phụ thuộc** vào Matrix nữa → nếu Matrix thay đổi, các đơn đang pending **không bị ảnh hưởng** |
| **Ý nghĩa** | Đây là snapshot approach — tốt cho stability, nhưng nếu cần đổi approver giữa chừng phải xoá log cũ + tạo mới |

---

### Q8. Stage 5–10 trong ApprovalMatrix vs StageOrder trong DOA_Matrix — cùng concept?

| | Nội dung |
|---|---|
| **Giả định Figma** | Level5–Level10 ở ApprovalMatrix và StageOrder 5–10 ở DOA_Matrix là cùng 1 concept, chỉ khác cách biểu diễn |
| **Phân tích từ code** | ✅ **Đúng.** Code dùng `Switch(StageCheck, "Level5", 4, ...)` để map tên stage sang số, rồi so sánh với `DOA_Matrix.StageOrder`. Cùng 1 approver, cùng 1 cấp — chỉ là 2 cách lưu khác nhau giữa 2 bảng |
| **Chi tiết** | ApprovalMatrix lưu email approver trong cột `Level5`, `Level6`... (text). DOA_Matrix lưu trong cột `ApproverEmail` + `StageOrder` (number). Code btnApprove dùng DOA_Matrix để xác định luồng |

---

### Q9. ApprovalMatrix.Level5–10 là bản copy/denormalize của DOA_Matrix?

| | Nội dung |
|---|---|
| **Giả định Figma** | Level5–10 trong ApprovalMatrix là bản copy. DOA_Matrix mới là **source of truth** (có thêm Threshold_Min/Max) |
| **Phân tích từ code** | ⚠️ **Phần lớn đúng, nhưng code KHÔNG đồng nhất.** Code `btnApprove` dùng **DOA_Matrix** để xác định next approver cho Level5+. Nhưng code `btnSubmit` (tạo đơn mới) có reference đến ApprovalMatrix columns Level5–10 ở một số chỗ. Nếu 2 bảng bị lệch → sai người duyệt |
| **Câu hỏi** | Có đúng kỹ thuật triển khai thực tế không? Hai cột này được maintain riêng hay sync tự động? Nếu DOA_Matrix thay đổi, ApprovalMatrix có được cập nhật? |
| **Ý kiến phân tích** | 🔴 **Rủi ro cao.** Nếu 2 nguồn bị lệch, đơn có thể gửi đến sai người. Cần confirm: ai maintain 2 bảng này và quy trình cập nhật |

---

### Q10. Số tiền lớn → đi qua NHIỀU stage (chứ không phải chỉ 1 stage cao)?

| | Nội dung |
|---|---|
| **Giả định Figma** | PR nhỏ dừng ở Level5, PR lớn đi tiếp Level6, 7, 8... Tức là đơn lớn phải qua **tất cả các cấp** từ thấp đến cao |
| **Phân tích từ code** | ✅ **Xác nhận đúng 100%.** Code: `ClearCollect(colDOAForRF, Filter(DOA_Matrix, Threshold_Min <= TotalAmount_MYR))` → lấy **tất cả** cấp có Threshold_Min nhỏ hơn tổng tiền. VD: đơn 80,000 MYR → qua Level5 (min=1) + Level6 (min=20,001) + Level7 (min=50,001) = 3 cấp DOA lần lượt |
| **Ví dụ minh hoạ** | Đơn 500,000 MYR → qua Level5 + 6 + 7 + 8 = 4 cấp DOA. Đơn 5,000 MYR → chỉ Level5 |

---

### Q11. Threshold_Min/Max bị lỗi format (dấu phẩy hàng nghìn)?

| | Nội dung |
|---|---|
| **Giả định Figma** | Giá trị thật là 20,000 / 50,000 / 100,000... Dấu phẩy trong CSV là thousands separator, không phải decimal |
| **Phân tích từ code/data** | ✅ **Đúng là thousands separator.** Trong file `DOA_Matrix_SY2425.csv`: `"1","20,000"` / `"20,001","50,000"` / `"50,001","100,000"`. SharePoint lưu kiểu Number, export CSV giữ format hiển thị. Code Power Apps so sánh `Threshold_Min <= TotalAmount_MYR` hoạt động đúng vì SharePoint trả về number thật (không phải string) |
| **Kết luận** | Đây là lỗi export/display, **không ảnh hưởng logic**. Giá trị thật đúng là 20000, 50000, 100000... |

---

## PHẦN B — PHÂN TÍCH TỪ DATA MODEL (Ảnh 3 — ERD)

### Q12. Quan hệ giữa các bảng — confirm từ code

| Quan hệ (Figma) | Code xác nhận? | Ghi chú |
|---|---|---|
| PR-GeneralInfo —1:N→ PR_Item (via PR_No) | ✅ Đúng | `Filter(PR_Item, PR_No0 = selectedPR.PR_No)` |
| PR-GeneralInfo —1:N→ Approval_log (via PR_No) | ✅ Đúng | `Filter(Approval_log, PR_No = X)` |
| PR-GeneralInfo —1:N→ PR_Comments (via PR_No) | ✅ Đúng | `Filter(PR_Comments, PR_No = X)` |
| PR-GeneralInfo —lookup→ ApprovalMatrix (Subsidiary+Dept+Campus+Curriculum) | ✅ Đúng | Code dùng `LookUp(ApprovalMatrix, ...)` với 4 key |
| PR-GeneralInfo —lookup→ DOA_Matrix (Subsidiary+Campus, filter Threshold) | ✅ Đúng | Code dùng `Filter(DOA_Matrix, ... && Threshold_Min <= TotalAmount_MYR)` |
| PR-GeneralInfo —lookup→ Campus_ApprovalMatrix [chỉ XWA?] | ❌ **Không thấy trong code** | Cần xác nhận |
| Approval_log sinh ra từ ApprovalMatrix + DOA_Matrix (runtime, không phải FK) | ✅ Đúng | Log chỉ lưu **snapshot** email tại thời điểm tạo |

### Q13. Master Data FK mapping

| FK trong Figma | Có trong code? | Ghi chú |
|---|---|---|
| Item Subsidiary → NS_Master_Subsidiary.NS_InternalID | ✅ | `itemSubsidiaryNSID` trong PR_Item |
| Item Campus → NS_Campus_Center.NS_InternalID | ✅ | `CampusNSID` trong PR_Item |
| Item Curriculum → NS_Master_Curriculum.CurrNSInternalID | ✅ | `CurriculumnNSID` trong PR_Item |
| NV Vendor External → NS_Master_Vendor.NSExternalID | ✅ | `NSVendorExternalID` trong GeneralInfo |
| Payment Term → Payment_Term.PaymentTermName | ⚠️ Không rõ | Không thấy trong code `.fx` hiện có |

---

## PHẦN C — GAPS PHÁT HIỆN THÊM TỪ CODE (Không có trên Figma)

### Q14. 🔴 btnReject + btnReturn logic bị comment trong code

| | Nội dung |
|---|---|
| **Trên Figma workflow** | Flow diagram có nhánh Return rõ ràng ở mỗi stage (Reviewer, Reviewer2, BudgetOwner, Level5+) |
| **Trong code** | `btnReject.fx` và `btnReturn.fx` **chỉ show modal**, logic xử lý thực tế bị comment `/* ... */` |
| **Câu hỏi** | Logic reject/return hoạt động ở đâu hiện tại? Trong modal handler chưa share? Hay chưa implement? |
| **Impact** | Nếu chưa implement → approver **không thể từ chối/trả về** đơn → critical |

### Q15. 🔴 Email notification bị tắt

| | Nội dung |
|---|---|
| **Trên Figma** | Workflow ngầm hiểu có notification cho approver |
| **Trong code** | Code gọi Workato flow notify **đang bị comment hoàn toàn** |
| **Câu hỏi** | Approver hiện nhận thông báo bằng cách nào? Push notification từ Power Apps? Hay phải tự vào app kiểm tra? |

### Q16. 🟡 "Cancelled" status trên Figma workflow

| | Nội dung |
|---|---|
| **Trên Figma** | Flow có trạng thái "Cancelled" (cuối cùng, bên cạnh Final Approved) |
| **Trong code** | Không thấy logic nào set Status = "Cancelled". Chỉ có: Draft, Reviewer, Reviewer2, BudgetOwner, Level5–10, Final Approved, Rejected |
| **Câu hỏi** | Khi nào đơn bị "Cancelled"? Ai có quyền cancel? Hay đây là feature chưa implement? |

---

## PHẦN D — TỔNG HỢP VÀ ĐỀ XUẤT TRÌNH BÀY

### Phân loại theo mức độ:

| Mức | Findings | Tổng |
|---|---|---|
| 🔴 Critical (ảnh hưởng vận hành) | Q1-CS2, Q9, Q14, Q15 | 4 |
| 🟡 Medium (cần xác nhận) | Q2, Q5, Q6, Q10, Q11, Q12 (Campus_AM), Q16 | 7 |
| 🟢 Đã confirm đúng | Q3, Q4, Q7, Q8, Q10, Q11 (display only) | 5 |

### Đề xuất thứ tự trình bày cho thứ 6:

```
1. [5 phút] Giới thiệu phạm vi phân tích
   → "Chúng tôi đã đọc toàn bộ code Power Fx + data SharePoint + đối chiếu với Figma"

2. [10 phút] Confirm những gì đã hiểu đúng (Q3, Q4, Q7, Q8, Q10)
   → Tạo confidence, cho đối tác thấy mình hiểu hệ thống

3. [15 phút] Critical findings cần giải đáp ngay (Q9, Q14, Q15, Q16)
   → ApprovalMatrix vs DOA_Matrix có bị lệch?
   → Reject/Return đang hoạt động ở đâu?
   → Email notification hiện trạng?
   → Cancelled status?

4. [10 phút] Câu hỏi data integrity (Q1, Q2, Q6)
   → Composite key, PR_No uniqueness, Re-assign cycles

5. [5 phút] Câu hỏi scope (Q5, Q12-Campus_AM, Q13-PaymentTerm)
   → Campus_ApprovalMatrix cho XWA là gì?
   → Master data nào chưa nằm trong scope?

6. [5 phút] Đề xuất improvements & next steps
```
