#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

// Returns PNG bytes for a video poster using ffmpegthumbnailer, or empty on
// failure / when the tool is not installed. No hard dependency: absence just
// yields the placeholder on the Dart side.
static std::vector<uint8_t> GenerateThumbnailPng(const std::string& path,
                                                 int max_dim) {
  std::vector<uint8_t> bytes;
  char tmpl[] = "/tmp/subm_vthumbXXXXXX.png";
  int fd = mkstemps(tmpl, 4);
  if (fd < 0) return bytes;
  close(fd);

  // -c png writes PNG to the output path; -s sets the size; -t 10% seeks.
  std::string cmd = "ffmpegthumbnailer -i '" + path + "' -o '" + tmpl +
                    "' -s " + std::to_string(max_dim) +
                    " -c png -t 10% >/dev/null 2>&1";
  int rc = std::system(cmd.c_str());
  if (rc == 0) {
    if (FILE* f = std::fopen(tmpl, "rb")) {
      std::fseek(f, 0, SEEK_END);
      long n = std::ftell(f);
      std::fseek(f, 0, SEEK_SET);
      if (n > 0) {
        bytes.resize(static_cast<size_t>(n));
        if (std::fread(bytes.data(), 1, bytes.size(), f) != bytes.size()) {
          bytes.clear();
        }
      }
      std::fclose(f);
    }
  }
  std::remove(tmpl);
  return bytes;
}

static void local_media_method_call_cb(FlMethodChannel* channel,
                                       FlMethodCall* method_call,
                                       gpointer user_data) {
  if (g_strcmp0(fl_method_call_get_name(method_call),
                "generateVideoThumbnail") != 0) {
    fl_method_call_respond_not_implemented(method_call, nullptr);
    return;
  }
  FlValue* args = fl_method_call_get_args(method_call);
  std::string path;
  int max_dim = 512;
  if (fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
    FlValue* p = fl_value_lookup_string(args, "path");
    if (p && fl_value_get_type(p) == FL_VALUE_TYPE_STRING) {
      path = fl_value_get_string(p);
    }
    FlValue* m = fl_value_lookup_string(args, "maxDimension");
    if (m && fl_value_get_type(m) == FL_VALUE_TYPE_INT) {
      max_dim = static_cast<int>(fl_value_get_int(m));
    }
  }

  g_autoptr(FlMethodResponse) response = nullptr;
  if (path.empty()) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    std::vector<uint8_t> png = GenerateThumbnailPng(path, max_dim);
    if (png.empty()) {
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    } else {
      g_autoptr(FlValue) v = fl_value_new_uint8_list(png.data(), png.size());
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(v));
    }
  }
  fl_method_call_respond(method_call, response, nullptr);
}

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "submersion");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "submersion");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Local media channel: OS-generated video poster thumbnails. Kept alive for
  // the app lifetime by tying it to the view's object lifetime.
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* local_media_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "com.submersion.app/local_media", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      local_media_channel, local_media_method_call_cb, nullptr, nullptr);
  g_object_set_data_full(G_OBJECT(view), "local_media_channel",
                         local_media_channel, g_object_unref);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
