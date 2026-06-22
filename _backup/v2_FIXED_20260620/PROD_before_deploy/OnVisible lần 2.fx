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
// || (Or) with SharePoint may be non-delegable on 17,781 rows
// Original: Filter('SY2425-Approval_log', 'Approved By' = User().Email || Requestor = User().Email)
// Fix: 2 separate delegable queries then union
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

// ===== Set Dept Admin vars FIRST (needed for colUserPRs Step 3) =====
Set(
    varIsDeptAdmin,
    !IsEmpty(Filter(XWA_Dept_Admin_List, AdminProfile.Email = User().Email))
);
Set(
    varAdminDepartments,
    LookUp(XWA_Dept_Admin_List, AdminProfile.Email = User().Email).DepartmentName
);

// ===== FIX: Pre-build local collection of user-relevant PRs =====
// Thay vì dùng "PR_No in FilteredPRNos" (non-delegable) trong Gallery Filter,
// ta fetch tất cả PR liên quan vào collection local rồi Gallery filter trên đó.

// Step 1: Tất cả PR mà user là Requestor (delegable query)
ClearCollect(
    colUserPRs,
    Filter('SY2425-PR-GeneralInfo', Requestor = User().Email)
);

// Step 2: Nếu user là Dept Admin, thêm PRs của department
// Chỉ dùng Department = (delegable). Dedup qua IsEmpty check bên dưới.
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
// Dùng Distinct để lấy unique PR_Nos, rồi check từng cái
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

// ===== Procurement Members: override colUserPRs =====
// ROOT CAUSE: SharePoint không hỗ trợ delegable "contains" search (toán tử "in")
// → Phải load data vào local collection để search Title/PR_No/Requestor
// ClearCollect bị giới hạn bởi Data row limit dù filter delegable
// → Batch theo quý, mỗi batch 3 tháng < 2000 items
// → 8 batches = 24 tháng coverage (tháng chưa có data → 0 items, không ảnh hưởng)
//
// YÊU CẦU: Settings → Data row limit = 2000

If(
    !IsBlank(
        LookUp(
            'SY2425-ProcurementMembers',
            ProcurementMember = Office365Users.MyProfileV2().mail
        ).ProcurementMember
    ),
    // Batch 1: 0-92 days (Q hiện tại)
    ClearCollect(
        colUserPRs,
        Filter('SY2425-PR-GeneralInfo', Created >= DateAdd(Today(), -92, TimeUnit.Days))
    );
    // Batch 2: 92-184 days
    Collect(
        colUserPRs,
        Filter('SY2425-PR-GeneralInfo',
            Created >= DateAdd(Today(), -184, TimeUnit.Days) &&
            Created < DateAdd(Today(), -92, TimeUnit.Days)
        )
    );
    // Batch 3: 184-276 days
    Collect(
        colUserPRs,
        Filter('SY2425-PR-GeneralInfo',
            Created >= DateAdd(Today(), -276, TimeUnit.Days) &&
            Created < DateAdd(Today(), -184, TimeUnit.Days)
        )
    );
    // Batch 4: 276-365 days
    Collect(
        colUserPRs,
        Filter('SY2425-PR-GeneralInfo',
            Created >= DateAdd(Today(), -365, TimeUnit.Days) &&
            Created < DateAdd(Today(), -276, TimeUnit.Days)
        )
    );
    // Batch 5: 365-457 days
    Collect(
        colUserPRs,
        Filter('SY2425-PR-GeneralInfo',
            Created >= DateAdd(Today(), -457, TimeUnit.Days) &&
            Created < DateAdd(Today(), -365, TimeUnit.Days)
        )
    );
    // Batch 6: 457-549 days
    Collect(
        colUserPRs,
        Filter('SY2425-PR-GeneralInfo',
            Created >= DateAdd(Today(), -549, TimeUnit.Days) &&
            Created < DateAdd(Today(), -457, TimeUnit.Days)
        )
    );
    // Batch 7: 549-641 days
    Collect(
        colUserPRs,
        Filter('SY2425-PR-GeneralInfo',
            Created >= DateAdd(Today(), -641, TimeUnit.Days) &&
            Created < DateAdd(Today(), -549, TimeUnit.Days)
        )
    );
    // Batch 8: 641-730 days (24 tháng)
    Collect(
        colUserPRs,
        Filter('SY2425-PR-GeneralInfo',
            Created >= DateAdd(Today(), -730, TimeUnit.Days) &&
            Created < DateAdd(Today(), -641, TimeUnit.Days)
        )
    )
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