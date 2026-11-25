import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unisync/main.dart';

void main() {
  testWidgets('abre na tela de login com e-mail, senha e botão Google',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const UniSyncApp());
    await tester.pumpAndSettle();

    expect(find.text('Acesse sua conta'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Continuar com Google'), findsOneWidget);
    expect(find.text('Esqueci minha senha'), findsOneWidget);
    expect(find.textContaining('Criar conta'), findsOneWidget);

    // Valida rejeição de e-mail inválido e senha fraca
    final badEmail = await AppStorage.registerAccount(
      email: 'nao-e-email',
      password: 'abc123',
    );
    expect(badEmail.isSuccess, isFalse);

    final weakPassword = await AppStorage.registerAccount(
      email: 'teste@uni.br',
      password: 'abcdef',
    );
    expect(weakPassword.isSuccess, isFalse);
  });

  testWidgets(
      'cria conta, personaliza com listas suspensas e mantém dados após sair e entrar',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final registerOutcome = await AppStorage.registerAccount(
      email: 'maria@uni.br',
      password: 'segredo123',
    );
    expect(registerOutcome.isSuccess, isTrue);

    await tester.pumpWidget(const UniSyncApp());
    await tester.pumpAndSettle();

    expect(find.text('Passo 1 de 3'), findsOneWidget);
    expect(find.text('Seu nome'), findsOneWidget);
    expect(find.text('Seu curso'), findsOneWidget);
    expect(find.text('Em qual período você está?'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Maria');

    final courseDropdown = find.byType(DropdownButton<String>).at(0);
    await tester.ensureVisible(courseDropdown);
    await tester.tap(courseDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administração').last);
    await tester.pumpAndSettle();

    final periodDropdown = find.byType(DropdownButton<String>).at(1);
    await tester.ensureVisible(periodDropdown);
    await tester.tap(periodDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('4º período').last);
    await tester.pumpAndSettle();

    await AppStorage.saveProfile(
      const UserProfile(
        name: 'Maria',
        course: 'Administração',
        period: '4º período',
      ),
    );
    await AppStorage.setOnboardingComplete(true);

    // Sai da conta e entra novamente: os dados continuam salvos.
    await AppStorage.signOut();
    expect(await AppStorage.getActiveUserEmail(), isNull);

    final loginOutcome = await AppStorage.signIn(
      email: 'maria@uni.br',
      password: 'segredo123',
    );
    expect(loginOutcome.isSuccess, isTrue);
    final loaded = await AppStorage.loadProfile();
    expect(loaded.name, 'Maria');
    expect(loaded.course, 'Administração');
    expect(loaded.period, '4º período');
  });

  testWidgets('responde tarefa fixa com Sim e exibe contagem mensal no Resumo',
      (tester) async {
    final now = DateTime.now();
    const email = 'ana@uni.br';
    final subjectsJson = jsonEncode([
      const SubjectItem(
        id: 'sub_1',
        name: 'Cálculo II',
        weekdays: <int>[1, 3],
        startTime: '08:00',
        endTime: '10:00',
        colorIndex: 0,
      ).toJson(),
    ]);
    final tasksJson = jsonEncode([
      FixedTask(
        id: 'task_1',
        title: 'Carona com Mikael',
        time: '16:00',
        weekdays: <int>[now.weekday],
        completedDates: const <String>[],
      ).toJson(),
    ]);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'active_user_email': email,
      'u_${email}_onboarding_complete': true,
      'u_${email}_profile_name': 'Ana Souza',
      'u_${email}_profile_course': 'Engenharia Civil',
      'u_${email}_profile_period': '4º período',
      'u_${email}_subjects': subjectsJson,
      'u_${email}_fixed_tasks': tasksJson,
    });

    await tester.pumpWidget(const UniSyncApp());
    await tester.pumpAndSettle();

    expect(find.text('Olá, Ana!'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Sim'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Carona com Mikael'), findsOneWidget);
    expect(find.text('Não'), findsOneWidget);

    await tester.tap(find.text('Sim'));
    await tester.pumpAndSettle();
    expect(find.text('1 vez neste mês'), findsOneWidget);

    await tester.tap(find.text('Resumo'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Hábitos e tarefas fixas'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Hábitos e tarefas fixas'), findsOneWidget);
    expect(find.text('1 vez no mês'), findsOneWidget);
  });

  testWidgets('abre anotações ao clicar na disciplina e exibe opções nas Configurações',
      (tester) async {
    const email = 'joao@uni.br';
    final subjectsJson = jsonEncode([
      const SubjectItem(
        id: 'sub_1',
        name: 'Algoritmos',
        weekdays: <int>[2, 4],
        startTime: '10:00',
        endTime: '12:00',
        colorIndex: 1,
      ).toJson(),
    ]);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'active_user_email': email,
      'u_${email}_onboarding_complete': true,
      'u_${email}_profile_name': 'João Silva',
      'u_${email}_profile_course': 'Sistemas de Informação',
      'u_${email}_profile_period': '3º período',
      'u_${email}_subjects': subjectsJson,
    });

    await tester.pumpWidget(const UniSyncApp());
    await tester.pumpAndSettle();

    // Testa abertura de Configurações com resetar e sair da conta
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Disciplinas e horários'), findsOneWidget);
    expect(find.text('Notificações no celular'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sair da conta'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Resetar dados do app'), findsOneWidget);
    expect(find.text('Sair da conta'), findsOneWidget);

    // Volta para Início e clica na disciplina para abrir anotações
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Algoritmos'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Algoritmos'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma anotação ainda'), findsOneWidget);
    expect(find.text('+ Nova anotação'), findsOneWidget);
  });
}
