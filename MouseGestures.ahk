#SingleInstance Force
#Requires AutoHotkey v2.0

MediaBtn := GestureButton('F14', MediaBtnCallback, MediaBtnContinueCallback, , , Colors.Olive)
MediaBtn.MinChangeUp := 5
MediaBtn.MinChangeDown := 5
MediaBtnCallback(MouseGesture) {
    switch MouseGesture, false {
        case 'U':
            return
        case 'D':
            return
        case 'L':
            Send '{Media_Prev}'
        case 'R':
            Send '{Media_Next}'
        default:
            Send '{Media_Play_Pause}'
    }
}
MediaBtnContinueCallback(MouseGesture, amount, startMonitor := 0) {
    switch MouseGesture, false {
        case 'U':
            SoundSetVolume '+' . amount
            if SoundGetVolume() > 0
                SoundSetMute 0
            Vol := Round(SoundGetVolume())
            ShowOSD(Vol, OSDMode.Mouse, startMonitor, Vol)
            return true
        case 'D':
            SoundSetVolume '-' . amount
            if SoundGetVolume() <= 0
                SoundSetMute 1
            Vol := Round(SoundGetVolume())
            ShowOSD(SoundGetMute() ? Chr(0x1F507) : Vol, OSDMode.Mouse, startMonitor, Vol)
            return true
    }
    return false
}

; DesktopBtn
; Win+Tab - open Task View
; Win+CTRL+left/right - cycle through virtual desktops
DesktopBtn := GestureButton('F15', DesktopBtnCallback)
DesktopBtnCallback(MouseGesture) {
    switch MouseGesture, false {
        case 'U':
            Send '{LWin}'
        case 'D':
            Send '#{d}'
        case 'L':
            Send '#^{Left}'
        case 'R':
            Send '#^{Right}'
        default:
            send '#{Tab}'
    }
}

GroupAdd 'browser', 'ahk_exe chrome.exe'
GroupAdd 'browser', 'ahk_exe firefox.exe'
BrowserTab := GestureButton('RButton', BrowserTabCallBack, , 'ahk_group browser', , Colors.Brown)
BrowserTabCallBack(MouseGesture) {
    switch MouseGesture, false {
        case 'U':
            Send '{F5}'
        case 'D':
            Send '^{w}'
        case 'L':
            Send '+^{Tab}'
        case 'R':
            Send '^{Tab}'
        default:
            Click("Right")
    }
}

VsCodeTab := GestureButton('RButton', VsCodeTabCallBack, , 'ahk_exe Code.exe', , Colors.Teal)
VsCodeTabCallBack(MouseGesture) {
    switch MouseGesture, false {
        case 'U':
            Send '^{s}'
        case 'D':
            Send '^{w}'
        case 'L':
            Send '^{PgUp}'
        case 'R':
            Send '^{PgDn}'
        default:
            Click("Right")
    }
}

; ------------------ Classes and Functions ------------------

class GestureButton {
    Button := unset
    GestureCallBack := unset
    ContinueGestureResistance := 512 + 128
    GestureContinueCallBack := ""
    IsGestureContinueTrigger := false
    MaxTrack := 1
    MinChangeUp := 15
    MinChangeDown := 15
    MinChangeLeft := 15
    MinChangeRight := 15

    ; Instance state for tracking
    LastX := 0
    LastY := 0
    CurrentGesture := ""
    WinActiveTitle := ""
    TrailGui := ""
    hDC := 0
    hPen := 0
    VirtualX := 0
    VirtualY := 0
    TrailColor := 0xFFFF00
    StartMonitor := 0

    __New(button, gestureCallBack, gestureContinueCallBack := unset, winActiveTitle := '', maxTrack := 1, trailColor :=
        0x00FFFF) {
        this.Button := button
        this.WinActiveTitle := winActiveTitle
        HotIfWinActive this.WinActiveTitle
        Hotkey this.Button, this.BtnDown.Bind(this)
        HotIfWinActive ; Reset context to prevent leak
        this.GestureCallBack := gestureCallBack
        if IsSet(gestureContinueCallBack) && gestureContinueCallBack {
            this.GestureContinueCallBack := gestureContinueCallBack
        }
        this.MaxTrack := maxTrack
        this.TrailColor := trailColor
    }
    __Delete() {
        try {
            HotIfWinActive this.WinActiveTitle
            Hotkey this.Button, 'Off'
            HotIfWinActive
        }
    }

    BtnDown(*) {
        CoordMode "Mouse", "Screen"
        MouseGetPos(&startX, &startY)
        this.StartMonitor := this.GetMonitorIndexFromPoint(startX, startY)
        this.EnableTrail()
        this.StartTracking()
        this.IsGestureContinueTrigger := false
        continueGestureAmount := 1
        MouseGesture := ""

        while GetKeyState(this.Button, "P") {
            if this.IsGestureContinueTrigger {
                ; Boost minChange if ContinueTrigger
                result := this.UpdateGesture(this.MinChangeUp, this.MinChangeDown, this.MinChangeLeft, this.MinChangeRight
                )
                MouseGesture := result[1]
                gestureSpeed := result[2]
                isNewStep := result[3]
                continueGestureAmount := isNewStep ? Ceil(gestureSpeed ** 2 / this.ContinueGestureResistance) : 0
            } else {
                result := this.UpdateGesture(this.MinChangeUp, this.MinChangeDown, this.MinChangeLeft, this.MinChangeRight
                )
                MouseGesture := result[1]
                gestureSpeed := result[2]
                continueGestureAmount := Ceil(gestureSpeed ** 2 / this.ContinueGestureResistance)
                if (continueGestureAmount < 1)
                    continueGestureAmount := 1
            }

            if MouseGesture {
                ToolTip MouseGesture
                try {
                    if this.GestureContinueCallBack && continueGestureAmount > 0 {
                        if this.GestureContinueCallBack.IsVariadic || this.GestureContinueCallBack.MaxParams >= 3
                            this.IsGestureContinueTrigger |= this.GestureContinueCallBack.Call(MouseGesture,
                                continueGestureAmount, this.StartMonitor)
                        else
                            this.IsGestureContinueTrigger |= this.GestureContinueCallBack.Call(MouseGesture,
                                continueGestureAmount)
                    }
                }
                catch as e  ; Handles the first error thrown by the block above.
                {
                    ; MsgBox(e.Message)
                }
            }
            Sleep 50
        }

        ; Out of loop when button up
        try {
            if !this.IsGestureContinueTrigger {
                this.GestureCallBack.Call(MouseGesture)
            }
        }
        catch as e  ; Handles the first error thrown by the block above.
        {
            ; MsgBox(e.Message)
            ; Send this.Button
        }
        this.DisableTrail()
        ToolTip
    }

    StartTracking(resetVisual := true) {
        MouseGetPos &x, &y
        this.LastX := x
        this.LastY := y
        this.CurrentGesture := ""
        if this.hDC && resetVisual
            DllCall("MoveToEx", "Ptr", this.hDC, "Int", x - this.VirtualX, "Int", y - this.VirtualY, "Ptr", 0) ; Move drawing cursor to new position without drawing
    }

    UpdateGesture(minUp := 1, minDown := 1, minLeft := 1, minRight := 1) {
        MouseGetPos &currX, &currY
        if this.hDC
            DllCall("LineTo", "Ptr", this.hDC, "Int", currX - this.VirtualX, "Int", currY - this.VirtualY) ; Draw line from previous position to current
        dx := currX - this.LastX
        dy := this.LastY - currY

        track := ""
        if (Abs(dy) >= Abs(dx)) {
            if (dy > minUp)
                track := "U"
            else if (dy < -minDown)
                track := "D"
        } else {
            if (dx > minRight)
                track := "R"
            else if (dx < -minLeft)
                track := "L"
        }

        speed := Max(Abs(dx), Abs(dy))
        isNewStep := false

        if (track != "") {
            this.LastX := currX
            this.LastY := currY
            isNewStep := true
            if (track != SubStr(this.CurrentGesture, -1))
                this.CurrentGesture .= track
        }

        return [SubStr(this.CurrentGesture, -this.MaxTrack), speed, isNewStep]
    }

    EnableTrail() {
        try {
            this.VirtualX := SysGet(76) ; SM_XVIRTUALSCREEN: Left coordinate of the virtual screen
            this.VirtualY := SysGet(77) ; SM_YVIRTUALSCREEN: Top coordinate of the virtual screen
            this.TrailGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +LastFound")
            this.TrailGui.BackColor := "000001"
            WinSetTransColor "000001", this.TrailGui
            this.TrailGui.Show("NA x" this.VirtualX " y" this.VirtualY " w" SysGet(78) " h" SysGet(79)) ; SM_CXVIRTUALSCREEN (Width), SM_CYVIRTUALSCREEN (Height)

            this.hDC := DllCall("GetDC", "Ptr", this.TrailGui.Hwnd, "Ptr") ; Get Device Context for drawing
            this.hPen := DllCall("CreatePen", "Int", 0, "Int", 3, "Int", this.TrailColor, "Ptr") ; Create Pen: Style=Solid(0), Width=3, Color=BGR
            DllCall("SelectObject", "Ptr", this.hDC, "Ptr", this.hPen) ; Select pen into DC
        }
    }

    DisableTrail() {
        try {
            if this.hDC {
                DllCall("ReleaseDC", "Ptr", this.TrailGui.Hwnd, "Ptr", this.hDC) ; Release Device Context to prevent memory leak
                this.hDC := 0
            }
            if this.hPen {
                DllCall("DeleteObject", "Ptr", this.hPen) ; Delete Pen object to free resources
                this.hPen := 0
            }
            if this.TrailGui {
                this.TrailGui.Destroy()
                this.TrailGui := ""
            }
        }
    }

    GetMonitorIndexFromPoint(x, y) {
        loop MonitorGetCount() {
            MonitorGet(A_Index, &mL, &mT, &mR, &mB)
            if (x >= mL && x < mR && y >= mT && y < mB)
                return A_Index
        }
        return MonitorGetPrimary()
    }
}

class Colors {
    static Red := 0x0000FF
    static Green := 0x00FF00
    static Blue := 0xFF0000
    static Cyan := 0xFFFF00
    static Magenta := 0xFF00FF
    static Yellow := 0x00FFFF
    static Black := 0x000000
    static White := 0xFFFFFF
    static Orange := 0x00A5FF
    static Purple := 0x800080
    static Pink := 0xCBC0FF
    static Gray := 0x808080
    static Teal := 0x808000
    static Gold := 0x00D7FF
    static Silver := 0xC0C0C0
    static Navy := 0x800000
    static Maroon := 0x000080
    static Olive := 0x008080
    static Brown := 0x2A2AA5
    static Coral := 0x507FFF
    static Indigo := 0x82004B
    static Violet := 0xE22B8A
    static Turquoise := 0xD0E040
}

class OSDMode {
    static Mouse := 0
    static Main := 1
    static All := 2
}

ShowOSD(
    text,
    mode := OSDMode.Mouse, specificMonitor := 0,
    progress := -1,
    width := 130, height := 130, cornerRadius := 30,
    transparent := 150,
    fgColor := Colors.White, bgColor := Colors.Black,
    displayTime := 750, fadeDuration := 150) {
    static Guis := Map()
    static StopFadeOut := false
    static CurrentHideGui := unset

    if IsSet(CurrentHideGui)
        SetTimer CurrentHideGui, 0

    StopFadeOut := true

    HideGui() {
        StopFadeOut := false
        if (fadeDuration > 0) {
            start := A_TickCount
            while (A_TickCount - start < fadeDuration) {
                if StopFadeOut {
                    for _, v in Guis
                        try WinSetTransparent(transparent, v["Gui"])
                    return
                }
                alpha := Max(0, transparent * (1 - ((A_TickCount - start) / fadeDuration)))
                for _, v in Guis
                    try WinSetTransparent(Integer(alpha), v["Gui"])
                Sleep 10
            }
        }
        if !StopFadeOut {
            for _, v in Guis
                v["Gui"].Hide()
        }
    }

    CurrentHideGui := HideGui

    FormatColor(c) {
        if IsInteger(c)
            return Format("{:06X}", ((c & 0xFF) << 16) | (c & 0xFF00) | ((c >> 16) & 0xFF))
        return c
    }

    Monitors := []
    if (mode = OSDMode.All) {
        loop MonitorGetCount()
            Monitors.Push(A_Index)
    } else if (mode = OSDMode.Main) {
        Monitors.Push(MonitorGetPrimary())
    } else { ; Mouse
        if specificMonitor {
            Monitors.Push(specificMonitor)
        } else {
            visibleFound := false
            for mon, guiObj in Guis {
                if DllCall("IsWindowVisible", "Ptr", guiObj["Gui"].Hwnd) {
                    Monitors.Push(mon)
                    visibleFound := true
                }
            }

            if !visibleFound {
                MouseGetPos(&mx, &my)
                loop MonitorGetCount() {
                    MonitorGet(A_Index, &mL, &mT, &mR, &mB)
                    if (mx >= mL && mx < mR && my >= mT && my < mB) {
                        Monitors.Push(A_Index)
                        break
                    }
                }
                if !Monitors.Length
                    Monitors.Push(MonitorGetPrimary())
            }
        }
    }

    for mon, guiObj in Guis {
        shouldHide := true
        for m in Monitors {
            if (m == mon) {
                shouldHide := false
                break
            }
        }
        if shouldHide
            guiObj["Gui"].Hide()
    }

    for mon in Monitors {
        if !Guis.Has(mon) {
            Guis[mon] := Map()
        }
    }

    for mon, guiObj in Guis {
        if !guiObj.Has("Gui") {
            g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +Owner -DPIScale")
            g.BackColor := FormatColor(bgColor)
            g.MarginX := 20
            g.MarginY := 10
            g.SetFont("s10 c" FormatColor(fgColor) " w700", "Segoe UI")
            t := g.Add("Text", "Center 0x200 w" width, "")
            p := g.Add("Progress", "wp h10 c" FormatColor(fgColor) " Background" FormatColor(bgColor) " Hidden", 0)
            guiObj["Gui"] := g
            guiObj["Text"] := t
            guiObj["Progress"] := p
            guiObj["LastW"] := 0
        }

        fontSize := Min(Round(width * 0.45), Round(width / (Max(StrLen(text), 1) * 0.85)))
        if (height != -1) {
            textH := height - 20
            if (progress != -1)
                textH -= 20
            fontSize := Min(fontSize, Round(textH / 1.5))
        } else {
            textH := Round(fontSize * 1.5)
        }
        guiObj["Text"].SetFont("s" fontSize " c" FormatColor(fgColor))
        guiObj["Text"].Value := text
        guiObj["Text"].Opt("+0x200")
        guiObj["Text"].Move(, , width, textH)

        if (progress != -1) {
            guiObj["Progress"].Value := progress
            guiObj["Progress"].Visible := true
            guiObj["Progress"].Move(, 10 + textH + 10, width)
        } else {
            guiObj["Progress"].Visible := false
        }
        guiObj["Gui"].BackColor := FormatColor(bgColor)
        WinSetTransparent(transparent, guiObj["Gui"])
    }

    for mon in Monitors {
        guiObj := Guis[mon]
        MonitorGet(mon, &mL, &mT, &mR, &mB)
        mW := mR - mL
        mH := mB - mT

        isVisible := DllCall("IsWindowVisible", "Ptr", guiObj["Gui"].Hwnd)
        if isVisible
            guiObj["Gui"].Show("NoActivate AutoSize")
        else
            guiObj["Gui"].Show("NoActivate AutoSize Hide")
        guiObj["Gui"].GetPos(&curX, &curY, &w, &h)

        if !guiObj.Has("LastW") || guiObj["LastW"] != w || guiObj["LastH"] != h || guiObj["LastR"] != cornerRadius {
            WinSetRegion "0-0 w" w " h" h " R" cornerRadius "-" cornerRadius, guiObj["Gui"]
            guiObj["LastW"] := w
            guiObj["LastH"] := h
            guiObj["LastR"] := cornerRadius
        }

        x := mL + (mW - w) / 2
        y := mT + (mH * (mH > mW ? 0.9 : 0.8))

        if !isVisible || x != curX || y != curY
            guiObj["Gui"].Show("NoActivate x" x " y" y)
    }

    SetTimer CurrentHideGui, -displayTime
}
