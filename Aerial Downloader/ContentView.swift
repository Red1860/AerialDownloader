import SwiftUI
import AppKit

struct Screensaver {
    
    var name : String
    var url : String
    var image : String
    var id: String
    var category: [String]
}

enum DownloadNames {
    case Downloading
    case Downloaded
    case Failed
}

struct ContentView: View {
    
    //Screensaver Struct example
    //    let screensavers =
    //        Screensaver(name: "Hawaii", url: "hawaii.mov", image: "image", id: "id"),
    //        Screensaver(name: "Antarctica", url: "antarctica.mov", image: "image", id: "id"),
    //        Screensaver(name: "USA", url: "usa.mov", image: "image", id: "id")
    //    ]
    
    
    //The four states
    @State var loadedScreensaver: [Screensaver] = []
    @State private var downloadStatus: [String: String] = [:]
    @State private var selectedCategory: String? = nil
    @State private var displayNames: [String: String] = [:]
    @State private var showWelcome = true
    @State private var hoveredCategory: String? = nil
    @State private var searchText: String = ""
    
    let categoryNames: [String:String] = [
        "55B7C95D-CEAF-4FD8-ADEF-F5BC657D8F6D": "Earth",
        "5EF41171-4862-4F93-800C-AD86CE5E6891": "Cityscape",
        "8BE8B524-6EAE-43F5-A3E8-01DCFA1BCD4B": "Underwater",
        "A33A55D9-EDEA-4596-A850-6C10B54FBBB5": "Landscape"
    ]
    
    let imageNames = ["Earth", "Cityscape", "Underwater", "Landscape"]
    
    var uniqueCategories: [String] {
        let allCategories = loadedScreensaver.flatMap { $0.category }
        return Array(Set(allCategories)).sorted()
    }
    
    // This column is used with LazyGrid so the app displays 2x2 columns.
    let columns = [
        GridItem(.flexible(), spacing: 35),
        GridItem(.flexible())
    ]
    
    
    // The 3 functions needed for this app
    
    
    func generateDisplayNames() {
        displayNames.removeAll()
        var counts: [String: Int] = [:]
        var occurrences: [String: Int] = [:]
        
        for screensaver in loadedScreensaver {
            counts[screensaver.name, default: 0] += 1
        }
        
        for screensaver in loadedScreensaver {
            let name = screensaver.name
            
            occurrences[name, default: 0] += 1
            
            if counts[name, default: 0] > 1 {
                displayNames[screensaver.id] = "\(name) \(occurrences[name, default: 0])"
            } else {
                displayNames[screensaver.id] = name
            }
        }
    }
    
    //An array containing Screensaver Objects
    func loadScreensavers() {
        loadedScreensaver.removeAll()
        if let fileURL = Bundle.main.url(
            forResource: "entries",
            withExtension: "json"
        ) {
            let data = try! Data(contentsOf: fileURL)
            let content = try! JSONSerialization.jsonObject(with: data)
            
            if let dictionary = content as? [String: Any] {
                if let assets = dictionary["assets"] as? [[String: Any]] {
                    
                    
                    for asset in assets {
                        if let name = asset["accessibilityLabel"] as? String,
                           let url = asset["url-4K-SDR-240FPS"] as? String,
                           let image = asset["previewImage"] as? String,
                           let id = asset["id"] as? String,
                           let category = asset["categories"] as? [String] {
                            
                            let screensaver = Screensaver(
                                name: name,
                                url: url,
                                image: image,
                                id: id,
                                category: category)
                            
                            loadedScreensaver.append(screensaver)
                            
                        }
                    }
                    print(loadedScreensaver.count)
                    
                }
            }
        }
    }
    
    //Function to download screensavers from the server using URLShared
    func testDownload(_ screensaver: Screensaver) {
        let panel = NSSavePanel()
        
        panel.nameFieldStringValue = "\(screensaver.name).mov"
        panel.begin() {response in
            if response == .OK {
                if let destinationURL = panel.url {
                    print(destinationURL.path)
                    downloadStatus[screensaver.id] = "Downloading..."
                    if let downloadURL = URL(string: screensaver.url) {
                        
                        let task = URLSession.shared.downloadTask(with: downloadURL){
                            temporaryURL, response, error in
                            
                            if let temporaryURL = temporaryURL {
                                do {
                                    try FileManager.default.moveItem(
                                        at: temporaryURL,
                                        to: destinationURL
                                    )
                                    Task {@MainActor in
                                        downloadStatus[screensaver.id] = "Downloaded!"
                                    }
                                    
                                    print("Save Succesful")
                                    print(temporaryURL)
                                }
                                catch {
                                    Task { @MainActor in
                                        downloadStatus[screensaver.id] = "Failed"
                                    }
                                    print("failed to save file")
                                }
                            }
                            if let error = error {
                                Task { @MainActor in
                                    downloadStatus[screensaver.id] = "Failed"
                                }
                                print("Download failed: \(error)")
                                return
                            }
                            
                        }
                        task.resume()
                    }
                }
            } else {
                print("user pressed cancel")
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            
            //Welcome Screen
            if showWelcome {
                VStack{
                    Text("Welcome to Aeriel Downloader!")
                        .font(.largeTitle)
                    
                    Button("Continue") {
                        withAnimation(.easeInOut(duration: 1.0)){
                            showWelcome = false
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            //The rest of the App
            else {
                
                //Screensavers in a particular category
                if let categoryID = selectedCategory {
                    let filteredScreensaver = loadedScreensaver
                        .filter {$0.category.contains(categoryID)}
                        .filter {
                            searchText.isEmpty ||
                            (displayNames[$0.id] ?? $0.name)
                                .localizedCaseInsensitiveContains(searchText)
                        }
                        .sorted { $0.name < $1.name}
                        
                    
                    Text(categoryNames[categoryID] ?? "Unkown Category")
                        .font(.largeTitle)
                        .bold()
                        .padding(.top, 24)
                    
                    TextField("Search", text:$searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                    
                    ScrollView {
                        
                        ForEach(filteredScreensaver, id: \.id) {screensaver in
                            HStack(spacing:20){
                                CachedImage(url: screensaver.image)
                                    .frame(width: 160, height: 90)
                                Text(displayNames[screensaver.id] ?? screensaver.name)
                                Spacer()
                                Button(downloadStatus[screensaver.id] ?? "Download") {
                                    testDownload(screensaver)
                                }
                                .disabled(downloadStatus[screensaver.id] == "Downloading...")
                                .bold()
                                .padding(20)
                            }
                            .padding()
                            .background(.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Button("back") {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            selectedCategory = nil
                            print("Back")
                            searchText = ""
                        }}
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .padding(.bottom, 24)
                }
                
                //The 4 Category Cards
                else {
                    
                    Text("Select a category")
                        .font(.largeTitle)
                        .padding(.top, 24)
                        .bold()
                    
                    Button("Home") {
                        withAnimation(.easeInOut(duration: 1.0)){
                            showWelcome = true
                        }}
                    
                    GeometryReader {geometry in
                        let cardWidth = min(
                            500,
                            (geometry.size.width - 120) / 2,
                            (geometry.size.height - 220) / 2 * (500.0 / 350.0)
                        )
                        let cardHeight = cardWidth * (350.0 / 500.0)
                        
                            LazyVGrid(columns: columns, spacing: 35){
                                ForEach(uniqueCategories, id: \.self) {categoryID in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            
                                            selectedCategory = categoryID
                                            print("selected catagory: \(categoryID)")}}
                                    label: {
                                        VStack {
                                            Image(categoryNames[categoryID] ?? "Earth")
                                                .resizable()
                                                    .scaledToFill()
                                                    .frame(width: cardWidth, height: cardHeight)
                                                    .clipped()
                                                    .cornerRadius(15)
                                            Text(categoryNames[categoryID] ?? "Unknown")
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                                               alignment: .center)
                                        .background(.gray.opacity(0.15))
                                        .cornerRadius(12)
                                    }
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                    .buttonStyle(.plain)
                                    .onHover { isHovering in
                                        hoveredCategory = isHovering ? categoryID : nil
                                    }
                                    .scaleEffect(hoveredCategory == categoryID ? 1.05 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: hoveredCategory)
                                }
                            }
                            .padding(.horizontal, 30)
                            .padding(.vertical, 30)
                            Spacer()
                    }
                    .onAppear {
                        loadScreensavers()
                        generateDisplayNames()
                    }
                }
            }
        }
    }
}



#Preview {
    ContentView()
}


