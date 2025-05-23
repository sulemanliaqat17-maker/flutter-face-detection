import 'package:face_detection_app/utils/colors.dart';
import 'package:face_detection_app/widgets/poppins_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

enum TextfieldDecorationType { Outline, Underline, Outline2 }

class CustomizableTextField extends StatelessWidget {
  final String? title;
  final String? urduTitle;
  final Color? titleTextColor;
  final double? titleFontSize;
  final TextEditingController controller;
  final String hintText;
  final FocusNode focusNode;
  final String? Function(String?)? validator;
  final Function(String) onChanged;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final Color focusedIconColor;
  final Color unfocusedIconColor;
  final bool hideText;
  VoidCallback? onSuffixIconPressed;
  final bool readOnly;
  Widget? prefixWidget;
  Widget? suffixWidget;
  TextInputType? textInputType;
  Function(String)? onFieldSubmit;
  EdgeInsetsGeometry? prefixPadding;
  EdgeInsetsGeometry? suffixPadding;
  List<TextInputFormatter>? inputFormatters;
  int? maxLines;
  TextfieldDecorationType? textfieldDecorationType;
  bool? isTitleSpace;
  bool? isRequired;
  double? titleDistance;
  TextInputAction? textInputAction;

  CustomizableTextField({
    super.key,
    this.title,
    this.urduTitle,
    this.titleTextColor,
    this.titleFontSize,
    required this.controller,
    required this.hintText,
    required this.focusNode,
    required this.validator,
    required this.onChanged,
    required this.prefixIcon,
    required this.suffixIcon,
    required this.focusedIconColor,
    required this.unfocusedIconColor,
    required this.hideText,
    this.onSuffixIconPressed,
    this.readOnly = false,
    this.prefixWidget,
    this.suffixWidget,
    this.textInputType,
    this.onFieldSubmit,
    this.prefixPadding,
    this.suffixPadding,
    this.inputFormatters,
    this.maxLines,
    this.textfieldDecorationType,
    this.isTitleSpace,
    this.isRequired,
    this.titleDistance,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: (isTitleSpace ?? false) ? 8.w : 0.w),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Visibility(
                        visible: title != null,
                        child: PoppinsTextWidget(
                          fontsize: titleFontSize ?? 12.sp,
                          fontWeight: FontWeight.w500,
                          color: titleTextColor ?? Colors.black,
                          text: title ?? "",
                        ),
                      ),
                      Visibility(
                        visible: isRequired ?? false,
                        child: PoppinsTextWidget(
                          fontsize: titleFontSize ?? 12.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                          text: "*",
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Visibility(
                        visible: (isRequired ?? false) && urduTitle != null,
                        child: PoppinsTextWidget(
                          fontsize: titleFontSize ?? 12.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                          text: "*",
                        ),
                      ),
                      Visibility(
                        visible: urduTitle != null,
                        child: PoppinsTextWidget(
                          fontsize: titleFontSize ?? 12.sp,
                          fontWeight: FontWeight.w500,
                          color: titleTextColor ?? Colors.black,
                          textAlign: TextAlign.end,
                          text: urduTitle ?? "",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: (isTitleSpace ?? false) ? 8.w : 0.w),
          ],
        ),
        SizedBox(height: titleDistance ?? 0.h),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30.r),
            boxShadow: textfieldDecorationType == TextfieldDecorationType.Outline2
                ? [
                    // BoxShadow(
                    //   color: Colors.black.withOpacity(0.2),
                    //   offset: Offset(5, 5), // Shadow on bottom-left (to create depth)
                    //   blurRadius: 10,
                    //   spreadRadius: 0,
                    // ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3), // Shadow color
                      offset: Offset(2, 3), // Shadow offset
                      blurRadius: 5, // Shadow blur radius
                      spreadRadius: 0, // Spread radius
                    ),
                  ]
                : [],
          ),
          child: TextFormField(
            textCapitalization: TextCapitalization.sentences,
            controller: controller,
            focusNode: focusNode,
            obscureText: hideText,
            keyboardType: textInputType,
            decoration: (textfieldDecorationType == null)
                ? outlineDecoration(context)
                : (textfieldDecorationType == TextfieldDecorationType.Underline)
                    ? underlineDecoration(context)
                    : (textfieldDecorationType == TextfieldDecorationType.Outline2)
                        ? outlineDecoration2(context)
                        : outlineDecoration(context),
            cursorWidth: 2.w,
            inputFormatters: inputFormatters,
            readOnly: readOnly,
            validator: validator,
            onChanged: onChanged,
            onFieldSubmitted: onFieldSubmit,
            cursorColor: Colors.blue,
            style: GoogleFonts.poppins(
              textStyle: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.black, fontSize: 16.sp),
            ),
            maxLines: maxLines ?? 1,
            textInputAction: textInputAction ?? TextInputAction.done,
          ),
        ),
      ],
    );
  }

  InputDecoration underlineDecoration(BuildContext context) {
    return InputDecoration(
      contentPadding: EdgeInsets.only(left: 2.w, right: 20.w, top: 5.h, bottom: 5.h),
      border: const UnderlineInputBorder(borderSide: BorderSide(color: textFieldBorderColor)),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: textFieldBorderColor),
      ),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
      errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
      errorStyle: GoogleFonts.poppins(
        textStyle: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontSize: 12.sp, color: Colors.red),
      ),
      prefixIcon: prefixWidget != null
          ? Container(
              padding: prefixPadding ??
                  EdgeInsets.only(top: 16.h, bottom: 16.h, left: 20.w, right: 10.w),
              child: prefixWidget,
            )
          : prefixIcon == null
              ? null
              : Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18.w),
                  child: Icon(
                    prefixIcon,
                    color: (focusNode.hasFocus) ? focusedIconColor : unfocusedIconColor,
                  ),
                ),
      suffixIcon: (suffixWidget != null)
          ? Container(
              padding: suffixPadding ??
                  EdgeInsets.only(top: 16.h, bottom: 16.h, left: 20.w, right: 10.w),
              child: suffixWidget,
            )
          : suffixIcon == null
              ? null
              : Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18.w),
                  child: InkWell(
                    onTap: onSuffixIconPressed,
                    child: Icon(suffixIcon, color: unfocusedIconColor),
                  ),
                ),
      filled: true,
      fillColor: (focusNode.hasFocus) ? Colors.transparent : Colors.transparent,
      focusColor: Colors.black,
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(
        textStyle: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: hintColor, fontSize: 12.sp),
      ),
      errorMaxLines: 2,
    );
  }

  InputDecoration outlineDecoration(BuildContext context) {
    return InputDecoration(
      contentPadding: EdgeInsets.only(left: 14.w, right: 14.w, top: 18.h, bottom: 18.h),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: textFieldBorderColor),
        borderRadius: BorderRadius.circular(36.r),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: textFieldBorderColor),
        borderRadius: BorderRadius.circular(36.r),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: primaryColor),
        borderRadius: BorderRadius.circular(36.r),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(36.r),
      ),
      errorStyle: GoogleFonts.poppins(
        textStyle: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontSize: 12.sp, color: Colors.red),
      ),
      prefixIcon: prefixWidget != null
          ? Container(
              padding: prefixPadding ??
                  EdgeInsets.only(top: 16.h, bottom: 16.h, left: 20.w, right: 10.w),
              child: prefixWidget,
            )
          : prefixIcon == null
              ? null
              : Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18.w),
                  child: Icon(
                    prefixIcon,
                    color: (focusNode.hasFocus) ? focusedIconColor : unfocusedIconColor,
                  ),
                ),
      suffixIcon: (suffixWidget != null)
          ? Container(
              padding: suffixPadding ??
                  EdgeInsets.only(top: 16.h, bottom: 16.h, left: 20.w, right: 10.w),
              child: suffixWidget,
            )
          : suffixIcon == null
              ? null
              : Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18.w),
                  child: InkWell(
                    onTap: onSuffixIconPressed,
                    child: Icon(suffixIcon, color: unfocusedIconColor),
                  ),
                ),
      filled: true,
      fillColor: (focusNode.hasFocus) ? Colors.white : Colors.white,
      focusColor: Colors.black,
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(
        textStyle: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: hintColor, fontSize: 16.sp),
      ),
      errorMaxLines: 2,
    );
  }

  InputDecoration outlineDecoration2(BuildContext context) {
    return InputDecoration(
      contentPadding: EdgeInsets.only(left: 14.w, right: 14.w, top: 12.h, bottom: 12.h),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(14.r),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(14.r),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: primaryColor),
        borderRadius: BorderRadius.circular(14.r),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(14.r),
      ),
      errorStyle: GoogleFonts.poppins(
        textStyle: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontSize: 10.sp, color: Colors.red),
      ),
      prefixIcon: prefixWidget != null
          ? Container(
              padding: prefixPadding ??
                  EdgeInsets.only(top: 16.h, bottom: 16.h, left: 20.w, right: 10.w),
              child: prefixWidget,
            )
          : prefixIcon == null
              ? null
              : Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18.w),
                  child: Icon(
                    prefixIcon,
                    color: (focusNode.hasFocus) ? focusedIconColor : unfocusedIconColor,
                  ),
                ),
      suffixIcon: (suffixWidget != null)
          ? Container(
              padding: suffixPadding ??
                  EdgeInsets.only(top: 16.h, bottom: 16.h, left: 20.w, right: 10.w),
              child: suffixWidget,
            )
          : suffixIcon == null
              ? null
              : Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18.w),
                  child: InkWell(
                    onTap: onSuffixIconPressed,
                    child: Icon(suffixIcon, color: unfocusedIconColor),
                  ),
                ),
      filled: true,
      fillColor: (focusNode.hasFocus) ? Colors.white : Colors.white,
      focusColor: Colors.black,
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(
        textStyle: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: hintColor, fontSize: 12.sp),
      ),
      errorMaxLines: 2,
    );
  }
}
