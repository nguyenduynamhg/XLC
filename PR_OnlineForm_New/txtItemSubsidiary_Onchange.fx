
Patch(
    ColRecords, 
    LookUp(ColRecords, GridID = ThisItem.GridID), // Find the record by ID
    {itemCode: drpItemName.Selected.ItemCode,
    itemCategory: drpItemName.Selected.ItemCategory,
    itemName: drpItemName.Selected.itemName, 
    GridtaxCode: cmbTaxCode.Selected.TaxName,
    GLNumber: drpItemName.Selected.GLNumber, 
    BudgetType: drpItemName.Selected.BudgetType,
    itemDescription:txtItemDescription.Value, 
        Quantity:Value(txtQuant_5.Value),
    UnitPrice: Value(txtUnitPrice_4.Value), 
    GridSub: txtItemSubsidiary.Selected.Name

    }
);


Set(SubSearch, First(ColRecords).GridSub);

If(
    !IsBlank(SubSearch),
    Clear(colBatch1);
    Clear(colBatch2);

    Collect(
            colBatch1,
            ShowColumns(
                Sort(
                    Filter(
                        NS_Master_Vendor,
                        OpenSubsidiary = SubSearch
                    ),
                    IndexID,
                    SortOrder.Ascending
                ),
                VendorFullName,
                IndexID, 
                NSInternalID, 
                DefaultCurrency
            )
    );

    If(
        CountRows(colBatch1) >= 2000,
        ClearCollect(
            colBatch2,
            ShowColumns(
                Sort(
                    Filter(
                        NS_Master_Vendor,
                        OpenSubsidiary = SubSearch && IndexID > Last(colBatch1).IndexID
                    ),
                    IndexID,
                    SortOrder.Ascending
                ),
                VendorFullName,
                IndexID, NSInternalID, DefaultCurrency
            )
        )
    );
    Clear(colVendorList);
    Collect(colVendorList, colBatch1, colBatch2);
    ,

    // Else: Subsidiary is blank
    Clear(colVendorList)
)