import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'university_map_data.dart';

const _background = Color(0xFF1A202C);
const _control = Color(0xFFC9CDD4);
const _light = Color(0xFFEDF2F7);
const _blue = Color(0xFF3478F6);
const _ink = Color(0xFF1F2430);
const _muted = Color(0xFF7E8798);

class MapRoomRequest {
  const MapRoomRequest(this.room, this.id);

  final String room;
  final int id;
}

class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    this.catalog,
    this.roomRequest,
    this.notificationsEnabled = true,
    this.onToggleNotifications,
  });

  final MapCatalog? catalog;
  final MapRoomRequest? roomRequest;
  final bool notificationsEnabled;
  final VoidCallback? onToggleNotifications;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final Future<MapCatalog> _catalog = widget.catalog != null
      ? Future.value(widget.catalog)
      : rootBundle
            .loadString('assets/map/aitu_rooms.json')
            .then(MapCatalog.fromJson);
  final _query = TextEditingController();
  final _transform = TransformationController();
  final String _building = 'C1';
  int _block = 0;
  int _floor = 1;
  MapRoom? _selected;
  bool _showResults = false;
  Size _viewport = Size.zero;
  MapFloor? _plan;

  @override
  void initState() {
    super.initState();
    if (widget.roomRequest != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openRoomRequest(widget.roomRequest!);
      });
    }
  }

  @override
  void didUpdateWidget(covariant MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final request = widget.roomRequest;
    if (request != null && request.id != oldWidget.roomRequest?.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openRoomRequest(request);
      });
    }
  }

  Future<void> _openRoomRequest(MapRoomRequest request) async {
    MapCatalog catalog;
    try {
      catalog = await _catalog;
    } catch (_) {
      return;
    }
    if (!mounted || widget.roomRequest?.id != request.id) return;
    final query = request.room.trim();
    final exact = catalog.exact(query);
    final matches = exact == null ? catalog.search(query) : <MapRoom>[exact];
    if (matches.length == 1) {
      _chooseRoom(matches.first);
    } else {
      _query.text = query;
      setState(() {
        _selected = null;
        _showResults = true;
      });
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _transform.dispose();
    super.dispose();
  }

  double _fitScale(MapFloor plan) =>
      math.min(_viewport.width / plan.width, _viewport.height / plan.height) *
      .92;

  void _fitPlan() {
    final plan = _plan;
    if (plan == null || _viewport.isEmpty) return;
    final scale = _fitScale(plan);
    _transform.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setTranslationRaw(
        (_viewport.width - plan.width * scale) / 2,
        (_viewport.height - plan.height * scale) / 2,
        0,
      );
  }

  void _changePlan(MapCatalog catalog, {int? block, int? floor}) {
    final blocks = catalog.blocksFor(_building);
    final nextBlock =
        block ?? (blocks.contains(_block) ? _block : blocks.first);
    final floors = catalog.floorsFor(_building, nextBlock);
    _query.clear();
    setState(() {
      _block = nextBlock;
      _floor = floor ?? (floors.contains(_floor) ? _floor : floors.first);
      _selected = null;
      _showResults = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitPlan());
  }

  void _chooseRoom(MapRoom room) {
    FocusManager.instance.primaryFocus?.unfocus();
    _query.text = room.number;
    setState(() {
      _block = room.block;
      _floor = room.floor;
      _selected = room;
      _showResults = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final plan = _plan;
      if (!mounted || plan == null || _viewport.isEmpty) return;
      final scale = math.max(_fitScale(plan) * 2.3, 1.4);
      final center = room.bounds.center;
      _transform.value = Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale)
        ..setTranslationRaw(
          _viewport.width / 2 - center.dx * scale,
          _viewport.height / 2 - center.dy * scale,
          0,
        );
    });
  }

  void _submit(MapCatalog catalog) {
    final room = catalog.exact(_query.text);
    if (room != null) {
      _chooseRoom(room);
    } else {
      setState(() {
        _selected = null;
        _showResults = true;
      });
    }
  }

  Widget _dropdown<T>(
    T value,
    List<T> options,
    String Function(T) label,
    ValueChanged<T> onChanged,
    double width,
  ) {
    return SizedBox(
      width: width,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _control,
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            dropdownColor: _light,
            icon: const Icon(Icons.keyboard_arrow_down, color: _ink, size: 18),
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            items: options
                .map(
                  (option) => DropdownMenuItem<T>(
                    value: option,
                    child: Text(label(option), overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (option) {
              if (option != null && option != value) onChanged(option);
            },
          ),
        ),
      ),
    );
  }

  Widget _searchField(MapCatalog catalog) => SizedBox(
    height: 44,
    child: TextField(
      controller: _query,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: _ink, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'C1.2.223 или 2.223',
        hintStyle: const TextStyle(color: Color(0xFF9CA2AB), fontSize: 13),
        suffixIcon: const Icon(Icons.search_rounded, size: 22, color: _ink),
        filled: true,
        fillColor: _light,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (_) => setState(() {
        _showResults = true;
        if (catalog.search(_query.text).isEmpty) _selected = null;
      }),
      onSubmitted: (_) => _submit(catalog),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MapCatalog>(
      future: _catalog,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Не удалось открыть карту'));
        }
        if (!snapshot.hasData) {
          return const ColoredBox(color: _background, child: SizedBox.expand());
        }
        final catalog = snapshot.data!;
        final plan = catalog.plan(_building, _block, _floor);
        _plan = plan;
        final results = catalog.search(_query.text);
        final hasQuery = normalizeRoomQuery(_query.text).isNotEmpty;
        final svgName = 'C1_${_block == 0 ? 'all' : _block}_$_floor.svg';
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 680;
            return ColoredBox(
              color: const Color(0xFFF7F4ED),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.2,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Task',
                                      style: TextStyle(color: _ink),
                                    ),
                                    TextSpan(
                                      text: 'Hub',
                                      style: TextStyle(color: _blue),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'AITU campus map',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: widget.notificationsEnabled
                              ? const Color(0xFFE7F0FF)
                              : const Color(0xFFE8E8E8),
                          borderRadius: BorderRadius.circular(15),
                          child: InkWell(
                            onTap: widget.onToggleNotifications,
                            borderRadius: BorderRadius.circular(15),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Tooltip(
                                message: widget.notificationsEnabled
                                    ? 'Отключить уведомления'
                                    : 'Включить уведомления',
                                child: Icon(
                                  widget.notificationsEnabled
                                      ? Icons.notifications_active_outlined
                                      : Icons.notifications_off_outlined,
                                  color: widget.notificationsEnabled
                                      ? _blue
                                      : _muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 14 : 22),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'University Map',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.6,
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Показать всю карту',
                          onPressed: _fitPlan,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFE0E8FF),
                            foregroundColor: _ink,
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 10 : 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF1FF),
                        border: Border.all(color: const Color(0xFFD0E1FF)),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: _blue,
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Select a room on the map or search for it by room number.',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: ColoredBox(
                          color: _background,
                          child: LayoutBuilder(
                            builder: (context, mapConstraints) {
                              final viewport = Size(
                                mapConstraints.maxWidth,
                                mapConstraints.maxHeight,
                              );
                              if (_viewport != viewport) {
                                _viewport = viewport;
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted && _selected == null) _fitPlan();
                                });
                              }
                              return Stack(
                                children: [
                                  InteractiveViewer(
                                    transformationController: _transform,
                                    constrained: false,
                                    boundaryMargin: const EdgeInsets.all(1200),
                                    minScale: .2,
                                    maxScale: 8,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapUp: (details) {
                                        for (final room
                                            in plan.rooms.reversed) {
                                          if (room.contains(
                                            details.localPosition,
                                          )) {
                                            setState(() => _selected = room);
                                            break;
                                          }
                                        }
                                      },
                                      child: SizedBox(
                                        width: plan.width,
                                        height: plan.height,
                                        child: Stack(
                                          children: [
                                            SvgPicture.asset(
                                              'assets/map/svg/$svgName',
                                              width: plan.width,
                                              height: plan.height,
                                              fit: BoxFit.fill,
                                            ),
                                            CustomPaint(
                                              size: Size(
                                                plan.width,
                                                plan.height,
                                              ),
                                              painter: _SelectionPainter(
                                                _selected,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 18,
                                    left: 14,
                                    right: 14,
                                    child: Row(
                                      children: [
                                        _dropdown(
                                          _block,
                                          catalog.blocksFor(_building),
                                          (value) =>
                                              value == 0 ? 'Все' : 'C1.$value',
                                          (value) => _changePlan(
                                            catalog,
                                            block: value,
                                          ),
                                          82,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(child: _searchField(catalog)),
                                      ],
                                    ),
                                  ),
                                  if (_showResults && hasQuery)
                                    Positioned(
                                      top: 68,
                                      left: 14,
                                      right: 14,
                                      child: Material(
                                        color: _light,
                                        elevation: 8,
                                        borderRadius: BorderRadius.circular(12),
                                        clipBehavior: Clip.antiAlias,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxHeight: 224,
                                          ),
                                          child: results.isEmpty
                                              ? const Padding(
                                                  padding: EdgeInsets.all(12),
                                                  child: Text(
                                                    'Кабинет не найден',
                                                  ),
                                                )
                                              : ListView.builder(
                                                  shrinkWrap: true,
                                                  itemCount: results.length,
                                                  itemBuilder: (context, index) {
                                                    final room = results[index];
                                                    return ListTile(
                                                      dense: true,
                                                      title: Text(
                                                        room.number,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      subtitle: Text(
                                                        'C1.${room.block} · ${room.floor} этаж',
                                                      ),
                                                      onTap: () =>
                                                          _chooseRoom(room),
                                                    );
                                                  },
                                                ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    right: 14,
                                    top: viewport.height * .43,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: _light,
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Column(
                                        children: catalog
                                            .floorsFor(_building, _block)
                                            .reversed
                                            .map(
                                              (floor) => SizedBox(
                                                width: 42,
                                                height: 42,
                                                child: TextButton(
                                                  onPressed: () => _changePlan(
                                                    catalog,
                                                    floor: floor,
                                                  ),
                                                  style: TextButton.styleFrom(
                                                    padding: EdgeInsets.zero,
                                                    backgroundColor:
                                                        floor == _floor
                                                        ? _ink
                                                        : _light,
                                                    foregroundColor:
                                                        floor == _floor
                                                        ? _light
                                                        : _ink,
                                                    shape: const CircleBorder(),
                                                  ),
                                                  child: Text(
                                                    '$floor',
                                                    style: const TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                  if (_selected != null)
                                    Positioned(
                                      left: 20,
                                      right: 20,
                                      bottom: 16,
                                      child: Card(
                                        color: _light,
                                        elevation: 8,
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _selected!.number,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              Text(
                                                'C1.${_selected!.block} · ${_selected!.floor} этаж',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    left: 14,
                                    bottom: 6,
                                    child: Text(
                                      '© Yuujiso · локальная карта',
                                      style: TextStyle(
                                        color: _light.withValues(alpha: .55),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SelectionPainter extends CustomPainter {
  _SelectionPainter(this.room);
  final MapRoom? room;

  @override
  void paint(Canvas canvas, Size size) {
    if (room == null) return;
    final outline = room!.outline;
    final path = Path()..moveTo(outline.first.dx, outline.first.dy);
    for (final point in outline.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xA0FFE04B));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF6A00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) =>
      oldDelegate.room != room;
}
