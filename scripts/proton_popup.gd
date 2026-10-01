class_name ProtonPopup
extends RefCounted
## Startup popup: this launcher only runs games through GE-Proton.

const TITLE := "THIS LAUNCHER REQUIRES GE-PROTON"

const MISSING_TEXT := """GE-Proton was NOT found. Every game here runs through GE-Proton, and launching is disabled until it is installed.

EASY WAY
  1. Open ProtonUp-Qt (or ProtonPlus) from your apps
  2. Install a numbered GE-Proton (e.g. GE-Proton11-7),
     NOT "Proton-GE Latest" (it can grab the ARM build)

MANUAL WAY
  1. Download GE-Proton*.tar.gz from the releases page
  2. Extract it into ~/.steam/root/compatibilitytools.d/

Then press RETRY."""

const NO_RUNTIME := "No Steam Linux Runtime was found (and no umu-run). Open Steam once so it can download its runtimes, then press RETRY."


static func build(parent: Control, proton_dir: String, on_retry: Callable, on_close: Callable) -> UiKit.Overlay:
	var o := UiKit.make_overlay(parent, TITLE, 900)
	var ready := Proton.can_launch(proton_dir)
	if ready:
		UiKit.add_label(o.box, "DETECTED: " + Proton.version_name(proton_dir), 28, Color("7cff7c"))
		UiKit.add_label(o.box, proton_dir, 18, Color(0.7, 0.7, 0.7))
		var runtime := Proton.find_runtime(proton_dir)
		var via: String = runtime[0].get_file() if not runtime.is_empty() else "umu-run"
		UiKit.add_label(o.box, "Every game is launched through %s using this exact GE-Proton build. Other Proton versions are not supported." % via)
		var row := UiKit.add_row(o.box)
		o.focus_target = UiKit.add_button(row, "  OK  ", on_close)
	else:
		if proton_dir == "":
			UiKit.add_label(o.box, MISSING_TEXT, 22)
		else:
			UiKit.add_label(o.box, "DETECTED: " + Proton.version_name(proton_dir), 24, Color("7cff7c"))
			UiKit.add_label(o.box, NO_RUNTIME, 22, UiKit.PINK)
		var row := UiKit.add_row(o.box)
		o.focus_target = UiKit.add_button(row, "RETRY", on_retry)
		UiKit.add_button(row, "OPEN DOWNLOAD PAGE", func(): OS.shell_open(Proton.RELEASES_URL))
		UiKit.add_button(row, "CLOSE", on_close)
	return o
