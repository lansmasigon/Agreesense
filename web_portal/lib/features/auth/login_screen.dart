import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

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
  bool _obscurePassword = true;
  bool _rememberMe = false;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
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
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient (Image removed as requested)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0D4720),
                    Color(0xFF082E14),
                  ],
                ),
              ),
            ),
          ),
          
          // Content
          Positioned.fill(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text('🌱', style: TextStyle(fontSize: 28)),
                              SizedBox(width: 8),
                              Text(
                                'AGRISENSE',
                                style: TextStyle(
                                  fontFamily: 'Sora',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Main Content
                Expanded(
                  child: isMobile 
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: _buildHeroSection(isMobile: true),
                            ),
                            const SizedBox(height: 48),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: _buildLoginCard(),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 64),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _buildHeroSection(isMobile: false),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 48),
                                  child: _buildLoginCard(),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection({required bool isMobile}) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Smarter Farming Starts Here',
              style: TextStyle(
                fontFamily: 'Sora',
                fontWeight: FontWeight.w800,
                fontSize: isMobile ? 36 : 56,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -1,
              ),
              textAlign: isMobile ? TextAlign.center : TextAlign.left,
            ),
            const SizedBox(height: 24),
            Text(
              'Empowering farmers and agricultural agencies with intelligent crop recommendations, calamity monitoring, supply forecasting, and data-driven decisions.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: isMobile ? 16 : 18,
                color: Colors.white.withOpacity(0.9),
                height: 1.5,
              ),
              textAlign: isMobile ? TextAlign.center : TextAlign.left,
            ),
            const SizedBox(height: 40),
            _buildFeatureList(isMobile: isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureList({required bool isMobile}) {
    final features = [
      'Crop Recommendation',
      'Financial Forecasting',
      'Calamity Monitoring',
      'Supply Analytics',
    ];

    return Column(
      crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 16),
              Text(
                feature,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoginCard() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.72),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sign in to continue to your dashboard.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  const Text('Email', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                  const SizedBox(height: 4),
                  _buildTextField(
                    controller: _emailController,
                    hint: 'Enter your email',
                    icon: '📧',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  
                  const SizedBox(height: 12),
                  const Text('Password', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                  const SizedBox(height: 4),
                  _buildTextField(
                    controller: _passwordController,
                    hint: '••••••••',
                    icon: '🔒',
                    isPassword: true,
                  ),
                  
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged: (v) => setState(() => _rememberMe = v ?? false),
                              activeColor: const Color(0xFF2E7D32),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Remember me', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF4B5563))),
                        ],
                      ),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Forgot?', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                      ),
                    ],
                  ),
                  
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E7D32).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('LOGIN', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 1)),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                              ],
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  const Divider(color: Color(0x331F2937), height: 1),
                  const SizedBox(height: 8),
                  
                  Column(
                    children: [
                      const Text('Need assistance?', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF64748B))),
                      const SizedBox(height: 2),
                      Text('Contact your Municipal Agriculture Office.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF1F2937).withOpacity(0.8))),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  const Text('Version 1.0 • © 2026 AgriSense', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required String icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(icon, style: const TextStyle(fontSize: 16)),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              obscureText: isPassword && _obscurePassword,
              keyboardType: keyboardType,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF1F2937)),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (isPassword)
            IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF9CA3AF),
                size: 18,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          if (!isPassword) const SizedBox(width: 14),
        ],
      ),
    );
  }
}
