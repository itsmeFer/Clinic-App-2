// lib/widgets/royal_scaffold.dart
import 'package:flutter/material.dart';
import 'package:RoyalClinic/widgets/royal_app_bar.dart';

class TealX {
  static const Color primary = Color(0xFF00897B);
  static const Color primaryLight = Color(0xFF4DB6AC);
  static const Color text = Color(0xFF0F1C1A);

  static LinearGradient bgGradient = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFE7F4F2),
      Color(0xFFF8FFFE),
    ],
  );
}

/// Scaffold wrapper supaya semua halaman punya background & AppBar seragam
class RoyalScaffold extends StatelessWidget {
  const RoyalScaffold({
    super.key,
    required this.body,
    this.title = 'Royal Clinic',
    this.centerTitle = false,
    this.showBack = false,
    this.trailingActions = const [],
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.resizeToAvoidBottomInset,
    this.useSafeArea = true,
  });

  final Widget body;
  final String title;
  final bool centerTitle;
  final bool showBack;
  final List<Widget> trailingActions;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool? resizeToAvoidBottomInset;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: TealX.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: RoyalAppBar(
          title: title,
          centerTitle: centerTitle,
          showBack: showBack,
          trailingActions: trailingActions,
        ),
        body: useSafeArea ? SafeArea(child: body) : body,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      ),
    );
  }
}
