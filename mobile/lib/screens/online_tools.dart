import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../core/account_api.dart';
import '../core/grammar_checker.dart';
import '../core/photo_input.dart';
import '../ui/design.dart';
import 'account.dart';

Uint8List compressImage(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes),
      info = decoder?.startDecode(bytes);
  if (info == null || info.width * info.height > 20000000) {
    throw const ApiFailure('Rasm o‘lchami mos emas.');
  }
  final source = decoder!.decode(bytes);
  if (source == null) throw const ApiFailure('Rasm o‘qilmadi.');
  final oriented = img.bakeOrientation(source),
      resized = oriented.width > 1600 || oriented.height > 1600
          ? img.copyResize(
              oriented,
              width: oriented.width >= oriented.height ? 1600 : null,
              height: oriented.height > oriented.width ? 1600 : null,
            )
          : oriented;
  // Do not transmit location or camera EXIF metadata with the translated photo.
  resized.exif = img.ExifData();
  return img.encodeJpg(resized, quality: 78);
}

class OnlineToolScreen extends StatefulWidget {
  final int mode;
  final String initial;
  final ImagePicker? picker;
  const OnlineToolScreen({
    super.key,
    required this.mode,
    this.initial = '',
    this.picker,
  });
  @override
  State<OnlineToolScreen> createState() => _ToolState();
}

class _ToolState extends State<OnlineToolScreen> {
  final text = TextEditingController();
  bool busy = false, reverse = false;
  bool selecting = false;
  late final ImagePicker picker = widget.picker ?? ImagePicker();
  String style = 'neutral';
  String? error;
  Uint8List? image;
  Map<String, dynamic>? result;
  @override
  void initState() {
    super.initState();
    text.text = widget.initial;
    if (widget.mode == 2 && widget.picker == null) {
      selecting = true;
      restorePhoto();
    }
  }

  Future<void> restorePhoto() async {
    await recoverPhotoAtStartup();
    if (!mounted) return;
    final photo = recoveredPhoto;
    recoveredPhoto = null;
    try {
      if (photo != null) {
        await acceptPhoto(photo);
      } else if (recoveredPhotoError != null) {
        setState(() => error = recoveredPhotoError);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiFailure ? e.toString() : photoError(e));
      }
    } finally {
      recoveredPhotoError = null;
      if (mounted) setState(() => selecting = false);
    }
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void offline() {
    final issues = checkGrammar(text.text);
    setState(
      () => result = {
        'corrected': applyGrammarIssues(text.text, issues),
        'explanation': 'Oflayn tekshiruv: faqat sodda qoidalar tekshirildi.',
        'issues': issues
            .map(
              (i) => {
                'original': i.original,
                'replacement': i.replacement,
                'explanation': i.explanation,
              },
            )
            .toList(),
      },
    );
  }

  Future<void> acceptPhoto(XFile file) async {
    if (await file.length() > 10 * 1024 * 1024) {
      throw const ApiFailure('10 MB gacha rasm tanlang.');
    }
    final compressed = await compute(compressImage, await file.readAsBytes());
    if (compressed.length > 3 * 1024 * 1024) {
      throw const ApiFailure('Kichikroq rasm tanlang.');
    }
    if (mounted) {
      setState(() {
        image = compressed;
        error = null;
        result = null;
      });
    }
  }

  Future<void> choose(ImageSource source) async {
    if (selecting || busy) return;
    setState(() {
      selecting = true;
      error = null;
    });
    try {
      final photo = await picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
        requestFullMetadata: false,
      );
      if (photo != null && mounted) await acceptPhoto(photo);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiFailure ? e.toString() : photoError(e));
      }
    } finally {
      if (mounted) setState(() => selecting = false);
    }
  }

  Future<void> submit() async {
    if (widget.mode != 0 && !await requireAccount(context)) return;
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      if (widget.mode == 2 && image == null) {
        throw const ApiFailure('Avval rasm tanlang.');
      }
      if (widget.mode != 2 && text.text.trim().isEmpty) {
        throw const ApiFailure('Matn kiriting.');
      }
      final p = await accountApi.request(
        [
          '/translate',
          '/ai/translate',
          '/image/translate',
          '/grammar',
        ][widget.mode],
        method: 'POST',
        body: {
          if (widget.mode != 2) 'text': text.text.trim(),
          if (widget.mode == 2) 'image': base64Encode(image!),
          'source_language': reverse ? 'uz' : 'en',
          'target_language': reverse ? 'en' : 'uz',
          'style': style,
        },
      );
      if (mounted) {
        setState(() => result = (p['result'] as Map).cast<String, dynamic>());
      }
    } catch (e) {
      if (mounted) {
        if (widget.mode == 3 &&
            (e is! ApiFailure || e.status == 0 || e.status >= 500)) {
          offline();
        } else {
          setState(() => error = e.toString());
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => PageFrame(
    title: [
      'Matn tarjimasi',
      'AI tarjima',
      'Rasm tarjimasi',
      'Grammatika',
    ][widget.mode],
    child: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(
          widget.mode == 3
              ? 'Fikringizni aniq ifodalang'
              : 'Ma’noni birga ochamiz',
          style: display(26),
        ),
        const SizedBox(height: 12),
        Text(
          'Yuborish tugmasi orqali matn yoki tanlangan rasm tarjima xizmatiga uzatiladi.',
          style: TextStyle(color: muted(c), fontSize: 12),
        ),
        const SizedBox(height: 18),
        if (widget.mode != 3)
          Row(
            children: [
              Expanded(
                child: Text(
                  reverse ? 'O‘zbekcha → Inglizcha' : 'Inglizcha → O‘zbekcha',
                ),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() => reverse = !reverse),
                child: const Text('Almashtirish'),
              ),
            ],
          ),
        if (widget.mode == 2) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const ValueKey('take-photo'),
                onPressed: busy || selecting
                    ? null
                    : () => choose(ImageSource.camera),
                icon: AppIcon(
                  'assets/icons/camera.svg',
                  size: 19,
                  color: Theme.of(c).colorScheme.onPrimary,
                ),
                label: const Text('Suratga olish'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('pick-photo'),
                onPressed: busy || selecting
                    ? null
                    : () => choose(ImageSource.gallery),
                icon: const AppIcon(AppIcons.imageOutlined, size: 19),
                label: const Text('Galereyadan'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Matnni yorug‘ joyda, tekis va to‘liq kadrlang. Surat faqat «Tarjima qilish» bosilganda yuboriladi.',
            style: TextStyle(color: muted(c), fontSize: 12),
          ),
          if (selecting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (image != null)
            Column(
              children: [
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    image!,
                    height: 220,
                    fit: BoxFit.contain,
                    semanticLabel: 'Tarjima uchun tanlangan rasm',
                  ),
                ),
                TextButton(
                  onPressed: busy || selecting
                      ? null
                      : () => setState(() {
                          image = null;
                          result = null;
                        }),
                  child: const Text('Rasmni olib tashlash'),
                ),
              ],
            ),
        ] else
          TextField(
            controller: text,
            maxLength: 4000,
            maxLines: 7,
            decoration: InputDecoration(
              hintText: widget.mode == 3
                  ? 'Inglizcha matn kiriting…'
                  : 'Tarjima uchun matn…',
            ),
          ),
        if (widget.mode == 1)
          DropdownButtonFormField<String>(
            initialValue: style,
            decoration: const InputDecoration(labelText: 'Uslub'),
            items: const [
              DropdownMenuItem(value: 'neutral', child: Text('Tabiiy')),
              DropdownMenuItem(value: 'formal', child: Text('Rasmiy')),
              DropdownMenuItem(value: 'informal', child: Text('Norasmiy')),
            ],
            onChanged: (v) => style = v ?? 'neutral',
          ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: busy || selecting ? null : submit,
          child: Text(
            busy
                ? 'Tayyorlanmoqda…'
                : widget.mode == 3
                ? 'Tekshirish'
                : 'Tarjima qilish',
          ),
        ),
        if (widget.mode == 3)
          OutlinedButton(
            onPressed: busy ? null : offline,
            child: const Text('Oflayn tekshirish'),
          ),
        if (busy)
          const Padding(
            padding: EdgeInsets.all(18),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(c).colorScheme.error),
            ),
          ),
        if (result != null)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Glass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((result!['extractedText'] ?? '')
                      .toString()
                      .isNotEmpty) ...[
                    const Text('Rasmdagi matn'),
                    SelectableText(result!['extractedText'].toString()),
                    const SizedBox(height: 16),
                  ],
                  SelectableText(
                    (widget.mode == 3
                                ? result!['corrected']
                                : result!['translation'])
                            ?.toString() ??
                        '',
                    style: display(21),
                  ),
                  const SizedBox(height: 12),
                  Text(result!['explanation']?.toString() ?? ''),
                  for (final i in (result!['issues'] as List? ?? []))
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        '${i['original']} → ${i['replacement']}\n${i['explanation']}',
                      ),
                    ),
                  for (final a in (result!['alternatives'] as List? ?? []))
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text('${a['meaning']} — ${a['usage']}'),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
