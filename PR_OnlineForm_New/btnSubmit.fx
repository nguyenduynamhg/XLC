// Bật vòng xoay tải dữ liệu (Spinner) để báo hiệu hệ thống đang xử lý và chặn người dùng bấm nút liên tiếp
Set(varSpinner, true);

// BẮT ĐẦU BƯỚC 1: KIỂM TRA TÍNH HỢP LỆ CỦA CÁC TRƯỜNG DỮ LIỆU (VALIDATION)
If(
    // KIỂM TRA TRƯỜNG HỢP A: Nếu nút gạt ToggleVendor đang TẮT (Nhà cung cấp mới / một lần)
    ToggleVendor.Checked = false,
        
        // Điều kiện kiểm tra: Các trường thông tin chung và ID của nhà cung cấp một lần không được trống
        If(IsBlank(DataCardValue4.Value) || Len(DataCardValue4.Value) < 20 || IsBlank(DataCardValue15_1.SelectedDate) 
        || IsBlank(DataCardValue13_1.Value) || IsEmpty(DataCardValue17_1.Attachments) || IsBlank(drpCurrrency.Selected.Value)
        || IsBlank(drpPaymentTerm.Selected.Value) || IsBlank(cmbOneTimeVendor.Selected.NSInternalID),
            // Nếu có bất kỳ trường nào vi phạm, đặt biến kiểm tra fields là false (không hợp lệ)
            Set(checkFields, false),
            
            // Nếu thông tin chung đã đầy đủ, tiếp tục kiểm tra lưới danh sách mặt hàng (itemGrid)
            If(IsEmpty(itemGrid.AllItems), 
                Set(checkFields, false), // Nếu lưới không có sản phẩm nào -> Không hợp lệ
                
                // Đếm xem trong lưới có dòng sản phẩm nào bị bỏ sót thông tin bắt buộc không
                Set(
                    CountFalse,
                    CountIf(
                        itemGrid.AllItems,
                        IsBlank(drpCurrrency.Selected) || 
                        IsBlank(txtItemDepartment.Selected.DepartmentName) || 
                        IsBlank(txtQuant_5.Value) || 
                        IsBlank(txtUnitPrice_4.Value) ||
                        IsBlank(txtItemDescription.Value) || 
                        IsBlank(cmbTaxCode.Selected) || 
                        IsBlank(drpCampuNew.Selected)
                    )
                );

                // Dựa vào số dòng bị lỗi (CountFalse) để quyết định dữ liệu hợp lệ hay không
                If(
                    CountFalse > 0,
                    Set(checkFields, false), // Có ít nhất 1 dòng bị thiếu thông tin
                    Set(checkFields, true)   // Tất cả các dòng trong lưới đều đầy đủ thông tin
                )
            )
        ),
    
    // KIỂM TRA TRƯỜNG HỢP B: Nếu nút gạt ToggleVendor đang BẬT (Nhà cung cấp có sẵn trên hệ thống)
    // Quy trình kiểm tra tương tự như trên, chỉ thay cmbOneTimeVendor bằng DataCardValue6
    If(IsBlank(DataCardValue4.Value) || Len(DataCardValue4.Value) < 20 || IsBlank(DataCardValue15_1.SelectedDate) || IsBlank(DataCardValue13_1.Value) || IsEmpty(DataCardValue17_1.Attachments) || IsBlank(drpCurrrency.Selected.Value) || IsBlank(drpPaymentTerm.Selected.Value) || IsBlank(DataCardValue6.Value),
        Set(checkFields, false),
        
        If(IsEmpty(itemGrid.AllItems), 
            Set(checkFields, false),
            
            Set(
                CountFalse,
                CountIf(
                    itemGrid.AllItems,
                    IsBlank(drpCurrrency.Selected) || 
                    IsBlank(txtItemDepartment.Selected.DepartmentName) || 
                    IsBlank(txtQuant_5.Value) || 
                    IsBlank(txtUnitPrice_4.Value) ||
                    IsBlank(txtItemDescription.Value) || 
                    IsBlank(cmbTaxCode.Selected) || 
                    IsBlank(drpCampuNew.Selected)
                )
            );

            If(
                CountFalse > 0,
                Set(checkFields, false),
                Set(checkFields, true)
            )
        )
    )
);

// BẮT ĐẦU BƯỚC 2: KIỂM TRA MA TRẬN PHÊ DUYỆT (APPROVAL MATRIX VALIDATION)
// Hệ thống đối chiếu thông tin của MẶT HÀNG ĐẦU TIÊN trong lưới xem đã cấu hình người duyệt chưa
If(
    IsBlank(
        LookUp(
            ApprovalMatrix_SY2425,
            Subsidiary           = First(itemGrid.AllItems).txtItemSubsidiary.Selected.Name &&
            Dept                 = First(itemGrid.AllItems).txtItemDepartment.Selected.DepartmentName &&
            Campus               = First(itemGrid.AllItems).drpCampuNew.Selected.CampusName &&
            Curriculumn_YearGroup = First(itemGrid.AllItems).cmbCurriculum.Selected.CurriculumName
        )
    ),
    // Nếu không tìm thấy cấu hình phê duyệt phù hợp -> Đặt checkMatrix là false và tắt màn hình tải
    Set(checkMatrix, false); Set(varSpinner, false),
    // Nếu tìm thấy cấu hình hợp lệ -> Đặt checkMatrix là true
    Set(checkMatrix, true)
);

// BẮT ĐẦU BƯỚC 3: XỬ LÝ LƯU TRỮ KHI TẤT CẢ ĐIỀU KIỆN ĐỀU ĐẠT (checkFields & checkMatrix đều đúng)
If(
    checkFields && checkMatrix,

    // 3.1. Tạo định dạng Tháng/Năm hiện tại (Ví dụ: Tháng 06 năm 2026 -> "0626")
    Set(
        currentMonthYear,
        Text(Today(), "[$-en-US]mmyy")
    );
    
    // 3.2. Tìm bản ghi có số thứ tự lớn nhất trong tháng này để làm căn cứ tăng số (Ví dụ: RF0626-0015)
    Set(
        lastPRRecord,
        First(
            SortByColumns(
                Filter(
                    'SY2425-PR-GeneralInfo',
                    MonthYear = currentMonthYear
                ),
                "LastNumber",
                SortOrder.Descending
            )
        )
    );
    
    // 3.3. Tính toán số thứ tự tiếp theo (Tăng lên 1)
    If(
        IsBlank(lastPRRecord),
        Set(nextIncrementingNumber, 1), // Nếu là đơn đầu tiên trong tháng thì bắt đầu từ 1
        Set(nextIncrementingNumber, lastPRRecord.IncrementingNumber + 1) // Ngược lại thì tăng thêm 1
    );
    
    // 3.4. Định dạng số thứ tự thành chuỗi có 4 chữ số (Ví dụ: số 1 thành "0001")
    Set(
        formattedIncrementingNumber,
        Text(nextIncrementingNumber, "0000")
    );
    
    // 3.5. Ráp nối thành Mã Yêu Cầu Mua Hàng (Mã PR) hoàn chỉnh (Ví dụ: "RF0626-0001")
    Set(
        prNumber,
        "RF" & currentMonthYear & "-" & formattedIncrementingNumber
    );
    
    // 3.6. Cơ chế phụ: Đề phòng trùng lặp mã PR vừa sinh, kiểm tra lại trên SharePoint một lần nữa
    Set(
        checking,
        LookUp('SY2425-PR-GeneralInfo', PR_No = prNumber)
    );
    If(
        !IsBlank(checking), // Nếu xui rủi mã PR này đã tồn tại
        Set(nextIncrementingNumber, nextIncrementingNumber + 1); // Tăng tiếp lên 1 đơn vị nữa
        Set(formattedIncrementingNumber, Text(nextIncrementingNumber, "0000"));
        Set(prNumber, "RF" & currentMonthYear & "-" & formattedIncrementingNumber);
    );
    
    // 3.7. Gửi thông tin trên Form nhập liệu (General Info) lên danh sách SharePoint chính
    SubmitForm(GeneralInforForm);
    
    // 3.8. Kiểm tra xem cơ sở này có thuộc hệ thống RealKids không để định tuyến quy trình duyệt
    If(First(itemGrid.AllItems).drpCampuNew.Selected.RealKids = "Yes", 
        Set(PRRouteType, "RealKids"), 
        Set(PRRouteType, "0")
    );
    
    // 3.9. Cập nhật bổ sung các thông tin tính toán phức tạp vào bản ghi vừa Submit xong
    Patch(
        'SY2425-PR-GeneralInfo',
        GeneralInforForm.LastSubmit, // Xác định đúng bản ghi vừa gửi thành công
        {
            PR_No: prNumber,
            MonthYear: currentMonthYear,
            IncrementingNumber: nextIncrementingNumber,
            'Total Amount': Sum(itemGrid.AllItems, txtTotalAmount_4.Value), // Tổng tiền nguyên tệ
            TotalAmount_MYR: Sum(itemGrid.AllItems, txtTotalAmount_MYR.Value), // Tổng tiền quy đổi sang tiền MYR
            PR_Type: drpPRType.Selected.TypeName,
            PRTypeNSID: drpPRType.Selected.Value,
            Status: "Reviewer", // Đặt trạng thái ban đầu là chuyển cho người soát xét
            LatestStatus: "Pending",
            Department: Office365Users.MyProfileV2().department, // Tự động lấy phòng ban của người đăng nhập
            Campus: Office365Users.MyProfileV2().companyName, 
            NSPaymentTermID: drpPaymentTerm.Selected.Value,
            NSVendorFullName: cmbOneTimeVendor.Selected.VendorFullName, 
            NSVendorExternalID: VendorNSInternalID, 
            RequestorName: TextInputCanvas4.Value, 
            Item_Subsidiary_NS_ID: First(itemGrid.AllItems).txtItemSubsidiary.Selected.NS_InternalID, 
            Item_Campus_NS_ID: First(itemGrid.AllItems).drpCampuNew.Selected.NSCampusID, 
            Item_Curriculum_NS_ID: First(itemGrid.AllItems).cmbCurriculum.Selected.CurNSInternalID, 
            Item_Dept_NS_ID: First(itemGrid.AllItems).txtItemDepartment.Selected.NS_InternalID,
            Item_Subsidiary: First(itemGrid.AllItems).txtItemSubsidiary.Selected.Name, 
            Item_Campus: First(itemGrid.AllItems).drpCampuNew.Selected.CampusName, 
            Item_Curriculum: First(itemGrid.AllItems).cmbCurriculum.Selected.CurriculumName, 
            Item_Dept: First(itemGrid.AllItems).txtItemDepartment.Selected.DepartmentName, 
            RouteType: PRRouteType,
            Purpose_Subcode: Coalesce(First(itemGrid.AllItems).cmbPurposeSubcode.Selected.Title, ""),
            Purpose_Subcode_Id: Coalesce(First(itemGrid.AllItems).cmbPurposeSubcode.Selected.'Internal ID', 0)
        }
    );
    
    // 3.10. Vòng lặp ForAll: Lưu chi tiết TỪNG MẶT HÀNG từ lưới nhập liệu vào danh sách phụ 'SY2425-PR_Item'
    ForAll(
        itemGrid.AllItems,
        Patch(
            'SY2425-PR_Item',
            Defaults('SY2425-PR_Item'), // Tạo bản ghi mới hoàn toàn cho từng dòng
            {
                'PR_No (PR_No0)': prNumber, // Liên kết mặt hàng này với mã PR tổng ở trên
                ItemName: ThisRecord.drpItemName.Selected.itemName,
                ItemManualInput: ThisRecord.drpItemName.Selected.ItemCategory,
                itemDepartment: ThisRecord.txtItemDepartment.Selected.DepartmentName,
                Quantity: Value(ThisRecord.txtQuant_5.Value),
                UnitPrice: Value(ThisRecord.txtUnitPrice_4.Value),
                Currency: txtDefaultCurrency.Text,
                'Total Amount': Value(ThisRecord.txtTotalAmount_4.Value),
                Item_TotalAmt_MYR: Value(ThisRecord.txtTotalAmount_MYR.Value),
                CurYearGroup: ThisRecord.cmbCurriculum.Selected.CurriculumName, 
                NSItemInternalID: ThisRecord.combItemName.Selected.NSItemInternalID, 
                NSItemExternalID: ThisRecord.drpItemName.Selected.NSItemExternalID,
                NSDepartmentID: ThisRecord.txtItemDepartment.Selected.NS_InternalID,
                ExpenseType: ThisRecord.drpItemName.Selected.BudgetType,
                GridID: ThisRecord.GridID, 
                ItemID: ThisRecord.drpItemName.Selected.ItemCode, 
                GLNumber: ThisRecord.drpItemName.Selected.GLNumber, 
                itemDescription: txtItemDescription.Value, 
                Dept_NSID: ThisRecord.txtItemDepartment.Selected.NS_InternalID, 
                itemGrossAmount: Value(ThisRecord.txtGrossAmountTax.Value), 
                itemTaxCode: ThisRecord.cmbTaxCode.Selected.TaxName, 
                itemTaxPercentage: ThisRecord.cmbTaxCode.Selected.TaxPercentage, 
                Campus: ThisRecord.drpCampuNew.Selected.CampusName, 
                CampusNSID: ThisRecord.drpCampuNew.Selected.NSCampusID,
                CurriculumnNSID: ThisRecord.cmbCurriculum.Selected.CurNSInternalID, 
                itemTaxNSID: ThisRecord.cmbTaxCode.Selected.NS_InternalID,
                itemSubsidiary: ThisRecord.txtItemSubsidiary.Selected.Name, 
                itemSubsidiaryNSID: ThisRecord.txtItemSubsidiary.Selected.NS_InternalID,
                PurposeSubcode: Coalesce(ThisRecord.cmbPurposeSubcode.Selected.Title, ""),
                PurposeSubcodeID: Coalesce(ThisRecord.cmbPurposeSubcode.Selected.'Internal ID', 0)
            }
        )
    );
   
    // 3.11. Lấy chuỗi danh sách email người duyệt (dạng JSON) từ Ma trận phê duyệt, dọn dẹp các ký tự xuống dòng
    Set(
        varReviewerJson,
        Substitute(
            Substitute(
                Coalesce(
                    LookUp(
                        ApprovalMatrix_SY2425,
                        Subsidiary = First(itemGrid.AllItems).txtItemSubsidiary.Selected.Name &&
                        Dept       = First(itemGrid.AllItems).txtItemDepartment.Selected.DepartmentName &&
                        Campus     = First(itemGrid.AllItems).drpCampuNew.Selected.CampusName &&
                        Curriculumn_YearGroup = First(itemGrid.AllItems).cmbCurriculum.Selected.CurriculumName
                    ).Reviewer,
                    "[]"
                ),
                Char(10), // Xóa ký tự Line Feed (Xuống dòng)
                ""
            ),
            Char(13), // Xóa ký tự Carriage Return (Về đầu dòng)
            ""
        )
    );

    // 3.12. Chuyển đổi chuỗi JSON vừa làm sạch thành một Bảng dữ liệu chứa danh sách Email (varReviewerList)
    Set(
        varReviewerList,
        ForAll(
            ParseJSON(varReviewerJson) As ParsedReviewer,
            { Email: Text(ParsedReviewer) }
        )
    );

    // 3.13. Nếu danh sách người duyệt không rỗng, tạo Nhật ký phê duyệt (Approval Log) ở trạng thái "Chờ duyệt" (Pending) cho từng người
    If(
        !IsEmpty(varReviewerList),
        ForAll(
            varReviewerList As R,
            Patch(
                'SY2425-Approval_log',
                Defaults('SY2425-Approval_log'),
                {
                    PR_No: prNumber,
                    Dept: Office365Users.MyProfileV2().department,
                    Campus: Office365Users.MyProfileV2().companyName,
                    Requestor: Office365Users.MyProfileV2().mail,
                    'Requestor Name': Office365Users.MyProfileV2().displayName,
                    'Approved By': R.Email,
                    'Approver Name': IfError(
                        Office365Users.UserProfileV2(R.Email).displayName,
                        "Unknown"
                    ),
                    Item_Campus: First(itemGrid.AllItems).drpCampuNew.Selected.CampusName, 
                    Item_Curriculum: First(itemGrid.AllItems).cmbCurriculum.Selected.CurriculumName,
                    Item_Dept: First(itemGrid.AllItems).txtItemDepartment.Selected.DepartmentName, 
                    Item_Subsidiary: First(itemGrid.AllItems).txtItemSubsidiary.Selected.Name,
                    Stage: "Reviewer",
                    StageCheck: "Reviewer",
                    Status: "Pending",
                    LogType: "Reviewer"
                }
            )
        )
    );

    // 3.14. Bắn thông báo thành công (màu xanh lá) hiển thị mã PR cho người dùng nhìn thấy
    Notify(
        "Your Purchase request and item details successfully submitted. Purchase Request Number: " & prNumber & " has been created!",
        NotificationType.Success
    );

    // 3.15. Xóa dữ liệu cũ trên Form để sẵn sàng cho lần nhập tiếp theo
    ResetForm(GeneralInforForm);

    /* LƯU Ý: Đoạn code gọi tự động gửi email tự động (Power Automate Flow) dưới đây 
       đang bị khóa lại (nằm trong ký hiệu mở rộng / * * /), nó sẽ không chạy.
    */
    /*
    If(
        !IsEmpty(varReviewerList),
        ForAll(
            varReviewerList As R,
            XMCO_SY2425_PRSubmmitedFlow_Single.Run(prNumber, R.Email, IfError(Office365Users.UserProfileV2(R.Email).displayName, "an.huynhthien@vas.edu.vn"), User().FullName)
        )
    );
    */
    
    // Xóa bộ sưu tập lưu tạm thời vì đã gửi thành công
    Clear(ColRecords)
    ,
    
    // BẮT ĐẦU BƯỚC 4: XỬ LÝ LỖI (Nếu dữ liệu thiếu hoặc sai ma trận)
    // Trường hợp 4.1: Nếu có trường có dấu * bị bỏ trống
    If(checkFields = false,
        Notify("There are field with * that you could not leave them blank. Please fill in the data")
    );
    // Trường hợp 4.2: Nếu không tìm thấy cấu hình phê duyệt cho tổ hợp này
    If(checkMatrix = false, 
        Notify(
            "No approval matrix is configured for this Subsidiary / Department / Campus / Curriculum. Please adjust your selection.",
            NotificationType.Error
        )
    );
    // Lưu tạm các sản phẩm hiện tại vào bộ sưu tập 'ColRecords' để giữ lại dữ liệu cho người dùng sửa tiếp
    Set(ColRecords, itemGrid.AllItems)
);

// BƯỚC VỆ SINH SAU CÙNG: Trả các biến trạng thái về mặc định
Set(VendorCurrency, "MYR"); // Đặt tiền tệ mặc định nhà cung cấp là MYR
Reset(ToggleVendor);       // Khởi động lại nút gạt nhà cung cấp
Set(varSpinner, false);    // Tắt vòng xoay tải dữ liệu (Kết thúc quy trình)