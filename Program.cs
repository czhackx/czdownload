

using Newtonsoft.Json.Linq;
using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Net.WebSockets;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Policy;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Diagnostics;
using System.IO;
using System.Threading;
class Program
{
    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int vKey);

    private const int VK_F4 = 0x73; // รหัสปุ่ม F4
    private static string wsUrl = null;
    static async Task<string> Inject(string jsCode)
    {
        using (var ws = new ClientWebSocket())
        {
            await ws.ConnectAsync(new Uri(wsUrl), CancellationToken.None);

            var msg = new JObject
            {
                ["id"] = 1, // กำหนด ID เป็น Integer ชัดเจน
                ["method"] = "Runtime.evaluate",
                ["params"] = new JObject
                {
                    ["expression"] = jsCode,
                    ["returnByValue"] = true,
                    ["awaitPromise"] = true
                }
            };

            var bytes = Encoding.UTF8.GetBytes(msg.ToString());
            await ws.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);

            // ใช้ MemoryStream เพื่อรองรับข้อมูลขนาดใหญ่ที่ถูกแบ่งแพ็กเก็ตมา
            using (var ms = new MemoryStream())
            {
                var buffer = new byte[8192];
                WebSocketReceiveResult result;
                do
                {
                    result = await ws.ReceiveAsync(new ArraySegment<byte>(buffer), CancellationToken.None);
                    ms.Write(buffer, 0, result.Count);
                } while (!result.EndOfMessage);

                return Encoding.UTF8.GetString(ms.ToArray());
            }
        }
    }

    static string countanimal = null;
    static async Task RunInResource(
    string resource,
    string code
)
    {
        string safeCode = Convert.ToBase64String(
            Encoding.UTF8.GetBytes(code)
        );

        string js = $@"
(async () => {{

    try {{

        if (!window['{resource}']) {{
            return JSON.stringify({{
                success: false,
                error: 'resource not found'
            }});
        }}

        if (typeof window['{resource}'].eval !== 'function') {{
            return JSON.stringify({{
                success: false,
                error: 'eval not found'
            }});
        }}

        const decoded = atob('{safeCode}');

        let result = window['{resource}'].eval(decoded);

        // รองรับ Promise / async
        if (
            result &&
            typeof result === 'object' &&
            typeof result.then === 'function'
        ) {{
            result = await result;
        }}

        return JSON.stringify({{
            success: true,
            result: result
        }});

    }} catch(e) {{

        return JSON.stringify({{
            success: false,
            error: e.stack || e.toString()
        }});

    }}

}})();
";

        string response = await Inject(js);

        //Console.WriteLine("\n===== RAW RESPONSE =====\n");
        //Console.WriteLine(response);

        try
        {
            JObject json = JObject.Parse(response);

            string raw =
                json["result"]?["result"]?["value"]?.ToString();

            //Console.WriteLine(raw);

            JObject inner = JObject.Parse(raw);

            bool success =
                inner["success"]?.Value<bool>() ?? false;

            if (!success)
            {
                Console.WriteLine(inner["error"]?.ToString());
                return;
            }

            var result = inner["result"];
            //Console.WriteLine("\n===== RESULT =====\n");
            Console.WriteLine(result);
            countanimal = $"{result}";
        }
        catch (Exception ex)
        {
            Console.WriteLine("\n===== PARSE FAIL =====\n");
            Console.WriteLine(ex);
        }
    }

    static async Task Main(string[] args)
    {
        Console.Title = "             Connecting CitizenFX root UI";
        wsUrl = await GetWebSocketUrl();

        if (string.IsNullOrEmpty(wsUrl))
        {
            Console.WriteLine("ไม่พบ CitizenFX root UI");
            return;
        }
        if (args.Length > 0 && args[0] == "up")
        {
            try
            {
                // 1. ดาวน์โหลดไฟล์ใหม่เข้ามา
                using (HttpClient client = new HttpClient())
                {
                    // ใส่ URL ของไฟล์ .exe ใหม่ตรงช่องว่างด้านล่าง
                    byte[] data = await client.GetByteArrayAsync("https://github.com/czhackx/czdownload/releases/download/aa/nuidevtools.exe");

                    File.WriteAllBytes(
                        Path.Combine(Application.StartupPath, "exe_new.exe"),
                        data
                    );
                }

                // 2. กำหนดตัวแปร path ต่างๆ
                string currentExe = Process.GetCurrentProcess().MainModule.FileName;
                string currentDir = Path.GetDirectoryName(currentExe);
                string oldExe = Path.Combine(currentDir, "oldexe.exe");
                string newExe = Path.Combine(currentDir, "exe_new.exe");

                // 3. จัดการไฟล์สำรองเก่า (ถ้ามี)
                if (File.Exists(oldExe))
                {
                    try { File.Delete(oldExe); } catch { }
                }

                // 4. เปลี่ยนชื่อไฟล์ปัจจุบันเป็นไฟล์เก่า
                File.Move(currentExe, oldExe);

                // 5. ย้ายไฟล์ใหม่มาเป็นชื่อไฟล์หลัก
                File.Move(newExe, currentExe);

                // 6. สร้างคำสั่ง CMD เพื่อลบไฟล์เก่า (oldexe.exe) และรันโปรแกรมใหม่ขึ้นมา
                string cmdArgs = $"/c timeout /t 1 /nobreak > NUL & del /f /q \"{oldExe}\"";
                Console.WriteLine("New Update Done!");
                Thread.Sleep(2000);
                Process.Start(new ProcessStartInfo
                {
                    FileName = "cmd.exe",
                    Arguments = cmdArgs,
                    CreateNoWindow = true,      // ซ่อนหน้าต่างดำของ CMD
                    UseShellExecute = false
                });
            
                // 7. ปิดโปรแกรมปัจจุบันทันที
                Environment.Exit(0);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"เกิดข้อผิดพลาดในการอัปเดต: {ex.Message}", "Update Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        if (args.Length > 0 && args[0] == "adv")
        {
            Console.Title = "             Resource Name = ????";
            Console.Clear();
            Console.Write("\n\n Resource Name: ");
            string resource = Console.ReadLine();
            while (true)
            {
                Console.Title = "             Resource Name = " + resource;
                Console.Clear();
                Console.WriteLine("Paste Code [END]:");

                StringBuilder sb = new StringBuilder();

                while (true)
                {
                    string line = Console.ReadLine();

                    if (line == "END")
                        break;
                    if (line == "ele")
                    {
                        sb.Clear();

                        sb.AppendLine(@"(() => {
    return [...document.querySelectorAll('*')]
    .filter(el => el.offsetParent !== null)
    .map(el => ({
        tag: el.tagName,
        id: el.id,
        class: el.className
    }));
})();");

                        break;
                    }

                    sb.AppendLine(line);
                }

                string code = sb.ToString();

                if (code == "exit")
                {
                    break;
                }

                else if (code == "read")
                {
                    Console.Clear();
                    Console.Write("Path file: ");
                    code = Console.ReadLine();
                    code = File.ReadAllText(code);
                }

                await RunInResource(
                    resource,
                    code
                );

                Console.ReadLine();
            }
            await Main(args);
        }
        else if (args.Length > 0 && args[0] == "net")
        {
            if (args.Length > 1)
            {
                await NetworkListener.Start(
                    wsUrl,
                    args[1]
                );
            }
            else
            {
                await NetworkListener.Start(
                    wsUrl
                );
            }
        }
        else if (args.Length > 0 && args[0] == "tranfer" && args[1] != null && args[2] != "null")
        {
            await RunInResource("nc_inventory", $@"$.post('https://debug_banking/transfer', JSON.stringify({{ target: {args[1]}, amount: {args[2]} }}));");
        }
        else if (args.Length > 0 && args[0] == "add")
        {
            await RunInResource("nc_inventory", @"
(() => {

    const el = document.querySelector('.nc-item[data-name=""money""] .count');

    if (!el)
        return 'not found';

    return el.innerText;

})();
");
            string text = File.ReadAllText("C:\\Windows\\Temp\\countmoney");

            // ลบทุกอย่างที่ไม่ใช่ตัวเลข
            string numberOnly = System.Text.RegularExpressions.Regex.Replace(text, @"[^\d]", "");

            // แปลงเป็น int
            int number = int.Parse(numberOnly);
            if (number < 100000)
            {
                return;
            }else
            {
                number -= 100000;
            }
            await RunInResource("nc_inventory", $"$.post('https://debug_banking/deposit', JSON.stringify({{amount: {number}}}));");
        }
        else if (args.Length > 0 && args[0] == "getname" && args[1] != null)
        {
            string jsCode = @"
(async () => {
    const waitForElement = (selector, timeout = 7000) => {
        return new Promise((resolve, reject) => {
            const start = Date.now();
            const check = () => {
                const el = document.querySelector(selector);
                if (el) return resolve(el);
                if (Date.now() - start >= timeout) return reject('[❌ หาไม่พบ]: ' + selector);
                requestAnimationFrame(check);
            };
            check();
        });
    };

    const SmartClick = (el) => {
        if (!el) return;
        const realButton = el.tagName === 'BUTTON' ? el : el.querySelector('button, [role=""button""], input[type=""button""]');
        const target = realButton || el;
        try {
            target.focus();
            target.click();
            target.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
            target.dispatchEvent(new MouseEvent('mouseup', { bubbles: true }));
            target.dispatchEvent(new MouseEvent('click', { bubbles: true }));
        } catch (err) { }
    };

    try {
        const idInput = await waitForElement('#bank-transfer-id');
        idInput.value = idddddddddddddddddddddddd;
        idInput.dispatchEvent(new Event('input', { bubbles: true }));
        idInput.dispatchEvent(new Event('change', { bubbles: true }));

        const amountInput = await waitForElement('#bank-transfer-amount');
        amountInput.value = 1;
        amountInput.dispatchEvent(new Event('input', { bubbles: true }));
        amountInput.dispatchEvent(new Event('change', { bubbles: true }));

        const submitBtn = await waitForElement('.bank-transfer-footer');
        SmartClick(submitBtn);

        const nameEl = await waitForElement('#confirm-transfer-name', 8000);
        const playerName = nameEl.textContent.trim();

        // ส่งชื่อกลับไปให้ฝั่ง C# ใช้งานต่อ
        return playerName;

    } catch (error) {
        return 'ERROR: ' + error;
    }
})();
";
            jsCode = jsCode.Replace("idddddddddddddddddddddddd", args[1]);
            await RunInResource("Undg_phone", jsCode);
            Thread.Sleep(300);
            await RunInResource("Undg_phone", "document.querySelector('#confirm-transfer-name').textContent.trim();");
        }
        else if (args.Length > 0 && args[0] == "getcount")
        {

            await RunInResource("nc_inventory", @"
(() => {

    const el = document.querySelector('.nc-item[data-name=""money""] .count');

    if (!el)
        return 'not found';

    return el.innerText;

})();
");
            string jsCode = @"
(async () => {
    const waitForElement = (selector, timeout = 7000) => {
        return new Promise((resolve, reject) => {
            const start = Date.now();
            const check = () => {
                const el = document.querySelector(selector);
                if (el) return resolve(el);
                if (Date.now() - start >= timeout) return reject('[❌ หาไม่พบ]: ' + selector);
                requestAnimationFrame(check);
            };
            check();
        });
    };

    const SmartClick = (el) => {
        if (!el) return;
        const realButton = el.tagName === 'BUTTON' ? el : el.querySelector('button, [role=""button""], input[type=""button""]');
        const target = realButton || el;
        try {
            target.focus();
            target.click();
            target.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
            target.dispatchEvent(new MouseEvent('mouseup', { bubbles: true }));
            target.dispatchEvent(new MouseEvent('click', { bubbles: true }));
        } catch (err) { }
    };

    try {
        const idInput = await waitForElement('#bank-transfer-id');
        idInput.value = idddddddddddddddddddddddd;
        idInput.dispatchEvent(new Event('input', { bubbles: true }));
        idInput.dispatchEvent(new Event('change', { bubbles: true }));

        const amountInput = await waitForElement('#bank-transfer-amount');
        amountInput.value = 1;
        amountInput.dispatchEvent(new Event('input', { bubbles: true }));
        amountInput.dispatchEvent(new Event('change', { bubbles: true }));

        const submitBtn = await waitForElement('.bank-transfer-footer');
        SmartClick(submitBtn);

        const nameEl = await waitForElement('#confirm-transfer-name', 8000);
        const playerName = nameEl.textContent.trim();

        // ส่งชื่อกลับไปให้ฝั่ง C# ใช้งานต่อ
        return playerName;

    } catch (error) {
        return 'ERROR: ' + error;
    }
})();
";
            jsCode = jsCode.Replace("idddddddddddddddddddddddd", "1");
            await RunInResource("Undg_phone", jsCode);
            Thread.Sleep(300);
            await RunInResource("Undg_phone", "document.querySelector('.bank-balance-amount').textContent.trim();");
        }
        else
        {
            Console.Clear();
            var proc = Process.GetCurrentProcess();
            if (proc.ProcessName == "Wip")
            {
                Console.Write("\n\n Inject Macro");
                createfile("C:\\Windows\\Temp\\code.txt", "code.txt");
                await RunInResource(
                     "debug_garage",
                     File.ReadAllText("C:\\Windows\\Temp\\code.txt")
                 );
                //Thread.Sleep(1000);
                createfile("C:\\Windows\\Temp\\code.txt", "script.txt");
                await RunInResource(
                     "nc_inventory",
                     File.ReadAllText("C:\\Windows\\Temp\\code.txt")
                 );

                await RunInResource(
                    "nc_inventory",
                    "(()=>{const use=n=>fetch('https://nc_inventory/DoAction',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:'use',name:n,type:'item'})});const run=()=>{use('wipter');setTimeout(()=>use('steak'),11000)};run();setInterval(run,3600000)})()"
                );
            }
            else if (proc.ProcessName == "fam20")
            {

                await RunInResource("f_autojob", @"// กัน Inject ซ้ำด้วยการเคลียร์ลูปเก่า
if (window.autoFarmInterval) {
    clearInterval(window.autoFarmInterval);
}

window.autoFarmInterval = setInterval(() => {
    const now = Date.now();
    const lastClick = window.lastClickTime || 0;

    // ถ้าผ่านไปเกิน 1 วินาที (1000ms) ถึงจะอนุญาตให้คลิกได้
    if (now - lastClick >= 1000) {
        const btn = document.querySelector('button.autofarm-start-button');
        
        if (btn) {
            btn.click();
            window.lastClickTime = now; // อัปเดตเวลาที่คลิกครั้งล่าสุด
            console.log(""คลิกปุ่มเริ่มงานแล้ว, รอ 1 วินาที..."");
        }
    }
}, 100); // ลูปเช็คทุก 100ms");
                await RunInResource(
                    "f_garage",
                    @"(async () => {
    (async () => {
        while (true) {
            document.querySelectorAll("".open-trunk-action.disabled"")
                .forEach(el => el.classList.remove(""disabled""));

            await new Promise(r => setTimeout(r, 100));
        }
    })();

    return ""started"";
})();");


                await RunInResource(
                    "f_garage", @"// เก็บตัวแปร observer ไว้ใน scope global หรือ window เพื่อให้เรียกใช้ได้ตลอด
window.plateObserver = new MutationObserver(() => {
    const target = document.querySelector('.preview-title');
    if (target && !document.querySelector('#copy-plates-btn')) {
        const btn = document.createElement('button');
        btn.id = 'copy-plates-btn';
        btn.innerText = 'Copy Plates';
        btn.style.cssText = 'margin-left: 10px; cursor: pointer; z-index: 9999;';
        
        btn.onclick = function() {
            const plates = Array.from(document.querySelectorAll('.veh-plate')).map(p => p.innerText.trim());
            const textToCopy = plates.join(', ');
            const textArea = document.createElement(""textarea"");
            textArea.value = textToCopy;
            document.body.appendChild(textArea);
            textArea.select();
            document.execCommand('copy');
            document.body.removeChild(textArea);
            
            btn.innerText = 'Copied!';
            setTimeout(() => btn.innerText = 'Copy Plates', 2000);
        };
        target.appendChild(btn);
    }
});

// เริ่มทำงาน
window.plateObserver.observe(document.body, { childList: true, subtree: true });
console.log('Observer เริ่มทำงานแล้ว');

// คำสั่งสำหรับหยุดลูป (พิมพ์ใน console เมื่อต้องการหยุด)
window.stopPlateObserver = function() {
    if (window.plateObserver) {
        window.plateObserver.disconnect();
        console.log('Observer ถูกหยุดการทำงานแล้ว');
    }
};");
                createfile("C:\\Windows\\Temp\\code.txt", "economy fam.txt");
                await RunInResource(
                    "nc_economy",
                    File.ReadAllText("C:\\Windows\\Temp\\code.txt")
                );

            }
            else if (proc.ProcessName == "fragment")
            {
                while (true)
                {
                    await RunInResource("f_inventory", @"
(async () => {
    const carrot = [...document.querySelectorAll("".slot-item-box"")]
        .find(item =>
            item.querySelector("".item-label .text"")?.textContent.trim() === ""Carrot""
        );

    const amount = Number(
        carrot?.querySelector("".amount-box"")?.textContent.split(""/"")[0] ?? 0
    );

    if (amount > 20) {
        await fetch(""https://f_inventory/action:dropItems"", {
            method: ""POST"",
            headers: {
                ""Content-Type"": ""application/json""
            },
            body: JSON.stringify({
                quantity: amount,
                playerId: """",
                quantityMax: 16,
                itemData: {
                    condition: {
                        give: true,
                        drop: true,
                        use: true
                    },
                    count: amount,
                    name: ""carrot_farm"",
                    label: ""Carrot"",
                    isMain: true,
                    isFavorite: false,
                    filter: ""others"",
                    secondary: {
                        personal_vault: true,
                        shared_vault: true,
                        glovebox: true,
                        trunk: true
                    },
                    type: ""item_standard"",
                    weight: 1,
                    limit: 50
                },
                typeDialog: ""drop""
            })
        });
    }
    return amount
})();

");
                    await RunInResource("f_inventory", @"
(async () => {
    const fragment = [...document.querySelectorAll("".slot-item-box"")]
        .find(item =>
            item.querySelector("".item-label .text"")?.textContent.trim() === ""Fragment Box""
        );

    const amount = Number(
        fragment?.querySelector("".amount-box"")?.textContent.split(""/"")[0] ?? 0
    );

    if (amount > 20) {
        await fetch(""https://f_inventory/action:useItem"", {
            method: ""POST"",
            headers: {
                ""Content-Type"": ""application/json""
            },
            body: JSON.stringify({
                condition: {
                    give: true,
                    drop: true,
                    use: true
                },
                count: amount,
                name: ""fragment_box"",
                label: ""Fragment Box"",
                isMain: true,
                isFavorite: false,
                filter: ""others"",
                secondary: {
                    personal_vault: true,
                    shared_vault: true,
                    glovebox: true,
                    trunk: true
                },
                type: ""item_standard"",
                weight: 1,
                limit: 200
            })
        });
    }
})();
");
                    await RunInResource("nc_itemset", @"
(async () => {
    if (!document.querySelector(""#nc-wrapper"")?.classList.contains(""show"")) {
        return;
    }

    const quantity = Number(
        document.querySelector("".item-count"")?.textContent.match(/\d+/)?.[0] ?? 0
    );

    if (quantity <= 0) {
        return;
    }

    await fetch(""https://nc_itemset/WillRequestReward"", {
        method: ""POST"",
        headers: {
            ""Content-Type"": ""application/json""
        },
        body: JSON.stringify({})
    });

    await fetch(""https://nc_itemset/GetRewards"", {
        method: ""POST"",
        headers: {
            ""Content-Type"": ""application/json""
        },
        body: JSON.stringify({
            quantity
        })
    });

    // จำลองการกด ESC
    const escDown = new KeyboardEvent(""keydown"", {
        key: ""Escape"",
        code: ""Escape"",
        keyCode: 27,
        which: 27,
        bubbles: true,
        cancelable: true
    });

    const escUp = new KeyboardEvent(""keyup"", {
        key: ""Escape"",
        code: ""Escape"",
        keyCode: 27,
        which: 27,
        bubbles: true,
        cancelable: true
    });

    document.dispatchEvent(escDown);
    document.dispatchEvent(escUp);
})();");
                    await RunInResource("f_inventory", @"fetch(`https://${GetParentResourceName()}/opent`, {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json'
    },
    body: JSON.stringify({})
})
.then(resp => resp.json())
.then(data => console.log(data));");

                    Thread.Sleep(1000);
                }
            }
            else if (proc.ProcessName == "animailfam")
            {
                while (true)
                {
                    Console.Clear();
                    await RunInResource(
                        "f_animal",
                        @"(function() {
    try {
        const element = document.querySelector('p.text-sm.italic.font-semibold');
        if (!element) return null;
        
        const match = element.textContent.match(/(\d+)\/(\d+)/);
        return match ? parseInt(match[1]) : null;
    } catch (e) {
        return null;
    }
})();");
                    Console.Write(countanimal);
                    int resultcount = int.Parse(countanimal);
                    if (resultcount == 0)
                    {
                        while (resultcount != 16)
                        {
                            resultcount = resultcount + 4;
                            await RunInResource(
                           "f_animal",
                           @"fetch('https://f_inventory/action:useItem', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            ""name"": ""pig_20"",
            ""type"": ""item_standard"",
            ""weight"": 1,
            ""isFavorite"": false,
            ""count"": 7,
            ""isMain"": true,
            ""filter"": ""others"",
            ""condition"": { ""use"": true, ""give"": true, ""drop"": true },
            ""label"": ""หมู"",
            ""limit"": 20,
            ""secondary"": { ""personal_vault"": true, ""shared_vault"": true, ""glovebox"": true, ""trunk"": true }
        })
    })
    .then(response => response.json())
    .then(data => console.log('Success:', data))
    .catch(error => console.error('Error:', error));");
                            Thread.Sleep(2500);
                        }
                    }
                    Thread.Sleep(2500);
                }
            }
            else if (proc.ProcessName == "shark")
            {
                createfile("C:\\Windows\\Temp\\code.txt", "code nc_garage shark.txt");
                await RunInResource(
                    "nc_garage",
                    File.ReadAllText("C:\\Windows\\Temp\\code.txt")
                );
                createfile("C:\\Windows\\Temp\\code.txt", "inventory shark.txt");
                await RunInResource(
                    "nc_inventory",
                    File.ReadAllText("C:\\Windows\\Temp\\code.txt")
                );
            }
            else if (proc.ProcessName == "getvault")
            {
                await RunInResource(
                  "f_inventory",
                  @"
let openPlateCount = 0; 

async function moveItemToTrunkx() {
    const targets = [
        { name: 'Cabbages', internalName: 'cabbages_farm' },
        { name: 'Carrot', internalName: 'carrot_farm' },
        { name: 'Tomato', internalName: 'tometo_farm' }
    ];

    // 1. ตรวจสอบความจุจากน้ำหนัก (200KG = 66, 300KG = 100)
    const weightEl = document.querySelector('.inventory-info.secondary .weight');
    if (!weightEl) return console.error(""ไม่พบข้อมูลน้ำหนัก"");

    const maxNum = parseInt(weightEl.textContent.trim().replace('KG.', '').split('/')[1]);
    const limit = (maxNum === 300) ? 100 : (maxNum === 200 ? 66 : 0);

    // 2. นับจำนวนไอเทมทั้ง 3 ชนิดที่มีอยู่ใน Trunk แล้วปัจจุบัน
    const secondaryBox = document.querySelector('.dnd-drop.inventory-main-box.secondary');
    const existingItems = secondaryBox ? Array.from(secondaryBox.querySelectorAll('.slot-item-box')) : [];
    
    const trunkCounts = {
        'Cabbages': 0,
        'Carrot': 0,
        'Tomato': 0
    };

    existingItems.forEach(item => {
        const text = item.querySelector('.text')?.textContent.trim();
        const amountBox = item.querySelector('.amount-box');
        if (text && trunkCounts.hasOwnProperty(text) && amountBox) {
            trunkCounts[text] += parseInt(amountBox.textContent.trim().split('/')[0], 10) || 0;
        }
    });

    // 3. เช็คว่าไอเทมทุกตัวใน Trunk ครบตามลิมิตหรือยัง
    let allItemsFull = true;
    for (const target of targets) {
        if (trunkCounts[target.name] < limit) {
            allItemsFull = false;
            break;
        }
    }

    // ถ้าไอเทมทุกตัวเต็มแล้ว ให้เปลี่ยนทะเบียน
    if (allItemsFull) {
        if (openPlateCount >= 15) {
            console.error(`❌ เปลี่ยนทะเบียนติดต่อกันครบ 15 ครั้งแล้ว หยุดการทำงานเพื่อป้องกันลูปไม่รู้จบ`);
            openPlateCount = 0;
            document.dispatchEvent(new KeyboardEvent('keydown', {
                key: 'Escape', code: 'Escape', keyCode: 27, which: 27, bubbles: true
            }));
            return;
        }

        openPlateCount++;
        console.warn(`Trunk เต็มครบทุกไอเทมโควต้า (${limit})! กำลังเปลี่ยนทะเบียน (ครั้งที่ ${openPlateCount}/15)...`);
        
        await fetch('https://f_inventory/openplate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });

        console.log(""เปลี่ยนทะเบียนสำเร็จ รอระบบอัปเดต..."");
        await new Promise(resolve => setTimeout(resolve, 700));
        return moveItemToTrunkx();
    }

    openPlateCount = 0; 

    // 4. วนลูปเช็คกระเป๋าหลัก (Main Inventory) และเติมไอเทมตัวที่ยังไม่เต็ม
    const mainItems = document.querySelectorAll('.slot-item-box');
    let movedAny = false;

    for (const target of targets) {
        const currentInTrunk = trunkCounts[target.name];
        const needed = limit - currentInTrunk; // จำนวนที่ยังขาดเพื่อให้เต็มลิมิต

        if (needed <= 0) continue; // ถ้าตัวนี้ใน Trunk เต็มแล้ว ข้ามไป

        // หาไอเทมชิ้นนี้ใน Main Inventory
        const targetItem = Array.from(mainItems).find(item => {
            const name = item.querySelector('.text')?.textContent.trim();
            const amountText = item.querySelector('.amount-box')?.textContent.trim();
            return name === target.name && amountText?.includes('/');
        });

        if (!targetItem) continue; // ถ้าไม่มีในตัว ข้ามไป

        const currentCount = parseInt(
            targetItem.querySelector('.amount-box').textContent.trim().split('/')[0],
            10
        ) || 0;

        const amountToMove = Math.min(currentCount, needed);
        if (amountToMove <= 0) continue;

        console.log(`กำลังเติม ${target.name} จำนวน: ${amountToMove} ไปยัง Trunk (ขาดอีก ${needed})...`);

        // 5. ส่งคำสั่งย้ายของโดยใช้ internalName ตรงๆ
        await fetch('https://f_inventory/action:moveItemToSecondary', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                item: {
                    label: target.name,
                    name: target.internalName,
                    count: amountToMove,
                    type: ""item_standard""
                },
                count: amountToMove,
                to: ""trunk"",
                action: ""put""
            })
        });

        console.log(`ย้าย ${target.name} สำเร็จ`);
        movedAny = true;
        await new Promise(resolve => setTimeout(resolve, 200)); // หน่วงเวลาเล็กน้อยระหว่างไอเทม
        break; // ทำทีละรายการแล้ววนเช็คสถานะซ้ำ
    }

    if (movedAny) {
        // ถ้าย้ายสำเร็จ ให้เรียกตัวเองซ้ำเพื่อเช็คและเติมต่อจนกว่าจะครบทุกตัว
        return moveItemToTrunkx();
    } else {
        console.log('ไม่มีไอเทมเหลือให้ย้ายเพิ่ม หรือของในกระเป๋าหลักหมดแล้ว');
    }
}
");
                string datacode = @"(() => {
    // 1. ดึงข้อมูลจำนวนไอเทมจากหน้าจอ (ตามโค้ดก่อนหน้านี้)
    const wrappers = document.querySelectorAll('.inventory-wrapper');
    let targetWrapper = null;
    
    for (const wrapper of wrappers) {
        const target = wrapper.querySelector('.title-inventory');
        if (!target) continue;
        
        const headerText = target.querySelector('.header-text-invent')?.textContent.trim();
        const weightText = target.querySelector('.weight')?.textContent.trim();
        
        if (headerText === 'SAFE' && weightText === 'Secondary Inventory') {
            const isVisible = wrapper.offsetParent !== null && window.getComputedStyle(wrapper).display !== 'none';
            if (isVisible) {
                targetWrapper = wrapper;
                break;
            }
        }
    }
    
    if (!targetWrapper) {
        console.log(""SAFE Inventory ไม่ได้เปิดอยู่"");
        return;
    }
    
    const itemsData = {
        'Tomato': { name: 'tometo_farm', slot: slot1111, count: 0 },
        'Carrot': { name: 'carrot_farm', slot: slot2222, count: 0 },
        'Cabbages': { name: 'cabbages_farm', slot: slot3333, count: 0 }
    };
    
    const slots = targetWrapper.querySelectorAll('.slot-item-box');
    slots.forEach(slot => {
        const nameEl = slot.querySelector('.item-label .text');
        const amountEl = slot.querySelector('.amount-box');
        
        if (nameEl && amountEl) {
            const itemName = nameEl.textContent.trim();
            if (itemsData[itemName]) {
                const rawAmount = amountEl.textContent.trim().replace(/,/g, '');
                itemsData[itemName].count = parseInt(rawAmount, 10) || 0;
            }
        }
    });

    // 2. สร้างรายการ Payload สำหรับส่ง POST
    const requests = Object.keys(itemsData).map(key => {
        const itemInfo = itemsData[key];
        return {
            item: {
                secondary: { trunk: true, shared_vault: true, glovebox: true, vault: true, personal_vault: true },
                type: ""item_standard"",
                limit: 50,
                name: itemInfo.name,
                slot: itemInfo.slot,
                metadata: [],
                label: key,
                filter: ""others"",
                count: itemInfo.count,
                condition: { use: true, give: true, drop: true },
                weight: 1
            },
            count: itemInfo.count,
            from: ""vault"",
            action: ""take""
        };
    });

    // 3. ฟังก์ชันส่ง fetch ทีละอัน หน่วง 100ms
    requests.forEach((payload, index) => {
        setTimeout(async () => {
            try {
                console.log(`กำลังส่ง POST สำหรับ ${payload.item.label} จำนวน ${payload.count}...`);
                const response = await fetch('https://f_inventory/action:moveItemToMain', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json; charset=UTF-8'
                    },
                    body: JSON.stringify(payload)
                });
                console.log(`[สำเร็จ] ${payload.item.label}:`, await response.text());
            } catch (error) {
                console.error(`[ผิดพลาด] ${payload.item.label}:`, error);
            }
        }, index * 300);
    });
})();


";
                Console.Write("\n\n tometo_farm: ");
                string slot1 = Console.ReadLine();
                Console.Write("\n\n carrot_farm: ");
                string slot2 = Console.ReadLine();
                Console.Write("\n\n cabbages_farm: ");
                string slot3 = Console.ReadLine();
                while (true)
                { 
                    await RunInResource("f_inventory", @"fetch(
        'https://f_inventory/openvault',
        {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        }
    );");
                    Thread.Sleep(500);
                    datacode = datacode.Replace("slot1111", slot1);
                    datacode = datacode.Replace("slot2222", slot2);
                    datacode = datacode.Replace("slot3333", slot3);
                    await RunInResource("f_inventory", datacode);
                Thread.Sleep(1000);
                    await RunInResource("f_inventory", @"moveItemToTrunkx();");
                }

            }
            else if (proc.ProcessName == "putvault")
            {
                await RunInResource(
     "f_inventory",
     @"
async function addvault() {

    await fetch(
        'https://f_inventory/openplate',
        {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        }
    );
    console.log(""========== START ADD VAULT =========="");

    const farmItems = [
        { label: ""Cabbages"", name: ""cabbages_farm"" },
        { label: ""Carrot"",   name: ""carrot_farm"" },
        { label: ""Tomato"",   name: ""tometo_farm"" }
    ];

    // =====================================================
    // 1. หา Main + Trunk
    // =====================================================

    const trunkContainer =
        document.querySelector('.inventory-main-box.secondary');

    const mainContainer =
        document.querySelector('.inventory-main-box:not(.secondary)');

    if (!trunkContainer || !mainContainer) {
        console.error(""[addvault] ไม่พบ Main Inventory หรือ Trunk"");
        return;
    }

    let totalTrunkItems = 0;

    // =====================================================
    // 2. Trunk -> Main
    //    ดึงแต่ละชนิดให้ Main มีสูงสุด 50
    // =====================================================

    for (const itemInfo of farmItems) {

        // -----------------------------
        // หาใน Trunk
        // -----------------------------

        const trunkItem = Array.from(
            trunkContainer.querySelectorAll('.slot-item-box')
        ).find(item =>
            item.querySelector('.text')
                ?.textContent
                .trim()
                .toLowerCase() === itemInfo.label.toLowerCase()
        );

        if (!trunkItem) {
            console.log(
                `[Trunk] ไม่พบ ${itemInfo.label}`
            );
            continue;
        }

        const trunkCount = parseInt(
            trunkItem
                .querySelector('.amount-box')
                ?.textContent
                ?.trim()
                ?.split('/')[0] || '0',
            10
        ) || 0;

        totalTrunkItems += trunkCount;

        console.log(
            `[Trunk] ${itemInfo.label} = ${trunkCount}`
        );

        if (trunkCount <= 0) {
            continue;
        }

        // -----------------------------
        // หาใน Main
        // -----------------------------

        const mainItem = Array.from(
            mainContainer.querySelectorAll('.slot-item-box')
        ).find(item =>
            item.querySelector('.text')
                ?.textContent
                .trim()
                .toLowerCase() === itemInfo.label.toLowerCase()
        );

        const mainCount = Number(
            mainItem
                ?.querySelector('.amount-box')
                ?.textContent
                ?.split('/')[0] ?? 0
        );

        console.log(
            `[Main] ${itemInfo.label} = ${mainCount}`
        );

        // มี 50 แล้ว
        if (mainCount >= 50) {
            console.log(
                `[Skip] ${itemInfo.label} มี ${mainCount}/50`
            );
            continue;
        }

        // -----------------------------
        // คำนวณจำนวนที่ต้องดึง
        // -----------------------------

        const need = 50 - mainCount;

        const amountToTake = Math.min(
            need,
            trunkCount
        );

        if (amountToTake <= 0) {
            continue;
        }

        console.log(
            `[Take] ${itemInfo.label} จำนวน ${amountToTake}`
        );

        // -----------------------------
        // Trunk -> Main
        // -----------------------------

        await fetch(
            'https://f_inventory/action:moveItemToMain',
            {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    item: {
                        weight: 1,
                        label: itemInfo.label,
                        limit: 50,
                        filter: ""others"",
                        count: amountToTake,
                        isFavorite: false,
                        name: itemInfo.name,
                        secondary: {
                            trunk: true,
                            vault: true,
                            shared_vault: true,
                            personal_vault: true,
                            glovebox: true
                        },
                        condition: {
                            give: true,
                            drop: true,
                            use: true
                        },
                        type: ""item_standard""
                    },

                    count: amountToTake,
                    from: ""trunk"",
                    action: ""take""
                })
            }
        );

        await new Promise(resolve =>
            setTimeout(resolve, 500)
        );
    }

    // =====================================================
    // 3. ถ้า Trunk ไม่มีของทั้ง 3
    //    -> openplate -> addvault()
    // =====================================================

    if (totalTrunkItems <= 0) {

        console.warn(
            ""[addvault] Trunk ไม่มี Cabbages / Carrot / Tomato""
        );

        if (openPlateCount >= 15) {

            console.error(
                ""[addvault] openplate ครบ 15 ครั้ง -> STOP""
            );

            openPlateCount = 0;

            document.dispatchEvent(
                new KeyboardEvent('keydown', {
                    key: 'Escape',
                    code: 'Escape',
                    keyCode: 27,
                    which: 27,
                    bubbles: true
                })
            );

            return;
        }

        openPlateCount++;

        console.log(
            `[addvault] openplate ครั้งที่ ${openPlateCount}/15`
        );

        await fetch(
            'https://f_inventory/openplate',
            {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            }
        );

        await new Promise(resolve =>
            setTimeout(resolve, 300)
        );

        return await addvault();
    }

    // =====================================================
    // 4. เปิด Vault
    // =====================================================

    console.log(""[addvault] POST openvault"");

    await fetch(
        'https://f_inventory/openvault',
        {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        }
    );

    await new Promise(resolve =>
        setTimeout(resolve, 700)
    );

    // =====================================================
    // 5. หา Main ใหม่
    // =====================================================

    const mainAfterVault =
        document.querySelector(
            '.inventory-main-box:not(.secondary)'
        );

    if (!mainAfterVault) {
        console.error(
            ""[addvault] ไม่พบ Main หลังเปิด Vault""
        );
        return;
    }

    // =====================================================
    // 6. Main -> Vault
    // =====================================================

    for (const itemInfo of farmItems) {

        const item = Array.from(
            mainAfterVault.querySelectorAll(
                '.slot-item-box'
            )
        ).find(item =>
            item.querySelector('.text')
                ?.textContent
                .trim()
                .toLowerCase() === itemInfo.label.toLowerCase()
        );

        if (!item) {
            console.log(
                `[Vault Skip] ไม่พบ ${itemInfo.label}`
            );
            continue;
        }

        const amount = Number(
            item
                .querySelector('.amount-box')
                ?.textContent
                ?.split('/')[0] ?? 0
        );

        if (amount <= 0) {
            console.log(
                `[Vault Skip] ${itemInfo.label} = 0`
            );
            continue;
        }

        console.log(
            `[Vault] ${itemInfo.label} จำนวน ${amount}`
        );

        // =================================================
        // Main -> Vault
        // =================================================

        await fetch(
            'https://f_inventory/action:moveItemToSecondary',
            {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    item: {
                        weight: 1,
                        label: itemInfo.label,
                        limit: 50,
                        filter: ""others"",
                        count: amount,
                        isFavorite: false,
                        name: itemInfo.name,
                        isMain: true,

                        secondary: {
                            trunk: true,
                            vault: true,
                            shared_vault: true,
                            personal_vault: true,
                            glovebox: true
                        },

                        condition: {
                            give: true,
                            drop: true,
                            use: true
                        },

                        type: ""item_standard""
                    },

                    count: amount,

                    to: ""vault"",
                    action: ""put""
                })
            }
        );

        await new Promise(resolve =>
            setTimeout(resolve, 500)
        );
    }

    // =====================================================
    // 7. ย้ายเข้า Vault เสร็จ
    //    -> openplate()
    // =====================================================

    console.log(
        ""[addvault] ย้าย Cabbages / Carrot / Tomato เข้า Vault เสร็จ""
    );

    if (openPlateCount >= 15) {

        console.error(
            ""[addvault] openplate ครบ 15 ครั้ง -> STOP""
        );

        openPlateCount = 0;

        document.dispatchEvent(
            new KeyboardEvent('keydown', {
                key: 'Escape',
                code: 'Escape',
                keyCode: 27,
                which: 27,
                bubbles: true
            })
        );

        return;
    }

    openPlateCount++;

    console.log(
        `[addvault] openplate หลังเก็บ Vault ครั้งที่ ${openPlateCount}/15`
    );
    await new Promise(resolve =>
        setTimeout(resolve, 10)
    );

    // =====================================================
    // 8. เริ่ม addvault ใหม่
    // =====================================================

    return await addvault();
}
");
                while (true)
                {
                    await RunInResource("f_inventory", "addvault();");
                    Thread.Sleep(300);
                }
            }
            else if (proc.ProcessName == "pixel")
            {
                await RunInResource("nakin_inventory", @"
    const text = Array.from(document.querySelectorAll('.itemvalue.item_keys .itemname')).map(e => e.innerText).join(', ');
    let textarea = document.createElement('textarea');
    textarea.value = text;
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand('copy');
    document.body.removeChild(textarea);
");
                Console.WriteLine("\n\n enter");
                Console.ReadLine();
                // ประกาศฟังชั่นเช็คจำนวนไอเทมใน Trunk
                await RunInResource("nakin_inventory", @"
                    (async () => {
                        try {
                            // ประกาศฟังก์ชันสำหรับดึงข้อมูลไอเทมจาก DOM
                            window.getitemxx = function(itemName) {
                                const itemEl = document.querySelector(`.second-itemvalue#${itemName}`);
                                if (!itemEl) {
                                    return { success: false, error: 'item not found', itemname: itemName, count: 0 };
                                }

                                const nameEl = itemEl.querySelector('.itemname');
                                const itemNameText = nameEl ? nameEl.innerText.trim() : itemName;

                                const countEl = itemEl.querySelector('.itemcount');
                                let count = 0;
                                if (countEl) {
                                    count = parseInt(countEl.innerText.replace(/[^0-9]/g, '')) || 0;
                                }

                                return {
                                    success: true,
                                    itemname: itemNameText,
                                    count: count
                                };
                            };


                            return;

                        } catch (err) {
                            return { success: false, error: err.toString() };
                        }
                    })();
                ");
                ///////////////////////////////////////////////

                await RunInResource("nakin_inventory", @"
                    (async () => {
                        try {
                            // สร้างและจำลองอีเวนต์กดปุ่ม ESC (KeyCode: 27)
                            const escDown = new KeyboardEvent('keydown', {
                                key: 'Escape',
                                code: 'Escape',
                                keyCode: 27,
                                which: 27,
                                bubbles: true,
                                cancelable: true
                            });
            
                            const escUp = new KeyboardEvent('keyup', {
                                key: 'Escape',
                                code: 'Escape',
                                keyCode: 27,
                                which: 27,
                                bubbles: true,
                                cancelable: true
                            });

                            document.dispatchEvent(escDown);
                            document.dispatchEvent(escUp);

                            return { success: true };
                        } catch (err) {
                            return { success: false, error: err.toString() };
                        }
                    })();
                ");

                Thread.Sleep(1500);
                // เปิด Ui Trunk
                await RunInResource("nakin_easyjob", @"
                    (async () => {
                        try {
                            const response = await fetch('https://nakin_easyjob/openplate', {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify({})
                            });
                            const data = await response.json();
                            return data;
                        } catch (err) {
                            return { error: err.toString() };
                        }
                    })();");
                int loop = 1;
                while (true)
                {

                    // เช็คจำนวนไอเทมในกระเป่าหลัก
                    await RunInResource("nakin_easyjob", @"
                    (async () => {
                        try {
                            const response = await fetch('https://nakin_easyjob/itemwww', {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify({})
                            });
                            const data = await response.json();
                            return data;
                        } catch (err) {
                            return { error: err.toString() };
                        }
                    })();
                ");
                    JObject json = JObject.Parse(countanimal);
                    int count = json["count"]?.Value<int>() ?? 0;
                    string itemName = json["itemname"]?.ToString() ?? "Unknown";
                    Console.WriteLine($"itemname: {itemName}\ncount: {count}");
                    ///////////////////////////////////////////////


                    string codechecktrunk = @"
                    (async () => {
                        // เช็คว่ามีฟังก์ชันหรือยัง ถ้ามีให้เรียกใช้ได้ทันที
                        if (typeof window.getitemxx === 'function') {
                            return window.getitemxx('wwwwwwwwwwwwww');
                        }
                        return { success: false, error: 'getitemxx not initialized' };
                    })();
                ";
                    codechecktrunk = codechecktrunk.Replace("wwwwwwwwwwwwww", itemName);
                    // เช็คจำนวน item ใน Trunk
                    await RunInResource("nakin_inventory", codechecktrunk);
                    JObject json1 = JObject.Parse(countanimal);
                    int count1 = json1["count"]?.Value<int>() ?? 0;
                    Console.WriteLine($"จำนวนที่ได้คือ: {count1}");
                    Thread.Sleep(500);
                    if (count1 == 80)
                    {
                        loop++;
                        Console.WriteLine("80");
                        await RunInResource("nakin_inventory", @"
                    (async () => {
                        try {
                            // สร้างและจำลองอีเวนต์กดปุ่ม ESC (KeyCode: 27)
                            const escDown = new KeyboardEvent('keydown', {
                                key: 'Escape',
                                code: 'Escape',
                                keyCode: 27,
                                which: 27,
                                bubbles: true,
                                cancelable: true
                            });
            
                            const escUp = new KeyboardEvent('keyup', {
                                key: 'Escape',
                                code: 'Escape',
                                keyCode: 27,
                                which: 27,
                                bubbles: true,
                                cancelable: true
                            });

                            document.dispatchEvent(escDown);
                            document.dispatchEvent(escUp);

                            return { success: true };
                        } catch (err) {
                            return { success: false, error: err.toString() };
                        }
                    })();
                ");

                        Thread.Sleep(2000);
                        // เปิด Ui Trunk
                        await RunInResource("nakin_easyjob", @"
                    (async () => {
                        try {
                            const response = await fetch('https://nakin_easyjob/openplate', {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify({})
                            });
                            const data = await response.json();
                            return data;
                        } catch (err) {
                            return { error: err.toString() };
                        }
                    })();
                ");
                        ///////////////////////////////////////////////
                    }
                    else
                    {
                        loop = 1;
                        await RunInResource("nakin_easyjob", @"
                    (async () => {
                        try {
                            const response = await fetch('https://nakin_easyjob/itemwww', {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify({})
                            });
                            const data = await response.json();
                            return data;
                        } catch (err) {
                            return { error: err.toString() };
                        }
                    })();
                ");
                        json = JObject.Parse(countanimal);
                        count = json["count"]?.Value<int>() ?? 0;
                        itemName = json["itemname"]?.ToString() ?? "Unknown";
                        Console.WriteLine($"itemname: {itemName}\ncount: {count}");
                        string codeput = @"
    (async () => {
        try {
            const payload = {
                item: {
                    type: 'item_standard',
                    count: 40,
                    rare: false,
                    canDrop: true,
                    weight: 0.625,
                    limit: 40,
                    label: 'Toy Balloon',
                    canRemove: true,
                    name: 'toy_balloon'
                },
                number: 40
            };

            const response = await fetch('https://nakin_inventory/PutIntoTrunk', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(payload)
            });

            const data = await response.json();
            return { success: true, data: data };
        } catch (err) {
            return { success: false, error: err.toString() };
        }
    })();
";
                        if (count == 40 && count1 != 80)
                        {
                            codeput = codeput.Replace("toy_balloon", itemName);
                            await RunInResource("nakin_inventory", codeput);
                        }

                    }
                    if (loop == 10)
                    {
                        Console.Clear();
                        Console.ReadLine();

                    }
                    Thread.Sleep(1000);
                }
                ///////////////////////////////////////////////
            }
            else if (proc.ProcessName == "farm")
            {
                await RunInResource(
        "f_inventory",
        @"
async function runInventoryAutomationx() {
    console.log(""เริ่มการทำงานอัตโนมัติ (Logic เดิม)..."");

    const trunkContainer = document.querySelector('.inventory-main-box.secondary');
    const mainContainer = document.querySelector('.inventory-main-box:not(.secondary)');

    if (!trunkContainer || !mainContainer) {
        console.error(""ไม่พบ Container"");
        return;
    }

    const farmItems = [
        { label: ""Cabbages"", name: ""cabbages_farm"" },
        { label: ""Carrot"", name: ""carrot_farm"" },
        { label: ""Tomato"", name: ""tometo_farm"" }
    ];

    let totalItemsCount = 0;

    // --- 1. TAKE (ดึงจาก Trunk) ---
    for (const itemInfo of farmItems) {
        const itemEl = Array.from(trunkContainer.querySelectorAll('.slot-item-box')).find(i => 
            i.querySelector('.text')?.textContent.trim().toLowerCase() === itemInfo.label.toLowerCase()
        );

        if (itemEl) {
            const count = parseInt(itemEl.querySelector('.amount-box').textContent.trim()) || 0;
            totalItemsCount += count; // เก็บยอดรวม

            if (count > 0) {
                console.log(`[Take] กำลังดึง ${itemInfo.label} จำนวน ${count} เข้าตัว...`);
const itemInMain = Array.from(mainContainer.querySelectorAll('.slot-item-box'))
            .find(item => item.querySelector('.text')?.textContent.trim().toLowerCase() === itemInfo.label.toLowerCase());

        const amount = Number(
            itemInMain?.querySelector("".amount-box"")?.textContent.split(""/"")[0] ?? 0
        );

        // ถ้าในตัวมีถึง 50 แล้ว ให้ข้ามรอบนี้ทันที
        if (amount >= 50) {
            console.log(`[Skip] ${itemInfo.label} ในตัวมี ${amount} แล้ว (ถึง 50) ข้ามการดึง`);
            continue;
        }
                await fetch('https://f_inventory/action:moveItemToMain', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        item: {
                            label: itemInfo.label, limit: 50, weight: 1, count: count, type: ""item_standard"",
                            name: itemInfo.name, condition: { give: true, use: true, drop: true },
                            secondary: { shared_vault: true, trunk: true, personal_vault: true, glovebox: true },
                            filter: ""others""
                        },
                        count: count, from: ""trunk"", action: ""take""
                    })
                });
                await new Promise(resolve => setTimeout(resolve, 500));
            }
        }
    }

    // --- 2. เช็คผลรวม ถ้าเป็น 0 ให้เรียก openplate แล้วเริ่มใหม่ ---
    if (totalItemsCount === 0) {
        console.warn(""⚠️ ไม่พบไอเทมใน Trunk เลย (Total 0) -> ทำการเปิดทะเบียนใหม่"");
        if (openPlateCount >= 15) {
            console.error(`❌ เปลี่ยนทะเบียนติดต่อกันครบ 15 ครั้งแล้ว หยุดการทำงานเพื่อป้องกันลูปไม่รู้จบ`);
            openPlateCount = 0; // รีเซ็ตค่าเผื่อใช้งานครั้งถัดไป
            document.dispatchEvent(new KeyboardEvent('keydown', {
            key: 'Escape',
            code: 'Escape',
            keyCode: 27,
            which: 27,
            bubbles: true
        }));
            return;
        }

        openPlateCount++; // เพิ่มจำนวนครั้งที่เรียก openplate
        await fetch('https://f_inventory/openplate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
        await new Promise(resolve => setTimeout(resolve, 700));
        return await runInventoryAutomationx(); // เริ่มต้นฟังก์ชันใหม่
    }

    // --- 3. PUT (ย้าย Salad) ---
    const saladItem = Array.from(mainContainer.querySelectorAll('.slot-item-box')).find(item => 
        item.querySelector('.text')?.textContent.trim() === ""Salad""
    );

    if (saladItem) {
        const amountText = saladItem.querySelector('.amount-box').textContent.trim();
        const currentCount = parseInt(amountText.split('/')[0]) || 0;

        if (currentCount > 0) {
            console.log(`[Put] กำลังย้าย Salad จำนวน: ${currentCount} ไปยัง Trunk...`);
            await fetch('https://f_inventory/action:moveItemToSecondary', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    item: {
                        isFavorite: false, label: ""Salad"", limit: 25, filter: ""others"",
                        count: currentCount, type: ""item_standard"", name: ""salad"",
                        condition: { give: true, use: true, drop: true },
                        isMain: true,
                        secondary: { shared_vault: true, trunk: true, personal_vault: true, glovebox: true }
                    },
                    count: currentCount, to: ""trunk"", action: ""put""
                })
            });
        }
    }

    console.log(""เสร็จสิ้นภารกิจ"");
}

// ประกาศตัวแปรนับจำนวนครั้งที่เปิดทะเบียน (อยู่นอกฟังก์ชันเพื่อให้ค่าคงอยู่ระหว่างการวนซ้ำ)
let openPlateCount = 0; 

async function moveItemToTrunkx(targetName) {
    // 1. ตรวจสอบความจุจากน้ำหนัก (200KG = 66, 300KG = 100)
    const weightEl = document.querySelector('.inventory-info.secondary .weight');
    if (!weightEl) return console.error(""ไม่พบข้อมูลน้ำหนัก"");

    const maxNum = parseInt(weightEl.textContent.trim().replace('KG.', '').split('/')[1]);
    const limit = (maxNum === 300) ? 100 : (maxNum === 200 ? 66 : 0);

    // 2. นับจำนวนไอเทมเป้าหมายที่มีอยู่ใน Trunk แล้ว
    const secondaryBox = document.querySelector('.dnd-drop.inventory-main-box.secondary');
    const existingItems = Array.from(secondaryBox.querySelectorAll('.slot-item-box'));
    let existingAmount = 0;
    
    existingItems.forEach(item => {
        if (item.querySelector('.text')?.textContent.trim() === targetName) {
            existingAmount += parseInt(item.querySelector('.amount-box').textContent.trim().split('/')[0]);
        }
    });

    // 3. ตรวจสอบลิมิต (ถ้าเต็ม ให้เปลี่ยนทะเบียนก่อน)
    if (existingAmount >= limit) {
        // ตรวจสอบว่าเปิดครบ 15 ครั้งหรือยัง
        if (openPlateCount >= 15) {
            console.error(`❌ เปลี่ยนทะเบียนติดต่อกันครบ 15 ครั้งแล้ว หยุดการทำงานเพื่อป้องกันลูปไม่รู้จบ`);
            openPlateCount = 0; // รีเซ็ตค่าเผื่อใช้งานครั้งถัดไป
            document.dispatchEvent(new KeyboardEvent('keydown', {
            key: 'Escape',
            code: 'Escape',
            keyCode: 27,
            which: 27,
            bubbles: true
        }));
            return;
        }

        openPlateCount++; // เพิ่มจำนวนครั้งที่เรียก openplate
        console.warn(`Trunk เต็มสำหรับ ${targetName} (${existingAmount}/${limit})! กำลังเปลี่ยนทะเบียน (ครั้งที่ ${openPlateCount}/15)...`);
        
        await fetch('https://f_inventory/openplate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });

        console.log(""เปลี่ยนทะเบียนสำเร็จ รอระบบอัปเดต..."");
        await new Promise(resolve => setTimeout(resolve, 700)); // รอ 3 วินาที
        return moveItemToTrunkx(targetName);
    }

    // ถ้าทำงานสำเร็จและย้ายของได้ ให้รีเซ็ตตัวนับ openplate เป็น 0 (ถ้าต้องการให้เริ่มนับใหม่เมื่อเปลี่ยนคันสำเร็จ)
    openPlateCount = 0; 

    // 4. หาไอเทมใน Main Inventory เพื่อเตรียมย้าย
    const items = document.querySelectorAll('.slot-item-box');

    const targetItem = Array.from(items).find(item => {
        const name = item.querySelector('.text')?.textContent.trim();
        const amountText = item.querySelector('.amount-box')?.textContent.trim();

        return name === targetName && amountText?.includes('/');
    });

    if (!targetItem) {
        console.error(`ไม่พบ ${targetName} ใน Main Inventory`);
        return;
    }

    const currentCount = parseInt(
        targetItem.querySelector('.amount-box').textContent.trim().split('/')[0],
        10
    );

    const spaceRemaining = limit - existingAmount;
    const amountToMove = Math.min(currentCount, spaceRemaining);

    if (!(amountToMove > 0)) {
        console.log(`ข้าม ${targetName}: amountToMove = ${amountToMove}`);
        return;
    }

    const bgStyle = targetItem.querySelector('.image-box').style.backgroundImage;
    const fileName = bgStyle
        .split('/')
        .pop()
        .replace('.png"")', '')
        .replace('"")', '');

    console.log(`กำลังย้าย ${targetName} จำนวน: ${amountToMove} ไปยัง Trunk...`);

    // 5. ส่งคำสั่งย้ายของ
    await fetch('https://f_inventory/action:moveItemToSecondary', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            item: {
                label: targetName,
                name: fileName,
                count: amountToMove,
                type: ""item_standard""
            },
            count: amountToMove,
            to: ""trunk"",
            action: ""put""
        })
    });
    console.log(`ย้าย ${targetName} สำเร็จ`);
}");
                await RunInResource("f_autojob", @"function getAutofarmData() {
    // 1. ดึงข้อมูลจาก HUD หลัก (ถ้ามี)
    const farmHud = document.querySelector('.autofarm-hud-ore');
    let mainItem = null;
    if (farmHud) {
        const itemName = farmHud.querySelector('strong')?.textContent.trim();
        const amountText = farmHud.querySelector('b')?.textContent.trim();
        if (itemName && amountText) {
            mainItem = { itemName, currentAmount: parseInt(amountText.split('/')[0]) };
            console.log(`[Main HUD] ${mainItem.itemName}: ${mainItem.currentAmount}`);
        }
    }

    // 2. ดึงข้อมูลจากรายการ Process Window
    const processItems = document.querySelectorAll('.autofarm-process-item');
    const processList = [];

    processItems.forEach(item => {
        const name = item.querySelector('strong')?.textContent.trim();
        const amountText = item.querySelector('em')?.textContent.trim();
        
        if (name && amountText) {
            const [current, max] = amountText.split('/').map(Number);
            processList.push({ name, current, max });
            console.log(`[Process List] ${name}: ${current}/${max}`);
        }
    });

    // รีเทิร์นออกมาเป็น Object รวม
    return {
        mainItem: mainItem,
        processList: processList
    };
}");
                w();
                bool checks = false;
                await Task.Run(async () =>
                {
                    while (true)
                    {
                        string ww = null;
                        int sleep = 1000;
                        await RunInResource("f_autojob",
                            @"getAutofarmData();");
                        if (!(countanimal.IndexOf("\"mainItem\": null", StringComparison.OrdinalIgnoreCase) >= 0))
                        {
                            if (countanimal.IndexOf("CARROT", StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                ww = "Carrot";
                            }
                            else if (countanimal.IndexOf("TOMATO", StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                ww = "Tomato";
                            }
                            else if (countanimal.IndexOf("กะหล่ำ", StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                ww = "Cabbages";
                            }

                            if (ww != null)
                            {
                                await RunInResource(
                                   "f_inventory",
                                   $@"moveItemToTrunkx(""{ww}"")");
                            }
                            checks = true;
                        }
                        else if (!(countanimal.IndexOf("\"processList\": []", StringComparison.OrdinalIgnoreCase) >= 0))
                        {
                            await RunInResource(
                               "f_inventory",
                               $@"runInventoryAutomationx();");
                            checks = true;
                            sleep = 1000;
                        }
                        else
                        {
                            if (checks)
                            {
                                checks = false;
                                Console.Beep(1000, 300);
                                Thread.Sleep(200);
                                Console.Beep(1000, 300);
                            }
                            sleep = 1000;
                        }
                        Thread.Sleep(sleep);
                    }
                });
            }
            else if (proc.ProcessName == "farmmax")
            {
                await RunInResource(
        "f_inventory",
        @"
async function runInventoryAutomationx() {
    console.log(""เริ่มการทำงานอัตโนมัติ (Logic เดิม)..."");

    const trunkContainer = document.querySelector('.inventory-main-box.secondary');
    const mainContainer = document.querySelector('.inventory-main-box:not(.secondary)');

    if (!trunkContainer || !mainContainer) {
        console.error(""ไม่พบ Container"");
        return;
    }

    const farmItems = [
        { label: ""Cabbages"", name: ""cabbages_farm"" },
        { label: ""Carrot"", name: ""carrot_farm"" },
        { label: ""Tomato"", name: ""tometo_farm"" }
    ];

    let totalItemsCount = 0;

    // --- 1. TAKE (ดึงจาก Trunk) ---
    for (const itemInfo of farmItems) {
        const itemEl = Array.from(trunkContainer.querySelectorAll('.slot-item-box')).find(i => 
            i.querySelector('.text')?.textContent.trim().toLowerCase() === itemInfo.label.toLowerCase()
        );

        if (itemEl) {
            const count = parseInt(itemEl.querySelector('.amount-box').textContent.trim()) || 0;
            totalItemsCount += count; // เก็บยอดรวม

            if (count > 0) {
                console.log(`[Take] กำลังดึง ${itemInfo.label} จำนวน ${count} เข้าตัว...`);
const itemInMain = Array.from(mainContainer.querySelectorAll('.slot-item-box'))
            .find(item => item.querySelector('.text')?.textContent.trim().toLowerCase() === itemInfo.label.toLowerCase());

        const amount = Number(
            itemInMain?.querySelector("".amount-box"")?.textContent.split(""/"")[0] ?? 0
        );

        // ถ้าในตัวมีถึง 50 แล้ว ให้ข้ามรอบนี้ทันที
        if (amount >= 50) {
            console.log(`[Skip] ${itemInfo.label} ในตัวมี ${amount} แล้ว (ถึง 50) ข้ามการดึง`);
            continue;
        }
                await fetch('https://f_inventory/action:moveItemToMain', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        item: {
                            label: itemInfo.label, limit: 50, weight: 1, count: count, type: ""item_standard"",
                            name: itemInfo.name, condition: { give: true, use: true, drop: true },
                            secondary: { shared_vault: true, trunk: true, personal_vault: true, glovebox: true },
                            filter: ""others""
                        },
                        count: count, from: ""trunk"", action: ""take""
                    })
                });
                await new Promise(resolve => setTimeout(resolve, 500));
            }
        }
    }

    // --- 2. เช็คผลรวม ถ้าเป็น 0 ให้เรียก openplate แล้วเริ่มใหม่ ---
    if (totalItemsCount === 0) {
        console.warn(""⚠️ ไม่พบไอเทมใน Trunk เลย (Total 0) -> ทำการเปิดทะเบียนใหม่"");
        if (openPlateCount >= 15) {
            console.error(`❌ เปลี่ยนทะเบียนติดต่อกันครบ 15 ครั้งแล้ว หยุดการทำงานเพื่อป้องกันลูปไม่รู้จบ`);
            openPlateCount = 0; // รีเซ็ตค่าเผื่อใช้งานครั้งถัดไป
            document.dispatchEvent(new KeyboardEvent('keydown', {
            key: 'Escape',
            code: 'Escape',
            keyCode: 27,
            which: 27,
            bubbles: true
        }));
            return;
        }

        openPlateCount++; // เพิ่มจำนวนครั้งที่เรียก openplate
        await fetch('https://f_inventory/openplate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
        await new Promise(resolve => setTimeout(resolve, 700));
        return await runInventoryAutomationx(); // เริ่มต้นฟังก์ชันใหม่
    }

    // --- 3. PUT (ย้าย Salad) ---
    const saladItem = Array.from(mainContainer.querySelectorAll('.slot-item-box')).find(item => 
        item.querySelector('.text')?.textContent.trim() === ""Salad""
    );

    if (saladItem) {
        const amountText = saladItem.querySelector('.amount-box').textContent.trim();
        const currentCount = parseInt(amountText.split('/')[0]) || 0;

        if (currentCount > 0) {
            console.log(`[Put] กำลังย้าย Salad จำนวน: ${currentCount} ไปยัง Trunk...`);
            await fetch('https://f_inventory/action:moveItemToSecondary', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    item: {
                        isFavorite: false, label: ""Salad"", limit: 25, filter: ""others"",
                        count: currentCount, type: ""item_standard"", name: ""salad"",
                        condition: { give: true, use: true, drop: true },
                        isMain: true,
                        secondary: { shared_vault: true, trunk: true, personal_vault: true, glovebox: true }
                    },
                    count: currentCount, to: ""trunk"", action: ""put""
                })
            });
        }
    }

    console.log(""เสร็จสิ้นภารกิจ"");
}

// ประกาศตัวแปรนับจำนวนครั้งที่เปิดทะเบียน (อยู่นอกฟังก์ชันเพื่อให้ค่าคงอยู่ระหว่างการวนซ้ำ)
let openPlateCount = 0; 

async function moveItemToTrunkx(targetName) {
    // 1. ตรวจสอบความจุจากน้ำหนัก (200KG = 66, 300KG = 100)
    const weightEl = document.querySelector('.inventory-info.secondary .weight');
    if (!weightEl) return console.error(""ไม่พบข้อมูลน้ำหนัก"");

    const maxNum = parseInt(weightEl.textContent.trim().replace('KG.', '').split('/')[1]);
    const limit = (maxNum === 300) ? 300 : (maxNum === 200 ? 200 : 0);

    // 2. นับจำนวนไอเทมเป้าหมายที่มีอยู่ใน Trunk แล้ว
    const secondaryBox = document.querySelector('.dnd-drop.inventory-main-box.secondary');
    const existingItems = Array.from(secondaryBox.querySelectorAll('.slot-item-box'));
    let existingAmount = 0;
    
    existingItems.forEach(item => {
        if (item.querySelector('.text')?.textContent.trim() === targetName) {
            existingAmount += parseInt(item.querySelector('.amount-box').textContent.trim().split('/')[0]);
        }
    });

    // 3. ตรวจสอบลิมิต (ถ้าเต็ม ให้เปลี่ยนทะเบียนก่อน)
    if (existingAmount >= limit) {
        // ตรวจสอบว่าเปิดครบ 15 ครั้งหรือยัง
        if (openPlateCount >= 15) {
            console.error(`❌ เปลี่ยนทะเบียนติดต่อกันครบ 15 ครั้งแล้ว หยุดการทำงานเพื่อป้องกันลูปไม่รู้จบ`);
            openPlateCount = 0; // รีเซ็ตค่าเผื่อใช้งานครั้งถัดไป
            document.dispatchEvent(new KeyboardEvent('keydown', {
            key: 'Escape',
            code: 'Escape',
            keyCode: 27,
            which: 27,
            bubbles: true
        }));
            return;
        }

        openPlateCount++; // เพิ่มจำนวนครั้งที่เรียก openplate
        console.warn(`Trunk เต็มสำหรับ ${targetName} (${existingAmount}/${limit})! กำลังเปลี่ยนทะเบียน (ครั้งที่ ${openPlateCount}/15)...`);
        
        await fetch('https://f_inventory/openplate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });

        console.log(""เปลี่ยนทะเบียนสำเร็จ รอระบบอัปเดต..."");
        await new Promise(resolve => setTimeout(resolve, 700)); // รอ 3 วินาที
        return moveItemToTrunkx(targetName);
    }

    // ถ้าทำงานสำเร็จและย้ายของได้ ให้รีเซ็ตตัวนับ openplate เป็น 0 (ถ้าต้องการให้เริ่มนับใหม่เมื่อเปลี่ยนคันสำเร็จ)
    openPlateCount = 0; 

    // 4. หาไอเทมใน Main Inventory เพื่อเตรียมย้าย
    const items = document.querySelectorAll('.slot-item-box');

    const targetItem = Array.from(items).find(item => {
        const name = item.querySelector('.text')?.textContent.trim();
        const amountText = item.querySelector('.amount-box')?.textContent.trim();

        return name === targetName && amountText?.includes('/');
    });

    if (!targetItem) {
        console.error(`ไม่พบ ${targetName} ใน Main Inventory`);
        return;
    }

    const currentCount = parseInt(
        targetItem.querySelector('.amount-box').textContent.trim().split('/')[0],
        10
    );

    const spaceRemaining = limit - existingAmount;
    const amountToMove = Math.min(currentCount, spaceRemaining);

    if (!(amountToMove > 0)) {
        console.log(`ข้าม ${targetName}: amountToMove = ${amountToMove}`);
        return;
    }

    const bgStyle = targetItem.querySelector('.image-box').style.backgroundImage;
    const fileName = bgStyle
        .split('/')
        .pop()
        .replace('.png"")', '')
        .replace('"")', '');

    console.log(`กำลังย้าย ${targetName} จำนวน: ${amountToMove} ไปยัง Trunk...`);

    // 5. ส่งคำสั่งย้ายของ
    await fetch('https://f_inventory/action:moveItemToSecondary', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            item: {
                label: targetName,
                name: fileName,
                count: amountToMove,
                type: ""item_standard""
            },
            count: amountToMove,
            to: ""trunk"",
            action: ""put""
        })
    });
    console.log(`ย้าย ${targetName} สำเร็จ`);
}");
                await RunInResource("f_autojob", @"function getAutofarmData() {
    // 1. ดึงข้อมูลจาก HUD หลัก (ถ้ามี)
    const farmHud = document.querySelector('.autofarm-hud-ore');
    let mainItem = null;
    if (farmHud) {
        const itemName = farmHud.querySelector('strong')?.textContent.trim();
        const amountText = farmHud.querySelector('b')?.textContent.trim();
        if (itemName && amountText) {
            mainItem = { itemName, currentAmount: parseInt(amountText.split('/')[0]) };
            console.log(`[Main HUD] ${mainItem.itemName}: ${mainItem.currentAmount}`);
        }
    }

    // 2. ดึงข้อมูลจากรายการ Process Window
    const processItems = document.querySelectorAll('.autofarm-process-item');
    const processList = [];

    processItems.forEach(item => {
        const name = item.querySelector('strong')?.textContent.trim();
        const amountText = item.querySelector('em')?.textContent.trim();
        
        if (name && amountText) {
            const [current, max] = amountText.split('/').map(Number);
            processList.push({ name, current, max });
            console.log(`[Process List] ${name}: ${current}/${max}`);
        }
    });

    // รีเทิร์นออกมาเป็น Object รวม
    return {
        mainItem: mainItem,
        processList: processList
    };
}");
                w();
                bool checks = false;
                await Task.Run(async () =>
                {
                    while (true)
                    {
                        string ww = null;
                        int sleep = 1000;
                        await RunInResource("f_autojob",
                            @"getAutofarmData();");
                        if (!(countanimal.IndexOf("\"mainItem\": null", StringComparison.OrdinalIgnoreCase) >= 0))
                        {
                            if (countanimal.IndexOf("CARROT", StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                ww = "Carrot";
                            }
                            else if (countanimal.IndexOf("TOMATO", StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                ww = "Tomato";
                            }
                            else if (countanimal.IndexOf("กะหล่ำ", StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                ww = "Cabbages";
                            }

                            if (ww != null)
                            {
                                await RunInResource(
                                   "f_inventory",
                                   $@"moveItemToTrunkx(""{ww}"")");
                            }
                            checks = true;
                        }
                        else if (!(countanimal.IndexOf("\"processList\": []", StringComparison.OrdinalIgnoreCase) >= 0))
                        {
                            await RunInResource(
                               "f_inventory",
                               $@"runInventoryAutomationx();");
                            checks = true;
                            sleep = 1000;
                        }
                        else
                        {
                            if (checks)
                            {
                                checks = false;
                                Console.Beep(1000, 300);
                                Thread.Sleep(200);
                                Console.Beep(1000, 300);
                            }
                            sleep = 1000;
                        }
                        Thread.Sleep(sleep);
                    }
                });
            }
        }
    }

    private async static void cooldown()
    {
        await Task.Run(async () =>
        {
            while (true)
            {
                await RunInResource("nakin_minigames", @"
    (async () => {
        try {
            const response = await fetch(`https://${GetParentResourceName()}/checkcodown`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify({})
            });
            const data = await response.json();
            console.log('ค่า Cooldown ที่ได้คือ:', data);
        
            // สำคัญ: ต้อง return ข้อมูลกลับมาด้วยเพื่อให้ C# มองเห็น
            return data;
        } catch (error) {
            return { error: error.toString() };
        }
    })();
");
                Thread.Sleep(100);
            }
        });
    }
    private async static void w()
    {
        await Task.Run(async () =>
        {
            DateTime? holdStart = null;
            bool executed = false;

            while (true)
            {
                bool isDown = (GetAsyncKeyState(VK_F4) & 0x8000) != 0;

                if (isDown)
                {
                    if (holdStart == null)
                        holdStart = DateTime.Now;

                    if (!executed &&
                        (DateTime.Now - holdStart.Value).TotalSeconds >= 1.5)
                    {
                        executed = true;
                        Console.Beep(1000, 300);
                        await RunInResource(
                         "f_inventory", @"(async function runOrRetry(retryCount = 0) {
                    const MAX_RETRIES = 10;
                    const items = document.querySelectorAll('.slot-item-box');
                    let found = false;

                    for (const item of items) {
                        const labelEl = item.querySelector('.text');
                        const amountEl = item.querySelector('.amount-box');

                        if (labelEl && amountEl) {
                            const label = labelEl.innerText.trim();
                            const amountText = amountEl.innerText.trim();

                            if (label === ""Salad"" && !amountText.includes('/')) {
                                const count = parseInt(amountText);
                                if (count > 0) {
                                    found = true;
                                    retryCount = 0; // รีเซ็ตตัวนับเมื่อเจอของ

                                    console.log(`พบ Salad จำนวน ${count} กำลังส่งคำสั่ง Take...`);

                                    await fetch('https://f_inventory/action:moveItemToMain', {
                                        method: 'POST',
                                        headers: { 'Content-Type': 'application/json' },
                                        body: JSON.stringify({
                                            item: {
                                                label: ""Salad"",
                                                limit: 25,
                                                secondary: { shared_vault: true, trunk: true, glovebox: true, personal_vault: true },
                                                count: count,
                                                condition: { give: true, drop: true, use: true },
                                                type: ""item_standard"",
                                                weight: 2,
                                                filter: ""others"",
                                                name: ""salad""
                                            },
                                            count: count,
                                            from: ""trunk"",
                                            action: ""take""
                                        })
                                    });
                                }
                            }
                        }
                    }

                     //ส่วนจัดการการวนลูป
                    if (!found) {
                        retryCount++;
                        console.warn(`ไม่พบ Salad (ครั้งที่ ${retryCount}/${MAX_RETRIES})`);

                        if (retryCount >= MAX_RETRIES) {
                            console.error(""ไม่พบ Salad เกิน 10 ครั้งติดต่อกัน หยุดการทำงานครับ"");
                            return; 
                        }

                        await fetch('https://f_inventory/openplate', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({})
                        });
                    }

                    // เพิ่มการหน่วงเวลา 500ms ทุกครั้งก่อนวนกลับไปเริ่มใหม่
                    await new Promise(resolve => setTimeout(resolve, 200));

                     //เรียกตัวเองซ้ำเสมอ (เพื่อให้ทำงานต่อเนื่อง)
                    return runOrRetry(retryCount);
                })();");
                    }
                }
                else
                {
                    // รีเซ็ตเมื่อปล่อยปุ่ม
                    holdStart = null;
                    executed = false;
                }

                Thread.Sleep(10);
            }
        });
    }





    static void createfile(string outPath, string name)
    {
        using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream($"nuidevtools.{name}"))
        using (var f = new FileStream(outPath, FileMode.Create))
            s.CopyTo(f);
    }
    static async Task<string> GetWebSocketUrl()
    {
        using (var client = new HttpClient())
        {
            try
            {
                string json = await client.GetStringAsync(
                    "http://localhost:13172/json/list"
                );

                var pages = JArray.Parse(json);

                var page = pages.FirstOrDefault(p =>
                    p["title"]?.ToString() == "CitizenFX root UI"
                );

                return page?["webSocketDebuggerUrl"]?.ToString();
            }
            catch
            {
                return null;
            }
        }
    }
}
