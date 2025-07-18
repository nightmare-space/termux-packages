TERMUX_PKG_HOMEPAGE=https://gitea.com/gitea/tea
TERMUX_PKG_DESCRIPTION="The official CLI for Gitea"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="0.10.0"
TERMUX_PKG_SRCURL=https://gitea.com/gitea/tea/archive/v$TERMUX_PKG_VERSION.tar.gz
TERMUX_PKG_SHA256=16cfbab7cf3c53d2291354d214edede008ab4e526af1573a3d8b5ef3cb549963
TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_BUILD_IN_SRC=true

termux_step_pre_configure() {
	termux_setup_golang
}

termux_step_make() {
	go mod vendor

	local SDK_VER=$(go list -f '{{.Version}}' -m code.gitea.io/sdk/gitea)
	go build \
		-ldflags "-X 'main.Version=${TERMUX_PKG_VERSION}' -X 'main.SDK=${SDK_VER}'" \
		-o tea
}

termux_step_make_install() {
	install -Dm700 -t "$TERMUX_PREFIX"/bin ./tea
}
