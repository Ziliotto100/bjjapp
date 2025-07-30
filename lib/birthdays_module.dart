// lib/birthdays_module.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'user_card_widget.dart'; // Usado para a página de visualização de foto

class BirthdaysPage extends StatefulWidget {
  final String academyId;
  final UserModel currentUser;

  const BirthdaysPage({
    super.key,
    required this.academyId,
    required this.currentUser,
  });

  @override
  State<BirthdaysPage> createState() => _BirthdaysPageState();
}

class _BirthdaysPageState extends State<BirthdaysPage> {
  late Future<List<dynamic>> _birthdayListFuture;
  // Mapa para associar Aluno.userId a um UserModel para obter a foto
  late Future<Map<String, String?>> _profileImageUrls;

  @override
  void initState() {
    super.initState();
    _birthdayListFuture = _fetchBirthdays();
    _profileImageUrls = _fetchProfileImages();
  }

  // --- FUNÇÃO ADICIONADA PARA BUSCAR FOTOS DOS ALUNOS ---
  Future<Map<String, String?>> _fetchProfileImages() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('academyId', isEqualTo: widget.academyId)
        .where('profileImagePath', isNotEqualTo: null)
        .get();

    return {
      for (var doc in snapshot.docs)
        doc.id: doc.data()['profileImagePath'] as String?
    };
  }

  Future<List<dynamic>> _fetchBirthdays() async {
    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now();
    final List<dynamic> allUsers = [];

    // Busca alunos
    final studentsSnapshot = await firestore
        .collection('academies')
        .doc(widget.academyId)
        .collection('students')
        .get();
    final students = studentsSnapshot.docs
        .map((doc) => Aluno.fromJson(doc.id, doc.data()))
        .toList();
    allUsers.addAll(students);

    // Busca professores e gerentes
    final usersSnapshot = await firestore
        .collection('users')
        .where('academyId', isEqualTo: widget.academyId)
        .where('role', whereIn: ['teacher', 'manager']).get();
    final teachersAndManagers =
        usersSnapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    allUsers.addAll(teachersAndManagers);

    // Filtra pelos aniversariantes do mês
    final birthdayList = allUsers.where((user) {
      DateTime? birthDate;
      if (user is Aluno) {
        birthDate = user.dataNascimento;
      } else if (user is UserModel) {
        birthDate = user.dataNascimento;
      }
      return birthDate != null && birthDate.month == now.month;
    }).toList();

    // Ordena por dia do aniversário
    birthdayList.sort((a, b) {
      final dateA =
          (a is Aluno) ? a.dataNascimento! : (a as UserModel).dataNascimento!;
      final dateB =
          (b is Aluno) ? b.dataNascimento! : (b as UserModel).dataNascimento!;
      return dateA.day.compareTo(dateB.day);
    });

    return birthdayList;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      // Espera ambos os futures completarem
      future: Future.wait([_birthdayListFuture, _profileImageUrls]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const EmptyStateWidget(
            icon: Icons.error_outline,
            title: 'Erro ao Carregar',
            message: 'Não foi possível buscar os aniversariantes.',
          );
        }
        // --- CORREÇÃO APLICADA AQUI ---
        if (!snapshot.hasData || (snapshot.data![0] as List).isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.cake_outlined,
            title: 'Nenhum Aniversariante',
            message: 'Ninguém faz aniversário neste mês.',
          );
        }

        final birthdayList = snapshot.data![0] as List<dynamic>;
        final imageUrls = snapshot.data![1] as Map<String, String?>;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _birthdayListFuture = _fetchBirthdays();
              _profileImageUrls = _fetchProfileImages();
            });
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
            itemCount: birthdayList.length,
            itemBuilder: (context, index) {
              final user = birthdayList[index];
              final isStudent = user is Aluno;

              // --- LÓGICA PARA CONSTRUIR O CARD CORRIGIDO ---
              final String name = isStudent ? user.nome : user.name;
              final String? belt = isStudent ? user.faixa : user.faixa;
              final DateTime birthDate = isStudent
                  ? user.dataNascimento!
                  : (user as UserModel).dataNascimento!;
              final String heroTag =
                  'birthday_pic_${isStudent ? user.id : user.uid}';

              String? profileImageUrl;
              if (isStudent) {
                profileImageUrl = imageUrls[user.userId];
              } else {
                profileImageUrl = (user as UserModel).profileImagePath;
              }

              final bool hasImage =
                  profileImageUrl != null && profileImageUrl.isNotEmpty;

              return Card(
                child: ListTile(
                  leading: GestureDetector(
                    onTap: () {
                      if (hasImage) {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PhotoViewPage(
                            imageUrl: profileImageUrl!,
                            heroTag: heroTag,
                          ),
                        ));
                      }
                    },
                    child: Hero(
                      tag: heroTag,
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: primaryAccent,
                        backgroundImage:
                            hasImage ? NetworkImage(profileImageUrl) : null,
                        child: !hasImage
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                    fontSize: 24,
                                    color: primaryAccentForeground),
                              )
                            : null,
                      ),
                    ),
                  ),
                  title: Text(name,
                      style: Theme.of(context).textTheme.titleMedium),
                  subtitle: belt != null
                      ? Text(belt, style: const TextStyle(color: textSecondary))
                      : null,
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: primaryAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primaryAccent)),
                    child: Text(
                      "Dia ${DateFormat('d').format(birthDate)}",
                      style: const TextStyle(
                          color: primaryAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
