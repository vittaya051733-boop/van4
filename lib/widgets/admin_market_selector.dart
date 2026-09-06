import 'package:flutter/material.dart';

import '../models/admin_market.dart';
import '../services/admin_market_scope.dart';

class AdminMarketSelector extends StatelessWidget {
  const AdminMarketSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AdminMarketScope.instance,
      builder: (context, _) {
        final scope = AdminMarketScope.instance;
        final markets = scope.activeMarkets;
        final selected = scope.selectedMarketId;

        if (!scope.canSelectMarket) {
          final label = scope.selectedMarket?.displayLabel ??
              scope.lockedBranchId ??
              'สาขา';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.storefront_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return PopupMenuButton<String?>(
          tooltip: 'เลือกสาขา',
          onSelected: scope.selectMarket,
          itemBuilder: (context) {
            return <PopupMenuEntry<String?>>[
              const PopupMenuItem<String?>(
                value: null,
                child: Text('ทั้งหมด'),
              ),
              const PopupMenuDivider(),
              ...markets.map(
                (market) => PopupMenuItem<String?>(
                  value: market.id,
                  child: Text(market.displayLabel),
                ),
              ),
            ];
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.storefront_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    selected == null
                        ? 'ทั้งหมด'
                        : scope.selectedMarket?.name ?? selected,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AdminMarketScopeBanner extends StatelessWidget {
  const AdminMarketScopeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AdminMarketScope.instance,
      builder: (context, _) {
        final scope = AdminMarketScope.instance;
        if (scope.isAllMarkets) {
          return const SizedBox.shrink();
        }
        final market = scope.selectedMarket;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDBA74)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.filter_alt_outlined, color: Color(0xFFEA580C), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'กำลังดูสาขา: ${market?.displayLabel ?? scope.selectedMarketId}',
                  style: const TextStyle(
                    color: Color(0xFF9A3412),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => scope.selectMarket(null),
                child: const Text('ทั้งหมด'),
              ),
            ],
          ),
        );
      },
    );
  }
}

String adminMarketScopeSubtitle(AdminMarket? market) {
  if (market == null) {
    return 'ทุกตลาด';
  }
  final parts = <String>[market.name];
  if (market.amphoe != null && market.amphoe!.trim().isNotEmpty) {
    parts.add(market.amphoe!.trim());
  }
  return parts.join(' · ');
}
