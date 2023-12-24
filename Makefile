phony: test build deploy run clean

clean:
	rm -rf .pub-cache
	rm -rf .dart_tool
	flutter clean

install: clean
	flutter packages get
	flutter packages upgrade
	flutter update-packages
	flutter pub cache repair
	flutter precache

run:
	flutter run

build_linux:
	flutter build linux --release

build_macos:
	flutter build macos

build_windows:
	flutter build windows --release