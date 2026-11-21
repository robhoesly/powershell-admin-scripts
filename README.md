# PowerShell Admin Scripts

Small collection of Windows maintenance, update, and IT admin / MSP PowerShell scripts with related files and reference info.

## How to Get and Run These Scripts

1. Download the script(s) you want to use
2. Review the code (optional): Right-click the `.ps1` file and select **Edit** (opens in Notepad) to inspect the code.
3. Open PowerShell: Press **Windows Key + X**, select **Terminal (Admin)**, and click **Yes** in the User Account Control prompt.
4. Navigate to the download location:
   ```powershell
   cd C:\Temp
   ```
5. Run the script manually/interactively:
   ```powershell
   .\winget_silent.ps1
   ```

## Example: WinGet (`winget_silent.ps1`)

This updates your third-party apps using WinGet, Microsoft Store apps, Office/Microsoft 365, and Windows OS patches in one pass, and also saves a log file (winget_silent.log) in the same location.

## Optional: Create a One-Click Desktop Shortcut

Once you've verified the script runs cleanly, you can make a shortcut to run it anytime without opening Terminal manually:

1. Right-click your Desktop > **New** > **Shortcut**
2. Paste this into the Target field:
   ```text
   C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File "C:\Temp\winget_silent.ps1"
   ```
3. Name the shortcut file appropriately (for example, **Run System Updates**) and click **Finish**.
4. Right-click the new shortcut, select **Properties**, and then **Advanced**.
5. Check **Run as administrator**, then click **OK**.

## Quick Troubleshooting: If Windows Blocks the Script

1. The script may not be digitally signed or may have come from another computer.

   Windows tags downloaded files with a **Zone.Identifier** stream. Try running these commands in your download directory (`C:\Temp`) to check and unblock the file:

   ```powershell
   Get-Item * -Stream "Zone.Identifier"
   Unblock-File .\winget_silent.ps1
   ```

   Alternatively, copy and paste the script text into a new Notepad file on your PC and save it with a `.ps1` extension (for example, `winget_silent.ps1`).

2. The script still does not run manually in PowerShell.

   Check your execution policy:

   ```powershell
   Get-ExecutionPolicy -List
   ```

   Usually `CurrentUser` or `LocalMachine` should be set to **RemoteSigned**.

   If the policy is **Undefined** or **Restricted**, run this command and test the script again:

   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
   ```