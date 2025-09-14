# 📸 Sprocket

**A Professional Film Photography Shot Logging App for iOS**

Sprocket is a comprehensive iOS application designed for film photographers who want to meticulously track their shots, camera settings, and locations. Built with SwiftUI and Core Data, it provides an intuitive interface for logging every aspect of your photography session.

![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-3.0+-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## ✨ Features

### 🎯 **Core Functionality**
- **Shot Logging**: Record detailed information for each photograph
- **Camera Settings Tracking**: Log aperture, shutter speed, ISO, and exposure value (EV)
- **Equipment Management**: Track camera body, lens, and film stock used
- **Location Services**: Automatically capture GPS coordinates and location names
- **Photo Capture**: Built-in camera integration for instant photo capture
- **Frame Numbering**: Track frame numbers for film rolls

### 🔍 **Lens Calculator & Planning Tools**
- **Field of View Calculator**: Calculate horizontal, vertical, and diagonal FOV for any focal length
- **Crop Factor Conversions**: Convert between Full Frame, APS-C, Micro 4/3, and other sensor formats
- **Framing Predictions**: Visualize frame coverage at specified subject distances
- **Format Comparison**: Side-by-side analysis of different camera formats and focal lengths
- **Real-time Camera Overlay**: Live frame overlays on camera preview showing accurate framing for selected lenses
- **iPhone Camera Integration**: Uses iPhone's actual camera specifications for precise overlay calculations

### 📱 **User Experience**
- **Intuitive Interface**: Clean, modern SwiftUI design optimized for one-handed use
- **Haptic Feedback**: Tactile responses for better user interaction
- **Real-time Metering**: Live exposure metering with tap-to-focus
- **Dark Mode Support**: Full dark mode compatibility across all features
- **Frame Overlay Controls**: Quick access viewfinder button for camera overlay settings
- **Settings Persistence**: Remember your preferences across sessions
- **Data Export**: Core Data integration for data management

### 🗺️ **Location Features**
- **GPS Integration**: Automatic location capture
- **Location Names**: Reverse geocoding for readable location names
- **Privacy-First**: Location permissions handled gracefully

### 📊 **Data Management**
- **Core Data Storage**: Robust local data persistence
- **Shot History**: Complete log of all captured shots
- **Search & Filter**: Find specific shots quickly
- **Data Integrity**: UUID-based unique identification

## 🚀 Getting Started

### Prerequisites
- iOS 15.0 or later
- Xcode 13.0 or later
- Swift 5.0 or later

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/cjgetty/Sprocket.git
   cd Sprocket
   ```

2. **Open in Xcode**
   ```bash
   open Sprocket.xcodeproj
   ```

3. **Build and Run**
   - Select your target device or simulator
   - Press `Cmd + R` to build and run

### First Launch
1. Grant location permissions when prompted
2. Grant camera permissions for photo capture
3. Start logging your first shot!

## 📖 Usage

### Logging a Shot
1. **Set Camera Settings**: Adjust aperture, shutter speed, and ISO using the intuitive controls
2. **Add Equipment Info**: Enter camera body, lens, and film stock details
3. **Capture Location**: The app automatically captures your current location
4. **Take Photo**: Use the built-in camera or add notes
5. **Save Shot**: Tap the save button to log your shot

### Using the Lens Calculator
1. **Access Calculator**: Go to Settings → Planning Tools → Lens Calculator
2. **Select Format**: Choose your camera's sensor format (Full Frame, APS-C, etc.)
3. **Adjust Focal Length**: Use the slider to set your desired focal length
4. **View Calculations**: See field of view angles, crop factor conversions, and framing predictions
5. **Compare Formats**: Use the comparison tool to analyze different lens/format combinations

### Camera Frame Overlay
1. **Enable Overlay**: Tap the viewfinder button on the main camera screen
2. **Configure Settings**: Adjust overlay opacity and select target lens/format
3. **Live Preview**: See real-time frame overlays showing how your selected lens would frame the shot
4. **Integration**: Changes in the lens calculator automatically update the camera overlay

### Managing Your Shots
- View all logged shots in the history section
- Search and filter by date, location, or equipment
- Export data for backup or analysis
- Edit existing shots if needed

## 🏗️ Architecture

### Core Components

- **`ContentView`**: Main SwiftUI interface with camera controls, shot logging, and frame overlay integration
- **`LensCalculatorView`**: Comprehensive lens calculator with field of view calculations and format comparisons
- **`CameraFrameOverlay`**: Real-time camera frame overlay system with iPhone camera integration
- **`CoreDataManager`**: Handles data persistence and Core Data operations
- **`LocationManager`**: Manages GPS location services and reverse geocoding
- **`PhotoCaptureManager`**: Handles camera integration and photo capture
- **`Persistence`**: Core Data stack configuration

### Data Model

The app uses a `LoggedShot` entity with the following attributes:
- **Basic Info**: `id`, `timestamp`, `notes`
- **Camera Settings**: `aperture`, `shutterSpeed`, `iso`, `ev`
- **Equipment**: `cameraBody`, `lens`, `filmStock`, `frameNumber`
- **Location**: `latitude`, `longitude`, `locationName`
- **Media**: `imageData` (optional photo attachment)

## 🛠️ Technical Details

### Dependencies
- **SwiftUI**: Modern declarative UI framework
- **Core Data**: Local data persistence
- **Core Location**: GPS and location services
- **AVFoundation**: Camera and photo capture
- **MapKit**: Location display and reverse geocoding

### Permissions Required
- **Location**: `NSLocationWhenInUseUsageDescription`
- **Camera**: `NSCameraUsageDescription`

### Performance Optimizations
- Lazy loading of Core Data entities
- Efficient image compression for storage
- Background location updates
- Memory-conscious photo handling

## 🎨 Customization

### Settings
- Enable/disable haptic feedback
- Customize default camera settings
- Set preferred location accuracy
- Configure data retention policies
- Access lens calculator and planning tools
- Adjust camera frame overlay opacity and settings
- Toggle dark mode preferences

### UI Themes
The app follows iOS design guidelines with:
- Dynamic Type support
- Dark mode compatibility
- Accessibility features
- Responsive layout design

## 📱 Screenshots

*Screenshots coming soon - showing the main interface, shot logging, and history views*

## 🤝 Contributing

We welcome contributions! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Cameron Getty**
- GitHub: [@cjgetty](https://github.com/cjgetty)
- Project Link: [https://github.com/cjgetty/Sprocket](https://github.com/cjgetty/Sprocket)

## 🙏 Acknowledgments

- Built with ❤️ using SwiftUI
- Inspired by the film photography community
- Thanks to all contributors and testers

## 📞 Support

If you have any questions or need help, please:
1. Check the [Issues](https://github.com/cjgetty/Sprocket/issues) page
2. Create a new issue with detailed information
3. Contact the maintainer

---

**Happy Shooting! 📸**

*Sprocket - Because every shot tells a story.*
