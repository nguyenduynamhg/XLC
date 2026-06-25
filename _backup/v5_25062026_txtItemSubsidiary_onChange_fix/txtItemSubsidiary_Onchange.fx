// Fix: Use current row's subsidiary directly
Set(SubSearch, txtItemSubsidiary.Selected.Name);

Patch(
    ColRecords, 
    LookUp(ColRecords, GridID = ThisItem.GridID),
    {
        itemCode: drpItemName.Selected.ItemCode,
        itemCategory: drpItemName.Selected.ItemCategory,
        itemName: drpItemName.Selected.itemName, 
        GridtaxCode: cmbTaxCode.Selected.TaxName,
        GLNumber: drpItemName.Selected.GLNumber, 
        BudgetType: drpItemName.Selected.BudgetType,
        itemDescription: txtItemDescription.Value, 
        Quantity: Value(txtQuant_5.Value),
        UnitPrice: Value(txtUnitPrice_4.Value), 
        GridSub: SubSearch
    }
);

If(
    !IsBlank(SubSearch),
    
    // Batch 1: Use ID (numeric) instead of IndexID (text with commas)
    ClearCollect(
        colBatch1,
        ShowColumns(
            FirstN(
                Sort(
                    Filter(NS_Master_Vendor, OpenSubsidiary = SubSearch),
                    ID,
                    SortOrder.Ascending
                ),
                2000
            ),
            VendorFullName, ID, NSInternalID, DefaultCurrency
        )
    );

    // Batch 2
    If(
        CountRows(colBatch1) >= 2000,
        ClearCollect(
            colBatch2,
            ShowColumns(
                FirstN(
                    Sort(
                        Filter(NS_Master_Vendor, OpenSubsidiary = SubSearch && ID > Last(colBatch1).ID),
                        ID,
                        SortOrder.Ascending
                    ),
                    2000
                ),
                VendorFullName, ID, NSInternalID, DefaultCurrency
            )
        ),
        Clear(colBatch2)
    );

    // Batch 3 (for subsidiaries with >4000 vendors if needed)
    If(
        CountRows(colBatch2) >= 2000,
        ClearCollect(
            colBatch3,
            ShowColumns(
                FirstN(
                    Sort(
                        Filter(NS_Master_Vendor, OpenSubsidiary = SubSearch && ID > Last(colBatch2).ID),
                        ID,
                        SortOrder.Ascending
                    ),
                    2000
                ),
                VendorFullName, ID, NSInternalID, DefaultCurrency
            )
        ),
        Clear(colBatch3)
    );

    // Combine all batches
    ClearCollect(colVendorList, colBatch1, colBatch2, colBatch3);
    ,
    Clear(colVendorList)
)