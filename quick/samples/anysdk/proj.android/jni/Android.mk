LOCAL_PATH := $(call my-dir)

$(call import-add-path, $(QUICK_V3_LIB)/extra/anysdk/)

include $(CLEAR_VARS)

LOCAL_MODULE := game_shared

LOCAL_MODULE_FILENAME := libgame

LOCAL_SRC_FILES := hellocpp/main.cpp \
    ../../sources/AppDelegate.cpp \
    $(QUICK_V3_LIB)/ProjectConfig/SimulatorConfig.cpp

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../../sources

LOCAL_LDLIBS := -lGLESv2 \
                -llog \
                -lz \
                -landroid

LOCAL_EXPORT_LDLIBS := -lGLESv1_CM \
                       -lGLESv2 \
                       -lEGL \
                       -llog \
                       -lz \
                       -landroid

LOCAL_WHOLE_STATIC_LIBRARIES := libquickcocos2dx
LOCAL_WHOLE_STATIC_LIBRARIES += PluginProtocolStatic

include $(BUILD_SHARED_LIBRARY)

$(call import-module,proj.android)
$(call import-module,protocols/android)
