THEOS ?= /home/codespace/theos
ARCHS = arm64 arm64e
TARGET = iphone:latest:17.0

ifeq ($(wildcard $(THEOS)/makefiles/common.mk),)
$(error Theos not found at $(THEOS). Set THEOS to your Theos path.)
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SpotifyTweak
SpotifyTweak_FILES = Tweak.xm
SpotifyTweak_FRAMEWORKS = UIKit WebKit MediaPlayer AVFoundation
SpotifyTweak_CFLAGS = -fobjc-arc
SpotifyTweak_CFLAGS += -DSIDELOADING=1

include $(THEOS)/makefiles/tweak.mk
