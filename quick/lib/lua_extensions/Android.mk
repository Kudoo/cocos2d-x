
LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE := lua_extensions_static
LOCAL_MODULE_FILENAME := libluaextensions

LOCAL_SRC_FILES := \
                        $(LOCAL_PATH)/cjson/fpconv.c \
                        $(LOCAL_PATH)/cjson/lua_cjson.c \
                        $(LOCAL_PATH)/cjson/strbuf.c \
                        $(LOCAL_PATH)/zlib/lua_zlib.c \
                        $(LOCAL_PATH)/filesystem/lfs.c \
                        $(LOCAL_PATH)/lpack/lpack.c \
                        $(LOCAL_PATH)/lsqlite3/sqlite3.c \
                        $(LOCAL_PATH)/lsqlite3/lsqlite3.c \


LOCAL_EXPORT_C_INCLUDES := $(COCOS2DX_ROOT)/external/luajit/include \
                           $(COCOS2DX_ROOT)/external/tolua \
                           $(QUICK_V3_LIB)/lua_bindings/manual \
                           $(LOCAL_PATH)/ \
                           $(LOCAL_PATH)/cjson \
                           $(LOCAL_PATH)/zlib \
                           $(LOCAL_PATH)/debugger \
                           $(LOCAL_PATH)/filesystem \
                           $(LOCAL_PATH)/lpack \
                           $(LOCAL_PATH)/lsqlite3

LOCAL_C_INCLUDES := $(LOCAL_PATH)/ \
                    $(COCOS2DX_ROOT)/external/lua/luajit/include \
                    $(COCOS2DX_ROOT)/external/lua/tolua \
                    $(QUICK_V3_LIB)/lua_bindings/manual \
                    $(LOCAL_PATH)/cjson \
                    $(LOCAL_PATH)/zlib \
                    $(LOCAL_PATH)/debugger \
                    $(LOCAL_PATH)/filesystem \
                    $(LOCAL_PATH)/lpack \
                    $(LOCAL_PATH)/lsqlite3 \
                    $(COCOS2DX_CORE) \
                    $(COCOS2DX_CORE)/platform \
                    $(COCOS2DX_CORE)/platform/android \
                    $(COCOS2DX_CORE)/kazmath/include \
                    $(COCOS2DX_ROOT)/extensions \
                    $(COCOS2DX_ROOT)/external

LOCAL_WHOLE_STATIC_LIBRARIES := luajit_static
#LOCAL_WHOLE_STATIC_LIBRARIES += cocos_extension_static

ifndef $(QUICK_MINI_TARGET)

    #LOCAL_WHOLE_STATIC_LIBRARIES += cocos_curl_static
    #LOCAL_WHOLE_STATIC_LIBRARIES += cocos_external_static

endif

LOCAL_CFLAGS += -Wno-psabi -DCC_LUA_ENGINE_ENABLED=1 $(ANDROID_COCOS2D_BUILD_FLAGS)

include $(BUILD_STATIC_LIBRARY)

$(call import-module,lua/luajit/prebuilt/android)
#$(call import-module,extensions)

ifndef $(QUICK_MINI_TARGET)
    #$(call import-module,external)
endif
