# ReTheme for AutoHotkey v2

ReTheme is a skinning and custom theme engine for AutoHotkey v2 GUI windows. It supports dark mode, custom color schemes, system menu integrations, and an interactive live Theme Editor.

See - https://www.autohotkey.com/boards/viewtopic.php?f=83&t=140841

## Basic Usage

To apply the default theme (Default Dark) to a GUI window, include the script and call `Apply` with the window's HWND:

```autohotkey
#Include ReTheme.ahk ; immediately applies hooks
RT.Apply(MainGui.Hwnd) ; optional - removes initial window flicker
```

---

## Configuration Properties

You can customize ReTheme by modifying the static properties in the `RT.Config` class before calling `RT.Apply()` or `RT.Init()`:

```autohotkey
; Disable the automatic hotkey
RT.Config.EnableEditorHotkey := false

; Change the theme editor shortcut key combination
RT.Config.EditorHotkey := "^+e" ; Ctrl+Shift+E

; Apply a different default theme from themes.ini
RT.Config.DefaultTheme := "Midnight Purple"

; Disable automatic "Themes" menu generation
RT.Config.AddThemesMenu := false
```

### Configuration Reference

| Property | Default Value | Description |
| :--- | :--- | :--- |
| `RT.Config.Robust` | `true` | Safeguards subclass callback depths to prevent message loops. |
| `RT.Config.AutoInheritBg` | `true` | Controls automatic background color inheritance for Static and Link controls inside container controls (e.g. GroupBoxes). |
| `RT.Config.EnableEditorHotkey` | `true` | If true, enables the hotkey to open the live Theme Editor. |
| `RT.Config.EditorHotkey` | `^+t` | The AutoHotkey key combination pattern for the Theme Editor hotkey (Default: Ctrl+Shift+T). |
| `RT.Config.DefaultTheme` | `"Default Dark"` | The default theme name from `themes.ini` or custom map to apply. |
| `RT.Config.AddThemesMenu` | `true` | Injects a "Themes" dropdown into the window menu bar (if the window has a MenuBar). |
| `RT.Config.AddEditorToMenu` | `true` | Appends "Theme Editor..." to the bottom of the generated Themes menu. |
| `RT.Config.ButtonCursor` | `"Hand"` | Hover cursor for push buttons, checkboxes, radios, and tab buttons. |
| `RT.Config.InputCursor` | `"IBeam"` | Hover cursor for standard edits and hotkeys. |
| `RT.Config.DropdownCursor` | `"Hand"` | Hover cursor for dropdown ComboBoxes and dropdown list items. |
| `RT.Config.SliderCursor` | `"Hand"` | Hover cursor for sliders/trackbars. |
| `RT.Config.MenuCursor` | `"Hand"` | Hover cursor for the window MenuBar. |

---

## Initialization & Overrides (`RT.Init`)

You can initialize `ReTheme` with custom theme presets, rule maps, and configuration overrides via `RT.Init`:

```autohotkey
; Signature:
RT.Init(themeOrPalette := "", rulesArray := "", configMap := "")
```

### Examples

**1. Initialize with a specific theme name:**
```autohotkey
RT.Init("Dracula")
```

**2. Initialize with a custom color preset map:**
```autohotkey
PresetMap := Map(
    "BaseBg",  "1A1B26",
    "Surface", "24283B",
    "Text",    "A9B1D6",
    "Accent",  "7AA2F7",
    "Border",  "383E56",
    "Header",  "1F2335",
    "FgDim",   "565F89"
)
RT.Init(PresetMap)
```

**3. Initialize with configuration overrides:**
```autohotkey
Overrides := Map(
    "EnableEditorHotkey", true,
    "EditorHotkey", "+!t" ; Shift+Alt+T
)
RT.Init("Ocean Dark", "", Overrides)
```

---

## Theme Editor Shortcut

By default, pressing **Ctrl+Shift+T** (`^+t`) launches the interactive Theme Editor. 

- This hotkey is context-sensitive and only triggers when a themed GUI window is active.
- The editor lets you preview and choose colors in real-time using native Windows Color Picker dialogs, and save them back to `themes.ini`.

---

## Menu Integration APIs

While the Theme Editor is automatically added to the window's main MenuBar by default (controlled by `RT.Config.AddEditorToMenu`), you can manually integrate it into other menus:

### Custom or Context Menus

To append the Theme Editor option to custom menu objects or context (right-click) menus:

```autohotkey
MyMenu := Menu()
MyMenu.Add("My Action", (*) => MsgBox())

RT.AddThemeEditorToMenu(MyMenu)
```

### Window System Menu

To add the Theme Editor to the window's native system menu (accessed by right-clicking the window title bar):

```autohotkey
RT.AddThemeEditorToSystemMenu(MainGui.Hwnd)
```

---

## Custom Cursors & Rule Customization

ReTheme allows you to control hover cursors and apply customized styles dynamically.

### Global Cursors

You can configure global hover cursor styles by modifying the `RT.Config` options before initializing or applying themes:

```autohotkey
RT.Config.ButtonCursor := "Hand"
RT.Config.InputCursor := "IBeam"
```

Available named cursors: `"Hand"`, `"Arrow"`, `"IBeam"`, `"Wait"`, `"Cross"`, `"UpArrow"`, `"Size"`, `"No"`, `"Help"`, etc. Set to `""` to disable custom cursors for that category.

### Selector & Control Name Rules

When initializing the engine with `RT.Init(Palette, MyRules)`, you can provide a list of rule maps to match controls by class or by their AutoHotkey variable/control `Name`:

```autohotkey
MyRules := [
    ; Target by Win32 Class Name
    Map("Selector", "Edit", "Bg", "Surface", "Fg", "Text", "Border", "Accent", "Cursor", "IBeam"),
    
    ; Target specifically by the control name tag (v-variable)
    Map("Selector", "submitBtn", "Bg", "Accent", "Fg", "BaseBg")
]
RT.Init(RT.Palette(MyConfig), MyRules)
```

### Specific HWND Rule Customization (CtlCache Overriding)

For runtime styling overrides of individual controls, you can write directly to `RT.CtlCache` using the control's `Hwnd` **before** calling `RT.Apply(MainGui.Hwnd)`:

```autohotkey
customBtn := MainGui.Add("Button", "w200 h40", "Click Me")

RT.CtlCache[customBtn.Hwnd] := Map(
    "Bg", "FF003C",
    "Fg", "00FFEA",
    "Border", "333344",
    "HoverBg", "FFFFFF",
    "HoverFg", "000000",
    "HoverBorder", "000000",
    "PressedBg", "00FF00",
    "PressedFg", "FF0000",
    "PressedBorder", "000000",
    "CheckedBg", "FF00FF",
    "CheckedFg", "000000",
    "CheckedBorder", "FF00FF",
    "DisabledBg", "000000",
    "DisabledFg", "FF0000",
    "DisabledBorder", "000000",
    "Cursor", "Hand"
)

RT.Apply(MainGui.Hwnd)
```

---

### Style Override Keys Reference

Here are all the keys you can specify in your custom rule maps (for `MyRules` or `RT.CtlCache` HWND overrides):

| Key | Description | Applicable Controls |
| :--- | :--- | :--- |
| `Bg` | Default background color. | All subclassed controls |
| `Fg` | Default text (foreground) color. | All subclassed controls |
| `Border` | Default border color. | All subclassed controls with borders |
| `HoverBg` | Background color when mouse hovers. | Buttons, Checkboxes, Radios |
| `HoverFg` | Text color when mouse hovers. | Buttons, Checkboxes, Radios |
| `HoverBorder` | Border color when mouse hovers. | Buttons, Checkboxes, Radios |
| `PressedBg` | Background color when clicked/pressed. | Buttons, Checkboxes, Radios |
| `PressedFg` | Text/Icon color when clicked/pressed. | Buttons, Checkboxes, Radios |
| `PressedBorder` | Border color when clicked/pressed. | Buttons, Checkboxes, Radios |
| `CheckedBg` | Background color when checked/toggled. | Checkboxes, Radios, Toggled Buttons |
| `CheckedFg` | Dot/Checkmark/Text color when checked. | Checkboxes, Radios, Toggled Buttons |
| `CheckedBorder` | Border color when checked/toggled. | Checkboxes, Radios, Toggled Buttons |
| `DisabledBg` | Background color when disabled. | Buttons, Checkboxes, Radios |
| `DisabledFg` | Text/Icon color when disabled. | Buttons, Checkboxes, Radios |
| `DisabledBorder` | Border color when disabled. | Buttons, Checkboxes, Radios |
| `FocusedBg` | Background color when focused. | Buttons |
| `FocusedFg` | Text color when focused. | Buttons |
| `FocusedBorder` | Border color when focused. | Edits, ComboBoxes, ListBoxes, Hotkeys, Buttons |
| `Cursor` | Custom hover mouse cursor (name or Resource ID). | All subclassed controls |

---

### Cursors Reference List

You can assign these named string cursors (or a custom Win32 Resource ID integer) globally to `RT.Config` properties or to the `"Cursor"` rule key:

| Cursor Name | Win32 Identifier | Visual Indicator |
| :--- | :--- | :--- |
| `"Hand"` | `IDC_HAND` (32649) | Clicking hand pointer (typically for links/buttons) |
| `"Arrow"` | `IDC_ARROW` (32512) | Standard selection arrow |
| `"IBeam"` | `IDC_IBEAM` (32513) | Text editing insertion point cursor |
| `"Wait"` | `IDC_WAIT` (32514) | Hourglass / spinning wheel (busy cursor) |
| `"Cross"` | `IDC_CROSS` (32515) | Crosshair pointer |
| `"UpArrow"` | `IDC_UPARROW` (32516) | Vertical arrow pointing straight up |
| `"Size"` / `"SizeAll"` | `IDC_SIZEALL` (32646) | Four-pointed moving arrow |
| `"SizeNWSE"` | `IDC_SIZENWSE` (32642) | Double-pointed diagonal resizing arrow (NW to SE) |
| `"SizeNESW"` | `IDC_SIZENESW` (32643) | Double-pointed diagonal resizing arrow (NE to SW) |
| `"SizeWE"` | `IDC_SIZEWE` (32644) | Double-pointed horizontal resizing arrow (W to E) |
| `"SizeNS"` | `IDC_SIZENS` (32645) | Double-pointed vertical resizing arrow (N to S) |
| `"No"` | `IDC_NO` (32648) | Slashing "Not Allowed" circle |
| `"AppStarting"` | `IDC_APPSTARTING` (32650) | Arrow pointer with a small busy hourglass |
| `"Help"` | `IDC_HELP` (32651) | Arrow pointer with a question mark |
