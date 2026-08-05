class_name PlatformUtils
extends Object

## Cross-platform runtime checks used by touch UI and platform-specific systems.
## Web builds use browser capabilities and user-agent hints because OS.has_feature
## can only report "web", not whether the page is running on a phone/tablet.

static func is_mobile_native_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


static func is_web_platform() -> bool:
	return OS.has_feature("web")


static func is_mobile_web_browser() -> bool:
	if not is_web_platform():
		return false

	if not Engine.has_singleton("JavaScriptBridge"):
		return false
	var bridge := Engine.get_singleton("JavaScriptBridge")
	if bridge == null:
		return false

	var result: Variant = bridge.call("eval", """
		(() => {
			const nav = navigator || {};
			const ua = nav.userAgent || "";
			const uaDataMobile = !!(nav.userAgentData && nav.userAgentData.mobile);
			const mobileUa = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini|Mobile/i.test(ua);
			const touchPoints = Number(nav.maxTouchPoints || 0);
			const coarsePointer = !!(window.matchMedia && window.matchMedia("(pointer: coarse)").matches);
			const hoverless = !!(window.matchMedia && window.matchMedia("(hover: none)").matches);
			const viewportShortSide = Math.min(window.innerWidth || 0, window.innerHeight || 0);
			const screenWidth = (window.screen && window.screen.width) || 0;
			const screenHeight = (window.screen && window.screen.height) || 0;
			const screenShortSide = Math.min(screenWidth, screenHeight);
			const compactViewport = viewportShortSide > 0 && viewportShortSide <= 1100;
			const compactScreen = screenShortSide > 0 && screenShortSide <= 1200;

			// UA/userAgentData handles normal phones and tablets. Capability checks
			// cover installed PWAs and browsers that reduce their UA string.
			return uaDataMobile || mobileUa || (
				touchPoints > 1 && coarsePointer && hoverless && (compactViewport || compactScreen)
			);
		})()
	""", true)
	return result is bool and result


static func is_mobile_platform() -> bool:
	return is_mobile_native_platform() or is_mobile_web_browser()


static func is_desktop_native_platform() -> bool:
	return OS.has_feature("windows") or OS.has_feature("macos") or OS.has_feature("linuxbsd")


static func is_desktop_web_browser() -> bool:
	return is_web_platform() and not is_mobile_web_browser()


static func is_desktop_platform() -> bool:
	return is_desktop_native_platform() or is_desktop_web_browser()
