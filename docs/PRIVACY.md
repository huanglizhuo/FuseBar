# FuseBar Privacy Policy

Effective September 17, 2026. Developer: Huang Lizhuo.

FuseBar is a free macOS menu bar utility. It has no account, advertising, analytics SDK, or developer-operated backend. FuseBar does not collect or transmit your battery, Wi-Fi, Bluetooth, audio, or location information to the developer or third parties.

## Information processed on your Mac

FuseBar reads battery and charging status, Wi-Fi connection and signal status, and audio output status to display them locally. It can adjust output volume and mute when supported, and select the default media output device. Preferences are stored locally using macOS UserDefaults.

Bluetooth access is optional and used to show Bluetooth power and the connection state of paired devices. FuseBar does not scan for or pair devices. Location permission is optional and used because macOS restricts access to Wi-Fi network names and scans. Network scanning only starts when you request it. You can explicitly request a Wi-Fi power change or connection to a supported network. Wi-Fi passwords are used for the current connection attempt and are not saved by FuseBar or included in its logs. FuseBar does not request location coordinates or start location updates. Declining optional permissions leaves the other status features available.

FuseBar displays running applications and stores your pinned application identifiers and their order locally. File and folder shortcuts are added through the macOS file picker. Their display names and security-scoped bookmarks are stored on your Mac; FuseBar does not upload their paths or contents. Removing a shortcut does not delete the original file.

You can revoke permissions in System Settings and disable launch at login in the app or macOS settings. FuseBar does not automatically hide other menu bar icons.

## External links and support

Opening support or privacy links launches your browser. GitHub and Apple operate their own services under their own privacy policies. If you contact support or post a GitHub issue, information you voluntarily provide is used to respond to your request. GitHub issues are public; do not include passwords or sensitive personal information.

## Contact

Contact Huang Lizhuo at lizhuo.huang@outlook.com, or use [GitHub Issues](https://github.com/huanglizhuo/FuseBar/issues).

Changes to this policy will be published here with an updated effective date.

### Coding workspace preferences

FuseBar stores optional keyboard shortcut settings, pinned application identifiers/bookmarks, and user-created project names, folder bookmarks, and preview/repository URLs locally in app preferences. Application search reads common application directories on demand and does not index project file contents. Opening a saved web address hands it to your default browser; that browser then connects to the destination you configured. Project entries do not run shell commands or start development servers. Removing a project removes its FuseBar configuration, not its files.

FuseBar reads enabled keyboard input sources, their names and icons, and the current selection locally. When you select an input source, it asks macOS to switch to it. FuseBar does not read keystrokes, typed text, or input-method candidates, and does not transmit input-source information.

To sort the app shelf by recent use, FuseBar observes application activation and launch events and stores up to 100 application bundle identifiers in local preferences. It does not store window titles, document contents, or usage durations, and does not upload this ordering.
