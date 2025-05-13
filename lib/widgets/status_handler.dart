// lib/widgets/status_handler.dart

import 'package:flutter/material.dart';

/// 로딩, 에러, 빈 상태를 처리하고 데이터 빌더를 호출하는 범용 위젯
class StatusHandler extends StatelessWidget {
  final bool loading;
  final String? error;
  final bool isEmpty;
  final WidgetBuilder emptyBuilder;
  final WidgetBuilder dataBuilder;
  final Widget? loadingWidget;

  /// 위치 파라미터로 구성된 생성자
  const StatusHandler(
    this.loading,
    this.error,
    this.isEmpty,
    this.emptyBuilder,
    this.dataBuilder, [
    this.loadingWidget,
    Key? key,
  ]) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return loadingWidget ?? const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(child: Text('에러 발생: \$error'));
    }
    if (isEmpty) {
      return emptyBuilder(context);
    }
    return dataBuilder(context);
  }
}
