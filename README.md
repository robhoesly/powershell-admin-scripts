# powershell-admin-scripts
Collection of Windows maintenance, update, and IT admin / MSP PowerShell scripts

# winget_silent.ps1
This updates your third-party apps (using WinGet), Microsoft Store apps, Office/Microsoft 365, and Windows OS patches in one pass, and saves a log file (winget_silent.log) in the same folder.

# HOW TO SET IT UP & RUN IT
Extract the file: Unzip the attachment to a simple folder like C:\Temp.
Rename the extension: Rename winget_silent.txt to winget_silent.ps1. (Tip: Make sure "File name extensions" is checked under the View tab in File Explorer so it doesn't end up named winget_silent.ps1.txt).
Review the code (optional): Right-click the .ps1 file and select Edit (or open in Notepad) if you want to inspect everything it does before running.
Open PowerShell: Press Windows Key + X, select Terminal (Admin), and click Yes on the User Account Control prompt.

Run the script:
cd C:\Temp
.\winget_silent.ps1
(Note: If updates require a restart, the script gives a 30-second countdown at the end. Press Ctrl + C to cancel the automatic reboot.)

# OPTIONAL: CREATE A ONE-CLICK DESKTOP SHORTCUT
Once you've verified it runs cleanly, you can make a shortcut to run it anytime without opening Terminal manually:
Right-click your Desktop > New > Shortcut.
Paste this into the Target field:
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File "C:\Temp\winget_silent.ps1"
Name it something like Run System Updates and click Finish.
Right-click the new shortcut > Properties > Shortcut tab > Advanced... > check Run as administrator > click OK.

# QUICK TROUBLESHOOTING (IF WINDOWS BLOCKS THE SCRIPT)
Q1: I get an error saying the script is not digitally signed or came from another computer.
Windows tags downloaded files with a Zone.Identifier stream. Run these commands in C:\Temp to check and unblock it:
Get-Item * -Stream "Zone.Identifier"
Unblock-File .\winget_silent.ps1
(Alternatively, just copy/paste the text into a brand-new Notepad file on your PC and save it as winget_silent.ps1.)
Q2: It still won't run manually in PowerShell.
Check your Execution Policy with:
Get-ExecutionPolicy -List
Ideally, CurrentUser or LocalMachine should be set to RemoteSigned. If they are Undefined or Restricted, run this once and try again:
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
