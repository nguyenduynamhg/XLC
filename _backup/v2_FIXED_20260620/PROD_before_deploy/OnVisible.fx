// ===== PROD BACKUP - OnVisible =====
// Copied from PROD app BEFORE applying fix
// Date: ___/06/2026
// Purpose: Immediate revert if fix causes issues on PROD
//
// PASTE CODE TỪ PROD APP VÀO ĐÂY:
// Power Apps > XMCO - SiriusNex (PROD) > YourPR Screen > OnVisible property > Select All > Paste

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