AULA 1: Fundamentos e Persistência Local com SQLite

Este mini-projeto contém o código e o roteiro para a Aula 1.

Objetivos
- Configurar projeto Flutter
- Implementar modelo de dados
- Criar serviço de banco de dados SQLite
- Desenvolver CRUD básico

Como usar
1. Abra a pasta `lab05-flutter/task_manager`.
2. Rode:

```bash
flutter pub get
flutter run
```

Arquivos principais
- `lib/models/task.dart` - modelo Task
- `lib/services/database_service.dart` - serviço SQLite (sqflite)
- `lib/screens/task_list_screen.dart` - UI com CRUD
- `lib/main.dart` - ponto de entrada

Roteiro da aula (90min) - prática
1. Setup inicial: `flutter create task_manager` (ou abrir esta pasta)
2. Dependências: explicar `sqflite`, `path_provider`, `path`, `uuid`, `intl`.
3. Modelo: mostrar `Task` e métodos `toMap`/`fromMap`.
4. DatabaseService: singleton, `_initDB`, `_createDB`, e métodos CRUD.
5. UI: `TaskListScreen` com listagem, adicionar, marcar/completar, excluir.
6. Exercícios: implementar prioridade via dropdown, filtro por status, contador de tarefas.

Comentários
- Os exemplos aqui são intencionados para uso em sala; adaptar nomes e estilos conforme necessário.
