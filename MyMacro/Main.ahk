#SingleInstance, force

global LoggerPath := A_ScriptDir . "\Logger.ahk"
global GuiPath := A_ScriptDir . "\Gui.ahk"

if (!FileExist(GuiPath)) {
  MsgBox, 4096, Error, Can't Find %GuiPath% !
  Exit
} else if (!FileExist(LoggerPath)) {
  MsgBox, 4096, Error, Can't Find %LoggerPath% !
  Exit
}

WinGet, GuiPID, PID, % GuiPath
WinGet, LoggerPID, PID, % LoggerPath

Process, Close, %GuiPID%
Process, Close, %LoggerPID%
Run, %LoggerPath%,,, loggerPID
Run, %GuiPath%,,, GuiPID