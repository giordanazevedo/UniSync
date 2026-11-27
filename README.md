# UniSync

**UniSync** — *Sua vida universitária em sintonia.* Aplicativo **Flutter / Dart** de organização acadêmica, tarefas fixas e controle financeiro para estudantes.

## Funcionalidades

1. **Configuração inicial em 3 passos:**
   - **Passo 1:** Nome, curso e em qual período está.
   - **Passo 2:** Cadastro das disciplinas com dias da semana e horário de início e fim.
   - **Passo 3:** Agendamento de tarefas fixas com horário e dias da semana.
2. **Tarefas fixas com notificação no celular:**
   - Envia notificação local no horário configurado perguntando se você fez a tarefa (`Sim, fiz` / `Não fiz`).
   - A confirmação de presença aparece na tela **Início** apenas nos dias com aulas cadastradas.
   - Mostra no **Resumo** quantas vezes no mês cada tarefa fixa foi feita.
3. **Anotações por disciplina:**
   - Ao clicar em qualquer disciplina (no Início, Agenda, Resumo ou lista de disciplinas), abre a tela de anotações para criar, editar e excluir notas daquela matéria.
4. **Agenda, Frequência e Finanças:**
   - Calendário mensal real com aulas e tarefas fixas de cada dia.
   - Confirmação diária de presença nas aulas e lançamentos financeiros do mês.

## Estrutura do projeto

- `lib/main.dart`: inicialização, tratamento de notificações e roteamento inicial.
- `lib/models/app_models.dart`: modelos de perfil, disciplinas, anotações, tarefas fixas e finanças.
- `lib/services/storage_service.dart`: persistência local com `shared_preferences`.
- `lib/services/notification_service.dart`: agendamento e resposta de notificações locais (`flutter_local_notifications` + `timezone`).
- `lib/screens/`: telas do app (onboarding, início, agenda, tarefas fixas, anotações, finanças, resumo e configurações).
- `lib/theme/app_theme.dart`: tema visual e componentes reutilizáveis.
- `test/widget_test.dart`: testes automatizados de interface.

## Como executar

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

> Se no futuro precisar compilar para iOS em um Mac, recrie a pasta `ios/` com `flutter create --platforms=ios .`.

## Publicar na Firebase Hosting

O site é publicado em [https://unisyncbr.web.app](https://unisyncbr.web.app).

```powershell
flutter build web --release
firebase deploy --only hosting --project unisync-479ad
```

Para cadastro, login Google e recuperação de senha funcionarem em produção, adicione
`https://unisyncbr.web.app/` às Redirect URLs em Authentication > URL Configuration
no Supabase.
