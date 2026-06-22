Set(
    varSpinner,
    true
);
If(
    ToggleVendor.Checked = false,
    If(
        IsBlank(DataCardValue4.Value) || Len(DataCardValue4.Value) < 20 || IsBlank(DataCardValue15_1.SelectedDate) || IsBlank(DataCardValue13_1.Value) || IsEmpty(DataCardValue17_1.Attachments) || IsBlank(drpCurrrency.Selected.Value) || IsBlank(drpPaymentTerm.Selected.Value || IsBlank(cmbOneTimeVendor.Selected.NSInternalID)),
        Set(
            checkFields,
            false
        ),
        // Count records with any blank fields
        If(
            IsEmpty(itemGrid.AllItems),
            Set(
                checkFields,
                false
            ),
            Set(
                CountFalse,
                CountIf(
                    itemGrid.AllItems,
                    IsBlank(drpCurrrency.Selected) || IsBlank(txtItemDepartment.Selected.DepartmentName) ||//replace Combobox of Department
 IsBlank(txtQuant_5.Value) || IsBlank(txtUnitPrice_4.Value) ||
                    //IsBlank(drpItemName.Selected) ||
//IsBlank(combItemName.Selected) || 
 IsBlank(txtItemDescription.Value) || IsBlank(cmbTaxCode.Selected) || IsBlank(drpCampuNew.Selected)
                    //IsBlank(txtBudgetCode_3.Value) 
                )
            );
            // Set checkFields based on CountFalse
            If(
                CountFalse > 0,
                Set(
                    checkFields,
                    false
                ),
                Set(
                    checkFields,
                    true
                )
            )
        )
    ),
    If(
        IsBlank(DataCardValue4.Value) || Len(DataCardValue4.Value) < 20 || IsBlank(DataCardValue15_1.SelectedDate) || IsBlank(DataCardValue13_1.Value) || IsEmpty(DataCardValue17_1.Attachments) || IsBlank(drpCurrrency.Selected.Value) || IsBlank(drpPaymentTerm.Selected.Value || IsBlank(DataCardValue6.Value) || DataCardValue6.Value = ""),
        Set(
            checkFields,
            false
        ),
        // Count records with any blank fields
        If(
            IsEmpty(itemGrid.AllItems),
            Set(
                checkFields,
                false
            ),
            Set(
                CountFalse,
                CountIf(
                    itemGrid.AllItems,
                    IsBlank(drpCurrrency.Selected) || IsBlank(txtItemDepartment.Selected.DepartmentName) ||//replace Combobox of Department
 IsBlank(txtQuant_5.Value) || IsBlank(txtUnitPrice_4.Value) || IsBlank(drpItemName.Selected) || IsBlank(combItemName.Selected) || IsBlank(txtItemDescription.Value) || IsBlank(cmbTaxCode.Selected) || IsBlank(drpCampuNew.Selected)
                    //IsBlank(txtBudgetCode_3.Value) 
                )
            );
            // Set checkFields based on CountFalse
            If(
                CountFalse > 0,
                Set(
                    checkFields,
                    false
                ),
                Set(
                    checkFields,
                    true
                )
            )
        )
    )
);
// Validation: ensure combo exists in Approval Matrix for FIRST item
If(
    IsBlank(
        LookUp(
            ApprovalMatrix_SY2425,
            Subsidiary = First(itemGrid.AllItems).txtItemSubsidiary.Selected.Name && Dept = First(itemGrid.AllItems).txtItemDepartment.Selected.DepartmentName && Campus = First(itemGrid.AllItems).drpCampuNew.Selected.CampusName && Curriculumn_YearGroup = First(itemGrid.AllItems).cmbCurriculum.Selected.CurriculumName
        )
    ),
    Set(
        checkMatrix,
        false
    );
    Set(
        varSpinner,
        false
    ),
    Set(
        checkMatrix,
        true
    );
    
);
// Notify the user based on checkFields
If(
    checkFields && checkMatrix,
    // Get current month and year as MMYY
    Set(
        currentMonthYear,
        Text(
            Today(),
            "[$-en-US]mmyy"
        )
    );
    // Check if there's already a PR for this month and year
    Set(
        lastPRRecord,
        First(
            SortByColumns(
                Filter(
                    'SY2425-PR-GeneralInfo',
                    MonthYear = currentMonthYear
                ),
                "LastNumber",
                SortOrder.Descending
            )
        )
    );
    // Determine the next incrementing number (xxxx)
    If(
        IsBlank(lastPRRecord),
        Set(
            nextIncrementingNumber,
            1
        ),// Start from 0001 if no record exists
        Set(
            nextIncrementingNumber,
            lastPRRecord.IncrementingNumber + 1
        )// Increment if record exists
    );
    // Ensure the incrementing number is always 4 digits
    Set(
        formattedIncrementingNumber,
        Text(
            nextIncrementingNumber,
            "0000"
        )
    );
    // Create the PR number
    Set(
        prNumber,
        "RF" & currentMonthYear & "-" & formattedIncrementingNumber
    );
    // Submit the form General Info:
    // Determine The PR type based on number of unique campuses
    Set(
        prType,
        txtCountPR.Text
    );
    //Save the Item Details to SY2425-PR-Item
    Set(
        checking,
        LookUp(
            'SY2425-PR-GeneralInfo',
            PR_No = prNumber
        )
    );
    If(
        IsBlank(checking),
        prNumber,
        Set(
            nextIncrementingNumber,
            nextIncrementingNumber + 1
        );
        Set(
            formattedIncrementingNumber,
            Text(
                nextIncrementingNumber,
                "0000"
            )
        );
        Set(
            prNumber,
            "RF" & currentMonthYear & "-" & formattedIncrementingNumber
        );
    );
    SubmitForm(GeneralInforForm);
    //  If (IsBlank(VendorNSInternalID), Set(VendorNSInternalID, "33"));
    If (
        First(itemGrid.AllItems).drpCampuNew.Selected.RealKids = "Yes",
        Set(
            PRRouteType,
            "RealKids"
        ),
        Set(
            PRRouteType,
            "0"
        )
    );
    // Save the PR Number to SharePoint
    Patch(
        'SY2425-PR-GeneralInfo',
        GeneralInforForm.LastSubmit,
        {
            PR_No: prNumber,
            MonthYear: currentMonthYear,
            IncrementingNumber: nextIncrementingNumber,
            'Total Amount': Sum(
                itemGrid.AllItems,
                txtTotalAmount_4.Value
            ),
            TotalAmount_MYR: Sum(
                itemGrid.AllItems,
                txtTotalAmount_MYR.Value
            ),
            PR_Type: drpPRType.Selected.TypeName,
            PRTypeNSID: drpPRType.Selected.Value,
            Status: "Draft",
            LatestStatus: "Pending",
            Department: Office365Users.MyProfileV2().department,
            Campus: Office365Users.MyProfileV2().companyName,
            NSPaymentTermID: drpPaymentTerm.Selected.Value,
            NSVendorFullName: cmbOneTimeVendor.Selected.VendorFullName,
            NSVendorExternalID: VendorNSInternalID,
            RequestorName: TextInputCanvas4.Value,
            Item_Subsidiary_NS_ID: First(itemGrid.AllItems).txtItemSubsidiary.Selected.NS_InternalID,
            Item_Campus_NS_ID: First(itemGrid.AllItems).drpCampuNew.Selected.NSCampusID,
            Item_Curriculum_NS_ID: First(itemGrid.AllItems).cmbCurriculum.Selected.CurNSInternalID,
            Item_Dept_NS_ID: First(itemGrid.AllItems).txtItemDepartment.Selected.NS_InternalID,
            Item_Subsidiary: First(itemGrid.AllItems).txtItemSubsidiary.Selected.Name,
            Item_Campus: First(itemGrid.AllItems).drpCampuNew.Selected.CampusName,
            Item_Curriculum: First(itemGrid.AllItems).cmbCurriculum.Selected.CurriculumName,
            Item_Dept: First(itemGrid.AllItems).txtItemDepartment.Selected.DepartmentName,
            RouteType: PRRouteType,
            Purpose_Subcode: If(
                IsBlank(First(itemGrid.AllItems).cmbPurposeSubcode.Selected),
                Blank(),
                First(itemGrid.AllItems).cmbPurposeSubcode.Selected.Title
            ),
            Purpose_Subcode_Id: If(
                IsBlank(First(itemGrid.AllItems).cmbPurposeSubcode.Selected),
                0,
                First(itemGrid.AllItems).cmbPurposeSubcode.Selected.'Internal ID'
            )
        }
    );
    ForAll(
        itemGrid.AllItems,
        Patch(
            'SY2425-PR_Item',
            Defaults('SY2425-PR_Item'),
            {
                'PR_No (PR_No0)': prNumber,
                ItemName: ThisRecord.drpItemName.Selected.itemName,
                ItemManualInput: ThisRecord.drpItemName.Selected.ItemCategory,
                itemDepartment: ThisRecord.txtItemDepartment.Selected.DepartmentName,
                Quantity: Value(ThisRecord.txtQuant_5.Value),
                UnitPrice: Value(ThisRecord.txtUnitPrice_4.Value),
                Currency: txtDefaultCurrency.Text,
                'Total Amount': Value(ThisRecord.txtTotalAmount_4.Value),
                Item_TotalAmt_MYR: Value(ThisRecord.txtTotalAmount_MYR.Value),
                CurYearGroup: ThisRecord.cmbCurriculum.Selected.CurriculumName,
                NSItemInternalID: ThisRecord.combItemName.Selected.NSItemInternalID,
                NSItemExternalID: ThisRecord.drpItemName.Selected.NSItemExternalID,
                NSDepartmentID: ThisRecord.txtItemDepartment.Selected.NS_InternalID,
                ExpenseType: ThisRecord.drpItemName.Selected.BudgetType,
                GridID: ThisRecord.GridID,
                ItemID: ThisRecord.drpItemName.Selected.ItemCode,
                GLNumber: ThisRecord.drpItemName.Selected.GLNumber,
                itemDescription: txtItemDescription.Value,
                Dept_NSID: ThisRecord.txtItemDepartment.Selected.NS_InternalID,
                itemGrossAmount: Value(ThisRecord.txtGrossAmountTax.Value),
                itemTaxCode: ThisRecord.cmbTaxCode.Selected.TaxName,
                itemTaxPercentage: ThisRecord.cmbTaxCode.Selected.TaxPercentage,
                Campus: ThisRecord.drpCampuNew.Selected.CampusName,
                CampusNSID: ThisRecord.drpCampuNew.Selected.NSCampusID,
                CurriculumnNSID: ThisRecord.cmbCurriculum.Selected.CurNSInternalID,
                itemTaxNSID: ThisRecord.cmbTaxCode.Selected.NS_InternalID,
                itemSubsidiary: ThisRecord.txtItemSubsidiary.Selected.Name,
                itemSubsidiaryNSID: ThisRecord.txtItemSubsidiary.Selected.NS_InternalID,
                PurposeSubcode: If(
                    IsBlank(ThisRecord.cmbPurposeSubcode.Selected),
                    Blank(),
                    ThisRecord.cmbPurposeSubcode.Selected.Title
                ),
                PurposeSubcodeID: If(
                    IsBlank(ThisRecord.cmbPurposeSubcode.Selected),
                    0,
                    ThisRecord.cmbPurposeSubcode.Selected.'Internal ID'
                )
            }
        )
    );
    // Optionally, notify the user of the created PR number
    Notify(
        "Your Purchase request and item details successfully submitted. Purchase Request Number: " & prNumber & " has been created!",
        NotificationType.Success
    );
    ResetForm(GeneralInforForm);
    Clear(ColRecords);
    ,
    If(
        checkFields = false,
        Notify("There are field with * that you could not leave them blank. Please fill in the data");
    );
    If (
        checkMatrix = false,
        Notify(
            "No approval matrix is configured for this Subsidiary / Department / Campus / Curriculum. Please adjust your selection.",
            NotificationType.Error
        )
    );
    Set(
        ColRecords,
        itemGrid.AllItems
    );
    
);
Set(
    VendorCurrency,
    "MYR"
);
Reset(ToggleVendor);
Set (
    varSpinner,
    false
);
