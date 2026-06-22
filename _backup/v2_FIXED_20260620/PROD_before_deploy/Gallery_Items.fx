// ===== PROD BACKUP - Gallery Items =====
// Copied from PROD app BEFORE applying fix
// Date: ___/06/2026
// Purpose: Immediate revert if fix causes issues on PROD
//
// PASTE CODE TỪ PROD APP VÀO ĐÂY:
// Power Apps > XMCO - SiriusNex (PROD) > YourPR Screen > Gallery > Items property > Select All > Paste

If(
    IsBlank(
        LookUp(
            'SY2425-ProcurementMembers',
            ProcurementMember = Office365Users.MyProfileV2().mail
        ).ProcurementMember
    ),
    Switch(
        varIsDeptAdmin,
        true,
        SortByColumns(
            Filter(
                'SY2425-PR-GeneralInfo',
                varIsDeptAdmin &&
                    Department in varAdminDepartments &&
                (IsBlank(txtSearchPR.Value) || StartsWith(PR_No, txtSearchPR.Value)) &&
                (IsBlank(dateFrom.SelectedDate) || Created >= dateFrom.SelectedDate) &&
                (IsBlank(dateTo.SelectedDate) || Created <= dateTo.SelectedDate) &&
                (IsBlank(drpStatus.Selected.Value) || drpStatus.Selected.Value = "All Status" || Status = drpStatus.Selected.Value) &&
                (IsBlank(drpLatestStatus.Selected.Value) || drpLatestStatus.Selected.Value = "All Stage" || LatestStatus = drpLatestStatus.Selected.Value) &&
                (IsBlank(cmbCampSearch.Selected.Value) || cmbCampSearch.Selected.Value = "All Campus" || Item_Campus = cmbCampSearch.Selected.Value) &&
                (IsBlank(cmbDeptSearch.Selected.Value) || cmbDeptSearch.Selected.Value = "All Department" || Item_Dept = cmbDeptSearch.Selected.Value) &&
                (IsBlank(cmbSubSearch.Selected.Value) || cmbSubSearch.Selected.Value = "All Subsidiary" || Item_Subsidiary = cmbSubSearch.Selected.Value) &&
                (IsBlank(cmbCurriculmSearch.Selected.Value) || cmbCurriculmSearch.Selected.Value = "All Curriculum" || Item_Curriculum = cmbCurriculmSearch.Selected.Value)
            ),
            "Created",
            SortOrder.Descending
        ),
        SortByColumns(
            Filter(
                'SY2425-PR-GeneralInfo',
                (PR_No in FilteredPRNos || PR_No in FilteredPRNos_PRList || User().Email = "powerautomate.xclmy@srikdu.onmicrosoft.com") &&
                (IsBlank(txtSearchPR.Value) || StartsWith(PR_No, txtSearchPR.Value)) &&
                (IsBlank(dateFrom.SelectedDate) || Created >= dateFrom.SelectedDate) &&
                (IsBlank(dateTo.SelectedDate) || Created <= dateTo.SelectedDate) &&
                (IsBlank(drpStatus.Selected.Value) || drpStatus.Selected.Value = "All Status" || Status = drpStatus.Selected.Value) &&
                (IsBlank(drpLatestStatus.Selected.Value) || drpLatestStatus.Selected.Value = "All Stage" || LatestStatus = drpLatestStatus.Selected.Value) &&
                (IsBlank(cmbCampSearch.Selected.Value) || cmbCampSearch.Selected.Value = "All Campus" || Item_Campus = cmbCampSearch.Selected.Value) &&
                (IsBlank(cmbDeptSearch.Selected.Value) || cmbDeptSearch.Selected.Value = "All Department" || Item_Dept = cmbDeptSearch.Selected.Value) &&
                (IsBlank(cmbSubSearch.Selected.Value) || cmbSubSearch.Selected.Value = "All Subsidiary" || Item_Subsidiary = cmbSubSearch.Selected.Value) &&
                (IsBlank(cmbCurriculmSearch.Selected.Value) || cmbCurriculmSearch.Selected.Value = "All Curriculum" || Item_Curriculum = cmbCurriculmSearch.Selected.Value)
            ),
            "Created",
            SortOrder.Descending
        )
    ),
    If(
        SeachToggle.Checked = false,
        SortByColumns(
            Filter(
                'SY2425-PR-GeneralInfo',
                (IsBlank(txtSearchPR.Value) || StartsWith(PR_No, txtSearchPR.Value)) &&
                (IsBlank(dateFrom.SelectedDate) || Created >= dateFrom.SelectedDate) &&
                (IsBlank(dateTo.SelectedDate) || Created <= dateTo.SelectedDate) &&
                (IsBlank(drpStatus.Selected.Value) || drpStatus.Selected.Value = "All Status" || Status = drpStatus.Selected.Value) &&
                (IsBlank(drpLatestStatus.Selected.Value) || drpLatestStatus.Selected.Value = "All Stage" || LatestStatus = drpLatestStatus.Selected.Value) &&
                (IsBlank(cmbCampSearch.Selected.Value) || cmbCampSearch.Selected.Value = "All Campus" || Item_Campus = cmbCampSearch.Selected.Value) &&
                (IsBlank(cmbDeptSearch.Selected.Value) || cmbDeptSearch.Selected.Value = "All Department" || Item_Dept = cmbDeptSearch.Selected.Value) &&
                (IsBlank(cmbSubSearch.Selected.Value) || cmbSubSearch.Selected.Value = "All Subsidiary" || Item_Subsidiary = cmbSubSearch.Selected.Value) &&
                (IsBlank(cmbCurriculmSearch.Selected.Value) || cmbCurriculmSearch.Selected.Value = "All Curriculum" || Item_Curriculum = cmbCurriculmSearch.Selected.Value)
            ),
            "Created",
            SortOrder.Descending
        ),
        SortByColumns(
            Filter(
                'SY2425-PR-GeneralInfo',
                (Requestor = User().Email || (varIsDeptAdmin && Department in varAdminDepartments)) &&
                (IsBlank(txtSearchPR.Value) || StartsWith(PR_No, txtSearchPR.Value)) &&
                (IsBlank(dateFrom.SelectedDate) || Created >= dateFrom.SelectedDate) &&
                (IsBlank(dateTo.SelectedDate) || Created <= dateTo.SelectedDate) &&
                (IsBlank(drpStatus.Selected.Value) || drpStatus.Selected.Value = "All Status" || Status = drpStatus.Selected.Value) &&
                (IsBlank(drpLatestStatus.Selected.Value) || drpLatestStatus.Selected.Value = "All Stage" || LatestStatus = drpLatestStatus.Selected.Value) &&
                (IsBlank(cmbCampSearch.Selected.Value) || cmbCampSearch.Selected.Value = "All Campus" || Item_Campus = cmbCampSearch.Selected.Value) &&
                (IsBlank(cmbDeptSearch.Selected.Value) || cmbDeptSearch.Selected.Value = "All Department" || Item_Dept = cmbDeptSearch.Selected.Value) &&
                (IsBlank(cmbSubSearch.Selected.Value) || cmbSubSearch.Selected.Value = "All Subsidiary" || Item_Subsidiary = cmbSubSearch.Selected.Value) &&
                (IsBlank(cmbCurriculmSearch.Selected.Value) || cmbCurriculmSearch.Selected.Value = "All Curriculum" || Item_Curriculum = cmbCurriculmSearch.Selected.Value)
            ),
            "Created",
            SortOrder.Descending
        )
    )
)