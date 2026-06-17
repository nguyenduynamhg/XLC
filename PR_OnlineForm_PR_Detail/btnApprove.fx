Set(
    calTotalAmoutMYRDE, 
    SelectedPR.'Total Amount' * 
        LookUp(
            'SY2425-ExchangeRate', 
            CurrencyFormat = SelectedPR.Currency
        ).ExchangeRate
    
);

If(
    IsBlank(SelectedPR.TotalAmount_MYR) || Value(SelectedPR.TotalAmount_MYR) = 0,
    Patch(
        'SY2425-PR-GeneralInfo',
        LookUp('SY2425-PR-GeneralInfo', PR_No = SelectedPR.PR_No),
        {
            TotalAmount_MYR: calTotalAmoutMYRDE
        }
    )
);
If(
    
    IsBlank(txtTitle.Value) Or Len(txtTitle.Value) < 20 Or IsBlank(DataCardValue15_3.SelectedDate) Or IsBlank(txtDescription.Value) Or IsBlank(DataCardValue17_3.Attachments) Or 
    IsBlank(cmbOneTimeVendor_De.Selected.VendorFullName),
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
                IsBlank(cmbCurrency2.Selected) || IsBlank(txtItemDepartmentDe.Selected.DepartmentName) || IsBlank(txtQuant_4.Value) || IsBlank(txtUnitPrice_3.Value) || IsBlank(cmbCurriculumDe.Selected) || IsBlank(combItemCodeDe.Selected) || IsBlank(drpItemName_1.Selected)
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

    Set(varSpinner, true);
    UpdateContext({ isApproving: true });

    // -----------------------------
    // 0) Determine PRRouteType
    // -----------------------------
    If(
        First(itemGrid_2.AllItems).drpCampuNew_De.Selected.RealKids = "Yes",
        Set(PRRouteType, "RealKids"),
        Set(PRRouteType, "0")
    );

    // 1) Get current pending approval record for THIS approver
    Set(
        latestPendingRecord,
        First(
            SortByColumns(
                Filter(
                    'SY2425-Approval_log',
                    PR_No   = SelectedPR.PR_No &&
                    'Approved By' = User().Email &&
                    Status  = "Pending"
                ),
                "Created",
                SortOrder.Descending
            )
        )
    );

    // If nothing to approve, exit
    If(
        IsBlank(latestPendingRecord),
        Set(varSpinner, false);
        Notify("No pending approval found for you on this RF.", NotificationType.Error);
    );

    // 2) Map StageCheck → numeric stage & DOA order
    Set(
        varCurrentStage,
        Switch(
            latestPendingRecord.StageCheck,
            "Reviewer",    1,
            "Reviewer2",   2,
            "BudgetOwner", 3,
            "Level5",      4,
            "Level6",      5,
            "Level7",      6,
            "Level8",      7,
            "Level9",      8,
            "Level10",     9,
            0
        )
    );

    Set(
        varCurrentDOAOrder,
        Switch(
            latestPendingRecord.StageCheck,
            "Level5",  5,
            "Level6",  6,
            "Level7",  7,
            "Level8",  8,
            "Level9",  9,
            "Level10", 10,
            Blank()
        )
    );

    // 2b) Map RF header Status → numeric RF stage
    Set(
        varRFStage,
        Switch(
            SelectedPR.Status,
            "Reviewer",    1,
            "Reviewer2",   2,
            "BudgetOwner", 3,
            "Level5",      4,
            "Level6",      5,
            "Level7",      6,
            "Level8",      7,
            "Level9",      8,
            "Level10",     9,
            "Final Approved", 10,
            10
        )
    );

    // 3) Build DOA stages collection for this RF
    Set(varRFSubsidiary, SelectedPR.Item_Subsidiary);
    Set(varRFCampus,     SelectedPR.Item_Campus);
    Set(varRFTotalMYR,   SelectedPR.TotalAmount_MYR);

    ClearCollect(
        colDOAForRF,
        Filter(
            DOA_Matrix_SY2425,
            Subsidiary    = varRFSubsidiary &&
            Campus        = varRFCampus     &&
            Threshold_Min <= varRFTotalMYR
        )
    );

    // Final DOA StageOrder = max StageOrder from colDOAForRF
    Set(
        varDOAFinalStageOrder,
        If(
            IsEmpty(colDOAForRF),
            Blank(),
            Last(
                SortByColumns(
                    colDOAForRF,
                    "StageOrder",
                    SortOrder.Ascending
                )
            ).StageOrder
        )
    );

    // 4) Approve current log record (always Approved first)
    Patch(
        'SY2425-Approval_log',
        latestPendingRecord,
        {
            ApprovedByWho: User().Email,
            Status: "Approved",
            LogType: latestPendingRecord.StageCheck
        }
    );

    // 4b) If this log is EARLIER than RF stage → just mark Approved and STOP.
    If(
        varCurrentStage < varRFStage,
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
                Value,
                dupKey
            )
        );
        ClearCollect(colToDelete, { ID: Blank() });
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
                            PR_No = SelectedPR.PR_No &&
                            Status = "Pending" &&
                            PR_No & "|" & 'Approved By' & "|" & LogType = dupKey
                        )
                    ) - 1
                )
            )
        );
        RemoveIf('SY2425-Approval_log', ID in colToDelete.ID);
        Set(varSpinner, false);
        Notify("Approval completed successfully.", NotificationType.Success);
    );

    // 5) Branch logic: matrix stages (≤3) vs DOA stages (≥4)
    If(
        // MATRIX STAGES (1–3)
        varCurrentStage <= 3,

        // A1) If BudgetOwner just approved
        If(
            latestPendingRecord.StageCheck = "BudgetOwner",

            // If there are DOA rows, go to first DOA stage
            If(
                !IsEmpty(colDOAForRF),
                With(
                    {
                        _firstDOARec:
                            First(
                                SortByColumns(
                                    Filter(colDOAForRF, StageOrder >= 5),
                                    "StageOrder",
                                    SortOrder.Ascending
                                )
                            )
                    },
                    If(
                        !IsBlank(_firstDOARec),
                        With(
                            {
                                _firstStageName:
                                    Switch(
                                        _firstDOARec.StageOrder,
                                        5, "Level5",
                                        6, "Level6",
                                        7, "Level7",
                                        8, "Level8",
                                        9, "Level9",
                                        10,"Level10"
                                    )
                            },
                            Patch(
                                'SY2425-PR-GeneralInfo',
                                LookUp('SY2425-PR-GeneralInfo', PR_No = SelectedPR.PR_No),
                                { Status: _firstStageName, LatestStatus: latestPendingRecord.StageCheck}
                            );
                            Patch(
                                'SY2425-Approval_log',
                                Defaults('SY2425-Approval_log'),
                                {
                                    PR_No: SelectedPR.PR_No,
                                    Dept: SelectedPR.Department,
                                    Campus: varRFCampus,
                                    Item_Subsidiary: varRFSubsidiary,
                                    Item_Campus: varRFCampus,
                                    Item_Dept: SelectedPR.Item_Dept,
                                    Item_Curriculum: SelectedPR.Item_Curriculum,
                                    Requestor: SelectedPR.Requestor,
                                    'Requestor Name': SelectedPR.RequestorName,
                                    'Approved By': _firstDOARec.ApproverEmail,
                                    'Approver Name': _firstDOARec.ApproverName,
                                    Stage: _firstStageName,
                                    StageCheck: _firstStageName,
                                    Status: "Pending",
                                    LogType: _firstDOARec.StageName
                                }
                            )
                        )
                    )
                ),
                // No DOA rows → BudgetOwner is final approver
                Patch(
                    'SY2425-PR-GeneralInfo',
                    LookUp('SY2425-PR-GeneralInfo', PR_No = SelectedPR.PR_No),
                    { Status: "Final Approved", LatestStatus: "Final Approved", FinalApprovedDate: Now() }
                );
                Patch('SY2425-Approval_log', latestPendingRecord, { Status: "Final Approved" })
            ),

            // Reviewer / Reviewer2 → move to next matrix stage
            Set(varNextStage, varCurrentStage + 1);

            Patch(
                'SY2425-PR-GeneralInfo',
                LookUp('SY2425-PR-GeneralInfo', PR_No = SelectedPR.PR_No),
                {
                    Status: Switch(varNextStage, 2, "Reviewer2", 3, "BudgetOwner"),
                    LatestStatus: latestPendingRecord.StageCheck
                }
            );

            // Build list of next-stage approvers
            Set(
                varNextApproverList,
                Switch(
                    varNextStage,

                    // Reviewer2 – JSON list
                    2,
                        ForAll(
                            ParseJSON(
                                Substitute(
                                    Substitute(
                                        LookUp(
                                            ApprovalMatrix_SY2425,
                                            Subsidiary = SelectedPR.Item_Subsidiary &&
                                            Dept       = SelectedPR.Item_Dept &&
                                            Campus     = SelectedPR.Item_Campus &&
                                            Curriculumn_YearGroup = SelectedPR.Item_Curriculum
                                        ).Reviewer2,
                                        Char(10),
                                        ""
                                    ),
                                    Char(13),
                                    ""
                                )
                            ) As Parsed,
                            { Email: Parsed }
                        ),

                    // BudgetOwner – SINGLE EMAIL (RealKids rules applied here)
                    
                    3,
                        With(
                        {
                            // BƯỚC 1: Lấy toàn bộ dòng dữ liệu từ Matrix (chỉ LookUp 1 lần)
                            _MatrixRecord: LookUp(
                                ApprovalMatrix_SY2425,
                                Subsidiary = SelectedPR.Item_Subsidiary &&
                                Dept = SelectedPR.Item_Dept &&
                                Campus = SelectedPR.Item_Campus &&
                                Curriculumn_YearGroup = SelectedPR.Item_Curriculum
                            )
                        },
                        // BƯỚC 2: Tính toán logic email dựa trên kết quả Bước 1
                        With(
                            {
                                _FinalEmail: 
                                If(
                                    PRRouteType = "RealKids",
                                    // Logic cho RealKids
                                    If(
                                        SelectedPR.Item_Dept = "Operations : Facility",
                                        _MatrixRecord.'Budget Owner',
                                        If(
                                            Value(SelectedPR.TotalAmount_MYR) <= 2500,
                                            _MatrixRecord.RKManager,
                                            _MatrixRecord.RKManager2
                                        )
                                    ),
                                    // Logic mặc định (Non-RealKids)
                                    _MatrixRecord.'Budget Owner'
                                )
                            },
                            // BƯỚC 3: Trả về Table và làm sạch văn bản
                            Table(
                                {
                                    Email: 
                                        Text(
                                            Substitute(
                                                Substitute(
                                                    _FinalEmail, // Dùng biến đã tính ở Bước 2
                                                    Char(10),
                                                    ""
                                                ),
                                                Char(13),
                                                ""
                                            )
                                        )
                                }
                            )
                        )
                    )


                )
            );

            // Create logs for next matrix approver(s)
            ForAll(
                varNextApproverList As NextAppr,
                Patch(
                    'SY2425-Approval_log',
                    Defaults('SY2425-Approval_log'),
                    {
                        PR_No: SelectedPR.PR_No,
                        Dept: SelectedPR.Department,
                        Campus: SelectedPR.Campus,
                        Item_Subsidiary: SelectedPR.Item_Subsidiary,
                        Item_Campus: SelectedPR.Item_Campus,
                        Item_Dept: SelectedPR.Item_Dept,
                        Item_Curriculum: SelectedPR.Item_Curriculum,
                        Requestor: SelectedPR.Requestor,
                        'Requestor Name': SelectedPR.RequestorName,
                        'Approved By': NextAppr.Email,
                        'Approver Name': IfError(Office365Users.UserProfileV2(NextAppr.Email).displayName, "Unknown"),
                        Stage: Switch(varNextStage, 2, "Reviewer2", 3, "BudgetOwner"),
                        StageCheck: Switch(varNextStage, 2, "Reviewer2", 3, "BudgetOwner"),
                        Status: "Pending",
                        LogType: Switch(varNextStage, 2, "Reviewer2", 3, "BudgetOwner")
                    }
                )
            );
            /*
            If(
                !IsEmpty(varNextApproverList),

                ForAll(
                    varNextApproverList As R,

                
                    XMCO_SY2425_PRSubmmitedFlow_Single.Run(
                    SelectedPR.PR_No,                                        // RF number
                    R.Email,                              // send to first reviewer
                    IfError(
                        Office365Users.UserProfileV2(R.Email).displayName,
                        "an.huynhthien@vas.edu.vn"
                    ),
                    User().FullName
                    )
                )
            );*/
            
        ),

        // DOA STAGES (5–10) unchanged
        With(
            { _finalOrder: varDOAFinalStageOrder, _currentOrder: varCurrentDOAOrder },
            If(
                !IsBlank(_finalOrder) && _currentOrder = _finalOrder,
                Patch(
                    'SY2425-PR-GeneralInfo',
                    LookUp('SY2425-PR-GeneralInfo', PR_No = SelectedPR.PR_No),
                    { Status: "Final Approved", LatestStatus: "Final Approved", FinalApprovedDate: Now() }
                );
                Patch('SY2425-Approval_log', latestPendingRecord, { Status: "Final Approved" }),
                With(
                    {
                        _nextDOARec:
                            First(
                                SortByColumns(
                                    Filter(
                                        colDOAForRF,
                                        StageOrder > _currentOrder &&
                                        StageOrder <= _finalOrder
                                    ),
                                    "StageOrder",
                                    SortOrder.Ascending
                                )
                            )
                    },
                    If(
                        !IsBlank(_nextDOARec),
                        With(
                            {
                                _nextStageName:
                                    Switch(
                                        _nextDOARec.StageOrder,
                                        5, "Level5",
                                        6, "Level6",
                                        7, "Level7",
                                        8, "Level8",
                                        9, "Level9",
                                        10,"Level10"
                                    )
                            },
                            Patch(
                                'SY2425-PR-GeneralInfo',
                                LookUp('SY2425-PR-GeneralInfo', PR_No = SelectedPR.PR_No),
                                { Status: _nextStageName, LatestStatus: latestPendingRecord.StageCheck }
                            );
                            Patch(
                                'SY2425-Approval_log',
                                Defaults('SY2425-Approval_log'),
                                {
                                    PR_No: SelectedPR.PR_No,
                                    Dept: SelectedPR.Department,
                                    Campus: varRFCampus,
                                    Item_Subsidiary: varRFSubsidiary,
                                    Item_Campus: varRFCampus,
                                    Item_Dept: SelectedPR.Item_Dept,
                                    Item_Curriculum: SelectedPR.Item_Curriculum,
                                    Requestor: SelectedPR.Requestor,
                                    'Requestor Name': SelectedPR.RequestorName,
                                    'Approved By': _nextDOARec.ApproverEmail,
                                    'Approver Name': _nextDOARec.ApproverName,
                                    Stage: _nextStageName,
                                    StageCheck: _nextStageName,
                                    Status: "Pending",
                                    LogType: _nextDOARec.StageName
                                }
                            );
                            /*
                            XMCO_SY2425_PRSubmmitedFlow_Single.Run(
                                SelectedPR.PR_No,                                        // RF number
                                _nextDOARec.ApproverEmail,                              // send to first reviewer
                                IfError(
                                    Office365Users.UserProfileV2(_nextDOARec.ApproverEmail).displayName,
                                    "an.huynhthien@vas.edu.vn"
                                ),
                                User().FullName
                            );*/
                        ),
                        Patch(
                            'SY2425-PR-GeneralInfo',
                            LookUp('SY2425-PR-GeneralInfo', PR_No = SelectedPR.PR_No),
                            { Status: "Final Approved", LatestStatus: "Final Approved", FinalApprovedDate: Now() }
                        );
                        Patch('SY2425-Approval_log', latestPendingRecord, { Status: "Final Approved" })
                    )
                )
            )
        )
    );

    // 6) Clean up duplicate pending logs
    ClearCollect(
        colDuplicateKeys,
        RenameColumns(
            Distinct(
                ForAll(
                    Filter('SY2425-Approval_log', PR_No = SelectedPR.PR_No && Status = "Pending"),
                    PR_No & "|" & 'Approved By' & "|" & LogType
                ),
                Value
            ),
            Value,
            dupKey
        )
    );

    ClearCollect(colToDelete, { ID: Blank() });

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
                        PR_No = SelectedPR.PR_No &&
                        Status = "Pending" &&
                        PR_No & "|" & 'Approved By' & "|" & LogType = dupKey
                    )
                ) - 1
            )
        )
    );

    RemoveIf('SY2425-Approval_log', ID in colToDelete.ID);

    // 7) Finalize UI
    Set(varSpinner, false);
    Notify("Approval completed successfully.", NotificationType.Success);
    ,
    If(checkFields = false,
        Notify("There are field with * that you could not leave them blank. Please fill in the data");
    );
    If (checkMatrix = false, 
        Notify(
        "No approval matrix is configured for this Subsidiary / Department / Campus / Curriculum. Please adjust your selection.",
        NotificationType.Error)
    );
)
