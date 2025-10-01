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

/// Representa um módulo ou tela principal do aplicativo.
class AppModule {
  final String id;
  final String title;
  final IconData icon;
  final List<UserRole>? requiredRoles;
  // --- ASSINATURA DA FUNÇÃO CORRIGIDA ---
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

  List<AppModule> _filterModules(List<AppModule> allModules) {
    List<AppModule> filtered = [];
    for (var module in allModules) {
      bool canViewByRole = module.requiredRoles == null ||
          module.requiredRoles!.contains(userRole);

      if (userRole == UserRole.manager) {
        const hiddenForManager = [
          'student_profile',
          'teacher_dashboard',
          'teacher_students',
        ];
        if (hiddenForManager.contains(module.id)) {
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
          if (filteredSubModules.isNotEmpty) {
            newModule = AppModule(
              id: module.id,
              title: module.title,
              icon: module.icon,
              requiredRoles: module.requiredRoles,
              pageBuilder: module.pageBuilder,
              subModules: filteredSubModules,
              requiredFeature: module.requiredFeature,
            );
            filtered.add(newModule);
          }
        } else {
          filtered.add(newModule);
        }
      }
    }
    return filtered;
  }

  List<AppModule> getDrawerModulesForCurrentUser() {
    final all = _getAllPossibleModules();
    List<AppModule> filtered = _filterModules(all);

    AppModule? inicioModule;
    try {
      if (userRole == UserRole.student) {
        inicioModule = filtered.firstWhere((m) => m.id == 'student_profile');
      } else if (userRole == UserRole.teacher) {
        inicioModule = filtered.firstWhere((m) => m.id == 'teacher_dashboard');
      } else if (userRole == UserRole.manager) {
        inicioModule = filtered.firstWhere((m) => m.id == 'manager_dashboard');
      }
    } catch (e) {
      inicioModule = null;
    }

    final otherModules =
        filtered.where((m) => m.id != inicioModule?.id).toList();
    otherModules.sort((a, b) => a.title.compareTo(b.title));

    final List<AppModule> sortedList = [];
    if (inicioModule != null) sortedList.add(inicioModule);
    sortedList.addAll(otherModules);

    return sortedList;
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

  // --- CHAMADAS DO PAGEBUILDER CORRIGIDAS ---
  List<AppModule> _getAllPossibleModules() {
    return [
      // Módulos do Super Admin
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
      // --- MÓDULO DE PLANOS ADICIONADO ---
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

      AppModule(
        id: 'manager_dashboard',
        title: 'Início',
        icon: Icons.dashboard_rounded,
        requiredRoles: [UserRole.manager],
        pageBuilder: (user, teachers, students, plan) =>
            ManagerDashboardPage(user: user),
      ),
      AppModule(
        id: 'teacher_dashboard',
        title: 'Início',
        icon: Icons.dashboard_rounded,
        requiredRoles: [UserRole.teacher],
        pageBuilder: (user, teachers, students, plan) => TeacherDashboardPage(
          user: user,
          isSparringMode: false,
          onNavigateToSparring: () {},
          todosParticipantesDaAcademia: students,
        ),
      ),
      AppModule(
        id: 'student_profile',
        title: 'Início',
        icon: Icons.home_rounded,
        requiredRoles: [UserRole.student],
        pageBuilder: (user, teachers, students, plan) =>
            UserProfilePage(user: user, hasScaffold: false),
      ),

      AppModule(
        id: 'manager_financial',
        title: 'Financeiro',
        icon: Icons.monetization_on_rounded,
        requiredRoles: [UserRole.manager],
        requiredFeature: 'financial_reports',
        subModules: [
          AppModule(
            id: 'manager_fees',
            title: 'Mensalidades',
            icon: Icons.request_quote_outlined,
            pageBuilder: (user, teachers, students, plan) =>
                MonthlyFeeManagerPage(academyId: user.academyId),
          ),
          AppModule(
            id: 'manager_reports',
            title: 'Relatórios',
            icon: Icons.bar_chart_rounded,
            pageBuilder: (user, teachers, students, plan) =>
                ManagerReportsPage(user: user),
          ),
        ]..sort((a, b) => a.title.compareTo(b.title)),
      ),

      AppModule(
        id: 'common_academy',
        title: 'Academia',
        icon: Icons.business_rounded,
        subModules: [
          AppModule(
            id: 'common_birthdays',
            title: 'Aniversários',
            icon: Icons.cake_rounded,
            pageBuilder: (user, teachers, students, plan) =>
                BirthdaysPage(academyId: user.academyId, currentUser: user),
          ),
          AppModule(
            id: 'teacher_checkin',
            title: 'Check-in',
            icon: Icons.check_circle_outline_rounded,
            requiredRoles: [UserRole.teacher],
            pageBuilder: (user, teachers, students, plan) => CheckinTeacherPage(
                user: user,
                academyId: user.academyId,
                todosParticipantesDaAcademia: students),
          ),
          AppModule(
            id: 'academy_notifications',
            title: 'Comunicados',
            icon: Icons.campaign_outlined,
            requiredRoles: [UserRole.manager, UserRole.teacher],
            pageBuilder: (user, teachers, students, plan) =>
                AcademyNotificationsPage(user: user),
          ),
          AppModule(
            id: 'common_schedule',
            title: 'Grade',
            icon: Icons.calendar_month_rounded,
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
            title: 'Alunos',
            icon: Icons.people_alt_rounded,
            requiredRoles: [UserRole.teacher],
            pageBuilder: (user, teachers, students, plan) =>
                AlunosTeacherPage(academyId: user.academyId, teacher: user),
          ),
          AppModule(
            id: 'manager_students',
            title: 'Alunos',
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

      AppModule(
        id: 'personal_panel',
        title: 'Painel Pessoal',
        icon: Icons.person_rounded,
        requiredRoles: [UserRole.student, UserRole.teacher, UserRole.manager],
        subModules: [
          AppModule(
            id: 'common_training_log',
            title: 'Diário de Treinos',
            icon: Icons.auto_stories_outlined,
            pageBuilder: (user, teachers, students, plan) =>
                TrainingLogPage(user: user),
          ),
          AppModule(
            id: 'common_notebook',
            title: 'Caderno de Estudos',
            icon: Icons.book_rounded,
            requiredFeature: 'study_notebook',
            pageBuilder: (user, teachers, students, plan) =>
                StudyNotebookPage(userId: user.uid, currentPlan: plan),
          ),
          AppModule(
            id: 'common_history',
            title: 'Histórico',
            icon: Icons.calendar_today_rounded,
            requiredRoles: [UserRole.teacher, UserRole.student],
            pageBuilder: (user, teachers, students, plan) =>
                MyCheckinsPage(user: user),
          ),
        ]..sort((a, b) => a.title.compareTo(b.title)),
      ),

      AppModule(
        id: 'common_tools',
        title: 'Ferramentas',
        icon: Icons.construction_rounded,
        subModules: [
          AppModule(
            id: 'common_rules',
            title: 'Livro de Regras',
            icon: Icons.gavel_rounded,
            requiredFeature: 'rules_module',
            pageBuilder: (user, teachers, students, plan) =>
                RulesPage(user: user, currentPlan: plan),
          ),
          AppModule(
            id: 'common_scoreboard',
            title: 'Placar',
            icon: Icons.scoreboard_rounded,
            requiredFeature: 'scoreboard_module',
            pageBuilder: (user, teachers, students, plan) => MatchSetupPage(
                user: user,
                academyId: user.academyId,
                todosAlunosDaAcademia: students),
          ),
          AppModule(
            id: 'teacher_sparring',
            title: 'Sorteio de Treinos',
            icon: Icons.shuffle_rounded,
            requiredRoles: [UserRole.teacher, UserRole.manager],
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
        ]..sort((a, b) => a.title.compareTo(b.title)),
      ),

      AppModule(
        id: 'common_video_aulas',
        title: 'Videoaulas',
        icon: Icons.video_library_rounded,
        requiredFeature: 'video_library',
        pageBuilder: (user, teachers, students, plan) =>
            VideoLibraryPage(user: user, currentPlan: plan),
      ),
      AppModule(
        id: 'common_shop',
        title: 'Loja',
        icon: Icons.storefront_rounded,
        requiredFeature: 'shop_module',
        pageBuilder: (user, teachers, students, plan) =>
            ShopPage(user: user, currentPlan: plan),
      ),
    ];
  }

  Map<String, dynamic> getDefaultTabSettings() {
    List<String> defaultVisibleIds;
    switch (userRole) {
      case UserRole.superAdmin:
        defaultVisibleIds = [
          'superadmin_dashboard',
          'superadmin_financial',
          'superadmin_academies',
          'superadmin_plans', // Adicionado
          'superadmin_tutorials',
        ];
        break;
      case UserRole.manager:
        defaultVisibleIds = [
          'manager_dashboard',
          'common_academy',
          'common_training_log',
          'manager_financial',
          'common_tools',
        ];
        break;
      case UserRole.teacher:
        defaultVisibleIds = [
          'teacher_dashboard',
          'common_academy',
          'common_training_log',
          'common_tools',
          'teacher_checkin',
        ];
        break;
      case UserRole.student:
      default:
        defaultVisibleIds = [
          'student_profile',
          'common_schedule',
          'common_training_log',
          'common_shop',
          'common_video_aulas',
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
