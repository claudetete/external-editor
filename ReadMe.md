# Introduction #
You can use any editor and any application with ExternalEditor.


# Install #
  * Download last verstion at http://code.google.com/p/external-editor/downloads/list
  * Unzip anywhere
  * Run ExernalEditor.exe

# Settings #
  * Right click on tray icon and select Options
  * you can set the path of your favorite editor and the shortcut to launch external editor

---

  * edit the ExternalEditor.ee file to add any application you want to use external editor
  * you must respect the same syntax as follow:
```
;; Opera
exe=opera            ;; executable name
selectall=^a         ;; select all shortcut
copy=^c              ;; copy shortcut
paste=^v             ;; paste shortcut
gohome=^{HOME}       ;; go to start shortcut
;;
;; Mozilla Firefox
exe=firefox
selectall=^a
copy=^c
paste=^v
gohome=^{HOME}
;; etc
```
  * Shortcut syntax is from [AutoHotKey](http://www.autohotkey.com/docs/Hotkeys.htm)