import 'package:avatar_maker/avatar_maker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Aspect ratio (height / width) of the avatar_maker package's composited
/// SVG canvas (`AvatarService.drawSVG` always emits `width="264px"
/// height="280px"`). The character/outfit art is NOT centered inside that
/// canvas — every outfit silhouette is bottom-flush (its lowest row sits
/// exactly at y=280, at close to full canvas width), with the slack margin
/// living entirely above the head. Fitting the art to a *square* first (as
/// `BoxFit.cover` would) discards almost that whole bottom-flush strip
/// before we ever get a say — so instead we size the art to its true
/// aspect ratio and let [kAvatarArtAlignment] crop it, which is what
/// actually closes the gap.
const double kAvatarArtAspectRatio = 280 / 264;

/// Extra zoom applied on top of the natural aspect-ratio fit. Below 1.0,
/// the artwork's own width no longer covers the full circle, so a corner
/// gap starts to reappear — 1.0 is the last value with zero gap, verified
/// against every outfit silhouette the customizer offers. 0.95 accepts a
/// faint gap at the corners in exchange for a touch more headroom; going
/// much lower reintroduces a clearly visible ring (checked down to 0.85).
/// One named constant keeps that trade-off identical everywhere the
/// avatar renders (grid tile, selected state, profile/header).
const double kAvatarArtScale = 0.95;

/// Bottom-aligned: the artwork's lowest row (the outfit's hem, which is
/// where every outfit silhouette is at its widest) is pinned to the bottom
/// of the circle, and the slack margin is cropped off the top instead —
/// giving the head a breathing gap up top while the shoulders/outfit fill
/// the frame edge to edge at the bottom and get naturally clipped by the
/// curve at the corners.
const Alignment kAvatarArtAlignment = Alignment(0, 1.0);

/// Renders an avatar — either live from an [AvatarMakerController] mid
/// customisation, or a saved [svgString] — clipped to a circle of [size]
/// diameter, cropped via [kAvatarArtAspectRatio]/[kAvatarArtScale]/
/// [kAvatarArtAlignment] so the artwork fills the frame instead of
/// floating with a padding ring around it.
///
/// Deliberately doesn't delegate to the package's own [AvatarMakerAvatar]
/// widget: that widget draws its SVG at a fixed 80% of its circle
/// (`height: radius * 1.6` inside a `radius * 2` box) via `BoxFit.contain`,
/// which both shrinks the art unnecessarily and (like `BoxFit.cover` would)
/// loses the aspect-ratio information this fix depends on. Composing the
/// cosmetic background/effect/effect-color layers ourselves (same public
/// API `AvatarMakerAvatar` uses internally) lets both the live-controller
/// path and the saved-svgString path share one rendering pipeline, so one
/// set of constants produces the same framing everywhere.
class FramedAvatar extends StatelessWidget {
  final double size;
  final AvatarMakerController? controller;
  final String? svgString;
  final Color backgroundColor;

  const FramedAvatar({
    super.key,
    required this.size,
    this.controller,
    this.svgString,
    this.backgroundColor = Colors.white,
  }) : assert(
         controller != null || svgString != null,
         'FramedAvatar needs either a controller or a saved svgString',
       );

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return _frame(context, svgString!);
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _frame(
        context,
        controller.displayedAvatarSVG,
        background:
            controller.previewBackgroundCosmetic ??
            controller.selectedBackgroundCosmetic,
        effect:
            controller.previewEffectCosmetic ??
            controller.selectedEffectCosmetic,
        effectColor:
            controller.previewEffectColorCosmetic ??
            controller.selectedEffectColorCosmetic,
      ),
    );
  }

  Widget _frame(
    BuildContext context,
    String svgString, {
    CosmeticPropertyItem? background,
    CosmeticPropertyItem? effect,
    CosmeticPropertyItem? effectColor,
  }) {
    final artWidth = size * kAvatarArtScale;
    final artHeight = artWidth * kAvatarArtAspectRatio;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: backgroundColor,
          child: OverflowBox(
            minWidth: artWidth,
            maxWidth: artWidth,
            minHeight: artHeight,
            maxHeight: artHeight,
            alignment: kAvatarArtAlignment,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (background != null)
                  Positioned.fill(
                    child: background.buildWidget(context, artWidth),
                  ),
                if (effect != null)
                  Positioned.fill(
                    child: effectColor is EffectColorCosmeticItem
                        ? EffectCosmeticItemWithColor(
                            effect: effect as EffectCosmeticItem,
                            color: effectColor.color,
                            size: artWidth,
                          )
                        : effect.buildWidget(context, artWidth),
                  ),
                if (svgString.isNotEmpty)
                  SvgPicture.string(
                    svgString,
                    width: artWidth,
                    height: artHeight,
                    fit: BoxFit.fill,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
