
LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE := quickcocos2dx
LOCAL_MODULE_FILENAME := libquickcocos2dx

LOCAL_CFLAGS := -Wno-psabi -DUSE_FILE32API -DCC_LUA_ENGINE_ENABLED=1 $(ANDROID_COCOS2D_BUILD_FLAGS)
LOCAL_EXPORT_CFLAGS := -Wno-psabi -DUSE_FILE32API -DCC_LUA_ENGINE_ENABLED=1

LOCAL_WHOLE_STATIC_LIBRARIES := cocos_lua_static
LOCAL_WHOLE_STATIC_LIBRARIES += extra_static
LOCAL_WHOLE_STATIC_LIBRARIES += event_static
LOCAL_WHOLE_STATIC_LIBRARIES += websockets_static
LOCAL_WHOLE_STATIC_LIBRARIES += cocos_network_static
#LOCAL_WHOLE_STATIC_LIBRARIES += cocosbuilder_static
#LOCAL_WHOLE_STATIC_LIBRARIES += spine_static

include $(BUILD_STATIC_LIBRARY)

$(call import-module,lua_bindings)
$(call import-module,extra)
$(call import-module,event)
$(call import-module,extensions)
$(call import-module,websockets/prebuilt/android)
$(call import-module,network)
#$(call import-module,editor-support/cocosbuilder)
#$(call import-module,editor-support/spine)