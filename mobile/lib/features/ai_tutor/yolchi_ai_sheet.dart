import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/app_button.dart';
import '../../data/services/i_ai_tutor_service.dart';

class YolchiAiSheet extends StatefulWidget {
  final Future<AIExplanationResponse> Function() loadExplanation;
  final VoidCallback onStartReinforcement;

  const YolchiAiSheet({
    super.key,
    required this.loadExplanation,
    required this.onStartReinforcement,
  });

  @override
  State<YolchiAiSheet> createState() => _YolchiAiSheetState();
}

class _YolchiAiSheetState extends State<YolchiAiSheet> {
  late Future<AIExplanationResponse> _request = widget.loadExplanation();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final isRu = locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru');

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isRu ? 'Разбор ошибки с Yo‘lchi' : 'Yo‘lchi bilan xato tahlili',
                  style: text.titleLarge,
                ),
                const SizedBox(height: 16),
                FutureBuilder<AIExplanationResponse>(
                  future: _request,
                  builder: (context, snapshot) {
                    final explanation = snapshot.data;
                    if (snapshot.connectionState != ConnectionState.done) {
                      return LinearProgressIndicator(
                        semanticsLabel: isRu
                            ? 'Yo‘lchi анализирует ответ'
                            : 'Yo‘lchi javobni tahlil qilmoqda',
                      );
                    }
                    if (explanation == null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRu
                                ? 'Не удалось загрузить объяснение Yo‘lchi.'
                                : 'Yo‘lchi izohini yuklab bo‘lmadi.',
                          ),
                          TextButton(
                            onPressed: () => setState(
                              () => _request = widget.loadExplanation(),
                            ),
                            child: Text(isRu ? 'Повторить' : 'Qayta urinish'),
                          ),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          explanation.isDeterministicFallback
                              ? (isRu ? 'Готовый разбор' : 'Tayyor izoh')
                              : (isRu ? 'Объяснение Yo‘lchi AI' : 'Yo‘lchi AI izohi'),
                          style: text.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(explanation.title, style: text.titleMedium),
                        const SizedBox(height: 8),
                        Text(explanation.explanation),
                        const SizedBox(height: 8),
                        Text(explanation.remediationStep),
                        if (explanation.suggestedAction.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(explanation.suggestedAction),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                AppButton(
                  text: isRu ? 'Закрепить тему' : 'Mavzuni mustahkamlash',
                  onPressed: widget.onStartReinforcement,
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(isRu ? 'Вернуться к уроку' : 'Darsga qaytish'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
