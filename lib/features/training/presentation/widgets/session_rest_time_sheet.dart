import 'package:flutter/material.dart';

class SessionRestTimeSheet extends StatefulWidget {
  final int initialSeconds;
  final String exerciseName;

  const SessionRestTimeSheet({
    super.key,
    required this.initialSeconds,
    required this.exerciseName,
  });

  @override
  State<SessionRestTimeSheet> createState() => SessionRestTimeSheetState();
}

class SessionRestTimeSheetState extends State<SessionRestTimeSheet> {
  late int _seconds;
  late FixedExtentScrollController _controller;

  static final List<int> _options = [
    for (var s = 15; s <= 600; s += 15) s,
  ];

  @override
  void initState() {
    super.initState();
    _seconds = ((widget.initialSeconds / 15).round() * 15).clamp(15, 600);
    final idx = _options.indexOf(_seconds);
    _controller = FixedExtentScrollController(
      initialItem: idx >= 0 ? idx : 3,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _label(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m > 0 && s > 0) return '${m}min ${s.toString().padLeft(2, '0')}s';
    if (m > 0) return '${m}min 0s';
    return '${s}s';
  }
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Temporizador de Descanso',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Temporizador de Descanso – ${widget.exerciseName}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: ListWheelScrollView.useDelegate(
                controller: _controller,
                itemExtent: 44,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) {
                  setState(() => _seconds = _options[i]);
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: _options.length,
                  builder: (context, index) {
                    final selected = _options[index] == _seconds;
                    return Center(
                      child: Text(
                        _label(_options[index]),
                        style: TextStyle(
                          fontSize: selected ? 20 : 16,
                          fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? primary : Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _seconds),
                child: const Text('Listo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
