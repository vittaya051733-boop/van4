import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_repository.dart';
import 'admin_screens.dart';
import 'services/admin_illegal_product_alert_service.dart';
import 'services/admin_presence_service.dart';

class VanMarketAdminApp extends StatelessWidget {
  const VanMarketAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ADMIN',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE65100),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.white,
        cardTheme: const CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
        ),
      ),
      home: const AdminAuthGate(),
    );
  }
}

class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _AdminLoadingScreen(label: 'กำลังตรวจสอบการเข้าสู่ระบบ');
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const AdminLoginScreen();
        }

        return FutureBuilder<AdminAccessCheck>(
          future: AdminRepository.checkAdminAccess(),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const _AdminLoadingScreen(
                label: 'กำลังตรวจสอบสิทธิ์แอดมิน',
              );
            }

            if (adminSnapshot.data?.allowed == true) {
              unawaited(AdminPresenceService.instance.ensureRegistered());
              return _AdminIllegalProductAlertHost(
                child: AdminHomeScreen(user: user),
              );
            }

            return _AdminAccessDeniedScreen(
              user: user,
              reason: adminSnapshot.data?.reason,
            );
          },
        );
      },
    );
  }
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      setState(() {
        _errorText = switch (error.code) {
          'invalid-credential' => 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
          'invalid-email' => 'รูปแบบอีเมลไม่ถูกต้อง',
          'user-disabled' => 'บัญชีนี้ถูกระงับการใช้งาน',
          _ => error.message ?? 'เข้าสู่ระบบไม่สำเร็จ',
        };
      });
    } catch (_) {
      setState(() {
        _errorText = 'ไม่สามารถเข้าสู่ระบบได้ในขณะนี้';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = (MediaQuery.sizeOf(context).shortestSide * 0.74)
        .clamp(120.0, 360.0)
        .toDouble();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            logoSize * 20 / 120,
                          ),
                          child: Image.asset(
                            'assets/app_logo.png',
                            width: logoSize,
                            height: logoSize,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'เข้าสู่ระบบแอดมิน',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF9A3412),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ใช้บัญชี Firebase ที่มีอีเมลอยู่ใน collection admins (แอดมิน)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'อีเมลแอดมิน',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'กรุณากรอกอีเมล';
                          }
                          if (!text.contains('@')) {
                            return 'อีเมลไม่ถูกต้อง';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'รหัสผ่าน',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if ((value ?? '').isEmpty) {
                            return 'กรุณากรอกรหัสผ่าน';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) =>
                            _isSubmitting ? null : _signIn(),
                      ),
                      if (_errorText != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          _errorText!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _signIn,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE65100),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('เข้าสู่ระบบ'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminLoadingScreen extends StatelessWidget {
  const _AdminLoadingScreen({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final logoSize = (MediaQuery.sizeOf(context).shortestSide * 0.74)
        .clamp(120.0, 360.0)
        .toDouble();

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(logoSize * 20 / 120),
              child: Image.asset(
                'assets/app_logo.png',
                width: logoSize,
                height: logoSize,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _AdminAccessDeniedScreen extends StatelessWidget {
  const _AdminAccessDeniedScreen({required this.user, this.reason});

  final User user;
  final String? reason;

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final reasonText = reason?.trim() ?? '';
    final isFirestoreConnectionError =
        reasonText.contains('Unable to establish connection') ||
        reasonText.contains('อ่าน Firestore ไม่ได้');
    final title = isFirestoreConnectionError
        ? 'เชื่อมต่อ Firestore ไม่ได้'
        : 'อีเมลนี้ยังไม่อยู่ใน collection admins (แอดมิน)';

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 72,
                  color: Color(0xFFE65100),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  user.email ?? user.uid,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
                if (reason != null && reason!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    reason!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFB45309),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  isFirestoreConnectionError
                      ? 'ล็อกอินสำเร็จแล้ว แต่แอปอ่าน Firestore ไม่ได้ — ปิดแอปแล้วรันใหม่ด้วย flutter run (ไม่ใช่ hot reload)'
                      : 'ถ้ายังเห็นข้อความเก่า ให้ rebuild แอป van4 จากโค้ดล่าสุด',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: _signOut,
                  child: const Text('ออกจากระบบ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminIllegalProductAlertHost extends StatefulWidget {
  const _AdminIllegalProductAlertHost({required this.child});

  final Widget child;

  @override
  State<_AdminIllegalProductAlertHost> createState() =>
      _AdminIllegalProductAlertHostState();
}

class _AdminIllegalProductAlertHostState
    extends State<_AdminIllegalProductAlertHost> {
  @override
  void initState() {
    super.initState();
    unawaited(AdminIllegalProductAlertService.instance.startMonitoring());
  }

  @override
  void dispose() {
    unawaited(AdminIllegalProductAlertService.instance.stopMonitoring());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
