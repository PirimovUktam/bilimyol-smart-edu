import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_card.dart';

class DictionarySheet extends StatefulWidget {
  const DictionarySheet({super.key});

  @override
  State<DictionarySheet> createState() => _DictionarySheetState();
}

class _DictionarySheetState extends State<DictionarySheet> {
  final _word = TextEditingController();
  final _client = http.Client();
  bool _loading = false;
  String? _error;
  String? _resultWord;
  String? _phonetic;
  List<({String part, String text, String? example})> _definitions = [];

  @override
  void dispose() {
    _client.close();
    _word.dispose();
    super.dispose();
  }

  static AppStrings _resolveStrings(BuildContext context) {
    final registered = Localizations.of<AppStrings>(context, AppStrings);
    if (registered != null) return registered;
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final isRu = locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru');
    return isRu ? AppStrings.ru : AppStrings.uz;
  }

  Future<void> _lookup() async {
    final s = _resolveStrings(context);
    if (_loading) return;
    final word = _word.text.trim().toLowerCase();
    setState(() {
      _error = null;
      _resultWord = null;
      _definitions = [];
    });
    if (word.length > 40 ||
        !RegExp(r"^[a-z]+(?:[-'][a-z]+)*$").hasMatch(word)) {
      setState(() => _error = s.dictionaryInvalidWord);
      return;
    }
    setState(() => _loading = true);
    try {
      final uri = Uri.https(
        'api.dictionaryapi.dev',
        '/api/v2/entries/en/$word',
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (response.statusCode == 404) {
        setState(() => _error = s.dictionaryNotFound);
        return;
      }
      if (response.statusCode != 200) {
        setState(() => _error = s.dictionaryServerError);
        return;
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final definitions = <({String part, String text, String? example})>[];
      String? phonetic;
      if (body is List) {
        for (final item in body.take(4).whereType<Map>()) {
          final pronunciation = item['phonetic'];
          if (pronunciation is String) phonetic ??= pronunciation;
          final meanings = item['meanings'];
          if (meanings is! List) continue;
          for (final meaning in meanings.take(6).whereType<Map>()) {
            final options = meaning['definitions'];
            if (options is! List) continue;
            final entry = options
                .whereType<Map>()
                .where(
                  (value) =>
                      value['definition'] is String &&
                      (value['definition'] as String).trim().isNotEmpty,
                )
                .firstOrNull;
            if (entry == null) continue;
            final part = meaning['partOfSpeech'];
            final example = entry['example'];
            definitions.add((
              part: part is String ? part : '',
              text: entry['definition'] as String,
              example: example is String ? example : null,
            ));
          }
        }
      }
      setState(() {
        if (definitions.isEmpty) {
          _error = s.dictionaryNotFound;
        } else {
          _resultWord = word;
          _phonetic = phonetic;
          _definitions = definitions.take(3).toList();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = s.dictionaryNetworkError);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final s = _resolveStrings(context);
    final theme = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.dictionaryTitle, style: theme.titleLarge),
                ),
                IconButton(
                  tooltip: s.dictionaryCloseTooltip,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              s.dictionarySubtitle,
              style: AppTypography.ui(fontSize: 13, color: c.slatefine),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _word,
              enabled: !_loading,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: s.dictionaryWordLabel,
                hintText: s.dictionaryWordHint,
                prefixIcon: Icon(
                  Icons.translate_rounded,
                  size: 18,
                  color: c.brand,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _lookup(),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 46),
              child: FilledButton.icon(
                onPressed: _loading ? null : _lookup,
                icon: const Icon(Icons.search_rounded),
                label: Text(
                  _loading ? s.dictionarySearching : s.dictionarySearchAction,
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.errorSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: c.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: AppTypography.ui(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: c.errorText,
                      ),
                    ),
                  ),
                ),
              ),
            if (_resultWord != null) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _resultWord!,
                    style: AppTypography.ui(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  if (_phonetic != null && _phonetic!.isNotEmpty)
                    Text(
                      _phonetic!,
                      style: AppTypography.mono(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: c.path,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              for (final entry in _definitions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    borderRadius: 16,
                    backgroundColor: c.subtle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (entry.part.isNotEmpty) ...[
                          AppBadge(
                            text: entry.part,
                            variant: AppBadgeVariant.teal,
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          entry.text,
                          style: AppTypography.ui(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                            height: 1.4,
                          ),
                        ),
                        if (entry.example != null &&
                            entry.example!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '“${entry.example!}”',
                            style: AppTypography.ui(
                              fontSize: 12.5,
                              color: c.slatefine,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Text(s.dictionarySourceFooter, style: theme.bodySmall),
          ],
        ),
      ),
    );
  }
}
