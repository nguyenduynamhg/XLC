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
// APPROACH: Batch load ALL PRs → filter locally by permission
// Tại sao: ForAll + LookUp quá chậm cho heavy approvers (200+ API calls)
// Local filter trên collection thì instant (milliseconds)
//
// YÊU CẦU: Settings → Data row limit = 2000

// Step 1: Batch load ALL PRs (8 batches × 3 tháng, mỗi batch < 2000)
ClearCollect(colUserPRs, Filter('SY2425-PR-GeneralInfo', Created >= DateAdd(Today(), -92, TimeUnit.Days)));
Collect(colUserPRs, Filter('SY2425-PR-GeneralInfo', Created >= DateAdd(Today(), -184, TimeUnit.Days) && Created < DateAdd(Today(), -92, TimeUnit.Days)));
Collect(colUserPRs, Filter('SY2425-PR-GeneralInfo', Created >= DateAdd(Today(), -276, TimeUnit.Days) && Created < DateAdd(Today(), -184, TimeUnit.Days)));
Collect(colUserPRs, Filter('SY2425-PR-GeneralInfo', Created >= DateAdd(Today(), -365, TimeUnit.Days) && Created < DateAdd(Today(), -276, TimeUnit.Days)));
Collect(colUserPRs, Filter('SY2425-PR-GeneralInfo', Created >= DateAdd(Today(), -457, TimeUnit.Days) && Created < DateAdd(Today(), -365, TimeUnit.Days)));
Collect(colUserPRs, Filter('SY2425-PR-GeneralInfo', Created >= DateAdd(Today(), -549, TimeUnit.Days) && Created < DateAdd(Today(), -457, TimeUnit.Days)));
Collect(colUserPRs, Filter('SY2425-PR-GeneralInfo', Created >= DateAdd(Today(), -641, TimeUnit.Days) && Created < DateAdd(Today(), -549, TimeUnit.Days)));
Collect(colUserPRs, Filter('SY2425-PR-GeneralInfo', Created >= DateAdd(Today(), -730, TimeUnit.Days) && Created < DateAdd(Today(), -641, TimeUnit.Days)));

// Step 2: Nếu KHÔNG phải Procurement → filter local theo permission (instant)
// Procurement giữ nguyên ALL PRs
If(
    IsBlank(
        LookUp(
            'SY2425-ProcurementMembers',
            ProcurementMember = Office365Users.MyProfileV2().mail
        ).ProcurementMember
    ),
    // NOT Procurement: chỉ giữ PRs mà user có quyền xem
    ClearCollect(
        colUserPRs,
        Filter(
            colUserPRs,
            Requestor = User().Email ||
            PR_No in FilteredPRNos ||
            PR_No in FilteredPRNos_PRList ||
            (varIsDeptAdmin && Department = varAdminDepartments)
        )
    )
    // ELSE: Procurement → giữ nguyên all PRs trong colUserPRs
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
