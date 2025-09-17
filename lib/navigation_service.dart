// lib/navigation_service.dart
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

/// Representa um módulo ou tela principal do aplicativo.
class AppModule {
  final String id;
  final String title;
  final IconData icon;
  final List<UserRole>? requiredRoles;
  final Widget Function(UserModel, List<UserModel>, List<Aluno>)? pageBuilder;
  final List<AppModule>? subModules;

  AppModule({
    required this.id,
    required this.title,
    required this.icon,
    this.requiredRoles,
    this.pageBuilder,
    this.subModules,
  });
}

/// Serviço para gerenciar os módulos e as configurações de navegação do usuário.
class NavigationService {
  final String userId;
  final UserRole userRole;

  NavigationService({required this.userId, required this.userRole});

  CollectionReference get _tabSettingsCollection => FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('tab_settings');

  List<AppModule> _filterModules(List<AppModule> allModules) {
    List<AppModule> filtered = [];
    for (var module in allModules) {
      bool canView = module.requiredRoles == null ||
          module.requiredRoles!.contains(userRole);

      if (userRole == UserRole.superAdmin) {
        if (module.requiredRoles == null ||
            !module.requiredRoles!.contains(UserRole.superAdmin)) {
          canView = false;
        }
      }

      if (userRole == UserRole.manager) {
        const hiddenForManager = [
          'student_profile',
          'student_history',
          'teacher_history',
          'teacher_dashboard',
          'teacher_students',
          'student_progress'
        ];
        if (hiddenForManager.contains(module.id)) {
          canView = false;
        }
      }

      if (canView) {
        AppModule newModule = module;
        if (module.subModules != null) {
          final filteredSubModules = _filterModules(module.subModules!);
          newModule = AppModule(
            id: module.id,
            title: module.title,
            icon: module.icon,
            requiredRoles: module.requiredRoles,
            pageBuilder: module.pageBuilder,
            subModules: filteredSubModules,
          );
        }
        filtered.add(newModule);
      }
    }
    return filtered;
  }

  List<AppModule> getDrawerModulesForCurrentUser() {
    final all = _getAllPossibleModules();
    return _filterModules(all);
  }

  List<AppModule> getFlatPageModulesForCurrentUser() {
    final List<AppModule> flatList = [];
    final hierarchicalList = getDrawerModulesForCurrentUser();

    for (final module in hierarchicalList) {
      if (module.pageBuilder != null) {
        flatList.add(module);
      }
      if (module.subModules != null) {
        for (final subModule in module.subModules!) {
          if (subModule.pageBuilder != null) {
            flatList.add(subModule);
          }
        }
      }
    }
    return flatList;
  }

  List<AppModule> _getAllPossibleModules() {
    return [
      // ===================================
      // MÓDULOS DO SUPER ADMIN
      // ===================================
      AppModule(
        id: 'superadmin_dashboard',
        title: 'Dashboard',
        icon: Icons.dashboard_rounded,
        requiredRoles: [UserRole.superAdmin],
        pageBuilder: (user, teachers, students) => const AdminDashboardPage(),
      ),
      AppModule(
        id: 'superadmin_financial',
        title: 'Financeiro',
        icon: Icons.monetization_on_outlined,
        requiredRoles: [UserRole.superAdmin],
        pageBuilder: (user, teachers, students) => const AdminFinancialPage(),
      ),
      AppModule(
        id: 'superadmin_academies',
        title: 'Academias',
        icon: Icons.business_rounded,
        requiredRoles: [UserRole.superAdmin],
        pageBuilder: (user, teachers, students) => const AcademyListPage(),
      ),
      AppModule(
        id: 'superadmin_notifications',
        title: 'Comunicados',
        icon: Icons.campaign_rounded,
        requiredRoles: [UserRole.superAdmin],
        pageBuilder: (user, teachers, students) =>
            const AdminNotificationsPage(),
      ),
      AppModule(
        id: 'superadmin_videos',
        title: 'Vídeos',
        icon: Icons.video_library_outlined,
        requiredRoles: [UserRole.superAdmin],
        pageBuilder: (user, teachers, students) => const VideoAuditPage(),
      ),
      AppModule(
        id: 'superadmin_tutorials',
        title: 'Tutoriais',
        icon: Icons.help_outline_rounded,
        requiredRoles: [UserRole.superAdmin],
        pageBuilder: (user, teachers, students) => const TutorialsAdminPage(),
      ),

      // ===================================
      // MÓDULOS DO GERENTE
      // ===================================
      AppModule(
        id: 'manager_dashboard',
        title: 'Início',
        icon: Icons.dashboard_rounded,
        requiredRoles: [UserRole.manager],
        pageBuilder: (user, teachers, students) =>
            ManagerDashboardPage(user: user),
      ),
      AppModule(
          id: 'manager_financial',
          title: 'Financeiro',
          icon: Icons.monetization_on_rounded,
          requiredRoles: [
            UserRole.manager
          ],
          subModules: [
            AppModule(
              id: 'manager_fees',
              title: 'Mensalidades',
              icon: Icons.request_quote_outlined,
              requiredRoles: [UserRole.manager],
              pageBuilder: (user, teachers, students) =>
                  MonthlyFeeManagerPage(academyId: user.academyId),
            ),
            AppModule(
              id: 'manager_reports',
              title: 'Relatórios',
              icon: Icons.bar_chart_rounded,
              requiredRoles: [UserRole.manager],
              pageBuilder: (user, teachers, students) =>
                  ManagerReportsPage(user: user),
            ),
          ]),
      AppModule(
        id: 'common_academy',
        title: 'Academia',
        icon: Icons.business_rounded,
        subModules: [
          AppModule(
            id: 'academy_notifications',
            title: 'Comunicados',
            icon: Icons.campaign_outlined,
            requiredRoles: [UserRole.manager, UserRole.teacher],
            pageBuilder: (user, teachers, students) =>
                AcademyNotificationsPage(user: user),
          ),
          AppModule(
            id: 'common_schedule',
            title: 'Grade',
            icon: Icons.calendar_month_rounded,
            pageBuilder: (user, teachers, students) =>
                SchedulePage(user: user, teachers: teachers),
          ),
          AppModule(
            id: 'manager_students',
            title: 'Alunos',
            icon: Icons.people_alt_rounded,
            requiredRoles: [UserRole.manager],
            pageBuilder: (user, teachers, students) =>
                AlunosManagerPage(academyId: user.academyId, manager: user),
          ),
          AppModule(
            id: 'manager_teachers',
            title: 'Professores',
            icon: Icons.school_rounded,
            requiredRoles: [UserRole.manager],
            pageBuilder: (user, teachers, students) => ProfessoresManagerPage(
                academyId: user.academyId, manager: user),
          ),
          AppModule(
            id: 'manager_units',
            title: 'Gerenciar Unidades',
            icon: Icons.store_mall_directory_outlined,
            requiredRoles: [UserRole.manager],
            pageBuilder: (user, teachers, students) =>
                ManageUnitsPage(academyId: user.academyId, manager: user),
          ),
          AppModule(
            id: 'teacher_students',
            title: 'Alunos',
            icon: Icons.people_alt_rounded,
            requiredRoles: [UserRole.teacher],
            pageBuilder: (user, teachers, students) =>
                AlunosTeacherPage(academyId: user.academyId, teacher: user),
          ),
          AppModule(
            id: 'teacher_checkin',
            title: 'Check-in',
            icon: Icons.check_circle_outline_rounded,
            requiredRoles: [UserRole.teacher],
            pageBuilder: (user, teachers, students) => CheckinTeacherPage(
                user: user,
                academyId: user.academyId,
                todosParticipantesDaAcademia: students),
          ),
          AppModule(
            id: 'common_birthdays',
            title: 'Aniversários',
            icon: Icons.cake_rounded,
            pageBuilder: (user, teachers, students) =>
                BirthdaysPage(academyId: user.academyId, currentUser: user),
          ),
        ],
      ),
      // +++ INÍCIO DA MODIFICAÇÃO +++
      AppModule(
          id: 'personal_development',
          title: 'Evolução Pessoal',
          icon: Icons.insights_rounded,
          subModules: [
            AppModule(
              id: 'common_training_log',
              title: 'Diário de Treinos',
              icon: Icons.auto_stories_outlined,
              pageBuilder: (user, teachers, students) =>
                  TrainingLogPage(user: user),
            ),
            AppModule(
              id: 'common_notebook',
              title: 'Caderno de Estudos',
              icon: Icons.book_rounded,
              pageBuilder: (user, teachers, students) =>
                  StudyNotebookPage(userId: user.uid),
            ),
          ]),
      // +++ FIM DA MODIFICAÇÃO +++
      AppModule(
          id: 'common_tools',
          title: 'Ferramentas',
          icon: Icons.construction_rounded,
          subModules: [
            AppModule(
              id: 'teacher_sparring',
              title: 'Sorteio de Treinos',
              icon: Icons.shuffle_rounded,
              requiredRoles: [UserRole.teacher, UserRole.manager],
              pageBuilder: (user, teachers, students) => SorteioTeacherPage(
                user: user,
                academyId: user.academyId,
                todosParticipantesDaAcademia: students,
                isSparringMode: false,
                onIniciarSparring: (rounds, type, participants) {},
                onCheckinAlunos: (students) {},
              ),
            ),
            AppModule(
              id: 'common_scoreboard',
              title: 'Placar',
              icon: Icons.scoreboard_rounded,
              pageBuilder: (user, teachers, students) => MatchSetupPage(
                  user: user,
                  academyId: user.academyId,
                  todosAlunosDaAcademia: students),
            ),
            AppModule(
              id: 'common_rules',
              title: 'Livro de Regras',
              icon: Icons.gavel_rounded,
              pageBuilder: (user, teachers, students) => RulesPage(user: user),
            ),
          ]),

      // Módulos do Professor
      AppModule(
        id: 'teacher_dashboard',
        title: 'Início',
        icon: Icons.dashboard_rounded,
        requiredRoles: [UserRole.teacher],
        pageBuilder: (user, teachers, students) => TeacherDashboardPage(
          user: user,
          isSparringMode: false,
          onNavigateToSparring: () {},
          todosParticipantesDaAcademia: students,
        ),
      ),
      AppModule(
        id: 'teacher_history',
        title: 'Histórico',
        icon: Icons.calendar_today_rounded,
        requiredRoles: [UserRole.teacher],
        pageBuilder: (user, teachers, students) => MyCheckinsPage(user: user),
      ),

      // Módulos do Aluno
      AppModule(
          id: 'student_progress',
          title: 'Meu Perfil',
          icon: Icons.person_rounded,
          requiredRoles: [
            UserRole.student
          ],
          subModules: [
            AppModule(
              id: 'student_profile',
              title: 'Início',
              icon: Icons.home_rounded,
              requiredRoles: [UserRole.student],
              pageBuilder: (user, teachers, students) =>
                  UserProfilePage(user: user, hasScaffold: false),
            ),
            AppModule(
              id: 'student_history',
              title: 'Histórico',
              icon: Icons.calendar_today_rounded,
              requiredRoles: [UserRole.student],
              pageBuilder: (user, teachers, students) =>
                  MyCheckinsPage(user: user),
            ),
          ]),

      // Módulos Comuns restantes
      AppModule(
        id: 'common_video_aulas',
        title: 'Videoaulas',
        icon: Icons.video_library_rounded,
        pageBuilder: (user, teachers, students) => VideoLibraryPage(user: user),
      ),
      AppModule(
        id: 'common_shop',
        title: 'Loja',
        icon: Icons.storefront_rounded,
        pageBuilder: (user, teachers, students) => ShopPage(user: user),
      ),
    ];
  }

  /// Retorna as configurações de abas padrão para um novo usuário.
  Map<String, dynamic> getDefaultTabSettings() {
    List<String> defaultVisibleIds;
    switch (userRole) {
      case UserRole.superAdmin:
        defaultVisibleIds = [
          'superadmin_dashboard',
          'superadmin_financial',
          'superadmin_academies',
          'superadmin_notifications',
          'superadmin_tutorials',
        ];
        break;
      case UserRole.manager:
        defaultVisibleIds = [
          'manager_dashboard',
          'common_academy',
          'personal_development', // <<< ALTERADO AQUI
          'manager_financial',
          'common_tools',
        ];
        break;
      case UserRole.teacher:
        defaultVisibleIds = [
          'teacher_dashboard',
          'common_academy',
          'personal_development', // <<< ALTERADO AQUI
          'common_tools',
          'teacher_history',
        ];
        break;
      case UserRole.student:
      default:
        defaultVisibleIds = [
          'student_profile',
          'common_academy',
          'personal_development', // <<< ALTERADO AQUI
          'common_tools',
          'student_history',
        ];
        break;
    }

    final allModuleIds =
        getFlatPageModulesForCurrentUser().map((m) => m.id).toList();
    return {
      'order': allModuleIds,
      'visible': defaultVisibleIds.toSet().toList().take(5).toList(),
    };
  }

  Future<void> saveTabSettings(List<String> newOrder, List<String> newVisible) {
    return _tabSettingsCollection.doc('user_prefs').set({
      'order': newOrder,
      'visible': newVisible,
    });
  }

  Stream<DocumentSnapshot> getTabSettingsStream() {
    return _tabSettingsCollection.doc('user_prefs').snapshots();
  }
}
