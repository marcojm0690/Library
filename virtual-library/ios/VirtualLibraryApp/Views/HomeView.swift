import SwiftUI

/// Main home screen of the Virtual Library app.
/// Provides navigation to ISBN scanning and cover scanning features.
struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // App header
                VStack(spacing: 10) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Virtual Library")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Identify books by scanning")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Navigation options
                VStack(spacing: 20) {
                    NavigationLink(destination: ScanIsbnView()) {
                        FeatureButton(
                            icon: "barcode.viewfinder",
                            title: "Scan ISBN Barcode",
                            description: "Use camera to scan book barcode"
                        )
                    }
                    
                    NavigationLink(destination: ScanCoverView()) {
                        FeatureButton(
                            icon: "doc.text.viewfinder",
                            title: "Scan Book Cover",
                            description: "Use OCR to identify from cover"
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Reusable button component for feature navigation
struct FeatureButton: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.white)
                .frame(width: 60)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.blue)
        )
        .shadow(radius: 3)
    }
}

#Preview {
    HomeView()
}
