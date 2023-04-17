#include <stdint.h>
#include <stdbool.h>

typedef void * (*DeserializeHandler)(const uint8_t *bytes, uintptr_t bytes_len);

void reax_init(const int8_t * storage_dir);
void reax_init_handler(void * ptr, void (*callback)(int32_t id, bool is_stream, const uint8_t *bytes, uintptr_t bytes_len, void * ptr));
void reax_abort(void * handle);

void reax_storage_init();
void * reax_storage_welcome_shown(DeserializeHandler handler);
void * reax_storage_show_welcome(DeserializeHandler handler);
void * reax_storage_start_track(DeserializeHandler handler);
void * reax_storage_stop_track(DeserializeHandler handler);
void * reax_storage_delete_track(int64_t timestamp, DeserializeHandler handler);
void * reax_storage_store_track_value(const uint8_t * bytes, intptr_t bytes_len, DeserializeHandler handler);
void * reax_storage_tracks(DeserializeHandler handler);
void * reax_storage_track(int64_t timestamp, DeserializeHandler handler);
void * reax_storage_save_peripheral(const uint8_t * bytes, intptr_t bytes_len, DeserializeHandler handler);
void * reax_storage_peripherals(int32_t stream_id);
