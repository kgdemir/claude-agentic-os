# Windows desktop (.NET)

Applies to WinForms, WPF and WebView2 apps and Visual Studio extensions (VSIX). Linux build limits:
`NETSDK1100` in `~/.claude/guides/stacks/dotnet-gotchas.md`.

- **Build and test these projects on Windows,** or exclude them from Linux builds explicitly (build the other project files, or `-p:EnableWindowsTargeting=true` where only targeting is missing). Say in the reply when a Windows-only project could not be built here.
  *Why: a green Linux run that skipped the desktop project proves nothing about it.*
- **UI controls are touched only on the UI thread** (`Control.Invoke` / `BeginInvoke`, `Dispatcher.InvokeAsync`); background work never blocks it with `.Result` or `.Wait()`.
  *Why: a cross-thread call throws or corrupts the control; a blocked UI thread freezes the window.*
- **WebView2: check for the runtime at startup** (`CoreWebView2Environment.GetAvailableBrowserVersionString`) and show a clear message or install the Evergreen runtime; set a user data folder the app can write to.
  *Why: without the runtime, initialization throws on machines that never installed Edge WebView2.*
