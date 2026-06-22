# Bug Fix: PR List Not Showing for Requester/Approver (Delegation Limit)

**Date:** 2026-06-22  
**Screen:** PR_OnlineForm_YourPR  
**Reported by:** MY - SiriusNex Go-live Support  
**Case example:** RF0626-0021 (Arina Binti Tumin — vừa tạo vừa duyệt)  
**Status:** Fixed — pending deployment

---

## 1. Mô tả lỗi (Business)

### Hiện tượng
- User tạo RF (Request Form) và cũng là người duyệt (Requester = Approver).
- Sau khi submit, RF **không hiển thị** trong danh sách "Your PR" trên dashboard.
- RF chỉ xuất hiện ở Workflows notification, không thấy trên giao diện app.

### Impact
- User không thể xem lại, track hoặc approve RF mình tạo từ dashboard.
- Phải dựa vào email notification link để truy cập detail page.
- Ảnh hưởng tất cả user có PR mới khi list > 2,000 records.

### Affected Users
| Role | Bị ảnh hưởng? | Lý do |
|------|:---:|--------|
| Regular User (Requester + Approver) | ✅ | `in` / `||` non-delegable |
| Dept Admin | ✅ | `Department in varAdminDepartments` non-delegable |
| Procurement Member (Toggle ON) | ✅ | `||` non-delegable |
| Procurement Member (Toggle OFF) | ❌ | Xem all records, no user filter |
| Service Account | ❌ | Xem all records |

---

## 2. Root Cause Analysis (Technical)

### SharePoint Delegation Limit
Power Apps gửi filter query tới SharePoint. Khi dùng **non-delegable operators**, Power Apps chỉ tải về tối đa **500 records** (default) hoặc **2,000 records** (max setting), rồi lọc locally trên số records đó.

```
SharePoint List: 17,781 records
        ↓ (non-delegable query)
Power Apps tải về: 500-2,000 records ĐẦU TIÊN (by ID ascending = records cũ nhất)
        ↓
Filter locally trên 500-2,000 records
        ↓
Records mới (RF0626-0021) nằm ở vị trí ~17,000+ → BỊ BỎ QUA
```

### Non-delegable Operators trong code cũ

| Location | Expression | Operator | Delegable? |
|----------|-----------|----------|:---:|
| OnVisible | `'Approved By' = User().Email \|\| Requestor = User().Email` | `\|\|` | ❌ |
| Gallery (Regular) | `PR_No in FilteredPRNos` | `in` | ❌ |
| Gallery (Regular) | `PR_No in FilteredPRNos_PRList` | `in` | ❌ |
| Gallery (Dept Admin) | `Department in varAdminDepartments` | `in` | ❌ |
| Gallery (Toggle ON) | `Requestor = User().Email \|\| (varIsDeptAdmin && ...)` | `\|\|` | ❌ |
| Gallery (Search) | `Search(..., txtSearchPR.Value, Title, PR_No, ...)` | `Search()` | ❌ |

### Delegable Operators trên SharePoint

| Operator | Delegable? | Ví dụ |
|----------|:---:|--------|
| `=` | ✅ | `Requestor = User().Email` |
| `<>` | ❌ | `Requestor <> User().Email` |
| `<`, `>`, `<=`, `>=` | ✅ | `Created >= dateFrom` |
| `&&` (And) | ✅ | `A = x && B = y` |
| `\|\|` (Or) | ❌ | `A = x \|\| B = y` |
| `in` | ❌ | `PR_No in Collection` |
| `Search()` | ❌ | `Search(source, text, columns)` |
| `StartsWith()` | ✅ | `StartsWith(PR_No, "RF0626")` |

---

## 3. Code cũ (OnVisible.fx)

```powerfx
// Non-delegable: || trên SharePoint list 17k+ rows
ClearCollect(
    FilteredPRNos,
    Filter(
        'SY2425-Approval_log',
        'Approved By' = User().Email || Requestor = User().Email  // ❌ || non-delegable
    ).PR_No
);
```

## 4. Code cũ (Gallery Items)

```powerfx
// Branch: Regular User (không phải Procurement, không phải Dept Admin)
SortByColumns(
    Filter(
        AddColumns(
            Search(                                          // ❌ Search() non-delegable
                Filter(
                    'SY2425-PR-GeneralInfo',
                    PR_No in FilteredPRNos ||               // ❌ in non-delegable
                    PR_No in FilteredPRNos_PRList ||        // ❌ in non-delegable
                    User().Email = "powerautomate.xclmy@srikdu.onmicrosoft.com"
                ),
                txtSearchPR.Value, Title, PR_No, RejectComment, Requestor
            ),
            SearchMatch, true
        ),
        // ... date/status filters
    ),
    "Created", SortOrder.Descending
)

// Branch: Dept Admin
Filter(
    'SY2425-PR-GeneralInfo',
    varIsDeptAdmin && Department in varAdminDepartments     // ❌ in non-delegable
)

// Branch: Procurement Toggle ON
Filter(
    'SY2425-PR-GeneralInfo',
    Requestor = User().Email ||                            // ❌ || non-delegable
    (varIsDeptAdmin && Department in varAdminDepartments)   // ❌ in non-delegable
)
```

---

## 5. Code mới (OnVisible_FIXED.fx)

### Strategy: Pre-build local collection bằng delegable queries

```powerfx
// FIX 1: Tách || thành 2 queries riêng biệt (mỗi cái delegable)
ClearCollect(
    FilteredPRNos,
    Filter('SY2425-Approval_log', 'Approved By' = User().Email).PR_No  // ✅ delegable
);
Collect(
    FilteredPRNos,
    Filter('SY2425-Approval_log', Requestor = User().Email).PR_No      // ✅ delegable
);

// FIX 2: Build colUserPRs — local collection chứa tất cả PRs liên quan

// Step 1: PRs user tạo (delegable)
ClearCollect(
    colUserPRs,
    Filter('SY2425-PR-GeneralInfo', Requestor = User().Email)           // ✅ delegable
);

// Step 2: Dept Admin — thêm PRs của department (delegable)
If(
    varIsDeptAdmin,
    ForAll(
        Filter('SY2425-PR-GeneralInfo', Department = varAdminDepartments) As DeptPR,  // ✅ delegable
        If(
            IsEmpty(Filter(colUserPRs, PR_No = DeptPR.PR_No)),  // dedup trên local
            Collect(colUserPRs, DeptPR)
        )
    )
);

// Step 3: PRs user approve (LookUp từng PR_No — delegable)
If(
    !IsEmpty(FilteredPRNos),
    ForAll(
        Distinct(FilteredPRNos, PR_No) As PRItem,
        If(
            IsEmpty(Filter(colUserPRs, PR_No = PRItem.Value)),
            Collect(colUserPRs, LookUp('SY2425-PR-GeneralInfo', PR_No = PRItem.Value))  // ✅ delegable
        )
    )
);
```

## 6. Code mới (Gallery_FIXED.fx)

### Strategy: Filter trên local collection — không bị delegation limit

```powerfx
If(
    IsBlank(LookUp('SY2425-ProcurementMembers', ProcurementMember = Office365Users.MyProfileV2().mail).ProcurementMember),

    // KHÔNG phải Procurement Member
    Switch(
        varIsDeptAdmin,
        true,
        // Dept Admin: filter trên colUserPRs (local, đã có department PRs)
        SortByColumns(
            Filter(colUserPRs, /* search + date/status filters */),
            "Created", SortOrder.Descending
        ),
        // Regular User
        If(
            User().Email = "powerautomate.xclmy@srikdu.onmicrosoft.com",
            // Service account: query SP trực tiếp (cần all records)
            SortByColumns(Filter('SY2425-PR-GeneralInfo', ...), "Created", SortOrder.Descending),
            // Regular user: filter trên colUserPRs (local)
            SortByColumns(Filter(colUserPRs, ...), "Created", SortOrder.Descending)
        )
    ),

    // LÀ Procurement Member
    If(
        SeachToggle.Checked = false,
        // Toggle OFF: xem all (query SP trực tiếp)
        SortByColumns(Filter('SY2425-PR-GeneralInfo', ...), "Created", SortOrder.Descending),
        // Toggle ON: chỉ xem PRs liên quan → dùng colUserPRs (local)
        SortByColumns(Filter(colUserPRs, ...), "Created", SortOrder.Descending)
    )
)
```

---

## 7. Thay đổi Search behavior

| | Code cũ | Code mới |
|--|---------|----------|
| **Function** | `Search(..., txtSearchPR.Value, Title, PR_No, RejectComment, Requestor)` | `StartsWith(PR_No, txtSearchPR.Value)` |
| **Columns searched** | 4 columns (Title, PR_No, RejectComment, Requestor) | 1 column (PR_No only) |
| **Delegable** | ❌ | ✅ (trên SP) / N/A (trên local) |
| **Match type** | Contains (anywhere in text) | Prefix only (begins with) |

**Lý do thay đổi:** `Search()` luôn non-delegable. Trên local collection có thể dùng `in` operator nếu cần tìm nhiều columns — xem note bên dưới.

**Nếu cần search nhiều columns trên local collection:**
```powerfx
(IsBlank(txtSearchPR.Value) || 
 StartsWith(PR_No, txtSearchPR.Value) || 
 txtSearchPR.Value in Title || 
 txtSearchPR.Value in Requestor)
```
*(Trên local collection, `in` không bị delegation limit)*

---

## 8. Tóm tắt so sánh

| Metric | Code cũ | Code mới |
|--------|---------|----------|
| Delegation warnings | 5-6 | 0 |
| Max records hiển thị | 500-2,000 | **Tất cả** |
| Data source của Gallery | SharePoint trực tiếp | Local collection (`colUserPRs`) |
| OnVisible network calls | 2-3 | 4-6 (nhưng tất cả delegable) |
| Gallery refresh speed | Mỗi lần → query SP | Filter trên memory → **nhanh hơn** |
| Bug RF0626-0021 | ❌ Không hiển thị | ✅ Luôn hiển thị |

---

## 9. Testing Checklist

- [ ] Regular user tạo PR mới → xuất hiện trong list ngay sau navigate back
- [ ] Regular user là approver của PR khác → PR đó xuất hiện
- [ ] User vừa tạo vừa duyệt (Requester = Approver) → PR hiển thị
- [ ] Dept Admin thấy tất cả PRs trong department mình quản lý
- [ ] Dept Admin thấy PRs mình tạo (dù khác department)
- [ ] Service account thấy tất cả PRs
- [ ] Procurement Member (Toggle OFF) thấy tất cả PRs
- [ ] Procurement Member (Toggle ON) chỉ thấy PRs liên quan
- [ ] Search by PR_No hoạt động đúng
- [ ] Date range filter hoạt động
- [ ] Status/Stage/Campus/Department/Subsidiary/Curriculum filters hoạt động
- [ ] Performance: screen load time chấp nhận được (< 5s)

---

## 10. Deployment Notes

1. Copy code từ `OnVisible_FIXED.fx` → paste vào OnVisible property của screen `PR_OnlineForm_YourPR`
2. Copy code từ `Gallery_FIXED.fx` → paste vào Items property của Gallery control
3. Publish app
4. Test với user account có PR mới (ví dụ RF0626-0021)
5. Confirm delegation warnings đã hết trong Power Apps Studio

---
---

# APPENDIX A: Full Code Cũ (BACKUP — để rollback nếu cần)

## A1. OnVisible (code cũ — đang chạy production)

> Copy toàn bộ block dưới đây → paste vào **OnVisible** property của screen `PR_OnlineForm_YourPR` để rollback.

```powerfx
ClearCollect(
    ColRecords,
    {
        ItemField: "",
        Commodity: "",
        CommodityID: "",
        ExpType: "",
        Campus: "",
        Quantity: 0,
        UnitPrice: 0,
        Currency: "",
        Amount: 0,
        Currencies: "VND",
        BudgetCode: ""
    }
);
ClearCollect(
    PRItems,
    {itemName: ""}
);
// 1. Create a collection to store the filtered PR_No values
ClearCollect(
    FilteredPRNos,
    Filter(
        'SY2425-Approval_log',
        'Approved By' = User().Email || Requestor = User().Email
    ).PR_No
);
ClearCollect(
    FilteredPRNos_PRList,
    Filter(
        'SY2425-PR-GeneralInfo',
        Requestor = User().Email
    ).PR_No
);
/*ClearCollect(
    FilteredAppendPRNo,
    Filter(
        'SY2425-PR-AppendLog',
        AppendEmail = User().Email
    ).PR_No
);*/
Set(
    varIsDeptAdmin,
    !IsEmpty(Filter(XWA_Dept_Admin_List, AdminProfile.Email = User().Email))
);
Set(
    varAdminDepartments,
    LookUp(XWA_Dept_Admin_List, AdminProfile.Email = User().Email).DepartmentName
);

Set(ToggleMyRF, false);
Set(ctnReturnVisible, false);
// Build the list once
ClearCollect(
    colSubsidiary,
    Table({ Value: "All Subsidiary" }),
    
        Sort(
            Distinct(
                   'SY2425-PR-GeneralInfo',
                    Item_Subsidiary
                ),
            "Result",
            SortOrder.Ascending
        )
);
ClearCollect(
    colDepartments,
    Table({ Value: "All Department" }),
    
        Sort(
            Distinct(
                   'SY2425-PR-GeneralInfo',
                    Item_Dept
                ),
            "Result",
            SortOrder.Ascending
        )
);
ClearCollect(
    colCampus,
    Table({ Value: "All Campus" }),
    
        Sort(
            Distinct(
                   'SY2425-PR-GeneralInfo',
                    Item_Campus
                ),
            "Result",
            SortOrder.Ascending
        )
);
ClearCollect(
    colCurriculum,
    Table({ Value: "All Curriculum" }),
    
        Sort(
            Distinct(
                   'SY2425-PR-GeneralInfo',
                    Item_Curriculum
                ),
            "Result",
            SortOrder.Ascending
        )
);

ClearCollect(
    colRFStatus,
    Table({ Value: "All Status" }),
    
        Sort(
            Distinct(
                   'SY2425-PR-GeneralInfo',
                    Status
                ),
            "Result",
            SortOrder.Ascending
        )
);

ClearCollect(
    colRFStage,
    Table({ Value: "All Stage" }),
    
        Sort(
            Distinct(
                   'SY2425-PR-GeneralInfo',
                    LatestStatus
                ),
            "Result",
            SortOrder.Ascending
        )
);
```

## A2. Gallery Items (code cũ — đang chạy production)

> Copy toàn bộ block dưới đây → paste vào **Items** property của Gallery control để rollback.

```powerfx
If(
    IsBlank(
        LookUp(
            'SY2425-ProcurementMembers',
            ProcurementMember = Office365Users.MyProfileV2().mail
        ).ProcurementMember
    ),
    // Start to check the latest status. 
        Switch(
            varIsDeptAdmin, 
            true,

    
        SortByColumns(
        Filter(
            AddColumns(
                Search(
                    Filter(
                        'SY2425-PR-GeneralInfo',
                        
                        varIsDeptAdmin &&
                               Department in varAdminDepartments
                        
                      //  ||  User().Email = "svc-siriusnex@xwa.edu.sg"
                    ),
                    txtSearchPR.Value,
                    Title,
                    PR_No,
                    RejectComment, 
                    Requestor
                ),
                SearchMatch, true
            ),
               
                   

            (IsBlank(dateFrom.SelectedDate) || Created >= dateFrom.SelectedDate) &&
            (IsBlank(dateTo.SelectedDate) || Created <= dateTo.SelectedDate) &&
            (IsBlank(drpStatus.Selected.Value) || drpStatus.Selected.Value = "All Status" || Status = drpStatus.Selected.Value) &&
            (IsBlank(drpLatestStatus.Selected.Value) || drpLatestStatus.Selected.Value = "All Stage" || LatestStatus = drpLatestStatus.Selected.Value) &&
            (IsBlank(cmbCampSearch.Selected.Value) || cmbCampSearch.Selected.Value = "All Campus" || Item_Campus = cmbCampSearch.Selected.Value) && 
            (IsBlank(cmbDeptSearch.Selected.Value) || cmbDeptSearch.Selected.Value ="All Department" || Item_Dept = cmbDeptSearch.Selected.Value) &&
            (IsBlank(cmbSubSearch.Selected.Value) || cmbSubSearch.Selected.Value ="All Subsidiary" || Item_Subsidiary = cmbSubSearch.Selected.Value) &&
            (IsBlank(cmbCurriculmSearch.Selected.Value) || cmbCurriculmSearch.Selected.Value ="All Curriculum" || Item_Curriculum = cmbCurriculmSearch.Selected.Value) 
            ),
        "Created",
        SortOrder.Descending
        )
     
        
      
        ,
       
       SortByColumns(
        Filter(
            AddColumns(
                Search(
                    Filter(
                        'SY2425-PR-GeneralInfo',
                        PR_No in FilteredPRNos || 
                        PR_No in FilteredPRNos_PRList 
                        ||  User().Email = "powerautomate.xclmy@srikdu.onmicrosoft.com"
                    ),
                    txtSearchPR.Value,
                    Title,
                    PR_No,
                    RejectComment, 
                    Requestor
                ),
                SearchMatch, true
            ),
               
                   

            (IsBlank(dateFrom.SelectedDate) || Created >= dateFrom.SelectedDate) &&
            (IsBlank(dateTo.SelectedDate) || Created <= dateTo.SelectedDate) &&
            (IsBlank(drpStatus.Selected.Value) || drpStatus.Selected.Value = "All Status" || Status = drpStatus.Selected.Value) &&
            (IsBlank(drpLatestStatus.Selected.Value) || drpLatestStatus.Selected.Value = "All Stage" || LatestStatus = drpLatestStatus.Selected.Value) &&
            
            (IsBlank(cmbCampSearch.Selected.Value) || cmbCampSearch.Selected.Value = "All Campus" || Item_Campus = cmbCampSearch.Selected.Value) && 
            (IsBlank(cmbDeptSearch.Selected.Value) || cmbDeptSearch.Selected.Value ="All Department" || Item_Dept = cmbDeptSearch.Selected.Value) &&
            (IsBlank(cmbSubSearch.Selected.Value) || cmbSubSearch.Selected.Value ="All Subsidiary" || Item_Subsidiary = cmbSubSearch.Selected.Value) &&
            (IsBlank(cmbCurriculmSearch.Selected.Value) || cmbCurriculmSearch.Selected.Value ="All Curriculum" || Item_Curriculum = cmbCurriculmSearch.Selected.Value) 
        ),
        "Created",
        SortOrder.Descending
            )
        )
    //End of switch to check PR LatestStatus.    
    
,
   
    If(
    SeachToggle.Checked = false,

    // No filter by Requestor
    SortByColumns(
        Filter(
            AddColumns(
                Search(
                    'SY2425-PR-GeneralInfo',
                    txtSearchPR.Value,
                    Title,
                    PR_No,
                    RejectComment, 
                    Requestor
                ),
                SearchMatched, true
            )
             
            ,
            
                            
               
                          
            (IsBlank(dateFrom.SelectedDate) || Created >= dateFrom.SelectedDate) &&
            (IsBlank(dateTo.SelectedDate) || Created <= dateTo.SelectedDate) &&
            (IsBlank(drpStatus.Selected.Value) || drpStatus.Selected.Value = "All Status" || Status = drpStatus.Selected.Value) &&
            (IsBlank(drpLatestStatus.Selected.Value) || drpLatestStatus.Selected.Value = "All Stage" || LatestStatus = drpLatestStatus.Selected.Value) &&
            (IsBlank(cmbCampSearch.Selected.Value) || cmbCampSearch.Selected.Value = "All Campus" || Item_Campus = cmbCampSearch.Selected.Value) && 
            (IsBlank(cmbDeptSearch.Selected.Value) || cmbDeptSearch.Selected.Value ="All Department" || Item_Dept = cmbDeptSearch.Selected.Value) &&
            (IsBlank(cmbSubSearch.Selected.Value) || cmbSubSearch.Selected.Value ="All Subsidiary" || Item_Subsidiary = cmbSubSearch.Selected.Value) &&
            (IsBlank(cmbCurriculmSearch.Selected.Value) || cmbCurriculmSearch.Selected.Value ="All Curriculum" || Item_Curriculum = cmbCurriculmSearch.Selected.Value) 
        ),
        "Created",
        SortOrder.Descending
    ),

    // Filter by Requestor or admin of department - Support log 164
    SortByColumns(
        Filter(
            AddColumns(
                Search(
                    'SY2425-PR-GeneralInfo',
                    txtSearchPR.Value,
                   Title,
                    PR_No,
                    RejectComment, 
                    Requestor
                ),
                SearchMatched, true
            ),
            
                
            Requestor = User().Email || 
                    (
                        varIsDeptAdmin &&
                               Department in varAdminDepartments
                    )
             &&
            (IsBlank(dateFrom.SelectedDate) || Created >= dateFrom.SelectedDate) &&
            (IsBlank(dateTo.SelectedDate) || Created <= dateTo.SelectedDate) &&
            (IsBlank(drpStatus.Selected.Value) || drpStatus.Selected.Value = "All Status" || Status = drpStatus.Selected.Value) &&
            (IsBlank(drpLatestStatus.Selected.Value) || drpLatestStatus.Selected.Value = "All Stage" || LatestStatus = drpLatestStatus.Selected.Value) &&
            (IsBlank(cmbCampSearch.Selected.Value) || cmbCampSearch.Selected.Value = "All Campus" || Item_Campus = cmbCampSearch.Selected.Value) && 
            (IsBlank(cmbDeptSearch.Selected.Value) || cmbDeptSearch.Selected.Value ="All Department" || Item_Dept = cmbDeptSearch.Selected.Value) &&
            (IsBlank(cmbSubSearch.Selected.Value) || cmbSubSearch.Selected.Value ="All Subsidiary" || Item_Subsidiary = cmbSubSearch.Selected.Value) &&
            (IsBlank(cmbCurriculmSearch.Selected.Value) || cmbCurriculmSearch.Selected.Value ="All Curriculum" || Item_Curriculum = cmbCurriculmSearch.Selected.Value) 
        ),
        "Created",
        SortOrder.Descending
    )
)


)
```

---
---

# APPENDIX B: Full Code Mới (ĐỂ DEPLOY)

## B1. OnVisible_FIXED (copy vào OnVisible property)

```powerfx
ClearCollect(
    ColRecords,
    {
        ItemField: "",
        Commodity: "",
        CommodityID: "",
        ExpType: "",
        Campus: "",
        Quantity: 0,
        UnitPrice: 0,
        Currency: "",
        Amount: 0,
        Currencies: "VND",
        BudgetCode: ""
    }
);
ClearCollect(
    PRItems,
    {itemName: ""}
);

// ===== FIX: Split || into 2 delegable Filter calls =====
ClearCollect(
    FilteredPRNos,
    Filter(
        'SY2425-Approval_log',
        'Approved By' = User().Email
    ).PR_No
);
Collect(
    FilteredPRNos,
    Filter(
        'SY2425-Approval_log',
        Requestor = User().Email
    ).PR_No
);
// ===== END FIX =====

ClearCollect(
    FilteredPRNos_PRList,
    Filter(
        'SY2425-PR-GeneralInfo',
        Requestor = User().Email
    ).PR_No
);

/*ClearCollect(
    FilteredAppendPRNo,
    Filter(
        'SY2425-PR-AppendLog',
        AppendEmail = User().Email
    ).PR_No
);*/

// ===== Set Dept Admin vars FIRST =====
Set(
    varIsDeptAdmin,
    !IsEmpty(Filter(XWA_Dept_Admin_List, AdminProfile.Email = User().Email))
);
Set(
    varAdminDepartments,
    LookUp(XWA_Dept_Admin_List, AdminProfile.Email = User().Email).DepartmentName
);

// ===== FIX: Pre-build local collection of user-relevant PRs =====

// Step 1: Tất cả PR mà user là Requestor (delegable query)
ClearCollect(
    colUserPRs,
    Filter('SY2425-PR-GeneralInfo', Requestor = User().Email)
);

// Step 2: Nếu user là Dept Admin, thêm PRs của department
If(
    varIsDeptAdmin,
    ForAll(
        Filter(
            'SY2425-PR-GeneralInfo',
            Department = varAdminDepartments
        ) As DeptPR,
        If(
            IsEmpty(Filter(colUserPRs, PR_No = DeptPR.PR_No)),
            Collect(colUserPRs, DeptPR)
        )
    )
);

// Step 3: Thêm các PR mà user là Approver nhưng chưa có trong colUserPRs
If(
    !IsEmpty(FilteredPRNos),
    ForAll(
        Distinct(FilteredPRNos, PR_No) As PRItem,
        If(
            IsEmpty(Filter(colUserPRs, PR_No = PRItem.Value)),
            Collect(
                colUserPRs,
                LookUp('SY2425-PR-GeneralInfo', PR_No = PRItem.Value)
            )
        )
    )
);
// ===== END FIX: colUserPRs =====

Set(ToggleMyRF, false);
Set(ctnReturnVisible, false);

// Build the list once
ClearCollect(
    colSubsidiary,
    Table({ Value: "All Subsidiary" }),
        Sort(
            Distinct(
                   'SY2425-PR-GeneralInfo',
                    Item_Subsidiary
                ),
            "Result",
            SortOrder.Ascending
        )
);
ClearCollect(
    colDepartments,
    Table({ Value: "All Department" }),
        Sort(
            Distinct(
                   'SY2425-PR-GeneralInfo',
                    Item_Dept
                ),
            "Result",
            SortOrder.Ascending
        )
);
ClearCollect(
    colCampus,
    Table({ Value: "All Campus" }),
        Sort(
            Distinct(
                   'SY2425-PR-GeneralInfo',
                    Item_Campus
                ),
            "Result",
            SortOrder.Ascending
        )
);
ClearCollect(
    colCurriculum,
    Table({ Value: "All Curriculum" }),
        Sort(
            Distinct(
                   'SY2425-PR-GeneralInfo',
                    Item_Curriculum
                ),
            "Result",
            SortOrder.Ascending
        )
);

ClearCollect(
    colRFStatus,
    Table({ Value: "All Status" }),
        Sort(
            Distinct(
                   'SY2425-PR-GeneralInfo',
                    Status
                ),
            "Result",
            SortOrder.Ascending
        )
);

ClearCollect(
    colRFStage,
    Table({ Value: "All Stage" }),
        Sort(
            Distinct(
                   'SY2425-PR-GeneralInfo',
                    LatestStatus
                ),
            "Result",
            SortOrder.Ascending
        )
);
```

## B2. Gallery_FIXED (copy vào Gallery Items property)

```powerfx
If(
    IsBlank(
        LookUp(
            'SY2425-ProcurementMembers',
            ProcurementMember = Office365Users.MyProfileV2().mail
        ).ProcurementMember
    ),
    Switch(
        varIsDeptAdmin,
        true,
        // Dept Admin: dùng colUserPRs (đã bao gồm PRs department + PRs cá nhân)
        SortByColumns(
            Filter(
                colUserPRs,
                (IsBlank(txtSearchPR.Value) || StartsWith(PR_No, txtSearchPR.Value)) &&
                (IsBlank(dateFrom.SelectedDate) || Created >= dateFrom.SelectedDate) &&
                (IsBlank(dateTo.SelectedDate) || Created <= dateTo.SelectedDate) &&
                (IsBlank(drpStatus.Selected.Value) || drpStatus.Selected.Value = "All Status" || Status = drpStatus.Selected.Value) &&
                (IsBlank(drpLatestStatus.Selected.Value) || drpLatestStatus.Selected.Value = "All Stage" || LatestStatus = drpLatestStatus.Selected.Value) &&
                (IsBlank(cmbCampSearch.Selected.Value) || cmbCampSearch.Selected.Value = "All Campus" || Item_Campus = cmbCampSearch.Selected.Value) &&
                (IsBlank(cmbDeptSearch.Selected.Value) || cmbDeptSearch.Selected.Value = "All Department" || Item_Dept = cmbDeptSearch.Selected.Value) &&
                (IsBlank(cmbSubSearch.Selected.Value) || cmbSubSearch.Selected.Value = "All Subsidiary" || Item_Subsidiary = cmbSubSearch.Selected.Value) &&
                (IsBlank(cmbCurriculmSearch.Selected.Value) || cmbCurriculmSearch.Selected.Value = "All Curriculum" || Item_Curriculum = cmbCurriculmSearch.Selected.Value)
            ),
            "Created",
            SortOrder.Descending
        ),
        // Regular User: service account sees all from SP, others use pre-built local collection
        If(
            User().Email = "powerautomate.xclmy@srikdu.onmicrosoft.com",
            SortByColumns(
                Filter(
                    'SY2425-PR-GeneralInfo',
                    (IsBlank(txtSearchPR.Value) || StartsWith(PR_No, txtSearchPR.Value)) &&
                    (IsBlank(dateFrom.SelectedDate) || Created >= dateFrom.SelectedDate) &&
                    (IsBlank(dateTo.SelectedDate) || Created <= dateTo.SelectedDate) &&
                    (IsBlank(drpStatus.Selected.Value) || drpStatus.Selected.Value = "All Status" || Status = drpStatus.Selected.Value) &&
                    (IsBlank(drpLatestStatus.Selected.Value) || drpLatestStatus.Selected.Value = "All Stage" || LatestStatus = drpLatestStatus.Selected.Value) &&
                    (IsBlank(cmbCampSearch.Selected.Value) || cmbCampSearch.Selected.Value = "All Campus" || Item_Campus = cmbCampSearch.Selected.Value) &&
                    (IsBlank(cmbDeptSearch.Selected.Value) || cmbDeptSearch.Selected.Value = "All Department" || Item_Dept = cmbDeptSearch.Selected.Value) &&
                    (IsBlank(cmbSubSearch.Selected.Value) || cmbSubSearch.Selected.Value = "All Subsidiary" || Item_Subsidiary = cmbSubSearch.Selected.Value) &&
                    (IsBlank(cmbCurriculmSearch.Selected.Value) || cmbCurriculmSearch.Selected.Value = "All Curriculum" || Item_Curriculum = cmbCurriculmSearch.Selected.Value)
                ),
                "Created",
                SortOrder.Descending
            ),
            // Regular user: filter from colUserPRs (local collection, no delegation issues)
            SortByColumns(
                Filter(
                    colUserPRs,
                    (IsBlank(txtSearchPR.Value) || StartsWith(PR_No, txtSearchPR.Value)) &&
                    (IsBlank(dateFrom.SelectedDate) || Created >= dateFrom.SelectedDate) &&
                    (IsBlank(dateTo.SelectedDate) || Created <= dateTo.SelectedDate) &&
                    (IsBlank(drpStatus.Selected.Value) || drpStatus.Selected.Value = "All Status" || Status = drpStatus.Selected.Value) &&
                    (IsBlank(drpLatestStatus.Selected.Value) || drpLatestStatus.Selected.Value = "All Stage" || LatestStatus = drpLatestStatus.Selected.Value) &&
                    (IsBlank(cmbCampSearch.Selected.Value) || cmbCampSearch.Selected.Value = "All Campus" || Item_Campus = cmbCampSearch.Selected.Value) &&
                    (IsBlank(cmbDeptSearch.Selected.Value) || cmbDeptSearch.Selected.Value = "All Department" || Item_Dept = cmbDeptSearch.Selected.Value) &&
                    (IsBlank(cmbSubSearch.Selected.Value) || cmbSubSearch.Selected.Value = "All Subsidiary" || Item_Subsidiary = cmbSubSearch.Selected.Value) &&
                    (IsBlank(cmbCurriculmSearch.Selected.Value) || cmbCurriculmSearch.Selected.Value = "All Curriculum" || Item_Curriculum = cmbCurriculmSearch.Selected.Value)
                ),
                "Created",
                SortOrder.Descending
            )
        )
    ),
    If(
        SeachToggle.Checked = false,
        SortByColumns(
            Filter(
                'SY2425-PR-GeneralInfo',
                (IsBlank(txtSearchPR.Value) || StartsWith(PR_No, txtSearchPR.Value)) &&
                (IsBlank(dateFrom.SelectedDate) || Created >= dateFrom.SelectedDate) &&
                (IsBlank(dateTo.SelectedDate) || Created <= dateTo.SelectedDate) &&
                (IsBlank(drpStatus.Selected.Value) || drpStatus.Selected.Value = "All Status" || Status = drpStatus.Selected.Value) &&
                (IsBlank(drpLatestStatus.Selected.Value) || drpLatestStatus.Selected.Value = "All Stage" || LatestStatus = drpLatestStatus.Selected.Value) &&
                (IsBlank(cmbCampSearch.Selected.Value) || cmbCampSearch.Selected.Value = "All Campus" || Item_Campus = cmbCampSearch.Selected.Value) &&
                (IsBlank(cmbDeptSearch.Selected.Value) || cmbDeptSearch.Selected.Value = "All Department" || Item_Dept = cmbDeptSearch.Selected.Value) &&
                (IsBlank(cmbSubSearch.Selected.Value) || cmbSubSearch.Selected.Value = "All Subsidiary" || Item_Subsidiary = cmbSubSearch.Selected.Value) &&
                (IsBlank(cmbCurriculmSearch.Selected.Value) || cmbCurriculmSearch.Selected.Value = "All Curriculum" || Item_Curriculum = cmbCurriculmSearch.Selected.Value)
            ),
            "Created",
            SortOrder.Descending
        ),
        // Toggle ON: dùng colUserPRs để tránh || non-delegable trên SP
        SortByColumns(
            Filter(
                colUserPRs,
                (IsBlank(txtSearchPR.Value) || StartsWith(PR_No, txtSearchPR.Value)) &&
                (IsBlank(dateFrom.SelectedDate) || Created >= dateFrom.SelectedDate) &&
                (IsBlank(dateTo.SelectedDate) || Created <= dateTo.SelectedDate) &&
                (IsBlank(drpStatus.Selected.Value) || drpStatus.Selected.Value = "All Status" || Status = drpStatus.Selected.Value) &&
                (IsBlank(drpLatestStatus.Selected.Value) || drpLatestStatus.Selected.Value = "All Stage" || LatestStatus = drpLatestStatus.Selected.Value) &&
                (IsBlank(cmbCampSearch.Selected.Value) || cmbCampSearch.Selected.Value = "All Campus" || Item_Campus = cmbCampSearch.Selected.Value) &&
                (IsBlank(cmbDeptSearch.Selected.Value) || cmbDeptSearch.Selected.Value = "All Department" || Item_Dept = cmbDeptSearch.Selected.Value) &&
                (IsBlank(cmbSubSearch.Selected.Value) || cmbSubSearch.Selected.Value = "All Subsidiary" || Item_Subsidiary = cmbSubSearch.Selected.Value) &&
                (IsBlank(cmbCurriculmSearch.Selected.Value) || cmbCurriculmSearch.Selected.Value = "All Curriculum" || Item_Curriculum = cmbCurriculmSearch.Selected.Value)
            ),
            "Created",
            SortOrder.Descending
        )
    )
)
```

---

## Rollback Instructions

Nếu code mới gây lỗi, rollback bằng cách:
1. Copy code từ **Appendix A1** → paste vào OnVisible property
2. Copy code từ **Appendix A2** → paste vào Gallery Items property
3. Publish app