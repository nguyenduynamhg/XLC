If(
    IsBlank(txtTitle.Value) || Len(txtTitle.Value) < 20 || IsBlank(txtDescription.Value) Or IsBlank(DataCardValue17_3.Attachments),
    Set(
        checkFields2,
        false
    ),
    // Count records with any blank fields
    If(
        IsEmpty(itemGrid_2.AllItems),
        Set(
            checkFields2,
            false
        ),
        Set(
            CountFalse2,
            CountIf(
                itemGrid_2.AllItems,
                IsBlank(drpCurrrency.Selected.Value) || IsBlank(cmbCurriculumDe.Selected) || IsBlank(txtItemDepartmentDe.Selected.DepartmentName) || IsBlank(txtQuant_4.Value) || IsBlank(txtUnitPrice_3.Value) /*|| IsBlank(drpItemName_1.Selected) || IsBlank(combItemCodeDe.Selected)*/
            )
        );
        // Set checkFields based on CountFalse
    If(
            CountFalse2 > 0,
            Set(
                checkFields2,
                false
            ),
            Set(
                checkFields2,
                true
            )
        )
    )
);
// Reset the edit mode and refresh data
UpdateContext({btnSubClicked: true});
ClearCollect(
    itemCollection,
    itemGrid_2.AllItems
);
/*
Set(
    UprType,
    If(CountIf(
               itemGrid_2.AllItems,
                txtItemDepartmentDe.Selected.DepartmentName = "Operations : Technology"
            ) =0,"NonICT","ICT")
);*/




Set(
    TotalAmountGrid,
    Sum(
        itemGrid_2.AllItems,
        Value(txtTotalAmount_5.Value)
    )
);
//Search for Reviewer Email
       

Set(
    reviewerEmail,
    LookUp(
        ApprovalMatrix_SY2425,
        
        //Campus = Office365Users.MyProfileV2().officeLocation And Dept = Office365Users.MyProfileV2().department// ReviewerEmail is the field storing the reviewer's email
        Requestor = User().Email
    ).Reviewer
);



Patch(
    'SY2425-PR-GeneralInfo',
    LookUp(
        'SY2425-PR-GeneralInfo',
        PR_No = SelectedPR.PR_No
    ),
    {
        Status: "Reviewer",
        LatestStatus: "Pending",
        'Total Amount': Sum(
                itemGrid_2.AllItems,
                txtTotalAmount_3.Value
            ),
        TotalAmount_MYR: Value(Sum(
        itemGrid_2.AllItems,
        Value(txtTotalAmount_5.Value)
    )),
        PR_Type: drpPRType_1.Selected.TypeName,
        PRTypeNSID: drpPRType_1.Selected.Value
    }
);
// Optionally, notify the user of the created PR number
Notify(
    "Your Purchase request and item details successfully submitted. Purchase Request Number: " & SelectedPR.PR_No & " has been created!",
    NotificationType.Success
);


//Create Approval Log for Reviewer
// Search for Reviewer list (JSON)

// Build a table of reviewers: { Email: "a@x", "b@x", ... }

// 1. Get Reviewer JSON text and strip CR/LF
Set(
    varReviewerJson2,
    Substitute(
        Substitute(
            Coalesce(
                LookUp(
                    ApprovalMatrix_SY2425,
                    Subsidiary = First(itemGrid_2.AllItems).txtItemSubsidiary2.Selected.Name &&
                    Dept       = First(itemGrid_2.AllItems).txtItemDepartmentDe.Selected.DepartmentName &&
                    Campus     = First(itemGrid_2.AllItems).drpCampuNew_De.Selected.CampusName &&
                    Curriculumn_YearGroup = First(itemGrid_2.AllItems).cmbCurriculumDe.Selected.CurriculumName
                ).Reviewer,
                "[]"
            ),
            Char(10),    // remove line feed
            ""
        ),
        Char(13),        // remove carriage return
        ""
    )
);

// 2. Build a table of reviewers: { Email: "a@x", "b@x", ... }
Set(
    varReviewerList2,
    ForAll(
        ParseJSON(varReviewerJson2) As ParsedReviewer2,
        {
            Email: Text(ParsedReviewer2)
        }
    )
);


    // ===============================
// Create Approval Logs for REVIEWER stage
// ===============================
If(
    !IsEmpty(varReviewerList2),
    ForAll(
        varReviewerList2 As R,
        Patch(
            'SY2425-Approval_log',
            Defaults('SY2425-Approval_log'),
            {
                PR_No: SelectedPR.PR_No,
                Dept: Office365Users.MyProfileV2().department,
                Campus: Office365Users.MyProfileV2().companyName,
                Requestor: Office365Users.MyProfileV2().mail,
                'Requestor Name': Office365Users.MyProfileV2().displayName,

                'Approved By': R.Email,
                'Approver Name': IfError(
                    Office365Users.UserProfileV2(R.Email).displayName,
                    "Unknown"
                ),
                Item_Campus: First(itemGrid_2.AllItems).drpCampuNew_De.Selected.CampusName, 
                Item_Curriculum: First(itemGrid_2.AllItems).cmbCurriculumDe.Selected.CurriculumName,
                Item_Dept:First(itemGrid_2.AllItems).txtItemDepartmentDe.Selected.DepartmentName, 
                Item_Subsidiary:First(itemGrid_2.AllItems).txtItemSubsidiary2.Selected.Name,
                Stage: "Reviewer",
                StageCheck: "Reviewer",
                Status: "Pending",
                LogType: "Reviewer"
            }
        );

    
    )
);
    // ========================================
// Notify user & call Flow for FIRST reviewer
// ========================================
Notify(
    "Your Purchase request and item details successfully submitted. Purchase Request Number: " & prNumber & " has been created!",
    NotificationType.Success
);



//Remove Duplicated records

// Step 1: Create unique keys for identifying duplicates

ClearCollect(
    colDuplicateKeys,
    RenameColumns(
        Distinct(
            ForAll(
                Filter(
                    'SY2425-Approval_log',
                    PR_No = SelectedPR.PR_No &&
                    Status = "Pending"
                ),
                PR_No & "|" & 'Approved By' & "|" & LogType
            ),
            Value
        ),
        Value, dupKey
    )
);


// Step 2: Loop over each unique key, and collect all duplicates except the latest one
ClearCollect(colToDelete, {ID: Blank()});

ForAll(
    colDuplicateKeys,
    Collect(
        colToDelete,
        FirstN(
            SortByColumns(
                Filter(
                    'SY2425-Approval_log',
                    PR_No = SelectedPR.PR_No &&
                    Status = "Pending" &&
                    PR_No & "|" & 'Approved By' & "|" & LogType = dupKey
                ),
                "Modified",
                SortOrder.Ascending
            ),
            CountRows(
                Filter(
                    'SY2425-Approval_log',
                    PR_No = SelectedPR.PR_No And
                    Status = "Pending" And
                    PR_No & "|" & 'Approved By' & "|" & LogType = dupKey
                )
            ) - 1
        )
    )
);


// Step 3: Remove the collected duplicate items
RemoveIf(
    'SY2425-Approval_log',
    ID in colToDelete.ID
);

//GeneralInforForm_2.DisplayMode.View;
Navigate(PR_OnlineForm_YourPR)