Main := Gui("-Resize", "Custom Component Themeing")
Main.SetFont("s10", "Consolas")

customBtn := Main.Add("Button", "x20 y10 w400 h40", "Hooked Button")

chk := Main.Add("CheckBox", "x20 y60 w400 h20", "Disable Button")
chk.OnEvent("Click", (ctrl, *) => customBtn.Enabled := !ctrl.Value)

;#region Themeing

#Include ReTheme.ahk
MyConfig := Map(
    "Accent", "448e3a"
)
RT.Init(RT.Palette(MyConfig))
RT.Config.EnableEditorHotkey := false
RT.CtlCache[customBtn.Hwnd] := Map(
    "Bg", "FF003C",
    "Fg", "00FFEA",
    "Border", "333344",
    "HoverBg", "ffffff",
    "HoverFg", "000000",
    "HoverBorder", "000000",
    "PressedBg", "00ff00",
    "PressedFg", "0026ff",
    "PressedBorder", "ff00ff",
    "DisabledBg", "000000",
    "DisabledFg", "ff0000",
    "DisabledBorder", "ffff00",
    "Cursor", "UpArrow"
)
RT.Apply(Main.Hwnd)

;#endregion

Main.Show("w440 h100")