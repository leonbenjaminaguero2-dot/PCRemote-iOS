import SwiftUI
import GameController

@MainActor final class Remote: ObservableObject {
 @Published var host = UserDefaults.standard.string(forKey:"host") ?? "192.168.1.100"
 @Published var pin = UserDefaults.standard.string(forKey:"pin") ?? ""
 @Published var status = "Sin conectar"
 @Published var screenshot: UIImage?
 var timer: Timer?
 func save(){ UserDefaults.standard.set(host,forKey:"host");UserDefaults.standard.set(pin,forKey:"pin") }
 func request(_ path:String, method:String="GET", body:[String:Any]?=nil) async -> Data? {
  guard let url=URL(string:"http://\(host):8765/api/\(path)") else {return nil}
  var req=URLRequest(url:url);req.httpMethod=method;req.timeoutInterval=4;req.setValue(pin,forHTTPHeaderField:"X-PCRemote-Pin")
  if let body {req.httpBody=try? JSONSerialization.data(withJSONObject:body);req.setValue("application/json",forHTTPHeaderField:"Content-Type")}
  do {let (data,response)=try await URLSession.shared.data(for:req);guard let r=response as? HTTPURLResponse, (200..<300).contains(r.statusCode) else {status="Error de conexión / PIN";return nil};status="Conectado";return data} catch {status="Sin conexión";return nil}
 }
 func send(_ path:String,body:[String:Any]=[:]) {Task { _ = await request(path,method:"POST",body:body) }}
 func refresh(){Task {if let data=await request("screen.jpg"),let img=UIImage(data:data){screenshot=img}}}
 func start(){stop();refresh();timer=Timer.scheduledTimer(withTimeInterval:0.7,repeats:true){[weak self] _ in Task { @MainActor in self?.refresh() } }}
 func stop(){timer?.invalidate();timer=nil}
}
struct HomeView: View {
 @StateObject private var remote=Remote()
 @State private var tab=0
 @State private var showSettings=false
 private let bg=Color(red:0.035,green:0.04,blue:0.06)
 var body: some View {
  ZStack {bg.ignoresSafeArea();VStack(spacing:16){
   HStack {VStack(alignment:.leading){Text("PC Remote").font(.title2.bold());Text(remote.status).font(.caption).foregroundStyle(.cyan)};Spacer();Button {showSettings=true} label:{Image(systemName:"gearshape.fill").font(.title3)}}.padding(.horizontal)
   Group {switch tab {case 0:control;case 1:screen;default:apps}}.frame(maxWidth:.infinity,maxHeight:.infinity)
   HStack {nav("Control",icon:"gamecontroller.fill",index:0);nav("Screen",icon:"display",index:1);nav("Apps",icon:"square.grid.2x2.fill",index:2)}.padding(9).background(.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius:18)).padding(.horizontal)
  }.padding(.top,12).padding(.bottom,8)}.foregroundStyle(.white)
  .sheet(isPresented:$showSettings){NavigationStack{Form {TextField("IP de Windows",text:$remote.host).textInputAutocapitalization(.never).keyboardType(.numbersAndPunctuation);SecureField("PIN del servidor",text:$remote.pin);Button("Guardar y comprobar") {remote.save();Task{_ = await remote.request("status")}};Text("Solo red local. No expongas el puerto 8765 a Internet.").font(.caption)}.navigationTitle("Ajustes").toolbar{Button("Listo"){showSettings=false}}}}
  .onChange(of:tab){_,new in if new == 1 {remote.start()} else {remote.stop()}}.onDisappear{remote.stop()}
 }
 func nav(_ title:String,icon:String,index:Int)->some View{Button {tab=index} label:{VStack(spacing:5){Image(systemName:icon);Text(title).font(.caption)}.frame(maxWidth:.infinity).padding(9).background(tab==index ? Color.cyan.opacity(0.2):.clear).clipShape(RoundedRectangle(cornerRadius:12))}}
 var control:some View{VStack(spacing:25){Text("CONTROL").font(.caption).foregroundStyle(.gray);HStack(spacing:8){Spacer();Button("↑"){key("up")};Spacer()};HStack(spacing:15){Button("←"){key("left")};Button("OK"){key("enter")};Button("→"){key("right")}};Button("↓"){key("down")};HStack{Button("ESC"){key("escape")};Spacer();Button("ESPACIO"){key("space")};Spacer();Button("⌫"){key("backspace")}}.padding();HStack{Button("Clic izquierdo"){remote.send("click",body:["right":false])};Spacer();Button("Clic derecho"){remote.send("click",body:["right":true])}}.padding();Text("Deslizá sobre Screen para mover el ratón").font(.caption).foregroundStyle(.gray)}.buttonStyle(RemoteButton()).padding()}
 func key(_ key:String){remote.send("key",body:["key":key])}
 var screen:some View {GeometryReader{ geo in ZStack {Color.black;if let img=remote.screenshot {Image(uiImage:img).resizable().scaledToFit()} else {Text("Esperando pantalla...").foregroundStyle(.gray)}}.frame(width:geo.size.width,height:geo.size.height).contentShape(Rectangle()).gesture(DragGesture(minimumDistance:2).onChanged{v in let dx=Int(v.translation.width/7),dy=Int(v.translation.height/7);if abs(dx)+abs(dy)>0 {remote.send("mouse",body:["dx":max(-200,min(200,dx)),"dy":max(-200,min(200,dy))])}}).onTapGesture{remote.send("click",body:["right":false])}}}
 var apps:some View{ScrollView{VStack(spacing:12){ForEach([("Bloc de notas","notepad","note.text"),("Calculadora","calc","plus.forwardslash.minus"),("Explorador","explorer","folder")],id:\.1){item in HStack{Image(systemName:item.2).frame(width:42,height:42).background(.white.opacity(0.1));Text(item.0);Spacer();Button("Abrir"){remote.send("apps/\(item.1)")}.buttonStyle(.borderedProminent).tint(.cyan)}.padding().background(.white.opacity(0.06))}}.padding()}}
}
struct RemoteButton:ButtonStyle {func makeBody(configuration:Configuration)->some View{configuration.label.font(.title3.bold()).frame(minWidth:64,minHeight:52).background(configuration.isPressed ? Color.cyan.opacity(0.5):Color.white.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius:12))}}
