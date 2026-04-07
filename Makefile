# VoiceInput — Swift Package Manager + signed .app bundle
APP_NAME := VoiceInput
BUILD_DIR := .build
ENTITLEMENTS := Resources/VoiceInput.entitlements
INFO_PLIST := Resources/Info.plist

.PHONY: build package run install clean

build:
	swift build -c release

package: build
	@echo "Packaging $(APP_NAME).app …"
	@BIN_PATH="$$(swift build -c release --show-bin-path)/$(APP_NAME)"; \
	rm -rf "$(BUILD_DIR)/$(APP_NAME).app"; \
	mkdir -p "$(BUILD_DIR)/$(APP_NAME).app/Contents/MacOS"; \
	mkdir -p "$(BUILD_DIR)/$(APP_NAME).app/Contents/Resources"; \
	cp "$$BIN_PATH" "$(BUILD_DIR)/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)"
	cp "$(INFO_PLIST)" "$(BUILD_DIR)/$(APP_NAME).app/Contents/Info.plist"
	printf 'APPL????' > "$(BUILD_DIR)/$(APP_NAME).app/Contents/PkgInfo"
	codesign --force --deep --sign - --entitlements "$(ENTITLEMENTS)" "$(BUILD_DIR)/$(APP_NAME).app"
	@echo "Built: $(BUILD_DIR)/$(APP_NAME).app"

run: package
	open "$(BUILD_DIR)/$(APP_NAME).app"

install: package
	cp -R "$(BUILD_DIR)/$(APP_NAME).app" /Applications/
	@echo "Installed to /Applications/$(APP_NAME).app"

clean:
	swift package clean
	rm -rf "$(BUILD_DIR)"
