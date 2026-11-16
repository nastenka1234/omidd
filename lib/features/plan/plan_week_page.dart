import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/api_client.dart';
import '../../core/jalali.dart';
import '../../core/models.dart';
import '../../theme/glass.dart';
import '../../theme/tokens.dart';
import '../../theme/lottie_views.dart';

final weekPlanProvider = FutureProvider.autoDispose<List<PlanDay>>((ref) async {
  final today = todayIso();
  Map<String, dynamic> r;
  try {
    r = await Api.i.getC('/plan', q: {'day': today, 'days': 7});
  } on ApiError catch (e) {
    if (!e.isNetwork) rethrow;
    // آفلاین و بدون کش هفتگیِ همین روز: از کش روزهای تکی بساز
    final days = <PlanDay>[];
    for (var i = 0; i < 7; i++) {
      final c = await Api.i.cacheRead('/plan', {'day': addDays(today, i)});
      days.add(c is Map ? PlanDay.fromJson(c) : PlanDay(addDays(today, i), [], 'none', ''));
    }
    if (days.every((d) => d.items.isEmpty && d.source == 'none')) rethrow;
    Api.i.offlineData.value = true;
    return days;
  }
  final list = r['plans'] as List?;
  if (list == null) return [PlanDay.fromJson(r)];
  return [for (final x in list) PlanDay.fromJson(x)];
});

class PlanWeekPage extends ConsumerStatefulWidget {
  const PlanWeekPage({super.key});
  @override
  ConsumerState<PlanWeekPage> createState() => _PlanWeekPageState();
}

class _PlanWeekPageState extends ConsumerState<PlanWeekPage> {
  int sel = 0;

  Widget _strip(List<PlanDay> list) => SizedBox(
        height: 74,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final j = Jalali.fromDateTime(parseIso(list[i].day));
            final on = i == sel;
            final w = j.formatter.wN.split(' ').first;
            return GestureDetector(
              onTap: () => setState(() => sel = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: 58,
                decoration: BoxDecoration(
                  color: on ? T.acc : T.sec,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: on ? T.acc : T.line),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(w, style: TextStyle(fontSize: 11, color: on ? T.bg : T.tx2, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(fa(j.day),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: on ? T.bg : T.tx)),
                  const SizedBox(height: 3),
                  Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: list[i].items.isEmpty ? Colors.transparent : (on ? T.bg : T.acc))),
                ]),
              ),
            );
          },
        ),
      );

  Widget _day(PlanDay p, String tomorrow) => Glass(
        key: ValueKey(p.day),
        borderColor: p.source == 'ai' ? T.acc : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('${p.day == tomorrow ? 'فردا · ' : ''}${jalaliFull(p.day)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
            if (p.source == 'ai')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: T.acc, borderRadius: BorderRadius.circular(20)),
                child: const Text('ویرایش‌شده توسط هوش مصنوعی',
                    style: TextStyle(color: T.bg, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ]),
          if (p.note.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(p.note, style: const TextStyle(color: T.hi, fontSize: 13))),
          const SizedBox(height: 8),
          if (p.items.isEmpty)
            const Text('برنامه‌ای ثبت نشده', style: TextStyle(color: T.tx2))
          else
            for (var i = 0; i < p.items.length; i++)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 320 + i * 90),
                curve: Curves.easeOutCubic,
                builder: (_, v, c) =>
                    Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: c)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Text(fa(i + 1), style: const TextStyle(color: T.acc, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            '${p.items[i].part}${p.items[i].subject.isEmpty ? '' : ' — ${p.items[i].subject}'}')),
                    Text(
                        '${fmtMin(p.items[i].minutes)}${p.items[i].testsTarget > 0 ? ' · ${fa(p.items[i].testsTarget)} تست' : ''}',
                        style: const TextStyle(color: T.tx2, fontSize: 12)),
                  ]),
                ),
              ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(weekPlanProvider);
    final tomorrow = addDays(todayIso(), 1);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 8), child: PageTitle('برنامه', sub: 'روز را انتخاب کن')),
      plans.when(
        loading: () => const Expanded(child: AppLoader()),
        error: (e, _) => Expanded(
            child: ErrorState(e is ApiError ? e.fa : 'خطا در دریافت برنامه',
                onRetry: () => ref.invalidate(weekPlanProvider))),
        data: (list) {
          final i = sel.clamp(0, list.length - 1);
          return Expanded(
            child: Column(children: [
              _strip(list),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.refresh(weekPlanProvider.future),
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                            position: Tween(begin: const Offset(0, .08), end: Offset.zero).animate(a), child: c),
                      ),
                      child: _day(list[i], tomorrow),
                    ),
                  ]),
                ),
              ),
            ]),
          );
        },
      ),
    ]);
  }
}
