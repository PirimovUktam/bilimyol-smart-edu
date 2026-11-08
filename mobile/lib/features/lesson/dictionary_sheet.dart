import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  Future<void> _lookup() async {
    if (_loading) return;
    final word = _word.text.trim().toLowerCase();
    setState(() {
      _error = null;
      _resultWord = null;
      _definitions = [];
    });
    if (word.length > 40 ||
        !RegExp(r"^[a-z]+(?:[-'][a-z]+)*$").hasMatch(word)) {
      setState(() => _error = 'Bitta inglizcha so‘z kiriting. Masalan: hello.');
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
        setState(() => _error = 'Bu so‘z uchun ta’rif topilmadi.');
        return;
      }
      if (response.statusCode != 200) {
        setState(
          () => _error = 'Lug‘at hozir javob bermayapti. Qayta urinib ko‘ring.',
        );
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
          _error = 'Bu so‘z uchun ta’rif topilmadi.';
        } else {
          _resultWord = word;
          _phonetic = phonetic;
          _definitions = definitions.take(3).toList();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Lug‘atga ulanib bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
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
                  child: Text('Inglizcha so‘z lug‘ati', style: theme.titleLarge),
                ),
                IconButton(
                  tooltip: 'Lug‘atni yopish',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Inglizcha ta’rif, talaffuz va misolni toping.'),
            const SizedBox(height: 12),
            TextField(
              controller: _word,
              enabled: !_loading,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Inglizcha so‘z',
                hintText: 'hello',
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _lookup(),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _lookup,
              icon: const Icon(Icons.search_rounded),
              label: Text(_loading ? 'Izlanmoqda…' : 'So‘zni izlash'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_resultWord != null) ...[
              const SizedBox(height: 12),
              Text(
                [_resultWord, _phonetic].whereType<String>().join(' '),
                style: theme.titleLarge,
              ),
              for (final entry in _definitions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.text),
                  subtitle: Text(
                    [entry.part, entry.example]
                        .whereType<String>()
                        .where((text) => text.isNotEmpty)
                        .join('\n'),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Text('Manba: Free Dictionary API', style: theme.bodySmall),
          ],
        ),
      ),
    );
  }
}
