#include <stdbool.h>

typedef void * (*DeserializeHandler)(const unsigned char *bytes, int bytes_len);

void reax_init(const char * storage_dir);
void reax_init_handler(void * ptr, void (*callback)(int id, bool is_stream, const unsigned char *bytes, int bytes_len, void * ptr));
void reax_abort(void * handle);

void reax_storage_init();
void * reax_storage_welcome_shown(DeserializeHandler handler);
void * reax_storage_show_welcome(DeserializeHandler handler);
void * reax_storage_start_track(DeserializeHandler handler);
void * reax_storage_stop_track(DeserializeHandler handler);
void * reax_storage_store_track_value(double acc_x, double acc_y, double acc_z, DeserializeHandler handler);
void * reax_storage_tracks(DeserializeHandler handler);
