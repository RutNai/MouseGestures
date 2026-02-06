#Requires AutoHotkey v2.0
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
                    MsgBox(e.Message)
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