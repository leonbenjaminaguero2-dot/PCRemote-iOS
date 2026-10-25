using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Http;
var builder = WebApplication.CreateBuilder(args);
var port = int.TryParse(Environment.GetEnvironmentVariable("PCREMOTE_PORT"),out var p)?p:8765;
var pin = Environment.GetEnvironmentVariable("PCREMOTE_PIN");
if (string.IsNullOrWhiteSpace(pin)) { Console.Error.WriteLine("Set PCREMOTE_PIN before starting. Example: $env:PCREMOTE_PIN='your-long-random-secret'"); return; }
builder.WebHost.UseUrls($"http://0.0.0.0:{port}");
var app=builder.Build();
app.Use(async(ctx,next)=>{
 if(ctx.Request.Path.StartsWithSegments("/api")){
  var supplied=ctx.Request.Headers["X-PCRemote-Pin"].ToString();
  if(supplied.Length!=pin.Length || !CryptographicOperations.FixedTimeEquals(System.Text.Encoding.UTF8.GetBytes(supplied),System.Text.Encoding.UTF8.GetBytes(pin))) {ctx.Response.StatusCode=401;return;}
 }
 await next();
});
app.MapGet("/api/status",()=>Results.Ok(new {online=true, machine=Environment.MachineName, version="2.0-preview"}));
app.MapGet("/api/screen.jpg",()=>{
 try { var bounds=System.Windows.Forms.Screen.PrimaryScreen?.Bounds ?? throw new Exception("No active display"); using var bmp=new Bitmap(bounds.Width,bounds.Height);using(var g=Graphics.FromImage(bmp))g.CopyFromScreen(bounds.Left,bounds.Top,0,0,bounds.Size);using var ms=new MemoryStream();bmp.Save(ms,ImageFormat.Jpeg);return Results.File(ms.ToArray(),"image/jpeg"); }
 catch(Exception e){return Results.Problem(e.Message,statusCode:503);}
});
app.MapPost("/api/mouse",(MouseRequest r)=>{if(r.Dx is < -200 or > 200 || r.Dy is < -200 or > 200)return Results.BadRequest();var pos=System.Windows.Forms.Cursor.Position;System.Windows.Forms.Cursor.Position=new Point(pos.X+r.Dx,pos.Y+r.Dy);return Results.Ok();});
app.MapPost("/api/click",(ClickRequest r)=>{uint down=r.Right?0x0008u:0x0002u,up=r.Right?0x0010u:0x0004u;Native.mouse_event(down,0,0,0,UIntPtr.Zero);Native.mouse_event(up,0,0,0,UIntPtr.Zero);return Results.Ok();});
app.MapPost("/api/key",(KeyRequest r)=>{if(!KeyMap.AllowedKeys.TryGetValue(r.Key,out var key))return Results.BadRequest("Unsupported key");Native.keybd_event(key,0,0,UIntPtr.Zero);Native.keybd_event(key,0,2,UIntPtr.Zero);return Results.Ok();});
app.MapGet("/api/apps",()=>Results.Ok(new[]{new {name="Notepad",id="notepad"},new{name="Calculator",id="calc"},new{name="Explorer",id="explorer"}}));
app.MapPost("/api/apps/{id}",(string id)=>{var exe=id switch {"notepad"=>"notepad.exe","calc"=>"calc.exe","explorer"=>"explorer.exe",_=>null};if(exe is null)return Results.NotFound();System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(exe){UseShellExecute=true});return Results.Ok();});
Console.WriteLine($"PC Remote on port {port} (LAN only; do not expose to internet)");app.Run();
class Native { [DllImport("user32.dll")]public static extern void mouse_event(uint flags,uint dx,uint dy,uint data,UIntPtr extra);
[DllImport("user32.dll")]public static extern void keybd_event(byte vk,byte scan,uint flags,UIntPtr extra); }
record MouseRequest(int Dx,int Dy);record ClickRequest(bool Right);record KeyRequest(string Key);
class KeyMap { public static readonly Dictionary<string,byte> AllowedKeys=new(StringComparer.OrdinalIgnoreCase){["up"]=0x26,["down"]=0x28,["left"]=0x25,["right"]=0x27,["enter"]=0x0D,["escape"]=0x1B,["space"]=0x20,["backspace"]=0x08}; }
