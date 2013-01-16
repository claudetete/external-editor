;;; ExternalEditor.ahk --- an interface between an application and an editor

;; Copyright (c) 2013 Claude Tete
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;

;; Author: Claude Tete  <claude.tete@gmail.com>
;; Version: 0.2
;; Created: January 2013
;; Last-Updated: January 2013

;;; Commentary:
;; idea is from external-editor found here http://shreevatsa.wordpress.com/2006/12/29/editing-textareas-in-an-external-editor/

;;; Change Log:
;; 2013-01-16 (0.2)
;;     add file to manage multiple application not hard coded + gui
;; 2013-01-14 (0.1)
;;     Initial Release, try with opera and emacs

;;; Code:
;
;;
;;; ENVIRONMENT
;; Recommended for performance and compatibility with future AutoHotkey.
#NoEnv
;; Recommended for catching common errors.
#Warn
;; Recommended for new scripts due to its superior speed and reliability.
SendMode Input
;; Ensures a consistent starting directory.
SetWorkingDir %A_ScriptDir%
;; only on instance of this script
#SingleInstance force
;; application name use in msgbox, etc
ApplicationName = ExternalEditor
;; get temp folder
EnvGet, TempFolderShort, TEMP
;; get long path of temp folder
Loop %TempFolderShort%, 1
  TempFolder = %A_LoopFileLongPath%

;
;;
;;; PARAMETERS
if 0 > 0
{
  ;; get first parameter
  IniFilePath = %1%
  ;; when file exist
  IfExist, IniFilePath
  {
    ;; get long path instead of short path
    Loop %IniFilePath%, 1
      IniFile = %A_LoopFileLongPath%
  }
  else
  {
    ;; file do not exist
    IniFile = %IniFilePath%
  }
}
else
{
  ;; no parameter
  IniFile = %ApplicationName%.ini
}

;
;;
;;; SETTING
;; load ini file
GoSub, LoadIniFile
;;
;; version number
SoftwareVersion = 0.1
;;
;; load ee file for all application settings
GoSub, LoadEEFile
;; set shortcut for all applications
GoSub, SetShortcut

;
;;
;;; ICON
;; get icon file into the exe
FileInstall, ExternalEditor.ico, ExternalEditor.ico, 1
;; display icon in tray zone
Menu, TRAY, Icon, ExternalEditor.ico

;
;;
;;; MENU
;; Delete the current menu
Menu, tray, NoStandard
;; Add the item About in the menu
Menu, tray, add, About, MenuAbout
;; Add the item Help in the menu
Menu, tray, add, Help, MenuHelp
;; Creates a separator line.
Menu, tray, add
;; Add the item Options in the menu
Menu, tray, add, Options, MenuOptions
;; Add the item Remove in the menu
Menu, tray, add, Remove all tmp file, MenuRemoveAllTmpFile
;; Add the item Reload in the menu
Menu, tray, add, Reload .ini and ee file, MenuReload
;; Add the item Edit ini in the menu
Menu, tray, add, Edit .ini file, MenuEditIni
;; Add the item Create/Save ini in the menu
Menu, tray, add, Create/Save .ini file, MenuCreateSaveIni
;; Creates a separator line.
Menu, tray, add
;; add the standard menu
Menu, tray, Standard


;; End of script
Return

;
;;
;;; PROCESSING
ExternalEditIndex:
  for Index, Element in ArrayExe
  {
    If WinActive("ahk_exe" . Element . ".exe")
    {
      ExternalEdit(Index)
      Break
    }
  }
Return

;;
;;; Select all, copy to a temporary file, open this file in favorite editor
;;; when file saved, go to application, select all, paste from saved file, go to the start
ExternalEdit(Index)
{
  global ArrayExe, ArraySelectAll, ArrayCopy, ArrayPaste, ArrayGoHome
  global EditorCommand, TempFolder

  ;; save clipboard
  ClipSaved := ClipboardAll

  ;; empty the clipboard
  Clipboard =
  ;; get the uniq id of application window
  WindowHWND := WinActive("ahk_exe " . ArrayExe[Index] . ".exe")

  ;; select all
  SendInput, % ArraySelectAll[Index]
  ;; copy in clipboard
  SendInput, % ArrayCopy[Index]
  ;; wait the end of copy
  ClipWait

  ;; current date
  FormatTime, CurrentDate, , yyyy-MM-dd_HH-mm-ss
  ;;
  ;; set path and filename of temporary file
  FileName = % TempFolder . "\" . ArrayExe[Index] . "_" . CurrentDate . ".ee"
  ;;
  ;; put all clipboard in file
  FileAppend, %clipboard%, %FileName%
  ;; get the file time of modification of file (for reference)
  FileGetTime, CurrentDate, %FileName%, M

  ;; launch the favorite editor to open the temporary file
  Run %EditorCommand%  "%FileName%"

  ;; init loop
  FileTime = %CurrentDate%
  ;; while the modification time reference is the same as the current
  ;; modification time
  While (FileTime = CurrentDate)
  {
    ;; get modification time of temporary file
    FileGetTime, FileTime, %FileName%, M
    ;; wait 100ms (pooling)
    Sleep, 100
  }

  ;; copy file content in clipboard
  FileRead, FilsSaved, %FileName%
  Clipboard := FilsSaved

  ;; can detect hidden window
  DetectHiddenWindows, On
  ;; activate the application window
  WinActivate, ahk_id %WindowHWND%
  ;; cannot detect hidden window
  DetectHiddenWindows, Off
  ;; wait the window to be active
  WinWaitActive, ahk_id %WindowHWND%
  ;;
  ;; select all
  SendInput, % ArraySelectAll[Index]
  ;; wait 50ms
  Sleep, 50
  ;; paste clipboard
  SendInput, % ArrayPaste[Index]
  ;; wait 50ms
  Sleep, 50
  ;; go to the start
  SendInput, % ArrayGoHome[Index]

 ;; restore the clipboard
  Clipboard := ClipSaved
}
Return

;
;;
;;; FUNCTIONS
;;
;;; read ee file to get all applications
LoadEEFile:
  ;; init array of different application
  ArrayExe       := Object()
  ArraySelectAll := Object()
  ArrayCopy      := Object()
  ArrayPaste     := Object()
  ArrayGoHome    := Object()

  ;; init count of options for an application
  CountOptions := 4

  ;; read each line of the ee file
  Loop, read, %ApplicationName%.ee
  {
    ;; COMMENT
    isComment := RegExMatch(A_LoopReadLine, "^\s*;;.*$")
    if isComment
    {
      ;; do not parse the line when it is a comment
      Continue
    }

    ;; EXE
    isExe := RegExMatch(A_LoopReadLine, "i)^\s*exe=.*$")
    if isExe
    {
      ;; a new application should end another application with 4 options
      if CountOptions != 4
      {
        ;; end parsing
        Break
      }
      else
      {
        ;; new application so reset counter of options
        CountOptions := 0
      }
      ;; get the exe name
      NewOption := RegExReplace(A_LoopReadLine, "i)^\s*exe=(.*)\s*(;;.*)?", "$1")
      ;; new entry in array of exe
      ArrayExe.Insert(NewOption)
      ;; next line in ee file
      Continue
    }

    ;; SELECT ALL
    isSelectAll := RegExMatch(A_LoopReadLine, "i)^\s*selectall=.*$")
    if isSelectAll
    {
      CountOptions += 1
      ;; get the select all shortcut
      NewOption := RegExReplace(A_LoopReadLine, "i)^\s*selectall=(.*)\s*(;;.*)?$", "$1")
      ;; new entry in array of select all shortcut
      ArraySelectAll.insert(NewOption)
      ;; next line in ee file
      Continue
    }

    ;; COPY
    isCopy := RegExMatch(A_LoopReadLine, "i)^\s*copy=.*$")
    if isCopy
    {
      CountOptions += 1
      ;; get the copy shortcut
      NewOption := RegExReplace(A_LoopReadLine, "i)^\s*copy=(.*)\s*(;;.*)?$", "$1")
      ;; new entry in array of copy shortcut
      ArrayCopy.insert(NewOption)
      ;; next line in ee file
      Continue
    }

    ;; PASTE
    isPaste := RegExMatch(A_LoopReadLine, "i)^\s*paste=.*$")
    if isPaste
    {
      CountOptions += 1
      ;; get the paste shortcut
      NewOption := RegExReplace(A_LoopReadLine, "i)^\s*paste=(.*)\s*(;;.*)?$", "$1")
      ;; new entry in array of paste shortcut
      ArrayPaste.insert(NewOption)
      ;; next line in ee file
      Continue
    }

    ;; GO HOME
    isGoHome := RegExMatch(A_LoopReadLine, "i)^\s*gohome=.*$")
    if isGoHome
    {
      CountOptions += 1
      ;; get the home shortcut
      NewOption := RegExReplace(A_LoopReadLine, "i)^\s*gohome=(.*)\s*(;;.*)?$", "$1")
      ;; new entry in array of home shortcut
      ArrayGoHome.insert(NewOption)
      ;; next line in ee file
      Continue
    }
  }

  ;; the application must have 4 options
  if CountOptions != 4
  {
    ;; display a error message
    MsgBox, 0x10, %ApplicationName%, Missing options in ee file.`nSee Help to fix and restart.
  }
Return

;;
;;; set the shortcut of external edit for each application in ee file
SetShortcut:
  ;; for each element in array exe from ee file
  for Index, Element in ArrayExe
  {
    ;; active next shortcuts only for exe in ArrayExe
    HotKey, IfWinActive, ahk_exe %Element%.exe
    ;; active the shortcut
    HotKey, %ExternalEditShortcut%, ExternalEditIndex
  }
Return

;;
;;; load all options from ini file if exists or use default value
LoadIniFile:
  IniRead, ExternalEditShortcut, %IniFile%, Shortcut, ExternalEditShortcut, F2
  IniRead, EditorCommand,        %IniFile%, Editor, EditorCommand, notepad
Return

;;
;;; Edit a ini file
MenuEditIni:
  ;; Launch default editor maximized.
  Run, %IniFile%, , Max UseErrorLevel
  ;; when error to launch
  if ErrorLevel = ERROR
    MsgBox, 0x10, %ApplicationName%, cannot access %IniFile%: No such file or directory.`n(Use before "Create/Save .ini file")
Return

;;
;;; Save all settings in a ini file
MenuCreateSaveIni:
  IniWrite, %ExternalEditShortcut%, %IniFile%, Shortcut, ExternalEditShortcut
  IniWrite, %EditorCommand%,        %IniFile%, Editor, EditorCommand
  ;;
  ;; display a traytip to indicate file save
  TrayTip, %ApplicationName%, %IniFile% file saved., 5, 1
Return

;
;;
;;; MENU HANDLER
;;
;;; handler of the item about
MenuAbout:
  Gui, AboutHelp_:Margin, 30, 10
  Gui, AboutHelp_:Add, Text, 0x1, % ApplicationName "`nVersion " . SoftwareVersion
  Gui, AboutHelp_:Show, AutoSize, About %ApplicationName%
Return

;;
;;; handler of the item help
MenuHelp:
  ;; human readability for shortcut
  StringReplace, MainKey, ExternalEditShortcut, +, % "Shift + "
  StringReplace, MainKey, MainKey, ^, % "Ctrl + "
  StringReplace, MainKey, MainKey, !, % "Alt + "
  StringReplace, MainKey, MainKey, #, % "Win + "
  Gui, AboutHelp_:Add, Text, ,
(
ExternalEditor provide a way to edit into an other editor with "%MainKey%". By example edit gmail in emacs from opera.

ExternalEditor.ee syntax:
`t;; Comment example
`texe=opera`t`t;; name of executable file (without extension)
`tselectall=^a`t`t;; select all shortcut (^ = Control, ! = Alt, + = Shift)
`tcopy=^c`t`t;; copy shortcut (^ = Control, ! = Alt, + = Shift)
`tpaste=^v`t`t;; paste shortcut (^ = Control, ! = Alt, + = Shift)
`tgohome=^{HOME}`t;; go home shortcut (^ = Control, ! = Alt, + = Shift)
`t;; another comment, you can add plenty of application:
`texe=firefox`t`t;; name of executable file (without extension)
`tselectall=^a`t`t;; select all shortcut (^ = Control, ! = Alt, + = Shift)
`tcopy=^c`t`t;; copy shortcut (^ = Control, ! = Alt, + = Shift)
`tpaste=^v`t`t;; paste shortcut (^ = Control, ! = Alt, + = Shift)
`tgohome=^{HOME}`t;; go home shortcut (^ = Control, ! = Alt, + = Shift)
)
  Gui, AboutHelp_:Show, AutoSize, Help %ApplicationName%
Return

;;
;;; handler for the about window
AboutHelp_GuiClose:
AboutHelp_GuiEscape:
  ;; destroy the window without saving anything
  Gui, Destroy
Return

;;
;;; handler of the item Reload .ini
MenuReload:
  ;; load ini file
  GoSub, LoadIniFile
  ;; load ee file (all application settings)
  GoSub, LoadEEFile
Return

;;
;;; remnove all temporary file created by this script
MenuRemoveAllTmpFile:
  ;; remove all temporary file
  FileDelete, % TempFolder . "\*.ee"
Return

;;
;;; handler for the item options
MenuOptions:
  ;; SHORTCUT
  ;; frame with title "Shortcut"
  Gui, Options_:Add, GroupBox, x8 w500 h45, Shortcut
  ;; checkbox at 15x15 pixels margin previous frame "Shortcut"
  IfInString, ExternalEditShortcut, #
  {
    Gui, Options_:Add, CheckBox, xp+15 yp+15 h20 Section Checked1 vWinKey, Windows + ...
    ;; remove windows keys reference
    StringReplace, myShortcut, ExternalEditShortcut, #, , All
  }
  else
  {
    Gui, Options_:Add, CheckBox, xp+15 yp+15 h20 Section Checked0 vWinKey, Windows + ...
    myShortcut = %ExternalEditShortcut%
  }
  ;; edit to capture shortcut in a new column
  Gui, Options_:Add, Hotkey, ys w300 vEEditorShortcut, %myShortcut%

  ;; COMMAND
  ;; frame with title "Command"
  Gui, Options_:Add, GroupBox, x8 w500 h90, Command
  ;; label at 15x15 pixels margin previous frame "Misc (not cmd)"
  Gui, Options_:Add, Text, xp+15 yp+15 Section, Editor command:
  ;; edit in a new column
  Gui, Options_:Add, Edit, xs w470 h40 vECommand, %EditorCommand%

  ;; BUTTON
  ;; OK button (default) (center with the Cancel button Width (550 - 70 - 10 - 70) / 2 = 200)
  Gui, Options_:Add, Button, w70 x200 Section Default, OK
  ;; Cancel button in a new column (gap of 10 pixels between the button)
  Gui, Options_:Add, Button, w70 ys, Cancel
  ;;
  ;; display the gui
  Gui, Options_:Show, AutoSize, %ApplicationName% - Options
Return
;;
;;: handler for the set shortcut window
Options_GuiClose:
Options_GuiEscape:
Options_ButtonCancel:
  ;; destroy the window without saving anything
  Gui, Destroy
Return

;;
;;; handler for the OK button of set shortcut window
Options_ButtonOK:
  ;; get the variable from the gui options
  GuiControlGet, EEditorShortcut
  GuiControlGet, WinKey
  GuiControlGet, ECommand

  ;; remove the gui
  Gui, Destroy

  ;; set global variables
  EditorCommand = %ECommand%
  ;;
  ;; get new shortcut and set it
  Options_SetShortcut(EEditorShortcut, WinKey)
  ;;
  ;; the settings are saved
  GoSub, MenuCreateSaveIni
Return

;;
;;; set new shortcut
Options_SetShortcut(Key, WindowKey)
{
  global ExternalEditShortcut, ApplicationName

  ;; when the checkbox window key is checked
  if WindowKey = 1
  {
    ;; prefix shortcut with #
    Key = % "#" Key
  }
  ;; unset previous shortcut
  HotKey, %ExternalEditShortcut%, , Off
  ;; when key already exist
  HotKey, %Key%, , UseErrorLevel
  if ErrorLevel = 0
  {
    ;; enable new shortcut
    HotKey, %Key%, , On
  }
  else
  {
    ;; when it is not a nonexistent hotkey in the current script
    If ErrorLevel != 5
    {
      MsgBox, 0x10, %ApplicationName%: error, Error: Wrong shortcuts
    }
    else
    {
      ;; the shortcut do not already exist in the current script
    }
  }
  ;; set new shortcut
  HotKey, %Key%, ExternalEditIndex
  ;; set new shortcut and write in ini file
  ExternalEditShortcut = %Key%
}
Return
