/* UpdateContext({ isApproving: false });

If(
    IsBlank(txtRejectComment.Value),
    Notify("Please enter reason to reject", NotificationType.Warning),
    
    // Begin main rejection logic
    With(
        {
            currentApprovalLog: LookUp(
                'SY2425-Approval_log',
                PR_No = SelectedPR.PR_No &&
                Status = "Pending" &&
                field_7 = User().Email
            )
        },
        
        If(
            !IsBlank(currentApprovalLog),
            
            // 1. Update Approval Log to Rejected
            Patch(
                'SY2425-Approval_log',
                currentApprovalLog,
                {
                    Status: "Returned",
                    RejectComment: txtRejectComment.Value,
                    Returned: "1"
                }
            );

            // 2. Update PR-GeneralInfo to Rejected and move Stage back to Draft
            Patch(
                'SY2425-PR-GeneralInfo',
                LookUp('SY2425-PR-GeneralInfo', PR_No = SelectedPR.PR_No),
                {
                    Status: "Draft",
                    LatestStatus: "Returned"
                }
            );
/*
            // 3. Notify Requestor
            SY2425_Rejected_Notify.Run(
                SelectedPR.PR_No,
                Office365Users.MyProfileV2().displayName,
                currentApprovalLog.Stage,
                currentApprovalLog.Requestor
            );
*/
            
            // 4. Update AppendLog if exists (optional logic)
         /*   Patch(
                'SY2425-PR-AppendLog',
                LookUp(
                    'SY2425-PR-AppendLog',
                    AppendEmail = Office365Users.MyProfileV2().mail &&
                    PR_No = SelectedPR.PR_No
                ),
                {
                    Status: "Rejected by " & Office365Users.MyProfileV2().displayName
                }
            );*/
            /*

            // 5. Navigate
            Navigate(PR_OnlineForm_YourPR)
        )
    )
)
*/
UpdateContext({ showModal: true });
