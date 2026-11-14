APP_NAME   := AirHalo
PROJECT    := $(APP_NAME).xcodeproj
DERIVED    := build/DerivedData
CONFIG     ?= Debug
APP_PATH   := $(DERIVED)/Build/Products/$(CONFIG)/$(APP_NAME).app

.PHONY: gen build run stop test clean signing open

## Generate the Xcode project from project.yml
gen:
	xcodegen generate --quiet

## Build the app
build: gen
	xcodebuild -project $(PROJECT) -scheme $(APP_NAME) -configuration $(CONFIG) \
		-derivedDataPath $(DERIVED) -destination 'platform=macOS' -quiet build
	@echo "Built $(APP_PATH)"

## Build, quit any running copy, and launch
run: build stop
	open "$(APP_PATH)"

## Quit a running AirHalo
stop:
	-@pkill -x $(APP_NAME) 2>/dev/null || true

## Run the gesture brain's unit tests (no Xcode project needed)
test:
	cd Packages/AirHaloBrain && swift test

## Open the project in Xcode
open: gen
	open $(PROJECT)

## Write Config/Signing.local.xcconfig from your Apple Development certificate
signing:
	@NAME=$$(security find-identity -v -p codesigning 2>/dev/null \
		| sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -1); \
	if [ -z "$$NAME" ]; then \
		echo "No usable 'Apple Development' signing identity (certificate + private key) on this Mac."; \
		echo "In Xcode: Settings > Accounts > your team > Manage Certificates > + > Apple Development."; \
		exit 1; \
	fi; \
	TEAM=$$(security find-certificate -c "$$NAME" -p 2>/dev/null \
		| openssl x509 -noout -subject 2>/dev/null \
		| sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1); \
	printf 'DEVELOPMENT_TEAM = %s\nCODE_SIGN_IDENTITY = Apple Development\n' "$$TEAM" > Config/Signing.local.xcconfig; \
	echo "Wrote Config/Signing.local.xcconfig (team $$TEAM)"

clean:
	rm -rf build $(PROJECT)
