/*
UpdateContext({isApproving: false});

Set(
    AppendedRecord,
    First(
        SortByColumns(
            Filter(
                'SY2425-PR-AppendLog',
                AppendEmail = Office365Users.MyProfileV2().mail && PR_No = SelectedPR.PR_No
            ),
            "Created",
            SortOrder.Descending
        )
    )
);

If (IsBlank(txtRejectComment.Value), Notify ("Please enter reason to reject", NotificationType.Warning),
    If(
        !IsBlank(AppendedRecord) And AppendedRecord.Status = "Pending",
        Patch('SY2425-PR-AppendLog', LookUp('SY2425-PR-AppendLog',AppendEmail = Office365Users.MyProfileV2().mail && PR_No = SelectedPR.PR_No),
        {
            Status:"Rejected"
        }
        ),

        Patch(
        'SY2425-PR-GeneralInfo',
        LookUp(
            'SY2425-PR-GeneralInfo',
            PR_No = SelectedPR.PR_No
        ),
        {
            Status:"Rejected",
            LatestStatus:"Rejected", 
            RejectComment: txtRejectComment.Value 
        }
    );

    Patch(
        'SY2425-Approval_log',
        LookUp('SY2425-Approval_log',PR_No = SelectedPR.PR_No && Status = "Pending" && 'Approved By'=Office365Users.MyProfileV2().mail),
        {
            Status:"Rejected"
        }
    );
/* To be added later
    SY2425_Rejected_Notify.Run(
        SelectedPR.PR_No,
        Office365Users.MyProfileV2().displayName,
        LookUp('SY2425-Approval_log',PR_No = SelectedPR.PR_No && Status = "Rejected" && 'Approved By'=Office365Users.MyProfileV2().mail).Stage,
        LookUp('SY2425-Approval_log',PR_No = SelectedPR.PR_No && Status = "Rejected" && 'Approved By'=Office365Users.MyProfileV2().mail).Requestor 
    );
*/
/*
    Patch('SY2425-PR-AppendLog', LookUp('SY2425-PR-AppendLog',AppendEmail = Office365Users.MyProfileV2().mail && PR_No = SelectedPR.PR_No),
        {
            Status:"Rejected by " & Office365Users.MyProfileV2().displayName
        }
        );

    );

    // Submit Reject Reason to PR Comment 
Patch(
    SY2425_PR_Comments,
    Defaults(SY2425_PR_Comments),
    {
        PR_No: SelectedPR.PR_No,  
        Comments: txtRejectComment.Value,  
        CreatedEmail:Office365Users.MyProfileV2().mail,
        Status: "Rejected"  // Or any default status value
    }
);


// Reset the comment input box
Reset(txtComment);


    Navigate(PR_OnlineForm_YourPR);
)
*/
UpdateContext({ showModalReject: true });