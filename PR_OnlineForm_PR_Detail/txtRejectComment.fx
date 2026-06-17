/*If(
    
        LookUp(
            'SY2425-PR-GeneralInfo',
            PR_No = SelectedPR.PR_No
        ).RejectComment<>""
    ,
    
     LookUp(
            'SY2425-PR-GeneralInfo',
            PR_No = SelectedPR.PR_No
        ).RejectComment,
        
        "Reason to Reject"
)*/

With(
    {
        // 1. Get the current PR's specific rejection comment
        currentComment: LookUp('SY2425-PR-GeneralInfo', PR_No = SelectedPR.PR_No).RejectComment,
        
        // 2. Get all historical "Returned" comments from the Log
        logComments: Concat(
            Filter(
                'SY2425-Approval_log', 
                PR_No = SelectedPR.PR_No && Returned = 1
            ),
            // Format: "Date: Comment" followed by a new line
            Text(Created, "[$-en-US]dd/mm/yyyy") & " by " & 'Approver Name'  & ": " & RejectComment & Char(10),
            Char(10) // Separator between entries
        )
    },
    // Display Logic
    If(
        !IsBlank(logComments),
        logComments,
        If(!IsBlank(currentComment), currentComment)
    )
)