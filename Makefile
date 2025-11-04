.PHONY: generate clear build dmg release qa

generate:
	@Scripts/generate.sh

clear:
	@Scripts/clear.sh

build:
	@echo "🔨 Building AIUsageTracker..."
	@xcodebuild -workspace AIUsageTracker.xcworkspace -scheme AIUsageTracker -configuration Release -destination "platform=macOS" -skipMacroValidation build

dmg:
	@echo "💽 Creating DMG package..."
	@Scripts/create_dmg.sh

release: clear generate build dmg
	@echo "🚀 Release build completed! DMG is ready for distribution."

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Darwin)
qa:
	@echo "🧪 Running core analytics tests"
	@swift test --package-path Packages/VibeviewerCore
	@echo "🧪 Running storage pipeline tests"
	@swift test --package-path Packages/VibeviewerStorage
else
qa:
	@echo "⚠️  QA suite requires macOS frameworks; skipping on $(UNAME_S)"
endif


