using Newtonsoft.Json.Linq;
using System;
using System.Net.WebSockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

public static class NetworkListener
{
    private static ClientWebSocket ws;

    public static async Task Start(
        string wsUrl,
        string filterResource = null
    )
    {
        while (true)
        {
            try
            {
                ws = new ClientWebSocket();

                await ws.ConnectAsync(
                    new Uri(wsUrl),
                    CancellationToken.None
                );

                Console.WriteLine("[+] Connected");

                await EnableNetwork();

                Console.WriteLine("[+] Listening...\n");

                while (
                    ws.State == WebSocketState.Open
                )
                {
                    string json = await Receive();

                    if (
                        string.IsNullOrWhiteSpace(json)
                    )
                        continue;

                    JObject obj;

                    try
                    {
                        obj = JObject.Parse(json);
                    }
                    catch
                    {
                        continue;
                    }

                    string method =
                        obj["method"]?.ToString();

                    if (
                        method
                        == "Network.requestWillBeSent"
                    )
                    {
                        HandleRequest(
                            obj,
                            filterResource
                        );
                    }
                }
            }
            catch
            {
                Console.WriteLine(
                    "[-] Reconnecting..."
                );
            }

            await Task.Delay(1000);
        }
    }

    static async Task EnableNetwork()
    {
        JObject enable = new JObject
        {
            ["id"] = 1,
            ["method"] = "Network.enable"
        };

        await Send(enable);
    }

    static void HandleRequest(
        JObject obj,
        string filterResource
    )
    {
        string url =
            obj["params"]?["request"]?["url"]?.ToString();

        string method =
            obj["params"]?["request"]?["method"]?.ToString();

        string postData =
            obj["params"]?["request"]?["postData"]?.ToString();

        if (
            string.IsNullOrEmpty(url)
        )
            return;

        if (
            !url.StartsWith("https://")
        )
            return;

        Uri uri;

        try
        {
            uri = new Uri(url);
        }
        catch
        {
            return;
        }

        string resource =
            uri.Host;

        if (
            !string.IsNullOrEmpty(filterResource)
            &&
            resource != filterResource
        )
            return;

        Console.WriteLine(
            "========================="
        );

        Console.WriteLine(
            "[RESOURCE] " + resource
        );

        Console.WriteLine(
            "[METHOD]   " + method
        );

        Console.WriteLine(
            "[URL]      " + url
        );

        if (
            !string.IsNullOrEmpty(postData)
        )
        {
            Console.WriteLine(
                "[POST]"
            );

            Console.WriteLine(postData);
        }

        Console.WriteLine(
            "=========================\n"
        );
    }

    static async Task Send(
        JObject obj
    )
    {
        byte[] bytes =
            Encoding.UTF8.GetBytes(
                obj.ToString()
            );

        await ws.SendAsync(
            new ArraySegment<byte>(bytes),
            WebSocketMessageType.Text,
            true,
            CancellationToken.None
        );
    }

    static async Task<string> Receive()
    {
        byte[] buffer =
            new byte[1024 * 512];

        WebSocketReceiveResult result =
            await ws.ReceiveAsync(
                new ArraySegment<byte>(buffer),
                CancellationToken.None
            );

        return Encoding.UTF8.GetString(
            buffer,
            0,
            result.Count
        );
    }
}