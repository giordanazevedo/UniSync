# ControlApp Flutter

Aplicativo Flutter e Dart.

## Estrutura

- `lib/main.dart` — aplicação, telas, tema e componentes.
- `test/widget_test.dart` — testes de interface.
- `pubspec.yaml` — dependências e configuração Flutter.
- `analysis_options.yaml` — regras estáticas.

## Comandos

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Se as pastas de plataforma ainda não existirem:

```bash
flutter create --platforms=android,ios,web .
```

Não adicionar dependências de React, Next.js, Payload ou Node.js.
