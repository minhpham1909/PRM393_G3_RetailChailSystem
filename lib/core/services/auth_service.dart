import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Dịch vụ xác thực người dùng (dùng chung cho tất cả actor)
/// Quản lý đăng nhập, đăng xuất, và thông tin người dùng hiện tại
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  GoogleSignIn? _googleSignIn;

  GoogleSignIn get _googleSignInInstance {
    _googleSignIn ??= GoogleSignIn();
    return _googleSignIn!;
  }

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

  /// Đăng nhập bằng Google
  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      return await _auth.signInWithPopup(provider);
    }

    // Luồng cho Mobile giữ nguyên
    final googleUser = await _googleSignInInstance.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'aborted-by-user',
        message: 'Google sign-in was cancelled by user.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  /// Đăng xuất
  Future<void> signOut() async {
    if (!kIsWeb && _googleSignIn != null) {
      await _googleSignInInstance.signOut();
    }
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

  /// Tạo tài khoản mới nhưng KHÔNG đăng nhập (Dùng Secondary FirebaseApp)
  Future<String?> createAccountWithoutLogin(String email, String password) async {
    try {
      FirebaseApp secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      UserCredential userCredential = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(email: email, password: password);
      
      final uid = userCredential.user?.uid;
      
      await secondaryApp.delete();
      return uid;
    } catch (e) {
      rethrow;
    }
  }
}
