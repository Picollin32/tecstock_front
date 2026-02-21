import 'package:tecstock/pages/home_page.dart';
import 'package:tecstock/services/auth_service.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nomeUsuarioController = TextEditingController();
  final _senhaController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _nomeUsuarioController.dispose();
    _senhaController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.login(
        _nomeUsuarioController.text.trim(),
        _senhaController.text,
      );

      if (!mounted) return;

      if (result['success']) {
        final nivelAcesso = await AuthService.getNivelAcesso();
        if (!mounted) return;

        if (nivelAcesso == 0) {
          Navigator.of(context).pushReplacementNamed('/empresas');
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(result['message'] ?? 'Usuário ou senha inválidos')),
              ],
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('Erro de conexão. Verifique o servidor.')),
            ],
          ),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 860;
          return isWide ? _buildWideLayout() : _buildNarrowLayout();
        },
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _buildBrandPanel(),
        ),
        Expanded(
          flex: 4,
          child: Container(
            color: const Color(0xFFFAFAFA),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                child: _buildFormPanel(maxWidth: 380),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
        ),
      ),
      child: Stack(
        children: [
          _buildDecorativeCircles(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Card(
                    elevation: 12,
                    shadowColor: Colors.black38,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: _buildFormPanel(maxWidth: 380),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
        ),
      ),
      child: Stack(
        children: [
          _buildDecorativeCircles(),
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/TecStock_icone.png',
                  width: 110,
                  height: 110,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 32),
                const Text(
                  'TecStock',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sistema de Gerenciamento\nde Oficina Mecânica',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                _buildFeatureItem(Icons.inventory_2_outlined, 'Controle de Estoque e Peças'),
                const SizedBox(height: 16),
                _buildFeatureItem(Icons.description_outlined, 'Ordens de Serviço e Orçamentos'),
                const SizedBox(height: 16),
                _buildFeatureItem(Icons.people_outline, 'Gestão de Clientes e Funcionários'),
                const SizedBox(height: 16),
                _buildFeatureItem(Icons.analytics_outlined, 'Relatórios e Auditoria'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDecorativeCircles() {
    return Positioned.fill(
      child: OverflowBox(
        alignment: Alignment.center,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -60,
              child: _circle(220, Colors.white.withValues(alpha: 0.06)),
            ),
            Positioned(
              bottom: -100,
              left: -80,
              child: _circle(280, Colors.white.withValues(alpha: 0.05)),
            ),
            Positioned(
              top: 120,
              right: -40,
              child: _circle(140, Colors.white.withValues(alpha: 0.04)),
            ),
            Positioned(
              bottom: 80,
              right: 40,
              child: _circle(90, Colors.white.withValues(alpha: 0.07)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildFormPanel({required double maxWidth}) {
    final inputDecoration = InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD32F2F)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFF757575)),
      prefixIconColor: const Color(0xFF1565C0),
    );

    return Theme(
      data: ThemeData(inputDecorationTheme: inputDecoration),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bem-vindo!',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Entre com suas credenciais para acessar o sistema',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Usuário',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nomeUsuarioController,
                    focusNode: _usernameFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
                    decoration: const InputDecoration(
                      hintText: 'Nome de usuário',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Informe o usuário' : null,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Senha',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _senhaController,
                    focusNode: _passwordFocus,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    decoration: InputDecoration(
                      hintText: 'Sua senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Informe a senha' : null,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: _isLoading ? 0 : 3,
                        shadowColor: const Color(0xFF1565C0).withValues(alpha: 0.4),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Entrar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 18),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      '© ${DateTime.now().year} TecStock · Todos os direitos reservados',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
