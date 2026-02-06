# MouseGestures

A powerful and modular Mouse Gesture library for AutoHotkey v2. This project allows you to trigger actions by moving your mouse in specific directions while holding a button, complete with visual trails and On-Screen Display (OSD) feedback.

## Features

*   **Gesture Recognition**: Supports directional gestures (Up, Down, Left, Right) and sequences.
*   **Visual Feedback**: Draws a colored trail on the screen as you perform gestures to visualize the movement.
*   **On-Screen Display (OSD)**: Displays text or progress bars (e.g., for volume control) on the active monitor.
*   **Context Sensitive**: Define different gestures for specific applications (e.g., Browsers, VS Code) using `WinTitle` matching.
*   **Continuous Actions**: Supports continuous triggering for actions like volume adjustment while holding the gesture position.
*   **Modular Design**: Separated into libraries (`GestureButton`, `OSD`, `Colors`) for easy integration.

## Requirements

*   AutoHotkey v2.0+

## Installation

1.  Download or clone this repository.
2.  Ensure `AutoHotkey v2` is installed.
3.  Run `MouseGestures.ahk` to start the script.

## Usage

The main configuration resides in `MouseGestures.ahk`. You can define gestures using the `GestureButton` class included in `Lib/`.

### Creating a Gesture

Instantiate the `GestureButton` class with the desired hotkey and callback function.

```ahk
#Include <GestureButton>

; Define a gesture on the Right Mouse Button
MyGesture := GestureButton('RButton', CallbackFunction)

CallbackFunction(gesture) {
    switch gesture {
        case 'U': MsgBox("Up Gesture")
        case 'D': MsgBox("Down Gesture")
        case 'L': MsgBox("Left Gesture")
        case 'R': MsgBox("Right Gesture")
        default:  Click("Right") ; Fallback to normal click if no gesture
    }
}
```

### Context-Sensitive Gestures

You can restrict gestures to specific windows by providing a WinTitle.

```ahk
; Only active in Chrome
ChromeGesture := GestureButton('RButton', ChromeCallback, , 'ahk_exe chrome.exe')
```

### Continuous Gestures (e.g., Volume Control)

Use the `gestureContinueCallBack` parameter to handle actions that repeat while the button is held.

```ahk
MediaBtn := GestureButton('F14', MediaCallback, MediaContinueCallback)

MediaContinueCallback(gesture, amount, startMonitor) {
    if (gesture == 'U') {
        SoundSetVolume '+' . amount
        return true ; Return true to indicate the continuous action was handled
    }
    return false
}
```

## Project Structure

*   `MouseGestures.ahk`: Main entry point containing example configurations for Media controls, Desktop navigation, and Browser tabs.
*   `Lib/GestureButton.ahk`: Core class handling mouse tracking, visual trails, and gesture logic.
*   `Lib/OSD.ahk`: Class for displaying the On-Screen Display overlays.
*   `Lib/Colors.ahk`: Helper class for color constants.