# FuseBar Privacy Policy

Effective October 5, 2026. Developer: Huang Lizhuo.

FuseBar is a free macOS menu bar utility. It has no account, advertising, analytics SDK, or developer-operated backend. FuseBar does not collect or transmit your battery, Wi-Fi, Bluetooth, audio, or location information to the developer or third parties.

## Information processed on your Mac

FuseBar reads battery and charging status (including the system's time-remaining estimate and Low Power Mode state), Wi-Fi connection and signal status, and audio output status to display them locally. It can adjust output volume and mute when supported, and select the default media output device. Preferences are stored locally using macOS UserDefaults.

Bluetooth access is optional and used to show paired devices and to connect or disconnect them when you click. FuseBar does not scan for or pair devices. For Bluetooth audio devices, system display names are matched by exact device identifiers and cached in local preferences so renamed headphones keep their display name while disconnected. This cache stays on your Mac and entries are removed when the device no longer appears in the paired list. Location permission is optional and used because macOS restricts access to Wi-Fi network names and scans. Network scanning only starts when you request it. You can explicitly request a Wi-Fi power change or connection to a supported network. Wi-Fi passwords are used for the current connection attempt and are not saved by FuseBar or included in its logs. FuseBar does not request location coordinates or start location updates. Declining optional permissions leaves the other status features available.

FuseBar displays your running applications; it does not keep pinned or favorite apps. File and folder shortcuts are added through the macOS file picker. Their display names and security-scoped bookmarks are stored on your Mac; FuseBar does not upload their paths or contents. Removing a shortcut does not delete the original file.

You can revoke permissions in System Settings and disable launch at login in the app or macOS settings. FuseBar does not automatically hide other menu bar icons.

## External links and support

Opening support, privacy, or release links launches your browser; FuseBar does not check for updates in the background. GitHub and Apple operate their own services under their own privacy policies. If you contact support or post a GitHub issue, information you voluntarily provide is used to respond to your request. GitHub issues are public; do not include passwords or sensitive personal information.

## Contact

Contact Huang Lizhuo at lizhuo.huang@outlook.com, or use [GitHub Issues](https://github.com/huanglizhuo/FuseBar/issues).

Changes to this policy will be published here with an updated effective date.

### Coding workspace preferences

FuseBar stores optional keyboard shortcut settings and user-created project names, folder bookmarks, and preview/repository URLs locally in app preferences. Application search reads common application directories on demand and does not index project file contents. Unified search also uses file shortcuts you explicitly added and built-in actions. Matching, including pinyin for Chinese names, runs on your Mac; search queries and search history are not saved. Opening a saved web address hands it to your default browser; that browser then connects to the destination you configured. Project entries do not run shell commands or start development servers. A project can also store the bundle identifier of the app you choose to open its folder. Removing a project removes its FuseBar configuration, not its files.

FuseBar reads enabled keyboard input sources, their names and icons, and the current selection locally. When you select an input source, it asks macOS to switch to it. FuseBar does not read keystrokes, typed text, or input-method candidates, and does not transmit input-source information.

To sort the app shelf by recent use, FuseBar observes application activation and launch events and stores up to 100 application bundle identifiers in local preferences. It does not store window titles, document contents, or usage durations, and does not upload this ordering.

### Wi-Fi 沙盒访问与声音连接补充（2026-09-21）

App Sandbox 增加标准 `com.apple.security.network.client` 权限，用于 CoreWLAN 访问系统 Wi-Fi 服务；此权限本身也允许出站连接，但 FuseBar 未新增外部请求、遥测或上传代码。定位授权仍仅用于读取 Wi-Fi 名称和用户按需扫描，不启动位置采集。声音菜单可显示已配对音频设备，点击后尝试蓝牙连接并选择对应的本机媒体输出；不会自动断开耳机或操作键盘鼠标。

### Data from earlier versions

Earlier versions could store pinned app identifiers and bookmarks (`pinnedApplications`, `applicationBookmarks`) and the identifiers of recently used menu actions (`menuRecentActions`). Current versions neither read nor write these keys; any existing values remain only in FuseBar's local preferences on your Mac.

### Diagnostics

Settings → Diagnostics shows a summary of states and counts for support requests, such as whether Wi-Fi is connected or how many input sources are enabled. It excludes Wi-Fi, device, file and project names, and includes the latest error message as shown in FuseBar. It is copied to the clipboard only when you click Copy; FuseBar never sends it anywhere.
