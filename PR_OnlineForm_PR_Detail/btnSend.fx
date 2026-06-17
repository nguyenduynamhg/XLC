// Submit comment to SharePoint list
Patch(
    SY2425_PR_Comments,
    Defaults(SY2425_PR_Comments),
    {
        PR_No: SelectedPR.PR_No,  
        Comments: txtComment.Value,  
        CreatedEmail:Office365Users.MyProfileV2().mail,
        Status: "Posted"  // Or any default status value
    }
);


// Reset the comment input box
Reset(txtComment);

// Optionally, you can refresh the gallery to reflect the new comment
Refresh(SY2425_PR_Comments);

