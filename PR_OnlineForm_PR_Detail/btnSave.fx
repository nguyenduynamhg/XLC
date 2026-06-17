//Check if user delete or Edit items in the grid
IfError(
If(
    
    IsBlank(txtTitle.Value) Or Len(txtTitle.Value) < 20 Or IsBlank(DataCardValue15_3.SelectedDate) Or IsBlank(txtDescription.Value) Or IsBlank(DataCardValue17_3.Attachments) Or 
    IsBlank(cmbOneTimeVendor_De.Selected),
    Set(
        checkFields,
        false
    ),


    // Count records with any blank fields
    If(
        IsEmpty(itemGrid_2.AllItems),
        Set(
            checkFields,
            false
        ),
        Set(
            CountFalse,
            CountIf(
                itemGrid_2.AllItems,
                IsBlank(cmbCurrency2.Selected) || IsBlank(txtItemDepartmentDe.Selected.DepartmentName) || IsBlank(txtQuant_4.Value) || IsBlank(txtUnitPrice_3.Value) || IsBlank(cmbCurriculumDe.Selected) /*|| IsBlank(combItemCodeDe.Selected) || IsBlank(drpItemName_1.Selected)*/
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
);
    // Validation: ensure combo exists in Approval Matrix for FIRST item
    If(
        IsBlank(
            LookUp(
                ApprovalMatrix_SY2425,
                Subsidiary           = First(itemGrid_2.AllItems).txtItemSubsidiary2.Selected.Name &&
                Dept                 = First(itemGrid_2.AllItems).txtItemDepartmentDe.Selected.DepartmentName &&
                Campus               = First(itemGrid_2.AllItems).drpCampuNew_De.Selected.CampusName &&
                Curriculumn_YearGroup = First(itemGrid_2.AllItems).cmbCurriculumDe.Selected.CurriculumName
            )
        ),
        Set(checkMatrix, false);
        
        Set(varSpinner, false),
        Set(checkMatrix, true);

        
    );

    If(checkFields && checkMatrix,
    // Step 1: Collect all items with the same PR_No into a temporary collection
    ClearCollect(
        itemsToRemove,
        Filter('SY2425-PR_Item', 'PR_No (PR_No0)' = SelectedPR.PR_No)
    );

    // Step 2: Remove items from the SharePoint list
    ForAll(
        itemsToRemove,
        Remove('SY2425-PR_Item',ThisRecord)
    );
    ClearCollect(
        itemCollection,
        itemGrid_2.AllItems
    );
    // Step 3: Insert new or updated items from itemGrid_2 into the SharePoint list
    ForAll(
        itemCollection,
        Patch(
            'SY2425-PR_Item',
            Defaults('SY2425-PR_Item'),
            {
                'PR_No (PR_No0)': SelectedPR.PR_No,
                ItemName: ThisRecord.drpItemName_1.Selected.itemName,
                ItemManualInput:ThisRecord.drpItemName_1.Selected.ItemCategory,
                itemDepartment:ThisRecord.txtItemDepartmentDe.Selected.DepartmentName,
                Quantity: Value(ThisRecord.txtQuant_4.Value),  // Convert text to number
                UnitPrice: Value(ThisRecord.txtUnitPrice_3.Value), // Convert text to number
                Currency: cmbCurrency2.Selected.Value,
                'Total Amount': Value(ThisRecord.txtTotalAmount_3.Value), // Convert text to number
                GLNumber:ThisRecord.drpItemName_1.Selected.GLNumber,
                GLDescription: ThisRecord.drpItemName_1.Selected.GLDescription,
                Item_TotalAmt_MYR: Value(ThisRecord.txtTotalAmount_5.Value),
                CurYearGroup: ThisRecord.cmbCurriculumDe.Selected.CurriculumName, 
                NSItemInternalID: ThisRecord.drpItemName_1.Selected.NSItemInternalID, 
                NSItemExternalID: ThisRecord.drpItemName_1.Selected.NSItemExternalID,
                NSDepartmentID:ThisRecord.txtItemDepartmentDe.Selected.NS_InternalID,
                GridID:ThisRecord.GridID, 
                itemDescription: ThisRecord.txtItemDescriptionDE.Value, 
              //  ExpenseType: ThisRecord.drpItemName_1.Selected.BudgetType, 
                ItemID: ThisRecord.drpItemName_1.Selected.ItemCode, 
               // GLNumber: ThisRecord.drpItemName_1.Selected.GLNumber, 
                Dept_NSID:ThisRecord.txtItemDepartmentDe.Selected.NS_InternalID,
                itemGrossAmount: Value(ThisRecord.txtGrossAmountTaxDe.Value), 
                itemTaxCode: ThisRecord.cmbTaxCodeDe.Selected.TaxName, 
                itemTaxPercentage: ThisRecord.cmbTaxCodeDe.Selected.TaxPercentage, 
                Campus: ThisRecord.drpCampuNew_De.Selected.CampusName, 
                CampusNSID: ThisRecord.drpCampuNew_De.Selected.NSCampusID,
                CurriculumnNSID: ThisRecord.cmbCurriculumDe.Selected.CurNSInternalID, 
                itemTaxNSID: ThisRecord.cmbTaxCodeDe.Selected.NS_InternalID, 
                
                itemSubsidiary: ThisRecord.txtItemSubsidiary2.Selected.Name, 
                itemSubsidiaryNSID: ThisRecord.txtItemSubsidiary2.Selected.NS_InternalID
            
            }
        )
    );

    // Step 4: Refresh the gallery data
    ClearCollect(
        itemGrid_2_Col, 
        Filter('SY2425-PR_Item', 'PR_No (PR_No0)' = SelectedPR.PR_No)
    );

    // Step 5: Notify the user about successful operation
    Notify("Data saved successfully", NotificationType.Success);

    // Submit the General Info Form (if applicable)
    SubmitForm(GeneralInforForm_2);

    Set (
    uniqueCampusesCount,
    CountRows(Distinct(itemGrid_2_Col,Campus))  
    );

    // Determine The PR type based on number of unique campuses
    /*Set(
        UprType,
        If(CountIf(
                itemGrid_2.AllItems,
                    txtItemDepartmentDe.Selected.DepartmentName = "Operations : Technology"
                ) =0,"NonICT","ICT")
    );*/

    Set(TotalAmountGrid, Sum(itemGrid_2.AllItems, Value(txtTotalAmount_3.Value)) );
    Set(TotalEstAmountSGD, Sum(itemGrid_2.AllItems, Value(txtTotalAmount_5.Value)));
    // Update the General Info list

    If(ToggleVendor_1.Checked = true, Set(POVendorNSDefaultID, "33"), Set(POVendorNSDefaultID, cmbOneTimeVendor_De.Selected.NSInternalID));
    Set(POVendorNSDefaultID, cmbOneTimeVendor_De.Selected.NSInternalID);
    Set(POVendorNSDefaultName, cmbOneTimeVendor_De.Selected.VendorFullName);

    Patch(
        'SY2425-PR-GeneralInfo',
        LookUp('SY2425-PR-GeneralInfo', PR_No = SelectedPR.PR_No),
        {   Purpose: txtDescription.Value,
            
            PR_Type: drpPRType_1.Selected.TypeName,
            PRTypeNSID: drpPRType_1.Selected.Value,
            'Total Amount': Value(TotalAmountGrid),
            TotalAmount_MYR: Value(Sum(
        itemGrid_2.AllItems,
        Value(txtTotalAmount_5.Value)
    )), 
            NSVendorFullName: POVendorNSDefaultName, 
            NSVendorExternalID:POVendorNSDefaultID, 
            PRVendorName:DataCardValue10.Value, 
            Contract:chkContract.Checked,
            ContractStartDate: ContractStartDate.SelectedDate, 
            ContractEndDate: ContractEndDate.SelectedDate, 
        
            Item_Subsidiary_NS_ID:First(itemCollection).txtItemSubsidiary2.Selected.NS_InternalID, 
            Item_Campus_NS_ID: First(itemCollection).drpCampuNew_De.Selected.NSCampusID, 
            Item_Curriculum_NS_ID: First(itemCollection).cmbCurriculumDe.Selected.CurNSInternalID, 
            Item_Dept_NS_ID: First(itemCollection).txtItemDepartmentDe.Selected.NS_InternalID,

            Item_Subsidiary:First(itemCollection).txtItemSubsidiary2.Selected.Name, 
            Item_Campus: First(itemCollection).drpCampuNew_De.Selected.CampusName, 
            Item_Curriculum: First(itemCollection).cmbCurriculumDe.Selected.CurriculumName, 
            Item_Dept: First(itemCollection).txtItemDepartmentDe.Selected.DepartmentName           
        }
    );

    // Reset the edit mode and refresh data
    UpdateContext({ editMode: false });
    btnSubmit.DisplayMode.Edit;
    Set(varStartDate, Blank());
    Set(varEndDate, Blank());
    ,
    If(checkFields = false,
        Notify("There are field with * that you could not leave them blank. Please fill in the data");
    );
    If (checkMatrix = false, 
        Notify(
        "No approval matrix is configured for this Subsidiary / Department / Campus / Curriculum. Please adjust your selection.",
        NotificationType.Error)
    );
    
        
    ClearCollect(ColRecords,itemGrid_2.AllItems);
),true,false);

