import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class AuthOutcome {
  const AuthOutcome({
    this.error,
    this.launchedExternalFlow = false,
  });

  final String? error;
  final bool launchedExternalFlow;

  bool get isSuccess => error == null;
}

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  bool _initialized = false;

  bool get isReady => _initialized && SupabaseConfig.isConfigured;

  SupabaseClient? get _client => isReady ? Supabase.instance.client : null;

  String get _webRedirectUrl => '${Uri.base.origin}${Uri.base.path}';

  User? get currentUser => _client?.auth.currentUser;

  String? get currentUserEmail => currentUser?.email?.trim().toLowerCase();

  Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();

  Future<void> initialize() async {
    if (_initialized || !SupabaseConfig.isConfigured) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url.trim(),
        publishableKey: SupabaseConfig.anonKey.trim(),
      );
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  String _friendlyAuthError(Object error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials')) {
        return 'E-mail ou senha incorretos.';
      }
      if (msg.contains('email not confirmed')) {
        return 'Esta conta ainda aguarda confirmação. Tente entrar com Google ou tente novamente mais tarde.';
      }
      if (msg.contains('user already registered') ||
          msg.contains('already exists')) {
        return 'Este e-mail já está cadastrado. Tente entrar ou recuperar sua senha.';
      }
      if (msg.contains('invalid email') || msg.contains('unable to validate')) {
        return 'Digite um endereço de e-mail válido.';
      }
      if (msg.contains('weak password') || msg.contains('at least')) {
        return 'Escolha uma senha mais forte (mínimo de 6 caracteres).';
      }
      if (msg.contains('rate limit') ||
          msg.contains('too many requests') ||
          msg.contains('over_email_send_rate_limit')) {
        return 'Muitas tentativas seguidas. Aguarde alguns minutos e tente novamente.';
      }
      if (msg.contains('provider is not enabled')) {
        return 'O login com Google está temporariamente indisponível.';
      }
      return 'Não foi possível concluir o acesso. Tente novamente.';
    }
    return 'Não foi possível conectar ao servidor. Verifique sua internet e tente novamente.';
  }

  Future<AuthOutcome> signUp({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      return const AuthOutcome(
        error: 'Serviço indisponível no momento. Verifique sua conexão.',
      );
    }

    final normalized = email.trim().toLowerCase();
    try {
      final response = await client.auth.signUp(
        email: normalized,
        password: password,
        emailRedirectTo:
            kIsWeb ? _webRedirectUrl : SupabaseConfig.mobileRedirectUrl,
      );

      if (response.session != null) {
        return const AuthOutcome();
      }

      final identities = response.user?.identities;
      if (identities != null && identities.isEmpty) {
        return const AuthOutcome(
          error:
              'Este e-mail já está cadastrado. Tente entrar ou usar "Esqueci minha senha".',
        );
      }

      // Tenta autenticar imediatamente caso o servidor já tenha confirmado a conta.
      try {
        await client.auth.signInWithPassword(
          email: normalized,
          password: password,
        );
        return const AuthOutcome();
      } catch (signInError) {
        return AuthOutcome(error: _friendlyAuthError(signInError));
      }
    } catch (e) {
      return AuthOutcome(error: _friendlyAuthError(e));
    }
  }

  Future<AuthOutcome> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      return const AuthOutcome(
        error: 'Serviço indisponível no momento. Verifique sua conexão.',
      );
    }

    try {
      await client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      return const AuthOutcome();
    } catch (e) {
      return AuthOutcome(error: _friendlyAuthError(e));
    }
  }

  Future<AuthOutcome> signInWithGoogle() async {
    final client = _client;
    if (client == null) {
      return const AuthOutcome(
        error: 'Não foi possível conectar para entrar com o Google.',
      );
    }

    try {
      final launched = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? _webRedirectUrl : SupabaseConfig.mobileRedirectUrl,
        authScreenLaunchMode:
            kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView,
      );
      if (!launched) {
        return const AuthOutcome(
          error: 'Não foi possível abrir a tela de login do Google.',
        );
      }
      return const AuthOutcome(launchedExternalFlow: true);
    } catch (e) {
      return AuthOutcome(error: _friendlyAuthError(e));
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    final client = _client;
    if (client == null) {
      return 'Não foi possível enviar a recuperação de senha agora. Verifique sua conexão.';
    }
    try {
      await client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: kIsWeb ? _webRedirectUrl : SupabaseConfig.mobileRedirectUrl,
      );
      return null;
    } catch (e) {
      return _friendlyAuthError(e);
    }
  }

  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    try {
      await client.auth.signOut();
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> fetchUserCloudData() async {
    final client = _client;
    final user = currentUser;
    if (client == null || user == null) return null;

    try {
      final row = await client
          .from('user_app_data')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      return row;
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveUserCloudData(Map<String, dynamic> payload) async {
    final client = _client;
    final user = currentUser;
    if (client == null || user == null) return false;

    try {
      await client.from('user_app_data').upsert(<String, dynamic>{
        'user_id': user.id,
        'email': user.email ?? '',
        ...payload,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
