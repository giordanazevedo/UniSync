# Roteiro de Apresentação — UniSync
**Disciplina:** Código de Alta Performance Mobile  
**Aplicativo:** UniSync — *Sua vida universitária em sintonia*  
**Duração total:** 10 minutos  
**Integrantes:** `[Nome 1]`, `[Nome 2]`, `[Nome 3]` *(preencher antes de apresentar)*

> **Lembrete obrigatório (pág. 2 do edital):** um integrante do grupo deve preencher o formulário: https://forms.gle/VEdkCR5xLLe9Qf7a8

---

## Slide 1 — Capa & Introdução (1 min)
### O que mostrar no slide
- Logo **UniSync** + slogan *"Sua vida universitária em sintonia."*
- Integrantes do grupo
- **O Problema:** estudantes espalham horários de aula, anotações de disciplinas, hábitos/tarefas fixas, controle de faltas e finanças em 4 ou 5 aplicativos diferentes — e frequentemente perdem tudo ao trocar de celular.
- **Desafio de Performance:**
  1. Garantir **resposta instantânea na UI** mesmo sem internet ou em rede móvel instável;
  2. Enviar **notificações diárias recorrentes** no celular sem drenar bateria nem travar a CPU;
  3. Renderizar **calendário, listas dinâmicas e gráficos** mantendo **60/120 FPS** sem engasgos (*jank*) nem vazamentos de memória (*memory leaks*).

### Fala sugerida (1 min)
> "Olá! Somos [nomes] e apresentamos o **UniSync**, um app mobile em Flutter criado para centralizar a rotina universitária: disciplinas com horários e anotações, tarefas fixas com confirmação diária, agenda, frequência e finanças. O maior desafio de performance nesse tipo de aplicativo é manter a interface sempre fluida e responsiva — mesmo offline —, agendar notificações sem gastar bateria em segundo plano e garantir sincronização segura na nuvem sem travar a Main Thread."

---

## Slide 2 — Stack Tecnológica e Arquitetura (1,5 min)
### O que mostrar no slide
- **Stack escolhida:**
  - **Flutter 3.50 + Dart 3.14:** compilação nativa AOT (sem ponte JavaScript), motor gráfico próprio (Impeller/Skia) para 60/120 FPS constantes e UI declarativa otimizada com `const`.
  - **Supabase (Auth + PostgreSQL + RLS):** autenticação real com verificação de e-mail, login com Google (OAuth 2.0) e sincronização na nuvem protegida por *Row Level Security*.
  - **SharedPreferences (Cache local offline-first):** leitura e escrita locais instantâneas.
  - **flutter_local_notifications + timezone:** agendamento nativo no SO (`AlarmManager` no Android).
  - **Fontes locais (`Plus Jakarta Sans`):** embutidas em `assets/fonts/` (zero latência de rede na renderização tipográfica).
- **Arquitetura em Camadas:**
  ```text
  lib/
  ├── config/    → supabase_config.dart (credenciais e redirect URL)
  ├── models/    → app_models.dart (modelos imutáveis e serialização)
  ├── services/  → storage_service.dart | supabase_service.dart | notification_service.dart
  ├── screens/   → auth | onboarding | home | agenda | fixed_tasks | notes | finance | summary | settings
  └── theme/     → app_theme.dart (design system, tokens e CustomPainters)
  ```
- Separação clara entre **UI** (`screens/`), **estado/modelos** (`models/`) e **I/O de rede/disco/SO** (`services/`), mantendo a **UI Thread** livre de bloqueios.

### Fala sugerida (1,5 min)
> "Escolhemos **Flutter e Dart** porque o código é compilado diretamente para código de máquina nativo, sem bridge JavaScript, o que reduz latência e mantém animações a 60 FPS estáveis. No backend, integramos o **Supabase** com PostgreSQL e Row Level Security para login real com e-mail verificado e Google OAuth. Arquiteturalmente, refatoramos o projeto de um arquivo monolítico de mais de 3.000 linhas para camadas separadas (`models`, `services`, `screens` e `theme`), isolando toda a lógica de armazenamento, rede e notificações fora da camada visual."

---

## Slide 3 — Demonstração Prática: "O Caminho Feliz" (2 min)
### Roteiro cronometrado da Live Demo
1. **Login / Cadastro (20s):** mostrar tela de Login com verificação de e-mail e **Continuar com Google** (`Nuvem ativa`).
2. **Personalização em 3 passos (25s):** Passo 1 com listas suspensas (curso, período e turno) → Passo 2 cadastrando disciplinas e horários → Passo 3 agendando uma tarefa fixa com horário de notificação.
3. **Início + Tarefas Fixas + Anotações (40s):**
   - Confirmar presença (`Sim, assisti`) e responder tarefa fixa (`Sim` / `Não`) — destacar resposta imediata sem spinner travando a tela.
   - Clicar em uma disciplina para abrir **Anotações** e criar uma nota.
   - Mostrar o botão `+ Adicionar` para novas disciplinas.
4. **Agenda, Finanças e Resumo (35s):**
   - Alternar abas com transição instantânea: calendário mensal na **Agenda**, lançamentos em **Finanças** e o **Resumo** mostrando frequência semanal (`S1`–`S4`), contagem mensal das tarefas fixas (`X vezes no mês`) e o gráfico donut de gastos.
   - Abrir **Configurações** destacando backup na nuvem, teste de notificação, resetar dados e sair da conta sem perder os dados.

### Fala sugerida (durante a demo)
> "Notem a velocidade de inicialização e a ausência de travamentos ao alternar abas, marcar tarefas e abrir anotações. Mesmo sincronizando com o Supabase na nuvem, a interface responde na hora sem bloquear o usuário."

---

## Slides 4, 5 e 6 — Mergulho Técnico: Otimizações de Performance (3,5 min)
*(Ponto mais importante da avaliação — 3 técnicas aplicadas na prática no UniSync)*

### Técnica 1 — Arquitetura Offline-First & Consolidação de Rede (`storage_service.dart` + `supabase_service.dart`)
- **Problema:** fazer múltiplas requisições HTTP síncronas a cada clique trava a UI e falha sem internet.
- **Solução aplicada:**
  1. **Escrita otimista local-first:** toda ação salva primeiro no cache local (`SharedPreferences`) e atualiza a tela imediatamente (**0 ms de espera de rede**).
  2. **Sincronização assíncrona não-bloqueante:** `_syncInBackground()` usa `unawaited(pushToCloud())` para enviar o estado atualizado ao Supabase sem travar a Main Thread.
  3. **Consolidação em documento JSONB único (`public.user_app_data`):** em vez de disparar 6+ queries separadas (`profiles`, `subjects`, `notes`, `tasks`, `attendance`, `finance`) no login ou na troca de celular, o `pullFromCloud()` baixa **toda a conta em 1 única requisição** autenticada por RLS.

### Técnica 2 — Gerenciamento de Memória, CPU e Bateria (`notification_service.dart` + ciclo de vida)
- **Prevenção de Memory Leaks:**
  - Todos os `TextEditingController` e `StreamSubscription` (`_notificationSub`, `_authSub`) são liberados explicitamente em `dispose()`.
  - Uso consistente de `if (!mounted) return;` após operações assíncronas (`await`), evitando `setState` em widgets desmontados.
- **Zero polling em segundo plano (economia de bateria):**
  - Em vez de manter um `Timer` ou serviço rodando na CPU para disparar lembretes, delegamos o agendamento ao sistema operacional nativo via `zonedSchedule` + `ScheduledNotificationBootReceiver` no Android (`AlarmManager`).
- **Correção de gargalo crítico de CPU (bug real encontrado):**
  - Na versão inicial, o laço `while (scheduled.weekday != weekday || scheduled.hour > hour ...)` entrava em **loop infinito** quando o horário atual era maior que o horário da tarefa, travando a CPU e a UI Thread.
  - Reescrevemos `_nextInstanceOfWeekdayAndTime()` construindo a data-alvo no horário exato e avançando no máximo **7 iterações — O(1)**.

### Técnica 3 — Otimização de Interface (UI) e Renderização (`app_theme.dart` + `summary_screen.dart` + `agenda_screen.dart`)
- **Gráficos vetoriais leves via `CustomPainter`:** o logo (`_UniSyncMarkPainter`) e o gráfico donut de gastos (`_DonutChartPainter`) são desenhados diretamente na GPU via `Canvas` sem carregar bibliotecas pesadas de gráficos nem imagens PNG pesadas — e com `shouldRepaint` evitando redesenhos desnecessários.
- **Renderização preguiçosa e `const`:** uso de `ListView.separated` e `GridView.builder` (reciclagem/lazy building), construtores `const` para pular rebuilds no Flutter Element Tree e atualização direcionada entre abas com `ValueNotifier<int>` (`appRefreshNotifier`).
- **Fontes embutidas localmente:** `Plus Jakarta Sans` carregada direto dos assets do pacote, eliminando requisições HTTP extras de fontes e *layout shift* (FOUT) no Cold Start.

---

## Slide 7 — Métricas e Profiling: Antes vs. Depois (1,5 min)
### Comparativo real do projeto (Antes vs. Depois da refatoração)

| Métrica | Antes (Protótipo inicial) | Depois (UniSync otimizado) | Melhoria |
| :--- | :--- | :--- | :--- |
| **Tamanho do workspace** | ~1,36 GB (JDK embutido, projetos duplicados, builds) | ~5 MB de código + assets | **-99% de bloat** |
| **Estrutura do código** | 1 arquivo monolítico (3.088 linhas em `main.dart`) | 14 arquivos em camadas (`models/services/screens/theme`) | **Modular e testável** |
| **Erros estáticos (`flutter analyze`)** | Erro de compilação + 18+ avisos | **0 issues (`No issues found`)** | **100% limpo** |
| **Loop de agendamento (CPU)** | Loop infinito quando hora atual > hora da tarefa | Complexidade **O(1)** (máx. 7 passos) | **0 travamentos** |
| **Latência percebida ao clicar** | Bloqueio potencial / sem persistência real | **0 ms** (local-first + sync assíncrono em 1 query) | **UI instantânea** |
| **Testes automatizados (`flutter test`)** | Falhando por compile error e overflow | **5/5 testes passando em ~4s** | **Cobertura validada** |
| **Framerate & Render (Android 16 · Impeller Vulkan)** | Overflows e picos de CPU | **120 FPS médios · UI 0,5 ms / Raster 1,8 ms · p50/p95: 5 ms · p99: 8 ms** (627 frames) | **120 FPS (0,16% jank)** |
| **Consumo de Memória (DevTools / VM Service)** | Sem controle de `dispose()` | **Dart Heap: 20,7 MB** · Total Size: 20,8 MB · `SurfaceCard`: 1,9 KB | **Curva plana (0 leaks)** |
| **Otimização de Assets (Release APK)** | Fontes e ícones sem otimização | **MaterialIcons: 1,65 MB → 7,3 KB** (tree-shaking) | **-99,6% no peso dos ícones** |

### Slide 9 — Prints reais do Flutter DevTools (`evidencias/`)
- **Performance (`devtools_performance_120fps.png`):** **120 FPS (average)** em `arm64 (64 bit) android`, **Engine: Impeller**, frame destacado com **UI: 0,5 ms** e **Raster: 1,8 ms**, barras azuis estáveis entre 1 e 4 ms.
- **Memory (`devtools_memory_heap.png`):** curva totalmente plana no gráfico de memória, **Total Size: 20,8 MB** e **Dart Heap: 20,7 MB**, comprovando ausência de *memory leaks*.
- **Terminal (`evidencia_profiling_android16.png`):** `adb shell dumpsys gfxinfo` confirmando **627 frames**, **1 janky frame (0,16%)**, **p50/p90/p95 = 5 ms**, **p99 = 8 ms**, **GPU p50 = 2 ms / p99 = 4 ms**, além de `flutter analyze` (`0 issues`) e `flutter test` (`5/5 OK`).

---

## Slide 8 — Lições Aprendidas e Encerramento (30 seg)
- **Principal desafio técnico:** diagnosticar e corrigir o loop infinito no cálculo de agendamento das notificações + conciliar login OAuth Google / verificação de e-mail com sincronização offline-first sem bloquear a interface.
- **Próximos passos:**
  1. Migrar o cache local de `SharedPreferences` para banco relacional local (**SQLite/Drift**) com indexação para grandes volumes de anotações e lançamentos;
  2. Usar `Isolate` (`compute()`) para serialização/desserialização JSON em segundo plano quando o histórico crescer;
  3. Adicionar notificações push remotas e sincronização incremental (*delta sync*).
- **Encerramento:** *"Obrigado! Estamos abertos para perguntas."*
