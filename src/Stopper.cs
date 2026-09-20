// DeepSeek Harness stopper: kills the running dsh web process.
// /s = silent, no message box (used by the uninstaller).
using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

static class Program
{
    [STAThread]
    static int Main(string[] args)
    {
        bool silent = args.Length > 0 && (args[0] == "/s" || args[0] == "-s" || args[0] == "/S" || args[0] == "-S");
        string dataDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DeepSeekHarness");
        string pidFile = Path.Combine(dataDir, "pid.txt");
        int pid;
        bool running = false;
        if (File.Exists(pidFile) && int.TryParse(File.ReadAllText(pidFile).Trim(), out pid) && pid > 0)
        {
            try
            {
                Process p = Process.GetProcessById(pid);
                if (!p.HasExited && p.ProcessName.IndexOf("node", StringComparison.OrdinalIgnoreCase) >= 0) running = true;
            }
            catch { }
            if (running)
            {
                ProcessStartInfo psi = new ProcessStartInfo("taskkill", "/F /T /PID " + pid);
                psi.UseShellExecute = false;
                psi.CreateNoWindow = true;
                try { Process.Start(psi).WaitForExit(10000); } catch { }
                try { File.Delete(pidFile); } catch { }
            }
        }
        if (!running)
        {
            try { File.Delete(pidFile); } catch { }
            if (!silent)
                MessageBox.Show("DeepSeek Harness 没有在运行。", "DeepSeek Harness",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
        else if (!silent)
        {
            MessageBox.Show("DeepSeek Harness 已关闭。", "DeepSeek Harness",
                MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
        return 0;
    }
}
