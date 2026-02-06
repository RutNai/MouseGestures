#SingleInstance Force
#Requires AutoHotkey v2.0

class GestureButton {
    Button := unset
    ; IsBtnDown := false
    GestureCallBack := unset
    ContinueGestureResistance := 256.0
    GestureContinueCallBack := unset
    IsGestureContinueTrigger := false
    MaxTrack := unset
    MinChangeUp := 10
    MinChangeDown := 10
    MinChangeLeft := 10
    MinChangeRight := 10
    MinChange => [this.MinChangeUp, this.MinChangeDown, this.MinChangeLeft, this.MinChangeRight]

    __New(button, gestureCallBack, gestureContinueCallBack := unset, winActiveTitle := '', maxTrack := 1) {
        this.Button := button
        HotIfWinActive winActiveTitle
        Hotkey this.Button, this.BtnDown.Bind(this)
        ; Hotkey this.Button . ' Up' , this.BtnUp.Bind(this)
        this.GestureCallBack := gestureCallBack
        if IsSet(gestureContinueCallBack) {
            this.GestureContinueCallBack := gestureContinueCallBack ? gestureContinueCallBack : unset
        }
        this.MaxTrack := maxTrack
    }
    __Delete() {
        Hotkey this.Button, 'Off'
        ; Hotkey this.Button . ' Up', 'Off'
    }

    BtnDown(*) {
        ; this.IsBtnDown := true
        GestureButton.GetMouseGesture(True)
        this.IsGestureContinueTrigger := false
        continueGestureAmount := 1

        ; while (this.IsBtnDown) {
        while GetKeyState(this.Button, "P") {
            if this.IsGestureContinueTrigger {
                ; Boost minChange if ContinueTrigger
                result := GestureButton.GetMouseGesture(false, this.MaxTrack, [1,1,1,1])
                MouseGesture := result[1]
                gestureSpeed := result[2]
                continueGestureAmount := Ceil(gestureSpeed**2/this.ContinueGestureResistance)
            } else {
                MouseGesture := GestureButton.GetMouseGesture(false, this.MaxTrack, this.MinChange)[1]
            }

            if MouseGesture {
                ToolTip MouseGesture
                try {
                    this.IsGestureContinueTrigger |= this.GestureContinueCallBack.Call(MouseGesture, continueGestureAmount)
                    if this.IsGestureContinueTrigger {
                        GestureButton.GetMouseGesture(True)
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
        ToolTip
    }
    ; BtnUp(*) {
    ;     this.IsBtnDown := false
    ; }
/**
 * @description {`GetMouseGesture()`} 
 * @param {(Boolean)} [reset]  
 * Set to true to reset gesture.
 * @param {(int)} [maxTrack]  
 * Max gesture output allow.
 * @param {(array)} [minChange]  
 * Array of minimum pixel change in each direction U D L R
 * @returns {(array)}  
 * return array of Direction string and number speed.
 * @example <caption></caption>  
 */
    static GetMouseGesture(reset := false, maxTrack := 1, minChange := [10,10,10,10]) {
        static
        mousegetpos(&xpos2, &ypos2)
        static xpos1 := xpos2
        static ypos1 := ypos2
        dx := xpos2 - xpos1
        dy := ypos1 - ypos2
        (abs(dy) >= abs(dx) ? (dy > 0 ? (track := 'U') : (track := 'D')) : (dx > 0 ? (track := 'R') : (track := 'L')))	;track is up or down, left or right
        if not(dy > minChange[1] or dy < -minChange[2] or dx < -minChange[3] or dx > minChange[4]){
            track := ''    ;not tracking at all if no significant change in x or y
        }
        speed := Max(abs(dx), abs(dy))
        xpos1 := xpos2
        ypos1 := ypos2
        static gesture := ''

        if (track != SubStr(gesture, -1))
            gesture := gesture . track   ;ignore track if not changing since previous track
        gesture := reset ? '' : gesture
        return [SubStr(gesture, -maxTrack), speed]
    }
}

MediaBtn := GestureButton('F14', MediaBtnCallback, MediaBtnContinueCallback)
MediaBtn.MinChangeUp := 5
MediaBtn.MinChangeDown := 5
MediaBtnCallback(MouseGesture) {
    switch MouseGesture, false {
        case 'U':
        case 'D':
        case 'L':
            Send '{Media_Prev}'
        case 'R':
            Send '{Media_Next}'
        default:
            Send '{Media_Play_Pause}'
    }
}
MediaBtnContinueCallback(MouseGesture, amount) {
    switch MouseGesture, false {
        case 'U':
            ; Send '{Volume_Up ' . amount . '}' ; send repeatedly is slow
            ; SoundSetVolume '+' . amount ; this not popup media ui but faster
            if amount > 1{
                SoundSetVolume '+' . amount-1
            }
            Send '{Volume_Up}' ; end with this to popup media volume ui
            return true
        case 'D':
            ; Send '{Volume_Down ' . amount . '}'
            ; SoundSetVolume '-' . amount
            if amount > 1{
                SoundSetVolume '-' . amount-1 
            }
            Send '{Volume_Down}' 
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
BrowserTab := GestureButton('RButton', BrowserTabCallBack, , 'ahk_group browser')
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

VsCodeTab := GestureButton('RButton', VsCodeTabCallBack, , 'ahk_exe Code.exe')
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
