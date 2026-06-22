// ===== DEV BACKUP - Gallery Items =====
// Copied from DEV app BEFORE deploying to PROD
// Date: ___/06/2026
// Purpose: Revert point if PROD deploy fails
//
// PASTE CODE TỪ DEV APP VÀO ĐÂY:
// Power Apps > SiriusNex (DEV) > YourPR Screen > Gallery > Items property > Select All > Paste

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
        // Dept Admin: dùng colUserPRs (đã bao gồm PRs department + PRs cá nhân)
        // Tránh dùng "Department in varAdminDepartments" trực tiếp trên SP vì non-delegable
        SortByColumns(
            Filter(
                colUserPRs,
                (IsBlank(txtSearchPR.Value) || txtSearchPR.Value in PR_No || txtSearchPR.Value in Title || txtSearchPR.Value in Requestor || txtSearchPR.Value in RejectComment) &&
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
        // Regular User: service account sees all from SP, others use pre-built local collection
        If(
            User().Email = "powerautomate.xclmy@srikdu.onmicrosoft.com",
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
            // Regular user: filter from colUserPRs (local collection, no delegation issues)
            SortByColumns(
                Filter(
                    colUserPRs,
                    (IsBlank(txtSearchPR.Value) || txtSearchPR.Value in PR_No || txtSearchPR.Value in Title || txtSearchPR.Value in Requestor || txtSearchPR.Value in RejectComment) &&
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
        // Toggle ON: dùng colUserPRs (local, no delegation limit)
        SortByColumns(
            Filter(
                colUserPRs,
                (IsBlank(txtSearchPR.Value) || txtSearchPR.Value in PR_No || txtSearchPR.Value in Title || txtSearchPR.Value in Requestor || txtSearchPR.Value in RejectComment) &&
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