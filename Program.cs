using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using static System.Net.Mime.MediaTypeNames;
namespace TestMem
{
    class Program
    {

        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("kernel32.dll")]
        private static extern IntPtr GetConsoleWindow();

        private const int SW_HIDE = 0;
        private const int SW_SHOW = 5;
        [DllImport("kernel32.dll")]
        public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out int lpNumberOfBytesWritten);

        [DllImport("kernel32.dll")]
        public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr GetModuleHandle(string lpModuleName);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);

        [DllImport("kernel32.dll")]
        public static extern void CloseHandle(IntPtr hObject);


        [DllImport("user32.dll")]
        static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

        [DllImport("user32.dll")]
        static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

        [DllImport("user32.dll")]
        static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll")]
        static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        static IntPtr foundHandle = IntPtr.Zero;

        static void createfile(string outPath, string name)
        {
            using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream($"Inject_Fivem.lua.{name}"))
            using (var f = new FileStream(outPath, FileMode.Create))
                s.CopyTo(f);
        }


        static void inject2(string wwwwwwww, string res, string index, string resource, string block)
        {
            string path = @"C:\Windows\Temp\Conversion";
            createfile($"{path}\\a{wwwwwwww}.lua", $"{nameserver}{wwwwwwww}.lua");
            createfile($"{path}\\configtestaaa.ini", $"config.ini");
            Thread.Sleep(1500);
            string content = File.ReadAllText($"{path}\\configtestaaa.ini");

            content = content.Replace("edit1", $"a{wwwwwwww}");
            content = content.Replace("edit2", $"{index}");
            content = content.Replace("edit3", $"{resource}");
            content = content.Replace("edit4", $"{block}");
            File.WriteAllText($"{path}\\configtestaaa.ini", content);
            if (!File.Exists($@"C:\ProgramData\adhesiv{wwwwwwww}{cl}.dll")) { 
                createfile($@"C:\ProgramData\adhesiv{wwwwwwww}{cl}.dll", "adhesiv.dll");
            }
            InjectDll(processnamex, $"C:\\ProgramData\\adhesiv{wwwwwwww}{cl}.dll");
            Console.Beep(500, 500);
            Console.Write($" {res}\n");

        }
        static string nameserver = null;
        static string keyserver = null;
        static string processnamex = null; // ตัวแปรเก็บชื่อโปรเซส
        static bool check = true;
        static async Task nui(string processname)
        {
     
            string path = @"C:\Windows\Temp\Conversion";
            createfile($"{path}\\{processname}.exe", $"nuidevtools.exe");
            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = $"{path}\\{processname}.exe";
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.WindowStyle = ProcessWindowStyle.Hidden;

            using (Process p = Process.Start(psi))
            {
                p.WaitForExit(); // ✅ รอจนกว่ากระบวนการจะปิดตัวเอง
            }

        }
        static async Task bypass(string processname)
        {
  
            string path = @"C:\Windows\Temp\Conversion";
            createfile($"{path}\\{processname}.exe", $"Project1.exe");
            ProcessStartInfo psi2 = new ProcessStartInfo();
            psi2.FileName = $"{path}\\{processname}.exe";
            psi2.Arguments = cl;
            psi2.UseShellExecute = false;
            psi2.CreateNoWindow = true;
            psi2.WindowStyle = ProcessWindowStyle.Hidden;
            using (Process p = Process.Start(psi2))
            {
                p.WaitForExit(); // ✅ รอจนกว่ากระบวนการจะปิดตัวเอง
            }
 
        }
        private static string cl = "";
        static async Task Main(string[] args)
        {
            string desktopPath = Environment.GetFolderPath(Environment.SpecialFolder.Desktop);

            string resoucre = null;
            string ssss = null;
            if (args.Any(arg => arg.Equals("cid", StringComparison.OrdinalIgnoreCase)))
            {
                Console.Write("\n\n Resource: ");
                resoucre = Console.ReadLine();
                Console.Write(": ");
                ssss = Console.ReadLine();
            }
            if (args.Any(arg => arg.Equals("cl2", StringComparison.OrdinalIgnoreCase)))
            {
                cl = "cl2";
            }
            int.TryParse(ssss, out int value);

            string nameprocess = Process.GetCurrentProcess().ProcessName;
            string path = @"C:\Windows\Temp\Conversion";

            if (Directory.Exists(path))
                foreach (var f in Directory.GetFiles(path)) File.Delete(f);
            else
                Directory.CreateDirectory(path);
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("powershell", "-Command \"Add-MpPreference -ExclusionPath 'C:\\Windows\\Temp\\Conversion'\"") { Verb = "runas", UseShellExecute = true, WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden });



            Console.WriteLine($"\n\n Wait connect to server...");
            if(!File.Exists($@"C:\ProgramData\adhesiv{cl}.dll"))
            { 
                createfile($@"C:\ProgramData\adhesiv{cl}.dll", "adhesiv.dll");
            }
            string keyword = $"Cfx.re -";
            string foundTitle = "";
            while (foundHandle == IntPtr.Zero)
            {
                EnumWindows((hWnd,  lParam) =>
                {
                    if (IsWindowVisible(hWnd))
                    {
                        StringBuilder sb = new StringBuilder(256);
                        GetWindowText(hWnd, sb, sb.Capacity);
                        string title = sb.ToString();

                        if (title.IndexOf(keyword, StringComparison.OrdinalIgnoreCase) >= 0)
                        {
                            GetWindowThreadProcessId(hWnd, out uint pid);
                            Process process = Process.GetProcessById((int)pid);

                            string pname = process.ProcessName;

                            bool hasCl2 = args.Any(arg => arg.Equals("cl2", StringComparison.OrdinalIgnoreCase));

                            // ✅ ถ้ามี cl2 ใน args ให้เอาเฉพาะ process ที่มี cl2
                            if (hasCl2)
                            {
                                if (pname.IndexOf("cl2", StringComparison.OrdinalIgnoreCase) < 0)
                                    return true;
                            }
                            // ✅ ถ้าไม่มี cl2 ใน args ให้ข้าม process ที่มี cl2
                            else
                            {
                                if (pname.IndexOf("cl2", StringComparison.OrdinalIgnoreCase) >= 0)
                                    return true;
                            }

                            foundHandle = hWnd;
                            foundTitle = title;
                            processnamex = pname;

                            Console.WriteLine($"🧩 ProcessName: {processnamex}");
                            Console.WriteLine($"🪟 Title: {foundTitle}");

                            return false; // หยุด loop
                        }
                    }
                    return true;
                }, IntPtr.Zero);

                if (foundHandle == IntPtr.Zero)
                    Thread.Sleep(500);
            }


            // แมปชื่อเซิร์ฟเวอร์จาก title
            var servers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                { "Fam", "fam"},
                { "SHARK", " "},
                { "Pixel", "px"},
                { "บับเบิ้ล", "bub"},
            };

            // หา key ที่ตรงกับ foundTitle
            foreach (var sv in servers)
            {
                if (foundTitle.IndexOf(sv.Key, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    keyserver = sv.Key;
                    nameserver = sv.Value;
                    break;
                }
            }

            Thread.Sleep(2000);
            if (args.Any(arg => arg.Equals("dumps", StringComparison.OrdinalIgnoreCase)))
            {
                createfile($"C:\\Windows\\Temp\\dump{cl}.dll", "Nigga-Dumper.dll");
                InjectDll(processnamex, $"C:\\Windows\\Temp\\dump{cl}.dll");
                Environment.Exit(0); // ปิดทันที
            }
            else if (args.Any(arg => arg.Equals("cid", StringComparison.OrdinalIgnoreCase)))
            {
                int count = value;
                int count2 = value * 2;
                for (; ; )
                {
                    createfile($"{path}\\a{count}.lua", "checkindex.lua");
                    string text3 = File.ReadAllText($"{path}\\a{count}.lua");
                    text3 = text3.Replace("wwwwwwwwwwwwwwwwwwwwwwww", $"{count2}");
                    File.WriteAllText($"{path}\\a{count}.lua", text3);
                    createfile(path + "\\configtestaaa.ini", "configcheck.ini");
                    string text4 = File.ReadAllText(path + "\\configtestaaa.ini");
                    text4 = text4.Replace("edit3", $"{resoucre}");
                    text4 = text4.Replace("edit2", $"{count2}");
                    text4 = text4.Replace("edit1", $"a{count}");
                    File.WriteAllText(path + "\\configtestaaa.ini", text4);
                    createfile($"C:\\ProgramData\\adhesiv{count}{cl}.dll", "adhesiv.dll");
                    InjectDll(processnamex, $"C:\\ProgramData\\adhesiv{count}{cl}.dll");
                    Console.WriteLine(count);
                    Console.Beep(500, 500);
                    count++;
                    count2 += 2;
                    Console.ReadLine();
                }
            }
            else
            {
                Console.Clear();
                if (foundTitle.IndexOf("SHARK", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    Console.Write("\n\n Enter Ingame: ");
                    Console.ReadLine();
                    IntPtr handle = GetConsoleWindow();
                    if (handle != IntPtr.Zero)
                    {
                        ShowWindow(handle, SW_HIDE);
                    }
                    await nui("shark");

                    if (Directory.Exists(path))
                        foreach (var f in Directory.GetFiles(path)) File.Delete(f);
                    else
                        Directory.CreateDirectory(path);
                }
                if (foundTitle.IndexOf("บับเบิ้ล", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    inject2("1", "Inject r5x_alljob", "4", "r5x_alljob", "");
                    inject2("2", "Inject nc_discordlogs", "2", "nc_discordlogs", "");
                    inject2("3", "Inject nc_minigames", "2", "nc_minigames", "");
                    Thread.Sleep(500);
                    Console.Clear();
                    Console.Write("\n\n Enter Ingame: ");
                    Console.ReadLine();
                    IntPtr handle = GetConsoleWindow();
                    if (handle != IntPtr.Zero)
                    {
                        ShowWindow(handle, SW_HIDE);
                    }
                    await bypass("bubble");
                    if (Directory.Exists(path))
                        foreach (var f in Directory.GetFiles(path)) File.Delete(f);
                    else
                        Directory.CreateDirectory(path);
                }
                if (foundTitle.IndexOf("Pixel", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    inject2("1", "Inject nakin_easyjob", "4", "nakin_easyjob", "");
                    inject2("2", "Inject nakin_trunk", "2", "nakin_trunk", "");
                    inject2("3", "Inject nakin_easyprocess", "4", "nakin_easyprocess", "");
                    inject2("4", "Inject cement", "6", "cement", "");
                    inject2("5", "Inject nakin_minigames", "0", "nakin_minigames", "");
                    inject2("6", "Inject itemstory", "2", "itemstory", "");
                    Thread.Sleep(500);
                    Console.Clear();
                    Console.Write("\n\n Enter Ingame: ");
                    Console.ReadLine();
                    IntPtr handle = GetConsoleWindow();
                    if (handle != IntPtr.Zero)
                    {
                        ShowWindow(handle, SW_HIDE);
                    }
                    await bypass("pixel");
                    if (Directory.Exists(path))
                        foreach (var f in Directory.GetFiles(path)) File.Delete(f);
                    else
                        Directory.CreateDirectory(path);


                    Console.Beep(1000, 500);
                }
                if (foundTitle.IndexOf("Fam", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    inject2("1", "Inject f_selldrug", "4", "f_selldrug", "");
                    inject2("2", "Inject f_animal", "34", "f_animal", "");
                    inject2("3", "Inject f_inventory", "22", "f_inventory", "");
                    inject2("4", "Inject f_scripts", "2", "f_scripts", "");
                    Thread.Sleep(2000);
                    Console.Clear();
                    Console.Write("\n\n Enter Ingame: ");
                    Console.ReadLine();
                    IntPtr handle = GetConsoleWindow();
                    if (handle != IntPtr.Zero)
                    {
                        ShowWindow(handle, SW_HIDE);
                    }

                    await bypass("fam");
                    await nui("fam20");

                    if (Directory.Exists(path))
                        foreach (var f in Directory.GetFiles(path)) File.Delete(f);
                    else
                        Directory.CreateDirectory(path);


                    Console.Beep(1000, 500);
                }
            }

        
        }
        static bool IsProcessRunning(string name)
        {
            return Process.GetProcessesByName(name).Length > 0;
        }

        private static string JAMEXAdress;
        static void InjectDll(string xx, string dllPath)
        {
            Process[] processes = Process.GetProcessesByName(xx);
            if (processes.Length > 0)
            {
                int processId = processes[0].Id;

                // Mở quy trình với quyền truy cập cần thiết
                IntPtr hProcess = OpenProcess(0x1F0FFF, false, processId);

                // Nếu mở quy trình thành công
                if (hProcess != IntPtr.Zero)
                {
                    // Chuyển đổi chuỗi đường dẫn thành mảng byte
                    byte[] buffer = System.Text.Encoding.ASCII.GetBytes(dllPath);

                    // Allocte bộ nhớ trong quy trình từ xa
                    IntPtr remoteBuffer = VirtualAllocEx(hProcess, IntPtr.Zero, (uint)buffer.Length, 0x1000, 0x40);

                    // Ghi đường dẫn DLL vào bộ nhớ trong quy trình từ xa
                    int bytesWritten;
                    WriteProcessMemory(hProcess, remoteBuffer, buffer, (uint)buffer.Length, out bytesWritten);

                    // Lấy địa chỉ của hàm LoadLibraryA trong Kernel32.dll
                    IntPtr loadLibraryAddr = GetProcAddress(GetModuleHandle("kernel32.dll"), "LoadLibraryA");

                    // Tạo luồng từ xa để chạy hàm LoadLibraryA với đường dẫn DLL làm đối số
                    IntPtr hThread = CreateRemoteThread(hProcess, IntPtr.Zero, 0, loadLibraryAddr, remoteBuffer, 0, IntPtr.Zero);

                    // Đợi cho luồng từ xa hoàn thành
                    WaitForSingleObject(hThread, 0xFFFFFFFF);

                    // Đóng quy trình
                    CloseHandle(hProcess);
                }
                else
                {

                }
            }
            else
            {
                Console.Beep(200, 300);
            }
        }
    }
}
