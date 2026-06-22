# Backup & Version Control

Cấu trúc thư mục backup cho project SiriusNex Power Apps.

## Quy tắc đặt tên

```
_backup/
├── v1_ORIGINAL/          ← Code gốc từ PROD (trước khi fix bất kỳ thứ gì)
├── v2_FIXED_20260620/    ← Fix delegation lần 1 (ngày deploy)
├── v3_FIXED_20260622/    ← Fix optimization (ngày deploy)
└── README.md
```

## Cách dùng

- **Trước khi sửa**: Copy file hiện tại vào folder `vX_xxx_DATE/`
- **File name**: Giữ nguyên tên gốc, thêm folder version để phân biệt
- **Revert**: Copy file từ folder backup → paste lại vào folder chính

## Version History

| Version | Ngày | Mô tả | Status |
|---------|------|--------|--------|
| v1_ORIGINAL | - | Code gốc từ PROD, chưa sửa gì | Baseline |
| v2_FIXED_20260620 | 2026-06-20 | Fix delegation: split ||, pre-build colUserPRs | Tested |
| v3_FIXED_20260622 | 2026-06-22 | Optimize Step 3: giới hạn LookUp, giảm load time | Testing |
