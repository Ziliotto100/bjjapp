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
      } else if (userRole == UserRole.manager) {
        const hiddenForManager = [
          'student_profile',
          'teacher_dashboard',
          'teacher_students',
        ];
        if (hiddenForManager.contains(module.id)) {
          canView = false;
        }
      }

      if (canView) {
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

  List<AppModule> _getAllPossibleModules() {
    return [
      // Módulos do Super Admin
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

      // --- INÍCIO DA CORREÇÃO: Módulos de "Início" agora são todos de nível superior ---
      AppModule(
        id: 'manager_dashboard',
        title: 'Início',
        icon: Icons.dashboard_rounded,
        requiredRoles: [UserRole.manager],
        pageBuilder: (user, teachers, students) =>
            ManagerDashboardPage(user: user),
      ),
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
        id: 'student_profile',
        title: 'Início',
        icon: Icons.home_rounded,
        requiredRoles: [UserRole.student],
        pageBuilder: (user, teachers, students) =>
            UserProfilePage(user: user, hasScaffold: false),
      ),
      // --- FIM DA CORREÇÃO ---

      // Módulo Financeiro (Apenas Gerente)
      AppModule(
        id: 'manager_financial',
        title: 'Financeiro',
        icon: Icons.monetization_on_rounded,
        requiredRoles: [UserRole.manager],
        subModules: [
          AppModule(
            id: 'manager_fees',
            title: 'Mensalidades',
            icon: Icons.request_quote_outlined,
            pageBuilder: (user, teachers, students) =>
                MonthlyFeeManagerPage(academyId: user.academyId),
          ),
          AppModule(
            id: 'manager_reports',
            title: 'Relatórios',
            icon: Icons.bar_chart_rounded,
            pageBuilder: (user, teachers, students) =>
                ManagerReportsPage(user: user),
          ),
        ]..sort((a, b) => a.title.compareTo(b.title)),
      ),

      // Módulo Academia
      AppModule(
        id: 'common_academy',
        title: 'Academia',
        icon: Icons.business_rounded,
        subModules: [
          AppModule(
            id: 'common_birthdays',
            title: 'Aniversários',
            icon: Icons.cake_rounded,
            pageBuilder: (user, teachers, students) =>
                BirthdaysPage(academyId: user.academyId, currentUser: user),
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
            id: 'academy_class_plan',
            title: 'Plano de Aulas',
            icon: Icons.edit_calendar_rounded,
            requiredRoles: [UserRole.manager, UserRole.teacher],
            pageBuilder: (user, teachers, students) =>
                ClassPlanPage(user: user),
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
        ]..sort((a, b) => a.title.compareTo(b.title)),
      ),

      // Módulo Unificado "Painel Pessoal"
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
          AppModule(
            id: 'common_history',
            title: 'Histórico',
            icon: Icons.calendar_today_rounded,
            requiredRoles: [UserRole.teacher, UserRole.student],
            pageBuilder: (user, teachers, students) =>
                MyCheckinsPage(user: user),
          ),
        ]..sort((a, b) => a.title.compareTo(b.title)),
      ),

      // Módulo Ferramentas
      AppModule(
        id: 'common_tools',
        title: 'Ferramentas',
        icon: Icons.construction_rounded,
        subModules: [
          AppModule(
            id: 'common_rules',
            title: 'Livro de Regras',
            icon: Icons.gavel_rounded,
            pageBuilder: (user, teachers, students) => RulesPage(user: user),
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
        ]..sort((a, b) => a.title.compareTo(b.title)),
      ),

      // Módulos comuns restantes
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
