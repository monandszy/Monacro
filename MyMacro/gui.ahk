#SingleInstance, force
#NoEnv

SetBatchLines, -1
Thread, NoTimers
DetectHiddenWindows, On
SetTitleMatchMode, 2
DetectHiddenText, On
SetWorkingDir %A_ScriptDir%

;----------------------------------------------------
global GuiLogFile := A_ScriptDir . "/.Logs/GuiLog.log"
FileDelete %GuiLogFile%
Log(name, text) {
  FileAppend, %name%:[%text%]`n, %GuiLogFile%,
}
Log("DateTime", A_Now)
;----------------------------------------------------
; Static Options
;----------------------------------------------------
global EditorPath := "C:\Program Files\VSCodium\VSCodium.exe"  
global SettingsPath := A_ScriptDir . "/settings"
global UpdateLatestSelectOnRecord := True
global isTipEnabled := True
;----------------------------------------------------
; Dynamic Options
;----------------------------------------------------
global WorkDir
global NewRecordName
global RecordFolderPath
global PlaySpeed
global FileSaveMode
global NewRecordPath
global LatestSelectPath
global LatestSelectName
global isLogKeyboard 
global isLogMouse 
global isLogSleep 
global isLogWindow 
global isLogColor 
global isAggregateMode 
global isPreciseMode 
global isAppendSaveMode
global isOverrideSaveMode
global isNewSaveMode
LoadSettings()

LoadSettings() {
  Loop, Read, %SettingsPath%
  {
    option := StrSplit(A_LoopReadLine, ":",,2)
    label := option[1]
    ; Log("labelInit", label)
    %label% := option[2]
  }
}
UpdateSettings() {
NewSettings = 
(
WorkDir:%WorkDir%
NewRecordName:%NewRecordName%
RecordFolderPath:%RecordFolderPath%
PlaySpeed:%PlaySpeed%
NewRecordPath:%NewRecordPath%
LatestSelectPath:%LatestSelectPath%
LatestSelectName:%LatestSelectName%
MainGuiHwnd:%MainGuiHwnd%
isLogKeyboard:%isLogKeyboard%
isLogMouse:%isLogMouse%
isLogSleep:%isLogSleep%
isLogWindow:%isLogWindow%
isLogColor:%isLogColor%
isAggregateMode:%isAggregateMode%
isPreciseMode:%isPreciseMode%
isAppendSaveMode:%isAppendSaveMode%
isOverrideSaveMode:%isOverrideSaveMode%
isNewSaveMode:%isNewSaveMode%
)
  FileDelete, %SettingsPath%
  FileAppend, %NewSettings%, %SettingsPath%
}
;----------------------------------------------------
; Util Options
;----------------------------------------------------
global FileSaveModes := "New,Override,Append"
global TimingModes = "Precise,Aggregate" 
global LogOptions := "Color,Keyboard,Mouse,Sleep,Window"
global IsRecordingPlaying := False
global RecentTip := ""
global TipBackup := ""
global TipToggle := 0
global PlayTitle
global PlayingPID
global guiHwnds := []
global buttonHwnds := []
global lastWMHideTime := []
global buttonToggled := []
global buttonEnabled := []
global AHK := A_IsCompiled ? A_ScriptDir "\AutoHotkey.exe" : A_AhkPath
IfNotExist, %AHK%
{
  MsgBox, 4096, Error, Can't Find %AHK% !
  Exit
}
;----------------------------------------------------
global WM_ON_LOGGER := 0x0401
global WM_OFF_LOGGER := 0x0402
global WM_PAUSE_LOGGER := 0x0403
global WM_RESUME_LOGGER := 0x0404
global WM_TEST_LOGGER := 0x0405

global LoggerPath := A_ScriptDir . "\Logger.ahk"
WinGet, LoggerPID, PID, % LoggerPath
if (LoggerPID = "") {
  MsgBox, 4096, Error, LoggerPID is Null, Increase Sleep Timer
  Exit
}
; Log("LoggerPID", LoggerPID)
global LoggerHwnd := WinExist("ahk_pid" . LoggerPID)
if (LoggerHwnd + 0 = 0) {
  MsgBox, 4096, Error, LoggerHwnd is Null, Increase Sleep Timer
  Exit
}
; Log("LoggerHwnd", LoggerHwnd)
PostLoggerMessage(WM_TEST_LOGGER)

PostLoggerMessage(ID) {
  PostMessage, ID, 0,0,, % "ahk_id" . LoggerHwnd
  ; Log("PostLoggerMessage", ID " " ErrorLevel " " LoggerHwnd) 
}

;----------------------------------------------------
Gui, Main: +AlwaysOnTop +ToolWindow -Caption
Gui, Main: +HwndMain_gui_id
guiHwnds["Main"] := Main_gui_id
global MainGuiHwnd := Main_gui_id
; Log("Main", Main_gui_id + 0)
Gui, Main: Font, s11 
Gui, Main: Margin, 0, 0

global DynamicButtons := "Play,Edit,Exit"
global StaticButtons := "Record"
global SpecialButtons := "Pause" ; Work when not recording
MainButtons = 
(
[F1]Record
[F2]Pause
[F3]Play
[F4]Edit
[F5]Exit
)
For i,text in StrSplit(Mainbuttons, "`n")
{
  hotkey := SubStr(text, 2, InStr(text, "]") - 2)
  label := RegExReplace(text, ".*]")
  Hwnd:= label . "_id"
  Gui, Main: Add, Button, x+0 h22 v%label% default g%label% hwnd%Hwnd%, %A_Space%%text%%A_Space%
  buttonHwnds[label] := %Hwnd%
  buttonToggled[label] := False
  buttonEnabled[label] := True
  Hotkey, %hotkey%, %label%Hotkey
  Hotkey, ^%hotkey%, %label%OptionHotkey
}
Gui, Main: Show, NA y0, Macro Recorder
Gui, Main: Submit, NoHide

; Get the position of the main GUI window
; x left edge align ; y top align ; w width ; h height
global GuiX, GuiY, GuiWidth, GuiHeight
WinGetPos, GuiX, GuiY, GuiWidth, GuiHeight, Macro Recorder

DisableMainButton("Pause")
UpdateTip("Welcome!")

Return
;----------------------------------------------------

RecordHotkey:
PlayHotkey:
EditHotkey:
ExitHotkey:
PauseHotkey:
label := RegExReplace(A_ThisLabel, "Hotkey$")
state := buttonEnabled[label]
if (state) {
  Goto, %label%
}
Return

EnableMainButton(label) {
  GuiControl, Main: Enable , %label%
  buttonEnabled[label] := True
}

DisableMainButton(label) {
  GuiControl, Main: Disable, %label%
  buttonEnabled[label] := False
}

Record:
  if (buttonToggled["Record"]) { ; Revert to State 1
    if (buttonToggled["Pause"]) 
      Resume()
    PostLoggerMessage(WM_OFF_LOGGER)
    IsRecordingPlaying := False
    buttonToggled["Record"] := False
    GuiControl, Main: , Record, [F1]Record
    EnableMainButton("Play")
    EnableMainButton("Exit")
    DisableMainButton("Pause")
    UpdateTip("Saved " + NewRecordName)
  }
  else { ; Go to State 2
    SetNewRecordPath()
    UpdateSettings()
    PostLoggerMessage(WM_ON_LOGGER)
    IsRecordingPlaying := True
    buttonToggled["Record"] := True
    GuiControl, Main: , Record, [F1]Stop
    DisableMainButton("Play")
    DisableMainButton("Exit")
    EnableMainButton("Pause")
    UpdateTip("Recording to " + NewRecordName)
  }
Return

Pause:
  if (buttonToggled["Pause"]) { ; Revert to State 1
    Resume()
  } else { ; Go to State 2
    PostLoggerMessage(WM_PAUSE_LOGGER)
    IsRecordingPlaying := False
    TipBackup = %RecentTip%
    UpdateTip("Paused " + RecentTip)
    buttonToggled["Pause"] := True
    GuiControl, Main: , Pause, [F2]Resume
  }
Return

Resume() {
  PostLoggerMessage(WM_RESUME_LOGGER)
  UpdateSettings()
  IsRecordingPlaying := True
  UpdateTip(TipBackup)
  buttonToggled["Pause"] := False
  GuiControl, Main: , Pause, [F2]Pause
}

Play:
  if (buttonToggled["Play"]) { ; Revert to State 1
    if (buttonToggled["Pause"]) 
      Resume()
    PlayEnd()
    buttonToggled["Play"] := False
    GuiControl, Main: , Play, [F3]Play
    EnableMainButton("Record")
    EnableMainButton("Exit")
    DisableMainButton("Pause")
    UpdateTip("Stopped: " . PlayTitle)
  } 
  else { ; Go to State 2
    If (!FileExist(LatestSelectPath)) {
      UpdateTip("File " LatestSelectName " does not exist")
      Return
    }
    PlayStart()
    buttonToggled["Play"] := True
    GuiControl, Main: , Play, [F3]Stop
    DisableMainButton("Record")
    DisableMainButton("Exit")
    EnableMainButton("Pause")
    UpdateTip("Playing:" . PlayTitle)
  }
Return

PlayStart() {
global PlayTitle, PlayingPID
  PlayTitle := LatestSelectName
  Run, %AHK% /r %NewRecordPath%,,, OutputPID
  PlayingPID := OutputPID
  SetTimer, CheckPlay, 1000
}

PlayEnd() {
  SetTimer, CheckPlay, Off
  Process, Close, %PlayingPID%
}

CheckPlay:
global PlayingPID
  Exists := ProcessExist(PlayingPID)
  if (Exists)  {
    Return
  } else {
    Gosub, Play ; Toggle Stop
    UpdateTip("Finished: " . PlayTitle)
  }
Return

ProcessExist(PID) {
  Process, Exist, %PID%
  return ErrorLevel
}

Edit:
global LatestSelectPath, LatestSelectName
  if (FileExist(LatestSelectPath)) {
    val := """" EditorPath """ """ LatestSelectPath """"
    Run, *RunAs %val%
      UpdateTip("Editing " LatestSelectName)
  } else {
    UpdateTip("File " LatestSelectName " does not exist")
}
Return

Exit:
  UpdateSettings()
  Gui, Tip: Destroy
  Process, Close, %loggerPID%
  ExitApp

UpdateTip(text:="") {
  global TipToggle ; Cycles trough guis to prevent flickering from Destroying
  if(text = "" || !isTipEnabled)
    return
  Gui, Tip%TipToggle%: +AlwaysOnTop +ToolWindow -Caption
  Gui, Tip%TipToggle%: +HwndTip_gui_id
  guiHwnds["Tip" + TipToggle] := Tip_gui_id
  Gui, Tip%TipToggle%: Font, bold s11
  Gui, Tip%TipToggle%: Margin, 0, 0
  
  w := GuiX + GuiWidth + 100
  Gui, Tip%TipToggle%: Add, Button, h22 Disabled, %text%
  
  Gui, Tip%TipToggle%: Show, NA y0 X%w%, TipConsole
  Gui, Tip%TipToggle%: Submit, NoHide
  Sleep, 25 ; Delay To Render
  TipToggle:= !TipToggle
  Gui, Tip%TipToggle%: Destroy
  Return
}

;----------------------------------------------------
; Open OptionsX Gui via vlabel (right click support)
MainGuiContextMenu:
  label := A_GuiControl
  state := buttonEnabled[label]
  If (hasValue(SpecialButtons, label)) { 
    If (!IsRecordingPlaying) 
      OpenStaticOptionGui(label)
  } 
  else if (state) {
    if (hasValue(DynamicButtons, label)) 
      OpenDynamicOptionGui(label)
    else If (hasValue(StaticButtons, label))
      OpenStaticOptionGui(label)
  }
Return

; OptionsX chain (Ctrl hotkey support)
RecordOptionHotkey:
label := RegExReplace(A_ThisLabel, "OptionHotkey$")
state := buttonEnabled[label]
if (state) {
  OpenStaticOptionGui(label)
}
Return

PlayOptionHotkey:
EditOptionHotkey:
ExitOptionHotkey:
label := RegExReplace(A_ThisLabel, "OptionHotkey$")
state := buttonEnabled[label]
if (state) {
  OpenDynamicOptionGui(label)
}
Return

; Special treatment, Options function different than Button
PauseOptionHotkey:
label := RegExReplace(A_ThisLabel, "OptionHotkey$")
if (!IsRecordingPlaying) {
  OpenStaticOptionGui(label)
}
Return

OpenDynamicOptionGui(title) {
  
  DetectHiddenWindows, On
  Hwnd := guiHwnds[title]
  isHiddenbyWM := A_TickCount - lastWMHideTime[Hwnd] < 200 ; byWM (if not passed)
  ; Log("was", isHiddenbyWM)
  if (!isHiddenbyWM) {  ; If passed
    ; Log("Show", !wasHidden)
  } else if (lastWMHideTime[Hwnd]) {
    Gui, %title%: Destroy
    ; Log("DoNothing", A_TickCount)
    Return
  } 
  LoadOptionsGui(title)
}

OpenStaticOptionGui(title) {
  DetectHiddenWindows, On
  ; Check if Gui already created
  Hwnd := guiHwnds[title]
  isHiddenbyWM := A_TickCount - lastWMHideTime[Hwnd] < 200 ; byWM (if not passed)
  if (WinExist("ahk_id " . Hwnd) + 0) {
    DetectHiddenWindows, Off
    window:= title . "Options"
    if (!WinExist(window) && !isHiddenbyWM) { ; Show/Hide Toggle
      Gui, %title%: show,, %window%
    } else {
      Gui, %title%: hide
    }
    DetectHiddenWindows, On
    Return
  }
  LoadOptionsGui(title)
}

LoadOptionsGui(title) {
  Gui, %title%: +AlwaysOnTop +ToolWindow -Caption 
  Gui, %title%: +LastFound
  Gui, %title%: +Hwnd%title%_gui_id
  guiHwnds[title] := %title%_gui_id
  Gui, %title%: Font, s11
  Gui, %title%: Margin, 1, 1
  
  Load%title%Options()
  
  Hwnd := buttonHwnds[title]
  ControlGetPos, X, Y, w, h, , ahk_id %Hwnd%
  Y := h
  X := X + GuiX
  Gui, %title%: Show, w120 x%X% y%Y%, (title)

  OnMessage(0x0006, "WM_ACTIVATE")
}

; Event handler to close the GUI when it loses focus
WM_ACTIVATE(wParam, lParam, msg, Hwnd) {
  Hwnd:= Format("0x{:X}", Hwnd)
  if(Hwnd != guiHwnds["Main"]) {
    if (wParam = 0) {
      For i,v in StrSplit(DynamicButtons, ",")
      {
        If (Hwnd = guiHwnds[v]) {
          ; Log("Destroy", "")
          Gui, Destroy
          lastWMHideTime[Hwnd] := A_TickCount
          Return
        }
      }
      ; Log("Hide", "")
      Gui, Hide
      ; Timer For eliminating Show after Hide
      lastWMHideTime[Hwnd] := A_TickCount
    }
  }
}

LoadRecordOptions() {
  global RecordInputText
  Gui, Record: Add, Edit, x0 w120 h20 vRecordInputText ToolTip, NewRecordName
  Gui, Record: Add, Button, x1 w0 h0 Hidden gSubmitRecord Default, 
  global IsOverride, IsNew, IsAppend
  For i,mode in StrSplit(FileSaveModes, ",")
  {
    isMode:= is%mode%SaveMode ? "Checked" : ""
    Gui, Record: Add, Checkbox, %isMode% vIs%mode% g%mode%, %mode% 
  }
}

SubmitRecord:
global NewRecordName
  GuiControlGet, inputText, , RecordInputText
  NewRecordName = %inputText%
  UpdateTip("LatestNewRecordName: " . NewRecordName)
  Gui, Record: Hide
Return

Append:
New:
Override:
global FileSaveModes
  is%A_ThisLabel%SaveMode := True
  GuiControl, , Is%A_ThisLabel%, 1
  UpdateTip("SetSaveMode: " . A_ThisLabel . ":" . is%A_ThisLabel%SaveMode)
  For i,mode in StrSplit(FileSaveModes, ",")
  {
    If (mode != A_ThisLabel)  {
      is%mode%SaveMode := False
      GuiControl, , Is%mode%, 0
    }
  }
Return

LoadPauseOptions() {
  global IsAggregate, IsPrecise
  For i,mode in StrSplit(TimingModes, ",")
  {
    isMode:= is%mode%Mode ? "Checked" : ""
    Gui, Pause: Add, Checkbox, x1 %isMode% vIs%mode% g%mode%, %mode%Mode
  }
  
  global PauseInputText, DecreaseSpeed, IncreaseSpeed
  Gui, Pause: Add, Text, x0 w1, Spd:
  Gui, Pause: Add, Button, x+0 w20 h20 vDecreaseSpeed gDecreaseSpeed, -
  Gui, Pause: Add, Edit, x+0 w45 h20 vPauseInputText Tooltip, %PlaySpeed%
  Gui, Pause: Add, Button, x+0 w20 h20 vIncreaseSpeed gIncreaseSpeed, +
  Gui, Pause: Add, Button, x+0 w0 h0 Hidden gSubmitSpeed Default, 

  global isKeyboard, isMouse, isColor, isWindow, isSleep
  For i, name in StrSplit(LogOptions, ",") {
    isTrue:= isLog%name% ? "Checked" : ""
    Gui, Pause: Add, Checkbox, x1  %isTrue% vIs%name% gLog%name%, Log%name%
  }
}

Precise:
Aggregate:
global TimingModes
  is%A_ThisLabel%Mode := True
  GuiControl, , Is%A_ThisLabel%, 1
  UpdateTip("SetTimingMode: " . A_ThisLabel . ":" . is%A_ThisLabel%Mode)
  For i,mode in StrSplit(TimingModes, ",")
  {
    If (mode != A_ThisLabel)  {
      is%mode%Mode := False
      GuiControl, , Is%mode%, 0
    }
  }
Return

DecreaseSpeed:
global PlaySpeed
  if (PlaySpeed > 1) 
    PlaySpeed--
  else if (PlaySpeed > 0.2)
    PlaySpeed := PlaySpeed - 0.1
  trimmed := RTrim(PlaySpeed, 0)
  GuiControl,, PauseInputText, %trimmed%
  LogSpeedChange()
Return

IncreaseSpeed:
global PlaySpeed
  If (PlaySpeed < 1) 
    PlaySpeed:= PlaySpeed + 0.1
  else 
    PlaySpeed++
  trimmed := RTrim(PlaySpeed, 0)
  GuiControl,, PauseInputText, %trimmed%
  LogSpeedChange()
Return

SubmitSpeed:
global PlaySpeed
  GuiControlGet, inputText, , PauseInputText
  if (RegExMatch(inputText, "^\d+(\.\d+)?$") && inputText > 0) {
    PlaySpeed = %inputText%
    trimmed := RTrim(PlaySpeed, 0)
    GuiControl,, PlaySpeed, %A_Space%%trimmed%
    UpdateTip("SetPlaySpeed: " . PlaySpeed)
  } else {
    UpdateTip("InvalidPlaySpeed: " . inputText)
  }
  LogSpeedChange()
Return

LogSpeedChange() {
  If (!IsRecordingPlaying) {
    ; TODO Log new speed paramter (somehow alter selected file)
  }
}

LogKeyboard:
LogMouse:
LogColor:
LogWindow:
LogSleep:
global IsRecordingPlaying, LogOptions
  is%A_ThisLabel% := !is%A_ThisLabel%
  UpdateTip("Set" + A_ThisLabel ": " + is%A_ThisLabel%)
Return

LoadPlayOptions() {
  Loop, %RecordFolderPath%\*.ahk
  {
    SplitPath, A_LoopFilePath, FileName
    FileName := StrReplace(FileName, ".ahk", "")
    Gui, Play: Add, Button, h20 gPlayFile, %FileName%
  }
}

PlayFile:
global LatestSelectPath, LatestSelectName
  GuiControlGet, ButtonText, FocusV  ; Get the text of the clicked button
  LatestSelectPath := RecordFolderPath . ButtonText . ".ahk"
  LatestSelectName := ButtonText
  Gosub, Play
Return

LoadEditOptions() {
  Loop, %RecordFolderPath%\*.ahk
  {
    SplitPath, A_LoopFilePath, FileName
    FileName := StrReplace(FileName, ".ahk", "")
    Gui, Edit: Add, Button, h20 gEditFile, %FileName%
  }
}

; C:\Users\Name\..My\VSCode\AutoHotKey\MyMacro\Macros\Record_20240717225252.ahk
EditFile:
global RecordFolderPath, LatestEditPath
  GuiControlGet, ButtonText, FocusV  ; Get the text of the clicked button
  LatestSelectPath := RecordFolderPath . ButtonText . ".ahk"
  LatestSelectName := ButtonText
  Gosub, Edit
Return

LoadExitOptions() {
  global ExitInputText
  Gui, Exit: Add, Text, x0, %A_Space%WorkDir:%A_Space%
  Gui, Exit: Add, Text, x+0 w50 vWorkDir, %WorkDir%%A_Space%
  
  Gui, Exit: Add, Edit, x0 w120 h20 vExitInputText Tooltip, SetWorkDir
  Gui, Exit: Add, Button, x+0 w0 h0 Hidden gSetWorkDir Default, 
  Loop, Files, %A_ScriptDir%\*.*, D
  {
    dirName := A_LoopFileName
    If (SubStr(dirName, 1, 1) != ".")
      Gui, Exit: Add, Button, x0 h20 gChangeWorkDir, %dirName%
  }
}

SetWorkDir:
global WorkDir
  GuiControlGet, inputText, , ExitInputText
  WorkDir := inputText
  RecordFolderPath := A_ScriptDir . "\" . WorkDir "\"
  Gui, Play: Destroy
  Gui, Edit: Destroy
  UpdateTip("SetRecordFolder: " . WorkDir)
Return

ChangeWorkDir:
global WorkDir	
  GuiControlGet, ButtonText, FocusV  ; Get the text of the clicked button
  WorkDir := ButtonText
  GuiControl,, WorkDir, %WorkDir%
Return

F10::
Hide:
hidebuttons:=!hidebuttons
if hidebuttons {
  Gui Main:Hide
	Gui Tip:Hide
} else {
  Gui Main:Show
	Gui Tip:Show
}
Return

SetNewRecordPath() {
  global NewRecordName, RecordFolderPath, NewRecordPath
  if (NewRecordName = "Null" || NewRecordName = "") {
    NewRecordName := "Record_" . A_Now
  }
  else if (!isOverrideSaveMode && RegExMatch(NewRecordName, "Record_\d{12}")) {
    NewRecordName := "Record_" . A_Now
  }
  else if (isNewSaveMode && !RegExMatch(NewRecordName, "Record_\d{12}")) {
    highest:= 0
    Loop, %RecordFolderPath%\*.ahk
    {
      SplitPath, A_LoopFilePath, FileName
      if (InStr(FileName, NewRecordName "_")) {
        number := StrSplit(FileName, NewRecordName "_")[2]
        number := StrReplace(number, ".ahk", "")
        if (number > highest) 
          highest := number
      }
    }
    highest++
    NewRecordName := NewRecordName "_" highest
  }
  
  if (isOverrideSaveMode && FileExist(NewRecordPath)) {
    FileDelete %NewRecordPath% 
  }

  NewRecordPath := A_ScriptDir . "\" . WorkDir "\" . NewRecordName . ".ahk"

  if (UpdateLatestSelectOnRecord) {
    LatestSelectPath := NewRecordPath
    LatestSelectName := NewRecordName
  }
}

hasValue(list, item, del:=",") {
  if (item = "")
    Return False
	haystack:=del
	if !IsObject(list)
		haystack.= list del
	else
		for k,v in list
			haystack.= v del	
	Return !!InStr(del haystack del, del item del)
}

ExitHandler: 
  if (buttonToggled["Record"]) ; Revert to State 1
    PostLoggerMessage(WM_OFF_LOGGER)
  UpdateSettings()  
  PID := DllCall("GetCurrentProcessId")
  RunWait, taskkill /pid %PID%,, hide