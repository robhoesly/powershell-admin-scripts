# powershell-admin-scripts
# DESCRIPTION:
Small collection of Windows maintenance, update, and IT admin / MSP PowerShell scripts with related files and reference info.

# HOW TO SETUP AND RUN SCRIPTS
1. Download the script you want to use
2. Review the code (optional): Right-click the .ps1 file and select **Edit** (opens in Notepad) to inspect code
3. Open PowerShell: Press **Windows Key + X**, select **Terminal (Admin)**, and click **Yes** on the User Account Control prompt.
4. Navigate to download location (`cd C:\Temp`)
6. Example of running script manually/interactively (`.\winget_silent.ps1`)

# EXAMPLE: WINGET (winget_silent.ps1)
This updates your third-party apps using WinGet, Microsoft Store apps, Office/Microsoft 365, and Windows OS patches in one pass, and also saves a log file (winget_silent.log) in the same location.

# OPTIONAL: CREATE A ONE-CLICK DESKTOP manually, 
Once you've verified the script runs cleanly, you can make a shortcut to run it anytime without opening Terminal manually:
1. Right-click your Desktop > **New** > **Shortcut**
2. Paste this into the Target field:
`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File "C:\Temp\winget_silent.ps1"`
3. Name the shortcut file appropriately (example: **Run System Updates**) and click **Finish**.
4. Right-click the new shortcut > **Properties** > **Advanced...** > check **Run as administrator** > click **OK**

# QUICK TROUBLESHOOTING (IF WINDOWS BLOCKS THE SCRIPT)
**Q1** Script not digitally signed or came from another computer.
**A1.** Windows tags downloaded files with a *Zone.Identifier stream.* Try running these commands in your download directory (C:\Temp) to check and unblock it:
`Get-Item * -Stream "Zone.Identifier"`
`Unblock-File .\winget_silent.ps1`
`(Alternatively, just copy/paste the text into a new Notepad file on your PC and save it appropriately (example: winget_silent.ps1.)`

**Q2** The script still doesn't run manually in PowerShell.
**A2** Check your Execution Policy by running this command:
**Get-ExecutionPolicy -List**
Usually CurrentUser or LocalMachine should be set to **RemoteSigned**
If they are **Undefined** or **Restricted,** run this command and try the script again:
`Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force`