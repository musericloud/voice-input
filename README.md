# VoiceInput

macOS 菜单栏语音输入工具。按住 Fn 键说话，松开后将转录文字自动注入当前聚焦的输入框。

## 功能

- **按住 Fn 录音**：通过 CGEvent tap 全局监听 Fn 键，抑制系统 emoji 选择器
- **流式语音识别**：基于 Apple Speech Recognition framework，实时显示转录文本
- **多语言支持**：简体中文（默认）、英语、繁体中文、日语、韩语，菜单栏一键切换
- **HUD 悬浮窗**：屏幕底部居中的无边框胶囊面板，青蓝渐变波形动画由实时音频 RMS 驱动
- **智能粘贴**：自动检测 CJK 输入法，临时切换 ASCII 键盘确保 Cmd+V 不被拦截，完成后恢复原输入法和剪贴板
- **LLM 纠错**（可选）：通过 OpenAI 兼容 API 修正语音识别错误、补充标点、去除口头语气词

## 系统要求

- macOS 14.0+
- Xcode Command Line Tools（构建）

## 构建与安装

```bash
# 构建
make build

# 构建并打包为签名的 .app
make package

# 打包并直接运行
make run

# 安装到 /Applications
make install

# 清理构建产物
make clean
```

## 权限设置

首次运行后需在 **系统设置 → 隐私与安全性** 中授权：

| 权限 | 用途 | 授权方式 |
|------|------|----------|
| 辅助功能 | Fn 键全局监听 + 模拟 Cmd+V | 手动添加应用 |
| 麦克风 | 录音 | 首次按 Fn 时自动弹窗 |
| 语音识别 | Apple Speech 转录 | 首次按 Fn 时自动弹窗 |

> 重新编译安装后签名变化，需在辅助功能中删除旧条目并重新添加。

## 使用

1. 启动后菜单栏出现波形图标
2. 按住 **Fn** 键说话，屏幕底部弹出悬浮窗实时显示转录
3. 松开 **Fn** 键，文字自动粘贴到当前光标位置
4. 点击菜单栏图标可切换识别语言

## LLM 纠错配置

1. 菜单栏图标 → **LLM Refinement** → **Settings…**
2. 填写 API Base URL、API Key、Model，点 **Test** 验证后 **Save**
3. 回到菜单勾选 **Enable Refinement**

启用后松开 Fn 键会先经过 LLM 处理（悬浮窗显示 "Refining..."），修正语音识别错误、补充标点、去除口头语气词后再注入文本。

## 项目结构

```
Sources/VoiceInput/
├── VoiceInput.swift           # 应用入口
├── AppDelegate.swift          # 菜单栏、窗口管理
├── FnKeyMonitor.swift         # CGEvent tap 全局 Fn 键监听
├── RecordingController.swift  # 录音 + 语音识别 + RMS 处理
├── RecordingOverlayPanel.swift # HUD 悬浮窗面板
├── WaveformBarsView.swift     # 渐变色波形条动画
├── PasteInjector.swift        # 剪贴板注入 + Cmd+V 模拟
├── InputSourceManager.swift   # CJK 输入法检测与切换
├── LLMRefinementService.swift # OpenAI 兼容 API 调用
├── LLMSettingsView.swift      # LLM 设置界面 (SwiftUI)
├── AppSettings.swift          # UserDefaults 持久化
├── LLMConfig.swift            # LLM 配置数据结构
├── KeychainStore.swift        # Keychain 存储（遗留迁移用）
└── VoiceLanguage.swift        # 语言枚举
Resources/
├── Info.plist                 # 应用配置 (LSUIElement)
└── VoiceInput.entitlements    # 权限声明
```

## 技术细节

- **LSUIElement 模式**：仅菜单栏图标，无 Dock 图标
- **Fn 键抑制**：CGEvent tap 拦截 `flagsChanged` 中的 `maskSecondaryFn`，返回 `nil` 阻止事件传递
- **波形驱动**：音频 tap 计算 RMS → attack/release 平滑包络 → 7 根竖条加权 + 随机抖动
- **输入法安全粘贴**：检测非键盘布局的输入源 → 临时切换 ASCII → Cmd+V → 恢复原输入法 + 剪贴板
- **构建产物**：Swift Package Manager → ad-hoc 签名的 `.app` bundle
