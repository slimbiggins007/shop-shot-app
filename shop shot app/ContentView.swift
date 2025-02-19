//
//  ContentView.swift
//  shop shot app
//
//  Created by Jett Magnuson on 2/12/25.
//

import SwiftUI
import PhotosUI
import Charts

struct ContentView: View {
    @StateObject private var dataManager = ProductDataManager()
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingAddProductSheet = false
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(dataManager.products) { product in
                        ProductCard(product: product, dataManager: dataManager)
                    }
                }
                .padding()
            }
            .navigationTitle("Shop Shot")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showImagePicker = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                if newValue != nil {
                    showingAddProductSheet = true
                }
            }
            .sheet(isPresented: $showingAddProductSheet) {
                AddProductView(image: $selectedImage, dataManager: dataManager)
            }
        }
    }
}

struct ProductCard: View {
    let product: ProductItem
    let dataManager: ProductDataManager
    @State private var showingOptions = false
    @State private var showingShoppingOptions = false
    
    let shoppingSites: [(name: String, icon: String, urlFormat: String)] = [
        ("Amazon", "cart", "https://www.amazon.com/s?k=%@"),
        ("Walmart", "cart.fill", "https://www.walmart.com/search?q=%@"),
        ("Target", "cart.circle", "https://www.target.com/s?searchTerm=%@")
    ]
    
    var body: some View {
        VStack(spacing: 8) {
            if let image = dataManager.loadImage(product.image) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.searchTerm)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Button {
                showingShoppingOptions = true
            } label: {
                HStack {
                    Image(systemName: "cart")
                    Text("Buy Now")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .contextMenu {
            Button(role: .destructive) {
                dataManager.deleteProduct(product)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                showingOptions = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        .sheet(isPresented: $showingOptions) {
            EditProductView(product: product, dataManager: dataManager)
        }
        .sheet(isPresented: $showingShoppingOptions) {
            NavigationStack {
                List {
                    ForEach(shoppingSites, id: \.name) { site in
                        Button {
                            openSite(urlFormat: site.urlFormat)
                            showingShoppingOptions = false
                        } label: {
                            HStack {
                                Image(systemName: site.icon)
                                    .foregroundColor(.blue)
                                Text(site.name)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .navigationTitle("Choose Store")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingShoppingOptions = false
                        }
                    }
                }
            }
        }
    }
    
    private func openSite(urlFormat: String) {
        let searchTerm = product.searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = String(format: urlFormat, searchTerm)
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

struct SimilarProductsView: View {
    let searchTerm: String
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var priceHistory: [ProductAIService.PriceHistory] = []
    
    let shoppingSites: [(name: String, icon: String, urlFormat: String)] = [
        ("Amazon", "cart", "https://www.amazon.com/s?k=%@"),
        ("Walmart", "cart.fill", "https://www.walmart.com/search?q=%@"),
        ("Target", "cart.circle", "https://www.target.com/s?searchTerm=%@")
    ]
    
    var body: some View {
        List {
            if !priceHistory.isEmpty {
                Section(header: Text("Price History")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Chart {
                            ForEach(priceHistory, id: \.date) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Price", point.price)
                                )
                                .foregroundStyle(by: .value("Store", point.store))
                            }
                        }
                        .frame(height: 200)
                        
                        // Current prices
                        let currentPrices = ProductAIService.shared.getCurrentPrices(for: searchTerm)
                        ForEach(currentPrices, id: \.store) { storePrices in
                            HStack {
                                Text(storePrices.store)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("$\(storePrices.price, specifier: "%.2f")")
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section {
                if isLoading {
                    ForEach(shoppingSites, id: \.name) { site in
                        HStack {
                            Image(systemName: site.icon)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(site.name)
                                    .fontWeight(.medium)
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Checking prices...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    ForEach(shoppingSites, id: \.name) { site in
                        Button {
                            openSite(urlFormat: site.urlFormat)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: site.icon)
                                    .foregroundColor(.blue)
                                Text(site.name)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            } header: {
                Text("Available at these stores")
            } footer: {
                Text("Prices and availability may vary")
                    .font(.caption)
            }
        }
        .navigationTitle("Similar Products")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            // Load price history
            priceHistory = ProductAIService.shared.getPriceHistory(for: searchTerm)
            
            // Simulate loading delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isLoading = false
            }
        }
    }
    
    private func openSite(urlFormat: String) {
        let encodedTerm = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = String(format: urlFormat, encodedTerm)
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

struct AddProductView: View {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    let dataManager: ProductDataManager
    @State private var isAnalyzing = false
    @State private var detectedSearchTerm: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                }
                
                if isAnalyzing {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 5)
                        Text("Analyzing image...")
                    }
                } else {
                    Section("Product Name") {
                        TextField("Enter product name", text: $detectedSearchTerm)
                            .textInputAutocapitalization(.words)
                        
                        if detectedSearchTerm.isEmpty {
                            Text("Tip: Enter a product name if AI detection isn't accurate")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Product")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProduct()
                    }
                    .disabled(isAnalyzing || detectedSearchTerm.isEmpty)
                }
            }
            .onAppear {
                analyzeImage()
            }
        }
    }
    
    private func analyzeImage() {
        guard let image = image else { return }
        isAnalyzing = true
        
        ProductAIService.shared.analyzeImage(image) { result in
            DispatchQueue.main.async {
                self.isAnalyzing = false
                self.detectedSearchTerm = result ?? ""
            }
        }
    }
    
    private func saveProduct() {
        guard let image = image else { return }
        
        dataManager.addProduct(
            image: image,
            searchTerm: detectedSearchTerm
        )
        self.image = nil
        dismiss()
    }
}

struct EditProductView: View {
    let product: ProductItem
    let dataManager: ProductDataManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchTerm: String
    @State private var showingSimilarProducts = false
    
    init(product: ProductItem, dataManager: ProductDataManager) {
        self.product = product
        self.dataManager = dataManager
        _searchTerm = State(initialValue: product.searchTerm)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if let image = dataManager.loadImage(product.image) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                }
                
                Section("Product Name") {
                    TextField("Product Name", text: $searchTerm)
                }
                
                Section {
                    Button {
                        showingSimilarProducts = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Find Similar Products")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Edit Product")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dataManager.updateProduct(
                            product,
                            newSearchTerm: searchTerm
                        )
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSimilarProducts) {
                NavigationStack {
                    SimilarProductsView(searchTerm: searchTerm)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
