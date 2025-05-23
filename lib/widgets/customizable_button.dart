import 'package:face_detection_app/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomizableTextButton extends StatelessWidget {
  String? buttonTitle;
  final Widget? prefixButtonIcon;
  final Widget? suffixButtonIcon;
  final bool isFullWidth;
  final bool isOutlined;
  final VoidCallback onPressed;
  final double? buttonWidth;
  final TextStyle buttonTitleStyle;
  double buttonBorderRadius;
  final Color? buttonColor;
  final bool? isDisabled;
  final double? verticalPadding;
  final double? horizontalPadding;

  CustomizableTextButton({
    super.key,
    this.buttonTitle,
    required this.onPressed,
    this.buttonWidth,
    this.isFullWidth = false,
    this.isOutlined = false,
    required this.buttonTitleStyle,
    required this.buttonBorderRadius,
    this.buttonColor,
    this.prefixButtonIcon,
    this.suffixButtonIcon,
    this.isDisabled = false,
    this.verticalPadding,
    this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: (isFullWidth) ? MediaQuery.of(context).size.width : buttonWidth,
        padding: EdgeInsets.symmetric(
          horizontal:
              ((suffixButtonIcon != null || prefixButtonIcon != null) && buttonTitle == null)
                  ? 16.w
                  : horizontalPadding ?? 50.w,
          vertical: verticalPadding ?? 16.h,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(buttonBorderRadius),
          border: isOutlined ? Border.all(color: textFieldBorderColor, width: 1.w) : null,
          color: (isOutlined) ? Colors.transparent : buttonColor,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Visibility(
            //   visible: prefixButtonIcon != null,
            //   child: Icon(
            //     Icons.home_outlined,
            //     color: (isOutlined) ? fgPrimaryColor : bgPrimaryColor,
            //   ),
            // ),
            Visibility(visible: prefixButtonIcon != null, child: prefixButtonIcon ?? Container()),
            Visibility(
              visible: prefixButtonIcon != null && buttonTitle != null,
              child: SizedBox(width: 12.w),
            ),
            Visibility(
              visible: suffixButtonIcon != null && buttonTitle != null,
              child: SizedBox(height: 24.h, width: 24.h),
            ),
            Visibility(
              visible: suffixButtonIcon != null && buttonTitle != null,
              child: Expanded(child: SizedBox(width: 12.w)),
            ),
            Visibility(
              visible: buttonTitle != null,
              child: Text(buttonTitle ?? "", style: buttonTitleStyle),
            ),
            Visibility(
              visible: suffixButtonIcon != null && buttonTitle != null,
              child: Expanded(child: SizedBox(width: 12.w)),
            ),
            // Visibility(
            //   visible: suffixButtonIcon != null,
            //   child: Icon(
            //     Icons.arrow_forward_rounded,
            //     color: (isOutlined) ? fgPrimaryColor : bgPrimaryColor,
            //   ),
            // ),
            Visibility(visible: suffixButtonIcon != null, child: suffixButtonIcon ?? Container()),
          ],
        ),
      ),
    );
  }
}
