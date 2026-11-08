import 'package:flutter/material.dart';
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Yo‘lchi bilan xato tahlili', style: text.titleLarge),
            const SizedBox(height: 16),
            FutureBuilder<AIExplanationResponse>(
              future: _request,
              builder: (context, snapshot) {
                final explanation = snapshot.data;
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator(
                    semanticsLabel: 'Yo‘lchi javobni tahlil qilmoqda',
                  );
                }
                if (explanation == null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Yo‘lchi izohini yuklab bo‘lmadi.'),
                      TextButton(
                        onPressed: () =>
                            setState(() => _request = widget.loadExplanation()),
                        child: const Text('Qayta urinish'),
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      explanation.isDeterministicFallback
                          ? 'Tayyor izoh'
                          : 'Yo‘lchi AI izohi',
                      style: text.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(explanation.title, style: text.titleMedium),
                    const SizedBox(height: 8),
                    Text(explanation.explanation),
                    const SizedBox(height: 8),
                    Text(explanation.remediationStep),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            AppButton(
              text: 'Mavzuni mustahkamlash',
              onPressed: widget.onStartReinforcement,
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Darsga qaytish'),
            ),
          ],
        ),
      ),
    );
  }
}
