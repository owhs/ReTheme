#Requires AutoHotkey v2.0

; Create the main window with expanded dimensions
MainGui := Gui(, "AHK2 Component Showcase")
MainGui.OnEvent("Close", (*) => ExitApp())

; ==============================================================================
; MENU SYSTEMS
; ==============================================================================

FileMenu := Menu()
FileMenu.Add("E&xit", (*) => ExitApp())
AppMenuBar := MenuBar()
AppMenuBar.Add("&File", FileMenu)
MainGui.MenuBar := AppMenuBar

CtxMenu := Menu()
CtxMenu.Add("Context Action", (*) => MsgBox("Context menu triggered!"))
MainGui.OnEvent("ContextMenu", (*) => CtxMenu.Show())

BtnMenu := Menu()
BtnMenu.Add("Menu Option 1", (*) => UpdateStatus("Selected Option 1"))
BtnMenu.Add("Menu Option 2", (*) => UpdateStatus("Selected Option 2"))

; ==============================================================================
; TAB CONTROL & LAYOUT
; ==============================================================================

Tabs := MainGui.Add("Tab3", "x10 y10 w530 h510", ["Standard && Lists", "Advanced Views", "Buttons && Inputs", "Layout && Markup", "Specialised && Native"])
;Tabs.OnEvent("Change", (Ctrl, *) => (Ctrl.Value == 5) ? (DllCall("user32\IsWindowVisible", "Ptr", ChildPanel.Hwnd) ? 0 : DllCall("user32\ShowWindow", "Ptr", ChildPanel.Hwnd, "Int", 8)) : (DllCall("user32\IsWindowVisible", "Ptr", ChildPanel.Hwnd) ? DllCall("user32\ShowWindow", "Ptr", ChildPanel.Hwnd, "Int", 0) : 0))
Tabs.OnEvent("Change", (Ctrl, *) => Ctrl.Value == 5 ? ChildPanel.Show() : ChildPanel.Hide())


; ------------------------------------------------------------------------------
; TAB 1: Standard && Lists
; ------------------------------------------------------------------------------
Tabs.UseTab(1)

MainGui.Add("Text", "x30 y50", "Radio Buttons:")
MainGui.Add("Radio", "vRadio1 x30 y70", "Option A").OnEvent("Click", (*) => UpdateStatus("Selected Option A"))
MainGui.Add("Radio", "vRadio2 x30 y90", "Option B").OnEvent("Click", (*) => UpdateStatus("Selected Option B"))

MainGui.Add("Text", "x180 y50", "Checkboxes:")
MainGui.Add("CheckBox", "vCheck1 x180 y70", "Enable Feature X")
MainGui.Add("CheckBox", "vCheck2 x180 y90", "Enable Feature Y")

MainGui.Add("Text", "x340 y50", "Number Input (UpDown):")
NumEdit := MainGui.Add("Edit", "x340 y70 w60")
MainGui.Add("UpDown", "Range0-100", 50)

MainGui.Add("Text", "x30 y130", "Free-type Dropdown (ComboBox):")
MainGui.Add("ComboBox", "x30 y150 w200", ["Editable 1", "Editable 2"])

MainGui.Add("Text", "x280 y130", "List-only Dropdown (DropDownList):")
MainGui.Add("DropDownList", "x280 y150 w220 Choose1", ["Fixed Choice A", "Fixed Choice B"])

MainGui.Add("Text", "x30 y200", "Standard ListBox:")
MainGui.Add("ListBox", "x30 y220 w470 r8", ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5"])

; ------------------------------------------------------------------------------
; TAB 2: Advanced Views
; ------------------------------------------------------------------------------
Tabs.UseTab(2)

MainGui.Add("Text", "x30 y50", "ListView Control (Double-click a row):")
LV := MainGui.Add("ListView", "x30 y70 w220 h140", ["ID", "Item", "Colour"])
LV.Add("", "1", "Apple", "Red")
LV.Add("", "2", "Banana", "Yellow")
LV.Add("", "3", "Grape", "Purple")
LV.ModifyCol(1, 40)
LV.ModifyCol(2, 80)
LV.ModifyCol(3, 80)
LV.OnEvent("DoubleClick", (Ctrl, RowNum) => UpdateStatus("Double-clicked row " RowNum))

MainGui.Add("Text", "x280 y50", "TreeView Control:")
TV := MainGui.Add("TreeView", "x280 y70 w220 h140")
Parent1 := TV.Add("Root Node 1")
TV.Add("Child Node A", Parent1)
TV.Add("Child Node B", Parent1)
Parent2 := TV.Add("Root Node 2")
TV.Modify(Parent1, "Expand")

MainGui.Add("Text", "x30 y230", "Dropdown Calendar (DateTime):")
MainGui.Add("DateTime", "x30 y250 w180", "ShortDate")

MainGui.Add("Text", "x280 y230", "Month Calendar View (MonthCal):")
MainGui.Add("MonthCal", "x280 y250")

; ------------------------------------------------------------------------------
; TAB 3: Buttons && Inputs
; ------------------------------------------------------------------------------
Tabs.UseTab(3)

MainGui.Add("Button", "x30 y50 w110 h30", "Standard MsgBox").OnEvent("Click", (*) => MsgBox("Button clicked!"))
MainGui.Add("Button", "x150 y50 w110 h30", "Show ToolTip").OnEvent("Click", (*) => ShowTemporaryToolTip("This is a tooltip!"))

MainGui.Add("Checkbox", "x30 y100 w150 h30 +0x1000", "Toggle Button State")

BtnIcon := MainGui.Add("Button", "x190 y100 w150 h30 +0x40")
hIcon := LoadPicture("shell32.dll", "Icon44 w16", &imgType)
SendMessage(0xF7, 1, hIcon, BtnIcon.Hwnd)

MainGui.Add("Button", "x350 y100 w150 h30", "Dropdown Menu ▼").OnEvent("Click", (*) => BtnMenu.Show())

MainGui.Add("Text", "x30 y160", "Slider & Connected Progress Bar:")
Sld := MainGui.Add("Slider", "x30 y180 w230 Range0-100", 30)
Prg := MainGui.Add("Progress", "x30 y220 w230 h20", 30)
Sld.OnEvent("Change", (Ctrl, *) => Prg.Value := Ctrl.Value)

MainGui.Add("Text", "x30 y270", "Hotkey Input Control:")
MainGui.Add("Hotkey", "x30 y290 w230 vMyHotkey")

; ------------------------------------------------------------------------------
; TAB 4: Layout && Markup
; ------------------------------------------------------------------------------
Tabs.UseTab(4)

MainGui.Add("GroupBox", "x30 y50 w470 h70", "Grouped Section")
MainGui.Add("Picture", "x45 y74 w24 h24 Icon20", "shell32.dll")
MainGui.Add("Link", "x85 y78", 'Visit the <a href="https://www.autohotkey.com">AutoHotkey Website</a>')

MainGui.Add("Text", "x30 y140 w470 h2 +0x10")

MainGui.Add("Text", "x30 y160 w210", "Left side text block.")
MainGui.Add("Text", "x255 y160 w2 h130 +0x11")
MainGui.Add("Text", "x270 y160 w230", "Right side text block.")

MainGui.Add("Text", "x30 y300", "Multi-line Edit Field:")
MainGui.Add("Edit", "x30 y320 w470 h90", "Line 1`nLine 2`nLine 3")

; ------------------------------------------------------------------------------
; TAB 5: Specialised && Native
; ------------------------------------------------------------------------------
Tabs.UseTab(5)

; ActiveX Control
MainGui.Add("Text", "x30 y50", "ActiveX Control (Embedded HTML Document Engine):")
IE := MainGui.Add("ActiveX", "x30 y70 w470 h100", "htmlfile")
HTMLDoc := IE.Value
HTMLDoc.open()
HTMLDoc.write("<html><body style='font-family:sans-serif;font-size:11px;background:#fcfcfc;margin:10px;'><b>Hello World!</b><br>This is native HTML rendered via ActiveX.</body></html>")
HTMLDoc.close()

; Custom Control
MainGui.Add("Text", "x30 y180", "Custom Control (SysIPAddress32):")
MainGui.Add("Custom", "ClassSysIPAddress32 x30 y200 w130 h21")

; Password Input Style Modifier
MainGui.Add("Text", "x180 y180", "Password Input (+Password):")
MainGui.Add("Edit", "x180 y200 w140 h21 +Password", "SecretText")

; Read Only Input Style Modifier
MainGui.Add("Text", "x340 y180", "Read-Only Field (+ReadOnly):")
MainGui.Add("Edit", "x340 y200 w160 h21 +ReadOnly", "Cannot modify this text")

; Checkbox-enabled ListView Variant
MainGui.Add("Text", "x30 y240", "ListView Variant with Checkboxes (+Checked):")
LV2 := MainGui.Add("ListView", "x30 y260 w470 h110 +Checked", ["Feature", "Status"])
LV2.Add("", "Auto-backup on exit", "Enabled")
LV2.Add("", "Minimise to system tray", "Disabled")
LV2.Modify(1, "+Check")

; Child GUI Container Panel Framework
MainGui.Add("Text", "x30 y385", "Child GUI Panel Container (Acts as a functional sub-window framework):")

ChildPanel := Gui("-Caption +Border")
ChildPanel.Add("Button", "x10 y10 w100 h24", "Panel Button 1")
ChildPanel.Add("Button", "x120 y10 w100 h24", "Panel Button 2")
ChildPanel.Add("Edit", "x10 y42 w430 h22", "Contained dynamically inside the structural child panel")
ChildPanel.Opt("+Parent" . MainGui.Hwnd)

; Keeps panel hidden initially since Tab 1 loads first
ChildPanel.Show("x30 y405 w470 h75 Hide")

Tabs.UseTab()

; ==============================================================================
; STATUS BAR & HELPERS
; ==============================================================================

SB := MainGui.Add("StatusBar")
SB.SetParts(220, 160)
SB.SetText(" Ready", 1)
SB.SetText(" Environment: Production", 2)
SB.SetText(" v2.0", 3)

UpdateStatus(Text) {
    SB.SetText(" " . Text, 1)
}

ShowTemporaryToolTip(Text) {
    ToolTip(Text)
    SetTimer(() => ToolTip(), -2000)
}


#Include ReTheme.ahk ; immediately applies hooks
RT.Apply(MainGui.Hwnd) ; optional - removes initial window flicker

MainGui.Show("w550 h560")