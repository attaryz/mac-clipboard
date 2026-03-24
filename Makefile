# Clipboard Manager Makefile
# Usage: make [target]

# Configuration
APP_NAME := ClipboardManager
BUILD_DIR := build
APP_BUNDLE := $(APP_NAME).app
INSTALL_DIR := $(HOME)/Applications
LAUNCH_AGENT_DIR := $(HOME)/Library/LaunchAgents
LAUNCH_AGENT_PLIST := $(LAUNCH_AGENT_DIR)/com.user.clipboardmanager.plist
SUPPORT_DIR := $(HOME)/Library/Application Support/$(APP_NAME)

# Source files
SRC_DIR := Sources
SWIFT_SOURCES := $(wildcard $(SRC_DIR)/*.swift)

# Compiler settings
SWIFT_FLAGS := -framework Cocoa -framework SwiftUI -framework Combine \
               -target arm64-apple-macosx13.0 -parse-as-library

# Default target
.PHONY: all
all: build

# Build the executable
.PHONY: build
build: $(BUILD_DIR)/$(APP_NAME)

$(BUILD_DIR)/$(APP_NAME): $(SWIFT_SOURCES)
	@mkdir -p $(BUILD_DIR)
	@echo "Building $(APP_NAME)..."
	@swiftc -o $@ $(SWIFT_FLAGS) $(SWIFT_SOURCES)
	@echo "Build complete: $@"

# Build the app bundle
.PHONY: app
app: $(APP_BUNDLE)

$(APP_BUNDLE): $(BUILD_DIR)/$(APP_NAME) Resources/Info.plist
	@echo "Creating app bundle..."
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	@cp Resources/Info.plist $(APP_BUNDLE)/Contents/
	@echo "APPL????" > $(APP_BUNDLE)/Contents/PkgInfo
	@echo "App bundle created: $(APP_BUNDLE)"

# Install the app
.PHONY: install
install: stop app
	@echo "Installing $(APP_NAME)..."
	@mkdir -p $(INSTALL_DIR)
	@rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)
	@cp -R $(APP_BUNDLE) $(INSTALL_DIR)/
	@echo "Installed to $(INSTALL_DIR)/$(APP_BUNDLE)"
	@$(MAKE) setup-autostart
	@$(MAKE) start
	@echo "Installation complete!"

# Uninstall the app
.PHONY: uninstall
uninstall: stop
	@echo "Uninstalling $(APP_NAME)..."
	@rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)
	@rm -f $(LAUNCH_AGENT_PLIST)
	@echo "Removing support files..."
	@rm -rf $(SUPPORT_DIR)
	@echo "Uninstall complete!"

# Setup auto-start via LaunchAgent
.PHONY: setup-autostart
setup-autostart:
	@echo "Setting up auto-start..."
	@mkdir -p $(LAUNCH_AGENT_DIR)
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $(LAUNCH_AGENT_PLIST)
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(LAUNCH_AGENT_PLIST)
	@echo '<plist version="1.0">' >> $(LAUNCH_AGENT_PLIST)
	@echo '<dict>' >> $(LAUNCH_AGENT_PLIST)
	@echo '    <key>Label</key>' >> $(LAUNCH_AGENT_PLIST)
	@echo '    <string>com.user.clipboardmanager</string>' >> $(LAUNCH_AGENT_PLIST)
	@echo '    <key>ProgramArguments</key>' >> $(LAUNCH_AGENT_PLIST)
	@echo '    <array>' >> $(LAUNCH_AGENT_PLIST)
	@echo '        <string>$(INSTALL_DIR)/$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)</string>' >> $(LAUNCH_AGENT_PLIST)
	@echo '    </array>' >> $(LAUNCH_AGENT_PLIST)
	@echo '    <key>RunAtLoad</key>' >> $(LAUNCH_AGENT_PLIST)
	@echo '    <true/>' >> $(LAUNCH_AGENT_PLIST)
	@echo '    <key>KeepAlive</key>' >> $(LAUNCH_AGENT_PLIST)
	@echo '    <false/>' >> $(LAUNCH_AGENT_PLIST)
	@echo '</dict>' >> $(LAUNCH_AGENT_PLIST)
	@echo '</plist>' >> $(LAUNCH_AGENT_PLIST)
	@echo "Auto-start configured"

# Start the app
.PHONY: start
start:
	@echo "Starting $(APP_NAME)..."
	@launchctl load $(LAUNCH_AGENT_PLIST) 2>/dev/null || true
	@open $(INSTALL_DIR)/$(APP_BUNDLE) 2>/dev/null || $(INSTALL_DIR)/$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME) &
	@echo "App started"

# Stop the app
.PHONY: stop
stop:
	@echo "Stopping $(APP_NAME)..."
	@pkill -f "$(APP_NAME)" 2>/dev/null || true
	@launchctl unload $(LAUNCH_AGENT_PLIST) 2>/dev/null || true
	@sleep 1
	@echo "App stopped"

# Restart the app
.PHONY: restart
restart: stop start

# Run without installing (for development)
.PHONY: run
run: build
	@echo "Running $(APP_NAME)..."
	@./$(BUILD_DIR)/$(APP_NAME)

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(APP_BUNDLE)
	@echo "Clean complete"

# Deep clean (including support files)
.PHONY: distclean
distclean: clean
	@echo "Removing all support files..."
	@rm -rf $(SUPPORT_DIR)
	@echo "Deep clean complete"

# Create installer package
.PHONY: package
package: app
	@echo "Creating installer package..."
	@rm -f $(APP_NAME)-1.0.0.pkg
	@pkgbuild --root $(APP_BUNDLE) \
		--identifier com.user.clipboardmanager \
		--install-location /Applications/$(APP_BUNDLE) \
		--version 1.0.0 \
		$(APP_NAME)-1.0.0.pkg
	@echo "Package created: $(APP_NAME)-1.0.0.pkg"

# Show help
.PHONY: help
help:
	@echo "Clipboard Manager - Available Commands:"
	@echo ""
	@echo "  make build       - Build the executable"
	@echo "  make app         - Build the app bundle"
	@echo "  make install     - Install app to ~/Applications and setup auto-start"
	@echo "  make uninstall   - Remove app and all associated files"
	@echo "  make run         - Run the app without installing (for development)"
	@echo "  make start       - Start the installed app"
	@echo "  make stop        - Stop the running app"
	@echo "  make restart     - Restart the app"
	@echo "  make clean       - Remove build artifacts"
	@echo "  make distclean   - Remove build artifacts and support files"
	@echo "  make package     - Create installer package"
	@echo "  make help        - Show this help message"
	@echo ""
