// lib/navigation_service.dart
// ignore_for_file: unused_import, duplicate_ignore

import 'package:bjjapp/academy_notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';
import 'manager_module.dart';
import 'teacher_module.dart';
import 'student_module.dart';
import 'schedule_module.dart';
import 'scoreboard_module.dart';
import 'study_notebook_module.dart';
import 'training_log_module.dart';
import 'shop_module.dart';
import 'birthdays_module.dart';
import 'video_library_module.dart';
import 'rules_module.dart';
import 'manager_reports_page.dart';
import 'manager_units_module.dart';
import 'super_admin_module.dart';
import 'admin_dashboard_module.dart';
import 'admin_financial_page.dart';
import 'admin_notifications_page.dart';
import 'class_plan_module.dart';
import 'features.dart';
import 'strength_training_module.dart';
import 'student_ranking_page.dart';

/// Representa um módulo ou tela principal do aplicativo.
class AppModule {
  final String id;
  final String title;
  final IconData icon;
  final List<UserRole>? requiredRoles;
  final Widget Function(
      UserModel, List<UserModel>, List<Aluno>, SubscriptionPlan?)? pageBuilder;
  final List<AppModule>? subModules;
  final String? requiredFeature;

  AppModule({
    required this.id,
    required this.title,
    required this.icon,
    this.requiredRoles,
    this.pageBuilder,
    this.subModules,
    this.requiredFeature,
  });
}

/// Serviço para gerenciar os módulos e as configurações de navegação do usuário.
class NavigationService {
  final String userId;
  final UserRole userRole;
  final SubscriptionPlan? currentPlan;

  NavigationService({
    required this.userId,
    required this.userRole,
    this.currentPlan,
  });

  CollectionReference get _tabSettingsCollection => FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('tab_settings');

  // Função de filtro permanece a mesma, mas com adição de lógica anti-superadmin
  List<AppModule> _filterModules(List<AppModule> allModules) {
    List<AppModule> filtered = [];
    for (var module in allModules) {
      bool canViewByRole = module.requiredRoles == null ||
          module.requiredRoles!.contains(userRole);

      // --- Adicionada lógica específica para Manager/Teacher/Student não verem SuperAdmin ---
      if (userRole != UserRole.superAdmin &&
          (module.requiredRoles?.contains(UserRole.superAdmin) ?? false)) {
        canViewByRole = false;
      }
      // --- Fim da adição ---

      if (userRole == UserRole.manager) {
        const hiddenForManager = [
          'student_profile', // Item dentro de Painel Pessoal
          'teacher_dashboard',
          'teacher_students', // Alunos (Prof)
        ];
        if (hiddenForManager.contains(module.id)) {
          canViewByRole = false;
        }
      }

      if (userRole == UserRole.teacher) {
        const hiddenForTeacher = [
          'manager_dashboard',
          'manager_financial_group', // Grupo Financeiro
          'manager_fees', // Subitem Financeiro
          'manager_reports', // Subitem Financeiro
          'manager_students', // Alunos (Ger)
          'manager_teachers', // Professores
          'manager_units', // Unidades
          'student_profile', // Item dentro de Painel Pessoal
        ];
        if (hiddenForTeacher.contains(module.id)) {
          canViewByRole = false;
        }
      }

      if (userRole == UserRole.student) {
        const hiddenForStudent = [
          'manager_dashboard',
          'teacher_dashboard',
          'manager_financial_group', // Grupo Financeiro
          'manager_fees', // Subitem Financeiro
          'manager_reports', // Subitem Financeiro
          'teacher_checkin', // Check-in
          'academy_notifications', // Comunicados
          'academy_class_plan', // Plano de Aulas
          'teacher_students', // Alunos (Prof)
          'manager_students', // Alunos (Ger)
          'manager_teachers', // Professores
          'manager_units', // Unidades
          'teacher_sparring', // Sorteio
        ];
        if (hiddenForStudent.contains(module.id)) {
          canViewByRole = false;
        }
      }

      if (userRole == UserRole.superAdmin) {
        if (module.requiredRoles == null ||
            !module.requiredRoles!.contains(UserRole.superAdmin)) {
          canViewByRole = false;
        }
      }

      bool canViewByFeature = true;
      if (module.requiredFeature != null) {
        canViewByFeature =
            currentPlan?.features[module.requiredFeature] ?? false;
      }

      if (canViewByRole && canViewByFeature) {
        AppModule newModule = module;
        if (module.subModules != null) {
          final filteredSubModules = _filterModules(module.subModules!);
          // Só adiciona o módulo pai (mesmo sem pageBuilder) se ele tiver submódulos VÃLIDOS
          // Isso é importante para a estrutura do Drawer
          if (filteredSubModules.isNotEmpty) {
            newModule = AppModule(
              id: module.id,
              title: module.title,
              icon: module.icon,
              requiredRoles: module.requiredRoles,
              pageBuilder: module.pageBuilder, // Mantém nulo se for o caso
              subModules: filteredSubModules,
              requiredFeature: module.requiredFeature,
            );
            filtered.add(newModule);
          }
          // Adiciona o módulo pai mesmo sem submódulos VÃLIDOS, SE ele tiver um pageBuilder próprio
          else if (module.pageBuilder != null) {
            filtered.add(newModule);
          }
        }
        // Adiciona se não tiver submódulos E tiver pageBuilder
        else if (module.pageBuilder != null) {
          filtered.add(newModule);
        }
      }
    }
    return filtered;
  }

  List<AppModule> getDrawerModulesForCurrentUser() {
    // Usa a função de filtro diretamente
    List<AppModule> filtered = _filterModules(_getAllPossibleModules());

    // A lógica de ordenação específica do Drawer permanece
    AppModule? inicioModule;
    try {
      if (userRole == UserRole.student) {
        // Procura pelo ID específico do perfil do aluno dentro do Painel Pessoal
        inicioModule = filtered
            .firstWhere((m) => m.id == 'personal_panel_group')
            .subModules
            ?.firstWhere((sub) => sub.id == 'student_profile');
      } else if (userRole == UserRole.teacher) {
        inicioModule = filtered.firstWhere((m) => m.id == 'teacher_dashboard',
            orElse: () => throw Exception());
      } else if (userRole == UserRole.manager) {
        inicioModule = filtered.firstWhere((m) => m.id == 'manager_dashboard',
            orElse: () => throw Exception());
      } else if (userRole == UserRole.superAdmin) {
        inicioModule = filtered.firstWhere(
            (m) => m.id == 'superadmin_dashboard',
            orElse: () => throw Exception());
      }
    } catch (e) {
      // Fallback mais robusto: Pega o primeiro módulo com pageBuilder
      try {
        inicioModule = filtered.firstWhere((m) => m.pageBuilder != null);
      } catch (e) {
        inicioModule =
            filtered.isNotEmpty ? filtered.first : null; // Ãšltimo caso
      }
    }

    final otherModules =
        filtered.where((m) => m.id != inicioModule?.id).toList();
    // Remove explicitamente o grupo 'Painel Pessoal' da ordenação principal do drawer se o 'Meu Perfil' do aluno foi movido para o início
    if (userRole == UserRole.student && inicioModule?.id == 'student_profile') {
      otherModules.removeWhere((m) => m.id == 'personal_panel_group');
    }

    otherModules.sort((a, b) => a.title.compareTo(b.title));

    final List<AppModule> sortedList = [];
    if (inicioModule != null) sortedList.add(inicioModule);
    sortedList.addAll(otherModules);

    return sortedList; // Retorna a lista hierárquica e ordenada para o Drawer
  }

  // --- FUNÇÃO CORRIGIDA NOVAMENTE ---
  List<AppModule> getFlatPageModulesForCurrentUser() {
    final List<AppModule> flatList = [];
    // 1. Pega TODOS os módulos possíveis
    final List<AppModule> allPossibleModules = _getAllPossibleModules();
    // 2. Filtra hierarquicamente baseado em role e plano
    final List<AppModule> filteredHierarchicalList =
        _filterModules(allPossibleModules);

    // 3. Função recursiva para achatar a lista filtrada, pegando apenas itens com pageBuilder
    void flatten(List<AppModule> modules) {
      for (final module in modules) {
        // Adiciona Ã  lista plana APENAS se tiver uma tela associada
        if (module.pageBuilder != null) {
          // Evita adicionar módulos 'placeholder' de início que não são o do usuário atual
          if (!(['manager_dashboard', 'teacher_dashboard', 'student_profile']
                  .contains(module.id) &&
              module.id != _getHomeModuleIdForCurrentUser())) {
            flatList.add(module);
          } else if (module.id == _getHomeModuleIdForCurrentUser()) {
            flatList.add(module); // Adiciona o módulo de início correto
          }
        }
        // Se tiver submódulos, chama a função recursivamente para eles
        if (module.subModules != null) {
          flatten(module.subModules!);
        }
      }
    }

    // 4. Inicia o processo de achatamento
    flatten(filteredHierarchicalList);

    // 5. Retorna a lista plana final
    return flatList;
  }

  // Helper para obter o ID do módulo de início correto
  String _getHomeModuleIdForCurrentUser() {
    switch (userRole) {
      case UserRole.manager:
        return 'manager_dashboard';
      case UserRole.teacher:
        return 'teacher_dashboard';
      case UserRole.student:
        return 'student_profile';
      case UserRole.superAdmin:
        return 'superadmin_dashboard';
      default:
        return ''; // Ou um fallback razoável
    }
  }

  // --- _getAllPossibleModules() com IDs de grupo distintos ---
  List<AppModule> _getAllPossibleModules() {
    // Os módulos de Início agora ficam fora dos grupos para facilitar a lógica
    final managerHome = AppModule(
      id: 'manager_dashboard',
      title: 'Início', // Título genérico para aba/drawer
      icon: Icons.dashboard_rounded,
      requiredRoles: [UserRole.manager],
      pageBuilder: (user, teachers, students, plan) =>
          ManagerDashboardPage(user: user),
    );
    final teacherHome = AppModule(
      id: 'teacher_dashboard',
      title: 'Início', // Título genérico para aba/drawer
      icon: Icons.dashboard_rounded,
      requiredRoles: [UserRole.teacher],
      pageBuilder: (user, teachers, students, plan) => TeacherDashboardPage(
        user: user,
        isSparringMode: false, // Será atualizado pelo listener
        onNavigateToSparring: () {}, // Será passado corretamente na HomePage
        todosParticipantesDaAcademia: students,
      ),
    );
    final studentHome = AppModule(
      // Módulo do aluno movido para cá
      id: 'student_profile',
      title: 'Meu Perfil', // Renomeado para clareza no Drawer/Tabs
      icon: Icons.account_circle_rounded,
      requiredRoles: [UserRole.student],
      pageBuilder: (user, teachers, students, plan) =>
          UserProfilePage(user: user, hasScaffold: false),
    );

    return [
      // Módulos do Super Admin (continuam iguais)
      AppModule(
        id: 'superadmin_dashboard',
        title: 'Dashboard',
        icon: Icons.dashboard_rounded,
        requiredRoles: [UserRole.superAdmin],
        pageBuilder: (user, teachers, students, plan) =>
            const AdminDashboardPage(),
      ),
      AppModule(
        id: 'superadmin_financial',
        title: 'Financeiro',
        icon: Icons.monetization_on_outlined,
        requiredRoles: [UserRole.superAdmin],
        pageBuilder: (user, teachers, students, plan) =>
            const AdminFinancialPage(),
      ),
      AppModule(
        id: 'superadmin_academies',
        title: 'Academias',
        icon: Icons.business_rounded,
        requiredRoles: [UserRole.superAdmin],
        pageBuilder: (user, teachers, students, plan) =>
            const AcademyListPage(),
      ),
      AppModule(
        id: 'superadmin_notifications',
        title: 'Comunicados',
        icon: Icons.campaign_rounded,
        requiredRoles: [UserRole.superAdmin],
        pageBuilder: (user, teachers, students, plan) =>
            const AdminNotificationsPage(),
      ),
      AppModule(
        id: 'superadmin_plans',
        title: 'Planos',
        icon: Icons.star_border_rounded,
        requiredRoles: [UserRole.superAdmin],
        pageBuilder: (user, teachers, students, plan) => const AdminPlansPage(),
      ),
      AppModule(
        id: 'superadmin_videos',
        title: 'Vídeos',
        icon: Icons.video_library_outlined,
        requiredRoles: [UserRole.superAdmin],
        pageBuilder: (user, teachers, students, plan) => const VideoAuditPage(),
      ),
      AppModule(
        id: 'superadmin_tutorials',
        title: 'Tutoriais',
        icon: Icons.help_outline_rounded,
        requiredRoles: [UserRole.superAdmin],
        pageBuilder: (user, teachers, students, plan) =>
            const TutorialsAdminPage(),
      ),

      // Módulos de Início (separados para clareza)
      managerHome,
      teacherHome,
      studentHome,

      // Módulo Pai Financeiro (Gerente)
      AppModule(
        id: 'manager_financial_group', // ID de grupo
        title: 'Financeiro',
        icon: Icons.monetization_on_rounded,
        requiredRoles: [UserRole.manager], // Só gerente acessa grupo financeiro
        requiredFeature: 'financial_reports', // Feature no grupo
        subModules: [
          AppModule(
            id: 'manager_fees',
            title: 'Mensalidades',
            icon: Icons.request_quote_outlined,
            // Herda requiredRoles e requiredFeature do pai (implicitamente pela filtragem)
            pageBuilder: (user, teachers, students, plan) =>
                MonthlyFeeManagerPage(academyId: user.academyId),
          ),
          AppModule(
            id: 'manager_reports',
            title: 'Relatórios',
            icon: Icons.bar_chart_rounded,
            // Herda requiredRoles e requiredFeature do pai
            pageBuilder: (user, teachers, students, plan) =>
                ManagerReportsPage(user: user),
          ),
        ]..sort((a, b) => a.title.compareTo(b.title)),
      ),

      // Módulo Pai Academia (Comum)
      AppModule(
        id: 'common_academy_group', // ID de grupo
        title: 'Academia',
        icon: Icons.business_rounded,
        // Roles que podem ver *algum* item dentro de Academia
        requiredRoles: [UserRole.manager, UserRole.teacher, UserRole.student],
        subModules: [
          AppModule(
            id: 'common_birthdays',
            title: 'Aniversários',
            icon: Icons.cake_rounded,
            // Todos podem ver aniversários
            requiredRoles: [
              UserRole.manager,
              UserRole.teacher,
              UserRole.student
            ],
            pageBuilder: (user, teachers, students, plan) =>
                BirthdaysPage(academyId: user.academyId, currentUser: user),
          ),
          AppModule(
            id: 'student_ranking',
            title: 'Ranking',
            icon: Icons.emoji_events_rounded,
            requiredRoles: [UserRole.student],
            pageBuilder: (user, teachers, students, plan) => StudentRankingPage(
              user: user,
              students: students,
              teachers: teachers,
            ),
          ),
          AppModule(
            id: 'teacher_checkin',
            title: 'Check-in',
            icon: Icons.check_circle_outline_rounded,
            requiredRoles: [
              UserRole.teacher
            ], // Só professor faz check-in por aqui
            pageBuilder: (user, teachers, students, plan) => CheckinTeacherPage(
                user: user,
                academyId: user.academyId,
                todosParticipantesDaAcademia: students),
          ),
          AppModule(
            id: 'academy_notifications',
            title: 'Comunicados',
            icon: Icons.campaign_outlined,
            requiredRoles: [
              UserRole.manager,
              UserRole.teacher
            ], // Manager e Teacher podem enviar
            pageBuilder: (user, teachers, students, plan) =>
                AcademyNotificationsPage(user: user),
          ),
          AppModule(
            id: 'common_schedule',
            title: 'Grade',
            icon: Icons.calendar_month_rounded,
            // Todos podem ver a grade
            requiredRoles: [
              UserRole.manager,
              UserRole.teacher,
              UserRole.student
            ],
            pageBuilder: (user, teachers, students, plan) =>
                SchedulePage(user: user, teachers: teachers),
          ),
          AppModule(
            id: 'academy_class_plan',
            title: 'Plano de Aulas',
            icon: Icons.edit_calendar_rounded,
            requiredRoles: [UserRole.manager, UserRole.teacher],
            requiredFeature: 'class_plan_module',
            pageBuilder: (user, teachers, students, plan) =>
                ClassPlanPage(user: user, currentPlan: plan),
          ),
          AppModule(
            id: 'teacher_students',
            // --- CORREÇÃO DO TÃTULO ---
            title: 'Alunos',
            // --- FIM DA CORREÇÃO ---
            icon: Icons.people_alt_rounded,
            requiredRoles: [UserRole.teacher],
            pageBuilder: (user, teachers, students, plan) =>
                AlunosTeacherPage(academyId: user.academyId, teacher: user),
          ),
          AppModule(
            id: 'manager_students',
            // --- CORREÇÃO DO TÃTULO ---
            title: 'Alunos',
            // --- FIM DA CORREÇÃO ---
            icon: Icons.people_alt_rounded,
            requiredRoles: [UserRole.manager],
            pageBuilder: (user, teachers, students, plan) =>
                AlunosManagerPage(academyId: user.academyId, manager: user),
          ),
          AppModule(
            id: 'manager_teachers',
            title: 'Professores',
            icon: Icons.school_rounded,
            requiredRoles: [UserRole.manager],
            pageBuilder: (user, teachers, students, plan) =>
                ProfessoresManagerPage(
                    academyId: user.academyId, manager: user),
          ),
          AppModule(
            id: 'manager_units',
            title: 'Unidades',
            icon: Icons.store_mall_directory_outlined,
            requiredRoles: [UserRole.manager],
            pageBuilder: (user, teachers, students, plan) =>
                ManageUnitsPage(academyId: user.academyId, manager: user),
          ),
        ]..sort((a, b) => a.title.compareTo(b.title)),
      ),

      // Módulo Pai Painel Pessoal
      AppModule(
        id: 'personal_panel_group', // ID de grupo
        title: 'Painel Pessoal',
        icon: Icons.person_rounded,
        requiredRoles: [UserRole.student, UserRole.teacher, UserRole.manager],
        subModules: [
          AppModule(
            id: 'common_training_log',
            title: 'Diário de Treinos',
            icon: Icons.auto_stories_outlined,
            // Todos podem ter diário
            requiredRoles: [
              UserRole.student,
              UserRole.teacher,
              UserRole.manager
            ],
            pageBuilder: (user, teachers, students, plan) =>
                TrainingLogPage(user: user),
          ),
          AppModule(
            id: 'common_notebook',
            title: 'Caderno de Estudos',
            icon: Icons.book_rounded,
            requiredFeature: 'study_notebook',
            // Todos podem ter caderno se a feature estiver ativa
            requiredRoles: [
              UserRole.student,
              UserRole.teacher,
              UserRole.manager
            ],
            pageBuilder: (user, teachers, students, plan) =>
                StudyNotebookPage(userId: user.uid, currentPlan: plan),
          ),
          AppModule(
            id: 'common_history',
            title: 'Meu Histórico', // Histórico de checkins/graduações
            icon: Icons.calendar_today_rounded,
            requiredRoles: [
              UserRole.teacher,
              UserRole.student
            ], // Só aluno/prof tem checkin/graduação assim
            pageBuilder: (user, teachers, students, plan) =>
                MyCheckinsPage(user: user),
          ),
          // O Módulo de Perfil do Aluno foi movido para fora como `studentHome`
        ]..sort((a, b) => a.title.compareTo(b.title)),
      ),

      // Módulo Pai Ferramentas
      AppModule(
        id: 'common_tools_group', // ID de grupo
        title: 'Ferramentas',
        icon: Icons.construction_rounded,
        // Roles que podem ver *alguma* ferramenta
        requiredRoles: [UserRole.manager, UserRole.teacher, UserRole.student],
        subModules: [
          AppModule(
            id: 'common_rules',
            title: 'Livro de Regras',
            icon: Icons.gavel_rounded,
            requiredFeature: 'rules_module',
            // Todos podem ver regras se a feature estiver ativa
            requiredRoles: [
              UserRole.manager,
              UserRole.teacher,
              UserRole.student
            ],
            pageBuilder: (user, teachers, students, plan) =>
                RulesPage(user: user, currentPlan: plan),
          ),
          AppModule(
            id: 'common_scoreboard',
            title: 'Placar',
            icon: Icons.scoreboard_rounded,
            requiredFeature: 'scoreboard_module',
            // Todos podem usar placar se a feature estiver ativa
            requiredRoles: [
              UserRole.manager,
              UserRole.teacher,
              UserRole.student
            ],
            pageBuilder: (user, teachers, students, plan) => MatchSetupPage(
                user: user,
                academyId: user.academyId,
                todosAlunosDaAcademia: students,
                currentPlan: plan),
          ),
          AppModule(
            id: 'teacher_sparring',
            title: 'Sorteio de Treinos',
            icon: Icons.shuffle_rounded,
            requiredRoles: [
              UserRole.teacher,
              UserRole.manager
            ], // Só prof/gerente sorteia
            requiredFeature: 'sparring_draw',
            pageBuilder: (user, teachers, students, plan) => SorteioTeacherPage(
              user: user,
              academyId: user.academyId,
              todosParticipantesDaAcademia: students,
              isSparringMode: false,
              onIniciarSparring: (rounds, type, participants) {},
              onCheckinAlunos: (students) {},
            ),
          ),
          AppModule(
            id: 'strength_training',
            title: 'Musculação',
            icon: Icons.fitness_center,
            requiredFeature: 'strength_training_module',
            // Todos podem usar musculação se a feature estiver ativa
            requiredRoles: [
              UserRole.manager,
              UserRole.teacher,
              UserRole.student
            ],
            pageBuilder: (user, teachers, students, plan) =>
                StrengthTrainingPage(user: user),
          ),
        ]..sort((a, b) => a.title.compareTo(b.title)),
      ),

      // Módulos independentes (sem grupo pai visível no drawer)
      AppModule(
        id: 'common_video_aulas',
        title: 'Videoaulas',
        icon: Icons.video_library_rounded,
        requiredFeature: 'video_library',
        // Todos podem ver videoaulas se a feature estiver ativa
        requiredRoles: [UserRole.manager, UserRole.teacher, UserRole.student],
        pageBuilder: (user, teachers, students, plan) =>
            VideoLibraryPage(user: user, currentPlan: plan),
      ),
      AppModule(
        id: 'common_shop',
        title: 'Loja',
        icon: Icons.storefront_rounded,
        requiredFeature: 'shop_module',
        // Todos podem ver a loja se a feature estiver ativa
        requiredRoles: [UserRole.manager, UserRole.teacher, UserRole.student],
        pageBuilder: (user, teachers, students, plan) =>
            ShopPage(user: user, currentPlan: plan),
      ),
    ];
  }

  // --- getDefaultTabSettings() ajustado ---
  Map<String, dynamic> getDefaultTabSettings() {
    List<String> defaultVisibleIds;
    // Pega todos os módulos *já achatados e filtrados* para este usuário
    final availableFlatModules = getFlatPageModulesForCurrentUser();
    final allAvailableIds = availableFlatModules.map((m) => m.id).toList();

    switch (userRole) {
      case UserRole.superAdmin:
        defaultVisibleIds = [
          'superadmin_dashboard',
          'superadmin_financial',
          'superadmin_academies',
          'superadmin_plans',
          'superadmin_tutorials',
        ];
        break;
      case UserRole.manager:
        defaultVisibleIds = [
          'manager_dashboard', // Início (Gerente)
          'manager_students', // Alunos
          'manager_fees', // Mensalidades
          'common_schedule', // Grade
          'common_training_log', // Diário
        ];
        break;
      case UserRole.teacher:
        defaultVisibleIds = [
          'teacher_dashboard', // Início (Professor)
          'teacher_checkin', // Check-in
          'common_schedule', // Grade
          'academy_class_plan', // Plano de Aulas
          'common_training_log', // Diário
        ];
        break;
      case UserRole.student:
      default:
        defaultVisibleIds = [
          'student_profile', // Meu Perfil
          'common_schedule', // Grade
          'common_training_log', // Diário
          'common_shop', // Loja
          'common_video_aulas', // Videoaulas
        ];
        break;
    }

    // Garante que os IDs padrão realmente existam nos módulos disponíveis e limita a 5
    final validDefaultVisibleIds = defaultVisibleIds
        .where((id) => allAvailableIds.contains(id))
        .take(5)
        .toList();

    // Se, após a validação, a lista ficar vazia, adiciona o primeiro módulo disponível (que é o de Início)
    if (validDefaultVisibleIds.isEmpty && allAvailableIds.isNotEmpty) {
      validDefaultVisibleIds.add(allAvailableIds.first);
    }

    // A ordem inicial ('order') deve conter TODOS os módulos disponíveis para o usuário
    final initialOrder = allAvailableIds;

    return {
      'order': initialOrder,
      'visible': validDefaultVisibleIds,
    };
  }

  // --- saveTabSettings() e getTabSettingsStream() com validação ---
  Future<void> saveTabSettings(List<String> newOrder, List<String> newVisible) {
    // Garante que apenas IDs existentes sejam salvos
    final allAvailableIds =
        getFlatPageModulesForCurrentUser().map((m) => m.id).toSet();
    final validOrder =
        newOrder.where((id) => allAvailableIds.contains(id)).toList();
    final validVisible =
        newVisible.where((id) => allAvailableIds.contains(id)).take(5).toList();

    // Adiciona módulos faltantes ao final da ordem, se necessário
    for (var id in allAvailableIds) {
      if (!validOrder.contains(id)) {
        validOrder.add(id);
      }
    }

    return _tabSettingsCollection.doc('user_prefs').set({
      'order': validOrder, // Salva a ordem validada e completa
      'visible': validVisible, // Salva os visíveis validados e limitados
    });
  }

  Stream<DocumentSnapshot> getTabSettingsStream() {
    return _tabSettingsCollection.doc('user_prefs').snapshots();
  }
}
