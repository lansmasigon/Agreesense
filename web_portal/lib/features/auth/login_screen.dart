import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import 'dart:math' as math;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isLoginMode = true;
  String _selectedRole = 'MAO';

  late AnimationController _bgController;

  final List<String> _roles = ['MAO', 'BAW', 'Technician'];

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      
      if (_isLoginMode) {
        final response = await supabase
            .from('profiles')
            .select()
            .eq('email', _emailController.text.trim())
            .eq('password', _passwordController.text.trim())
            .maybeSingle();

        if (response == null) {
          throw Exception('Invalid credentials or unauthorized access.');
        }
        ref.read(currentUserProvider.notifier).setUser(response);
      } else {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();
        
        final exists = await supabase
            .from('profiles')
            .select()
            .eq('email', email)
            .maybeSingle();
            
        if (exists != null) {
          throw Exception('Terminal access for this email already exists.');
        }

        final response = await supabase.from('profiles').insert({
          'email': email,
          'password': password,
          'role': _selectedRole.toLowerCase(),
          'full_name': email.split('@')[0], 
        }).select().single();

        ref.read(currentUserProvider.notifier).setUser(response);
      }
      
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // LEFT: Bloomberg Terminal / Animated Satellite Style
          Expanded(
            flex: 5,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A), // Dark slate
              ),
              child: Stack(
                children: [
                  // Animated background map simulation
                  AnimatedBuilder(
                    animation: _bgController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(math.sin(_bgController.value * 2 * math.pi) * 20, math.cos(_bgController.value * 2 * math.pi) * 20),
                        child: Transform.scale(
                          scale: 1.1,
                          child: Opacity(
                            opacity: 0.15,
                            child: Image.network(
                              'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=2000&auto=format&fit=crop',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                      );
                    }
                  ),
                  // Grid overlay
                  CustomPaint(
                    size: Size.infinite,
                    painter: GridPainter(),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(64.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.eco_rounded, color: AppColors.accent, size: 48),
                        const SizedBox(height: 24),
                        const Text('AGRISENSE', style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 8, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        const Text('MUNICIPAL\nCOMMAND\nCENTER', style: TextStyle(color: Colors.white, fontSize: 56, height: 1.1, fontWeight: FontWeight.bold, letterSpacing: -2)),
                        const Spacer(),
                        Row(
                          children: [
                            _buildTerminalStat('ACTIVE NODES', '1,245', AppColors.accent),
                            const SizedBox(width: 48),
                            _buildTerminalStat('SYSTEM HEALTH', '99.9%', AppColors.information),
                            const SizedBox(width: 48),
                            _buildTerminalStat('LATEST SYNC', '0.4s ago', AppColors.warning),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          
          // RIGHT: Login Form
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.05),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Government Seal Placeholder
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.account_balance, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        _isLoginMode ? 'Welcome Back' : 'Initialize Terminal',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1, color: AppColors.text),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLoginMode ? 'Enter your credentials to access the command center.' : 'Register a new administrative node.',
                        style: const TextStyle(color: AppColors.secondaryText, fontSize: 15),
                      ),
                      const SizedBox(height: 48),
                      
                      const Text('Email Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'name@municipality.gov.ph',
                          hintStyle: const TextStyle(color: AppColors.border),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 24),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                          if (_isLoginMode)
                            TextButton(onPressed: (){}, child: const Text('Forgot Password?', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)))
                        ],
                      ),
                      if (!_isLoginMode) const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: const TextStyle(color: AppColors.border),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                        ),
                        obscureText: true,
                      ),
                      
                      if (!_isLoginMode) ...[
                        const SizedBox(height: 24),
                        const Text('Access Level', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                          ),
                          items: _roles.map((role) {
                            return DropdownMenuItem(value: role, child: Text(role));
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _selectedRole = value);
                          },
                        ),
                      ],
                      
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                      ],
                      
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(20),
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(_isLoginMode ? 'Login to Terminal' : 'Initialize Node', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isLoginMode = !_isLoginMode;
                              _errorMessage = null;
                            });
                          },
                          child: Text(
                            _isLoginMode ? 'Request Terminal Access' : 'Return to Login',
                            style: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 48),
                      const Center(child: Text('v2.4.0-stable', style: TextStyle(color: AppColors.border, fontSize: 12, fontFamily: 'monospace'))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
      
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
