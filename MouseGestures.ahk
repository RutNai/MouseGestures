#SingleInstance Force
#Requires AutoHotkey v2.0
#Include <Colors>
#Include <OSD>
#Include <GestureButton>

MediaOSD := OSD()

MediaBtn := GestureButton('F14', MediaBtnCallback, MediaBtnContinueCallback, , , Colors.Olive, false)
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
            MediaOSD.Show(Chr(0x23EE))
        case 'R':
            Send '{Media_Next}'
            MediaOSD.Show(Chr(0x23ED))
        default:
            Send '{Media_Play_Pause}'
            MediaOSD.Show(Chr(0x23EF))
    }
}
MediaBtnContinueCallback(MouseGesture, amount, startMonitor := 0) {
    switch MouseGesture, false {
        case 'U':
            SoundSetVolume '+' . amount
            if SoundGetVolume() > 0
                SoundSetMute 0
            Vol := Round(SoundGetVolume())
            MediaOSD.Show(Vol, Vol, startMonitor)
            return true
        case 'D':
            SoundSetVolume '-' . amount
            if SoundGetVolume() <= 0
                SoundSetMute 1
            Vol := Round(SoundGetVolume())
            MediaOSD.Show(SoundGetMute() ? Chr(0x1F507) : Vol, Vol, startMonitor)
            return true
    }
    return false
}

; DesktopBtn
; Win+Tab - open Task View
; Win+CTRL+left/right - cycle through virtual desktops
DesktopBtn := GestureButton('F15', DesktopBtnCallback, , , , , false)
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