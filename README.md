# Natural Swipe Universal

面向已越狱 iOS 设备的通用 App 内自然滑动插件。项目通过 TrollFools 注入到目标 App，在目标 App 自己的进程内构造单指 `UITouch/UIEvent`，让原生列表、信息流等页面接收类似真实手指的上下滑动。

**触摸范围说明：本项目是目标 App 进程内触摸，不是系统全局顶层触摸。** 事件由注入的目标 App 自己构造并交给该 App 的 UIKit 事件队列处理，只影响当前被注入的 App；不会控制桌面、其他 App 或系统全局触摸。

本项目不注入 SpringBoard，不运行全局后台服务，也不监听网络端口。

## 用途

- 自动浏览信息流、商品列表、阅读列表等原生滚动页面。
- 设置随机滑动速度、滑动间隔、滑动次数。
- 次数设置为 `0` 时持续运行，轻点浮窗即可停止。
- 长按浮窗打开设置菜单。
- 记录当前 App 内的个人滑动轨迹，按个人起点、终点和速度曲线回放。
- 浮窗可以拖动贴左边或右边；5 秒没有真实触摸后收起为侧边小拉手，自动滑动仍继续。

## 设备测试

项目作者反馈：通用版已在越狱设备上通过 TrollFools 对多类普通 App 做过实机测试，大部分常见 App 可用。测试设备为：

| 设备 | 系统 | 环境 |
| --- | --- | --- |
| iPhone 13 Pro Max | iOS 15.3 | 越狱 + TrollFools App 注入 |
| iPhone 14 Pro Max（iPhone15,3） | iOS 16.5（20F66） | Dopamine rootless + TrollFools App 注入 |

测试目标为 arm64 普通 App 主进程。

不同 App 的界面和手势实现有差异，以上为作者实际使用反馈，不代表每个 App 均已逐一验证。原生 `UIScrollView`、`UITableView`、`UICollectionView` 信息流适配最好；复杂 SwiftUI、自定义手势、WKWebView、Unity/Metal 自绘页面可能仍需单独适配。项目不承诺所有 App 都兼容。

当前成品是 `arm64` dylib，最低目标 iOS 15.0；不要注入 SpringBoard、backboardd 或仅接受 arm64e 的系统进程。

## 用法

1. 下载 Release 中的 `NaturalSwipeUniversal.dylib`。
2. 在 TrollFools 中选择目标 App 的主 App，不要选择 SpringBoard 或 App 扩展。
3. 注入 `NaturalSwipeUniversal.dylib`。
4. 完全退出并重新打开目标 App，等待约 2 秒。
5. 看到右侧“滑动”浮窗后：
   - 轻点：按当前配置立即开始；运行中轻点停止。
   - 长按约 0.55 秒：打开菜单和设置。
   - 拖动后松手：自动贴边并记忆位置。
   - 小拉手轻点：展开并按当前配置运行。

每个 App 的配置、个人样本和事件日志分别写入该 App 容器的 `Documents/NaturalSwipe/`，不会共享拼多多或其他 App 的数据。

App 更新或重装后，TrollFools 注入通常需要重新执行。不要把通用版和本机的拼多多专用版同时注入同一个 App。

## 构建

本仓库提供源码和已签名成品。需要在 Minis/iSH 或相同的 Linux iOS 交叉编译环境中构建：

```sh
python3 build.py
```

默认使用：

- `/tmp/sdks/iPhoneOS16.5.sdk`
- Alpine/Linux clang
- LLVM lld
- 本项目使用的 Linux `ldid`

可以按本地环境调整 `build.py` 中的 SDK、clang 和签名工具路径。构建结果为：

```text
dist/NaturalSwipeUniversal.dylib
```

本仓库的 Release 同时提供：

- `NaturalSwipeUniversal.dylib`：TrollFools 直接注入文件。
- `NaturalSwipeUniversal-TrollFools-1.0.0.zip`：成品和简明说明。
- `NaturalSwipeUniversal-source-1.0.0.zip`：源码归档。

## 技术实现

插件在目标 App 进程内：

1. 通过 ElleKit 提供的 `MSHookMessageEx` 优先挂接 `UIApplication sendEvent:`。
2. ElleKit 不可用时，尝试 Objective-C runtime 备用挂钩。
3. 使用 `IOHIDEvent` 构造单指触摸的 HID 信息。
4. 通过 UIKit 私有触摸对象和 `UIApplication` 事件队列发送 Began、Moved、Ended、Cancelled 事件。
5. 由目标 App 自己的 UIKit 手势系统处理滚动。

通用版会跳过 App 扩展、SpringBoard 和 backboardd，并对重复初始化做保护。

## 开源参考与许可

本项目整体代码采用 Apache License 2.0，完整许可证见 [`LICENSE`](LICENSE)。

项目实现和研究参考：

- [KIF](https://github.com/kif-framework/KIF)：参考 `UITouch`、`UIEvent` 和 `IOHIDEvent` 的应用内触摸构造方式。KIF 使用 Apache-2.0，相关许可和归属见 [`licenses/KIF-NOTICE.txt`](licenses/KIF-NOTICE.txt)。
- [PTFakeTouch](https://github.com/xuan32546/PTFakeTouch)：参考用户态触摸和 Began/Moved/Ended 滑动调用方式。本项目没有直接打包 PTFakeTouch framework。
- [IOS13-SimulateTouch / ZXTouch](https://github.com/xuan32546/IOS13-SimulateTouch)：用于对比系统级录制回放方案；本项目没有采用其系统级服务路径。
- [iolate/SimulateTouch](https://github.com/iolate/SimulateTouch)：用于核对历史触摸事件格式；本项目没有直接复制其旧版系统服务实现。
- [Theos headers](https://github.com/theos/headers)：用于核对 `IOHIDEvent` 私有函数声明和 ABI。

第三方许可证文件保存在 [`licenses/`](licenses/)；本项目不包含任何密钥、设备地址、个人样本或专用 App 配置。

## 开发声明

本项目由作者在真实越狱设备环境中设计、实现、构建和验证，开发过程获得 **OpenAI 辅助**，包括代码设计、调试分析、文档整理和开源仓库发布协助。OpenAI 不属于本项目的版权所有者或运行维护者。

## 免责声明

本项目仅用于个人设备研究、辅助操作和 UIKit 触摸事件实验。请遵守目标 App 的服务条款和当地法律，不要用于绕过安全校验、刷量、欺诈或影响他人账户。使用者自行承担注入、签名、兼容性和数据风险。
