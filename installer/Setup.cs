using System;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Collections.Generic;
using System.Reflection;
using System.Security.Principal;
using System.Security.Cryptography;
using System.Threading;
using System.Windows.Forms;
using System.Drawing;
using System.Diagnostics;
using System.Management;
using System.Text.RegularExpressions;

class Setup : Form {
    TextBox folder = new TextBox();
    CheckBox desktop = new CheckBox();
    Button install = new Button();
    Label info = new Label();
    const string Version = "0.1.7";
    [STAThread] static int Main(string[] args) {
        try {
            if(args.Length == 2 && args[0] == "--test-ui") {
                Application.EnableVisualStyles();
                using(var form=new Setup()) {form.Show();Application.DoEvents();using(var bmp=new Bitmap(form.Width,form.Height)){form.DrawToBitmap(bmp,new Rectangle(0,0,form.Width,form.Height));bmp.Save(args[1]);}form.Close();}return 0;
            }
            if(args.Length == 2 && args[0] == "--test-stop") {StopExisting(Path.GetFullPath(args[1]),@"Local\TrofeoSetupTest-"+Hash(Path.GetFullPath(args[1]))+"-");return 0;}
            if(args.Length == 2 && args[0] == "--test-install") { Install(args[1], false, true); return 0; }
            if(!Environment.Is64BitOperatingSystem) throw new Exception("Нужна 64-разрядная Windows 10 или 11.");
            if(!new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator)) {
                Process.Start(new ProcessStartInfo(Application.ExecutablePath) { UseShellExecute=true, Verb="runas" }); return 0;
            }
            Application.EnableVisualStyles(); Application.Run(new Setup()); return 0;
        } catch(Exception e) { if(args.Length>0) File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"setup-test-error.txt"),e.ToString()); else MessageBox.Show(e.Message,"Trofeo",MessageBoxButtons.OK,MessageBoxIcon.Error); return 1; }
    }
    Setup() {
        Text="Установка Windows System Monitor Trofeo"; ClientSize=new Size(570,310);
        FormBorderStyle=FormBorderStyle.FixedDialog; MaximizeBox=false; StartPosition=FormStartPosition.CenterScreen;
        Font=new Font("Segoe UI",10); Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        var title=new Label {Text="Trofeo "+Version+" — установка и обновление",Location=new Point(20,20),Size=new Size(530,30)};Controls.Add(title);
        Controls.Add(new Label {Text="Папка установки:",Location=new Point(20,65),Size=new Size(200,25)});
        folder.Text=@"C:\Windows System Monitor Trofeo";folder.SetBounds(20,94,435,28);Controls.Add(folder);
        var browse=new Button {Text="Обзор...",Location=new Point(465,92),Size=new Size(85,30)};
        browse.Click+=(s,e)=>{using(var d=new FolderBrowserDialog()){d.SelectedPath=folder.Text;if(d.ShowDialog()==DialogResult.OK)folder.Text=d.SelectedPath;}};Controls.Add(browse);
        desktop.Text="Ярлык на рабочем столе";desktop.Checked=true;desktop.SetBounds(20,140,500,25);Controls.Add(desktop);
        info.Text="Перед обновлением Trofeo завершится автоматически.\nНастройки и логи сохраняются. .NET 8 включён.\nДрайверы USB и PawnIO не устанавливаются.";
        info.SetBounds(20,178,530,70);Controls.Add(info);
        install.Text="Установить";install.SetBounds(400,263,150,30);Controls.Add(install);
        install.Click+=(s,e)=>{
            install.Enabled=false;
            try {
                info.Text="Завершаю Trofeo и устанавливаю обновление…";info.Refresh();
                Install(folder.Text,desktop.Checked,false);
                info.Text="Установка завершена.";install.Text="Готово";
                if(MessageBox.Show(this,"Установка завершена. Запустить Trofeo сейчас?","Trofeo",MessageBoxButtons.YesNo,MessageBoxIcon.Question)==DialogResult.Yes){
                    try {
                        Process.Start(new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),@"System32\wscript.exe"),
                            "\"" + Path.Combine(Path.GetFullPath(folder.Text),"Trofeo-Hidden.vbs") + "\" start") {
                                UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=Path.GetFullPath(folder.Text)
                            });
                    } catch(Exception launchError){MessageBox.Show(this,"Trofeo установлен, но не удалось запустить: "+launchError.Message+"\nОткройте ярлык Trofeo Monitor.","Trofeo",MessageBoxButtons.OK,MessageBoxIcon.Warning);}
                }
                Close();
            }
            catch(Exception ex){MessageBox.Show(ex.Message,"Установка не завершена",MessageBoxButtons.OK,MessageBoxIcon.Error);install.Enabled=true;}
        };
    }
    static void SafePath(string path) {
        var item=new DirectoryInfo(Path.GetFullPath(path));
        while(item!=null) { if(item.Exists && (item.Attributes & FileAttributes.ReparsePoint)!=0) throw new Exception("Папка содержит ссылку: "+item.FullName);item=item.Parent; }
    }
    static string Under(string root,string relative) {
        if(Path.IsPathRooted(relative)) throw new Exception("Invalid package path");
        string full=Path.GetFullPath(Path.Combine(root,relative));
        if(!full.StartsWith(root+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase)) throw new Exception("Invalid package path");
        SafePath(Path.GetDirectoryName(full));
        if(File.Exists(full) && (File.GetAttributes(full)&FileAttributes.ReparsePoint)!=0) throw new Exception("Файл является ссылкой: "+full);
        return full;
    }
    static Mutex Lock(string name) {
        var m=new Mutex(false,name);bool held;
        try{held=m.WaitOne(0);}catch(AbandonedMutexException){held=true;}
        if(!held){m.Dispose();throw new Exception("Закройте Trofeo через «Выход» в трее и повторите установку.");}
        return m;
    }
    static void Install(string destination,bool shortcut,bool test) {
        string root=Path.GetFullPath(destination).TrimEnd(Path.DirectorySeparatorChar);
        if(root.Length<4 || root.Equals(Environment.GetFolderPath(Environment.SpecialFolder.Windows),StringComparison.OrdinalIgnoreCase))throw new Exception("Выберите отдельную папку Trofeo.");
        SafePath(root);
        if(Directory.Exists(root) && Directory.EnumerateFileSystemEntries(root).Any() &&
           !File.Exists(Path.Combine(root,"Start-Trofeo.ps1")) && !File.Exists(Path.Combine(root,"trofeo-install.json")))
            throw new Exception("Папка не пуста и не является установкой Trofeo.");
        Mutex tray=null,monitor=null;
        if(!test){StopExisting(root);tray=Lock(@"Local\TrofeoTray");try{monitor=Lock(@"Local\WindowsSystemMonitorTrofeo-"+Hash("RECOVERYSUPERVISOR"));}catch{tray.ReleaseMutex();tray.Dispose();throw;}}
        var saved=new Dictionary<string,string>();var added=new List<string>();
        string backup=Path.Combine(root,"backups","setup-"+DateTime.Now.ToString("yyyyMMdd-HHmmss-fff"));
        try {
            using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip"))
            using(var zip=new ZipArchive(stream,ZipArchiveMode.Read)) {
                foreach(var entry in zip.Entries) {
                    if(entry.FullName.EndsWith("/"))continue;
                    string target=Under(root,entry.FullName);
                    if(entry.FullName=="trofeo-settings.json" && File.Exists(target))continue;
                    if(File.Exists(target)) {
                        string save=Under(backup,entry.FullName);Directory.CreateDirectory(Path.GetDirectoryName(save));File.Copy(target,save);saved[target]=save;
                    }else added.Add(target);
                    Directory.CreateDirectory(Path.GetDirectoryName(target));
                    using(var input=entry.Open()) using(var output=File.Create(target))input.CopyTo(output);
                }
            }
            string exe=Under(root,@"artifacts\v0.1.7\WindowsSystemMonitorTrofeo.exe");
            var check=Process.Start(new ProcessStartInfo(exe,"--check-runtime") {UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=root});
            if(!check.WaitForExit(15000)){check.Kill();throw new Exception("Проверка .NET не завершилась.");}
            if(check.ExitCode!=0)throw new Exception("Проверка .NET завершилась ошибкой.");
            Shortcut(root,root);
            if(!test) {
                if(shortcut)Shortcut(root,Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory));
            }
            File.WriteAllText(Under(root,"trofeo-install.json"),"{\"version\":\""+Version+"\",\"selfContained\":true}");
        }catch {
            foreach(var pair in saved)File.Copy(pair.Value,pair.Key,true);
            foreach(var file in added)if(File.Exists(file))File.Delete(file);
            throw;
        }finally {
            if(monitor!=null){monitor.ReleaseMutex();monitor.Dispose();}
            if(tray!=null){tray.ReleaseMutex();tray.Dispose();}
        }
    }
    static bool UnderInstall(Process process,string root) {
        try{return process.SessionId==Process.GetCurrentProcess().SessionId &&
            process.MainModule.FileName.StartsWith(root.TrimEnd(Path.DirectorySeparatorChar)+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase);}
        catch(System.ComponentModel.Win32Exception){return false;}
        catch(InvalidOperationException){return false;}
    }
    static void StopExisting(string root,string eventPrefix=@"Local\Trofeo") {
        using(var exit=new EventWaitHandle(false,EventResetMode.ManualReset,eventPrefix+"Exit"))
        using(var stop=new EventWaitHandle(false,EventResetMode.ManualReset,eventPrefix+"Stop")) {
            exit.Set();stop.Set();
            var deadline=DateTime.UtcNow.AddSeconds(45);
            while(true){
                bool active=false;
                foreach(var p in Process.GetProcessesByName("WindowsSystemMonitorTrofeo"))using(p){if(UnderInstall(p,root)&&!p.HasExited)active=true;}
                if(!active)break;
                if(DateTime.UtcNow>=deadline)throw new Exception("Trofeo не завершил передачу кадра. Файлы не изменены. Повторите установку после завершения монитора.");
                Thread.Sleep(100);
            }
            // Older tray versions have no exit event. After USB has stopped, close only
            // PowerShell hosts whose -File argument matches this installation exactly.
            using(var query=new ManagementObjectSearcher("SELECT ProcessId,CommandLine FROM Win32_Process WHERE Name='powershell.exe' AND SessionId="+Process.GetCurrentProcess().SessionId))
            using(var results=query.Get()){
                foreach(ManagementObject item in results)using(item){
                    var command=item["CommandLine"] as string;
                    if(command==null)continue;
                    var match=Regex.Match(command,@"-File\s+(?:""(?<file>[^""]+)""|(?<file>\S+))",RegexOptions.IgnoreCase);
                    if(!match.Success)continue;
                    string file;
                    try{file=Path.GetFullPath(match.Groups["file"].Value);}catch(ArgumentException){continue;}
                    if(!file.Equals(Path.Combine(root,"Trofeo-Tray.ps1"),StringComparison.OrdinalIgnoreCase)&&
                       !file.Equals(Path.Combine(root,"Start-Trofeo.ps1"),StringComparison.OrdinalIgnoreCase))continue;
                    try{using(var p=Process.GetProcessById(Convert.ToInt32(item["ProcessId"]))){if(!p.HasExited){p.Kill();if(!p.WaitForExit(5000))throw new Exception("Не удалось закрыть окно Trofeo.");}}}
                    catch(ArgumentException){}
                }
            }
            foreach(var p in Process.GetProcessesByName("TrofeoPreviewRenderer"))using(p){
                if(UnderInstall(p,root)&&!p.HasExited&&!p.WaitForExit(3000)){p.Kill();p.WaitForExit(3000);}
            }
            Thread.Sleep(200);
        }
    }
    static string Hash(string value){using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(System.Text.Encoding.UTF8.GetBytes(value))).Replace("-","");}
    static void Shortcut(string root,string where) {
        dynamic shell=Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));
        dynamic link=shell.CreateShortcut(Path.Combine(where,"Trofeo Monitor.lnk"));
        link.TargetPath=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),@"System32\wscript.exe");
        link.Arguments="\""+Path.Combine(root,"Trofeo-Hidden.vbs")+"\" start";
        link.WorkingDirectory=root;link.IconLocation=Path.Combine(root,@"assets\trofeo-app.ico")+",0";link.Save();
        System.Runtime.InteropServices.Marshal.FinalReleaseComObject(link);
        System.Runtime.InteropServices.Marshal.FinalReleaseComObject(shell);
    }
}
