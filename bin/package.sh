#!/bin/sh

BIN_DIR="$(dirname $(readlink -f "$0"))"
export PROJECT_ROOT="${PROJECT_ROOT:-"$(dirname "$BIN_DIR")"}"
export ARTIFACTS_DIR="${ARTIFACTS_DIR:-"$PROJECT_ROOT/artifacts"}"

export BUILD_VERSION=${BUILD_VERSION:-"6.1.0"}
export BUILD_VERSION_TEXT=${BUILD_VERSION_TEXT:-"rc1"}
export SBP_VERSION=$(echo "$BUILD_VERSION-$BUILD_VERSION_TEXT")

set -o errexit

# cleanup

cd ${PROJECT_ROOT}

rm -rf var/cache/* \
    vendor/shopware/administration/Resources/nuxt-component-library \
    vendor/shopware/core/Framework/Test \
    vendor/shopware/core/Content/Test \
    vendor/shopware/core/Checkout/Test \
    vendor/shopware/elasticsearch/Test \
    vendor/shopware/platform/src/Docs \
    vendor/shopware/platform/bin \
    vendor/symfony/*/Tests \
    vendor/twig/twig/test \
    vendor/swiftmailer/swiftmailer/tests \
    vendor/google/auth/tests \
    vendor/monolog/monolog/tests \
    vendor/phenx/php-font-lib/sample-fonts

mkdir -p var/log var/cache var/queue

echo "${SBP_VERSION}" > public/recovery/install/data/version

REFERENCE_INSTALLER_URL="https://releases.shopware.com/sw6/install_6.0.0_ea1_1563354247.zip"
REFERENCE_INSTALLER_SHA256="eea7508800e95fbdd4cc89ada1a29aba429db82b41a94ae32bf9e34ea27a3697"
REFERENCE_INSTALLER_FILE="$ARTIFACTS_DIR/reference.zip"

# make update
if [ -n "$REFERENCE_INSTALLER_URL" ]; then
    curl -sS "${REFERENCE_INSTALLER_URL}" -o "$REFERENCE_INSTALLER_FILE"
    HASH_CHECK_LINE="$REFERENCE_INSTALLER_SHA256  $REFERENCE_INSTALLER_FILE"
    echo "${HASH_CHECK_LINE}" | sha256sum -c -

    set -x

    REFERENCE_TEMP_DIR=$(mktemp -d)
    cd $REFERENCE_TEMP_DIR
    mv "$REFERENCE_INSTALLER_FILE" .
    unzip -qq *.zip

    UPDATE_TEMP_DIR=$(mktemp -d)

    # copy files that changed between the reference and the new version
    rsync -rvcmq --compare-dest="$REFERENCE_TEMP_DIR" "$PROJECT_ROOT/" "$UPDATE_TEMP_DIR/"
    cd "$UPDATE_TEMP_DIR"

    # add update meta information
    mkdir update-assets
    echo "${BUILD_VERSION} ${BUILD_VERSION_TEXT}" > update-assets/version

    ${PROJECT_ROOT}/bin/deleted_files_vendor.sh -o"$REFERENCE_TEMP_DIR/vendor" -n"$PROJECT_ROOT/vendor" > update-assets/cleanup.txt

    zip -qq -9 -r update.zip .

    mv update.zip "$ARTIFACTS_DIR/update.zip"
fi

# installer

cd ${PROJECT_ROOT}

zip -qq -9 -r install.zip .
mv install.zip "$ARTIFACTS_DIR/"

