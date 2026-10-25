# PC Remote 2.0 — prototype (LAN)

This is a **first working prototype**, not the full promised feature set. iOS SwiftUI client and Windows .NET 8 server.

## Windows 11
1. Install .NET 8 SDK.
2. Open PowerShell in `WindowsServer`.
3. Run `$env:PCREMOTE_PIN='choose-a-long-random-secret'`.
4. Run `dotnet run`.
5. Find PC's LAN IPv4 with `ipconfig`, allow private-network firewall access to TCP 8765.
6. Keep PowerShell open. This build does not install a Windows service or run while signed out.

## iPhone
1. Upload repository including hidden `.github` folder to GitHub.
2. Actions > Build PC Remote IPA > Run workflow.
3. Download IPA artifact and sign using a compatible sideloading solution; unsigned IPA is not installable directly.
4. Connect phone and PC to same Wi-Fi. Enter IPv4 and secret PIN in Settings.

## Currently implemented
- PIN-authenticated status and screen JPEG snapshot polling (~1.4fps).
- Mouse movement, clicks, arrow/enter/escape/space/backspace keys.
- Launch allowlisted Windows apps (Notepad, Calculator, Explorer).
- SwiftUI dark UI with Control / Screen / Apps, saved IP and PIN.

## Limitations / security
- HTTP LAN only; traffic and PIN are **not encrypted**. Use only on a trusted private network; never port-forward TCP 8765 to Internet. Future version should use TLS and secure pairing.
- iOS currently requests App Transport Security exceptions for LAN HTTP; tighten in production.
- No remote Wake-on-LAN, HUD editor, Bluetooth gamepad mapping, background service, Windows lock-screen control, true low-latency video, remote Internet access or power management yet.
- Mouse drag uses cumulative translation and may feel too fast; needs incremental gesture tracking.
- Windows screen capture requires an interactive desktop session; locked screen and service Session 0 are not supported.
- No Mac/Xcode or Windows .NET build tests were executed in this environment. Treat build as unverified.
