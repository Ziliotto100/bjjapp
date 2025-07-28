// lib/navigation_service.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';
import 'manager_module.dart';
import 'teacher_module.dart';
import 'student_module.dart';
import 'schedule_module.dart';
import 'scoreboard_module.dart';
import 'study_notebook_module.dart';
import 'shop_module.dart';
import 'notifications_module.dart'; // <-- NOVO IMPORT

/// Representa um módulo ou tela principal do aplicativo.
class AppModule {
  final String id;
  final String title;
  final IconData icon;
  final UserRole? requiredRole; // Papel necessário para ver este módulo
  final Widget Function(UserModel, List<UserModel>, List<Aluno>) pageBuilder;

  AppModule({
    required this.id,
    required this.title,
    required this.icon,
    this.requiredRole,
    required this.pageBuilder,
  });
}

/// Serviço para gerenciar os módulos e as configurações de navegação do usuário.
class NavigationService {
  final String userId;
  final UserRole userRole;

  NavigationService({required this.userId, required this.userRole});

  /// Retorna a coleção de configurações de abas do usuário no Firestore.
  CollectionReference get _tabSettingsCollection => FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('tab_settings');

  /// Lista de todos os módulos disponíveis no aplicativo.
  List<AppModule> get allModules {
    return [
      // Módulos do Gerente
      AppModule(
        id: 'manager_dashboard',
        title: 'Início',
        icon: Icons.dashboard_rounded,
        requiredRole: UserRole.manager,
        pageBuilder: (user, teachers, students) =>
            ManagerDashboardPage(user: user),
      ),
      AppModule(
        id: 'manager_students',
        title: 'Alunos',
        icon: Icons.people_alt_rounded,
        requiredRole: UserRole.manager,
        pageBuilder: (user, teachers, students) =>
            AlunosManagerPage(academyId: user.academyId, manager: user),
      ),
      AppModule(
        id: 'manager_teachers',
        title: 'Professores',
        icon: Icons.school_rounded,
        requiredRole: UserRole.manager,
        pageBuilder: (user, teachers, students) =>
            ProfessoresManagerPage(academyId: user.academyId, manager: user),
      ),
      AppModule(
        id: 'manager_fees',
        title: 'Mensalidades',
        icon: Icons.monetization_on_rounded,
        requiredRole: UserRole.manager,
        pageBuilder: (user, teachers, students) =>
            MonthlyFeeManagerPage(academyId: user.academyId),
      ),

      // Módulos do Professor
      AppModule(
        id: 'teacher_dashboard',
        title: 'Início',
        icon: Icons.dashboard_rounded,
        requiredRole: UserRole.teacher,
        pageBuilder: (user, teachers, students) => TeacherDashboardPage(
          user: user,
          isSparringMode: false, // O estado real virá da tela principal
          onNavigateToSparring: () {},
        ),
      ),
      AppModule(
        id: 'teacher_students',
        title: 'Alunos',
        icon: Icons.people_alt_rounded,
        requiredRole: UserRole.teacher,
        pageBuilder: (user, teachers, students) =>
            AlunosTeacherPage(academyId: user.academyId, teacher: user),
      ),
      AppModule(
        id: 'teacher_checkin',
        title: 'Check-in',
        icon: Icons.check_circle_outline_rounded,
        requiredRole: UserRole.teacher,
        pageBuilder: (user, teachers, students) => CheckinTeacherPage(
            academyId: user.academyId, todosParticipantesDaAcademia: students),
      ),
      AppModule(
        id: 'teacher_sparring',
        title: 'Sorteio',
        icon: Icons.shuffle_rounded,
        requiredRole: UserRole.teacher,
        pageBuilder: (user, teachers, students) => SorteioTeacherPage(
          academyId: user.academyId,
          todosParticipantesDaAcademia: students,
          isSparringMode: false, // O estado real virá da tela principal
          onIniciarSparring: (rounds, type, participants) {},
          onCheckinAlunos: (students) {},
        ),
      ),

      // Módulos do Aluno
      AppModule(
        id: 'student_profile',
        title: 'Meu Perfil',
        icon: Icons.person_rounded,
        requiredRole: UserRole.student,
        pageBuilder: (user, teachers, students) =>
            UserProfilePage(user: user, hasScaffold: false),
      ),
      AppModule(
        id: 'student_history',
        title: 'Histórico',
        icon: Icons.calendar_today_rounded,
        requiredRole: UserRole.student,
        pageBuilder: (user, teachers, students) => MyCheckinsPage(user: user),
      ),

      // Módulos Comuns
      AppModule(
        id: 'common_notifications', // <-- NOVO MÓDULO
        title: 'Avisos',
        icon: Icons.notifications_rounded,
        pageBuilder: (user, teachers, students) =>
            NotificationsPage(user: user),
      ),
      AppModule(
        id: 'common_schedule',
        title: 'Grade',
        icon: Icons.calendar_month_rounded,
        pageBuilder: (user, teachers, students) =>
            SchedulePage(user: user, teachers: teachers),
      ),
      AppModule(
        id: 'common_shop',
        title: 'Loja',
        icon: Icons.storefront_rounded,
        pageBuilder: (user, teachers, students) => ShopPage(user: user),
      ),
      AppModule(
        id: 'common_notebook',
        title: 'Estudos',
        icon: Icons.book_rounded,
        pageBuilder: (user, teachers, students) =>
            StudyNotebookPage(userId: user.uid),
      ),
      AppModule(
        id: 'common_scoreboard',
        title: 'Placar',
        icon: Icons.scoreboard_rounded,
        pageBuilder: (user, teachers, students) => MatchSetupPage(
            academyId: user.academyId, todosAlunosDaAcademia: students),
      ),
    ];
  }

  /// Retorna os módulos disponíveis para o papel do usuário atual.
  List<AppModule> getModulesForCurrentUser() {
    return allModules
        .where((module) =>
            module.requiredRole == null || module.requiredRole == userRole)
        .toList();
  }

  /// Retorna as configurações de abas padrão para um novo usuário.
  Map<String, dynamic> getDefaultTabSettings() {
    List<String> defaultVisibleIds;
    switch (userRole) {
      case UserRole.manager:
        defaultVisibleIds = [
          'manager_dashboard',
          'common_notifications', // <-- ADICIONADO
          'manager_students',
          'manager_teachers',
          'common_schedule',
        ];
        break;
      case UserRole.teacher:
        defaultVisibleIds = [
          'teacher_dashboard',
          'common_notifications', // <-- ADICIONADO
          'common_schedule',
          'teacher_students',
          'teacher_checkin',
        ];
        break;
      case UserRole.student:
      default:
        defaultVisibleIds = [
          'student_profile',
          'common_notifications', // <-- ADICIONADO
          'common_schedule',
          'student_history',
          'common_notebook',
        ];
        break;
    }
    final allModuleIds = getModulesForCurrentUser().map((m) => m.id).toList();
    return {
      'order': allModuleIds,
      'visible': defaultVisibleIds,
    };
  }

  /// Salva as novas configurações de abas (ordem e visibilidade) no Firestore.
  Future<void> saveTabSettings(List<String> newOrder, List<String> newVisible) {
    return _tabSettingsCollection.doc('user_prefs').set({
      'order': newOrder,
      'visible': newVisible,
    });
  }

  /// Retorna um stream com as configurações de abas do usuário.
  Stream<DocumentSnapshot> getTabSettingsStream() {
    return _tabSettingsCollection.doc('user_prefs').snapshots();
  }
}
