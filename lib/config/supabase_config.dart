/// Configuração do projeto Supabase do UniSync.
///
/// Como preencher:
/// 1. Acesse https://supabase.com e abra seu projeto.
/// 2. Vá em Project Settings -> API (ou Connect).
/// 3. Cole abaixo a "Project URL" e a chave pública "Publishable / anon key"
///    (ou passe via --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...).
///
/// IMPORTANTE: Use SOMENTE a chave pública (anon/publishable), nunca a service_role.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bsmwjjgbnklysfsdsmuf.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_3qY0jb4jCAi0EM2riBgw6A_ZBeOYlUd',
  );

  /// Deep link usado no Android/iOS para retorno do login com Google e recuperação de senha.
  /// Adicione "unisync://login-callback/" em Authentication -> URL Configuration -> Redirect URLs no Supabase.
  static const String mobileRedirectUrl = 'unisync://login-callback/';

  static bool get isConfigured =>
      url.trim().isNotEmpty && anonKey.trim().isNotEmpty;
}
