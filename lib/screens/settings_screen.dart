import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../config/supabase_config.dart';
import '../models/app_models.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'auth_screens.dart';
import 'fixed_tasks_screen.dart';
import 'onboarding_screens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onDataChanged});

  final VoidCallback? onDataChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserProfile profile = const UserProfile(name: '', course: '', period: '');
  String? userEmail;
  bool notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final loadedProfile = await AppStorage.loadProfile();
    final email = await AppStorage.getActiveUserEmail();
    final enabled = await AppStorage.areNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      profile = loadedProfile;
      userEmail = email;
      notificationsEnabled = enabled;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => notificationsEnabled = value);
    await AppStorage.setNotificationsEnabled(value);
    final tasks = await AppStorage.loadFixedTasks();
    if (value) {
      await NotificationService.instance.requestPermissions();
      await NotificationService.instance.rescheduleAllFixedTasks(tasks);
    } else {
      await NotificationService.instance.cancelAll();
    }
    widget.onDataChanged?.call();
  }

  Future<void> _testNotification() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'As notificações chegam no celular (Android/iOS). No navegador web elas ficam desativadas.',
          ),
        ),
      );
      return;
    }
    final sent = await NotificationService.instance.showGeneralTestNotification();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Notificação de teste enviada para o celular!'
              : 'Permita notificações do UniSync nas configurações do celular.',
        ),
      ),
    );
  }

  Future<void> _restartOnboarding() async {
    await AppStorage.setOnboardingComplete(false);
    if (!mounted) return;
    replaceScreen(context, const ProfileSetupScreen());
  }

  Future<void> _confirmResetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Resetar dados do app?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Isso vai apagar seu perfil, disciplinas, anotações, tarefas fixas, presenças e finanças desta conta para começar do zero. Seu login continuará salvo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Resetar tudo'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await NotificationService.instance.cancelAll();
    await AppStorage.resetCurrentUserData();
    if (!mounted) return;
    replaceScreen(context, const ProfileSetupScreen());
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Sair da conta?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Seus dados continuarão salvos na sua conta. Basta entrar novamente com seu e-mail e senha.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: blue),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await NotificationService.instance.cancelAll();
    await AppStorage.signOut();
    if (!mounted) return;
    replaceScreen(context, const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    final displayName = profile.name.isEmpty ? 'Estudante' : profile.name;
    final subtitleParts = <String>[
      if (profile.course.isNotEmpty) profile.course,
      if (profile.period.isNotEmpty) profile.period,
      if (profile.shift.isNotEmpty) profile.shift,
    ];
    final displaySubtitle = subtitleParts.isEmpty
        ? 'Complete seu perfil acadêmico'
        : subtitleParts.join(' · ');

    return MobileFrame(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: canvas,
          surfaceTintColor: canvas,
          title: const Text(
            'Configurações',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    await pushScreen<bool>(
                      context,
                      const ProfileSetupScreen(isEditing: true),
                    );
                    await _loadData();
                    widget.onDataChanged?.call();
                  },
                  child: SurfaceCard(
                    child: Row(
                      children: [
                        Avatar(initials: profile.initials),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  color: ink,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              if (userEmail != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  userEmail!,
                                  style: const TextStyle(
                                    color: blue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                displaySubtitle,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const PillBadge(label: 'Editar'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SurfaceCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppStorage.isCloudConnected
                            ? paleGreen
                            : paleBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        AppStorage.isCloudConnected
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded,
                        color: AppStorage.isCloudConnected ? green : blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStorage.isCloudConnected
                                ? 'Backup na nuvem ativo'
                                : SupabaseConfig.isConfigured
                                    ? 'Supabase pronto'
                                    : 'Backup local (configure o Supabase)',
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppStorage.isCloudConnected
                                ? 'Seus dados são salvos automaticamente no Supabase.'
                                : 'Preencha lib/config/supabase_config.dart para sincronizar entre celulares.',
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (AppStorage.isCloudConnected)
                      TextButton(
                        onPressed: () async {
                          final ok = await AppStorage.pushToCloud();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Dados sincronizados na nuvem!'
                                    : 'Não foi possível sincronizar agora.',
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'Sincronizar',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SurfaceCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    SettingsRow(
                      title: 'Disciplinas e horários',
                      subtitle: 'Adicionar mais disciplinas, editar ou anotar',
                      onTap: () async {
                        await pushScreen<bool>(
                          context,
                          const SubjectsSetupScreen(isOnboarding: false),
                        );
                        widget.onDataChanged?.call();
                      },
                    ),
                    const Divider(height: 1, color: borderColor),
                    SettingsRow(
                      title: 'Tarefas fixas',
                      subtitle: 'Agendar horários e notificações no celular',
                      onTap: () async {
                        await pushScreen<void>(
                          context,
                          const FixedTasksScreen(),
                        );
                        widget.onDataChanged?.call();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SurfaceCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Notificações no celular',
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: const Text(
                        'Avisar no horário agendado das tarefas fixas',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      value: notificationsEnabled,
                      onChanged: _toggleNotifications,
                    ),
                    const Divider(height: 1, color: borderColor),
                    SettingsRow(
                      title: 'Testar notificação no celular',
                      subtitle: 'Enviar um aviso de teste agora',
                      onTap: _testNotification,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SurfaceCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    SettingsRow(
                      title: 'Refazer configuração inicial',
                      subtitle: 'Revisar perfil, disciplinas e tarefas fixas',
                      onTap: _restartOnboarding,
                    ),
                    const Divider(height: 1, color: borderColor),
                    ListTile(
                      onTap: _confirmResetData,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Resetar dados do app',
                        style: TextStyle(
                          color: red,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: const Text(
                        'Apagar disciplinas, anotações, tarefas e finanças',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      trailing: const Icon(
                        Icons.restart_alt_rounded,
                        color: red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SecondaryButton(
                label: 'Sair da conta',
                onPressed: _signOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
