#!/bin/sh
scons target=template_release \
	optimize=size \
	lto=full \
	module_text_server_adv_enabled=no \
	module_text_server_fb_enabled=yes \
	disable_3d=yes \
	module_vorbis_enabled=no \
	module_webrtc_enabled=no \
	module_websocket_enabled=no \
	module_webxr_enabled=no \
	module_multiplayer_enabled=no \
	module_noise_enabled=no \
	module_raycast_enabled=no \
	module_mobile_vr_enabled=no \
	module_ogg_enabled=no \
	module_theora_enabled=no \
	debug_symbols=no
