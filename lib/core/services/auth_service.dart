import 'package:firebase_auth/firebase_auth.dart';

/// Dịch vụ xác thực người dùng (dùng chung cho tất cả actor)
/// Quản lý đăng nhập, đăng xuất, và thông tin người dùng hiện tại
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Lấy người dùng hiện tại (null nếu chưa đăng nhập)
  User? get currentUser => _auth.currentUser;

  /// Kiểm tra đã đăng nhập chưa
  bool get isLoggedIn => _auth.currentUser != null;

  /// Lắng nghe thay đổi trạng thái đăng nhập
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Đăng nhập bằng email và mật khẩu
  Future<UserCredential> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Đăng xuất
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Gửi email đặt lại mật khẩu
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Tạo tài khoản mới (dùng cho Admin/Manager tạo tài khoản nhân viên)
  Future<UserCredential> createAccount(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
}
