// lib/academy_profile_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'common_widgets.dart';

class AcademyProfilePage extends StatefulWidget {
  final String academyId;

  const AcademyProfilePage({super.key, required this.academyId});

  @override
  State<AcademyProfilePage> createState() => _AcademyProfilePageState();
}

class _AcademyProfilePageState extends State<AcademyProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _instagramController = TextEditingController();
  final _websiteController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _responsibleNameController = TextEditingController();
  final _responsiblePhoneController = TextEditingController();

  // --- INÍCIO DA ALTERAÇÃO ---
  final _pixKeyController = TextEditingController();
  final _monthlyFeeController = TextEditingController();
  // --- FIM DA ALTERAÇÃO ---

  // NOVOS controladores para endereço
  final _logradouroController = TextEditingController();
  final _numeroController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _cepController = TextEditingController();

  XFile? _newLogoFile;
  String? _currentLogoUrl;
  bool _hasCnpj = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAcademyData();
  }

  @override
  void dispose() {
    // Certifique-se de descartar os novos controladores
    _pixKeyController.dispose();
    _monthlyFeeController.dispose();
    super.dispose();
  }

  Future<void> _loadAcademyData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _phoneController.text = data['contactPhoneNumber'] ?? '';
        _instagramController.text = data['instagramUrl'] ?? '';
        _websiteController.text = data['websiteUrl'] ?? '';
        _currentLogoUrl = data['logoUrl'];
        _cnpjController.text = data['cnpj'] ?? '';
        _responsibleNameController.text = data['responsibleName'] ?? '';
        _responsiblePhoneController.text = data['responsiblePhone'] ?? '';
        _hasCnpj = data['cnpj'] != null;

        // --- INÍCIO DA ALTERAÇÃO ---
        _pixKeyController.text = data['pixKey'] ?? '';
        if (data['monthlyFee'] != null) {
          _monthlyFeeController.text = (data['monthlyFee'] as num)
              .toStringAsFixed(2)
              .replaceAll('.', ',');
        }
        // --- FIM DA ALTERAÇÃO ---

        // Carrega os dados do mapa de endereço, se existir
        if (data['address'] is Map) {
          final addressMap = data['address'] as Map<String, dynamic>;
          _logradouroController.text = addressMap['logradouro'] ?? '';
          _numeroController.text = addressMap['numero'] ?? '';
          _bairroController.text = addressMap['bairro'] ?? '';
          _cidadeController.text = addressMap['cidade'] ?? '';
          _cepController.text = addressMap['cep'] ?? '';
        }
      }
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao carregar dados da academia.',
          type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 600);
    if (pickedFile != null) {
      setState(() {
        _newLogoFile = pickedFile;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      String? logoUrl = _currentLogoUrl;
      if (_newLogoFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('academy_logos')
            .child('${widget.academyId}.jpg');
        if (kIsWeb) {
          await ref.putData(await _newLogoFile!.readAsBytes());
        } else {
          await ref.putFile(File(_newLogoFile!.path));
        }
        logoUrl = await ref.getDownloadURL();
      }

      final Map<String, String> addressMap = {
        'logradouro': _logradouroController.text.trim(),
        'numero': _numeroController.text.trim(),
        'bairro': _bairroController.text.trim(),
        'cidade': _cidadeController.text.trim(),
        'cep': _cepController.text.trim(),
      };

      // --- INÍCIO DA ALTERAÇÃO ---
      // Converte o valor da mensalidade para double
      final monthlyFeeValue = double.tryParse(
          _monthlyFeeController.text.trim().replaceAll(',', '.'));
      // --- FIM DA ALTERAÇÃO ---

      await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .update({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'logoUrl': logoUrl,
        'contactPhoneNumber': _phoneController.text.trim(),
        'instagramUrl': _instagramController.text.trim(),
        'websiteUrl': _websiteController.text.trim(),
        'cnpj': _hasCnpj ? _cnpjController.text.trim() : null,
        'address': addressMap,
        'responsibleName': _responsibleNameController.text.trim(),
        'responsiblePhone': _responsiblePhoneController.text.trim(),
        // --- INÍCIO DA ALTERAÇÃO ---
        'pixKey': _pixKeyController.text.trim(),
        'monthlyFee': monthlyFeeValue,
        // --- FIM DA ALTERAÇÃO ---
      });

      showBjjSnackBar(context, 'Perfil da academia atualizado com sucesso!',
          type: 'success');
      Navigator.of(context).pop();
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao salvar o perfil: $e', type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Perfil da Academia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _isSaving ? null : _saveProfile,
            tooltip: 'Salvar Alterações',
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isSaving
                  ? const Center(
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Salvando...'),
                      ],
                    ))
                  : Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          _buildLogoPicker(),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                                labelText: 'Nome da Academia'),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'O nome é obrigatório'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                                labelText: 'Descrição / Sobre',
                                alignLabelWithHint: true),
                            maxLines: 4,
                          ),
                          const SizedBox(height: 24),
                          Text("Endereço",
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _logradouroController,
                            decoration: const InputDecoration(
                                labelText: 'Logradouro (Rua, Av...)'),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _numeroController,
                                  decoration:
                                      const InputDecoration(labelText: 'Nº'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _bairroController,
                                  decoration: const InputDecoration(
                                      labelText: 'Bairro'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _cidadeController,
                                  decoration: const InputDecoration(
                                      labelText: 'Cidade'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _cepController,
                                  decoration:
                                      const InputDecoration(labelText: 'CEP'),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    CepInputFormatter(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                              "Contato e Pagamentos", // Título da seção atualizado
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                                labelText: 'Telefone da Academia (WhatsApp)'),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              PhoneInputFormatter(),
                            ],
                          ),
                          // --- INÍCIO DA ALTERAÇÃO ---
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _pixKeyController,
                            decoration: const InputDecoration(
                                labelText: 'Chave PIX para Mensalidades'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _monthlyFeeController,
                            decoration: const InputDecoration(
                                labelText: 'Valor Padrão da Mensalidade (R\$)'),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                          // --- FIM DA ALTERAÇÃO ---
                          const SizedBox(height: 24),
                          Text("Responsável Legal",
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            title: const Text("Possui CNPJ?"),
                            value: _hasCnpj,
                            onChanged: (value) {
                              setState(() {
                                _hasCnpj = value!;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (_hasCnpj)
                            TextFormField(
                              controller: _cnpjController,
                              decoration:
                                  const InputDecoration(labelText: 'CNPJ'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                CnpjInputFormatter(),
                              ],
                            ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _responsibleNameController,
                            decoration: const InputDecoration(
                                labelText: 'Nome do Responsável'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _responsiblePhoneController,
                            decoration: const InputDecoration(
                                labelText: 'Telefone do Responsável'),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              PhoneInputFormatter(),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text("Redes Sociais",
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _instagramController,
                            decoration: const InputDecoration(
                                labelText: 'Instagram (URL)'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _websiteController,
                            decoration: const InputDecoration(
                                labelText: 'Website (URL)'),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildLogoPicker() {
    ImageProvider? imageProvider;
    if (_newLogoFile != null) {
      if (kIsWeb) {
        // Para web, usamos a imagem em memória
      } else {
        imageProvider = FileImage(File(_newLogoFile!.path));
      }
    } else if (_currentLogoUrl != null) {
      imageProvider = CachedNetworkImageProvider(_currentLogoUrl!);
    }

    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: darkSurface,
            backgroundImage: imageProvider,
            child: _newLogoFile != null && kIsWeb
                ? ClipOval(
                    child: FutureBuilder<Uint8List>(
                      future: _newLogoFile!.readAsBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                          );
                        }
                        return const CircularProgressIndicator();
                      },
                    ),
                  )
                : (imageProvider == null
                    ? const Icon(Icons.storefront, size: 60, color: textHint)
                    : null),
          ),
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_currentLogoUrl == null && _newLogoFile == null
                ? 'Adicionar Logo'
                : 'Trocar Logo'),
          ),
        ],
      ),
    );
  }
}
