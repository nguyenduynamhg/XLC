// ===== BẮT BUỘC: App Settings =====
// Settings → General → Data row limit for non-delegable queries → 2000
// Nếu không đổi, ClearCollect chỉ lấy được 500 rows (default)
// ====================================

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

// ===== Set Dept Admin vars =====
Set(
    varIsDeptAdmin,
    !IsEmpty(Filter(XWA_Dept_Admin_List, AdminProfile.Email = User().Email))
);
Set(
    varAdminDepartments,
    LookUp(XWA_Dept_Admin_List, AdminProfile.Email = User().Email).DepartmentName
);

// ===== Detect Procurement Member =====
Set(
    varIsProcurement,
    !IsBlank(
        LookUp(
            'SY2425-ProcurementMembers',
            ProcurementMember = Office365Users.MyProfileV2().mail
        ).ProcurementMember
    )
);

// ===== Build colUserPRs =====
If(
    varIsProcurement,
    // ===== Procurement Members =====
    // Load 2000 PRs mới nhất (sort ID giảm dần) để search Title khi cần
    // Gallery mặc định dùng SP direct (không bị limit), chỉ dùng collection khi search
    ClearCollect(
        colUserPRs,
        SortByColumns(
            Filter('SY2425-PR-GeneralInfo', ID > 0),
            "ID",
            SortOrder.Descending
        )
    ),

    // ===== Non-Procurement: chỉ load PRs liên quan đến user =====
    // Step 1: PRs mà user là Requestor
    ClearCollect(
        colUserPRs,
        Filter('SY2425-PR-GeneralInfo', Requestor = User().Email)
    );

    // Step 2: Nếu DeptAdmin, thêm PRs của department
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

    // Step 3: Thêm PRs mà user là Approver
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
    )
);
// ===== END colUserPRs =====

Set(ToggleMyRF, false);
Set(ctnReturnVisible, false);

// Build dropdown lists
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
