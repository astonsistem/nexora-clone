import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/sky_theme.dart';
import '../../home/theme/home_tokens.dart';
import '../data/models/pengaduan_models.dart';
import '../data/pengaduan_service.dart';
import 'widgets/pengaduan_shared.dart';

class PengaduanCreatePage extends StatefulWidget {
  const PengaduanCreatePage({super.key});

  @override
  State<PengaduanCreatePage> createState() => _PengaduanCreatePageState();
}

class _PengaduanCreatePageState extends State<PengaduanCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _service = PengaduanService();

  List<TicketType> _types = const [];
  String? _selectedTypeId;
  XFile? _attachment;
  bool _loadingTypes = true;
  bool _submitting = false;
  double? _progress;
  String? _typesError;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    setState(() {
      _loadingTypes = true;
      _typesError = null;
    });
    try {
      final types = await _service.getTypes();
      if (!mounted) return;
      setState(() {
        _types = types;
        _loadingTypes = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingTypes = false;
        _typesError = _service.extractErrorMessage(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingTypes = false;
        _typesError = 'Jenis pengaduan gagal dimuat.';
      });
    }
  }

  Future<void> _pickAttachment() async {
    if (_submitting) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (file == null || !mounted) return;
    if (await file.length() > 5 * 1024 * 1024) {
      _showSnack('Ukuran lampiran maksimal 5 MB.', isError: true);
      return;
    }
    setState(() => _attachment = file);
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _progress = null;
    });
    try {
      await _service.createTicket(
        ticketTypeId: _selectedTypeId!,
        subject: _subjectController.text,
        description: _descriptionController.text,
        attachmentPath: _attachment?.path,
        onSendProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() => _progress = sent / total);
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaduan berhasil dikirim.'),
          backgroundColor: HomeTokens.success,
        ),
      );
      Navigator.pop(context, true);
    } on DioException catch (error) {
      if (!mounted) return;
      _showSnack(_service.extractErrorMessage(error), isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Pengaduan gagal dikirim. Silakan coba lagi.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _progress = null;
        });
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: PengaduanScaffold(
        title: 'Buat Pengaduan',
        subtitle: 'Sampaikan keluhan atau kebutuhan bantuan',
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildIntro(),
                        const SizedBox(height: 18),
                        _buildTypeField(),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _subjectController,
                          enabled: !_submitting,
                          maxLength: 150,
                          textInputAction: TextInputAction.next,
                          decoration: pengaduanInputDecoration(
                            label: 'Subjek *',
                            hint: 'Ringkasan pengaduan',
                            prefixIcon: const Icon(Icons.title_rounded),
                          ),
                          validator: (value) {
                            final length = value?.trim().length ?? 0;
                            if (length < 5) {
                              return 'Subjek minimal 5 karakter.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          enabled: !_submitting,
                          minLines: 5,
                          maxLines: 9,
                          maxLength: 2000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: pengaduanInputDecoration(
                            label: 'Deskripsi *',
                            hint: 'Jelaskan kendala secara lengkap',
                          ),
                          validator: (value) {
                            final length = value?.trim().length ?? 0;
                            if (length < 10) {
                              return 'Deskripsi minimal 10 karakter.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildAttachment(),
                        const SizedBox(height: 22),
                        if (_progress != null) ...[
                          LinearProgressIndicator(
                            value: _progress,
                            color: SkyTheme.instance.accent,
                          ),
                          const SizedBox(height: 8),
                        ],
                        SkyAccentBuilder(
                          builder: (context, accent, _) {
                            return FilledButton.icon(
                              onPressed: _submitting ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                              label: Text(
                                _submitting
                                    ? 'Mengirim...'
                                    : 'Kirim Pengaduan',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return SkyAccentBuilder(
      builder: (context, accent, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.support_agent_rounded, color: accent),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Sampaikan keluhan atau kebutuhan bantuan kepada tim HR.',
                  style: TextStyle(color: HomeTokens.ink, height: 1.4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeField() {
    if (_loadingTypes) {
      return const LinearProgressIndicator();
    }
    if (_typesError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(child: Text(_typesError!)),
            TextButton(onPressed: _loadTypes, child: const Text('Coba lagi')),
          ],
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedTypeId,
      isExpanded: true,
      decoration: pengaduanInputDecoration(
        label: 'Jenis pengaduan *',
        prefixIcon: const Icon(Icons.category_outlined),
      ),
      items: _types
          .map(
            (type) => DropdownMenuItem(
              value: type.id,
              child: Text(type.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: _submitting
          ? null
          : (value) => setState(() => _selectedTypeId = value),
      validator: (value) => value == null ? 'Pilih jenis pengaduan.' : null,
    );
  }

  Widget _buildAttachment() {
    final file = _attachment;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomeTokens.line),
      ),
      child: Row(
        children: [
          Icon(Icons.image_outlined, color: SkyTheme.instance.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file?.name ?? 'Lampiran foto (opsional)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Text(
                  'JPG atau PNG · maks. 5 MB',
                  style: TextStyle(fontSize: 11, color: HomeTokens.muted),
                ),
              ],
            ),
          ),
          if (file != null)
            IconButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() => _attachment = null),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Hapus',
            )
          else
            TextButton(
              onPressed: _submitting ? null : _pickAttachment,
              child: const Text('Pilih'),
            ),
        ],
      ),
    );
  }
}
