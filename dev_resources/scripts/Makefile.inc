
VERSION_MIN := 8.0
ARCHS := armv7 armv7s arm64 x86_64 i386

define host
$(if $(filter armv7 armv7s,$(1)),\
    --host=arm-apple-darwin,\
    $(if $(filter arm64,$(1)),\
        --host=aarch64-apple-darwin,\
        $(if $(filter i386,$(1)),\
            --host=i386-apple-darwin,\
        )\
    )\
)
endef

define cpu
$(if $(filter armv7s,$(1)),\
    -mcpu=swift,\
)
endef

define fpu
$(if $(filter armv7%,$(1)),\
    -mfpu=neon,\
)
endef

define sdk
$(if $(filter arm%,$(1)),\
    iphoneos,\
    iphonesimulator\
)
endef

define version_min
$(if $(filter arm%,$(1)),\
    -miphoneos-version-min=$(VERSION_MIN),\
    -mios-simulator-version-min=$(VERSION_MIN)\
)
endef
