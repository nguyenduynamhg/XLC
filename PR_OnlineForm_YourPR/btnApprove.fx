// Bật vòng xoay tải dữ liệu (Spinner) để báo hiệu hệ thống đang xử lý và chặn bấm liên tục
Set(varSpinner, true);

// Thiết lập một biến context để đánh dấu ứng dụng đang trong trạng thái xử lý phê duyệt
UpdateContext({ isApproving: true });

// TÍNH TOÁN TIỀN TỆ: Lấy tổng tiền của đơn đang chọn nhân với Tỷ giá tra cứu từ bảng 'ExchangeRate' để ra tiền MYR
Set(
    calTotalAmoutMYR, 
    Gallery1.Selected.TotalAmount * LookUp(
            'SY2425-ExchangeRate', 
            CurrencyFormat = Gallery1.Selected.Currency
        ).ExchangeRate
);

// Nếu trường tổng tiền quy đổi (TotalAmount_MYR) trên SharePoint đang trống hoặc bằng 0, cập nhật ngay giá trị vừa tính ở trên vào đơn hàng
If(
    IsBlank(Gallery1.Selected.TotalAmount_MYR) || Value(Gallery1.Selected.TotalAmount_MYR) = 0,
    Patch(
        'SY2425-PR-GeneralInfo',
        LookUp('SY2425-PR-GeneralInfo', PR_No = Gallery1.Selected.PR_No),
        {
            TotalAmount_MYR: calTotalAmoutMYR
        }
    )
);

// -----------------------------
// 0) XÁC ĐỊNH LOẠI ĐỊNH TUYẾN (Nếu RouteType là RealKids thì gắn biến là RealKids, ngược lại là "0")
// -----------------------------
If(
    Gallery1.Selected.RouteType = "RealKids",
    Set(PRRouteType, "RealKids"),
    Set(PRRouteType, "0")
);

// 1. LẤY NHẬT KÝ DUYỆT HIỆN TẠI ĐANG CHỜ CỦA NGƯỜI ĐANG ĐĂNG NHẬP
Set(
    latestPendingRecord,
    First(
        SortByColumns(
            Filter(
                'SY2425-Approval_log',
                PR_No   = Gallery1.Selected.PR_No &&
                field_7 = User().Email &&          // field_7 chứa Email của người duyệt
                Status  = "Pending"                // Trạng thái phải là Đang chờ duyệt
            ),
            "Created",
            SortOrder.Descending                   // Lấy bản ghi mới nhất vừa tạo
        )
    )
);

// Kiểm tra bảo vệ: Nếu hệ thống không tìm thấy lượt duyệt nào đang chờ của bạn đối với đơn này -> Dừng xử lý và báo lỗi
If(
    IsBlank(latestPendingRecord),
    Set(varSpinner, false);
    Notify("No pending approval found for you on this RF.", NotificationType.Error)
);

// 2. CHUYỂN ĐỔI TÊN GIAI ĐOẠN HIỆN TẠI THÀNH SỐ (ĐỂ DỄ SO SÁNH LỚN BÉ)
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

// Xác định thứ tự cấp duyệt DOA (Chỉ áp dụng từ Level 5 đến Level 10, các cấp trước đó trả về Blank)
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

// Chuyển đổi trạng thái hiện tại trên Header của đơn hàng (Status trên tổng quan) thành số tương ứng
Set(
    varRFStage,
    Switch(
        Gallery1.Selected.Status,
        "Reviewer",        1,
        "Reviewer2",       2,
        "BudgetOwner",     3,
        "Level5",          4,
        "Level6",          5,
        "Level7",          6,
        "Level8",          7,
        "Level9",          8,
        "Level10",         9,
        "Final Approved", 10,
        0
    )
);

// 3. XÁC ĐỊNH CÁC CẤP PHÊ DUYỆT THEO MA TRẬN PHÂN QUYỀN (DOA MATRIX) CHO ĐƠN NÀY
Set(varRFSubsidiaryDS, Gallery1.Selected.Item_Subsidiary);
Set(varRFCampusDS,     Gallery1.Selected.Item_Campus);
Set(varRFTotalMYRDS,   Gallery1.Selected.TotalAmount_MYR);

// Lọc ra tất cả các dòng phê duyệt trong Ma trận DOA có Công ty + Cơ sở trùng khớp và Số tiền tối thiểu (Threshold_Min) nhỏ hơn hoặc bằng số tiền của đơn này
ClearCollect(
    colDOAForRF,
    Filter(
        DOA_Matrix_SY2425,
        Subsidiary    = varRFSubsidiaryDS &&
        Campus        = varRFCampusDS &&
        Threshold_Min <= varRFTotalMYRDS
    )
);

// Lấy ra Cấp bậc duyệt cuối cùng cao nhất (Số StageOrder lớn nhất) cần đạt cho đơn này dựa trên số tiền đơn hàng
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

// 4. TIẾN HÀNH PHÊ DUYỆT: Cập nhật lượt duyệt hiện tại của bạn thành "Approved" (Đã duyệt)
Patch(
    'SY2425-Approval_log',
    latestPendingRecord,
    {
        ApprovedByWho: User().Email,
        Status: "Approved",
        LogType: latestPendingRecord.StageCheck
    }
);


// 4b) Cơ chế sửa lỗi quy trình: Nếu lượt duyệt bạn vừa bấm thuộc về một giai đoạn cũ/thấp hơn giai đoạn hiện tại của đơn hàng (đơn nhảy cóc hoặc duyệt bù) -> Chỉ cập nhật "Approved" cho bạn rồi DỪNG LUÔN quy trình tại đây, không sinh thêm cấp tiếp theo.
If(
    varCurrentStage < varRFStage,
    // (Bắt đầu dọn dẹp log trùng) Tạo các khóa duy nhất định danh các log đang chờ duyệt bị trùng
    ClearCollect(
        colDuplicateKeys,
        RenameColumns(
            Distinct(
                ForAll(
                    Filter(
                        'SY2425-Approval_log',
                        PR_No = Gallery1.Selected.PR_No &&
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
                        PR_No = Gallery1.Selected.PR_No &&
                        Status = "Pending" &&
                        PR_No & "|" & 'Approved By' & "|" & LogType = dupKey
                    ),
                    "Modified",
                    SortOrder.Ascending
                ),
                CountRows(
                    Filter(
                        'SY2425-Approval_log',
                        PR_No = Gallery1.Selected.PR_No &&
                        Status = "Pending" &&
                        PR_No & "|" & 'Approved By' & "|" & LogType = dupKey
                    )
                ) - 1
            )
        )
    );
    // Xóa các dòng log pending thừa thãi khỏi hệ thống
    RemoveIf('SY2425-Approval_log', ID in colToDelete.ID);
    Set(varSpinner, false);
    Notify("Approval completed successfully.", NotificationType.Success);
);

// 5) PHÂN NHÁNH LOGIC: XỬ LÝ CÁC CẤP MATRIX THÔNG THƯỜNG (CẤP <= 3) VS CÁC CẤP ĐẠI DIỆN DOA (CẤP >= 4)
If(
    // NHÁNH A: CÁC GIAI ĐOẠN ĐẦU THEO MA TRẬN CƠ BẢN (Reviewer, Reviewer2, BudgetOwner)
    varCurrentStage <= 3,

    // A1) NẾU NGƯỜI VỪA DUYỆT XONG LÀ BUDGET OWNER (Cấp 3)
    If(
        latestPendingRecord.StageCheck = "BudgetOwner",

        // Kiểm tra xem đơn hàng này có số tiền lớn đụng tới các cấp phê duyệt tài chính DOA (Cấp 5-10) hay không
        If(
            !IsEmpty(colDOAForRF),
            // TRƯỜNG HỢP CÓ DOA: Tìm cấp duyệt DOA đầu tiên (Cấp nhỏ nhất nhưng phải >= Cấp 5)
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
                        // Cập nhật trạng thái Header của đơn sang tên Cấp DOA đầu tiên đó
                        Patch(
                            'SY2425-PR-GeneralInfo',
                            LookUp('SY2425-PR-GeneralInfo', PR_No = Gallery1.Selected.PR_No),
                            { Status: _firstStageName, LatestStatus: latestPendingRecord.StageCheck }
                        );
                        // Tạo một lượt duyệt Chờ duyệt (Pending) mới cho Người phê duyệt thuộc cấp DOA đó
                        Patch(
                            'SY2425-Approval_log',
                            Defaults('SY2425-Approval_log'),
                            {
                                PR_No: Gallery1.Selected.PR_No,
                                Dept: Gallery1.Selected.Department,
                                Campus: varRFCampus,
                                Item_Subsidiary: varRFSubsidiary,
                                Item_Campus: varRFCampus,
                                Item_Dept: Gallery1.Selected.Item_Dept,
                                Item_Curriculum: Gallery1.Selected.Item_Curriculum,
                                Requestor: Gallery1.Selected.Requestor,
                                'Requestor Name': Gallery1.Selected.RequestorName,
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
            // TRƯỜNG HỢP KHÔNG CÓ DOA: BudgetOwner là cấp duyệt cuối cùng -> Đơn chính thức được phê duyệt hoàn toàn
            Patch(
                'SY2425-PR-GeneralInfo',
                LookUp('SY2425-PR-GeneralInfo', PR_No = Gallery1.Selected.PR_No),
                { Status: "Final Approved", LatestStatus: "Final Approved", FinalApprovedDate: Now() }
            );
            Patch('SY2425-Approval_log', latestPendingRecord, { Status: "Final Approved" })
        ),

        // A2) NẾU NGƯỜI DUYỆT LÀ REVIEWER HOẶC REVIEWER2 -> CHUYỂN SANG CẤP MA TRẬN TIẾP THEO (TĂNG LÊN 1 CẤP)
        Set(varNextStage, varCurrentStage + 1);

        // Cập nhật trạng thái đơn hàng trên Header sang cấp tiếp theo (Reviewer2 hoặc BudgetOwner)
        Patch(
            'SY2425-PR-GeneralInfo',
            LookUp('SY2425-PR-GeneralInfo', PR_No = Gallery1.Selected.PR_No),
            {
                Status: Switch(varNextStage, 2, "Reviewer2", 3, "BudgetOwner"),
                LatestStatus: latestPendingRecord.StageCheck
            }
        );

        // XÂY DỰNG DANH SÁCH EMAIL NHỮNG NGƯỜI DUYỆT Ở CẤP TIẾP THEO
        Set(
            varNextApproverList,
            Switch(
                varNextStage,

                // Nếu cấp tiếp theo là Reviewer2: Phân tách danh sách email dạng mảng JSON trong bảng cấu hình
                2,
                    ForAll(
                        ParseJSON(
                            Substitute(
                                Substitute(
                                    LookUp(
                                        ApprovalMatrix_SY2425,
                                        Subsidiary = Gallery1.Selected.Item_Subsidiary &&
                                        Dept       = Gallery1.Selected.Item_Dept &&
                                        Campus     = Gallery1.Selected.Item_Campus &&
                                        Curriculumn_YearGroup = Gallery1.Selected.Item_Curriculum
                                    ).Reviewer2,
                                    Char(10),
                                    ""
                                ),
                                Char(13),
                                ""
                            )
                        ) As Parsed,
                        { Email: Text(Parsed) }
                    ),

                // Nếu cấp tiếp theo là BudgetOwner: Có quy tắc tính toán phức tạp riêng cho nhóm trường RealKids
                3,
                    With(
                    {
                        // BƯỚC 1: Tìm dòng cấu hình ma trận phù hợp (chỉ LookUp 1 lần để tối ưu tốc độ)
                        _MatrixRecord: LookUp(
                            ApprovalMatrix_SY2425,
                            Subsidiary = Gallery1.Selected.Item_Subsidiary &&
                            Dept = Gallery1.Selected.Item_Dept &&
                            Campus = Gallery1.Selected.Item_Campus &&
                            Curriculumn_YearGroup = Gallery1.Selected.Item_Curriculum
                        )
                    },
                    // BƯỚC 2: Tính toán logic rẽ nhánh lấy Email phù hợp
                    With(
                        {
                            _FinalEmail: 
                            If(
                                PRRouteType = "RealKids",
                                // Nếu thuộc RealKids:
                                If(
                                    Gallery1.Selected.Item_Dept = "Operations : Facility",
                                    _MatrixRecord.'Budget Owner', // Nếu là phòng Facility thì dùng Budget Owner gốc
                                    If(
                                        Value(Gallery1.Selected.TotalAmount_MYR) <= 2500,
                                        _MatrixRecord.RKManager,  // Dưới hoặc bằng 2500 RM dùng RKManager
                                        _MatrixRecord.RKManager2   // Trên 2500 RM dùng RKManager2
                                    )
                                ),
                                // Nếu là trường học bình thường (Non-RealKids): Dùng Budget Owner mặc định
                                _MatrixRecord.'Budget Owner'
                            )
                        },
                        // BƯỚC 3: Đóng gói email kết quả vào dạng một Bảng dữ liệu và làm sạch ký tự lạ
                        Table(
                            {
                                Email: 
                                    Text(
                                        Substitute(
                                            Substitute(
                                                _FinalEmail, 
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

        // Tạo Nhật ký chờ duyệt (Pending Log) mới cho toàn bộ những người thuộc danh sách duyệt tiếp theo vừa tìm được
        ForAll(
            varNextApproverList As NextAppr,
            Patch(
                'SY2425-Approval_log',
                Defaults('SY2425-Approval_log'),
                {
                    PR_No: Gallery1.Selected.PR_No,
                    Dept: Gallery1.Selected.Department,
                    Campus: Gallery1.Selected.Campus,
                    Item_Subsidiary: Gallery1.Selected.Item_Subsidiary,
                    Item_Campus: Gallery1.Selected.Item_Campus,
                    Item_Dept: Gallery1.Selected.Item_Dept,
                    Item_Curriculum: Gallery1.Selected.Item_Curriculum,
                    Requestor: Gallery1.Selected.Requestor,
                    'Requestor Name': Gallery1.Selected.RequestorName,
                    'Approved By': NextAppr.Email,
                    'Approver Name': IfError(Office365Users.UserProfileV2(NextAppr.Email).displayName, "Unknown"),
                    Stage: Switch(varNextStage, 2, "Reviewer2", 3, "BudgetOwner"),
                    StageCheck: Switch(varNextStage, 2, "Reviewer2", 3, "BudgetOwner"),
                    Status: "Pending",
                    LogType: Switch(varNextStage, 2, "Reviewer2", 3, "BudgetOwner")
                }
            )
        );
        // (Ghi chú: Đoạn mã chạy luồng Flow gửi email tự động bên dưới hiện tại đang khóa bằng / * * /)
    ),

    // NHÁNH B: XỬ LÝ CÁC CẤP PHÊ DUYỆT TÀI CHÍNH LỚN DOA (CẤP 5 ĐẾN CẤP 10)
    With(
        { _finalOrder: varDOAFinalStageOrder, _currentOrder: varCurrentDOAOrder },
        If(
            // Nếu cấp hiện tại của bạn đã là CẤP CAO NHẤT mà số tiền đơn này yêu cầu duyệt -> Đơn chính thức được Duyệt Toàn Bộ
            !IsBlank(_finalOrder) && _currentOrder = _finalOrder,
            Patch(
                'SY2425-PR-GeneralInfo',
                LookUp('SY2425-PR-GeneralInfo', PR_No = Gallery1.Selected.PR_No),
                { Status: "Final Approved", LatestStatus: "Final Approved", FinalApprovedDate: Now() }
            );
            Patch('SY2425-Approval_log', latestPendingRecord, { Status: "Final Approved" }),
            
            // Ngược lại nếu vẫn còn cấp DOA cao hơn cần duyệt tiếp -> Đi tìm cấp DOA liền kề phía sau
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
                    // Nếu tìm được cấp DOA tiếp theo
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
                        // Cập nhật Header của đơn sang tên Level DOA mới
                        Patch(
                            'SY2425-PR-GeneralInfo',
                            LookUp('SY2425-PR-GeneralInfo', PR_No = Gallery1.Selected.PR_No),
                            { Status: _nextStageName, LatestStatus: latestPendingRecord.StageCheck }
                        );
                        // Tạo một log Chờ duyệt (Pending) mới chuyển tiếp tới cho Người duyệt cấp cao hơn đó
                        Patch(
                            'SY2425-Approval_log',
                            Defaults('SY2425-Approval_log'),
                            {
                                PR_No: Gallery1.Selected.PR_No,
                                Dept: Gallery1.Selected.Department,
                                Campus: varRFCampus,
                                Item_Subsidiary: varRFSubsidiary,
                                Item_Campus: varRFCampus,
                                Item_Dept: Gallery1.Selected.Item_Dept,
                                Item_Curriculum: Gallery1.Selected.Item_Curriculum,
                                Requestor: Gallery1.Selected.Requestor,
                                'Requestor Name': Gallery1.Selected.RequestorName,
                                'Approved By': _nextDOARec.ApproverEmail,
                                'Approver Name': _nextDOARec.ApproverName,
                                Stage: _nextStageName,
                                StageCheck: _nextStageName,
                                Status: "Pending",
                                LogType: _nextDOARec.StageName
                            }
                        );
                    ),
                    // Nếu rà soát lỗi mà không có cấp nào lớn hơn nữa -> Chốt Duyệt Toàn Bộ đơn
                    Patch(
                        'SY2425-PR-GeneralInfo',
                        LookUp('SY2425-PR-GeneralInfo', PR_No = Gallery1.Selected.PR_No),
                        { Status: "Final Approved", LatestStatus: "Final Approved", FinalApprovedDate: Now() }
                    );
                    Patch('SY2425-Approval_log', latestPendingRecord, { Status: "Final Approved" })
                )
            )
        )
    )
);

// 6) CƠ CHẾ DỌN DẸP SAU CÙNG: QUÉT VÀ XÓA BỎ CÁC LOG CHỜ DUYỆT (PENDING LOG) BỊ TRÙNG LẶP ĐỂ TRÁNH RÁC DỮ LIỆU
ClearCollect(
    colDuplicateKeys,
    RenameColumns(
        Distinct(
            Filter('SY2425-Approval_log', PR_No = Gallery1.Selected.PR_No && Status = "Pending"),
            PR_No & "|" & 'Approved By' & "|" & LogType
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
                    PR_No = Gallery1.Selected.PR_No &&
                    Status = "Pending" &&
                    PR_No & "|" & 'Approved By' & "|" & LogType = dupKey
                ),
                "Modified",
                SortOrder.Ascending
            ),
            CountRows(
                Filter(
                    'SY2425-Approval_log',
                    PR_No = Gallery1.Selected.PR_No &&
                    Status = "Pending" &&
                    PR_No & "|" & 'Approved By' & "|" & LogType = dupKey
                )
            ) - 1
        )
    )
);

// Tiến hành xóa các dòng log pending bị lặp dựa trên danh sách ID vừa gom được
RemoveIf('SY2425-Approval_log', ID in colToDelete.ID);

// 7) HOÀN TẤT GIAO DIỆN UI
Set(varSpinner, false); // Tắt vòng xoay tải dữ liệu
Notify("Approval completed successfully.", NotificationType.Success); // Bắn thông báo phê duyệt thành công màu xanh lá