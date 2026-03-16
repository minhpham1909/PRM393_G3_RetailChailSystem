# RCMS Mock Data — Retail Chain Management System

Bộ dữ liệu mẫu cho dự án PRM393 — Retail Chain Management System, chuyên biệt cho luồng quản lý nội bộ.

**Lưu ý:** Phạm vi dự án đã được tinh giản tối đa:
1. **Chỉ có 2 cấu trúc rẽ nhánh chính:**
   - **Admin**: Quản lý Central Master Warehouse (tổng kho duy nhất), phê duyệt nhập xuất kho, và quản lý các Store Manager.
   - **Store Manager**: Quản lý toàn bộ thông tin nội bộ của 1 chi nhánh cửa hàng.
2. **Không có phân mảnh khu vực:** Toàn bộ hệ thống được kết nối chung về 1 tổng kho thay vì chia nhiều miền.
3. Không có Staff và Customer.

## Tổng quan cấu trúc

| File | Mô tả | Số lượng |
|---|---|---|
| `warehouses.json` | 1 Tổng kho tập trung có kèm thông tin tồn kho Master | 1 |
| `stores.json` | 4 chi nhánh cửa hàng kết nối tổng kho | 4 |
| `users.json` | Tài khoản 2 actor: Admin (4) và Store Manager (4) | 8 |
| `categories.json` | Danh mục sản phẩm | 7 |
| `products.json` | Sản phẩm (5/thể loại) kèm Link ảnh Demo | 35 |
| `orders.json` | Hóa đơn bán hàng ẩn danh khách hàng (kèm chi tiết items) | 15 |
| `stock_requests.json` | Yêu cầu nhập hàng từ Admin(Tổng kho) | 8 |
| `inventory.json` | Tồn kho chi nhánh (địa điểm cửa hàng) | 4 x 35 |

## Chi tiết Users để test Auth Login (8 tài khoản)

### System Admin / Tổng kho (4 người)
| ID | Họ tên | Email | Password |
|---|---|---|---|
| ADM_001 | Truong Minh Quan | admin.truong@rcms.vn | Admin@123 |
| ADM_002 | Phan Thuy Linh | admin.linh@rcms.vn | Admin@123 |
| ADM_003 | Le Trung Hieu | admin.hieu@rcms.vn | Admin@123 |
| ADM_004 | Vo Ngoc Mai | admin.mai@rcms.vn | Admin@123 |

### Store Manager (4 người — 1/chi nhánh)
| ID | Họ tên | Email | Chi nhánh | Password |
|---|---|---|---|---|
| MGR_001 | Nguyen Hoang Thanh | manager.thanh@rcms.vn | STORE_001 | Manager@123 |
| MGR_002 | Tran Thi Bich Hoa | manager.hoa@rcms.vn | STORE_002 | Manager@123 |
| MGR_003 | Pham Van Duc | manager.duc@rcms.vn | STORE_003 | Manager@123 |
| MGR_004 | Le Thuy Ngoc | manager.ngoc@rcms.vn | STORE_004 | Manager@123 |

## Cách Import lên Firebase Firestore

Sử dụng thư mục script `firebase_seeder` được cung cấp kèm theo:
1. cd vào thư mục `firebase_seeder`
2. Chạy `npm install`
3. Lấy file Service Account Key của dự án Firebase (Settings > Service Accounts > Generate new private key)
4. Lưu file đó với tên `serviceAccountKey.json` vào chung cấp với thư mục `data` hoặc chỉ định đường dẫn trong code.
5. Chạy lệnh: `node seed.js` để tự động đẩy toàn bộ dữ liệu mẫu lên.
