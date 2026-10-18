import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/bridge_client.dart';

class LoginScreen extends StatefulWidget {
  final BridgeClient client;

  const LoginScreen({super.key, required this.client});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _activeRole = 'admin';
  final TextEditingController _idCtrl = TextEditingController(text: 'admin');
  final TextEditingController _pwdCtrl = TextEditingController(text: 'admin123');
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  void _selectRole(String role) {
    setState(() {
      _activeRole = role;
      _errorMessage = null;
      if (role == 'admin') {
        _idCtrl.text = 'admin';
        _pwdCtrl.text = 'admin123';
      } else if (role == 'teacher') {
        _idCtrl.text = 'teacher';
        _pwdCtrl.text = 'teacher123';
      } else if (role == 'student') {
        _idCtrl.text = '2025(s)-SE-5';
        _pwdCtrl.text = 'student123';
      }
    });
  }

  Future<void> _submitLogin() async {
    final id = _idCtrl.text.trim();
    final pwd = _pwdCtrl.text.trim();

    if (id.isEmpty || pwd.isEmpty) {
      setState(() => _errorMessage = 'Please enter both username/roll number and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await widget.client.login(
      identifier: id,
      password: pwd,
      role: _activeRole,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (!success) {
        _errorMessage = 'Invalid credentials for ${_activeRole[0].toUpperCase()}${_activeRole.substring(1)}. Please check your details.';
      }
    });
  }

  void _quickDemo(String role, String id, String pwd) {
    _selectRole(role);
    _idCtrl.text = id;
    _pwdCtrl.text = pwd;
    _submitLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 460,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Logo & Branding
                Center(
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: _getRoleColor().withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _getRoleColor().withValues(alpha: 0.35), width: 1.5),
                    ),
                    child: Icon(_getRoleIcon(), color: _getRoleColor(), size: 28),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'UNIVISION',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    'Biometric Station & Attendance Portal',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Role Selector Tabs
                const Text(
                  'Select Account Type:',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildRoleBtn('admin', 'Admin', Icons.security_rounded),
                    const SizedBox(width: 8),
                    _buildRoleBtn('teacher', 'Teacher', Icons.school_rounded),
                    const SizedBox(width: 8),
                    _buildRoleBtn('student', 'Student', Icons.person_rounded),
                  ],
                ),
                const SizedBox(height: 8),

                // Dynamic Role Description
                Text(
                  _getRoleDescription(),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 18),

                // Identifier Input
                Text(
                  _getIdLabel(),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _idCtrl,
                  decoration: InputDecoration(
                    hintText: _getIdPlaceholder(),
                    prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.textMuted, size: 18),
                  ),
                  onSubmitted: (_) => _submitLogin(),
                ),
                const SizedBox(height: 14),

                // Password Input
                const Text(
                  'Password:',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _pwdCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Enter account password',
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: AppTheme.textMuted, size: 18),
                  ),
                  onSubmitted: (_) => _submitLogin(),
                ),

                // Error Message Banner
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Sign In Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getRoleColor(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isLoading ? null : _submitLogin,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Sign In to UniVision', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),

                const SizedBox(height: 20),

                // 1-Click Demo Access
                const Center(
                  child: Text(
                    '— OR 1-CLICK DEMO ACCESS —',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () => _quickDemo('admin', 'admin', 'admin123'),
                        child: const Text('Demo Admin'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () => _quickDemo('teacher', 'teacher', 'teacher123'),
                        child: const Text('Demo Teacher'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () => _quickDemo('student', '2025(s)-SE-5', 'student123'),
                        child: const Text('Demo Student'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBtn(String role, String label, IconData icon) {
    final bool isSelected = _activeRole == role;
    final color = isSelected ? _getRoleColor() : AppTheme.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: () => _selectRole(role),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _getRoleColor().withValues(alpha: 0.15) : AppTheme.surfaceSunken,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? _getRoleColor() : AppTheme.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor() {
    switch (_activeRole) {
      case 'admin':
        return AppTheme.primary;
      case 'teacher':
        return AppTheme.success;
      case 'student':
        return const Color(0xFFA855F7); // Purple
      default:
        return AppTheme.primary;
    }
  }

  IconData _getRoleIcon() {
    switch (_activeRole) {
      case 'admin':
        return Icons.security_rounded;
      case 'teacher':
        return Icons.school_rounded;
      case 'student':
        return Icons.person_rounded;
      default:
        return Icons.security_rounded;
    }
  }

  String _getRoleDescription() {
    switch (_activeRole) {
      case 'admin':
        return 'Admin Console: View all attendance logs and enroll students via biometrics.';
      case 'teacher':
        return 'Teacher Station: Start class sessions, live AI face HUD, and view student attendance.';
      case 'student':
        return 'Student Portal: Check your personal attendance records and verification status.';
      default:
        return '';
    }
  }

  String _getIdLabel() {
    switch (_activeRole) {
      case 'admin':
        return 'Admin Username or Email:';
      case 'teacher':
        return 'Teacher Email or Username:';
      case 'student':
        return 'Student Roll Number or Email:';
      default:
        return 'Username or Email:';
    }
  }

  String _getIdPlaceholder() {
    switch (_activeRole) {
      case 'admin':
        return 'e.g. admin or admin@univision.edu';
      case 'teacher':
        return 'e.g. teacher@school.edu or teacher';
      case 'student':
        return 'e.g. 2025(s)-SE-5 or 2024-CS-001';
      default:
        return 'Enter identifier';
    }
  }
}
