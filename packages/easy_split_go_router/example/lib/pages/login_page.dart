import 'package:flutter/material.dart';

/// 登录页：匿名 MaterialPageRoute 直接 push —— 拦截器不转换，天然全屏
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: const Center(child: Text('全屏页面（fullscreen）')),
    );
  }
}
