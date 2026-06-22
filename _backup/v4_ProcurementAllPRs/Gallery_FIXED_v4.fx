// ===== Gallery Items Property =====
// v4: Procurement Members luôn dùng colUserPRs (đã load ALL PRs trong OnVisible)
//     → Search Title, PR_No, Requestor, RejectComment đều hoạt động, không bị delegation limit
//
// Logic phân nhánh:
// 1. Non-Procurement + DeptAdmin       → colUserPRs (PRs department + cá nhân + approver)
// 2. Non-Procurement + Service Account → SP trực tiếp (delegable, chỉ StartsWith PR_No)
// 3. Non-Procurement + Regular User    → colUserPRs (PRs cá nhân + approver)
// 4. Procurement Members               → colUserPRs (ALL PRs, load trong OnVisible)

If(
    !varIsProcurement,
    // ==================== NON-PROCUREMENT ====================
    Switch(
        varIsDeptAdmin,
        true,
        // Dept Admin: dùng colUserPRs (đã bao gồm PRs department + PRs cá nhân)
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
        // Regular User
        If(
            User().Email = "powerautomate.xclmy@srikdu.onmicrosoft.com",
            // Service account: SP trực tiếp (delegable, chỉ StartsWith PR_No)
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
            // Regular user: colUserPRs (local, no delegation)
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
    // ==================== PROCUREMENT MEMBERS ====================
    // colUserPRs đã chứa ALL PRs (load bằng Filter(SP, ID > 0) trong OnVisible)
    // → Search trên local collection: không bị delegation limit
    // → Không cần Toggle, không cần SP direct query
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
