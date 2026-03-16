# Desktop Automation Recorder ⚡

Automate your macOS workflow with ease. Record actions, capture timing, and replay with precision.

[**🚀 Download Latest Release (.zip)**](https://github.com/waveWhirlVfx/DesktopAutomationRecorder/releases/latest/download/DesktopAutomationRecorder_v1.0.0.zip)

![Desktop Automation Recorder Landing Page Screenshot](https://wavewhirlvfx.github.io/DesktopAutomationRecorder/hero.png)

## ⏺️ Overview

**Desktop Automation Recorder** is a powerful, open-source macOS utility designed to eliminate repetitive tasks. Unlike simple macro recorders, it leverages native macOS Accessibility hooks and Vision-based element detection to create robust, reliable automations.

### Why AutoRecorder?
- **High-Fidelity Timing**: Automatically records natural wait times between actions for realistic replay.
- **Smart Targeting**: Uses Semantic/Accessibility-based targeting (AXRole, AXLabel) rather than just screen coordinates.
- **Vision Integration**: Fallback OCR and image recognition for non-accessible UI elements.
- **Visual Workflow Editor**: A premium macOS interface to manage, loop, and refine your automation steps.

## 🚀 Key Features

- **Input Capture**: Records mouse clicks, double-clicks, right-clicks, drags, and scrolls.
- **Keyboard Engine**: Intelligent keystroke aggregation and shortcut detection.
- **System Events**: Monitors app launches, window switches, and file system changes (CRUD).
- **Wait States**: Integrated "Smart Wait" logic and manual delay controls.
- **Variables & Logic**: Support for variables and conditional step execution.

## 🛠️ Installation & Build

This project uses **XcodeGen** for project management.

### Prerequisites
- macOS 13.0+
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Build Steps
1. Clone the repository:
   ```bash
   git clone https://github.com/waveWhirlVfx/DesktopAutomationRecorder.git
   cd DesktopAutomationRecorder
   ```
2. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```
3. Open and Build:
   ```bash
   open DesktopAutomationRecorder.xcodeproj
   ```
   Or build from CLI:
   ```bash
   xcodebuild -project DesktopAutomationRecorder.xcodeproj -scheme DesktopAutomationRecorder -configuration Debug build
   ```

## 📖 Usage

1. **Record**: Click the "Record" button in the menu bar or main interface.
2. **Perform Actions**: Do your task naturally. The recorder captures everything including your pauses.
3. **Stop**: Finish the recording. 
4. **Edit**: Refine your steps in the Visual Editor. Add loops, adjust delays, or set variables.
5. **Replay**: Run your workflow and watch the automation take over.

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---
*Built with ❤️ for macOS Power Users.*
