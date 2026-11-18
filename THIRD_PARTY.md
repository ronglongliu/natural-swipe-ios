# 开源参考与许可

实现参考了 [KIF](https://github.com/kif-framework/KIF) 的应用内触摸构造方式：`UITouch-KIFAdditions.m`、`UIEvent+KIFAdditions.m`、`IOHIDEvent+KIF.m`、`UIView-KIFAdditions.m`。核对提交：`357a70fe0ccfb8ae5097d6ac14d0f010b376787d`（2026-10-16）。KIF 为 Apache-2.0；版权声明和许可证在 `licenses/`。核心方法是构造单个 UITouch、附加 HID 数据，交给本进程 UIApplication.sendEvent，随后由 UIKit 手势系统处理。

[PTFakeTouch](https://github.com/xuanxt/PTFakeTouch)，核对提交 `52ebb969f84f16e3e4e462dd34a542fb71426054`（2024-09-12），README 明确是 User mode 并列出 Began/Moved/Ended 滑动示例，声明 additions 来自 KIF。本项目没有直接集成该 framework，也没有其100个预分配触点；以 KIF 上游许可实现最小单触点引擎。

其他仓库：

- [IOS13-SimulateTouch / ZXTouch](https://github.com/xuan32546/IOS13-SimulateTouch)：README 是 iOS11–14 的 system-wide 触摸自动化和录制回放，自己也指向 PTFakeTouch 作为 application-wide 选择。本项目未采用其系统级服务路径。
- [iolate/SimulateTouch](https://github.com/iolate/SimulateTouch)：经典系统级模拟触摸库；可参考历史事件格式，未将其旧版兼容性当作iOS16适配证据。
- [Theos 私有 IOHIDEvent.h](https://github.com/theos/headers/blob/master/IOKit/hid/IOHIDEvent.h)：核实 AbsoluteTime、DigitizerFingerEventWithQuality、IOHIDEventAppendEvent 双参数和整数 setter ABI。

原拼多多专用版的 iOS16.5 运行证据来自本机独立验收 App 和拼多多目标进程。本通用分支按用户要求未做运行测试；原版测试结果不能直接作为通用版兼容性证明。
