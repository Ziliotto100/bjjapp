// lib/features.dart

/// Contém as chaves e nomes de todas as funcionalidades controláveis
/// pelos planos de assinatura. Centralizar isso em um só lugar
/// evita erros de digitação e facilita a adição de novas features no futuro.
class AppFeatures {
  /// O mapa de funcionalidades disponíveis.
  /// A 'key' é o identificador único que será salvo no Firestore.
  /// O 'value' é o nome amigável que será exibido na interface do Super Admin.
  static const Map<String, String> availableFeatures = {
    'video_library': 'Videoteca (Alunos e Professores)',
    'financial_reports': 'Relatórios Financeiros (Gerente)',
    'class_plan_module': 'Plano de Aulas (Gerente e Professores)',
    'shop_module': 'Loja Virtual (Todos)',
    'sparring_draw': 'Sorteio de Treinos (Gerente e Professores)',
    'study_notebook': 'Caderno de Estudos (Alunos e Professores)',
    'rules_module': 'Livro de Regras (Ferramentas)', // NOVO
    'scoreboard_module': 'Placar (Ferramentas)', // NOVO
    // Adicione futuras funcionalidades premium aqui. Por exemplo:
    // 'event_management': 'Módulo de Eventos',
  };
}
