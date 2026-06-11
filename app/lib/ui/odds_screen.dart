import 'package:flutter/material.dart';
import 'package:wc_app/state/odds_controller.dart';
import 'package:wc_app/ui/widgets/async_view.dart';

class OddsScreen extends StatefulWidget {
  final OddsController controller;
  final int matchId;
  const OddsScreen({super.key, required this.controller, required this.matchId});
  @override
  State<OddsScreen> createState() => _OddsScreenState();
}

class _OddsScreenState extends State<OddsScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.matchId);
  }

  Widget _cell(String label, double value) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return AsyncView(
          loading: c.loading,
          error: c.error,
          data: c.odds,
          onRetry: () => c.load(widget.matchId),
          builder: (odds) {
            final wdl = c.odds!.wdl;
            if (wdl == null) {
              return const Center(child: Text('暂无赔率'));
            }
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('胜平负', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  _cell('主胜', wdl.home),
                  _cell('平', wdl.draw),
                  _cell('客胜', wdl.away),
                ]),
                const Spacer(),
                const Text('赔率仅供参考。理性看球, 远离非法赌博。',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
              ]),
            );
          },
        );
      },
    );
  }
}
