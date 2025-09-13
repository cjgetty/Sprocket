//
//  FilmStockSettingsView.swift
//  Sprocket
//
//  Created by Cameron Getty on 9/12/25.
//

import SwiftUI
import CoreData

struct FilmStockSettingsView: View {
    @ObservedObject private var filmStockManager = FilmStockManager.shared
    @ObservedObject private var coreDataManager = CoreDataManager.shared
    @State private var showingAddFilmStock = false
    @State private var searchText = ""
    @State private var selectedType = "All"
    @State private var showingReciprocityInfo = false
    
    let filmTypes = ["All", "B&W", "Color Negative", "Color Positive", "Slide"]
    
    var filteredFilmStocks: [FilmStock] {
        var stocks = filmStockManager.availableFilmStocks
        
        // Filter by type
        if selectedType != "All" {
            stocks = stocks.filter { $0.type == selectedType }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            stocks = stocks.filter { filmStock in
                (filmStock.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (filmStock.manufacturer?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return stocks
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                VStack(spacing: 16) {
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("Search film stocks...", text: $searchText)
                            .font(.system(size: 16))
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Type Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filmTypes, id: \.self) { type in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedType = type
                                    }
                                }) {
                                    Text(type)
                                        .font(.system(size: 14, weight: .medium))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(selectedType == type ? Color.accentColor : Color(.systemGray5))
                                        )
                                        .foregroundColor(selectedType == type ? .white : .primary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.horizontal, 0)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(Color(.systemBackground))
                
                // Film Stock List
                List {
                    // Selected Film Stock Section
                    if let selectedFilmStock = filmStockManager.selectedFilmStock {
                        Section {
                            FilmStockRowView(
                                filmStock: selectedFilmStock,
                                isSelected: true,
                                onSelect: { _ in }
                            )
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        } header: {
                            Text("Currently Selected")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                        }
                    }
                    
                    // Available Film Stocks
                    Section {
                        ForEach(filteredFilmStocks, id: \.id) { filmStock in
                            FilmStockRowView(
                                filmStock: filmStock,
                                isSelected: filmStockManager.selectedFilmStock?.id == filmStock.id,
                                onSelect: { selectedFilmStock in
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        filmStockManager.selectFilmStock(selectedFilmStock)
                                    }
                                    triggerSelectionHaptic()
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    } header: {
                        Text("Available Film Stocks")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Film Stock")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddFilmStock = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingReciprocityInfo = true
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .sheet(isPresented: $showingAddFilmStock) {
                AddFilmStockView()
            }
            .sheet(isPresented: $showingReciprocityInfo) {
                ReciprocityInfoView()
            }
        }
        .onAppear {
            filmStockManager.loadFilmStocks()
            filmStockManager.loadSelectedFilmStock()
        }
    }
}

struct FilmStockRowView: View {
    let filmStock: FilmStock
    let isSelected: Bool
    let onSelect: (FilmStock) -> Void
    
    var body: some View {
        Button(action: {
            onSelect(filmStock)
        }) {
            HStack(alignment: .center, spacing: 12) {
                // Film Type Icon
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(filmTypeColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: filmTypeIcon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(filmTypeColor)
                    }
                    
                    Text(filmStock.type ?? "Unknown")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 50)
                
                // Film Stock Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(extractFilmName(from: filmStock.name ?? "Unknown"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(filmStock.manufacturer ?? "Unknown")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        if filmStock.reciprocityConstant > 1.0 {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                    }
                }
                
                // ISO Badge and Checkmark
                HStack(spacing: 8) {
                    Text("ISO \(Int(filmStock.iso))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .cornerRadius(6)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var filmTypeIcon: String {
        switch filmStock.type {
        case "B&W": return "circle.fill"
        case "Color Negative": return "circle.lefthalf.filled"
        case "Color Positive", "Slide": return "circle.righthalf.filled"
        default: return "circle"
        }
    }
    
    private func extractFilmName(from fullName: String) -> String {
        // Remove common manufacturer prefixes
        let manufacturers = ["Fujifilm", "Kodak", "Ilford", "Agfa", "Rollei", "Foma", "Adox", "Bergger", "Kentmere", "Arista", "T-Max", "Tri-X", "Delta", "HP5", "FP4", "Pan F", "Acros", "Neopan", "Provia", "Velvia", "Astia", "Ektar", "Portra", "Gold", "Ultra", "ColorPlus", "Superia", "C200", "X-Tra"]
        
        var filmName = fullName
        for manufacturer in manufacturers {
            if filmName.hasPrefix(manufacturer + " ") {
                filmName = String(filmName.dropFirst(manufacturer.count + 1))
                break
            }
        }
        
        return filmName.isEmpty ? fullName : filmName
    }
    
    private var filmTypeColor: Color {
        switch filmStock.type {
        case "B&W": return .gray
        case "Color Negative": return .blue
        case "Color Positive", "Slide": return .red
        default: return .secondary
        }
    }
}

struct AddFilmStockView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var filmStockManager = FilmStockManager.shared
    
    @State private var name = ""
    @State private var manufacturer = ""
    @State private var iso = 400.0
    @State private var type = "B&W"
    @State private var format = "35mm"
    @State private var reciprocityConstant = 1.0
    @State private var reciprocityExponent = 1.0
    @State private var developmentTime = 6.5
    @State private var temperature = 20.0
    @State private var notes = ""
    
    let filmTypes = ["B&W", "Color Negative", "Color Positive", "Slide"]
    let formats = ["35mm", "120", "4x5", "8x10", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Film Name")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            TextField("Enter film name", text: $name)
                                .font(.system(size: 17))
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Manufacturer")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            TextField("Enter manufacturer", text: $manufacturer)
                                .font(.system(size: 17))
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            Picker("Type", selection: $type) {
                                ForEach(filmTypes, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Format")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            Picker("Format", selection: $format) {
                                ForEach(formats, id: \.self) { format in
                                    Text(format).tag(format)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Basic Information")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("ISO")
                                .font(.system(size: 17, weight: .regular))
                            Spacer()
                            TextField("ISO", value: $iso, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 17))
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        
                        HStack {
                            Text("Development Time (min)")
                                .font(.system(size: 17, weight: .regular))
                            Spacer()
                            TextField("Minutes", value: $developmentTime, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 17))
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        
                        HStack {
                            Text("Temperature (°C)")
                                .font(.system(size: 17, weight: .regular))
                            Spacer()
                            TextField("Celsius", value: $temperature, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 17))
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Technical Specifications")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Reciprocity Constant")
                                .font(.system(size: 17, weight: .regular))
                            Spacer()
                            TextField("Constant", value: $reciprocityConstant, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 17))
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        
                        HStack {
                            Text("Reciprocity Exponent")
                                .font(.system(size: 17, weight: .regular))
                            Spacer()
                            TextField("Exponent", value: $reciprocityExponent, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 17))
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        
                        Text("For most films, use 1.0 for both values. Higher values indicate more reciprocity failure.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Reciprocity Failure")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Additional notes...", text: $notes, axis: .vertical)
                            .font(.system(size: 17))
                            .lineLimit(3...6)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Notes")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
            }
            .navigationTitle("Add Custom Film Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 17, weight: .regular))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveFilmStock()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .disabled(name.isEmpty || manufacturer.isEmpty)
                }
            }
        }
    }
    
    private func saveFilmStock() {
        let filmStock = filmStockManager.createCustomFilmStock(
            name: name,
            manufacturer: manufacturer,
            iso: iso,
            type: type,
            format: format,
            reciprocityConstant: reciprocityConstant,
            reciprocityExponent: reciprocityExponent,
            developmentTime: developmentTime,
            temperature: temperature,
            notes: notes.isEmpty ? nil : notes
        )
        
        filmStockManager.selectFilmStock(filmStock)
        presentationMode.wrappedValue.dismiss()
    }
}

struct ReciprocityInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What is Reciprocity Failure?")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Reciprocity failure (also known as the Schwarzschild effect) occurs in film photography when exposure times become very long (typically over 1 second). The film becomes less sensitive to light, requiring longer exposure times than what a light meter suggests.")
                            .font(.body)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How Sprocket Helps")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Sprocket automatically calculates the correct exposure time based on the specific reciprocity characteristics of your selected film stock. Each film has unique reciprocity failure curves, and our database includes these values for accurate long exposure photography.")
                            .font(.body)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("When to Use Reciprocity Compensation")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.orange)
                                Text("Exposure times longer than 1 second")
                            }
                            
                            HStack {
                                Image(systemName: "moon")
                                    .foregroundColor(.blue)
                                Text("Low light photography")
                            }
                            
                            HStack {
                                Image(systemName: "camera")
                                    .foregroundColor(.green)
                                Text("Long exposure techniques")
                            }
                        }
                        .font(.body)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tips for Long Exposures")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Use a sturdy tripod")
                            Text("• Use a cable release or self-timer")
                            Text("• Consider using a neutral density filter")
                            Text("• Bracket your exposures")
                            Text("• Keep notes on your results")
                        }
                        .font(.body)
                    }
                }
                .padding()
            }
            .navigationTitle("Reciprocity Failure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FilmStockSettingsView()
}
