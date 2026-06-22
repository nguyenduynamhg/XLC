// ===== NÚT DRAFT ĐƠN GIẢN ĐỂ TEST PURPOSESUBCODE =====
// Bỏ toàn bộ validation, chỉ tạo PR number + lưu data
// SAU KHI TEST XONG → XÓA PR TEST TRÊN SHAREPOINT

Set(varSpinner, true);

// 1. Tạo PR number
Set(currentMonthYear, Text(Today(), "[$-en-US]mmyy"));

Set(
    lastPRRecord,
    First(
        SortByColumns(
            Filter('SY2425-PR-GeneralInfo', MonthYear = currentMonthYear),
            "LastNumber",
            SortOrder.Descending
        )
    )
);

If(
    IsBlank(lastPRRecord),
    Set(nextIncrementingNumber, 1),
    Set(nextIncrementingNumber, lastPRRecord.IncrementingNumber + 1)
);

Set(formattedIncrementingNumber, Text(nextIncrementingNumber, "0000"));
Set(prNumber, "RF" & currentMonthYear & "-" & formattedIncrementingNumber);

// Chống trùng
Set(checking, LookUp('SY2425-PR-GeneralInfo', PR_No = prNumber));
If(
    !IsBlank(checking),
    Set(nextIncrementingNumber, nextIncrementingNumber + 1);
    Set(formattedIncrementingNumber, Text(nextIncrementingNumber, "0000"));
    Set(prNumber, "RF" & currentMonthYear & "-" & formattedIncrementingNumber);
);

// 2. Submit form GeneralInfo
SubmitForm(GeneralInforForm);

// 3. Patch GeneralInfo - chỉ giữ fields cần thiết + PurposeSubcode test
Patch(
    'SY2425-PR-GeneralInfo',
    GeneralInforForm.LastSubmit,
    {
        PR_No: prNumber,
        MonthYear: currentMonthYear,
        IncrementingNumber: nextIncrementingNumber,
        Status: "Draft",
        LatestStatus: "Pending",
        Department: Office365Users.MyProfileV2().department,
        Campus: Office365Users.MyProfileV2().companyName,
        RequestorName: TextInputCanvas4.Value,
        Purpose_Subcode: Coalesce(First(itemGrid.AllItems).cmbPurposeSubcode.Selected.Title, ""),
        Purpose_Subcode_Id: Coalesce(First(itemGrid.AllItems).cmbPurposeSubcode.Selected.InternalID, 0)
    }
);

// 4. Patch PR_Item - chỉ giữ fields tối thiểu + PurposeSubcode test
ForAll(
    itemGrid.AllItems,
    Patch(
        'SY2425-PR_Item',
        Defaults('SY2425-PR_Item'),
        {
            'PR_No (PR_No0)': prNumber,
            ItemName: Coalesce(ThisRecord.drpItemName.Selected.itemName, "TEST ITEM"),
            itemDepartment: Coalesce(ThisRecord.txtItemDepartment.Selected.DepartmentName, ""),
            Quantity: Value(Coalesce(ThisRecord.txtQuant_5.Value, "1")),
            UnitPrice: Value(Coalesce(ThisRecord.txtUnitPrice_4.Value, "0")),
            Currency: Coalesce(txtDefaultCurrency.Text, "MYR"),
            'Total Amount': Value(Coalesce(ThisRecord.txtTotalAmount_4.Value, "0")),
            PurposeSubcode: Coalesce(ThisRecord.cmbPurposeSubcode.Selected.Title, ""),
            PurposeSubcodeID: Coalesce(ThisRecord.cmbPurposeSubcode.Selected.InternalID, 0)
        }
    )
);

// 5. Thông báo kết quả
Notify(
    "TEST Draft saved! PR: " & prNumber & 
    " | PurposeSubcode: " & Coalesce(First(itemGrid.AllItems).cmbPurposeSubcode.Selected.Title, "(blank)") &
    " | ID: " & Coalesce(First(itemGrid.AllItems).cmbPurposeSubcode.Selected.InternalID, 0),
    NotificationType.Success
);

ResetForm(GeneralInforForm);
Set(varSpinner, false);
