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
    @State private var selectedCategory: ProductCategory = .clothing
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingAddProductSheet = false
    
    var filteredProducts: [ProductItem] {
        dataManager.products.filter { product in
            selectedCategory == product.category
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Category Picker
                Picker("Category", selection: $selectedCategory) {
                    ForEach(ProductCategory.allCases, id: \.self) { category in
                        Text(category.rawValue)
                            .tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Product Grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(filteredProducts) { product in
                            ProductCard(product: product, dataManager: dataManager)
                        }
                    }
                    .padding()
                }
                
                // Add Button
                Button(action: {
                    showImagePicker = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                }
                .padding()
            }
            .navigationTitle("Shop Shot")
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
        ("eBay", "tag", "https://www.ebay.com/sch/i.html?_nkw=%@"),
        ("Walmart", "cart.fill", "https://www.walmart.com/search?q=%@"),
        ("Target", "cart.circle", "https://www.target.com/s?searchTerm=%@"),
        ("Best Buy", "bag", "https://www.bestbuy.com/site/searchpage.jsp?st=%@"),
        ("Google", "magnifyingglass", "https://www.google.com/search?q=%@")
    ]
    
    var body: some View {
        VStack {
            if let image = dataManager.loadImage(product.image) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .cornerRadius(8)
            }
            
            Text(product.searchTerm)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button {
                showingShoppingOptions = true
            } label: {
                HStack {
                    Image(systemName: "cart")
                    Text("Buy Now")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
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
    @State private var searchResults: [SimilarProduct] = []
    @State private var isLoading = true
    @State private var priceHistory: [PricePoint] = []
    
    struct SimilarProduct: Identifiable {
        let id = UUID()
        let storeName: String
        let storeIcon: String
        var price: String
        let urlFormat: String
        var availability: String
    }
    
    struct PricePoint: Identifiable {
        let id = UUID()
        let date: Date
        let price: Double
        let store: String
    }
    
    var mainStores: [SimilarProduct] = [
        SimilarProduct(
            storeName: "Amazon",
            storeIcon: "cart",
            price: "Checking...",
            urlFormat: "https://www.amazon.com/s?k=%@",
            availability: "Checking..."
        ),
        SimilarProduct(
            storeName: "eBay",
            storeIcon: "tag",
            price: "Checking...",
            urlFormat: "https://www.ebay.com/sch/i.html?_nkw=%@",
            availability: "Checking..."
        ),
        SimilarProduct(
            storeName: "Walmart",
            storeIcon: "cart.fill",
            price: "Checking...",
            urlFormat: "https://www.walmart.com/search?q=%@",
            availability: "Checking..."
        ),
        SimilarProduct(
            storeName: "Target",
            storeIcon: "cart.circle",
            price: "Checking...",
            urlFormat: "https://www.target.com/s?searchTerm=%@",
            availability: "Checking..."
        ),
        SimilarProduct(
            storeName: "Best Buy",
            storeIcon: "bag",
            price: "Checking...",
            urlFormat: "https://www.bestbuy.com/site/searchpage.jsp?st=%@",
            availability: "Checking..."
        )
    ]
    
    var body: some View {
        List {
            if !priceHistory.isEmpty {
                Section(header: Text("Price History")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Chart(priceHistory) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Price", point.price)
                            )
                            .foregroundStyle(by: .value("Store", point.store))
                        }
                        .frame(height: 200)
                        
                        HStack {
                            Text("Lowest: $\(priceHistory.map { $0.price }.min() ?? 0, specifier: "%.2f")")
                                .foregroundColor(.green)
                            Spacer()
                            Text("Highest: $\(priceHistory.map { $0.price }.max() ?? 0, specifier: "%.2f")")
                                .foregroundColor(.red)
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section {
                if isLoading {
                    ForEach(mainStores) { store in
                        HStack {
                            Image(systemName: store.storeIcon)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.storeName)
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
                    ForEach(searchResults) { result in
                        Button {
                            openStore(urlFormat: result.urlFormat)
                        } label: {
                            HStack {
                                Image(systemName: result.storeIcon)
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.storeName)
                                        .fontWeight(.medium)
                                    HStack {
                                        Text(result.price)
                                            .foregroundColor(.green)
                                            .fontWeight(.semibold)
                                        Text("•")
                                        Text(result.availability)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundColor(.gray)
                            }
                        }
                        .foregroundColor(.primary)
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
            generatePriceHistory()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                searchResults = mainStores.map { store in
                    var updatedStore = store
                    if let latestPrice = priceHistory.filter({ $0.store == store.storeName }).last?.price {
                        updatedStore.price = String(format: "$%.2f", latestPrice)
                    }
                    updatedStore.availability = Bool.random() ? "In Stock" : "Limited Stock"
                    return updatedStore
                }
                isLoading = false
            }
        }
    }
    
    private func generatePriceHistory() {
        let calendar = Calendar.current
        let today = Date()
        
        for store in mainStores {
            var basePrice = Double.random(in: 30...80)
            
            for day in 0..<30 {
                if let date = calendar.date(byAdding: .day, value: -day, to: today) {
                    let fluctuation = Double.random(in: -5...5)
                    basePrice += fluctuation
                    basePrice = max(basePrice, 10)
                    
                    priceHistory.append(PricePoint(
                        date: date,
                        price: basePrice,
                        store: store.storeName
                    ))
                }
            }
        }
        
        priceHistory.sort { $0.date < $1.date }
    }
    
    private func openStore(urlFormat: String) {
        let encodedTerm = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = String(format: urlFormat, encodedTerm)
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
            dismiss()
        }
    }
}

struct AddProductView: View {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    let dataManager: ProductDataManager
    @State private var selectedCategory: ProductCategory = .clothing
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
                
                Picker("Category", selection: $selectedCategory) {
                    ForEach(ProductCategory.allCases, id: \.self) { category in
                        Text(category.rawValue)
                            .tag(category)
                    }
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
            category: selectedCategory,
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
    @State private var selectedCategory: ProductCategory
    @State private var searchTerm: String
    @State private var showingSimilarProducts = false
    
    init(product: ProductItem, dataManager: ProductDataManager) {
        self.product = product
        self.dataManager = dataManager
        _selectedCategory = State(initialValue: product.category)
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
                
                Picker("Category", selection: $selectedCategory) {
                    ForEach(ProductCategory.allCases, id: \.self) { category in
                        Text(category.rawValue)
                            .tag(category)
                    }
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
                            newCategory: selectedCategory,
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
