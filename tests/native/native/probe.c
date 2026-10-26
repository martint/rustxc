#include <stdint.h>
#include <stdlib.h>
#ifdef __linux__
#include <alsa/asoundlib.h>
#include <libudev.h>
#include <dbus/dbus.h>
#include <wayland-client.h>
#include <X11/Xlib.h>
#include <xkbcommon/xkbcommon.h>
/* Strong references force the linker to consume target libraries. This function
 * is linked but never called: smoke tests do not open desktop/audio devices. */
void *rustxc_discovery(void) {
    int major, minor, micro;
    dbus_get_version(&major, &minor, &micro);
    const char *version = snd_asoundlib_version();
    struct udev *udev = udev_new();
    struct wl_display *display = wl_display_connect(NULL);
    Display *x11 = XOpenDisplay(NULL);
    struct xkb_context *xkb = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    return version && udev && display && x11 ? xkb : NULL;
}
#endif
int rustxc_c(void) { return (int)sizeof(uint64_t); }
