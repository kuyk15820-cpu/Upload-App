ARCHS := arm64
TARGET := iphone:clang:16.5:14.0
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1
INSTALL_TARGET_PROCESSES := app

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := app

Trash_SRC = $(wildcard Trash/*.mm) $(wildcard Trash/*.m)

HUD_SRC = $(wildcard HUD/*.mm) $(wildcard HUD/*.m)

$(APPLICATION_NAME)_USE_MODULES := 0

$(APPLICATION_NAME)_FILES += $(wildcard sources/*.mm sources/*.m)

# $(APPLICATION_NAME)_FILES += $(Trash_SRC)

$(APPLICATION_NAME)_FILES += $(HUD_SRC)

$(APPLICATION_NAME)_CFLAGS += -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable -Wno-unused-value -Wno-module-import-in-extern-c -Wunused-but-set-variable -Wno-error=missing-noescape -Wno-error=objc-dictionary-duplicate-keys -Wno-error -Wno-unused-property-ivar -Wno-implicit-function-declaration

$(APPLICATION_NAME)_CFLAGS += -Iheaders -Isources -IENCRYPT -IHUD

$(APPLICATION_NAME)_STRIP = 1

$(APPLICATION_NAME)_CCFLAGS += -std=c++17 -fno-rtti -DNDEBUG -Wall -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -Wno-unused-function -fvisibility=hidden -IENCRYPT -fbracket-depth=1024

$(APPLICATION_NAME)_LDFLAGS += -lstdc++ -undefined dynamic_lookup

$(APPLICATION_NAME)_FRAMEWORKS += UIKit Foundation CoreGraphics QuartzCore Security AVFoundation AudioToolbox CoreMedia MobileCoreServices SystemConfiguration ImageIO WebKit UniformTypeIdentifiers

$(APPLICATION_NAME)_CODESIGN_FLAGS += -Slayout/entitlements.plist
$(APPLICATION_NAME)_RESOURCE_DIRS = ./layout/Resources

BUILD_NUMBER := $(shell date +%y%m%d%H%M)

include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

before-package::
	@echo "[*] Updating Build Number to $(BUILD_NUMBER)..."
	@sed -i '' 's/<string>1<\/string>/<string>$(BUILD_NUMBER)<\/string>/g' $(THEOS_STAGING_DIR)/Applications/$(APPLICATION_NAME).app/Info.plist

after-package::
	@rm -rf Payload
	@mkdir -p Payload
	@cp -r .theos/_/Applications/$(APPLICATION_NAME).app Payload/
	@chmod 755 Payload/$(APPLICATION_NAME).app/$(APPLICATION_NAME)
	@zip -rq $(APPLICATION_NAME).ipa Payload
	@rm -rf Payload
	@mkdir -p packages
	@mv $(APPLICATION_NAME).ipa packages/
	@echo "[*] Success: packages/$(APPLICATION_NAME).ipa"