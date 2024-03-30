import SwiftUI
import Foundation
struct ContentView: View {
    @State private var folderItems: [URL] = []
    @State private var fileItems: [URL] = []
    @State private var currentDirectory: URL?
    @State private var selectedFile: URL?
    @State private var showErrorPopup = false
    @State private var isFileDetailViewPresented = false
    @State private var fileContent: String = ""
    @State private var binaryFileError = false
    @State private var fileDeleted = false
    @State private var showNoWriteAccessAlert = false
    @State private var showWriteAccessAlert = false
    @State private var downloadFail = false
    @State private var isURLInputEmpty = true
    @State private var invalidURL = true
    @State private var downloadAlert = false
    @State private var symlinkItems: [URL] = []
    @State private var isShowingURLInput = false
    @State private var userSpecifiedURL: String = ""
    @State private var isDownloading = false
    @State private var showDeleteConfirmation = false
    @State private var deleteModeEnabled = false
    @State private var downloadComplete = true

    @FocusState private var isDownloadTextFieldFocused: Bool

    private var downloadTask: URLSessionDownloadTask?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {
                    HStack {
                        Button(action: {
                            deleteModeEnabled = false
                            loadFiles(at: URL(fileURLWithPath: "/"))
                        }) {
                            Text("/")
                                .padding(.horizontal, 20)
                        }

                        Button(action: {
                            deleteModeEnabled = false
                            if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                                let parentDirectory = documentsDirectory.deletingLastPathComponent()
                                loadFiles(at: parentDirectory)
                            }
                        }) {
                            Image(systemName: "app.dashed")
                                .padding(.horizontal, 20)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.clear)

                    HStack {
                        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.standardized
                        Button(action: {
                            deleteModeEnabled = false
                            
                            isShowingURLInput.toggle()

                            
                            if !isURLInputEmpty {
                                downloadFileFromURL(urlString: userSpecifiedURL, progressHandler: { progress in
                                }) { success in
                                }
                            }
                        }) {
                            if isShowingURLInput {
                                if isURLInputEmpty {
                                    Image(systemName: "xmark")
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                } else {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            } else {
                                Image(systemName: "arrow.down.to.line.alt")
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            
                        }
                        .disabled(currentDirectory?.standardizedFileURL != documentsDirectory)
                        .opacity(currentDirectory?.standardizedFileURL != documentsDirectory ? 0.6 : 1)

                        Button(action: {
                           
                            guard let currentDirectory = currentDirectory else {
                                print("Current directory is nil")
                                return
                            }

                            let fileManager = FileManager.default
                            if fileManager.isWritableFile(atPath: currentDirectory.path) {
                                showWriteAccessAlert = true
                            } else {
                                showNoWriteAccessAlert = true
                            }
                        }) {
                            Text("r/w")
                                .padding(.horizontal, 16)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.clear)
                    }

                    if isShowingURLInput {
                        
                        TextField("Enter URL", text: $userSpecifiedURL)
                            .padding(.horizontal)
                            .padding(.vertical, 5)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.bottom)
                            .onAppear {
                                userSpecifiedURL = "http://"
                            }
                            .onChange(of: userSpecifiedURL) { newValue in
                                if newValue.isEmpty || newValue == "http://" || newValue == "https://" {
                                    isURLInputEmpty = true
                                } else {
                                    isURLInputEmpty = false
                                }
                            }
                    }

                    HStack {
                        
                        
                        Button(action: {
                            if let directory = currentDirectory, directory != URL(fileURLWithPath: "/") {
                                loadFiles(at: directory.deletingLastPathComponent())
                                deleteModeEnabled = false
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.blue)
                                .clipShape(Circle())
                                
                        }
                        .disabled(currentDirectory == nil || currentDirectory == URL(fileURLWithPath: "/"))
                        .opacity(currentDirectory == nil || currentDirectory == URL(fileURLWithPath: "/") ? 0.6 : 1)
                        .frame(maxWidth: .infinity)
                        .background(Color.clear)
                        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.standardized

                        Button(action: {
                            deleteModeEnabled.toggle()
                        }) {
                            Text(deleteModeEnabled ? Image(systemName: "trash.slash") : Image(systemName: "trash")).foregroundColor(.red)
                        }
                        .disabled(currentDirectory?.standardizedFileURL != documentsDirectory)
                        .opacity(currentDirectory?.standardizedFileURL != documentsDirectory ? 0.6 : 1)


                    }
                    
                    if downloadComplete == false {
                        HStack {
                            Spacer()
                            Text("Downloading...")
                                .padding(8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity)
                            Spacer()
                        }
                    }
                    
                    Text((currentDirectory?.standardizedFileURL.path ?? ""))
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    ForEach(folderItems + symlinkItems, id: \.self) { item in
                        Button(action: {
                            loadFiles(at: item)
                        }) {
                            Text(item.lastPathComponent)
                                .font(.body)
                                .foregroundColor(Color.blue.opacity(0.7))
                        }
                    }

                    
                    ForEach(fileItems, id: \.self) { file in
                        Button(action: {
                            selectedFile = file
                            if deleteModeEnabled && fileIsInDocumentsFolder(file) {
                                deleteFile(file)
                                guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                                    print("Failed to get documents directory")
                                    return
                                }
                                DispatchQueue.main.async {
                                    self.loadFiles(at: self.currentDirectory ?? documentsDirectory)
                                }
                                fileDeleted = true
                            }
                            else {
                                readAndDisplayFileContent(file)
                            }
                        }) {
                            Text(file.lastPathComponent)
                                .font(.body)
                                .foregroundColor(.white)
                        }
                        .background(
                            deleteModeEnabled && fileIsInDocumentsFolder(file)
                                ? RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.red.opacity(0.5))
                                : nil
                        )
                    }
                }
                .padding()

            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                loadFiles(at: URL(fileURLWithPath: "/"))
            }
            .alert(isPresented: Binding<Bool>(
                get: { self.binaryFileError || self.showErrorPopup || self.showNoWriteAccessAlert || self.showWriteAccessAlert || self.fileDeleted || self.downloadAlert || self.downloadFail },
                set: { _ in }
            )) {
                if self.binaryFileError {
                    return Alert(
                        title: Text("Error"),
                        message: Text("The selected file is not viewable as a text file."),
                        dismissButton: .default(Text("OK")) {
                            self.binaryFileError = false
                        }
                    )
                } else if self.showErrorPopup {
                    return Alert(
                        title: Text("Error"),
                        message: Text("You don't have permission to view this folder."),
                        dismissButton: .default(Text("OK")) {
                            self.showErrorPopup = false
                        }
                    )
                } else if self.showNoWriteAccessAlert {
                    return Alert(
                        title: Text("No Write Access"),
                        message: Text("You do not have write access to the current directory."),
                        dismissButton: .default(Text("OK")) {
                            self.showNoWriteAccessAlert = false
                        }
                    )
                } else if self.showWriteAccessAlert {
                    return Alert(
                        title: Text("Write Access"),
                        message: Text("You have write access to the current directory."),
                        dismissButton: .default(Text("OK")) {
                            self.showWriteAccessAlert = false
                        }
                    )
                } else if self.fileDeleted {
                    return Alert(
                        title: Text("File deleted"),
                        message: Text("The selected file was deleted."),
                        dismissButton: .default(Text("OK")) {
                            self.fileDeleted = false
                        }
                    )
                } else if self.downloadAlert {
                    return Alert(
                        title: Text("Download complete"),
                        message: Text("Successfully downloaded the file at the specified URL."),
                        dismissButton: .default(Text("OK")) {
                            self.downloadAlert = false
                        }
                    )
                } else if self.downloadFail {
                    return Alert(
                        title: Text("Download error"),
                        message: Text("The download failed due to an error."),
                        dismissButton: .default(Text("OK")) {
                            self.downloadFail = false
                        }
                    )
                } else if self.invalidURL {
                    return Alert(
                        title: Text("Download error"),
                        message: Text("Invalid URL."),
                        dismissButton: .default(Text("OK")) {
                            self.invalidURL = false
                        }
                    )
                } else {
                    return Alert(title: Text(""))
                }
            }
            .actionSheet(isPresented: $showDeleteConfirmation) {
                
                ActionSheet(
                    title: Text("Delete File"),
                    message: Text("Are you sure you want to delete this file?"),
                    buttons: [
                        .destructive(Text("Delete")) {
                            if let fileURL = selectedFile {
                                deleteFile(fileURL)
                                loadFiles(at: currentDirectory ?? URL(fileURLWithPath: "/"))
                            }
                        },
                        .cancel()
                    ]
                )
            }

            .sheet(isPresented: $isFileDetailViewPresented) {
                TextDetailView(text: $fileContent)
            }
        }
    }

    private func loadFiles(at directoryURL: URL) {
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: [])

            folderItems = []
            symlinkItems = []
            fileItems = []
            for item in contents {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        folderItems.append(item)
                    } else if isSymlink(url: item) {
                        symlinkItems.append(item)
                    } else {
                        fileItems.append(item)
                    }
                }
            }
            folderItems.sort { $0.lastPathComponent < $1.lastPathComponent }
            symlinkItems.sort { $0.lastPathComponent < $1.lastPathComponent }
            fileItems.sort { $0.lastPathComponent < $1.lastPathComponent }

            currentDirectory = directoryURL
        } catch {
            self.showErrorPopup = true
        }
    }

    private func isSymlink(url: URL) -> Bool {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
            if let isSymbolicLink = resourceValues.isSymbolicLink {
                return isSymbolicLink
            }
        } catch {
            print("Error checking if file is a symbolic link: \(error.localizedDescription)")
        }
        return false
    }

    private func readAndDisplayFileContent(_ file: URL) {
        fileContent = "placeholder"
        print("Reading file from URL: \(file)")
        do {
            let data = try Data(contentsOf: file)
            guard let content = String(data: data, encoding: .utf8) else {
                binaryFileError = true
                return
            }

            let nonPrintableASCIICharacters = content.contains { character in
                let asciiValue = character.asciiValue ?? 0
                return !(0x00...0x7E).contains(asciiValue)
            }

            if nonPrintableASCIICharacters {
                binaryFileError = true
            } else {
                fileContent = content
                isFileDetailViewPresented = true
            }
        } catch {
            print("Error reading file: \(error.localizedDescription)")
        }
    }

    func downloadFileFromURL(urlString: String, progressHandler: ((Float) -> Void)? = nil, completionHandler: @escaping (Bool) -> Void) {
        self.downloadComplete = false
        
        if urlString.isEmpty || urlString == "http://" || urlString == "https://" {
            print("Received input is empty or 'http://' or 'https://'. Doing nothing.")
            completionHandler(false)
            self.downloadComplete = true
            self.isURLInputEmpty = true
            return
        }

        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            self.invalidURL = true
            completionHandler(false)
            return
        }

        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: nil, delegateQueue: OperationQueue.main)

        let downloadTask = session.downloadTask(with: url) { (tempURL, response, error) in
            guard let tempURL = tempURL, error == nil else {
                print("Failed to download file:", error?.localizedDescription ?? "Unknown error")
                completionHandler(false)
                DispatchQueue.main.async {
                    self.downloadComplete = true
                    self.downloadFail = true
                    self.isURLInputEmpty = true
                }
                return
            }

            do {
                guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    print("Failed to get documents directory")
                    completionHandler(false)
                    DispatchQueue.main.async {
                        self.downloadComplete = true
                        self.downloadFail = true
                        self.isURLInputEmpty = true
                    }
                    return
                }

                let originalFileName = url.lastPathComponent
                let destinationURL = documentsDirectory.appendingPathComponent(originalFileName)

                try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                print("File downloaded successfully as:", originalFileName)
                completionHandler(true)
                DispatchQueue.main.async {
                    self.downloadComplete = true
                    self.downloadAlert = true
                    self.isURLInputEmpty = true
                    guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                        print("Failed to get documents directory")
                        return
                    }
                    DispatchQueue.main.async {
                        self.loadFiles(at: self.currentDirectory ?? documentsDirectory)
                    }
                }
            } catch {
                print("Error moving downloaded file:", error.localizedDescription)
                completionHandler(false)
                DispatchQueue.main.async {
                    self.downloadComplete = true
                    self.downloadFail = true
                    self.isURLInputEmpty = true
                }
            }
        }

        downloadTask.resume()
    }


    private func deleteFile(_ fileURL: URL) {
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("File deleted successfully")
        } catch {
            print("Error deleting file: \(error.localizedDescription)")
        }
    }

    private func deleteFileConfirmation(_ fileURL: URL) {

        selectedFile = fileURL


        showDeleteConfirmation = true
    }

    private func fileIsInDocumentsFolder(_ fileURL: URL) -> Bool {

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        return fileURL.path.contains(documentsDirectory.path)
    }
}

struct TextDetailView: View {
    @Binding var text: String

    var body: some View {
        ScrollView {
            if !text.isEmpty {
                Text(text)
                    .padding()
            } else {
                ProgressView()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
