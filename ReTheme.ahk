#Requires AutoHotkey v2.0

class RT {
    class Config {
        static Robust := true
        static AutoInheritBg := true
        static EnableEditorHotkey := true
        static EditorHotkey := "^+t"
        static DefaultTheme := "Default Dark"
        static AddThemesMenu := true
        static AddEditorToMenu := true
        static ButtonCursor := "Hand"
        static InputCursor := "IBeam"
        static DropdownCursor := "Hand"
        static SliderCursor := "Hand"
        static MenuCursor := "Hand"
    }

    ; --- Common Win32/GDI Static Wrappers ---
    static P(x64, x32) => A_PtrSize == 8 ? x64 : x32
    static Rect(l := 0, t := 0, r := 0, b := 0) {
        buf := Buffer(16, 0)
        NumPut("Int", l, "Int", t, "Int", r, "Int", b, buf)
        return buf
    }
    class RectObj {
        __New(h := 0, client := 0) {
            this.buf := Buffer(16, 0)
            if h
                DllCall(client ? "user32\GetClientRect" : "user32\GetWindowRect", "Ptr", h, "Ptr", this.buf.Ptr)
        }
        Ptr => this.buf.Ptr
        L => NumGet(this.buf, 0, "Int")
        T => NumGet(this.buf, 4, "Int")
        R => NumGet(this.buf, 8, "Int")
        B => NumGet(this.buf, 12, "Int")
        W => this.R - this.L
        H => this.B - this.T
    }
    static GetMappedRect(hwnd, parent) {
        rc := RT.RectObj(hwnd)
        DllCall("user32\MapWindowPoints", "Ptr", 0, "Ptr", parent, "Ptr", rc.Ptr, "UInt", 2)
        return rc
    }
    static Send(h, m, w := 0, l := 0) => DllCall("user32\SendMessageW", "Ptr", h, "UInt", m, "UPtr", w, "Ptr", l, "Ptr")
    static Post(h, m, w := 0, l := 0) => DllCall("user32\PostMessageW", "Ptr", h, "UInt", m, "UPtr", w, "Ptr", l)
    static SetPos(h, x, y, w, h_, f := 0x14, a := 0) => DllCall("user32\SetWindowPos", "Ptr", h, "Ptr", a, "Int", x, "Int", y, "Int", w, "Int", h_, "UInt", f)
    static Parent(h, p := "") => p == "" ? DllCall("user32\GetParent", "Ptr", h, "Ptr") : DllCall("user32\SetParent", "Ptr", h, "Ptr", p)
    static Show(h, cmd) => DllCall("user32\ShowWindow", "Ptr", h, "Int", cmd)
    static Theme(h, t := "", s := 0) {
        if (t == "" || t == 0)
            return DllCall("uxtheme\SetWindowTheme", "Ptr", h, "WStr", "", "WStr", "")
        else
            return DllCall("uxtheme\SetWindowTheme", "Ptr", h, "WStr", t, "Ptr", s)
    }
    static Style(h, s := "") {
        old := A_DetectHiddenWindows
        DetectHiddenWindows "On"
        val := s == "" ? WinGetStyle(h) : WinSetStyle(s, h)
        DetectHiddenWindows old
        return val
    }
    static ExStyle(h, s := "") {
        old := A_DetectHiddenWindows
        DetectHiddenWindows "On"
        val := s == "" ? WinGetExStyle(h) : WinSetExStyle(s, h)
        DetectHiddenWindows old
        return val
    }
    static Pen(c, w := 1, rule := "") => DllCall("gdi32\CreatePen", "Int", 0, "Int", w, "UInt", IsInteger(c) ? c : RT.ResolveBGR(c, rule), "Ptr")
    static Brush(c, rule := "") => DllCall("gdi32\CreateSolidBrush", "UInt", IsInteger(c) ? c : RT.ResolveBGR(c, rule), "Ptr")
    static Select(hdc, obj) => DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", obj, "Ptr")
    static Delete(obj) => DllCall("gdi32\DeleteObject", "Ptr", obj)

    static gdipToken := 0
    static InitGDIPlus() {
        if RT.gdipToken
            return
        DllCall("LoadLibrary", "Str", "gdiplus.dll")
        si := Buffer(A_PtrSize == 8 ? 24 : 16, 0)
        NumPut("UInt", 1, si, 0)
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &tok := 0, "Ptr", si.Ptr, "Ptr", 0)
        RT.gdipToken := tok
    }
    static BgrToArgb(c) {
        bgr := IsInteger(c) ? c : RT.ResolveBGR(c)
        return 0xFF000000 | ((bgr & 0xFF) << 16) | (bgr & 0xFF00) | ((bgr >> 16) & 0xFF)
    }
    static GdipCircle(hdc, cx, cy, r, borderArgb, fillArgb := 0, borderW := 1.0) {
        RT.InitGDIPlus()
        DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc, "Ptr*", &pGfx := 0)
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", pGfx, "Int", 4)
        if fillArgb {
            DllCall("gdiplus\GdipCreateSolidFill", "UInt", fillArgb, "Ptr*", &pBr := 0)
            DllCall("gdiplus\GdipFillEllipse", "Ptr", pGfx, "Ptr", pBr, "Float", cx - r, "Float", cy - r, "Float", r * 2.0, "Float", r * 2.0)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", pBr)
        }
        DllCall("gdiplus\GdipCreatePen1", "UInt", borderArgb, "Float", borderW, "Int", 0, "Ptr*", &pPen := 0)
        DllCall("gdiplus\GdipDrawEllipse", "Ptr", pGfx, "Ptr", pPen, "Float", cx - r, "Float", cy - r, "Float", r * 2.0, "Float", r * 2.0)
        DllCall("gdiplus\GdipDeletePen", "Ptr", pPen)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGfx)
    }
    static GdipLines(hdc, argb, width, points*) {
        RT.InitGDIPlus()
        DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc, "Ptr*", &pGfx := 0)
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", pGfx, "Int", 4)
        DllCall("gdiplus\GdipCreatePen1", "UInt", argb, "Float", width, "Int", 0, "Ptr*", &pPen := 0)
        i := 1
        while i + 2 < points.Length {
            DllCall("gdiplus\GdipDrawLine", "Ptr", pGfx, "Ptr", pPen, "Float", points[i], "Float", points[i + 1], "Float", points[i + 2], "Float", points[i + 3])
            i += 2
        }
        DllCall("gdiplus\GdipDeletePen", "Ptr", pPen)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGfx)
    }

    static __New() {
        try {
            hUx := DllCall("LoadLibrary", "Str", "uxtheme.dll", "Ptr")
            RT.fnSetPreferredAppMode := DllCall("GetProcAddress", "Ptr", hUx, "Ptr", 135, "Ptr")
            RT.fnFlushMenuThemes := DllCall("GetProcAddress", "Ptr", hUx, "Ptr", 136, "Ptr")
            if RT.fnSetPreferredAppMode
                DllCall(RT.fnSetPreferredAppMode, "Int", 2)
            if RT.fnFlushMenuThemes
                DllCall(RT.fnFlushMenuThemes)
            pfnHook := CallbackCreate((h, e, hw, id, idC, t, tm) => RT.OnWindowEvent(h, e, hw, id, idC, t, tm), "F", 7)
            DllCall("user32\SetWinEventHook", "UInt", 0x8000, "UInt", 0x8002, "Ptr", 0, "Ptr", pfnHook, "UInt", DllCall("kernel32\GetCurrentProcessId", "UInt"), "UInt", 0, "UInt", 0, "Ptr")
        } catch {

        }
    }

    static OnWindowEvent(hWinEventHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime) {
        if (idObject == 0) {
            try {
                class := RT.GetClassName(hwnd)
                if (event == 0x8000 && class = "tooltips_class32") {
                    RT.Theme(hwnd, RT.ExplorerTheme)
                    RT.Send(hwnd, 0x0413, 0, RT.ResolveBGR("Surface"))
                    RT.Send(hwnd, 0x0414, 0, RT.ResolveBGR("Text"))
                }
                else if (event == 0x8002 && (class = "#32770" || class = "AutoHotkeyGUI")) {
                    if !RT.CtlCache.Has(hwnd)
                        RT.Apply(hwnd)
                    if RT.RootWindows.Has(hwnd)
                        RT.DWM_Apply(hwnd, RT.ActivePalette)
                }
            } catch {
            }
        }
    }

    static ParseColor(cStr) {
        hex := StrReplace(StrReplace(cStr, "#", ""), "0x", "")
        if (StrLen(hex) != 6)
            hex := "000000"
        return { RGB: hex, BGR: Integer("0x" SubStr(hex, 5, 2) SubStr(hex, 3, 2) SubStr(hex, 1, 2)) }
    }

    class PaintContext {
        __New(hwnd, hdc := 0, db := false) {
            this.hwnd := hwnd, this.ps := Buffer(RT.P(72, 64), 0)
            this.realHdc := hdc ? hdc : DllCall("user32\BeginPaint", "Ptr", hwnd, "Ptr", this.ps, "Ptr")
            this.isBeginPaint := !hdc
            rc := RT.RectObj(hwnd, 1)
            this.rc := rc.buf, this.w := rc.W, this.h := rc.H
            this.rule := RT.CtlCache.Has(hwnd) ? RT.CtlCache[hwnd] : Map()
            this.scale := A_ScreenDPI / 96, this.doubleBuffer := db
            this.hdc := db ? DllCall("gdi32\CreateCompatibleDC", "Ptr", this.realHdc, "Ptr") : this.realHdc
            if db {
                this.hBmp := DllCall("gdi32\CreateCompatibleBitmap", "Ptr", this.realHdc, "Int", this.w, "Int", this.h, "Ptr")
                this.oBmp := RT.Select(this.hdc, this.hBmp)
            }
        }
        S(v) => Integer(v * this.scale)
        Dispose() {
            if this.doubleBuffer {
                DllCall("gdi32\BitBlt", "Ptr", this.realHdc, "Int", 0, "Int", 0, "Int", this.w, "Int", this.h, "Ptr", this.hdc, "Int", 0, "Int", 0, "UInt", 0xCC0020)
                RT.Select(this.hdc, this.oBmp), RT.Delete(this.hBmp), DllCall("gdi32\DeleteDC", "Ptr", this.hdc)
            }
            if this.isBeginPaint
                DllCall("user32\EndPaint", "Ptr", this.hwnd, "Ptr", this.ps)
        }
        Fill(c, x := "", y := "", w := "", h := "", hdc := 0) {
            t := hdc ? hdc : this.hdc, b := RT.ResolveBrush(c, this.rule)
            if (x !== "") {
                rc := RT.Rect(x, y, x + w, y + h)
                DllCall("user32\FillRect", "Ptr", t, "Ptr", rc.Ptr, "Ptr", b)
            } else DllCall("user32\FillRect", "Ptr", t, "Ptr", this.rc.Ptr, "Ptr", b)
            return this
        }
        RoundRect(x1, y1, x2, y2, r, border := "", bg := "", hdc := 0) {
            t := hdc ? hdc : this.hdc
            hp := border !== "" ? RT.Pen(border, 1, this.rule) : DllCall("gdi32\GetStockObject", "Int", 8, "Ptr")
            hb := bg !== "" ? RT.ResolveBrush(bg, this.rule) : DllCall("gdi32\GetStockObject", "Int", 5, "Ptr")
            op := RT.Select(t, hp), ob := RT.Select(t, hb)
            DllCall("gdi32\RoundRect", "Ptr", t, "Int", x1, "Int", y1, "Int", x2, "Int", y2, "Int", r, "Int", r)
            RT.Select(t, op), RT.Select(t, ob)
            if border !== ""
                RT.Delete(hp)
            return this
        }
        Line(x1, y1, x2, y2, c := "", w := 1) {
            hp := RT.Pen(c !== "" ? c : "Border", w, this.rule), op := RT.Select(this.hdc, hp)
            DllCall("gdi32\MoveToEx", "Ptr", this.hdc, "Int", x1, "Int", y1, "Ptr", 0)
            DllCall("gdi32\LineTo", "Ptr", this.hdc, "Int", x2, "Int", y2)
            RT.Select(this.hdc, op), RT.Delete(hp)
            return this
        }
        Text(str, fg, rx, ry, rw, rh, f := 0x24) {
            DllCall("gdi32\SetTextColor", "Ptr", this.hdc, "UInt", RT.ResolveBGR(fg, this.rule))
            DllCall("gdi32\SetBkMode", "Ptr", this.hdc, "Int", 1)
            hf := RT.Send(this.hwnd, 0x0031)
            of := hf ? RT.Select(this.hdc, hf) : 0
            rc := RT.Rect(rx, ry, rx + rw, ry + rh)
            DllCall("user32\DrawTextW", "Ptr", this.hdc, "Str", str, "Int", -1, "Ptr", rc.Ptr, "UInt", f)
            if of
                RT.Select(this.hdc, of)
            return this
        }
        Tri(x1, y1, x2, y2, x3, y3, c) {
            pts := Buffer(24, 0), NumPut("Int", x1, "Int", y1, "Int", x2, "Int", y2, "Int", x3, "Int", y3, pts)
            bgr := IsInteger(c) ? c : RT.ResolveBGR(c, this.rule)
            hb := RT.Brush(bgr, this.rule), hp := RT.Pen(bgr, 1, this.rule)
            ob := RT.Select(this.hdc, hb), op := RT.Select(this.hdc, hp)
            DllCall("gdi32\Polygon", "Ptr", this.hdc, "Ptr", pts.Ptr, "Int", 3)
            RT.Select(this.hdc, ob), RT.Select(this.hdc, op), RT.Delete(hb), RT.Delete(hp)
            return this
        }
    }

    class Palette {
        __New(cfg := "") {
            cfg := cfg ? cfg.Clone() : Map()
            for k, v in Map("BaseBg", "121212", "Surface", "1E1E1E", "Text", "E0E0E0", "Accent", "0078D4", "Border", "333333", "Header", "1E1E1E", "FgDim", "888888")
                if !cfg.Has(k)
                    cfg[k] := v
            for k in ["CaptionBg", "CaptionFg"]
                if !cfg.Has(k)
                    cfg[k] := cfg[k = "CaptionBg" ? "BaseBg" : "Text"]
            this.BGR := Map(), this.RGB := Map(), this.Brushes := Map()
            for k, v in cfg {
                res := RT.ParseColor(v)
                this.RGB[k] := res.RGB, this.BGR[k] := res.BGR
                this.Brushes[k] := RT.Brush(res.BGR)
            }
            res := RT.ParseColor(cfg["BaseBg"])
            r := Integer("0x" SubStr(res.RGB, 1, 2))
            g := Integer("0x" SubStr(res.RGB, 3, 2))
            b := Integer("0x" SubStr(res.RGB, 5, 2))
            this.IsDark := (0.299 * r + 0.587 * g + 0.114 * b) < 128
        }
    }

    static DWM_Apply(hwnd, paletteObj) {
        attrDark := (VerCompare(A_OSVersion, "10.0.22000") >= 0) ? 20 : 19
        RT.DWMAttr(hwnd, attrDark, paletteObj.IsDark ? 1 : 0)
        RT.DWMAttr(hwnd, 33, paletteObj.IsDark ? 2 : 0)
        if (VerCompare(A_OSVersion, "10.0.22000") >= 0) {
            for item in [["Border", 34], ["CaptionBg", 35], ["CaptionFg", 36]] {
                if paletteObj.BGR.Has(item[1])
                    RT.DWMAttr(hwnd, item[2], paletteObj.BGR[item[1]])
            }
        }
    }
    static DWMAttr(hwnd, attr, val) {
        cb := Buffer(4), NumPut("UInt", val, cb)
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", attr, "Ptr", cb, "UInt", 4)
    }

    static IsDark => RT.ActivePalette ? RT.ActivePalette.IsDark : true
    static ExplorerTheme => RT.IsDark ? "DarkMode_Explorer" : "Explorer"
    static ItemsViewTheme => RT.IsDark ? "DarkMode_ItemsView" : "ItemsView"

    static pfnSubclass := 0
    static Attach(hwnd) {
        if this.Attached.Has(hwnd)
            return
        if !this.pfnSubclass
            this.pfnSubclass := CallbackCreate((h, m, w, l, i, d) => RT.SubclassProc(h, m, w, l, i, d), "F", 6)
        DllCall("comctl32\SetWindowSubclass", "Ptr", hwnd, "Ptr", this.pfnSubclass, "UPtr", hwnd, "Ptr", 0)
        this.Attached[hwnd] := true
    }
    static pfnLVSubclass := 0
    static SubclassListView(hLV) {
        if this.Attached.Has(hLV)
            return
        if !this.pfnLVSubclass
            this.pfnLVSubclass := CallbackCreate((h, m, w, l, i, d) => RT.LVSubclassProc(h, m, w, l, i, d), "F", 6)
        DllCall("comctl32\SetWindowSubclass", "Ptr", hLV, "Ptr", this.pfnLVSubclass, "UPtr", hLV, "Ptr", 0)
        this.Attached[hLV] := true
    }
    static LVSubclassProc(hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) {
        if (uMsg == 0x004E) { ; WM_NOTIFY
            parentHwnd := DllCall("user32\GetParent", "Ptr", hwnd, "Ptr")
            if parentHwnd {
                res := DllCall("user32\SendMessageW", "Ptr", parentHwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
                if res != 0
                    return res
            }
        }
        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }
    static SubclassProc(hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) {
        if !RT.Depths.Has(hwnd)
            RT.Depths[hwnd] := 0
        if RT.Config.Robust {
            try {
                if (RT.Depths[hwnd] > 4)
                    return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
                RT.Depths[hwnd]++
                result := RT.SubclassProcInternal(hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData)
                RT.Depths[hwnd]--
                return result
            } catch {
                RT.Depths[hwnd]--
                return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
            }
        } else {
            if (RT.Depths[hwnd] > 4)
                return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
            RT.Depths[hwnd]++
            result := RT.SubclassProcInternal(hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData)
            RT.Depths[hwnd]--
            return result
        }
    }

    static SyncPosition(hwnd, targetHwnd, dx := 0, dy := 0, dw := 0, dh := 0, after := 1, flags := 0x0010) {
        style := RT.Style(hwnd)
        DllCall("user32\ShowWindow", "Ptr", targetHwnd, "Int", (style & 0x10000000) ? 8 : 0)
        rc := RT.GetMappedRect(hwnd, RT.Parent(hwnd))
        RT.SetPos(targetHwnd, rc.L + dx, rc.T + dy, rc.W + dw, rc.H + dh, flags, after)
    }
    static DoListViewRedraw(hLV) {
        try DllCall("user32\RedrawWindow", "Ptr", hLV, "Ptr", 0, "Ptr", 0, "UInt", 0x0185)
    }
    static GetClassName(hwnd) {
        buf := Buffer(128, 0)
        DllCall("user32\GetClassNameW", "Ptr", hwnd, "Ptr", buf.Ptr, "Int", 128)
        return StrGet(buf)
    }

    static ClassCache := Map()
    static Depths := Map()

    static SubclassProcInternal(hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) {
        ; Use cached class name — avoid WinGetClass which pumps messages
        if RT.ClassCache.Has(hwnd)
            classNN := RT.ClassCache[hwnd]
        else {
            buf := Buffer(256, 0)
            DllCall("user32\GetClassNameW", "Ptr", hwnd, "Ptr", buf.Ptr, "Int", 256)
            classNN := StrGet(buf)
            RT.ClassCache[hwnd] := classNN
        }


        ; Clean up cache on window destruction
        if (uMsg == 0x0082) { ; WM_NCDESTROY
            RT.ClassCache.Delete(hwnd)
            if RT.ListViews.Has(hwnd)
                RT.ListViews.Delete(hwnd)
            if RT.RootWindows.Has(hwnd)
                RT.RootWindows.Delete(hwnd)
            if RT.ListViewRedrawTimers.Has(hwnd) {
                try SetTimer(RT.ListViewRedrawTimers[hwnd], 0)
                RT.ListViewRedrawTimers.Delete(hwnd)
            }
        }
        else if (uMsg == 0x000A) { ; WM_ENABLE
            res := DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
            DllCall("user32\InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1)
            DllCall("user32\UpdateWindow", "Ptr", hwnd)
            return res
        }

        if (uMsg == 0x0200) { ; WM_MOUSEMOVE
            if (classNN == "Button" && (RT.Style(hwnd) & 0x0F) != 0x07) || (classNN == "msctls_trackbar32") {
                isTrackbarDrag := (classNN == "msctls_trackbar32" && DllCall("user32\GetKeyState", "Int", 0x01))
                if !RT.ButtonHoverMap.Has(hwnd) || !RT.ButtonHoverMap[hwnd] || isTrackbarDrag {
                    if !RT.ButtonHoverMap.Has(hwnd) || !RT.ButtonHoverMap[hwnd] {
                        RT.ButtonHoverMap[hwnd] := true
                        tme := Buffer(16, 0)
                        NumPut("UInt", 16, tme, 0)
                        NumPut("UInt", 2, tme, 4) ; TME_LEAVE
                        NumPut("Ptr", hwnd, tme, 8)
                        DllCall("user32\TrackMouseEvent", "Ptr", tme.Ptr)
                    }
                    DllCall("user32\InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1)
                }
            }
        }
        else if (uMsg == 0x02A3) { ; WM_MOUSELEAVE
            if (classNN == "Button" && (RT.Style(hwnd) & 0x0F) != 0x07) || (classNN == "msctls_trackbar32") {
                RT.ButtonHoverMap[hwnd] := false
                DllCall("user32\InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1)
            }
        }
        else if (uMsg == 0x0201 || uMsg == 0x0202 || uMsg == 0x0007 || uMsg == 0x0008 || uMsg == 0x0100 || uMsg == 0x020A) {
            if (classNN == "msctls_trackbar32") {
                DllCall("user32\InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1)
            }
            if (uMsg == 0x0007 || uMsg == 0x0008) {
                if (classNN == "Edit" || classNN == "ComboBox" || classNN == "msctls_hotkey32" || classNN == "ListBox") {
                    if borderHwnd := RT.GetBorderHwnd(hwnd) {
                        rule := RT.CtlCache.Has(hwnd) ? RT.CtlCache[hwnd] : Map()
                        isFocus := (uMsg == 0x0007)
                        borderCol := isFocus ? (rule.Has("FocusedBorder") ? rule["FocusedBorder"] : "Accent") : (rule.Has("Border") ? rule["Border"] : "Border")
                        RT.CtlCache[borderHwnd]["Bg"] := borderCol
                        DllCall("user32\InvalidateRect", "Ptr", borderHwnd, "Ptr", 0, "Int", 1)
                    }
                }
            }
        }
        else if (uMsg == 0x0020) { ; WM_SETCURSOR
            hitTest := lParam & 0xFFFF
            if hitTest == 1 || hitTest == 5 { ; HTCLIENT or HTMENU
                cursorVal := ""
                if RT.CtlCache.Has(hwnd) && RT.CtlCache[hwnd].Has("Cursor") {
                    cursorVal := RT.CtlCache[hwnd]["Cursor"]
                } else if (classNN == "Button" && RT.Config.ButtonCursor != "" && (RT.Style(hwnd) & 0x0F) != 0x07) {
                    cursorVal := RT.Config.ButtonCursor
                } else if ((classNN == "ComboBox" || classNN == "ComboLBox") && RT.Config.DropdownCursor != "") {
                    cursorVal := RT.Config.DropdownCursor
                } else if (classNN == "msctls_trackbar32" && RT.Config.SliderCursor != "") {
                    cursorVal := RT.Config.SliderCursor
                } else if ((classNN == "Edit" || classNN == "msctls_hotkey32") && RT.Config.InputCursor != "") {
                    cursorVal := RT.Config.InputCursor
                } else if (hitTest == 5 && RT.Config.MenuCursor != "") {
                    cursorVal := RT.Config.MenuCursor
                } else if (classNN == "SysTabControl32" && RT.Config.ButtonCursor != "") {
                    DllCall("user32\GetCursorPos", "Ptr", pt := Buffer(8))
                    DllCall("user32\ScreenToClient", "Ptr", hwnd, "Ptr", pt)
                    tchi := Buffer(12, 0)
                    NumPut("Int", NumGet(pt, 0, "Int"), "Int", NumGet(pt, 4, "Int"), tchi)
                    tabIndex := RT.Send(hwnd, 0x130D, 0, tchi.Ptr)
                    if (tabIndex >= 0) {
                        cursorVal := RT.Config.ButtonCursor
                    }
                }
                if (cursorVal != "") {
                    hCursor := RT.GetCursorHandle(cursorVal)
                    if hCursor {
                        DllCall("user32\SetCursor", "Ptr", hCursor)
                        return 1
                    }
                }
            }
        }

        if (uMsg == 0x0014) {
            btnType := (classNN == "Button") ? (RT.Style(hwnd) & 0x0F) : -1
            if InStr("|#32770|AutoHotkeyGUI|", "|" classNN "|") {
                bg := (RT.CtlCache.Has(hwnd) && (rule := RT.CtlCache[hwnd]).Has("Bg")) ? rule["Bg"] : "BaseBg"
                if bg !== "" {
                    ctx := RT.PaintContext(hwnd, wParam)
                    ctx.Fill(bg)
                    ctx.Dispose()
                }
                return 1
            }
            else if InStr("|SysTabControl32|msctls_updown32|SysDateTimePick32|msctls_hotkey32|SysIPAddress32|msctls_trackbar32|", "|" classNN "|") || (classNN == "Button" && btnType != 8) {
                return 1
            }
        }
        else if (uMsg == 0x000F) {
            if (classNN == "#32770" && RT.CtlCache.Has(hwnd) && !(RT.Style(hwnd) & 0x40000000)) {
                bg := (rule := RT.CtlCache[hwnd]).Has("Bg") ? rule["Bg"] : "BaseBg"
                ctx := RT.PaintContext(hwnd)
                ctx.Fill(bg)
                ctx.Dispose()
                return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
            }
            if (classNN = "SysDateTimePick32" && !RT.IsDark)
                return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
            btnType := (classNN == "Button") ? (RT.Style(hwnd) & 0x0F) : -1
            if InStr("|SysTabControl32|ComboBox|msctls_updown32|SysDateTimePick32|msctls_hotkey32|SysIPAddress32|Static|msctls_trackbar32|", "|" classNN "|") || (classNN = "Button" && (btnType == 0x07 || btnType <= 1 || (RT.Style(hwnd) & 0x1000) || InStr("|2|3|4|5|6|9|", "|" btnType "|"))) {
                if (classNN = "Static" && ((type := RT.Style(hwnd) & 0x1F) != 0x10 && type != 0x11))
                    return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")

                rc := RT.RectObj(hwnd, 1)
                if (rc.W <= 0 || rc.H <= 0)
                    return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
                if (classNN = "SysTabControl32") {
                    tabCount := RT.Send(hwnd, 0x1304)
                    if tabCount <= 0
                        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
                }

                db := (classNN != "SysDateTimePick32")
                ctx := RT.PaintContext(hwnd, 0, db)
                (classNN = "SysTabControl32") ? RT.PaintTabs(ctx) :
                (classNN = "ComboBox") ? RT.PaintComboBox(ctx) :
                (classNN = "msctls_updown32") ? RT.PaintUpDown(ctx) :
                (classNN = "msctls_trackbar32") ? RT.PaintTrackbar(ctx) :
                (classNN = "Button" && btnType == 0x07) ? RT.PaintGroupBox(ctx) :
                (classNN = "Button" && (btnType <= 1 || (RT.Style(hwnd) & 0x1000))) ? RT.PaintButton(ctx) :
                (classNN = "Button" && InStr("|2|3|5|6|", "|" btnType "|")) ? RT.PaintCheckBox(ctx) :
                (classNN = "Button" && InStr("|4|9|", "|" btnType "|")) ? RT.PaintRadio(ctx) :
                (classNN = "SysDateTimePick32") ? RT.PaintInverted(ctx) :
                (classNN = "msctls_hotkey32") ? RT.PaintHotkey(ctx) :
                (classNN = "SysIPAddress32") ? RT.PaintIPAddress(ctx) :
                (classNN = "Static") ? RT.PaintDivider(ctx, type) : 0
                ctx.Dispose()
                if (classNN = "Button" && btnType == 0x07) {
                    RT.InvalidateGroupChildren(hwnd)
                }
                return 0
            }
            else if (classNN = "SysMonthCal32") {
                ret := DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
                hdc := DllCall("user32\GetDC", "Ptr", hwnd, "Ptr")
                if hdc {
                    ctx := RT.PaintContext(hwnd, hdc)
                    RT.PaintMonthCalNav(ctx)
                    DllCall("user32\ReleaseDC", "Ptr", hwnd, "Ptr", hdc)
                }
                return ret
            }
        }

        if (uMsg == 0x0128 && InStr("|#32770|AutoHotkeyGUI|", "|" classNN "|"))
            wParam := 0x00030001

        if (uMsg == 0x0047 && lParam) {
            if (NumGet(lParam, A_PtrSize == 8 ? 32 : 24, "UInt") & 3) != 3 {
                if (classNN != "SysListView32") {
                    if borderHwnd := RT.GetBorderHwnd(hwnd)
                        RT.SyncPosition(hwnd, borderHwnd, -1, -1, 2, 2, 1, 0x0010)
                    for childHwnd, _ in RT.ListViews {
                        if DllCall("user32\IsChild", "Ptr", hwnd, "Ptr", childHwnd) {
                            if !RT.ListViewRedrawTimers.Has(childHwnd) {
                                RT.ListViewRedrawTimers[childHwnd] := RT.DoListViewRedraw.Bind(RT, childHwnd)
                            }
                            SetTimer(RT.ListViewRedrawTimers[childHwnd], -50)
                        }
                    }
                }
                if staticHwnd := RT.RadioTextReverseMap.Has(hwnd) ? RT.RadioTextReverseMap[hwnd] : 0
                    RT.SyncPosition(hwnd, staticHwnd, 20, 0, 0, 0, hwnd, 0x0011)
            }
        }
        else if (uMsg == 0x0018) {
            if (lParam == 0) {
                for h in [RT.GetBorderHwnd(hwnd), RT.RadioTextReverseMap.Has(hwnd) ? RT.RadioTextReverseMap[hwnd] : 0] {
                    if h
                        RT.Show(h, wParam ? 8 : 0)
                }
            }
            if (classNN == "SysMonthCal32" && wParam)
                RT.ApplyMonthCalTheme(hwnd)
        }
        else if (uMsg == 0x0002) {
            if borderHwnd := RT.GetBorderHwnd(hwnd) {
                DllCall("user32\DestroyWindow", "Ptr", borderHwnd)
                RT.BorderMap.Delete(hwnd), RT.BordersSet.Delete(borderHwnd)
            }
            if staticHwnd := RT.RadioTextReverseMap.Has(hwnd) ? RT.RadioTextReverseMap[hwnd] : 0 {
                DllCall("user32\DestroyWindow", "Ptr", staticHwnd)
                RT.RadioTextMap.Delete(staticHwnd), RT.RadioTextReverseMap.Delete(hwnd)
            }
        }
        else if (uMsg >= 0x0132 && uMsg <= 0x0138) {
            if RT.CtlCache.Has(lParam)
                return RT.OnCtlColorInternal(wParam, lParam, uMsg, hwnd)
        }
        else if (uMsg == 0x0111) {
            id := wParam & 0xFFFF
            if (id >= 0x9000 && id < 0x9FFF) {
                idx := id - 0x9000
                themes := RT.GetThemesList()
                if (idx >= 1 && idx <= themes.Length) {
                    themeName := themes[idx]
                    RT.CurrentThemeName := themeName
                    RT.SetTheme(themeName)
                }
                return 0
            }
            else if (id == 0x9FFF) {
                RT.ThemeEditor.Show()
                return 0
            }
        }
        else if (uMsg == 0x0112) { ; WM_SYSCOMMAND
            if ((wParam & 0xFFFF) == 0x9FFF) {
                RT.ThemeEditor.Show()
                return 0
            }
        }

        if (uMsg == 0x002B) {
            hwndItem := NumGet(lParam, RT.P(24, 20), "Ptr")
            if RT.StatusBarTexts.Has(hwndItem) {
                itemID := NumGet(lParam, 8, "UInt"), hdc := NumGet(lParam, RT.P(32, 24), "Ptr")
                rcOffset := RT.P(40, 28)
                rcLeft := NumGet(lParam, rcOffset, "Int"), rcTop := NumGet(lParam, rcOffset + 4, "Int")
                rcRight := NumGet(lParam, rcOffset + 8, "Int"), rcBottom := NumGet(lParam, rcOffset + 12, "Int")
                text := RT.StatusBarTexts[hwndItem].Has(itemID) ? RT.StatusBarTexts[hwndItem][itemID] : ""
                ctx := RT.PaintContext(hwndItem, hdc)
                ctx.Fill(ctx.rule.Has("Bg") ? ctx.rule["Bg"] : "Controls", rcLeft, rcTop, rcRight - rcLeft, rcBottom - rcTop)
                if text != ""
                    ctx.Text(text, ctx.rule.Has("Fg") ? ctx.rule["Fg"] : "Text", rcLeft + 4, rcTop, rcRight - rcLeft - 4, rcBottom - rcTop, 36)
                ctx.Dispose()
                return 1
            }
        }
        else if (uMsg == 0x004E && lParam) {
            hwndFrom := NumGet(lParam, 0, "Ptr"), code := NumGet(lParam, RT.P(16, 8), "Int")
            if (code == -12) { ; NM_CUSTOMDRAW
                try {
                    classFrom := RT.GetClassName(hwndFrom)
                    if classFrom == "SysListView32" {
                        drawStage := NumGet(lParam, A_PtrSize * 3, "UInt")
                        if (drawStage == 1) ; CDDS_PREPAINT
                            return 0x20 ; CDRF_NOTIFYITEMDRAW

                        if (drawStage == 0x10001) { ; CDDS_ITEMPREPAINT
                            rule := RT.CtlCache.Has(hwndFrom) ? RT.CtlCache[hwndFrom] : Map()
                            itemIndex := NumGet(lParam, (A_PtrSize == 8) ? 56 : 36, "UPtr")
                            isSelected := DllCall("user32\SendMessageW", "Ptr", hwndFrom, "UInt", 0x102C, "UPtr", itemIndex, "Ptr", 2, "Ptr") & 2

                            if isSelected {
                                bgClr := 0xFFFFFFFF ; CLR_NONE (draw native selection)
                                fgClr := RT.ResolveBGR("Text")
                            } else {
                                bgClr := RT.ResolveBGR(rule.Has("Bg") ? rule["Bg"] : "Surface")
                                fgClr := RT.ResolveBGR(rule.Has("Fg") ? rule["Fg"] : "Text")
                            }

                            hdc := NumGet(lParam, (A_PtrSize == 8) ? 32 : 16, "Ptr")
                            DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", fgClr)
                            DllCall("gdi32\SetBkColor", "Ptr", hdc, "UInt", bgClr)

                            NumPut("UInt", fgClr, lParam, (A_PtrSize == 8) ? 80 : 48) ; clrText
                            NumPut("UInt", bgClr, lParam, (A_PtrSize == 8) ? 84 : 52) ; clrTextBk
                            return 0x02 ; CDRF_NEWFONT
                        }
                    }
                    else if classFrom == "SysHeader32" {
                        drawStage := NumGet(lParam, A_PtrSize * 3, "UInt")
                        if (drawStage == 1) ; CDDS_PREPAINT
                            return 0x20 ; CDRF_NOTIFYITEMDRAW

                        if (drawStage == 0x10001) { ; CDDS_ITEMPREPAINT
                            hdc := NumGet(lParam, (A_PtrSize == 8) ? 32 : 16, "Ptr")
                            itemIndex := NumGet(lParam, (A_PtrSize == 8) ? 56 : 36, "UPtr")

                            rcLeft := NumGet(lParam, (A_PtrSize == 8) ? 40 : 20, "Int")
                            rcTop := NumGet(lParam, (A_PtrSize == 8) ? 44 : 24, "Int")
                            rcRight := NumGet(lParam, (A_PtrSize == 8) ? 48 : 28, "Int")
                            rcBottom := NumGet(lParam, (A_PtrSize == 8) ? 52 : 32, "Int")

                            rcStruct := Buffer(16, 0)
                            NumPut("Int", rcLeft, "Int", rcTop, "Int", rcRight, "Int", rcBottom, rcStruct)

                            bgBrush := RT.ResolveBrush("Header")
                            DllCall("user32\FillRect", "Ptr", hdc, "Ptr", rcStruct.Ptr, "Ptr", bgBrush)

                            HDITEM := Buffer(A_PtrSize == 8 ? 72 : 48, 0)
                            NumPut("UInt", 2, HDITEM, 0) ; HDI_TEXT
                            textBuf := Buffer(512, 0)
                            NumPut("Ptr", textBuf.Ptr, HDITEM, 8)
                            NumPut("Int", 256, HDITEM, A_PtrSize == 8 ? 24 : 16)
                            DllCall("user32\SendMessageW", "Ptr", hwndFrom, "UInt", 0x120B, "UPtr", itemIndex, "Ptr", HDITEM.Ptr, "Ptr") ; HDM_GETITEMW

                            DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", RT.ResolveBGR("Text"))
                            DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", 1) ; TRANSPARENT

                            NumPut("Int", rcLeft + 8, rcStruct, 0)
                            DllCall("user32\DrawTextW", "Ptr", hdc, "Ptr", textBuf.Ptr, "Int", -1, "Ptr", rcStruct.Ptr, "UInt", 0x24) ; DT_VCENTER | DT_SINGLELINE
                            return 4 ; CDRF_SKIPDEFAULT
                        }
                    }
                }
            }
            if ((code == -754 || code == -740) && (hMC := RT.Send(hwndFrom, 0x1008)))
                RT.ApplyMonthCalTheme(hMC)
            else if (code == -308 || code == -328 || code == -306 || code == -326 || code == -307 || code == -327 || code == -305 || code == -325 || code == -180 || code == -181) {
                try {
                    classFrom := RT.GetClassName(hwndFrom)
                    if classFrom == "SysHeader32" {
                        hLV := DllCall("user32\GetParent", "Ptr", hwndFrom, "Ptr")
                    } else if classFrom == "SysListView32" {
                        hLV := hwndFrom
                    } else {
                        hLV := 0
                    }
                    if hLV && RT.GetClassName(hLV) == "SysListView32" {
                        if !RT.ListViewRedrawTimers.Has(hLV) {
                            RT.ListViewRedrawTimers[hLV] := RT.DoListViewRedraw.Bind(RT, hLV)
                        }
                        SetTimer(RT.ListViewRedrawTimers[hLV], -50)
                    }
                }
            }
        }

        if (uMsg == 0x0117) {
            hMenu := wParam, darkBrush := RT.ResolveBrush("Header")
            mi := Buffer(RT.P(40, 28), 0), NumPut("UInt", mi.Size, mi, 0), NumPut("UInt", 0x10, mi, 4)
            NumPut("Ptr", darkBrush, mi, RT.P(32, 24))
            DllCall("user32\SetMenuInfo", "Ptr", hMenu, "Ptr", mi.Ptr)
        }
        else if (uMsg == 0x0091) {
            hMenu := NumGet(lParam, 0, "Ptr"), hdc := NumGet(lParam, A_PtrSize, "Ptr")
            mbi := Buffer(RT.P(48, 32), 0), NumPut("UInt", mbi.Size, mbi, 0)
            if DllCall("user32\GetMenuBarInfo", "Ptr", hwnd, "Int", -3, "Int", 0, "Ptr", mbi.Ptr) {
                rcWin := RT.RectObj(hwnd)
                x1 := NumGet(mbi.Ptr, 4, "Int") - rcWin.L, y1 := NumGet(mbi.Ptr, 8, "Int") - rcWin.T
                x2 := NumGet(mbi.Ptr, 12, "Int") - rcWin.L, y2 := NumGet(mbi.Ptr, 16, "Int") - rcWin.T
                ctx := RT.PaintContext(hwnd, hdc), ctx.Fill("Header", x1, y1, x2 - x1, y2 - y1), ctx.Dispose()
                return 1
            }
        }
        else if (uMsg == 0x0092) {
            itemState := NumGet(lParam, 16, "UInt"), hdc := NumGet(lParam, RT.P(32, 24), "Ptr")
            rcOffset := RT.P(40, 28)
            left := NumGet(lParam, rcOffset, "Int"), top := NumGet(lParam, rcOffset + 4, "Int")
            right := NumGet(lParam, rcOffset + 8, "Int"), bottom := NumGet(lParam, rcOffset + 12, "Int")
            hMenu := NumGet(lParam, RT.P(64, 48), "Ptr"), iPos := NumGet(lParam, RT.P(88, 60), "Int")
            isHover := (itemState & 0x0001) || (itemState & 0x0040)
            ctx := RT.PaintContext(hwnd, hdc), ctx.Fill(isHover ? "Border" : "Header", left, top, right - left, bottom - top)
            bufLen := DllCall("user32\GetMenuStringW", "Ptr", hMenu, "UInt", iPos, "Ptr", 0, "Int", 0, "UInt", 0x0400)
            if bufLen > 0 {
                textBuf := Buffer((bufLen + 1) * 2, 0), DllCall("user32\GetMenuStringW", "Ptr", hMenu, "UInt", iPos, "Ptr", textBuf.Ptr, "Int", bufLen + 1, "UInt", 0x0400)
                ctx.Text(StrGet(textBuf), "Text", left, top, right - left, bottom - top, 0x25)
            }
            ctx.Dispose()
            return 1
        }
        else if ((uMsg == 0x0085 || uMsg == 0x0086) && InStr("|#32770|AutoHotkeyGUI|", "|" classNN "|")) {
            ret := DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
            if RT.RootWindows.Has(hwnd) {
                RT.DWM_Apply(hwnd, RT.ActivePalette)
            }
            RT.DrawMenuBarBottomLine(hwnd)
            return ret
        }
        else if (classNN = "msctls_statusbar32") {
            if (uMsg == 0x040B || uMsg == 0x0403) {
                partIdx := wParam & 0xFF, strVal := lParam ? StrGet(lParam, (uMsg == 0x040B) ? "UTF-16" : "CP0") : ""
                if !RT.StatusBarTexts.Has(hwnd)
                    RT.StatusBarTexts[hwnd] := Map()
                RT.StatusBarTexts[hwnd][partIdx] := strVal
                DllCall("user32\RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0501)
                return 1
            }
            if (uMsg == 0x0014)
                return 1
            if (uMsg == 0x0085) {
                hdc := DllCall("user32\GetWindowDC", "Ptr", hwnd, "Ptr")
                if hdc {
                    rcWin := RT.RectObj(hwnd)
                    ctx := RT.PaintContext(hwnd, hdc), ctx.Fill(ctx.rule.Has("Bg") ? ctx.rule["Bg"] : "Controls", 0, 0, rcWin.W, rcWin.H)
                    DllCall("user32\ReleaseDC", "Ptr", hwnd, "Ptr", hdc)
                }
                return 0
            }
            if (uMsg == 0x000F) {
                ctx := RT.PaintContext(hwnd), ctx.Fill(ctx.rule.Has("Bg") ? ctx.rule["Bg"] : "Controls")
                hFont := RT.Send(hwnd, 0x0031), oldFont := hFont ? RT.Select(ctx.hdc, hFont) : 0
                ctx.Text("", ctx.rule.Has("Fg") ? ctx.rule["Fg"] : "Text", 0, 0, 0, 0)
                numParts := RT.Send(hwnd, 0x0406)
                if (numParts <= 0)
                    numParts := 1
                loop numParts {
                    partIdx := A_Index - 1, rcPart := RT.Rect(), RT.Send(hwnd, 0x040A, partIdx, rcPart.Ptr)
                    text := (RT.StatusBarTexts.Has(hwnd) && RT.StatusBarTexts[hwnd].Has(partIdx)) ? RT.StatusBarTexts[hwnd][partIdx] : ""
                    if (text != "") {
                        left := NumGet(rcPart, 0, "Int"), NumPut("Int", left + 4, rcPart, 0)
                        DllCall("user32\DrawTextW", "Ptr", ctx.hdc, "Str", text, "Int", -1, "Ptr", rcPart.Ptr, "UInt", 36)
                    }
                }
                if oldFont
                    RT.Select(ctx.hdc, oldFont)
                ctx.Dispose()
                return 0
            }
        }
        else if (uMsg == 0x0201 || uMsg == 0x0203) {
            if RT.RadioTextMap.Has(hwnd) {
                radioHwnd := RT.RadioTextMap[hwnd]
                RT.Post(radioHwnd, 0x0201, 1, 0), RT.Post(radioHwnd, 0x0202, 0, 0)
                return 0
            }
        }


        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }

    static DrawMenuBarBottomLine(hwnd) {
        mbi := Buffer(RT.P(48, 32), 0), NumPut("UInt", mbi.Size, mbi, 0)
        if DllCall("user32\GetMenuBarInfo", "Ptr", hwnd, "Int", -3, "Int", 0, "Ptr", mbi.Ptr) {
            rcWin := RT.RectObj(hwnd)
            x1 := NumGet(mbi.Ptr, 4, "Int") - rcWin.L, y1 := NumGet(mbi.Ptr, 16, "Int") - rcWin.T, x2 := NumGet(mbi.Ptr, 12, "Int") - rcWin.L
            hdc := DllCall("user32\GetWindowDC", "Ptr", hwnd, "Ptr")
            if hdc {
                ctx := RT.PaintContext(hwnd, hdc), ctx.Fill("BaseBg", x1, y1, x2 - x1, 1)
                DllCall("user32\ReleaseDC", "Ptr", hwnd, "Ptr", hdc)
            }
        }
    }

    static PaintTabs(ctx) {
        selIdx := RT.Send(ctx.hwnd, 0x130B), tabCount := RT.Send(ctx.hwnd, 0x1304)
        if tabCount <= 0
            return
        ctx.Fill(ctx.rule.Has("Bg") ? ctx.rule["Bg"] : "BaseBg")
        adjRc := RT.Rect(0, 0, ctx.w, ctx.h)
        RT.Send(ctx.hwnd, 0x1328, 0, adjRc.Ptr)
        tabStripBottom := NumGet(adjRc, 4, "Int")
        hFont := RT.Send(ctx.hwnd, 0x0031), oldFont := hFont ? RT.Select(ctx.hdc, hFont) : 0
        DllCall("gdi32\SetBkMode", "Ptr", ctx.hdc, "Int", 1)
        hNullPen := DllCall("gdi32\GetStockObject", "Int", 8, "Ptr")
        loop tabCount {
            i := A_Index - 1, itemRc := RT.Rect(), RT.Send(ctx.hwnd, 0x130A, i, itemRc.Ptr)
            l := NumGet(itemRc, 0, "Int"), t := NumGet(itemRc, 4, "Int"), r := NumGet(itemRc, 8, "Int"), b := NumGet(itemRc, 12, "Int")
            if (i = selIdx) {
                bgKey := ctx.rule.Has("SelectedBg") ? ctx.rule["SelectedBg"] : (ctx.rule.Has("HoverBg") ? ctx.rule["HoverBg"] : "Surface")
                tabBrush := RT.ResolveBrush(bgKey)
                oPen := RT.Select(ctx.hdc, hNullPen), oBrush := RT.Select(ctx.hdc, tabBrush)
                DllCall("gdi32\RoundRect", "Ptr", ctx.hdc, "Int", l + 2, "Int", t, "Int", r - 1, "Int", b + 1, "Int", 6, "Int", 6)
                squareRc := RT.Rect(l + 2, b - 6, r - 1, b + 1)
                DllCall("user32\FillRect", "Ptr", ctx.hdc, "Ptr", squareRc.Ptr, "Ptr", tabBrush)
                RT.Select(ctx.hdc, oPen), RT.Select(ctx.hdc, oBrush)
                fgKey := ctx.rule.Has("SelectedFg") ? ctx.rule["SelectedFg"] : (ctx.rule.Has("Fg") ? ctx.rule["Fg"] : "Text")
                DllCall("gdi32\SetTextColor", "Ptr", ctx.hdc, "UInt", RT.ResolveBGR(fgKey))
            } else {
                DllCall("gdi32\SetTextColor", "Ptr", ctx.hdc, "UInt", RT.ResolveBGR(ctx.rule.Has("FgDim") ? ctx.rule["FgDim"] : "FgDim"))
            }
            textBuf := Buffer(512, 0), tcItem := Buffer(RT.P(40, 28), 0)
            NumPut("UInt", 1, tcItem, 0), NumPut("Ptr", textBuf.Ptr, tcItem, RT.P(16, 12)), NumPut("Int", 255, tcItem, RT.P(24, 16))
            RT.Send(ctx.hwnd, 0x133C, i, tcItem.Ptr)
            DllCall("user32\DrawTextW", "Ptr", ctx.hdc, "Ptr", textBuf.Ptr, "Int", -1, "Ptr", itemRc.Ptr, "UInt", 0x25)
        }
        if tabStripBottom > 0 {
            sepRc := RT.Rect(0, tabStripBottom - 1, ctx.w, tabStripBottom)
            borderBrush := RT.ResolveBrush(ctx.rule.Has("Border") ? ctx.rule["Border"] : "Border")
            DllCall("user32\FillRect", "Ptr", ctx.hdc, "Ptr", sepRc.Ptr, "Ptr", borderBrush)
        }
        if oldFont
            RT.Select(ctx.hdc, oldFont)
    }

    static PaintComboBox(ctx) {
        pWnd := RT.Parent(ctx.hwnd)
        parentBg := (pWnd && RT.CtlCache.Has(pWnd) && RT.CtlCache[pWnd].Has("Bg")) ? RT.CtlCache[pWnd]["Bg"] : "BaseBg"
        ctx.Fill(parentBg)
        bgKey := ctx.rule.Has("Bg") ? ctx.rule["Bg"] : "Surface", borderKey := ctx.rule.Has("Border") ? ctx.rule["Border"] : "Border"
        ctx.RoundRect(0, 0, ctx.w, ctx.h, ctx.S(6), borderKey, bgKey)
        cx := ctx.w - ctx.S(12), cy := ctx.h // 2, hw := ctx.S(4), ah := ctx.S(3), fgKey := ctx.rule.Has("Fg") ? ctx.rule["Fg"] : "Text"
        ctx.Line(cx - hw, cy - ah, cx, cy + 1, fgKey, 2)
        ctx.Line(cx, cy + 1, cx + hw, cy - ah, fgKey, 2)
        style := RT.Style(ctx.hwnd)
        if ((style & 3) == 3) {
            textStr := ControlGetText(ctx.hwnd)
            if textStr != ""
                ctx.Text(textStr, fgKey, ctx.S(6), 0, ctx.w - ctx.S(30), ctx.h, 0x24)
        }
    }

    static PaintUpDown(ctx) {
        ctx.Fill(ctx.rule.Has("Bg") ? ctx.rule["Bg"] : "Surface")
        midY := ctx.h // 2, borderCol := ctx.rule.Has("Border") ? ctx.rule["Border"] : "Border"
        ctx.Line(0, midY, ctx.w, midY, borderCol).Line(0, 0, 0, ctx.h, borderCol)
        fgColor := ctx.rule.Has("Fg") ? ctx.rule["Fg"] : "Text", aw := Max(3, ctx.w // 4), cx := ctx.w // 2
        ctx.Tri(cx - aw, midY // 2 + aw // 2, cx + aw, midY // 2 + aw // 2, cx, midY // 2 - aw // 2, fgColor)
        ctx.Tri(cx - aw, midY + midY // 2 - aw // 2, cx + aw, midY + midY // 2 - aw // 2, cx, midY + midY // 2 + aw // 2, fgColor)
    }

    static PaintGroupBox(ctx) {
        hFont := RT.Send(ctx.hwnd, 0x0031), oldFont := hFont ? RT.Select(ctx.hdc, hFont) : 0
        tm := Buffer(60, 0), DllCall("gdi32\GetTextMetricsW", "Ptr", ctx.hdc, "Ptr", tm.Ptr), tmH := NumGet(tm, 0, "Int")
        groupText := ControlGetText(ctx.hwnd)
        sz := Buffer(8, 0), DllCall("gdi32\GetTextExtentPoint32W", "Ptr", ctx.hdc, "Str", groupText, "Int", StrLen(groupText), "Ptr", sz.Ptr)
        textW := NumGet(sz, 0, "Int"), textX := ctx.S(9), borderY := tmH // 2
        borderKey := ctx.rule.Has("Border") ? ctx.rule["Border"] : "Border"
        bgKey := ctx.rule.Has("Bg") ? ctx.rule["Bg"] : "BaseBg"

        pWnd := RT.Parent(ctx.hwnd)
        parentBg := (pWnd && RT.CtlCache.Has(pWnd) && RT.CtlCache[pWnd].Has("Bg")) ? RT.CtlCache[pWnd]["Bg"] : "BaseBg"
        ctx.Fill(parentBg)

        ctx.RoundRect(0, borderY, ctx.w, ctx.h, ctx.S(8), borderKey, bgKey)
        if (groupText != "") {
            ctx.Fill(parentBg, textX - 2, borderY - 1, textW + 4, 2)
            ctx.Text(groupText, ctx.rule.Has("Fg") ? ctx.rule["Fg"] : "Text", textX, 0, textW + 4, tmH, 0x20)
        }
        if oldFont
            RT.Select(ctx.hdc, oldFont)
    }

    static PaintTrackbar(ctx) {
        pWnd := RT.Parent(ctx.hwnd)
        parentBg := (pWnd && RT.CtlCache.Has(pWnd) && RT.CtlCache[pWnd].Has("Bg")) ? RT.CtlCache[pWnd]["Bg"] : "BaseBg"
        ctx.Fill(parentBg)

        rcChan := Buffer(16, 0)
        RT.Send(ctx.hwnd, 0x041A, 0, rcChan.Ptr)
        cl := NumGet(rcChan, 0, "Int"), ct := NumGet(rcChan, 4, "Int"), cr := NumGet(rcChan, 8, "Int"), cb := NumGet(rcChan, 12, "Int")

        rcThumb := Buffer(16, 0)
        RT.Send(ctx.hwnd, 0x0419, 0, rcThumb.Ptr)
        tl := NumGet(rcThumb, 0, "Int"), tt := NumGet(rcThumb, 4, "Int"), tr := NumGet(rcThumb, 8, "Int"), tb := NumGet(rcThumb, 12, "Int")

        style := RT.Style(ctx.hwnd)
        isVertical := (style & 1) != 0

        trackThickness := ctx.S(4)
        accentColor := ctx.rule.Has("Fg") ? ctx.rule["Fg"] : "Accent"
        borderColor := ctx.rule.Has("Border") ? ctx.rule["Border"] : "Border"

        tx := tl + (tr - tl) // 2
        ty := tt + (tb - tt) // 2

        isHover := RT.ButtonHoverMap.Has(ctx.hwnd) && RT.ButtonHoverMap[ctx.hwnd]
        isFocused := DllCall("user32\GetFocus", "Ptr") == ctx.hwnd
        isDrag := DllCall("user32\GetKeyState", "Int", 0x01) && isFocused

        r := isDrag ? ctx.S(9) : (isHover || isFocused) ? ctx.S(8) : ctx.S(6)

        if !isVertical {
            cy := ct + (cb - ct - trackThickness) // 2
            ctx.RoundRect(tx, cy, cr, cy + trackThickness, trackThickness // 2, borderColor, borderColor)
            ctx.RoundRect(cl, cy, tx, cy + trackThickness, trackThickness // 2, accentColor, accentColor)
            acA := RT.BgrToArgb(accentColor), bgA := RT.BgrToArgb(parentBg)
            if (isHover || isFocused || isDrag) {
                RT.GdipCircle(ctx.hdc, tx, ty, r, acA, acA)
            } else {
                RT.GdipCircle(ctx.hdc, tx, ty, r, acA, acA)
                innerR := r - ctx.S(2)
                if (innerR > 0)
                    RT.GdipCircle(ctx.hdc, tx, ty, innerR, bgA, bgA)
            }
        } else {
            cx := cl + (cr - cl - trackThickness) // 2
            ctx.RoundRect(cx, ct, cx + trackThickness, ty, trackThickness // 2, borderColor, borderColor)
            ctx.RoundRect(cx, ty, cx + trackThickness, cb, trackThickness // 2, accentColor, accentColor)
            acA := RT.BgrToArgb(accentColor), bgA := RT.BgrToArgb(parentBg)
            if (isHover || isFocused || isDrag) {
                RT.GdipCircle(ctx.hdc, tx, ty, r, acA, acA)
            } else {
                RT.GdipCircle(ctx.hdc, tx, ty, r, acA, acA)
                innerR := r - ctx.S(2)
                if (innerR > 0)
                    RT.GdipCircle(ctx.hdc, tx, ty, innerR, bgA, bgA)
            }
        }
    }

    static PaintButton(ctx) {
        state := RT.Send(ctx.hwnd, 0x00F2) ; BM_GETSTATE
        isPressed := (state & 0x0004) != 0
        isChecked := RT.Send(ctx.hwnd, 0x00F0) == 1 ; BM_GETCHECK
        isFocused := (state & 0x0008) != 0 || DllCall("user32\GetFocus", "Ptr") == ctx.hwnd
        isHover := RT.ButtonHoverMap.Has(ctx.hwnd) && RT.ButtonHoverMap[ctx.hwnd]
        isEnabled := DllCall("user32\IsWindowEnabled", "Ptr", ctx.hwnd)

        pWnd := RT.Parent(ctx.hwnd)
        parentBg := (pWnd && RT.CtlCache.Has(pWnd) && RT.CtlCache[pWnd].Has("Bg")) ? RT.CtlCache[pWnd]["Bg"] : "BaseBg"
        ctx.Fill(parentBg)

        bgKey := ctx.rule.Has("Bg") ? ctx.rule["Bg"] : "Surface"
        fgKey := ctx.rule.Has("Fg") ? ctx.rule["Fg"] : "Text"
        borderKey := ctx.rule.Has("Border") ? ctx.rule["Border"] : "Border"

        if !isEnabled {
            bgKey := ctx.rule.Has("DisabledBg") ? ctx.rule["DisabledBg"] : (ctx.rule.Has("Bg") ? ctx.rule["Bg"] : "Surface")
            fgKey := ctx.rule.Has("DisabledFg") ? ctx.rule["DisabledFg"] : "FgDim"
            borderKey := ctx.rule.Has("DisabledBorder") ? ctx.rule["DisabledBorder"] : (ctx.rule.Has("Border") ? ctx.rule["Border"] : "Border")
        } else if isPressed {
            bgKey := ctx.rule.Has("PressedBg") ? ctx.rule["PressedBg"] : "Accent"
            fgKey := ctx.rule.Has("PressedFg") ? ctx.rule["PressedFg"] : "BaseBg"
            borderKey := ctx.rule.Has("PressedBorder") ? ctx.rule["PressedBorder"] : (ctx.rule.Has("Border") ? ctx.rule["Border"] : "Accent")
        } else if isChecked {
            bgKey := ctx.rule.Has("CheckedBg") ? ctx.rule["CheckedBg"] : (ctx.rule.Has("PressedBg") ? ctx.rule["PressedBg"] : "Accent")
            fgKey := ctx.rule.Has("CheckedFg") ? ctx.rule["CheckedFg"] : (ctx.rule.Has("PressedFg") ? ctx.rule["PressedFg"] : "BaseBg")
            borderKey := ctx.rule.Has("CheckedBorder") ? ctx.rule["CheckedBorder"] : (ctx.rule.Has("PressedBorder") ? ctx.rule["PressedBorder"] : (ctx.rule.Has("Border") ? ctx.rule["Border"] : "Accent"))
        } else if isHover {
            bgKey := ctx.rule.Has("HoverBg") ? ctx.rule["HoverBg"] : bgKey
            fgKey := ctx.rule.Has("HoverFg") ? ctx.rule["HoverFg"] : fgKey
            borderKey := ctx.rule.Has("HoverBorder") ? ctx.rule["HoverBorder"] : (ctx.rule.Has("Border") ? ctx.rule["Border"] : "Accent")
        } else if isFocused {
            bgKey := ctx.rule.Has("FocusedBg") ? ctx.rule["FocusedBg"] : bgKey
            fgKey := ctx.rule.Has("FocusedFg") ? ctx.rule["FocusedFg"] : fgKey
            borderKey := ctx.rule.Has("FocusedBorder") ? ctx.rule["FocusedBorder"] : (ctx.rule.Has("Border") ? ctx.rule["Border"] : "Accent")
        }

        ctx.RoundRect(0, 0, ctx.w, ctx.h, ctx.S(5), borderKey, bgKey)

        buttonText := ControlGetText(ctx.hwnd)
        hIcon := DllCall("user32\SendMessageW", "Ptr", ctx.hwnd, "UInt", 0x00F6, "UPtr", 1, "Ptr", 0, "Ptr")
        if hIcon {
            if (buttonText != "") {
                hFont := RT.Send(ctx.hwnd, 0x0031), oldFont := hFont ? RT.Select(ctx.hdc, hFont) : 0
                sz := Buffer(8, 0), DllCall("gdi32\GetTextExtentPoint32W", "Ptr", ctx.hdc, "Str", buttonText, "Int", StrLen(buttonText), "Ptr", sz.Ptr)
                tw := NumGet(sz, 0, "Int")
                if oldFont
                    RT.Select(ctx.hdc, oldFont)
                ix := (ctx.w - 16 - 6 - tw) // 2
                iy := (ctx.h - 16) // 2
                DllCall("user32\DrawIconEx", "Ptr", ctx.hdc, "Int", ix, "Int", iy, "Ptr", hIcon, "Int", 16, "Int", 16, "UInt", 0, "Ptr", 0, "UInt", 3)
                ctx.Text(buttonText, fgKey, ix + 16 + 6, 0, ctx.w - (ix + 16 + 6), ctx.h, 0x24)
            } else {
                ix := (ctx.w - 16) // 2
                iy := (ctx.h - 16) // 2
                DllCall("user32\DrawIconEx", "Ptr", ctx.hdc, "Int", ix, "Int", iy, "Ptr", hIcon, "Int", 16, "Int", 16, "UInt", 0, "Ptr", 0, "UInt", 3)
            }
        } else {
            if (buttonText != "") {
                ctx.Text(buttonText, fgKey, 0, 0, ctx.w, ctx.h, 0x25)
            }
        }
    }

    static PaintInverted(ctx, printFlags := 0xE) {
        hdcMem := DllCall("gdi32\CreateCompatibleDC", "Ptr", ctx.hdc, "Ptr")
        hBmp := DllCall("gdi32\CreateCompatibleBitmap", "Ptr", ctx.hdc, "Int", ctx.w, "Int", ctx.h, "Ptr")
        oBmp := RT.Select(hdcMem, hBmp)
        DllCall("user32\DefWindowProcW", "Ptr", ctx.hwnd, "UInt", 0x0317, "Ptr", hdcMem, "Ptr", printFlags)
        hdcDest := DllCall("gdi32\CreateCompatibleDC", "Ptr", ctx.hdc, "Ptr")
        hBmpDest := DllCall("gdi32\CreateCompatibleBitmap", "Ptr", ctx.hdc, "Int", ctx.w, "Int", ctx.h, "Ptr")
        oBmpDest := RT.Select(hdcDest, hBmpDest)
        ctx.Fill("BaseBg", , , , , hdcDest)
        DllCall("gdi32\BitBlt", "Ptr", hdcDest, "Int", 2, "Int", 2, "Int", ctx.w - 4, "Int", ctx.h - 4, "Ptr", hdcMem, "Int", 2, "Int", 2, "UInt", 0x00330008)
        ctx.RoundRect(0, 0, ctx.w, ctx.h, ctx.S(5), ctx.rule.Has("Border") ? ctx.rule["Border"] : "Border", "", hdcDest)
        DllCall("gdi32\BitBlt", "Ptr", ctx.hdc, "Int", 0, "Int", 0, "Int", ctx.w, "Int", ctx.h, "Ptr", hdcDest, "Int", 0, "Int", 0, "UInt", 0xCC0020)
        RT.Select(hdcDest, oBmpDest), RT.Delete(hBmpDest), DllCall("gdi32\DeleteDC", "Ptr", hdcDest)
        RT.Select(hdcMem, oBmp), RT.Delete(hBmp), DllCall("gdi32\DeleteDC", "Ptr", hdcMem)
    }

    static PaintHotkey(ctx) {
        ctx.Fill(ctx.rule.Has("Bg") ? ctx.rule["Bg"] : "Surface")
        hotkeyStr := RT.GetHotkeyText(ctx.hwnd), pad := ctx.S(6)
        ctx.Text(hotkeyStr, ctx.rule.Has("Fg") ? ctx.rule["Fg"] : "Text", pad, 0, ctx.w - pad * 2, ctx.h, 0x24)
        ctx.RoundRect(0, 0, ctx.w, ctx.h, ctx.S(5), ctx.rule.Has("Border") ? ctx.rule["Border"] : "Border")
    }

    static PaintIPAddress(ctx) {
        ctx.Fill(ctx.rule.Has("Bg") ? ctx.rule["Bg"] : "Surface"), edits := [], child := DllCall("user32\GetWindow", "Ptr", ctx.hwnd, "UInt", 5, "Ptr")
        while child {
            try {
                if InStr(WinGetClass(child), "Edit") {
                    rc := RT.GetMappedRect(child, ctx.hwnd)
                    edits.Push({ hwnd: child, left: rc.L, right: rc.R })
                }
            } catch {
            }
            child := DllCall("user32\GetWindow", "Ptr", child, "UInt", 2, "Ptr")
        }
        loop edits.Length {
            i := A_Index, j := i
            while (j > 1 && edits[j].left < edits[j - 1].left)
                tmp := edits[j], edits[j] := edits[j - 1], edits[j - 1] := tmp, j--
        }
        cy := ctx.h // 2 + Integer(2 * ctx.scale), fg := ctx.rule.Has("Fg") ? ctx.rule["Fg"] : "Text"
        loop 3 {
            cx := (edits.Length == 4) ? (edits[A_Index].right + edits[A_Index + 1].left) // 2 : Integer(ctx.w * A_Index / 4)
            ctx.Fill(fg, cx - 1, cy - 1, 3, 3)
        }
        ctx.RoundRect(0, 0, ctx.w, ctx.h, ctx.S(5), ctx.rule.Has("Border") ? ctx.rule["Border"] : "Border")
    }

    static GetHotkeyText(hwnd) {
        hk := RT.Send(hwnd, 0x0402)
        if (hk == 0)
            return "None"
        vk := hk & 0xFF, mods := (hk >> 8) & 0xFF, str := ""
        if (mods & 2)
            str .= "Ctrl + "
        if (mods & 4)
            str .= "Alt + "
        if (mods & 1)
            str .= "Shift + "
        return str . RT.GetKeyName(vk, mods & 8)
    }

    static GetKeyName(vk, ext) {
        lParam := DllCall("user32\MapVirtualKeyW", "UInt", vk, "UInt", 0, "UInt") << 16
        if ext
            lParam |= 0x01000000
        buf := Buffer(256, 0), DllCall("user32\GetKeyNameTextW", "Int", lParam, "Ptr", buf.Ptr, "Int", 128)
        name := StrGet(buf)
        return (name == "") ? Chr(vk) : Format("{:U}", SubStr(name, 1, 1)) . SubStr(name, 2)
    }

    static PaintMonthCalNav(ctx) {
        x1 := ctx.S(20), x2 := ctx.w - ctx.S(20), y := ctx.S(12)
        prev := RT.HitTestMonthCal(ctx.hwnd, x1, y, ctx.w)
        next := RT.HitTestMonthCal(ctx.hwnd, x2, y, ctx.w)
        if (prev && next) {
            ctx.Fill("Surface", prev.L - 1, prev.T - 1, prev.R - prev.L + 2, prev.B - prev.T + 2)
            cx := (prev.L + prev.R) // 2, cy := (prev.T + prev.B) // 2, r := ctx.S(4)
            ctx.Tri(cx + r, cy - r, cx + r, cy + r, cx - r, cy, "Text")
            ctx.Fill("Surface", next.L - 1, next.T - 1, next.R - next.L + 2, next.B - next.T + 2)
            cx := (next.L + next.R) // 2, cy := (next.T + next.B) // 2
            ctx.Tri(cx - r, cy - r, cx - r, cy + r, cx + r, cy, "Text")
        }
    }

    static HitTestMonthCal(hwnd, x, y, cw) {
        ht := Buffer(56, 0), NumPut("UInt", 56, ht, 0), NumPut("Int", x, ht, 4), NumPut("Int", y, ht, 8)
        RT.Send(hwnd, 0x100E, 0, ht.Ptr)
        rcLeft := NumGet(ht, 32, "Int"), rcTop := NumGet(ht, 36, "Int"), rcRight := NumGet(ht, 40, "Int"), rcBottom := NumGet(ht, 44, "Int"), w := rcRight - rcLeft
        return (w <= 0 || w >= cw // 2) ? 0 : { L: rcLeft, T: rcTop, R: rcRight, B: rcBottom }
    }

    static PaintDivider(ctx, type) {
        pWnd := RT.Parent(ctx.hwnd)
        bg := (pWnd && RT.CtlCache.Has(pWnd) && RT.CtlCache[pWnd].Has("Bg")) ? RT.CtlCache[pWnd]["Bg"] : "BaseBg"
        ctx.Fill(bg)
        lineColor := ctx.rule.Has("Border") ? ctx.rule["Border"] : "Border"
        if (type == 0x10)
            ctx.Fill(lineColor, 0, ctx.h // 2, ctx.w, 1)
        else
            ctx.Fill(lineColor, ctx.w // 2, 0, 1, ctx.h)
    }

    static PaintCheckBox(ctx) {
        state := RT.Send(ctx.hwnd, 0x00F2) ; BM_GETSTATE
        checkState := RT.Send(ctx.hwnd, 0x00F0) ; BM_GETCHECK: 0=unchecked, 1=checked, 2=indeterminate
        isFocused := (state & 0x0008) != 0 || DllCall("user32\GetFocus", "Ptr") == ctx.hwnd
        isHover := RT.ButtonHoverMap.Has(ctx.hwnd) && RT.ButtonHoverMap[ctx.hwnd]
        isEnabled := DllCall("user32\IsWindowEnabled", "Ptr", ctx.hwnd)

        pWnd := RT.Parent(ctx.hwnd)
        bg := (pWnd && RT.CtlCache.Has(pWnd) && RT.CtlCache[pWnd].Has("Bg")) ? RT.CtlCache[pWnd]["Bg"] : "BaseBg"
        ctx.Fill(bg)

        boxSize := Min(ctx.S(15), ctx.h)
        boxX := 1
        boxY := (ctx.h - boxSize) // 2
        radius := ctx.S(3)

        borderColor := ctx.rule.Has("Border") ? ctx.rule["Border"] : "Border"
        boxBg := ctx.rule.Has("Bg") ? ctx.rule["Bg"] : bg
        checkColor := ctx.rule.Has("Fg") ? ctx.rule["Fg"] : "Text"

        if !isEnabled {
            borderColor := ctx.rule.Has("DisabledBorder") ? ctx.rule["DisabledBorder"] : "FgDim"
            boxBg := ctx.rule.Has("DisabledBg") ? ctx.rule["DisabledBg"] : bg
            checkColor := ctx.rule.Has("DisabledFg") ? ctx.rule["DisabledFg"] : "FgDim"
        } else if checkState >= 1 {
            borderColor := ctx.rule.Has("CheckedBorder") ? ctx.rule["CheckedBorder"] : (ctx.rule.Has("PressedBorder") ? ctx.rule["PressedBorder"] : "Accent")
            boxBg := ctx.rule.Has("CheckedBg") ? ctx.rule["CheckedBg"] : (ctx.rule.Has("PressedBg") ? ctx.rule["PressedBg"] : "Accent")
            checkColor := ctx.rule.Has("CheckedFg") ? ctx.rule["CheckedFg"] : (ctx.rule.Has("PressedFg") ? ctx.rule["PressedFg"] : "BaseBg")
        } else if isHover || isFocused {
            borderColor := ctx.rule.Has("HoverBorder") ? ctx.rule["HoverBorder"] : (ctx.rule.Has("Border") ? ctx.rule["Border"] : "Accent")
            boxBg := ctx.rule.Has("HoverBg") ? ctx.rule["HoverBg"] : boxBg
            checkColor := ctx.rule.Has("HoverFg") ? ctx.rule["HoverFg"] : checkColor
        }

        ctx.RoundRect(boxX, boxY, boxX + boxSize, boxY + boxSize, radius, borderColor, boxBg)

        if checkState == 1 {
            x1 := boxX + ctx.S(4), y1 := boxY + boxSize // 2
            x2 := boxX + boxSize // 2 - ctx.S(1), y2 := boxY + boxSize - ctx.S(4)
            x3 := boxX + boxSize - ctx.S(3), y3 := boxY + ctx.S(4)
            RT.GdipLines(ctx.hdc, RT.BgrToArgb(checkColor), ctx.scale * 2.0, x1, y1, x2, y2, x3, y3)
        } else if checkState == 2 {
            dashW := boxSize - ctx.S(6), dashH := ctx.S(2)
            dashX := boxX + (boxSize - dashW) // 2
            dashY := boxY + (boxSize - dashH) // 2
            ctx.Fill(checkColor, dashX, dashY, dashW, dashH)
        }

        buttonText := ControlGetText(ctx.hwnd)
        if (buttonText != "") {
            textX := boxX + boxSize + ctx.S(4)
            ctx.Text(buttonText, isEnabled ? (ctx.rule.Has("Fg") ? ctx.rule["Fg"] : "Text") : "FgDim", textX, 0, ctx.w - textX, ctx.h, 0x24)
        }
    }

    static PaintRadio(ctx) {
        state := RT.Send(ctx.hwnd, 0x00F2) ; BM_GETSTATE
        isChecked := RT.Send(ctx.hwnd, 0x00F0) == 1 ; BM_GETCHECK
        isFocused := (state & 0x0008) != 0 || DllCall("user32\GetFocus", "Ptr") == ctx.hwnd
        isHover := RT.ButtonHoverMap.Has(ctx.hwnd) && RT.ButtonHoverMap[ctx.hwnd]
        isEnabled := DllCall("user32\IsWindowEnabled", "Ptr", ctx.hwnd)

        pWnd := RT.Parent(ctx.hwnd)
        bg := (pWnd && RT.CtlCache.Has(pWnd) && RT.CtlCache[pWnd].Has("Bg")) ? RT.CtlCache[pWnd]["Bg"] : "BaseBg"
        ctx.Fill(bg)

        circleSize := Min(ctx.S(15), ctx.h)
        circleX := 1
        circleY := (ctx.h - circleSize) // 2
        cx := circleX + circleSize // 2
        cy := circleY + circleSize // 2
        r := circleSize // 2

        borderColor := ctx.rule.Has("Border") ? ctx.rule["Border"] : "Border"
        boxBg := ctx.rule.Has("Bg") ? ctx.rule["Bg"] : bg
        checkColor := ctx.rule.Has("Fg") ? ctx.rule["Fg"] : "Text"

        if !isEnabled {
            borderColor := ctx.rule.Has("DisabledBorder") ? ctx.rule["DisabledBorder"] : "FgDim"
            boxBg := ctx.rule.Has("DisabledBg") ? ctx.rule["DisabledBg"] : bg
            checkColor := ctx.rule.Has("DisabledFg") ? ctx.rule["DisabledFg"] : "FgDim"
        } else if isChecked {
            borderColor := ctx.rule.Has("CheckedBorder") ? ctx.rule["CheckedBorder"] : (ctx.rule.Has("PressedBorder") ? ctx.rule["PressedBorder"] : "Accent")
            boxBg := ctx.rule.Has("CheckedBg") ? ctx.rule["CheckedBg"] : (ctx.rule.Has("PressedBg") ? ctx.rule["PressedBg"] : bg)
            checkColor := ctx.rule.Has("CheckedFg") ? ctx.rule["CheckedFg"] : (ctx.rule.Has("PressedFg") ? ctx.rule["PressedFg"] : "Accent")
        } else if isHover || isFocused {
            borderColor := ctx.rule.Has("HoverBorder") ? ctx.rule["HoverBorder"] : (ctx.rule.Has("Border") ? ctx.rule["Border"] : "Accent")
            boxBg := ctx.rule.Has("HoverBg") ? ctx.rule["HoverBg"] : boxBg
            checkColor := ctx.rule.Has("HoverFg") ? ctx.rule["HoverFg"] : checkColor
        }

        bgA := RT.BgrToArgb(boxBg), bdrA := RT.BgrToArgb(borderColor)
        RT.GdipCircle(ctx.hdc, cx, cy, r - 0.5, bdrA, bgA)

        if isChecked {
            innerR := ctx.S(3)
            dotA := RT.BgrToArgb(checkColor)
            RT.GdipCircle(ctx.hdc, cx, cy, innerR, dotA, dotA)
        }

        buttonText := RT.OriginalRadioTexts.Has(ctx.hwnd) ? RT.OriginalRadioTexts[ctx.hwnd] : ControlGetText(ctx.hwnd)
        if (buttonText != "") {
            textX := circleX + circleSize + ctx.S(4)
            ctx.Text(buttonText, isEnabled ? (ctx.rule.Has("Fg") ? ctx.rule["Fg"] : "Text") : "FgDim", textX, 0, ctx.w - textX, ctx.h, 0x24)
        }
    }

    static PaintLink(ctx) {
        pWnd := RT.Parent(ctx.hwnd)
        bg := (pWnd && RT.CtlCache.Has(pWnd) && RT.CtlCache[pWnd].Has("Bg")) ? RT.CtlCache[pWnd]["Bg"] : "BaseBg"
        ctx.Fill(bg)

        rawText := ""
        try rawText := ControlGetText(ctx.hwnd)
        if rawText = ""
            return

        ; Strip tags to build segments: [{text, isLink}, ...]
        segments := [], remaining := rawText, inTag := false
        while remaining != "" {
            aLow := InStr(remaining, "<a"), aUp := InStr(remaining, "<A")
            aPos := aLow && aUp ? Min(aLow, aUp) : (aLow ? aLow : aUp)
            if !aPos {
                segments.Push({ t: remaining, link: false })
                break
            }
            pre := SubStr(remaining, 1, aPos - 1)
            if pre != ""
                segments.Push({ t: pre, link: false })
            gtPos := InStr(remaining, ">", , aPos)
            if !gtPos
                break
            eLow := InStr(remaining, "</a>", , gtPos), eUp := InStr(remaining, "</A>", , gtPos)
            ePos := eLow && eUp ? Min(eLow, eUp) : (eLow ? eLow : eUp)
            if !ePos
                break
            linkText := SubStr(remaining, gtPos + 1, ePos - gtPos - 1)
            if linkText != ""
                segments.Push({ t: linkText, link: true })
            remaining := SubStr(remaining, ePos + 4)
        }

        ; Get font
        hFont := RT.Send(ctx.hwnd, 0x0031)
        oldFont := hFont ? RT.Select(ctx.hdc, hFont) : 0
        DllCall("gdi32\SetBkMode", "Ptr", ctx.hdc, "Int", 1)

        ; Create underline font for links
        hUnderFont := 0
        if hFont {
            lf := Buffer(92, 0)
            DllCall("gdi32\GetObjectW", "Ptr", hFont, "Int", 92, "Ptr", lf.Ptr)
            NumPut("Byte", 1, lf, 21) ; lfUnderline
            hUnderFont := DllCall("gdi32\CreateFontIndirectW", "Ptr", lf.Ptr, "Ptr")
        }

        ; Draw segments
        curX := 0
        for seg in segments {
            color := seg.link ? "Accent" : "Text"
            if seg.link && hUnderFont
                RT.Select(ctx.hdc, hUnderFont)
            else if hFont
                RT.Select(ctx.hdc, hFont)
            DllCall("gdi32\SetTextColor", "Ptr", ctx.hdc, "UInt", RT.ResolveBGR(color))
            rc := RT.Rect(curX, 0, ctx.w, ctx.h)
            DllCall("user32\DrawTextW", "Ptr", ctx.hdc, "Str", seg.t, "Int", -1, "Ptr", rc.Ptr, "UInt", 0x24)
            ; Measure width to advance cursor
            sz := Buffer(8, 0)
            DllCall("gdi32\GetTextExtentPoint32W", "Ptr", ctx.hdc, "Str", seg.t, "Int", StrLen(seg.t), "Ptr", sz.Ptr)
            curX += NumGet(sz, 0, "Int")
        }

        if hUnderFont
            RT.Delete(hUnderFont)
        if oldFont
            RT.Select(ctx.hdc, oldFont)
    }

    static ActivePalette := "", Rules := [], Hooked := false, CtlCache := Map(), BorderMap := Map(), BordersSet := Map(), StatusBarTexts := Map(), RadioTextMap := Map(), RadioTextReverseMap := Map(), OriginalRadioTexts := Map(), ButtonHoverMap := Map(), fnSetPreferredAppMode := 0, fnFlushMenuThemes := 0, ListViewRedrawTimers := Map(), HeaderTexts := Map(), HeaderFormats := Map(), ListViews := Map(), RootWindows := Map(), Attached := Map()

    static FindRule(sel, def := "") {
        for r in this.Rules
            if r.Has("Selector") && r["Selector"] = sel
                return r
        return def ? def : Map("Bg", "BaseBg", "Fg", "Text")
    }

    static ResolveRule(sel, classNN, ctrlName := "") {
        for r in this.Rules {
            if r.Has("Selector") && (r["Selector"] = sel || (ctrlName != "" && r["Selector"] = ctrlName) || r["Selector"] = "*" || InStr(classNN, r["Selector"]))
                return r
        }
        if InStr("|CheckBox|Radio|GroupBox|", "|" sel "|") {
            for r in this.Rules
                if r.Has("Selector") && r["Selector"] = "Static"
                    return r
        }

        bg := "BaseBg", fg := "Text", border := "", extra := Map()
        if InStr("|Edit|ComboBox|ListBox|msctls_updown32|SysDateTimePick32|SysMonthCal32|msctls_hotkey32|SysIPAddress32|SysListView32|SysTreeView32|", "|" classNN "|") || (classNN == "Button" && sel == "Button") {
            bg := "Surface", border := "Border"
            if classNN = "SysTreeView32"
                extra["Line"] := "Accent"
        } else if classNN = "Msctls_statusbar32" {
            bg := "Surface"
        } else if classNN = "msctls_progress32" {
            bg := "Surface", fg := "Accent"
        } else if sel = "GroupBox" {
            border := "Border"
        } else if classNN = "msctls_trackbar32" {
            fg := "Accent"
        }

        res := Map("Bg", bg, "Fg", fg)
        if border
            res["Border"] := border
        for k, v in extra
            res[k] := v
        return res
    }

    static IsThemedWindowActive(*) {
        activeHwnd := WinActive("A")
        return activeHwnd && RT.RootWindows.Has(activeHwnd)
    }

    static RegisterEditorHotkey() {
        static registeredHotkey := ""
        if registeredHotkey {
            try {
                HotIf(RT.IsThemedWindowActive)
                Hotkey(registeredHotkey, "Off")
            }
        }
        registeredHotkey := ""
        if RT.Config.EnableEditorHotkey && RT.Config.EditorHotkey {
            try {
                HotIf(RT.IsThemedWindowActive)
                Hotkey(RT.Config.EditorHotkey, (*) => (RT.Config.EnableEditorHotkey ? RT.ThemeEditor.Show() : ""), "On")
                registeredHotkey := RT.Config.EditorHotkey
            }
        }
    }

    static Init(themeOrPalette := "", rulesArray := "", configMap := "") {
        if IsObject(configMap) {
            if (configMap is Map) {
                for k, v in configMap {
                    if HasProp(RT.Config, k)
                        RT.Config.%k% := v
                }
            } else {
                for k, v in configMap.OwnProps() {
                    if HasProp(RT.Config, k)
                        RT.Config.%k% := v
                }
            }
        }

        resolvedPalette := ""
        if (themeOrPalette == "" || themeOrPalette == 0) {
            themeOrPalette := RT.Config.DefaultTheme
        }

        if IsObject(themeOrPalette) {
            if (themeOrPalette is RT.Palette) {
                resolvedPalette := themeOrPalette
            } else {
                resolvedPalette := RT.Palette(themeOrPalette)
                RT.CurrentThemeName := "Custom"
            }
        } else if (themeOrPalette != "") {
            cfg := RT.LoadThemeFromIni(themeOrPalette)
            if cfg {
                resolvedPalette := RT.Palette(cfg)
                RT.CurrentThemeName := themeOrPalette
            }
        }

        if !resolvedPalette {
            resolvedPalette := RT.Palette()
            RT.CurrentThemeName := "Default Dark"
        }

        this.ActivePalette := resolvedPalette
        RT.UpdateMenuTheme()
        this.Rules := rulesArray ? rulesArray.Clone() : []
        this.CtlCache := Map(), this.Attached := Map(), this.BorderMap := Map(), this.BordersSet := Map(), this.StatusBarTexts := Map(), this.OriginalRadioTexts := Map(), this.ButtonHoverMap := Map(), this.Depths := Map(), this.ListViewRedrawTimers := Map(), this.HeaderTexts := Map(), this.HeaderFormats := Map(), this.ListViews := Map()
        if !this.Hooked {
            for msg in [0x0132, 0x0133, 0x0134, 0x0135, 0x0136, 0x0137, 0x0138]
                OnMessage(msg, (wp, lp, m, hw) => RT.OnCtlColor(wp, lp, m, hw))
            this.Hooked := true
        }
        RT.RegisterEditorHotkey()
    }

    static GetBorderHwnd(hwnd) => this.BorderMap.Has(hwnd) ? this.BorderMap[hwnd] : 0
    static ResolveBGR(c, rule := "") {
        if rule && rule.Has(c) {
            val := rule[c]
            return (this.ActivePalette && this.ActivePalette.BGR.Has(val)) ? this.ActivePalette.BGR[val] : RT.ParseColor(val).BGR
        }
        return (this.ActivePalette && this.ActivePalette.BGR.Has(c)) ? this.ActivePalette.BGR[c] : RT.ParseColor(c).BGR
    }
    static ResolveRGB(c, rule := "") {
        if rule && rule.Has(c) {
            val := rule[c]
            return (this.ActivePalette && this.ActivePalette.RGB.Has(val)) ? this.ActivePalette.RGB[val] : RT.ParseColor(val).RGB
        }
        return (this.ActivePalette && this.ActivePalette.RGB.Has(c)) ? this.ActivePalette.RGB[c] : RT.ParseColor(c).RGB
    }

    static ResolveBrush(c, rule := "") {
        if !this.ActivePalette
            return 0
        if rule && rule.Has(c) {
            val := rule[c]
            if this.ActivePalette.Brushes.Has(val)
                return this.ActivePalette.Brushes[val]
            return this.ActivePalette.Brushes[val] := RT.Brush(val)
        }
        if this.ActivePalette.Brushes.Has(c)
            return this.ActivePalette.Brushes[c]
        return this.ActivePalette.Brushes[c] := RT.Brush(c)
    }

    static GetCursorHandle(name) {
        static cursors := Map(
            "Arrow", 32512,
            "IBeam", 32513,
            "Wait", 32514,
            "Cross", 32515,
            "UpArrow", 32516,
            "Size", 32640,
            "Icon", 32641,
            "SizeNWSE", 32642,
            "SizeNESW", 32643,
            "SizeWE", 32644,
            "SizeNS", 32645,
            "SizeAll", 32646,
            "No", 32648,
            "Hand", 32649,
            "AppStarting", 32650,
            "Help", 32651
        )
        if IsInteger(name)
            id := name
        else if cursors.Has(name)
            id := cursors[name]
        else
            return 0
        return DllCall("user32\LoadCursorW", "Ptr", 0, "Ptr", id, "Ptr")
    }

    static GetChildWindows(parent) {
        hwnds := []
        cb := CallbackCreate((h, l) => (hwnds.Push(h), 1), "F", 2)
        DllCall("user32\EnumChildWindows", "Ptr", parent, "Ptr", cb, "Ptr", 0)
        CallbackFree(cb)
        return hwnds
    }

    static ApplyMonthCalTheme(hwnd) {
        RT.Theme(hwnd)
        bg := RT.ResolveBGR("BaseBg"), fg := RT.ResolveBGR("Text")
        for item in [[0, bg], [4, bg], [1, fg], [2, RT.ResolveBGR("Surface")], [3, fg], [5, RT.ResolveBGR("FgDim")]]
            RT.Send(hwnd, 0x100A, item[1], item[2])
        RT.Attach(hwnd)
    }

    static Apply(hwnd, isRoot := true) {
        try {
            if this.CtlCache.Has(hwnd)
                return
            if isRoot && (RT.Style(hwnd) & 0x40000000)
                isRoot := false
            this.ApplyInternal(hwnd, isRoot)
        } catch {
            if !RT.Config.Robust
                throw
        }
    }

    static ApplyInternal(hwnd, isRoot := true) {
        if !this.ActivePalette
            this.Init(RT.Palette())

        classNN := ""
        try classNN := RT.GetClassName(hwnd)
        catch {
        }

        this.CtlCache[hwnd] := this.FindRule(classNN)
        if classNN = "#32770" {
            try RT.Theme(hwnd, RT.ExplorerTheme)
            try DllCall("uxtheme\EnableThemeDialogTexture", "Ptr", hwnd, "UInt", 2)
        }

        if isRoot {
            RT.RootWindows[hwnd] := true
            try GuiFromHwnd(hwnd).BackColor := this.ActivePalette.RGB["BaseBg"]
            RT.DWM_Apply(hwnd, this.ActivePalette)
            try DllCall("uxtheme\133", "Ptr", hwnd, "Int", this.ActivePalette.IsDark ? 1 : 0)
            RT.Attach(hwnd)
            RT.Send(hwnd, 0x0127, 0x00030001, 0)
            RT.RegisterThemesMenu(hwnd)
            RT.RegisterEditorHotkey()
        }

        for childHwnd in this.GetChildWindows(hwnd) {
            if this.Attached.Has(childHwnd) || this.BordersSet.Has(childHwnd) || RT.RadioTextMap.Has(childHwnd)
                continue
            classNN := RT.GetClassName(childHwnd)
            if InStr("|SysHeader32|ComboLBox|", "|" classNN "|")
                continue

            sel := classNN
            ctrlName := ""
            try {
                ctrlObj := GuiCtrlFromHwnd(childHwnd)
                if ctrlObj
                    ctrlName := ctrlObj.Name
            } catch {
            }

            if classNN = "Button" {
                try {
                    style := RT.Style(childHwnd)
                    if (style & 0x1000) {
                        sel := "Button"
                    } else {
                        btnType := style & 0x0F
                        sel := InStr("|2|3|5|6|", "|" btnType "|") ? "CheckBox" : InStr("|4|9|", "|" btnType "|") ? "Radio" : btnType == 7 ? "GroupBox" : "Button"
                    }
                }
            }
            rule := this.CtlCache.Has(childHwnd) ? this.CtlCache[childHwnd] : this.ResolveRule(sel, classNN, ctrlName)
            if !rule
                continue

            this.CtlCache[childHwnd] := rule
            if classNN = "AutoHotkeyGUI" {
                try GuiFromHwnd(childHwnd).BackColor := this.ActivePalette.RGB["BaseBg"]
                RT.Attach(childHwnd)
                continue
            }
            if classNN = "#32770" {
                try DllCall("uxtheme\133", "Ptr", childHwnd, "Int", RT.IsDark ? 1 : 0)
                RT.Theme(childHwnd, RT.ExplorerTheme)
                try DllCall("uxtheme\EnableThemeDialogTexture", "Ptr", childHwnd, "UInt", 2)
                try RT.Style(childHwnd, "+0x04000000")
                RT.Attach(childHwnd)
                continue
            }
            if classNN = "SysTabControl32" {
                try DllCall("uxtheme\133", "Ptr", childHwnd, "Int", RT.IsDark ? 1 : 0)
                RT.Theme(childHwnd, RT.ExplorerTheme)
                try RT.Style(childHwnd, "+0x04000000")
                RT.SetPos(childHwnd, 0, 0, 0, 0, 0x0013, 1)
                RT.Attach(childHwnd)
                continue
            }

            if classNN = "msctls_trackbar32" {
                RT.Theme(childHwnd, 0)
                try RT.Style(childHwnd, "+0x04000000")
                RT.Attach(childHwnd)
                continue
            }

            parentClass := ""
            try {
                pWnd := RT.Parent(childHwnd)
                if pWnd
                    parentClass := WinGetClass(pWnd)
            } catch {
            }

            if parentClass = "SysIPAddress32" {
                RT.Theme(childHwnd)
                continue
            }

            themeName := InStr("|Static|GroupBox|CheckBox|Radio|", "|" sel "|") ? "" : (classNN = "msctls_hotkey32" ? "" : RT.ExplorerTheme)
            if themeName !== ""
                RT.Theme(childHwnd, themeName)

            try {
                ctrlObj := GuiCtrlFromHwnd(childHwnd)
                if ctrlObj && rule.Has("Fg")
                    ctrlObj.SetFont("c" . this.ResolveRGB(rule["Fg"]))
            } catch {
            }

            if InStr("|SysIPAddress32|ComboBox|Edit|ListBox|msctls_hotkey32|", "|" classNN "|") {
                try {
                    exStyle := RT.ExStyle(childHwnd)
                    if exStyle & 0x0200
                        RT.ExStyle(childHwnd, exStyle & ~0x0200), RT.SetPos(childHwnd, 0, 0, 0, 0, 0x0237)
                } catch {
                }
            }

            if classNN = "msctls_progress32" {
                RT.Theme(childHwnd)
                RT.Send(childHwnd, 0x2001, 0, this.ResolveBGR(rule.Has("Bg") ? rule["Bg"] : "Surface"))
                RT.Send(childHwnd, 0x0409, 0, this.ResolveBGR(rule.Has("Fg") ? rule["Fg"] : "Accent"))
                continue
            }
            else if classNN = "SysDateTimePick32" {
                RT.Theme(childHwnd)
                bg := this.ResolveBGR("BaseBg"), fg := this.ResolveBGR("Text")
                for item in [[0, bg], [4, bg], [1, fg], [2, this.ResolveBGR("Surface")], [3, fg], [5, this.ResolveBGR("FgDim")]]
                    RT.Send(childHwnd, 0x1006, item[1], item[2])
                RT.Attach(childHwnd)
                continue
            }
            else if classNN = "SysMonthCal32" {
                this.ApplyMonthCalTheme(childHwnd)
                continue
            }
            else if classNN = "Static" {
                try {
                    type := RT.Style(childHwnd) & 0x1F
                    if type == 0x10 || type == 0x11 {
                        RT.Theme(childHwnd, 0)
                        try {
                            exStyle := RT.ExStyle(childHwnd)
                            if exStyle & 0x00020200
                                RT.ExStyle(childHwnd, exStyle & ~0x00020200)
                        }
                        try {
                            style := RT.Style(childHwnd)
                            if style & 0x00800000
                                RT.Style(childHwnd, style & ~0x00800000)
                        }
                        RT.SetPos(childHwnd, 0, 0, 0, 0, 0x0237)
                        RT.Attach(childHwnd)
                    }
                } catch {
                }
            }
            else if sel = "CheckBox" {
                RT.Theme(childHwnd, 0)
                try RT.Style(childHwnd, "+0x04000000")
                RT.Attach(childHwnd)
                continue
            }
            else if sel = "Radio" {
                RT.Theme(childHwnd, 0)
                if !RT.OriginalRadioTexts.Has(childHwnd)
                    RT.OriginalRadioTexts[childHwnd] := ControlGetText(childHwnd)
                try RT.Style(childHwnd, "+0x04000000")
                RT.Attach(childHwnd)
                continue
            }

            if (sel != "GroupBox" && classNN != "Static" && classNN != "SysLink")
                try RT.Style(childHwnd, "+0x04000000")

            hBorder := RT.GetBorderHwnd(childHwnd)
            isPushLike := (classNN == "Button" && (RT.Style(childHwnd) & 0x1000))
            if rule.Has("Border") && !hBorder
                && !InStr("|SysDateTimePick32|SysMonthCal32|msctls_updown32|ComboBox|msctls_hotkey32|SysListView32|SysTreeView32|", "|" classNN "|")
                && sel != "GroupBox" && sel != "Button" && sel != "CheckBox" && sel != "Radio" && !isPushLike && parentClass != "#32770" {
                try {
                    pWnd := RT.Parent(childHwnd)
                    rc := RT.GetMappedRect(childHwnd, pWnd)
                    hBorder := DllCall("user32\CreateWindowExW", "UInt", 0, "WStr", "Static", "Ptr", 0, "UInt", 0x4C000000 | (RT.Style(childHwnd) & 0x10000000), "Int", rc.L - 1, "Int", rc.T - 1, "Int", rc.W + 2, "Int", rc.H + 2, "Ptr", pWnd, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
                    if hBorder {
                        this.BordersSet[hBorder] := true, this.BorderMap[childHwnd] := hBorder
                        RT.SetPos(hBorder, rc.L - 1, rc.T - 1, rc.W + 2, rc.H + 2, 0x0010, 1)
                    }
                } catch {
                }
            }
            if hBorder {
                this.CtlCache[hBorder] := rule.Clone()
                this.CtlCache[hBorder]["Bg"] := rule.Has("Border") ? rule["Border"] : "Border"
                RT.SyncPosition(childHwnd, hBorder, -1, -1, 2, 2, 1, 0x0010)
            }
            shouldAttach := (rule.Has("Border") && classNN != "SysListView32" && classNN != "SysTreeView32")
                || InStr("|Msctls_statusbar32|SysIPAddress32|", "|" classNN "|")
                || rule.Has("Cursor")
                || (classNN == "Button" && (RT.Config.ButtonCursor != "" || rule.Count > 0))
                || InStr("|Edit|ComboBox|ListBox|msctls_updown32|msctls_hotkey32|msctls_trackbar32|", "|" classNN "|")
            if shouldAttach
                RT.Attach(childHwnd)

            if classNN = "SysListView32" {
                hHeader := RT.Send(childHwnd, 0x101F)
                if hHeader {
                    try DllCall("uxtheme\133", "Ptr", hHeader, "Int", RT.IsDark ? 1 : 0)
                    RT.Theme(hHeader, RT.IsDark ? "DarkMode_ItemsView" : "Explorer")
                }
                try DllCall("uxtheme\133", "Ptr", childHwnd, "Int", RT.IsDark ? 1 : 0)
                RT.Theme(childHwnd, RT.IsDark ? "DarkMode_Explorer" : "Explorer")

                try RT.ExStyle(childHwnd, "-0x00000200") ; WS_EX_CLIENTEDGE (remove 3D border)
                try RT.Style(childHwnd, "-0x00800000") ; WS_BORDER (remove standard border)
                DllCall("user32\SetWindowPos", "Ptr", childHwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0037)

                if rule.Has("Bg") {
                    bg := this.ResolveBGR(rule["Bg"])
                    RT.Send(childHwnd, 0x1001, 0, bg), RT.Send(childHwnd, 0x1026, 0, bg)
                }
                if rule.Has("Fg")
                    RT.Send(childHwnd, 0x1024, 0, this.ResolveBGR(rule["Fg"]))

                RT.ListViews[childHwnd] := hwnd
                RT.SubclassListView(childHwnd)
            }
            else if classNN = "SysTreeView32" {
                try DllCall("uxtheme\133", "Ptr", childHwnd, "Int", RT.IsDark ? 1 : 0)
                if rule.Has("Bg")
                    RT.Send(childHwnd, 0x111D, 0, this.ResolveBGR(rule["Bg"]))
                if rule.Has("Fg")
                    RT.Send(childHwnd, 0x111E, 0, this.ResolveBGR(rule["Fg"]))
                if rule.Has("Line")
                    RT.Send(childHwnd, 0x111F, 0, this.ResolveBGR(rule["Line"]))
            }
            else if classNN = "Msctls_statusbar32" {
                RT.Theme(childHwnd)
                if rule.Has("Bg")
                    RT.Send(childHwnd, 0x2001, 0, this.ResolveBGR(rule["Bg"]))
                try RT.Style(childHwnd, "-0x00800000")
                try RT.ExStyle(childHwnd, "-0x00000200")
                RT.SetPos(childHwnd, 0, 0, 0, 0, 0x0037)
                if !this.StatusBarTexts.Has(childHwnd)
                    this.StatusBarTexts[childHwnd] := Map()
                numParts := RT.Send(childHwnd, 0x0406)
                if numParts <= 0
                    numParts := 1
                RT.Send(childHwnd, 0x000B, 0, 0)
                loop numParts {
                    partIdx := A_Index - 1, lenAndType := RT.Send(childHwnd, 0x040C, partIdx), len := lenAndType & 0xFFFF
                    if len > 0 {
                        textBuf := Buffer((len + 1) * 2, 0), RT.Send(childHwnd, 0x040D, partIdx, textBuf.Ptr)
                        this.StatusBarTexts[childHwnd][partIdx] := StrGet(textBuf)
                        RT.Send(childHwnd, 0x040B, partIdx | 0x1100, textBuf.Ptr)
                    }
                }
                RT.Send(childHwnd, 0x000B, 1, 0)
                DllCall("user32\InvalidateRect", "Ptr", childHwnd, "Ptr", 0, "Int", 1)
                RT.Attach(RT.Parent(childHwnd))
            }
            else if classNN = "ComboBox" {
                cbi := Buffer(RT.P(64, 52), 0), NumPut("UInt", cbi.Size, cbi, 0)
                if RT.Send(childHwnd, 0x0164, 0, cbi.Ptr) {
                    hwndList := NumGet(cbi, RT.P(56, 48), "Ptr")
                    if hwndList {
                        RT.Theme(hwndList, RT.ExplorerTheme)
                        this.CtlCache[hwndList] := rule
                        RT.Attach(hwndList)
                    }
                }
            }
            DllCall("user32\RedrawWindow", "Ptr", childHwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0101)
        }
    }

    static InvalidateGroupChildren(hGroup) {
        rcGroup := RT.RectObj(hGroup)
        pWnd := DllCall("user32\GetParent", "Ptr", hGroup, "Ptr")
        if !pWnd
            return
        buf := Buffer(256)
        child := DllCall("user32\GetWindow", "Ptr", pWnd, "UInt", 5, "Ptr")
        while child {
            if child != hGroup {
                rcCtl := RT.RectObj(child)
                cx := rcCtl.L, cy := rcCtl.T
                if (cx >= rcGroup.L && cx <= rcGroup.R && cy >= rcGroup.T && cy <= rcGroup.B) {
                    DllCall("user32\InvalidateRect", "Ptr", child, "Ptr", 0, "Int", 1)
                }
            }
            child := DllCall("user32\GetWindow", "Ptr", child, "UInt", 2, "Ptr")
        }
    }

    static GetControlBg(hCtl, defaultBg) {
        rcCtl := RT.RectObj(hCtl)
        cx := rcCtl.L, cy := rcCtl.T
        pWnd := DllCall("user32\GetParent", "Ptr", hCtl, "Ptr")
        if !pWnd
            return defaultBg
        bestArea := 0, bgCol := defaultBg
        buf := Buffer(256)
        child := DllCall("user32\GetWindow", "Ptr", pWnd, "UInt", 5, "Ptr")
        while child {
            if child != hCtl {
                DllCall("user32\GetClassNameW", "Ptr", child, "Ptr", buf.Ptr, "Int", 256)
                clsName := StrGet(buf)
                if (clsName = "Button") {
                    style := DllCall("user32\GetWindowLongW", "Ptr", child, "Int", -16, "Int")
                    if ((style & 0x0F) == 0x07) {
                        rcGroup := RT.RectObj(child)
                        if (cx >= rcGroup.L && cx <= rcGroup.R && cy >= rcGroup.T && cy <= rcGroup.B) {
                            area := rcGroup.W * rcGroup.H
                            if (bestArea == 0 || area < bestArea) {
                                bestArea := area
                                if RT.CtlCache.Has(child) && RT.CtlCache[child].Has("Bg")
                                    bgCol := RT.CtlCache[child]["Bg"]
                                else
                                    bgCol := "BaseBg"
                            }
                        }
                    }
                }
            }
            child := DllCall("user32\GetWindow", "Ptr", child, "UInt", 2, "Ptr")
        }
        return bgCol
    }

    static OnCtlColor(wParam, lParam, msg, hwnd) {
        if RT.Config.Robust {
            try return RT.OnCtlColorInternal(wParam, lParam, msg, hwnd)
        } else return RT.OnCtlColorInternal(wParam, lParam, msg, hwnd)
    }

    static OnCtlColorInternal(wParam, lParam, msg, hwnd) {
        if !RT.CtlCache.Has(lParam) {
            buf := Buffer(256)
            DllCall("user32\GetClassNameW", "Ptr", lParam, "Ptr", buf.Ptr, "Int", 256)
            clsName := StrGet(buf)
            if (clsName = "Static" || clsName = "Button" || clsName = "SysLink") {
                pWnd := DllCall("user32\GetParent", "Ptr", lParam, "Ptr")
                bg := (pWnd && RT.CtlCache.Has(pWnd) && RT.CtlCache[pWnd].Has("Bg")) ? RT.CtlCache[pWnd]["Bg"] : "BaseBg"
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", RT.ResolveBGR("Text"))
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", RT.ResolveBGR(bg))
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
                return RT.ResolveBrush(bg)
            }
            return
        }
        rule := RT.CtlCache[lParam]
        if rule.Has("Fg")
            DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", RT.ResolveBGR(rule["Fg"]))
        bg := rule.Has("Bg") ? rule["Bg"] : "BaseBg"
        if bg == "BaseBg" && RT.Config.AutoInheritBg {
            buf := Buffer(256)
            DllCall("user32\GetClassNameW", "Ptr", lParam, "Ptr", buf.Ptr, "Int", 256)
            clsName := StrGet(buf)
            if (clsName = "Static" || clsName = "SysLink")
                bg := RT.GetControlBg(lParam, bg)
        }
        DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", RT.ResolveBGR(bg))
        DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
        return RT.ResolveBrush(bg)
    }

    static DockedProcesses := Map()
    static MakeFrameless(hwnd) {
        RT.Style(hwnd, RT.Style(hwnd) & ~0x00CC0000)
        RT.ExStyle(hwnd, RT.ExStyle(hwnd) & ~0x00000301)
        RT.SetPos(hwnd, 0, 0, 0, 0, 0x0237)
    }
    static Dock(child, host, x := 0, y := 0, pr := 0, pb := 0) {
        RT.MakeFrameless(child)
        RT.Style(child, RT.Style(child) & ~0x80000000 | 0x40000000)
        RT.Parent(child, host)
        if !RT.DockedProcesses.Has(host)
            RT.DockedProcesses[host] := []
        RT.DockedProcesses[host].Push({ child: child, x: x, y: y, pr: pr, pb: pb })
        WinGetClientPos(, , &gw, &gh, host)
        RT.SetPos(child, x, y, gw - x - pr, gh - y - pb, 0x0040)
        RT.Show(child, 5)
    }
    static HandleResize(host, MinMax, Width, Height) {
        if MinMax != -1 && RT.DockedProcesses.Has(host.Hwnd)
            for conf in RT.DockedProcesses[host.Hwnd]
                RT.SetPos(conf.child, conf.x, conf.y, Width - conf.x - conf.pr, Height - conf.y - conf.pb, 0x0004)
    }

    ; --- Dynamic Themes.ini & Menu Registration & Live Theme Editor ---

    static CreateDefaultThemesIni(iniPath := "themes.ini") {
        defaultThemes := "
        (
            [Default Dark]
            BaseBg=121212
            Surface=1E1E1E
            Text=E0E0E0
            Accent=0078D4
            Border=333333
            Header=1E1E1E
            FgDim=888888
            
            [Default Light]
            BaseBg=F3F3F3
            Surface=FFFFFF
            Text=202020
            Accent=0066CC
            Border=CCCCCC
            Header=E5E5E5
            FgDim=666666
            
            [Emerald Dark]
            BaseBg=0A1C15
            Surface=102E22
            Text=E0F0E8
            Accent=00A86B
            Border=1E4C3A
            Header=102E22
            FgDim=8ABFA3
            
            [Ocean Dark]
            BaseBg=0B131E
            Surface=111E30
            Text=E1ECF7
            Accent=0080FF
            Border=203550
            Header=111E30
            FgDim=8CA8C8
            
            [Midnight Purple]
            BaseBg=100B1A
            Surface=191129
            Text=EFEBF5
            Accent=9F5FDF
            Border=31204C
            Header=191129
            FgDim=B29BCF
            
            [Nord Dark]
            BaseBg=2E3440
            Surface=3B4252
            Text=ECEFF4
            Accent=88C0D0
            Border=4C566A
            Header=3B4252
            FgDim=D8DEE9
            
            [Nord Light]
            BaseBg=ECEFF4
            Surface=FFFFFF
            Text=2E3440
            Accent=5E81AC
            Border=D8DEE9
            Header=E5E9F0
            FgDim=4C566A
            
            [Dracula]
            BaseBg=282A36
            Surface=343746
            Text=F8F8F2
            Accent=BD93F9
            Border=44475A
            Header=21222C
            FgDim=6272A4
            
            [Gruvbox Dark]
            BaseBg=282828
            Surface=3C3836
            Text=EBDBB2
            Accent=FE8019
            Border=504945
            Header=1D2021
            FgDim=A89984
            
            [Gruvbox Light]
            BaseBg=FBF1C7
            Surface=F9F5D7
            Text=3C3836
            Accent=B57614
            Border=D5C4A1
            Header=EBDBB2
            FgDim=7C6F64
            
            [One Dark]
            BaseBg=21252B
            Surface=282C34
            Text=ABB2BF
            Accent=61AFEF
            Border=3E4452
            Header=21252B
            FgDim=5C6370
            
            [Tokyo Night]
            BaseBg=1A1B26
            Surface=24283B
            Text=A9B1D6
            Accent=7AA2F7
            Border=383E56
            Header=1F2335
            FgDim=565F89
            
            [GitHub Light]
            BaseBg=F6F8FA
            Surface=FFFFFF
            Text=24292F
            Accent=0969DA
            Border=D0D7DE
            Header=F3F4F6
            FgDim=57606A
            
            [Solarized Light]
            BaseBg=FDF6E3
            Surface=EEE8D5
            Text=586E75
            Accent=268BD2
            Border=D3C7A1
            Header=EEE8D5
            FgDim=93A1A1
            
            [Rose Pine Dawn]
            BaseBg=FAF4ED
            Surface=F2E9E1
            Text=575279
            Accent=907AA9
            Border=DFDAE5
            Header=F2E9E1
            FgDim=797593
        )"
        try FileAppend(defaultThemes, iniPath, "UTF-8")
    }

    static LoadThemeFromIni(themeName, iniPath := "themes.ini") {
        if !FileExist(iniPath)
            RT.CreateDefaultThemesIni(iniPath)
        if !FileExist(iniPath)
            return ""
        cfg := Map()
        for k in ["BaseBg", "Surface", "Text", "Accent", "Border", "Header", "FgDim"] {
            val := IniRead(iniPath, themeName, k, "")
            if (val != "")
                cfg[k] := val
        }
        if (cfg.Count == 0)
            return ""
        return cfg
    }

    static GetThemesList(iniPath := "themes.ini") {
        if !FileExist(iniPath)
            RT.CreateDefaultThemesIni(iniPath)
        if !FileExist(iniPath)
            return []
        try {
            sectionsStr := IniRead(iniPath)
            if (sectionsStr == "")
                return []
            return StrSplit(sectionsStr, "`n")
        } catch {
            return []
        }
    }

    static SaveThemeToIni(themeName, cfg, iniPath := "themes.ini") {
        for k, v in cfg {
            IniWrite(v, iniPath, themeName, k)
        }
    }

    static DeleteThemeFromIni(themeName, iniPath := "themes.ini") {
        try IniDelete(iniPath, themeName)
    }

    static ApplyThemeToAllWindows() {
        processId := DllCall("kernel32\GetCurrentProcessId", "UInt")
        _EnumProc(hwnd, lParam) {
            DllCall("user32\GetWindowThreadProcessId", "Ptr", hwnd, "Ptr*", &wndProcId := 0)
            if (wndProcId == processId) {
                try {
                    class := WinGetClass(hwnd)
                    if (class == "AutoHotkeyGUI" || class == "#32770") {
                        try GuiFromHwnd(hwnd).BackColor := RT.ActivePalette.RGB["BaseBg"]
                        RT.DWM_Apply(hwnd, RT.ActivePalette)
                        try DllCall("uxtheme\133", "Ptr", hwnd, "Int", RT.ActivePalette.IsDark ? 1 : 0)
                        RT.Apply(hwnd, true)
                        DllCall("user32\SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0037)
                        DllCall("user32\RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0185)
                    }
                }
            }
            return 1
        }
        cb := CallbackCreate(_EnumProc, "F", 2)
        DllCall("user32\EnumWindows", "Ptr", cb, "Ptr", 0)
        CallbackFree(cb)
    }

    static UpdateMenuTheme() {
        if !RT.ActivePalette
            return
        try {
            if RT.fnSetPreferredAppMode
                DllCall(RT.fnSetPreferredAppMode, "Int", RT.ActivePalette.IsDark ? 2 : 0)
            if RT.fnFlushMenuThemes
                DllCall(RT.fnFlushMenuThemes)
        } catch {
        }
    }

    static SetTheme(themeName, iniPath := "themes.ini") {
        cfg := RT.LoadThemeFromIni(themeName, iniPath)
        if !cfg
            return false
        RT.ActivePalette := RT.Palette(cfg)
        RT.UpdateMenuTheme()
        RT.CtlCache := Map()
        RT.Attached := Map()
        RT.StatusBarTexts := Map()
        RT.Depths := Map()

        RT.ApplyThemeToAllWindows()
        RT.UpdateAllMenus()
        try {
            if RT.fnFlushMenuThemes
                DllCall(RT.fnFlushMenuThemes)
        }
        return true
    }

    static RegisteredMenus := Map()
    static CurrentThemeName := "Default Dark"

    static IsThemeDark(themeName) {
        cfg := RT.LoadThemeFromIni(themeName)
        if !cfg
            return true
        try {
            bgHex := cfg.Has("BaseBg") ? cfg["BaseBg"] : "121212"
            hex := StrReplace(StrReplace(bgHex, "#", ""), "0x", "")
            if (StrLen(hex) != 6)
                hex := "000000"
            r := Integer("0x" SubStr(hex, 1, 2))
            g := Integer("0x" SubStr(hex, 3, 2))
            b := Integer("0x" SubStr(hex, 5, 2))
            return (0.299 * r + 0.587 * g + 0.114 * b) < 128
        }
        return true
    }

    static RegisterThemesMenu(hwnd) {
        hMenu := DllCall("user32\GetMenu", "Ptr", hwnd, "Ptr")
        if !hMenu
            return

        ; Clean up any existing "Themes" top-level menu item
        count := DllCall("user32\GetMenuItemCount", "Ptr", hMenu)
        loop count {
            idx := A_Index - 1
            buf := Buffer(256)
            DllCall("user32\GetMenuStringW", "Ptr", hMenu, "UInt", idx, "Ptr", buf.Ptr, "Int", 128, "UInt", 0x0400)
            if (StrGet(buf) == "Themes") {
                DllCall("user32\DeleteMenu", "Ptr", hMenu, "UInt", idx, "UInt", 0x0400)
                break
            }
        }

        if !RT.Config.AddThemesMenu
            return

        ; Create a popup menu for the themes list
        hThemesSub := DllCall("user32\CreatePopupMenu", "Ptr")
        RT.RegisteredMenus[hwnd] := hThemesSub
        themes := RT.GetThemesList()

        darkThemes := []
        lightThemes := []
        for idx, themeName in themes {
            if RT.IsThemeDark(themeName)
                darkThemes.Push({ name: themeName, idx: idx })
            else
                lightThemes.Push({ name: themeName, idx: idx })
        }

        for item in darkThemes {
            DllCall("user32\AppendMenuW", "Ptr", hThemesSub, "UInt", 0, "UPtr", 0x9000 + item.idx, "WStr", item.name)
        }

        if darkThemes.Length > 0 && lightThemes.Length > 0 {
            DllCall("user32\AppendMenuW", "Ptr", hThemesSub, "UInt", 0x0800, "UPtr", 0, "Ptr", 0)
        }

        for item in lightThemes {
            DllCall("user32\AppendMenuW", "Ptr", hThemesSub, "UInt", 0, "UPtr", 0x9000 + item.idx, "WStr", item.name)
        }

        if RT.Config.AddEditorToMenu {
            DllCall("user32\AppendMenuW", "Ptr", hThemesSub, "UInt", 0x0800, "UPtr", 0, "Ptr", 0)
            DllCall("user32\AppendMenuW", "Ptr", hThemesSub, "UInt", 0, "UPtr", 0x9FFF, "WStr", "Theme Editor...")
        }

        ; Append "Themes" as a top-level menu item
        DllCall("user32\AppendMenuW", "Ptr", hMenu, "UInt", 0x0010, "UPtr", hThemesSub, "WStr", "Themes")

        RT.UpdateMenuCheckmarks(hwnd)
        DllCall("user32\DrawMenuBar", "Ptr", hwnd)
    }

    static AddThemeEditorToMenu(menuObj, itemName := "Theme Editor...") {
        if IsObject(menuObj) && HasMethod(menuObj, "Add") {
            menuObj.Add(itemName, (*) => RT.ThemeEditor.Show())
        } else {
            DllCall("user32\AppendMenuW", "Ptr", menuObj, "UInt", 0, "UPtr", 0x9FFF, "WStr", itemName)
        }
    }

    static AddThemeEditorToSystemMenu(hwnd, itemName := "Theme Editor...") {
        hSysMenu := DllCall("user32\GetSystemMenu", "Ptr", hwnd, "Int", 0, "Ptr")
        if hSysMenu {
            DllCall("user32\AppendMenuW", "Ptr", hSysMenu, "UInt", 0x0800, "UPtr", 0, "Ptr", 0) ; Separator
            DllCall("user32\AppendMenuW", "Ptr", hSysMenu, "UInt", 0, "UPtr", 0x9FFF, "WStr", itemName)
        }
    }

    static UpdateMenuCheckmarks(hwnd) {
        if !RT.RegisteredMenus.Has(hwnd)
            return
        hThemesSub := RT.RegisteredMenus[hwnd]
        themes := RT.GetThemesList()
        for idx, themeName in themes {
            isChecked := (themeName == RT.CurrentThemeName)
            DllCall("user32\CheckMenuItem", "Ptr", hThemesSub, "UInt", 0x9000 + idx, "UInt", isChecked ? 0x0008 : 0x0000)
        }
    }

    static UpdateAllMenus() {
        for hwnd, hSub in RT.RegisteredMenus {
            if DllCall("user32\IsWindow", "Ptr", hwnd) {
                RT.UpdateMenuCheckmarks(hwnd)
                DllCall("user32\DrawMenuBar", "Ptr", hwnd)
            }
        }
    }

    static ReRegisterAllMenus() {
        processId := DllCall("kernel32\GetCurrentProcessId", "UInt")
        _EnumProc(hwnd, lParam) {
            DllCall("user32\GetWindowThreadProcessId", "Ptr", hwnd, "Ptr*", &wndProcId := 0)
            if (wndProcId == processId) {
                try {
                    class := WinGetClass(hwnd)
                    if (class == "AutoHotkeyGUI")
                        RT.RegisterThemesMenu(hwnd)
                }
            }
            return 1
        }
        cb := CallbackCreate(_EnumProc, "F", 2)
        DllCall("user32\EnumWindows", "Ptr", cb, "Ptr", 0)
        CallbackFree(cb)
    }

    class ThemeEditor {
        static guiObj := 0
        static listThemes := 0
        static btnNew := 0
        static btnClone := 0
        static btnDelete := 0
        static btnSave := 0
        static colorCtrls := Map()
        static selectedTheme := ""
        static currentColors := Map()

        static Show() {
            if RT.ThemeEditor.guiObj {
                RT.ThemeEditor.guiObj.Show()
                return
            }
            g := Gui("+Owner", "Theme Editor")
            g.OnEvent("Close", (*) => RT.ThemeEditor.guiObj := 0)
            RT.ThemeEditor.guiObj := g

            g.Add("Text", "x10 y10 w100", "Select Theme:")
            RT.ThemeEditor.listThemes := g.Add("DropDownList", "x10 y30 w180 Choose1")
            RT.ThemeEditor.listThemes.OnEvent("Change", (ctrl, *) => RT.ThemeEditor.OnThemeChange())

            RT.ThemeEditor.btnNew := g.Add("Button", "x200 y28 w80 h24", "New")
            RT.ThemeEditor.btnNew.OnEvent("Click", (*) => RT.ThemeEditor.OnNewTheme())

            RT.ThemeEditor.btnClone := g.Add("Button", "x285 y28 w80 h24", "Clone")
            RT.ThemeEditor.btnClone.OnEvent("Click", (*) => RT.ThemeEditor.OnCloneTheme())

            RT.ThemeEditor.btnDelete := g.Add("Button", "x370 y28 w80 h24", "Delete")
            RT.ThemeEditor.btnDelete.OnEvent("Click", (*) => RT.ThemeEditor.OnDeleteTheme())

            y := 70
            colors := ["BaseBg", "Surface", "Text", "Accent", "Border", "Header", "FgDim"]
            for col in colors {
                g.Add("Text", "x10 y" . (y + 4) . " w70", col . ":")
                preview := g.Add("Text", "x90 y" . y . " w30 h22 +Border +0x100")
                preview.OnEvent("Click", RT.ThemeEditor.OnColorClick.Bind(col))
                edit := g.Add("Edit", "x130 y" . y . " w90 h22 +ReadOnly")
                btnChoose := g.Add("Button", "x230 y" . (y - 1) . " w100 h24", "Choose...")
                btnChoose.OnEvent("Click", RT.ThemeEditor.OnColorClick.Bind(col))
                RT.ThemeEditor.colorCtrls[col] := { preview: preview, edit: edit }
                y += 32
            }

            RT.ThemeEditor.btnSave := g.Add("Button", "x10 y" . y . " w120 h30", "Save to INI")
            RT.ThemeEditor.btnSave.OnEvent("Click", (*) => RT.ThemeEditor.OnSaveTheme())

            RT.ThemeEditor.PopulateThemes()
            RT.Apply(g.Hwnd)
            g.Show("w460 h" . (y + 45))
        }

        static PopulateThemes(selectName := "") {
            themes := RT.GetThemesList()
            RT.ThemeEditor.listThemes.Delete()
            RT.ThemeEditor.listThemes.Add(themes)
            if (selectName != "" && themes.Length > 0) {
                loop themes.Length {
                    if (themes[A_Index] == selectName) {
                        RT.ThemeEditor.listThemes.Value := A_Index
                        break
                    }
                }
            } else if (themes.Length > 0) {
                RT.ThemeEditor.listThemes.Value := 1
            }
            RT.ThemeEditor.OnThemeChange()
        }

        static OnThemeChange() {
            themeName := RT.ThemeEditor.listThemes.Text
            if (themeName == "")
                return
            RT.ThemeEditor.selectedTheme := themeName
            cfg := RT.LoadThemeFromIni(themeName)
            if !cfg
                return
            RT.ThemeEditor.currentColors := cfg.Clone()
            RT.CurrentThemeName := themeName
            RT.SetTheme(themeName)
            RT.ThemeEditor.UpdateColorDisplay()
        }

        static UpdateColorDisplay() {
            for col, ctrls in RT.ThemeEditor.colorCtrls {
                hexColor := RT.ThemeEditor.currentColors[col]
                ctrls.edit.Value := "#" . hexColor
                hwnd := ctrls.preview.Hwnd
                RT.CtlCache[hwnd] := Map("Bg", "#" . hexColor, "Border", "Border")
                DllCall("user32\InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1)
            }
        }

        static OnColorClick(colorName, *) {
            currentHex := RT.ThemeEditor.currentColors[colorName]
            currentBGR := RT.ParseColor(currentHex).BGR
            newBGR := RT.ThemeEditor.ChooseColorDialog(currentBGR, RT.ThemeEditor.guiObj.Hwnd)
            if (newBGR != -1) {
                r := newBGR & 0xFF
                g := (newBGR >> 8) & 0xFF
                b := (newBGR >> 16) & 0xFF
                hexRGB := Format("{:02X}{:02X}{:02X}", r, g, b)
                RT.ThemeEditor.currentColors[colorName] := hexRGB
                RT.ThemeEditor.UpdateColorDisplay()
                RT.ActivePalette := RT.Palette(RT.ThemeEditor.currentColors)
                RT.UpdateMenuTheme()
                RT.CtlCache := Map()
                RT.StatusBarTexts := Map()
                RT.Depths := Map()

                RT.ApplyThemeToAllWindows()
                RT.ThemeEditor.UpdateColorDisplay()
            }
        }

        static ChooseColorDialog(defaultColorBGR := 0, hwndParent := 0) {
            static customColors := Buffer(64, 0)
            cc := Buffer(A_PtrSize == 8 ? 72 : 36, 0)
            NumPut("UInt", cc.Size, cc, 0)
            NumPut("Ptr", hwndParent, cc, A_PtrSize)
            NumPut("Ptr", 0, cc, A_PtrSize * 2)
            NumPut("UInt", defaultColorBGR, cc, A_PtrSize * 3)
            NumPut("Ptr", customColors.Ptr, cc, A_PtrSize * 4)
            NumPut("UInt", 0x00000103, cc, A_PtrSize * 5)
            if DllCall("comdlg32\ChooseColorW", "Ptr", cc.Ptr)
                return NumGet(cc, A_PtrSize * 3, "UInt")
            return -1
        }

        static OnSaveTheme() {
            themeName := RT.ThemeEditor.selectedTheme
            if (themeName == "")
                return
            RT.SaveThemeToIni(themeName, RT.ThemeEditor.currentColors)
            MsgBox("Theme '" . themeName . "' saved successfully!", "Theme Saved", 0x40)
            RT.ReRegisterAllMenus()
        }

        static OnNewTheme() {
            name := InputBox("Enter a name for the new theme:", "New Theme")
            if (name.Result != "OK" || name.Value == "")
                return
            newCfg := Map("BaseBg", "121212", "Surface", "1E1E1E", "Text", "E0E0E0", "Accent", "0078D4", "Border", "333333", "Header", "1E1E1E", "FgDim", "888888")
            RT.SaveThemeToIni(name.Value, newCfg)
            RT.ThemeEditor.PopulateThemes(name.Value)
            RT.ReRegisterAllMenus()
        }

        static OnCloneTheme() {
            themeName := RT.ThemeEditor.selectedTheme
            if (themeName == "")
                return
            name := InputBox("Enter a name for the cloned theme:", "Clone Theme", , themeName . " Copy")
            if (name.Result != "OK" || name.Value == "")
                return
            RT.SaveThemeToIni(name.Value, RT.ThemeEditor.currentColors)
            RT.ThemeEditor.PopulateThemes(name.Value)
            RT.ReRegisterAllMenus()
        }

        static OnDeleteTheme() {
            themeName := RT.ThemeEditor.selectedTheme
            if (themeName == "" || themeName == "Default Dark" || themeName == "Default Light") {
                MsgBox("Cannot delete default themes.", "Error", 0x10)
                return
            }
            conf := MsgBox("Are you sure you want to delete '" . themeName . "'?", "Confirm Delete", 0x4)
            if (conf == "No")
                return
            RT.DeleteThemeFromIni(themeName)
            RT.ThemeEditor.PopulateThemes()
            RT.ReRegisterAllMenus()
        }
    }
}

class ReTheme extends RT {
}