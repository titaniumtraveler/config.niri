#!/bin/env bash

run_niri() {
	exec {pipe}<> <(:)

	export RUST_LOG="error" MODE="script" PARENT="$$" PARENT_PIPE="$pipe"
	niri --config <(MODE="config" bash "$0") -- bash "$0"

	read -r -u "$pipe" exit_code
	read -r -u "$pipe"
	exec {pipe}>&-

	return "$exit_code"
}

print_config() {
	cat <<-KDL
		// red background to demonstrate the config is actually being applied
		layout {
			background-color "#FF0000"
		}
	KDL
}

run_niri_script() {
	niri msg -j outputs

	sleep 1

	niri msg action quit --skip-confirmation 2>/dev/null
}

diff_event_streams() {
	event_sock() {
		niri msg --json event-stream 2>/dev/null |
			# Add filters to prevent spurious events polluting the output
			jq --compact-output '.'
	}

	diff -u --report-identical-files --label='expected' - --label='actual' <(event_sock) <<-JSON
		{"WorkspacesChanged":{"workspaces":[{"id":1,"idx":1,"name":null,"output":"winit","is_urgent":false,"is_active":true,"is_focused":true,"active_window_id":null}]}}
		{"WindowsChanged":{"windows":[]}}
		{"KeyboardLayoutsChanged":{"keyboard_layouts":{"names":["English (US)"],"current_idx":0}}}
		{"OverviewOpenedOrClosed":{"is_open":false}}
		{"ConfigLoaded":{"failed":false}}
		{"CastsChanged":{"casts":[]}}
	JSON
	local diff_exit_code="$?"

	printf '%d\n' "$diff_exit_code" >"/proc/$PARENT/fd/$PARENT_PIPE"
}

main() {
	case "${MODE:=niri}" in
	config) print_config ;;
	script)
		exec 1>"/proc/$PARENT/fd/1"
		exec 2>"/proc/$PARENT/fd/2"

		diff_event_streams &
		run_niri_script

		wait
		echo "completed" >"/proc/$PARENT/fd/$PARENT_PIPE"
		;;
	niri) run_niri ;;
	*) printf 'Mode "%s" is not valid!\n' "$MODE" >&2 ;;
	esac
}

main
