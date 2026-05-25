import 'package:flutter/material.dart';

class CustomSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final String hintText;

  const CustomSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
    this.onClear,
    this.hintText = 'ابحث هنا...',
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  bool _showClearButton = false;

  @override
  void initState() {
    super.initState();
    // مراقبة النص لإظهار أو إخفاء زر المسح (X)
    widget.controller.addListener(() {
      setState(() {
        _showClearButton = widget.controller.text.isNotEmpty;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // لون خلفية حقل البحث
        borderRadius: BorderRadius.circular(15), // حواف دائرية ناعمة وعصرية
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01), // ظل خفيف جداً لإعطاء عمق
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
        textDirection: TextDirection.rtl, // يدعم الواجهات العربية بشكل ممتاز
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15,fontWeight: FontWeight.bold,),
          hintTextDirection: TextDirection.rtl,
          // أيقونة البحث في البداية (من اليمين للغة العربية)
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.grey.shade500,
            size: 24,
          ),
          // زر المسح يظهر فقط عند وجود نص داخل الحقل
          suffixIcon: _showClearButton
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  onPressed: () {
                    widget.controller.clear();
                    if (widget.onClear != null) widget.onClear!();
                  },
                )
              : null,
          // إزالة الحدود الافتراضية المزعجة والاعتماد على تصميم الـ Container
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
        ),
      ),
    );
  }
}
