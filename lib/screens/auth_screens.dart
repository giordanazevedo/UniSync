import 'package:material_ui/material_ui.dart';

import '../config/supabase_config.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';
import 'onboarding_screens.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final outcome = await AppStorage.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (!outcome.isSuccess) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(outcome.error!)),
      );
      return;
    }

    final completed = await AppStorage.isOnboardingComplete();
    final tasks = await AppStorage.loadFixedTasks();
    await NotificationService.instance.rescheduleAllFixedTasks(tasks);
    if (!mounted) return;

    replaceScreen(
      context,
      completed ? const AppShell() : const ProfileSetupScreen(),
    );
  }

  Future<void> _loginWithGoogle() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final outcome = await AppStorage.signInWithGoogle();
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!outcome.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(outcome.error!)),
      );
    }
  }

  Future<void> _forgotPassword() async {
    final resetEmailController =
        TextEditingController(text: _emailController.text.trim());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Recuperar senha',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Informe o e-mail da sua conta para enviarmos o link de redefinição de senha.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'seuemail@exemplo.com',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: blue),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enviar link'),
          ),
        ],
      ),
    );

    final targetEmail = resetEmailController.text.trim();
    resetEmailController.dispose();
    if (confirmed != true || !mounted) return;

    final error = await AppStorage.sendPasswordReset(targetEmail);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              'Enviamos um link de recuperação de senha para $targetEmail.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cloudConfigured = SupabaseConfig.isConfigured;

    return MobileFrame(
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      AppMark(size: 58),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: brandNavy,
                                  letterSpacing: -1,
                                  height: 1.05,
                                ),
                                children: [
                                  TextSpan(text: 'Uni'),
                                  TextSpan(
                                    text: 'Sync',
                                    style: TextStyle(color: brandIndigo),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Sua vida universitária em sintonia.',
                              style: TextStyle(
                                color: muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SurfaceCard(
                    borderRadius: 22,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'ENTRAR',
                              style: TextStyle(
                                color: blue,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                              ),
                            ),
                            PillBadge(
                              label: cloudConfigured
                                  ? 'Nuvem ativa'
                                  : 'Modo local',
                              backgroundColor:
                                  cloudConfigured ? paleGreen : paleBlue,
                              textColor: cloudConfigured ? green : blue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Acesse sua conta',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cloudConfigured
                              ? 'Seus dados ficam sincronizados na nuvem (Supabase) para não perder ao trocar de celular.'
                              : 'Configure o Supabase em lib/config/supabase_config.dart para salvar na nuvem e verificar e-mail.',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(height: 18),
                        AppField(
                          label: 'E-mail',
                          hintText: 'seuemail@exemplo.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textCapitalization: TextCapitalization.none,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Senha',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(
                            color: ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Digite sua senha',
                            hintStyle: const TextStyle(
                              color: Color(0xFF9EA3B0),
                              fontSize: 14,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: muted,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _forgotPassword,
                            style: TextButton.styleFrom(
                              foregroundColor: blue,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                            ),
                            child: const Text(
                              'Esqueci minha senha',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        PrimaryButton(
                          label: _submitting ? 'Entrando...' : 'Entrar',
                          onPressed: _login,
                        ),
                        const SizedBox(height: 14),
                        const Row(
                          children: [
                            Expanded(child: Divider(color: borderColor)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'ou',
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: borderColor)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _GoogleAuthButton(
                          label: 'Continuar com Google',
                          onPressed: _loginWithGoogle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton(
                      onPressed: () =>
                          pushScreen<void>(context, const SignUpScreen()),
                      child: const Text.rich(
                        TextSpan(
                          text: 'Não tem conta ainda? ',
                          style: TextStyle(
                            color: muted,
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            TextSpan(
                              text: 'Criar conta',
                              style: TextStyle(
                                color: blue,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
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

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_submitting) return;
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('As senhas não coincidem.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final outcome = await AppStorage.registerAccount(
      email: _emailController.text,
      password: password,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!outcome.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(outcome.error!)),
      );
      return;
    }

    if (outcome.requiresEmailVerification) {
      await _showEmailVerificationDialog(_emailController.text.trim());
      return;
    }

    replaceScreen(context, const ProfileSetupScreen());
  }

  Future<void> _signUpWithGoogle() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final outcome = await AppStorage.signInWithGoogle();
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!outcome.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(outcome.error!)),
      );
    }
  }

  Future<void> _showEmailVerificationDialog(String email) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Confirme seu e-mail',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Enviamos um link de verificação para $email.\n\nAbra sua caixa de entrada (ou spam), clique no link para confirmar sua conta e depois faça login.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final err =
                  await SupabaseService.instance.resendVerificationEmail(email);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    err ?? 'Link de verificação reenviado para $email.',
                  ),
                ),
              );
            },
            child: const Text('Reenviar e-mail'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: blue),
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text('Ir para o Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: canvas,
          surfaceTintColor: canvas,
          title: const Text(
            'Criar conta',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    AppMark(size: 52),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cadastre sua conta',
                            style: TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                            ),
                          ),
                          Text(
                            'Com verificação de e-mail e backup na nuvem pelo Supabase.',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SurfaceCard(
                  borderRadius: 22,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppField(
                        label: 'E-mail',
                        hintText: 'seuemail@exemplo.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textCapitalization: TextCapitalization.none,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Senha',
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Mín. 6 caracteres (letras e números)',
                          hintStyle: const TextStyle(
                            color: Color(0xFF9EA3B0),
                            fontSize: 14,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: muted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppField(
                        label: 'Confirmar senha',
                        hintText: 'Repita sua senha',
                        controller: _confirmController,
                        obscureText: _obscurePassword,
                        textCapitalization: TextCapitalization.none,
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: _submitting
                            ? 'Criando conta...'
                            : 'Criar conta',
                        onPressed: _signUp,
                      ),
                      const SizedBox(height: 14),
                      const Row(
                        children: [
                          Expanded(child: Divider(color: borderColor)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'ou',
                              style: TextStyle(
                                color: muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: borderColor)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _GoogleAuthButton(
                        label: 'Cadastrar com Google',
                        onPressed: _signUpWithGoogle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text.rich(
                      TextSpan(
                        text: 'Já tem conta? ',
                        style: TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(
                            text: 'Entrar',
                            style: TextStyle(
                              color: blue,
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleAuthButton extends StatelessWidget {
  const _GoogleAuthButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: Colors.white,
          side: const BorderSide(color: borderColor, width: 1.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: paleBlue,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'G',
                style: TextStyle(
                  color: blue,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: ink,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
