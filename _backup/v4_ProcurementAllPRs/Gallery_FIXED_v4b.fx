// ===== Gallery Items Property =====
// v4b: Procurement Members — Hybrid approach
//   - Không có search text → SP trực tiếp (delegable, ALL PRs, không bị row limit)
//   - Có search text → colUserPRs (local, search Title/PR_No/Requestor/RejectComment)
//
// Non-Procurement: giữ nguyên logic v4

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
    // Hybrid approach:
    //   Không search → SP trực tiếp (delegable, ALL PRs, không bị row limit)
    //   Có search → colUserPRs (local, 2000 PRs mới nhất, search Title/PR_No/Requestor/RejectComment)
    //
    // YÊU CẦU: App Settings → Data row limit = 2000
    //           OnVisible: ClearCollect với SortByColumns(ID, Descending) → load 2000 MỚI NHẤT
    If(
        IsBlank(txtSearchPR.Value),
        // Không có search text → SP trực tiếp (delegable, ALL PRs, không bị row limit)
        SortByColumns(
            Filter(
                'SY2425-PR-GeneralInfo',
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
        // Có search text → colUserPRs (local, chứa 2000 PRs mới nhất từ OnVisible)
        // Search "contains" trên PR_No, Title, Requestor, RejectComment — không delegation limit
        SortByColumns(
            Filter(
                colUserPRs,
                (txtSearchPR.Value in PR_No || txtSearchPR.Value in Title || txtSearchPR.Value in Requestor || txtSearchPR.Value in RejectComment) &&
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
