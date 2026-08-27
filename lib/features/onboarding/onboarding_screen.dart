import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/widgets/app_logo.dart';
import '../auth/login_screen.dart';

class OnboardingData {
  final IconData icon;
  final String title;
  final String body;
  const OnboardingData(this.icon, this.title, this.body);
}

List<OnboardingData> _pagesFor(AppLocalizations t) => [
      OnboardingData(
          Icons.video_camera_front_rounded, t.onboardTitle1, t.onboardBody1),
      OnboardingData(Icons.forum_rounded, t.onboardTitle2, t.onboardBody2),
      OnboardingData(Icons.dashboard_customize_rounded, t.onboardTitle3,
          t.onboardBody3),
    ];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final pages = _pagesFor(t);
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700; // tablet/desktop responsive breakpoint
    final isLast = _index == pages.length - 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      body: DecoratedBox(
        // Very subtle brand-tinted wash from the top — reads as premium
        // without looking like a loud marketing gradient.
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient(primary, isDark: isDark),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                child: Row(
                  children: [
                    AppLogo(size: 34, ),
                    const SizedBox(width: 10),
                    Text(
                      t.appName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _complete,
                      child: Text(t.skip),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final page = pages[i];
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isWide ? 480 : double.infinity,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: isWide ? 200 : 156,
                                height: isWide ? 200 : 156,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      primary.withOpacity(isDark ? 0.28 : 0.14),
                                      primary.withOpacity(isDark ? 0.10 : 0.04),
                                    ],
                                  ),
                                  boxShadow: AppColors.softShadow(primary),
                                ),
                                child: Center(
                                  child: Container(
                                    width: isWide ? 108 : 88,
                                    height: isWide ? 108 : 88,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: primary,
                                      boxShadow: AppColors.softShadow(primary),
                                    ),
                                    child: Icon(page.icon,
                                        size: isWide ? 50 : 40,
                                        color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 44),
                              Text(
                                page.title,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                page.body,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                        height: 1.5,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SmoothPageIndicator(
                controller: _controller,
                count: pages.length,
                effect: ExpandingDotsEffect(
                  activeDotColor: primary,
                  dotColor: Theme.of(context).dividerColor,
                  dotHeight: 8,
                  dotWidth: 8,
                  expansionFactor: 3.4,
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (isLast) {
                        _complete();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    child: Text(isLast ? t.getStarted : t.next),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
