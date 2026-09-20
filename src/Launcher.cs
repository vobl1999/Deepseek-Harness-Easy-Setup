// DeepSeek Harness launcher: starts "dsh web" with the bundled node.exe.
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;

static class Program
{
    [STAThread]
    static int Main()
    {
        string exeDir = AppDomain.CurrentDomain.BaseDirectory;
        string dataDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DeepSeekHarness");
        string pidFile = Path.Combine(dataDir, "pid.txt");
        string logFile = Path.Combine(dataDir, "run.log");
        try { Directory.CreateDirectory(dataDir); } catch { }

        int existingPid;
        if (File.Exists(pidFile) && int.TryParse(File.ReadAllText(pidFile).Trim(), out existingPid) && existingPid > 0)
        {
            try
            {
                Process p = Process.GetProcessById(existingPid);
                if (!p.HasExited && p.ProcessName.IndexOf("node", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    OpenBrowserFromLog(logFile);
                    return 0;
                }
            }
            catch { }
            try { File.Delete(pidFile); } catch { }
        }

        string nodePath = Path.Combine(exeDir, "node.exe");
        string binPath = Path.Combine(exeDir, "node_modules", "@deepseek-ai", "dsh", "lib", "bin.js");
        if (!File.Exists(nodePath) || !File.Exists(binPath))
        {
            MessageBox.Show("程序文件不完整，请重新安装 DeepSeek Harness。", "DeepSeek Harness",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }

        ProcessStartInfo psi = new ProcessStartInfo();
        psi.FileName = nodePath;
        psi.Arguments = "\"" + binPath + "\" web";
        psi.WorkingDirectory = exeDir;
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        psi.RedirectStandardOutput = true;
        psi.RedirectStandardError = true;
        psi.StandardOutputEncoding = Encoding.UTF8;
        psi.StandardErrorEncoding = Encoding.UTF8;
        string pathVar = Environment.GetEnvironmentVariable("PATH") ?? "";
        string extra = exeDir + ";" + Environment.GetFolderPath(Environment.SpecialFolder.System) + ";" +
                       Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        psi.EnvironmentVariables["PATH"] = extra + ";" + pathVar;

        Process child;
        try { child = Process.Start(psi); }
        catch (Exception ex)
        {
            MessageBox.Show("启动失败：" + ex.Message, "DeepSeek Harness",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }

        FileStream fs = new FileStream(logFile, FileMode.Create, FileAccess.Write, FileShare.ReadWrite);
        child.OutputDataReceived += delegate(object s, DataReceivedEventArgs e)
        {
            if (e.Data != null) { byte[] b = Encoding.UTF8.GetBytes(e.Data + "\n"); fs.Write(b, 0, b.Length); fs.Flush(); }
        };
        child.ErrorDataReceived += delegate(object s, DataReceivedEventArgs e)
        {
            if (e.Data != null) { byte[] b = Encoding.UTF8.GetBytes(e.Data + "\n"); fs.Write(b, 0, b.Length); fs.Flush(); }
        };
        child.BeginOutputReadLine();
        child.BeginErrorReadLine();
        try { File.WriteAllText(pidFile, child.Id.ToString()); } catch { }

        for (int i = 0; i < 40; i++)
        {
            Thread.Sleep(200);
            if (child.HasExited) break;
        }
        if (child.HasExited)
        {
            fs.Close();
            try { File.Delete(pidFile); } catch { }
            MessageBox.Show("启动失败，请查看日志：\r\n" + logFile, "DeepSeek Harness",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
        try { child.WaitForExit(); } catch { }
        try { File.Delete(pidFile); } catch { }
        fs.Close();
        return 0;
    }

    static void OpenBrowserFromLog(string logFile)
    {
        string url = "http://127.0.0.1:3080";
        try
        {
            if (File.Exists(logFile))
            {
                string text = File.ReadAllText(logFile);
                Match m = Regex.Match(text, "http://127\\.0\\.0\\.1:\\d+");
                if (m.Success) url = m.Value;
            }
        }
        catch { }
        try { Process.Start(url); } catch { }
    }
}
