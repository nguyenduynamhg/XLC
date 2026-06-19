If(
    IsBlank(
        LookUp(
            'SY2425-ProcurementMembers',
            ProcurementMember = Office365Users.MyProfileV2().mail
        ).ProcurementMember
    ),
    // Start to check the latest status. 
        Switch(
            varIsDeptAdmin, 
            true,

    
        SortByColumns(
        Filter(
            AddColumns(
                Search(
                    Filter(
                        'SY2425-PR-GeneralInfo',
                        
                        varIsDeptAdmin &&
                               Department in varAdminDepartments
                        
                      //  ||  User().Email = "svc-siriusnex@xwa.edu.sg"
                    ),
                    txtSearchPR.Value,
                    Title,
                    PR_No,
                    RejectComment, 
                    Requestor
                ),
                SearchMatch, true
            ),
               
                   

            (IsBlank(dateFrom.SelectedDate) || Created >= dateFrom.SelectedDate) &&
            (IsBlank(dateTo.SelectedDate) || Created <= dateTo.SelectedDate) &&
            (IsBlank(drpStatus.Selected.Value) || drpStatus.Selected.Value = "All Status" || Status = drpStatus.Selected.Value) &&
            (IsBlank(drpLatestStatus.Selected.Value) || drpLatestStatus.Selected.Value = "All Stage" || LatestStatus = drpLatestStatus.Selected.Value) &&
            (IsBlank(cmbCampSearch.Selected.Value) || cmbCampSearch.Selected.Value = "All Campus" || Item_Campus = cmbCampSearch.Selected.Value) && 
            (IsBlank(cmbDeptSearch.Selected.Value) || cmbDeptSearch.Selected.Value ="All Department" || Item_Dept = cmbDeptSearch.Selected.Value) &&
            (IsBlank(cmbSubSearch.Selected.Value) || cmbSubSearch.Selected.Value ="All Subsidiary" || Item_Subsidiary = cmbSubSearch.Selected.Value) &&
            (IsBlank(cmbCurriculmSearch.Selected.Value) || cmbCurriculmSearch.Selected.Value ="All Curriculum" || Item_Curriculum = cmbCurriculmSearch.Selected.Value) 
            ),
        "Created",
        SortOrder.Descending
        )
     
        
      
        ,
       
       SortByColumns(
        Filter(
            AddColumns(
                Search(
                    Filter(
                        'SY2425-PR-GeneralInfo',
                        PR_No in FilteredPRNos || 
                        PR_No in FilteredPRNos_PRList 
                        ||  User().Email = "powerautomate.xclmy@srikdu.onmicrosoft.com"
                    ),
                    txtSearchPR.Value,
                    Title,
                    PR_No,
                    RejectComment, 
                    Requestor
                ),
                SearchMatch, true
            ),
               
                   

            (IsBlank(dateFrom.SelectedDate) || Created >= dateFrom.SelectedDate) &&
            (IsBlank(dateTo.SelectedDate) || Created <= dateTo.SelectedDate) &&
            (IsBlank(drpStatus.Selected.Value) || drpStatus.Selected.Value = "All Status" || Status = drpStatus.Selected.Value) &&
            (IsBlank(drpLatestStatus.Selected.Value) || drpLatestStatus.Selected.Value = "All Stage" || LatestStatus = drpLatestStatus.Selected.Value) &&
            
            (IsBlank(cmbCampSearch.Selected.Value) || cmbCampSearch.Selected.Value = "All Campus" || Item_Campus = cmbCampSearch.Selected.Value) && 
            (IsBlank(cmbDeptSearch.Selected.Value) || cmbDeptSearch.Selected.Value ="All Department" || Item_Dept = cmbDeptSearch.Selected.Value) &&
            (IsBlank(cmbSubSearch.Selected.Value) || cmbSubSearch.Selected.Value ="All Subsidiary" || Item_Subsidiary = cmbSubSearch.Selected.Value) &&
            (IsBlank(cmbCurriculmSearch.Selected.Value) || cmbCurriculmSearch.Selected.Value ="All Curriculum" || Item_Curriculum = cmbCurriculmSearch.Selected.Value) 
        ),
        "Created",
        SortOrder.Descending
            )
        )
    //End of switch to check PR LatestStatus.    
    
,
   
    If(
    SeachToggle.Checked = false,

    // No filter by Requestor
    SortByColumns(
        Filter(
            AddColumns(
                Search(
                    'SY2425-PR-GeneralInfo',
                    txtSearchPR.Value,
                    Title,
                    PR_No,
                    RejectComment, 
                    Requestor
                ),
                SearchMatched, true
            )
             
            ,
            
                            
               
                          
            (IsBlank(dateFrom.SelectedDate) || Created >= dateFrom.SelectedDate) &&
            (IsBlank(dateTo.SelectedDate) || Created <= dateTo.SelectedDate) &&
            (IsBlank(drpStatus.Selected.Value) || drpStatus.Selected.Value = "All Status" || Status = drpStatus.Selected.Value) &&
            (IsBlank(drpLatestStatus.Selected.Value) || drpLatestStatus.Selected.Value = "All Stage" || LatestStatus = drpLatestStatus.Selected.Value) &&
            (IsBlank(cmbCampSearch.Selected.Value) || cmbCampSearch.Selected.Value = "All Campus" || Item_Campus = cmbCampSearch.Selected.Value) && 
            (IsBlank(cmbDeptSearch.Selected.Value) || cmbDeptSearch.Selected.Value ="All Department" || Item_Dept = cmbDeptSearch.Selected.Value) &&
            (IsBlank(cmbSubSearch.Selected.Value) || cmbSubSearch.Selected.Value ="All Subsidiary" || Item_Subsidiary = cmbSubSearch.Selected.Value) &&
            (IsBlank(cmbCurriculmSearch.Selected.Value) || cmbCurriculmSearch.Selected.Value ="All Curriculum" || Item_Curriculum = cmbCurriculmSearch.Selected.Value) 
        ),
        "Created",
        SortOrder.Descending
    ),

    // Filter by Requestor or admin of department - Support log 164
    SortByColumns(
        Filter(
            AddColumns(
                Search(
                    'SY2425-PR-GeneralInfo',
                    txtSearchPR.Value,
                   Title,
                    PR_No,
                    RejectComment, 
                    Requestor
                ),
                SearchMatched, true
            ),
            
                
            Requestor = User().Email || 
                    (
                        varIsDeptAdmin &&
                               Department in varAdminDepartments
                    )
             &&
            (IsBlank(dateFrom.SelectedDate) || Created >= dateFrom.SelectedDate) &&
            (IsBlank(dateTo.SelectedDate) || Created <= dateTo.SelectedDate) &&
            (IsBlank(drpStatus.Selected.Value) || drpStatus.Selected.Value = "All Status" || Status = drpStatus.Selected.Value) &&
            (IsBlank(drpLatestStatus.Selected.Value) || drpLatestStatus.Selected.Value = "All Stage" || LatestStatus = drpLatestStatus.Selected.Value) &&
            (IsBlank(cmbCampSearch.Selected.Value) || cmbCampSearch.Selected.Value = "All Campus" || Item_Campus = cmbCampSearch.Selected.Value) && 
            (IsBlank(cmbDeptSearch.Selected.Value) || cmbDeptSearch.Selected.Value ="All Department" || Item_Dept = cmbDeptSearch.Selected.Value) &&
            (IsBlank(cmbSubSearch.Selected.Value) || cmbSubSearch.Selected.Value ="All Subsidiary" || Item_Subsidiary = cmbSubSearch.Selected.Value) &&
            (IsBlank(cmbCurriculmSearch.Selected.Value) || cmbCurriculmSearch.Selected.Value ="All Curriculum" || Item_Curriculum = cmbCurriculmSearch.Selected.Value) 
        ),
        "Created",
        SortOrder.Descending
    )
)


)