TARGET := iphone:clang:15.0:14.0
INSTALL_TARGET_PROCESSES = com.garena.game.kgvo

LIBRARY_NAME = libsupport
libsupport_FILES = liberi.mm
libsupport_CFLAGS = -fobjc-arc
libsupport_FRAMEWORKS = UIKit Foundation
libsupport_LIBRARIES = objc fishhook
