#Requires AutoHotkey v2.0
#Include <Colors>

class OSD {
    class Mode {
        static Mouse := 0
        static Main := 1
        static All := 2
    }
    Guis := Map()
    StopFadeOut := false
    CurrentHideGui := ""
    Mode := OSD.Mode.Mouse
    Width := 130
    Height := 130
    CornerRadius := 30
    Transparent := 150
    FgColor := Colors.White
    BgColor := Colors.Black
    DisplayTime := 750
    FadeDuration := 150

    __New(
        mode := OSD.Mode.Mouse,
        width := 130, height := 130, cornerRadius := 30,
        transparent := 150,
        fgColor := Colors.White, bgColor := Colors.Black,
        displayTime := 750, fadeDuration := 150) {
        this.Mode := mode
        this.Width := width
        this.Height := height
        this.CornerRadius := cornerRadius
        this.Transparent := transparent
        this.FgColor := fgColor
        this.BgColor := bgColor
        this.DisplayTime := displayTime
        this.FadeDuration := fadeDuration
    }

    Show(text, progress := -1, specificMonitor := 0) {

        if this.CurrentHideGui
            SetTimer this.CurrentHideGui, 0

        this.StopFadeOut := true
        this.CurrentHideGui := ObjBindMethod(this, "HideGui", this.FadeDuration, this.Transparent)

        Monitors := []
        if (this.Mode = OSD.Mode.All) {
            loop MonitorGetCount()
                Monitors.Push(A_Index)
        } else if (this.Mode = OSD.Mode.Main) {
            Monitors.Push(MonitorGetPrimary())
        } else { ; Mouse
            if specificMonitor {
                Monitors.Push(specificMonitor)
            } else {
                visibleFound := false
                for mon, guiObj in this.Guis {
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

        for mon, guiObj in this.Guis {
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
            if !this.Guis.Has(mon) {
                this.Guis[mon] := Map()
            }
        }

        for mon, guiObj in this.Guis {
            if !guiObj.Has("Gui") {
                g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +Owner -DPIScale")
                g.BackColor := this.FormatColor(this.BgColor)
                g.MarginX := 20
                g.MarginY := 10
                g.SetFont("s10 c" this.FormatColor(this.FgColor) " w700", "Segoe UI")
                t := g.Add("Text", "Center 0x200 w" this.Width, "")
                p := g.Add("Progress", "wp h10 c" this.FormatColor(this.FgColor) " Background" this.FormatColor(this.BgColor) " Hidden",
                0)
                guiObj["Gui"] := g
                guiObj["Text"] := t
                guiObj["Progress"] := p
                guiObj["LastW"] := 0
            }

            fontSize := Min(Round(this.Width * 0.45), Round(this.Width / (Max(StrLen(text), 1) * 0.85)))
            if (this.Height != -1) {
                textH := this.Height - 20
                if (progress != -1)
                    textH -= 20
                fontSize := Min(fontSize, Round(textH / 1.5))
            } else {
                textH := Round(fontSize * 1.5)
            }
            guiObj["Text"].SetFont("s" fontSize " c" this.FormatColor(this.FgColor))
            guiObj["Text"].Value := text
            guiObj["Text"].Opt("+0x200")
            guiObj["Text"].Move(, , this.Width, textH)

            if (progress != -1) {
                guiObj["Progress"].Value := progress
                guiObj["Progress"].Visible := true
                guiObj["Progress"].Move(, 10 + textH + 10, this.Width)
            } else {
                guiObj["Progress"].Visible := false
            }
            guiObj["Gui"].BackColor := this.FormatColor(this.BgColor)
            WinSetTransparent(this.Transparent, guiObj["Gui"])
        }

        for mon in Monitors {
            guiObj := this.Guis[mon]
            MonitorGet(mon, &mL, &mT, &mR, &mB)
            mW := mR - mL
            mH := mB - mT

            isVisible := DllCall("IsWindowVisible", "Ptr", guiObj["Gui"].Hwnd)
            if isVisible
                guiObj["Gui"].Show("NoActivate AutoSize")
            else
                guiObj["Gui"].Show("NoActivate AutoSize Hide")
            guiObj["Gui"].GetPos(&curX, &curY, &w, &h)

            if !guiObj.Has("LastW") || guiObj["LastW"] != w || guiObj["LastH"] != h || guiObj["LastR"] != this.CornerRadius {
                WinSetRegion "0-0 w" w " h" h " R" this.CornerRadius "-" this.CornerRadius, guiObj["Gui"]
                guiObj["LastW"] := w
                guiObj["LastH"] := h
                guiObj["LastR"] := this.CornerRadius
            }

            x := mL + (mW - w) / 2
            y := mT + (mH * (mH > mW ? 0.9 : 0.8))

            if !isVisible || x != curX || y != curY
                guiObj["Gui"].Show("NoActivate x" x " y" y)
        }

        SetTimer this.CurrentHideGui, -this.DisplayTime
    }

    HideGui(fadeDuration, transparent) {
        this.StopFadeOut := false
        if (fadeDuration > 0) {
            start := A_TickCount
            while (A_TickCount - start < fadeDuration) {
                if this.StopFadeOut {
                    for _, v in this.Guis
                        try WinSetTransparent(transparent, v["Gui"])
                    return
                }
                alpha := Max(0, transparent * (1 - ((A_TickCount - start) / fadeDuration)))
                for _, v in this.Guis
                    try WinSetTransparent(Integer(alpha), v["Gui"])
                Sleep 10
            }
        }
        if !this.StopFadeOut {
            for _, v in this.Guis
                v["Gui"].Hide()
        }
    }

    FormatColor(c) {
        if IsInteger(c)
            return Format("{:06X}", ((c & 0xFF) << 16) | (c & 0xFF00) | ((c >> 16) & 0xFF))
        return c
    }
}
