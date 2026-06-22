// ===== VERSION: v3_FIXED_20260622 =====
// Changes from v2: Optimize Step 3 - limit LookUp calls to max 30
// Fixes: Delegation warnings on Approval_log || operator
// Fixes: Gallery non-delegable "in" operator on SP list

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
// || (Or) with SharePoint is non-delegable
// Original: Filter('SY2425-Approval_log', 'Approved By' = User().Email || Requestor = User().Email)
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

// ===== Set Dept Admin vars FIRST =====
Set(
    varIsDeptAdmin,
    !IsEmpty(Filter(XWA_Dept_Admin_List, AdminProfile.Email = User().Email))
);
Set(
    varAdminDepartments,
    LookUp(XWA_Dept_Admin_List, AdminProfile.Email = User().Email).DepartmentName
);

// ===== BUILD colUserPRs (local collection) =====
// Gallery sẽ filter từ collection này → không bị delegation limit

// Step 1: Tất cả PR mà user là Requestor (delegable - 1 API call)
ClearCollect(
    colUserPRs,
    Filter('SY2425-PR-GeneralInfo', Requestor = User().Email)
);

// Step 2: Nếu user là Dept Admin, thêm PRs của department (delegable - 1 API call)
If(
    varIsDeptAdmin,
    With(
        { DeptPRs: Filter('SY2425-PR-GeneralInfo', Department = varAdminDepartments) },
        ForAll(
            DeptPRs As DeptPR,
            If(
                IsEmpty(Filter(colUserPRs, PR_No = DeptPR.PR_No)),
                Collect(colUserPRs, DeptPR)
            )
        )
    )
);

// Step 3 (OPTIMIZED): Thêm PRs mà user là Approver nhưng chưa có trong colUserPRs
// Chỉ LookUp những PRs thật sự MISSING, giới hạn tối đa 30 calls
If(
    !IsEmpty(FilteredPRNos),
    With(
        {
            // Lọc ra unique PR_Nos chưa có trong colUserPRs
            MissingPRNos: Filter(
                Distinct(FilteredPRNos, PR_No),
                IsEmpty(Filter(colUserPRs, PR_No = Value))
            )
        },
        // Chỉ fetch tối đa 30 records (tránh quá chậm cho senior approvers)
        ForAll(
            FirstN(MissingPRNos, 30) As PRItem,
            Collect(
                colUserPRs,
                LookUp('SY2425-PR-GeneralInfo', PR_No = PRItem.Value)
            )
        )
    )
);
// ===== END BUILD colUserPRs =====

Set(ToggleMyRF, false);
Set(ctnReturnVisible, false);

// Build filter dropdown lists (1 API call each - delegable)
ClearCollect(
    colSubsidiary,
    Table({ Value: "All Subsidiary" }),
    Sort(
        Distinct('SY2425-PR-GeneralInfo', Item_Subsidiary),
        "Result",
        SortOrder.Ascending
    )
);
ClearCollect(
    colDepartments,
    Table({ Value: "All Department" }),
    Sort(
        Distinct('SY2425-PR-GeneralInfo', Item_Dept),
        "Result",
        SortOrder.Ascending
    )
);
ClearCollect(
    colCampus,
    Table({ Value: "All Campus" }),
    Sort(
        Distinct('SY2425-PR-GeneralInfo', Item_Campus),
        "Result",
        SortOrder.Ascending
    )
);
ClearCollect(
    colCurriculum,
    Table({ Value: "All Curriculum" }),
    Sort(
        Distinct('SY2425-PR-GeneralInfo', Item_Curriculum),
        "Result",
        SortOrder.Ascending
    )
);
ClearCollect(
    colRFStatus,
    Table({ Value: "All Status" }),
    Sort(
        Distinct('SY2425-PR-GeneralInfo', Status),
        "Result",
        SortOrder.Ascending
    )
);
ClearCollect(
    colRFStage,
    Table({ Value: "All Stage" }),
    Sort(
        Distinct('SY2425-PR-GeneralInfo', LatestStatus),
        "Result",
        SortOrder.Ascending
    )
);
